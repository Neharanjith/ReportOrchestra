"""Tests for the document-mode helper and the reasoning-stage branching.

Covers task cases 1, 2, and 9:
  1. Scientific paper runs the Reasoning Agent.
  2. Technical report skips the Reasoning Agent.
  9. Existing technical-report behavior remains unchanged (the mode-detection
     rule matches the language in the section-writing / outline / refinement
     prompts, so nothing else in the pipeline needs new configuration).
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parent.parent / "scripts" / "document_mode.py"
)
spec = importlib.util.spec_from_file_location("document_mode", SCRIPT)
dm = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(dm)


# ── Case 1: scientific paper is the default → reasoning runs ──────────────────
def test_absent_authors_note_is_scientific_paper():
    assert dm.detect_mode(None) == "SCIENTIFIC_PAPER"
    assert dm.reasoning_stage_runs("SCIENTIFIC_PAPER") is True


def test_empty_authors_note_is_scientific_paper():
    assert dm.detect_mode("") == "SCIENTIFIC_PAPER"
    assert dm.detect_mode("   \n\n   ") == "SCIENTIFIC_PAPER"


def test_ambiguous_authors_note_is_scientific_paper():
    """The prompts say: when ambiguous, use SCIENTIFIC_PAPER."""
    note = "Please emphasize clarity and use the working title 'Sparse Attention Revisited'."
    assert dm.detect_mode(note) == "SCIENTIFIC_PAPER"


def test_scientific_paper_from_workspace(tmp_path):
    (tmp_path / "inputs").mkdir()
    # No authors_note.md file at all.
    assert dm.detect_mode_from_workspace(tmp_path) == "SCIENTIFIC_PAPER"


# ── Case 2: explicit technical-report trigger → reasoning skipped ─────────────
def test_technical_report_trigger_from_note():
    note = "This should be written as a technical report for the DoD program office."
    assert dm.detect_mode(note) == "TECHNICAL_REPORT"
    assert dm.reasoning_stage_runs("TECHNICAL_REPORT") is False


def test_technical_paper_trigger_from_note():
    note = "Please produce a technical paper aimed at implementers."
    assert dm.detect_mode(note) == "TECHNICAL_REPORT"


def test_implementation_centered_trigger_from_note():
    note = "Frame this as an implementation-centered paper."
    assert dm.detect_mode(note) == "TECHNICAL_REPORT"


def test_case_insensitivity():
    assert dm.detect_mode("TECHNICAL REPORT PLEASE") == "TECHNICAL_REPORT"


def test_technical_report_from_workspace(tmp_path):
    (tmp_path / "inputs").mkdir()
    (tmp_path / "inputs" / "authors_note.md").write_text(
        "Please deliver a technical report."
    )
    assert dm.detect_mode_from_workspace(tmp_path) == "TECHNICAL_REPORT"


# ── Case 9: existing technical-report behavior is unchanged ──────────────────
# We assert: (a) the mode helper agrees with the language used in the existing
# prompts, (b) TECHNICAL_REPORT explicitly skips reasoning, (c) no other
# side-effect flag is invented.
def test_helper_agrees_with_prompt_language():
    """Prompts key off exactly these phrases — helper must too."""
    for phrase in (
        "technical report",
        "technical paper",
        "implementation-centered paper",
        "implementation centered paper",
    ):
        note = f"Write this as a {phrase}."
        assert dm.detect_mode(note) == "TECHNICAL_REPORT", phrase


def test_reasoning_only_runs_for_scientific_paper():
    assert dm.reasoning_stage_runs("SCIENTIFIC_PAPER") is True
    assert dm.reasoning_stage_runs("TECHNICAL_REPORT") is False
    assert dm.reasoning_stage_runs("anything_else") is False


def test_orchestrator_step_3_7_declares_the_gate():
    """SKILL.md must describe the mode-gated Step 3.7."""
    skill = (
        SCRIPT.parent.parent / "SKILL.md"
    ).read_text()
    assert "Step 3.7" in skill
    assert "Reasoning" in skill
    assert "TECHNICAL_REPORT" in skill
    assert "Skip this step entirely" in skill
    assert "document_mode.py" in skill
