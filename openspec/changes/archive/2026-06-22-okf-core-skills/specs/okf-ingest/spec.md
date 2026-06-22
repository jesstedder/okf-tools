## ADDED Requirements

### Requirement: Source to concept conversion
`okf-ingest` SHALL accept a source file or URL and create a typed OKF concept markdown file in the bundle.

#### Scenario: Ingest local file
- **WHEN** the user runs `okf-ingest source.md --type Source`
- **THEN** a new concept is created in the bundle with frontmatter `type: Source`

#### Scenario: Ingest web page
- **WHEN** the user provides a URL
- **THEN** the tool fetches the page, extracts markdown content, and writes a concept with `resource: <URL>`

### Requirement: Backlinking
`okf-ingest` SHALL add a link to the new concept from the appropriate `index.md`. If a relevant directory index exists, it SHALL update that index; otherwise it updates the root `index.md`.

#### Scenario: Directory index linking
- **WHEN** a new concept is created under `sources/`
- **THEN** `sources/index.md` includes a link to the new concept

### Requirement: Log entry
Every ingestion SHALL append an entry to `log.md` with a timestamp, source URI/path, and new concept ID.

#### Scenario: Log after ingestion
- **WHEN** `okf-ingest` creates `sources/blog-post.md`
- **THEN** `log.md` contains a new entry noting the creation

### Requirement: Idempotency
`okf-ingest` SHALL detect when the same source has already been ingested and either update the existing concept or prompt the user, depending on flags.

#### Scenario: Re-ingest same URL
- **WHEN** the same URL is ingested twice
- **THEN** the tool updates the existing concept file and logs an update entry

## MODIFIED Requirements

None.

## REMOVED Requirements

None.
