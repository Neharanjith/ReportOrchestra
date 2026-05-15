from src.agents.lit_review_agent import verify_and_emit_bib, _stable_key

def test_stable_key_deterministic():
    e = {"authors": [{"name": "Jane Doe"}], "year": 2022, "title": "Foo Bar"}
    assert _stable_key(e) == _stable_key(e)
    assert "Doe2022" in _stable_key(e)

def test_verify_drops_invalids(tmp_path):
    cands = [
        {"paperId": "p1", "title": "Valid Paper One",
         "year": 2022, "abstract": "ok", "authors": [{"name": "Smith"}]},
        {"paperId": "p2", "title": "No Abstract",
         "year": 2022, "abstract": "", "authors": []},
        {"paperId": "p3", "title": "Future Paper",
         "year": 2099, "abstract": "ok", "authors": []},
        {"paperId": "p1", "title": "Duplicate", "year": 2022,
         "abstract": "x", "authors": []},
    ]
    bib = tmp_path / "v.bib"
    cmap = tmp_path / "v.json"
    out = verify_and_emit_bib(cands, "2026-04-01",
                              bib_path=bib, map_path=cmap)
    assert len(out) == 1
    assert out[0]["paperId"] == "p1"
    assert bib.exists() and cmap.exists()
