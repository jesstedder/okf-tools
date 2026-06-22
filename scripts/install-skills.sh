#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERMES_SKILLS_DIR="${HOME}/.hermes/skills"
SKILL_PREFIX="okf-"

echo "Installing OKF skills from ${REPO_ROOT} to ${HERMES_SKILLS_DIR}"

mkdir -p "${HERMES_SKILLS_DIR}"

# Remove stale symlinks / old copies
for existing in "${HERMES_SKILLS_DIR}/${SKILL_PREFIX}"*; do
    [ -e "${existing}" ] || [ -L "${existing}" ] || continue
    rm -rf "${existing}"
done

# Link each skill
for skill_dir in "${REPO_ROOT}/skills/${SKILL_PREFIX}"*/; do
    [ -d "${skill_dir}" ] || continue
    skill_name="$(basename "${skill_dir}")"
    target="${HERMES_SKILLS_DIR}/${skill_name}"
    ln -sfn "${skill_dir}" "${target}"
    echo "  ${skill_name} -> ${target}"
done

echo "Done. Run 'hermes skills list' (or restart Hermes) to load them."
