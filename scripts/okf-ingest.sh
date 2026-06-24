#!/usr/bin/env bash
# Ingest a source file or URL into an OKF bundle as a typed concept.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/okf_lib.sh"

usage() {
    echo "usage: okf-ingest.sh --bundle <path> --source <file-or-url> --type <type>" >&2
    echo "                     [--id <concept-id>] [--title <title>] [--tags tag1,tag2]" >&2
    exit 1
}

BUNDLE="" SOURCE="" TYPE="" ID="" TITLE="" TAGS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle)  BUNDLE="$2";  shift 2 ;;
        --bundle=*) BUNDLE="${1#*=}"; shift ;;
        --source)  SOURCE="$2";  shift 2 ;;
        --source=*) SOURCE="${1#*=}"; shift ;;
        --type)    TYPE="$2";    shift 2 ;;
        --type=*)  TYPE="${1#*=}"; shift ;;
        --id)      ID="$2";      shift 2 ;;
        --id=*)    ID="${1#*=}"; shift ;;
        --title)   TITLE="$2";   shift 2 ;;
        --title=*) TITLE="${1#*=}"; shift ;;
        --tags)    TAGS="$2";    shift 2 ;;
        --tags=*)  TAGS="${1#*=}"; shift ;;
        *) echo "unknown option: $1" >&2; usage ;;
    esac
done

[[ -z "$BUNDLE" || -z "$SOURCE" || -z "$TYPE" ]] && usage
BUNDLE="${BUNDLE/#\~/$HOME}"
BUNDLE="$(cd "$BUNDLE" && pwd)"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

# Convert HTML to markdown: prefers pandoc, falls back to basic tag stripping.
_html_to_markdown() {
    if command -v pandoc &>/dev/null; then
        pandoc -f html -t markdown --wrap=none 2>/dev/null || cat
    else
        sed 's/<[^>]*>//g' | sed '/^[[:space:]]*$/d'
    fi
}

# Fetch a URL, returning body on stdout; content-type printed to stderr.
_fetch_url() {
    local url="$1"
    local tmp_hdr
    tmp_hdr=$(mktemp)
    curl -sL -A "okf-ingest/0.1" --max-time 30 -D "$tmp_hdr" "$url"
    local ct
    ct=$(grep -i "^content-type:" "$tmp_hdr" | tail -1 | \
         sed 's/^[Cc]ontent-[Tt]ype:[[:space:]]*//' | tr -d '\r')
    rm -f "$tmp_hdr"
    printf '%s' "$ct" >&2
}

# Load and convert source to markdown body.
BODY="" SOURCE_LABEL="$SOURCE"
if [[ "$SOURCE" == http://* || "$SOURCE" == https://* ]]; then
    # Fetch URL
    CT=""
    BODY=$(CT=$(_fetch_url "$SOURCE" 2>&1 >/dev/null); _fetch_url "$SOURCE" 2>/dev/null)
    # Re-fetch to capture content-type properly
    tmp_hdr=$(mktemp)
    BODY=$(curl -sL -A "okf-ingest/0.1" --max-time 30 -D "$tmp_hdr" "$SOURCE")
    CT=$(grep -i "^content-type:" "$tmp_hdr" | tail -1 | \
         sed 's/^[Cc]ontent-[Tt]ype:[[:space:]]*//' | tr -d '\r')
    rm -f "$tmp_hdr"
    if [[ "$CT" == *html* ]]; then
        BODY=$(printf '%s' "$BODY" | _html_to_markdown)
    fi
else
    SRC_PATH="${SOURCE/#\~/$HOME}"
    if [[ ! -f "$SRC_PATH" ]]; then
        echo "error: source not found: $SRC_PATH" >&2
        exit 1
    fi
    BODY=$(cat "$SRC_PATH")
    SOURCE_LABEL="$SRC_PATH"
    case "${SRC_PATH,,}" in
        *.html|*.htm)
            BODY=$(printf '%s' "$BODY" | _html_to_markdown) ;;
    esac
fi

# Check for existing concept with same resource (idempotency)
EXISTING_PATH=""
while IFS= read -r cid; do
    cfile="$BUNDLE/${cid}.md"
    res=$(okf_fm_get "$cfile" "resource" 2>/dev/null || true)
    if [[ "$res" == "$SOURCE" ]]; then
        EXISTING_PATH="$cfile"
        break
    fi
done < <(okf_list_concepts "$BUNDLE")

if [[ -n "$EXISTING_PATH" ]]; then
    TARGET_PATH="$EXISTING_PATH"
    IS_UPDATE=1
else
    if [[ -z "$ID" ]]; then
        # Derive slug from title or source
        STEM=""
        if [[ -n "$TITLE" ]]; then
            STEM="$TITLE"
        elif [[ "$SOURCE" == http://* || "$SOURCE" == https://* ]]; then
            # Last path component of URL
            STEM="${SOURCE%%\?*}"
            STEM="${STEM%%#*}"
            STEM="${STEM%/}"
            STEM="${STEM##*/}"
        else
            STEM="$(basename "${SOURCE}" | sed 's/\.[^.]*$//')"
        fi
        [[ -z "$STEM" ]] && STEM="ingested"
        SLUG=$(okf_slugify "$STEM")
        TYPE_LOWER="${TYPE,,}"
        if [[ "$TYPE_LOWER" == "source" ]]; then
            ID="sources/$SLUG"
        else
            ID="${TYPE_LOWER}s/$SLUG"
        fi
    fi
    TARGET_PATH="$BUNDLE/${ID}.md"
    IS_UPDATE=0
fi

# Determine title and description
if [[ -z "$TITLE" ]]; then
    FINAL_TITLE=$(okf_extract_title "$BODY" "$(basename "${TARGET_PATH%.md}" | sed 's/-/ /g')")
else
    FINAL_TITLE="$TITLE"
fi
FINAL_DESC=$(okf_extract_description "$BODY")

okf_render_concept \
    "$TARGET_PATH" \
    "$TYPE" \
    "$FINAL_TITLE" \
    "$FINAL_DESC" \
    "$SOURCE" \
    "$TAGS" \
    "$NOW" \
    "$BODY"

# Relative path from bundle root to concept file
CONCEPT_REL="${TARGET_PATH#$BUNDLE/}"

# Update index.md
INDEX_FILE="$BUNDLE/index.md"
if [[ ! -f "$INDEX_FILE" ]]; then
    printf '# %s\n\n' "$(basename "$BUNDLE")" > "$INDEX_FILE"
fi
INDEX_CONTENT=$(cat "$INDEX_FILE")
if ! grep -qF "$CONCEPT_REL" "$INDEX_FILE" && ! grep -qF "$FINAL_TITLE" "$INDEX_FILE"; then
    printf '%s\n- [%s](%s)\n' "${INDEX_CONTENT%$'\n'}" "$FINAL_TITLE" "$CONCEPT_REL" > "$INDEX_FILE"
fi

# Append to log.md
LOG_FILE="$BUNDLE/log.md"
if [[ ! -f "$LOG_FILE" ]]; then
    printf '# Log\n\n' > "$LOG_FILE"
fi
LOG_CONTENT=$(cat "$LOG_FILE")
LOG_ENTRY="## $NOW
- Ingested [$FINAL_TITLE]($CONCEPT_REL) from \`$SOURCE_LABEL\`

"
printf '%s\n%s' "${LOG_CONTENT%$'\n'}" "$LOG_ENTRY" > "$LOG_FILE"

if (( IS_UPDATE )); then
    echo "Updated: $TARGET_PATH"
else
    echo "Created: $TARGET_PATH"
fi
