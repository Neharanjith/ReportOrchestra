#!/usr/bin/env python3
"""
extract_experiments.py — Phase 2 of agent-research-aggregator.

Three modes:

1. LIST-BATCHES MODE (default, no --process):
   Groups discovered files into ~40KB batches and prints them for manual
   LLM extraction by the host agent.

2. PROCESS MODE (--process):
   Automates the full extraction pipeline:
   - Reads discovered_logs.json
   - Groups files into batches
   - Pre-filters batches for relevance (skips junk batches)
   - Calls LLM in parallel across batches
   - Writes results incrementally to raw_experiments.json
   - Supports resume via checkpoint file

3. VALIDATE MODE (--validate-only):
   Validates raw_experiments.json meets schema.

Usage:
    # List batches (host agent processes each manually):
    python extract_experiments.py \\
        --discovered workspace/ara/discovered_logs.json \\
        --list-batches

    # Process all batches with parallel LLM calls:
    python extract_experiments.py \\
        --discovered workspace/ara/discovered_logs.json \\
        --process --out workspace/ara/raw_experiments.json

    # Resume from checkpoint:
    python extract_experiments.py \\
        --discovered workspace/ara/discovered_logs.json \\
        --process --out workspace/ara/raw_experiments.json --resume

    # Validate:
    python extract_experiments.py \\
        --out workspace/ara/raw_experiments.json --validate-only
"""

import argparse
import json
import os
import sys
import time
import re
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

try:
    import httpx
    HAS_HTTPX = True
except ImportError:
    HAS_HTTPX = False


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DEFAULT_BATCH_BYTES = 40000
MAX_FILE_BYTES = 200 * 1024
CHECKPOINT_SUFFIX = ".checkpoint"

REQUIRED_TOP_KEYS = {"experiments"}
EXPERIMENT_REQUIRED = {"experiment_id", "confidence"}
EXPERIMENT_ONE_OF = {"hypothesis", "method", "results", "research_question"}
VALID_CONFIDENCE = {"high", "medium", "low"}

# Relevance keywords — if a batch's concatenated text scores below
# RELEVANCE_THRESHOLD, the batch is skipped entirely (saves LLM calls).
RELEVANCE_KEYWORDS = {
    "accuracy": 3, "loss": 3, "f1": 3, "bleu": 3, "rouge": 3,
    "perplexity": 3, "latency": 2, "throughput": 2, "recall": 3,
    "precision": 3, "metric": 2, "baseline": 2, "benchmark": 2,
    "dataset": 2, "experiment": 2, "evaluation": 2, "test set": 2,
    "training": 2, "validation": 2, "hyperparameter": 2, "epoch": 2,
    "model": 1, "result": 1, "score": 1, "improve": 1, "performance": 1,
}
RELEVANCE_THRESHOLD = 8


# ---------------------------------------------------------------------------
# Batch listing
# ---------------------------------------------------------------------------

def load_manifest(discovered_path: str) -> dict:
    p = Path(discovered_path)
    if not p.exists():
        print(f"[ERROR] Manifest not found: {discovered_path}", file=sys.stderr)
        sys.exit(1)
    with p.open(encoding="utf-8") as f:
        return json.load(f)


def build_batches(manifest: dict, batch_bytes: int) -> list[list[dict]]:
    """Group manifest files into batches under batch_bytes budget."""
    files = manifest.get("files", [])
    batches: list[list[dict]] = []
    current_batch: list[dict] = []
    current_size = 0

    for entry in files:
        size = min(entry["size_bytes"], MAX_FILE_BYTES)
        if current_batch and current_size + size > batch_bytes:
            batches.append(current_batch)
            current_batch = []
            current_size = 0
        current_batch.append(entry)
        current_size += size

    if current_batch:
        batches.append(current_batch)
    return batches


def print_batches(manifest: dict, batch_bytes: int):
    files = manifest.get("files", [])
    batches = build_batches(manifest, batch_bytes)

    print(f"Total batches: {len(batches)}")
    print(f"Total files  : {len(files)}")
    print()
    for i, batch in enumerate(batches, 1):
        total = sum(min(e["size_bytes"], MAX_FILE_BYTES) for e in batch)
        print(f"--- Batch {i} ({len(batch)} files, ~{total // 1024} KB) ---")
        for entry in batch:
            trunc = " [TRUNCATED]" if entry.get("truncated") else ""
            print(f"  [{entry['priority']:6}] [{entry['agent']:12}] {entry['path']}{trunc}")
        print()


# ---------------------------------------------------------------------------
# Relevance pre-filtering
# ---------------------------------------------------------------------------

