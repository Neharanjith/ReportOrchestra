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
