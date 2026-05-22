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
    """Distribution statement is inserted immediately after \begin{document}."""
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
    """Diagrams not embedded in any section content land before \end{document}."""
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
