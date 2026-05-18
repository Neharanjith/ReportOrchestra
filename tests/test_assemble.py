from src.agents.assembler import assemble

def test_assemble_inserts_body(tmp_path):
    template = "\\documentclass{article}\\begin{document}%%REPORT_BODY%%\\end{document}"
    sections = {"1.1": "\\subsection{Objective}\nDo X.",
                "3":   "\\section{Results}\nFound Y."}
    diagrams = {"fig_a": "\\begin{figure}A\\end{figure}"}
    bib = tmp_path / "ref.bib"
    bib.write_text("@article{X,title={X}}")
    out = tmp_path / "r.tex"
    tex = assemble(template, sections, diagrams,
                   bib_path=bib, distribution_stmt="DIST A",
                   out_path=out)
    assert "Objective" in tex and "Results" in tex
    assert "DIST A" in tex
    assert "\\bibliography{ref}" in tex
    assert (tmp_path / "ref.bib").exists()
