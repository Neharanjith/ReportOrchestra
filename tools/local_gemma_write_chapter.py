#!/usr/bin/env python3
"""Write one chapter of a report using local Ollama generation and TOC/source-guided retrieval."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from local_gemma_synthesize import generate

WORD_RE = re.compile(r"[A-Za-z][A-Za-z0-9_-]{2,}")
MULTISPACE_RE = re.compile(r"\s+")
EMAIL_RE = re.compile(r"\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b")
NUM_RE = re.compile(r"(?<![A-Za-z])[-+]?\d+(?:\.\d+)?(?:e[-+]?\d+)?%?", re.I)
STOPWORDS = {
    'the','and','for','with','from','into','through','using','used','this','that','these','those','are','was','were','been','being',
    'report','section','chapter','study','studies','case','project','results','result','data','method','methods','model','models',
    'approach','approaches','analysis','technical','context','background','objective','motivation','problem','formulation',
    'conclusions','lessons','learned','negative','work','what','did','not','cross','comparison','findings','major','opportunities'
}


def safe_read(path: Path) -> str:
    return path.read_text(errors='replace') if path.exists() else ''


def compact(text: str) -> str:
    return MULTISPACE_RE.sub(' ', text).strip()


def slugify(value: str) -> str:
    value = re.sub(r'[^A-Za-z0-9]+', '_', value).strip('_').lower()
    return value[:80] or 'chapter'


def normalize_guidance(value: str) -> str:
    value = value.strip().strip('`').strip()
    if value.startswith('[') and value.endswith(']'):
        value = value[1:-1].strip()
    return value


def gather_guidance(node: dict) -> list[str]:
    values = list(node.get('source_guidance', []))
    for child in node.get('subsections', []):
        values.extend(gather_guidance(child))
    seen = set()
    result = []
    for value in values:
        norm = normalize_guidance(value)
        if norm and norm not in seen:
            seen.add(norm)
            result.append(norm)
    return result


def chapter_role(title: str) -> str:
    upper = title.strip().upper()
    if upper == 'ACKNOWLEDGMENTS':
        return 'acknowledgments'
    if upper == 'REFERENCES':
        return 'references'
    if upper.startswith('APPENDIX'):
        return 'appendix'
    return 'main'


def chapter_keywords(chapter: dict) -> set[str]:
    text_parts = [chapter.get('section_title', '')]
    text_parts.extend(sub.get('subsection_title', '') for sub in chapter.get('subsections', []))
    text_parts.extend(gather_guidance(chapter))
    tokens = {
        token.lower() for token in WORD_RE.findall(' '.join(text_parts))
        if token.lower() not in STOPWORDS and not token[0].isdigit()
    }
    return tokens


def resolve_guidance(manifest: list[dict], guidance: str) -> list[dict]:
    guidance = normalize_guidance(guidance)
    low = guidance.lower()
    if not guidance:
        return []
    if guidance.endswith('/'):
        prefix = guidance.rstrip('/') + '/'
        matches = [rec for rec in manifest if rec.get('text_path') and rec['path'].startswith(prefix)]
    else:
        matches = [rec for rec in manifest if rec.get('text_path') and rec['path'] == guidance]
        if not matches:
            matches = [rec for rec in manifest if rec.get('text_path') and rec['path'].lower() == low]
        if not matches and '/' not in guidance and '.' not in guidance:
            matches = [rec for rec in manifest if rec.get('text_path') and guidance.lower() in rec['path'].lower()]
    dedup = {}
    for rec in matches:
        dedup[rec['path']] = rec
    return list(dedup.values())


def split_snippets(text: str) -> list[str]:
    if text.startswith('SOURCE_PATH:'):
        parts = text.splitlines()
        text = '\n'.join(parts[2:]) if len(parts) > 2 else text
    blocks = [compact(x) for x in re.split(r'\n\s*\n+', text) if compact(x)]
    snippets: list[str] = []
    for block in blocks:
        if len(block) <= 1600:
            snippets.append(block)
            continue
        sentences = re.split(r'(?<=[.!?])\s+', block)
        current = ''
        for sent in sentences:
            if not sent:
                continue
            if len(current) + len(sent) + 1 <= 1100:
                current = (current + ' ' + sent).strip()
            else:
                if current:
                    snippets.append(current)
                current = sent.strip()
        if current:
            snippets.append(current)
    return [s for s in snippets if len(s) >= 90]


def score_snippet(snippet: str, path: str, keywords: set[str]) -> int:
    low = snippet.lower()
    path_low = path.lower()
    score = 0
    score += 5 * sum(1 for key in keywords if key in low)
    score += 2 * sum(1 for key in keywords if key in path_low)
    score += 3 if NUM_RE.search(snippet) else 0
    score += 2 if any(word in low for word in ['experiment', 'dataset', 'training', 'architecture', 'failure', 'metric', 'implementation']) else 0
    if 'source_path:' in low:
        score -= 2
    if len(snippet) > 1450:
        score -= 1
    return score


def build_evidence_packet(ws: Path, chapter: dict, max_sources: int = 12, max_snippets_per_source: int = 2, max_total_chars: int = 45000) -> tuple[str, dict]:
    manifest = json.loads((ws / 'corpus/manifest.json').read_text())
    corpus_dir = ws / 'corpus'
    guidance = gather_guidance(chapter)
    keywords = chapter_keywords(chapter)
    matched: dict[str, dict] = {}
    for item in guidance:
        for rec in resolve_guidance(manifest, item):
            matched[rec['path']] = rec

    ranked_sources = []
    for rec in matched.values():
        text = safe_read(corpus_dir / rec['text_path'])
        snippets = sorted(split_snippets(text), key=lambda s: score_snippet(s, rec['path'], keywords), reverse=True)
        snippets = [EMAIL_RE.sub('[EMAIL REDACTED]', s) for s in snippets if score_snippet(s, rec['path'], keywords) > 0][:max_snippets_per_source]
        if not snippets:
            continue
        source_score = max(score_snippet(s, rec['path'], keywords) for s in snippets)
        ranked_sources.append((source_score, rec, snippets))

    ranked_sources.sort(key=lambda item: (item[0], item[1].get('text_chars', 0)), reverse=True)
    ranked_sources = ranked_sources[:max_sources]

    total_chars = 0
    blocks = []
    stats = Counter()
    for _, rec, snippets in ranked_sources:
        snippet_lines = []
        for snippet in snippets:
            if total_chars + len(snippet) > max_total_chars:
                continue
            total_chars += len(snippet)
            snippet_lines.append(f"- [UNVERIFIED EXTRACT] {snippet}")
            stats['snippets'] += 1
        if not snippet_lines:
            continue
        stats['sources'] += 1
        blocks.append(
            f"### Source: `{rec['path']}`\n"
            f"SHA-256: `{rec['sha256']}`\n\n"
            + '\n'.join(snippet_lines)
        )

    packet = (
        f"# Chapter Evidence Packet\n\n"
        f"Chapter: `{chapter['section_title']}`\n\n"
        f"## Source guidance\n" + '\n'.join(f"- `{item}`" for item in guidance[:60]) + "\n\n"
        f"## Retrieved source-linked extracts\n\n" + ('\n\n'.join(blocks) if blocks else '_No retrieved text-bearing sources matched._') + '\n'
    )
    return packet, {'guidance_count': len(guidance), **stats}


def load_refs(ws: Path) -> str:
    for candidate in [ws / 'refs.bib', ws / 'drafts/refs.bib', ws / 'drafts/References.bib']:
        if candidate.exists():
            return candidate.read_text(errors='replace')
    return ''


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--workspace', type=Path, required=True)
    parser.add_argument('--chapter-index', type=int, required=True, help='1-based index in outline.json section_plan')
    parser.add_argument('--model', default='gemma4:e2b')
    parser.add_argument('--max-sources', type=int, default=12)
    parser.add_argument('--max-snippets-per-source', type=int, default=2)
    args = parser.parse_args()

    ws = args.workspace.resolve()
    outline = json.loads((ws / 'outline.json').read_text())
    section_plan = outline['section_plan']
    if args.chapter_index < 1 or args.chapter_index > len(section_plan):
        raise SystemExit(f'chapter-index must be between 1 and {len(section_plan)}')
    chapter = section_plan[args.chapter_index - 1]
    role = chapter_role(chapter['section_title'])
    if role == 'references':
        raise SystemExit('References chapter is not written; bibliography is assembled separately.')

    authors_note = safe_read(ws / 'inputs/authors_note.md')
    synthesis = safe_read(ws / 'gemma/gemma_synthesis.md')
    refs = load_refs(ws)
    captions = safe_read(ws / 'figures/captions.json')
    packet, packet_stats = build_evidence_packet(
        ws,
        chapter,
        max_sources=args.max_sources,
        max_snippets_per_source=args.max_snippets_per_source,
    )

    prompt = f"""## Strict Knowledge Isolation & Anonymity
