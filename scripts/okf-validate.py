#!/usr/bin/env python3
"""Validate an OKF bundle."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from okf_bundle import Bundle
from okf_links import extract_all, resolve_link


class Finding:
    def __init__(self, level: str, concept_id: str, message: str):
        self.level = level
        self.concept_id = concept_id
        self.message = message

    def __str__(self) -> str:
        return f"{self.level}: [{self.concept_id}] {self.message}"


def validate_bundle(root: Path) -> list[Finding]:
    findings: list[Finding] = []

    try:
        bundle = Bundle(root)
    except Exception as exc:
        findings.append(Finding("ERROR", "", f"Failed to load bundle: {exc}"))
        return findings

    for err in bundle.errors:
        concept_id = err.split(":", 1)[0] if ":" in err else ""
        findings.append(Finding("ERROR", concept_id, err))

    concept_ids = set(bundle.concepts.keys())

    for concept in bundle.concepts.values():
        links = extract_all(concept.body)
        for link in links:
            resolved = resolve_link(link, concept.id, concept_ids)
            if resolved is None and not link.is_external():
                findings.append(
                    Finding("ERROR", concept.id, f"BROKEN_LINK: {link.raw} -> {link.target}")
                )

    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an OKF bundle")
    parser.add_argument("bundle", help="Path to the OKF bundle")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as errors")
    args = parser.parse_args()

    root = Path(args.bundle).expanduser().resolve()
    findings = validate_bundle(root)

    if not findings:
        print(f"OK: {root} is a valid OKF bundle")
        return 0

    for finding in findings:
        print(finding)
    print(f"\n{len(findings)} finding(s)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
