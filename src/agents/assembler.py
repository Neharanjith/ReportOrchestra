"""Assemble final LaTeX from sections, bib, diagrams, distribution stmt."""
from __future__ import annotations
import shutil
from pathlib import Path

def assemble(
    template_tex: str,
    section_files: dict,           # {section_id: latex_str}
    diagram_blocks: dict,          # {diagram_id: latex figure block}
    bib_path: str,
    distribution_stmt: str = "",
    acknowledgements: str = "",
    out_path: str = "outputs/report.tex",
) -> str:
    order = ["1.1", "1.2", "2.1", "2.2", "2.3", "3", "4.1", "4.2", "4.3"]
    body_parts = []
    if distribution_stmt:
        body_parts.append(
            "\\begin{center}\\textbf{" + distribution_stmt
            + "}\\end{center}\n\\vspace{1em}")
    for sid in order:
        if sid in section_files:
            body_parts.append(section_files[sid])
    for did, code in diagram_blocks.items():
        body_parts.append(code)
    if acknowledgements:
        body_parts.append("\\section*{Acknowledgements}\n" + acknowledgements)
    body_parts.append("\\bibliographystyle{ieeetr}")
    body_parts.append("\\bibliography{" + Path(bib_path).stem + "}")
    body = "\n\n".join(body_parts)

    if "%%REPORT_BODY%%" in template_tex:
        tex = template_tex.replace("%%REPORT_BODY%%", body)
    else:
        tex = template_tex.replace("\\end{document}",
                                   body + "\n\\end{document}")

    outp = Path(out_path)
    outp.parent.mkdir(parents=True, exist_ok=True)
    outp.write_text(tex)
    if Path(bib_path).exists():
        try:
            shutil.copy(bib_path, outp.parent / Path(bib_path).name)
        except shutil.SameFileError:
            pass
    return tex
