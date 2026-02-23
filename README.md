# interlearn

A Claude Code plugin that turns "we solved this before" from folklore into something you can actually query.

## What This Is

Every repo accumulates hard-won fixes in `docs/solutions/` and then quietly forgets they exist. interlearn is the memory layer for that problem. It builds a cross-repo index of solution docs, gives you a fast search surface, and audits whether closed work actually left behind useful documentation.

If interflux is your reviewer and interpath is your artifact generator, interlearn is the institutional memory that keeps both from reinventing the same lessons every two weeks.

## How It Works

interlearn is intentionally simple: one indexing script, one skill, one hook.

- `scripts/index-solutions.sh` scans `docs/solutions/*.md` across the Interverse monorepo, parses frontmatter (including mixed schemas), and writes:
  - `docs/solutions/INDEX.md` for humans
  - `docs/solutions/index.json` for tools
- `skills/interlearn/SKILL.md` provides three operator modes:
  - `/interlearn:index`
  - `/interlearn:search <query>`
  - `/interlearn:audit`
- `hooks/session-end.sh` refreshes the index on `SessionEnd` when you're in the monorepo, so the memory layer stays warm.

The design philosophy is straightforward: deterministic artifacts, path-derived module truth, and no hidden mutation.

## Getting Started

Install from the interagency marketplace:

```bash
claude plugins install interlearn@interagency-marketplace
```

Then:

1. **Build the index**: `/interlearn:index`
2. **Find prior work**: `/interlearn:search websocket timeout`
3. **Check coverage**: `/interlearn:audit`

The index is written to the monorepo root at `docs/solutions/`.

## Architecture

```
.claude-plugin/plugin.json   -> plugin manifest
skills/interlearn/SKILL.md   -> index/search/audit workflow
scripts/index-solutions.sh   -> deterministic cross-repo index builder
hooks/hooks.json             -> SessionEnd hook registration
hooks/session-end.sh         -> background index refresh trigger
```

## Design Decisions

A few choices are deliberate:

- **Shell-first implementation.** No MCP server, no daemon, no compiled binary for this phase.
- **Path is canonical module identity.** Frontmatter `module:` is too inconsistent to trust for grouping.
- **Schema-tolerant parsing.** Handles `problem_type` vs `category`, and multiple date keys.
- **Fail-open hook behavior.** Session teardown should never fail because indexing failed.
- **No auto-commit.** interlearn writes artifacts; humans decide when to commit them.

## Current Scope

Right now the skill and hook target the Interverse monorepo path conventions (`/root/projects/Interverse`). That's intentional for operational reliability in the current environment.

## What's Next

Improved ranking heuristics, stronger coverage auditing, and tighter integration with planning/review workflows so relevant prior fixes are surfaced before new work drifts into duplicate effort.
