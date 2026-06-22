## 1. Extend link library

- [x] 1.1 Add `rewrite_wikilinks(text, source_concept_id, existing_ids)` to `scripts/okf_links.py`.
- [x] 1.2 Compute relative markdown paths between concepts.
- [x] 1.3 Preserve unresolved wikilinks and existing markdown links.

## 2. Update converter

- [x] 2.1 Build the set of output concept IDs before writing files.
- [x] 2.2 Rewrite wikilinks in each concept body before writing.
- [x] 2.3 Add a `--keep-wikilinks` flag to optionally disable rewriting.

## 3. Tests and documentation

- [x] 3.1 Add unit tests for `rewrite_wikilinks`.
- [x] 3.2 Update `skills/okf-convert-claude-obsidian/SKILL.md` to mention markdown link output.
- [x] 3.3 Run `uv run pytest` and the conversion dry-run against `the-knowledge`.

## 4. Commit

- [x] 4.1 Validate the OpenSpec change.
- [x] 4.2 Archive the change.
- [x] 4.3 Commit the code changes to `main`.
