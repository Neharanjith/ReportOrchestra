"""Thin Semantic Scholar API wrapper with retry logic for rate limits."""
from __future__ import annotations
import os
import sys
import time
import requests

BASE = "https://api.semanticscholar.org/graph/v1"
_LAST = [0.0]
FIELDS = "title,authors,year,abstract,externalIds,venue,citationCount"

# Retry configuration
MAX_RETRIES = 3
BACKOFF_BASE = 2  # seconds: 2, 4, 8


def _auth_headers() -> dict:
    """Return the x-api-key header if S2_API_KEY is set in the environment.

    Without a key the public tier allows ~100 requests/5 min.
    With a key the authenticated tier allows ~10,000 requests/5 min.
    Obtain a free key at: https://www.semanticscholar.org/product/api
    """
    key = os.environ.get("S2_API_KEY", "")
    return {"x-api-key": key} if key else {}


def _throttle(rate=1.0):
    gap = 1.0 / rate
    wait = gap - (time.time() - _LAST[0])
    if wait > 0:
        time.sleep(wait)
    _LAST[0] = time.time()

def _request_with_retry(method: str, url: str, **kwargs) -> requests.Response:
    """Make HTTP request with exponential backoff retry on 429 errors."""
    last_exception = None
    for attempt in range(MAX_RETRIES + 1):
        _throttle()
        try:
            r = requests.request(method, url, **kwargs)
            if r.status_code in (429, 502, 503, 504):
                if attempt < MAX_RETRIES:
                    wait_time = BACKOFF_BASE * (2 ** attempt)
                    print(f"  [semantic_scholar] Server returned {r.status_code}, "
                          f"retrying in {wait_time}s... "
                          f"(attempt {attempt + 1}/{MAX_RETRIES})",
                          file=sys.stderr, flush=True)
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"  [semantic_scholar] Server returned {r.status_code}, "
                          f"max retries ({MAX_RETRIES}) exhausted.",
                          file=sys.stderr, flush=True)
            r.raise_for_status()
            return r
        except requests.exceptions.HTTPError as e:
            if e.response is not None and e.response.status_code == 429:
                last_exception = e
                continue
            raise
        except requests.exceptions.RequestException as e:
            last_exception = e
            if attempt < MAX_RETRIES:
                wait_time = BACKOFF_BASE * (2 ** attempt)
                print(f"  [semantic_scholar] Request failed ({e}), "
                      f"retrying in {wait_time}s... "
                      f"(attempt {attempt + 1}/{MAX_RETRIES})",
                      file=sys.stderr, flush=True)
                time.sleep(wait_time)
            else:
                raise
    # If we exhausted retries due to 429, raise the last exception
    if last_exception:
        raise last_exception
    raise RuntimeError("Unexpected retry loop exit")

def search(query: str, limit: int = 10) -> list[dict]:
    r = _request_with_retry(
        "GET",
        f"{BASE}/paper/search",
        params={"query": query, "limit": limit, "fields": FIELDS},
        headers=_auth_headers(),
        timeout=30,
    )
    return r.json().get("data", [])

def get_paper(paper_id: str) -> dict:
    r = _request_with_retry(
        "GET",
        f"{BASE}/paper/{paper_id}",
        params={"fields": FIELDS},
        headers=_auth_headers(),
        timeout=30,
    )
    return r.json()
