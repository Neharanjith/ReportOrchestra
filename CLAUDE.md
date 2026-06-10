# CLAUDE.md — ReportOrchestra

This file is read by Claude Code at the start of every session. It's the persistent memory of the project: what it is, how it's organized, and the rules of engagement. The detailed development roadmap (with paste-ready subtask prompts) lives in `PLAN.md`.

---

## What this project is

**ReportOrchestra** is a multi-agent pipeline that converts unstructured research materials (a 16K-line lab notebook, original proposal, last year's progress report, published papers, miscellaneous notes, a LaTeX template) into a submission-ready LaTeX **Final Project Report** in the DARPA / DoE / NSF / NASA / IARPA style. Inspired by PaperOrchestra (Song et al., 2026), adapted for US government technical reporting.

**The user is Leslie** (he/him), a researcher — not a programmer. He drives the project by pasting prompts into Claude Code and reading outputs. He does not write code. He does edit plain-text prompt files in `src/prompts/`.

---

## Architecture

Seven modules feed an end-to-end pipeline:

```
Inputs ─► Indexer ─► Outline Agent ─► (Lit Review ‖ Diagram Emitter ‖ Section Writer)
                                          └─► Assembler ─► Refinement Loop ─► latexmk ─► report.pdf
```

| Module | File | Responsibility |
|---|---|---|
| Indexer | `src/agents/indexer.py` | Load inputs; chunk notebook by markdown headers; per-chunk topical keywords; keyword-overlap retrieval |
| Outline Agent | `src/agents/outline_agent.py` | Emit a single JSON plan: `section_plan`, `lit_search_strategy`, `diagram_plan` |
| Lit Review Agent | `src/agents/lit_review_agent.py` | Discover candidates (Semantic Scholar + DTIC stub) → verify → emit `verified.bib` and `citation_map.json` → draft §1.2 Background |
| Diagram Emitter | `src/agents/diagram_emitter.py` | Generate TikZ or Mermaid code per `diagram_plan` entry. **Conceptual diagrams only — no data plots.** |
| Section Writer | `src/agents/section_writer.py` | Draft one section at a time, with strict citation/diagram allowlists |
| Assembler | `src/agents/assembler.py` | Stitch template + sections + diagrams + bib + distribution statement into one `.tex` |
| Refinement Agent | `src/agents/refinement_agent.py` | Score-driven accept/revert loop (≤3 iterations); reviewer scores 7 axes; revisor applies top-3 specific revisions only |

**Total: ~25–45 LLM calls per full report run.**

---

## Repo layout

```
report-orchestra/
├── PLAN.md                      # Development roadmap with paste-ready CC prompts
├── CLAUDE.md                    # This file
├── README.md
├── pyproject.toml
├── config/
│   ├── config.yaml              # Model assignments, paths, refinement thresholds, citation cutoff, AskSage/Ollama URLs
│   ├── nrl_template_mapping.yaml # Maps section_ids to NRL template chapter/section headings for PLACEHOLDER replacement
│   └── distribution_statement.txt # (Leslie writes this once; Program Manager reviews)
├── inputs/                      # Leslie's source materials (read-only at runtime): notebook.md, *.pdf, notes/, papers/, examples/, template.tex
├── work/                        # Per-run intermediate artifacts (safe to delete)
│   ├── 01_index/                # notebook_index.json (chunks with keywords)
│   ├── 02_outline/              # outline.json (section plan + lit search strategy + diagram plan)
│   ├── 03_lit_review/           # candidates.json, verified.bib, citation_map.json, background.tex
│   ├── 04_diagrams/             # per-diagram .tex files
│   ├── 05_sections/             # (sections held in memory during full_run; only background written to disk)
│   └── 07_refined/              # scores.json (refinement history), report_refined.tex
├── outputs/                     # report.tex, report.pdf (final deliverables)
├── src/
│   ├── cli.py                   # Entry point: `python -m src.cli {baseline,run}`
│   ├── agents/                  # indexer, outline_agent, lit_review_agent, diagram_emitter, section_writer, assembler, refinement_agent
│   ├── tools/                   # llm_client (Ollama + AskSage dispatcher), semantic_scholar, dtic_search, pdf_extract, latex_compile, mermaid_render
│   └── prompts/                 # Plain-text prompt files — Leslie's primary tuning surface
└── tests/                       # pytest, mostly offline with monkey-patched call_llm
```

---

## How to run

```bash
# One-shot baseline (single Sonnet call via AskSage, throwaway quality, end-to-end smoke):
python -m src.cli baseline

# Full multi-agent pipeline with all agents (outline, lit review, diagrams, sections, refinement):
python -m src.cli run

# Optional flags: --inputs <dir> --out <dir>
```

**Requires two environment variables for paid Claude model access via AskSage:**
```bash
export ASKSAGE_API_KEY="<your-asksage-api-token>"
export ASKSAGE_CERT_PATH="/path/to/.certs/full_dod_bundle.pem"
```

**Optional (improves Semantic Scholar rate limits):**
```bash
export S2_API_KEY="<your-semantic-scholar-key>"
```

AskSage provides FedRAMP High, DoD IL5/IL6 compliant access to Claude models through the Army GenAI endpoint. Ollama (free local models) is used by default for indexing and diagram generation.

---

## Hard rules — do not violate

1. **Leslie does not write code.** If a fix needs code, Claude Code writes it.
2. **Claude Code does not approve drafts.** Quality judgment of generated reports belongs to Leslie.
3. **Anti-leakage is sacred.** Any agent that drafts report content must use `anti_leakage=True` in its `call_llm` invocation. The block in `src/prompts/00_anti_leakage.txt` forbids using training knowledge beyond standard scientific terminology, inventing numbers, or citing papers not in the verified bibliography.
4. **No hallucinated citations.** `\cite{key}` may only reference keys that exist in `work/03_lit_review/verified.bib`. The Section Writer prompt enforces this; the Assembler validates and strips orphaned citations on the way out.
5. **No data plots from LLMs.** Diagrams are conceptual only (architecture, flow, block). Data figures, if any, come from Leslie's notebook and are inserted as static images.
6. **Conceptual visuals are TikZ or Mermaid only.** Mermaid renders to PDF via `mmdc` if installed; otherwise TikZ-only.
7. **Stop where the subtask ends.** When executing a `PLAN.md` §6 subtask, do exactly what it specifies, run its acceptance test, print the success line, and STOP. Do not continue into the next subtask unless explicitly asked.
8. **Every code change ends with `pytest -q` green and a git commit.** Commit messages start with the subtask ID (e.g., `4.2: verify + bib`).
9. **Distribution statement is never auto-generated.** Leslie writes `config/distribution_statement.txt` once; a program manager reviews it.
10. **NRL template placeholders are sacred.** The Assembler uses `config/nrl_template_mapping.yaml` to locate and replace PLACEHOLDER lines in the NRL template. Do not modify section_ids in `outline_agent.py` or mapping entries without updating both files in sync.

---

## Working conventions

**Prompts live in `src/prompts/*.txt`, not in code.** Code reads prompt files via `Path.read_text()` and applies `str.format(...)`. Never inline a prompt string into a `.py` file. This is what lets Leslie tune the system without writing code.

**Braces in prompt templates.** Because prompts are loaded with `str.format`, any literal LaTeX brace in the template must be doubled: write `\cite{{key}}` to produce `\cite{key}` at runtime. Existing prompts already follow this; preserve the convention.

**Models are dispatched by role, not hardcoded.** Always call `call_llm("<role>", system, user, ...)` and let `config/config.yaml` map the role to a `provider:model` string. Never hardcode `"claude-sonnet-4-6"` or similar inside an agent. Adding a new agent = adding a new role to `config.yaml`.

**Environment variables for runtime LLM calls:**
- `ASKSAGE_API_KEY` — Required to access Claude models via AskSage's Army GenAI endpoint.
- `ASKSAGE_CERT_PATH` — Required; path to DoD certificate bundle (`full_dod_bundle.pem`).
- `S2_API_KEY` — Optional; improves Semantic Scholar rate limits from ~100 to ~10,000 req/5min. Obtain free key at https://www.semanticscholar.org/product/api.

**Tests are mostly offline.** `tests/test_*_offline.py` files monkey-patch `call_llm` so unit tests don't burn AskSage tokens or require network. Network-dependent tests (Ollama smoke, latexmk, semantic_scholar) use `pytest.mark.skipif`. Keep this pattern; never write a test that silently requires the live network.

**Semantic Scholar retries & rate limiting.** The `src/tools/semantic_scholar.py` wrapper includes retry logic for 429 (rate limit), 502/503/504 (server) errors with exponential backoff. It honors both `S2_API_KEY` (if set) for higher limits and the `semantic_scholar_rate_limit` in `config.yaml`. Tests verify retry behavior without hitting the real API.

**AskSage integration in llm_client.py.** The `call_llm()` function dispatches by provider prefix:
- `ollama:devstral-small-2:24b` → local free inference
- `asksage:claude-sonnet-4-5-20250929` → Claude via Army GenAI endpoint (requires `ASKSAGE_API_KEY` and `ASKSAGE_CERT_PATH`)

The AskSage code includes retry logic for transient server errors. Errors in AskSage calls are fatal; do not add fallback logic that silently degrades to Ollama (that masks configuration problems).

**Work directory is disposable.** Anything in `work/` may be regenerated by re-running the pipeline. Don't put anything precious there. `outputs/` is the deliverable.

---

## Understanding the two models in this project

**Two layers of model choices:**

1. **CC's own backing model** (Leslie's choice, set via `claude --model <name>`):
   - Can be local (Ollama: devstral-small-2:24b, Nemotron, Llama) or cloud (Claude).
   - If local, prompts in `PLAN.md` §6 blocks are written to be explicit and schema-driven — what 24B models handle reliably.
   - If cloud, all guarantees about reasoning strength still apply: stick to the subtask, don't refactor opportunistically, don't combine subtasks.
   - If ambiguous, print `Stuck on: <one sentence>` and stop. Do not improvise.

