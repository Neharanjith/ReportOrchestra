#!/usr/bin/env python3
"""Build conservative PaperOrchestra inputs from an ingested broad corpus."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

SIGNAL = re.compile(
    r"(?i)(generaliz|baseline|result|experiment|rmse|mae|mse|ssim|accuracy|"
    r"improv|frequency|helmholtz|neural operator|fno|palis|minc|mixup|sharpness)"
)
NUMBER = re.compile(r"(?<![A-Za-z])[-+]?\d+(?:\.\d+)?(?:e[-+]?\d+)?%?", re.I)
EMAIL = re.compile(r"\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b")


def top_level(path: str) -> str:
    return path.split("/", 1)[0] if "/" in path else "[root]"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--inputs", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((args.corpus / "manifest.json").read_text())
    args.inputs.mkdir(parents=True, exist_ok=True)

    groups = Counter(top_level(item["path"]) for item in manifest)
    methods = Counter(item["method"] for item in manifest)
    evidence = []
    covered = set()
    for item in manifest:
        text_path = item.get("text_path")
        if not text_path:
            continue
        text = (args.corpus / text_path).read_text(errors="replace")
        candidates = []
        for paragraph in re.split(r"\n\s*\n", text):
            compact = " ".join(paragraph.split())
            if 80 <= len(compact) <= 1800 and SIGNAL.search(compact) and NUMBER.search(compact):
                compact = EMAIL.sub("[EMAIL REDACTED]", compact)
                candidates.append(compact)
        if candidates:
            covered.add(item["path"])
            for snippet in candidates[:3]:
                evidence.append(
                    f"### Source: `{item['path']}`\n"
                    f"SHA-256: `{item['sha256']}`\n\n"
                    f"[UNVERIFIED EXTRACT—check source before publication]\n\n{snippet}\n"
                )

    scope = "\n".join(f"- `{name}`: {count} files" for name, count in groups.most_common())
    method_rows = "\n".join(f"- `{name}`: {count}" for name, count in methods.most_common())
    idea = """# Cross-Domain Generalization in Physics-Guided Deep Learning

## Problem
Physics emulators and inverse models can fit their training regimes yet fail under
frequency shifts, geometry changes, new material systems, or new sensing domains.
This broad research program examines that generalization problem across underwater
acoustics, electromagnetic propagation, structural health monitoring, and related
physics-domain datasets.

## Hypothesis
Reliable cross-domain performance requires jointly improving representations,
physics consistency, optimization, and adaptation, while evaluating every method
under explicit out-of-distribution splits rather than interpolation-only tests.

## Method
Synthesize the supplied PALIS, neural-operator, MINC, meteorology, and structural
health monitoring artifacts as a multi-project evidence map. Distinguish completed
experiments from plans and external literature, compare recurring failure modes,
and identify which interventions transfer across physical domains.

## Key Contributions
- A provenance-tracked synthesis spanning the complete supplied ZIP archive.
- A taxonomy of cross-domain failure modes and mitigation strategies.
- Cross-project comparison of physics encoding, neural operators, augmentation,
  sharpness-aware optimization, normalization, and few-shot adaptation.
- Explicit separation of measured findings, proposed work, and unresolved questions.

## Open Questions
- Which reported gains survive matched out-of-distribution evaluation?
- Which methods transfer across acoustic, electromagnetic, and structural domains?
- What shared benchmarks and uncertainty measures are needed for defensible claims?
"""
    log = f"""# Broad Physics-DL Corpus Evidence Log

## 1. Corpus and provenance

This input was generated from the complete extracted `Physics_DL_Improv.zip`.
All {len(manifest)} files were hashed and classified. Text was recovered from
{sum('text_path' in item for item in manifest)} files; binary-only artifacts remain
represented in `corpus/manifest.json`. Extracted claims below are deliberately marked
UNVERIFIED until checked against their exact source.

### Top-level scope
{scope}

### Ingestion methods
{method_rows}

## 2. Evidence-bearing source coverage

Numeric/experimental passages were found in {len(covered)} distinct text-bearing
sources. The full manifest is authoritative for corpus coverage.

## 3. Source-linked experimental extracts

{chr(10).join(evidence)}
"""
    (args.inputs / "idea.md").write_text(idea, encoding="utf-8")
    (args.inputs / "experimental_log.md").write_text(log, encoding="utf-8")
    report = {
        "manifest_files": len(manifest),
        "text_files": sum("text_path" in item for item in manifest),
        "evidence_sources": len(covered),
        "evidence_extracts": len(evidence),
        "top_level_counts": dict(groups),
        "method_counts": dict(methods),
        "unrepresented_text_sources": sorted(
            item["path"] for item in manifest
            if item.get("text_path") and item["path"] not in covered
        ),
    }
    (args.corpus / "coverage_report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps({k: v for k, v in report.items() if k != "unrepresented_text_sources"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
