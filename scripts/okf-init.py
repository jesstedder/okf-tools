#!/usr/bin/env python3
"""Scaffold a new OKF bundle."""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from okf_frontmatter import render


TODAY = datetime.now(timezone.utc).strftime("%Y-%m-%d")


def index_content(name: str) -> str:
    return f"""# {name}

Bundle overview. Add links to concepts below.
"""


def log_content() -> str:
    return f"""# Log

## {TODAY}
- Created OKF bundle.
"""


def hot_content() -> str:
    return """# Hot

Recent context and quick notes go here. This file is read first by `okf-query`.
"""


def types_content() -> str:
    return """# OKF Type Registry

Default types used in this bundle:
- Concept
- Entity
- Guide
- Reference
- Source
- Decision
- Question
- Log
"""


def init_bundle(path: Path, name: str | None = None) -> None:
    path.mkdir(parents=True, exist_ok=True)
    name = name or path.name

    (path / "index.md").write_text(index_content(name), encoding="utf-8")
    (path / "log.md").write_text(log_content(), encoding="utf-8")
    (path / "hot.md").write_text(hot_content(), encoding="utf-8")

    example_fm = {
        "type": "Concept",
        "title": f"{name} starter concept",
        "description": "An example concept to get started.",
        "tags": ["example"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    example_body = "# Starter Concept\n\nReplace this with real content."
    (path / "concepts").mkdir(exist_ok=True)
    (path / "concepts" / "starter-concept.md").write_text(
        render(example_fm, example_body), encoding="utf-8"
    )

    (path / ".okf").mkdir(exist_ok=True)
    (path / ".okf" / "types.md").write_text(types_content(), encoding="utf-8")

    print(f"Created OKF bundle at {path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Scaffold a new OKF bundle")
    parser.add_argument("path", help="Directory to create")
    parser.add_argument("--name", help="Display name for the bundle")
    args = parser.parse_args()

    target = Path(args.path).expanduser().resolve()
    if target.exists() and any(target.iterdir()):
        print(f"Error: target directory is not empty: {target}", file=sys.stderr)
        return 1

    init_bundle(target, args.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
