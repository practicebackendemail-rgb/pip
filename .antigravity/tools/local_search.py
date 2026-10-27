#!/usr/bin/env python3
"""
Offline Context Distiller for Antigravity
Delegates codebase discovery and context filtering to local Ollama (qwen2.5-coder:7b),
with content-addressed disk caching, pure-Python regex fallback for Windows,
and zero external dependency requirements (uses urllib.request natively).
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
DEFAULT_MODEL = "qwen2.5-coder:7b"
CACHE_DIR = Path(".antigravity/.cache")
CACHE_DIR.mkdir(parents=True, exist_ok=True)

IGNORE_DIRS = {
    ".git",
    ".dart_tool",
    ".idea",
    ".gradle",
    "build",
    "android",
    "ios",
    "windows",
    "linux",
    "macos",
    "web",
    ".antigravity",
    "node_modules",
}


def run_ripgrep(query: str, paths: list[str], max_count: int = 15) -> str:
    """Perform fast regex/substring match across code files via rg or Python fallback."""
    cmd = ["rg", "-n", "--max-count", str(max_count), "--heading", "-e", query] + paths
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=15, encoding="utf-8")
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError, PermissionError):
        pass

    matches = []
    try:
        pattern = re.compile(query, re.IGNORECASE)
    except re.error:
        pattern = re.compile(re.escape(query), re.IGNORECASE)

    for p in paths:
        target_path = Path(p)
        if not target_path.exists():
            continue
        if target_path.is_file():
            _scan_file(target_path, pattern, matches, max_count)
        elif target_path.is_dir():
            for root, dirs, files in os.walk(target_path):
                dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
                for file in files:
                    if file.endswith((".dart", ".yaml", ".json", ".md", ".py")):
                        file_path = Path(root) / file
                        _scan_file(file_path, pattern, matches, max_count)
                        if len(matches) >= max_count:
                            break
                if len(matches) >= max_count:
                    break

    return "\n".join(matches)


def _scan_file(file_path: Path, pattern: re.Pattern, matches: list[str], max_count: int):
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            for idx, line in enumerate(f, start=1):
                if pattern.search(line):
                    matches.append(f"{file_path.as_posix()}:{idx}:{line.rstrip()}")
                    if len(matches) >= max_count:
                        return
    except Exception:
        pass


def cache_key(task_query: str, raw_matches: str, model: str) -> Path:
    """Content-addressed cache key so repeated queries skip re-inference."""
    h = hashlib.sha256(f"{model}:{task_query}:{raw_matches}".encode("utf-8")).hexdigest()
    return CACHE_DIR / f"{h}.json"


def distill_with_ollama(task_query: str, raw_matches: str, model: str = DEFAULT_MODEL, budget_tokens: int = 400) -> dict:
    """Use local model to distill code snippets into minimal necessary context."""
    if not raw_matches:
        return {"status": "empty", "distilled": "", "matches": 0, "files_touched": []}

    ck = cache_key(task_query, raw_matches, model)
    if ck.exists():
        try:
            return json.loads(ck.read_text(encoding="utf-8"))
        except Exception:
            pass

    prompt = f"""You are a code-context distiller. Output ONLY valid JSON, no prose.

Task: {task_query}
Raw matches:
{raw_matches[:8000]}

Return JSON with this exact shape:
{{"distilled": "<condensed code/context, file:line refs preserved, under {budget_tokens} tokens>", "files_touched": ["path:line", ...]}}

Rules:
- Strip comments, imports, boilerplate, unrelated functions.
- Keep only signatures/logic relevant to the task.
- Never fabricate file paths or line numbers not present in the raw matches.
"""

    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "format": "json",
        "options": {"temperature": 0.1, "num_predict": budget_tokens + 200},
    }

    try:
        req_data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            OLLAMA_URL,
            data=req_data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=25) as response:
            raw_body = response.read().decode("utf-8")
            raw_json = json.loads(raw_body)
            llm_text = raw_json.get("response", "{}")
            parsed = json.loads(llm_text)
            result = {"status": "ok", **parsed}
    except (urllib.error.URLError, ConnectionRefusedError, TimeoutError):
        result = {
            "status": "ollama_offline",
            "distilled": raw_matches[:1500],
            "files_touched": _extract_files(raw_matches),
        }
    except Exception as e:
        result = {
            "status": "error",
            "error": str(e),
            "distilled": raw_matches[:1500],
            "files_touched": _extract_files(raw_matches),
        }

    try:
        ck.write_text(json.dumps(result), encoding="utf-8")
    except Exception:
        pass

    return result


def _extract_files(raw_matches: str) -> list[str]:
    files = []
    for line in raw_matches.splitlines():
        parts = line.split(":", 2)
        if len(parts) >= 2 and parts[0] not in files:
            files.append(f"{parts[0]}:{parts[1]}")
    return files[:10]


def main():
    parser = argparse.ArgumentParser(description="Offline context distiller for Antigravity")
    parser.add_argument("--query", "-q", required=True, help="Intent or symbol to find")
    parser.add_argument("--paths", "-p", nargs="*", default=["lib"], help="Directories or files to search")
    parser.add_argument("--model", "-m", default=DEFAULT_MODEL, help="Ollama model to use")
    parser.add_argument("--budget", "-b", type=int, default=400, help="Approx. output token budget")
    parser.add_argument("--json", action="store_true", help="Emit structured JSON instead of plain text")

    args = parser.parse_args()

    raw_matches = run_ripgrep(args.query, args.paths)
    result = distill_with_ollama(args.query, raw_matches, args.model, args.budget)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(result.get("distilled", ""))
        if result.get("status") not in ("ok", "empty"):
            print(f"[status: {result['status']}]", file=sys.stderr)


if __name__ == "__main__":
    main()
