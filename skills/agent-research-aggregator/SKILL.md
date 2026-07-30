---
name: agent-research-aggregator
description: Pre-pipeline aggregator that scans AI agent cache directories (.claude, .cursor, .antigravity, .openclaw) or any user-specified directory for experimentation logs, extracts insights and numeric results, and formats them as PaperOrchestra-ready inputs (idea.md + experimental_log.md). TRIGGER when the user says "aggregate my agent logs for paper writing", "extract experiments from my coding agent history", "prepare PaperOrchestra inputs from my cache", "turn my agent logs into a paper", mentions a folder or directory they want to use as the basis for a paper, or wants to run PaperOrchestra but only has scattered agent experiment histories rather than structured inputs. Run this BEFORE paper-orchestra. Also called automatically by paper-orchestra when workspace/inputs/idea.md or workspace/inputs/experimental_log.md are missing.
---

# agent-research-aggregator

---

## Should I run? (decision gate)

Before starting Phase 1, check whether aggregation is actually needed:

| Situation | Action |
|---|---|
| `workspace/inputs/idea.md` **and** `workspace/inputs/experimental_log.md` both exist and are non-empty | **Skip this skill entirely.** Proceed directly to `paper-orchestra`. |
| Either file is missing or empty, **and** the user provided a directory path | **Run this skill** with that directory as `--search-roots`. |
| Either file is missing or empty, **and** no directory was provided | Scan cwd and `~` by default; show the discovery summary to the user before continuing. |
| The inputs exist but look thin (e.g. idea.md has < 5 lines, no numeric data in experimental_log.md) | **Ask the user** whether to supplement with aggregation or proceed as-is. |

The skill is intentionally a pre-pass — it is cheap to skip and should only run when the structured inputs don't already exist.

---

A pre-processing skill for PaperOrchestra (arXiv:2604.05018). Reads scattered
experimentation artifacts from AI coding-agent cache directories and synthesizes
them into the structured `(I, E)` input pair the PaperOrchestra pipeline expects.

```
[.claude/]  [.cursor/]  [.antigravity/]  [.openclaw/]
      │            │              │               │
      └────────────┴──────────────┴───────────────┘
                          │
                    Phase 1: Discovery
                  (discover_logs.py)
                          │
                    discovered_logs.json
                          │
                    Phase 2: Extraction
                  (LLM call per log batch)
                          │
                    raw_experiments.json
                          │
                    Phase 3: Synthesis
                  (LLM call — consolidate)
                          │
                    synthesis.json
                          │
                    Phase 4: Formatting
                  (format_po_inputs.py)
                          │
             ┌────────────┴────────────┐
      workspace/inputs/         workspace/ara/
        idea.md                   aggregation_report.md
        experimental_log.md       discovered_logs.json
                                  raw_experiments.json
                                  synthesis.json
```

The output drops directly into `workspace/inputs/` so the user can immediately
run `paper-orchestra` on the same workspace.

---

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--search-roots` | no | cwd, `~` | Comma-separated directories to scan for agent caches |
| `--agents` | no | all | Comma-separated subset: `claude,cursor,antigravity,openclaw` |
| `--workspace` | no | `./workspace` | PaperOrchestra workspace root |
| `--depth` | no | 4 | Max directory scan depth (prevents runaway scans on large home dirs) |
| `--since` | no | none | Only include logs modified after this date (ISO 8601: `2025-01-01`) |
| `--max-files` | no | unlimited | Stop discovery after finding this many files (safety cutoff for large directories) |
| `--quick` | no | false | Only scan priority agent directories, skip general file scan (faster for large directories) |

The user specifies these when invoking the skill, or you may ask them for
`--search-roots` if the current directory has no detectable agent caches.

---

## Phase 1 — Discovery (deterministic)

Run the discovery script to catalog every relevant log file:

```bash
python skills/agent-research-aggregator/scripts/discover_logs.py \
    --search-roots <roots> \
    --agents <agents> \
    --depth <depth> \
    --since <since> \
    --out workspace/ara/discovered_logs.json
