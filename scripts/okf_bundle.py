"""OKF bundle loading, enumeration, and traversal utilities."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from okf_frontmatter import FrontmatterError, parse_file, validate_required_type


RESERVED_NAMES = {"index.md", "log.md", "hot.md"}


@dataclass(frozen=True, slots=True)
class Concept:
    id: str
    path: Path
    frontmatter: dict[str, Any]
    body: str
    type: str

    @property
    def title(self) -> str:
        return self.frontmatter.get("title") or self.id.rsplit("/", 1)[-1].replace("-", " ").replace("_", " ")

    @property
    def description(self) -> str | None:
        return self.frontmatter.get("description")

    @property
    def tags(self) -> list[str]:
        tags = self.frontmatter.get("tags") or []
        if isinstance(tags, str):
            return [t.strip() for t in tags.split(",") if t.strip()]
        return [str(t).strip() for t in tags if str(t).strip()]


class Bundle:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self._concepts: dict[str, Concept] = {}
        self._errors: list[str] = []
        self._load()

    def _load(self) -> None:
        if not self.root.is_dir():
            raise BundleError(f"Bundle path is not a directory: {self.root}")

        for path in sorted(self.root.rglob("*.md")):
            rel = path.relative_to(self.root)
            rel_str = rel.as_posix()
            name = rel.name

            # Skip hidden directories (e.g., .git, .obsidian, .okf, .raw)
            if any(part.startswith(".") for part in rel.parts[:-1]):
                continue

            if name.lower() in RESERVED_NAMES:
                # Not a concept document; skip
                continue

            concept_id = rel.with_suffix("").as_posix()
            try:
                parsed = parse_file(path)
                concept_type = validate_required_type(parsed.data)
            except FrontmatterError as exc:
                self._errors.append(f"{rel_str}: {exc}")
                continue
            except Exception as exc:  # pragma: no cover
                self._errors.append(f"{rel_str}: {exc}")
                continue

            if concept_id.lower() in {cid.lower() for cid in self._concepts}:
                self._errors.append(
                    f"{rel_str}: CONFLICTING_ID — duplicates concept ID '{concept_id}' (case-insensitive collision)"
                )
                continue

            self._concepts[concept_id] = Concept(
                id=concept_id,
                path=path,
                frontmatter=parsed.data,
                body=parsed.body,
                type=concept_type,
            )

    @property
    def concepts(self) -> dict[str, Concept]:
        return dict(self._concepts)

    @property
    def errors(self) -> list[str]:
        return list(self._errors)

    def concept_exists(self, concept_id: str) -> bool:
        return any(cid.lower() == concept_id.lower() for cid in self._concepts)

    def get_concept(self, concept_id: str) -> Concept | None:
        for cid, concept in self._concepts.items():
            if cid.lower() == concept_id.lower():
                return concept
        return None

    def index_path(self) -> Path:
        return self.root / "index.md"

    def log_path(self) -> Path:
        return self.root / "log.md"

    def hot_path(self) -> Path:
        return self.root / "hot.md"


class BundleError(Exception):
    pass
