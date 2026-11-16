"""NextCloud desktop client fine-tune status (port of fine-tune-nextcloud.ps1).

Read-only Windows 11 integration health view: client, server URL, sync
mode, bounded VFS placeholder sample, cldflt, autostart, Defender
exclusions, data footprint. --apply-safe-tuning self-elevates and adds
Defender path/process exclusions + cldflt auto-start.
"""

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: nextcloud, tuning, defender


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--apply-safe-tuning", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    ps = (
        "$ErrorActionPreference = 'SilentlyContinue'; "
        "$clientExe = Join-Path $env:ProgramFiles 'Nextcloud\\nextcloud.exe'; "
        "if (-not (Test-Path $clientExe)) { Write-Error 'client not found'; exit 1 }; "
        "$out = [ordered]@{}; "
        "$out.client = @{ exe = $clientExe; "
        "  version = (Get-Item $clientExe).VersionInfo.FileVersion; "
        "  running = [bool](Get-Process nextcloud | Select-Object -First 1) }; "
        "$cfgPath = Join-Path $env:APPDATA 'NextCloud\\nextcloud.cfg'; "
        "$cfg = @{}; "
        "if (Test-Path $cfgPath) { "
        "  foreach ($l in (Get-Content $cfgPath)) { "
        "    if ($l -match 'localPath=') { $cfg.localPath = $l -replace '^.*?localPath=','' } "
        "    if ($l -match '0\\\\url=') { $cfg.url = $l -replace '^.*?0\\\\url=','' } "
        "    if ($l -match 'virtualFilesMode=') { $cfg.vfs = $l -replace '^.*?virtualFilesMode=','' } "
        "    if ($l -match '^isVfsEnabled=') { $cfg.vfsGen = $l -replace '^isVfsEnabled=','' } "
        "    if ($l -match 'moveToTrash=') { $cfg.trash = $l -replace '^moveToTrash=','' } "
        "    if ($l -match 'newBigFolderSizeLimit=') { $cfg.big = $l -replace '^.*?newBigFolderSizeLimit=','' } "
        "    if ($l -match 'networkUploadLimitSetting=') { $cfg.up = $l -replace '^.*?networkUploadLimitSetting=','' } "
        "    if ($l -match 'networkDownloadLimitSetting=') { $cfg.down = $l -replace '^.*?networkDownloadLimitSetting=','' } } }; "
        "$syncRoot = $cfg.localPath; "
        "if (-not $syncRoot) { $syncRoot = Join-Path $env:USERPROFILE 'Nextcloud' }; "
        "$syncRoot = $syncRoot.TrimEnd('/'); $cfg.syncRoot = $syncRoot; $out.cfg = $cfg; "
        "$top = @(); $ph = 0; $local = 0; $sample = @(); "
        "if (Test-Path $syncRoot) { "
        "  $top = @(Get-ChildItem $syncRoot -Force); "
        "  $sample = @($top | ForEach-Object { "
        "    if ($_.PSIsContainer) { Get-ChildItem $_.FullName -Force -File } else { $_ } } "
        "    | Select-Object -First 300); "
        "  $ph = ($sample | Where-Object { $_.Attributes -match 'Offline|RecallOnDataAccess|Sparse' }).Count; "
        "  $local = $sample.Count - $ph }; "
        "$out.sync = @{ top = $top.Count; sample = $sample.Count; "
        "  placeholders = $ph; local = $local }; "
        "$svc = Get-Service cldflt; "
        "$out.cldflt = if ($svc) { @{ status = [string]$svc.Status; start = [string]$svc.StartType } } else { $null }; "
        "$run = Get-ItemProperty 'HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run'; "
        "$out.autostart = ($run.PSObject.Properties.Name -contains 'Nextcloud'); "
        "$isAdmin = ([Security.Principal.WindowsPrincipal]"
        "[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("
        "[Security.Principal.WindowsBuiltInRole]::Administrator); "
        "$out.admin = $isAdmin; "
        "if ($isAdmin) { $mp = Get-MpPreference; "
        "  $out.exPaths = $mp.ExclusionPath; $out.exProcs = $mp.ExclusionProcess }; "
        "$out.dirs = @((Join-Path $env:APPDATA 'NextCloud'),"
        "             (Join-Path $env:LOCALAPPDATA 'Nextcloud')) | "
        "  ForEach-Object { if (Test-Path $_) { @{ path=$_; "
        "    mb=[math]::Round(((Get-ChildItem $_ -Recurse -File -Force | "
        "    Measure-Object Length -Sum).Sum / 1MB),1) } } }; "
    )
    dry_flag = "$true" if args.dry_run else "$false"
    tune_flag = "$true" if args.apply_safe_tuning else "$false"
    self_ps1 = str(Path(__file__).resolve().parent.parent
                   / "fine-tune-nextcloud.ps1").replace("/", "\\")
    ps += (
        f"$dry = {dry_flag}; "
        f"if ({tune_flag}) {{ "
        "  if (-not $isAdmin) { "
        f"    Start-Process powershell -Verb RunAs -Wait -ArgumentList @('-NoProfile','-File','{self_ps1}','-ApplySafeTuning'); "
        "    exit 0 }; "
        "  if (-not $dry) { "
        "    Add-MpPreference -ExclusionPath @($syncRoot,"
        "      (Join-Path $env:LOCALAPPDATA 'Nextcloud'),"
        "      (Join-Path $env:APPDATA 'NextCloud')); "
        "    Add-MpPreference -ExclusionProcess 'nextcloud.exe'; "
        "    sc.exe config cldflt start= auto | Out-Null; "
        "    $out.tuning = 'applied' } "
        "  else { $out.tuning = 'dry-run' } }; "
        "$out | ConvertTo-Json -Depth 4"
    )

    result = asyncio.run(run_ps_command(ps, timeout=180))
    if result.returncode != 0:
        print(result.stderr.strip() or "fine-tune check failed", file=sys.stderr)
        sys.exit(result.returncode)

    raw = result.stdout.strip()
    try:
        report = json.loads(raw[raw.index("{"):])
    except (ValueError, json.JSONDecodeError):
        report = {"raw": raw}

    if args.json:
        print(json.dumps(report, indent=2))
        return

    print("=== NextCloud Fine-Tune ===")
    c = report.get("client", {})
    print(f"[1] Client: v{c.get('version','?')} "
          f"({'running' if c.get('running') else 'not running'})")
    cfg = report.get("cfg", {})
    print(f"[2] Server: {cfg.get('url')}  Folder: {cfg.get('syncRoot')} "
          f"(vfs {cfg.get('vfs')}, general {cfg.get('vfsGen')})")
    s = report.get("sync", {})
    print(f"[3] Sync root: {s.get('top')} top entries; sample {s.get('sample')} "
          f"-> {s.get('local')} local / {s.get('placeholders')} placeholders")
    cd = report.get("cldflt")
    print(f"[4] cldflt: {cd['status']}/{cd['start'] if cd else 'not present'}")
    print(f"[5] Autostart: {'registered' if report.get('autostart') else 'NOT registered'}")
    if report.get("admin"):
        print(f"[6] Defender paths: {report.get('exPaths')}")
        print(f"    Defender procs: {report.get('exProcs')}")
    else:
        print("[6] Defender: elevated read required")
    for d in report.get("dirs") or []:
        print(f"[7] {d['path']} = {d['mb']} MB")
    if report.get("tuning"):
        print(f"[T] tuning: {report['tuning']}")


if __name__ == "__main__":
    main()