```

The script exits with code **2** when no `--project` filter is set (this is
expected on the first run). It prints a **"Projects found"** list to stdout —
show it to the user immediately.

**If no logs are found at all:** stop and ask the user to specify
`--search-roots` or point you at a directory that contains agent cache folders.

### File classification (automatic, no flags)

Every discovered file is tagged as **`foundation`** or **`experimental`** in
the manifest (`entry["class"]`) and summarized at the bottom of the discovery
printout under `By class:`:

- **Foundation** — project framing docs. Filename matches `README`,
  `ARCHITECTURE`, `METHOD`, `DESIGN`, `PROBLEM`, `HYPOTHESIS`, `IDEA`,
  `PROPOSAL`, `PLAN`, `NOTES`, `CLAUDE.md`, `.cursorrules`, `AGENTS.md`;
  file lives under `docs/`; or is a top-level `.md` at a search root.
- **Experimental** — everything else (agent-cache memory, chat/session dumps,
  run logs, metrics, ablations, `.ipynb`, `.jsonl`, etc.). Ambiguous files
  default to experimental.

Why the split: foundation docs are project *context* (they don't go stale the
way experiment logs do). Phase 2 bypasses them from relevance filtering *and*
freshness ranking, and Phase 3 injects their contents as `<foundation>`
context in the synthesis prompt. Experimental files still pass through the
relevance filter and any freshness budget.

If the printed `By class:` counts look wrong (a critical framing doc landed in
experimental, or a stale run log got tagged foundation), sanity-check that
before proceeding — the classification is filename-based and can be tuned in
`FOUNDATION_STEM_PREFIXES` / `FOUNDATION_PATH_COMPONENTS` at the top of
`discover_logs.py`.

---

## Phase 1.5 — Project Selection (mandatory)

**A paper can only be written from a single project. You must ask the user
which project to use before any LLM processing begins.**

1. Display the numbered project list from the discovery summary, e.g.:
   ```
   Projects found:
     [1] /home/alice/projects/my-rl-experiment  (42 files)
     [2] /home/alice/projects/llm-eval-suite    (17 files)
     [3] /home/alice/projects/old-demo          (3 files)
   ```
2. Ask: *"Which project should this paper be based on? Please choose a number
   or paste the project path."*
3. **Do not proceed to Phase 2 until the user has answered.**
4. Re-run discovery with the chosen project to filter the manifest:

```bash
python skills/agent-research-aggregator/scripts/discover_logs.py \
    --search-roots <roots> \
    --agents <agents> \
    --depth <depth> \
    --since <since> \
    --project "<chosen project path>" \
    --out workspace/ara/discovered_logs.json
```

This overwrites `discovered_logs.json` so only the selected project's files
remain. The script exits 0 on success.

**If the discovery finds only one project:** skip the question and inform the
user: *"Only one project found: `<path>`. Using it for the paper."* — then
re-run with `--project` automatically.

**If the discovery summary shows irrelevant files after filtering:** ask the
user whether to include or exclude them before continuing to Phase 2. Err on
the side of inclusion — the extraction prompt is conservative.

---

## Phase 2 — Extraction (LLM-assisted)

There are two ways to run Phase 2:

### Option A: Automated (recommended for large folders)

Use `--process` mode for parallel, resumable, relevance-filtered extraction:

```bash
python skills/agent-research-aggregator/scripts/extract_experiments.py \
    --discovered workspace/ara/discovered_logs.json \
    --process --out workspace/ara/raw_experiments.json \
    --max-workers 4
```

This reads `discovered_logs.json`, groups files into ~40 KB batches, and calls
the LLM on each batch **in parallel** (up to `--max-workers` at once). Key
improvements for large folders:

1. **Parallel extraction** — multiple batches processed concurrently, not one at
   a time (set `--max-workers` to match your LLM provider's concurrency limit).
2. **Relevance pre-filtering** — each batch is scored against experiment-related
   keywords before any LLM call. Low-scoring batches (config files, install
   logs) are skipped automatically. Disable with `--no-filter`.
3. **Foundation bypass** — files tagged `foundation` in Phase 1 (READMEs,
   method notes, top-level docs) are never batched or sent to the LLM. They
   are handed to Phase 3 as context via `--emit-foundation-bundle`.
4. **Freshness ranking** — experimental files are sorted newest-first before
   batching. Combined with `--budget-files N` (or `--budget-bytes N`), only
   the newest N experimental files are extracted; older ones are dropped
   with a printed summary. No hard date required.
5. **Resumable** — if processing crashes, rerun with `--resume` to pick up
   where you left off instead of restarting from batch 1.

**Extraction flags for large / stale folders:**

| Flag | Default | Description |
|---|---|---|
| `--budget-files N` | 0 (unlimited) | Cap on experimental files extracted (newest first) |
| `--budget-bytes N` | 0 (unlimited) | Cap on cumulative experimental bytes |
| `--emit-foundation-bundle <path>` | none | Write foundation context bundle for Phase 3 |
| `--foundation-max-bytes N` | 102400 | Byte cap on foundation bundle (drops oldest first) |

**LLM configuration** (via environment variables):

| Variable | Default | Description |
|---|---|---|
| `EXTRACTION_MODEL` or `LLM_MODEL` | *(required)* | Model name (e.g. `claude-sonnet-4-20250514`) |
| `EXTRACTION_BASE_URL` or `LLM_BASE_URL` | `http://localhost:11434/v1` | OpenAI-compatible API endpoint |
| `EXTRACTION_API_KEY` or `LLM_API_KEY` | `no-key-required` | API key |
| `LLM_TIMEOUT` | `180` | Per-call timeout in seconds |

