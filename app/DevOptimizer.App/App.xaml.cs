using System.IO;
using System.Windows;
using System.Windows.Threading;
using DevOptimizer.App.Services;
using DevOptimizer.App.ViewModels;
using DevOptimizer.App.Views;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace DevOptimizer.App;

/// <summary>
/// Parsed command-line arguments. Member names are stable — consumed by the deep links
/// (Command/Category/Settings), the headless selftest (SelfTest) and headless run (RunNow).
/// </summary>
internal sealed record AppArgs(string? Command, string? Category, bool Settings, bool SelfTest, bool RunNow);

/// <summary>
/// Application entry point: repo-root discovery, CLI arg parsing, DI host assembly,
/// global dispatcher exception handler, deep links, --selftest and -RunNow headless modes.
/// </summary>
public partial class App : Application
{
    private IHost? _host;

    /// <summary>
    /// Repo root: first directory walking up from the executable that contains
    /// config\hub-registry.json. Works from any build output directory.
    /// </summary>
    internal static string? RepoRoot { get; private set; }

    private static readonly char[] UnsafeDeeplinkChars = { '\r', '\n', '\0' };

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Global safety net: log every unhandled dispatcher exception and keep the app alive.
        DispatcherUnhandledException += OnDispatcherUnhandledException;

        var args = ParseArgs(e.Args);
        RepoRoot = FindRepoRoot(AppContext.BaseDirectory);
        if (RepoRoot is null)
        {
            AppendDebugLog(AppContext.BaseDirectory, "error: repo root not found (no config\\hub-registry.json above the exe)");
        }

        if (args.SelfTest)
        {
            StartSelfTest(args);
            return;
        }

        if (args.RunNow && !string.IsNullOrEmpty(args.Command))
        {
            StartRunNow(args);
            return;
        }

        _host = BuildHost(args);
        Log(RepoRoot, "checkpoint: host built");

        var window = _host.Services.GetRequiredService<MainWindow>();
        MainWindow = window;
        Log(RepoRoot, "checkpoint: vm-bound");

        window.Show();
        Log(RepoRoot, "checkpoint: view loaded");

