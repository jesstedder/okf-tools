## 1. Repository scaffolding

- [x] 1.1 Create `skills/` directory under `/var/home/jess/src/okf-tools`.
- [x] 1.2 Create `scripts/` directory for shared Python helpers.
- [x] 1.3 Add `scripts/install-skills.sh` that symlinks `skills/okf-*` into `~/.hermes/skills/`.
- [x] 1.4 Add `README.md` (or `OVERVIEW.md`) describing the repo and install flow.

## 2. Shared OKF library

- [x] 2.1 Implement `scripts/okf_bundle.py` to load a bundle, enumerate concepts, and resolve concept IDs.
- [x] 2.2 Implement `scripts/okf_frontmatter.py` to parse and validate YAML frontmatter (required `type`, optional fields).
- [x] 2.3 Implement `scripts/okf_links.py` to extract and resolve markdown links and Obsidian wikilinks.
- [x] 2.4 Add unit tests for bundle loading, frontmatter parsing, and link resolution.

## 3. Skill: okf-init

- [x] 3.1 Write `skills/okf-init/SKILL.md` with usage instructions.
- [x] 3.2 Implement `scripts/okf-init.py` to scaffold `index.md`, `log.md`, `hot.md`, and optional starter directories.
- [x] 3.3 Verify scaffold passes `okf-validate`.

## 4. Skill: okf-validate

- [x] 4.1 Write `skills/okf-validate/SKILL.md`.
- [x] 4.2 Implement `scripts/okf-validate.py` checking: required `type`, reserved filenames, duplicate IDs, broken links, malformed frontmatter.
- [x] 4.3 Run `okf-validate` against `the-knowledge` preview bundle and report findings.

## 5. Skill: okf-convert-claude-obsidian

- [x] 5.1 Write `skills/okf-convert-claude-obsidian/SKILL.md`.
- [x] 5.2 Implement `scripts/okf-convert-claude-obsidian.py` with folder-to-type mapping, metadata synthesis, wikilink preservation, and `--dry-run`.
- [x] 5.3 Test conversion on a copy of `the-knowledge`.

## 6. Skill: okf-query

- [x] 6.1 Write `skills/okf-query/SKILL.md`.
- [x] 6.2 Implement `scripts/okf-query.py` that reads `hot.md` → `index.md` → ranked concepts.
- [x] 6.3 Verify it can answer a known question from `the-knowledge` bundle.

## 7. Skill: okf-ingest

- [x] 7.1 Write `skills/okf-ingest/SKILL.md`.
- [x] 7.2 Implement `scripts/okf-ingest.py` to create a concept from a file or URL, update relevant `index.md`, and append to `log.md`.
- [x] 7.3 Add idempotency: detect duplicate source and update existing concept.

## 8. Multi-agent scaffolding and install

- [x] 8.1 Mirror `skills/okf-*` into `.claude/skills/okf-*`.
- [x] 8.2 Mirror `skills/okf-*` into `.opencode/skills/okf-*`.
- [x] 8.3 Run `scripts/install-skills.sh` and confirm all skills appear in `~/.hermes/skills/`.
- [x] 8.4 Smoke-test each skill via Hermes invocation.

## 9. Validation and archive

- [x] 9.1 Run `openspec validate okf-core-skills`.
- [x] 9.2 Run `openspec archive okf-core-skills` to sync delta specs to main specs.
- [x] 9.3 Commit the change artifacts, skills, scripts, and mirrored copies to git.
