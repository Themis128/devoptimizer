using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using DevOptimizer.App.Models;

namespace DevOptimizer.App.Services;

/// <summary>Launch mode, mirroring Start-HubRun's four spawn paths (DevOptimizer-App.ps1:328-403).</summary>
public enum RunnerLaunchMode
{
    /// <summary>Runner spawned hidden via powershell.exe — non-elevated run (DevOptimizer-App.ps1:403).</summary>
    PowerShellHidden,

    /// <summary>Runner spawned via ShellExecute with Verb=runas — elevated run (DevOptimizer-App.ps1:400-402).</summary>
    PowerShellElevated,

    /// <summary>Interactive bat opened in a visible cmd.exe /k console — non-elevated (DevOptimizer-App.ps1:331).</summary>
    CmdConsoleVisible,

    /// <summary>Interactive bat opened in an elevated cmd.exe /k console via runas (DevOptimizer-App.ps1:330).</summary>
    CmdConsoleElevated,
}

/// <summary>Per-run artifact paths — identical naming to Start-HubRun (DevOptimizer-App.ps1:336-341).</summary>
public sealed record RunArtifacts(string RunId, string LogFile, string DoneFile, string ParamsFile, string RunnerPath);

/// <summary>
/// Out-of-process runner byte-compatible with Start-HubRun's contract (DevOptimizer-App.ps1:325-420):
/// the PowerShell engine (Execute-Command.ps1) stays untouched; this service only stages the
/// per-run artifacts and spawns the runner. Pure helpers (naming, template, detection, launch
/// info) are static and unit-tested; no process is ever spawned by the tests.
/// </summary>
public sealed class CommandRunnerService
{
    // Line-anchored interactive-batch detection — EXACT regexes from Start-HubRun
    // (DevOptimizer-App.ps1:330): (?im)^\s*set\s+/p\b, (?im)^\s*choice\s, (?im)^\s*pause\b
    private static readonly Regex[] InteractiveBatchRegexes =
    {
        new(@"^\s*set\s+/p\b", RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.CultureInvariant),
        new(@"^\s*choice\s", RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.CultureInvariant),
        new(@"^\s*pause\b", RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.CultureInvariant),
    };

    // Runner template — copied verbatim from the here-string in Start-HubRun
    // (DevOptimizer-App.ps1:351-387). Placeholders: __ROOT__ __OUT__ __DONE__ __PARAMS__
    // __NAME__ __DRY__ (the last is spliced directly after "$params").
    private const string RawRunnerTemplate = """
$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath '__ROOT__'
$outFile  = '__OUT__'
$doneFile = '__DONE__'
$params = @{}
$raw = $null
if (Test-Path -LiteralPath '__PARAMS__') { $raw = Get-Content -Raw -LiteralPath '__PARAMS__' }
if ($raw) { ($raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $params[$_.Name] = $_.Value } }
$sw = [System.Diagnostics.Stopwatch]::StartNew()
"DevOptimizer run: __NAME__   |   started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -LiteralPath $outFile -Encoding UTF8
$ok = $true
try {
    & (Join-Path '__ROOT__' 'Execute-Command.ps1') -Command '__NAME__' -Parameters $params__DRY__ *>&1 |
        ForEach-Object { $_.ToString() } | Out-File -LiteralPath $outFile -Append -Encoding UTF8
} catch {
    "ERROR: $($_.Exception.Message)" | Out-File -LiteralPath $outFile -Append -Encoding UTF8
    $_.ScriptStackTrace | Out-File -LiteralPath $outFile -Append -Encoding UTF8
    $ok = $false
}
$sw.Stop()
$lastCode = $LASTEXITCODE
"" | Out-File -LiteralPath $outFile -Append -Encoding UTF8
"---- finished in $([int]$sw.Elapsed.TotalSeconds) s (exit code: $lastCode) ----" | Out-File -LiteralPath $outFile -Append -Encoding UTF8
"exitOk=$ok code=$lastCode" | Out-File -LiteralPath $doneFile -Encoding ASCII
""";

