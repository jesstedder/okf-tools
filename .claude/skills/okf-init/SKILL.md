---
name: okf-init
description: Scaffold a new Open Knowledge Format (OKF) bundle with index.md, log.md, hot.md, and a starter concept.
metadata:
  author: jess
  version: "0.1.0"
---

Use this skill to create a new OKF knowledge bundle.

## Invocation examples

- "Initialize an OKF bundle at ~/Documents/Obsidian/my-topic"
- `/okf-init path=~/Documents/Obsidian/my-topic`

## Steps

1. Confirm the target directory path with the user if not provided.
2. Ensure the target directory is empty (to avoid overwriting existing notes).
3. Run the scaffold script:
   ```bash
   cd /var/home/jess/src/okf-tools
   uv run scripts/okf-init.py <path> [--name <display-name>]
   ```
4. Verify the bundle was created:
   ```bash
   ls <path>
   # should show: index.md  log.md  hot.md  concepts/  .okf/
   ```
5. Report the created files and suggest running `okf-validate` next.

## What gets created

- `index.md` — bundle overview and links to concepts
- `log.md` — chronological change log
- `hot.md` — quick-access recent context (Hermes convention)
- `concepts/starter-concept.md` — example typed concept
- `.okf/types.md` — optional local type registry

## Output

Return the absolute path of the new bundle and a brief summary.