        _ = FinishStartupAsync(window, args);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _host?.Dispose();
        base.OnExit(e);
    }

    private IHost BuildHost(AppArgs args)
    {
        return Host.CreateDefaultBuilder()
            .ConfigureServices(services =>
            {
                services.AddSingleton(args);
                services.AddSingleton(_ => RepoRoot ?? AppContext.BaseDirectory);
                services.AddSingleton<RegistryService>();
                services.AddSingleton<SettingsService>();
                services.AddSingleton<CommandRunnerService>();
                services.AddSingleton<MainViewModel>();
                services.AddSingleton<MainWindow>();
            })
            .Build();
    }

    /// <summary>
    /// Headless selftest: no interactive window — the shell is instantiated with
    /// ShowActivated=false/ShowInTaskbar=false, the registry-driven checks run against the
    /// loaded view model and visual structure, then selftest: lines and the final
    /// SELFTEST PASS/FAIL verdict are appended and the process exits 0/1.
    /// </summary>
    private async void StartSelfTest(AppArgs args)
    {
        var repoRoot = RepoRoot;
        if (repoRoot is null)
        {
            AppendDebugLog(AppContext.BaseDirectory, "SELFTEST FAIL");
            Shutdown(1);
            return;
        }

        try
        {
            Log(repoRoot, "checkpoint: selftest entered");
            _host = BuildHost(args);
            var window = _host.Services.GetRequiredService<MainWindow>();
            // OnExplicitShutdown: window.Close() below must not end the process via
            // OnLastWindowClose with the default exit code — only Shutdown(exitCode)
            // terminates the selftest, so the verdict reaches the process exit code.
            ShutdownMode = ShutdownMode.OnExplicitShutdown;
            // Off-screen placement: the selftest window is never visible or interactive.
            window.WindowStartupLocation = WindowStartupLocation.Manual;
            window.Left = -10000;
            window.Top = -10000;
            window.ShowActivated = false;
            window.ShowInTaskbar = false;
            window.Show();

            int exitCode;
            if (!await WaitForViewModelLoadedAsync(window.ViewModel))
            {
                Log(repoRoot, "selftest: registry load failed");
                Log(repoRoot, "SELFTEST FAIL");
                exitCode = 1;
            }
            else
            {
                var checks = window.RunSelfTestChecks(repoRoot);
                var passed = SelfTestRunner.LogResults(repoRoot, checks);
                Log(repoRoot, "checkpoint: selftest finished");
                exitCode = passed ? 0 : 1;
            }

            window.Close();
            Shutdown(exitCode);
        }
        catch (Exception ex)
        {
            Log(repoRoot, $"SELFTEST EXCEPTION: {ex.Message}");
            Log(repoRoot, "SELFTEST FAIL");
            Shutdown(1);
        }
    }

    /// <summary>
    /// Headless -Command &lt;name&gt; -RunNow: shows no window, spawns the detached runner
    /// (same per-run artifacts), logs a deeplink: line and exits 0 immediately — the run
    /// completes asynchronously via the done-file protocol.
    /// </summary>
    private void StartRunNow(AppArgs args)
    {
        var repoRoot = RepoRoot!;
        var exitCode = 0;
        try
        {
            _host = BuildHost(args);
            var runner = _host.Services.GetRequiredService<CommandRunnerService>();
            var registry = _host.Services.GetRequiredService<RegistryService>();

            var snapshot = registry.LoadSnapshot(Path.Combine(repoRoot, "config", "hub-registry.json"));
            var definition = snapshot.Commands.FirstOrDefault(c => c.Name == args.Command);
            if (definition is null)
            {
                // Log-injection guard: strip control characters before echoing the raw arg.
                var loggedName = args.Command!.Replace("\r", string.Empty).Replace("\n", string.Empty).Replace("\0", string.Empty);
                Log(repoRoot, $"deeplink: command '{loggedName}' not found in registry - ignored");
                exitCode = 1;
            }
            else
            {
                Log(repoRoot, $"deeplink: command '{args.Command}' (run now)");
                runner.Start(definition, new Dictionary<string, object?>(), elevated: false, dryRun: false);
                Log(repoRoot, "checkpoint: run-now spawned");
            }
        }
        catch (Exception ex)
        {
            Log(repoRoot, $"error: run-now failed: {ex.Message}");
            exitCode = 1;
        }

        Shutdown(exitCode);
    }

    private async Task FinishStartupAsync(MainWindow window, AppArgs args)
    {
        try
        {
            if (!await WaitForViewModelLoadedAsync(window.ViewModel))
            {
                Log(RepoRoot, "checkpoint: registry load failed");
                return;
            }

            ApplyDeepLinks(window.ViewModel, args, RepoRoot!);
            Log(RepoRoot, "checkpoint: ui-populated");
        }
        catch (Exception ex)
        {
            Log(RepoRoot, $"error: startup continuation failed: {ex.Message}");
        }
    }

    /// <summary>Bounded wait for the code-behind's LoadAsync to populate the sidebar.</summary>
    private static async Task<bool> WaitForViewModelLoadedAsync(MainViewModel viewModel)
    {
        var deadline = DateTime.UtcNow.AddSeconds(10);
        while (viewModel.Categories.Count == 0)
        {
            if (viewModel.StatusText.StartsWith("Failed to load registry", StringComparison.Ordinal) || DateTime.UtcNow >= deadline)
            {
                return false;
            }

            await Task.Delay(50);
        }

        return true;
    }

    internal static bool IsSafeDeeplinkValue(string? value) => value is not null && value.IndexOfAny(UnsafeDeeplinkChars) < 0;

    /// <summary>
    /// Applies -Settings / -Category / -Command deep links (priority order) with the PS
    /// protocol semantics (DevOptimizer-App.ps1:935-975): unsafe values are rejected and
    /// logged, unknown targets are logged and ignored, applied targets log a deeplink: line.
    /// </summary>
    internal static void ApplyDeepLinks(MainViewModel viewModel, AppArgs args, string repoRoot)
    {
        var command = IsSafeDeeplinkValue(args.Command) ? args.Command : null;
        var category = IsSafeDeeplinkValue(args.Category) ? args.Category : null;

        // PS parity (DevOptimizer-App.ps1:940-943): the unsafe pattern only matches PRESENT
        // values — absent args are silent, present-but-unsafe args log the rejection.
        if (args.Command is not null && !IsSafeDeeplinkValue(args.Command))
        {
            LogService.Append(repoRoot, "deeplink: rejected unsafe command value");
        }

        if (args.Category is not null && !IsSafeDeeplinkValue(args.Category))
        {
            LogService.Append(repoRoot, "deeplink: rejected unsafe category value");
        }

        if (args.Settings)
        {
            LogService.Append(repoRoot, "deeplink: settings view requested");
            viewModel.StatusText = "Settings view is not available in this build.";
        }
        else if (category is not null)
        {
            var match = viewModel.Categories.FirstOrDefault(c => c.Name == category);
            if (match is not null)
            {
                LogService.Append(repoRoot, $"deeplink: category '{category}'");
                viewModel.SelectedCategory = match;
            }
            else
            {
                LogService.Append(repoRoot, $"deeplink: category '{category}' not found in registry - ignored");
                viewModel.StatusText = $"Deep link ignored: unknown category '{category}'.";
            }
        }
        else if (command is not null)
        {
            viewModel.SelectedCategory = viewModel.Categories.First(c => c.Name == "All");
            viewModel.SearchText = string.Empty;
            var row = viewModel.FilteredCommands.FirstOrDefault(c => c.Name == command);
            if (row is not null)
            {
                LogService.Append(repoRoot, $"deeplink: command '{command}'");
                viewModel.SelectedCommand = row;
            }
            else
            {
                LogService.Append(repoRoot, $"deeplink: command '{command}' not found in registry - ignored");
                viewModel.StatusText = $"Deep link ignored: unknown command '{command}'.";
            }
        }
    }

    /// <summary>Parses raw CLI arguments into <see cref="AppArgs"/> (case-insensitive, -x / --x).</summary>
    internal static AppArgs ParseArgs(IReadOnlyList<string> args)
    {
        string? command = null;
        string? category = null;
        bool settings = false;
        bool selfTest = false;
        bool runNow = false;

        for (var i = 0; i < args.Count; i++)
        {
            switch (args[i].ToLowerInvariant())
            {
                case "-command" or "--command":
                    command = i + 1 < args.Count ? args[++i] : null;
                    break;
                case "-category" or "--category":
                    category = i + 1 < args.Count ? args[++i] : null;
                    break;
                case "-settings" or "--settings":
                    settings = true;
                    break;
                case "-selftest" or "--selftest":
                    selfTest = true;
                    break;
                case "-runnow" or "--runnow":
                    runNow = true;
                    break;
            }
        }

        return new AppArgs(command, category, settings, selfTest, runNow);
    }

    /// <summary>
    /// Walks up from <paramref name="startDir"/> to the first directory containing
    /// config\hub-registry.json; returns null when the repo root cannot be located.
    /// </summary>
    internal static string? FindRepoRoot(string startDir)
    {
        var dir = new DirectoryInfo(startDir);
        while (dir is not null)
        {
            if (File.Exists(Path.Combine(dir.FullName, "config", "hub-registry.json")))
            {
                return dir.FullName;
            }

            dir = dir.Parent;
        }

        return null;
    }

    /// <summary>
    /// Appends one line to &lt;repoRoot&gt;\logs\app-runs\app-debug.log, creating the
    /// directory if needed. Small internal static helper so tests can scope it to a temp root.
    /// </summary>
    internal static void AppendDebugLog(string repoRoot, string line)
    {
        var dir = Path.Combine(repoRoot, "logs", "app-runs");
        Directory.CreateDirectory(dir);
        File.AppendAllText(Path.Combine(dir, "app-debug.log"), line + Environment.NewLine);
    }

    private static void Log(string? repoRoot, string line)
    {
        if (repoRoot is not null)
        {
            LogService.Append(repoRoot, line);
        }
    }

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        var root = RepoRoot ?? AppContext.BaseDirectory;
        var message = e.Exception.Message.Replace("\r", " ").Replace("\n", " ");
        var summary = $"exception: {DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} {e.Exception.GetType().FullName}: {message}";
        AppendDebugLog(root, summary);
        e.Handled = true;
    }
}
