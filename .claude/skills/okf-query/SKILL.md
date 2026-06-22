---
name: okf-query
description: Answer a question from an Open Knowledge Format (OKF) bundle by reading hot.md, index.md, and the most relevant concepts.
metadata:
  author: jess
  version: "0.1.0"
---

Use this skill to retrieve answers from an OKF bundle without requiring Obsidian or an external index.

## Invocation examples

- "Query the-knowledge for how Traefik is configured"
- `/okf-query --bundle ~/Documents/Obsidian/the-knowledge --query "Traefik configuration"`

## Steps

1. Resolve the bundle path.
2. Run the query tool:
   ```bash
   cd /var/home/jess/src/okf-tools
   uv run scripts/okf-query.py --bundle <bundle-path> --query "<question>" [--max 10]
   ```
3. Read the returned `hot.md` content if `hot_exists` is true.
4. Read `index.md` if needed.
5. Read the top-ranked concept files (`results[].id`) most relevant to the question.
6. Synthesize a concise answer and cite the concepts using markdown or wikilinks.

## Output

Return the answer with citations to the concept files you used.
