# ReportOrchestra: Development Plan (v1 — OpenCode Edition)

**Vision.** An automated multi-agent pipeline that ingests Leslie's unstructured research materials (16K-line lab notebook, original proposal, last year's progress report, published papers, additional notes) and produces a submission-ready LaTeX **Final Project Report** in DARPA/DoE/NSF style, with verified citations and auto-generated conceptual diagrams.

**Template.** PaperOrchestra (Song et al., 2026), adapted as follows:
- **Drop:** PaperBanana data-plot generation, VLM critic loop, conference-format autoraters.
- **Keep:** JSON-first outline, decoupled discovery/verification for citations, anti-leakage prompt, score-driven accept/revert refinement loop, exhaustive `citation_hints` in outline.
- **Add:** DTIC/NTRS-aware citation discovery, "Transitions" section logic, lab-notebook RAG indexer, distribution-statement boilerplate, TikZ/Mermaid diagram emitter.

**How to read this plan.** §1–5 and §7–10 set context. **§6 is what Leslie actually uses.** Every OC subtask in §6 has one literal copy-paste prompt in a fenced block. Paste it into OpenCode (running on `devstral-small-2:24b` by default), wait for OC to finish, verify the one-line acceptance check, then move to the next subtask.

---

## 1. System architecture

```
┌─────────────────┐     ┌────────────────────────────────────────────────────┐
│  Inputs         │     │                  ReportOrchestra                   │
│  - notebook.md  │     │                                                    │
│  - proposal.pdf │ ──► │  ┌──────────┐    ┌──────────────────┐              │
│  - last_pr.pdf  │     │  │  Indexer │ ─► │   Outline Agent  │ (JSON plan)  │
│  - papers/*.pdf │     │  └──────────┘    └────────┬─────────┘              │
│  - notes.md     │     │                           │                        │
│  - template.tex │     │      ┌────────────────────┼─────────────────┐      │
│  - examples/    │     │      ▼                    ▼                 ▼      │
└─────────────────┘     │  ┌────────┐         ┌──────────┐      ┌──────────┐ │
                        │  │ Lit    │         │ Section  │      │ Diagram  │ │
                        │  │ Review │         │ Writer   │      │ Emitter  │ │
                        │  └───┬────┘         └────┬─────┘      └────┬─────┘ │
                        │      └────────┬──────────┴─────────────────┘       │
                        │               ▼                                    │
                        │     ┌──────────────────┐  ┌────────────────────┐   │
                        │     │  Assembler       │ ─► Refinement Loop ──►│   │
                        │     │  (.tex + .bib)   │  │ (rubric, ≤3 iter)  │   │
                        │     └──────────────────┘  └─────────┬──────────┘   │
                        │                                     ▼              │
                        │                              ┌─────────────┐       │
                        │                              │  latexmk    │       │
                        │                              └──────┬──────┘       │
                        └─────────────────────────────────────┼──────────────┘
                                                              ▼
                                                       report.pdf + report.tex
```

Seven modules: Indexer, Outline Agent, Lit Review Agent, Diagram Emitter, Section Writer, Assembler, Refinement Agent. Total ~25–45 LLM calls per report run.

**NRL template-aware assembly.** The Assembler works natively with the NRL report template: instead of appending a monolithic body, it replaces `PLACEHOLDER` text blocks within the template's existing `\chapter{}` and `\section{}` structure. A `config/nrl_template_mapping.yaml` file maps each outline `section_id` to the exact chapter or section heading that precedes the corresponding placeholder. The Section Writer is constrained to produce content at `\section{}` level and below — never `\chapter{}` — since those headings already exist in the template.

---

## 2. Repository layout

```
report-orchestra/
├── PLAN.md
├── README.md
├── pyproject.toml
├── config/
│   ├── config.yaml
│   ├── distribution_statement.txt
│   └── nrl_template_mapping.yaml    ← section_id → NRL chapter/section heading
├── inputs/        notebook.md, proposal.pdf, last_progress_report.pdf, papers/, notes/, template.tex, examples/
├── work/          01_index/, 02_outline/, 03_lit_review/, 04_diagrams/, 05_sections/, 06_draft/, 07_refined/
├── outputs/       report.tex, report.pdf
├── src/
│   ├── cli.py
│   ├── agents/    indexer.py, outline_agent.py, lit_review_agent.py, diagram_emitter.py, section_writer.py, assembler.py, refinement_agent.py
│   ├── tools/     llm_client.py, semantic_scholar.py, dtic_search.py, pdf_extract.py, latex_compile.py, mermaid_render.py
│   └── prompts/   00_anti_leakage.txt, 02_outline.txt, 03a_chunk_summary.txt, 03_lit_synth.txt, 04_diagram.txt, 05_section_writer.txt, 07_reviewer.txt, 07_revisor.txt
└── tests/
```

---

## 3. Pareto-optimal model selection

OpenCode supports multiple model providers through its configuration. The following models are available for this project:

| Model | Cost (via AskSage tokens) | Use when |
|---|---|---|
| **Ollama (Devstral 24B / Nemotron-3-super)** | Free | Default for everything: parsing, code, chunk summaries, diagram code, citation key matching, format checks, bulk drafting |
| **Haiku 4.5 (via AskSage)** | ~$1 / $5 per Mtok | Cheap fan-out tasks where Ollama might be flaky: short JSON validators, single-page rubric scoring |
| **Sonnet 4.5/4.6 (via AskSage)** | ~$3 / $15 per Mtok | Long-context synthesis where one mistake cascades: outline JSON over the whole notebook, Intro/Background prose |
| **Opus 4.6/4.7 (via AskSage)** | ~$6 / $30 per Mtok | Hardest residual: refinement-loop tiebreaker; reserved, not default |

### AskSage Integration

**Important:** Paid Claude models (Sonnet, Opus, Haiku) are accessed through **AskSage** via the Army GenAI endpoint (`https://api.genai.army.mil`), not directly through Anthropic. AskSage provides:
- FedRAMP High, DoD IL5/IL6 compliant access
- Anthropic-compatible API endpoint (drop-in replacement)
- Token-based billing through your AskSage account
- **Requires DoD certificate bundle** for HTTPS verification

Available AskSage model identifiers:
- `claude-sonnet-4-5-20250929` — Default Sonnet (AWS Bedrock Gov)
- `claude-opus-4-7-default` — Most capable Opus (Google Vertex AI)
- `claude-opus-4-6-default` — Previous Opus (Google Vertex AI)
- `claude-haiku-4-5-20251001` — Fastest/cheapest (Google Vertex AI)

**Model Compatibility Note:** The default local model `devstral-small-2:24b` is developed by Mistral AI (French company), making it a non-Chinese open-source model compatible with OpenCode through Ollama. Alternative local models include `nemotron-3-super` (NVIDIA) and Llama models (Meta). All are Western-developed and OpenCode-compatible.

**Principle: default to Ollama (free), escalate only on demonstrated failure or high cascade risk.** Leslie's 8× L40s makes local viable for nearly every step. Escalation is one config flag, not a code change.

**Per-report runtime cost target:** ~$2.00 in AskSage tokens once tuned. **Build phase total:** $50–$150 across ~30 dev iterations.

**Important nuance for OC itself:** the OC prompts in §6 are written for `devstral-small-2:24b` as **OC's own backing model** — that is, *Leslie runs OpenCode on Devstral locally*. Each prompt is short, schema-driven, and explicit because that style is what 24B open-source models reliably handle. The system that OC builds will then call a *separate* mix of Ollama and AskSage models at report-generation time, per `config/config.yaml`.

### Configuring OpenCode Models

OpenCode reads model configuration from `opencode.json` or environment variables. To use different models:

1. **Local Ollama models (Free):** Configure OpenCode to use Ollama as the provider:
   ```json
   {
     "provider": "ollama",
     "model": "devstral-small-2:24b"
   }
   ```

2. **Paid models via AskSage (when escalation needed):** OpenCode can use AskSage's Anthropic-compatible endpoint. Set environment variables:
   ```bash
   export ASKSAGE_API_KEY="your-asksage-token-here"
   export ASKSAGE_CERT_PATH="/path/to/.certs/full_dod_bundle.pem"
   ```
   Note: The AskSage Army GenAI endpoint requires a DoD certificate bundle for HTTPS verification.

The `config/config.yaml` file controls which model the *ReportOrchestra system itself* uses for each task at runtime — this is separate from which model powers OpenCode during development.

---

## 4. Vision → MVP: development phases

| Phase | Goal | Done when... |
|---|---|---|
| **0. Setup** | Repo, env, OC+Ollama config, smoke tests | OpenCode with `devstral-small-2:24b` runs and edits a file |
| **1. Single-pass baseline** | One prompt → one draft. Bad output, but end-to-end. | `python -m src.cli baseline` produces a `.tex` that compiles |
| **2. Outline + Section Writer split** | Two-stage with JSON outline | Sections trace back to outline bullets |
| **3. Indexer** | Notebook chunked + searchable | Section Writer pulls only relevant notebook chunks |
| **4. Lit Review Agent** | Verified `.bib` generated, Intro+Background cited | Bibliography has zero hallucinated citations |
| **5. Diagram Emitter** | TikZ/Mermaid blocks render in the PDF | At least 2 conceptual diagrams in the output |
| **6. Refinement loop** | Score-driven accept/revert | Loop converges in ≤3 iterations on test input |
| **7. Polish** | Distribution stmt, ack, formatting, end-to-end wiring | Acceptance test on last year's data passes |

**Rule of thumb:** Phase 1's "bad output" is the most important deliverable. Once it works end-to-end with one prompt, every later phase replaces one component, not the system.

---

## 5. Task split — Leslie vs OpenCode

**Leslie does (no coding):**
- Provide and curate input materials.
- Make architectural and stylistic decisions when OC asks.
- Read and approve outline, lit-review verification, and final draft.
- Run the system, eyeball outputs at each phase before proceeding.
- Edit prompts in `src/prompts/*.txt` as the system matures (plain text, no code).
- Maintain `config/config.yaml`.
- Paste the §6 prompts into OC, in order.

**OpenCode does (everything else):**
- Write all Python code.
- Run tests and fix bugs.
- Debug LaTeX compile errors.
- Implement the prompts Leslie approves.

**Hard rules:**
1. Leslie does not write code. If a fix needs code, OC writes it.
2. OC does not approve drafts. Leslie reads outputs.
3. Every OC session starts by reading `PLAN.md` and the relevant `src/prompts/*.txt`.

---

## 6. Detailed subtasks with paste-ready OC prompts

**How to use each prompt below:**
1. Open OpenCode in the repo: `opencode` (with Ollama configured for `devstral-small-2:24b`)
2. Copy the entire fenced block under "**OC PROMPT**" — including ROLE, CONTEXT, DO THIS, ACCEPTANCE TEST, WHEN DONE, IF STUCK.
3. Paste it as a single message into OC. Hit enter.
4. When OC prints "Subtask X.Y complete", run the `✅ Verify` command yourself in another terminal. If it passes, move to the next subtask. If not, paste the failure into OC and ask it to fix.

Each prompt follows the same shape: ROLE → CONTEXT → PRECONDITIONS → DO THIS (numbered) → ACCEPTANCE TEST → WHEN DONE → IF STUCK. This shape is repetitive on purpose — it's what Devstral handles reliably.

---

### Phase 0 — Setup

#### 0.1 — Scaffold the project · Leslie + OC · XS · Devstral local · ~5 min

**Preconditions:** Empty directory. `PLAN.md` (this file) is in the directory.

