using System.IO;
using DevOptimizer.App;
using Xunit;

namespace DevOptimizer.App.Tests;

public class ExceptionHandlerTests
{
    [Fact]
    public void AppendDebugLog_CreatesDirectoryTreeAndAppendsLines()
    {
        var root = Path.Combine(Path.GetTempPath(), "doapp-exceptiontests-" + Guid.NewGuid().ToString("N"));
        try
        {
            var logPath = Path.Combine(root, "logs", "app-runs", "app-debug.log");

            App.AppendDebugLog(root, "line-one");
            App.AppendDebugLog(root, "line-two");

            Assert.True(File.Exists(logPath), $"expected log at {logPath}");
            var content = File.ReadAllText(logPath);
            Assert.Contains("line-one", content);
            Assert.Contains("line-two", content);
            Assert.EndsWith("line-two" + Environment.NewLine, content);
        }
        finally
        {
            try { Directory.Delete(root, recursive: true); } catch (IOException) { }
        }
    }

    [Fact]
    public void AppSource_RegistersGlobalDispatcherExceptionHandler()
    {
        // A WPF Application cannot be instantiated inside a unit test, so the global
        // handler is verified at source level (grep of the built source, plan Task 1 AC4).
        var repoRoot = App.FindRepoRoot(AppContext.BaseDirectory);
        Assert.False(string.IsNullOrEmpty(repoRoot), $"repo root not found walking up from {AppContext.BaseDirectory}");

        var source = File.ReadAllText(Path.Combine(repoRoot!, "app", "DevOptimizer.App", "App.xaml.cs"));

        Assert.Contains("DispatcherUnhandledException += OnDispatcherUnhandledException", source);
        Assert.Contains("e.Handled = true", source);
        Assert.Contains("AppendDebugLog(root", source);
    }
}