2. **Runtime system models** (controlled by `config/config.yaml`):
   - Ollama (free): used for indexing, chunk summary, diagram generation, section drafting.
   - AskSage (paid Claude via Army GenAI): used for high-stakes reasoning (outline, lit-review synthesis, refinement).
   - These are **independent** of what CC itself runs on. Leslie may run CC on Haiku (fast cloud development) while the system calls Sonnet/Opus at runtime.

---

## Token budget awareness

Leslie has a monthly AskSage token cap. Be frugal:

**Model assignment by `config/config.yaml` (current):**
- **Ollama (free)**: indexer, lit_search, diagram, section_writer
- **AskSage Claude (paid)**: outline (Sonnet), lit_synth (Sonnet), refinement_reviewer (Haiku), refinement_revisor (Sonnet)

**Per-report cost estimate:** ~$2.00–$3.00 in AskSage tokens depending on notebook size and lit-review depth. If a role assignment changes, verify it doesn't exceed Leslie's monthly cap.

**Never escalate paid models without justification:**
- Indexing, section drafting, diagram code generation: use Ollama (free).
- Only use Claude for: long-context reasoning (outline), citation discipline (lit synth), refinement JSON discipline.

**Tests:** Never call paid models. Always mock `call_llm()` in unit tests or skip network-dependent tests with `@pytest.mark.skipif`. Exception: Ollama smoke tests for development.

