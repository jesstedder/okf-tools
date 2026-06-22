## Context

We currently maintain knowledge in two forms:
- **claude-obsidian vaults** (`the-knowledge`, `the-lore`) using a custom folder layout (`concepts/`, `entities/`, `sources/`, etc.) and Obsidian wikilinks.
- **project data stores** (`432-milton-lore`) that export structured JSON into an Astro site.

Google's OKF v0.1 gives us a portable, tool-neutral baseline: a directory of markdown files with YAML frontmatter, concept identity by path, and reserved `index.md`/`log.md` files. We want Hermes skills that read and write OKF bundles directly, removing dependence on claude-obsidian-specific conventions while keeping Obsidian itself usable as an editor.

## Goals / Non-Goals

**Goals:**
- Define a small set of reusable Hermes skills for OKF bundle operations.
- Keep the source of truth for those skills in `/var/home/jess/src/okf-tools`.
- Install the skills into `~/.hermes/skills/` so Hermes can invoke them immediately.
- Support Obsidian wikilinks as an OKF extension for backward compatibility.
- Preserve the `hot.md` quick-access convention alongside OKF `index.md`/`log.md`.
- Provide a migration path from claude-obsidian vaults to OKF bundles.

**Non-Goals:**
- Modifying `432-milton-lore` or `the-horde` (handled in follow-up changes).
- Migrating `the-lore` personal vault now (it needs cleanup first).
- Replacing Obsidian as an editor.
- Building a new query language or indexer; `okf-query` reads files directly.

## Decisions

### 1. Skill source of truth lives in `okf-tools`, not `~/.hermes/skills/`
**Rationale:** Version-controlled skills can be iterated in the repo and shared across machines. `scripts/install-skills.sh` copies/symlinks them into `~/.hermes/skills/`.
**Alternative considered:** Edit skills directly in `~/.hermes/skills/` and sync back. Rejected because it inverts the GitOps model.

### 2. Skills are Hermes `SKILL.md` files with shell helpers underneath
**Rationale:** Hermes skills are markdown documents consumed by the agent. Heavy lifting (file scanning, YAML parsing, link checking) is delegated to small Python scripts in `scripts/okf-*.py` that the skill invokes via `terminal()`.
**Alternative considered:** Pure-skill implementation using only file tools. Rejected because validating a bundle, resolving wikilinks, and parsing frontmatter is too much to express in skill prose.

### 3. Wikilinks are a first-class extension
**Rationale:** The user has years of notes using `[[...]]` and wants to keep opening bundles in Obsidian. The validator accepts both `[[...]]` and standard markdown links; the query tool resolves both.
**Alternative considered:** Convert all wikilinks to markdown during migration. Rejected because it breaks Obsidian's native editing experience.

### 4. `hot.md` is retained as a Hermes convention
**Rationale:** It mirrors the existing `wiki/hot.md` quick-context file and gives agents a short, recent-context entry point. It is not part of the OKF spec, so it is ignored by spec-strict validators.
**Alternative considered:** Drop `hot.md` and rely only on `index.md`. Rejected because it loses the low-friction recent-context pattern.

### 5. Five focused skills instead of one monolithic skill
**Rationale:** `init`, `validate`, `convert`, `query`, and `ingest` are independent operations. Separate skills make them individually maintainable and let users invoke exactly what they need.
**Alternative considered:** A single `okf` skill with sub-commands. Rejected because Hermes skills are invoked by name; large branching inside one skill is harder to maintain.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Duplicate source/main specs during OpenSpec sync | Keep delta specs under `openspec/changes/<change>/specs/` until archive; only then write to `openspec/specs/`. |
| Hermes skill paths diverge from repo | `scripts/install-skills.sh` is idempotent and deletes stale symlinks before re-linking. |
| Wikilink ambiguity (`[[Foo]]` vs `[[foo]]` on case-insensitive filesystems) | Validator warns on case conflicts; converter normalizes concept IDs to lowercase paths. |
| `okf-query` loads too many files on large vaults | Query tool respects `max_concepts` and reads only top-N matches from `title`/`description`/`tags` before falling back to full-text. |
| Migration produces noisy diffs | Converter runs in `--dry-run` by default; metadata synthesis is previewed before write. |

## Migration Plan

1. Implement `okf-init` and `okf-validate` first.
2. Use `okf-convert-claude-obsidian` to migrate `the-knowledge` to a scratch bundle.
3. Validate the migrated bundle with `okf-validate` and fix any blockers.
4. Replace `the-knowledge/wiki` with the OKF bundle only after validation passes.
5. Later, repeat for `the-lore` after manual cleanup.
6. `432-milton-lore` and `the-horde` get their own changes once the core skills are stable.

Rollback: keep the original vault in a `wiki.pre-okf/` backup directory until the OKF bundle is confirmed usable in Obsidian.

## Open Questions

1. Should `okf-query` use an external search/index tool (e.g., ripgrep + Python scoring) or rely on the LLM reading files? *Decision deferred to implementation; start with simple file reads.*
2. Should `okf-ingest` fetch web pages itself or require the user to download sources first? *Decision: support both, but web fetch is optional and uses `curl`.*
3. Do we want a shared `okf-types.yaml` registry in each bundle, or let types be inferred per skill? *Decision: bundle-level `.okf/types.yaml` optional; skills define sensible defaults.*
