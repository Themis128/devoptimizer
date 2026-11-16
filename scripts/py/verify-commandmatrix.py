"""Port of scripts/Verify-CommandMatrix.ps1.

Static command-matrix validation over config/hub-registry.json:
  1. registry path resolves to a file
  2. entryPoint matches file extension
  3. ps1 files parse (via powershell AST check)
  4. requiresAdmin <-> #Requires -RunAsAdministrator (both dirs)
  5. cmd/python entryPoints must not carry registry params
  6. registry params must exist in the script param block
  7. script Mandatory params must appear in the registry
Exit 1 when any ERROR finding; -Quiet suppresses per-finding
output; -JsonReport writes a JSON report.
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path("D:/DevOptimizer")
REGISTRY = ROOT / "config" / "hub-registry.json"
LOG = ROOT / "logs" / "app-runs" / "command-matrix.log"
EXT_MAP = {"powershell": [".ps1"], "cmd": [".bat", ".cmd"],
           "python": [".py"]}

findings = []
quiet = False


def add(level, cmd, check, detail):
    findings.append({"Level": level, "Command": cmd,
                     "Check": check, "Detail": detail})
    if not quiet:
        print(f"[{level:<5}] {cmd}: {check} - {detail}")
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"[{datetime.now():%Y-%m-%d %H:%M:%S}] "
                    f"[{level}] {cmd}: {check} - "
                    f"{detail}\n")
    except OSError:
        pass


def ps_parse_and_params(path):
    """Return (parse_ok, params, mandatory_set) using a
    PowerShell AST probe."""
    ps = (
        "$e=$null;"
        f"$a=[System.Management.Automation.Language.Parser]"
        f"::ParseFile('{path}',[ref]$null,[ref]$e);"
        "if ($e.Count -gt 0) { 'PARSE_ERR|' + $e[0].Message"
        " + '|' + $e[0].Extent.StartLineNumber } else {"
        "  $a.ParamBlock.Parameters | ForEach-Object {"
        "    $m=$false;"
        "    foreach ($t in $_.Attributes) {"
        "      foreach ($n in $t.NamedArguments) {"
        "        if ($n.ArgumentName -eq 'Mandatory' -and"
        "            $n.Argument.Expression.Value) { $m=$true } } }"
        "    $_.Name.VariablePath.UserPath + '|' + $m } }")
    try:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps],
            capture_output=True, text=True, timeout=60)
    except Exception:
        add("WARN", str(path), "parse-probe",
            "powershell probe failed/timed out")
        return False, [], set()
    out = (r.stdout or "").strip()
    if out.startswith("PARSE_ERR|"):
        parts = out.split("|", 2)
        add("ERROR", str(path), "parse",
            f"{parts[1]} @ line "
            f"{parts[2] if len(parts) > 2 else '?'}")
        return False, [], set()
    params = []
    mandatory = set()
    for line in out.splitlines():
        if "|" in line:
            name, m = line.rsplit("|", 1)
            params.append(name.strip())
            if m.strip() == "True":
                mandatory.add(name.strip())
    return True, params, mandatory


def main():
    global quiet
    ap = argparse.ArgumentParser()
    ap.add_argument("-JsonReport", default="")
    ap.add_argument("-Quiet", action="store_true")
    a = ap.parse_args()
    quiet = a.Quiet

    registry = json.loads(REGISTRY.read_text(
        encoding="utf-8-sig"))
    commands = registry["commands"]
    parse_count = 0

    for c in commands:
        name = c["name"]
        path = ROOT / c["path"].replace("/", "\\")
        if not path.is_file():
            add("ERROR", name, "path",
                f"registry path not found: {c['path']}")
            continue
        ext = path.suffix.lower()

        expected = EXT_MAP.get(c.get("entryPoint"))
        if expected and ext not in expected:
            add("ERROR", name, "entrypoint",
                f"entryPoint '{c['entryPoint']}' does not "
                f"match extension '{ext}'")

        params, mandatory = [], set()
        if ext == ".ps1":
            ok, params, mandatory = \
                ps_parse_and_params(path)
            if ok:
                parse_count += 1

        head = path.read_text(
            encoding="utf-8-sig",
            errors="replace").splitlines()[:30]
        has_runas = any(re.search(
            r"#Requires\s+-RunAsAdministrator", h,
            re.IGNORECASE)
            for h in head)
        if c.get("requiresAdmin") and not has_runas:
            add("WARN", name, "admin-flag",
                "registry says requiresAdmin but script "
                "lacks #Requires -RunAsAdministrator "
                "(elevation handled by Execute-Command)")
        if (not c.get("requiresAdmin")) and has_runas:
            add("ERROR", name, "admin-flag",
                "script has #Requires -RunAsAdministrator"
                " but registry lacks requiresAdmin - "
                "would fail instantly at execute")

        reg_params = c.get("parameters") or []
        if reg_params and c.get("entryPoint") in (
                "cmd", "python"):
            add("WARN", name, "param-format",
                f"entryPoint '{c['entryPoint']}' has "
                "registry params - Execute-Command emits "
                "PS-style -Name:Value args that "
                f"'{c['entryPoint']}' interpreters reject")
        if ext == ".ps1" and params:
            pset = set(params)
            for rp in reg_params:
                if rp["name"] not in pset:
                    add("WARN", name, "param",
                        f"registry param '{rp['name']}' "
                        "not in script param block - app "
                        "dialog offers a dead parameter")
            reg_names = {rp["name"] for rp in reg_params}
            for pn in mandatory:
                if pn not in reg_names:
                    add("ERROR", name, "param",
                        f"script Mandatory param '{pn}' "
                        "missing from registry - execute "
                        "fails 'Required parameter "
                        "missing'")

    errors = [f for f in findings
              if f["Level"] == "ERROR"]
    warns = [f for f in findings
             if f["Level"] == "WARN"]
    if not quiet:
        print()
        print(f"Matrix: {len(commands)} commands | "
              f"parse-checked {parse_count} ps1 | "
              f"{len(errors)} ERROR, {len(warns)} WARN")
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"[SUMMARY] {len(commands)} commands, "
                    f"{parse_count} ps1 parsed, "
                    f"{len(errors)} ERROR, "
                    f"{len(warns)} WARN\n")
    except OSError:
        pass

    if a.JsonReport:
        report = {
            "date": datetime.now().isoformat(),
            "total": len(commands),
            "parseChecked": parse_count,
            "errors": len(errors),
            "warns": len(warns),
            "findings": findings}
        Path(a.JsonReport).write_text(
            json.dumps(report, indent=2),
            encoding="utf-8")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
