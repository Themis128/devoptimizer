#!/usr/bin/env python3
import os
import re
import json
from pathlib import Path

def main():
    root = Path(r'D:\DevOptimizer')
    problems = []

    # 1. Batch launchers -> referenced ps1
    # Find .bat and .cmd files in portable and root
    bat_files = []
    portable_dir = root / 'portable'
    if portable_dir.is_dir():
        bat_files.extend(portable_dir.rglob('*.bat'))
        bat_files.extend(portable_dir.rglob('*.cmd'))
    bat_files.extend(root.glob('*.bat'))
    bat_files.extend(root.glob('*.cmd'))

    for bat_path in bat_files:
        try:
            content = bat_path.read_text(encoding='utf-8', errors='ignore')
        except Exception:
            continue

        # Find .ps1 references: alphanumeric, underscores, hyphens, dots, backslashes, percent, dollar, tilde, space, ending with .ps1
        # We'll use a regex to capture potential .ps1 file references
        ps1_refs = re.findall(r'[A-Za-z0-9_\\-\\.\\%\$~ ]+\.ps1', content)
        for ref in ps1_refs:
            ref = ref.strip()
            # Expand variables
            expanded = ref.replace('%DEVOPT_HOME%', str(root))
            # Handle %~dp0 and %~dp0.. (batch file directory)
            bat_dir = bat_path.parent
            expanded = expanded.replace('%~dp0\\', str(bat_dir) + os.sep)
            expanded = expanded.replace('%~dp0..\\', str(bat_dir.parent) + os.sep)
            # Replace any other %VAR% with root (as a fallback)
            expanded = re.sub(r'%[^%]+%', lambda m: str(root), expanded)
            # Normalize path
            expanded = os.path.normpath(expanded)

            # Check if the expanded path exists as a file
            candidates = [
                expanded,
                os.path.join(str(root), expanded),
                os.path.join(str(root), os.path.basename(expanded))
            ]
            found = False
            for cand in candidates:
                if os.path.isfile(cand):
                    found = True
                    break
            if not found:
                problems.append({
                    'Type': 'BAT->PS1',
                    'Launcher': str(bat_path.relative_to(root)),
                    'Target': ref
                })

    # 2. Hub registry -> file paths
    reg_path = root / 'config' / 'hub-registry.json'
    if reg_path.is_file():
        try:
            with open(reg_path, 'r', encoding='utf-8') as f:
                reg_data = json.load(f)
        except Exception:
            reg_data = {}

        # The registry might have a 'commands' key or be the commands directly
        cmds = reg_data.get('commands', reg_data) if isinstance(reg_data, dict) else []
        if not isinstance(cmds, list):
            cmds = []

        for cmd in cmds:
            if not isinstance(cmd, dict):
                continue
            # Get the path from various possible keys
            path_val = cmd.get('Path') or cmd.get('FilePath') or cmd.get('Script')
            if path_val:
                # Check if the path exists
                if not os.path.exists(path_val):
                    problems.append({
                        'Type': 'REGISTRY',
                        'Launcher': cmd.get('Id', 'Unknown'),
                        'Target': path_val
                    })

    # Output results
    print(f"=== Broken references: {len(problems)} ===")
    # Group by Type
    grouped = {}
    for p in problems:
        grouped.setdefault(p['Type'], []).append(p)
    for ptype, plist in grouped.items():
        print(f"  {ptype}: {len(plist)}")
    print()
    # Sort by Type, then Launcher
    for p in sorted(problems, key=lambda x: (x['Type'], x['Launcher'])):
        print(f"[{p['Type']}] {p['Launcher']}")
        print(f"      -> {p['Target']}")

if __name__ == '__main__':
    main()