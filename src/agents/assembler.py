"""NRL-template-aware Assembler.

Replaces PLACEHOLDER lines within the existing \chapter{} / \section{}
structure of the NRL template. Each PLACEHOLDER is identified by the
chapter or section heading that precedes it, per nrl_template_mapping.yaml.

Key NRL requirements handled here:
- \chapter{} hierarchy: content is inserted at \section{} level and below.
- \begin{executivesummary} and \begin{acknowledgments} environments.
- verified.bib is copied to References.bib to match \bibliography{References}.
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
    next \chapter{} or \section{} boundary. Returns tex unchanged if the
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
    """Replace the body inside \begin{env_name}...\end{env_name}.

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