def score_relevance(text: str) -> int:
    """Score text for experiment-related content using keyword heuristics."""
    text_lower = text.lower()
    score = 0
    for keyword, weight in RELEVANCE_KEYWORDS.items():
        if keyword in text_lower:
            score += weight
    return score


def batch_text_preview(files: list[dict], manifest_dir: Path) -> str:
    """Read up to the first 8 KB of each file in a batch for relevance scoring."""
    parts = []
    total = 0
    limit = 32 * 1024  # 32 KB preview is enough for relevance scoring
    for entry in files:
        path = Path(entry["path"])
        if not path.exists():
            continue
        try:
            with path.open("r", encoding="utf-8", errors="replace") as f:
                chunk = f.read(2048)  # first 2 KB per file
            parts.append(chunk)
            total += len(chunk)
            if total > limit:
                break
        except OSError:
            continue
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# LLM extraction
# ---------------------------------------------------------------------------

def load_extraction_prompt() -> str:
    """Read extraction-prompt.md relative to this script."""
    script_dir = Path(__file__).resolve().parent.parent
    prompt_path = script_dir / "references" / "extraction-prompt.md"
    if prompt_path.exists():
        return prompt_path.read_text(encoding="utf-8")
    return _EMBEDDED_EXTRACTION_PROMPT


_EMBEDDED_EXTRACTION_PROMPT = """\
You are an experiment-log analyst. Your job is to read raw text from AI coding
agent logs and extract structured experiment information.

Return a JSON object with key "experiments" — an array of experiment records.
Each record has: experiment_id, source_files, confidence (high/medium/low),
research_question, hypothesis, method (approach, model_or_system, key_components),
setup (datasets, baselines, metrics, hyperparameters, hardware),
results (tables, key_numbers, qualitative), iterations, pii_stripped, warnings.

Extract ALL numeric results. Preserve units. Reconstruct tables.
Strip PII. Never fabricate data.

Return ONLY valid JSON. If no experiments found, return {"experiments": []}."""


