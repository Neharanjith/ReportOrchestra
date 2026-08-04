#!/usr/bin/env python3
"""document_mode.py — Determine SCIENTIFIC_PAPER vs TECHNICAL_REPORT.

Single source of truth for the mode-gating rule the Outline, Reasoning,
Section Writing, and Content Refinement agents all follow.

Rule (matches the prompt language used by each of those agents):

  * Default to SCIENTIFIC_PAPER when authors_note.md is absent, empty, or
    does not explicitly request a technical / implementation-centered document.
  * Return TECHNICAL_REPORT only when the note explicitly requests one:
    the phrases "technical report", "technical paper", "implementation
    centered paper" / "implementation-centered paper", or an equivalent
    engineering-focused document.

The check is intentionally conservative: an ambiguous note falls back to
SCIENTIFIC_PAPER, matching the prompts' "when ambiguous, use
SCIENTIFIC_PAPER" instruction.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SCIENTIFIC_PAPER = "SCIENTIFIC_PAPER"
TECHNICAL_REPORT = "TECHNICAL_REPORT"

_TECH_TRIGGER_PATTERNS = [
    r"\btechnical\s+report\b",
    r"\btechnical\s+paper\b",
    r"\bimplementation[\s\-]centered\s+paper\b",
    r"\bimplementation[\s\-]focused\s+paper\b",
    r"\bengineering[\s\-]focused\s+(?:paper|report|document)\b",
]
_TECH_TRIGGER_RE = re.compile("|".join(_TECH_TRIGGER_PATTERNS), re.IGNORECASE)


def detect_mode(authors_note_text: str | None) -> str:
    """Return SCIENTIFIC_PAPER or TECHNICAL_REPORT for the given note contents.

    ``authors_note_text`` may be None (file absent) or an empty/whitespace
    string; both yield SCIENTIFIC_PAPER. Any other content is scanned for a
    technical-report trigger phrase.
    """
    if not authors_note_text or not authors_note_text.strip():
        return SCIENTIFIC_PAPER
    if _TECH_TRIGGER_RE.search(authors_note_text):
        return TECHNICAL_REPORT
    return SCIENTIFIC_PAPER


def detect_mode_from_workspace(workspace: Path) -> str:
    """Load authors_note.md from a workspace directory and detect the mode."""
    note = workspace / "inputs" / "authors_note.md"
    text = note.read_text() if note.exists() else None
    return detect_mode(text)


def reasoning_stage_runs(mode: str) -> bool:
    """The Reasoning Agent runs iff mode == SCIENTIFIC_PAPER."""
    return mode == SCIENTIFIC_PAPER


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    p.add_argument(
        "--workspace",
        required=True,
        help="workspace directory (reads inputs/authors_note.md)",
    )
    args = p.parse_args()
    mode = detect_mode_from_workspace(Path(args.workspace))
    print(mode)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