Write exclusively from the supplied materials. Do not use outside knowledge,
invent results, identify authors or institutions, or add affiliations/emails.

You are writing ONE part of a technical report in LaTeX.
Return ONLY compilable LaTeX for the requested part.
Do not include a document preamble, title page, bibliography, or \\begin{{document}} / \\end{{document}}.

Role: {role}

Instructions by role:
- If role is `main` or `appendix`, write the chapter body beginning with the appropriate \\chapter{{...}} command and include section/subsection structure that follows the supplied outline.
- If role is `acknowledgments`, return only a complete \\begin{{acknowledgments}} ... \\end{{acknowledgments}} block.

Global requirements:
- Follow the supplied chapter outline and subsection structure.
- Use the retrieved chapter evidence packet as the primary source grounding.
- Use the global synthesis only for consistency and cross-project context.
- Keep all numerical claims marked as unverified unless directly supported in the supplied evidence.
- Preserve source distinctions: completed experiments, implementation artifacts, plans, literature, failures, unresolved claims.
- Cite only BibTeX keys present in the supplied bibliography.
- Prefer dense technical prose over bullet lists except where a compact table/list is clearly better.
- Do not write any other chapters.

<chapter_outline>
{json.dumps(chapter, indent=2)}
</chapter_outline>
<authors_note>
{authors_note or '[none]'}
</authors_note>
<chapter_evidence_packet>
{packet}
</chapter_evidence_packet>
<global_synthesis>
{synthesis}
</global_synthesis>
<figure_captions>
{captions}
</figure_captions>
<available_bibliography>
{refs}
</available_bibliography>
"""

    rendered = generate(args.model, prompt)
    if '```latex' in rendered:
        rendered = rendered.split('```latex', 1)[1].split('```', 1)[0]
    elif '```' in rendered:
        rendered = rendered.split('```', 1)[1].split('```', 1)[0]
    rendered = rendered.strip() + '\n'

    drafts = ws / 'drafts'
    chapters_dir = drafts / 'chapters'
    evidence_dir = drafts / 'chapter_evidence'
    chapters_dir.mkdir(parents=True, exist_ok=True)
    evidence_dir.mkdir(parents=True, exist_ok=True)

    filename = f"{args.chapter_index:02d}_{slugify(chapter['section_title'])}.tex"
    output_path = chapters_dir / filename
    output_path.write_text(rendered, encoding='utf-8')
    (evidence_dir / filename.replace('.tex', '.md')).write_text(packet, encoding='utf-8')

    manifest_path = drafts / 'chapter_manifest.json'
    manifest = []
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
    entry = {
        'chapter_index': args.chapter_index,
        'chapter_title': chapter['section_title'],
        'role': role,
        'output': str(output_path.relative_to(drafts)),
        'evidence_packet': str((evidence_dir / filename.replace('.tex', '.md')).relative_to(drafts)),
        'packet_stats': packet_stats,
    }
    manifest = [item for item in manifest if item.get('chapter_index') != args.chapter_index]
    manifest.append(entry)
    manifest.sort(key=lambda item: item['chapter_index'])
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')

    print(json.dumps(entry, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
