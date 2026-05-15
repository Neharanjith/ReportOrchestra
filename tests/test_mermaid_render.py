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
