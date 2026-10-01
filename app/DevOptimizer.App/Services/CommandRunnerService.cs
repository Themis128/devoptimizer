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

    private static readonly UTF8Encoding Utf8WithBom = new(encoderShouldEmitUTF8Identifier: true);

    private static readonly JsonSerializerOptions IndentedJson = new() { WriteIndented = true };

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
        // Defense-in-depth (CWE-78): the runas modes must keep shell-execution, so the
        // path can never be allowed to break out of its quoted argument.
        if (path.Contains('"') || path.Contains('\n') || path.Contains('\r'))
        {
            throw new ArgumentException("Launch path contains command-line quoting characters.", nameof(path));
        }

        var psi = new ProcessStartInfo
        {
            UseShellExecute = true, // Start-Process defaults to ShellExecute; required for Verb/WindowStyle
        };

        switch (mode)
        {
            case RunnerLaunchMode.PowerShellHidden:
                psi.FileName = "powershell.exe";
                psi.Arguments = $"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{path}\"";
                psi.WindowStyle = ProcessWindowStyle.Hidden;
                break;

            case RunnerLaunchMode.PowerShellElevated:
                psi.FileName = "powershell.exe";
                psi.Arguments = $"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{path}\"";
                psi.Verb = "runas"; // DevOptimizer-App.ps1:401
                break;

            case RunnerLaunchMode.CmdConsoleVisible:
                psi.FileName = "cmd.exe";
                psi.Arguments = $"/k \"{path}\"";
                psi.WorkingDirectory = Path.GetDirectoryName(path) ?? string.Empty; // DevOptimizer-App.ps1:331
                break;

            case RunnerLaunchMode.CmdConsoleElevated:
                psi.FileName = "cmd.exe";
                psi.Arguments = $"/k \"{path}\"";
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
}
