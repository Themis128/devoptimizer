#!/usr/bin/env python3
import os
import re
import json
from pathlib import Path


def _expand_batch_vars(text, bat_dir, root):
    """Expand the batch variables this checker understands."""
    text = text.replace('%DEVOPT_HOME%', str(root))
    # %~dp0 includes a trailing backslash in batch semantics
    text = text.replace('%~dp0..' + os.sep, str(bat_dir.parent) + os.sep)
    text = text.replace('%~dp0' + os.sep, str(bat_dir) + os.sep)
    text = text.replace('%~dp0', str(bat_dir) + os.sep)
    # Any remaining %VAR% falls back to the repo root
    text = re.sub(r'%[^%]+%', lambda m: str(root), text)
    return os.path.normpath(text)


def main():
    root = Path(r'D:\DevOptimizer')
    problems = []

    # 1. Batch launchers -> referenced ps1
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

        bat_dir = bat_path.parent

        # Directories this bat cd's into - '.\file.ps1' refs resolve against these
        cd_dirs = []
        for m in re.finditer(r'(?im)^\s*cd\s+(?:/d\s+)?"?([^"\r\n]+?)"?\s*$', content):
            cd_dirs.append(_expand_batch_vars(m.group(1).strip(), bat_dir, root))
        # Inline 'cd D:\path;' inside quoted -Command strings (elevated launchers)
        for m in re.finditer(r'\bcd\s+(?:/d\s+)?"?([A-Za-z]:[\\/][^"\'\s;]+)', content):
            cd_dirs.append(_expand_batch_vars(m.group(1).strip(), bat_dir, root))

        # .ps1 references: non-space/non-quote token ending in .ps1
        # (the old char-class pattern silently dropped backslash, truncating
        # every dir-containing ref to its basename -> 147 false positives)
        ps1_refs = re.findall(r'[^\s"()]+\.ps1', content)
        for ref in ps1_refs:
            ref = ref.strip()
            # Skip wildcard/glob refs (e.g. %BASE_DIR%\tools\*.ps1) - not file refs
            if '*' in ref:
                continue
            # Strip set "VAR=" assignment prefix if the token captured one
            if '=' in ref:
                ref = ref.split('=', 1)[1].strip('"')
            is_dotref = ref.startswith('.')

            expanded = _expand_batch_vars(ref, bat_dir, root)

            candidates = [
                expanded,
                os.path.join(str(root), expanded),
                os.path.join(str(root), os.path.basename(expanded)),
            ]
            if is_dotref:
                for d in cd_dirs:
                    candidates.append(os.path.join(d, expanded))

            found = False
            for cand in candidates:
                if os.path.isfile(cand):
                    found = True
                    break
            if not found:
                problems.append({
                    'Type': 'BAT->PS1',
                    'Launcher': str(bat_path.relative_to(root)),
                    'Target': ref,
                })

    # 2. Hub registry -> file paths
    reg_path = root / 'config' / 'hub-registry.json'
    if reg_path.is_file():
        try:
            with open(reg_path, 'r', encoding='utf-8') as f:
                reg_data = json.load(f)
        except Exception:
            reg_data = {}

        cmds = reg_data.get('commands', reg_data) if isinstance(reg_data, dict) else []
        if not isinstance(cmds, list):
            cmds = []

        for cmd in cmds:
            if not isinstance(cmd, dict):
                continue
            path_val = cmd.get('Path') or cmd.get('FilePath') or cmd.get('Script')
            if path_val and not os.path.exists(path_val):
                problems.append({
                    'Type': 'REGISTRY',
                    'Launcher': cmd.get('Id', 'Unknown'),
                    'Target': path_val,
                })

    # Output results
    print(f"=== Broken references: {len(problems)} ===")
    grouped = {}
    for p in problems:
        grouped.setdefault(p['Type'], []).append(p)
    for ptype, plist in grouped.items():
        print(f"  {ptype}: {len(plist)}")
    print()
    for p in sorted(problems, key=lambda x: (x['Type'], x['Launcher'])):
        print(f"[{p['Type']}] {p['Launcher']}")
        print(f"      -> {p['Target']}")


if __name__ == '__main__':
    main()
