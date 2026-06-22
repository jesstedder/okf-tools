# okf-tools

Hermes skills and helper scripts for working with the [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf).

## Install skills

From this repo:

```bash
./scripts/install-skills.sh
```

This symlinks `skills/okf-*` into `~/.hermes/skills/` so Hermes can invoke them.

## Skills

| Skill | Purpose |
|---|---|
| `okf-init` | Scaffold a new OKF bundle |
| `okf-validate` | Lint an OKF bundle |
| `okf-convert-claude-obsidian` | Migrate a claude-obsidian vault to OKF |
| `okf-query` | Answer questions from an OKF bundle |
| `okf-ingest` | Add a source to an OKF bundle |

## Development

Uses `uv` for dependency management:

```bash
uv sync --extra dev
uv run pytest
```

## License

MIT
