"""OKF frontmatter parsing and validation utilities."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


class FrontmatterError(Exception):
    """Raised when frontmatter is malformed or invalid."""

    def __init__(self, message: str, *, line: int | None = None):
        super().__init__(message)
        self.message = message
        self.line = line

    def __str__(self) -> str:
        if self.line is not None:
            return f"{self.message} (around line {self.line})"
        return self.message


@dataclass(frozen=True, slots=True)
class Frontmatter:
    data: dict[str, Any]
    body: str


def split_frontmatter(text: str) -> tuple[str | None, str]:
    """Split text into frontmatter YAML block and body."""
    if not text.lstrip().startswith("---"):
        return None, text

    lines = text.splitlines(keepends=True)
    # First line must be ---
    first = lines[0].lstrip()
    if not first.startswith("---"):
        return None, text

    end_index: int | None = None
    for i, line in enumerate(lines[1:], start=2):
        if line.rstrip() == "---":
            end_index = i
            break

    if end_index is None:
        raise FrontmatterError("Frontmatter start marker '---' found but no closing marker")

    fm_lines = lines[1 : end_index - 1]
    body_lines = lines[end_index:]
    return "".join(fm_lines), "".join(body_lines).lstrip("\n")


def parse(text: str) -> Frontmatter:
    """Parse a markdown concept file into frontmatter + body."""
    raw_fm, body = split_frontmatter(text)
    if raw_fm is None:
        return Frontmatter(data={}, body=body)

    try:
        data = yaml.safe_load(raw_fm) or {}
    except yaml.YAMLError as exc:
        line = getattr(exc, "problem_mark", None)
        line_no = line.line + 1 if line else None
        raise FrontmatterError(f"Malformed YAML frontmatter: {exc}", line=line_no) from exc

    if not isinstance(data, dict):
        raise FrontmatterError("Frontmatter must be a YAML mapping")

    return Frontmatter(data=data, body=body)


def parse_file(path: Path) -> Frontmatter:
    """Parse a concept file from disk."""
    return parse(path.read_text(encoding="utf-8"))


def validate_required_type(data: dict[str, Any]) -> str:
    """Return the concept type, or raise if missing/blank."""
    if "type" not in data:
        raise FrontmatterError("Missing required frontmatter field: type")
    value = data["type"]
    if value is None or (isinstance(value, str) and value.strip() == ""):
        raise FrontmatterError("Required frontmatter field 'type' is blank")
    if not isinstance(value, str):
        raise FrontmatterError("Frontmatter field 'type' must be a string")
    return value.strip()


def render(data: dict[str, Any], body: str) -> str:
    """Render frontmatter + body back to markdown text."""
    fm = yaml.safe_dump(data, sort_keys=False, allow_unicode=True, default_flow_style=False)
    return f"---\n{fm}---\n\n{body}"
