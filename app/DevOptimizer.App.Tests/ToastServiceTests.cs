using System.IO;
using DevOptimizer.App;
using DevOptimizer.App.Services;
using DevOptimizer.App.UserControls;
using Xunit;

namespace DevOptimizer.App.Tests;

public class ToastServiceTests
{
    private static string WriteSettings(string root, string json)
    {
        var dir = Path.Combine(root, "config");
        Directory.CreateDirectory(dir);
        var path = Path.Combine(dir, "app-settings.json");
        File.WriteAllText(path, json);
        return root;
    }

    [Fact]
    public void Resolve_NoSettings_ShowsWithDefaultSeconds()
    {
        var root = Path.Combine(Path.GetTempPath(), "toast-tests-" + Guid.NewGuid().ToString("N"));
        var decision = ToastService.Resolve("msg", ToastType.Info, root, null);
        Assert.True(decision.Show);
        Assert.Equal(5, decision.Seconds);
    }

    [Fact]
    public void Resolve_ToastsDisabled_Suppresses()
    {
        var root = WriteSettings(Path.Combine(Path.GetTempPath(), "toast-tests-" + Guid.NewGuid().ToString("N")),
            """{"toasts": false}""");
        var decision = ToastService.Resolve("msg", ToastType.Info, root, null);
        Assert.False(decision.Show);
    }

    [Fact]
    public void Resolve_MinSeconds_ClampsToAtLeastOne()
    {
        var root = WriteSettings(Path.Combine(Path.GetTempPath(), "toast-tests-" + Guid.NewGuid().ToString("N")),
            """{"toastMinSeconds": 0}""");
        var decision = ToastService.Resolve("msg", ToastType.Info, root, null);
        Assert.True(decision.Show);
        Assert.Equal(1, decision.Seconds);
    }

    [Fact]
    public void Resolve_DisplaySecondsOverride_Wins()
    {
        var root = WriteSettings(Path.Combine(Path.GetTempPath(), "toast-tests-" + Guid.NewGuid().ToString("N")),
            """{"toastMinSeconds": 10}""");
        var decision = ToastService.Resolve("msg", ToastType.Info, root, displaySeconds: 3);
        Assert.True(decision.Show);
        Assert.Equal(3, decision.Seconds);
    }

    [Fact]
    public void Resolve_CorruptedSettings_FallsBackToShow()
    {
        var root = WriteSettings(Path.Combine(Path.GetTempPath(), "toast-tests-" + Guid.NewGuid().ToString("N")),
            "{ not valid json");
        var decision = ToastService.Resolve("msg", ToastType.Info, root, null);
        Assert.True(decision.Show);
        Assert.Equal(5, decision.Seconds);
    }
}