---

## Setup requirements

**Leslie must do this once before running `python -m src.cli run`:**

1. **Ollama (for local free models):**
   - Install Ollama (≥v0.14.0) from https://ollama.ai
   - Pull the model: `ollama pull devstral-small-2:24b`
   - Start Ollama server: `ollama serve` (in a separate terminal)

2. **AskSage (for Claude models via Army GenAI):**
   - Get API token from https://chat.asksage.ai (Account Settings → API Keys)
   - Download DoD certificate bundle (`full_dod_bundle.pem`) and save to `~/.certs/`
   - Set environment variables:
     ```bash
     export ASKSAGE_API_KEY="your-asksage-token"
     export ASKSAGE_CERT_PATH="$HOME/.certs/full_dod_bundle.pem"
     ```
   - Verify: `curl --cacert $ASKSAGE_CERT_PATH -X POST 'https://api.genai.army.mil/server/anthropic/v1/messages' ...` (see PLAN.md §0.2 for curl example)

3. **Semantic Scholar API (optional, improves rate limits):**
   - Request free key at https://www.semanticscholar.org/product/api (takes ~1 business day)
   - Once approved: `export S2_API_KEY="your-s2-key"`

4. **LaTeX (for PDF compilation):**
   - `which latexmk` should return a path; if not: `apt-get install texlive-full` (Ubuntu) or `brew install --cask mactex` (macOS)

