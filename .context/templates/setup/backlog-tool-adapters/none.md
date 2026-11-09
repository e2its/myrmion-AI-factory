---
description: "Tool adapter for LOCAL FILE MODE. Materialised by SETUP --generate into docs/backlog/tool-adapter.md when the derived project_tracking.adapter is none (Q27 None, or a tracker with no adapter — EVOL-079). The SSOT is docs/backlog/state.md; no external tracker is involved."
tool: "None (local file mode)"
integration: "file"
cli_binary: null
---

# Tool Adapter: Local File Mode

> **Materialisation note.** This adapter is selected when the derived `project_tracking.adapter` is `none`: Q27 answered `None`, or named a tracker with no adapter (`gate.py discovery --resolve` warns). The BACKLOG subsystem runs entirely off local files — no CLI, no MCP, no network. `docs/backlog/state.md` is the single source of truth; `docs/backlog/issue-bodies/<id>.md` holds the canonical body content for each issue.

## 0. Prerequisites

None. This adapter uses only the file system. No binaries, no authentication.

---

## 1. Runtime Config

```json
{
  "tool": "None",
  "integration": "file",
  "cli_command": null,
  "project_ids": {
    "state_file": "docs/backlog/state.md",
    "bodies_dir": "docs/backlog/issue-bodies"
  },
  "board_field_mapping": {
    "columns": {{BOARD_COLUMNS}}
  }
}
```

Lifecycle columns: `config/quality.json → tracker.flow` (Q27.7) — backlog, ready, in progress, done; each one of `board_columns`.

---

## 2. Abstract Operations → File Operations

### 2.1 Bootstrap

#### `create_project`
Ensure `docs/backlog/` exists and copy the default state template:

```
WRITE docs/backlog/state.md from .context/templates/setup/backlog/state.md
MKDIR docs/backlog/issue-bodies/
```

#### `configure_board`
Update `state.md` frontmatter `board_columns` to `{{BOARD_COLUMNS}}`. No-op if already matching.

#### `create_label`
**No-op.** Labels in local mode are string tags stored per row in `state.md`. They are not pre-declared; the label column is free-form. The BACKLOG agent still follows the § 4.1 taxonomy for consistency.

#### `create_milestone`
**No-op.** Milestones are not materialised in local mode. The `Milestone` column in `state.md` remains a free-form string (e.g., `EPIC-1: Foundation`). Applied directly by `create_issue` when the caller supplies a milestone value.

---

### 2.2 Issue Lifecycle — `gate.py tracker` only

| Operation | Command |
| --- | --- |
| `create_issue`, `add_to_board`, `add_sub_issue` | `python3 scripts/gate.py tracker --ensure <rows.json> [--dry-run]` |
| sub-increment items | `python3 scripts/gate.py tracker --ensure --sub-increments <F>` |
| phase start (In Progress) | `python3 scripts/gate.py tracker --start --feature <F> --phase <P> [--item <IDENT>] [--aligns AC-…]` |
| `move_to_column`, `close_issue` | `python3 scripts/gate.py tracker --move <IDENT> --to backlog\|ready\|in-progress\|done` |

- Rows file: a JSON list of `{title, ident?, body?, labels?, parent?, milestone?, state?}`. `body` is a file path; `state` defaults to `backlog`.
- Create: the next `L-NNN` from `next_local_id`, the body copied to `issue-bodies/L-NNN.md` (a body already in `issue-bodies/` is pointed at), one 8-column row (`Local ID | Feature | Title | Status | Labels | Milestone | Parent | Body File`) in place of the placeholder row or after the last; `next_local_id`, `total_issues`, `last_updated` updated.
- Move: rewrites the row's `Status` to the state's column. Done = the flow's done column.
- An item under another parent is red — never re-parented. A parentless item is linked (`Parent` rewritten).
- Re-running creates nothing: a row found by its ident (the title head) is left as it is. Two rows on one ident: red.
- Never hand-edit `Status` — the gate re-reads the file after every write.

#### `add_label`
Rewrite the `Labels` column of the matching row in `state.md`: read the current comma-joined label list, append the new label if not already present, write back. Update `last_updated` timestamp in frontmatter. Idempotent.

---

### 2.3 Query / Verification

#### `query_board`
1. READ `docs/backlog/state.md`
2. Parse the `## Board` table into structured rows
3. Return `[{local_id, feature_id, title, status, labels, milestone, parent, body_path}, ...]` — one entry per 8-column row, with labels parsed from comma-joined string to array.

#### `get_item_id`
Search `state.md` for the row matching the given feature_id + phase; return its `local_id`. Returns null if not found.

#### `read_issue`
1. READ `state.md` row by `local_id`
2. READ `docs/backlog/issue-bodies/<local_id>.md` for the body
3. Return merged `{local_id, feature_id, title, body, labels, milestone, parent, status}`

#### `verify_issue`
Run `read_issue` and compare to expected values. Return `{ok, mismatches}`.

#### `verify_board_placement`
Return `{status: <current column from state.md>}`. A "board" in local mode IS the state file, so placement == status.

---

## 3. Placeholder Resolution

| Placeholder | Resolved by | When |
| --- | --- | --- |
| `{{BOARD_COLUMNS}}` | SETUP --generate from Q27.1 | Materialisation |

No post-init placeholders. Local mode has no runtime identifiers to capture.

---

## 4. Troubleshooting

| Symptom | Cause | Resolution |
| --- | --- | --- |
| `state.md: file not found` | `--init-board` not yet run | Run `BACKLOG --init-board` |
| Row ordering drift after manual edits | User hand-edited `state.md` | Run `BACKLOG --sync-execution` to rebuild cache from disk |
| `next_local_id` collision | Manual edit inserted a row with an existing ID | Renumber manually; `next_local_id` must be strictly greater than max existing ID |
| Orphaned body file | Row deleted without removing body | `BACKLOG --sync-execution` reports orphans; user decides to delete or re-link |

---

## 5. Adapter Capabilities Declaration

```yaml
required_ops:
  create_project:        native
  configure_board:       native
  create_label:          no-op     # labels are free-form strings in the Labels column — no label registry
  create_issue:          gate      # gate.py tracker --ensure
  add_to_board:          no-op     # a row in state.md is on the board
  move_to_column:        gate      # gate.py tracker --move / --start
  close_issue:           gate      # --move … --to done
  add_label:             native    # rewrites Labels column of the matching row in state.md (idempotent)
  query_board:           native
  get_item_id:           native
  read_issue:            native
  verify_issue:          composed
  verify_board_placement: native    # placement == status column

optional_ops:
  create_milestone:      no-op     # milestone is a free-form string in the Milestone column — no milestone registry
  add_sub_issue:         gate      # Parent column, through gate.py tracker --ensure
```

File mode supports sub-issue nesting natively via the `Parent` column of the 8-column board schema. Gate issues are materialised as rows whose `Parent` field points to their IMPLEMENT parent's local ID. The `--next-task` resolver reads the `Parent` column directly — no body cross-references required.
