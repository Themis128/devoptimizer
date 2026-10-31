"""Nuxt 3 optimization for Windows and WSL (Python port of nuxt3-optimization.ps1).

Python port of nuxt3-optimization.ps1
Nuxt 3 optimization functions - latest 2024/2025 best practices.
"""

import argparse
import asyncio
import ctypes
import json
import os
import re
import shutil
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "py"))

from devoptimizer_cli.core.executor import run_command, run_elevated  # noqa: E402
from devoptimizer_cli.core import winops  # noqa: E402

# CATEGORY: development
# TAGS: nuxt, development, wsl, node

RAM_GB = None


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}")


def _exec_args(name: str, extra: list[str]) -> list[str]:
    full = shutil.which(name)
    argv = [full or name] + extra
    if full and full.lower().endswith((".cmd", ".bat")):
        argv = ["cmd.exe", "/c"] + argv
    return argv


async def probe(name: str, args: list[str]) -> str:
    result = await run_command(_exec_args(name, args), timeout=30)
    return result.stdout.strip() if result.returncode == 0 else ""


def ram_gb() -> float:
    global RAM_GB
    if RAM_GB is None:
        try:

            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                            ("ullTotalPhys", ctypes.c_ulonglong)]

            stat = MEMORYSTATUSEX()
            stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
            ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat))
            RAM_GB = round(stat.ullTotalPhys / 1073741824, 2)
        except (OSError, AttributeError):
            RAM_GB = 16.0
    return RAM_GB


async def get_environment() -> dict:
    log("INFO", "Analyzing Nuxt 3 development environment...")
    env: dict = {
        "nodejs": {"installed": False, "version": None, "lts": False},
        "package_managers": {pm: {"installed": False, "version": None} for pm in ("npm", "pnpm", "yarn", "bun")},
        "nuxt": {"global_installed": False, "version": None},
        "wsl": {"installed": False, "distributions": [], "default": None},
        "git": {"installed": False, "version": None, "config": {}},
        "vscode": {"installed": False, "extensions": []},
        "system": {"ram_gb": ram_gb(), "ssd": False},
    }

    node_out = await probe("node", ["--version"])
    m = re.search(r"v(\d+)\.(\d+)\.(\d+)", node_out)
    if m:
        env["nodejs"]["installed"] = True
        env["nodejs"]["version"] = f"{m.group(1)}.{m.group(2)}.{m.group(3)}"
        env["nodejs"]["lts"] = int(m.group(1)) % 2 == 0

    for pm in ("npm", "pnpm", "yarn", "bun"):
        out = await probe(pm, ["--version"])
        if re.search(r"\d+\.\d+\.\d+", out):
            env["package_managers"][pm]["installed"] = True
            env["package_managers"][pm]["version"] = out.splitlines()[0].strip()

    nuxi_out = await probe("npx", ["nuxi", "--version"])
    m = re.search(r"(\d+\.\d+\.\d+)", nuxi_out)
    if m:
        env["nuxt"]["global_installed"] = True
        env["nuxt"]["version"] = m.group(1)

    result = await run_command(["wsl.exe", "-l", "-v"], timeout=30)
    if result.returncode == 0 and result.stdout.strip():
        lines = [l.strip() for l in result.stdout.replace("\x00", "").splitlines() if l.strip()]
        distros = [l.split()[0] for l in lines[1:] if l.split()]
        env["wsl"]["installed"] = bool(distros)
        env["wsl"]["distributions"] = distros
        for l in lines[1:]:
            if "*" in l:
                env["wsl"]["default"] = l.split()[0]
                break

    git_out = await probe("git", ["--version"])
    m = re.search(r"git version (\d+\.\d+\.\d+)", git_out)
    if m:
        env["git"]["installed"] = True
        env["git"]["version"] = m.group(1)
        for key in ("user.name", "user.email"):
            out = await probe("git", ["config", "--global", key])
            if out and "error" not in out.lower():
                env["git"]["config"][key.split(".")[1]] = out

    if shutil.which("code"):
        env["vscode"]["installed"] = True
        ext_out = await probe("code", ["--list-extensions"])
        env["vscode"]["extensions"] = [l for l in ext_out.splitlines() if l.strip()]

    ps = await winops.run_ps_command(
        "Get-PhysicalDisk | Where-Object MediaType -eq 'SSD' | Measure-Object | Select-Object -ExpandProperty Count")
    try:
        env["system"]["ssd"] = int(ps.stdout.strip() or "0") > 0
    except ValueError:
        pass

    log("SUCCESS", "Environment analysis completed")
    return env