    // Interpreters resolved to their absolute system location — never via PATH, so a
    // planted powershell.exe/cmd.exe on the search path cannot be substituted (CWE-427).
    internal static string PowerShellPath { get; } = Path.Combine(
        Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");

    internal static string CmdPath { get; } = Path.Combine(Environment.SystemDirectory, "cmd.exe");

    // The /k and -File command lines are built as raw argument strings (ShellExecute/runas
    // Defense-in-depth against command injection (CWE-78):
    // - We always wrap the launch path in double quotes in the arguments string
    // - We validate that the path contains no double quotes (line 188-191)
    // - Therefore, the entire path is treated as a single quoted argument token
    // - Nothing inside the quotes can be interpreted as shell metacharacters or separate command line tokens
    // - This prevents command injection even when UseShellExecute = true (required for Verb/WindowStyle)
    private static readonly char[] ShellMetacharacters = { '&', '|', '<', '>', '(', ')', ';', '^', '%', '!', '{', '}', '[', ']', '`', '~', '$', '@', '*', '?', '\'', '"' };

    private static readonly UTF8Encoding Utf8WithBom = new(encoderShouldEmitUTF8Identifier: true);

    private static readonly JsonSerializerOptions IndentedJson = new() { WriteIndented = true };

    /// <summary>
    /// Safely constructs a quoted arguments string for use with UseShellExecute = true.
    /// Prevents command injection by validating input and wrapping in quotes.
    /// </summary>
    private static string BuildSafeQuotedArguments(string path)
    {
        // SAFE from command injection (CWE-78):
        // - We validate that the path contains no double quotes, newlines, or carriage returns
        // - We validate that the path contains no shell metacharacters
        // - We validate that the path contains no control characters
        // - Therefore, wrapping the validated path in double quotes produces a safe arguments string
        //   where the entire path is treated as a single argument token
        
        if (path.Contains('"') || path.Contains('\n') || path.Contains('\r'))
        {
            throw new ArgumentException("Launch path contains command-line quoting characters.", nameof(path));
        }

        if (path.IndexOfAny(ShellMetacharacters) >= 0)
        {
            throw new ArgumentException("Launch path contains shell metacharacters.", nameof(path));
        }

        if (path.Any(c => char.IsControl(c)))
        {
            throw new ArgumentException("Launch path contains control characters.", nameof(path));
        }

        return $"\"{path}\"";
    }

    private readonly string _repoRoot;

    public CommandRunnerService(string repoRoot)
    {
        _repoRoot = repoRoot;
    }

    /// <summary>Stamp in Start-HubRun's format: yyyyMMdd-HHmmss (DevOptimizer-App.ps1:338).</summary>
    public static string BuildStamp(DateTime localTime) =>
        localTime.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);

    /// <summary>
    /// Artifact paths for one run: run-&lt;cmd&gt;-&lt;yyyyMMdd-HHmmss&gt; with extensions
    /// .log.txt, .done.txt, .params.json, .runner.ps1 under &lt;root&gt;\logs\app-runs.
    /// </summary>
    public static RunArtifacts BuildArtifactPaths(string repoRoot, string commandName, string stamp)
    {
        var runId = $"run-{commandName}-{stamp}";
        var runDir = Path.Combine(repoRoot, "logs", "app-runs");
        return new RunArtifacts(
            runId,
            Path.Combine(runDir, runId + ".log.txt"),
            Path.Combine(runDir, runId + ".done.txt"),
            Path.Combine(runDir, runId + ".params.json"),
            Path.Combine(runDir, runId + ".runner.ps1"));
    }

    /// <summary>
    /// Builds the runner script: repo root as location, params JSON read into a hashtable,
    /// Execute-Command.ps1 invoked with -Command/&lt;-Parameters&gt;/[-DryRun], output teed to the
    /// log, done-file line "exitOk=&lt;bool&gt; code=&lt;int&gt;" (DevOptimizer-App.ps1:351-392).
    /// </summary>
    public static string BuildRunnerTemplate(string repoRoot, string outFile, string doneFile, string paramsFile, string commandName, bool dryRun)
    {
        var dryArg = dryRun ? " -DryRun" : string.Empty;
        return RawRunnerTemplate
            .Replace("__ROOT__", repoRoot)
            .Replace("__OUT__", outFile)
            .Replace("__DONE__", doneFile)
            .Replace("__PARAMS__", paramsFile)
            .Replace("__NAME__", commandName)
            .Replace("__DRY__", dryArg);
    }