def call_llm_for_extraction(system_prompt: str, batch_text: str,
                            model: str, base_url: str, api_key: str,
                            timeout: int) -> dict | None:
    """Call an OpenAI-compatible API for batch extraction."""
    if not HAS_HTTPX:
        print("[ERROR] httpx is required for --process mode. Install: pip install httpx",
              file=sys.stderr)
        return None
    try:
        with httpx.Client(timeout=httpx.Timeout(timeout, connect=30, read=timeout)) as client:
            resp = client.post(
                f"{base_url.rstrip('/')}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": batch_text[:MAX_FILE_BYTES]},
                    ],
                    "temperature": 0.1,
                    "max_tokens": 4096,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            content = data["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"  [ERROR] LLM call failed: {e}", file=sys.stderr)
        return None

    # Extract JSON from response
    json_match = re.search(r"```(?:json)?\s*(.*?)\s*```", content, re.DOTALL)
    json_str = json_match.group(1) if json_match else content.strip()
    try:
        return json.loads(json_str)
    except json.JSONDecodeError as e:
        print(f"  [ERROR] Failed to parse JSON from LLM: {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Checkpoint management
# ---------------------------------------------------------------------------

def checkpoint_path(out_path: str) -> str:
    return out_path + CHECKPOINT_SUFFIX


def load_checkpoint(chk_path: str) -> dict:
    try:
        with open(chk_path, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"completed_batches": [], "experiments": []}


def save_checkpoint(chk_path: str, completed: list[int], experiments: list[dict]):
    data = {
        "completed_batches": completed,
        "experiments": experiments,
        "updated_at": datetime.now(tz=timezone.utc).isoformat(),
    }
    tmp = chk_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, chk_path)


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------

def process_extraction(
    discovered_path: str,
    out_path: str,
    *,
    batch_bytes: int,
    max_workers: int,
    resume: bool,
    filter_relevance: bool,
    relevance_threshold: int,
):
    manifest = load_manifest(discovered_path)
    manifest_dir = Path(discovered_path).resolve().parent
    batches = build_batches(manifest, batch_bytes)
    total_batches = len(batches)

    chk_path = checkpoint_path(out_path)
    checkpoint = load_checkpoint(chk_path) if resume else {"completed_batches": [], "experiments": []}
    completed_set = set(checkpoint.get("completed_batches", []))
    all_experiments: list[dict] = checkpoint.get("experiments", [])

    print(f"Total batches: {total_batches}")
    print(f"Already completed: {len(completed_set)}")
    print(f"Remaining: {total_batches - len(completed_set)}")
    print()

    if not completed_set:
        # First run — write empty raw_experiments.json so downstream knows it exists
        Path(out_path).parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"experiments": []}, f)

    # Read system prompt once
    system_prompt = load_extraction_prompt()

    # LLM config from env
    model = os.environ.get("EXTRACTION_MODEL") or os.environ.get("LLM_MODEL", "")
    base_url = os.environ.get("EXTRACTION_BASE_URL") or os.environ.get("LLM_BASE_URL", "http://localhost:11434/v1")
    api_key = os.environ.get("EXTRACTION_API_KEY") or os.environ.get("LLM_API_KEY", "no-key-required")
    timeout = int(os.environ.get("LLM_TIMEOUT", "180"))

    if not model and HAS_HTTPX:
        print("[WARN] No LLM model configured. Set EXTRACTION_MODEL or LLM_MODEL.", file=sys.stderr)
        print("Proceeding with --list-batches equivalent. Use --list-batches for display.\n", file=sys.stderr)

    lock = threading.Lock()

    def process_batch(batch_idx: int) -> list[dict]:
        batch = batches[batch_idx]
        batch_num = batch_idx + 1

        if batch_num in completed_set:
            print(f"  Batch {batch_num}/{total_batches}: already completed, skipping")
            return []

        # Pre-filter relevance
        if filter_relevance:
            preview = batch_text_preview(batch, manifest_dir)
            score = score_relevance(preview)
            if score < relevance_threshold:
                print(f"  Batch {batch_num}/{total_batches}: low relevance (score={score}), skipping")
                return []

        # Read all file contents
        parts = []
        for entry in batch:
            path = Path(entry["path"])
            if not path.exists():
                continue
            try:
                with path.open("r", encoding="utf-8", errors="replace") as f:
                    text = f.read(MAX_FILE_BYTES)
                parts.append(f"--- {entry['path']} ---\n{text}")
            except OSError:
                continue

        if not parts:
            print(f"  Batch {batch_num}/{total_batches}: no readable files, skipping")
            return []

        batch_text = "\n\n".join(parts)
        print(f"  Batch {batch_num}/{total_batches}: extracting ({len(batch_text) // 1024} KB)...", end=" ")

        if model and HAS_HTTPX:
            result = call_llm_for_extraction(system_prompt, batch_text, model, base_url, api_key, timeout)
        else:
            print("no LLM configured, using empty result")
            return []

        if result is None:
            print("FAILED")
            return []

        experiments = result.get("experiments", [])
        for exp in experiments:
            exp.setdefault("source_files", [e["path"] for e in batch])
        print(f"ok ({len(experiments)} experiments)")
        return experiments

    # Process batches in parallel
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = {pool.submit(process_batch, i): i for i in range(total_batches)}
        for future in as_completed(futures):
            idx = futures[future]
            batch_num = idx + 1
            try:
                new_experiments = future.result()
            except Exception as e:
                print(f"  [ERROR] Batch {batch_num}/{total_batches} failed: {e}", file=sys.stderr)
                continue

            if new_experiments is None:
                continue

            with lock:
                all_experiments.extend(new_experiments)
                completed_set.add(batch_num)
                # Write checkpoint + raw output incrementally
                save_checkpoint(chk_path, sorted(completed_set), all_experiments)
                raw = {"experiments": all_experiments,
                       "generated_at": datetime.now(tz=timezone.utc).isoformat(),
                       "total_files": len(manifest.get("files", [])),
                       "total_batches": total_batches,
                       "completed_batches": len(completed_set)}
                with open(out_path, "w", encoding="utf-8") as f:
                    json.dump(raw, f, indent=2)

    # Summary
    high = sum(1 for e in all_experiments if e.get("confidence") == "high")
    med = sum(1 for e in all_experiments if e.get("confidence") == "medium")
    low = sum(1 for e in all_experiments if e.get("confidence") == "low")
    skipped = total_batches - len(completed_set)

    print(f"\n=== Extraction Complete ===")
    print(f"Batches processed: {len(completed_set)}/{total_batches}")
    if skipped:
        print(f"Batches skipped (low relevance): {skipped}")
    print(f"Total experiments: {len(all_experiments)}")
    print(f"  High confidence: {high}")
    print(f"  Medium confidence: {med}")
    print(f"  Low confidence: {low}")
    print(f"Checkpoint: {chk_path}")
    print(f"Output: {out_path}")


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def validate_experiments(out_path: str) -> bool:
    path = Path(out_path)
    if not path.exists():
        print(f"[ERROR] File not found: {out_path}", file=sys.stderr)
        return False

    try:
        with path.open(encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"[ERROR] Invalid JSON: {e}", file=sys.stderr)
        return False

    missing_top = REQUIRED_TOP_KEYS - set(data.keys())
    if missing_top:
        print(f"[ERROR] Missing top-level keys: {missing_top}", file=sys.stderr)
        return False

    experiments = data["experiments"]
    if not isinstance(experiments, list):
        print("[ERROR] 'experiments' must be a list", file=sys.stderr)
        return False

    if len(experiments) == 0:
        print("[WARN] 'experiments' array is empty — no extractable data found.")

    errors = []
    warnings = []

    for i, exp in enumerate(experiments):
        label = exp.get("experiment_id", f"[index {i}]")
        for key in EXPERIMENT_REQUIRED:
            if key not in exp:
                errors.append(f"{label}: missing required key '{key}'")

        if not any(k in exp for k in EXPERIMENT_ONE_OF):
            errors.append(f"{label}: must have at least one of {EXPERIMENT_ONE_OF}")

        conf = exp.get("confidence", "")
        if conf not in VALID_CONFIDENCE:
            errors.append(f"{label}: 'confidence' must be one of {VALID_CONFIDENCE}, got '{conf}'")

        results = exp.get("results", {})
        if isinstance(results, dict):
            for j, table in enumerate(results.get("tables", [])):
                if not isinstance(table.get("headers"), list):
                    errors.append(f"{label}: results.tables[{j}].headers must be a list")
                if not isinstance(table.get("rows"), list):
                    errors.append(f"{label}: results.tables[{j}].rows must be a list")

        if conf == "low":
            key_nums = results.get("key_numbers", []) if isinstance(results, dict) else []
            tables = results.get("tables", []) if isinstance(results, dict) else []
            if not key_nums and not tables:
                warnings.append(f"{label}: low confidence + no numeric data")

    for w in warnings:
        print(f"[WARN] {w}")

    if errors:
        for e in errors:
            print(f"[ERROR] {e}", file=sys.stderr)
        print(f"\nValidation FAILED: {len(errors)} error(s), {len(warnings)} warning(s)")
        return False

    print(f"Validation PASSED: {len(experiments)} experiment(s), {len(warnings)} warning(s)")
    high = sum(1 for e in experiments if e.get("confidence") == "high")
    med = sum(1 for e in experiments if e.get("confidence") == "medium")
    low = sum(1 for e in experiments if e.get("confidence") == "low")
    print(f"  Confidence: {high} high / {med} medium / {low} low")
    tables_total = sum(
        len(e.get("results", {}).get("tables", []))
        for e in experiments if isinstance(e.get("results"), dict)
    )
    print(f"  Result tables found: {tables_total}")
    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Phase 2: batch listing, automated extraction, and validation"
    )
    parser.add_argument("--discovered", default=None,
                        help="Path to discovered_logs.json")
    parser.add_argument("--out", default=None,
                        help="Path to raw_experiments.json")
    parser.add_argument("--list-batches", action="store_true",
                        help="Print batches for manual LLM processing")
    parser.add_argument("--batch-bytes", type=int, default=DEFAULT_BATCH_BYTES,
                        help=f"Soft byte budget per batch (default: {DEFAULT_BATCH_BYTES})")
    parser.add_argument("--validate-only", action="store_true",
                        help="Validate raw_experiments.json (requires --out)")
    parser.add_argument("--process", action="store_true",
                        help="Run automated extraction with parallel LLM calls")
    parser.add_argument("--resume", action="store_true",
                        help="Resume from checkpoint (requires --process)")
    parser.add_argument("--max-workers", type=int, default=4,
                        help="Max parallel LLM calls (default: 4)")
    parser.add_argument("--no-filter", action="store_true",
                        help="Disable relevance pre-filtering")
    parser.add_argument("--relevance-threshold", type=int, default=RELEVANCE_THRESHOLD,
                        help=f"Minimum relevance score to process a batch (default: {RELEVANCE_THRESHOLD})")
    args = parser.parse_args()

    if args.process:
        if not args.discovered or not args.out:
            print("[ERROR] --process requires --discovered and --out", file=sys.stderr)
            sys.exit(1)
        process_extraction(
            args.discovered,
            args.out,
            batch_bytes=args.batch_bytes,
            max_workers=args.max_workers,
            resume=args.resume,
            filter_relevance=not args.no_filter,
            relevance_threshold=args.relevance_threshold,
        )
        sys.exit(0)

    if args.list_batches:
        if not args.discovered:
            print("[ERROR] --list-batches requires --discovered", file=sys.stderr)
            sys.exit(1)
        manifest = load_manifest(args.discovered)
        print_batches(manifest, args.batch_bytes)
        sys.exit(0)

    if args.validate_only:
        if not args.out:
            print("[ERROR] --validate-only requires --out", file=sys.stderr)
            sys.exit(1)
        ok = validate_experiments(args.out)
        sys.exit(0 if ok else 1)

    parser.print_help()
    sys.exit(1)


if __name__ == "__main__":
    main()
