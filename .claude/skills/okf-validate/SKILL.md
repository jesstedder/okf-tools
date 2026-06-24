---
name: okf-validate
description: Validate an Open Knowledge Format (OKF) bundle for required frontmatter, broken links, and structural issues.
metadata:
  author: jess
  version: "0.1.0"
---

Use this skill to lint an OKF bundle before using or migrating it.

## Invocation examples

- "Validate ~/Documents/Obsidian/the-knowledge"
- `/okf-validate bundle=~/Documents/Obsidian/the-knowledge`

## Steps

1. Resolve the bundle path.
2. Run the validator:
   ```bash
   # Linux/macOS:
   bash /var/home/jess/src/okf-tools/scripts/okf-validate.sh <bundle-path>
   # Windows:
   pwsh /var/home/jess/src/okf-tools/scripts/okf-validate.ps1 -Bundle <bundle-path>
   ```
3. Report the findings. If any are present, guide the user to fix them before proceeding.

## What is checked

- Every `.md` file (except `index.md`, `log.md`, `hot.md`) has a non-empty `type` field.
- YAML frontmatter is well-formed.
- No concept IDs collide on case-insensitive filesystems.
- Internal markdown links and Obsidian wikilinks resolve to existing concepts.

## Output

Print each finding with `LEVEL: [concept-id] message`. Exit code is non-zero if there are errors.
