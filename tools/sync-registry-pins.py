"""Sync registry count pins from the live hub-registry.json.

Rewrites the count assertions in .github/workflows/ci.yml (2 spots) and
app/DevOptimizer.App.Tests/RegistryServiceTests.cs (total + category dict)
so a registry regen no longer needs a manual pin dance. Run after every
Build-Registry.ps1 -Force.

Exit 0 = pins in sync (no changes) or successfully updated.
"""

import json
import re
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CI = REPO / ".github" / "workflows" / "ci.yml"
TESTS = REPO / "app" / "DevOptimizer.App.Tests" / "RegistryServiceTests.cs"
REGISTRY = REPO / "config" / "hub-registry.json"


def _contained(p: Path) -> Path:
    """Containment guard: the resolved path must stay inside the repo."""
    resolved = p.resolve()
    if resolved.parent != REPO and REPO not in resolved.parents:
        raise ValueError(f"path escapes repo: {p}")
    return resolved


def read_text_preserve(path: Path) -> str:
    """Read preserving original CRLF/LF (default text mode normalizes them)."""
    with _contained(path).open(encoding="utf-8-sig", newline="") as f:
        return f.read()


def write_text_preserve(path: Path, text: str) -> None:
    with _contained(path).open("w", encoding="utf-8", newline="") as f:
        f.write(text)


def main() -> int:
    reg = json.load(open(REGISTRY, encoding="utf-8-sig"))
    cmds = reg["commands"]
    total = len(cmds)
    cats = dict(sorted(Counter(c["category"] for c in cmds).items()))
    print(f"live registry: {total} commands, {len(cats)} categories")

    changed = False

    ci_text = read_text_preserve(CI)
    # Line-specific: the "Missing descriptions (expected 0)" pin must NOT move.
    new_ci, n1 = re.subn(
        r'(Commands: \$cmdCount \(expected )\d+(\))', rf"\g<1>{total}\g<2>", ci_text
    )
    new_ci, n2 = re.subn(
        r"(if \(\$cmdCount -ne )\d+(\))", rf"\g<1>{total}\g<2>", new_ci
    )
    new_ci, n3 = re.subn(
        r"(Command count mismatch: \$cmdCount != )\d+", rf"\g<1>{total}", new_ci
    )
    if new_ci != ci_text:
        write_text_preserve(CI, new_ci)
        print(f"ci.yml: {n1 + n2} pin(s) -> {total}")
        changed = True
    else:
        print("ci.yml: already in sync")

    t_text = read_text_preserve(TESTS)
    # Anchor to the LIVE-registry test only — the fixture test asserts
    # Assert.Equal(8, snapshot.Commands.Count) and must never be touched.
    new_tests, n_total = re.subn(
        r"(LoadSnapshot\(livePath\);\s*(?:\r?\n\s*)?Assert\.Equal\()\d+(, snapshot\.Commands\.Count\))",
        rf"\g<1>{total}\g<2>",
        t_text,
    )
    if n_total == 0:
        print("ERROR: live pin anchor not found in RegistryServiceTests.cs")
        return 1
    dict_block = re.search(
        r"(var expectedCounts = new Dictionary<string, int>\s*\{)(.*?)(\};)", new_tests, re.S
    )
    if dict_block:
        nl = "\r\n" if "\r\n" in t_text else "\n"
        indent = "            "
        entries = "".join(f'{indent}["{k}"] = {v},{nl}' for k, v in cats.items())
        replacement = (
            dict_block.group(1) + nl + entries + "        " + dict_block.group(3)
        )
        new_tests = new_tests[: dict_block.start()] + replacement + new_tests[dict_block.end():]
    if new_tests != t_text:
        write_text_preserve(TESTS, new_tests)
        print(f"RegistryServiceTests.cs: pins -> {total} + {len(cats)}-category dict")
        changed = True
    else:
        print("RegistryServiceTests.cs: already in sync")

    if not changed:
        print("PINS IN SYNC")
    return 0


if __name__ == "__main__":
    sys.exit(main())
