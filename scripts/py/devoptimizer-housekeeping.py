"""DevOptimizer repo housekeeping (port of
scripts/devoptimizer-housekeeping.ps1).

Idempotent cleanup of the D:\\DevOptimizer root:
1. stale transient reports older than --older-than-days ->
   archive\\housekeeping-<ts>\\reports\\
2. NT-native junk names (containing ':' or 'NUL', invisible to Win32)
   -> ...\\nt-names\\ via Git Bash, with manifest-nt-names.tsv
3. tiny stub docs (<100 bytes .md/.txt) -> ...\\tiny-files\\
4. summary.md + housekeeping.log append. Nothing is deleted, only
   moved to archive\\ (gitignored). --dry-run; --prune-docker opt-in
   (docker image prune -a + builder prune -af).
"""

import argparse
import datetime
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: housekeeping, archive, quarantine, nt-names

REPORT_PATTERNS = [
    "script-validation-report-*.txt",
    "TEST-RESULTS-*.txt",
    "event-log-report-*.html",
    "invalid-scripts-*.txt",
    "cleanup-log.txt",
    "high-priority-invalid.txt",
    "stderr.log",
    "stdout.log",
]
BASH_CANDIDATES = [
    r"C:\Program Files\Git\bin\bash.exe",
    r"C:\Program Files\Git\usr\bin\bash.exe",
]


def bash_path(root, winpath):
    p = str(winpath).replace("\\", "/")
    return "/" + p[0].lower() + p[2:]


def find_bash():
    for c in BASH_CANDIDATES:
        if Path(c).is_file():
            return c
    b = shutil.which("bash")
    if b and "System32" not in b and "WindowsApps" not in b:
        return b
    return None


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--older-than-days", type=int, default=14)
    ap.add_argument("--root", default=r"D:\DevOptimizer")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--prune-docker", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run
    root = Path(args.root)

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    arch = root / "archive" / f"housekeeping-{stamp}"
    reports_dir, nt_dir, tiny_dir = (arch / "reports",
                                     arch / "nt-names",
                                     arch / "tiny-files")
    log_file = root / "logs" / "housekeeping.log"

    def log(msg):
        line = f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {msg}"
        print(line)
        try:
            with open(log_file, "a") as fh:
                fh.write(line + "\n")
        except OSError:
            pass

    log(f"=== DevOptimizer Housekeeping (dryRun={dry}, "
        f"olderThan={args.older_than_days}d) ===")
    cutoff = (datetime.datetime.now() -
              datetime.timedelta(days=args.older_than_days)).timestamp()

    # --- 1. Stale transient reports ---
    stale = []
    for pat in REPORT_PATTERNS:
        for f in root.glob(pat):
            try:
                if f.is_file() and f.stat().st_mtime < cutoff:
                    stale.append(f)
            except OSError:
                pass
    stale = sorted({f.name: f for f in stale}.values(),
                   key=lambda f: f.name)
    kb = sum(f.stat().st_size for f in stale) / 1024
    log(f"[1] Stale report files found: {len(stale)} ({kb:.1f} KB)")
    report_moves = []
    if stale and not dry:
        reports_dir.mkdir(parents=True, exist_ok=True)
    for f in stale:
        if dry:
            report_moves.append((f.name, "would move",
                                 round(f.stat().st_size / 1024, 1)))
        else:
            try:
                kb = round(f.stat().st_size / 1024, 1)
                shutil.move(str(f), str(reports_dir / f.name))
                report_moves.append((f.name, "moved", kb))
            except OSError as e:
                log(f"  WARN move failed '{f.name}': {e}")
                report_moves.append((f.name, f"FAILED: {e}", 0))

    # --- 2. NT-native names via Git Bash ---
    bash = find_bash()
    nt_moves = []
    if not bash:
        log("[2] SKIP: Git Bash not found - NT-native sweep "
            "unavailable")
    else:
        script = r'''
set -u
cd "$HK_ROOT" || { echo "HK_ROOT_MISSING"; exit 1; }
[ "$HK_DRY" = "1" ] || mkdir -p "$HK_DEST"
MAN="$HK_DEST/manifest-nt-names.tsv"
[ "$HK_DRY" = "1" ] || : > "$MAN"
shopt -s dotglob nullglob
for path in *; do
  name="${path##*/}"
  case "$name" in *:*|NUL) ;; *) continue ;; esac
  if [ "$HK_DRY" = "1" ]; then
    printf 'would-move\t%s\n' "$name"
  else
    printf '%s\t%s\n' "$name" "$HK_ROOT/$name" >> "$MAN"
    mv -- "$name" "$HK_DEST/" 2>/dev/null && printf 'moved\t%s\n' "$name" \
      || printf 'FAILED\t%s\n' "$name"
  fi
done
'''
        env = {"HK_ROOT": bash_path(root, root),
               "HK_DEST": bash_path(root, nt_dir),
               "HK_DRY": "1" if dry else "0"}
        r = subprocess.run([bash, "-c", script], capture_output=True,
                           text=True, errors="replace", env=env)
        nt_moves = r.stdout.splitlines()
        for ln in nt_moves:
            log(f"  [2] {ln}")
        log(f"[2] NT-native names quarantined: {len(nt_moves)}")

    # --- 3. Tiny stub docs ---
    tiny = [f for f in root.iterdir()
            if f.is_file() and f.suffix in (".md", ".txt")
            and f.stat().st_size < 100]
    log(f"[3] Tiny stub docs found: {len(tiny)}")
    if tiny and not dry:
        tiny_dir.mkdir(parents=True, exist_ok=True)
    for f in tiny:
        if dry:
            log(f"  would move {f.name} ({f.stat().st_size} B)")
        else:
            try:
                shutil.move(str(f), str(tiny_dir / f.name))
                log(f"  moved {f.name}")
            except OSError as e:
                log(f"  WARN {f.name}: {e}")

    # --- 4. Broken-ref validation (scripts/check-broken-refs.py) ---
    checker = root / "scripts" / "check-broken-refs.py"
    if checker.is_file():
        log("[4] Running check-broken-refs.py")
        if dry:
            print(f"[dry-run] python {checker}")
        else:
            r = subprocess.run(
                [sys.executable, str(checker)], capture_output=True,
                text=True, errors="replace")
            for ln in (r.stdout + r.stderr).splitlines()[-10:]:
                log(f"  {ln}")

    # --- 5. Summary + optional docker prune ---
    if not dry:
        arch.mkdir(parents=True, exist_ok=True)
        (arch / "summary.md").write_text(
            f"# Housekeeping {stamp}\n\n"
            f"- reports moved: "
            f"{sum(1 for _, a, _ in report_moves if a == 'moved')}\n"
            f"- nt-names quarantined: "
            f"{sum(1 for l in nt_moves if l.startswith('moved'))}\n"
            f"- tiny files: {len(tiny)}\n")
    log(f"[4] Archive: {arch}")

    if args.prune_docker:
        log("[5] --prune-docker: docker image prune -a + "
            "builder prune -af")
        for cmd in (["docker", "image", "prune", "-a", "-f"],
                    ["docker", "builder", "prune", "-af"]):
            if dry:
                print(f"[dry-run] {' '.join(cmd)}")
            else:
                r = subprocess.run(cmd, capture_output=True, text=True,
                                   errors="replace")
                for ln in (r.stdout + r.stderr).splitlines()[-3:]:
                    log(f"  {ln}")
    log("=== Housekeeping done ===")


if __name__ == "__main__":
    main()
