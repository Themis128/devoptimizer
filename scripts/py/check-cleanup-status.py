"""Read-only Win11 cleanup status assessment (port of
scripts/check-cleanup-status.ps1).

Prints sizes of cleanable locations (drives, temp, dev caches, browser
data, VS Code/Electron caches, recycle bin, system caches, VHDX, big
system files, Docker) and a YES/MODERATE/NO verdict. Deletes nothing.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

# CATEGORY: cleanup
# TAGS: status, assessment, read-only, report

LA = os.environ.get("LOCALAPPDATA", "")
AD = os.environ.get("APPDATA", "")
UP = os.environ.get("USERPROFILE", "")
TMP = os.environ.get("TEMP", "")


def ds(path) -> int:
    p = Path(path)
    if not p.exists():
        return 0
    if p.is_file():
        return p.stat().st_size
    total = 0
    for f in p.rglob("*"):
        try:
            if f.is_file():
                total += f.stat().st_size
        except OSError:
            pass
    return total


cleanable = 0


def row(label, path, report_only=False):
    global cleanable
    p = Path(path)
    if not p.exists():
        print(f"{label:<44} : (not present)")
        return 0
    s = ds(p)
    if s >= 2**30:
        print(f"{label:<44} : {s / 2**30:8.2f} GB")
    else:
        print(f"{label:<44} : {s / 2**20:8.0f} MB")
    if not report_only:
        cleanable += s
    return s


def chromium_cache(root) -> int:
    rp = Path(root)
    if not rp.is_dir():
        return 0
    profs = [rp / "Default"] + [d for d in rp.glob("Profile *")
                                if d.is_dir()]
    return sum(ds(p / sub) for p in profs
               for sub in ("Cache", "Code Cache", "GPUCache"))


def main() -> None:
    global cleanable
    import datetime
    print(f"=== Win11 Cleanup Assessment - "
          f"{datetime.datetime.now():%Y-%m-%d %H:%M} ===")

    print("\n--- Drives ---")
    for letter in ("C:\\", "D:\\", "E:\\"):
        try:
            u = shutil.disk_usage(letter)
            pct = round(100 * u.free / (u.used + u.free)) \
                if u.used + u.free else 0
            print(f"{letter[0]}: free {u.free / 2**30:8.1f} GB  "
                  f"({pct}%)  used {u.used / 2**30:8.1f} GB")
        except OSError:
            pass

    print("\n--- Temp & crash data (user-level) ---")
    row("User temp", TMP)
    row("Windows temp", r"C:\Windows\Temp")
    row("CrashDumps", rf"{LA}\CrashDumps")
    row("WER archives (user)", rf"{LA}\Microsoft\Windows\WER")

    print("\n--- Dev caches (user-level) ---")
    row("npm cache", rf"{LA}\npm-cache")
    row("pip cache", rf"{LA}\pip\cache")
    row("pnpm store", rf"{LA}\pnpm\store")
    row("Cargo registry", rf"{UP}\.cargo\registry")
    row("NuGet packages", rf"{UP}\.nuget\packages")
    row("Go module cache", rf"{UP}\go\pkg")
    row("HuggingFace cache", rf"{UP}\.cache\huggingface")
    row("Ollama models (report-only, not auto-cleaned)",
        rf"{UP}\.ollama\models", report_only=True)

    print("\n--- Browser caches (Chrome/Edge) ---")
    chrome_root = rf"{LA}\Google\Chrome\User Data"
    edge_root = rf"{LA}\Microsoft\Edge\User Data"
    row("Chrome cache dirs", chrome_root)
    chrome_cache = chromium_cache(chrome_root)
    edge_cache = chromium_cache(edge_root)
    print(f"{'Chrome cache subset':<44} : "
          f"{chrome_cache / 2**20:8.0f} MB (precise, cleanable subset)")
    print(f"{'Edge cache subset':<44} : "
          f"{edge_cache / 2**20:8.0f} MB (precise, cleanable subset)")
    cleanable = cleanable - ds(chrome_root) + chrome_cache

    print("\n--- VS Code / Electron ---")
    for label, root in (("VS Code stable caches", rf"{AD}\Code"),
                        ("VS Code Insiders caches",
                         rf"{AD}\Code - Insiders")):
        s = sum(ds(Path(root) / sub) for sub in
                ("Cache", "CachedData", "Code Cache", "GPUCache",
                 "CachedExtensionVSIXs", "logs", "workspaceStorage")) \
            if Path(root).is_dir() else 0
        print(f"{label:<44} : {s / 2**20:8.0f} MB")
        cleanable += s
    for name, root in (("Discord", rf"{AD}\discord"),
                       ("Slack", rf"{AD}\Slack"),
                       ("Spotify", rf"{AD}\Spotify")):
        s = sum(ds(Path(root) / sub)
                for sub in ("Cache", "Code Cache", "GPUCache",
                            "Storage")) if Path(root).is_dir() else 0
        if s > 0:
            print(f"{name:<44} : {s / 2**20:8.0f} MB")
            cleanable += s

    print("\n--- Recycle bin ---")
    rb_label = r"C:\$Recycle.Bin"
    rb = ds(rb_label)
    print(f"{rb_label:<44} : {rb / 2**20:8.0f} MB "
          "(readable subset)")
    cleanable += rb

    print("\n--- System caches (best effort without admin) ---")
    row("Windows Update download cache",
        r"C:\Windows\SoftwareDistribution\Download")
    row("Delivery Optimization cache",
        r"C:\Windows\ServiceProfiles\NetworkService\AppData\Local"
        r"\Microsoft\Windows\DeliveryOptimization\Cache")

    print("\n--- VHDX backing disks ---")
    for root in (rf"{LA}\wsl", rf"{LA}\Docker"):
        rp = Path(root)
        if rp.is_dir():
            for f in rp.rglob("*.vhdx"):
                try:
                    short = str(f).replace(LA, r"~AppData\Local")
                    print(f"{short:<44} : "
                          f"{f.stat().st_size / 2**30:8.2f} GB")
                except OSError:
                    pass

    print("\n--- Big system files ---")
    for f in ("pagefile.sys", "hiberfil.sys", "swapfile.sys"):
        p = Path("C:\\") / f
        if p.exists():
            try:
                print(f"{f:<44} : {p.stat().st_size / 2**30:8.2f} GB")
            except OSError:
                pass

    print("\n--- Docker (if running) ---")
    r = subprocess.run(["docker", "version", "--format",
                        "{{.Server.Version}}"], capture_output=True,
                       text=True, errors="replace")
    if r.returncode == 0:
        print(subprocess.run(["docker", "system", "df"],
                             capture_output=True, text=True,
                             errors="replace").stdout)
    else:
        print("Docker daemon not running - skipped")

    print("\n=== Verdict ===")
    if cleanable >= 5 * 2**30:
        print(f"YES - ~{cleanable / 2**30:.1f} GB cleanable at user "
              "level right now.")
    elif cleanable >= 500 * 2**20:
        print(f"MODERATE - ~{cleanable / 2**20:.0f} MB cleanable at "
              "user level right now.")
    else:
        print(f"NO - only ~{cleanable / 2**20:.0f} MB cleanable at "
              "user level; system is tidy.")
    print("Run extended-cleanup.ps1 / win11-safe-cleanup.ps1 for "
          "user-level, elevated-complete-cleanup.ps1 for admin items.")


if __name__ == "__main__":
    sys.exit(main() or 0)
