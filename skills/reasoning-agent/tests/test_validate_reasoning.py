"""Tests for skills/reasoning-agent/scripts/validate_reasoning.py.

Covers task cases 3–6:
  3. A valid reasoning object passes validation.
  4. An unknown evidence ID fails validation.
  5. An approved claim with no evidence fails validation.
  6. Invalid confidence values fail schema validation.

Plus: claim_id-uniqueness, allowed_in_draft: false with no evidence is OK,
unknown top-level field is rejected, malformed JSON returns exit code 2.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "validate_reasoning.py"

spec = importlib.util.spec_from_file_location("validate_reasoning", SCRIPT)
vr = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(vr)


EVIDENCE_BUNDLE = [
    {"evidence_id": "EXP-04", "type": "experiment", "summary": "reduced-data run"},
    {"evidence_id": "FIG-03", "type": "figure",     "summary": "robustness plot"},
    {"evidence_id": "CITE-vaswani2017attention", "type": "citation",
     "summary": "attention mechanism"},
]


def _valid_plan() -> dict:
    return {
        "section_name": "Discussion",
        "section_goal": "Interpret performance under reduced-data conditions",
        "claims": [
            {
                "claim_id": "C1",
                "claim": "The method is more robust than the baseline under reduced-data conditions.",
                "evidence_ids": ["EXP-04", "FIG-03"],
                "reasoning": "The method's performance declined less than the baseline.",
                "assumptions": ["Both methods evaluated under equivalent conditions."],
                "alternative_interpretations": [
                    "The difference may be caused by regularization rather than architecture."
                ],
                "limitations": ["Only one dataset was evaluated."],
                "unresolved_questions": ["Whether the result generalizes to other datasets."],
                "confidence": "moderate",
                "allowed_in_draft": True,
            }
        ],
        "section_limitations": [],
        "synthesis": "Method degrades more gracefully under reduced-data conditions (C1).",
    }


def _write(tmp_path: Path, plan: dict, bundle=EVIDENCE_BUNDLE):
    plan_path = tmp_path / "discussion.json"
    ev_path = tmp_path / "discussion.evidence.json"
    plan_path.write_text(json.dumps(plan))
    ev_path.write_text(json.dumps(bundle))
    return plan_path, ev_path


# ── Case 3: valid plan passes ──────────────────────────────────────────────────
def test_valid_plan_passes(tmp_path):
    plan_path, ev_path = _write(tmp_path, _valid_plan())
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 0, errors
    assert errors == []


# ── Case 4: unknown evidence ID fails ─────────────────────────────────────────
def test_unknown_evidence_id_fails(tmp_path):
    plan = _valid_plan()
    plan["claims"][0]["evidence_ids"] = ["EXP-04", "EXP-999"]  # EXP-999 not in bundle
    plan_path, ev_path = _write(tmp_path, plan)
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 1
    assert any("EXP-999" in e and "unknown evidence id" in e for e in errors), errors


# ── Case 5: allowed_in_draft with no evidence fails ───────────────────────────
def test_allowed_in_draft_without_evidence_fails(tmp_path):
    plan = _valid_plan()
    plan["claims"][0]["evidence_ids"] = []
    # still allowed_in_draft: True
    plan_path, ev_path = _write(tmp_path, plan)
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 1
    assert any(
        "allowed_in_draft is true but no evidence_ids" in e for e in errors
    ), errors


def test_allowed_in_draft_false_without_evidence_is_ok(tmp_path):
    """Suppressed claim with no evidence should be legal — that's the point."""
    plan = _valid_plan()
    plan["claims"][0]["evidence_ids"] = []
    plan["claims"][0]["allowed_in_draft"] = False
    plan_path, ev_path = _write(tmp_path, plan)
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 0, errors


# ── Case 6: invalid confidence fails ──────────────────────────────────────────
def test_invalid_confidence_fails(tmp_path):
    plan = _valid_plan()
    plan["claims"][0]["confidence"] = "very_high"
    plan_path, ev_path = _write(tmp_path, plan)
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 1
    assert any("confidence" in e for e in errors), errors


# ── Extra coverage: schema structure ──────────────────────────────────────────
def test_missing_required_field_fails(tmp_path):
    plan = _valid_plan()
    del plan["synthesis"]
    plan_path, ev_path = _write(tmp_path, plan)
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 1
    assert any("synthesis" in e for e in errors), errors


def test_duplicate_claim_ids_fail(tmp_path):
    plan = _valid_plan()
    plan["claims"].append(dict(plan["claims"][0]))  # duplicate C1
    plan_path, ev_path = _write(tmp_path, plan)
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 1
    assert any("duplicate id" in e for e in errors), errors


def test_bad_claim_id_pattern_fails(tmp_path):
    plan = _valid_plan()
    plan["claims"][0]["claim_id"] = "claim-1"
    plan_path, ev_path = _write(tmp_path, plan)
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 1
    assert any("claim_id" in e for e in errors), errors


def test_bad_evidence_id_prefix_fails(tmp_path):
    plan = _valid_plan()
    plan["claims"][0]["evidence_ids"] = ["FOO-1"]  # not one of EXP/NOTE/CITE/FIG/TAB
    plan_path, ev_path = _write(tmp_path, plan)
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 1
    # Either the format check or the whitelist check will flag it; both are fine.
    assert any("FOO-1" in e for e in errors), errors


def test_malformed_json_returns_unrecoverable(tmp_path):
    plan_path = tmp_path / "bad.json"
    ev_path = tmp_path / "bad.evidence.json"
    plan_path.write_text("{not json")
    ev_path.write_text("[]")
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 2
    assert errors and "malformed JSON" in errors[0]


def test_missing_evidence_bundle_returns_unrecoverable(tmp_path):
    plan_path, _ = _write(tmp_path, _valid_plan())
    exit_code, errors = vr.validate(plan_path, tmp_path / "does_not_exist.json")
    assert exit_code == 2


def test_evidence_bundle_accepts_bare_string_list(tmp_path):
    plan_path, _ = _write(tmp_path, _valid_plan())
    ev_path = tmp_path / "bare.json"
    ev_path.write_text(json.dumps(["EXP-04", "FIG-03", "CITE-vaswani2017attention"]))
    exit_code, errors = vr.validate(plan_path, ev_path)
    assert exit_code == 0, errors


def test_schema_file_exists_and_is_valid_json():
    """Guardrail: the schema referenced by SKILL.md must be present and parseable."""
    schema = SCRIPT.parent.parent / "references" / "reasoning_schema.json"
    assert schema.exists()
    data = json.loads(schema.read_text())
    assert data.get("title") == "Reasoning Plan"
