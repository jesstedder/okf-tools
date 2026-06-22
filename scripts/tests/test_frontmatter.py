import pytest
from okf_frontmatter import FrontmatterError, parse, render


def test_parse_no_frontmatter():
    text = "# Hello\n\nBody"
    fm = parse(text)
    assert fm.data == {}
    assert fm.body == "# Hello\n\nBody"


def test_parse_frontmatter_and_body():
    text = """---
type: Concept
title: Hello World
tags: [foo, bar]
---

# Hello World

Body here.
"""
    fm = parse(text)
    assert fm.data == {"type": "Concept", "title": "Hello World", "tags": ["foo", "bar"]}
    assert fm.body.startswith("# Hello World")


def test_missing_close_marker():
    text = "---\ntype: Concept\n# Hello"
    with pytest.raises(FrontmatterError, match="no closing marker"):
        parse(text)


def test_malformed_yaml():
    text = "---\ntype: : bad\n---\n"
    with pytest.raises(FrontmatterError, match="Malformed YAML"):
        parse(text)


def test_render_roundtrip():
    data = {"type": "Concept", "title": "T"}
    body = "Hello"
    text = render(data, body)
    fm = parse(text)
    assert fm.data["type"] == "Concept"
    assert "Hello" in fm.body
