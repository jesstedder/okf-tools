#!/usr/bin/env bash
# Scaffold a new OKF bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/okf_lib.sh"

usage() { echo "usage: okf-init.sh <path> [--name <display-name>]" >&2; exit 1; }

[[ $# -lt 1 ]] && usage

TARGET=""
NAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --name=*) NAME="${1#*=}"; shift ;;
        -*) echo "unknown option: $1" >&2; usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[[ -z "$TARGET" ]] && usage

# Expand and resolve path
TARGET="${TARGET/#\~/$HOME}"

if [[ -e "$TARGET" ]] && [[ -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
    echo "error: target directory is not empty: $TARGET" >&2
    exit 1
fi

NAME="${NAME:-$(basename "$TARGET")}"
TODAY=$(date -u +"%Y-%m-%d")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

mkdir -p "$TARGET"

# index.md
cat > "$TARGET/index.md" <<EOF
# $NAME

Bundle overview. Add links to concepts below.
EOF

# log.md
cat > "$TARGET/log.md" <<EOF
# Log

## $TODAY
- Created OKF bundle.
EOF

# hot.md
cat > "$TARGET/hot.md" <<'EOF'
# Hot

Recent context and quick notes go here. This file is read first by `okf-query`.
EOF

# concepts/starter-concept.md
mkdir -p "$TARGET/concepts"
okf_render_concept \
    "$TARGET/concepts/starter-concept.md" \
    "Concept" \
    "$NAME starter concept" \
    "An example concept to get started." \
    "" \
    "example" \
    "$NOW" \
    "# Starter Concept

Replace this with real content."

# .okf/types.md
mkdir -p "$TARGET/.okf"
cat > "$TARGET/.okf/types.md" <<'EOF'
# OKF Type Registry

Default types used in this bundle:
- Concept
- Entity
- Guide
- Reference
- Source
- Decision
- Question
- Log
EOF

echo "Created OKF bundle at $TARGET"
