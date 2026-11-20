"""Port of scripts/backup-docker-nas.ps1.

Docker backup to NAS: pg_dumpall (gzip-magic checked),
volume tars (nightly<2GB / weekly / monthly), WSL layer
tars, manifest CSV with sha256, _carry/index.csv retry
queue, 3-attempt scp to omv:<NasDir>/<tier>/, retention
find -mtime, staging purge + keep last 2 staging dirs.
"""

import argparse
import csv
import hashlib
import shlex
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

LOG = Path("D:/DevOptimizer/logs/backup-docker-nas.log")
STAGING = Path("D:/DevOptimizer/backups/staging")
NAS_HOST = "omv"
NAS_DIR = "~/backups/devoptimizer"


def log(msg):
    try:
        LOG.parent.mkdir(exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} "
                    f"{msg}\n")
    except OSError:
        pass


def out(msg):
    print(msg)
    log(msg)


def run(cmd, timeout=None, **kw):
    try:
        return subprocess.run(cmd, capture_output=True,
                              text=True,
                              timeout=timeout or 600,
                              **kw)
    except Exception as e:
        print(e)
        return None


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def gzip_magic(p):
    try:
        with open(p, "rb") as f:
            return f.read(2) == b"\x1f\x8b"
    except OSError:
        return False


def nas_remote(path):
    # keep ~ expandable on the remote side
    return ("$HOME" + path[1:] if path.startswith("~")
            else path)


def scp_to_nas(local, tier):
    rdir = nas_remote(f"{NAS_DIR}/{tier}")
    run(["ssh", NAS_HOST,
         f"mkdir -p {shlex.quote(rdir)}"], timeout=60)
    target = f"{NAS_HOST}:{rdir}/"
    for attempt in range(1, 4):
        r = run(["scp", "-o", "ConnectTimeout=30",
                 str(local), target], timeout=3600)
        if r and r.returncode == 0:
            chk = run(["ssh", NAS_HOST,
                       f"ls -la {shlex.quote(rdir + '/' + local.name)}"],
                      timeout=60)
            if chk and chk.returncode == 0 and local.name in chk.stdout:
                out(f"  transferred {local.name} -> "
                    f"{target} (attempt {attempt})")
                return True
    out(f"  FAILED to transfer {local.name} after 3 "
        "attempts")
    return False


def enqueue_retry(local, tier):
    q = STAGING / "_carry"
    q.mkdir(parents=True, exist_ok=True)
    idx = q / "index.csv"
    rows = []
    if idx.exists():
        rows = list(csv.reader(
            idx.read_text().splitlines()))
    rows.append([str(local), tier,
                 datetime.now().isoformat()])
    idx.write_text("\n".join(
        ",".join(r) for r in rows))


def flush_retries():
    q = STAGING / "_carry"
    idx = q / "index.csv"
    if not idx.exists():
        return
    out("Retry queue flush:")
    rows = list(csv.reader(idx.read_text().splitlines()))
    keep = []
    for row in rows:
        if len(row) < 2:
            continue
        p, tier = Path(row[0]), row[1]
        if not p.exists():
            continue
        if not scp_to_nas(p, tier):
            keep.append(row)
        else:
            p.unlink()
    if keep:
        idx.write_text("\n".join(",".join(r)
                                 for r in keep))
    else:
        idx.unlink()


def pg_dump(user, container, dst):
    # docker exec pg_dumpall | gzip.exe via cmd
    pipe = subprocess.Popen(
        ["docker", "exec", container, "pg_dumpall",
         "-U", user],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL)
    gzexe = shutil.which("gzip.exe") or (
        r"C:\Program Files\Git\usr\bin\gzip.exe")
    # Confinement: dumps must land inside the staging tree.
    dp = Path(dst).resolve()
    if not dp.is_relative_to(STAGING.resolve()):
        raise ValueError("dump target escapes staging dir")
    gz = subprocess.Popen([gzexe, "-c"],
                          stdin=pipe.stdout,
                          stdout=dp.open("wb"))
    pipe.stdout.close()
    gz.wait()
    pipe.wait()
    if pipe.returncode == 0 and gzip_magic(dst):
        out(f"  pg_dumpall {container} -> {dst.name} OK")
        return True
    out(f"  pg_dumpall {container} FAILED (bad gzip)")
    dst.unlink(missing_ok=True)
    return False


def tar_volume(vol, dst):
    r = run(["docker", "run", "--rm",
             "-v", f"{vol}:/data:ro",
             "-v", f"{dst.parent}:/backup",
             "alpine",
             "tar", "czf",
             f"/backup/{dst.name}", "-C", "/data", "."],
            timeout=3600)
    return bool(r and r.returncode == 0
                and dst.exists())


def wsl_tar(src, dst, excludes):
    rel = dst.as_posix()
    if rel.startswith("D:/"):
        rel = "/mnt/d/" + rel[3:]
    # Drive tar directly via wsl -e (no bash -c, no shell parsing).
    argv = ["wsl.exe", "-d", "Ubuntu-24.04", "-e",
            "tar", "czf", rel]
    for e in excludes:
        argv += ["--exclude", e]
    argv += ["-C", src, "."]
    r = run(argv, timeout=7200)
    return bool(r and r.returncode == 0
                and dst.exists())


