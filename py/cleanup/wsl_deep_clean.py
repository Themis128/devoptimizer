#!/usr/bin/env python3
"""WSL deep clean - comprehensive WSL cleanup including journals, apt, docker, dev caches."""
import sys
import shlex
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from py.cleanup.utils import (
    Colors, mb, gb, get_free_space,
    write_header, write_done, write_warn, write_info, write_error,
    run_command
)

Colors.enable()


def run_wsl_cmd(distro: str, cmd_str: str, use_shell: bool, timeout: int = 300) -> bool:
    """Run a command in WSL distro. Returns True on success."""
    if use_shell:
        full_cmd = ["wsl", "-d", distro, "--", "bash", "-c", cmd_str]
        result = run_command(full_cmd, timeout=timeout, shell=False)
    else:
        cmd_args = shlex.split(cmd_str)
        full_cmd = ["wsl", "-d", distro, "--"] + cmd_args
        result = run_command(full_cmd, timeout=timeout, shell=False)
    return result.returncode == 0


def main():
    write_header("WSL Deep Clean")
    
    # Check WSL distros - wsl -l -q outputs UTF-16-LE on Windows
    result = run_command(["wsl", "-l", "-q"], encoding="utf-16-le")
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
        # Each entry: (label, command, use_shell)
        # Note: Some commands require sudo and will be skipped if no passwordless sudo
        cleanup_cmds = [
            # System packages (need sudo - will be attempted)
            ("apt clean", "sudo -n apt clean", False),
            ("apt autoclean", "sudo -n apt autoclean -y", False),
            ("apt autoremove", "sudo -n apt autoremove -y", False),
            ("apt lists refresh", "sudo -n apt update", False),
            
            # Journals (need sudo)
            ("journald (7 days)", "sudo -n journalctl --vacuum-time=7d", False),
            ("journald (size)", "sudo -n journalctl --vacuum-size=100M", False),
            
            # Temp (user-level, no sudo)
            ("temp folders", "rm -rf /tmp/* /var/tmp/*", True),
            
            # Docker (try without sudo first, then with)
            ("docker system prune", "docker system prune -f", False),
            ("docker builder prune", "docker builder prune -f", False),
            ("docker image prune", "docker image prune -f", False),
            
            # Dev caches (user-level)
            ("npm cache", "npm cache clean --force", False),
            ("pip cache", "pip cache purge", False),
            ("pnpm store", "pnpm store prune", False),
            ("yarn cache", "yarn cache clean", False),
            ("cargo cache", "cargo clean", False),
            ("go cache", "go clean -cache", False),
            ("ccache", "ccache -C", False),
            
            # VS Code server caches (user-level)
            ("VS Code CachedData", "find /home -name CachedData -type d -exec rm -rf {} +", True),
            ("VS Code workspaceStorage", "find /home -name workspaceStorage -type d -exec rm -rf {} +", True),
            ("VS Code logs", "find /home -name logs -path '*/.vscode-server/*' -type d -exec rm -rf {} +", True),
            ("VS Code extensions cache", "find /home -name extensions -path '*/.vscode-server/*' -type d -exec rm -rf {} +", True),
            ("VS Code node_modules", "find /home -name node_modules -path '*/.vscode-server/*' -type d -exec rm -rf {} +", True),
            
            # Language server caches (user-level)
            ("TypeScript cache", "find /home -name typescript -path '*/.cache/*' -type d -exec rm -rf {} +", True),
            ("pylint cache", "find /home -name .pylint.d -type d -exec rm -rf {} +", True),
            ("mypy cache", "find /home -name .mypy_cache -type d -exec rm -rf {} +", True),
            ("ruff cache", "find /home -name .ruff_cache -type d -exec rm -rf {} +", True),
            ("jedi cache", "find /home -name jedi -path '*/.cache/*' -type d -exec rm -rf {} +", True),
            ("gopls cache", "find /home -name gopls -path '*/.cache/*' -type d -exec rm -rf {} +", True),
            ("rust-analyzer cache", "find /home -name 'rust-analyzer' -path '*/.cache/*' -type d -exec rm -rf {} +", True),
            ("clangd cache", "find /home -name clangd -path '*/.cache/*' -type d -exec rm -rf {} +", True),
            
            # Node modules (user-level)
            ("node_modules (user)", "find /home -maxdepth 3 -name node_modules -type d -exec rm -rf {} +", True),
            
            # Editor temp files (user-level)
            ("editor temp files", "find /home -name '*.swp' -o -name '*~' -type f -delete", True),
            
            # Flatpak (user-level)
            ("flatpak unused", "flatpak uninstall --unused -y", False),
        ]
        
        for label, cmd_str, use_shell in cleanup_cmds:
            success = run_wsl_cmd(distro, cmd_str, use_shell)
            if success:
                write_done(f"{distro}: {label}")
            else:
                # Try to get error for better reporting
                if use_shell:
                    full_cmd = ["wsl", "-d", distro, "--", "bash", "-c", cmd_str]
                else:
                    cmd_args = shlex.split(cmd_str)
                    full_cmd = ["wsl", "-d", distro, "--"] + cmd_args
                result = run_command(full_cmd, timeout=300, shell=False)
                stderr = result.stderr.strip().split('\n')[0] if result.stderr else "error"
                if "not found" in stderr.lower() or "command not found" in stderr.lower():
                    write_info(f"{distro}: {label} - not available")
                elif "interactive authentication" in stderr.lower() or "permission denied" in stderr.lower():
                    write_warn(f"{distro}: {label} - needs sudo (run manually)")
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