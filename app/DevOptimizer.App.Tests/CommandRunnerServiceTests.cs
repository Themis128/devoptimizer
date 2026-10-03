using System.IO;
using System.Diagnostics;
using System.Text.Json;
using DevOptimizer.App.Services;
using Xunit;

namespace DevOptimizer.App.Tests;

public class CommandRunnerServiceTests
{
    // Pure-function tests only: naming, runner template, interactive-batch detection,
    // launch-mode routing, ProcessStartInfo building, params-file writing.
    // No process is ever spawned by these tests (Start() is deliberately not called).

    private const string InteractiveBatText = """
        @echo off
        REM installs portable tool with prompts
        set /p CONTINUE=Continue? [Y/N]
        if /i "%CONTINUE%"=="Y" goto main
        echo aborted
        exit /b 1
        :main
        echo installing
        """;

    private const string CleanBatText = """
        @echo off
        echo Running maintenance pass...
        del /q "%TEMP%\stale.tmp"
        exit /b 0
        """;

    // ------------------------------------------------------------------
    // Artifact naming — identical to Start-HubRun (DevOptimizer-App.ps1:336-341)
    // ------------------------------------------------------------------

    [Fact]
    public void BuildArtifactPaths_UsesExactStartHubRunNaming()
    {
        var artifacts = CommandRunnerService.BuildArtifactPaths(@"D:\repo", "win11-health-snapshot", "20260928-141530");

        Assert.Equal("run-win11-health-snapshot-20260928-141530", artifacts.RunId);
        Assert.Equal(@"D:\repo\logs\app-runs\run-win11-health-snapshot-20260928-141530.log.txt", artifacts.LogFile);
        Assert.Equal(@"D:\repo\logs\app-runs\run-win11-health-snapshot-20260928-141530.done.txt", artifacts.DoneFile);
        Assert.Equal(@"D:\repo\logs\app-runs\run-win11-health-snapshot-20260928-141530.params.json", artifacts.ParamsFile);
        Assert.Equal(@"D:\repo\logs\app-runs\run-win11-health-snapshot-20260928-141530.runner.ps1", artifacts.RunnerPath);
    }

    [Fact]
    public void BuildStamp_FormatsyyyyMMdd_HHmmss()
    {
        Assert.Equal("20260928-141530", CommandRunnerService.BuildStamp(new DateTime(2026, 9, 28, 14, 15, 30)));
        Assert.Equal("20260101-005909", CommandRunnerService.BuildStamp(new DateTime(2026, 1, 1, 0, 59, 9)));
    }

    // ------------------------------------------------------------------
    // Runner template — verbatim semantics of the here-string (DevOptimizer-App.ps1:351-392)
    // ------------------------------------------------------------------

