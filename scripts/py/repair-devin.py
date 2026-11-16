"""Port of scripts/devin/Repair-Devin.ps1 — guarded repair actions for
Devin Desktop's WSL remote (devin-server in Ubuntu-24.04). Dry-run
default; -FixBundle/-CleanLeftovers/-PruneServerLogs opt in.
Never touches extensions/, data/, settings, the live commit dir, or
.installation_lock. Exit codes: 0 done, 1 refused, 2 bundle fixed
(finish with Reload Window).
"""
import re
import subprocess
import sys

DISTRO = "Ubuntu-24.04"


def wsl(cmd):
    out = []
    for args in (["wsl.exe", "-d", DISTRO, "--", "bash", "-c", cmd],
                 ["wsl.exe", "-d", DISTRO, "--exec", "bash", "-c", cmd]):
        try:
            r = subprocess.run(args, capture_output=True, text=True)
            joined = r.stdout.replace("\x00", "")
            out = [l for l in re.split(r"\r?\n", joined) if l]
            if r.returncode == 0 or out:
                break
        except FileNotFoundError:
            continue
    return out


def approve(what, force):
    if force:
        return True
    print(f"[ASK ] about to: {what}")
    if not sys.stdin.isatty():
        print("       non-interactive launch: re-run with --force")
        return False
    try:
        answer = input("       type YES to continue (anything else"
                       " skips): ")
    except EOFError:
        return False
    return answer == "YES"