**Recipe for a large / stale folder** (skip old cruft without picking a date):

```bash
python skills/agent-research-aggregator/scripts/extract_experiments.py \
    --discovered workspace/ara/discovered_logs.json \
    --process --out workspace/ara/raw_experiments.json \
    --max-workers 4 \
    --budget-files 200 \
    --emit-foundation-bundle workspace/ara/foundation_bundle.md
```

After automated extraction, validate the output:

```bash
python skills/agent-research-aggregator/scripts/extract_experiments.py \
    --out workspace/ara/raw_experiments.json \
    --validate-only
```

### Option B: Manual (for small folders or custom LLM setups)

For small folders (<10 batches), process each batch manually:

1. List batches:
   ```bash
   python skills/agent-research-aggregator/scripts/extract_experiments.py \
       --discovered workspace/ara/discovered_logs.json --list-batches
   ```
2. For each batch: read the files, apply `references/extraction-prompt.md` as
   your system message, pass the raw log text as the user message, collect the
   structured JSON, append to `raw_experiments.json`.
3. Validate after all batches:
   ```bash
   python skills/agent-research-aggregator/scripts/extract_experiments.py \
       --out workspace/ara/raw_experiments.json --validate-only
   ```

Either way, **if batches are empty or all low-relevance**, warn the user before
proceeding to Phase 3.

---

## Phase 3 — Synthesis (LLM-assisted)

Consolidate possibly-redundant experiment records from multiple agent caches into
a single coherent research narrative. This is ONE LLM call.

**System message:** Use `references/synthesis-prompt.md` verbatim.

**User message:**
```
<foundation>
{contents of workspace/ara/foundation_bundle.md — if produced by Phase 2 via
--emit-foundation-bundle. Omit the block entirely if no bundle exists.}
</foundation>

<raw_experiments>
{contents of workspace/ara/raw_experiments.json}
</raw_experiments>
```

The `<foundation>` block gives the synthesizer project framing (problem
statement, method, architecture) so the narrative is grounded in the actual
project — but it must NOT be used as a source of numeric results or table
rows. See `references/synthesis-prompt.md` for the exact rules.

The LLM must return a `synthesis.json` with keys:
- `research_question` — the overarching question being investigated
- `hypothesis` — the core proposed solution / claim
- `method_summary` — how the approach works (concise, no data leakage)
- `key_contributions` — 2–5 bullet strings
- `experimental_setup` — datasets, metrics, baselines, implementation notes
- `results_tables` — array of `{title, headers[], rows[]}` markdown-table objects
- `qualitative_observations` — free-form text blocks (what worked, what didn't,
  failure modes, ablation insights)
- `iteration_history` — ordered list of `{iteration_id, change_description,
  outcome}` entries if multiple iterations are detected
- `open_questions` — questions that remain unanswered in the logs

Save to `workspace/ara/synthesis.json`.

> **Note:** By this point, the user has already selected a single project in
> Phase 1.5. The synthesis should represent one coherent research thread. If
> the LLM still surfaces multiple disconnected research questions, flag this
> as a data quality warning in the audit report (Phase 5) but do not re-ask
> for project selection — that decision was made earlier.

---

## Phase 4 — Formatting (deterministic)

Convert `synthesis.json` into PaperOrchestra input files:

```bash
python skills/agent-research-aggregator/scripts/format_po_inputs.py \
    --synthesis workspace/ara/synthesis.json \
    --out workspace/inputs/
```

This generates two files:

### `workspace/inputs/idea.md` (Sparse variant)

Follows the PaperOrchestra Sparse Idea format (arXiv:2604.05018, §3.1):

```markdown
# [Synthesized Research Title]

## Problem
<2–4 sentence problem statement derived from research_question>

## Hypothesis
<hypothesis from synthesis>

## Method
<method_summary from synthesis>

## Key Contributions
<key_contributions as bullet list>

## Open Questions
<open_questions, if any>
```

### `workspace/inputs/experimental_log.md`

Follows the PaperOrchestra Experimental Log format (App. D.3):

```markdown
## 1. Experimental Setup
<experimental_setup from synthesis, formatted as prose + sub-bullets>

## 2. Raw Numeric Data
<results_tables converted to GitHub-Flavored Markdown tables>

## 3. Qualitative Observations
<qualitative_observations from synthesis>

### Iteration History
<iteration_history as an ordered narrative, if present>
```

After running the script, **review both files** with the user:

1. Read `workspace/inputs/idea.md` aloud and ask: "Does this accurately capture
   your research question and method?"
