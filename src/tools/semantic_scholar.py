"""Thin Semantic Scholar API wrapper with retry logic for rate limits.

Supports optional API key via S2_API_KEY environment variable.
Get a free key at: https://www.semanticscholar.org/product/api#api-key
"""
from __future__ import annotations
import os
import sys
import time
import requests

BASE = "https://api.semanticscholar.org/graph/v1"
_LAST = [0.0]
FIELDS = "title,authors,year,abstract,externalIds,venue,citationCount"

# API key (optional but recommended to avoid rate limits)
API_KEY = os.environ.get("S2_API_KEY", "")

# Retry configuration
MAX_RETRIES = 3
BACKOFF_BASE = 2  # seconds: 2, 4, 8

def _throttle(rate=1.0):
    gap = 1.0 / rate
    wait = gap - (time.time() - _LAST[0])
    if wait > 0:
        time.sleep(wait)
    _LAST[0] = time.time()

def _request_with_retry(method: str, url: str, **kwargs) -> requests.Response:
    """Make HTTP request with exponential backoff retry on 429 errors.
    
    If S2_API_KEY environment variable is set, includes it in the
    x-api-key header for higher rate limits.
    """
    # Add API key header if available
    headers = kwargs.pop("headers", {})
    if API_KEY:
        headers["x-api-key"] = API_KEY
    kwargs["headers"] = headers
    
    last_exception = None
    for attempt in range(MAX_RETRIES + 1):
        _throttle()
        try:
            r = requests.request(method, url, **kwargs)
            if r.status_code == 429:
                if attempt < MAX_RETRIES:
                    wait_time = BACKOFF_BASE * (2 ** attempt)
                    print(f"  [semantic_scholar] Rate limited (429), "
                          f"retrying in {wait_time}s... "
                          f"(attempt {attempt + 1}/{MAX_RETRIES})",
                          file=sys.stderr, flush=True)
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"  [semantic_scholar] Rate limited (429), "
                          f"max retries ({MAX_RETRIES}) exhausted.",
                          file=sys.stderr, flush=True)
                    if not API_KEY:
                        print(f"  [semantic_scholar] TIP: Set S2_API_KEY "
                              f"environment variable for higher rate limits.",
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
        timeout=30
    )
    return r.json().get("data", [])

def get_paper(paper_id: str) -> dict:
    r = _request_with_retry(
        "GET",
        f"{BASE}/paper/{paper_id}",
        params={"fields": FIELDS},
        timeout=30
    )
    return r.json()
