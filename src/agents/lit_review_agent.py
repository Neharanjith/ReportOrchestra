"""Lit Review Agent: discovery + verification + drafting."""
from __future__ import annotations
import json
from pathlib import Path
from src.tools import semantic_scholar as ss
from src.tools import dtic_search as dtic

def discover(strategy: dict,
             out_path="work/03_lit_review/candidates.json") -> list[dict]:
    pool, seen = [], set()
    queries = list(strategy.get("introduction", {}).get("macro_queries", []))
    for cl in strategy.get("background", {}).get("clusters", []):
        queries += cl.get("queries", [])
    for q in queries:
        for hit in ss.search(q, limit=8):
            sid = hit.get("paperId")
            if sid and sid not in seen:
                seen.add(sid)
                hit["source"] = "ss"
                pool.append(hit)
        for hit in dtic.search(q, limit=5):
            key = ("dtic", hit.get("accession", q))
            if key not in seen:
                seen.add(key)
                hit["source"] = "dtic"
                pool.append(hit)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Path(out_path).write_text(json.dumps(pool, indent=2))
    return pool

import re
import bibtexparser
from bibtexparser.bwriter import BibTexWriter

def _stable_key(entry: dict) -> str:
    authors = entry.get("authors") or []
    last = (authors[0]["name"].split()[-1] if authors
            else "Anon").replace(" ", "")
    year = str(entry.get("year") or "ND")
    title = entry.get("title", "")
    short = re.sub(r"[^A-Za-z]+", "", title.split()[0])[:8] if title else "X"
    return f"{last}{year}{short}"

def verify_and_emit_bib(
    candidates: list[dict],
    cutoff: str,
    bib_path="work/03_lit_review/verified.bib",
    map_path="work/03_lit_review/citation_map.json",
) -> list[dict]:
    cutoff_year = int(cutoff[:4])
    verified, seen_ids, db_entries = [], set(), []
    for c in candidates:
        if not c.get("abstract"):
            continue
        if (c.get("year") or 0) > cutoff_year:
            continue
        t = c.get("title") or ""
        if len(t) < 6:
            continue
        sid = c.get("paperId") or (c.get("externalIds") or {}).get("DOI") or t
        if sid in seen_ids:
            continue
        seen_ids.add(sid)
        key = _stable_key(c)
        db_entries.append({
            "ENTRYTYPE": "article",
            "ID": key,
            "title": t,
            "author": " and ".join(a["name"]
                                   for a in (c.get("authors") or [])),
            "year": str(c.get("year") or ""),
            "journal": c.get("venue") or "",
        })
        verified.append({"key": key, **c})

    db = bibtexparser.bibdatabase.BibDatabase()
    db.entries = db_entries
    Path(bib_path).parent.mkdir(parents=True, exist_ok=True)
    with open(bib_path, "w") as f:
        f.write(BibTexWriter().write(db))
    Path(map_path).write_text(json.dumps(
        {v["key"]: {"title": v["title"],
                    "abstract": v.get("abstract", ""),
                    "year": v.get("year", "")}
         for v in verified}, indent=2))
    return verified