PNPM_CONFIGS = [
    ["store-dir", r"C:\.pnpm-store"],
    ["cache-dir", r"C:\.pnpm-cache"],
    ["state-dir", r"C:\.pnpm-state"],
    ["auto-install-peers", "true"],
    ["dedupe-peer-dependents", "true"],
    ["hoist-pattern", "*"],
    ["public-hoist-pattern", "*eslint*,*prettier*,*typescript*"],
    ["shamefully-hoist", "true"],
]
NPM_CONFIGS = [
    ["fund", "false"],
    ["audit", "false"],
    ["progress", "false"],
    ["loglevel", "warn"],
    ["cache", r"C:\.npm-cache"],
    ["registry", "https://registry.npmjs.org/"],
]
DEFENDER_PATHS = [
    r"C:\.pnpm-store",
    r"C:\.npm-cache",
    os.path.expandvars(r"%USERPROFILE%\node_modules"),
    os.path.expandvars(r"%USERPROFILE%\.nuxt"),
    os.path.expandvars(r"%USERPROFILE%\.output"),
    os.path.expandvars(r"%LOCALAPPDATA%\pnpm"),
    os.path.expandvars(r"%APPDATA%\npm"),
]


def node_options_for(ram: float) -> str:
    if ram >= 32:
        return "--max-old-space-size=16384 --experimental-vm-modules"
    if ram <= 8:
        return "--max-old-space-size=4096 --experimental-vm-modules"
    return "--max-old-space-size=8192 --experimental-vm-modules"


async def optimize_windows(dry_run: bool) -> int:
    log("INFO", "Optimizing Nuxt 3 for Windows (profile: Development)...")
    env = await get_environment()
    n = 0

    log("INFO", "Setting Node.js environment variables...")
    env_vars = {
        "NODE_OPTIONS": node_options_for(env["system"]["ram_gb"]),
        "NODE_ENV": "development",
        "NUXT_TELEMETRY_DISABLED": "1",
        "NITRO_PRESET": "node-server",
    }
    for key, value in env_vars.items():
        if dry_run:
            log("INFO", f"[DRY RUN] Would set {key} = {value}")
        else:
            winops.reg_set(r"HKCU\Environment", key, value)
            log("SUCCESS", f"Set {key} = {value}")
        n += 1

    for pm, configs in (("pnpm", PNPM_CONFIGS), ("npm", NPM_CONFIGS)):
        if not env["package_managers"][pm]["installed"]:
            continue
        log("INFO", f"Optimizing {pm} configuration...")
        for cfg in configs:
            cmd = _exec_args(pm, ["config", "set"] + cfg)
            if dry_run:
                log("INFO", f"[DRY RUN] Would run: {' '.join(cmd)}")
            else:
                result = await run_command(cmd, timeout=60)
                if result.returncode == 0:
                    log("SUCCESS", f"Applied {pm} config: {' '.join(cfg)}")
                else:
                    log("WARN", f"Failed to apply {pm} config: {' '.join(cfg)}")
            n += 1

    log("INFO", "Adding Windows Defender exclusions for development folders...")
    for path in DEFENDER_PATHS:
        if dry_run:
            log("INFO", f"[DRY RUN] Would add Defender exclusion: {path}")
        else:
            result = await run_elevated(
                ["powershell", "-NoProfile", "-NonInteractive", "-Command",
                 f"Add-MpPreference -ExclusionPath '{path}'"], timeout=60)
            if result.returncode == 0:
                log("SUCCESS", f"Added Windows Defender exclusion: {path}")
            else:
                log("WARN", f"Could not add Windows Defender exclusion: {path}")
        n += 1

    desktop = Path(os.path.expandvars(r"%USERPROFILE%\Desktop"))
    config_path = desktop / "nuxt.config.optimized.ts"
    scripts_path = desktop / "package-scripts-template.json"
    if dry_run:
        log("INFO", f"[DRY RUN] Would write {config_path} and {scripts_path}")
    else:
        config_path.write_text(NUXT_CONFIG_TEMPLATE, encoding="utf-8")
        scripts_path.write_text(json.dumps({"scripts": PACKAGE_SCRIPTS}, indent=2), encoding="utf-8")
        log("SUCCESS", f"Created optimized Nuxt config template: {config_path}")
        log("SUCCESS", f"Created package.json scripts template: {scripts_path}")
    n += 2

    log("INFO", "Nuxt 3 Windows optimization completed")
    return n


