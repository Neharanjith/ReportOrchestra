from unittest.mock import patch
from pathlib import Path
from src.agents.indexer import build_index

def test_build_index_writes_keywords(tmp_path):
    md = "# A\nalpha\n\n# B\nbeta"
    out = tmp_path / "idx.json"
    with patch("src.agents.indexer.call_llm",
               return_value="alpha, beta, gamma"):
        chunks = build_index(md, out_path=out)
    assert all("keywords" in c for c in chunks)
    assert chunks[0]["keywords"] == ["alpha", "beta", "gamma"]
    assert out.exists()
