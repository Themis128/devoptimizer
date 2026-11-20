"""Port of tools/Variants/OLLAMA-MULTI-MODEL-SYSTEM-STATUS-NoAdmin.bat
— reports Ollama CLI version, model list, core files presence
(5 expected), count of ollama-*.bat scripts referencing
ollama-batch-helper.bat, 'ollama run qwen' leftovers and
Invoke-OllamaMultiModelAnalysis in ai-integration-module.ps1.
"""
import shutil
import subprocess
import sys
from pathlib import Path

VARIANTS_DIR = Path(__file__).resolve().parents[1].parent / "tools" / "Variants"
OUT_DIR = VARIANTS_DIR / "ai-analysis"


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, **kw).returncode
    except FileNotFoundError:
        print(f"[WARNING] tool not found: {cmd[0]}")
        return 127


def ps_to_json(ps_cmd, dest):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = Path(dest).resolve()
    root = OUT_DIR.resolve()
    if ".." in p.parts or not p.is_relative_to(root):
        raise ValueError("dest escapes the allowed output directory")
    with p.open("w", encoding="utf-8") as f:
        subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass",
             "-Command",
             "try { " + ps_cmd + " | ConvertTo-Json } catch { '{}' }"],
            stdout=f, stderr=subprocess.DEVNULL)


def find_tool(name):
    for cand in (VARIANTS_DIR.parent / name,
                 VARIANTS_DIR / name,
                 VARIANTS_DIR / "tools" / name,
                 VARIANTS_DIR.parent / "tools" / name):
        if cand.exists():
            return cand
    return VARIANTS_DIR / "tools" / name


def helper(prompt, out):
    bat = find_tool("ollama-batch-helper.bat")
    return run(["cmd", "/c", str(bat), "-prompt", prompt,
                "-output", str(OUT_DIR / out)])

CORE = ["tools/ollama-utils.ps1", "tools/run-ollama-all.ps1",
        "tools/ollama-batch-helper.bat",
        "RUN-OLLAMA-ALL-MODELS.bat", "configs/ollama.config.json"]


def main():
    if shutil.which("ollama"):
        run(["ollama", "--version"])
        run(["ollama", "list"])
    else:
        print("[WARNING] ollama not found in PATH")
    wd = VARIANTS_DIR
    root = wd.parent.parent
    core = sum(1 for c in CORE
               if (wd / c).exists() or (root / c).exists())
    print(f"Core files present: {core}/5")
    updated = 0
    for f in wd.glob("ollama-*.bat"):
        try:
            if "ollama-batch-helper.bat" in f.read_text(
                    encoding="utf-8", errors="replace"):
                updated += 1
        except OSError:
            pass
    print(f"Scripts using ollama-batch-helper: {updated}")
    qwen_left = [f.name for f in wd.glob("ollama-*.bat")
                 if "ollama run qwen" in f.read_text(
                     encoding="utf-8", errors="replace")]
    if qwen_left:
        print("[WARNING] 'ollama run qwen' leftovers:", qwen_left)
    aim = wd / "ai-integration-module.ps1"
    has_fn = aim.exists() and ("Invoke-OllamaMultiModelAnalysis"
        in aim.read_text(encoding="utf-8", errors="replace"))
    print(f"ai-integration-module has "
          f"Invoke-OllamaMultiModelAnalysis: {has_fn}")
    if core == 5 and updated >= 5:
        print("[SUCCESS] Ollama multi-model system fully deployed")
        return 0
    if core < 5:
        print(f"[WARNING] Missing {5 - core} core file(s)")
    if updated < 5:
        print(f"[WARNING] Only {updated} scripts updated "
              "(expected >=5)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
