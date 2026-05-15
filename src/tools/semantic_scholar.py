"""Thin Semantic Scholar API wrapper. Free tier, ~1 req/sec."""
from __future__ import annotations
import time, requests

BASE = "https://api.semanticscholar.org/graph/v1"
_LAST = [0.0]
FIELDS = "title,authors,year,abstract,externalIds,venue,citationCount"

def _throttle(rate=1.0):
    gap = 1.0 / rate
    wait = gap - (time.time() - _LAST[0])
    if wait > 0: time.sleep(wait)
    _LAST[0] = time.time()

def search(query: str, limit: int = 10) -> list[dict]:
    _throttle()
    r = requests.get(f"{BASE}/paper/search",
                     params={"query": query, "limit": limit,
                             "fields": FIELDS}, timeout=30)
    r.raise_for_status()
    return r.json().get("data", [])

def get_paper(paper_id: str) -> dict:
    _throttle()
    r = requests.get(f"{BASE}/paper/{paper_id}",
                     params={"fields": FIELDS}, timeout=30)
    r.raise_for_status()
    return r.json()
