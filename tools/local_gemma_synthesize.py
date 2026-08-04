#!/usr/bin/env python3
"""Map-reduce evidence synthesis using a local Ollama model only."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from urllib.request import Request, urlopen


def generate(model: str, prompt: str) -> str:
    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.1, "num_ctx": 131072},
    }).encode()
    request = Request(
        "http://127.0.0.1:11434/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    with urlopen(request, timeout=1800) as response:
        return json.load(response)["response"]


def chunks(text: str, target: int = 70_000) -> list[str]:
    sections = text.split("\n### Source: ")
    result, current = [], ""
    for index, section in enumerate(sections):
        part = section if index == 0 else "\n### Source: " + section
        if current and len(current) + len(part) > target:
            result.append(current)
            current = part
        else:
            current += part
    if current:
        result.append(current)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--model", default="gemma4:e2b")
    parser.add_argument("--authors-note", type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    parts = chunks(args.log.read_text(errors="replace"))
    author_note = ""
    if args.authors_note and args.authors_note.exists():
        author_note = args.authors_note.read_text(errors="replace").strip()
    summaries = []
    for index, part in enumerate(parts, 1):
        prompt = """You are processing one batch of a provenance-tracked physics deep-learning corpus.
Use ONLY the supplied batch. Do not use outside knowledge. Do not identify people or institutions.
Produce concise Markdown with:
1. project families and physical domains;
2. completed experiments and exact numeric findings, each retaining SOURCE_PATH and SHA-256;
3. proposed/uncompleted methods;
4. failures, contradictions, and uncertainty;
5. datasets, metrics, architectures, and optimizers explicitly named.
Never convert an UNVERIFIED extract into a verified fact. Label every numerical claim UNVERIFIED.

<authors_note>
""" + (author_note or "[none]") + """
</authors_note>

<evidence_batch>
""" + part + "\n</evidence_batch>"
        summary = generate(args.model, prompt)
        (args.out / f"batch_{index:03d}.md").write_text(summary, encoding="utf-8")
        summaries.append(summary)
        print(f"completed batch {index}/{len(parts)}", flush=True)

    final_prompt = """You are synthesizing locally generated evidence summaries for a broad physics
deep-learning technical report. Use ONLY the supplied summaries. Preserve project boundaries among
PALIS/acoustics, meteorology/electromagnetics, neural operators, MINC/material systems, and structural
health monitoring. Do not pool incompatible metrics. Separate completed evidence, implementation
artifacts, proposed work, external literature, and unresolved claims. Every number must remain labeled
UNVERIFIED with an exact source path/hash. Produce Markdown sections: Program Scope; Shared Problem
Formulation; Project-by-Project Evidence; Cross-Project Failure Modes; Intervention Evidence Matrix;
Limitations; Recommended Matched Benchmark; Claim Ledger.

<authors_note>
""" + (author_note or "[none]") + """
</authors_note>

<batch_summaries>
""" + "\n\n--- BATCH ---\n\n".join(summaries) + "\n</batch_summaries>"
    synthesis = generate(args.model, final_prompt)
    (args.out / "gemma_synthesis.md").write_text(synthesis, encoding="utf-8")
    print(f"wrote {args.out / 'gemma_synthesis.md'}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
