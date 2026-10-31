"""Development cache cleaner (Python port of dev-cache-cleaner.ps1).

Python port of dev-cache-cleaner.ps1
Development cache cleaner: Node.js/Python/IDE/Docker/Git caches with exclusions.
"""

import argparse
import asyncio
import json
import os
import shutil
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command  # noqa: E402

# CATEGORY: cleanup
# TAGS: dev, cache, cleanup


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}")


def dir_size_mb(path: Path) -> float:
    try:
        if not path.exists():
            return 0.0
    except OSError:
        return 0.0
    total = 0
    try:
        for item in path.rglob("*"):
            try:
                if item.is_file():
                    total += item.stat().st_size
            except OSError:
                continue
    except OSError:
        pass
    return round(total / 1048576, 2)


def rmtree_contents(path: Path) -> int:
    freed = 0
    try:
        for item in path.iterdir():
            try:
                if item.is_dir():
                    size_bytes = sum(
                        f.stat().st_size for f in item.rglob("*") if f.is_file()
                    )
                    shutil.rmtree(item, ignore_errors=True)
                else:
                    size_bytes = item.stat().st_size
                    item.unlink()
                freed += size_bytes
            except OSError:
                continue
    except OSError:
        pass
    return freed


def expand(p: str) -> Path:
    return Path(os.path.expandvars(p.replace("/", "\\")))


FAMILIES: dict[str, list[tuple[str, str]]] = {
    "nodejs": [
        ("npm cache", "%APPDATA%\\npm-cache"),
        ("npm local cache", "%LOCALAPPDATA%\\npm-cache"),
        ("npm user cache", "%USERPROFILE%\\.npm"),
        ("pnpm cache", "%USERPROFILE%\\AppData\\Local\\pnpm-cache"),
        ("pnpm store", "%USERPROFILE%\\.pnpm-store"),
        ("Yarn cache", "%LOCALAPPDATA%\\Yarn\\Cache"),
        ("Yarn user cache", "%USERPROFILE%\\.yarn\\cache"),
    ],
    "python": [
        ("pip cache", "%LOCALAPPDATA%\\pip\\Cache"),
        ("pip user cache", "%USERPROFILE%\\.cache\\pip"),
        ("pipx cache", "%LOCALAPPDATA%\\pipx\\cache"),
    ],
    "ide": [
        ("VS Code workspace storage", "%APPDATA%\\Code\\User\\workspaceStorage"),
        ("VS Code history", "%APPDATA%\\Code\\User\\History"),
        ("VS Code logs", "%APPDATA%\\Code\\logs"),
        ("Cursor workspace storage", "%APPDATA%\\Cursor\\User\\workspaceStorage"),
        ("Cursor history", "%APPDATA%\\Cursor\\User\\History"),
        ("Cursor logs", "%APPDATA%\\Cursor\\logs"),
        ("JetBrains logs", "%LOCALAPPDATA%\\JetBrains\\Toolbox\\logs"),
    ],
}


def find_pycache(root: Path, depth: int) -> list[Path]:
    found: list[Path] = []
    if not root.exists():
        return found
    try:
        for current_root, dirs, _files in os.walk(root):
            rel = Path(current_root).relative_to(root)
            if Path(current_root).name == "__pycache__":
                found.append(Path(current_root))
                dirs[:] = []
                continue
            if len(rel.parts) >= depth:
                dirs[:] = []
                continue
    except OSError:
        pass
    return found


def resolve_config_paths(values: list[str] | None, script_root: Path) -> list[Path]:
    out: list[Path] = []
    for item in values or []:
        if not item or not item.strip():
            continue
        expanded = os.path.expandvars(item.replace("/", "\\"))
        p = Path(expanded)
        if not p.is_absolute():
            p = script_root / p
        try:
            p = p.resolve()
        except OSError:
            p = Path(os.path.abspath(p))
        out.append(p)
    return sorted(set(out))


def load_config(script_root: Path) -> dict:
    for candidate in (
        script_root / "dev-cache-cleaner-config.json",
        _REPO_ROOT / "scripts" / "cache-cleaner-config.json",
    ):
        try:
            with open(candidate, encoding="utf-8-sig") as fh:
                return json.loads(fh.read())
        except (OSError, ValueError):
            continue
    return {}


def should_exclude(path: Path, exclusions: list[Path], patterns: list[str]) -> bool:
    for e in exclusions:
        try:
            path.relative_to(e)
            return True
        except ValueError:
            continue
    lowered = str(path).lower()
    return any(pattern.lower() in lowered for pattern in patterns)


async def clean_family(
    family: str,
    dry_run: bool,
    exclusions: list[Path],
    patterns: list[str],
    stats: dict,
) -> None:
    for name, template in FAMILIES[family]:
        path = expand(template)
        if should_exclude(path, exclusions, patterns):
            log("DEBUG", f"Skipping {name} at {path} (excluded)")
            continue
        if not path.exists():
            log("DEBUG", f"{name} not found at {path}")
            continue
        size = dir_size_mb(path)
        if dry_run:
            log("INFO", f"DRY RUN: Would clean {name} ({size} MB)")
            stats["would_free_mb"] = round(stats["would_free_mb"] + size, 2)
        else:
            try:
                shutil.rmtree(path)
                log("SUCCESS", f"Cleaned {name} ({size} MB)")
                stats["freed_mb"] = round(stats["freed_mb"] + size, 2)
                stats["count"] += 1
            except OSError as e:
                log("ERROR", f"Failed to clean {name}: {e}")
                stats["errors"] += 1


