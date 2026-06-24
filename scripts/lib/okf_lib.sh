#!/usr/bin/env bash
# OKF shared bash library.
# Source with: source "$(dirname "${BASH_SOURCE[0]}")/lib/okf_lib.sh"

# Get a single string frontmatter field value from a .md file.
# Prints the value, or nothing if absent/null.
okf_fm_get() {
    local file="$1" field="$2"
    [[ "$(head -1 "$file")" == "---" ]] || return
    awk -v f="$field" '
        NR == 1 { next }
        /^---[[:space:]]*$/ { exit }
        {
            if (match($0, "^" f ":[[:space:]]*")) {
                val = substr($0, RLENGTH+1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
                gsub(/^["'"'"']|["'"'"']$/, "", val)
                if (val != "null") print val
                exit
            }
        }
    ' "$file"
}

# Get tags from frontmatter as newline-separated values.
# Handles block sequences (- tag) and inline arrays ([tag1, tag2]).
okf_fm_get_tags() {
    local file="$1"
    [[ "$(head -1 "$file")" == "---" ]] || return
    awk '
        NR == 1 { next }
        /^---[[:space:]]*$/ { exit }
        /^tags:[[:space:]]*\[/ {
            val = $0; sub(/^tags:[[:space:]]*\[/, "", val); sub(/\].*/, "", val)
            n = split(val, arr, ",")
            for (i=1; i<=n; i++) {
                gsub(/^[[:space:]"'"'"']+|[[:space:]"'"'"']+$/, "", arr[i])
                if (arr[i] != "") print arr[i]
            }
            in_tags = 0; next
        }
        /^tags:/ { in_tags = 1; next }
        in_tags && /^[[:space:]]*-[[:space:]]/ {
            tag = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", tag)
            gsub(/^[[:space:]"'"'"']+|[[:space:]"'"'"']+$/, "", tag)
            if (tag != "") print tag; next
        }
        in_tags && /^[^[:space:]-]/ { in_tags = 0 }
    ' "$file"
}

# Print the body content (everything after the closing ---).
# Leading blank lines are stripped.
okf_fm_body() {
    local file="$1"
    local first_line
    first_line=$(head -1 "$file")
    if [[ "$first_line" != "---" ]]; then
        cat "$file"
        return
    fi
    local line2
    line2=$(awk 'NR>1 && /^---[[:space:]]*$/{print NR; exit}' "$file")
    if [[ -z "$line2" ]]; then
        cat "$file"
        return
    fi
    tail -n +"$((line2 + 1))" "$file" | sed '/./,$!d'
}

# Return 0 if the file has a non-empty type field, 1 otherwise.
okf_fm_has_type() {
    local t
    t=$(okf_fm_get "$1" "type")
    [[ -n "$t" ]]
}

# Convert a string to a URL/filename-safe slug.
okf_slugify() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-zA-Z0-9_-]\+/-/g; s/^-\+//; s/-\+$//'
}

