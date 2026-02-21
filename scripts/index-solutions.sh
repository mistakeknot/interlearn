#!/usr/bin/env bash
#
# index-solutions.sh — Cross-repo solution doc indexer for Interverse.
#
# Scans all docs/solutions/*.md files across hub/, plugins/, services/,
# infra/, and root docs/, parses YAML frontmatter, and generates:
#   - docs/solutions/INDEX.md   (human-readable, grouped by module)
#   - docs/solutions/index.json (machine-readable, flat + by_module)
#
# Usage:
#   bash index-solutions.sh <interverse-root>
#
# The script is deterministic — running it twice on the same input
# produces identical output (sorted by module + path).

set -euo pipefail

INTERVERSE_ROOT="${1:?Usage: index-solutions.sh <interverse-root>}"
INTERVERSE_ROOT="$(cd "$INTERVERSE_ROOT" && pwd)"

OUTPUT_DIR="$INTERVERSE_ROOT/docs/solutions"
INDEX_MD="$OUTPUT_DIR/INDEX.md"
INDEX_JSON="$OUTPUT_DIR/index.json"

mkdir -p "$OUTPUT_DIR"

# --- Exclusion patterns ---
# Meta-docs that aren't solution docs
EXCLUDE_NAMES="INDEX.md|README.md|TEMPLATE.md"
EXCLUDE_SUFFIXES="_INDEX.md|_SUMMARY.md|_REFERENCE.md|_QUICK_START.md"

# All-caps filenames that are reference/guide docs (not solution docs)
is_excluded() {
    local basename="$1"
    # Check exact name matches
    if echo "$basename" | grep -qE "^($EXCLUDE_NAMES)$"; then
        return 0
    fi
    # Check suffix matches
    if echo "$basename" | grep -qE "($EXCLUDE_SUFFIXES)$"; then
        return 0
    fi
    # Check all-uppercase filenames (reference docs, not solutions)
    # Allow date-prefixed files and lowercase files through
    if echo "$basename" | grep -qE '^[A-Z][A-Z_]+\.md$'; then
        return 0
    fi
    return 1
}

# --- Find all solution docs ---
TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

find "$INTERVERSE_ROOT/hub" \
     "$INTERVERSE_ROOT/plugins" \
     "$INTERVERSE_ROOT/services" \
     "$INTERVERSE_ROOT/infra" \
     "$INTERVERSE_ROOT/docs" \
     -path '*/docs/solutions/*.md' \
     -type f \
     2>/dev/null | sort > "$TMPDIR_WORK/all_files.txt"

# --- Parse frontmatter and build entries ---
ENTRIES_FILE="$TMPDIR_WORK/entries.jsonl"
: > "$ENTRIES_FILE"

