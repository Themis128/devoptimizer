"""Enhanced event-log checker (Python port of enhanced-event-log-checker.ps1).

Analyzes recent System/Application/Security events over a look-back
window; summarizes critical/warning/info counts, top samples with
--detailed, and exports an HTML report with --export-report.
Read-only unless exporting.
"""

import argparse
import asyncio
import html
import json
import sys
import time
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.winops import run_ps_command  # noqa: E402

# CATEGORY: utilities
# TAGS: eventlog, diagnostics, health


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--hours", type=int, default=24)
    parser.add_argument("--detailed", action="store_true")
    parser.add_argument("--export-report", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    ps = (
        f"$start = (Get-Date).AddHours(-{args.hours}); "
        "$out = [ordered]@{ system = @{ computer = $env:COMPUTERNAME; "
        "  user = $env:USERNAME; time = (Get-Date).ToString('u') }; "
        "logs = @{} }; "
        "foreach ($log in @('System','Application','Security')) { "
        "  $ev = @(Get-WinEvent -FilterHashtable @{LogName=$log; "
        "    StartTime=$start} -ErrorAction SilentlyContinue); "
        "  $crit = @($ev | Where-Object LevelDisplayName -eq 'Critical'); "
        "  $err  = @($ev | Where-Object LevelDisplayName -eq 'Error'); "
        "  $warn = @($ev | Where-Object LevelDisplayName -eq 'Warning'); "
        "  $info = @($ev | Where-Object LevelDisplayName -eq 'Information'); "
        "  $samples = @($err + $crit | Sort-Object TimeCreated -Descending | "
        "    Select-Object -First 10 | ForEach-Object { @{ "
        "      time = $_.TimeCreated.ToString('s'); level = $_.LevelDisplayName; "
        "      id = $_.Id; provider = $_.ProviderName; "
        "      msg = (($_.Message -split \"`n\")[0]) } }); "
        "  $out.logs[$log] = @{ total = $ev.Count; critical = $crit.Count; "
        "    errors = $err.Count; warnings = $warn.Count; info = $info.Count; "
        "    samples = $samples } }; "
        "$out | ConvertTo-Json -Depth 5"
    )

    result = asyncio.run(run_ps_command(ps, timeout=180))
    if result.returncode != 0:
        print(result.stderr.strip() or "event log query failed",
              file=sys.stderr)
        sys.exit(result.returncode)

    raw = result.stdout.strip()
    report = json.loads(raw[raw.index("{"):]) if "{" in raw else {}

    if args.json:
        print(json.dumps(report, indent=2))
        return

    s = report.get("system", {})
    print("Enhanced Event Log Analysis")
    print(f"Computer: {s.get('computer')}  User: {s.get('user')}  "
          f"Window: {args.hours}h\n")
    total_crit = total_err = 0
    for log, d in (report.get("logs") or {}).items():
        total_crit += d.get("critical", 0)
        total_err += d.get("errors", 0)
        print(f"{log}: {d.get('total')} events — {d.get('critical')} critical, "
              f"{d.get('errors')} errors, {d.get('warnings')} warnings, "
              f"{d.get('info')} info")
        if args.detailed:
            for e in d.get("samples", []):
                print(f"  [{e['time']}] {e['level']} id={e['id']} "
                      f"{e['provider']}: {e['msg'][:100]}")

    verdict = ("Critical" if total_crit else
               ("Warning" if total_err else "Good"))
    print(f"\nOverall: {verdict} ({total_crit} critical, {total_err} errors)")

    if args.export_report:
        path = Path(f"event-log-report-{time.strftime('%Y%m%d-%H%M%S')}.html")
        rows = "".join(
            f"<tr><td>{html.escape(log)}</td><td>{d['total']}</td>"
            f"<td>{d['critical']}</td><td>{d['errors']}</td>"
            f"<td>{d['warnings']}</td><td>{d['info']}</td></tr>"
            for log, d in (report.get("logs") or {}).items())
        path.write_text(
            "<html><body><h1>Event Log Analysis</h1>"
            f"<p>{html.escape(str(s.get('computer')))} — {args.hours}h window</p>"
            "<table border='1'><tr><th>Log</th><th>Total</th><th>Critical</th>"
            "<th>Errors</th><th>Warnings</th><th>Info</th></tr>"
            f"{rows}</table><h2>Verdict: {verdict}</h2></body></html>",
            encoding="utf-8")
        print(f"report: {path.resolve()}")


if __name__ == "__main__":
    main()
