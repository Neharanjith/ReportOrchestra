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

    # Build a section_id -> [diagram_code, ...] index so each diagram lands
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
