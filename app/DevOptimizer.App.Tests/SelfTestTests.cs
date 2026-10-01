using System.IO;
using System.Text.RegularExpressions;
using DevOptimizer.App;
using DevOptimizer.App.Services;
using DevOptimizer.App.ViewModels;
using Xunit;

namespace DevOptimizer.App.Tests;

public class SelfTestTests
{
    // The assertion engine runs against the Task 2 fixture copied into a temp repo root;
    // the live registry is only touched by the exe selftest run (Task 6 Step 1).

    private static string FixturePath => Path.Combine(AppContext.BaseDirectory, "Fixtures", "registry-sample.json");

    private static string CreateTempRoot()
    {
        var root = Path.Combine(Path.GetTempPath(), "doapp-selftesttests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(root, "config"));
        File.Copy(FixturePath, Path.Combine(root, "config", "hub-registry.json"));
        return root;
    }

    private static async Task<MainViewModel> CreateLoadedViewModelAsync(string root)
    {
        var vm = new MainViewModel(root, new RegistryService(), new SettingsService(), new CommandRunnerService(root));
        await vm.LoadAsync();
        return vm;
    }

    private static string ReadLog(string root) => File.ReadAllText(Path.Combine(root, "logs", "app-runs", "app-debug.log"));

    private static void Cleanup(string root)
    {
        try { Directory.Delete(root, recursive: true); } catch (IOException) { }
    }

    // ------------------------------------------------------------------
    // LogService — Log-D line format (DevOptimizer-App.ps1:78)
    // ------------------------------------------------------------------

    [Fact]
    public void LogService_Append_WritesTimestampedLine_AndCreatesDirectory()
    {
        var root = CreateTempRoot();
        try
        {
            LogService.Append(root, "checkpoint: unit-test");

            var lines = ReadLog(root)
                .Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var line = Assert.Single(lines);
            Assert.Matches(@"^\d{2}:\d{2}:\d{2}\.\d{3} checkpoint: unit-test$", line);
        }
        finally { Cleanup(root); }
    }

    // ------------------------------------------------------------------
    // Assertion engine against the fixture registry
    // ------------------------------------------------------------------

    [Fact]
    public async Task SelfTestRunner_RunChecks_AllPassOnFixture()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            var checks = SelfTestRunner.RunChecks(vm, root, searchQuery: "cleanup", detailPanelChildCount: 8);

            Assert.Equal(5, checks.Count); // sidebar, category filter, search, exclusion regression, detail structure
            Assert.All(checks, c => Assert.True(c.Passed, $"{c.Name}: {c.Detail}"));
            // Fixture lock: the probed category (index 3 = maintenance, 1 command) yields
            // 0 semantic matches — shown 0, NOT the whole category.
            Assert.Contains(checks, c => c.Name.Contains("excludes category") && c.Passed && c.Detail.Contains("category has 1"));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task SelfTestRunner_PositiveControl_FailsWhenSearchMatchesNothing()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            var checks = SelfTestRunner.RunChecks(vm, root, searchQuery: "zzz-no-such-token", detailPanelChildCount: 8);

            var searchCheck = Assert.Single(checks, c => c.Name.StartsWith("all + search", StringComparison.Ordinal));
            Assert.False(searchCheck.Passed); // expected 0 matches -> positive control fails
            Assert.Contains(checks, c => !c.Passed);
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task SelfTestRunner_DetailPanelStructure_FailsWithoutChildren()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            var checks = SelfTestRunner.RunChecks(vm, root, searchQuery: "cleanup", detailPanelChildCount: 0);

            var detailCheck = Assert.Single(checks, c => c.Name == "detail panel children");
            Assert.False(detailCheck.Passed);
        }
        finally { Cleanup(root); }
    }

    // ------------------------------------------------------------------
    // Verdict logging — selftest: lines + SELFTEST PASS / SELFTEST FAIL
    // ------------------------------------------------------------------

    [Fact]
    public async Task SelfTestRunner_LogResults_WritesVerdictLines()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            var passing = SelfTestRunner.LogResults(root, SelfTestRunner.RunChecks(vm, root, "cleanup", 8));
            Assert.True(passing);
            Assert.Contains("SELFTEST PASS", ReadLog(root));

            var failing = SelfTestRunner.LogResults(root, new[]
            {
                new SelfTestCheck("forced failure", false, "expected 1, shown 2"),
            });
            Assert.False(failing);

            var log = ReadLog(root);
            Assert.Contains("SELFTEST FAIL", log);
            Assert.Matches(@"^\d{2}:\d{2}:\d{2}\.\d{3} selftest: .+$", ExtractLineContaining(log, "selftest:"));
        }
        finally { Cleanup(root); }
    }

    private static string ExtractLineContaining(string text, string token)
    {
        var line = text.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries)
            .First(l => l.Contains(token));
        return line.TrimEnd('\r');
    }

    // ------------------------------------------------------------------
    // Source-level regression: the selftest verdict must reach the exit code.
    // window.Close() under OnLastWindowClose starts app shutdown with the default
    // exit code, so the selftest host must switch to OnExplicitShutdown before the
    // window is shown and terminate via Shutdown(exitCode).
    // ------------------------------------------------------------------

    [Fact]
    public void AppSource_SelfTestHost_ShutsDownExplicitly()
    {
        var repoRoot = App.FindRepoRoot(AppContext.BaseDirectory);
        Assert.False(string.IsNullOrEmpty(repoRoot), $"repo root not found walking up from {AppContext.BaseDirectory}");

        var source = File.ReadAllText(Path.Combine(repoRoot!, "app", "DevOptimizer.App", "App.xaml.cs"));
        Assert.Contains("Shutdown(exitCode);", source);

        var selfTestStart = source.IndexOf("private async void StartSelfTest", StringComparison.Ordinal);
        Assert.True(selfTestStart >= 0, "StartSelfTest not found");
        var modeIndex = source.IndexOf("ShutdownMode = ShutdownMode.OnExplicitShutdown;", selfTestStart, StringComparison.Ordinal);
        var showIndex = source.IndexOf("window.Show();", selfTestStart, StringComparison.Ordinal);
        Assert.True(modeIndex >= selfTestStart, "selftest host must set ShutdownMode.OnExplicitShutdown");
        Assert.True(showIndex > modeIndex, "ShutdownMode.OnExplicitShutdown must be set before the window is shown");
    }

    // ------------------------------------------------------------------
    // Headless arg parsing — RunNow implies no window (no separate flag exists)
    // ------------------------------------------------------------------

    [Fact]
    public void ParseArgs_HeadlessFlags()
    {
        var runNow = App.ParseArgs(new[] { "-Command", "win11-health-snapshot", "-RunNow" });
        Assert.Equal("win11-health-snapshot", runNow.Command);
        Assert.True(runNow.RunNow); // no window in this mode; there is no dedicated "no window" flag
        Assert.False(runNow.SelfTest);

        Assert.True(App.ParseArgs(new[] { "--selftest" }).SelfTest);
        Assert.True(App.ParseArgs(new[] { "-Settings" }).Settings);
        Assert.False(App.ParseArgs(new string[0]).RunNow);
    }

    // ------------------------------------------------------------------
    // Deep links — PS protocol semantics (DevOptimizer-App.ps1:935-975)
    // ------------------------------------------------------------------

    [Fact]
    public async Task ApplyDeepLinks_Command_PreselectsRow_AndLogs()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            App.ApplyDeepLinks(vm, App.ParseArgs(new[] { "-Command", "disk-status" }), root);

            Assert.Equal("disk-status", vm.SelectedCommand?.Name);
            Assert.Equal("All", vm.SelectedCategory?.Name); // command branch resets category + search
            Assert.Contains("deeplink: command 'disk-status'", ReadLog(root));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task ApplyDeepLinks_UnknownCommand_Ignored_AndLogged()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            App.ApplyDeepLinks(vm, App.ParseArgs(new[] { "-Command", "no-such-command" }), root);

            Assert.Null(vm.SelectedCommand);
            Assert.Contains("deeplink: command 'no-such-command' not found in registry - ignored", ReadLog(root));
            Assert.Contains("unknown command", vm.StatusText);
            Assert.DoesNotContain("rejected unsafe", ReadLog(root)); // absent -Category stays silent
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task ApplyDeepLinks_Category_Filters_AndLogs()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            App.ApplyDeepLinks(vm, App.ParseArgs(new[] { "-Category", "cleanup" }), root);

            Assert.Equal("cleanup", vm.SelectedCategory?.Name);
            Assert.Equal(3, vm.FilteredCount);
            Assert.Contains("deeplink: category 'cleanup'", ReadLog(root));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task ApplyDeepLinks_UnknownCategory_Ignored_AndLogged()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            App.ApplyDeepLinks(vm, App.ParseArgs(new[] { "-Category", "no-such-category" }), root);

            Assert.Equal("All", vm.SelectedCategory?.Name);
            Assert.Contains("deeplink: category 'no-such-category' not found in registry - ignored", ReadLog(root));
            Assert.Contains("unknown category", vm.StatusText);
            Assert.DoesNotContain("rejected unsafe", ReadLog(root)); // absent -Command stays silent
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task ApplyDeepLinks_UnsafeValues_Rejected_AndLogged()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            App.ApplyDeepLinks(vm, App.ParseArgs(new[] { "-Command", "bad\r\nname", "-Category", "bad\0cat" }), root);

            var log = ReadLog(root);
            Assert.Contains("deeplink: rejected unsafe command value", log);
            Assert.Contains("deeplink: rejected unsafe category value", log);
            Assert.Null(vm.SelectedCommand);
            Assert.Equal("All", vm.SelectedCategory?.Name);
            Assert.False(App.IsSafeDeeplinkValue("bad\r\nname"));
            Assert.True(App.IsSafeDeeplinkValue("clean-value"));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task ApplyDeepLinks_AbsentArgs_Silent_NoRejectionNoise()
    {
        // PS parity: the rejection line is only for PRESENT-but-unsafe values; a launch
        // without -Command/-Category must not log any rejection noise.
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            App.ApplyDeepLinks(vm, App.ParseArgs(new[] { "-Category", "cleanup" }), root);

            var log = ReadLog(root);
            Assert.Contains("deeplink: category 'cleanup'", log);
            Assert.DoesNotContain("rejected unsafe command value", log);
            Assert.DoesNotContain("rejected unsafe category value", log);
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task ApplyDeepLinks_Settings_Requested_AndLogged()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            App.ApplyDeepLinks(vm, App.ParseArgs(new[] { "-Settings" }), root);

            Assert.Contains("deeplink: settings view requested", ReadLog(root));
            Assert.Contains("Settings", vm.StatusText);
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task ApplyDeepLinks_CategoryTakesPriorityOverCommand()
    {
        var root = CreateTempRoot();
        try
        {
            var vm = await CreateLoadedViewModelAsync(root);

            App.ApplyDeepLinks(vm, App.ParseArgs(new[] { "-Command", "disk-status", "-Category", "cleanup" }), root);

            // PS priority: Settings > Category > Command.
            Assert.Equal("cleanup", vm.SelectedCategory?.Name);
            Assert.Null(vm.SelectedCommand);
            Assert.DoesNotContain("deeplink: command", ReadLog(root));
        }
        finally { Cleanup(root); }
    }
}
