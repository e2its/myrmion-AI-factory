---
last_updated: null
total_issues: 0
next_local_id: 1
board_columns: [Todo, In Progress, Review, Done]
---

# Backlog State

> **SSOT Local Mode**: This file is the single source of truth for backlog tracking when no external project management tool is configured. Do NOT use alongside an external tool.

## Board

| Local ID | Feature | Title | Status | Labels | Milestone | Parent | Body File |
|----------|---------|-------|--------|--------|-----------|--------|-----------|
| — | — | — | — | — | — | — | — |

**Column semantics (file mode):**

- `Local ID` — sequential local identifier allocated by the BACKLOG agent (e.g. `L-001`). Matches `next_local_id` in frontmatter.
- `Feature` — Feature ID (e.g. `FEAT-001`) when the row belongs to a feature; blank for infra, cluster, gate issues.
- `Title` — issue title as materialised by `create_issue`.
- `Status` — current column name from `board_columns` (e.g. `Todo`, `In Progress`, `Done`).
- `Labels` — comma-joined label list. First-class storage for phase labels (`phase:codesign`, `phase:contract-freeze`, ...), slice labels (`slice:EPIC-1.2`), cluster labels (`cluster:CLUSTER-001`), and cascade-stale labels (`stale-after-cascade`, `stale-after-slice-peer-iterated`). The `add_label` adapter operation appends to this column idempotently.
- `Milestone` — free-form milestone string following the schema in `Factory-backlog-operations.instructions.md` § 4.2 (`EPIC-{N}: {Name}`, `Phase {K}: {Name}`, `Sprint {K}`, or blank).
- `Parent` — local ID of the parent issue when the row represents a sub-issue nested under another (e.g. a gate issue nested under its IMPLEMENT parent). Blank for standalone issues. See `Factory-backlog-operations.instructions.md` § 1.1 for the sub-issue nesting model.
- `Body File` — relative path to the body markdown under `docs/backlog/issue-bodies/`.

## Next Action

Run `BACKLOG --init-board` to initialize the local backlog.
