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
