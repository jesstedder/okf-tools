---
name: okf-ingest
description: Ingest a source file or URL into an Open Knowledge Format (OKF) bundle as a typed concept.
metadata:
  author: jess
  version: "0.1.0"
---

Use this skill to add a new source, reference, or concept to an OKF bundle.

## Invocation examples

- "Ingest https://example.com/post into the-knowledge as a Source"
- `/okf-ingest --bundle ~/Documents/Obsidian/the-knowledge --source ~/Downloads/article.md --type Source`

## Steps

1. Confirm the bundle path, source, and concept type.
2. Run the ingest tool from the okf-tools repo root:
   ```bash
   # Linux/macOS:
   bash scripts/okf-ingest.sh \
     --bundle <bundle-path> \
     --source <file-or-url> \
     --type <type> \
     [--title "Override Title"] \
     [--tags tag1,tag2]
   ```
   ```powershell
   # Windows:
   pwsh scripts/okf-ingest.ps1 \
     -Bundle <bundle-path> -Source <file-or-url> -Type <type> \
     [-Title "Override Title"] [-Tags tag1,tag2]
   ```
3. Verify the new concept file, index link, and log entry.
4. Run `okf-validate` on the bundle.

## Behavior

- For URLs, fetches the page and converts HTML to markdown (uses `pandoc` if available, otherwise strips tags).
- For local files, reads as markdown; `.html`/`.htm` files are converted.
- Synthesizes `title`, `description`, `timestamp`, and `tags` if not provided.
- Sets `resource` frontmatter to the source URL/path.
- Detects duplicate sources by `resource` and updates the existing concept instead of creating a new one.
- Appends a link to the new concept in `index.md`.
- Logs the ingestion in `log.md`.

## Output

Return the absolute path of the created/updated concept.