# Normalize a path: resolve . and .. components, lowercase.
okf_normalize_path() {
    local path="${1//\\/\/}"
    local -a parts=()
    local part
    IFS='/' read -ra raw <<< "$path"
    for part in "${raw[@]}"; do
        if [[ "$part" == ".." && ${#parts[@]} -gt 0 ]]; then
            unset 'parts[-1]'
        elif [[ -n "$part" && "$part" != "." ]]; then
            parts+=("$part")
        fi
    done
    (IFS='/'; printf '%s' "${parts[*]}" | tr '[:upper:]' '[:lower:]')
}

# Compute a relative markdown link path from source concept to target concept.
# Both are concept IDs (no .md suffix, no leading slash).
# Example: okf_relative_path "concepts/my-note" "entities/bob" → "../entities/bob.md"
okf_relative_path() {
    local source="$1" target="$2"
    case "$source" in
        */*) local sdir="${source%/*}" ;;
        *)   printf '%s.md\n' "$target"; return ;;
    esac

    local -a SPARTS TPARTS
    IFS='/' read -ra SPARTS <<< "$sdir"
    IFS='/' read -ra TPARTS <<< "$target"
    local ns=${#SPARTS[@]} nt=${#TPARTS[@]} i=0

    while (( i < ns && i < nt-1 )) && [[ "${SPARTS[$i]}" == "${TPARTS[$i]}" ]]; do
        (( i++ )) || true
    done

    local rel="" j
    for (( j=i; j<ns; j++ )); do rel="${rel:+$rel/}.."; done
    for (( j=i; j<nt-1; j++ )); do rel="${rel:+$rel/}${TPARTS[$j]}"; done
    printf '%s%s.md\n' "${rel:+$rel/}" "${TPARTS[$((nt-1))]}"
}

# List all concept IDs in a bundle (relative paths, no .md extension, sorted).
# Skips reserved files and hidden-directory contents.
okf_list_concepts() {
    local root
    root="$(cd "$1" && pwd)"
    while IFS= read -r -d '' f; do
        local rel="${f#$root/}"
        local base="${rel##*/}"
        case "${base,,}" in index.md|log.md|hot.md) continue;; esac
        local dir="${rel%/*}"
        if [[ "$dir" != "$rel" ]]; then
            local skip=0 part
            IFS='/' read -ra parts <<< "$dir"
            for part in "${parts[@]}"; do
                [[ "$part" == .* ]] && skip=1 && break
            done
            (( skip )) && continue
        fi
        printf '%s\n' "${rel%.md}"
    done < <(find "$root" -name "*.md" -print0 | sort -z)
}

# Extract title: first H1 line, or derive from filename stem.
okf_extract_title() {
    local body="$1" stem="$2"
    local title
    title=$(printf '%s\n' "$body" | grep -m1 '^# ' | sed 's/^# //')
    printf '%s\n' "${title:-${stem//-/ }}"
}

# Extract description: first non-heading, non-empty line (up to 200 chars).
okf_extract_description() {
    local body="$1"
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        printf '%s\n' "${line:0:200}"
        return
    done <<< "$body"
}

# Extract #hashtag patterns from body as newline-separated tags.
okf_extract_hashtags() {
    printf '%s\n' "$1" | { grep -oE '#[A-Za-z0-9_-]+' || true; } | sed 's/^#//'
}

# Print a YAML scalar value, quoting with single quotes when necessary.
_okf_yaml_str() {
    local val="$1"
    if [[ -z "$val" ]]; then
        printf 'null'
        return
    fi
    local need_quote=0
    [[ "$val" =~ ^[[:space:]] || "$val" =~ [[:space:]]$ ]] && need_quote=1
    [[ "$val" =~ ^[:\#\&\*\!\|\>\'\"%@\`\{\}\[\]] ]] && need_quote=1
    [[ "$val" == *": "* ]] && need_quote=1
    case "$val" in null|true|false|yes|no|on|off) need_quote=1;; esac
    if (( need_quote )); then
        printf "'%s'" "${val//\'/\'\'}"
    else
        printf '%s' "$val"
    fi
}

# Write an OKF concept file to DEST.
# Args: DEST TYPE TITLE DESCRIPTION RESOURCE TAGS TIMESTAMP BODY
# TAGS is comma-separated. DESCRIPTION, RESOURCE may be empty strings.
okf_render_concept() {
    local dest="$1" type="$2" title="$3" desc="$4" resource="$5" \
          tags="$6" timestamp="$7" body="$8"
    mkdir -p "$(dirname "$dest")"
    {
        echo '---'
        echo "type: $(_okf_yaml_str "$type")"
        echo "title: $(_okf_yaml_str "$title")"
        echo "description: $(_okf_yaml_str "$desc")"
        [[ -n "$resource" ]] && echo "resource: $(_okf_yaml_str "$resource")"
        if [[ -n "$tags" ]]; then
            echo 'tags:'
            IFS=',' read -ra _tag_arr <<< "$tags"
            local _t
            for _t in "${_tag_arr[@]}"; do
                _t="${_t#"${_t%%[![:space:]]*}"}"
                _t="${_t%"${_t##*[![:space:]]}"}"
                [[ -n "$_t" ]] && echo "- $_t"
            done
        else
            echo 'tags: []'
        fi
        echo "timestamp: $timestamp"
        echo '---'
        echo ''
        printf '%s\n' "$body"
    } > "$dest"
}

# Rewrite Obsidian wikilinks to relative markdown links.
# Reads content from stdin; prints rewritten content to stdout.
# Usage: printf '%s' "$content" | okf_rewrite_wikilinks SOURCE_ID IDS_FILE
# IDS_FILE: plain text file with one concept ID per line.
okf_rewrite_wikilinks() {
    local source_id="$1" ids_file="$2"
    awk -v source_id="$source_id" '
        FNR == NR {
            id = $0
            lower = tolower(id); gsub(/ /, "-", lower)
            ids[lower] = id
            n = split(id, parts, "/")
            base = tolower(parts[n]); gsub(/ /, "-", base)
            if (!(base in basenames)) basenames[base] = id
            next
        }
        {
            line = $0; out = ""
            while (match(line, /\[\[[^]]+\]\]/)) {
                out = out substr(line, 1, RSTART-1)
                raw = substr(line, RSTART, RLENGTH)
                line = substr(line, RSTART+RLENGTH)
                inner = substr(raw, 3, length(raw)-4)
                pipe = index(inner, "|")
                if (pipe > 0) {
                    target = substr(inner, 1, pipe-1)
                    label  = substr(inner, pipe+1)
                } else {
                    target = inner; label = inner
                }
                gsub(/^[ \t]+|[ \t]+$/, "", target)
                gsub(/^[ \t]+|[ \t]+$/, "", label)
                lt = tolower(target); gsub(/ /, "-", lt)
                resolved = ""
                if (lt in ids)      resolved = ids[lt]
                else if (lt in basenames) resolved = basenames[lt]
                if (resolved != "") {
                    rel = _relpath(source_id, resolved)
                    out = out "[" label "](" rel ".md)"
                } else {
                    out = out raw
                }
            }
            print out line
        }
        function _relpath(src, tgt,    n,i,j,tmp,sdir,ns,nt,common,rel,S,T) {
            n = split(src, tmp, "/")
            if (n <= 1) return tgt
            sdir = ""; for (i=1; i<n; i++) sdir = (sdir=="" ? tmp[i] : sdir"/"tmp[i])
            ns = split(sdir, S, "/"); nt = split(tgt, T, "/")
            i = 1; while (i<=ns && i<=nt-1 && S[i]==T[i]) i++
            common = i-1; rel = ""
            for (j=common+1; j<=ns; j++) rel = (rel=="" ? ".." : rel"/..")
            for (j=common+1; j<=nt-1; j++) rel = (rel=="" ? T[j] : rel"/"T[j])
            return (rel=="" ? T[nt] : rel"/"T[nt])
        }
    ' "$ids_file" -
}
