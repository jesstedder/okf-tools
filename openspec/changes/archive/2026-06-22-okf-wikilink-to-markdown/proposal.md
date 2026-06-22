## Why

Obsidian wikilinks (`[[target]]`) are convenient but not portable. GitHub and most static-site generators do not render them. To keep Obsidian compatibility while also targeting GitHub, the OKF converter should produce canonical markdown links during migration.

## What

Update `okf-convert-claude-obsidian` to rewrite wikilinks into relative markdown links:
- `[[Concept Name]]` → `[Concept Name](path/to/concept-name.md)`
- `[[Concept Name|display text]]` → `[display text](path/to/concept-name.md)`

Unresolved wikilinks are left as-is so Obsidian can still resolve them and `okf-validate` can flag them.

## Scope

- Add `rewrite_wikilinks()` to `scripts/okf_links.py`.
- Call it from `scripts/okf-convert-claude-obsidian.py`.
- Update the `okf-convert-claude-obsidian` SKILL.md.
- Add unit tests.

## Risks / Trade-offs

- Links that rely on Obsidian aliases or un-typed filenames may not resolve and will stay as wikilinks.
- Anchor links inside wikilinks (`[[Concept#Heading]]`) are not supported in this pass.
- Existing markdown links are untouched.
