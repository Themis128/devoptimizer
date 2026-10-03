# Forge Plan: DevOptimizer Win11 app — target architecture & Phase-1 optimization

**Date:** 2026-09-28 (generation 4 — revised after critic rounds 1-3)
**Requested by:** user ("create the architecture of the win 11 app based to websearch, github repo search and best practices. We must optimize it")

## Goal

Replace the fragile PowerShell/WPF shell with a typed .NET WPF application (MVVM, compiled XAML, DI) while keeping the proven PowerShell command engine untouched — cutting startup cost and eliminating the XamlReader/PS-5.1 fragility class, on a phased strangler-fig path.

## Research basis (web + GitHub, Sep 2026)

- **WPF vs WinUI 3:** Microsoft recommends WinUI 3 + Windows App SDK for *new* native apps, but the 2026 practitioner consensus is that WPF remains the safer, more mature choice for modernization-in-place; WinUI 3's ecosystem/tooling is still behind and apps ship larger. Sources: [Microsoft Learn](https://learn.microsoft.com), [WinUI vs WPF in 2026 (ctco.blog)](https://www.ctco.blog), [platform.uno modernization guidance](https://platform.uno), [sviluppatoremigliore.com](https://sviluppatoremigliore.com).
- **Packaging/updates:** Velopack is the 2026 default for per-user .NET apps needing delta auto-updates without Store constraints; MSIX fits Store/enterprise scenarios; ClickOnce is dated. Sources: [Top 7 desktop app frameworks 2026 (teamdev.com)](https://teamdev.com), [MSI vs MSIX vs ClickOnce (comcomponent.com)](https://comcomponent.com), [Velopack integration example (wiki.generalshub.com)](https://wiki.generalshub.com).
- **Reference architectures:** [CommunityToolkit/MVVM-Samples](https://github.com/CommunityToolkit/MVVM-Samples), [CommunityToolkit/dotnet](https://github.com/communitytoolkit/dotnet), [stevsharp/MVVMCleanArchitecture](https://github.com/stevsharp/MVVMCleanArchitecture), [microsoft/TemplateStudio](https://github.com/microsoft/TemplateStudio) (WPF MVVM project type), [MVVM Toolkit docs](https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm).

## Architecture (target)

**Layering (Clean Architecture, feature-sliced):**

```
D:\DevOptimizer\  (repo root)
  DevOptimizer.App.ps1 → DevOptimizer-App.ps1   KEPT untouched this generation (fallback UI +
                                                Pester subject); 1070-line PS/WPF monolith
  devoptimizer.ps1, Execute-Command.ps1         UNTOUCHED — the engine IS the product (349 cmds)
  Build-Registry.ps1, Discover-Scripts.ps1      UNTOUCHED this generation (producer fix = Phase 3)
  config/hub-registry.json                      UNCHANGED FORMAT — typed loader replaces
                                                hand-rolled parsing (UTF-8 BOM: tolerate)
  app/
    DevOptimizer.App/            NEW — C# WPF shell (net8.0-windows), the only new UI
      App.xaml(.cs)              Generic Host + DI + global exception handler + arg parsing +
                                 repo-root discovery (walk up to the dir containing
                                 config\hub-registry.json — works from any build output dir)
      app.manifest               PerMonitorV2 DPI awareness
      Views/                     MainWindow + detail/settings (compiled BAML — no XamlReader)
      ViewModels/                MainViewModel, CommandItemViewModel (this generation);
                                 SettingsViewModel + settings/detail views (Phase 2+)
                                 (ObservableObject/RelayCommand from CommunityToolkit.Mvvm)
      Services/                  RegistryService      — typed load of config/hub-registry.json;
                                                       search = name/description/path/tags,
                                                       category EXCLUDED (regression-locked:
                                                       AppCore.psm1:86-97, AppCore.Tests:108)
                                 CommandRunnerService — out-of-process powershell.exe runner that
                                                       calls Execute-Command.ps1 (engine boundary
                                                       UNCHANGED), per-run artifacts identical to
                                                       Start-HubRun (DevOptimizer-App.ps1:325),
                                                       elevation via requiresAdmin metadata
                                                       (ShellExecute runas), interactive-.bat
                                                       detection (set /p | choice | pause)
                                 SettingsService      — same schema/keys/file as AppCore
                                                       (config/app-settings.json; key
                                                       `defaultDryRun`, not `dryRunDefault`)
                                 ToastService, JumpListService (Phase 2+), LogService (same
                                 logs\app-runs\app-debug.log line formats: checkpoint:/
                                 selftest:/deeplink:)
      Models/                    CommandDefinition (incl. tags + metadata), RegistrySnapshot,
                                 AppSettings (typed)
    DevOptimizer.App.Tests/      NEW — xUnit unit tests (services, viewmodel logic)
    launcher/                    KEPT — DevOptimizer.exe gains exe identity + forwards to
                                 DevOptimizer.App.exe; DOAPP_LEGACY=1 falls back to the old
                                 PowerShell app during migration
```

**Decisions:**

- **D1 — Strangler, not rewrite:** the 349-script PowerShell engine stays out-of-process; only the shell is replaced. A runner contract identical to `Start-HubRun` (DevOptimizer-App.ps1:325) keeps behavior byte-compatible: same per-run artifact names (`run-<cmd>-<stamp>.{log,done,params}.txt/json`, `runner.ps1`), same `Execute-Command.ps1 -Command <name> -Parameters <hashtable> [-DryRun]` invocation (hashtable deserialized from the params JSON), same done-file `exitOk=… code=…` protocol.
- **D2 — WPF (not WinUI 3):** maturity wins for a modernization-in-place of a working app; WinUI 3 re-evaluated only if Fluent UI becomes a hard requirement (Phase 3+).
- **D3 — Compiled XAML + MVVM + DI:** eliminates the `XamlReader::Parse` + manual `x:Name` mapping class (DevOptimizer-App.ps1:786-794) and the PS 5.1 strict-mode/hashtable fragility recorded in tests; `ObservableObject`/`RelayCommand` from CommunityToolkit.Mvvm.
- **D4 — Registry consumed typed; producer fixed separately:** root cause of the nondeterminism/file-mode breakage is localized to `Build-Registry.ps1:58-82` (file-mode loads a JSON shape that no longer matches inline discovery, yielding 0 commands). Fixing the producer is its own later generation; this generation only freezes the CONSUMER contract (schema-valid JSON, 349 commands).
- **D5 — Packaging stays per-user PS installer this generation; Velopack adopted in Phase 3** for delta auto-updates (no Store dependency, `vpk` CLI flow). No MSIX (no Store/enterprise need, would require signing infrastructure).
- **D6 — Self-test parity is a gate:** `DevOptimizer.App.exe --selftest` runs the same registry-driven assertions headless and exits 0, so the existing harness and Pester suite keep functioning during and after the migration.

## Tech Stack

net8.0-windows (SDK 8.0.424 installed; WindowsDesktop 10.0.x runtimes present and compatible), WPF, CommunityToolkit.Mvvm 8.x, Microsoft.Extensions.Hosting (DI), System.Text.Json (BOM-tolerant load), xUnit; ReadyToRun publish via `scripts/Build-App.ps1`; launcher stays .NET 8 single-file.

## Work Scope

**In:** Phase-1 vertical slice — C# shell that lists/searches/runs all 349 commands with parity (filters with the regression-locked search semantics, detail panel, elevated/dry-run, deep links, self-test, logging), unit-tested services, launcher rewire, build integration.
**Out (later generations):** settings UI parity overlay, jump list + toast services wiring into UI, registry producer determinism fix (D4), Velopack packaging (D5), PS app removal, WinUI 3 evaluation, MSIX/signing.

## Verification Strategy

Level: **e2e for the slice + unchanged legacy suites.**
- `dotnet build app/DevOptimizer.App` and `dotnet test app/DevOptimizer.App.Tests` — unit + build gate.
- `app\bin\DevOptimizer.exe --selfcheck` (exit 0) and the App exe `--selftest` (exit 0, `SELFTEST PASS` in `logs\app-runs\app-debug.log`) — runtime parity gate (interactive session required).
- `pwsh -NoProfile -File scripts\Test-App.ps1` — legacy Pester suite must stay 37/37 (PS app untouched; launcher selfcheck output stays byte-compatible with the assertions in `tests/app/AppPackage.Tests.ps1`).
- `powershell -NoProfile -ExecutionPolicy Bypass -File validate-all-scripts.ps1` — repo-wide syntax gate.

### Task 1: C# WPF project skeleton
**Goal:** A building .NET 8 WPF project with DI host, manifest, repo-root discovery, and a minimal window.
**Dependencies:** None
**Files:**
- Create: `app/DevOptimizer.App/DevOptimizer.App.csproj`
- Create: `app/DevOptimizer.App/App.xaml`
- Create: `app/DevOptimizer.App/App.xaml.cs`
- Create: `app/DevOptimizer.App/app.manifest`
- Create: `app/DevOptimizer.App/Views/MainWindow.xaml`
- Create: `app/DevOptimizer.App/Views/MainWindow.xaml.cs`
**Acceptance Criteria:**
- [ ] `dotnet build app/DevOptimizer.App -c Release` exits 0 with zero errors.
- [ ] csproj targets net8.0-windows, UseWPF=true, references CommunityToolkit.Mvvm and Microsoft.Extensions.Hosting; app.manifest declares PerMonitorV2 DPI awareness.
- [ ] App.xaml.cs locates the repo root by walking up from AppContext.BaseDirectory to the first directory containing `config\hub-registry.json`, parses `args` into a record, and shows MainWindow via DI (no XamlReader anywhere in the project).
- [ ] App.xaml.cs registers a global `DispatcherUnhandledException` handler that appends the exception summary to `logs\app-runs\app-debug.log` and sets `Handled=true`; verified by grep of the built source (behavior exercised by ExceptionHandlerTests.cs created in Task 2).
**Step 1:** Verify with `dotnet build app/DevOptimizer.App -c Release`; exit 0 and no `XamlReader` token anywhere under `app/DevOptimizer.App/`.

### Task 2: Typed models + RegistryService
**Goal:** Typed, testable load/filter/search of the existing registry JSON with the regression-locked search semantics.
**Dependencies:** Task 1
**Files:**
- Create: `app/DevOptimizer.App/Models/CommandDefinition.cs`
- Create: `app/DevOptimizer.App/Models/RegistrySnapshot.cs`
- Create: `app/DevOptimizer.App/Services/RegistryService.cs`
- Create: `app/DevOptimizer.App.Tests/DevOptimizer.App.Tests.csproj`
- Create: `app/DevOptimizer.App.Tests/Fixtures/registry-sample.json`
- Test: `app/DevOptimizer.App.Tests/RegistryServiceTests.cs`
- Test: `app/DevOptimizer.App.Tests/ExceptionHandlerTests.cs`
**Acceptance Criteria:**
- [ ] RegistryService deserializes `config/hub-registry.json` (UTF-8 BOM tolerated — strip before System.Text.Json) into exactly 349 CommandDefinition objects carrying name, path, category, description, requiresAdmin, entryPoint, parameters, tags, metadata.
- [ ] Search = case-insensitive substring across name/description/path/tags with category EXCLUDED, mirroring `Test-CommandFilter` (app/DevOptimizer-AppCore.psm1:86-97): searching `cleanup` returns 16 on live data and MUST NOT return all 61 commands of the cleanup category (regression: AppCore.Tests.ps1:108-109, DevOptimizer-App.ps1:1046-1051).
- [ ] Category filter returns exactly these live counts: utilities 183, cleanup 61, ai-ml 36, maintenance 21, gaming 18, system-optimization 10, development 9, network 4, security 4, monitoring 3 (total 349).
- [ ] `dotnet test` green: correctness tests run against `Fixtures/registry-sample.json` (≥ 6 commands covering all fields, including one whose category name matches another command's description); exactly one integration test reads the live file and asserts the exact count 349 (intentional regression lock per D4 — re-verify the registry before running if the producer ever changes).
- [ ] ExceptionHandlerTests green: invoking the Task 1 handler with a dummy exception appends a line to a temp-scoped debug log and marks the exception handled.
**Step 1:** Run `dotnet test app/DevOptimizer.App.Tests`; all tests green.

### Task 3: SettingsService (schema parity)
**Goal:** Same settings schema, defaults, and file as AppCore.
**Dependencies:** Task 1, Task 2
**Files:**
- Create: `app/DevOptimizer.App/Models/AppSettings.cs`
- Create: `app/DevOptimizer.App/Services/SettingsService.cs`
- Test: `app/DevOptimizer.App.Tests/SettingsServiceTests.cs`
**Acceptance Criteria:**
- [ ] Settings keys, defaults, and valid-value sets match `app/DevOptimizer-AppCore.psm1` `$script:SettingsSchema` exactly (key `defaultDryRun` — regression-locked in the unit test with a comment citing the source lines 28-41).
- [ ] Reads/writes `config/app-settings.json`; missing file yields defaults; invalid values fall back to defaults per key (same semantics as Get-AppSettings lines 45-59).
- [ ] `dotnet test` green.
**Step 1:** Round-trip test writes to a temp dir (never the live config file); run `dotnet test app/DevOptimizer.App.Tests`, all green.

### Task 4: CommandRunnerService (engine boundary parity)
**Goal:** Out-of-process runner byte-compatible with Start-HubRun's contract.
**Dependencies:** Task 2, Task 3
**Files:**
- Create: `app/DevOptimizer.App/Services/CommandRunnerService.cs`
- Test: `app/DevOptimizer.App.Tests/CommandRunnerServiceTests.cs`
**Acceptance Criteria:**
- [ ] Generates per-run artifacts with identical naming: `logs/app-runs/run-<cmd>-<yyyyMMdd-HHmmss>.log.txt`, `.done.txt`, `.params.json`, `runner.ps1`.
- [ ] Runner template sets location to repo root, reads params JSON into a hashtable, invokes `Execute-Command.ps1 -Command <name> -Parameters <hashtable> [-DryRun]`, tees output to the log, writes done-file `exitOk=<bool> code=<int>`; the template text contains the literal `Execute-Command.ps1`.
- [ ] Interactive-batch detection uses Start-HubRun's line-anchored regexes (`(?im)^\s*set\s+/p\b`, `(?im)^\s*choice\s`, `(?im)^\s*pause\b`) and, exactly like Start-HubRun (DevOptimizer-App.ps1:328-331), routes cmd entry points to a visible `cmd.exe /k` window ONLY when NOT dry-run (elevated variant uses runas); PowerShell entry points are never routed to cmd.
- [ ] Elevated PowerShell runs launch the runner via ShellExecute with `Verb="runas"` (matching Start-HubRun's elevated launch, DevOptimizer-App.ps1:400-403); non-elevated runs use the plain hidden spawn; a unit test asserts the built ProcessStartInfo for both paths (Verb, UseShellExecute, window style).
- [ ] `dotnet test` green (pure-function tests for naming/template/detection; no process spawned in unit tests).
**Step 1:** Detection fixtures inline in the test file (one interactive bat text, one clean bat text); `dotnet test` green (serialized after Task 3's gate — same command, never concurrent).

### Task 5: MainViewModel + full shell UI parity
**Goal:** The C# window lists, searches, details, and runs commands like the PS app.
**Dependencies:** Task 2, Task 3, Task 4
**Files:**
- Modify: `app/DevOptimizer.App/Views/MainWindow.xaml`
- Modify: `app/DevOptimizer.App/Views/MainWindow.xaml.cs`
- Create: `app/DevOptimizer.App/ViewModels/MainViewModel.cs`
- Create: `app/DevOptimizer.App/ViewModels/CommandItemViewModel.cs`
- Test: `app/DevOptimizer.App.Tests/MainViewModelTests.cs`
**Acceptance Criteria:**
- [ ] Sidebar lists the 10 categories with the Task 2 counts; the search box's text-change event drives the MainViewModel filter live with the Task 2 semantics (name/description/path/tags, category excluded); command list virtualized; detail panel shows description, path, tags, admin flag, and parameter grid.
- [ ] Run button spawns CommandRunnerService with current parameters; Elevated button present only when requiresAdmin and invokes the elevated runas launch path from Task 4; DryRun checkbox defaults from the `defaultDryRun` setting; output pane polls the run log file until the done-file appears and prints the exit line.
- [ ] ViewModel filter/count logic unit-tested against the Task 2 fixture; `dotnet test` green.
**Step 1:** No XamlReader, no logic in code-behind beyond DI/wiring — enforced by a unit test asserting `Views/MainWindow.xaml.cs` contains no `XamlReader` and no method body over 10 lines; `dotnet test` green.

### Task 6: Deep links, --selftest, logging parity
**Goal:** Headless automation parity with the PS app's observable contract.
**Dependencies:** Task 5
**Files:**
- Modify: `app/DevOptimizer.App/App.xaml.cs`
- Create: `app/DevOptimizer.App/Services/LogService.cs`
- Test: `app/DevOptimizer.App.Tests/SelfTestTests.cs`
**Acceptance Criteria:**
- [ ] `-Command <name>`, `-Category <name>`, `-Settings` args preselect/filter/navigate exactly like the PS deep links; each logs a `deeplink:` line to `logs\app-runs\app-debug.log`. Additionally `-Command <name> -RunNow` is a headless mode: it shows no window, spawns the CommandRunnerService detached runner with the same per-run artifacts, logs a `deeplink:` line, and exits 0 immediately (the run completes asynchronously via the done-file protocol).
- [ ] `--selftest` runs the registry-driven assertions (category filter counts, search counts per Task 2 semantics, detail-panel structure) with no interactive window: it instantiates MainWindow with ShowActivated=false/ShowInTaskbar=false, runs assertions against the loaded visual tree, closes, appends `selftest:` lines and a final `SELFTEST PASS`/`SELFTEST FAIL`, and exits 0/1.
- [ ] LogService emits the same line prefixes the PS app writes via Log-D to `logs\app-runs\app-debug.log` (DevOptimizer-App.ps1:78, :937-1065): `checkpoint: <milestone>` at view-loaded/vm-bound/ui-populated, `selftest: <assertion>` lines, `deeplink: <args>`.
- [ ] `dotnet test` green for the selftest assertion engine against the fixture registry.
**Step 1:** Build then run from the project output dir: `dotnet build app/DevOptimizer.App -c Release` followed by `app/DevOptimizer.App/bin/Release/net8.0-windows/DevOptimizer.App.exe --selftest` — exits 0 with `SELFTEST PASS` appended to the debug log (works from the build dir because Task 1's root discovery walks up to `config\hub-registry.json`).

### Task 7: Launcher rewire + build integration
**Goal:** One exe entry point that starts the C# app; legacy fallback preserved; Pester assertions intact.
**Dependencies:** Task 6
**Files:**
- Modify: `app/launcher/Program.cs`
- Modify: `scripts/Build-App.ps1`
- Modify: `app/README.md`
**Acceptance Criteria:**
- [ ] Launcher launches `DevOptimizer.App.exe` from its own directory and forwards args; with env `DOAPP_LEGACY=1` it launches the PowerShell app exactly as before (both paths verified).
- [ ] `--selfcheck` output PRESERVES the existing lines `repo=…`, `script=… [OK]`, `forwarded=…` verbatim — `script=` and `forwarded=` are the lines actually pinned by tests/app/AppPackage.Tests.ps1 (lines 27 and 39), `repo=` is preserved conservatively — and ADDS an `app=<path> [<status>]` line for the C# exe; exits 0 when all present, 2 when the app exe is missing.
- [ ] `scripts/Build-App.ps1` builds the App project (dotnet publish, ReadyToRun), the launcher, and the icon, copying both exes into `app\bin`; run completes with exit 0 and both exes present.
- [ ] `installer/Install-DevOptimizer.ps1` needs no change (it references only `app\bin\DevOptimizer.exe`, line 23) — verified by grep.
- [ ] `app/README.md` updated to describe the C# shell architecture, the launcher rewire, and the `DOAPP_LEGACY=1` fallback (was: icon + PS-app host only).
**Step 1:** `app\bin\DevOptimizer.exe --selfcheck` exits 0; `pwsh -NoProfile -File scripts\Test-App.ps1` still 37/37 (selfcheck assertions pass unchanged).

### Task 8: Final verification
**Goal:** All gates green, no regressions.
**Dependencies:** Task 7
**Files:**
**Acceptance Criteria:**
- [ ] `dotnet test app/DevOptimizer.App.Tests` all green.
- [ ] `app\bin\DevOptimizer.exe --selfcheck` exit 0; App exe `--selftest` exits 0 with `SELFTEST PASS`.
- [ ] Deep-link smoke: launch with `-Category cleanup`, confirm a fresh `deeplink:` line in `logs\app-runs\app-debug.log` within 10 s, then terminate the app process.
- [ ] `pwsh -NoProfile -File scripts\Test-App.ps1` still 37/37.
- [ ] `powershell -NoProfile -ExecutionPolicy Bypass -File validate-all-scripts.ps1` reports 0 invalid.
- [ ] Real run parity: `DevOptimizer.App.exe -Command win11-health-snapshot -RunNow` exits 0 without showing a window, and within 120 s the newest `logs/app-runs/run-win11-health-snapshot-*.done.txt` exists and contains `exitOk=`.
**Step 1:** Run the six gates above in order; every gate command exits as specified.

## Phase roadmap (NOT this generation)

1. **Phase 2:** settings overlay UI parity, jump list + toast wiring, favorites parity; PS app kept as fallback.
2. **Phase 3:** registry producer determinism fix (single canonical discovery source; repair file-mode drift at Build-Registry.ps1:58-82), Velopack packaging + update channel, PS app removal, optional net10 retarget (SDK install), WinUI 3 re-evaluation only if Fluent is required.

## Critic Responses

**Round 1** (generation 1): feasibility-critic REJECT, integration-critic REJECT, coverage-critic REJECT — 14 findings, all addressed in generation 2 (search contract regression-locked, `defaultDryRun` key, fixture/csproj declared, Task 3→2 edge, Task 6 build-output run, Pester selfcheck pinning, tags/metadata fields, BOM load, hashtable prose, root-level file placement, pinned category counts, selftest mechanism, Task 8 steps, caveat replaced by this section).

**Round 2** (generation 2): feasibility-critic APPROVE, coverage-critic APPROVE, integration-critic REJECT — 1 REJECT-level finding + advisories, addressed in generation 3:

1. **Task 3 ∥ Task 4 build contention** (integration): Task 4 now depends on Task 2, Task 3 — the identical `dotnet test` gates run strictly serialized.
2. **`-not $DryRun` exemption + line-anchored regexes** (integration, advisory): Task 4 AC3 now quotes Start-HubRun's exact regexes and the dry-run exemption at DevOptimizer-App.ps1:328.
3. **`repo=` pin overstatement** (integration + coverage, advisory): Task 7 AC2 now states accurately that only `script=` (line 27) and `forwarded=` (line 39) are pinned; `repo=` preserved conservatively.
4. **Concrete search trigger** (coverage, advisory): Task 5 AC1 names the text-change → ViewModel filter mechanism.

**Round 3** (generation 3): feasibility-critic APPROVE, integration-critic APPROVE, coverage-critic REJECT — 3 REJECT-level findings + advisories, addressed in generation 4:

1. **Headless run mode missing** (coverage): Task 6 AC1 now defines `-Command <name> -RunNow` (no window, spawns the detached runner via the identical done-file protocol, exits 0), and Task 8 AC6 uses it with `win11-health-snapshot` + done-file assertion — the runner's out-of-process contract is now verified end-to-end.
2. **Global exception handler had no task** (coverage): Task 1 AC now requires the `DispatcherUnhandledException` handler (log-append + Handled=true, grep-verified); Task 2 adds `ExceptionHandlerTests.cs` exercising it.
3. **Elevated runas launch uncovered** (coverage): Task 4 gains an AC requiring `Verb="runas"` ShellExecute launch for elevated runs (mirroring DevOptimizer-App.ps1:400-403) with a ProcessStartInfo unit test; Task 5 AC2 wires the Elevated button to that path.
4. **Tree-vs-scope mismatch** (coverage, advisory): SettingsViewModel/settings views and ToastService/JumpListService annotated "(Phase 2+)" in the tree.
5. **Integration test count** (coverage, advisory): Task 2's live integration test now asserts exactly 349 (matching AC1; intentional D4 regression lock).
6. **Log prefix citations** (coverage, advisory): Task 6 AC3 cites Log-D and the exact source lines (:78, :937-1065).
7. **Stale README** (integration, advisory): Task 7 now updates `app/README.md` (declared Modify).
8. **Generation header** (feasibility, advisory): header updated to generation 4.

**Round 1 findings and dispositions (all addressed in generation 2):**

1. **Search contract (all three critics):** Task 2/5/6 and the architecture tree now spec search as name/description/path/tags with category EXCLUDED, mirroring `Test-CommandFilter` (AppCore.psm1:86-97) and the regression locks (AppCore.Tests.ps1:108-109, selftest 1046-1051). The earlier "category-name substrings" clause is removed.
2. **`dryRunDefault` → `defaultDryRun`** (feasibility, integration): Task 5 now uses the real schema key; Task 3 locks it with source-line citation.
3. **Undeclared fixture path** (feasibility): `app/DevOptimizer.App.Tests/Fixtures/registry-sample.json` and the test csproj are now declared in Task 2's Files.
4. **Missing dependency edge** (integration): Task 3 now depends on Task 1, Task 2 (test project exists before its tests gate on it); tasks 2/3 no longer run concurrently.
5. **Task 6 artifact ordering** (integration): Task 6 Step 1 runs the selftest from the project build output (root discovery from Task 1 makes this valid) instead of the not-yet-published `app\bin` copy.
6. **Pester selfcheck pinning** (integration): Task 7 now preserves the pinned selfcheck output lines verbatim and only adds an `app=` line — no test modification required; Task 7 Step 1 re-runs the suite.
7. **tags/metadata fields** (integration): CommandDefinition now includes tags + metadata; Task 5 detail panel consistent.
8. **BOM handling** (integration, advisory): Task 2 mandates BOM-tolerant JSON load.
9. **Runner prose** (integration, advisory): architecture tree now says `-Parameters <hashtable>` (deserialized from JSON).
10. **Repo-root file placement** (coverage, advisory): the tree now correctly places DevOptimizer-App.ps1, devoptimizer.ps1, Execute-Command.ps1, Build-Registry.ps1 at the repo root.
11. **Live per-category counts pinned** (coverage, advisory): Task 2 AC3 pins all ten counts.
12. **Task 6 selftest mechanism** (feasibility, advisory): specified as off-screen window instantiation with visual-tree assertions.
13. **Task 8 steps** (feasibility, advisory): Step markers added.
14. **Stale panel caveat** (feasibility, advisory): replaced by this Critic Responses section.
