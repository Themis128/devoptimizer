"""Port of scripts/nvidia-pair-setup.ps1 — NVIDIA PAIR (Personal AI
Router) installer/manager. Flags: --status (default), --install,
--pull-models, --verify, --configure-cline, --models, --version,
--dry-run.
"""
import argparse
import ipaddress
import json
import os
import socket
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

# CATEGORY: ai-ml
# TAGS: nvidia, pair, ollama, setup

PAIR_EXE = r"C:\Program Files\PAIR\PAIR.exe"
PAIR_DATA_ROOT = str(Path(os.environ.get(
    "LOCALAPPDATA", "")) / "Nvidia Corporation" / "Personal AI Router")
ENGINE_OLLAMA_EXE = str(Path(PAIR_DATA_ROOT) / "engine-bin"
                        / "ollama" / "ollama.exe")
OLLAMA_RUNTIME = "http://127.0.0.1:11435"
PROXY_OPENAI = "http://127.0.0.1:11434"
PROXY_LMSTUDIO = "http://127.0.0.1:1234"
RELEASES_API = ("https://api.github.com/repos/NVIDIA/"
                "Personal-AI-Router/releases/latest")
CLINE_SETTINGS = (r"D:\DevOptimizer\scripts"
                  r"\cline-settings-nvidia-pair.json")


def status(msg, kind="Info"):
    print(f"[{kind}] {msg}")


def header(t):
    print(f"\n=== {t} ===")


_ENDPOINTS = ("api.github.com", "127.0.0.1", "localhost")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, hdrs, newurl):
        return None


def _local_proxy_ok(url):
    """Fixed local PAIR proxy: http + loopback-only resolution."""
    p = urllib.parse.urlparse(url)
    if p.scheme != "http" or (p.hostname or "").lower() \
            not in ("127.0.0.1", "localhost"):
        return False
    try:
        infos = socket.getaddrinfo(p.hostname, None)
    except OSError:
        return False
    return all(ipaddress.ip_address(i[4][0]).is_loopback
               for i in infos)


def _get(url, timeout=20):
    p = urllib.parse.urlparse(url)
    if p.scheme not in ("http", "https") \
            or p.hostname not in _ENDPOINTS:
        raise ValueError(f"endpoint not allowed: {url}")
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return json.loads(r.read())


def _models(url, timeout=5):
    try:
        return _get(url + "/v1/models", timeout).get("data", [])
    except Exception:
        return None


def test_installed():
    out = subprocess.run(["tasklist"], capture_output=True,
                         text=True).stdout
    svcs = sorted({ln.split(",")[0].strip('"')
                   for ln in out.splitlines()
                   if ln.lower().startswith("nvpair-")})
    return Path(PAIR_EXE).exists(), svcs


def latest_installer_url():
    try:
        rel = _get(RELEASES_API, 20)
        for a in rel.get("assets", []):
            if a["name"].startswith("NVPAIR-Setup-") and \
                    a["name"].endswith("-x64.exe"):
                status(f"Latest release: {rel.get('tag_name')}")
                return a["browser_download_url"]
    except Exception as e:
        status(f"Could not query releases API: {e}", "Warning")
    return None


def do_install(dry):
    header("Installing NVIDIA PAIR (official installer)")
    if Path(PAIR_EXE).exists():
        status("PAIR already installed at C:\\Program Files\\PAIR",
               "Success")
        return
    url = latest_installer_url()
    if not url:
        status("No installer URL found - download manually from "
               "https://github.com/NVIDIA/Personal-AI-Router/releases",
               "Error")
        return
    tmp = Path(tempfile.gettempdir()) / "NVPAIR-Setup-x64.exe"
    if dry:
        status(f"[dry-run] download {url} -> {tmp}; run {tmp} /S")
        return
    status(f"Downloading {url} ...")
    urllib.request.urlretrieve(url, tmp)
    status("Running silent install (/S)...")
    subprocess.run([str(tmp), "/S"]).returncode
    if Path(PAIR_EXE).exists():
        status("PAIR installed. Launch the desktop app (or run: "
               "nvpair for the terminal UI) to set up "
               "engines/pairing.", "Success")
    else:
        status("Install did not produce C:\\Program Files\\PAIR - "
               "check the installer window.", "Warning")