parse_frontmatter() {
    local file="$1"
    local rel_path="${file#$INTERVERSE_ROOT/}"
    local basename
    basename="$(basename "$file")"

    # Skip excluded files
    if is_excluded "$basename"; then
        return
    fi

    # Extract YAML frontmatter (between first and second ---)
    local frontmatter
    frontmatter="$(awk '/^---/{n++; if(n==2) exit} n==1{print}' "$file")"

    # Derive module from path: hub/<mod>/... → <mod>, plugins/<mod>/... → <mod>, etc.
    local module=""
    module="$(echo "$rel_path" | awk -F/ '{
        if ($1 == "docs") print "interverse"
        else if (NF >= 2) print tolower($2)
    }')"

    # Extract fields from frontmatter (handles both schemas)
    # All grep calls guarded with || true to prevent set -e failures
    local title="" date="" problem_type="" severity="" tags=""

    if [ -n "$frontmatter" ]; then
        title="$(echo "$frontmatter" | grep -m1 '^title:' | sed 's/^title: *//; s/^"//; s/"$//' || true)"

        # date: try date, created, date_resolved, date_discovered
        date="$(echo "$frontmatter" | grep -m1 -E '^(date|created|date_resolved|date_discovered):' | sed 's/^[^:]*: *//; s/^"//; s/"$//' || true)"

        # problem_type: try problem_type, then category
        problem_type="$(echo "$frontmatter" | grep -m1 '^problem_type:' | sed 's/^problem_type: *//' || true)"
        if [ -z "$problem_type" ]; then
            problem_type="$(echo "$frontmatter" | grep -m1 '^category:' | sed 's/^category: *//' || true)"
        fi

        severity="$(echo "$frontmatter" | grep -m1 '^severity:' | sed 's/^severity: *//' || true)"

        # tags: handle both [inline] and multi-line formats
        local tags_line
        tags_line="$(echo "$frontmatter" | grep -m1 '^tags:' || true)"
        if [ -n "$tags_line" ]; then
            local tags_value="${tags_line#tags:}"
            tags_value="${tags_value# }"
            if [[ "$tags_value" == \[* ]]; then
                # Inline format: [tag1, tag2, tag3]
                tags="$(echo "$tags_value" | tr -d '[]"' | sed 's/, */,/g')"
            elif [ -z "$tags_value" ]; then
                # Multi-line format: collect indented "  - item" lines
                tags="$(echo "$frontmatter" | awk '/^tags:/{found=1; next} found && /^  - /{sub(/^  - */, ""); gsub(/"/, ""); items = items ? items "," $0 : $0; next} found && !/^  - /{exit} END{print items}')"
            fi
        fi

        # module: always use path-derived module for grouping
        # Frontmatter module: is often descriptive ("System", "Flux-Drive", "Plugin")
        # rather than matching the actual repo directory, so it's unreliable for grouping.
        # Path-derived module is canonical.
        :
    fi

    # Fall back: title from first H1 heading
    if [ -z "$title" ]; then
        title="$(grep -m1 '^# ' "$file" | sed 's/^# //' || true)"
    fi
    # Last resort: filename
    if [ -z "$title" ]; then
        title="$(echo "$basename" | sed 's/\.md$//; s/-/ /g; s/_/ /g')"
    fi

    # Infer problem_type from path subdirectory if missing
    if [ -z "$problem_type" ]; then
        local subdir
        subdir="$(echo "$rel_path" | awk -F/ '{for(i=1;i<=NF;i++){if($i=="solutions" && i+1<NF){print $(i+1); exit}}}')"
        if [ -n "$subdir" ] && [ "$subdir" != "$basename" ]; then
            problem_type="$subdir"
        fi
    fi

    # Build JSON entry using jq
    local tags_json="[]"
    if [ -n "$tags" ]; then
        tags_json="$(echo "$tags" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | jq -R . | jq -sc .)"
    fi

    jq -nc \
        --arg path "$rel_path" \
        --arg module "$module" \
        --arg title "$title" \
        --arg date "$date" \
        --arg problem_type "$problem_type" \
        --arg severity "$severity" \
        --argjson tags "$tags_json" \
        '{path: $path, module: $module, title: $title, date: $date, problem_type: $problem_type, severity: $severity, tags: $tags}' \
        >> "$ENTRIES_FILE"
}

while IFS= read -r file; do
    parse_frontmatter "$file"
done < "$TMPDIR_WORK/all_files.txt"

# Sort entries deterministically by module + path
jq -sc 'sort_by(.module, .path)' "$ENTRIES_FILE" > "$TMPDIR_WORK/sorted_entries.json"

TOTAL_COUNT="$(jq 'length' "$TMPDIR_WORK/sorted_entries.json")"

# --- Generate index.json ---
jq -n \
    --argjson entries "$(cat "$TMPDIR_WORK/sorted_entries.json")" \
    --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson count "$TOTAL_COUNT" \
    '{
        generated: $generated,
        count: $count,
        entries: $entries,
        by_module: ($entries | group_by(.module) | map({key: .[0].module, value: .}) | from_entries)
    }' > "$TMPDIR_WORK/index.json"

mv "$TMPDIR_WORK/index.json" "$INDEX_JSON"

# --- Generate INDEX.md ---
{
    echo "# Solution Docs Index"
    echo ""
    echo "Cross-repo index of institutional knowledge across the Interverse monorepo."
    echo ""
    echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ) | **Total:** $TOTAL_COUNT docs"
    echo ""
    echo "---"
    echo ""

    # Group by module
    jq -r '
        group_by(.module) | .[] |
        "## " + .[0].module + " (" + (length | tostring) + " docs)\n\n" +
        "| Doc | Type | Severity | Date | Tags |\n" +
        "|-----|------|----------|------|------|\n" +
        (map(
            "| [" + .title + "](" + .path + ") | " +
            .problem_type + " | " +
            .severity + " | " +
            .date + " | " +
            (.tags | if length > 0 then join(", ") else "" end) +
            " |"
        ) | join("\n")) + "\n"
    ' "$TMPDIR_WORK/sorted_entries.json"
} > "$TMPDIR_WORK/INDEX.md"

mv "$TMPDIR_WORK/INDEX.md" "$INDEX_MD"

echo "Indexed $TOTAL_COUNT solution docs → $INDEX_MD, $INDEX_JSON"
