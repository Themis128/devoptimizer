"""Dynamic WSL Resource Balancer (port of
scripts/wsl-resource-balancer.ps1).

Monitors WSL /proc/meminfo pressure and applies Docker container
memory limits + restart policies by priority tier (Devin Desktop
priority). --monitor loop, --apply-limits, --reclaim-memory
(echo 3 > drop_caches), --show-status. Mutating; --dry-run.
"""

import argparse
import subprocess
import sys
import time

# CATEGORY: maintenance
# TAGS: wsl, docker, memory, resource-management

TIERS = {
    "Critical": [
        "postgres", "social-postgres", "redis", "social-redis",
        "dmr-lan-proxy", "dmr-watchdog", "portainer",
    ],
    "Important": [
        "n8n", "social-api", "social-api-gateway", "social-frontend",
        "social-worker-default", "social-worker-messenger",
        "social-worker-media", "social-worker-publishing",
        "celery-beat", "browser-novnc", "prometheus", "grafana",
        "alertmanager", "node-exporter", "cadvisor", "minio",
        "chroma", "nextcloud-mcp-server", "stack-ops",
        "n8n-task-runner", "social-metrics", "n8n-metrics",
        "c7099c0d27fc_social-cloudflared",
    ],
    "Optional": [
        "linkedin-browser-sidecar", "tiktok-browser-sidecar",
        "facebook-browser-sidecar", "social-media-comfyui-gpu",
        "languagetool",
    ],
}
TIER_LIMITS = {"Critical": "2g", "Important": "1g",
               "Optional": "512m"}
TIER_RESTART = {"Critical": "always", "Important": "unless-stopped",
                "Optional": "no"}
GB = 2**30


def wsl_meminfo():
    r = subprocess.run(["wsl", "-e", "cat", "/proc/meminfo"],
                       capture_output=True, text=True,
                       errors="replace")
    if r.returncode != 0:
        return None
    info = {}
    for line in r.stdout.splitlines():
        parts = line.replace(":", "").split()
        if len(parts) >= 2 and parts[0][0].isalnum():
            try:
                info[parts[0]] = int(parts[1]) * 1024
            except ValueError:
                pass
    return info


def pressure(args):
    info = wsl_meminfo()
    if not info:
        return None
    total = info.get("MemTotal", 0)
    avail = info.get("MemAvailable") or (
        info.get("MemFree", 0) + info.get("Buffers", 0)
        + info.get("Cached", 0))
    if not total:
        return None
    used = round((total - avail) / total * 100, 1)
    return {
        "totalGB": round(total / GB, 1),
        "freeGB": round(avail / GB, 2),
        "usedPercent": used,
        "isPressure": used >= args.pressure_threshold,
        "isCritical": used >= args.critical_threshold,
        "swapTotalGB": round(info.get("SwapTotal", 0) / GB, 1),
        "swapFreeGB": round(info.get("SwapFree", 0) / GB, 1),
    }


def containers():
    r = subprocess.run(
        ["docker", "ps", "--format",
         "{{.Names}}|{{.ID}}|{{.Status}}|{{.Image}}"],
        capture_output=True, text=True, errors="replace")
    out = []
    for line in r.stdout.splitlines():
        p = line.split("|")
        if len(p) >= 4:
            out.append({"name": p[0].strip(), "id": p[1].strip(),
                        "status": p[2].strip(), "image": p[3].strip()})
    return out


def tier_of(name):
    for tier, names in TIERS.items():
        if name in names:
            return tier
    return "Optional"


def apply_limits(dry):
    for c in containers():
        tier = tier_of(c["name"])
        for cmd in (["docker", "update", f"--memory={TIER_LIMITS[tier]}",
                     c["name"]],
                    ["docker", "update",
                     f"--restart={TIER_RESTART[tier]}", c["name"]]):
            if dry:
                print(f"[dry-run] {' '.join(cmd)}")
            else:
                r = subprocess.run(cmd, capture_output=True, text=True,
                                   errors="replace")
                if r.returncode != 0:
                    print(f"WARN {c['name']}: "
                          f"{r.stderr.strip()[:120]}")


def reclaim(dry):
    print("Reclaiming guest page cache (drop_caches=3)...")
    cmd = ["wsl", "-u", "root", "--", "sh", "-c",
           "sync; echo 3 > /proc/sys/vm/drop_caches"]
    if dry:
        print(f"[dry-run] {' '.join(cmd)}")
    else:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           errors="replace")
        print("reclaim " + ("done" if r.returncode == 0
                            else f"rc={r.returncode}"))


def show_status(args):
    p = pressure(args)
    if p:
        print(f"WSL memory: {p['usedPercent']}% used "
              f"({p['freeGB']}/{p['totalGB']} GB free) | "
              f"swap {p['swapFreeGB']}/{p['swapTotalGB']} GB | "
              f"pressure={p['isPressure']} critical={p['isCritical']}")
    else:
        print("WSL memory: unavailable")
    print(f"{'container':<40} {'tier':<10} {'limit':<6} restart")
    for c in containers():
        t = tier_of(c["name"])
        try:
            r = subprocess.run(
                ["docker", "inspect", "--format",
                 "{{.HostConfig.Memory}} "
                 "{{.HostConfig.RestartPolicy.Name}}", c["name"]],
                capture_output=True, text=True, errors="replace")
            parts = r.stdout.split()
            mem = int(parts[0]) if parts else 0
            actual_mem = (f"{mem // 2**30}g" if mem >= 2**30
                          else ("unlimited" if mem == 0
                                else f"{mem}B"))
            actual_rst = parts[1] if len(parts) > 1 else "?"
        except (OSError, ValueError):
            actual_mem = actual_rst = "?"
        print(f"{c['name']:<40} {t:<10} {TIER_LIMITS[t]:<6} "
              f"{TIER_RESTART[t]:<13} actual: {actual_mem} / "
              f"{actual_rst}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--monitor", action="store_true")
    ap.add_argument("--apply-limits", action="store_true")
    ap.add_argument("--reclaim-memory", action="store_true")
    ap.add_argument("--show-status", action="store_true")
    ap.add_argument("--interval", type=int, default=30)
    ap.add_argument("--pressure-threshold", type=int, default=85)
    ap.add_argument("--critical-threshold", type=int, default=95)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    def tick():
        p = pressure(args)
        if p is None:
            print("WSL not running (skipped)")
            return
        print(f"[{time.strftime('%H:%M:%S')}] {p['usedPercent']}% "
              f"used, {p['freeGB']} GB free")
        if p["isCritical"]:
            print("CRITICAL pressure - reclaiming + enforcing limits")
            reclaim(args.dry_run)
            apply_limits(args.dry_run)
        elif p["isPressure"]:
            reclaim(args.dry_run)

    did = False
    if args.apply_limits:
        apply_limits(args.dry_run)
        did = True
    if args.reclaim_memory:
        reclaim(args.dry_run)
        did = True
    if args.monitor:
        while True:
            tick()
            time.sleep(args.interval)
    elif not did:
        show_status(args)


if __name__ == "__main__":
    main()
