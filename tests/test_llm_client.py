import pytest, requests
from src.tools.llm_client import resolve_model, call_llm, load_config

def _ollama_up():
    try:
        url = load_config()["ollama"]["base_url"] + "/api/tags"
        return requests.get(url, timeout=2).status_code == 200
    except Exception:
        return False

def test_resolve_model():
    assert resolve_model("indexer").startswith("ollama:")
    assert resolve_model("outline").startswith("asksage:")

@pytest.mark.skipif(not _ollama_up(), reason="ollama not running")
def test_ollama_smoke():
    out = call_llm("indexer", "Be brief. Reply with one word.",
                   "Say only the word HI in capital letters.",
                   max_tokens=20)
    assert "HI" in out.upper()
