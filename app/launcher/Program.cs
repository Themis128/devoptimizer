using System.Diagnostics;

namespace DevOptimizer.Launcher;

// Windowless launcher: hosts the DevOptimizer app behind a real exe identity
// (taskbar icon, Start menu, jump list) without a console flash. Default target is
// the C# WPF shell (DevOptimizer.App.exe) next to the launcher; DOAPP_LEGACY=1 (or a
// missing app exe) falls back to the original PowerShell/WPF app below.
internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        // bin -> app -> repo root
        string binDir = AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
        string appDir = Path.GetDirectoryName(binDir)!;
        string repoRoot = Path.GetDirectoryName(appDir)!;
        string script = Path.Combine(repoRoot, "DevOptimizer-App.ps1");
        string appExe = Path.Combine(binDir, "DevOptimizer.App.exe");

        if (args.Any(a => a.Equals("--selfcheck", StringComparison.OrdinalIgnoreCase)))
        {
            Console.WriteLine("DevOptimizer launcher selfcheck");
            Console.WriteLine($"repo={repoRoot}");
            Console.WriteLine($"script={script} [{(File.Exists(script) ? "OK" : "MISSING")}]");
            Console.WriteLine($"app={appExe} [{(File.Exists(appExe) ? "OK" : "MISSING")}]");
            Console.WriteLine($"forwarded={string.Join(' ', args.Where(a => !a.Equals("--selfcheck", StringComparison.OrdinalIgnoreCase)))}");
            return File.Exists(script) && File.Exists(appExe) ? 0 : 2;
        }

        // Default: the C# WPF shell next to the launcher; args forwarded verbatim.
        // DOAPP_LEGACY=1 (or a missing app exe) uses the legacy PowerShell path below.
        if (Environment.GetEnvironmentVariable("DOAPP_LEGACY") != "1" && File.Exists(appExe))
        {
            var appPsi = new ProcessStartInfo
            {
                FileName = appExe,
                UseShellExecute = false,
                WorkingDirectory = repoRoot
            };
            foreach (var a in args)
            {
                appPsi.ArgumentList.Add(a);
            }

            try
            {
                Process.Start(appPsi);
                return 0;
            }
            catch (Exception ex)
            {
                MessageBoxText("Failed to start DevOptimizer:\n" + ex.Message);
                return 1;
            }
        }

        // --- legacy fallback: the PowerShell/WPF app (DOAPP_LEGACY=1) ---
        if (!File.Exists(script))
        {
            MessageBoxText("DevOptimizer installation is broken: script not found:\n" + script);
            return 2;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
            WorkingDirectory = repoRoot
        };
        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-STA");
        psi.ArgumentList.Add("-ExecutionPolicy");
        psi.ArgumentList.Add("Bypass");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(script);
        foreach (var a in args)
        {
            psi.ArgumentList.Add(a);
        }

        try
        {
            Process.Start(psi);
            return 0;
        }
        catch (Exception ex)
        {
            MessageBoxText("Failed to start DevOptimizer:\n" + ex.Message);
            return 1;
        }
    }

    private static void MessageBoxText(string text)
    {
        try
        {
            System.Windows.Forms.MessageBox.Show(text, "DevOptimizer");
        }
        catch
        {
            // headless context - nothing to show
        }
    }
}
