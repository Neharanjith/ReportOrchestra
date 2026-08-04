#!/usr/bin/env python3
"""Dispatch between normal whole-paper writing and TOC-triggered chapter writing."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def toc_included(authors_note: str) -> bool:
    return 'toc_included: true' in authors_note.lower()


def chapter_role(title: str) -> str:
    upper = title.strip().upper()
    if upper == 'REFERENCES':
        return 'references'
    if upper == 'ACKNOWLEDGMENTS':
        return 'acknowledgments'
    if upper.startswith('APPENDIX'):
        return 'appendix'
    return 'main'


def run(cmd: list[str], cwd: Path) -> None:
    subprocess.run(cmd, cwd=str(cwd), check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--workspace', type=Path, required=True)
    parser.add_argument('--model', default='gemma4:e2b')
    args = parser.parse_args()

    ws = args.workspace.resolve()
    tools_dir = Path(__file__).resolve().parent
    authors_note = (ws / 'inputs/authors_note.md').read_text(errors='replace') if (ws / 'inputs/authors_note.md').exists() else ''

    if not toc_included(authors_note):
        run([sys.executable, str(tools_dir / 'local_gemma_write_paper.py'), '--workspace', str(ws), '--model', args.model], tools_dir.parent)
        print('mode=normal')
        return 0

    outline = json.loads((ws / 'outline.json').read_text())
    for index, chapter in enumerate(outline.get('section_plan', []), 1):
        if chapter_role(chapter['section_title']) == 'references':
            continue
        run([
            sys.executable,
            str(tools_dir / 'local_gemma_write_chapter.py'),
            '--workspace', str(ws),
            '--chapter-index', str(index),
            '--model', args.model,
        ], tools_dir.parent)

    run([sys.executable, str(tools_dir / 'assemble_chaptered_paper.py'), '--workspace', str(ws)], tools_dir.parent)
    print('mode=chaptered')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
