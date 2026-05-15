from src.agents.indexer import chunk_notebook

def test_simple_split():
    md = "# A\nalpha\n\n# B\nbeta\n\n## B.1\nbeta one"
    chunks = chunk_notebook(md, max_tokens=10000)
    assert len(chunks) == 3
    assert chunks[0]["header_path"] == ["# A"]
    assert "alpha" in chunks[0]["text"]
    assert chunks[2]["header_path"] == ["# B", "## B.1"]

def test_oversize_split():
    big = "# Big\n\n" + "\n\n".join(["para " * 200 for _ in range(5)])
    chunks = chunk_notebook(big, max_tokens=300)
    assert len(chunks) > 1
