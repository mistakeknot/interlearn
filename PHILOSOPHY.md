# interlearn Philosophy

## Purpose
Cross-repo institutional knowledge index — indexes solution docs across the Interverse monorepo, enables unified search, and audits reflect coverage.

## North Star
Every solved problem should be findable from any repo in the ecosystem.

## Working Priorities
- Index completeness (no orphaned solution docs)
- Search relevance (right result in top 3)
- Reflect coverage (closed beads have solution docs)

## Brainstorming Doctrine
1. Start from outcomes and failure modes, not implementation details.
2. Generate at least three options: conservative, balanced, and aggressive.
3. Explicitly call out assumptions, unknowns, and dependency risk across modules.
4. Prefer ideas that improve clarity, reversibility, and operational visibility.

## Planning Doctrine
1. Convert selected direction into small, testable, reversible slices.
2. Define acceptance criteria, verification steps, and rollback path for each slice.
3. Sequence dependencies explicitly and keep integration contracts narrow.
4. Reserve optimization work until correctness and reliability are proven.

## Decision Filters
- Does this reduce re-solving of previously solved problems?
- Does this make the index more complete?
- Is the search result actionable without reading the full doc?
- Does this close the loop between beads and institutional knowledge?