def retention(tier_dir, days):
    r = run(["ssh", NAS_HOST,
             f"find {shlex.quote(NAS_DIR + '/' + tier_dir)} "
             f"-type f -mtime +{days} -delete"],
            timeout=120)
    return bool(r and r.returncode == 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-Tier", default="auto")
    ap.add_argument("-DryRun", action="store_true")
    ap.add_argument("-SkipVolumes",
                    action="store_true")
    ap.add_argument("-SkipDbs", action="store_true")
    a = ap.parse_args()

    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    stamp = STAGING / ts
    stamp.mkdir(parents=True, exist_ok=True)
    out(f"=== Backup Docker -> NAS ({ts}) ===")
    manifest = stamp / f"manifest-{ts}.csv"
    mrows = []

    today = datetime.now()
    tier = ("monthly" if today.day == 1
            else "weekly" if today.weekday() == 6
            else "nightly")
    if a.Tier != "auto":
        tier = a.Tier

    # DB dumps
    if not a.SkipDbs:
        for cont, user, name in [
                ("social-postgres", "postgres",
                 "social-postgres")]:
            dst = stamp / f"{name}-pg-{ts}.sql.gz"
            if a.DryRun:
                out(f"  [dry] pg_dump {cont}")
            elif pg_dump(user, cont, dst):
                mrows.append([dst.name, str(dst.stat()
                                          .st_size),
                              sha256(dst),
                              "nightly"])

    # volume tars
    if not a.SkipVolumes:
        r = run(["docker", "volume", "ls", "--format",
                 "{{.Name}}"])
        vols = ((r.stdout if r else "")
                .strip().splitlines())
        for vol in vols:
            dst = stamp / f"vol-{vol}-{ts}.tar.gz"
            if a.DryRun:
                out(f"  [dry] tar vol {vol}")
                continue
            if tar_volume(vol, dst):
                sz = dst.stat().st_size
                vt = tier
                if tier == "nightly" and sz > 2 * 2**30:
                    out(f"  skip {vol}: {sz / 2**30:.1f}GB "
                        "> 2GB nightly cap")
                    dst.unlink()
                    continue
                mrows.append([dst.name, str(sz),
                              sha256(dst), vt])
                out(f"  volume {vol} OK ({vt})")
            else:
                out(f"  volume {vol} tar FAILED")

    # WSL layer tars (monthly/weekly/config only)
    tw = run(["tasklist", "/FI",
              "IMAGENAME eq vmmemWSL"])
    wsl_up = bool(tw and "vmmemWSL" in tw.stdout)
    if tier != "nightly" and wsl_up:
        wsl_layers = [
            ("/home/tbaltzakis/devoptimizer",
             "wsl-devoptimizer",
             ["node_modules", ".git/objects"]),
            ("/home/tbaltzakis/cloudless.gr",
             "wsl-cloudless", ["node_modules", ".git"]),
            ("/etc", "wsl-etc", [])]
        if tier == "monthly":
            wsl_layers += [
                ("/var/lib/docker", "wsl-docker-root",
                 ["overlay2/tmp"]),
                ("/home/tbaltzakis", "wsl-home",
                 ["node_modules", ".git", ".cache",
                  "Downloads"])]
        for src, name, excl in wsl_layers:
            dst = stamp / f"{name}-{ts}.tar.gz"
            if a.DryRun:
                out(f"  [dry] wsl tar {src}")
                continue
            if wsl_tar(src, dst, excl):
                mrows.append([dst.name,
                              str(dst.stat().st_size),
                              sha256(dst), tier])
                out(f"  wsl layer {src} OK")
            else:
                out(f"  wsl layer {src} FAILED")

    # manifest (confinement: stays inside the staging tree)
    mp = Path(manifest).resolve()
    if not mp.is_relative_to(STAGING.resolve()):
        raise ValueError("manifest escapes staging dir")
    with mp.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["file", "bytes", "sha256", "tier"])
        w.writerows(mrows)

    # scp everything
    if a.DryRun:
        out("DRY RUN - no transfers")
        return 0
    flush_retries()
    for f in stamp.iterdir():
        if f.name == manifest.name:
            continue
        t = next((r[3] for r in mrows
                  if r[0] == f.name), tier)
        if not scp_to_nas(f, t):
            enqueue_retry(f, t)
    if not scp_to_nas(manifest, tier):
        enqueue_retry(manifest, tier)

    # retention: nightly 7, weekly 28, monthly 180
    for t, d in (("nightly", 7), ("weekly", 28),
                 ("monthly", 180)):
        retention(t, d)

    # staging: purge transferred, keep last 2 dirs
    dirs = sorted(STAGING.iterdir(), reverse=True)
    for d in dirs[2:]:
        if d.is_dir() and d.name != "_carry":
            for f in d.iterdir():
                if (STAGING / "_carry"
                        / "index.csv").exists() and f.name in (
                        (STAGING / "_carry" / "index.csv")
                        .read_text()):
                    continue
                try:
                    f.unlink()
                except OSError:
                    pass
    out("Done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
