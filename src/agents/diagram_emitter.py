"""Diagram Emitter: TikZ or Mermaid code per spec."""
from __future__ import annotations
from pathlib import Path
from src.tools.llm_client import call_llm

PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "04_diagram.txt"

def emit(spec: dict, notebook_excerpts: str = "") -> str:
    template = PROMPT_PATH.read_text()
    user = template.format(
        diagram_id=spec["diagram_id"],
        title=spec["title"],
        kind=spec["kind"],
        intent=spec["intent"],
        notebook_excerpts=notebook_excerpts[:6000] or "(none)",
    )
    return call_llm("diagram",
                    "You output a single LaTeX figure block.",
                    user, anti_leakage=False, temperature=0.2,
                    max_tokens=2500)

def emit_all(diagram_plan: list[dict],
             excerpts_by_section: dict | None = None,
             out_dir="work/04_diagrams") -> dict:
    out = {}
    outp = Path(out_dir)
    outp.mkdir(parents=True, exist_ok=True)
    excerpts_by_section = excerpts_by_section or {}
    for spec in diagram_plan:
        ex = excerpts_by_section.get(spec.get("section_anchor", ""), "")
        code = emit(spec, ex)
        (outp / f"{spec['diagram_id']}.tex").write_text(code)
        out[spec["diagram_id"]] = code
    return out
