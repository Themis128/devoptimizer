using DevOptimizer.App;
using Xunit;

namespace DevOptimizer.App.Tests;

public class DeepLinkTests
{
    [Theory]
    [InlineData("devoptimizer://command/check-cleanup-status", "check-cleanup-status", null, false)]
    [InlineData("devoptimizer://command/run%20tool", "run tool", null, false)]
    [InlineData("devoptimizer://category/cleanup", null, "cleanup", false)]
    [InlineData("devoptimizer://settings", null, null, true)]
    public void ParseProtocolUrl_KnownSegments_ProduceExpectedArgs(
        string url, string? command, string? category, bool settings)
    {
        var args = App.ParseArgs(new[] { url });
        Assert.Equal(command, args.Command);
        Assert.Equal(category, args.Category);
        Assert.Equal(settings, args.Settings);
    }

    [Theory]
    [InlineData("devoptimizer://unknown-segment")]
    [InlineData("devoptimizer://")]
    public void ParseProtocolUrl_UnknownOrEmpty_YieldsEmptyArgs(string url)
    {
        var args = App.ParseArgs(new[] { url });
        Assert.Null(args.Command);
        Assert.Null(args.Category);
        Assert.False(args.Settings);
    }

    [Fact]
    public void ParseProtocolUrl_Command_MapsToName()
    {
        var args = App.ParseArgs(new[] { "devoptimizer://command/win11-safe-cleanup" });
        Assert.Equal("win11-safe-cleanup", args.Command);
    }
}
