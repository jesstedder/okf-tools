#!/usr/bin/env python3
"""Answer a question from an OKF bundle by ranking relevant concepts."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from okf_bundle import Bundle


STOPWORDS = {"a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
             "to", "of", "and", "or", "in", "on", "at", "for", "with", "from",
             "as", "it", "its", "this", "that", "these", "those", "how", "what",
             "when", "where", "why", "who", "which", "can", "do", "does", "did",
             "i", "you", "we", "they", "my", "your", "our", "their"}


def _tokens(text: str) -> list[str]:
    return [t for t in re.findall(r"[a-zA-Z0-9_+-]+", text.lower()) if t not in STOPWORDS]


def _score_concept(concept, query_terms: set[str]) -> float:
    score = 0.0
    fields = [
        (concept.title, 4),
        (concept.description or "", 3),
        (" ".join(concept.tags), 3),
        (concept.type, 2),
        (concept.body, 1),
    ]
    for text, weight in fields:
        text_tokens = _tokens(text)
        matches = sum(1 for t in text_tokens if t in query_terms)
        # small boost for exact phrase presence
        if " ".join(query_terms) in text.lower():
            matches += 5
        score += matches * weight
    return score


def query_bundle(root: Path, query: str, max_results: int = 10) -> dict:
    bundle = Bundle(root)
    query_terms = set(_tokens(query))

    hot = bundle.hot_path().read_text(encoding="utf-8") if bundle.hot_path().exists() else ""
    index = bundle.index_path().read_text(encoding="utf-8") if bundle.index_path().exists() else ""

    scored = []
    for concept in bundle.concepts.values():
        score = _score_concept(concept, query_terms)
        if score > 0:
            scored.append({
                "id": concept.id,
                "title": concept.title,
                "type": concept.type,
                "description": concept.description,
                "tags": concept.tags,
                "score": score,
            })

    scored.sort(key=lambda x: x["score"], reverse=True)
    results = scored[:max_results]

    return {
        "bundle": str(root),
        "query": query,
        "hot_exists": bool(hot),
        "index_exists": bool(index),
        "results": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Query an OKF bundle")
    parser.add_argument("--bundle", required=True, help="Path to OKF bundle")
    parser.add_argument("--query", required=True, help="Question or keywords")
    parser.add_argument("--max", type=int, default=10, help="Max concepts to return")
    args = parser.parse_args()

    result = query_bundle(Path(args.bundle).expanduser().resolve(), args.query, args.max)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
