# interlearn

Cross-repo institutional knowledge index for the Interverse monorepo.

## What it does

- **Indexes** all `docs/solutions/*.md` files across `hub/`, `plugins/`, `services/`, `infra/`, and root
- **Generates** `docs/solutions/INDEX.md` (human-readable) and `docs/solutions/index.json` (machine-readable) at the Interverse root
- **Searches** across all solution docs with frontmatter-aware filtering
- **Audits** reflect coverage against closed beads

## Skills

- `/interlearn:index` — Rebuild the cross-repo index
- `/interlearn:search <query>` — Search solution docs by keyword, tag, or module
- `/interlearn:audit` — Check reflect coverage for closed beads

## Hook

SessionEnd hook auto-refreshes the index when working in the Interverse monorepo.

## Install

```bash
claude plugins install interlearn@interagency-marketplace
```
