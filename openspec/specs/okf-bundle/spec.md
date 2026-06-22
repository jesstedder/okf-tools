# okf-bundle Specification

## Purpose
TBD - created by archiving change okf-core-skills. Update Purpose after archive.
## Requirements
### Requirement: Bundle structure
An OKF bundle SHALL be a directory tree of UTF-8 markdown files. Each markdown file except `index.md` and `log.md` is a concept.

#### Scenario: Valid OKF bundle root
- **WHEN** a user invokes `okf-init` to scaffold a bundle
- **THEN** the tool creates `index.md`, `log.md`, `hot.md`, and an optional concept directory

#### Scenario: Concept identity by path
- **WHEN** a file exists at `wiki/concepts/frigate-nvr.md`
- **THEN** its concept ID is `wiki/concepts/frigate-nvr`

### Requirement: Concept frontmatter
Every concept markdown file SHALL contain YAML frontmatter with at least a `type` field. Other fields (`title`, `description`, `resource`, `tags`, `timestamp`) are optional but recommended.

#### Scenario: Minimal valid concept
- **WHEN** a concept file contains frontmatter with `type: Concept`
- **THEN** `okf-validate` reports it as valid

#### Scenario: Missing required type
- **WHEN** a concept file lacks a `type` field
- **THEN** `okf-validate` reports a MISSING_TYPE error

### Requirement: Reserved filenames
The filenames `index.md` and `log.md` are reserved for directory listings and update history. They SHALL NOT be used as concept documents.

#### Scenario: Reserved filename validation
- **WHEN** `okf-validate` scans a bundle
- **THEN** it allows `index.md` and `log.md` at any directory level and rejects any other file with those names if treated as a concept

### Requirement: Link formats
Concept links MAY be standard markdown links (`[label](path)`) or Obsidian wikilinks (`[[concept]]`, `[[path/to/concept|label]]`). Both forms SHALL be resolved against concept IDs.

#### Scenario: Broken markdown link detection
- **WHEN** a concept contains `[broken](missing.md)`
- **THEN** `okf-validate` reports a BROKEN_LINK error

#### Scenario: Broken wikilink detection
- **WHEN** a concept contains `[[Missing Page]]`
- **THEN** `okf-validate` reports a BROKEN_LINK error

### Requirement: Quick-access `hot.md`
A bundle MAY contain a `hot.md` file at the root as a non-spec quick-access entry point. An agent reading the bundle for context SHALL read `hot.md` first when present, then `index.md`, then drill into concepts.

#### Scenario: Hot file first
- **WHEN** an agent queries `okf-query` and `hot.md` exists
- **THEN** it reads `hot.md` before `index.md`