**Complexity:** XS (Extra Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

```text
ROLE: You are OpenCode in a fresh, otherwise empty directory that
already contains PLAN.md.
CONTEXT: Read PLAN.md sections 2 and 6.0.1 before doing anything.
TASK: Scaffold the report-orchestra Python project.

DO THIS, IN ORDER:

1. Create the directory tree from PLAN.md §2. For empty directories
   (inputs/, work/, outputs/, src/prompts/), add a .gitkeep file.

2. For every Python file listed in src/agents/ and src/tools/, create
   it with EXACTLY this content (one line):
       """Placeholder. Implemented in a later subtask."""

3. Create src/__init__.py, src/agents/__init__.py, src/tools/__init__.py,
   tests/__init__.py — all empty.

4. Create README.md with one line: "# ReportOrchestra"

5. Create config/config.yaml as an empty file (filled in 0.4).
   Create config/distribution_statement.txt as an empty file.

6. Create pyproject.toml with EXACTLY this content:

   [project]
   name = "report-orchestra"
   version = "0.0.1"
   requires-python = ">=3.11"
   dependencies = [
     "requests>=2.31",
     "pymupdf>=1.24",
     "pyyaml>=6.0",
     "tqdm>=4.66",
     "tiktoken>=0.7",
     "python-Levenshtein>=0.25",
     "bibtexparser>=1.4",
   ]

   [project.optional-dependencies]
   dev = ["pytest>=8.0"]
   asksage = ["asksageclient>=1.42"]

   [build-system]
   requires = ["setuptools>=68"]
   build-backend = "setuptools.build_meta"

7. Run: git init && git add -A && git commit -m "0.1: scaffold"

ACCEPTANCE TEST:
Run: python -c "import src.agents.indexer, src.tools.llm_client; print('ok')"
Output must be exactly: ok

WHEN DONE:
Print: "Subtask 0.1 complete: scaffold created"
STOP. Do not start any other subtask.

IF STUCK:
Print "Stuck on: <one sentence>" and stop. Do not improvise file layouts.
```

✅ **Verify:** `python -c "import src.agents.indexer, src.tools.llm_client; print('ok')"` prints `ok`.

---

#### 0.2 — Configure OpenCode + Ollama + AskSage · Leslie only · XS · ~15 min

**No OC prompt — Leslie does this once.**

**Complexity:** XS (Extra Small)
**Recommended Model:** N/A (manual setup)

**Part A: Ollama Setup (for OpenCode and free local inference)**

1. Install Ollama (≥ v0.14.0) and pull the model: `ollama pull devstral-small-2:24b`
2. Confirm the server is running: `ollama serve` (in its own terminal).
3. Configure OpenCode to use Ollama. Create or edit `~/.config/opencode/opencode.json`:
   ```json
   {
     "provider": "ollama",
     "model": "devstral-small-2:24b",
     "ollama": {
       "baseUrl": "http://localhost:11434"
     }
   }
   ```

4. Launch OpenCode: `opencode`
5. Test it: ask OC to "create a file called hello.txt with the word hello in it." Confirm the file appears.

**Part B: AskSage Setup (for paid Claude model access at runtime)**

ReportOrchestra uses AskSage to access Claude models (Sonnet, Opus, Haiku) for tasks that require stronger reasoning. AskSage provides an Anthropic-compatible API endpoint via the Army GenAI infrastructure.

1. Get your AskSage API token from your account at https://chat.asksage.ai (Account Settings → API Keys)

2. Obtain the DoD certificate bundle (`full_dod_bundle.pem`) and place it in a `.certs/` directory:
   ```bash
   mkdir -p ~/.certs
   # Copy your full_dod_bundle.pem to ~/.certs/
   ```

3. Set the environment variables (add to `~/.bashrc` or `~/.zshrc`):
   ```bash
   export ASKSAGE_API_KEY="your-asksage-token-here"
   export ASKSAGE_CERT_PATH="$HOME/.certs/full_dod_bundle.pem"
   ```

4. Verify your token and certificate work:
   ```bash
   curl --cacert $ASKSAGE_CERT_PATH \
     -X POST 'https://api.genai.army.mil/server/anthropic/v1/messages' \
     -H "Authorization: Bearer $ASKSAGE_API_KEY" \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "claude-sonnet-4-5-20250929",
       "max_tokens": 50,
       "messages": [{"role": "user", "content": "Say hello"}]
     }'
   ```
   You should see a JSON response with Claude's reply.

**Available AskSage Models:**
- `claude-sonnet-4-5-20250929` — Default balanced model (AWS Bedrock Gov)
- `claude-opus-4-7-default` — Most capable (Google Vertex AI)
- `claude-haiku-4-5-20251001` — Fastest/cheapest (Google Vertex AI)

**Part C: Semantic Scholar API Key (for higher rate limits)**

The Semantic Scholar API works without a key but is rate-limited to ~100 requests per 5 minutes. An API key raises that ceiling to ~10,000 requests per 5 minutes, which matters when discovering citations across many queries.

1. Request a free key at: https://www.semanticscholar.org/product/api (takes ~1 business day to approve)

2. Once issued, add it to your shell environment (same file as AskSage vars):
   ```bash
   export S2_API_KEY="your-semantic-scholar-key-here"
   ```

3. Verify it works:
   ```bash
   curl -H "x-api-key: $S2_API_KEY" \
     "https://api.semanticscholar.org/graph/v1/paper/search?query=neural+networks&limit=1&fields=title"
   ```
   You should see a JSON response with a paper title. Without the key the same URL also works, but will hit rate limits faster during a full lit-review run.

✅ **Verify:** 
- OC successfully creates files (Ollama working)
- The curl command returns a valid JSON response (AskSage working)
- `echo $S2_API_KEY` shows your Semantic Scholar key (or empty if not yet approved — that is fine for setup; the system degrades gracefully to the public rate limit)

---

#### 0.3 — LaTeX compile wrapper · OC · XS · Devstral local · ~10 min

**Preconditions:** 0.1 done. `latexmk` installed (`which latexmk` returns a path).

**Complexity:** XS (Extra Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.0.3.
PRECONDITIONS: 0.1 is complete.
TASK: Implement a LaTeX compile wrapper and one smoke test.

DO THIS:

1. Replace src/tools/latex_compile.py with EXACTLY this code:

```python
"""LaTeX compilation wrapper using latexmk."""
from __future__ import annotations
import subprocess, sys, shutil
from pathlib import Path

def compile_pdf(tex_path) -> tuple[bool, str]:
    tex_path = Path(tex_path).resolve()
    if not tex_path.exists():
        return False, f"File not found: {tex_path}"
    if shutil.which("latexmk") is None:
        return False, "latexmk not installed"
    result = subprocess.run(
        ["latexmk", "-pdf", "-interaction=nonstopmode", "-halt-on-error",
         tex_path.name],
        cwd=str(tex_path.parent),
        capture_output=True, text=True, timeout=180,
    )
    success = result.returncode == 0 and tex_path.with_suffix(".pdf").exists()
    return success, (result.stdout + "\n" + result.stderr)[-4000:]

def main():
    if len(sys.argv) != 2:
        print("Usage: python -m src.tools.latex_compile <file.tex>")
        sys.exit(2)
    ok, log = compile_pdf(sys.argv[1])
    print("OK" if ok else "FAIL")
    print(log[-2000:])
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
```

2. Create tests/fixtures/hello.tex containing exactly:

   \documentclass{article}
   \begin{document}
   Hello, world.
   \end{document}

3. Create tests/test_latex_compile.py:

```python
import shutil, pytest
from pathlib import Path
from src.tools.latex_compile import compile_pdf

FIX = Path(__file__).parent / "fixtures" / "hello.tex"

@pytest.mark.skipif(shutil.which("latexmk") is None,
                    reason="latexmk not installed")
def test_hello_compiles():
    ok, log = compile_pdf(FIX)
    assert ok, log
```

4. Run: pytest tests/test_latex_compile.py -v

5. Commit: git add -A && git commit -m "0.3: latex_compile + smoke test"

ACCEPTANCE TEST:
pytest output contains "1 passed" or "1 skipped". No "failed" or "error".

WHEN DONE:
Print: "Subtask 0.3 complete: latex_compile wrapper verified"
STOP.

IF STUCK:
If latexmk is missing, print:
"Stuck: latexmk not installed. Leslie should install texlive (e.g.,
brew install --cask mactex on macOS or apt install texlive-full on
Ubuntu) and rerun this subtask."
Otherwise: print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_latex_compile.py -v` shows 1 passed (or 1 skipped if latexmk is missing — install it first).

---

#### 0.4 — Config + unified LLM client · OC · S · Devstral local · ~20 min

**Preconditions:** 0.1 and 0.3 done.

**Complexity:** S (Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §3 and §6.0.4.
PRECONDITIONS: 0.1 and 0.3 are complete.
TASK: Create config/config.yaml and implement src/tools/llm_client.py
that dispatches to either Ollama or AskSage (for Claude models) based
on a "provider:model" string.

DO THIS:

1. Replace config/config.yaml with EXACTLY:

```yaml
models:
  indexer:             ollama:devstral-small-2:24b
  outline:             asksage:claude-sonnet-4-5-20250929
  lit_search:          ollama:devstral-small-2:24b
  lit_synth:           asksage:claude-sonnet-4-5-20250929
  diagram:             ollama:devstral-small-2:24b
  section_writer:      ollama:devstral-small-2:24b
  refinement_reviewer: asksage:claude-haiku-4-5-20251001
  refinement_revisor:  asksage:claude-sonnet-4-5-20250929
paths:
  inputs:  ./inputs
  work:    ./work
  outputs: ./outputs
refinement:
  max_iterations: 3
  accept_on_tie:  true
citation:
  cutoff_date: "2026-04-01"
  semantic_scholar_rate_limit: 1.0
  min_citations: 25
ollama:
  base_url: "http://localhost:11434"
asksage:
  base_url: "https://api.genai.army.mil/server/anthropic"
```

2. Replace src/tools/llm_client.py with EXACTLY:

```python
"""Unified LLM client. Dispatches by 'provider:model' prefix.

Supports:
- ollama: Local Ollama models (free)
- asksage: Claude models via AskSage's Anthropic-compatible API
"""
from __future__ import annotations
import yaml, requests, os, sys, time
from pathlib import Path
from functools import lru_cache

CONFIG_PATH = Path(__file__).resolve().parents[2] / "config" / "config.yaml"
PROMPTS_DIR = Path(__file__).resolve().parents[1] / "prompts"

@lru_cache(maxsize=1)
def load_config() -> dict:
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)

def resolve_model(role: str) -> str:
    cfg = load_config()
    if role not in cfg["models"]:
        raise KeyError(f"Role '{role}' not in config.yaml")
    return cfg["models"][role]

def call_llm(role: str, system: str, user: str, *,
             anti_leakage: bool = False, temperature: float = 0.2,
             max_tokens: int = 4096) -> str:
    model_id = resolve_model(role)
    provider, model = model_id.split(":", 1)
    if anti_leakage:
        anti = PROMPTS_DIR / "00_anti_leakage.txt"
        if anti.exists():
            system = anti.read_text() + "\n\n" + system
    if provider == "ollama":
        return _call_ollama(model, system, user, temperature, max_tokens)
    if provider == "asksage":
        return _call_asksage(model, system, user, temperature, max_tokens)
    raise ValueError(f"Unknown provider: {provider}")

def _call_ollama(model, system, user, temperature, max_tokens):
    url = load_config()["ollama"]["base_url"] + "/api/chat"
    r = requests.post(url, json={
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "stream": False,
        "options": {"temperature": temperature, "num_predict": max_tokens},
    }, timeout=600)
    r.raise_for_status()
    return r.json()["message"]["content"]

def _call_asksage(model, system, user, temperature, max_tokens):
    """Call Claude models via AskSage's Anthropic-compatible endpoint.

    AskSage provides an Anthropic Messages API compatible endpoint at:
    https://api.genai.army.mil/server/anthropic/v1/messages

    Authentication: Bearer token via ASKSAGE_API_KEY environment variable.
    Certificate: DoD cert bundle via ASKSAGE_CERT_PATH environment variable.
    
    Includes retry logic for transient server errors (502, 503, 504).
    """
    cfg = load_config()
    base_url = cfg.get("asksage", {}).get("base_url", 
                "https://api.genai.army.mil/server/anthropic")
    api_key = os.environ.get("ASKSAGE_API_KEY", "")
    cert_path = os.environ.get("ASKSAGE_CERT_PATH", "")

    if not api_key:
        raise ValueError("ASKSAGE_API_KEY environment variable not set")
    if not cert_path:
        raise ValueError("ASKSAGE_CERT_PATH environment variable not set "
                         "(path to DoD certificate bundle)")
    if not Path(cert_path).exists():
        raise ValueError(f"Certificate file not found: {cert_path}")

    url = f"{base_url}/v1/messages"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "system": system,
        "messages": [{"role": "user", "content": user}],
    }
    
    # Retry logic for transient server errors
    max_retries = 3
    for attempt in range(max_retries):
        r = requests.post(url, headers=headers, json=payload, 
                          verify=cert_path, timeout=600)
        
        if r.status_code in (502, 503, 504):
            if attempt < max_retries - 1:
                wait_time = 2 ** (attempt + 1)
                print(f"  [asksage] Server error ({r.status_code}), "
                      f"retrying in {wait_time}s... "
                      f"(attempt {attempt + 1}/{max_retries})",
                      file=sys.stderr, flush=True)
                time.sleep(wait_time)
                continue
        
        r.raise_for_status()
        resp = r.json()
        content = resp.get("content", [])
        return "".join(block.get("text", "") for block in content 
                       if block.get("type") == "text")
    
    # If we exhausted retries, raise the last error
    r.raise_for_status()
```

NOTE: Two environment variables must be set for paid Claude model 
calls via AskSage:
- ASKSAGE_API_KEY: Your API key from AskSage account settings
- ASKSAGE_CERT_PATH: Path to DoD certificate bundle (full_dod_bundle.pem)

When running OpenCode itself on Ollama, these are only needed for
the ReportOrchestra system's runtime calls.

3. Create tests/test_llm_client.py:

```python
import pytest, requests
from src.tools.llm_client import resolve_model, call_llm, load_config

def _ollama_up():
    try:
        url = load_config()["ollama"]["base_url"] + "/api/tags"
        return requests.get(url, timeout=2).status_code == 200
    except Exception:
        return False

def test_resolve_model():
    assert resolve_model("indexer").startswith("ollama:")
    assert resolve_model("outline").startswith("asksage:")

@pytest.mark.skipif(not _ollama_up(), reason="ollama not running")
def test_ollama_smoke():
    out = call_llm("indexer", "Be brief. Reply with one word.",
                   "Say only the word HI in capital letters.",
                   max_tokens=20)
    assert "HI" in out.upper()
```

4. Run: pytest tests/test_llm_client.py -v

5. Commit: git add -A && git commit -m "0.4: llm_client + config (Ollama + AskSage)"

ACCEPTANCE TEST:
- test_resolve_model passes.
- test_ollama_smoke passes if Ollama is running (else skipped).

WHEN DONE:
Print: "Subtask 0.4 complete: llm_client + config"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_llm_client.py -v` shows 2 passed (or 1 passed + 1 skipped).

---

### Phase 1 — Single-pass baseline

#### 1.1 — Input loader · OC · S · Devstral local · ~25 min

**Preconditions:** 0.x done. Inputs in place under `inputs/`.

