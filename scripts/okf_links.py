"""Link extraction and resolution for OKF bundles."""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True, slots=True)
class Link:
    raw: str
    target: str
    kind: str  # "markdown" or "wikilink"
    label: str

    def is_external(self) -> bool:
        """Return True if target is not a relative concept path."""
        if not self.target:
            return False
        if self.target.startswith(("http://", "https://", "mailto:", "file://")):
            return True
        if self.target.startswith("#") or self.target.startswith("/"):
            # Absolute root paths are external unless we choose to resolve them;
            # OKF uses relative paths, so treat absolute as external.
            return True
        return False


_MARKDOWN_LINK_RE = re.compile(r"!?\[([^\]]*)\]\(([^)]+)\)")
_WIKILINK_RE = re.compile(r"\[\[([^\]|]+)(?:\|([^\]]*))?\]\]")


def extract_markdown_links(text: str) -> Iterable[Link]:
    """Extract standard markdown links from text."""
    for match in _MARKDOWN_LINK_RE.finditer(text):
        label, target = match.groups()
        # Strip surrounding whitespace / angle brackets
        target = target.strip().strip("<>").split(" ")[0]
        yield Link(raw=match.group(0), target=target, kind="markdown", label=label)


def extract_wikilinks(text: str) -> Iterable[Link]:
    """Extract Obsidian wikilinks from text."""
    for match in _WIKILINK_RE.finditer(text):
        target, label = match.groups()
        yield Link(raw=match.group(0), target=target.strip(), kind="wikilink", label=(label or target).strip())


def extract_all(text: str) -> list[Link]:
    """Extract both markdown and wikilink targets."""
    return list(extract_markdown_links(text)) + list(extract_wikilinks(text))


def resolve_link(link: Link, source_concept_id: str, existing_ids: set[str]) -> str | None:
    """Return normalized concept ID if internal target exists, otherwise None.

    For markdown relative links, resolve relative to source concept directory.
    For wikilinks, try exact match first, then case-insensitive match.
    """
    if link.is_external():
        # Not a concept link we validate
        return None

    target = link.target
    if link.kind == "markdown":
        # Strip .md extension and any fragment
        if "#" in target:
            target = target.split("#", 1)[0]
        target = target.removesuffix(".md")

        if target.startswith("./") or target.startswith("../") or "/" in target or not target.startswith("/"):
            # Resolve relative to source concept location
            source_parts = source_concept_id.split("/")
            joined = "/".join(source_parts[:-1]) + "/" + target if source_parts else target
            # Normalize .. and .
            normalized = _normalize_path(joined)
            return _find_existing(normalized, existing_ids)

    # Wikilink or bare name
    # Try exact, then case-insensitive, then basename match across existing ids
    candidates = [
        target,
        target.removeprefix("/").removesuffix(".md"),
        _normalize_path(target),
    ]
    if " " in target:
        candidates.append(target.replace(" ", "-").lower())

    for candidate in candidates:
        exact = _find_existing(candidate, existing_ids)
        if exact:
            return exact

    # Wikilink bare name: match against basename of existing concepts
    target_lower = target.lower()
    for cid in existing_ids:
        basename = cid.rsplit("/", 1)[-1].lower()
        if basename == target_lower or basename == target_lower.replace(" ", "-"):
            return _find_existing(cid, existing_ids)
    return None


def _normalize_path(path: str) -> str:
    parts: list[str] = []
    for part in path.replace("\\", "/").split("/"):
        if part == ".." and parts:
            parts.pop()
        elif part and part != ".":
            parts.append(part)
    return "/".join(parts).lower()


def _find_existing(concept_id: str, existing_ids: set[str]) -> str | None:
    if concept_id in existing_ids:
        return concept_id
    lower = concept_id.lower()
    for cid in existing_ids:
        if cid.lower() == lower:
            return cid
    return None
