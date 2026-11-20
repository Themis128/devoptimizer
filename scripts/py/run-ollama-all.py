"""Ollama multi-model runner (Python port of tools/run-ollama-all.ps1).

Runs a prompt across all installed Ollama models via the REST API
(:11434/api/tags + /api/generate), laptop-tuned concurrency, timestamped
output folder with per-model files + aggregate.md.
Exit codes: 0 all ok, 2 partial, 3 none, 1 fatal.
"""

import argparse
import concurrent.futures
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

# CATEGORY: utilities
# TAGS: ollama, ai, runner

API = "http://localhost:11434"


def http_json(path: str, payload: dict | None, timeout: int) -> dict:
    # SSRF guard: only the fixed local ollama API is reachable.
    url = API + path
    p = urllib.parse.urlparse(url)
    if p.scheme != "http" or p.hostname not in ("localhost",
                                                "127.0.0.1"):
        raise ValueError(f"endpoint not allowed: {url}")
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def run_model(model: str, prompt: str, timeout: int) -> dict:
    try:
        resp = http_json("/api/generate",
                         {"model": model, "prompt": prompt, "stream": False},
                         timeout)
        return {"model": model, "success": True, "response": resp.get("response", "")}
    except Exception as e:  # noqa: BLE001 - per-model failure is reported, not fatal
        return {"model": model, "success": False, "error": str(e)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--prompt")
    src.add_argument("--prompt-file")
    parser.add_argument("--output-dir", default="logs")
    parser.add_argument("--concurrency", type=int, default=2)
    parser.add_argument("--config-file", default="configs/system-config.json")
    parser.add_argument("--timeout-seconds", type=int, default=300)
    args = parser.parse_args()

    prompt = Path(args.prompt_file).read_text(encoding="utf-8") \
        if args.prompt_file else args.prompt
    if not prompt.strip():
        print("prompt is empty", file=sys.stderr)
        sys.exit(1)

    allow: list[str] = []
    deny: list[str] = []
    cfg = Path(args.config_file)
    if cfg.exists():
        try:
            c = json.loads(cfg.read_text(encoding="utf-8"))
            allow = c.get("allow") or []
            deny = c.get("deny") or []
            if c.get("concurrency"):
                args.concurrency = c["concurrency"]
        except json.JSONDecodeError as e:
            print(f"warn: config parse failed: {e}", file=sys.stderr)

    try:
        models = [m["name"] for m in http_json("/api/tags", None, 30)["models"]]
    except Exception as e:  # noqa: BLE001
        print(f"cannot list models: {e}", file=sys.stderr)
        sys.exit(1)
    if allow:
        models = [m for m in models if any(a in m for a in allow)]
    if deny:
        models = [m for m in models if not any(d in m for d in deny)]
    if not models:
        print("no models selected", file=sys.stderr)
        sys.exit(1)

    stamp = time.strftime("%Y%m%d-%H%M%S")
    out_dir = Path(args.output_dir) / f"ollama-run-{stamp}"
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"running {len(models)} models, concurrency {args.concurrency}",
          file=sys.stderr)

    results = []
    with concurrent.futures.ThreadPoolExecutor(
            max_workers=args.concurrency) as pool:
        futs = {pool.submit(run_model, m, prompt, args.timeout_seconds): m
                for m in models}
        for fut in concurrent.futures.as_completed(futs):
            r = fut.result()
            results.append(r)
            safe = r["model"].replace(":", "_").replace("/", "_")
            (out_dir / f"{safe}.txt").write_text(
                r.get("response") or f"ERROR: {r.get('error')}", encoding="utf-8")
            print(f"  {r['model']}: {'ok' if r['success'] else r['error']}",
                  file=sys.stderr)

    ok = sum(1 for r in results if r["success"])
    agg = out_dir / "aggregate.md"
    with agg.open("w", encoding="utf-8") as f:
        f.write(f"# Ollama run {stamp} — {ok}/{len(results)} ok\n\n")
        f.write(f"Prompt ({len(prompt)} chars):\n\n```\n{prompt}\n```\n\n")
        for r in results:
            f.write(f"## {r['model']}\n\n")
            f.write((r.get("response") or f"ERROR: {r.get('error')}") + "\n\n")
    print(f"aggregate: {agg}", file=sys.stderr)

    sys.exit(0 if ok == len(results) else (3 if ok == 0 else 2))


if __name__ == "__main__":
    main()