async def clean_pycache(
    roots: list[Path],
    depth: int,
    dry_run: bool,
    exclusions: list[Path],
    patterns: list[str],
    stats: dict,
) -> None:
    dirs: list[Path] = []
    for root in roots:
        dirs.extend(find_pycache(root, depth))
    dirs = [d for d in sorted(set(dirs)) if not should_exclude(d, exclusions, patterns)]
    if not dirs:
        log("DEBUG", "No Python __pycache__ directories found within configured roots")
        return
    removed = 0
    freed = 0.0
    for d in dirs:
        size = dir_size_mb(d)
        if dry_run:
            log("INFO", f"DRY RUN: Would clean Python __pycache__ ({size} MB) at {d}")
            freed += size
        else:
            try:
                shutil.rmtree(d)
                removed += 1
                freed += size
            except OSError as e:
                log("ERROR", f"Failed to clean {d}: {e}")
                stats["errors"] += 1
    if removed or dry_run:
        label = "DRY RUN: " if dry_run else ""
        log("INFO" if dry_run else "SUCCESS",
            f"{label}Cleaned {removed if not dry_run else len(dirs)} Python __pycache__ directories ({round(freed, 2)} MB)")


async def clean_docker(dry_run: bool, stats: dict) -> None:
    docker = shutil.which("docker")
    if not docker:
        log("DEBUG", "Docker not found, skipping Docker cache cleanup")
        return
    if dry_run:
        log("INFO", "DRY RUN: Would run docker system prune")
        return
    result = await run_command(
        [
            "docker", "system", "prune", "-f",
            "--filter", "label!=com.docker.desktop.service=model-runner",
            "--filter", "label!=com.docker.model-runner.role=model-storage",
        ],
        timeout=300,
    )
    if result.returncode == 0:
        log("SUCCESS", "Docker system prune completed")
    else:
        log("ERROR", f"Docker system prune failed: {result.stderr[:120]}")
        stats["errors"] += 1


def clean_git(dry: bool, stats: dict) -> None:
    if not shutil.which("git"):
        log("DEBUG", "Git not found, skipping Git cache cleanup")
        return
    if dry:
        log("INFO", f"DRY RUN: Would run git gc --aggressive --prune=now in {_REPO_ROOT}")
        return
    import subprocess

    try:
        result = subprocess.run(
            ["git", "gc", "--aggressive", "--prune=now"],
            cwd=str(_REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=600,
        )
        if result.returncode == 0:
            log("SUCCESS", "Git garbage collection completed")
        else:
            log("ERROR", f"git gc failed: {result.stderr[:120]}")
            stats["errors"] += 1
    except (OSError, subprocess.TimeoutExpired):
        stats["errors"] += 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Development cache cleaner")
    parser.add_argument("--dry-run", action="store_true", help="Preview without deleting")
    parser.add_argument("--analyze", action="store_true", help="Report sizes only, no changes")
    parser.add_argument("--pycache-depth", type=int, default=6)
    parser.add_argument("--pycache-roots", nargs="*", default=[])
    for fam in FAMILIES:
        parser.add_argument(f"--{fam}", action="store_true", help=f"Clean {fam} caches only")
    parser.add_argument("--docker", action="store_true", help="Run docker system prune")
    parser.add_argument("--git", action="store_true", help="Run git gc in the repo root")
    parser.add_argument("--all", action="store_true", help="Clean every family")
    args = parser.parse_args()

    script_root = Path(__file__).resolve().parent
    config = load_config(script_root)
    exclusions = resolve_config_paths(config.get("exclusions", {}).get("paths"), script_root)
    patterns = list(config.get("exclusions", {}).get("patterns", []))
    pycache_roots = resolve_config_paths(
        config.get("searchRoots", {}).get("python"),
        script_root,
    ) or [Path(a).resolve() for a in args.pycache_roots]

    stats = {"freed_mb": 0.0, "would_free_mb": 0.0, "count": 0, "errors": 0}
    mode = "DRY RUN" if args.dry_run else ("ANALYZE" if args.analyze else "ACTIVE CLEANUP")
    log("INFO", f"=== Development Cache Cleaner ({mode}) ===")

    dry = args.dry_run or args.analyze
    families = [f for f in FAMILIES if getattr(args, f) or args.all]
    if args.analyze:
        for family in families:
            for name, template in FAMILIES[family]:
                path = expand(template)
                if path.exists():
                    log("INFO", f"{name}: {dir_size_mb(path)} MB at {path}")
        for root in pycache_roots:
            for d in find_pycache(root, args.pycache_depth):
                log("INFO", f"__pycache__: {dir_size_mb(d)} MB at {d}")
        return

    for family in families:
        asyncio.run(clean_family(family, dry, exclusions, patterns, stats))
    if args.python or args.all:
        asyncio.run(clean_pycache(args.pycache_roots and [Path(r) for r in args.pycache_roots] or pycache_roots,
                                  args.pycache_depth, dry, exclusions, patterns, stats))
    if args.docker or args.all:
        asyncio.run(clean_docker(dry, stats))
    if args.git or args.all:
        clean_git(dry, stats)

    log("INFO", f"Freed {stats['freed_mb']} MB across {stats['count']} targets ({stats['errors']} errors)")
    if stats["errors"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
