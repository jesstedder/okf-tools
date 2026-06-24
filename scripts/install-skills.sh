#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_PREFIX="okf-"
SKILLS_SRC="${REPO_ROOT}/skills"

usage() {
    cat >&2 <<EOF
usage: install-skills.sh [--hermes] [--global] [--claude] [--opencode] [--copilot] [--all]

  --hermes    Install to ~/.hermes/skills  (default if no flags given)
  --claude    Install to ~/.claude/skills
  --opencode  Install to ~/.opencode/skills
  --copilot   Install to ~/.copilot/skills
  --global    Install to claude + opencode + copilot (all non-hermes agents)
  --all       Install to all destinations (hermes + global)
EOF
    exit 1
}

DEST_HERMES=0 DEST_CLAUDE=0 DEST_OPENCODE=0 DEST_COPILOT=0

if [[ $# -eq 0 ]]; then
    DEST_HERMES=1
else
    for arg in "$@"; do
        case "$arg" in
            --hermes)   DEST_HERMES=1 ;;
            --claude)   DEST_CLAUDE=1 ;;
            --opencode) DEST_OPENCODE=1 ;;
            --copilot)  DEST_COPILOT=1 ;;
            --global)   DEST_CLAUDE=1; DEST_OPENCODE=1; DEST_COPILOT=1 ;;
            --all)      DEST_HERMES=1; DEST_CLAUDE=1; DEST_OPENCODE=1; DEST_COPILOT=1 ;;
            *) echo "unknown option: $arg" >&2; usage ;;
        esac
    done
fi

_install_to() {
    local dest="$1"
    echo "Installing to ${dest}"
    mkdir -p "${dest}"
    # Remove stale symlinks
    for existing in "${dest}/${SKILL_PREFIX}"*; do
        [ -e "${existing}" ] || [ -L "${existing}" ] || continue
        rm -rf "${existing}"
    done
    # Link each skill
    for skill_dir in "${SKILLS_SRC}/${SKILL_PREFIX}"*/; do
        [ -d "${skill_dir}" ] || continue
        skill_name="$(basename "${skill_dir}")"
        ln -sfn "${skill_dir}" "${dest}/${skill_name}"
        echo "  ${skill_name}"
    done
}

(( DEST_HERMES ))   && _install_to "${HOME}/.hermes/skills"
(( DEST_CLAUDE ))   && _install_to "${HOME}/.claude/skills"
(( DEST_OPENCODE )) && _install_to "${HOME}/.opencode/skills"
(( DEST_COPILOT ))  && _install_to "${HOME}/.copilot/skills"

echo "Done."