Once these are set up, `python -m src.cli run` should work end-to-end.

---

## When starting a session

**If Leslie pastes a §6 subtask block:**
1. Copy the entire fenced block (ROLE / CONTEXT / PRECONDITIONS / DO THIS / ACCEPTANCE TEST / WHEN DONE / IF STUCK).
2. Follow it verbatim. Don't second-guess, refactor opportunistically, or merge subtasks.
3. When the acceptance test passes, print the "WHEN DONE" line and STOP.

**For other tasks:**
1. Skim `PLAN.md` §1–5 for context; read §6 for any active subtask.
2. Read `src/prompts/*.txt` files relevant to the work.
3. Check `git log --oneline -20` to see what's completed (phases 0–4 mostly done; phases 5–7 in progress).
4. Confirm `pytest -q` is green; if not, fix the failure first.
5. Read the relevant source files if you're debugging or refactoring.

**Critical context:**
- Phases 0–3 (setup, baseline, outline, indexing) are mature. Avoid refactoring them.
- Phase 4 (lit review: discovery, verification, background drafting) is complete.
- Phase 5–7 (diagrams, sections, assembler, refinement) are complete but may need fixes.
- Always check `config/config.yaml` and `config/nrl_template_mapping.yaml` — changes to section_ids require both files to be kept in sync.

---

## MVP implementation status

**Complete (Phases 0–7):**
- End-to-end pipeline: outline → index → lit review → diagrams → sections → assemble → refine → PDF
- Notebook chunking and keyword-based retrieval
- Semantic Scholar candidate discovery with retry logic
- Citation verification and deduplicated `.bib` generation
- NRL template-aware assembly with PLACEHOLDER replacement
- Refinement loop with scoring and accept/revert logic
- Full LaTeX compilation and error recovery

**Not in scope (v2+):**
- Embedding-based retrieval (current: keyword overlap, intentional for simplicity)
- Real DTIC/NTRS/OSTI scrapers (stub in `dtic_search.py` returns empty; API integration deferred)
- Auto-extraction of numerical results into LaTeX tables
- Automated continuity check against last year's progress report
- VLM (vision language model) critic loop for diagrams
- Data-plot generation from LLMs (diagrams are conceptual only)
- PII scrubbing / `--scrub` mode
- Embedding-based semantic search (would replace keyword overlap retriever)

---

## When in doubt

**About a design decision:** Ask Leslie. Do not assume.

**About a code mechanic:** Check `PLAN.md` §6 for the closest analogous subtask and follow that pattern.

**About a model assignment or LLM call:** Read `config/config.yaml` and `src/tools/llm_client.py`. Never hardcode a model string. Always use the `call_llm("<role>", ...)` pattern.

**About section_ids or template structure:** Check `config/nrl_template_mapping.yaml` and `src/agents/outline_agent.py` in sync. These two files must match.

**About what "done" means:** Look for the `ACCEPTANCE TEST` line in the current subtask. If you can't run that test and pass it, you're not done.

**About environment variables:** 
- `ASKSAGE_API_KEY` and `ASKSAGE_CERT_PATH` are required only if `config.yaml` has `asksage:*` models.
- `S2_API_KEY` is optional; graceful degradation to public rate limits if absent.
- Ollama URLs and AskSage URLs are in `config.yaml` — do not hardcode.

**About test failures:** Always check if the test is mocking `call_llm` (it should be). Network-dependent tests should use `@pytest.mark.skipif`. Never write a test that silently requires live APIs.