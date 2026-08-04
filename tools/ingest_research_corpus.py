#!/usr/bin/env python3
"""Create a provenance-tracked text corpus from a mixed research archive."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree

TEXT_EXTS = {
    ".md", ".txt", ".py", ".json", ".yaml", ".yml", ".toml", ".csv",
    ".tex", ".bib", ".log", ".sh", ".jl", ".html", ".mhtml",
}
OFFICE_EXTS = {".docx", ".pptx", ".xlsx"}
MAX_TEXT_BYTES = 2_000_000


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def clean_xml_text(data: bytes) -> str:
    root = ElementTree.fromstring(data)
    pieces = []
    for node in root.iter():
        if node.text and node.tag.rsplit("}", 1)[-1] in {"t", "p", "tab", "br"}:
            pieces.append(node.text)
    return "\n".join(pieces)


def office_text(path: Path) -> str:
    patterns = {
        ".docx": re.compile(r"word/(document|header\\d+|footer\\d+|footnotes|endnotes)\\.xml$"),
        ".pptx": re.compile(r"ppt/(slides/slide\\d+|notesSlides/notesSlide\\d+)\\.xml$"),
        ".xlsx": re.compile(r"xl/(sharedStrings|worksheets/sheet\\d+)\\.xml$"),
    }
    chunks = []
    with zipfile.ZipFile(path) as archive:
        for name in sorted(archive.namelist()):
            if patterns[path.suffix.lower()].match(name):
                try:
                    chunks.append(f"\n--- {name} ---\n{clean_xml_text(archive.read(name))}")
                except ElementTree.ParseError:
                    continue
    return "\n".join(chunks)


def pdf_text(path: Path) -> str:
    result = subprocess.run(
        ["pdftotext", "-layout", str(path), "-"],
        check=False, capture_output=True, text=True, errors="replace",
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "pdftotext failed")
    return result.stdout


def nested_zip_listing(path: Path) -> str:
    with zipfile.ZipFile(path) as archive:
        rows = [
            f"{item.file_size}\t{item.CRC:08x}\t{item.filename}"
            for item in archive.infolist()
        ]
    return "Nested ZIP inventory (size, CRC32, path):\n" + "\n".join(rows)


def extract_text(path: Path) -> tuple[str, str]:
    suffix = path.suffix.lower()
    if suffix in TEXT_EXTS:
        data = path.read_bytes()[:MAX_TEXT_BYTES]
        note = "\n[TRUNCATED AT 2,000,000 BYTES]\n" if path.stat().st_size > len(data) else ""
        return data.decode("utf-8", errors="replace") + note, "text"
    if suffix in OFFICE_EXTS:
        return office_text(path), "office_xml"
    if suffix == ".pdf":
        return pdf_text(path), "pdftotext"
    if suffix == ".zip":
        return nested_zip_listing(path), "nested_zip_inventory"
    return "", "metadata_only"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    source = args.source.resolve()
    out = args.out.resolve()
    text_dir = out / "text"
    text_dir.mkdir(parents=True, exist_ok=True)

    manifest = []
    methods = Counter()
    for index, path in enumerate(sorted(p for p in source.rglob("*") if p.is_file()), 1):
        relative = path.relative_to(source)
        record = {
            "path": str(relative),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
            "extension": path.suffix.lower() or "[none]",
        }
        try:
            text, method = extract_text(path)
            record["method"] = method
            record["text_chars"] = len(text)
            if text.strip():
                target = text_dir / f"{index:04d}.txt"
                target.write_text(
                    f"SOURCE_PATH: {relative}\nSOURCE_SHA256: {record['sha256']}\n\n{text}",
                    encoding="utf-8",
                )
                record["text_path"] = str(target.relative_to(out))
        except Exception as error:
            record["method"] = "error"
            record["error"] = str(error)
        methods[record["method"]] += 1
        manifest.append(record)

    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    summary = {
        "source": str(source),
        "files": len(manifest),
        "source_bytes": sum(item["bytes"] for item in manifest),
        "methods": dict(methods),
        "text_files": sum("text_path" in item for item in manifest),
        "text_chars": sum(item.get("text_chars", 0) for item in manifest),
        "errors": [item for item in manifest if item["method"] == "error"],
    }
    (out / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
