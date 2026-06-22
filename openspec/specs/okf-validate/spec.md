# okf-validate Specification

## Purpose
TBD - created by archiving change okf-core-skills. Update Purpose after archive.
## Requirements
### Requirement: Required frontmatter
`okf-validate` SHALL check that every concept file has a non-empty `type` field.

#### Scenario: Missing type
- **WHEN** a concept file has no `type` frontmatter key
- **THEN** `okf-validate` emits a MISSING_TYPE finding

#### Scenario: Blank type
- **WHEN** a concept file has `type:` with an empty value
- **THEN** `okf-validate` emits a BLANK_TYPE finding

### Requirement: Reserved filename checks
`okf-validate` SHALL allow `index.md` and `log.md` as directory metadata, but SHALL report an error if a concept is represented by either name.

#### Scenario: Reserved name hidden in concept directory
- **WHEN** a file named `concepts/index.md` exists in a concept directory
- **THEN** `okf-validate` reports no error (it is a directory index)

#### Scenario: Ambiguous concept filename
- **WHEN** a user attempts to create a concept named `log.md`
- **THEN** `okf-validate` reports a RESERVED_NAME error

### Requirement: Link target resolution
`okf-validate` SHALL resolve all markdown links and wikilinks to concept IDs. Links to external URIs and anchors are ignored unless the URI points to another concept in the same bundle.

#### Scenario: Valid internal markdown link
- **WHEN** a concept links to `[label](../entities/vaultwarden.md)` and the file exists
- **THEN** `okf-validate` reports no link error

#### Scenario: Valid internal wikilink
- **WHEN** a concept links to `[[entities/vaultwarden]]` and `entities/vaultwarden.md` exists
- **THEN** `okf-validate` reports no link error

### Requirement: Duplicate concept IDs
`okf-validate` SHALL detect duplicate concept IDs within a bundle.

#### Scenario: Case-insensitive filesystem collision
- **WHEN** both `concepts/MacOS.md` and `concepts/macos.md` exist
- **THEN** `okf-validate` reports a CONFLICTING_ID error

### Requirement: YAML frontmatter well-formedness
`okf-validate` SHALL report invalid YAML in frontmatter.

#### Scenario: Malformed YAML
- **WHEN** a file begins with `---` and then contains invalid YAML before `---`
- **THEN** `okf-validate` emits a MALFORMED_FRONTMATTER error

