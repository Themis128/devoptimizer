using System.Diagnostics;

namespace DevOptimizer.Launcher;

// Windowless launcher: hosts the PowerShell/WPF app behind a real exe identity
// (taskbar icon, Start menu, jump list) without a console flash.
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

        if (args.Any(a => a.Equals("--selfcheck", StringComparison.OrdinalIgnoreCase)))
        {
            Console.WriteLine("DevOptimizer launcher selfcheck");
            Console.WriteLine($"repo={repoRoot}");
            Console.WriteLine($"script={script} [{(File.Exists(script) ? "OK" : "MISSING")}]");
            Console.WriteLine($"forwarded={string.Join(' ', args.Where(a => !a.Equals("--selfcheck", StringComparison.OrdinalIgnoreCase)))}");
            return File.Exists(script) ? 0 : 2;
        }

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
