#!/usr/bin/env python3
"""validate_reasoning.py — deterministic validator for Reasoning Agent output.

Enforces the reasoning-plan schema, plus:
  * every evidence_id referenced by any claim must exist in the supplied
    evidence_bundle (whitelist supplied by the orchestrator, not by the model);
  * every claim with allowed_in_draft: true has >=1 evidence_id;
  * claim_ids are unique;
  * confidence values are within the allowed enum;
  * all required top-level and per-claim fields are present.

The JSON Schema (references/reasoning_schema.json) is loaded and applied first
so structural errors surface with clear paths. jsonschema is optional; if it
is not installed the script falls back to a hand-rolled structural check that
matches the schema.

Exit codes:
    0  valid
    1  invalid — recoverable (orchestrator should re-prompt with report)
    2  invalid — unrecoverable (unreadable file, malformed JSON, missing
       evidence bundle)

Errors are written both to stderr (short human summary) and to
<plan_path>.errors.json (machine-readable), so the orchestrator can splice
the report into a retry prompt.

Usage:
    python validate_reasoning.py \\
        --plan workspace/reasoning/discussion.json \\
        --evidence-bundle workspace/reasoning/discussion.evidence.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

CONFIDENCE_VALUES = {"low", "moderate", "high"}
CLAIM_ID_RE = re.compile(r"^C[0-9]+$")
EVIDENCE_ID_RE = re.compile(r"^(EXP|NOTE|CITE|FIG|TAB)-[A-Za-z0-9_\-]+$")

REQUIRED_TOP = [
    "section_name",
    "section_goal",
    "claims",
    "section_limitations",
    "synthesis",
]
REQUIRED_CLAIM = [
    "claim_id",
    "claim",
    "evidence_ids",
    "reasoning",
    "assumptions",
    "alternative_interpretations",
    "limitations",
    "unresolved_questions",
    "confidence",
    "allowed_in_draft",
]


def _schema_path() -> Path:
    return Path(__file__).resolve().parent.parent / "references" / "reasoning_schema.json"


def _load_json(path: Path) -> object:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        raise FileNotFoundError(f"file not found: {path}")
    except json.JSONDecodeError as e:
        raise ValueError(f"malformed JSON in {path}: {e}")


def _load_evidence_ids(path: Path) -> set[str]:
    """Read the whitelist of evidence IDs the orchestrator handed the agent.

    Accepts either a bare array of IDs or an array of objects with an
    evidence_id field; the orchestrator's on-disk form uses the latter.
    """
    raw = _load_json(path)
    if not isinstance(raw, list):
        raise ValueError(
            f"evidence bundle must be a JSON array (got {type(raw).__name__}): {path}"
        )
    ids: set[str] = set()
    for i, item in enumerate(raw):
        if isinstance(item, str):
            ids.add(item)
        elif isinstance(item, dict) and isinstance(item.get("evidence_id"), str):
            ids.add(item["evidence_id"])
        else:
            raise ValueError(
                f"evidence bundle item #{i} must be a string or "
                f"{{evidence_id: ...}} object"
            )
    return ids


def _structural_check(plan: object) -> list[str]:
    """Fallback check when jsonschema is not installed."""
    errors: list[str] = []
    if not isinstance(plan, dict):
        return [f"top-level: expected object, got {type(plan).__name__}"]

    for key in REQUIRED_TOP:
        if key not in plan:
            errors.append(f"top-level: missing required field '{key}'")

    unknown_top = set(plan.keys()) - set(REQUIRED_TOP)
    for key in sorted(unknown_top):
        errors.append(f"top-level: unknown field '{key}'")

    if isinstance(plan.get("section_name"), str) is False and "section_name" in plan:
        errors.append("section_name: must be a string")
    if isinstance(plan.get("section_goal"), str) is False and "section_goal" in plan:
        errors.append("section_goal: must be a string")
    if isinstance(plan.get("synthesis"), str) is False and "synthesis" in plan:
        errors.append("synthesis: must be a string")

    sec_lims = plan.get("section_limitations")
    if sec_lims is not None and not (
        isinstance(sec_lims, list) and all(isinstance(x, str) for x in sec_lims)
    ):
        errors.append("section_limitations: must be an array of strings")

    claims = plan.get("claims")
    if claims is None:
        return errors
    if not isinstance(claims, list):
        errors.append("claims: must be an array")
        return errors

    for idx, claim in enumerate(claims):
        prefix = f"claims[{idx}]"
        if not isinstance(claim, dict):
            errors.append(f"{prefix}: expected object")
            continue
        for key in REQUIRED_CLAIM:
            if key not in claim:
                errors.append(f"{prefix}: missing required field '{key}'")
        unknown = set(claim.keys()) - set(REQUIRED_CLAIM)
        for key in sorted(unknown):
            errors.append(f"{prefix}: unknown field '{key}'")

        cid = claim.get("claim_id")
        if isinstance(cid, str) and not CLAIM_ID_RE.match(cid):
            errors.append(f"{prefix}.claim_id: must match ^C[0-9]+$ (got {cid!r})")

        conf = claim.get("confidence")
        if conf is not None and conf not in CONFIDENCE_VALUES:
            errors.append(
                f"{prefix}.confidence: must be one of low/moderate/high "
                f"(got {conf!r})"
            )

        allowed = claim.get("allowed_in_draft")
        if allowed is not None and not isinstance(allowed, bool):
            errors.append(f"{prefix}.allowed_in_draft: must be a boolean")

        ev_ids = claim.get("evidence_ids")
        if ev_ids is not None:
            if not isinstance(ev_ids, list) or not all(
                isinstance(x, str) for x in ev_ids
            ):
                errors.append(f"{prefix}.evidence_ids: must be array of strings")
            else:
                for e in ev_ids:
                    if not EVIDENCE_ID_RE.match(e):
                        errors.append(
                            f"{prefix}.evidence_ids: '{e}' does not match "
                            "^(EXP|NOTE|CITE|FIG|TAB)-..."
                        )

        for list_field in (
            "assumptions",
            "alternative_interpretations",
            "limitations",
            "unresolved_questions",
        ):
            val = claim.get(list_field)
            if val is not None and not (
                isinstance(val, list) and all(isinstance(x, str) for x in val)
            ):
                errors.append(f"{prefix}.{list_field}: must be array of strings")

        for str_field in ("claim", "reasoning"):
            val = claim.get(str_field)
            if val is not None and not isinstance(val, str):
                errors.append(f"{prefix}.{str_field}: must be a string")

    return errors


def _schema_check(plan: object, schema: dict) -> list[str]:
    """Preferred: use jsonschema if available, otherwise fall back."""
    try:
        import jsonschema  # type: ignore
    except ImportError:
        return _structural_check(plan)
    validator = jsonschema.Draft202012Validator(schema)
    errors: list[str] = []
    for err in sorted(validator.iter_errors(plan), key=lambda e: list(e.absolute_path)):
        path = "/".join(str(p) for p in err.absolute_path) or "top-level"
        errors.append(f"schema: {path}: {err.message}")
    return errors


def _cross_field_checks(plan: dict, allowed_ids: set[str]) -> list[str]:
    """Checks that go beyond the JSON Schema:
      * evidence-ID whitelist
      * allowed_in_draft => at least one evidence_id
      * claim_id uniqueness
    """
    errors: list[str] = []
    seen_ids: set[str] = set()

    for idx, claim in enumerate(plan.get("claims") or []):
        if not isinstance(claim, dict):
            continue
        prefix = f"claims[{idx}]"

        cid = claim.get("claim_id")
        if isinstance(cid, str):
            if cid in seen_ids:
                errors.append(f"{prefix}.claim_id: duplicate id {cid!r}")
            seen_ids.add(cid)

        ev_ids = claim.get("evidence_ids") or []
        if isinstance(ev_ids, list):
            for e in ev_ids:
                if isinstance(e, str) and e not in allowed_ids:
                    errors.append(
                        f"{prefix}.evidence_ids: unknown evidence id {e!r} "
                        "(not in supplied evidence_bundle)"
                    )

        if claim.get("allowed_in_draft") is True:
            if not (isinstance(ev_ids, list) and any(
                isinstance(e, str) for e in ev_ids
            )):
                errors.append(
                    f"{prefix}: allowed_in_draft is true but no evidence_ids "
                    "are supplied"
                )

    return errors


def validate(plan_path: Path, evidence_path: Path) -> tuple[int, list[str]]:
    """Return (exit_code, errors). exit_code=0 valid, 1 recoverable, 2 unrecoverable."""
    try:
        plan = _load_json(plan_path)
    except (FileNotFoundError, ValueError) as e:
        return 2, [str(e)]

    try:
        allowed_ids = _load_evidence_ids(evidence_path)
    except (FileNotFoundError, ValueError) as e:
        return 2, [f"evidence bundle: {e}"]

    try:
        schema = json.loads(_schema_path().read_text())
    except FileNotFoundError:
        return 2, [f"reasoning schema not found: {_schema_path()}"]

    errors = _schema_check(plan, schema)
    if isinstance(plan, dict):
        errors.extend(_cross_field_checks(plan, allowed_ids))

    if errors:
        return 1, errors
    return 0, []


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    p.add_argument("--plan", required=True, help="path to reasoning plan JSON")
    p.add_argument(
        "--evidence-bundle",
        required=True,
        help="path to evidence-bundle JSON (whitelist of evidence_ids)",
    )
    p.add_argument(
        "--report",
        help="write errors to this JSON file (default: <plan>.errors.json)",
    )
    args = p.parse_args()

    plan_path = Path(args.plan)
    evidence_path = Path(args.evidence_bundle)
    report_path = Path(args.report) if args.report else plan_path.with_suffix(
        plan_path.suffix + ".errors.json"
    )

    exit_code, errors = validate(plan_path, evidence_path)

    report_path.write_text(json.dumps({
        "plan": str(plan_path),
        "evidence_bundle": str(evidence_path),
        "exit_code": exit_code,
        "errors": errors,
    }, indent=2))

    if errors:
        print(f"[reasoning] validation FAILED ({len(errors)} error(s)):",
              file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        print(f"[reasoning] report written to {report_path}", file=sys.stderr)
    else:
        print(f"[reasoning] validation OK: {plan_path}")

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
