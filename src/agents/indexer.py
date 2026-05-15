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

import tiktoken

_ENC = tiktoken.get_encoding("cl100k_base")
def _tok(s: str) -> int:
    return len(_ENC.encode(s))

def chunk_notebook(text: str, max_tokens: int = 2000) -> list[dict]:
    """Split markdown by headers, then by paragraph if oversize."""
    lines = text.splitlines()
    chunks, cur, header_path = [], [], []
    def flush():
        if cur:
            chunks.append({"header_path": list(header_path),
                           "text": "\n".join(cur).strip()})
    for ln in lines:
        if ln.startswith("#"):
            flush()
            cur = []
            level = len(ln) - len(ln.lstrip("#"))
            header_path = header_path[:level-1] + [ln.strip()]
            cur.append(ln)
        else:
            cur.append(ln)
    flush()

    refined = []
    for c in chunks:
        if _tok(c["text"]) <= max_tokens:
            refined.append(c)
        else:
            paras = c["text"].split("\n\n")
            buf = []
            for p in paras:
                buf.append(p)
                if _tok("\n\n".join(buf)) > max_tokens and len(buf) > 1:
                    refined.append({"header_path": c["header_path"],
                                    "text": "\n\n".join(buf[:-1])})
                    buf = [p]
            if buf:
                refined.append({"header_path": c["header_path"],
                                "text": "\n\n".join(buf)})

    for i, c in enumerate(refined):
        c["id"] = f"chunk_{i:04d}"
        c["token_count"] = _tok(c["text"])
    return refined

import tiktoken

_ENC = tiktoken.get_encoding("cl100k_base")
def _tok(s: str) -> int:
    return len(_ENC.encode(s))

def chunk_notebook(text: str, max_tokens: int = 2000) -> list[dict]:
    """Split markdown by headers, then by paragraph if oversize."""
    lines = text.splitlines()
    chunks, cur, header_path = [], [], []
    def flush():
        if cur:
            chunks.append({"header_path": list(header_path),
                           "text": "\n".join(cur).strip()})
    for ln in lines:
        if ln.startswith("#"):
            flush()
            cur = []
            level = len(ln) - len(ln.lstrip("#"))
            header_path = header_path[:level-1] + [ln.strip()]
            cur.append(ln)
        else:
            cur.append(ln)
    flush()

    refined = []
    for c in chunks:
        if _tok(c["text"]) <= max_tokens:
            refined.append(c)
        else:
            paras = c["text"].split("\n\n")
            buf = []
            for p in paras:
                buf.append(p)
                if _tok("\n\n".join(buf)) > max_tokens and len(buf) > 1:
                    refined.append({"header_path": c["header_path"],
                                    "text": "\n\n".join(buf[:-1])})
                    buf = [p]
            if buf:
                refined.append({"header_path": c["header_path"],
                                "text": "\n\n".join(buf)})

    for i, c in enumerate(refined):
        c["id"] = f"chunk_{i:04d}"
        c["token_count"] = _tok(c["text"])
    return refined

import tiktoken

_ENC = tiktoken.get_encoding("cl100k_base")
def _tok(s: str) -> int:
    return len(_ENC.encode(s))

def chunk_notebook(text: str, max_tokens: int = 2000) -> list[dict]:
    """Split markdown by headers, then by paragraph if oversize."""
    lines = text.splitlines()
    chunks, cur, header_path = [], [], []
    def flush():
        if cur:
            chunks.append({"header_path": list(header_path),
                           "text": "\n".join(cur).strip()})
    for ln in lines:
        if ln.startswith("#"):
            flush()
            cur = []
            level = len(ln) - len(ln.lstrip("#"))
            header_path = header_path[:level-1] + [ln.strip()]
            cur.append(ln)
        else:
            cur.append(ln)
    flush()

    refined = []
    for c in chunks:
        if _tok(c["text"]) <= max_tokens:
            refined.append(c)
        else:
            paras = c["text"].split("\n\n")
            buf = []
            for p in paras:
                buf.append(p)
                if _tok("\n\n".join(buf)) > max_tokens and len(buf) > 1:
                    refined.append({"header_path": c["header_path"],
                                    "text": "\n\n".join(buf[:-1])})
                    buf = [p]
            if buf:
                refined.append({"header_path": c["header_path"],
                                "text": "\n\n".join(buf)})

    for i, c in enumerate(refined):
        c["id"] = f"chunk_{i:04d}"
        c["token_count"] = _tok(c["text"])
    return refined

import json
from tqdm import tqdm
from src.tools.llm_client import call_llm

_SUMMARY_PATH = Path(__file__).parent.parent / "prompts" / "03a_chunk_summary.txt"

def build_index(notebook_text: str,
                out_path="work/01_index/notebook_index.json") -> list[dict]:
    chunks = chunk_notebook(notebook_text)
    template = _SUMMARY_PATH.read_text() if _SUMMARY_PATH.exists() else ""
    for c in tqdm(chunks, desc="indexing"):
        user = template.format(
            header_path=" > ".join(c["header_path"]),
            chunk_text=c["text"][:6000])
        kws = call_llm("indexer",
                       "Be brief. One line of comma-separated keywords.",
                       user, temperature=0.0, max_tokens=80)
        c["keywords"] = [k.strip().lower()
                         for k in kws.split(",") if k.strip()]
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Path(out_path).write_text(json.dumps(chunks, indent=2))
    return chunks
