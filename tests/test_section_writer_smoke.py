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
        # Section writer must use \section or lower — never \chapter
        return "\\section{Metrics}\nAccuracy and F1 are reported."
    with patch("src.agents.section_writer.call_llm", side_effect=fake_call):
        out = write_section(spec, "Some excerpt.", bib, ["fig_a"])
    assert "Metrics" in out
    assert "Smith2020" in captured["user"]
    assert "accuracy" in captured["user"]
    assert "fig:fig_a" in captured["user"]
    # The prompt must forbid \chapter{} — verify the instruction is present
    assert "chapter" in captured["user"].lower()
    assert "Do NOT emit" in captured["user"] or "NOT emit" in captured["user"]
    # Section writer output must not contain \chapter{}
    assert "\\chapter" not in out
