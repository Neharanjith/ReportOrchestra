import json, pytest
from pathlib import Path
from src.agents.outline_agent import _validate

FIX = Path(__file__).parent / "fixtures"

def test_valid_outline():
    _validate(json.loads((FIX / "outline_ok.json").read_text()))

def test_invalid_outline_raises():
    with pytest.raises(ValueError):
        _validate(json.loads((FIX / "outline_bad.json").read_text()))