NUXT_CONFIG_TEMPLATE = """// Nuxt 3 Optimized Configuration - Windows
export default defineNuxtConfig({
  experimental: {
    payloadExtraction: false,
    renderJsonPayloads: true,
    typedPages: true,
    watcher: 'parcel'
  },
  nitro: {
    esbuild: { options: { target: 'esnext' } },
    minify: process.env.NODE_ENV === 'production',
    sourceMap: process.env.NODE_ENV === 'development'
  },
  vite: {
    optimizeDeps: { include: ['vue', '@vue/runtime-core', '@vue/runtime-dom'] },
    server: {
      fs: { strict: false },
      watch: { usePolling: false, ignored: ['**/node_modules/**', '**/.git/**'] }
    },
    build: {
      rollupOptions: { output: { manualChunks: { vendor: ['vue'], utils: ['lodash-es', 'date-fns'] } } }
    }
  },
  css: { devSourcemap: true },
  devtools: { enabled: process.env.NODE_ENV === 'development' },
  ssr: true,
  prerender: { crawlLinks: false },
  modules: ['@pinia/nuxt', '@nuxtjs/tailwindcss', '@vueuse/nuxt'],
  typescript: {
    strict: true,
    typeCheck: process.env.NODE_ENV === 'development' ? 'build' : false
  },
  build: { transpile: process.env.NODE_ENV === 'production' ? [] : undefined }
})
"""

PACKAGE_SCRIPTS = {
    "dev": "nuxt dev --host 0.0.0.0 --port 3000",
    "dev:turbo": "nuxt dev --host 0.0.0.0 --port 3000 --no-fork-ts-checker",
    "build": "nuxt build",
    "build:analyze": "nuxt build --analyze",
    "preview": "nuxt preview",
    "postinstall": "nuxt prepare",
    "clean": "nuxt cleanup",
    "clean:modules": "rimraf node_modules .nuxt .output",
    "type-check": "nuxt typecheck",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
}

PS_ALIASES = """
# Nuxt 3 Development Aliases - Added by nuxt3-optimization.py
function nuxt-dev { pnpm dev }
function nuxt-build { pnpm build }
function nuxt-clean { pnpm clean; Remove-Item -Recurse -Force .nuxt, .output -ErrorAction SilentlyContinue }
function nuxt-fresh { nuxt-clean; pnpm install }
function nuxt-analyze { pnpm build:analyze }
function nuxt-type-check { pnpm type-check }
function nuxt-create { param([string]$name); if (-not $name) { Write-Host "Usage: nuxt-create <project-name>"; return }; npx nuxi@latest init $name; Set-Location $name; pnpm install }
Set-Alias -Name nd -Value nuxt-dev
Set-Alias -Name nb -Value nuxt-build
Set-Alias -Name nc -Value nuxt-clean
Set-Alias -Name nf -Value nuxt-fresh
"""

