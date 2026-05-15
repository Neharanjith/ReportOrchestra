from unittest.mock import patch
from src.agents import lit_review_agent as lra

def test_discover_dedupes(tmp_path):
    fake_ss_data = [
        {"paperId": "p1", "title": "T1", "year": 2022, "abstract": "a"},
        {"paperId": "p2", "title": "T2", "year": 2023, "abstract": "b"},
        {"paperId": "p1", "title": "T1", "year": 2022, "abstract": "a"},
    ]
    strategy = {"introduction": {"macro_queries": ["q"]},
                "background": {"clusters": []}}
    with patch.object(lra.ss, "search", return_value=fake_ss_data):
        with patch.object(lra.dtic, "search", return_value=[]):
            out = lra.discover(strategy,
                               out_path=tmp_path / "c.json")
    assert len(out) == 2
    assert {p["paperId"] for p in out} == {"p1", "p2"}
