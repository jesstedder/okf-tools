## Context

The initial `okf-convert-claude-obsidian` skill preserves wikilinks exactly. This is fine for a pure Obsidian workflow but fails for GitHub rendering or other markdown pipelines. The OKF spec itself uses relative markdown links, so conversion should normalize links to that form.

## Decision

Add a single rewrite pass to the converter:

1. Build the set of output concept IDs before writing any files.
2. For each concept body, use `okf_links.rewrite_wikilinks(body, source_id, existing_ids)`.
3. If a wikilink target resolves to a known concept, replace it with a relative markdown link computed from the source concept's directory to the target concept's path.
4. If it does not resolve, leave the original wikilink in place.

## Link path rules

- Source `a/b/c.md` linking to `a/b/d.md` → `[label](d.md)`
- Source `a/b/c.md` linking to `a/d.md` → `[label](../d.md)`
- Source `a/b/c.md` linking to `x/y/z.md` → `[label](../../x/y/z.md)`

## Fallback behavior

Unresolved wikilinks remain wikilinks so:
- Obsidian can still render them (possibly pointing to notes not included in the OKF bundle).
- `okf-validate` flags them as broken if the target is truly missing.
