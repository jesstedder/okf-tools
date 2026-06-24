#!/usr/bin/env bash
# Convert a claude-obsidian vault to an OKF bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/okf_lib.sh"

usage() {
    echo "usage: okf-convert-claude-obsidian.sh --source <vault> --dest <path>" >&2
    echo "       [--dry-run] [--keep-wikilinks]" >&2
    exit 1
}

SOURCE="" DEST="" DRY_RUN=0 KEEP_WIKILINKS=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)  SOURCE="$2"; shift 2 ;;
        --source=*) SOURCE="${1#*=}"; shift ;;
        --dest)    DEST="$2";   shift 2 ;;
        --dest=*)  DEST="${1#*=}"; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --keep-wikilinks) KEEP_WIKILINKS=1; shift ;;
        *) echo "unknown option: $1" >&2; usage ;;
    esac
done

[[ -z "$SOURCE" || -z "$DEST" ]] && usage
SOURCE="${SOURCE/#\~/$HOME}"
DEST="${DEST/#\~/$HOME}"
SOURCE="$(cd "$SOURCE" && pwd)"
DEST="$(cd "$(dirname "$DEST")" && pwd)/$(basename "$DEST")"

if [[ $DRY_RUN -eq 0 && -d "$DEST" && -n "$(ls -A "$DEST" 2>/dev/null)" ]]; then
    echo "error: destination is not empty: $DEST" >&2
    exit 1
fi

# Folder-to-type mapping
_folder_type() {
    case "$1" in
        concepts)   echo "Concept" ;;
        entities)   echo "Entity" ;;
        guides)     echo "Guide" ;;
        homelab)    echo "Decision" ;;
        meta)       echo "Decision" ;;
        questions)  echo "Question" ;;
        references) echo "Reference" ;;
        sources)    echo "Source" ;;
        *)          echo "Concept" ;;
    esac
}

# Use wiki/ subdir if it exists, else vault root
if [[ -d "$SOURCE/wiki" ]]; then
    WIKI_ROOT="$SOURCE/wiki"
else
    WIKI_ROOT="$SOURCE"
fi

# Phase 1: discover .md files and compute concept IDs
tmp_ids=$(mktemp)
tmp_entries=$(mktemp)  # format: SRC_PATH|REL_DIR|CONCEPT_ID
trap 'rm -f "$tmp_ids" "$tmp_entries"' EXIT

while IFS= read -r -d '' f; do
    rel="${f#$WIKI_ROOT/}"
    base="${rel##*/}"
    # Skip reserved files
    case "${base,,}" in index.md|log.md|hot.md) continue;; esac
    # Skip hidden dirs
    dir="${rel%/*}"
    if [[ "$dir" != "$rel" ]]; then
        skip=0
        IFS='/' read -ra parts <<< "$dir"
        for part in "${parts[@]}"; do [[ "$part" == .* ]] && skip=1 && break; done
        (( skip )) && continue
    fi
    # Compute concept ID
    if [[ "$dir" == "$rel" ]]; then
        rel_dir=""
    else
        rel_dir="$dir"
    fi
    stem="${base%.md}"
    slug=$(okf_slugify "$stem")
    if [[ -n "$rel_dir" ]]; then
        concept_id="${rel_dir}/${slug}"
    else
        concept_id="$slug"
    fi
    printf '%s\n' "$concept_id" >> "$tmp_ids"
    printf '%s|%s|%s\n' "$f" "$rel_dir" "$concept_id" >> "$tmp_entries"
done < <(find "$WIKI_ROOT" -name "*.md" -print0 | sort -z)

total=$(wc -l < "$tmp_entries")
shown=0