def show_status():
    header("NVIDIA PAIR Status")
    app, svcs = test_installed()
    status(f"Desktop app installed : {app}",
           "Success" if app else "Error")
    status(f"Service processes     : {len(svcs)}",
           "Success" if len(svcs) >= 8 else "Warning")
    for label, url in (("Router proxy (all chat models)",
                        PROXY_OPENAI),
                       ("LM Studio bridge", PROXY_LMSTUDIO),
                       ("Ollama engine", OLLAMA_RUNTIME)):
        m = _models(url)
        if m is None:
            status(f"{label:<22}: DOWN {url}", "Warning")
        else:
            status(f"{label:<22}: UP   {url}  ({len(m)} models)",
                   "Success")
    if Path(ENGINE_OLLAMA_EXE).exists():
        status("\nLocal engine models:")
        subprocess.run([ENGINE_OLLAMA_EXE, "list"])
    status("\nCluster: pair nodes via the desktop app (Settings -> "
           "Cluster) or terminal UI (Cluster tab, six-digit PIN).")


def pull_models(models, dry):
    header("Pulling models into PAIR engine")
    if not Path(ENGINE_OLLAMA_EXE).exists() and not dry:
        status("Bundled Ollama engine not found - is PAIR installed "
               "and run once?", "Error")
        return
    env = dict(os.environ, OLLAMA_HOST="127.0.0.1:11435")
    for m in models:
        status(f"Pulling {m} ...")
        if dry:
            status(f"[dry-run] {ENGINE_OLLAMA_EXE} pull {m}")
        else:
            subprocess.run([ENGINE_OLLAMA_EXE, "pull", m], env=env)
    if not dry:
        subprocess.run([ENGINE_OLLAMA_EXE, "list"], env=env)


def verify(dry):
    header("Verifying PAIR end-to-end")
    m = _models(PROXY_OPENAI, 10)
    if m is None:
        status("OpenAI proxy check failed", "Error")
    else:
        status(f"Cluster-wide models via {PROXY_OPENAI}:", "Success")
        for d in m:
            status(f"  {d.get('id')}")
        if m and all(str(d.get("id", "")).startswith("text-embedding")
                     for d in m):
            status("Only embedding models available - pull a chat "
                   "model (--pull-models).", "Warning")
    if dry:
        status("[dry-run] POST /v1/chat/completions inference test")
        return
    try:
        body = json.dumps({
            "model": "qwen2.5-coder:7b",
            "messages": [{"role": "user",
                          "content": "Reply with: PAIR OK"}],
            "max_tokens": 20}).encode()
        test_url = PROXY_OPENAI + "/v1/chat/completions"
        if not _local_proxy_ok(test_url):
            raise ValueError(f"endpoint not allowed: {test_url}")
        req = urllib.request.Request(
            test_url, data=body,
            headers={"Content-Type": "application/json"})
        with urllib.request.build_opener(_NoRedirect).open(
                req, timeout=180) as r:
            resp = json.loads(r.read())
        txt = resp["choices"][0]["message"]["content"]
        status(f"Inference test: {txt}", "Success")
    except Exception as e:
        status(f"Inference test failed: {e}", "Warning")


def configure_cline(dry):
    header("Configuring Cline for PAIR")
    dst = Path(os.environ.get("APPDATA", "")) / "Code" / "User" / \
        "globalStorage" / "saoudrizwan.claude-dev" / "settings"
    status(f"Template: {CLINE_SETTINGS}")
    status(f"Review and copy settings into Cline. Endpoint: "
           f"{PROXY_OPENAI}/v1")
    status("Models: plan=qwen3:4b  act=qwen2.5-coder:7b  "
           "(restart VS Code after change)")
    if dry:
        return
    dst.mkdir(parents=True, exist_ok=True)


def main():
    ap = argparse.ArgumentParser(
        description="NVIDIA PAIR setup/status")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--install", action="store_true")
    ap.add_argument("--pull-models", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--configure-cline", action="store_true")
    ap.add_argument("--models", nargs="+",
                    default=["qwen2.5-coder:7b", "qwen3:4b"])
    ap.add_argument("--version", default="latest")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not (args.install or args.pull_models or args.verify
            or args.configure_cline):
        args.status = True
    if args.install:
        do_install(args.dry_run)
    if args.pull_models:
        pull_models(args.models, args.dry_run)
    if args.configure_cline:
        configure_cline(args.dry_run)
    if args.verify:
        verify(args.dry_run)
    if args.status:
        show_status()
    return 0


if __name__ == "__main__":
    sys.exit(main())
