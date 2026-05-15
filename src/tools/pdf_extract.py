"""Extract text from PDFs using PyMuPDF."""
from pathlib import Path
import fitz  # PyMuPDF

def extract_text(pdf_path) -> str:
    doc = fitz.open(str(pdf_path))
    try:
        return "\n\n".join(page.get_text() for page in doc)
    finally:
        doc.close()
