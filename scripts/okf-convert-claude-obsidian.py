#!/usr/bin/env python3
"""Convert a claude-obsidian vault to an OKF bundle."""
from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from okf_frontmatter import render


FOLDER_TYPE_MAP = {
    "concepts": "Concept",
    "entities": "Entity",
    "guides": "Guide",
    "homelab": "Decision",
    "meta": "Decision",
    "questions": "Question",
    "references": "Reference",
    "sources": "Source",
}

_TAG_RE = re.compile(r"#([A-Za-z0-9_-]+)")


def _slugify(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "-", name).strip("-").lower()


def _extract_title(body: str, filename: str) -> str:
    match = re.search(r"^#\s+(.+?)$", body, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return filename.replace("-", " ").replace("_", " ")


def _extract_description(body: str) -> str | None:
    lines = [line.strip() for line in body.splitlines() if line.strip()]
    for line in lines:
        if line.startswith("#"):
            continue
        return line[:200]
    return None


def _extract_tags(body: str, existing_tags: list[str] | None) -> list[str]:
    tags = list(existing_tags) if existing_tags else []
    tags.extend(_TAG_RE.findall(body))
    return list(dict.fromkeys(tags))  # preserve order, dedupe


def _timestamp_fallback(path: Path) -> str:
    mtime = path.stat().st_mtime
    return datetime.fromtimestamp(mtime, tz=timezone.utc).isoformat()


def _convert_file(src: Path, dest_root: Path, rel_dir: Path, dry_run: bool) -> dict | None:
    text = src.read_text(encoding="utf-8")

    # Very simple frontmatter extraction; if present, preserve it
    if text.lstrip().startswith("---"):
        parts = text.split("---", 2)
        if len(parts) >= 3:
            body = parts[2].lstrip("\n")
        else:
            body = text
    else:
        body = text

    folder = rel_dir.parts[0] if rel_dir.parts else ""
    default_type = FOLDER_TYPE_MAP.get(folder, "Concept")
    filename = src.stem

    title = _extract_title(body, filename)
    description = _extract_description(body)
    tags = _extract_tags(body, None)
    timestamp = _timestamp_fallback(src)

    frontmatter = {
        "type": default_type,
        "title": title,
        "description": description,
        "tags": tags,
        "timestamp": timestamp,
    }

    dest_rel = rel_dir / f"{_slugify(filename)}.md"
    dest_path = dest_root / dest_rel

    if dry_run:
        return {
            "dest": dest_path,
            "frontmatter": frontmatter,
        }

    dest_path.parent.mkdir(parents=True, exist_ok=True)
    dest_path.write_text(render(frontmatter, body), encoding="utf-8")
    return {"dest": dest_path, "frontmatter": frontmatter}


def convert_vault(source: Path, dest: Path, *, dry_run: bool) -> list[dict]:
    source = source.expanduser().resolve()
    dest = dest.expanduser().resolve()

    wiki_root = source / "wiki" if (source / "wiki").is_dir() else source

    results: list[dict] = []
    for md_path in sorted(wiki_root.rglob("*.md")):
        rel = md_path.relative_to(wiki_root)
        if any(part.startswith(".") for part in rel.parts[:-1]):
            continue
        if rel.name.lower() in {"index.md", "log.md", "hot.md"}:
            continue

        converted = _convert_file(md_path, dest, rel.parent, dry_run)
        if converted:
            results.append(converted)

    if not dry_run:
        # Create OKF index/log/hot from claude-obsidian ones if present
        if (wiki_root / "index.md").exists():
            (dest / "index.md").write_text((wiki_root / "index.md").read_text(encoding="utf-8"), encoding="utf-8")
        else:
            (dest / "index.md").write_text(f"# {dest.name}\n\nConverted from claude-obsidian vault.\n", encoding="utf-8")
        if (wiki_root / "log.md").exists():
            (dest / "log.md").write_text((wiki_root / "log.md").read_text(encoding="utf-8"), encoding="utf-8")
        else:
            (dest / "log.md").write_text("# Log\n\nConverted vault.\n", encoding="utf-8")
        if (wiki_root / "hot.md").exists():
            (dest / "hot.md").write_text((wiki_root / "hot.md").read_text(encoding="utf-8"), encoding="utf-8")

    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert a claude-obsidian vault to OKF")
    parser.add_argument("--source", required=True, help="Source claude-obsidian vault path")
    parser.add_argument("--dest", required=True, help="Destination OKF bundle path")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing")
    args = parser.parse_args()

    dest = Path(args.dest).expanduser().resolve()
    if not args.dry_run and dest.exists() and any(dest.iterdir()):
        print(f"Error: destination is not empty: {dest}", file=sys.stderr)
        return 1

    results = convert_vault(Path(args.source), dest, dry_run=args.dry_run)

    for result in results[:10]:
        print(f"{'WOULD CREATE' if args.dry_run else 'CREATED'}: {result['dest']}")
    if len(results) > 10:
        print(f"... and {len(results) - 10} more")

    print(f"\nTotal concepts: {len(results)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
