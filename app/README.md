# DevOptimizer — Windows 11 Application

The DevOptimizer hub as a first-class Windows 11 application: a real launcher
executable with its own icon and identity, Win 11 window chrome, a settings page,
toast notifications, taskbar jump list, single-instance enforcement, a per-user
installer that registers it in Windows Settings → Apps, and a Pester test suite.

```
app\
  DevOptimizer-AppCore.psm1   Testable application core (settings, filter, autostart, toast, chrome, mutex)
  DevOptimizer.ico            Multi-resolution icon (256/48/32/16)
  launcher\                   .NET 8 launcher source (DevOptimizer.Launcher.csproj, Program.cs)
  bin\DevOptimizer.exe        Built single-file launcher (~0.25 MB)
installer\
  Install-DevOptimizer.ps1    Per-user install: Start Menu shortcut + HKCU Apps-list entry
  Uninstall-DevOptimizer.ps1  Per-user uninstall
tests\app\                    Pester suite (34 tests: units + package integration)
scripts\Build-App.ps1         Rebuilds icon + launcher exe
scripts\Test-App.ps1          Runs the Pester suite (auto-installs Pester 5+ per-user)
```

## Install / run / remove

```powershell
# install (per user, no elevation) - Start Menu + Windows Settings > Apps
powershell -NoProfile -ExecutionPolicy Bypass -File installer\Install-DevOptimizer.ps1

# run
DevOptimizer            # Start menu, or:
D:\DevOptimizer\app\bin\DevOptimizer.exe
D:\DevOptimizer\app\bin\DevOptimizer.exe -Category cleanup     # deep links
D:\DevOptimizer\app\bin\DevOptimizer.exe -Settings

# remove (per user)
powershell -NoProfile -ExecutionPolicy Bypass -File installer\Uninstall-DevOptimizer.ps1
```

## Components

| Component | Where |
|---|---|
| Win 11 chrome — dark titlebar, rounded corners, Mica backdrop (silent fallback) | AppCore `Set-WindowChrome`, applied on `SourceInitialized` |
| Single instance — second launch focuses the running window | AppCore `Test-SingleInstance` (named mutex) |
| Settings page — theme, log level, toasts, autostart, default dry-run | App UI "⚙ Settings" → `config\app-settings.json` |
| Toast notifications when long runs (≥ N s, configurable) finish | AppCore `Send-RunCompleteToast` (WinRT, PowerShell AUMID) |
| Taskbar jump list — Health snapshot / Cleanup / Settings | App startup (`System.Windows.Shell.JumpList`) |
| Launch at Windows startup — per-user Run key toggle | Settings page → AppCore `Set-AutoStart` (HKCU, off by default) |

Deep links accepted by both the exe and `DevOptimizer-App.ps1`:
`-Command <name>`, `-Category <name>`, `-Settings`.

## Tests

```powershell
pwsh -NoProfile -File scripts\Test-App.ps1          # or -CI for minimal output
```

34 tests: settings schema/roundtrip/invalid-enum/corrupt-file, the search filter
regression lock (a category name can never match a whole category via search),
autostart set/query/clear against an injected Run key, single-instance mutex
cross-process semantics, launcher selfcheck + argument forwarding, icon directory
structure, HKCU Apps-list registration, Start Menu shortcut target, embedded XAML
well-formedness, and Win 11 component wiring assertions.

The UI itself is covered by the headless self-test (data pipeline, category
filtering, search, detail panel):

```powershell
DOAPP_SELFTEST=1 powershell -NoProfile -STA -ExecutionPolicy Bypass -File DevOptimizer-App.ps1
# results: logs\app-runs\app-debug.log
```

## Notes

- The launcher is framework-dependent on .NET 8 desktop (present via the installed
  SDK). `scripts\Build-App.ps1` rebuilds everything; flip `SelfContained` in the
  csproj for a portable (~100 MB) build.
- Everything is per-user: no elevation is required or used at any point.
- The engine (`Execute-Command.ps1`, `config\hub-registry.json`) is unchanged —
  the app is a Windows 11 presentation layer over the same 353-command registry.
