using System.IO;
using DevOptimizer.App;
using DevOptimizer.App.Models;
using DevOptimizer.App.Services;
using Xunit;

namespace DevOptimizer.App.Tests;

public class RegistryServiceTests
{
    // Fixture shape (Fixtures/registry-sample.json, 8 commands):
    //   categories: cleanup 3, utilities 2, maintenance 1, network 1, monitoring 1
    //   search "cleanup" -> 5: cleanup-temp-files (name/path), disk-status (description),
    //     admin-cleanup-elevated (name/path), cleanup-tools-launcher (name/path),
    //     safe-purge (tags only)
    //   "junk-sweeper" is in the cleanup category but has no "cleanup" token in any
    //   searched field — it locks the category-exclusion semantics. "disk-status" is
    //   category "utilities" but its description contains "cleanup" (the fixture's
    //   category-name-in-another-command's-description trap).

    private static readonly string[] ExpectedCleanupSearchNames =
    {
        "cleanup-temp-files", "disk-status", "admin-cleanup-elevated", "cleanup-tools-launcher", "safe-purge",
    };

    private static string FixturePath => Path.Combine(AppContext.BaseDirectory, "Fixtures", "registry-sample.json");

    private static RegistrySnapshot LoadFixture() => new RegistryService().LoadSnapshot(FixturePath);

    // ------------------------------------------------------------------
    // Correctness against the fixture
    // ------------------------------------------------------------------

    [Fact]
    public void Fixture_Loads_AllEightCommands()
    {
        var snapshot = LoadFixture();
        Assert.Equal(8, snapshot.Commands.Count);
    }

    [Fact]
    public void Fixture_Commands_CarryAllTypedFields()
    {
        var snapshot = LoadFixture();

        var command = Assert.Single(snapshot.Commands, c => c.Name == "cleanup-temp-files");
        Assert.Equal("scripts/cleanup-temp-files.ps1", command.Path);
        Assert.Equal("cleanup", command.Category);
        Assert.Equal("Removes temporary files from the system", command.Description);
        Assert.False(command.RequiresAdmin);
        Assert.Equal("powershell", command.EntryPoint);
        Assert.Equal(new[] { "temp", "disk" }, command.Tags);

        var parameter = Assert.Single(command.Parameters);
        Assert.Equal("TargetDir", parameter.Name);
        Assert.Equal("string", parameter.Type);
        Assert.True(parameter.Required);
        Assert.Equal("Directory to clean", parameter.Description);

        Assert.Equal("1.0.0", command.Metadata["version"]);
        Assert.Equal("https://github.com/devoptimizer/devoptimizer", command.Metadata["sourceUrl"]);
        Assert.Equal("DevOptimizer", command.Metadata["author"]);
    }

    [Fact]
    public void Fixture_Snapshot_CarriesTopLevelDocumentFields()
    {
        var snapshot = LoadFixture();

        Assert.Equal("1.0.0", snapshot.Version);
        Assert.Equal(5, snapshot.Categories.Count);
        Assert.Equal(3, snapshot.Categories.Single(c => c.Name == "cleanup").CommandCount);
    }

    [Fact]
    public void Fixture_Search_MatchesNameDescriptionPathAndTags()
    {
        var snapshot = LoadFixture();
        var results = RegistryService.Search(snapshot, "cleanup");

        Assert.Equal(ExpectedCleanupSearchNames.Length, results.Count);
        Assert.Equal(
            ExpectedCleanupSearchNames.OrderBy(n => n, StringComparer.Ordinal),
            results.Select(c => c.Name).OrderBy(n => n, StringComparer.Ordinal));
    }

    [Fact]
    public void Fixture_Search_ExcludesCategory_NotEveryCleanupCommandMatches()
    {
        // Regression lock (AppCore.Tests.ps1:108-109, DevOptimizer-App.ps1:1046-1051):
        // searching a category name must NOT return every command of that category.
        // junk-sweeper (category "cleanup") lacks "cleanup" in all searched fields and
        // must be excluded; disk-status (category "utilities") matches via description.
        var snapshot = LoadFixture();
        var results = RegistryService.Search(snapshot, "cleanup");

        Assert.DoesNotContain(results, c => c.Name == "junk-sweeper");
        Assert.Contains(results, c => c.Name == "disk-status");
        Assert.NotEqual(
            RegistryService.ByCategory(snapshot, "cleanup").Select(c => c.Name).OrderBy(n => n, StringComparer.Ordinal),
            results.Select(c => c.Name).OrderBy(n => n, StringComparer.Ordinal));
    }

