from src.agents.indexer import load_inputs
from pathlib import Path

FIX = Path(__file__).parent / "fixtures" / "inputs"

def test_load_inputs_basic():
    data = load_inputs(FIX)
    assert "Day 1 results" in data["notebook"]
    assert "documentclass" in data["template"]
    assert data["papers"] == []
    assert data["proposal"] == ""
