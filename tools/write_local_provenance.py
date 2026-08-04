#!/usr/bin/env python3
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ws = root / "workspace_physics_zip_an"


def item(path: Path):
    return {
        "path": str(path.relative_to(root)) if path.is_relative_to(root) else str(path),
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


figures = {
    path.name: item(path)
    for path in sorted((ws / "figures").glob("fig_*.png"))
}
record = {
    "created_at": datetime.now(timezone.utc).isoformat(),
    "execution": {
        "mode": "local_only",
        "llm_provider": "ollama",
        "model": "gemma4:e2b",
        "external_api_calls_for_final_pipeline": False,
    },
    "source_archive": item(Path("/home/neha/Physics_DL_Improv.zip")),
    "corpus": {
        "manifest": item(ws / "corpus/manifest.json"),
        "summary": item(ws / "corpus/summary.json"),
        "coverage_report": item(ws / "corpus/coverage_report.json"),
        "files_hashed": 877,
        "unique_hashes": 710,
        "text_files": 555,
        "metadata_only_files": 200,
    },
    "inputs": {
        name: item(ws / "inputs" / name)
        for name in ("idea.md", "experimental_log.md", "template.tex",
                     "conference_guidelines.md", "authors_note.md")
    },
    "gemma": {
        "batch_summaries": len(list((ws / "gemma").glob("batch_*.md"))),
        "synthesis": item(ws / "gemma/gemma_synthesis.md"),
    },
    "outline": item(ws / "outline.json"),
    "figures": figures,
    "bibliography": {
        "refs": item(ws / "final/refs.bib"),
        "source": "embedded in Physics_DL_Improv.zip",
        "verification": "offline archive metadata only",
    },
    "final": {
        "paper_tex": item(ws / "final/paper.tex"),
        "paper_pdf": item(ws / "final/paper.pdf"),
    },
    "known_warnings": [
        "Four Office lock files were invalid 162-byte placeholders.",
        "Archive numeric extracts remain labeled UNVERIFIED.",
        "True image inspection was blocked by the host filesystem helper; deterministic PNG checks passed.",
        "Bibliography was not externally cross-verified at user request.",
    ],
}
(ws / "provenance.json").write_text(json.dumps(record, indent=2) + "\n")
print(ws / "provenance.json")
