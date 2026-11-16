"""Port of scripts/ml-frameworks-setup.ps1 — install ML frameworks:
--install-all (default), --tensorflow-only, --pytorch-only,
--jupyter-only, --verbose, --dry-run.
"""
import argparse
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

# CATEGORY: ai-ml
# TAGS: tensorflow, pytorch, jupyter, setup

PYTHON_URL = "https://www.python.org/ftp/python/3.11.5/python-3.11.5-amd64.exe"  # noqa: E501

TF_PKGS = ["tensorflow[gpu]", "tensorflow-hub", "tensorflow-datasets",
           "tensorflow-addons", "tensorflow-model-optimization"]
TORCH_PKGS = [["torch", "torchvision", "torchaudio", "--index-url",
               "https://download.pytorch.org/whl/cu118"],
              ["torch-geometric"],
              ["torch-scatter", "torch-sparse", "torch-cluster",
               "torch-spline-conv"],
              ["pytorch-lightning"], ["torchmetrics"]]
JUPYTER_PKGS = ["jupyterlab", "notebook", "ipywidgets",
                "jupyter_contrib_nbextensions"]
DATA_PKGS = ["pandas", "numpy", "matplotlib", "seaborn", "plotly",
             "scikit-learn", "scipy", "statsmodels", "opencv-python",
             "pillow", "requests", "beautifulsoup4", "lxml"]
EXTRA_PKGS = ["transformers", "datasets", "accelerate",
              "sentence-transformers", "openai", "langchain",
              "langchain-community", "streamlit", "gradio", "dash",
              "fastapi", "uvicorn", "mlflow", "black", "isort",
              "flake8", "mypy", "pytest", "pytest-cov", "pre-commit"]


def log(msg, level="INFO"):
    print(f"[{level}] {msg}")


def pip(args, dry):
    cmd = [sys.executable, "-m", "pip", "install"] + args
    if dry:
        print("[dry-run]", " ".join(cmd))
        return 0
    log("pip install " + " ".join(args))
    return subprocess.run(cmd).returncode


def ensure_python(dry):
    if shutil.which("python") or shutil.which("py"):
        return True
    log("Python not found. Installing Python...", "WARNING")
    if dry:
        log(f"[dry-run] download {PYTHON_URL} + /quiet install")
        return True
    tmp = Path(tempfile.gettempdir()) / "python-installer.exe"
    urllib.request.urlretrieve(PYTHON_URL, tmp)
    subprocess.run([str(tmp), "/quiet", "InstallAllUsers=1",
                    "PrependPath=1", "Include_test=0"], check=False)
    tmp.unlink(missing_ok=True)
    return shutil.which("python") is not None


def install_tf(dry):
    log("=== TensorFlow ===")
    for p in TF_PKGS:
        pip([p], dry)


def install_torch(dry):
    log("=== PyTorch ===")
    for grp in TORCH_PKGS:
        pip(grp, dry)


def install_jupyter(dry):
    log("=== Jupyter ===")
    for p in JUPYTER_PKGS + DATA_PKGS:
        pip([p], dry)


def install_extras(dry):
    log("=== Additional ML tools ===")
    for p in EXTRA_PKGS:
        pip([p], dry)


def main():
    ap = argparse.ArgumentParser(description="ML frameworks setup")
    ap.add_argument("--install-all", action="store_true")
    ap.add_argument("--tensorflow-only", action="store_true")
    ap.add_argument("--pytorch-only", action="store_true")
    ap.add_argument("--jupyter-only", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not (args.tensorflow_only or args.pytorch_only
            or args.jupyter_only):
        args.install_all = True
    if not ensure_python(args.dry_run):
        log("Python install failed", "ERROR")
        return 1
    if args.install_all or args.tensorflow_only:
        install_tf(args.dry_run)
    if args.install_all or args.pytorch_only:
        install_torch(args.dry_run)
    if args.install_all or args.jupyter_only:
        install_jupyter(args.dry_run)
    if args.install_all:
        install_extras(args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
