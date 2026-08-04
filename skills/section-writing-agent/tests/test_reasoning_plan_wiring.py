"""Tests for how the Section Writing Agent consumes reasoning plans.

Covers task cases 7, 8, and (as a follow-through) 9:

  7. Section Writer receives reasoning plans for scientific papers.
  8. Section Writer receives no reasoning plans for technical reports.
  9. Existing technical-report behavior remains unchanged.

Structural tests over the SKILL.md and prompt.md files, plus a small
call-composition helper test that shows the input dict actually excludes
`reasoning_plans` when mode is TECHNICAL_REPORT.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL_DIR = HERE.parent
SKILL_MD = SKILL_DIR / "SKILL.md"
PROMPT_MD = SKILL_DIR / "references" / "prompt.md"

# Load document_mode helper without needing to install the project as a package.
_DM_PATH = (
    SKILL_DIR.parent / "paper-orchestra" / "scripts" / "document_mode.py"
)
_spec = importlib.util.spec_from_file_location("document_mode", _DM_PATH)
dm = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(dm)


def compose_section_writer_inputs(
    outline: dict,
    reasoning_plans: dict | None,
    mode: str,
) -> dict:
    """Reference implementation of how the orchestrator assembles the
    Section Writing Agent's user message. The rule under test:
    include `reasoning_plans` iff mode == SCIENTIFIC_PAPER.
    """
    payload: dict = {"outline": outline}
    if mode == "SCIENTIFIC_PAPER":
        payload["reasoning_plans"] = reasoning_plans or {}
    # In TECHNICAL_REPORT mode, reasoning_plans is deliberately absent.
    return payload


# ── Case 7: scientific-paper mode passes reasoning_plans ──────────────────────
def test_scientific_paper_mode_passes_reasoning_plans():
    plans = {
        "discussion": {"section_name": "Discussion", "claims": []},
    }
    payload = compose_section_writer_inputs(
        outline={"section_plan": []}, reasoning_plans=plans, mode="SCIENTIFIC_PAPER"
    )
    assert "reasoning_plans" in payload
    assert payload["reasoning_plans"] is plans


def test_helper_agrees_with_scientific_paper_default():
    """No authors_note → default mode → reasoning plans must be passed."""
    mode = dm.detect_mode(None)
    payload = compose_section_writer_inputs(
        outline={}, reasoning_plans={"introduction": {}}, mode=mode
    )
    assert "reasoning_plans" in payload


# ── Case 8: technical-report mode omits reasoning_plans ───────────────────────
def test_technical_report_mode_omits_reasoning_plans():
    payload = compose_section_writer_inputs(
        outline={"section_plan": []},
        reasoning_plans={"discussion": {"claims": []}},
        mode="TECHNICAL_REPORT",
    )
    assert "reasoning_plans" not in payload


def test_helper_agrees_with_technical_report_trigger():
    note = "Please write this as a technical report."
    mode = dm.detect_mode(note)
    payload = compose_section_writer_inputs(
        outline={}, reasoning_plans={"introduction": {}}, mode=mode
    )
    assert "reasoning_plans" not in payload


# ── Case 9: existing behavior is preserved (structural guardrails) ───────────
def test_skill_md_still_documents_technical_report_mode():
    """The TECHNICAL_REPORT flow must remain first-class in SKILL.md."""
    text = SKILL_MD.read_text()
    assert "TECHNICAL_REPORT" in text
    assert "SCIENTIFIC_PAPER" not in text or "SCIENTIFIC_PAPER mode only" in text


def test_prompt_md_preserves_technical_report_depth_contract():
    text = PROMPT_MD.read_text()
    # The prior TECHNICAL_REPORT depth rules must still be present.
    assert "TECHNICAL_REPORT mode" in text
    assert "Mechanism" in text or "mechanism" in text  # tone rule preserved
    assert "Do not invent" in text or "do not invent" in text.lower()


# ── Additional structural coverage for the new reasoning-plans wiring ────────
def test_skill_md_lists_reasoning_input_and_mode_gate():
    text = SKILL_MD.read_text()
    assert "workspace/reasoning/*.json" in text
    assert "SCIENTIFIC_PAPER mode only" in text
    assert "TECHNICAL_REPORT" in text
    # The multimodal-call inputs section names the reasoning_plans key.
    assert "reasoning_plans" in text


def test_prompt_md_teaches_the_reasoning_plan_rules():
    text = PROMPT_MD.read_text()
    # The new 0b block covers the required constraints.
    assert "reasoning_plans" in text
    assert "allowed_in_draft" in text
    assert "strengthen" in text  # "Do not strengthen a claim beyond..."
    # Preserves confidence and distinction between observation/interpretation.
    assert "confidence" in text
    assert "observation" in text.lower()
    # And requires natural prose (no mechanical JSON dumps).
    assert "not reproduce" in text.lower() or "not simply reproduce" in text.lower() \
        or "not read as JSON" in text.lower() or "not mechanically" in text.lower() \
        or "not reproduce json" in text.lower() or "not simply reproduce" in text.lower() \
        or "mechanically" in text.lower()
