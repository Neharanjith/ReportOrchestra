# Reasoning Plan schema

Human-readable companion to `reasoning_schema.json`. The JSON Schema is the
source of truth; this file explains intent.

## Purpose

One JSON object per section. It captures *what the section is entitled to
say*, given the supplied evidence — before any prose is written. The Section
Writing Agent later turns approved claims into fluent scientific prose.

## Top-level fields

| Field | Type | Notes |
|---|---|---|
| `section_name` | string | The section this plan governs (e.g. "Discussion"). |
| `section_goal` | string | One-sentence goal drawn from the outline. |
| `claims` | array | Zero or more candidate claims, each independently reasoned. |
| `section_limitations` | array&nbsp;of&nbsp;strings | Limitations that apply to the section as a whole, not tied to a single claim. |
| `synthesis` | string | ≤400 words. How the approved claims fit together as a story. |

`additionalProperties: false` at the top level — no ad-hoc keys.

## Claim object

| Field | Type | Notes |
|---|---|---|
| `claim_id` | string | Must match `^C[0-9]+$` (e.g. `C1`). |
| `claim` | string | One sentence. |
| `evidence_ids` | array of strings | Prefixed IDs; see below. |
| `reasoning` | string | The logical connection between evidence and claim. |
| `assumptions` | array of strings | Non-trivial assumptions the inference requires. |
| `alternative_interpretations` | array of strings | Plausible competing readings. |
| `limitations` | array of strings | Limitations of the evidence for this claim. |
| `unresolved_questions` | array of strings | What the evidence leaves open. |
| `confidence` | enum | `"low"`, `"moderate"`, `"high"`. Nothing else. |
| `allowed_in_draft` | boolean | Only `true` if the evidence is sufficient to state the claim in the paper. |

## Evidence ID format

Every entry in `evidence_ids` must match `^(EXP|NOTE|CITE|FIG|TAB)-[A-Za-z0-9_-]+$`.

| Prefix | Meaning |
|---|---|
| `EXP-` | Experimental result / measured value |
| `NOTE-` | Notebook or project excerpt |
| `CITE-` | Verified citation (bibkey) |
| `FIG-` | Figure |
| `TAB-` | Table |

The orchestrator constructs the whitelist of allowed IDs (the
`evidence_bundle`) and hands it to the agent. The deterministic validator
rejects any ID that is not on that whitelist. The model is never allowed to
validate its own invented evidence.

## Deterministic validation

`scripts/validate_reasoning.py` enforces, in addition to the JSON Schema:

1. Every `evidence_ids` value is present in the supplied `evidence_bundle`.
2. Every claim with `allowed_in_draft: true` has at least one entry in
   `evidence_ids`.
3. `confidence` values use only the allowed enum.
4. `claim_id` values are unique across the plan.
5. Required top-level and per-claim fields are present.

Exit codes:

| Code | Meaning | Orchestrator action |
|---|---|---|
| 0 | valid | send to Section Writing Agent |
| 1 | invalid — recoverable (e.g. unknown evidence, missing field) | re-prompt the agent with the error report; retry up to 3× |
| 2 | invalid — unrecoverable (unreadable file, malformed JSON top-level) | fail loudly |

The validator writes a machine-readable error report to
`<plan_path>.errors.json` alongside a short human-readable summary on stderr.

## Example

```json
{
  "section_name": "Discussion",
  "section_goal": "Interpret performance under reduced-data conditions",
  "claims": [
    {
      "claim_id": "C1",
      "claim": "The method is more robust than the baseline under reduced-data conditions.",
      "evidence_ids": ["EXP-04", "FIG-03"],
      "reasoning": "The method's performance declined less than the baseline when both were evaluated under the same reduced-data conditions.",
      "assumptions": [
        "Both methods were evaluated under equivalent conditions."
      ],
      "alternative_interpretations": [
        "The difference may be caused by prompt design or regularization rather than the architecture alone."
      ],
      "limitations": [
        "Only one dataset was evaluated."
      ],
      "unresolved_questions": [
        "Whether the result generalizes to other datasets."
      ],
      "confidence": "moderate",
      "allowed_in_draft": true
    }
  ],
  "section_limitations": [],
  "synthesis": "Under reduced-data conditions the method degrades more gracefully than the baseline (C1), though the effect is measured on a single dataset and could be attributable to factors beyond architecture. This motivates the multi-dataset evaluation outlined as future work."
}
```
