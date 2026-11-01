using System.IO;
using System.Windows;
using System.Windows.Controls;
using DevOptimizer.App.Models;
using DevOptimizer.App.ViewModels;

namespace DevOptimizer.App.Services;

/// <summary>
/// Debug-log writer with the same line format the PS app uses via Log-D
/// (DevOptimizer-App.ps1:78): "HH:mm:ss.fff &lt;message&gt;" appended to
/// logs\app-runs\app-debug.log (directory created on demand).
/// Emits the parity prefixes: checkpoint:, selftest:, deeplink:.
/// </summary>
public static class LogService
{
    public static void Append(string repoRoot, string line)
    {
        var dir = Path.Combine(repoRoot, "logs", "app-runs");
        Directory.CreateDirectory(dir);
        File.AppendAllText(Path.Combine(dir, "app-debug.log"), $"{DateTime.Now:HH:mm:ss.fff} {line}{Environment.NewLine}");
    }
}

/// <summary>One headless selftest assertion outcome.</summary>
public sealed record SelfTestCheck(string Name, bool Passed, string Detail);

/// <summary>
/// Registry-driven selftest assertion engine (PS structure, DevOptimizer-App.ps1:1025-1060):
/// sidebar categories, category filter at a fixed sidebar index, live search with a
/// positive control, the category-exclusion regression, and detail-panel structure.
/// Expectations are recomputed independently from the registry snapshot so a broken
/// ViewModel pipeline is caught; the window passes in its detail-panel child count so
/// this class never touches the visual tree itself.
/// </summary>
public static class SelfTestRunner
{
    public const string SelfTestQuery = "diagnostic";

    public const int CategoryProbeIndex = 3;

    public static async Task<IReadOnlyList<SelfTestCheck>> RunChecksAsync(MainViewModel viewModel, string repoRoot, string searchQuery, int detailPanelChildCount)
    {
        var checks = new List<SelfTestCheck>();
        var snapshot = new RegistryService().LoadSnapshot(Path.Combine(repoRoot, "config", "hub-registry.json"));
        var commands = snapshot.Commands;

        checks.Add(CheckSidebar(viewModel, commands));
        checks.Add(CheckCategoryFilter(viewModel, commands));
        checks.Add(await CheckSearchAsync(viewModel, snapshot, searchQuery));
        checks.Add(await CheckCategoryNameExclusionAsync(viewModel, snapshot));

        viewModel.SearchText = string.Empty;
        viewModel.SelectedCategory = viewModel.Categories.FirstOrDefault(c => c.Name == "All");
        viewModel.SelectedCommand = viewModel.FilteredCommands.FirstOrDefault();
        checks.Add(new SelfTestCheck(
            "detail panel children",
            detailPanelChildCount >= 3,
            $"children {detailPanelChildCount} (selection: {viewModel.SelectedCommand?.Name ?? "none"})"));

        return checks;
    }

    private static SelfTestCheck CheckSidebar(MainViewModel viewModel, List<CommandDefinition> commands)
    {
        var expected = new List<CategoryItem> { new("All", commands.Count) };
        expected.AddRange(commands
            .GroupBy(c => c.Category, StringComparer.OrdinalIgnoreCase)
            .OrderByDescending(g => g.Count())
            .ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
            .Select(g => new CategoryItem(g.Key, g.Count())));

        var passed = expected.Count == viewModel.Categories.Count;
        if (passed)
        {
            for (var i = 0; i < expected.Count; i++)
            {
                if (expected[i].Name != viewModel.Categories[i].Name || expected[i].Count != viewModel.Categories[i].Count)
                {
                    passed = false;
                    break;
                }
            }
        }

        return new SelfTestCheck("sidebar categories", passed, $"entries {viewModel.Categories.Count}, expected {expected.Count}");
    }

    private static SelfTestCheck CheckCategoryFilter(MainViewModel viewModel, List<CommandDefinition> commands)
    {
        if (viewModel.Categories.Count <= CategoryProbeIndex)
        {
            return new SelfTestCheck($"category[{CategoryProbeIndex}] filter", false, $"sidebar has only {viewModel.Categories.Count} entries");
        }

        var probed = viewModel.Categories[CategoryProbeIndex];
        viewModel.SearchText = string.Empty;
        viewModel.SelectedCategory = probed;
        var expected = commands.Count(c => string.Equals(c.Category, probed.Name, StringComparison.OrdinalIgnoreCase));
        return new SelfTestCheck(
            $"category[{CategoryProbeIndex}] '{probed.Name}' filter",
            viewModel.FilteredCount == expected,
            $"shown {viewModel.FilteredCount}, expected {expected}");
    }

    private static async Task<SelfTestCheck> CheckSearchAsync(MainViewModel viewModel, RegistrySnapshot snapshot, string searchQuery)
    {
        viewModel.SelectedCategory = viewModel.Categories.FirstOrDefault(c => c.Name == "All");
        viewModel.SearchText = searchQuery;
        // The view model debounces SearchText (SearchDebounceMs) before ApplyFilter runs;
        // settle past it plus one dispatcher cycle before reading the filtered count.
        await Task.Delay(MainViewModel.SearchDebounceMs + 300);
        var expectedQuery = RegistryService.Search(snapshot, searchQuery).Count;
        return new SelfTestCheck(
            $"all + search '{searchQuery}'",
            viewModel.FilteredCount == expectedQuery && expectedQuery > 0,
            $"shown {viewModel.FilteredCount}, expected {expectedQuery} (positive control)");
    }

    private static async Task<SelfTestCheck> CheckCategoryNameExclusionAsync(MainViewModel viewModel, RegistrySnapshot snapshot)
    {
        var probed = viewModel.Categories.Count > CategoryProbeIndex ? viewModel.Categories[CategoryProbeIndex] : null;
        if (probed is null)
        {
            return new SelfTestCheck("category-name search exclusion", false, "no probed category (sidebar too small)");
        }

        viewModel.SearchText = probed.Name;
        await Task.Delay(MainViewModel.SearchDebounceMs + 300);
        var expected = RegistryService.Search(snapshot, probed.Name).Count;
        return new SelfTestCheck(
            $"search category name '{probed.Name}' excludes category",
            viewModel.FilteredCount == expected,
            $"semantic matches {expected}, category has {probed.Count}, shown {viewModel.FilteredCount}");
    }

    /// <summary>Appends the selftest: lines plus the final verdict; returns the aggregate result.</summary>
    public static bool LogResults(string repoRoot, IReadOnlyList<SelfTestCheck> checks)
    {
        foreach (var check in checks)
        {
            LogService.Append(repoRoot, $"selftest: {check.Name} -> {(check.Passed ? "ok" : "FAIL")} ({check.Detail})");
        }

        var passed = checks.All(c => c.Passed);
        LogService.Append(repoRoot, passed ? "SELFTEST PASS" : "SELFTEST FAIL");
        return passed;
    }

    /// <summary>
    /// Walks the known shell layout (root grid -> body grid -> detail grid -> header
    /// StackPanel) and counts the detail panel's children; 0 when the layout is not found.
    /// </summary>
    public static int CountDetailPanelChildren(Window window)
    {
        if (window.Content is Grid root && root.Children.Count > 1
            && root.Children[1] is Grid body && body.Children.Count > 2
            && body.Children[2] is Grid detail && detail.Children.Count > 0
            && detail.Children[0] is StackPanel panel)
        {
            return panel.Children.Count;
        }

        return 0;
    }
}
