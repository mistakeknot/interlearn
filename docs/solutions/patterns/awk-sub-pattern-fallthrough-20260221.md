---
title: "Awk sub() Mutates $0 Causing Pattern Fall-Through on Same Line"
category: correctness
tags: [awk, shell, parsing, frontmatter, pattern-matching, sub, $0-mutation]
severity: P2
discovery: implementation
applies_to: [interlearn]
date: 2026-02-21
---

# Awk sub() Mutates $0 Causing Pattern Fall-Through on Same Line

## Problem Statement

Multi-line YAML tag parser in `index-solutions.sh` only extracted the first tag from lists like:

```yaml
tags:
  - tui
  - lipgloss
  - bubble-tea
```

Expected: `tui,lipgloss,bubble-tea`. Actual: `tui`.

## Investigation

1. Verified the frontmatter extraction was correct — all 7 tag lines were present in the variable.
2. Tested the awk command in isolation with `echo "$FRONTMATTER" | awk '...'` — it worked correctly, returning all tags.
3. Tested inside the full script context — only returned first tag.
4. Added debug output to awk — discovered the `exit` in the second pattern rule fired immediately after the first tag was processed.
5. Used `cat -A` to inspect for hidden characters — none found.
6. Key realization: the difference between the working isolated test and the failing in-script test was that awk's pattern evaluation processes ALL rules per line, and `sub()` modifies `$0` in-place.

## Root Cause

In awk, all pattern-action rules are evaluated for each input line, top to bottom. The original code had two rules that both checked `$0`:

```awk
# Rule 1: process tag lines
found && /^  - / { sub(/^  - */, ""); items = items "," $0 }

# Rule 2: exit on non-tag lines
found && !/^  - / { exit }
```

When processing `  - tui`:
1. Rule 1 matches `/^  - /` — fires, `sub()` changes `$0` from `  - tui` to `tui`
2. Rule 2 checks `!/^  - /` against the **modified** `$0` (`tui`) — it does NOT start with `  - `, so `!/^  - /` is TRUE
3. Rule 2 fires, executing `exit` after only one tag

## Solution

Add `next` after Rule 1 to skip subsequent rules for the current line:

```awk
# BEFORE (broken):
found && /^  - / { sub(/^  - */, ""); gsub(/"/, ""); items = items ? items "," $0 : $0 }
found && !/^  - / { exit }

# AFTER (correct):
found && /^  - / { sub(/^  - */, ""); gsub(/"/, ""); items = items ? items "," $0 : $0; next }
found && !/^  - / { exit }
```

## Files Changed

- `plugins/interlearn/scripts/index-solutions.sh` (line 119)

## Prevention

### Detection - Catch Early
- Whenever an awk script has multiple pattern-action rules that check `$0` or fields derived from it, verify whether earlier rules modify `$0` via `sub()`, `gsub()`, or field assignment.
- Test with multi-element inputs, not just single-element cases.

### Best Practices
- **Always use `next` after a rule that modifies `$0`** if subsequent rules check `$0` patterns. This is analogous to `continue` in a loop or early return in a function.
- Alternatively, capture the original value before modifying: `orig=$0; sub(...); ...` and use `orig` in later rules.
- Prefer `next` — it's idiomatic awk and makes the rule exclusivity explicit.

### Testing
- Test YAML tag parsing with: 0 tags, 1 tag, 3+ tags, tags with quotes, tags with hyphens.
- The bug only manifests with 2+ tags — single-tag inputs work correctly because awk reaches EOF after processing the one line.

## Key Insight

In awk, `sub()` and `gsub()` modify `$0` in-place, and ALL pattern-action rules evaluate against the CURRENT `$0`. Without `next`, a rule that strips a prefix from `$0` will cause a subsequent "does not match prefix" rule to fire on the same line. This is a silent correctness bug — no error, just wrong output.

## Related

- [GNU Awk Manual — Pattern-Action Rules](https://www.gnu.org/software/gawk/manual/gawk.html#Pattern-Action-Summary): "Awk reads an input record and evaluates each rule's pattern. For each pattern that matches, awk executes the associated action."
- `docs/guides/shell-and-tooling-patterns.md` — shell scripting conventions in Interverse
