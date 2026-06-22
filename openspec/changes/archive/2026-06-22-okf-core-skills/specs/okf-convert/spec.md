## ADDED Requirements

### Requirement: Source vault discovery
`okf-convert-claude-obsidian` SHALL accept a source vault path and discover its claude-obsidian structure (`wiki/`, `.raw/`, `hot.md`, `index.md`, `log.md`, typed folders).

#### Scenario: Detect claude-obsidian vault
- **WHEN** the tool runs against a directory containing `wiki/index.md` and `wiki/hot.md`
- **THEN** it treats the directory as a claude-obsidian vault

### Requirement: Folder-to-type mapping
The converter SHALL map existing claude-obsidian folders to default OKF concept types:
- `concepts/` → `Concept`
- `entities/` → `Entity`
- `guides/` → `Guide`
- `homelab/` → `Decision`
- `meta/` → `Decision`
- `questions/` → `Question`
- `references/` → `Reference`
- `sources/` → `Source`

#### Scenario: Automatic type inference
- **WHEN** a file is at `wiki/concepts/gitops-health.md`
- **THEN** the converted concept has `type: Concept`

#### Scenario: Override via frontmatter
- **WHEN** an existing note already has `type: Override`
- **THEN** the converter preserves that type instead of using the folder default

### Requirement: Link preservation
The converter SHALL preserve Obsidian wikilinks in body text. It MAY also generate markdown-link alternates, but SHALL NOT rewrite wikilinks by default.

#### Scenario: Wikilink untouched
- **WHEN** a note contains `[[Frigate NVR]]`
- **THEN** the converted OKF concept still contains `[[Frigate NVR]]`

### Requirement: Metadata synthesis
The converter SHALL synthesize `title` from the H1 or filename, `description` from the first paragraph, `tags` from existing `#tag` syntax or frontmatter, and `timestamp` from git history or file mtime.

#### Scenario: Synthesize missing metadata
- **WHEN** a source note has no frontmatter
- **THEN** the converted concept has `type`, `title`, and `timestamp` populated

### Requirement: Dry-run and preview
The converter SHALL support a dry-run mode that emits a preview of changes without writing files.

#### Scenario: Preview migration
- **WHEN** the user passes `--dry-run`
- **THEN** the tool prints new file paths and metadata without touching the source or destination

## MODIFIED Requirements

None.

## REMOVED Requirements

None.
