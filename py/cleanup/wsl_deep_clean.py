#!/usr/bin/env python3
"""WSL deep clean - comprehensive WSL cleanup including journals, apt, docker, dev caches."""
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from pathlib import Path
from py.cleanup.utils import (
    Colors, mb, gb, get_free_space,
    write_header, write_done, write_warn, write_info, write_error,
    run_command
)

Colors.enable()


def main():
    write_header("WSL Deep Clean")
    
    # Check WSL distros
    result = run_command(["wsl", "-l", "-q"])
    if result.returncode != 0:
        write_warn("No WSL distros found")
        return
    
    distros = [d.strip() for d in result.stdout.strip().split('\n') if d.strip()]
    
    for distro in distros:
        print(f"> Cleaning WSL distro: {distro}")
        
        # Disk usage before
        result = run_command(["wsl", "-d", distro, "--", "df", "-h", "/"])
        if result.returncode == 0:
            write_info(f"Disk usage before:\n{result.stdout.strip()}")
        
        # Comprehensive cleanup commands
        cleanup_cmds = [
            # System packages
            ("apt clean", ["apt", "clean"]),
            ("apt autoclean", ["apt", "autoclean", "-y"]),
            ("apt autoremove", ["apt", "autoremove", "-y"]),
            ("apt lists refresh", ["apt", "update"]),
            
            # Journals
            ("journald (7 days)", ["journalctl", "--vacuum-time=7d"]),
            ("journald (size)", ["journalctl", "--vacuum-size=100M"]),
            
            # Temp
            ("temp folders", ["rm", "-rf", "/tmp/*", "/var/tmp/*"]),
            
            # Docker
            ("docker system prune", ["docker", "system", "prune", "-f"]),
            ("docker builder prune", ["docker", "builder", "prune", "-f"]),
            ("docker image prune", ["docker", "image", "prune", "-f"]),
            
            # Dev caches
            ("npm cache", ["npm", "cache", "clean", "--force"]),
            ("pip cache", ["pip", "cache", "purge"]),
            ("pnpm store", ["pnpm", "store", "prune"]),
            ("yarn cache", ["yarn", "cache", "clean"]),
            ("cargo cache", ["cargo", "clean"]),
            ("go cache", ["go", "clean", "-cache"]),
            ("ccache", ["ccache", "-C"]),
            
            # VS Code server caches
            ("VS Code CachedData", ["find", "/home", "-name", "CachedData", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("VS Code workspaceStorage", ["find", "/home", "-name", "workspaceStorage", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("VS Code logs", ["find", "/home", "-name", "logs", "-path", "*/.vscode-server/*", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("VS Code extensions cache", ["find", "/home", "-name", "extensions", "-path", "*/.vscode-server/*", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("VS Code node_modules", ["find", "/home", "-name", "node_modules", "-path", "*/.vscode-server/*", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            
            # Language server caches
            ("TypeScript cache", ["find", "/home", "-name", "typescript", "-path", "*/.cache/*", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("pylint cache", ["find", "/home", "-name", ".pylint.d", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("mypy cache", ["find", "/home", "-name", ".mypy_cache", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("ruff cache", ["find", "/home", "-name", ".ruff_cache", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("jedi cache", ["find", "/home", "-name", "jedi", "-path", "*/.cache/*", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("gopls cache", ["find", "/home", "-name", "gopls", "-path", "*/.cache/*", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("rust-analyzer cache", ["find", "/home", "-name", "rust-analyzer", "-path", "*/.cache/*", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            ("clangd cache", ["find", "/home", "-name", "clangd", "-path", "*/.cache/*", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            
            # Node modules (careful - requires npm install after)
            ("node_modules (user)", ["find", "/home", "-maxdepth", "3", "-name", "node_modules", "-type", "d", "-exec", "rm", "-rf", "{}", "+"]),
            
            # Editor temp files
            ("editor temp files", ["find", "/home", "-name", "*.swp", "-o", "-name", "*~", "-type", "f", "-delete"]),
            
            # Flatpak
            ("flatpak unused", ["flatpak", "uninstall", "--unused", "-y"]),
        ]
        
        for label, cmd in cleanup_cmds:
            result = run_command(["wsl", "-d", distro, "--"] + cmd, timeout=300)
            if result.returncode == 0:
                write_done(f"{distro}: {label}")
            else:
                stderr = result.stderr.strip().split('\n')[0] if result.stderr else "error"
                if "not found" in stderr.lower() or "command not found" in stderr.lower():
                    write_info(f"{distro}: {label} - not available")
                else:
                    write_warn(f"{distro}: {label} failed ({stderr[:80]})")
        
        # Disk usage after
        result = run_command(["wsl", "-d", distro, "--", "df", "-h", "/"])
        if result.returncode == 0:
            write_info(f"Disk usage after:\n{result.stdout.strip()}")
        
        write_info(f"WSL cleanup complete for {distro}. To compact virtual disk manually:")
        write_info("  wsl --shutdown")
        write_info("  Then use Disk Management or optimize-vhd on the .vhdx file")


if __name__ == "__main__":
    main()