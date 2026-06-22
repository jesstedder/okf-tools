## Why

We need a common, portable way for Hermes (and other agents) to read, write, validate, and query markdown-based knowledge bundles in our projects and personal vaults. Google's Open Knowledge Format (OKF) v0.1 provides a minimal, git-friendly, agent-readable standard: markdown files with YAML frontmatter, concept identity by file path, and `index.md`/`log.md` conventions.

Adopting OKF lets us migrate away from the claude-obsidian-specific vault conventions while keeping the same compounding-knowledge workflow. It also gives future projects (`432-milton-lore`, `the-horde`, and others) a single, reusable skill set for storing structured knowledge as markdown.

## What Changes

Create a set of Hermes skills in `/var/home/jess/src/okf-tools/skills/okf-*/SKILL.md` that operate on OKF bundles. The source of truth is the `okf-tools` repo; a `scripts/install-skills.sh` helper copies/symlinks the skills into `~/.hermes/skills/` so they are invocable by Hermes.

Skills to create:
- `okf-init` — scaffold a new OKF bundle (`index.md`, `log.md`, `hot.md`, optional type registry).
- `okf-validate` — lint a bundle: required `type`, reserved filenames, frontmatter validity, broken markdown/wikilinks, duplicate concept IDs.
- `okf-convert-claude-obsidian` — migrate a vault using the claude-obsidian layout (`wiki/`, `hot.md`, `index.md`, `log.md`, typed folders) into an OKF bundle.
- `okf-query` — answer questions from an OKF bundle by reading `hot.md`, then `index.md`, then relevant concepts.
- `okf-ingest` — ingest a raw source into the bundle as a new OKF concept, linked from `index.md` and logged in `log.md`.

Keep Obsidian wikilinks (`[[...]]`) as an accepted OKF extension for compatibility. Keep `hot.md` as a Hermes/OKF quick-access convention alongside the spec's `index.md` and `log.md`.

This change is limited to the **core skills**; project-specific adapters (`432-milton-lore` OKF rendering, `the-horde` inventory types) are out of scope and will be handled as follow-up changes.

## Capabilities

### New Capabilities

- `okf-bundle`: Represent knowledge as an OKF directory of markdown files (concepts, index, log, hot).
- `okf-validate`: Check bundle health, frontmatter completeness, valid links, and concept identity collisions.
- `okf-convert`: Transform an existing claude-obsidian vault into an OKF bundle.
- `okf-query`: Retrieve answers from an OKF bundle using the hot/index/concept hierarchy.
- `okf-ingest`: Add external sources to an OKF bundle as typed concepts.

### Modified Capabilities

None. This is a greenfield skill set. Existing claude-obsidian projects are untouched unless the user explicitly runs the converter.

## Impact

- New top-level `skills/` directory in `/var/home/jess/src/okf-tools`.
- New `scripts/install-skills.sh` to sync skills into `~/.hermes/skills/`.
- Optional mirrored `.claude/skills/` and `.opencode/skills/` copies for multi-agent reuse.
- First migration target is `~/Documents/Obsidian/the-knowledge` once skills are implemented and validated.
- `the-lore` remains a later cleanup effort; `432-milton-lore` and `the-horde` are out of scope for this change.
