#!/usr/bin/env bash
# Answer a question from an OKF bundle by ranking relevant concepts.
# Outputs JSON with hot_exists, index_exists, and scored results.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/okf_lib.sh"

usage() {
    echo "usage: okf-query.sh --bundle <path> --query <question> [--max <n>]" >&2
    exit 1
}

BUNDLE="" QUERY="" MAX=10
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle)  BUNDLE="$2";  shift 2 ;;
        --bundle=*) BUNDLE="${1#*=}"; shift ;;
        --query)   QUERY="$2";   shift 2 ;;
        --query=*) QUERY="${1#*=}"; shift ;;
        --max)     MAX="$2";     shift 2 ;;
        --max=*)   MAX="${1#*=}"; shift ;;
        *) echo "unknown option: $1" >&2; usage ;;
    esac
done

[[ -z "$BUNDLE" || -z "$QUERY" ]] && usage
BUNDLE="${BUNDLE/#\~/$HOME}"
BUNDLE="$(cd "$BUNDLE" && pwd)"

HOT_FILE="$BUNDLE/hot.md"
IDX_FILE="$BUNDLE/index.md"
hot_exists="false"; [[ -f "$HOT_FILE" ]] && hot_exists="true"
index_exists="false"; [[ -f "$IDX_FILE" ]] && index_exists="true"

# Phase 1: extract concept metadata to a TSV file.
# Columns (tab-separated): id, type, title, description, tags, body_snippet
# Internal newlines/tabs in values are replaced with spaces.
tmp_ids=$(mktemp)
tmp_data=$(mktemp)
trap 'rm -f "$tmp_ids" "$tmp_data"' EXIT

okf_list_concepts "$BUNDLE" > "$tmp_ids"

while IFS= read -r cid; do
    file="$BUNDLE/${cid}.md"
    okf_fm_has_type "$file" || continue

    ftype=$(okf_fm_get "$file" "type") || ftype=""
    ftitle=$(okf_fm_get "$file" "title") || ftitle=""
    [[ -z "$ftitle" ]] && { stem="${cid##*/}"; ftitle="${stem//-/ }"; }
    fdesc=$(okf_fm_get "$file" "description") || fdesc=""
    ftags=$(okf_fm_get_tags "$file" | tr '\n' ' ' | sed 's/ $//') || ftags=""
    fbody=$(okf_fm_body "$file" 2>/dev/null | head -c 2000 | tr '\n\t' '  ') || fbody=""

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cid" "$ftype" "$ftitle" "$fdesc" "$ftags" "$fbody"
done < "$tmp_ids" > "$tmp_data"

# Phase 2: score and rank concepts, emit JSON.
awk -v query="$QUERY" -v max_r="$MAX" \
    -v hot_exists="$hot_exists" \
    -v index_exists="$index_exists" \
    -v bundle="$BUNDLE" \
    -F'\t' '
BEGIN {
    phrase = tolower(query)
    gsub(/[^a-zA-Z0-9_+\-]+/, " ", phrase)

    raw_q = tolower(query)
    gsub(/[^a-zA-Z0-9_+\-]+/, " ", raw_q)
    n = split(raw_q, qtoks, " ")
    for (i = 1; i <= n; i++) {
        t = qtoks[i]
        if (t != "" && !is_stop(t)) qterms[t] = 1
    }
}
{
    cid   = $1; ftype = $2; ftitle = $3
    fdesc = $4; ftags = $5; fbody  = $6

    s = 0
    s += score_field(tolower(ftitle), 4, phrase)
    s += score_field(tolower(fdesc),  3, phrase)
    s += score_field(tolower(ftags),  3, phrase)
    s += score_field(tolower(ftype),  2, phrase)
    s += score_field(tolower(fbody),  1, phrase)

    if (s > 0) {
        n_res++
        res_id[n_res]    = cid
        res_score[n_res] = s
        res_title[n_res] = ftitle
        res_type[n_res]  = ftype
        res_desc[n_res]  = fdesc
        res_tags[n_res]  = ftags
    }
}
END {
    # Insertion sort descending by score
    for (i = 2; i <= n_res; i++) {
        ki = res_id[i]; ks = res_score[i]; kt = res_title[i]
        ktype = res_type[i]; kd = res_desc[i]; ktags = res_tags[i]
        j = i-1
        while (j >= 1 && res_score[j] < ks) {
            res_id[j+1]    = res_id[j]
            res_score[j+1] = res_score[j]
            res_title[j+1] = res_title[j]
            res_type[j+1]  = res_type[j]
            res_desc[j+1]  = res_desc[j]
            res_tags[j+1]  = res_tags[j]
            j--
        }
        res_id[j+1]    = ki; res_score[j+1] = ks; res_title[j+1] = kt
        res_type[j+1]  = ktype; res_desc[j+1] = kd; res_tags[j+1] = ktags
    }

    print "{"
    printf "  \"bundle\": \"%s\",\n",       ej(bundle)
    printf "  \"query\": \"%s\",\n",        ej(query)
    printf "  \"hot_exists\": %s,\n",       hot_exists
    printf "  \"index_exists\": %s,\n",     index_exists
    print  "  \"results\": ["
    limit = (n_res < max_r) ? n_res : max_r
    for (i = 1; i <= limit; i++) {
        tag_j = build_tags(res_tags[i])
        desc_j = (res_desc[i] == "" || res_desc[i] == "null") ? "null" : "\"" ej(res_desc[i]) "\""
        printf "    {\"id\": \"%s\", \"title\": \"%s\", \"type\": \"%s\", \"description\": %s, \"tags\": %s, \"score\": %s}%s\n",
            ej(res_id[i]), ej(res_title[i]), ej(res_type[i]),
            desc_j, tag_j, res_score[i],
            (i < limit ? "," : "")
    }
    print "  ]"
    print "}"
}
function score_field(text, w, phrase,    toks, m, c, t) {
    m = split(text, toks, /[^a-zA-Z0-9_+\-]+/)
    c = 0
    for (t = 1; t <= m; t++) {
        if (toks[t] != "" && (toks[t] in qterms)) c++
    }
    if (index(text, phrase) > 0) c += 5
    return c * w
}
function is_stop(w) {
    return (w ~ /^(a|an|the|is|are|was|were|be|been|being|to|of|and|or|in|on|at|for|with|from|as|it|its|this|that|these|those|how|what|when|where|why|who|which|can|do|does|did|i|you|we|they|my|your|our|their)$/)
}
function ej(s) {
    gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
    gsub(/\n/, "\\n",   s); gsub(/\r/, "\\r", s)
    gsub(/\t/, "\\t",   s)
    return s
}
function build_tags(tag_str,    a, n, i, out) {
    if (tag_str == "") return "[]"
    n = split(tag_str, a, " ")
    out = "["
    for (i = 1; i <= n; i++) {
        if (a[i] == "") continue
        out = out (out == "[" ? "" : ", ") "\"" ej(a[i]) "\""
    }
    return out "]"
}
' "$tmp_data"
