---
name: reasoning-agent
description: Step 3.5 of the PaperOrchestra pipeline for scientific papers. Runs once per section between evidence collection (outline + lit review + figures + experimental log) and section writing. Produces a structured reasoning plan (JSON) that decides which claims the section is entitled to make from the supplied evidence, with assumptions, alternative interpretations, limitations, and per-claim confidence. Does not write paper prose. TRIGGER when the orchestrator delegates Step 3.5 in SCIENTIFIC_PAPER mode. SKIPPED entirely in TECHNICAL_REPORT mode.
---

# Reasoning Agent (Step 3.5)

Between evidence collection and section writing. Runs **only for scientific
papers**. Skipped whenever `authors_note.md` explicitly requests a technical
report, technical paper, implementation-centered paper, or an equivalent
engineering-focused document — the same rule the Outline, Section Writing,
and Content Refinement agents use.

## What it is

A pre-writing stage that decides, for each section, *what the section is
entitled to say* given the supplied evidence. Its output is a structured
reasoning plan, not paper prose. The Section Writing Agent then turns
approved claims into fluent scientific prose without inventing content or
strengthening claims beyond the plan.

The agent produces one JSON file per section under
`workspace/reasoning/<section_slug>.json`. These are inspectable intermediate
artifacts.

## Mode gating (must match the rest of the pipeline)

- **SCIENTIFIC_PAPER (default)** — `authors_note.md` is absent, empty, or does
  not explicitly request a technical/implementation report. Run this agent.
- **TECHNICAL_REPORT** — `authors_note.md` explicitly requests a "technical
  report", "technical paper", "implementation-centered paper", or an
  equivalent engineering-focused document. **Skip this agent entirely.** Do
  not create `workspace/reasoning/`. The Section Writing Agent must not
  receive a reasoning input in this mode.

This is the same document-mode rule used in `skills/outline-agent`,
`skills/section-writing-agent`, and `skills/content-refinement-agent`; do not
introduce a second, parallel switch.

## Inputs (per section)

Provide only section-relevant evidence. Do not dump the whole workspace into
the prompt when section-specific selection is available.

- `outline.json` → the entry for this section (`section_id`, title, goals,
  bullets) — from `skills/outline-agent`
- Relevant experimental results from `experimental_log.md` — the subset that
  supports this section (do not include unrelated results)
- Relevant extracted project evidence (notebook chunks, notes)
- Verified literature from `citation_pool.json` / `refs.bib` (title,
  abstract, key) for the citations that plausibly bear on this section
- Relevant figures and tables — `figures/captions.json` entries and any
  extracted table metrics from `workspace/metrics.json`
- `authors_note.md` if present and non-empty (advisory only)

Every piece of evidence handed to the agent MUST carry a stable **evidence
ID** the agent can reference in its output:

| Evidence type | ID prefix | Example |
|---|---|---|
| Experimental result | `EXP-` | `EXP-04` |
| Notebook / project excerpt | `NOTE-` | `NOTE-12` |
| Verified citation | `CITE-` | `CITE-vaswani2017attention` |
| Figure | `FIG-` | `FIG-main_results` |
| Table | `TAB-` | `TAB-ablation` |

The orchestrator constructs the ID list, hands it to the agent as
`evidence_bundle`, and later reuses the same list to validate the output.

## Output

One JSON object per section, written to
`workspace/reasoning/<section_slug>.json`. See
`references/reasoning-schema.md` and `references/reasoning_schema.json` for
the strict schema. Filenames use sanitized lowercase section names
(`introduction.json`, `methodology.json`, `results.json`, `discussion.json`).

The Section Writing Agent later consumes only claims where
`allowed_in_draft: true`.

## How to run it

For each section in the outline:

1. Assemble the section-scoped inputs and the evidence ID list.
2. Prepend the Anti-Leakage Prompt from
   `../paper-orchestra/references/anti-leakage-prompt.md`.
3. Load `references/prompt.md` as the system message. Substitute
   `{section_name}`, `{section_goal}`, and `{section_role}` (one of
   `introduction`, `methodology`, `results`, `discussion`, `other`) so the
   agent applies the right section-aware sub-rules.
4. Send the section-scoped evidence bundle as the user message.
5. Parse the JSON response. Run:
   ```bash
   python skills/reasoning-agent/scripts/validate_reasoning.py \
       --plan workspace/reasoning/<slug>.json \
       --evidence-bundle workspace/reasoning/<slug>.evidence.json
   ```
6. If validation fails, **re-prompt the agent** with the validator's error
   report appended to the user message. Retry up to 3 times. If the third
   retry still fails, fail loudly — do not silently pass an unvalidated
   plan to the Section Writing Agent.

The validator is deterministic. The model is not permitted to validate its
own invented evidence — evidence ID membership is checked against the
`evidence_bundle` file the orchestrator wrote, not against anything the
model produced.

## Resources

- `references/prompt.md` — the reasoning-agent system prompt (verbatim rules)
- `references/reasoning-schema.md` — human-readable schema doc
- `references/reasoning_schema.json` — JSON Schema (Draft 2020-12)
- `scripts/validate_reasoning.py` — deterministic validator, exit codes for
  retry loops