    [Fact]
    public void Fixture_Search_IsCaseInsensitive()
    {
        var snapshot = LoadFixture();

        Assert.Equal(
            RegistryService.Search(snapshot, "cleanup").Select(c => c.Name).OrderBy(n => n, StringComparer.Ordinal),
            RegistryService.Search(snapshot, "CLEANUP").Select(c => c.Name).OrderBy(n => n, StringComparer.Ordinal));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Fixture_Search_BlankQuery_ReturnsAllCommands(string query)
    {
        var snapshot = LoadFixture();
        Assert.Equal(snapshot.Commands.Count, RegistryService.Search(snapshot, query).Count);
    }

    [Fact]
    public void Fixture_Search_NoMatch_ReturnsEmpty()
    {
        var snapshot = LoadFixture();
        Assert.Empty(RegistryService.Search(snapshot, "zzz-no-such-token"));
    }

    [Fact]
    public void Fixture_ByCategory_ReturnsExactSets()
    {
        var snapshot = LoadFixture();

        Assert.Equal(
            new[] { "cleanup-temp-files", "admin-cleanup-elevated", "junk-sweeper" }.OrderBy(n => n, StringComparer.Ordinal),
            RegistryService.ByCategory(snapshot, "cleanup").Select(c => c.Name).OrderBy(n => n, StringComparer.Ordinal));
        Assert.Equal(2, RegistryService.ByCategory(snapshot, "utilities").Count);
        Assert.Single(RegistryService.ByCategory(snapshot, "maintenance"));
        Assert.Single(RegistryService.ByCategory(snapshot, "network"));
        Assert.Single(RegistryService.ByCategory(snapshot, "monitoring"));
        Assert.Empty(RegistryService.ByCategory(snapshot, "does-not-exist"));
    }

    [Fact]
    public void Fixture_ByCategory_IsCaseInsensitive_AndNotDrivenByDescription()
    {
        // disk-status's description contains "cleanup" but its category is "utilities":
        // the category filter must not pull it in, and matching is case-insensitive.
        var snapshot = LoadFixture();
        var cleanup = RegistryService.ByCategory(snapshot, "Cleanup");

        Assert.Equal(3, cleanup.Count);
        Assert.DoesNotContain(cleanup, c => c.Name == "disk-status");
    }

    // ------------------------------------------------------------------
    // Integration regression lock (D4): the ONLY test that reads the live
    // config/hub-registry.json. Counts were verified against the live file
    // on 2026-11-09; re-verify if the producer (Build-Registry.ps1) changes.
    // ------------------------------------------------------------------
    [Fact]
    public void Live_Registry_PinsTotalCategoryAndSearchCounts()
    {
        var repoRoot = App.FindRepoRoot(AppContext.BaseDirectory);
        Assert.False(string.IsNullOrEmpty(repoRoot), $"repo root not found walking up from {AppContext.BaseDirectory}");

        var livePath = Path.Combine(repoRoot!, "config", "hub-registry.json");
        var snapshot = new RegistryService().LoadSnapshot(livePath);

        Assert.Equal(772, snapshot.Commands.Count);

        var expectedCounts = new Dictionary<string, int>
        {
            ["ai"] = 2,
            ["ai-ml"] = 43,
            ["backup-restore"] = 5,
            ["cleanup"] = 130,
            ["development"] = 12,
            ["diagnostics"] = 1,
            ["docker"] = 3,
            ["gaming"] = 26,
            ["maintenance"] = 46,
            ["monitoring"] = 7,
            ["network"] = 5,
            ["security"] = 4,
            ["storage"] = 1,
            ["system"] = 2,
            ["system-optimization"] = 3,
            ["utilities"] = 480,
            ["verification"] = 2,
        };
        var actualCounts = snapshot.Commands
            .GroupBy(c => c.Category, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
        Assert.Equal(
            expectedCounts.OrderBy(kv => kv.Key, StringComparer.Ordinal),
            actualCounts.OrderBy(kv => kv.Key, StringComparer.Ordinal));

        // The typed load carries the core fields on every command.
        Assert.All(snapshot.Commands, c =>
        {
            Assert.False(string.IsNullOrWhiteSpace(c.Name));
            Assert.False(string.IsNullOrWhiteSpace(c.Path));
            Assert.False(string.IsNullOrWhiteSpace(c.Category));
            Assert.False(string.IsNullOrWhiteSpace(c.EntryPoint));
        });

        // Regression-locked search: "cleanup" -> 50, NOT the cleanup-category commands.
        var searchResults = RegistryService.Search(snapshot, "cleanup");
        Assert.Equal(81, searchResults.Count);
        Assert.NotEqual(RegistryService.ByCategory(snapshot, "cleanup").Count, searchResults.Count);
    }
}
