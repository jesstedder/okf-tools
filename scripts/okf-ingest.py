#!/usr/bin/env python3
"""Ingest a source file or URL into an OKF bundle as a typed concept."""
from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parent))

from okf_bundle import Bundle
from okf_frontmatter import parse_file, render

try:
    from markdownify import markdownify as md
except ImportError:  # pragma: no cover
    md = None


def _slugify(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "-", name).strip("-").lower()


def _extract_title(body: str, fallback: str) -> str:
    match = re.search(r"^#\s+(.+?)$", body, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return fallback


def _extract_description(body: str) -> str | None:
    lines = [line.strip() for line in body.splitlines() if line.strip()]
    for line in lines:
        if line.startswith("#"):
            continue
        return line[:200]
    return None


def _fetch_url(url: str) -> tuple[str, str]:
    req = Request(url, headers={"User-Agent": "okf-ingest/0.1"})
    with urlopen(req, timeout=30) as resp:
        content_type = resp.headers.get("Content-Type", "").lower()
        data = resp.read()

    # Try to detect encoding
    encoding = "utf-8"
    if "charset=" in content_type:
        encoding = content_type.split("charset=")[-1].split(";")[0].strip()

    text = data.decode(encoding, errors="replace")
    return text, content_type


def _html_to_markdown(html: str) -> str:
    if md is None:
        raise RuntimeError("markdownify is required to convert HTML; install with `uv sync`")
    return md(html, heading_style="ATX")


def _load_source(source: str) -> tuple[str, str, str]:
    """Return (body, source_label, mime-ish content_type)."""
    if source.startswith(("http://", "https://")):
        text, content_type = _fetch_url(source)
        if "html" in content_type:
            text = _html_to_markdown(text)
        return text, source, content_type

    path = Path(source).expanduser().resolve()
    if not path.exists():
        raise FileNotFoundError(f"Source not found: {path}")
    text = path.read_text(encoding="utf-8")
    content_type = "text/markdown"
    if path.suffix.lower() in {".html", ".htm"}:
        text = _html_to_markdown(text)
        content_type = "text/html"
    return text, str(path), content_type


def _find_existing_by_resource(bundle: Bundle, resource: str) -> Path | None:
    for concept in bundle.concepts.values():
        if concept.frontmatter.get("resource") == resource:
            return concept.path
    return None


def _update_index(root: Path, concept_rel: str, title: str) -> None:
    index_path = root / "index.md"
    if not index_path.exists():
        index_path.write_text(f"# {root.name}\n\n", encoding="utf-8")

    content = index_path.read_text(encoding="utf-8")
    link_line = f"- [{title}]({concept_rel})"
    if concept_rel in content or title in content:
        return
    content = content.rstrip() + "\n" + link_line + "\n"
    index_path.write_text(content, encoding="utf-8")


def _append_log(root: Path, concept_rel: str, title: str, source: str) -> None:
    log_path = root / "log.md"
    if not log_path.exists():
        log_path.write_text("# Log\n\n", encoding="utf-8")

    now = datetime.now(timezone.utc).isoformat()
    entry = f"## {now}\n- Ingested [{title}]({concept_rel}) from `{source}`\n\n"
    content = log_path.read_text(encoding="utf-8").rstrip() + "\n" + entry
    log_path.write_text(content, encoding="utf-8")


def ingest(
    bundle_path: Path,
    source: str,
    concept_type: str,
    *,
    concept_id: str | None = None,
    title: str | None = None,
    tags: list[str] | None = None,
) -> Path:
    bundle = Bundle(bundle_path)

    # Idempotency: update existing concept if same resource
    existing_path = _find_existing_by_resource(bundle, source)
    if existing_path:
        target_path = existing_path
        is_update = True
    else:
        if concept_id is None:
            slug = _slugify(title or Path(source).stem or urlparse(source).path.split("/")[-1] or "ingested")
            concept_id = f"{concept_type.lower()}s/{slug}" if concept_type.lower() != "source" else f"sources/{slug}"
        target_path = bundle_path / f"{concept_id}.md"
        target_path.parent.mkdir(parents=True, exist_ok=True)
        is_update = False

    body, source_label, _ = _load_source(source)
    final_title = title or _extract_title(body, target_path.stem.replace("-", " "))
    description = _extract_description(body)

    frontmatter = {
        "type": concept_type,
        "title": final_title,
        "description": description,
        "resource": source,
        "tags": tags or [],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    target_path.write_text(render(frontmatter, body), encoding="utf-8")

    concept_rel = target_path.relative_to(bundle_path).as_posix()
    _update_index(bundle_path, concept_rel, final_title)
    _append_log(bundle_path, concept_rel, final_title, source)

    action = "Updated" if is_update else "Created"
    print(f"{action}: {target_path}")
    return target_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Ingest a source into an OKF bundle")
    parser.add_argument("--bundle", required=True, help="Path to OKF bundle")
    parser.add_argument("--source", required=True, help="File path or URL to ingest")
    parser.add_argument("--type", required=True, help="OKF concept type")
    parser.add_argument("--id", help="Concept ID (relative path without .md)")
    parser.add_argument("--title", help="Override title")
    parser.add_argument("--tags", help="Comma-separated tags")
    args = parser.parse_args()

    tags = [t.strip() for t in args.tags.split(",") if t.strip()] if args.tags else None
    ingest(
        Path(args.bundle).expanduser().resolve(),
        args.source,
        args.type,
        concept_id=args.id,
        title=args.title,
        tags=tags,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