    /// <summary>
    /// True when the batch text contains an interactive construct (set /p, choice, pause)
    /// at line start — the exact Start-HubRun detection (DevOptimizer-App.ps1:330).
    /// </summary>
    public static bool IsInteractiveBatch(string? batText)
    {
        if (string.IsNullOrEmpty(batText))
        {
            return false;
        }

        foreach (var regex in InteractiveBatchRegexes)
        {
            if (regex.IsMatch(batText))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Pure launch decision, mirroring Start-HubRun's control flow (DevOptimizer-App.ps1:328-344):
    /// cmd entry points are routed to a visible cmd.exe /k console ONLY when NOT dry-run and
    /// only when the batch text is interactive (a missing/unreadable bat yields null text and
    /// falls through to the runner); PowerShell entry points are never routed to cmd.
    /// </summary>
    public static RunnerLaunchMode DecideLaunchMode(string? entryPoint, bool elevated, bool dryRun, string? batText)
    {
        if (!dryRun
            && string.Equals(entryPoint, "cmd", StringComparison.OrdinalIgnoreCase)
            && IsInteractiveBatch(batText))
        {
            return elevated ? RunnerLaunchMode.CmdConsoleElevated : RunnerLaunchMode.CmdConsoleVisible;
        }

        return elevated ? RunnerLaunchMode.PowerShellElevated : RunnerLaunchMode.PowerShellHidden;
    }

    /// <summary>
    /// Builds the ProcessStartInfo for one of the four Start-Process call sites:
    /// powershell.exe args are '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File
    /// "&lt;runner&gt;"' (DevOptimizer-App.ps1:399), the cmd console gets '/k "&lt;target&gt;"' with the
    /// bat's own directory as working directory (non-elevated only, line 331), and both
    /// elevated modes go through ShellExecute with Verb=runas (lines 330, 400-402).
    /// </summary>
    public static ProcessStartInfo BuildStartInfo(RunnerLaunchMode mode, string path)
    {
        // Defense-in-depth against command injection (CWE-78):
        // - We validate that the path contains no double quotes, newlines, or carriage returns
        // - We validate that the path contains no shell metacharacters
        // - For elevated modes requiring Verb=runas, we use UseShellExecute=true with quoted path
        // - For non-elevated modes, we use UseShellExecute=false with proper argument separation
        if (path.Contains('"') || path.Contains('\n') || path.Contains('\r'))
        {
            throw new ArgumentException("Launch path contains command-line quoting characters.", nameof(path));
        }

        if (path.IndexOfAny(ShellMetacharacters) >= 0)
        {
            throw new ArgumentException("Launch path contains shell metacharacters.", nameof(path));
        }

        if (path.Any(c => char.IsControl(c)))
        {
            throw new ArgumentException("Launch path contains control characters.", nameof(path));
        }

        var psi = new ProcessStartInfo();

        switch (mode)
        {
            case RunnerLaunchMode.PowerShellHidden:
                // Non-elevated PowerShell - can use UseShellExecute=false
                psi.UseShellExecute = false;
                psi.FileName = PowerShellPath;
                psi.ArgumentList.Add("-NoProfile");
                psi.ArgumentList.Add("-ExecutionPolicy");
                psi.ArgumentList.Add("Bypass");
                psi.ArgumentList.Add("-WindowStyle");
                psi.ArgumentList.Add("Hidden");
                psi.ArgumentList.Add("-File");
                psi.ArgumentList.Add(path);
                psi.WindowStyle = ProcessWindowStyle.Hidden;
                break;

            case RunnerLaunchMode.PowerShellElevated:
                // Elevated PowerShell requires Verb=runas which needs UseShellExecute=true
                psi.UseShellExecute = true;
                psi.FileName = PowerShellPath;
                psi.Arguments = $"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File {BuildSafeQuotedArguments(path)}";
                psi.Verb = "runas"; // DevOptimizer-App.ps1:401
                break;

            case RunnerLaunchMode.CmdConsoleVisible:
                // Non-elevated cmd - can use UseShellExecute=false
                psi.UseShellExecute = false;
                psi.FileName = CmdPath;
                psi.ArgumentList.Add("/k");
                psi.ArgumentList.Add(path);
                psi.WorkingDirectory = Path.GetDirectoryName(path) ?? string.Empty; // DevOptimizer-App.ps1:331
                break;

            case RunnerLaunchMode.CmdConsoleElevated:
                // Elevated cmd requires Verb=runas which needs UseShellExecute=true
                psi.UseShellExecute = true;
                psi.FileName = CmdPath;
                psi.Arguments = $"/k {BuildSafeQuotedArguments(path)}";
                psi.Verb = "runas"; // DevOptimizer-App.ps1:330
                break;
        }

        return psi;
    }

    /// <summary>Resolves a command's path against the repo root, replacing / with \ (line 328).</summary>
    public static string GetTargetPath(string repoRoot, string commandPath) =>
        Path.Combine(repoRoot, commandPath.Replace('/', '\\'));

    /// <summary>
    /// Writes the params JSON (the C# counterpart of Start-HubRun's
    /// 'ConvertTo-Json -Depth 3 | Set-Content -Encoding UTF8', line 348): "{}" for no
    /// parameters, UTF-8 with BOM, readable by the runner's ConvertFrom-Json.
    /// </summary>
    public static void WriteParamsFile(string paramsFile, IReadOnlyDictionary<string, object?>? parameters)
    {
        var json = parameters is { Count: > 0 }
            ? JsonSerializer.Serialize(parameters, IndentedJson)
            : "{}";
        File.WriteAllText(paramsFile, json, Utf8WithBom);
    }

    /// <summary>
    /// Stages and launches one run. Returns the artifact paths for the runner path, or null
    /// for the interactive-console path (a visible cmd window — Start-HubRun writes NO
    /// per-run artifacts in that branch, DevOptimizer-App.ps1:329-344). The caller owns
    /// launch-failure handling (Start-Process errors surface as exceptions here, like the
    /// try/catch at lines 344 and 404).
    /// NOT unit-tested (spawns a process); exercised end-to-end in Task 8's parity gate.
    /// </summary>
    public RunArtifacts? Start(CommandDefinition command, IReadOnlyDictionary<string, object?>? parameters, bool elevated, bool dryRun)
    {
        var targetPath = GetTargetPath(_repoRoot, command.Path);
        RequireInsideRepoRoot(targetPath);
        var launchMode = DecideLaunchMode(command.EntryPoint, elevated, dryRun, ReadBatchTextSafely(targetPath));

        if (launchMode is RunnerLaunchMode.CmdConsoleVisible or RunnerLaunchMode.CmdConsoleElevated)
        {
            Process.Start(BuildStartInfo(launchMode, targetPath));
            return null;
        }

        var artifacts = BuildArtifactPaths(_repoRoot, command.Name, BuildStamp(DateTime.Now));
        Directory.CreateDirectory(Path.GetDirectoryName(artifacts.LogFile)!);

        WriteParamsFile(artifacts.ParamsFile, parameters);
        File.WriteAllText(
            artifacts.RunnerPath,
            BuildRunnerTemplate(_repoRoot, artifacts.LogFile, artifacts.DoneFile, artifacts.ParamsFile, command.Name, dryRun),
            Utf8WithBom);

        Process.Start(BuildStartInfo(launchMode, artifacts.RunnerPath));
        return artifacts;
    }

    // Get-Content -Raw -ErrorAction SilentlyContinue (line 329): unreadable file -> null text.
    private static string? ReadBatchTextSafely(string targetPath)
    {
        try
        {
            return File.Exists(targetPath) ? File.ReadAllText(targetPath) : null;
        }
        catch (IOException)
        {
            return null;
        }
    }

    // Containment (CWE-22): a registry command may only launch inside the repo root, so a
    // tampered registry entry cannot point the runner at an arbitrary executable.
    private void RequireInsideRepoRoot(string targetPath)
    {
        var fullTarget = Path.GetFullPath(targetPath);
        var fullRoot = Path.GetFullPath(_repoRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                       + Path.DirectorySeparatorChar;
        if (!fullTarget.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException($"Command target escapes the hub root: {targetPath}", nameof(targetPath));
        }
    }
}
