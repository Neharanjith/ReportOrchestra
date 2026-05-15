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