**Complexity:** S (Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.1.1. Phase 0 is complete.
TASK: Implement input loading from PDFs and Markdown.

DO THIS:

1. Replace src/tools/pdf_extract.py with EXACTLY:

```python
"""Extract text from PDFs using PyMuPDF."""
from pathlib import Path
import fitz  # PyMuPDF

def extract_text(pdf_path) -> str:
    doc = fitz.open(str(pdf_path))
    try:
        return "\n\n".join(page.get_text() for page in doc)
    finally:
        doc.close()
```

2. Replace src/agents/indexer.py with EXACTLY:

```python
"""Input loading and (later) notebook indexing."""
from __future__ import annotations
from pathlib import Path
from src.tools.pdf_extract import extract_text

def load_inputs(inputs_dir) -> dict:
    d = Path(inputs_dir)
    def _read(p):
        return p.read_text() if p.exists() else ""
    def _pdf(p):
        return extract_text(p) if p.exists() else ""

    papers = []
    papers_dir = d / "papers"
    if papers_dir.exists():
        for p in sorted(papers_dir.glob("*.pdf")):
            papers.append({"filename": p.name, "text": extract_text(p)})

    notes = ""
    notes_dir = d / "notes"
    if notes_dir.exists():
        for p in sorted(notes_dir.glob("*.md")):
            notes += f"\n\n# {p.name}\n\n" + p.read_text()

    examples = []
    ex_dir = d / "examples"
    if ex_dir.exists():
        for p in sorted(ex_dir.glob("*")):
            if p.suffix in {".tex", ".md", ".txt"}:
                examples.append(p.read_text())
            elif p.suffix == ".pdf":
                examples.append(extract_text(p))

    return {
        "notebook":             _read(d / "notebook.md"),
        "proposal":             _pdf(d / "proposal.pdf"),
        "last_progress_report": _pdf(d / "last_progress_report.pdf"),
        "papers":               papers,
        "notes":                notes,
        "template":             _read(d / "template.tex"),
        "examples":             examples,
    }
```

3. Create tests/fixtures/inputs/notebook.md with content:
   # Notebook
   Day 1 results: accuracy = 0.91

4. Create tests/fixtures/inputs/template.tex with content:
   \documentclass{article}\begin{document}\end{document}

5. Create tests/test_indexer_load.py:

```python
from src.agents.indexer import load_inputs
from pathlib import Path

FIX = Path(__file__).parent / "fixtures" / "inputs"

def test_load_inputs_basic():
    data = load_inputs(FIX)
    assert "Day 1 results" in data["notebook"]
    assert "documentclass" in data["template"]
    assert data["papers"] == []
    assert data["proposal"] == ""
```

6. Run: pytest tests/test_indexer_load.py -v

7. Commit: git add -A && git commit -m "1.1: input loader"

ACCEPTANCE TEST: pytest shows 1 passed.

WHEN DONE:
Print: "Subtask 1.1 complete: input loader"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_indexer_load.py -v` shows 1 passed.

---

#### 1.2 — Single-prompt baseline runner · OC · M · Devstral local · ~30 min

This subtask produces the throw-away end-to-end MVP. OC writes the runner; the runtime LLM call uses Sonnet (one-shot, ~$0.50–1.00 per invocation).

**Preconditions:** 1.1 done. Real inputs (or a sanitized subset) placed in `inputs/`.

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) for OC — Free; Runtime uses Sonnet (~$0.50-1.00)

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.1.2.
PRECONDITIONS: 1.1 is complete.
TASK: Implement a single-prompt baseline that produces a complete
LaTeX Final Report end-to-end. We will replace it later, but it must
work now.

DO THIS:

1. Save src/prompts/01_baseline.txt with EXACTLY this text (literal,
   between the markers; do not include the markers):

---begin---
You are drafting a US government technical Final Project Report.
Use ONLY the materials in this session. Do not invent results,
numbers, or citations. The output must be a complete LaTeX
document that compiles with latexmk. Use the provided template's
document class and section structure.

Section structure (mandatory):
1 INTRODUCTION
  1.1 Objective
  1.2 Background
2 TECHNICAL APPROACH
  2.1 Background
  2.2 Data and Data Preparation
  2.3 Metrics
3 RESULTS / TECHNICAL PROGRESS
4 CONCLUSIONS
  4.1 Progress and Accomplishments
  4.2 Summary
  4.3 Transitions
ACKNOWLEDGEMENTS
REFERENCES
APPENDIX

Output ONLY the LaTeX source between \documentclass and the final
\end{document}. No markdown fences, no commentary.
---end---

2. Replace src/cli.py with EXACTLY:

```python
"""Command-line entrypoint for ReportOrchestra."""
from __future__ import annotations
import argparse
from pathlib import Path
from src.agents.indexer import load_inputs
from src.tools.llm_client import call_llm
from src.tools.latex_compile import compile_pdf

PROMPT_PATH = Path(__file__).parent / "prompts" / "01_baseline.txt"

def baseline_run(inputs_dir="inputs", out_dir="outputs") -> int:
    data = load_inputs(inputs_dir)
    system = PROMPT_PATH.read_text()

    parts = [
        f"=== TEMPLATE ===\n{data['template']}",
        f"=== PROPOSAL ===\n{data['proposal'][:30000]}",
        f"=== LAST PROGRESS REPORT ===\n{data['last_progress_report'][:30000]}",
        f"=== LAB NOTEBOOK ===\n{data['notebook'][:120000]}",
        f"=== ADDITIONAL NOTES ===\n{data['notes'][:20000]}",
    ]
    if data["examples"]:
        parts.append(f"=== EXAMPLE FINAL REPORT (style only) ===\n{data['examples'][0][:30000]}")
    user = "\n\n".join(parts)

    tex = call_llm("outline", system, user,
                   anti_leakage=False, max_tokens=16000)

    outp = Path(out_dir)
    outp.mkdir(parents=True, exist_ok=True)
    tex_file = outp / "report_v0.tex"
    tex_file.write_text(tex)

    ok, log = compile_pdf(tex_file)
    if not ok:
        print("First compile failed. Retrying with log feedback...")
        retry_user = (
            f"The following LaTeX failed to compile. Fix it and "
            f"return the full corrected document.\n\n"
            f"=== ERROR LOG ===\n{log[-3000:]}\n\n"
            f"=== LATEX SOURCE ===\n{tex}"
        )
        tex = call_llm("outline", system, retry_user, max_tokens=16000)
        tex_file.write_text(tex)
        ok, log = compile_pdf(tex_file)

    print("OK" if ok else "FAIL")
    if not ok:
        print(log[-1500:])
    return 0 if ok else 1

def main():
    p = argparse.ArgumentParser()
    p.add_argument("command", choices=["baseline"])
    p.add_argument("--inputs", default="inputs")
    p.add_argument("--out", default="outputs")
    args = p.parse_args()
    if args.command == "baseline":
        raise SystemExit(baseline_run(args.inputs, args.out))

if __name__ == "__main__":
    main()
```

3. Add tests/test_cli_smoke.py:

```python
import src.cli as cli
def test_main_callable():
    assert callable(cli.main)
```

4. Run: pytest tests/ -q

5. Commit: git add -A && git commit -m "1.2: single-prompt baseline"

ACCEPTANCE TEST:
- All pytest tests pass.
- python -m src.cli baseline --help does not crash.

WHEN DONE:
Print: "Subtask 1.2 complete: baseline runner ready. Leslie:
populate inputs/, ensure ASKSAGE_API_KEY is set, then run
`python -m src.cli baseline`."
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** Leslie sets `ASKSAGE_API_KEY`, drops real inputs into `inputs/`, runs `python -m src.cli baseline`, gets `outputs/report_v0.pdf`. Quality will be poor — that's fine.

---

### Phase 2 — Outline + Section Writer split

#### 2.1 — Anti-leakage prompt file · OC · XS · Devstral local · ~3 min

**Complexity:** XS (Extra Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

```text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.2.1.
TASK: Save the anti-leakage prompt to a file.

DO THIS:

1. Create src/prompts/00_anti_leakage.txt with the EXACT text
   between ---begin--- and ---end--- below (do not include the markers):

---begin---
STRICT KNOWLEDGE ISOLATION (mandatory)

Write this report as if you have no prior knowledge of the project,
methodology, experiments, or results. Construct the document
exclusively from the materials provided in the current session
(notebook, proposal, last progress report, papers, notes, template,
examples, and verified bibliography). Treat these inputs as the only
source of truth.

You MUST NOT:
- Retrieve facts from your training data about the project's domain
  beyond standard scientific terminology.
- Invent numerical results, dates, baselines, datasets, or metrics.
- Add citations that do not appear in the verified bibliography
  provided in this session.
- Insert author names, affiliations, or sponsor identifiers that
  are not explicitly in the inputs.
- Embellish or extrapolate beyond what the inputs support.

If a section bullet has no supporting material, write the literal
token [CITATION NEEDED] (or [DATA NEEDED] for missing numbers) so
a human reviewer can resolve it.

Allowed sources:
- The materials explicitly provided in this session.
- Logical reasoning derived from those materials.
- Standard scientific and engineering vocabulary.

This constraint is strict and overrides any other instruction.
---end---

2. Commit: git add -A && git commit -m "2.1: anti-leakage prompt"

ACCEPTANCE TEST:
The file exists and is non-empty.

WHEN DONE:
Print: "Subtask 2.1 complete: anti-leakage prompt saved"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
```

✅ **Verify:** `cat src/prompts/00_anti_leakage.txt` shows the prompt.

---

#### 2.2 — Outline Agent · OC · M · Sonnet at runtime · ~30 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) for OC — Free; Runtime uses Sonnet

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.2.2, §1 (architecture diagram), and note that
each section_id produced here maps to an NRL chapter/section heading per
config/nrl_template_mapping.yaml. Do NOT change the section_id values —
the Assembler relies on them to locate PLACEHOLDER blocks in the template.
PRECONDITIONS: 0.x, 1.x, 2.1 complete.
TASK: Implement the Outline Agent that produces a JSON plan and saves
it to work/02_outline/outline.json.

DO THIS:

1. Save src/prompts/02_outline.txt with EXACTLY the text between
   ---begin--- and ---end--- (do not include the markers):

---begin---
You are a senior researcher planning a US government Final Project
Report (DARPA/DoE/NSF style). Output a single VALID JSON object —
nothing else, no markdown fences, no prose.

Use only the provided materials. Do not invent results.

Schema (every key required, in this exact order):
{
  "section_plan": [
    {
      "section_id": "1.1",
      "title": "Objective",
      "content_bullets": ["bullet 1", "bullet 2"],
      "notebook_topics": ["topic 1", "topic 2"],
      "citation_hints": ["paper or report introducing X",
                         "Author (Title) for dataset Y"]
    }
  ],
  "lit_search_strategy": {
    "introduction": {
      "macro_queries": ["q1", "q2", "q3"],
      "must_cite_anchors": ["concept 1", "concept 2"]
    },
    "background": {
      "clusters": [
        {"name": "cluster name",
         "queries": ["q1", "q2"],
         "expected_count": 5}
      ]
    }
  },
  "diagram_plan": [
    {
      "diagram_id": "fig_system_architecture",
      "title": "System Architecture",
      "kind": "tikz",
      "intent": "one-sentence description",
      "section_anchor": "2.1"
    }
  ]
}

Rules:
- section_plan MUST contain entries with these section_ids:
  "1.1","1.2","2.1","2.2","2.3","3","4.1","4.2","4.3".
  These IDs map to NRL chapters/sections per config/nrl_template_mapping.yaml:
  1.1 → INTRODUCTION chapter, 1.2 → BACKGROUND AND RELATED WORK chapter,
  2.1 → Problem Formulation section, 2.2 → Approach section,
  2.3 → METHODOLOGY chapter, 3 → RESULTS chapter, 4.1 → DISCUSSION chapter,
  4.2 → SUMMARY AND CONCLUSIONS chapter, 4.3 → Transitions subsection.
  Do NOT alter these section_ids; they are consumed verbatim by the Assembler.
- Every dataset, metric, baseline, or external tool mentioned in the
  notebook MUST appear as a citation_hint somewhere.
- 2 to 4 entries in diagram_plan. Each kind is "tikz" or "mermaid".
  Conceptual only (architecture, flow, block) — no data plots.
- Output JSON only.
---end---

2. Replace src/agents/outline_agent.py with EXACTLY:

```python
"""Outline Agent: produces a JSON plan from inputs."""
from __future__ import annotations
import json
from pathlib import Path
from src.tools.llm_client import call_llm
from src.agents.indexer import load_inputs

PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "02_outline.txt"
REQUIRED_SECTION_IDS = {"1.1","1.2","2.1","2.2","2.3","3","4.1","4.2","4.3"}

def generate_outline(inputs_dir="inputs",
                     out_path="work/02_outline/outline.json") -> dict:
    data = load_inputs(inputs_dir)
    system = PROMPT_PATH.read_text()
    user_parts = [
        f"=== PROPOSAL ===\n{data['proposal'][:30000]}",
        f"=== LAST PROGRESS REPORT ===\n{data['last_progress_report'][:30000]}",
        f"=== LAB NOTEBOOK ===\n{data['notebook'][:200000]}",
        f"=== NOTES ===\n{data['notes'][:20000]}",
        f"=== TEMPLATE ===\n{data['template']}",
    ]
    user = "\n\n".join(user_parts)
    text = call_llm("outline", system, user,
                    temperature=0.1, max_tokens=8000)
    outline = _parse_with_retry(text, system, user)
    _validate(outline)
    outp = Path(out_path)
    outp.parent.mkdir(parents=True, exist_ok=True)
    outp.write_text(json.dumps(outline, indent=2))
    return outline

def _parse_with_retry(text, system, user):
    try:
        return json.loads(_strip_fences(text))
    except json.JSONDecodeError as e:
        retry_user = (user
            + f"\n\n=== PREVIOUS ATTEMPT FAILED PARSING: {e} ===\n"
            + "Re-emit ONLY the corrected JSON object. No prose.")
        text2 = call_llm("outline", system, retry_user,
                         temperature=0.0, max_tokens=8000)
        return json.loads(_strip_fences(text2))

def _strip_fences(s: str) -> str:
    s = s.strip()
    if s.startswith("```"):
        s = s.split("\n", 1)[1] if "\n" in s else s[3:]
        if s.endswith("```"):
            s = s[:-3]
    return s.strip()

def _validate(outline: dict):
    ids = {sec["section_id"] for sec in outline.get("section_plan", [])}
    missing = REQUIRED_SECTION_IDS - ids
    if missing:
        raise ValueError(f"Outline missing required section_ids: {missing}")
    if not outline.get("diagram_plan"):
        raise ValueError("Outline has no diagram_plan entries")
```

3. Create tests/fixtures/outline_ok.json with a minimal valid outline
   (all 9 section_ids, 2 diagrams, basic lit_search_strategy).
   Create tests/fixtures/outline_bad.json that's missing section "3".

4. Create tests/test_outline_validate.py:

```python
import json, pytest
from pathlib import Path
from src.agents.outline_agent import _validate

FIX = Path(__file__).parent / "fixtures"

def test_valid_outline():
    _validate(json.loads((FIX / "outline_ok.json").read_text()))

def test_invalid_outline_raises():
    with pytest.raises(ValueError):
        _validate(json.loads((FIX / "outline_bad.json").read_text()))
```

5. Run: pytest tests/test_outline_validate.py -v

6. Commit: git add -A && git commit -m "2.2: outline agent"

ACCEPTANCE TEST: pytest shows 2 passed.

WHEN DONE:
Print: "Subtask 2.2 complete: outline agent (validation tested,
runtime call deferred to Leslie)."
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_outline_validate.py -v` shows 2 passed.

---

#### 2.3 — Section Writer · OC · M · Devstral local at runtime · ~30 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.2.3.
PRECONDITIONS: 2.1 and 2.2 complete.
TASK: Implement the Section Writer that drafts ONE section at a time.

DO THIS:

1. Save src/prompts/05_section_writer.txt with EXACTLY the text
   between ---begin--- and ---end--- (do not include the markers):

---begin---
You are drafting one section of a US government Final Project
Report formatted for the NRL (Naval Research Laboratory) report
template. Use ONLY the materials provided. Do not invent numbers,
results, or citations.

Section to draft:
- ID: {section_id}
- Title: {title}
- Content bullets to cover (every bullet must be addressed):
{content_bullets}

Available materials:

NOTEBOOK_EXCERPTS (chunks selected as relevant to this section):
{notebook_excerpts}

VERIFIED_BIB (these are the ONLY citations you may use):
{bib_keys_and_titles}

DIAGRAMS_AVAILABLE (refer with \ref{<label>}):
{diagram_labels}

Output rules:
- Output LaTeX only. No commentary. No markdown fences.
- Do NOT emit \chapter{{}} commands. The NRL template already defines
  all chapter headings; emitting one will corrupt the document structure.
- The highest heading level you may use is \section{{}}. Use
  \subsection{{}} and \subsubsection{{}} as needed below that.
- If this section maps to a chapter-level slot (section_ids 1.1, 1.2,
  2.3, 3, 4.1, 4.2, 4.3), begin with \section{{}} subsections or prose
  directly — do not restate the chapter title.
- If this section maps to a section-level slot (section_ids 2.1, 2.2),
  begin with \subsection{{}} or prose directly.
- Use \cite{{key}} only with keys in VERIFIED_BIB.
- Use \ref{{label}} only with labels in DIAGRAMS_AVAILABLE.
- If a bullet has no support, write [CITATION NEEDED] or
  [DATA NEEDED] inline. Do not skip the bullet.
- Aim for 200–500 words unless bullets clearly demand more.
---end---

NOTE: The doubled braces {{}} are Python str.format escapes; they
become single braces at runtime (e.g., \section{{Title}} → \section{Title}).

2. Replace src/agents/section_writer.py with EXACTLY:

```python
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
```

3. Create tests/test_section_writer_smoke.py:

```python
from unittest.mock import patch
from src.agents.section_writer import write_section

def test_format_substitutes_correctly():
    spec = {"section_id": "2.3",
            "title": "Metrics",
            "content_bullets": ["accuracy", "f1"]}
    bib = [{"key": "Smith2020", "title": "Foo"}]
    captured = {}
    def fake_call(role, system, user, **kw):
        captured["user"] = user
        # Section writer must use \section or lower — never \chapter
        return "\\section{Metrics}\nAccuracy and F1 are reported."
    with patch("src.agents.section_writer.call_llm", side_effect=fake_call):
        out = write_section(spec, "Some excerpt.", bib, ["fig_a"])
    assert "Metrics" in out
    assert "Smith2020" in captured["user"]
    assert "accuracy" in captured["user"]
    assert "fig:fig_a" in captured["user"]
    # The prompt must forbid \chapter{} — verify the instruction is present
    assert "chapter" in captured["user"].lower()
    assert "Do NOT emit" in captured["user"] or "NOT emit" in captured["user"]
    # Section writer output must not contain \chapter{}
    assert "\\chapter" not in out
```

4. Run: pytest tests/test_section_writer_smoke.py -v

5. Commit: git add -A && git commit -m "2.3: section writer"

ACCEPTANCE TEST: pytest shows 1 passed.

WHEN DONE:
Print: "Subtask 2.3 complete: section writer"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_section_writer_smoke.py -v` shows 1 passed.

---

### Phase 3 — Notebook indexer

#### 3.1 — Chunker · OC · M · Devstral local · ~25 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.3.1.
TASK: Add a notebook chunker that splits markdown by headers, with a
soft size cap.

DO THIS:

1. Append to src/agents/indexer.py (DO NOT remove existing code):

```python
import tiktoken

_ENC = tiktoken.get_encoding("cl100k_base")
def _tok(s: str) -> int:
    return len(_ENC.encode(s))

def chunk_notebook(text: str, max_tokens: int = 2000) -> list[dict]:
    """Split markdown by headers, then by paragraph if oversize."""
    lines = text.splitlines()
    chunks, cur, header_path = [], [], []
    def flush():
        if cur:
            chunks.append({"header_path": list(header_path),
                           "text": "\n".join(cur).strip()})
    for ln in lines:
        if ln.startswith("#"):
            flush()
            cur = []
            level = len(ln) - len(ln.lstrip("#"))
            header_path = header_path[:level-1] + [ln.strip()]
            cur.append(ln)
        else:
            cur.append(ln)
    flush()

    refined = []
    for c in chunks:
        if _tok(c["text"]) <= max_tokens:
            refined.append(c)
        else:
            paras = c["text"].split("\n\n")
            buf = []
            for p in paras:
                buf.append(p)
                if _tok("\n\n".join(buf)) > max_tokens and len(buf) > 1:
                    refined.append({"header_path": c["header_path"],
                                    "text": "\n\n".join(buf[:-1])})
                    buf = [p]
            if buf:
                refined.append({"header_path": c["header_path"],
                                "text": "\n\n".join(buf)})

    for i, c in enumerate(refined):
        c["id"] = f"chunk_{i:04d}"
        c["token_count"] = _tok(c["text"])
    return refined
```

2. Create tests/test_chunker.py:

```python
from src.agents.indexer import chunk_notebook

def test_simple_split():
    md = "# A\nalpha\n\n# B\nbeta\n\n## B.1\nbeta one"
    chunks = chunk_notebook(md, max_tokens=10000)
    assert len(chunks) == 3
    assert chunks[0]["header_path"] == ["# A"]
    assert "alpha" in chunks[0]["text"]
    assert chunks[2]["header_path"] == ["# B", "## B.1"]

def test_oversize_split():
    big = "# Big\n\n" + "\n\n".join(["para " * 200 for _ in range(5)])
    chunks = chunk_notebook(big, max_tokens=300)
    assert len(chunks) > 1
```

3. Run: pytest tests/test_chunker.py -v

4. Commit: git add -A && git commit -m "3.1: notebook chunker"

ACCEPTANCE TEST: pytest shows 2 passed.

WHEN DONE:
Print: "Subtask 3.1 complete: chunker"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_chunker.py -v` shows 2 passed.

---

#### 3.2 — Topical summary per chunk · OC · S · Devstral local at runtime · ~20 min

**Complexity:** S (Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.3.2.
PRECONDITIONS: 3.1 done.
TASK: Run a per-chunk topical summary and save the index.

DO THIS:

1. Save src/prompts/03a_chunk_summary.txt with EXACTLY the text
   between ---begin--- and ---end--- (do not include markers):

---begin---
You produce one-line topical labels for notebook chunks.

Notebook chunk under headers: {header_path}
---
{chunk_text}
---

Output exactly one line: a comma-separated list of 3 to 8 topical
keywords covering datasets, methods, metrics, results, dates, or
external tools mentioned. No prose, no JSON, no markdown — just
the keywords on a single line.
---end---

2. Append to src/agents/indexer.py:

```python
import json
from tqdm import tqdm
from src.tools.llm_client import call_llm

_SUMMARY_PATH = Path(__file__).parent.parent / "prompts" / "03a_chunk_summary.txt"

def build_index(notebook_text: str,
                out_path="work/01_index/notebook_index.json") -> list[dict]:
    chunks = chunk_notebook(notebook_text)
    template = _SUMMARY_PATH.read_text() if _SUMMARY_PATH.exists() else ""
    for c in tqdm(chunks, desc="indexing"):
        user = template.format(
            header_path=" > ".join(c["header_path"]),
            chunk_text=c["text"][:6000])
        kws = call_llm("indexer",
                       "Be brief. One line of comma-separated keywords.",
                       user, temperature=0.0, max_tokens=80)
        c["keywords"] = [k.strip().lower()
                         for k in kws.split(",") if k.strip()]
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Path(out_path).write_text(json.dumps(chunks, indent=2))
    return chunks
```

3. Create tests/test_index_offline.py:

```python
from unittest.mock import patch
from pathlib import Path
from src.agents.indexer import build_index

def test_build_index_writes_keywords(tmp_path):
    md = "# A\nalpha\n\n# B\nbeta"
    out = tmp_path / "idx.json"
    with patch("src.agents.indexer.call_llm",
               return_value="alpha, beta, gamma"):
        chunks = build_index(md, out_path=out)
    assert all("keywords" in c for c in chunks)
    assert chunks[0]["keywords"] == ["alpha", "beta", "gamma"]
    assert out.exists()
```

4. Run: pytest tests/test_index_offline.py -v

5. Commit: git add -A && git commit -m "3.2: per-chunk topical summary"

ACCEPTANCE TEST: pytest shows 1 passed.

WHEN DONE:
Print: "Subtask 3.2 complete: chunk summarizer"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_index_offline.py -v` shows 1 passed.

---

#### 3.3 — Retrieval · OC · S · No LLM · ~15 min

**Complexity:** S (Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free (no LLM calls at runtime)

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.3.3.
PRECONDITIONS: 3.2 done.
TASK: Add keyword-overlap retrieval over the indexed chunks.

DO THIS:

1. Append to src/agents/indexer.py:

```python
def retrieve(topics: list[str], index_path="work/01_index/notebook_index.json",
             k: int = 8) -> list[dict]:
    """Return top-k chunks ranked by token-overlap with topics."""
    chunks = json.loads(Path(index_path).read_text())
    wanted = {t.lower().strip() for t in topics if t.strip()}
    def score(c):
        kws = set(c.get("keywords", []))
        hp_tokens = set(" ".join(c.get("header_path", [])).lower().split())
        text_tokens = set(c["text"].lower().split())
        return (3 * len(kws & wanted)
                + 2 * len(hp_tokens & wanted)
                + 1 * len(text_tokens & wanted))
    ranked = sorted(chunks, key=score, reverse=True)
    return [c for c in ranked[:k] if score(c) > 0]
```

2. Create tests/test_retrieve.py:

```python
import json
from pathlib import Path
from src.agents.indexer import retrieve

def test_retrieve_ranks_by_overlap(tmp_path):
    idx = tmp_path / "idx.json"
    chunks = [
        {"id": "c0", "header_path": ["# Metrics"],
         "keywords": ["accuracy", "f1"], "text": "scores accuracy f1"},
        {"id": "c1", "header_path": ["# Misc"],
         "keywords": ["budget"], "text": "unrelated"},
        {"id": "c2", "header_path": ["# Data"],
         "keywords": ["accuracy"], "text": "data prep"},
    ]
    idx.write_text(json.dumps(chunks))
    out = retrieve(["accuracy", "metric"], index_path=idx, k=5)
    assert out[0]["id"] == "c0"
    assert "c1" not in [c["id"] for c in out]
```

3. Run: pytest tests/test_retrieve.py -v

4. Commit: git add -A && git commit -m "3.3: keyword retrieval"

ACCEPTANCE TEST: pytest shows 1 passed.

WHEN DONE:
Print: "Subtask 3.3 complete: retrieval"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_retrieve.py -v` shows 1 passed.

---

### Phase 4 — Lit Review Agent

#### 4.1 — Semantic Scholar + DTIC discovery · OC · M · No LLM · ~30 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free (no LLM calls)

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.4.1.
TASK: Implement candidate-paper discovery using Semantic Scholar
(and a stub for DTIC). NO LLM CALLS in this subtask — just HTTP.

DO THIS:

1. Replace src/tools/semantic_scholar.py with EXACTLY:

```python
"""Thin Semantic Scholar API wrapper with retry logic for rate limits."""
from __future__ import annotations
import os
import sys
import time
import requests

BASE = "https://api.semanticscholar.org/graph/v1"
_LAST = [0.0]
FIELDS = "title,authors,year,abstract,externalIds,venue,citationCount"

# Retry configuration
MAX_RETRIES = 3
BACKOFF_BASE = 2  # seconds: 2, 4, 8


def _auth_headers() -> dict:
    """Return the x-api-key header if S2_API_KEY is set in the environment.

    Without a key the public tier allows ~100 requests/5 min.
    With a key the authenticated tier allows ~10,000 requests/5 min.
    Obtain a free key at: https://www.semanticscholar.org/product/api
    """
    key = os.environ.get("S2_API_KEY", "")
    return {"x-api-key": key} if key else {}


def _throttle(rate=1.0):
    gap = 1.0 / rate
    wait = gap - (time.time() - _LAST[0])
    if wait > 0:
        time.sleep(wait)
    _LAST[0] = time.time()

def _request_with_retry(method: str, url: str, **kwargs) -> requests.Response:
    """Make HTTP request with exponential backoff retry on 429 errors."""
    last_exception = None
    for attempt in range(MAX_RETRIES + 1):
        _throttle()
        try:
            r = requests.request(method, url, **kwargs)
            if r.status_code in (429, 502, 503, 504):
                if attempt < MAX_RETRIES:
                    wait_time = BACKOFF_BASE * (2 ** attempt)
                    print(f"  [semantic_scholar] Server returned {r.status_code}, "
                          f"retrying in {wait_time}s... "
                          f"(attempt {attempt + 1}/{MAX_RETRIES})",
                          file=sys.stderr, flush=True)
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"  [semantic_scholar] Server returned {r.status_code}, "
                          f"max retries ({MAX_RETRIES}) exhausted.",
                          file=sys.stderr, flush=True)
            r.raise_for_status()
            return r
        except requests.exceptions.HTTPError as e:
            if e.response is not None and e.response.status_code == 429:
                last_exception = e
                continue
            raise
        except requests.exceptions.RequestException as e:
            last_exception = e
            if attempt < MAX_RETRIES:
                wait_time = BACKOFF_BASE * (2 ** attempt)
                print(f"  [semantic_scholar] Request failed ({e}), "
                      f"retrying in {wait_time}s... "
                      f"(attempt {attempt + 1}/{MAX_RETRIES})",
                      file=sys.stderr, flush=True)
                time.sleep(wait_time)
            else:
                raise
    # If we exhausted retries due to 429, raise the last exception
    if last_exception:
        raise last_exception
    raise RuntimeError("Unexpected retry loop exit")

def search(query: str, limit: int = 10) -> list[dict]:
    r = _request_with_retry(
        "GET",
        f"{BASE}/paper/search",
        params={"query": query, "limit": limit, "fields": FIELDS},
        headers=_auth_headers(),
        timeout=30,
    )
    return r.json().get("data", [])

def get_paper(paper_id: str) -> dict:
    r = _request_with_retry(
        "GET",
        f"{BASE}/paper/{paper_id}",
        params={"fields": FIELDS},
        headers=_auth_headers(),
        timeout=30,
    )
    return r.json()
```

2. Replace src/tools/dtic_search.py with EXACTLY (stub):

```python
"""DTIC search stub. Real implementation deferred to v2."""
def search(query: str, limit: int = 10) -> list[dict]:
    return []
```

3. Replace src/agents/lit_review_agent.py with EXACTLY:

```python
"""Lit Review Agent: discovery + verification + drafting."""
from __future__ import annotations
import json
from pathlib import Path
from src.tools import semantic_scholar as ss
from src.tools import dtic_search as dtic

def discover(strategy: dict,
             out_path="work/03_lit_review/candidates.json") -> list[dict]:
    pool, seen = [], set()
    queries = list(strategy.get("introduction", {}).get("macro_queries", []))
    for cl in strategy.get("background", {}).get("clusters", []):
        queries += cl.get("queries", [])
    for q in queries:
        for hit in ss.search(q, limit=8):
            sid = hit.get("paperId")
            if sid and sid not in seen:
                seen.add(sid)
                hit["source"] = "ss"
                pool.append(hit)
        for hit in dtic.search(q, limit=5):
            key = ("dtic", hit.get("accession", q))
            if key not in seen:
                seen.add(key)
                hit["source"] = "dtic"
                pool.append(hit)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Path(out_path).write_text(json.dumps(pool, indent=2))
    return pool
```

4. Create tests/test_lit_discovery_offline.py:

```python
from unittest.mock import patch
from src.agents import lit_review_agent as lra

def test_discover_dedupes(tmp_path):
    fake_ss_data = [
        {"paperId": "p1", "title": "T1", "year": 2022, "abstract": "a"},
        {"paperId": "p2", "title": "T2", "year": 2023, "abstract": "b"},
        {"paperId": "p1", "title": "T1", "year": 2022, "abstract": "a"},
    ]
    strategy = {"introduction": {"macro_queries": ["q"]},
                "background": {"clusters": []}}
    with patch.object(lra.ss, "search", return_value=fake_ss_data):
        with patch.object(lra.dtic, "search", return_value=[]):
            out = lra.discover(strategy,
                               out_path=tmp_path / "c.json")
    assert len(out) == 2
    assert {p["paperId"] for p in out} == {"p1", "p2"}
```

5. Create tests/test_semantic_scholar_retry.py:

```python
import os
from unittest.mock import patch, MagicMock
import pytest
import src.tools.semantic_scholar as sem
from src.tools.semantic_scholar import _request_with_retry

def test_retry_on_429(capsys):
    """Test that 429 triggers retry with console output."""
    mock_responses = [
        MagicMock(status_code=429, raise_for_status=MagicMock(
            side_effect=__import__('requests').exceptions.HTTPError(
                response=MagicMock(status_code=429)))),
        MagicMock(status_code=200, json=lambda: {"data": []},
                  raise_for_status=MagicMock()),
    ]
    with patch("src.tools.semantic_scholar.requests.request",
               side_effect=mock_responses):
        with patch("src.tools.semantic_scholar.time.sleep"):
            r = _request_with_retry("GET", "http://test.com")
    assert r.status_code == 200
    captured = capsys.readouterr()
    assert "Server returned 429" in captured.err
    assert "retrying" in captured.err

def test_max_retries_exhausted():
    """Test that max retries raises after exhaustion."""
    mock_response = MagicMock(status_code=429)
    mock_response.raise_for_status.side_effect = (
        __import__('requests').exceptions.HTTPError(
            response=MagicMock(status_code=429)))
    with patch("src.tools.semantic_scholar.requests.request",
               return_value=mock_response):
        with patch("src.tools.semantic_scholar.time.sleep"):
            with pytest.raises(__import__('requests').exceptions.HTTPError):
                _request_with_retry("GET", "http://test.com")

def test_auth_header_sent_when_s2_api_key_set():
    """x-api-key header is included in every request when S2_API_KEY is set."""
    mock_resp = MagicMock(status_code=200, json=lambda: {"data": []},
                          raise_for_status=MagicMock())
    with patch.dict(os.environ, {"S2_API_KEY": "test-key-123"}):
        with patch("src.tools.semantic_scholar.requests.request",
                   return_value=mock_resp) as mock_req:
            with patch("src.tools.semantic_scholar.time.sleep"):
                sem.search("neural networks")
    headers_sent = mock_req.call_args[1].get("headers", {})
    assert headers_sent.get("x-api-key") == "test-key-123"

def test_no_auth_header_when_s2_api_key_absent():
    """No x-api-key header is sent when S2_API_KEY is not in the environment."""
    mock_resp = MagicMock(status_code=200, json=lambda: {"data": []},
                          raise_for_status=MagicMock())
    env_without_key = {k: v for k, v in os.environ.items() if k != "S2_API_KEY"}
    with patch.dict(os.environ, env_without_key, clear=True):
        with patch("src.tools.semantic_scholar.requests.request",
                   return_value=mock_resp) as mock_req:
            with patch("src.tools.semantic_scholar.time.sleep"):
                sem.search("neural networks")
    headers_sent = mock_req.call_args[1].get("headers", {})
    assert "x-api-key" not in headers_sent
```

6. Run: pytest tests/test_lit_discovery_offline.py tests/test_semantic_scholar_retry.py -v

7. Commit: git add -A && git commit -m "4.1: lit discovery + S2 wrapper with API key support and retry logic"

ACCEPTANCE TEST: pytest shows 5 passed.

WHEN DONE:
Print: "Subtask 4.1 complete: candidate discovery with API key auth and rate-limit retry"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_lit_discovery_offline.py tests/test_semantic_scholar_retry.py -v` shows 5 passed.

---

#### 4.2 — Verification + dedup + .bib · OC · M · No LLM · ~25 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free (no LLM calls)

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.4.2.
PRECONDITIONS: 4.1 done.
TASK: Verify candidates, drop hallucinations, dedupe, emit a BibTeX
file and a citation_map.json.

DO THIS:

1. Append to src/agents/lit_review_agent.py:

```python
import re
import bibtexparser
from bibtexparser.bwriter import BibTexWriter

def _stable_key(entry: dict) -> str:
    authors = entry.get("authors") or []
    last = (authors[0]["name"].split()[-1] if authors
            else "Anon").replace(" ", "")
    year = str(entry.get("year") or "ND")
    title = entry.get("title", "")
    short = re.sub(r"[^A-Za-z]+", "", title.split()[0])[:8] if title else "X"
    return f"{last}{year}{short}"

def verify_and_emit_bib(
    candidates: list[dict],
    cutoff: str,
    bib_path="work/03_lit_review/verified.bib",
    map_path="work/03_lit_review/citation_map.json",
) -> list[dict]:
    cutoff_year = int(cutoff[:4])
    verified, seen_ids, db_entries = [], set(), []
    for c in candidates:
        if not c.get("abstract"):
            continue
        if (c.get("year") or 0) > cutoff_year:
            continue
        t = c.get("title") or ""
        if len(t) < 6:
            continue
        sid = c.get("paperId") or (c.get("externalIds") or {}).get("DOI") or t
        if sid in seen_ids:
            continue
        seen_ids.add(sid)
        key = _stable_key(c)
        db_entries.append({
            "ENTRYTYPE": "article",
            "ID": key,
            "title": t,
            "author": " and ".join(a["name"]
                                   for a in (c.get("authors") or [])),
            "year": str(c.get("year") or ""),
            "journal": c.get("venue") or "",
        })
        verified.append({"key": key, **c})

    db = bibtexparser.bibdatabase.BibDatabase()
    db.entries = db_entries
    Path(bib_path).parent.mkdir(parents=True, exist_ok=True)
    with open(bib_path, "w") as f:
        f.write(BibTexWriter().write(db))
    Path(map_path).write_text(json.dumps(
        {v["key"]: {"title": v["title"],
                    "abstract": v.get("abstract", ""),
                    "year": v.get("year", "")}
         for v in verified}, indent=2))
    return verified
```

2. Create tests/test_verify_bib.py:

```python
from src.agents.lit_review_agent import verify_and_emit_bib, _stable_key

def test_stable_key_deterministic():
    e = {"authors": [{"name": "Jane Doe"}], "year": 2022, "title": "Foo Bar"}
    assert _stable_key(e) == _stable_key(e)
    assert "Doe2022" in _stable_key(e)

def test_verify_drops_invalids(tmp_path):
    cands = [
        {"paperId": "p1", "title": "Valid Paper One",
         "year": 2022, "abstract": "ok", "authors": [{"name": "Smith"}]},
        {"paperId": "p2", "title": "No Abstract",
         "year": 2022, "abstract": "", "authors": []},
        {"paperId": "p3", "title": "Future Paper",
         "year": 2099, "abstract": "ok", "authors": []},
        {"paperId": "p1", "title": "Duplicate", "year": 2022,
         "abstract": "x", "authors": []},
    ]
    bib = tmp_path / "v.bib"
    cmap = tmp_path / "v.json"
    out = verify_and_emit_bib(cands, "2026-04-01",
                              bib_path=bib, map_path=cmap)
    assert len(out) == 1
    assert out[0]["paperId"] == "p1"
    assert bib.exists() and cmap.exists()
```

3. Run: pytest tests/test_verify_bib.py -v

4. Commit: git add -A && git commit -m "4.2: verify + bib"

ACCEPTANCE TEST: pytest shows 2 passed.

WHEN DONE:
Print: "Subtask 4.2 complete: verification + bib"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_verify_bib.py -v` shows 2 passed.

---

#### 4.3 — Intro/Background drafting from verified bib · OC · M · Sonnet at runtime · ~25 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) for OC — Free; Runtime uses Sonnet

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.4.3.
PRECONDITIONS: 4.2 done.
TASK: Implement drafting of section 1.2 (Background) from the
verified bib + outline.

DO THIS:

1. Save src/prompts/03_lit_synth.txt with EXACTLY the text between
   ---begin--- and ---end--- (do not include markers):

---begin---
You are writing section 1.2 (Background and Related Work) of a US
government Final Project Report formatted for the NRL template. Use
ONLY the verified bibliography below. Do not cite from training memory.

Outline for this section:
{outline_section}

Verified bibliography (cite at least 75% of these by their key):
{citation_map}

Project proposal context (for framing the gap):
{proposal_excerpt}

Output:
- LaTeX content for section 1.2 only.
- Do NOT emit a \chapter{{}} heading — the chapter heading
  "\chapter{{BACKGROUND AND RELATED WORK}}" already exists in the NRL
  template. Emitting it again would duplicate and corrupt the document.
- Use \section{{}} for major topic clusters within this chapter, and
  \subsection{{}} below that if needed.
- Use \cite{{key}} for every nontrivial claim.
- Group citations by methodology cluster from the outline.
- End with one paragraph on the specific gap this project addresses.
- No commentary, no fences.
---end---

NOTE: \cite{{key}} double braces are escapes for str.format.

2. Append to src/agents/lit_review_agent.py:

```python
from src.tools.llm_client import call_llm

_SYNTH_PATH = Path(__file__).parent.parent / "prompts" / "03_lit_synth.txt"

def draft_background(outline: dict,
                     citation_map: dict,
                     proposal_text: str,
                     out_path="work/03_lit_review/intro_background.tex") -> str:
    template = _SYNTH_PATH.read_text()
    sec_12 = next((s for s in outline["section_plan"]
                   if s["section_id"] == "1.2"), {})
    user = template.format(
        outline_section=json.dumps(sec_12, indent=2),
        citation_map=json.dumps(
            {k: {"title": v["title"][:200], "year": v.get("year", "")}
             for k, v in citation_map.items()}, indent=2),
        proposal_excerpt=(proposal_text or "")[:8000],
    )
    tex = call_llm("lit_synth",
                   "You write a Background section in LaTeX.",
                   user, anti_leakage=True, temperature=0.3,
                   max_tokens=3000)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Path(out_path).write_text(tex)
    return tex
```

3. Create tests/test_draft_background_offline.py:

```python
from unittest.mock import patch
from src.agents.lit_review_agent import draft_background

def test_draft_background_writes_file(tmp_path):
    outline = {"section_plan": [{"section_id": "1.2",
                                  "title": "Background",
                                  "content_bullets": ["b1"]}]}
    cmap = {"Smith2020Foo": {"title": "Foo", "year": 2020}}
    out = tmp_path / "ib.tex"
    # Section 1.2 maps to \chapter{BACKGROUND AND RELATED WORK} in the NRL
    # template, so the LLM output starts at \section{} level — never \chapter{}
    with patch("src.agents.lit_review_agent.call_llm",
               return_value=r"\section{Prior Work}\cite{Smith2020Foo} ok"):
        draft_background(outline, cmap, "proposal text", out_path=out)
    text = out.read_text()
    assert "Prior Work" in text
    assert "Smith2020Foo" in text
    assert "\\chapter" not in text  # chapter heading must not appear in content
```

4. Run: pytest tests/test_draft_background_offline.py -v

5. Commit: git add -A && git commit -m "4.3: background drafting"

ACCEPTANCE TEST: pytest shows 1 passed.

WHEN DONE:
Print: "Subtask 4.3 complete: background drafting"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_draft_background_offline.py -v` shows 1 passed.

---

### Phase 5 — Diagram Emitter

#### 5.1 — TikZ/Mermaid emitter · OC · S · Devstral local at runtime · ~25 min

**Complexity:** S (Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.5.1.
TASK: Implement a per-diagram code emitter.

DO THIS:

1. Save src/prompts/04_diagram.txt with EXACTLY the text between
   ---begin--- and ---end--- (do not include markers):

---begin---
You write a single conceptual diagram as either a TikZ figure or a
Mermaid block. Output ONLY code — no commentary, no markdown
fences around the OUTER block, no explanation.

Diagram spec:
- id: {diagram_id}
- title: {title}
- kind: {kind}
- intent: {intent}

Relevant context from the lab notebook:
{notebook_excerpts}

Output rules:

If kind == "tikz":
  Produce a complete LaTeX figure block:
    \begin{{figure}}[ht]
    \centering
    \begin{{tikzpicture}}
      ... your TikZ code ...
    \end{{tikzpicture}}
    \caption{{ONE concise sentence}}
    \label{{fig:{diagram_id}}}
    \end{{figure}}
  Use only standard TikZ libraries: arrows.meta, positioning, shapes.
  Keep readable on a single page (no more than ~12 nodes).
  Conceptual only (architecture or flow). No data plots.

If kind == "mermaid":
  Produce TWO things separated by exactly one blank line:
    1. A mermaid code block starting with three backticks + mermaid
       and ending with three backticks.
    2. A LaTeX figure block:
       \begin{{figure}}[ht]
       \centering
       \includegraphics[width=0.9\linewidth]{{diagrams/{diagram_id}.pdf}}
       \caption{{ONE concise sentence}}
       \label{{fig:{diagram_id}}}
       \end{{figure}}
---end---

NOTE: Double braces {{ }} are escapes for Python's str.format.

2. Replace src/agents/diagram_emitter.py with EXACTLY:

```python
"""Diagram Emitter: TikZ or Mermaid code per spec."""
from __future__ import annotations
from pathlib import Path
from src.tools.llm_client import call_llm

PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "04_diagram.txt"

def emit(spec: dict, notebook_excerpts: str = "") -> str:
    template = PROMPT_PATH.read_text()
    user = template.format(
        diagram_id=spec["diagram_id"],
        title=spec["title"],
        kind=spec["kind"],
        intent=spec["intent"],
        notebook_excerpts=notebook_excerpts[:6000] or "(none)",
    )
    return call_llm("diagram",
                    "You output a single LaTeX figure block.",
                    user, anti_leakage=False, temperature=0.2,
                    max_tokens=2500)

def emit_all(diagram_plan: list[dict],
             excerpts_by_section: dict | None = None,
             out_dir="work/04_diagrams") -> dict:
    out = {}
    outp = Path(out_dir)
    outp.mkdir(parents=True, exist_ok=True)
    excerpts_by_section = excerpts_by_section or {}
    for spec in diagram_plan:
        ex = excerpts_by_section.get(spec.get("section_anchor", ""), "")
        code = emit(spec, ex)
        (outp / f"{spec['diagram_id']}.tex").write_text(code)
        out[spec["diagram_id"]] = code
    return out
```

3. Create tests/test_diagram_offline.py:

```python
from unittest.mock import patch
from src.agents.diagram_emitter import emit_all

def test_emit_all_writes_files(tmp_path):
    plan = [
        {"diagram_id": "fig_arch", "title": "Arch", "kind": "tikz",
         "intent": "show flow", "section_anchor": "2.1"},
        {"diagram_id": "fig_pipe", "title": "Pipe", "kind": "mermaid",
         "intent": "pipeline", "section_anchor": "2.2"},
    ]
    with patch("src.agents.diagram_emitter.call_llm",
               return_value="\\begin{figure}\\end{figure}"):
        out = emit_all(plan, {"2.1": "ex"}, out_dir=tmp_path)
    assert set(out.keys()) == {"fig_arch", "fig_pipe"}
    assert (tmp_path / "fig_arch.tex").exists()
```

4. Run: pytest tests/test_diagram_offline.py -v

5. Commit: git add -A && git commit -m "5.1: diagram emitter"

ACCEPTANCE TEST: pytest shows 1 passed.

WHEN DONE:
Print: "Subtask 5.1 complete: diagram emitter"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_diagram_offline.py -v` shows 1 passed.

---

#### 5.2 — Mermaid renderer (optional) · OC · S · No LLM · ~15 min

**Complexity:** S (Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free (no LLM calls)

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.5.2.
TASK: Add a Mermaid → PDF renderer using mmdc. If mmdc isn't
installed, the function returns False and the caller falls back to
TikZ-only.

DO THIS:

1. Replace src/tools/mermaid_render.py with EXACTLY:

```python
"""Render mermaid blocks to PDF using mmdc (mermaid-cli)."""
import shutil, subprocess, re
from pathlib import Path

_MERMAID_RE = re.compile(r"```mermaid\s*(.*?)```", re.DOTALL)

def has_mmdc() -> bool:
    return shutil.which("mmdc") is not None

def render_block_to_pdf(mermaid_src: str, out_pdf) -> bool:
    if not has_mmdc():
        return False
    out_pdf = Path(out_pdf)
    out_pdf.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_pdf.with_suffix(".mmd")
    tmp.write_text(mermaid_src)
    try:
        subprocess.run(["mmdc", "-i", str(tmp), "-o", str(out_pdf)],
                       check=True, capture_output=True, timeout=60)
        return True
    except Exception:
        return False

def extract_and_render(diagram_tex: str, diagram_id: str, out_dir) -> str:
    """Returns the LaTeX figure portion (after the mermaid block)."""
    m = _MERMAID_RE.search(diagram_tex)
    if not m:
        return diagram_tex
    mermaid_src = m.group(1).strip()
    render_block_to_pdf(mermaid_src,
                        Path(out_dir) / "diagrams" / f"{diagram_id}.pdf")
    return diagram_tex[m.end():].strip()
```

2. Create tests/test_mermaid_render.py:

```python
from unittest.mock import patch
from src.tools.mermaid_render import render_block_to_pdf

def test_render_returns_false_without_mmdc(tmp_path):
    with patch("src.tools.mermaid_render.has_mmdc", return_value=False):
        ok = render_block_to_pdf("graph TD; A-->B", tmp_path / "x.pdf")
    assert ok is False

def test_render_writes_mmd_when_mmdc_present(tmp_path):
    with patch("src.tools.mermaid_render.has_mmdc", return_value=True), \
         patch("src.tools.mermaid_render.subprocess.run") as run:
        ok = render_block_to_pdf("graph TD; A-->B",
                                 tmp_path / "diagrams" / "x.pdf")
    assert ok is True
    assert (tmp_path / "diagrams" / "x.mmd").exists()
    run.assert_called_once()
```

3. Run: pytest tests/test_mermaid_render.py -v

4. Commit: git add -A && git commit -m "5.2: mermaid renderer"

ACCEPTANCE TEST: pytest shows 2 passed.

WHEN DONE:
Print: "Subtask 5.2 complete: mermaid renderer"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_mermaid_render.py -v` shows 2 passed.

---

### Phase 6 — Refinement loop

#### 6.1 — Reviewer + Revisor prompts · OC · S · Haiku/Sonnet at runtime · ~10 min

**Complexity:** S (Small)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free; Runtime uses Haiku ($1/$5) and Sonnet ($3/$15)

**OC PROMPT:**

```text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.6.1.
TASK: Save the reviewer and revisor prompt files.

DO THIS:

1. Save src/prompts/07_reviewer.txt with EXACTLY the text between
   ---begin--- and ---end--- (do not include markers):

---begin---
You review a US government technical Final Project Report against
a fixed rubric. Output JSON only — no prose, no fences.

Score each axis 1–5 (5 = best). Be strict; default to 3 unless the
report clearly excels.

IMPORTANT: In your JSON output, you MUST escape all backslashes as \\
(double backslash). For example, write \\cite{} not \cite{}, and
\\section{} not \section{}. This is required for valid JSON.

Schema:
{
  "objective_clarity":           {"score": 0, "rationale": "..."},
  "technical_progress_evidence": {"score": 0, "rationale": "..."},
  "data_and_metrics_rigor":      {"score": 0, "rationale": "..."},
  "transitions_concreteness":    {"score": 0, "rationale": "..."},
  "citation_grounding":          {"score": 0, "rationale": "..."},
  "writing_clarity":             {"score": 0, "rationale": "..."},
  "overall":                     {"score": 0, "rationale": "..."},
  "top_3_specific_revisions":    ["...", "...", "..."]
}

The report (full LaTeX) follows.
---end---

2. Save src/prompts/07_revisor.txt with EXACTLY the text between
   ---begin--- and ---end--- (do not include markers):

---begin---
You revise a LaTeX Final Project Report based on reviewer feedback.

Apply ONLY the three specific revisions in REVIEW.top_3_specific_revisions.
Do not introduce new citations. Do not invent results. Do not change
numerical values that exist in the report. Preserve the document
class, packages, and section structure.

Output the FULL revised LaTeX document. No commentary, no fences.

REVIEW (JSON):
{review_json}

CURRENT LATEX:
{latex_source}
---end---

3. Commit: git add -A && git commit -m "6.1: reviewer + revisor prompts"

ACCEPTANCE TEST:
Both files exist and are non-empty (use `wc -l` to verify).

WHEN DONE:
Print: "Subtask 6.1 complete: reviewer + revisor prompts"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
```

✅ **Verify:** `wc -l src/prompts/07_reviewer.txt src/prompts/07_revisor.txt` shows non-zero counts.

---

#### 6.2 — Score-driven loop · OC · M · Haiku + Sonnet at runtime · ~30 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) for OC — Free; Runtime uses Haiku + Sonnet

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.6.2.
PRECONDITIONS: 6.1 done.
TASK: Implement the accept/revert refinement loop.

DO THIS:

1. Replace src/agents/refinement_agent.py with EXACTLY:

```python
"""Score-driven refinement loop."""
from __future__ import annotations
import json, re
from pathlib import Path
from src.tools.llm_client import call_llm

PROMPTS = Path(__file__).parent.parent / "prompts"

AXES = ["objective_clarity", "technical_progress_evidence",
        "data_and_metrics_rigor", "transitions_concreteness",
        "citation_grounding", "writing_clarity"]

def review(latex_src: str) -> dict:
    system = (PROMPTS / "07_reviewer.txt").read_text()
    text = call_llm("refinement_reviewer", system, latex_src,
                    temperature=0.0, max_tokens=4000)
    return _strip_and_load(text)

def revise(latex_src: str, review_json: dict) -> str:
    template = (PROMPTS / "07_revisor.txt").read_text()
    user = template.format(
        review_json=json.dumps(review_json, indent=2),
        latex_source=latex_src)
    return call_llm("refinement_revisor",
                    "You revise a LaTeX document.",
                    user, temperature=0.2, max_tokens=16000)

def loop(latex_src: str, max_iter: int = 3,
         log_path="work/07_refined/scores.json") -> tuple:
    history = []
    cur = latex_src
    cur_review = review(cur)
    history.append({"iter": 0, "review": cur_review})
    for i in range(1, max_iter + 1):
        candidate = revise(cur, cur_review)
        cand_review = review(candidate)
        accept = _accept(cur_review, cand_review)
        history.append({"iter": i, "accepted": accept,
                        "review": cand_review})
        if not accept:
            break
        cur, cur_review = candidate, cand_review
        if cur_review.get("overall", {}).get("score", 0) >= 5:
            break
    Path(log_path).parent.mkdir(parents=True, exist_ok=True)
    Path(log_path).write_text(json.dumps(history, indent=2))
    return cur, history

def _accept(old: dict, new: dict) -> bool:
    o = old.get("overall", {}).get("score", 0)
    n = new.get("overall", {}).get("score", 0)
    if n > o: return True
    if n < o: return False
    for ax in AXES:
        if new.get(ax, {}).get("score", 0) < old.get(ax, {}).get("score", 0):
            return False
    return True

def _strip_and_load(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1]
        if text.endswith("```"):
            text = text[:-3]
    text = text.strip()
    # Fix invalid JSON escape sequences: replace backslashes not followed
    # by valid JSON escape characters with escaped backslashes
    text = re.sub(r'\\(?!["\\/bfnrtu])', r'\\\\', text)
    return json.loads(text)
```

2. Create tests/test_refinement_offline.py:

```python
from src.agents.refinement_agent import _accept

BASE = {ax: {"score": 3} for ax in
        ["objective_clarity","technical_progress_evidence",
         "data_and_metrics_rigor","transitions_concreteness",
         "citation_grounding","writing_clarity"]}
def mk(overall, **overrides):
    r = {**BASE, **overrides}
    r["overall"] = {"score": overall}
    return r

def test_accept_when_overall_increases():
    assert _accept(mk(3), mk(4)) is True

def test_revert_when_overall_decreases():
    assert _accept(mk(4), mk(3)) is False

def test_revert_on_tie_with_subaxis_decrease():
    old = mk(3)
    new = mk(3, writing_clarity={"score": 2})
    assert _accept(old, new) is False

def test_accept_on_tie_with_no_decreases():
    old = mk(3)
    new = mk(3, writing_clarity={"score": 4})
    assert _accept(old, new) is True
```

3. Run: pytest tests/test_refinement_offline.py -v

4. Commit: git add -A && git commit -m "6.2: refinement loop"

ACCEPTANCE TEST: pytest shows 4 passed.

WHEN DONE:
Print: "Subtask 6.2 complete: refinement loop"
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_refinement_offline.py -v` shows 4 passed.

---

### Phase 7 — Polish

#### 7.1 — NRL-Aware Assembler · OC · M · Devstral local · ~30 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**Background for OC.** The NRL report template already contains `\chapter{}` and
`\section{}` headings and `\begin{executivesummary}` / `\begin{acknowledgments}`
environments. Each content slot is marked by a `PLACEHOLDER` line. The Assembler
must replace those PLACEHOLDER lines with generated content rather than appending
a monolithic body. The bibliography must be copied as `References.bib` because the
NRL template uses `\bibliography{References}`. The `bibunits` package is used by the
template for appendix-level bibliographies and should not be disturbed.

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.7.1 and the NRL-template background note above it.
PRECONDITIONS: 0.x through 6.x complete.
TASK: Implement the NRL-aware Assembler that replaces PLACEHOLDER blocks
inside the existing NRL template structure, and create the section-to-chapter
mapping configuration file.

DO THIS:

1. Create config/nrl_template_mapping.yaml with EXACTLY:

```yaml
# Maps outline section_ids to the NRL template heading that precedes each
# PLACEHOLDER block. The assembler searches for the heading, then replaces
# the first PLACEHOLDER line found after it (stopping at the next
# \chapter or \section boundary).
sections:
  "1.1": "\\chapter{INTRODUCTION}"
  "1.2": "\\chapter{BACKGROUND AND RELATED WORK}"
  "2.1": "\\section{Problem Formulation}"
  "2.2": "\\section{Approach}"
  "2.3": "\\chapter{METHODOLOGY}"
  "3":   "\\chapter{RESULTS}"
  "4.1": "\\chapter{DISCUSSION}"
  "4.2": "\\chapter{SUMMARY AND CONCLUSIONS}"
  "4.3": "\\subsection{Transitions}"

# LaTeX environment names used by the NRL template for special sections
executive_summary: "executivesummary"
acknowledgments:   "acknowledgments"

# NRL template uses \bibliography{References}; verified.bib is copied
# to this filename automatically
bibliography_name: "References"
```

2. Replace src/agents/assembler.py with EXACTLY:

```python
"""NRL-template-aware Assembler.

Replaces PLACEHOLDER lines within the existing \\chapter{} / \\section{}
structure of the NRL template. Each PLACEHOLDER is identified by the
chapter or section heading that precedes it, per nrl_template_mapping.yaml.

Key NRL requirements handled here:
- \\chapter{} hierarchy: content is inserted at \\section{} level and below.
- \\begin{executivesummary} and \\begin{acknowledgments} environments.
- verified.bib is copied to References.bib to match \\bibliography{References}.
- bibunits (used for appendix bibliographies) is left untouched.
"""
from __future__ import annotations
import re, shutil, yaml
from pathlib import Path

_DEFAULT_MAPPING = (
    Path(__file__).resolve().parents[2] / "config" / "nrl_template_mapping.yaml"
)

# Matches any line that contains the word PLACEHOLDER (case-insensitive).
# The NRL template uses bare "PLACEHOLDER" lines as content insertion markers.
_PLACEHOLDER_RE = re.compile(
    r"^[^\n]*PLACEHOLDER[^\n]*$", re.MULTILINE | re.IGNORECASE
)


def _load_mapping(mapping_path=None) -> dict:
    p = Path(mapping_path) if mapping_path else _DEFAULT_MAPPING
    with open(p) as f:
        return yaml.safe_load(f)


def _replace_placeholder_after_heading(
    tex: str, heading: str, content: str
) -> str:
    """Replace the first PLACEHOLDER after 'heading' with 'content'.

    Limits the search to the current section's content by stopping at the
    next \\chapter{} or \\section{} boundary. Returns tex unchanged if the
    heading or PLACEHOLDER is absent (graceful no-op).
    """
    m = re.search(re.escape(heading), tex)
    if not m:
        return tex  # heading not found in template — skip silently

    after_pos = m.end()

    # Stop searching at the next \chapter{...} or \section{...} so we
    # don't accidentally claim a PLACEHOLDER that belongs to an adjacent section.
    next_boundary = re.search(r"\\(?:chapter|section)\{", tex[after_pos:])
    end_pos = (
        after_pos + next_boundary.start() if next_boundary else len(tex)
    )

    region = tex[after_pos:end_pos]
    ph = _PLACEHOLDER_RE.search(region)
    if not ph:
        return tex  # no PLACEHOLDER in this section — skip silently

    # Splice generated content over the PLACEHOLDER line
    abs_start = after_pos + ph.start()
    abs_end = after_pos + ph.end()
    return tex[:abs_start] + content + tex[abs_end:]


def _replace_environment_content(
    tex: str, env_name: str, content: str
) -> str:
    """Replace the body inside \\begin{env_name}...\\end{env_name}.

    Used for NRL-specific environments: executivesummary, acknowledgments.
    Returns tex unchanged if the environment is absent.
    """
    pattern = re.compile(
        r"(\\begin\{" + re.escape(env_name) + r"\})"
        r".*?"
        r"(\\end\{" + re.escape(env_name) + r"\})",
        re.DOTALL,
    )
    m = pattern.search(tex)
    if not m:
        return tex  # environment absent — skip
    return (
        tex[: m.start(1) + len(m.group(1))]
        + "\n"
        + content
        + "\n"
        + tex[m.start(2) :]
    )


def assemble(
    template_tex: str,
    section_files: dict,       # {section_id: latex_str}
    diagram_blocks: dict,      # {diagram_id: latex figure block}
    bib_path: str,
    distribution_stmt: str = "",
    acknowledgements: str = "",
    executive_summary: str = "",
    out_path: str = "outputs/report.tex",
    _mapping_path=None,        # override path for unit tests
) -> str:
    mapping = _load_mapping(_mapping_path)
    section_map = mapping.get("sections", {})
    exec_env   = mapping.get("executive_summary", "executivesummary")
    ack_env    = mapping.get("acknowledgments", "acknowledgments")
    bib_name   = mapping.get("bibliography_name", "References")

    tex = template_tex

    # 1. Prepend distribution statement immediately after \begin{document}
    if distribution_stmt:
        dist_block = (
            "\n\\begin{center}\\textbf{"
            + distribution_stmt
            + "}\\end{center}\n\\vspace{1em}\n"
        )
        if "\\begin{document}" in tex:
            tex = tex.replace("\\begin{document}",
                              "\\begin{document}" + dist_block, 1)

    # 2. Populate executive summary environment if content provided
    if executive_summary:
        tex = _replace_environment_content(tex, exec_env, executive_summary)

    # 3. Replace each section's PLACEHOLDER in the NRL chapter/section structure.
    #    Process in outline order so that multi-PLACEHOLDER chapters (e.g.,
    #    SUMMARY AND CONCLUSIONS containing both 4.2 body and 4.3 Transitions)
    #    are resolved top-to-bottom correctly.
    section_order = [
        "1.1", "1.2", "2.1", "2.2", "2.3", "3", "4.1", "4.2", "4.3"
    ]
    for sid in section_order:
        if sid not in section_files or sid not in section_map:
            continue
        heading = section_map[sid]
        tex = _replace_placeholder_after_heading(
            tex, heading, section_files[sid]
        )

    # 4. Append diagram blocks that were not already embedded in section content.
    #    (If cli.py embeds diagrams into section_files at their anchor, they
    #    won't appear here. Orphans fall back to placement before \end{document}.)
    embedded_ids = {
        did
        for did, _code in diagram_blocks.items()
        if any(did in sf for sf in section_files.values())
    }
    orphan_diagrams = "\n\n".join(
        code
        for did, code in diagram_blocks.items()
        if did not in embedded_ids
    )
    if orphan_diagrams and "\\end{document}" in tex:
        tex = tex.replace(
            "\\end{document}", orphan_diagrams + "\n\n\\end{document}", 1
        )

    # 5. Populate acknowledgments environment
    if acknowledgements:
        tex = _replace_environment_content(tex, ack_env, acknowledgements)

    # 6. Write output; copy verified.bib → References.bib (NRL uses
    #    \bibliography{References}, so the filename must match exactly)
    outp = Path(out_path)
    outp.parent.mkdir(parents=True, exist_ok=True)
    outp.write_text(tex)

    bib = Path(bib_path)
    if bib.exists():
        shutil.copy(bib, outp.parent / f"{bib_name}.bib")

    return tex
```

3. Create tests/fixtures/nrl_template_snippet.tex with EXACTLY:

```latex
\documentclass[12pt]{article}

\begin{document}

\begin{executivesummary}
PLACEHOLDER
\end{executivesummary}

\chapter{INTRODUCTION}

PLACEHOLDER

\chapter{BACKGROUND AND RELATED WORK}

PLACEHOLDER

\begin{acknowledgments}
PLACEHOLDER
\end{acknowledgments}

\bibliography{References}
\end{document}
```

4. Create tests/fixtures/nrl_mapping.yaml with EXACTLY:

```yaml
sections:
  "1.1": "\\chapter{INTRODUCTION}"
  "1.2": "\\chapter{BACKGROUND AND RELATED WORK}"
executive_summary: "executivesummary"
acknowledgments: "acknowledgments"
bibliography_name: "References"
```

5. Replace tests/test_assemble.py with EXACTLY:

```python
from pathlib import Path
from src.agents.assembler import assemble

FIX     = Path(__file__).parent / "fixtures"
NRL_TEX = (FIX / "nrl_template_snippet.tex").read_text()
MAPPING = FIX / "nrl_mapping.yaml"


def test_assemble_replaces_chapter_placeholders(tmp_path):
    """PLACEHOLDER lines inside NRL chapters are replaced with section content."""
    sections = {
        "1.1": "The objective is to develop a neural network classifier.",
        "1.2": "Prior work spans deep learning and signal processing.",
    }
    bib = tmp_path / "verified.bib"
    bib.write_text("@article{Smith2020Foo,title={Foo}}")
    out = tmp_path / "report.tex"

    tex = assemble(
        NRL_TEX, sections, {},
        bib_path=bib,
        acknowledgements="This work was supported by ONR.",
        out_path=out,
        _mapping_path=MAPPING,
    )

    assert "objective is to develop" in tex, "section 1.1 content missing"
    assert "deep learning" in tex, "section 1.2 content missing"
    assert "This work was supported" in tex, "acknowledgements missing"
    assert "PLACEHOLDER" not in tex, "unreplaced PLACEHOLDER remains"
    # NRL bibliography: verified.bib must be copied as References.bib
    assert (out.parent / "References.bib").exists(), "References.bib not created"


def test_assemble_distribution_stmt_precedes_content(tmp_path):
    """Distribution statement is inserted immediately after \\begin{document}."""
    template = (
        "\\begin{document}\n"
        "\\chapter{INTRODUCTION}\nPLACEHOLDER\n"
        "\\end{document}"
    )
    bib = tmp_path / "v.bib"
    bib.write_text("")
    out = tmp_path / "r.tex"

    tex = assemble(
        template, {"1.1": "intro text"}, {},
        bib_path=bib,
        distribution_stmt="DIST STMT A",
        out_path=out,
        _mapping_path=MAPPING,
    )

    assert "DIST STMT A" in tex
    assert tex.index("DIST STMT A") < tex.index("intro text")


def test_assemble_orphan_diagrams_appended_before_end(tmp_path):
    """Diagrams not embedded in any section content land before \\end{document}."""
    template = (
        "\\begin{document}\n"
        "\\chapter{INTRODUCTION}\nPLACEHOLDER\n"
        "\\end{document}"
    )
    bib = tmp_path / "v.bib"
    bib.write_text("")
    out = tmp_path / "r.tex"
    diagrams = {"fig_arch": "\\begin{figure}[ht]arch\\end{figure}"}

    tex = assemble(
        template, {"1.1": "intro text"}, diagrams,
        bib_path=bib, out_path=out,
        _mapping_path=MAPPING,
    )

    assert "arch\\end{figure}" in tex, "orphan diagram missing from output"
    assert tex.index("arch\\end{figure}") < tex.index("\\end{document}")
```

6. Run: pytest tests/test_assemble.py -v

7. Commit: git add -A && git commit -m "7.1: NRL-aware assembler with placeholder replacement"

ACCEPTANCE TEST:
- pytest shows 3 passed.
- `grep -c PLACEHOLDER tests/fixtures/nrl_template_snippet.tex` prints 3
  (confirming the fixture has PLACEHOLDERs to replace).
- After a full run, `outputs/References.bib` exists (not `verified.bib`).

WHEN DONE:
Print: "Subtask 7.1 complete: NRL-aware assembler"
STOP.

IF STUCK:
- If a test fails with "heading not found": confirm the heading string in
  nrl_mapping.yaml exactly matches the text in the fixture (backslash escaping).
- If "PLACEHOLDER remains": check that the heading for that section_id is
  in the mapping AND exists verbatim in the template.
- Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `pytest tests/test_assemble.py -v` shows 3 passed.

---

#### 7.2 — End-to-end wiring: `python -m src.cli run` · OC · M · Devstral local · ~30 min

**Complexity:** M (Medium)
**Recommended Model:** Ollama (devstral-small-2:24b) — Free

**OC PROMPT:**

````text
ROLE: You are OpenCode in the report-orchestra repo.
CONTEXT: Read PLAN.md §6.7.2 and the architecture diagram in §1.
PRECONDITIONS: All 0.x through 7.1 are complete.
TASK: Wire the agents into a single end-to-end "run" command.

DO THIS:

1. Replace src/cli.py with EXACTLY:

```python
"""Command-line entrypoint for ReportOrchestra."""
from __future__ import annotations
import argparse, json, yaml
from pathlib import Path
from src.agents.indexer import load_inputs, build_index, retrieve
from src.agents.outline_agent import generate_outline
from src.agents.lit_review_agent import (discover, verify_and_emit_bib,
                                          draft_background)
from src.agents.section_writer import write_section
from src.agents.diagram_emitter import emit_all
from src.agents.assembler import assemble
from src.agents.refinement_agent import loop as refine_loop
from src.tools.llm_client import call_llm
from src.tools.latex_compile import compile_pdf

PROMPT_PATH = Path(__file__).parent / "prompts" / "01_baseline.txt"

def baseline_run(inputs_dir="inputs", out_dir="outputs") -> int:
    data = load_inputs(inputs_dir)
    system = PROMPT_PATH.read_text()
    parts = [
        f"=== TEMPLATE ===\n{data['template']}",
        f"=== PROPOSAL ===\n{data['proposal'][:30000]}",
        f"=== LAST PROGRESS REPORT ===\n{data['last_progress_report'][:30000]}",
        f"=== LAB NOTEBOOK ===\n{data['notebook'][:120000]}",
        f"=== ADDITIONAL NOTES ===\n{data['notes'][:20000]}",
    ]
    if data["examples"]:
        parts.append(f"=== EXAMPLE ===\n{data['examples'][0][:30000]}")
    user = "\n\n".join(parts)
    tex = call_llm("outline", system, user, max_tokens=16000)
    outp = Path(out_dir); outp.mkdir(parents=True, exist_ok=True)
    tex_file = outp / "report_v0.tex"
    tex_file.write_text(tex)
    ok, log = compile_pdf(tex_file)
    print("OK" if ok else "FAIL")
    if not ok: print(log[-1500:])
    return 0 if ok else 1

def full_run(inputs_dir="inputs", out_dir="outputs") -> int:
    inputs = load_inputs(inputs_dir)
    cfg = yaml.safe_load(open("config/config.yaml"))

    print("[1/7] outline ..."); outline = generate_outline(inputs_dir)
    print("[2/7] indexing notebook ..."); build_index(inputs["notebook"])

    print("[3/7] lit review ...")
    candidates = discover(outline["lit_search_strategy"])
    verify_and_emit_bib(candidates, cfg["citation"]["cutoff_date"])
    cmap = json.loads(Path("work/03_lit_review/citation_map.json").read_text())
    intro_bg = draft_background(outline, cmap, inputs["proposal"])

    print("[4/7] diagrams ...")
    excerpts_by_section = {}
    for sec in outline["section_plan"]:
        hits = retrieve(sec.get("notebook_topics", []), k=4)
        excerpts_by_section[sec["section_id"]] = "\n\n".join(
            h["text"] for h in hits)
    diagrams = emit_all(outline["diagram_plan"], excerpts_by_section)
    diag_labels = [d["diagram_id"] for d in outline["diagram_plan"]]

    # Build a section_id → [diagram_code, ...] index so each diagram lands
    # in the correct NRL chapter (the Assembler places orphans before
    # \end{document} as a fallback, but in-chapter placement is preferred).
    diag_by_section: dict = {}
    for spec in outline["diagram_plan"]:
        anchor = spec.get("section_anchor", "3")
        code = diagrams.get(spec["diagram_id"], "")
        if code:
            diag_by_section.setdefault(anchor, []).append(code)

    print("[5/7] sections ...")
    # Start with the Background section produced by the Lit Review agent,
    # then embed any diagrams anchored there.
    intro_bg_content = intro_bg
    for dcode in diag_by_section.get("1.2", []):
        intro_bg_content += "\n\n" + dcode
    section_files = {"1.2": intro_bg_content}

    for sec in outline["section_plan"]:
        sid = sec["section_id"]
        if sid in section_files:
            continue
        hits = retrieve(sec.get("notebook_topics", []), k=8)
        excerpt = "\n\n".join(f"[{h['id']}]\n{h['text']}" for h in hits)
        verified_for_sec = [{"key": k, "title": cmap[k]["title"]}
                            for k in list(cmap.keys())[:25]]
        content = write_section(sec, excerpt, verified_for_sec, diag_labels)
        # Embed diagrams anchored to this section so they appear in the
        # correct NRL chapter after PLACEHOLDER replacement.
        for dcode in diag_by_section.get(sid, []):
            content += "\n\n" + dcode
        section_files[sid] = content

    print("[6/7] assemble ...")
    dist = ""
    dist_path = Path("config/distribution_statement.txt")
    if dist_path.exists():
        dist = dist_path.read_text().strip()
    ack = ""
    ack_path = Path("inputs/notes/acknowledgements.md")
    if ack_path.exists():
        ack = ack_path.read_text()
    out_tex = Path(out_dir) / "report.tex"
    # The Assembler replaces PLACEHOLDER blocks in the NRL template structure.
    # diagram_blocks passed here are already embedded in section_files above,
    # so this dict serves only as an orphan fallback; pass it anyway.
    # verified.bib is automatically copied to References.bib by the assembler.
    tex = assemble(inputs["template"], section_files, diagrams,
                   "work/03_lit_review/verified.bib", dist, ack,
                   executive_summary="",   # populate from inputs if available
                   out_path=out_tex)

    print("[7/7] refine ...")
    refined, _ = refine_loop(tex,
                             max_iter=cfg["refinement"]["max_iterations"])
    out_tex.write_text(refined)

    ok, log = compile_pdf(out_tex)
    print("OK" if ok else "FAIL")
    if not ok: print(log[-1500:])
    return 0 if ok else 1

def main():
    p = argparse.ArgumentParser()
    p.add_argument("command", choices=["baseline", "run"])
    p.add_argument("--inputs", default="inputs")
    p.add_argument("--out", default="outputs")
    args = p.parse_args()
    if args.command == "baseline":
        raise SystemExit(baseline_run(args.inputs, args.out))
    if args.command == "run":
        raise SystemExit(full_run(args.inputs, args.out))

if __name__ == "__main__":
    main()
```

2. Run: python -m src.cli run --help
   (smoke test — should print usage, not crash).

3. Run all tests: pytest -q

4. Commit: git add -A && git commit -m "7.2: end-to-end run wired"

ACCEPTANCE TEST:
- python -m src.cli run --help does not crash.
- pytest -q passes (no failures).

WHEN DONE:
Print: "Subtask 7.2 complete: end-to-end run wired. Leslie:
populate inputs/, ensure ASKSAGE_API_KEY is set, then run
`python -m src.cli run`."
STOP.

IF STUCK: Print "Stuck on: <what>" and stop.
````

✅ **Verify:** `python -m src.cli run --help` runs; `pytest -q` is green. Then Leslie does the real run.

---

#### 7.3 — Acceptance test on last year's data · Leslie + OC · S · ~half a day

**No OC prompt — Leslie drives this iteratively.**

**Complexity:** S (Small) per iteration
**Recommended Model:** Ollama (devstral-small-2:24b) for prompt edits — Free

1. Make a copy of last year's actual progress report inputs in `inputs_test/`.
2. Run `python -m src.cli run --inputs inputs_test --out outputs_test`.
3. Compare `outputs_test/report.pdf` against the actual report Leslie filed last year.
4. List specific quality gaps (citations missed, sections shallow, tone wrong, etc.).
5. For each gap, paste an OC ticket like:

   ```
   ROLE: OpenCode, report-orchestra repo.
   TASK: Edit src/prompts/05_section_writer.txt to add this rule
   under "Output rules": "<specific rule from Leslie>". After editing,
   run `pytest -q` and commit with message
   "7.3: prompt tweak — <one-line summary>".
   ```

6. Iterate on prompts only — no code changes — until satisfied.

---

## 7. Token & cost budget

**Build phase (OC running on free Devstral, Leslie pasting prompts):**
- OC inference: $0 (local).
- Per-test runs that hit AskSage: ~$1–3 each (in AskSage tokens). Across ~30 dev iterations: **$50–$150 total**.

**Per-report runtime (after MVP is tuned):**
- Outline (Sonnet via AskSage, ~200K input + 5K output): ~$0.70
- Background drafting (Sonnet via AskSage, ~80K input + 8K output): ~$0.36
- Refinement reviewer (Haiku via AskSage, 3× ~50K input + 2K output): ~$0.20
- Refinement revisor (Sonnet via AskSage, 3× ~60K input + 16K output): ~$0.80
- Everything else (sections, indexing, diagrams, lit search): **free** (Devstral local)
- **Total per report: ~$2.00 in AskSage tokens.** Well under any reasonable monthly budget.

**Aggressive cost-cutting fallback:** flip `outline`, `lit_synth`, and `refinement_revisor` to `ollama:devstral-small-2:24b` in `config.yaml`. Per-report cost goes to $0 with some quality hit. Keep `refinement_reviewer` on Haiku via AskSage — cheap, and JSON discipline matters there.

---

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Devstral produces invalid JSON for outline | Validate with `json.loads`, retry once with error fed back, fall back to Sonnet on second failure |
| Lab notebook chunking misses cross-references | Phase 3.3 retrieval is keyword-based and dumb; add embeddings (free with `nomic-embed` via Ollama) only if v1 quality is poor |
| Hallucinated citations creep in | Section Writer prompt restricts `\cite{}` to verified keys; Assembler should add a final pass that strips `\cite{}` whose key isn't in `verified.bib` |
| DTIC scraper unreliable | Currently a stub; revisit only after MVP works end-to-end. Semantic Scholar alone covers most academic citations |
| Refinement loop gets stuck | Hard cap `max_iter=3`; revert-and-stop on any overall score decrease |
| Local Ollama loses tool access in OC | Documented gotcha — verify OpenCode config points to running Ollama server |
| Distribution statement is wrong | Leslie writes `distribution_statement.txt` once and a program manager reviews; never auto-generated |
| 16K-line notebook leaks PII | Indexer can be extended with a `--scrub` mode that flags chunks containing names/emails for review before they go into prompts |
| NRL template heading mismatch | `_replace_placeholder_after_heading` silently skips a section if the heading string in `nrl_template_mapping.yaml` doesn't match the template verbatim (different whitespace, braces, case). Mitigation: after a run, grep the output for remaining `PLACEHOLDER` occurrences (`grep -c PLACEHOLDER outputs/report.tex`) and fix the mapping. Log a warning to stderr when a section is skipped. |
| Multiple PLACEHOLDER blocks in one chapter | If a chapter has two PLACEHOLDERs (e.g., 4.2 body + 4.3 Transitions subsection), sequential processing handles them correctly only if both headings appear in `nrl_template_mapping.yaml`. Verify the mapping covers every distinct placeholder in the template before running. |
| Section Writer emits `\chapter{}` headings | The prompt forbids it, but LLMs occasionally ignore constraints. The Refinement Agent should flag `\chapter` occurrences inside generated content (not the template's own headers); add a post-assembly regex check that warns if `\chapter` appears more times than expected from the template. |
| `bibunits` appendix bibliographies break | The NRL template uses `bibunits` for per-appendix reference lists. The Assembler does not touch `\begin{bibunit}` / `\end{bibunit}` blocks. Ensure that `\putbib` commands inside appendices reference correct `.bib` names (typically `References.bib`). No code change required unless the template uses a non-standard name. |
| `nrlabstract` and SF298 fields left blank | These NRL-specific environments are not currently populated by any agent. Leslie must fill `\nrlabstract`, `\ReportDate`, `\ReportNumber`, and related SF298 metadata fields manually in `inputs/template.tex` before running the pipeline. |

---

## 9. Definition of done (MVP)

The MVP is complete when Leslie can:

1. Drop new inputs into `inputs/`.
2. Run `python -m src.cli run`.
3. Get back `outputs/report.pdf` in under 30 minutes.
4. Spend ≤2 hours fixing `[CITATION NEEDED]` and stylistic issues to get a submittable report.
5. Spend ≤$5 in AskSage tokens per run.

Anything beyond that — better diagrams, embedding-based retrieval, multi-pass numeric extraction for tables, automated continuity-with-last-year checks — is **v2**, not MVP.

---

## 10. First OpenCode session — exact opening message

When Leslie starts the very first OC session, paste this:

```text
Read PLAN.md from start to finish, then execute Subtask 0.1 exactly
as specified in §6 (the fenced "OC PROMPT" block). When done, print
the success line and STOP. Do not start any other subtask.
```

That's it. Every later session starts the same way: open OC, paste the next subtask's OC prompt block, wait for the success line, run the acceptance check yourself, move on.

---

## Appendix A: Model & Provider Compatibility Verification

### OpenCode + Ollama Compatibility

OpenCode supports Ollama as a provider through its configuration system. To verify:

1. **Ollama server running:** `curl http://localhost:11434/api/tags` should return available models
2. **Model pulled:** `ollama list` should show `devstral-small-2:24b`
3. **OpenCode configured:** `~/.config/opencode/opencode.json` points to Ollama

### AskSage API Compatibility

ReportOrchestra uses AskSage's Anthropic-compatible endpoint (Army GenAI) for Claude models. To verify:

1. **API Key set:** `echo $ASKSAGE_API_KEY` should show your token
2. **Certificate path set:** `echo $ASKSAGE_CERT_PATH` should show path to DoD cert bundle
3. **Certificate exists:** `ls -la $ASKSAGE_CERT_PATH` should show the file
4. **Endpoint reachable:** 
   ```bash
   curl --cacert $ASKSAGE_CERT_PATH \
     -X POST 'https://api.genai.army.mil/server/anthropic/v1/messages' \
     -H "Authorization: Bearer $ASKSAGE_API_KEY" \
     -H 'Content-Type: application/json' \
     -d '{"model": "claude-sonnet-4-5-20250929", "max_tokens": 10, "messages": [{"role": "user", "content": "Hi"}]}'
   ```
5. **Token budget:** Check your AskSage account for available tokens

### Non-Chinese Model Verification

The recommended models are all Western-developed:

| Model | Developer | Country | Access Via |
|---|---|---|---|
| devstral-small-2:24b | Mistral AI | France | Ollama (local) |
| nemotron-3-super | NVIDIA | USA | Ollama (local) |
| Llama 3.x | Meta | USA | Ollama (local) |
| Claude Sonnet 4.5 | Anthropic | USA | AskSage API |
| Claude Opus 4.7 | Anthropic | USA | AskSage API |
| Claude Haiku 4.5 | Anthropic | USA | AskSage API |

All models are compatible with OpenCode/ReportOrchestra and meet the non-Chinese origin requirement. AskSage is a US company (now part of BigBear.ai) providing FedRAMP High authorized access to these models.

---

## Appendix B: Subtask Complexity & Model Summary

| Subtask | Complexity | OC Model (Build) | Runtime Model | Est. Cost |
|---|---|---|---|---|
| 0.1 Scaffold | XS | Devstral (Free) | N/A | $0 |
| 0.2 Configure OC+Ollama+AskSage | XS | N/A (Manual) | N/A | $0 |
| 0.3 LaTeX wrapper | XS | Devstral (Free) | N/A | $0 |
| 0.4 Config + LLM client | S | Devstral (Free) | N/A | $0 |
| 1.1 Input loader | S | Devstral (Free) | N/A | $0 |
| 1.2 Baseline runner | M | Devstral (Free) | Sonnet (AskSage) | ~$1 |
| 2.1 Anti-leakage prompt | XS | Devstral (Free) | N/A | $0 |
| 2.2 Outline Agent | M | Devstral (Free) | Sonnet (AskSage) | ~$0.70 |
| 2.3 Section Writer | M | Devstral (Free) | Devstral | $0 |
| 3.1 Chunker | M | Devstral (Free) | N/A | $0 |
| 3.2 Topical summary | S | Devstral (Free) | Devstral | $0 |
| 3.3 Retrieval | S | Devstral (Free) | N/A | $0 |
| 4.1 Lit discovery | M | Devstral (Free) | N/A | $0 |
| 4.2 Verify + bib | M | Devstral (Free) | N/A | $0 |
| 4.3 Background draft | M | Devstral (Free) | Sonnet (AskSage) | ~$0.36 |
| 5.1 Diagram emitter | S | Devstral (Free) | Devstral | $0 |
| 5.2 Mermaid renderer | S | Devstral (Free) | N/A | $0 |
| 6.1 Reviewer/Revisor prompts | S | Devstral (Free) | N/A | $0 |
| 6.2 Refinement loop | M | Devstral (Free) | Haiku+Sonnet (AskSage) | ~$1 |
| 7.1 Assembler | M | Devstral (Free) | N/A | $0 |
| 7.2 End-to-end wiring | M | Devstral (Free) | Mixed (AskSage) | ~$2 |
| 7.3 Acceptance test | S | Devstral (Free) | Mixed (AskSage) | ~$2 |

**Legend:**
- XS = Extra Small (~3-5 min)
- S = Small (~15-20 min)
- M = Medium (~25-30 min)

---

## Appendix C: AskSage API Reference

### Authentication
All AskSage API calls require:
1. **Bearer token:** `Authorization: Bearer YOUR_ASKSAGE_API_KEY`
2. **DoD Certificate:** For HTTPS verification (Army GenAI endpoint)

### Endpoint
```
POST https://api.genai.army.mil/server/anthropic/v1/messages
```

### Environment Variables
```bash
export ASKSAGE_API_KEY="your-asksage-token-here"
export ASKSAGE_CERT_PATH="/path/to/.certs/full_dod_bundle.pem"
```

### Available Models (via AskSage)
| Model ID | Description | Backend |
|---|---|---|
| `claude-sonnet-4-5-20250929` | Default balanced (recommended) | AWS Bedrock Gov |
| `claude-opus-4-7-default` | Most capable | Google Vertex AI |
| `claude-opus-4-6-default` | Previous Opus | Google Vertex AI |
| `claude-haiku-4-5-20251001` | Fastest/cheapest | Google Vertex AI |

### Example Request
```bash
curl --cacert $ASKSAGE_CERT_PATH \
  -X POST 'https://api.genai.army.mil/server/anthropic/v1/messages' \
  -H "Authorization: Bearer $ASKSAGE_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 1024,
    "system": "You are a helpful assistant.",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Response Format
```json
{
  "id": "msg_...",
  "type": "message",
  "role": "assistant",
  "model": "claude-sonnet-4-5-20250929",
  "content": [{"type": "text", "text": "Hello! How can I help?"}],
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 12, "output_tokens": 8}
}
```

For full documentation, see: https://docs.asksage.ai/docs/v2/api-documentation/Anthropic-Compatibility-Guide.html
