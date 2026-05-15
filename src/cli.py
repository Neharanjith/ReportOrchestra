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