def main():
    fix_bundle = "--fix-bundle" in sys.argv
    clean = "--clean-leftovers" in sys.argv
    prune = "--prune-server-logs" in sys.argv
    force = "--force" in sys.argv
    commit_arg = None
    days = 14
    for i, a in enumerate(sys.argv):
        if a == "--commit" and i + 1 < len(sys.argv):
            commit_arg = sys.argv[i + 1]
        if a == "--days" and i + 1 < len(sys.argv):
            days = int(sys.argv[i + 1])

    print(f"=== Devin Repair ({DISTRO}) ===")
    if "ok" not in " ".join(wsl("echo ok")):
        print(f"[FAIL] WSL distro '{DISTRO}' unreachable - check WSL"
              " FIRST (Docker VM state, vmmemWSL memory,"
              " wsl --shutdown recovery) before touching Devin.")
        return 1
    print("[ OK ] WSL distro reachable")

    dry_run = not (fix_bundle or clean or prune)
    if dry_run:
        print("[ DRY ] no action switches given - dry-run, nothing"
              " will change")

    procs = wsl("pgrep -af 'server-mai[n]' || true")
    live = None
    m = re.search(r"\.devin-server/bin/([a-f0-9]{40})/",
                  "\n".join(procs))
    if m:
        live = m.group(1)
    alldirs = [d for d in wsl(
        "ls -1 $HOME/.devin-server/bin/ 2>/dev/null || true")
        if re.match(r"^[a-f0-9]{40}$", d)]
    if not live and alldirs:
        t = wsl("ls -1t $HOME/.devin-server/bin/ | head -1")
        live = t[0].strip() if t else None
    if live and not re.match(r"^[a-f0-9]{40}$", live):
        live = None

    bundle_broken = False
    if live:
        base = f"$HOME/.devin-server/bin/{live}/node_modules"
        check = wsl(f"test -d {base}/minimist -a -d {base}/@vscode"
                    " && echo intact || echo broken")
        bundle_broken = "broken" in check

    exit_code = 0

    if fix_bundle:
        if not live:
            print("[FAIL] --fix-bundle: no commit dir found in"
                  " ~/.devin-server/bin and no server running -"
                  " nothing to fix.")
            return 1
        allowed = (bundle_broken
                   or (commit_arg and re.match(r"^[a-f0-9]{40}$",
                                               commit_arg))
                   or force)
        if not allowed:
            print(f"[FAIL] --fix-bundle refused: bundle for {live}"
                  " is INTACT. Nothing suggests corruption.")
            print("       Use --commit <40hex> to target a specific"
                  " dir or --force to override.")
            return 1
        if not dry_run:
            if not approve(f"kill devin-server and delete"
                           f" ~/.devin-server/bin/{live} (~700 MB"
                           " re-download on next Reload Window)",
                           force):
                print("[SKIP] --fix-bundle cancelled")
            else:
                print(f"[FIX ] killing server + deleting bundle dir"
                      f" {live} ...")
                wsl(f"pkill -f 'server-mai[n]'; rm -rf"
                    f" $HOME/.devin-server/bin/{live}; echo done")
                print("[FIX ] done. NOW CLICK 'Reload Window' in"
                      " Devin (or reopen) - a fresh bundle downloads"
                      " automatically.")
                exit_code = 2
        else:
            print(f"[ DRY ] --fix-bundle would delete:"
                  f" ~/.devin-server/bin/{live}"
                  f" (bundleBroken={bundle_broken})")

    if clean:
        superseded = [d for d in alldirs if d != live]
        sidecars = []
        for d in superseded:
            sidecars += wsl(
                f"ls -1 $HOME/.devin-server/.{d}.log"
                f" $HOME/.devin-server/.{d}.pid"
                f" $HOME/.devin-server/.{d}.token 2>/dev/null"
                " || true")
        if not superseded and not sidecars:
            print("[ OK ] --clean-leftovers: nothing to clean (only"
                  " the live commit exists)")
        elif dry_run:
            print(f"[ DRY ] --clean-leftovers would delete dirs:"
                  f" {', '.join(superseded)}; sidecars:"
                  f" {len(sidecars)} file(s)")
        else:
            if not approve(f"delete {len(superseded)} superseded"
                           f" commit dir(s) and {len(sidecars)}"
                           " sidecar file(s)", force):
                print("[SKIP] --clean-leftovers cancelled")
            else:
                for d in superseded:
                    wsl(f"rm -rf $HOME/.devin-server/bin/{d};"
                        " echo removed")
                    print(f"[FIX ] deleted dir"
                          f"  ~/.devin-server/bin/{d}")
                for f in sidecars:
                    leaf = f.strip().rsplit("/", 1)[-1]
                    wsl(f"rm -f '$HOME/{leaf}'; echo removed")
                    print(f"[FIX ] deleted file {f.strip()}")
                print("[ OK ] .installation_lock, extensions/ and"
                      " data/ untouched")

    if prune:
        old = wsl(f"find $HOME/.devin-server/data/logs -type f"
                  f" -mtime +{days} 2>/dev/null || true")
        size_raw = wsl(
            f"find $HOME/.devin-server/data/logs -type f"
            f" -mtime +{days} -print0 2>/dev/null | xargs -0 -r"
            " du -ch 2>/dev/null | tail -1 | cut -f1")
        size = size_raw[0].strip() if size_raw else "0"
        if not old:
            print(f"[ OK ] --prune-server-logs: no files older than"
                  f" {days} days")
        elif dry_run:
            print(f"[ DRY ] --prune-server-logs would delete"
                  f" {len(old)} file(s) ({size}) older than"
                  f" {days} days")
        else:
            if not approve(f"delete {len(old)} old server-log"
                           f" file(s) ({size})", force):
                print("[SKIP] --prune-server-logs cancelled")
            else:
                wsl(f"find $HOME/.devin-server/data/logs -type f"
                    f" -mtime +{days} -delete; echo pruned")
                print(f"[FIX ] pruned {len(old)} file(s) ({size})"
                      " from ~/.devin-server/data/logs")

    if dry_run:
        if live:
            state = ("BROKEN - --fix-bundle applies"
                     if bundle_broken else "intact")
            print(f"[ DRY ] live commit: {live} (bundle {state})")
        else:
            print("[ DRY ] live commit: none (server down, no"
                  " commit dirs)")
        left = [d for d in alldirs if d != live]
        if live and bundle_broken:
            fix_msg = "WOULD delete " + live
        elif live:
            fix_msg = "nothing (bundle intact)"
        else:
            fix_msg = "nothing (no commit)"
        print("[ DRY ] --fix-bundle: " + fix_msg)
        clean_msg = ("WOULD delete " + ", ".join(left)
                     if left else "nothing")
        print("[ DRY ] --clean-leftovers: " + clean_msg)
        print("[ DRY ] --prune-server-logs: run with --days N to"
              " see file candidates")
        print("=== DRY-RUN COMPLETE - NOTHING CHANGED ===")
    else:
        print("=== REPAIR RUN COMPLETE ===")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
