import pytest
from pathlib import Path

from okf_bundle import Bundle, BundleError


def make_bundle(tmp_path: Path, files: dict[str, str]) -> Bundle:
    for rel, content in files.items():
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    return Bundle(tmp_path)


def test_bundle_loads_concepts(tmp_path):
    b = make_bundle(
        tmp_path,
        {
            "index.md": "# Index",
            "hot.md": "# Hot",
            "concepts/a.md": "---\ntype: Concept\n---\n\nA",
            "entities/b.md": "---\ntype: Entity\n---\n\nB",
        },
    )
    assert set(b.concepts) == {"concepts/a", "entities/b"}
    assert b.concepts["concepts/a"].type == "Concept"


def test_bundle_detects_missing_type(tmp_path):
    b = make_bundle(tmp_path, {"concepts/a.md": "# A"})
    assert any("Missing required frontmatter field: type" in err for err in b.errors)


def test_bundle_detects_conflicting_case_ids(tmp_path):
    b = make_bundle(
        tmp_path,
        {
            "concepts/MacOS.md": "---\ntype: Concept\n---\n",
            "concepts/macos.md": "---\ntype: Concept\n---\n",
        },
    )
    assert any("CONFLICTING_ID" in err for err in b.errors)


def test_bundle_error_on_missing_dir(tmp_path):
    with pytest.raises(BundleError):
        Bundle(tmp_path / "does-not-exist")