    [Fact]
    public void BuildRunnerTemplate_ContainsEngineContract()
    {
        var runner = CommandRunnerService.BuildRunnerTemplate(
            @"D:\repo", @"D:\repo\logs\app-runs\run-x.log.txt", @"D:\repo\logs\app-runs\run-x.done.txt",
            @"D:\repo\logs\app-runs\run-x.params.json", "win11-health-snapshot", dryRun: false);

        // The engine boundary: the runner invokes Execute-Command.ps1 by literal name.
        Assert.Contains("Execute-Command.ps1", runner);
        Assert.Contains(@"& (Join-Path 'D:\repo' 'Execute-Command.ps1') -Command 'win11-health-snapshot' -Parameters $params *>&1", runner);
        // Repo root becomes the working directory (DevOptimizer-App.ps1:352).
        Assert.Contains(@"Set-Location -LiteralPath 'D:\repo'", runner);
        // Params JSON is read into a hashtable (lines 356-357).
        Assert.Contains(@"$raw = Get-Content -Raw -LiteralPath 'D:\repo\logs\app-runs\run-x.params.json'", runner);
        Assert.Contains("($raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $params[$_.Name] = $_.Value }", runner);
        // Done-file protocol line (line 387) — writes through the $doneFile variable set at line 354.
        Assert.Contains(@"""exitOk=$ok code=$lastCode"" | Out-File -LiteralPath $doneFile -Encoding ASCII", runner);
        Assert.Contains(@"$doneFile = 'D:\repo\logs\app-runs\run-x.done.txt'", runner);
    }

    [Fact]
    public void BuildRunnerTemplate_AllPlaceholdersReplaced()
    {
        var runner = CommandRunnerService.BuildRunnerTemplate(@"D:\r", "o", "d", "p", "n", dryRun: false);

        Assert.DoesNotContain("__ROOT__", runner);
        Assert.DoesNotContain("__OUT__", runner);
        Assert.DoesNotContain("__DONE__", runner);
        Assert.DoesNotContain("__PARAMS__", runner);
        Assert.DoesNotContain("__NAME__", runner);
        Assert.DoesNotContain("__DRY__", runner);
    }

    [Fact]
    public void BuildRunnerTemplate_DryRunSplice_MatchesStartHubRun()
    {
        var dry = CommandRunnerService.BuildRunnerTemplate(@"D:\r", "o", "d", "p", "n", dryRun: true);
        var wet = CommandRunnerService.BuildRunnerTemplate(@"D:\r", "o", "d", "p", "n", dryRun: false);

        Assert.Contains("-Parameters $params -DryRun *>&1", dry);
        Assert.Contains("-Parameters $params *>&1", wet);
        Assert.DoesNotContain("-DryRun", wet);
    }

    // ------------------------------------------------------------------
    // Interactive-batch detection — exact Start-HubRun regexes (DevOptimizer-App.ps1:330)
    // ------------------------------------------------------------------

    [Fact]
    public void IsInteractiveBatch_DetectsInteractiveFixtures()
    {
        Assert.True(CommandRunnerService.IsInteractiveBatch(InteractiveBatText)); // set /p
        Assert.True(CommandRunnerService.IsInteractiveBatch("@echo off\r\nchoice /c YN\r\n")); // choice
        Assert.True(CommandRunnerService.IsInteractiveBatch("@echo off\r\npause\r\n")); // pause
    }

    [Fact]
    public void IsInteractiveBatch_CleanFixture_ReturnsFalse()
    {
        Assert.False(CommandRunnerService.IsInteractiveBatch(CleanBatText));
    }

    [Fact]
    public void IsInteractiveBatch_LineAnchored_Signatures()
    {
        // (?im) anchoring: tokens only count at line start (after optional whitespace)...
        Assert.False(CommandRunnerService.IsInteractiveBatch("@echo off\r\necho set /p VALUE=not a prompt\r\n"));
        Assert.True(CommandRunnerService.IsInteractiveBatch("  set /p VALUE=prompt\r\n")); // leading whitespace ok
        // ...with word boundaries: "set /path" is NOT "set /p", "unpaused" is NOT "pause".
        Assert.False(CommandRunnerService.IsInteractiveBatch("@echo off\r\nset /path %TEMP%\r\n"));
        Assert.False(CommandRunnerService.IsInteractiveBatch("@echo off\r\necho unpaused now\r\n"));
        // Case-insensitive.
        Assert.True(CommandRunnerService.IsInteractiveBatch("@echo off\r\nSET /P X=y\r\n"));
    }

    [Fact]
    public void IsInteractiveBatch_NullOrEmpty_ReturnsFalse()
    {
        // Mirrors Get-Content -ErrorAction SilentlyContinue producing $null for a missing file.
        Assert.False(CommandRunnerService.IsInteractiveBatch(null));
        Assert.False(CommandRunnerService.IsInteractiveBatch(string.Empty));
    }

    // ------------------------------------------------------------------
    // Launch routing — Start-HubRun control flow (DevOptimizer-App.ps1:328-344, 397-403)
    // ------------------------------------------------------------------

    [Fact]
    public void DecideLaunchMode_RoutesExactlyLikeStartHubRun()
    {
        // Interactive cmd bat: visible console, elevated via runas.
        Assert.Equal(RunnerLaunchMode.CmdConsoleVisible,
            CommandRunnerService.DecideLaunchMode("cmd", elevated: false, dryRun: false, batText: InteractiveBatText));
        Assert.Equal(RunnerLaunchMode.CmdConsoleElevated,
            CommandRunnerService.DecideLaunchMode("cmd", elevated: true, dryRun: false, batText: InteractiveBatText));

        // Dry run exempts the cmd console route (line 328: only when NOT dry-run).
        Assert.Equal(RunnerLaunchMode.PowerShellHidden,
            CommandRunnerService.DecideLaunchMode("cmd", elevated: false, dryRun: true, batText: InteractiveBatText));
        Assert.Equal(RunnerLaunchMode.PowerShellElevated,
            CommandRunnerService.DecideLaunchMode("cmd", elevated: true, dryRun: true, batText: InteractiveBatText));

        // PowerShell entry points are NEVER routed to cmd, even when interactive-looking.
        Assert.Equal(RunnerLaunchMode.PowerShellHidden,
            CommandRunnerService.DecideLaunchMode("powershell", elevated: false, dryRun: false, batText: InteractiveBatText));
        Assert.Equal(RunnerLaunchMode.PowerShellElevated,
            CommandRunnerService.DecideLaunchMode("powershell", elevated: true, dryRun: false, batText: InteractiveBatText));

        // Non-interactive / missing bat text falls through to the hidden runner.
        Assert.Equal(RunnerLaunchMode.PowerShellHidden,
            CommandRunnerService.DecideLaunchMode("cmd", elevated: false, dryRun: false, batText: CleanBatText));
        Assert.Equal(RunnerLaunchMode.PowerShellHidden,
            CommandRunnerService.DecideLaunchMode("cmd", elevated: false, dryRun: false, batText: null));
    }

    // ------------------------------------------------------------------
    // ProcessStartInfo — Start-Process call sites (DevOptimizer-App.ps1:330-331, 399-403)
    // ------------------------------------------------------------------

    [Fact]
    public void BuildStartInfo_PowerShellHidden_PlainHiddenSpawn()
    {
        var psi = CommandRunnerService.BuildStartInfo(RunnerLaunchMode.PowerShellHidden, @"D:\repo\logs\app-runs\run-x.runner.ps1");

        // Interpreters are absolute system paths — never resolved via PATH.
        Assert.Equal(CommandRunnerService.PowerShellPath, psi.FileName);
        Assert.True(Path.IsPathRooted(psi.FileName));
        Assert.Equal("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"D:\\repo\\logs\\app-runs\\run-x.runner.ps1\"", psi.Arguments);
        Assert.True(psi.UseShellExecute);
        Assert.Equal(string.Empty, psi.Verb);
        Assert.Equal(ProcessWindowStyle.Hidden, psi.WindowStyle);
    }

    [Fact]
    public void BuildStartInfo_PowerShellElevated_RunAsShellExecute()
    {
        // DevOptimizer-App.ps1:400-402 — elevated runner launches via ShellExecute runas.
        var psi = CommandRunnerService.BuildStartInfo(RunnerLaunchMode.PowerShellElevated, @"D:\repo\logs\app-runs\run-x.runner.ps1");

        Assert.Equal(CommandRunnerService.PowerShellPath, psi.FileName);
        Assert.Equal("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"D:\\repo\\logs\\app-runs\\run-x.runner.ps1\"", psi.Arguments);
        Assert.Equal("runas", psi.Verb);
        Assert.True(psi.UseShellExecute);
        Assert.Equal(ProcessWindowStyle.Normal, psi.WindowStyle); // hiding comes from -WindowStyle in the args
    }

    [Fact]
    public void BuildStartInfo_CmdConsoleVisible_WithBatWorkingDirectory()
    {
        // DevOptimizer-App.ps1:331 — visible cmd.exe /k, working directory = bat's parent.
        var psi = CommandRunnerService.BuildStartInfo(RunnerLaunchMode.CmdConsoleVisible, @"D:\repo\portable\tool.bat");

        Assert.Equal(CommandRunnerService.CmdPath, psi.FileName);
        Assert.True(Path.IsPathRooted(psi.FileName));
        Assert.Equal("/k \"D:\\repo\\portable\\tool.bat\"", psi.Arguments);
        Assert.Equal(@"D:\repo\portable", psi.WorkingDirectory);
        Assert.Equal(string.Empty, psi.Verb);
        Assert.True(psi.UseShellExecute);
        Assert.Equal(ProcessWindowStyle.Normal, psi.WindowStyle);
    }

    [Fact]
    public void BuildStartInfo_CmdConsoleElevated_RunAs()
    {
        // DevOptimizer-App.ps1:330 — elevated interactive bat: cmd.exe /k via runas.
        var psi = CommandRunnerService.BuildStartInfo(RunnerLaunchMode.CmdConsoleElevated, @"D:\repo\portable\tool.bat");

        Assert.Equal(CommandRunnerService.CmdPath, psi.FileName);
        Assert.Equal("/k \"D:\\repo\\portable\\tool.bat\"", psi.Arguments);
        Assert.Equal("runas", psi.Verb);
        Assert.True(psi.UseShellExecute);
        Assert.Equal(ProcessWindowStyle.Normal, psi.WindowStyle);
    }

    [Fact]
    public void BuildStartInfo_MetacharacterPath_Throws()
    {
        // The /k and -File argument strings are raw command lines — shell metacharacters
        // in the launch path must be rejected before a process can be spawned.
        foreach (var bad in new[] { @"D:\repo\tool&calc.bat", @"D:\rep|o\tool.bat", @"D:\repo\to>ol.bat", @"D:\repo\%PATH%\tool.bat" })
        {
            Assert.ThrowsAny<ArgumentException>(() =>
                CommandRunnerService.BuildStartInfo(RunnerLaunchMode.CmdConsoleVisible, bad));
            Assert.ThrowsAny<ArgumentException>(() =>
                CommandRunnerService.BuildStartInfo(RunnerLaunchMode.PowerShellHidden, bad));
        }
    }

    [Fact]
    public void BuildStartInfo_QuoteAndNewlinePath_StillThrows()
    {
        Assert.ThrowsAny<ArgumentException>(() =>
            CommandRunnerService.BuildStartInfo(RunnerLaunchMode.CmdConsoleVisible, @"D:\repo\to""ol.bat"));
        Assert.ThrowsAny<ArgumentException>(() =>
            CommandRunnerService.BuildStartInfo(RunnerLaunchMode.PowerShellHidden, "D:\\repo\\to\nol.bat"));
    }

    // ------------------------------------------------------------------
    // Params file — ConvertTo-Json counterpart (DevOptimizer-App.ps1:348); temp dir only
    // ------------------------------------------------------------------

    [Fact]
    public void WriteParamsFile_NoParameters_WritesEmptyObject_WithUtf8Bom()
    {
        var path = Path.Combine(Path.GetTempPath(), "doapp-runnertests-" + Guid.NewGuid().ToString("N"), "run-x.params.json");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!); // Start() stages the dir; WriteParamsFile itself does not
        try
        {
            CommandRunnerService.WriteParamsFile(path, null);

            Assert.True(File.Exists(path));
            var bytes = File.ReadAllBytes(path);
            Assert.Equal(new byte[] { 0xEF, 0xBB, 0xBF }, bytes[..3]); // Set-Content -Encoding UTF8 parity (line 348)

            using var doc = JsonDocument.Parse(bytes[3..]);
            Assert.Equal(JsonValueKind.Object, doc.RootElement.ValueKind);
            Assert.Empty(doc.RootElement.EnumerateObject());
        }
        finally
        {
            try { Directory.Delete(Path.GetDirectoryName(path)!, recursive: true); } catch (IOException) { }
        }
    }

    [Fact]
    public void WriteParamsFile_WithParameters_WritesReadableJson()
    {
        var path = Path.Combine(Path.GetTempPath(), "doapp-runnertests-" + Guid.NewGuid().ToString("N"), "run-x.params.json");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        try
        {
            CommandRunnerService.WriteParamsFile(path, new Dictionary<string, object?>
            {
                ["TargetDir"] = @"C:\Temp\Clean Me",
                ["QuickClean"] = true,
                ["RetentionDays"] = 7,
            });

            using var doc = JsonDocument.Parse(File.ReadAllBytes(path)[3..]);
            Assert.Equal(@"C:\Temp\Clean Me", doc.RootElement.GetProperty("TargetDir").GetString());
            Assert.True(doc.RootElement.GetProperty("QuickClean").GetBoolean());
            Assert.Equal(7, doc.RootElement.GetProperty("RetentionDays").GetInt32());
        }
        finally
        {
            try { Directory.Delete(Path.GetDirectoryName(path)!, recursive: true); } catch (IOException) { }
        }
    }

    [Fact]
    public void GetTargetPath_ReplacesSlashesAndJoinsRoot()
    {
        // DevOptimizer-App.ps1:328 — Join-Path $script:RootPath ($cmd.path -replace '/', '\')
        Assert.Equal(@"D:\repo\scripts\admin-cleanup-elevated.ps1",
            CommandRunnerService.GetTargetPath(@"D:\repo", "scripts/admin-cleanup-elevated.ps1"));
    }
}
