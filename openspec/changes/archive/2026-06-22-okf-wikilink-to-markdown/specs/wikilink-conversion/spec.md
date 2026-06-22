## ADDED Requirements

### Requirement: Wikilink rewriting
`okf-convert-claude-obsidian` SHALL rewrite Obsidian wikilinks to relative markdown links when the target concept can be resolved.

#### Scenario: Simple wikilink
- **GIVEN** a claude-obsidian note contains `[[Frigate NVR]]`
- **WHEN** the converter processes the note and a concept with basename `frigate-nvr` exists in the output bundle
- **THEN** the output concept body contains `[Frigate NVR](path/to/frigate-nvr.md)`

#### Scenario: Wikilink with custom label
- **GIVEN** a note contains `[[Frigate NVR|NVR]]`
- **WHEN** the converter processes the note
- **THEN** the output contains `[NVR](path/to/frigate-nvr.md)`

#### Scenario: Unresolved wikilink
- **GIVEN** a note contains `[[Missing Concept]]`
- **WHEN** no matching concept exists in the output bundle
- **THEN** the wikilink is preserved unchanged

#### Scenario: Existing markdown links
- **GIVEN** a note already contains `[label](path.md)`
- **WHEN** the converter processes the note
- **THEN** the markdown link is left unchanged
