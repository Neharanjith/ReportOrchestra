import shutil, pytest
from pathlib import Path
from src.tools.latex_compile import compile_pdf

FIX = Path(__file__).parent / "fixtures" / "hello.tex"

@pytest.mark.skipif(shutil.which("latexmk") is None,
                    reason="latexmk not installed")
def test_hello_compiles():
    ok, log = compile_pdf(FIX)
    assert ok, log
