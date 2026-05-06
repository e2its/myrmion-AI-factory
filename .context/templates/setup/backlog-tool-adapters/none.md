---
description: "Tool adapter for LOCAL FILE MODE. Materialised by SETUP --generate into docs/backlog/tool-adapter.md when project_tracking.tool == \"None\". The SSOT is docs/backlog/state.md; no external tracker is involved."
tool: "None (local file mode)"
integration: "file"
cli_binary: null
---

# Tool Adapter: Local File Mode

> **Materialisation note.** This adapter is selected when Q27 answered `None`. The BACKLOG subsystem runs entirely off local files — no CLI, no MCP, no network. `docs/backlog/state.md` is the single source of truth; `docs/backlog/issue-bodies/<id>.md` holds the canonical body content for each issue.

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

### 2.2 Issue Lifecycle

#### `create_issue`
1. Allocate next local ID from `state.md` frontmatter `next_local_id` (e.g., `L-001`)
2. Write body to `docs/backlog/issue-bodies/<local_id>.md`
3. Append a new row to the `## Board` table in `state.md` with all 8 columns:
   `Local ID | Feature | Title | Status | Labels | Milestone | Parent | Body File`
   — `Labels` = comma-joined (may be empty if no labels at creation);
   — `Milestone` = free-form string or blank;
   — `Parent` = parent local ID when `parent_ref` is supplied to `create_issue` (used by `add_sub_issue` for gate nesting), blank otherwise;
   — `Body File` = relative path `issue-bodies/<local_id>.md`.
4. Increment `next_local_id` in frontmatter
5. Update `last_updated` timestamp in frontmatter

Return: `{local_id, body_path}`.

#### `add_to_board`
**No-op.** Issues created in local mode are already on the local board by virtue of being in `state.md`.

#### `move_to_column`
Rewrite the `Status` column of the matching row in `state.md`. Preserve all other columns. Update `last_updated`.

#### `close_issue`
Move to column `Done` (or the last column in `{{BOARD_COLUMNS}}`), then append a `<!-- closed: <ISO date> -->` inline comment to the row.

#### `add_label`
Rewrite the `Labels` column of the matching row in `state.md`: read the current comma-joined label list, append the new label if not already present, write back. Update `last_updated` timestamp in frontmatter. Idempotent.

#### `add_sub_issue`
**Native.** Rewrite the `Parent` column of the child row in `state.md` with the parent's local ID. Idempotent — if the parent is already set to the same value, no-op. Used when a preset declares sub-issue nesting (e.g., the 3 gate phases nested under IMPLEMENT). Update `last_updated` timestamp in frontmatter.

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
  create_issue:          native
  add_to_board:          no-op     # create_issue already adds to state.md
  move_to_column:        native
  close_issue:           native
  add_label:             native    # rewrites Labels column of the matching row in state.md (idempotent)
  query_board:           native
  get_item_id:           native
  read_issue:            native
  verify_issue:          composed
  verify_board_placement: native    # placement == status column

optional_ops:
  create_milestone:      no-op     # milestone is a free-form string in the Milestone column — no milestone registry
  add_sub_issue:         native    # rewrites Parent column of the child row in state.md (idempotent)
```

File mode supports sub-issue nesting natively via the `Parent` column of the 8-column board schema. Gate issues are materialised as rows whose `Parent` field points to their IMPLEMENT parent's local ID. The `--next-task` resolver reads the `Parent` column directly — no body cross-references required.
