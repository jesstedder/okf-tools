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

1. Run a dry-run preview:
   ```bash
   cd /var/home/jess/src/okf-tools
   uv run scripts/okf-convert-claude-obsidian.py \
     --source <vault-path> \
     --dest <output-path> \
     --dry-run
   ```

   To preserve wikilinks instead of converting them, add `--keep-wikilinks`.
2. Show the user the preview (first 10 files + total count).
3. If the user approves, run the converter without `--dry-run`.
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

- Keeps Obsidian wikilinks as-is by default, but can rewrite them to relative markdown links (recommended when targeting GitHub or static sites) with `--keep-wikilinks` omitted.
- Rewrites `[[Concept Name]]` to `[Concept Name](path/to/concept-name.md)` and `[[Concept Name|label]]` to `[label](path/to/concept-name.md)`.
- Leaves unresolved wikilinks unchanged so `okf-validate` can flag them.
- Synthesizes `title` from H1 or filename, `description` from first paragraph, `tags` from `#tag` syntax, `timestamp` from file mtime.
- Copies existing `wiki/index.md`, `wiki/log.md`, `wiki/hot.md` if present.

## Output

Return the absolute path of the new OKF bundle and the number of concepts converted.