WSL_SETUP_SCRIPT = """#!/bin/bash
echo "Starting Nuxt 3 WSL Optimization..."
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y
echo "Installing Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
echo "Installing build essentials..."
sudo apt-get install -y build-essential python3-dev
echo "Installing pnpm..."
curl -fsSL https://get.pnpm.io/install.sh | sh -
source ~/.bashrc
echo "Configuring pnpm..."
pnpm config set store-dir ~/.pnpm-store
pnpm config set cache-dir ~/.pnpm-cache
pnpm config set auto-install-peers true
pnpm config set shamefully-hoist true
echo "Installing global packages..."
pnpm add -g @nuxt/cli nuxi typescript @types/node rimraf cross-env
if ! git config --global user.name > /dev/null 2>&1; then
    echo "Please configure Git:"
    read -p "Enter your name: " git_name
    read -p "Enter your email: " git_email
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
fi
cat >> ~/.bashrc << 'EOL'
# Nuxt 3 Development Aliases
alias nd='pnpm dev'
alias nb='pnpm build'
alias nc='pnpm clean'
alias nf='rm -rf node_modules .nuxt .output && pnpm install'
alias na='pnpm build:analyze'
alias nt='pnpm type-check'
nuxt-create() {
    if [ -z "$1" ]; then
        echo "Usage: nuxt-create <project-name>"
        return 1
    fi
    npx nuxi@latest init "$1"
    cd "$1"
    pnpm install
}
EOL
echo "WSL optimization completed! Restart your WSL session to apply changes."
"""


def wsl_config_for(ram: float) -> str:
    memory, processors = ("16GB", "8") if ram >= 32 else (("4GB", "2") if ram <= 8 else ("8GB", "4"))
    return (
        "[wsl2]\n"
        f"memory={memory}\n"
        f"processors={processors}\n"
        "localhostForwarding=true\n"
        "swap=2GB\n"
        "swapFile=C:\\temp\\wsl-swap.vhdx\n\n"
        "[experimental]\n"
        "sparseVhd=true\n"
    )


async def optimize_wsl(distro: str, dry_run: bool) -> bool:
    log(f"INFO", f"Optimizing Nuxt 3 for WSL ({distro})...")
    env = await get_environment()
    if not env["wsl"]["installed"]:
        log("ERROR", "WSL is not installed. Please install WSL first.")
        return False

    script_path = Path(os.environ.get("TEMP", tempfile.gettempdir())) / "nuxt3-wsl-setup.sh"
    if dry_run:
        log("INFO", f"[DRY RUN] Would write {script_path} and execute it in {distro}")
        log("INFO", f"[DRY RUN] Would write .wslconfig: {wsl_config_for(env['system']['ram_gb']).splitlines()[1]}")
        return True

    script_path.write_text(WSL_SETUP_SCRIPT, encoding="utf-8", newline="\n")
    log("INFO", "Copying optimization script to WSL...")
    await run_command(["wsl.exe", "-d", distro, "cp", str(script_path), "/tmp/nuxt3-setup.sh"], timeout=60)
    await run_command(["wsl.exe", "-d", distro, "chmod", "+x", "/tmp/nuxt3-setup.sh"], timeout=30)
    log("INFO", "Executing optimization script in WSL (interactive; apt/pnpm prompts will show)...")
    result = await run_command(["wsl.exe", "-d", distro, "bash", "/tmp/nuxt3-setup.sh"], timeout=3600)
    if result.returncode != 0:
        log("WARN", f"WSL setup script exited {result.returncode}")

    wslconfig = Path(os.path.expandvars(r"%USERPROFILE%\.wslconfig"))
    if wslconfig.exists():
        backup = wslconfig.with_suffix(".wslconfig.nuxt-backup")
        shutil.copy2(wslconfig, backup)
        log("WARNING", f"Existing .wslconfig backed up to {backup} before overwrite")
    wslconfig.write_text(wsl_config_for(env["system"]["ram_gb"]), encoding="utf-8")
    log("SUCCESS", f"Created optimized .wslconfig: {wslconfig}")
    log("SUCCESS", "WSL Nuxt 3 optimization completed successfully")
    return True


