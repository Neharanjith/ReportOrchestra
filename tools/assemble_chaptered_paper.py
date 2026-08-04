#!/usr/bin/env python3
"""Assemble a single LaTeX paper from chapter files produced by local_gemma_write_chapter.py."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


BIB_RE = re.compile(r'\\bibliography\{[^}]+\}')
ENDDOC_RE = re.compile(r'\\end\{document\}')


def safe_read(path: Path) -> str:
    return path.read_text(errors='replace') if path.exists() else ''


def find_prefix(scaffold: str) -> str:
    candidates = []
    for marker in [r'\\chapter\{', r'\\begin\{acknowledgments\}', r'\\bibliography\{', r'\\appendix', r'\\end\{document\}']:
        match = re.search(marker, scaffold)
        if match:
            candidates.append(match.start())
    return scaffold[:min(candidates)] if candidates else scaffold


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--workspace', type=Path, required=True)
    parser.add_argument('--scaffold', type=Path)
    parser.add_argument('--manifest', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()

    ws = args.workspace.resolve()
    drafts = ws / 'drafts'
    manifest_path = args.manifest.resolve() if args.manifest else drafts / 'chapter_manifest.json'
    if not manifest_path.exists():
        raise SystemExit(f'manifest not found: {manifest_path}')
    manifest = json.loads(manifest_path.read_text())

    scaffold_path = args.scaffold.resolve() if args.scaffold else drafts / 'paper.tex'
    if not scaffold_path.exists():
        raise SystemExit('A scaffold paper.tex is required (default: workspace/drafts/paper.tex).')
    scaffold = safe_read(scaffold_path)
    prefix = find_prefix(scaffold)

    bibliography_cmd = '\\bibliography{References}'
    bib_match = BIB_RE.search(scaffold)
    if bib_match:
        bibliography_cmd = bib_match.group(0)

    output_path = args.output.resolve() if args.output else drafts / 'paper.tex'

    mains = [item for item in manifest if item['role'] == 'main']
    acks = [item for item in manifest if item['role'] == 'acknowledgments']
    apps = [item for item in manifest if item['role'] == 'appendix']

    def input_line(entry: dict) -> str:
        return f"\\input{{{entry['output'].replace('\\\\', '/').replace('.tex', '')}}}"

    pieces = [prefix.rstrip(), '']
    pieces.extend(input_line(entry) for entry in mains)
    pieces.append('')
    for entry in acks:
        pieces.append(input_line(entry))
        pieces.append('')
    pieces.append(bibliography_cmd)
    pieces.append('')
    if apps:
        pieces.append('\\appendix')
        pieces.append('')
        pieces.extend(input_line(entry) for entry in apps)
        pieces.append('')
    pieces.append('\\end{document}')

    output_path.write_text('\n'.join(pieces) + '\n', encoding='utf-8')
    print(output_path)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
