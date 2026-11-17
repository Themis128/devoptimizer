"""DevOptimizer MCP server (port of
scripts/mcp-devoptimizer-server.ps1).

JSON-RPC 2.0 / MCP 2024-11-05 over stdio. Methods: initialize,
tools/list, tools/call, notifications/*. Delegates each tool to its
existing PowerShell script under D:\\DevOptimizer\\scripts.
"""

import json
import subprocess
import sys
from pathlib import Path

# CATEGORY: utilities
# TAGS: mcp, json-rpc, devin, tools

MCP_VERSION = "2024-11-05"
DEV = Path(r"D:\DevOptimizer\scripts")

TOOLS = [
    {"name": "devin_health",
     "description": "Quick Devin Desktop health check (WSL, "
                    "devin-server, memory, bundles)",
     "inputSchema": {"type": "object", "properties": {
         "repair": {"type": "boolean",
                    "description": "Auto-repair if issues found"}}}},
    {"name": "devin_diagnostics",
     "description": "Deep Devin diagnostics (app version, commit dirs, "
                    "logs, error signatures)",
     "inputSchema": {"type": "object", "properties": {
         "outfile": {"type": "string",
                     "description": "Optional JSON output file "
                                    "path"}}}},
    {"name": "devin_doctor",
     "description": "Run community devin-doctor check (stores, schema, "
                    "config, disk)",
     "inputSchema": {"type": "object", "properties": {
         "skipInstall": {"type": "boolean",
                         "description": "Skip auto-install of "
                                        "devin-doctor"},
         "jsonOnly": {"type": "boolean",
                      "description": "Output only JSON"}}}},
    {"name": "devin_maintenance",
     "description": "Run daily maintenance (cache sweep, log "
                    "retention, bundle cleanup)",
     "inputSchema": {"type": "object", "properties": {
         "logRetentionDays": {"type": "integer", "default": 14},
         "reportRetentionDays": {"type": "integer", "default": 30}}}},
    {"name": "devin_repair",
     "description": "Repair Devin (bundles, leftovers, server logs)",
     "inputSchema": {"type": "object", "properties": {
         "fixBundle": {"type": "boolean"},
         "cleanLeftovers": {"type": "boolean"},
         "pruneServerLogs": {"type": "boolean"},
         "days": {"type": "integer", "default": 14},
         "force": {"type": "boolean"}}}},
    {"name": "devin_cleanup_acp",
     "description": "Prune ACP session messages",
     "inputSchema": {"type": "object", "properties": {
         "days": {"type": "integer", "default": 14}}}},
    {"name": "devin_tune_windows",
     "description": "Tune Windows for Devin (priority, startup, "
                    "Defender exclusions)",
     "inputSchema": {"type": "object", "properties": {
         "priority": {"type": "string"},
         "registerStartup": {"type": "boolean"},
         "defenderExclusions": {"type": "boolean"}}}},
]


def run_ps(script, *params):
    r = subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", str(script), *[str(x) for x in params]],
        capture_output=True, text=True, errors="replace")
    return (r.stdout + r.stderr).strip()


def call_tool(name, a):
    a = a or {}
    if name == "devin_health":
        return run_ps(DEV / "devin" / "Check-DevinHealth.ps1",
                      *(["-Repair"] if a.get("repair") else []))
    if name == "devin_diagnostics":
        p = []
        if a.get("outfile"):
            # Constrain diagnostics output to the DevOptimizer tree -
            # the MCP client controls this value and the server may
            # run elevated.
            resolved = Path(a["outfile"])
            if not resolved.is_absolute():
                resolved = (DEV / resolved)
            try:
                resolved.resolve().relative_to(DEV.resolve())
            except ValueError:
                return ("ERROR: outfile must be inside "
                        f"{DEV}")
            p = ["-OutFile", str(resolved)]
        return run_ps(DEV / "devin" / "Get-DevinDiagnostics.ps1", *p)
    if name == "devin_doctor":
        p = ((["-SkipInstall"] if a.get("skipInstall") else []) +
             (["-JsonOnly"] if a.get("jsonOnly") else []))
        return run_ps(DEV / "devin" / "Check-DevinDoctor.ps1", *p)
    if name == "devin_maintenance":
        return run_ps(
            DEV / "devin" / "Invoke-DevinDailyMaintenance.ps1",
            "-LogRetentionDays", a.get("logRetentionDays", 14),
            "-ReportRetentionDays", a.get("reportRetentionDays", 30))
    if name == "devin_repair":
        p = ((["-FixBundle"] if a.get("fixBundle") else []) +
             (["-CleanLeftovers"] if a.get("cleanLeftovers") else []) +
             (["-PruneServerLogs"] if a.get("pruneServerLogs") else []) +
             ["-Days", a.get("days", 14)] +
             (["-Force"] if a.get("force") else []))
        return run_ps(DEV / "devin" / "Repair-Devin.ps1", *p)
    if name == "devin_cleanup_acp":
        return run_ps(DEV / "prune-acp.ps1", "-Days",
                      a.get("days", 14))
    if name == "devin_tune_windows":
        p = ((["-Priority", a["priority"]] if a.get("priority")
              else []) +
             (["-RegisterStartup"] if a.get("registerStartup") else []) +
             (["-DefenderExclusions"] if a.get("defenderExclusions")
              else []))
        return run_ps(DEV / "devin" / "Tune-Windows-For-Devin.ps1", *p)
    raise ValueError(f"Unknown tool: {name}")


def respond(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue
        mid = req.get("id")
        method = req.get("method", "")
        if mid is None:  # notification
            continue
        if method == "initialize":
            respond({"jsonrpc": "2.0", "id": mid, "result": {
                "protocolVersion": MCP_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "devoptimizer",
                               "version": "1.0.0"}}})
        elif method == "tools/list":
            respond({"jsonrpc": "2.0", "id": mid,
                     "result": {"tools": TOOLS}})
        elif method == "tools/call":
            params = req.get("params", {})
            try:
                text = call_tool(params.get("name"),
                                 params.get("arguments"))
                respond({"jsonrpc": "2.0", "id": mid, "result": {
                    "content": [{"type": "text", "text": text}]}})
            except Exception as e:
                respond({"jsonrpc": "2.0", "id": mid,
                         "error": {"code": -32603,
                                   "message": str(e)}})
        else:
            respond({"jsonrpc": "2.0", "id": mid,
                     "error": {"code": -32601,
                               "message": f"Method not found: "
                                          f"{method}"}})


if __name__ == "__main__":
    main()
