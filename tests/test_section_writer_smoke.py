from unittest.mock import patch
from src.agents.section_writer import write_section

def test_format_substitutes_correctly():
    spec = {"section_id": "2.3",
            "title": "Metrics",
            "content_bullets": ["accuracy", "f1"]}
    bib = [{"key": "Smith2020", "title": "Foo"}]
    captured = {}
    def fake_call(role, system, user, **kw):
        captured["user"] = user
        return "\\subsection{Metrics}\nDone."
    with patch("src.agents.section_writer.call_llm", side_effect=fake_call):
        out = write_section(spec, "Some excerpt.", bib, ["fig_a"])
    assert "Metrics" in out
    assert "Smith2020" in captured["user"]
    assert "accuracy" in captured["user"]
    assert "fig:fig_a" in captured["user"]
