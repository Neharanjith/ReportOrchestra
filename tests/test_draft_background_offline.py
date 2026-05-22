from unittest.mock import patch
from src.agents.lit_review_agent import draft_background

def test_draft_background_writes_file(tmp_path):
    outline = {"section_plan": [{"section_id": "1.2",
                                  "title": "Background",
                                  "content_bullets": ["b1"]}]}
    cmap = {"Smith2020Foo": {"title": "Foo", "year": 2020}}
    out = tmp_path / "ib.tex"
    # Section 1.2 maps to \chapter{BACKGROUND AND RELATED WORK} in the NRL
    # template, so the LLM output starts at \section{} level — never \chapter{}
    with patch("src.agents.lit_review_agent.call_llm",
               return_value=r"\section{Prior Work}\cite{Smith2020Foo} ok"):
        draft_background(outline, cmap, "proposal text", out_path=out)
    text = out.read_text()
    assert "Prior Work" in text
    assert "Smith2020Foo" in text
    assert "\\chapter" not in text  # chapter heading must not appear in content
