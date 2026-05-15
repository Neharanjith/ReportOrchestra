from unittest.mock import patch
from src.agents.diagram_emitter import emit_all

def test_emit_all_writes_files(tmp_path):
    plan = [
        {"diagram_id": "fig_arch", "title": "Arch", "kind": "tikz",
         "intent": "show flow", "section_anchor": "2.1"},
        {"diagram_id": "fig_pipe", "title": "Pipe", "kind": "mermaid",
         "intent": "pipeline", "section_anchor": "2.2"},
    ]
    with patch("src.agents.diagram_emitter.call_llm",
               return_value="\\begin{figure}\\end{figure}"):
        out = emit_all(plan, {"2.1": "ex"}, out_dir=tmp_path)
    assert set(out.keys()) == {"fig_arch", "fig_pipe"}
    assert (tmp_path / "fig_arch.tex").exists()
