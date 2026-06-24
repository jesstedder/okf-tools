---
name: okf-convert-claude-obsidian
description: Convert a claude-obsidian vault layout to an Open Knowledge Format (OKF) bundle.
metadata:
  author: jess
  version: "0.1.0"
---

Use this skill to migrate an existing claude-obsidian vault (`wiki/`, typed folders, `hot.md`) to a standard OKF bundle.

## Invocation examples

- "Convert ~/Documents/Obsidian/the-knowledge to OKF at /tmp/the-knowledge-okf"
- `/okf-convert-claude-obsidian --source ~/Documents/Obsidian/the-knowledge --dest /tmp/the-knowledge-okf`

## Steps

1. Run a dry-run preview from the okf-tools repo root:
   ```bash
   # Linux/macOS:
   bash scripts/okf-convert-claude-obsidian.sh \
     --source <vault-path> \
     --dest <output-path> \
     --dry-run
   ```
   ```powershell
   # Windows:
   pwsh scripts/okf-convert-claude-obsidian.ps1 \
     -Source <vault-path> -Dest <output-path> -DryRun
   ```
   To preserve wikilinks instead of converting them, add `--keep-wikilinks` (bash) or `-KeepWikilinks` (PowerShell).
2. Show the user the preview (first 10 files + total count).
3. If the user approves, run the converter without `--dry-run` / `-DryRun`.
4. Run `okf-validate` on the resulting bundle and report findings.

## Folder-to-type mapping

| Source folder | OKF `type` |
|---|---|
| `concepts/` | `Concept` |
| `entities/` | `Entity` |
| `guides/` | `Guide` |
| `homelab/` | `Decision` |
| `meta/` | `Decision` |
| `questions/` | `Question` |
| `references/` | `Reference` |
| `sources/` | `Source` |
| anything else | `Concept` |

## Behavior

- Rewrites `[[Concept Name]]` to `[Concept Name](path/to/concept-name.md)` and `[[Concept Name|label]]` to `[label](path/to/concept-name.md)` by default.
- Leaves unresolved wikilinks unchanged so `okf-validate` can flag them.
- Synthesizes `title` from H1 or filename, `description` from first paragraph, `tags` from `#tag` syntax, `timestamp` from file mtime.
- Copies existing `wiki/index.md`, `wiki/log.md`, `wiki/hot.md` if present.

## Output

Return the absolute path of the new OKF bundle and the number of concepts converted.
