import json
from pathlib import Path
from src.agents.indexer import retrieve

def test_retrieve_ranks_by_overlap(tmp_path):
    idx = tmp_path / "idx.json"
    chunks = [
        {"id": "c0", "header_path": ["# Metrics"],
         "keywords": ["accuracy", "f1"], "text": "scores accuracy f1"},
        {"id": "c1", "header_path": ["# Misc"],
         "keywords": ["budget"], "text": "unrelated"},
        {"id": "c2", "header_path": ["# Data"],
         "keywords": ["accuracy"], "text": "data prep"},
    ]
    idx.write_text(json.dumps(chunks))
    out = retrieve(["accuracy", "metric"], index_path=idx, k=5)
    assert out[0]["id"] == "c0"
    assert "c1" not in [c["id"] for c in out]
