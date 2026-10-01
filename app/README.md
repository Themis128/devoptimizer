# DevOptimizer — Windows 11 Application

The DevOptimizer hub as a first-class Windows 11 application: one launcher
executable with its own icon and identity that starts the C# WPF shell
(MVVM, compiled XAML, dependency injection, per-monitor V2 DPI) over the
unchanged PowerShell engine, with the original PowerShell/WPF app kept as a
migration fallback, a per-user installer that registers the app in
Windows Settings → Apps, and a Pester test suite.

## One exe entry point (launcher rewire)

`app\bin\DevOptimizer.exe` (the launcher) decides what to start:

- **Default:** launches `DevOptimizer.App.exe` from its own directory — the C#
  WPF shell — forwarding every argument verbatim.
- **`DOAPP_LEGACY=1`:** launches the PowerShell app (`DevOptimizer-App.ps1`)
  exactly as before the rewire. This is the migration fallback.
- **Missing app exe:** falls back to the PowerShell app as well.
- **`--selfcheck`:** verifies the package and prints `repo=`, `script=`,
  `app=` (the C# exe) and `forwarded=` lines; exits 0 when everything is
  present, 2 otherwise.

## Layout

```
app\
  DevOptimizer.App\           C# WPF shell (net8.0-windows) — the primary UI
    App.xaml(.cs)             Generic Host + DI, repo-root discovery, deep links,
                              --selftest, -RunNow headless mode, global exception handler
    Models\                   CommandDefinition, RegistrySnapshot, AppSettings (typed)
    Services\                 RegistryService (BOM-tolerant typed load, regression-locked search),
                              SettingsService (AppCore schema parity), CommandRunnerService
                              (Start-HubRun-compatible out-of-process runner), LogService
    ViewModels\               MainViewModel (live search, categories, detail, run/output polling)
    Views\                    MainWindow (compiled BAML — no XamlReader)
    app.manifest              PerMonitorV2 DPI awareness
  DevOptimizer.App.Tests\     xUnit suite (`dotnet test`)
  DevOptimizer-AppCore.psm1   PowerShell application core (used by the fallback app)
  DevOptimizer-App.ps1        PowerShell/WPF app — DOAPP_LEGACY=1 fallback UI
  DevOptimizer.ico            Multi-resolution icon (256/48/32/16)
  launcher\                   .NET 8 launcher source (DevOptimizer.Launcher.csproj, Program.cs)
  bin\DevOptimizer.exe        Built single-file launcher (~0.25 MB)
  bin\DevOptimizer.App.exe    C# shell (published by Build-App.ps1 with its DLLs)
installer\
  Install-DevOptimizer.ps1    Per-user install: Start Menu shortcut + HKCU Apps-list entry
  Uninstall-DevOptimizer.ps1  Per-user uninstall
tests\app\                    Pester suite (launcher selfcheck/forwarding, icon, install, legacy app)
scripts\Build-App.ps1         Rebuilds icon + launcher exe + C# shell publish into app\bin
scripts\Test-App.ps1          Runs the Pester suite (auto-installs Pester 5+ per-user)
```

## Install / run / remove

```powershell
# install (per user, no elevation) - Start Menu + Windows Settings > Apps
powershell -NoProfile -ExecutionPolicy Bypass -File installer\Install-DevOptimizer.ps1

# run (launcher starts the C# shell)
DevOptimizer            # Start menu, or:
D:\DevOptimizer\app\bin\DevOptimizer.exe
D:\DevOptimizer\app\bin\DevOptimizer.exe -Category cleanup     # deep links
D:\DevOptimizer\app\bin\DevOptimizer.exe -Settings

# legacy PowerShell UI (migration fallback)
$env:DOAPP_LEGACY = '1'; D:\DevOptimizer\app\bin\DevOptimizer.exe

# headless self-test of the C# shell (no window; SELFTEST PASS/FAIL in the log)
D:\DevOptimizer\app\bin\DevOptimizer.App.exe --selftest

# remove (per user)
powershell -NoProfile -ExecutionPolicy Bypass -File installer\Uninstall-DevOptimizer.ps1
```

## Components

| Component | Where |
|---|---|
| C# WPF shell — MVVM, DI host, virtualized command list, detail panel, parameter grid | `DevOptimizer.App` (primary UI) |
| Out-of-process runner — same artifacts and done-file protocol as `Start-HubRun` | `DevOptimizer.App` `CommandRunnerService` |
| Settings parity — same keys/defaults/valid sets, `config\app-settings.json` | `DevOptimizer.App` `SettingsService` ↔ AppCore `$script:SettingsSchema` |
| Headless selftest — registry-driven assertions, exit 0/1 | `DevOptimizer.App.exe --selftest` |
| Win 11 chrome — dark titlebar, rounded corners, Mica backdrop (silent fallback) | Legacy app: AppCore `Set-WindowChrome` |
| Single instance — second launch focuses the running window | Legacy app: AppCore `Test-SingleInstance` (named mutex) |
| Toast notifications when long runs (≥ N s, configurable) finish | Legacy app: AppCore `Send-RunCompleteToast` (WinRT, PowerShell AUMID) |
| Taskbar jump list — Health snapshot / Cleanup / Settings | Legacy app startup (`System.Windows.Shell.JumpList`) |
| Launch at Windows startup — per-user Run key toggle | Legacy settings page → AppCore `Set-AutoStart` (HKCU, off by default) |

Deep links accepted by both the C# shell and `DevOptimizer-App.ps1`:
`-Command <name>`, `-Category <name>`, `-Settings` (plus `-RunNow` for the
headless run mode of the C# shell). Each applied deep link logs a `deeplink:`
line to `logs\app-runs\app-debug.log`.

## Tests

```powershell
dotnet test app\DevOptimizer.App.Tests               # C# unit suite (services, viewmodel, selftest engine)
pwsh -NoProfile -File scripts\Test-App.ps1          # or -CI for minimal output
D:\DevOptimizer\app\bin\DevOptimizer.exe --selfcheck # package selfcheck (repo/script/app/forwarded)
D:\DevOptimizer\app\bin\DevOptimizer.App.exe --selftest
```

The Pester suite covers the settings schema/roundtrip/invalid-enum/corrupt-file,
the search filter regression lock (a category name can never match a whole
category via search), autostart set/query/clear against an injected Run key,
single-instance mutex cross-process semantics, launcher selfcheck + argument
forwarding, icon directory structure, HKCU Apps-list registration, Start Menu
shortcut target, embedded XAML well-formedness, and Win 11 component wiring.

The C# shell's UI pipeline is covered by its headless self-test (sidebar
categories, category filter, search semantics, category-exclusion regression,
detail panel structure) — the verdict (`SELFTEST PASS`/`SELFTEST FAIL`) reaches
the process exit code and the `logs\app-runs\app-debug.log` file. The legacy
PowerShell app has its own equivalent:

```powershell
DOAPP_SELFTEST=1 powershell -NoProfile -STA -ExecutionPolicy Bypass -File DevOptimizer-App.ps1
# results: logs\app-runs\app-debug.log
```

## Notes

- The launcher and the C# shell are framework-dependent on .NET 8 desktop
  (present via the installed SDK). `scripts\Build-App.ps1` rebuilds everything
  (icon, launcher exe, ReadyToRun publish of the C# shell); flip
  `SelfContained` in the csproj for a portable (~100 MB) build.
- Everything is per-user: no elevation is required or used at any point.
- The engine (`Execute-Command.ps1`, `config\hub-registry.json`) is unchanged —
  both UIs are presentation layers over the same registry.