# Phase 2: convert each concept.
# Use fd 9 for reading entries so stdin stays free for okf_rewrite_wikilinks (which uses awk - ).
exec 9< "$tmp_entries"
while IFS='|' read -r src_path rel_dir concept_id <&9; do
    stem="${src_path##*/}"
    stem="${stem%.md}"

    # Extract body (strip existing frontmatter if present)
    first_line=$(head -1 "$src_path")
    if [[ "$first_line" == "---" ]]; then
        line2=$(awk 'NR>1 && /^---/{print NR; exit}' "$src_path")
        if [[ -n "$line2" ]]; then
            body=$(tail -n +"$((line2+1))" "$src_path" | sed '/./,$!d')
        else
            body=$(cat "$src_path")
        fi
    else
        body=$(cat "$src_path")
    fi

    # Determine type from folder
    top_folder="${rel_dir%%/*}"
    concept_type=$(_folder_type "$top_folder")

    # Extract metadata
    title=$(okf_extract_title "$body" "$stem")
    desc=$(okf_extract_description "$body")
    # Extract hashtags from body
    hashtags=$(okf_extract_hashtags "$body" | tr '\n' ',' | sed 's/,$//')

    # Get mtime as ISO 8601 timestamp
    if stat --version &>/dev/null 2>&1; then
        # GNU stat (Linux)
        mtime=$(stat -c %Y "$src_path")
    else
        # BSD stat (macOS)
        mtime=$(stat -f %m "$src_path")
    fi
    timestamp=$(date -u -d "@$mtime" +"%Y-%m-%dT%H:%M:%S+00:00" 2>/dev/null || \
                date -u -r "$mtime" +"%Y-%m-%dT%H:%M:%S+00:00" 2>/dev/null || \
                date -u +"%Y-%m-%dT%H:%M:%S+00:00")

    # Rewrite wikilinks (unless --keep-wikilinks)
    if (( ! KEEP_WIKILINKS )); then
        body=$(printf '%s' "$body" | okf_rewrite_wikilinks "$concept_id" "$tmp_ids")
    fi

    if [[ -n "$rel_dir" ]]; then
        dest_rel="${rel_dir}/$(okf_slugify "$stem").md"
    else
        dest_rel="$(okf_slugify "$stem").md"
    fi
    dest_path="$DEST/$dest_rel"

    if (( shown < 10 )); then
        if (( DRY_RUN )); then
            echo "WOULD CREATE: $dest_path"
        else
            echo "CREATED: $dest_path"
        fi
        (( shown++ )) || true
    fi

    if (( ! DRY_RUN )); then
        okf_render_concept \
            "$dest_path" \
            "$concept_type" \
            "$title" \
            "$desc" \
            "" \
            "$hashtags" \
            "$timestamp" \
            "$body"
    fi
done
exec 9<&-

remaining=$(( total - 10 ))
(( remaining > 0 )) && echo "... and $remaining more"

# Write OKF control files (only on real run)
if (( ! DRY_RUN )); then
    mkdir -p "$DEST"

    if [[ -f "$WIKI_ROOT/index.md" ]]; then
        if (( KEEP_WIKILINKS )); then
            cp "$WIKI_ROOT/index.md" "$DEST/index.md"
        else
            printf '%s' "$(cat "$WIKI_ROOT/index.md")" | \
                okf_rewrite_wikilinks "" "$tmp_ids" > "$DEST/index.md"
        fi
    else
        printf '# %s\n\nConverted from claude-obsidian vault.\n' \
            "$(basename "$DEST")" > "$DEST/index.md"
    fi

    if [[ -f "$WIKI_ROOT/log.md" ]]; then
        if (( KEEP_WIKILINKS )); then
            cp "$WIKI_ROOT/log.md" "$DEST/log.md"
        else
            printf '%s' "$(cat "$WIKI_ROOT/log.md")" | \
                okf_rewrite_wikilinks "" "$tmp_ids" > "$DEST/log.md"
        fi
    else
        printf '# Log\n\nConverted vault.\n' > "$DEST/log.md"
    fi

    if [[ -f "$WIKI_ROOT/hot.md" ]]; then
        if (( KEEP_WIKILINKS )); then
            cp "$WIKI_ROOT/hot.md" "$DEST/hot.md"
        else
            printf '%s' "$(cat "$WIKI_ROOT/hot.md")" | \
                okf_rewrite_wikilinks "" "$tmp_ids" > "$DEST/hot.md"
        fi
    fi
fi

echo ""
echo "Total concepts: $total"
