# Agent Instruction Manual: Offline Search & Context Delegation via Ollama

## Objective
Configure the workspace to delegate all raw codebase discovery, semantic search, and context filtering to a local Ollama instance. This dramatically reduces cloud token consumption in Antigravity by feeding only distilled, relevant code extracts into the cloud model's context window.

---

## Architecture & Workflow Overview
```
[User Task] 
     │
     ▼
[Antigravity Agent] ───(DO NOT read whole files directly)───┐
     │                                                      │
     ▼                                                      ▼
[Executes local_search.py via bash]                [Cloud Context Window]
     │                                                      ▲
     ├─► 1. ripgrep coarse filter                           │
     ├─► 2. AST / structural line slice                     │ (Dense context:
     └─► 3. Ollama local LLM context distiller ─────────────┘  ~300-600 tokens)
```

---

## Phase 1: Environment & Dependency Verification
The agent must run the following bash commands to verify prerequisites:

1. **Verify Ollama daemon is running:**
   ```bash
   curl -s http://127.0.0.1:11434/api/tags || echo "OLLAMA_OFFLINE"
   ```
   *If offline, start the service or prompt the user to run `ollama serve`.*

2. **Pull recommended lightweight models:**
   ```bash
   # Code distiller model (fast, small footprint, excellent instruction-following)
   ollama pull qwen2.5-coder:7b

   # Semantic embedding model (optional, for vector ranking)
   ollama pull nomic-embed-text
   ```

3. **Confirm the model actually pulled successfully:**
   ```bash
   curl -s http://127.0.0.1:11434/api/tags | grep -q "qwen2.5-coder" || echo "MODEL_MISSING"
   ```

4. **Verify search tools:**
   ```bash
   which rg || sudo apt-get install -y ripgrep
   python3 -c "import requests; print('requests installed')" || pip install requests
   ```

---

## Phase 2: Setup Workspace Scripts

Create the directory `.antigravity/tools/` if it does not exist, and deploy the distillation runner script.

### File: `.antigravity/tools/local_search.py`
```python
#!/usr/bin/env python3
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import requests

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
DEFAULT_MODEL = "qwen2.5-coder:7b"
CACHE_DIR = Path(".antigravity/.cache")
CACHE_DIR.mkdir(parents=True, exist_ok=True)


def run_ripgrep(query, paths, max_count=15):
    """Perform fast regex/substring match across code files."""
    cmd = ["rg", "-n", "--max-count", str(max_count), "--heading", "-e", query] + paths
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    except subprocess.TimeoutExpired:
        return ""
    return res.stdout.strip()


def cache_key(task_query, raw_matches, model):
    """Content-addressed cache key so repeated queries skip re-inference."""
    h = hashlib.sha256(f"{model}:{task_query}:{raw_matches}".encode()).hexdigest()
    return CACHE_DIR / f"{h}.json"


def distill_with_ollama(task_query, raw_matches, model=DEFAULT_MODEL, budget_tokens=400):
    """Use local model to distill code snippets into minimal necessary context."""
    if not raw_matches:
        return {"status": "empty", "distilled": "", "matches": 0}

    ck = cache_key(task_query, raw_matches, model)
    if ck.exists():
        return json.loads(ck.read_text())

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
        r = requests.post(OLLAMA_URL, json=payload, timeout=45)
        r.raise_for_status()
        raw = r.json().get("response", "{}")
        parsed = json.loads(raw)
        result = {"status": "ok", **parsed}
    except requests.exceptions.ConnectionError:
        result = {"status": "ollama_offline", "distilled": raw_matches[:1500], "files_touched": []}
    except Exception as e:
        result = {"status": "error", "error": str(e), "distilled": raw_matches[:1500], "files_touched": []}

    ck.write_text(json.dumps(result))
    return result


def main():
    parser = argparse.ArgumentParser(description="Offline context distiller for Antigravity")
    parser.add_argument("--query", "-q", required=True, help="Intent or symbol to find")
    parser.add_argument("--paths", "-p", nargs="*", default=["."], help="Directories or files to search")
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
            print(f"[warn: {result['status']}]", file=sys.stderr)


if __name__ == "__main__":
    main()
```

Make the script executable:
```bash
chmod +x .antigravity/tools/local_search.py
```

---

## Phase 3: Antigravity Agent Operational Rules

Add the following rules to `.antigravity/rules` or prepend to project operational instructions:

```markdown
### RULE: STRICT TOKEN CONSERVATION & CONTEXT DELEGATION

1. PROHIBITED ACTIONS:
   - NEVER dump entire source files (>100 lines) into the context window.
   - NEVER run recursive `cat`, `grep -R`, or broad file exploration commands that output unparsed code blocks directly to stdout.

2. MANDATORY CONTEXT GATHERING PROTOCOL:
   - Before planning edits or answering architecture questions, invoke the local context assistant:
     `python3 .antigravity/tools/local_search.py --query "<exact feature or error target>" --paths <directory> --json`
   - Only open or edit specific files and targeted line ranges identified by the local summary
     (use the `files_touched` field from the JSON output as the source of truth).
   - If exact line inspection is needed, use targeted line reads (e.g., `sed -n '40,80p' path/to/file`) instead of reading whole files.

3. EXCEPTION:
   - Files under 40 lines may be read directly via `view`/`cat` without invoking local_search.py —
     the distillation overhead isn't worth it below that size.

4. FAILURE HANDLING:
   - If the tool reports `"status": "ollama_offline"` or `"status": "error"`, fall back to the raw
     ripgrep output it returns rather than blocking the task, and surface a one-line warning to the user.
```

---

## Phase 4: Self-Test Verification
Run a verification pass to ensure the setup works without cloud token consumption:

1. Test query execution:
   ```bash
   python3 .antigravity/tools/local_search.py --query "class " --paths . --json
   ```
2. Confirm the response is valid JSON containing distilled symbols, correct `files_touched` references, and zero unnecessary conversational tokens.
3. Re-run the same command and confirm the second call returns instantly (cache hit) rather than re-invoking Ollama.
