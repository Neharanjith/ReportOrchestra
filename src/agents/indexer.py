"""Input loading and (later) notebook indexing."""
from __future__ import annotations
from pathlib import Path
from src.tools.pdf_extract import extract_text

def load_inputs(inputs_dir) -> dict:
    d = Path(inputs_dir)
    def _read(p):
        return p.read_text() if p.exists() else ""
    def _pdf(p):
        return extract_text(p) if p.exists() else ""

    papers = []
    papers_dir = d / "papers"
    if papers_dir.exists():
        for p in sorted(papers_dir.glob("*.pdf")):
            papers.append({"filename": p.name, "text": extract_text(p)})

    notes = ""
    notes_dir = d / "notes"
    if notes_dir.exists():
        for p in sorted(notes_dir.glob("*.md")):
            notes += f"\n\n# {p.name}\n\n" + p.read_text()

    examples = []
    ex_dir = d / "examples"
    if ex_dir.exists():
        for p in sorted(ex_dir.glob("*")):
            if p.suffix in {".tex", ".md", ".txt"}:
                examples.append(p.read_text())
            elif p.suffix == ".pdf":
                examples.append(extract_text(p))

    return {
        "notebook":             _read(d / "notebook.md"),
        "proposal":             _pdf(d / "proposal.pdf"),
        "last_progress_report": _pdf(d / "last_progress_report.pdf"),
        "papers":               papers,
        "notes":                notes,
        "template":             _read(d / "template.tex"),
        "examples":             examples,
    }