async def install_prerequisites(dry_run: bool) -> int:
    log("INFO", "Installing Nuxt 3 prerequisites for Windows...")
    env = await get_environment()
    installed = 0

    winget_jobs = []
    if not env["nodejs"]["installed"] or not env["nodejs"]["lts"]:
        winget_jobs.append("OpenJS.NodeJS.LTS")
    if not env["git"]["installed"]:
        winget_jobs.append("Git.Git")
    npm_jobs = []
    if not env["package_managers"]["pnpm"]["installed"]:
        npm_jobs.append("pnpm@latest")
    npm_jobs += ["@nuxt/cli@latest", "nuxi@latest", "typescript@latest",
                 "@types/node@latest", "rimraf@latest", "cross-env@latest"]

    for pkg in winget_jobs:
        if dry_run:
            log("INFO", f"[DRY RUN] Would winget install {pkg}")
            installed += 1
            continue
        result = await run_command(
            ["winget", "install", pkg, "--accept-source-agreements", "--accept-package-agreements"],
            timeout=1800)
        if result.returncode == 0:
            log("SUCCESS", f"{pkg} installed successfully")
            installed += 1
        else:
            log("WARN", f"Failed to install {pkg} via winget")

    for pkg in npm_jobs:
        if dry_run:
            log("INFO", f"[DRY RUN] Would npm install -g {pkg}")
            installed += 1
            continue
        result = await run_command(_exec_args("npm", ["install", "-g", pkg]), timeout=600)
        if result.returncode == 0:
            log("SUCCESS", f"Installed global package: {pkg}")
            installed += 1
        else:
            log("WARN", f"Failed to install: {pkg}")
    return installed


async def test_performance() -> dict:
    log("INFO", "Testing Nuxt 3 performance and configuration...")
    env = await get_environment()
    results = {
        "nodejs": env["nodejs"]["installed"],
        "package_manager": env["package_managers"]["pnpm"]["installed"] or env["package_managers"]["npm"]["installed"],
        "git": env["git"]["installed"],
        "optimal_setup": False,
        "recommendations": [],
    }
    if env["nodejs"]["lts"] and env["package_managers"]["pnpm"]["installed"] and env["git"]["installed"]:
        results["optimal_setup"] = True
        log("SUCCESS", "Optimal Nuxt 3 setup detected!")
    else:
        if not env["nodejs"]["lts"]:
            results["recommendations"].append("Install Node.js LTS for best compatibility")
        if not env["package_managers"]["pnpm"]["installed"]:
            results["recommendations"].append("Install pnpm for faster package management")
        if not env["git"]["installed"]:
            results["recommendations"].append("Install Git for version control")
    if env["system"]["ram_gb"] < 8:
        results["recommendations"].append("Consider upgrading RAM to 8GB+ for better development experience")
    if not env["system"]["ssd"]:
        results["recommendations"].append("Consider using an SSD for faster build times")
    log("SUCCESS", "Performance test completed")
    return results


async def main_async() -> int:
    parser = argparse.ArgumentParser(description="Nuxt 3 optimization for Windows and WSL")
    parser.add_argument("action", choices=["env", "windows", "wsl", "prereqs", "performance"], nargs="?", default="performance")
    parser.add_argument("--dry-run", action="store_true", help="Preview actions without applying")
    parser.add_argument("--distro", default="Ubuntu", help="WSL distribution for the wsl action")
    parser.add_argument("--json", action="store_true", help="JSON output (env/performance)")
    args = parser.parse_args()

    if args.action == "env":
        data = await get_environment()
        print(json.dumps(data, indent=2) if args.json else json.dumps(data))
        return 0
    if args.action == "windows":
        return 0 if await optimize_windows(args.dry_run) >= 0 else 1
    if args.action == "wsl":
        return 0 if await optimize_wsl(args.distro, args.dry_run) else 1
    if args.action == "prereqs":
        return 0 if await install_prerequisites(args.dry_run) >= 0 else 1
    data = await test_performance()
    if args.json:
        print(json.dumps(data, indent=2))
    else:
        print(f"Optimal setup: {data['optimal_setup']}")
        for rec in data["recommendations"]:
            print(f"  - {rec}")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main_async()))
