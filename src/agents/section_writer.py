"""Section Writer: drafts one section."""
from __future__ import annotations
from pathlib import Path
from src.tools.llm_client import call_llm

PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "05_section_writer.txt"

def write_section(section_spec: dict, notebook_excerpts: str,
                  verified_bib: list[dict], diagram_labels: list[str]) -> str:
    template = PROMPT_PATH.read_text()
    bib_lines = "\n".join(f"- {b['key']}: {b['title']}" for b in verified_bib)
    diag_lines = "\n".join(f"- fig:{d}" for d in diagram_labels)
    bullets = "\n".join(f"- {b}" for b in section_spec["content_bullets"])
    user = template.format(
        section_id=section_spec["section_id"],
        title=section_spec["title"],
        content_bullets=bullets,
        notebook_excerpts=notebook_excerpts or "(none retrieved)",
        bib_keys_and_titles=bib_lines or "(no citations available)",
        diagram_labels=diag_lines or "(no diagrams)",
    )
    system = "You write a single section of LaTeX for a technical report."
    return call_llm("section_writer", system, user,
                    anti_leakage=True, temperature=0.3, max_tokens=4000)
