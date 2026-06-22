# okf-query Specification

## Purpose
TBD - created by archiving change okf-core-skills. Update Purpose after archive.
## Requirements
### Requirement: Hot-first query order
`okf-query` SHALL read `hot.md` first, then `index.md`, then only the concepts needed to answer the user's question.

#### Scenario: Hot file exists
- **WHEN** a bundle contains `hot.md`
- **THEN** `okf-query` loads it before any other bundle files

#### Scenario: Hot file absent
- **WHEN** a bundle does not contain `hot.md`
- **THEN** `okf-query` proceeds to `index.md` without error

### Requirement: Concept selection
`okf-query` SHALL select concepts by matching the query against `title`, `description`, `type`, `tags`, and body text.

#### Scenario: Direct concept match
- **WHEN** the user asks "what is the Frigate NVR setup?"
- **THEN** the tool reads `concepts/frigate-nvr.md` and synthesizes an answer

### Requirement: Citation and linking
`okf-query` SHALL cite the concept files it draws from using markdown links or wikilinks, so the user can navigate in Obsidian or a browser.

#### Scenario: Cited answer
- **WHEN** an answer uses facts from `concepts/mcp-in-cluster-k8s-access.md`
- **THEN** the response includes a link to that concept

### Requirement: Markdown-only bundle assumption
`okf-query` SHALL operate on the markdown bundle directly without requiring an Obsidian plugin, database, or search index.

#### Scenario: Plain filesystem query
- **WHEN** the user runs `okf-query` against a directory of `.md` files
- **THEN** it returns an answer without external services

