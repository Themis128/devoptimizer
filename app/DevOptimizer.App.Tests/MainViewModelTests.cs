using System.Diagnostics;
using System.IO;
using DevOptimizer.App.Models;
using DevOptimizer.App.Services;
using DevOptimizer.App.ViewModels;
using Xunit;

namespace DevOptimizer.App.Tests;

public class MainViewModelTests
{
    // Filter/count tests run against the Task 2 fixture (8 commands: cleanup 3,
    // utilities 2, maintenance 1, network 1, monitoring 1) copied into a temp repo
    // root; the live registry is never touched and no process is ever spawned.

    private static readonly string[] FixtureNamesSorted =
    {
        "admin-cleanup-elevated", "cleanup-temp-files", "cleanup-tools-launcher", "disk-status",
        "junk-sweeper", "monitor-cpu", "net-reset", "safe-purge",
    };

    private static readonly string[] CleanupSearchNames =
    {
        "admin-cleanup-elevated", "cleanup-temp-files", "cleanup-tools-launcher", "disk-status", "safe-purge",
    };

    private static string FixturePath => Path.Combine(AppContext.BaseDirectory, "Fixtures", "registry-sample.json");

    private static string CreateTempRoot(string? settingsJson)
    {
        var root = Path.Combine(Path.GetTempPath(), "doapp-vmtests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(root, "config"));
        File.Copy(FixturePath, Path.Combine(root, "config", "hub-registry.json"));
        if (settingsJson is not null)
        {
            File.WriteAllText(Path.Combine(root, "config", "app-settings.json"), settingsJson);
        }

        return root;
    }

    private static MainViewModel CreateViewModel(string root) =>
        new(root, new RegistryService(), new SettingsService(), new CommandRunnerService(root));

    private sealed record LaunchCall(CommandDefinition Command, IReadOnlyDictionary<string, string> Parameters, bool Elevated, bool DryRun);

    private static void Cleanup(string root)
    {
        try { Directory.Delete(root, recursive: true); } catch (IOException) { }
    }

    // ------------------------------------------------------------------
    // Sidebar categories + initial list
    // ------------------------------------------------------------------

    [Fact]
    public async Task LoadAsync_PopulatesCategories_AllFirst_ThenCountDescending()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            await vm.LoadAsync();

            Assert.Equal(
                new[]
                {
                    ("All", 8), ("cleanup", 3), ("utilities", 2),
                    ("maintenance", 1), ("monitoring", 1), ("network", 1),
                },
                vm.Categories.Select(c => (c.Name, c.Count)));
            Assert.Equal(8, vm.TotalCommandCount);
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task LoadAsync_ShowsAllCommandsSortedByName()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            await vm.LoadAsync();

            Assert.Equal(FixtureNamesSorted, vm.FilteredCommands.Select(c => c.Name));
            Assert.Equal(8, vm.FilteredCount);
            Assert.True(vm.RunCommand.CanExecute(null) == false); // nothing selected yet
        }
        finally { Cleanup(root); }
    }

    // ------------------------------------------------------------------
    // Live search — Task 2 semantics (category excluded)
    // ------------------------------------------------------------------

    [Fact]
    public async Task SearchText_LiveFilter_ExcludesCategory()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            await vm.LoadAsync();

            vm.SearchText = "cleanup";

            Assert.Equal(CleanupSearchNames.Length, vm.FilteredCount);
            Assert.Equal(CleanupSearchNames, vm.FilteredCommands.Select(c => c.Name));
            // Regression trap: junk-sweeper (category "cleanup") is NOT matched; disk-status
            // (description contains "cleanup") IS matched.
            Assert.DoesNotContain(vm.FilteredCommands, c => c.Name == "junk-sweeper");
            Assert.Contains(vm.FilteredCommands, c => c.Name == "disk-status");

            vm.SearchText = "";
            Assert.Equal(8, vm.FilteredCount);

            vm.SearchText = "CLEANUP";
            Assert.Equal(CleanupSearchNames, vm.FilteredCommands.Select(c => c.Name));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task SelectedCategory_Filters_AndCombinesWithSearch()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            await vm.LoadAsync();

            vm.SelectedCategory = vm.Categories.First(c => c.Name == "cleanup");
            Assert.Equal(3, vm.FilteredCount);

            vm.SearchText = "cleanup";
            Assert.Equal(new[] { "admin-cleanup-elevated", "cleanup-temp-files" },
                vm.FilteredCommands.Select(c => c.Name));

            vm.SelectedCategory = vm.Categories.First(c => c.Name == "All");
            Assert.Equal(CleanupSearchNames, vm.FilteredCommands.Select(c => c.Name));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task SelectedCommand_ClearedWhenFilteredOut()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            await vm.LoadAsync();

            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "disk-status");
            Assert.NotNull(vm.SelectedCommand);

            vm.SearchText = "zzz-no-match";
            Assert.Empty(vm.FilteredCommands);
            Assert.Null(vm.SelectedCommand);
            Assert.Empty(vm.ParameterInputs);
        }
        finally { Cleanup(root); }
    }

    // ------------------------------------------------------------------
    // Detail panel + parameter grid + run gating
    // ------------------------------------------------------------------

    [Fact]
    public async Task SelectedCommand_PopulatesParameterGrid_AndGatesRunOnRequired()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            await vm.LoadAsync();

            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "cleanup-temp-files");

            var row = Assert.Single(vm.ParameterInputs);
            Assert.Equal("TargetDir", row.Name);
            Assert.Equal("string", row.Type);
            Assert.True(row.Required);
            Assert.Equal("Directory to clean", row.Description);
            Assert.True(vm.HasParameters);
            Assert.False(vm.RunCommand.CanExecute(null)); // required parameter empty

            row.Value = @"C:\Temp";
            Assert.True(vm.RunCommand.CanExecute(null));
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task ShowElevatedButton_TrueOnlyForAdminCommands()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            await vm.LoadAsync();

            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "admin-cleanup-elevated");
            Assert.True(vm.ShowElevatedButton);
            Assert.True(vm.RunElevatedCommand.CanExecute(null)); // no required params

            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "disk-status");
            Assert.False(vm.ShowElevatedButton);
            Assert.False(vm.RunElevatedCommand.CanExecute(null));
        }
        finally { Cleanup(root); }
    }

    // ------------------------------------------------------------------
    // Run / Elevated launch flow (recorded via LaunchOverride — no process spawned)
    // ------------------------------------------------------------------

    [Fact]
    public async Task Run_LaunchesWithCollectedParameters_AndPrintsExitLine()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            var calls = new List<LaunchCall>();
            var artifacts = CommandRunnerService.BuildArtifactPaths(root, "cleanup-temp-files", "20260928-120000");
            vm.LaunchOverride = (command, parameters, elevated, dryRun) =>
            {
                calls.Add(new LaunchCall(command, parameters, elevated, dryRun));
                Directory.CreateDirectory(Path.GetDirectoryName(artifacts.DoneFile)!);
                File.WriteAllText(artifacts.DoneFile, "exitOk=True code=0"); // done-file already present: poll drains synchronously
                return artifacts;
            };

            await vm.LoadAsync();
            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "cleanup-temp-files");
            vm.ParameterInputs.Single().Value = @"C:\Temp";

            vm.RunCommand.Execute(null);

            var call = Assert.Single(calls);
            Assert.Equal("cleanup-temp-files", call.Command.Name);
            Assert.Equal(@"scripts/cleanup-temp-files.ps1", call.Command.Path); // registry-sourced definition
            Assert.Equal(new Dictionary<string, string> { ["TargetDir"] = @"C:\Temp" }, call.Parameters);
            Assert.False(call.Elevated);
            Assert.False(call.DryRun);
            Assert.Contains("Launched 'cleanup-temp-files'", vm.OutputText);
            Assert.Contains("exitOk=True code=0", vm.OutputText); // exit line from the done file
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task Run_InteractiveCmd_PrintsConsoleMessage_NoArtifactsConsumed()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            var calls = new List<LaunchCall>();
            vm.LaunchOverride = (command, parameters, elevated, dryRun) =>
            {
                calls.Add(new LaunchCall(command, parameters, elevated, dryRun));
                return null; // interactive console path: no per-run artifacts
            };

            await vm.LoadAsync();
            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "cleanup-tools-launcher"); // entryPoint cmd

            vm.RunCommand.Execute(null);

            Assert.Single(calls);
            Assert.Contains("interactive tool", vm.OutputText);
            Assert.Contains("separate console window", vm.OutputText);
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task RunElevated_PassesElevated_ForAdminCommand()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            var calls = new List<LaunchCall>();
            vm.LaunchOverride = (command, parameters, elevated, dryRun) =>
            {
                calls.Add(new LaunchCall(command, parameters, elevated, dryRun));
                return null;
            };

            await vm.LoadAsync();
            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "admin-cleanup-elevated");

            vm.RunElevatedCommand.Execute(null);

            var call = Assert.Single(calls);
            Assert.True(call.Elevated);
            Assert.Empty(call.Parameters); // command declares no parameters
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task Run_RejectsCommandNotInRegistrySnapshot()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            var calls = new List<LaunchCall>();
            vm.LaunchOverride = (command, parameters, elevated, dryRun) =>
            {
                calls.Add(new LaunchCall(command, parameters, elevated, dryRun));
                return null;
            };

            await vm.LoadAsync();
            // Fabricated definition that never came from the snapshot (security advisory).
            vm.SelectedCommand = new CommandItemViewModel(new CommandDefinition
            {
                Name = "free-text-evil",
                Path = "evil/evil.ps1",
                Category = "utilities",
                EntryPoint = "powershell",
            });

            vm.RunCommand.Execute(null);

            Assert.Empty(calls);
            Assert.Contains("not in the loaded registry snapshot", vm.StatusText);
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task Run_BlockedWhileRequiredParametersMissing()
    {
        var root = CreateTempRoot(null);
        try
        {
            var vm = CreateViewModel(root);
            var calls = new List<LaunchCall>();
            vm.LaunchOverride = (command, parameters, elevated, dryRun) =>
            {
                calls.Add(new LaunchCall(command, parameters, elevated, dryRun));
                return null;
            };

            await vm.LoadAsync();
            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "cleanup-temp-files"); // requires TargetDir

            vm.RunCommand.Execute(null);

            Assert.Empty(calls);
            Assert.Contains("required parameters", vm.StatusText);
        }
        finally { Cleanup(root); }
    }

    // ------------------------------------------------------------------
    // Settings parity: DryRun checkbox defaults from `defaultDryRun`
    // ------------------------------------------------------------------

    [Fact]
    public async Task LoadAsync_DryRunDefaultsFromDefaultDryRunSetting()
    {
        var root = CreateTempRoot("""{ "defaultDryRun": true }""");
        try
        {
            var vm = CreateViewModel(root);
            var calls = new List<LaunchCall>();
            vm.LaunchOverride = (command, parameters, elevated, dryRun) =>
            {
                calls.Add(new LaunchCall(command, parameters, elevated, dryRun));
                return null;
            };

            await vm.LoadAsync();
            Assert.True(vm.DryRun);

            vm.SelectedCommand = vm.FilteredCommands.First(c => c.Name == "admin-cleanup-elevated");
            vm.RunCommand.Execute(null);

            Assert.True(Assert.Single(calls).DryRun);
        }
        finally { Cleanup(root); }
    }

    [Fact]
    public async Task LoadAsync_MissingRegistry_FailsGracefully()
    {
        var root = Path.Combine(Path.GetTempPath(), "doapp-vmtests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root); // no config dir at all
        try
        {
            var vm = CreateViewModel(root);
            await vm.LoadAsync();

            Assert.Contains("Failed to load registry", vm.StatusText);
            Assert.Empty(vm.Categories);
            Assert.Equal(0, vm.FilteredCount);
        }
        finally { Cleanup(root); }
    }

    // ------------------------------------------------------------------
    // Code-behind hygiene (plan Task 5 AC): no XamlReader, wiring only
    // ------------------------------------------------------------------

    [Fact]
    public void MainWindow_CodeBehind_IsWiringOnly()
    {
        var repoRoot = App.FindRepoRoot(AppContext.BaseDirectory);
        Assert.False(string.IsNullOrEmpty(repoRoot), $"repo root not found walking up from {AppContext.BaseDirectory}");

        var source = File.ReadAllText(Path.Combine(repoRoot!, "app", "DevOptimizer.App", "Views", "MainWindow.xaml.cs"));
        Assert.DoesNotContain("XamlReader", source, StringComparison.OrdinalIgnoreCase);

        // Rough deterministic brace scan: any block opened inside the class (depth 1 -> 2)
        // must close within 12 lines. The file contains no string literals with braces.
        var lines = source.Split('\n');
        var depth = 0;
        var openLine = -1;
        for (var i = 0; i < lines.Length; i++)
        {
            foreach (var ch in lines[i])
            {
                if (ch == '{')
                {
                    depth++;
                    if (depth == 2)
                    {
                        openLine = i;
                    }
                }
                else if (ch == '}')
                {
                    if (depth == 2)
                    {
                        var span = i - openLine + 1;
                        Assert.True(span <= 12, $"brace block at lines {openLine + 1}..{i + 1} spans {span} lines; method bodies must stay <= 10 lines");
                    }

                    depth--;
                }
            }
        }

        Assert.True(depth == 0, "unbalanced braces in MainWindow.xaml.cs");
        Assert.True(lines.Length <= 45, "MainWindow.xaml.cs must remain a small wiring file");
    }
}