2. Read the table headers from `workspace/inputs/experimental_log.md` and ask:
   "Are these the correct metrics and baselines?"

Revise based on feedback before proceeding to PaperOrchestra.

---

## Phase 5 — Audit Report (deterministic)

```bash
python skills/agent-research-aggregator/scripts/format_po_inputs.py \
    --synthesis workspace/ara/synthesis.json \
    --out workspace/inputs/ \
    --report workspace/ara/aggregation_report.md
```

The `--report` flag makes the script also write `aggregation_report.md`, which
contains:

- Number of agent caches scanned, files read, batches processed
- Per-agent breakdown (files found per agent type)
- Experiment records extracted (count, date range)
- Iterations detected (count, convergence direction)
- Data quality warnings (gaps, low-confidence extractions, conflicting numbers)
- Files written and their sizes

Show the report to the user. If the data quality section lists warnings, discuss
them before running paper-orchestra — garbage in, garbage out.

---

## Handoff to PaperOrchestra

Once the user has confirmed `idea.md` and `experimental_log.md`, the workspace
is ready for the paper-orchestra pipeline. You still need:

| File | Status | Action |
|---|---|---|
| `workspace/inputs/idea.md` | ✓ generated | user review recommended |
| `workspace/inputs/experimental_log.md` | ✓ generated | user review recommended |
| `workspace/inputs/template.tex` | **MISSING** | ask user to provide their conference LaTeX template |
| `workspace/inputs/conference_guidelines.md` | **MISSING** | ask user to provide (page limit, deadline, formatting rules) |

Tell the user exactly which two files are still needed, then offer to run
`paper-orchestra` once they supply them.

---

## Error handling

| Situation | Action |
|---|---|
| Cache directory does not exist | Skip silently; note in report |
| File is binary or non-text | Skip; note in report |
| File > 200 KB | Truncate at 200 KB; note in report with path |
| Discovery hits `--max-files` limit | Stop scanning; report total found and suggest using `--since` or narrower `--search-roots` |
| LLM extraction returns malformed JSON | Log the batch as `status: failed` and continue (automated mode retries once) |
| LLM call fails (timeout/network) in `--process` mode | Batch is skipped; checkpoint preserves all completed work; re-run with `--resume` |
| Relevance filter skips all batches | Warn user — logs may not contain experiment data; re-run with `--no-filter` to force full extraction |
| Synthesis returns > 1 `research_question` | Log as data quality warning in audit report; do not re-ask for project (was selected in Phase 1.5) |
| `results_tables` is empty after synthesis | Warn the user — PaperOrchestra's section-writing agent needs numeric data |

---

## Hard rules (never violate)

1. **Never write to agent cache directories.** This skill is read-only on `.claude/`, `.cursor/`, `.antigravity/`, `.openclaw/`.
2. **Never include personal information** (emails, names, credentials, API keys) in generated `idea.md` or `experimental_log.md`. The extraction prompt instructs the LLM to strip PII; double-check before handoff.
3. **Never fabricate results.** If a metric appears in only one log with low confidence, mark it `[UNVERIFIED]` in the table rather than silently including it.
4. **Never proceed past Phase 1 without user confirmation** of the discovered file list if the scan found > 50 files.

---

## Quick reference

```bash
# Phase 1: discover all projects (exits with code 2 — project selection required)
# Add --max-files N to stop early on huge directories
# Add --quick to skip general file scan
python skills/agent-research-aggregator/scripts/discover_logs.py \
    --search-roots . ~ --out workspace/ara/discovered_logs.json

# Phase 1.5: re-run with chosen project (exits 0)
python skills/agent-research-aggregator/scripts/discover_logs.py \
    --search-roots . ~ \
    --project "/home/user/projects/my-chosen-project" \
    --out workspace/ara/discovered_logs.json

# Phase 2 (automated — recommended for large folders):
#   Set EXTRACTION_MODEL, EXTRACTION_BASE_URL, EXTRACTION_API_KEY env vars
#   Add --resume to pick up from a previous partial run
#   Add --no-filter to disable relevance pre-filtering
python skills/agent-research-aggregator/scripts/extract_experiments.py \
    --discovered workspace/ara/discovered_logs.json \
    --process --out workspace/ara/raw_experiments.json \
    --max-workers 4

# Phase 2 validation (always run this after --process):
python skills/agent-research-aggregator/scripts/extract_experiments.py \
    --out workspace/ara/raw_experiments.json --validate-only

# Phase 3: Synthesis (LLM call, see above) ...

python skills/agent-research-aggregator/scripts/format_po_inputs.py \
    --synthesis workspace/ara/synthesis.json \
    --out workspace/inputs/ \
    --report workspace/ara/aggregation_report.md
```
