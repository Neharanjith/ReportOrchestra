#!/usr/bin/env python3
"""Write a complete LaTeX report with a local Ollama model."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from local_gemma_synthesize import generate


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--model", default="gemma4:e2b")
    args = parser.parse_args()
    ws = args.workspace.resolve()
    refs = (ws / "refs.bib").read_text(errors="replace")
    authors_note_path = ws / "inputs/authors_note.md"
    authors_note = ""
    if authors_note_path.exists():
        authors_note = authors_note_path.read_text(errors="replace").strip()
    prompt = """## Strict Knowledge Isolation & Anonymity
Write exclusively from the supplied materials. Do not use outside knowledge,
invent results, identify authors or institutions, or add affiliations/emails.

You are writing a broad NRL-style technical report. Return ONLY complete compilable
LaTeX, without Markdown fences. Preserve the supplied template preamble and NRL
document commands. Fill the report with a careful cross-project synthesis, not a
universal benchmark. Keep every numerical claim labeled as unverified archive
evidence and cite its source path/hash in a footnote or evidence table. Never pool
incompatible metrics. Explicitly separate completed experiments, implementations,
plans, external literature, and unresolved claims. Include all four supplied figures
with their exact IDs and captions. Cite only BibTeX keys present in refs.bib.

<idea>
""" + (ws / "inputs/idea.md").read_text() + """
</idea>
<outline>
""" + (ws / "outline.json").read_text() + """
</outline>
<authors_note>
""" + (authors_note or "[none]") + """
</authors_note>
<gemma_evidence_synthesis>
""" + (ws / "gemma/gemma_synthesis.md").read_text() + """
</gemma_evidence_synthesis>
<captions>
""" + (ws / "figures/captions.json").read_text() + """
</captions>
<available_bibliography>
""" + refs + """
</available_bibliography>
<template>
""" + (ws / "inputs/template.tex").read_text(errors="replace") + """
</template>
"""
    paper = generate(args.model, prompt)
    if "```latex" in paper:
        paper = paper.split("```latex", 1)[1].split("```", 1)[0]
    elif "```" in paper:
        paper = paper.split("```", 1)[1].split("```", 1)[0]
    drafts = ws / "drafts"
    drafts.mkdir(exist_ok=True)
    (drafts / "paper.tex").write_text(paper.strip() + "\n", encoding="utf-8")
    print(drafts / "paper.tex")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
