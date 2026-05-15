"""Outline Agent: produces a JSON plan from inputs."""
from __future__ import annotations
import json
from pathlib import Path
from src.tools.llm_client import call_llm
from src.agents.indexer import load_inputs

PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "02_outline.txt"
REQUIRED_SECTION_IDS = {"1.1","1.2","2.1","2.2","2.3","3","4.1","4.2","4.3"}

def generate_outline(inputs_dir="inputs",
                     out_path="work/02_outline/outline.json") -> dict:
    data = load_inputs(inputs_dir)
    system = PROMPT_PATH.read_text()
    user_parts = [
        f"=== PROPOSAL ===\n{data['proposal'][:30000]}",
        f"=== LAST PROGRESS REPORT ===\n{data['last_progress_report'][:30000]}",
        f"=== LAB NOTEBOOK ===\n{data['notebook'][:200000]}",
        f"=== NOTES ===\n{data['notes'][:20000]}",
        f"=== TEMPLATE ===\n{data['template']}",
    ]
    user = "\n\n".join(user_parts)
    text = call_llm("outline", system, user,
                    temperature=0.1, max_tokens=8000)
    outline = _parse_with_retry(text, system, user)
    _validate(outline)
    outp = Path(out_path)
    outp.parent.mkdir(parents=True, exist_ok=True)
    outp.write_text(json.dumps(outline, indent=2))
    return outline

def _parse_with_retry(text, system, user):
    try:
        return json.loads(_strip_fences(text))
    except json.JSONDecodeError as e:
        retry_user = (user
            + f"\n\n=== PREVIOUS ATTEMPT FAILED PARSING: {e} ===\n"
            + "Re-emit ONLY the corrected JSON object. No prose.")
        text2 = call_llm("outline", system, retry_user,
                         temperature=0.0, max_tokens=8000)
        return json.loads(_strip_fences(text2))

def _strip_fences(s: str) -> str:
    s = s.strip()
    if s.startswith("```"):
        s = s.split("\n", 1)[1] if "\n" in s else s[3:]
        if s.endswith("```"):
            s = s[:-3]
    return s.strip()

def _validate(outline: dict):
    ids = {sec["section_id"] for sec in outline.get("section_plan", [])}
    missing = REQUIRED_SECTION_IDS - ids
    if missing:
        raise ValueError(f"Outline missing required section_ids: {missing}")
    if not outline.get("diagram_plan"):
        raise ValueError("Outline has no diagram_plan entries")
