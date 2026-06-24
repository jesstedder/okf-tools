#!/usr/bin/env bash
# Validate an OKF bundle for structural issues and broken links.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/okf_lib.sh"

usage() { echo "usage: okf-validate.sh <bundle-path> [--strict]" >&2; exit 1; }

[[ $# -lt 1 ]] && usage

BUNDLE=""
# STRICT=0  # reserved for future use
while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict) shift ;;  # currently same behavior as default
        -*) echo "unknown option: $1" >&2; usage ;;
        *) BUNDLE="$1"; shift ;;
    esac
done

[[ -z "$BUNDLE" ]] && usage
BUNDLE="${BUNDLE/#\~/$HOME}"

if [[ ! -d "$BUNDLE" ]]; then
    echo "ERROR: [] bundle path is not a directory: $BUNDLE" >&2
    exit 1
fi

BUNDLE="$(cd "$BUNDLE" && pwd)"

findings=0

# Build the concept ID set (for link resolution)
tmp_ids=$(mktemp)
trap 'rm -f "$tmp_ids"' EXIT

okf_list_concepts "$BUNDLE" > "$tmp_ids"

# Build a lowercase→canonical map for case-insensitive ID collision detection
declare -A lower_ids=()

while IFS= read -r cid; do
    lower="${cid,,}"
    if [[ -n "${lower_ids[$lower]+set}" ]]; then
        echo "ERROR: [$cid] CONFLICTING_ID — duplicates concept ID (case-insensitive collision)"
        (( findings++ )) || true
    else
        lower_ids["$lower"]="$cid"
    fi
done < "$tmp_ids"

# For link resolution: build lowercase→canonical lookup
declare -A id_map=()
while IFS= read -r cid; do
    id_map["${cid,,}"]="$cid"
    base="${cid##*/}"
    # Also map basename for wikilink-style resolution
    bkey="__base__${base,,}"
    [[ -z "${id_map[$bkey]+set}" ]] && id_map["$bkey"]="$cid"
done < "$tmp_ids"

# Validate each concept file
while IFS= read -r cid; do
    file="$BUNDLE/${cid}.md"

    # Check type field
    if ! okf_fm_has_type "$file"; then
        echo "ERROR: [$cid] Missing or blank required frontmatter field: type"
        (( findings++ )) || true
        continue
    fi

    # Check for broken internal links in the body
    body=$(okf_fm_body "$file")

    # Extract markdown links: [label](target)
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        # Strip fragment
        link="${link%%#*}"
        link="${link% }"
        # Skip external links
        case "$link" in
            http://*|https://*|mailto:*|file://*|/*|"#"*) continue ;;
        esac
        # Resolve relative to source concept directory
        src_dir="${cid%/*}"
        if [[ "$src_dir" != "$cid" ]]; then
            # Normalize: strip .md, resolve path
            norm=$(okf_normalize_path "$src_dir/${link%.md}")
        else
            norm=$(okf_normalize_path "${link%.md}")
        fi
        # Check if resolved ID exists
        if [[ -z "${id_map[$norm]+set}" ]]; then
            echo "ERROR: [$cid] BROKEN_LINK: [$link] -> $link"
            (( findings++ )) || true
        fi
    done < <(printf '%s\n' "$body" | grep -oE '!?\[[^]]*\]\([^)]+\)' | \
             sed 's/^!*\[[^]]*\](\([^)]*\))/\1/')

    # Extract wikilinks: [[target]] or [[target|label]]
    while IFS= read -r wikilink; do
        [[ -z "$wikilink" ]] && continue
        # Strip pipe/label
        target="${wikilink%%|*}"
        # Skip external
        case "$target" in http://*|https://*) continue;; esac
        # Normalize for lookup
        norm=$(printf '%s' "$target" | tr '[:upper:]' '[:lower:]' | \
               sed 's/ /-/g' | sed 's/\.md$//')
        # Check by full normalized ID, then by basename
        local_found=0
        if [[ -n "${id_map[$norm]+set}" ]]; then
            local_found=1
        else
            bkey="__base__$norm"
            [[ -n "${id_map[$bkey]+set}" ]] && local_found=1
        fi
        if (( ! local_found )); then
            echo "ERROR: [$cid] BROKEN_LINK: [[$wikilink]] -> $target"
            (( findings++ )) || true
        fi
    done < <(printf '%s\n' "$body" | grep -oE '\[\[[^]]+\]\]' | \
             sed 's/^\[\[\(.*\)\]\]$/\1/')

done < "$tmp_ids"

if (( findings == 0 )); then
    echo "OK: $BUNDLE is a valid OKF bundle"
    exit 0
else
    echo ""
    echo "$findings finding(s)"
    exit 1
fi
