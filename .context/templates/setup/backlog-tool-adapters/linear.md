---
description: "Tool adapter STUB for Linear. Materialised by SETUP --generate into docs/backlog/tool-adapter.md when project_tracking.tool matches /linear/i. Contributors: fill in the concrete commands or MCP calls for each abstract operation, then remove the STUB banner."
tool: "Linear"
integration: "mcp"
cli_binary: null
stub: true
---

# Tool Adapter: Linear (STUB)

> ⚠️ **STUB ADAPTER.** This file is a template skeleton. Linear has no first-party CLI — the reference integration is via the **Linear MCP server**. Contributors should validate the MCP tool names and parameters against the current Linear MCP release and fill in the TODO markers.
>
> Once validated, remove this banner and the `stub: true` frontmatter.

## 0. Prerequisites

### Linear MCP Server

Linear integration uses the official MCP server. The server handles authentication via Linear OAuth — no raw API keys stored by the framework.

**Install:** follow <https://linear.app/docs/mcp>

**Configure** the MCP server in the agent's MCP config (Claude Code: `~/.claude.json` or per-project `.mcp.json`). The exact name the framework looks for is `linear` (adjust if your config uses a different server alias).

### Verify

The BACKLOG preflight check invokes the MCP server's `me` / `whoami` tool (or equivalent) and expects a successful authenticated response.

### Required Permissions

| Scope | Why |
| --- | --- |
| `read` | `query_board`, `read_issue` |
| `write` | `create_issue`, `move_to_column`, `close_issue` |
| `admin` (if required) | `create_project`, `configure_board` |

---

## 1. Runtime Config (populated by `--init-board`)

```json
{
  "tool": "Linear",
  "integration": "mcp",
  "cli_command": null,
  "mcp_server": "linear",
  "project_ids": {
    "workspace_id": "{{LINEAR_WORKSPACE_ID}}",
    "team_id": "{{LINEAR_TEAM_ID}}",
    "project_id": "{{LINEAR_PROJECT_ID}}"
  },
  "board_field_mapping": {
    "state_ids": {
      "Todo": "{{STATE_ID_TODO}}",
      "In Progress": "{{STATE_ID_IN_PROGRESS}}",
      "Review": "{{STATE_ID_REVIEW}}",
      "Done": "{{STATE_ID_DONE}}"
    }
  }
}
```

Linear uses **Workflow States** (not columns) — each has a UUID captured at init via the MCP `listWorkflowStates` (or equivalent) tool.

---

## 2. Abstract Operations → Linear MCP Tool Calls

> **Note.** Tool names below follow the naming pattern of common Linear MCP servers (`linear__<action>`). Validate against your specific MCP release — names may differ.

### 2.1 Bootstrap

#### `create_project` — **STUB**
Invoke `linear__createProject` with team ID and project name. Capture the returned `project_id`.

#### `configure_board` — **STUB**
Linear's workflow states are team-scoped and typically pre-configured by the admin. At init, list the team's workflow states:
```
mcp: linear__listWorkflowStates(teamId = {{LINEAR_TEAM_ID}})
```
Map `{{BOARD_COLUMNS}}` to the closest matching state names and persist the state IDs into `board_field_mapping.state_ids`.

#### `create_label` — **STUB**
```
mcp: linear__createIssueLabel(teamId, name, color)
```
Labels in Linear are team-scoped. Create the full phase/status taxonomy at init time.

#### `create_milestone` — **STUB (depends on strategy)**
- `epic-based`: Linear has native **Projects** — use one Linear Project per epic
- `sprint-based`: Linear has native **Cycles** — use `linear__createCycle`
- `phase-based`: custom Label or parent Initiative

---

### 2.2 Issue Lifecycle

#### `create_issue` — **STUB**
```
mcp: linear__createIssue({
  teamId: {{LINEAR_TEAM_ID}},
  projectId: {{LINEAR_PROJECT_ID}},
  title: "<title>",
  description: "<body>",
  labelIds: ["<label_id1>", "<label_id2>"],
  stateId: "{{STATE_ID_TODO}}",
  parentId: "<parent_issue_id_if_any>"
})
```

#### `add_to_board` — **NO-OP**
Linear issues created within a Team/Project appear on the corresponding board automatically.

#### `move_to_column` — **STUB**
```
mcp: linear__updateIssue({id: <issue_id>, stateId: <target_state_id>})
```

#### `close_issue` — **STUB**
Set state to `{{STATE_ID_DONE}}`. Linear auto-handles "completed" semantics.

#### `add_label` — **STUB**
Linear labels are referenced by ID (UUID). Resolve the label name to its ID via `linear__listIssueLabels`, fetch the issue's current `labelIds`, append the new ID if missing, and update:
```
mcp: linear__updateIssue({id: <issue_id>, labelIds: [<existing_ids>..., <new_label_id>]})
```
Used by the iteration-model cascade. Must be idempotent — skip the update if the label is already on the issue.

#### `add_sub_issue` — **STUB (native)**
Linear supports sub-issues natively via `parentId`. Two strategies:
- **At creation time:** pass `parentId` in `create_issue` directly
- **Post-hoc conversion:** `linear__updateIssue({id, parentId})` to re-parent an existing issue

Since `--plan-feature` may create the parent (IMPLEMENT) before the children (gates), use the post-hoc pattern: create all 8 phase issues standalone, then run `updateIssue` to set `parentId` on the three gate issues.

---

### 2.3 Query / Verification

#### `query_board` — **STUB**
```
mcp: linear__listIssues(teamId, projectId, first=500)
```

Returns a paginated list — the adapter MUST handle pagination until all items are retrieved.

#### `get_item_id` — **STUB**
Linear issue IDs are UUIDs. The agent typically references issues by **identifier** (e.g., `MASS-42`) which is a human-friendly slug. Use `linear__getIssue(identifier)` to resolve.

#### `read_issue` — **STUB**
```
mcp: linear__getIssue(id or identifier)
```

#### `verify_issue` — **COMPOSED**
`read_issue` + compare.

#### `verify_board_placement` — **STUB**
Read the issue's `state.name` and compare against the expected column name.

---

## 3. Placeholder Resolution

| Placeholder | Resolved by | When |
| --- | --- | --- |
| `{{LINEAR_WORKSPACE_ID}}` | MCP `me` call during `--init-board` | First init |
| `{{LINEAR_TEAM_ID}}` | User prompt (team to use) | First init |
| `{{LINEAR_PROJECT_ID}}` | `linear__createProject` or existing project selection | First init |
| `{{STATE_ID_*}}` | `linear__listWorkflowStates` for the team | First init |

---

## 4. Troubleshooting

| Symptom | Cause | Resolution |
| --- | --- | --- |
| `MCP server 'linear' not found` | MCP server not installed/configured | See § 0 Prerequisites |
| `Not authenticated` | Linear OAuth expired | Re-authorize the MCP server |
| `Workflow state not found` | Team workflow states changed | Re-run `configure_board` to refresh `state_ids` mapping |
| `Rate limit exceeded` | Too many MCP calls | Batch queries; rely on `project-board-cache.md` |

---

## 5. Adapter Capabilities Declaration

```yaml
required_ops:
  create_project:        TODO
  configure_board:       TODO
  create_label:          TODO
  create_issue:          TODO
  add_to_board:          no-op     # implicit
  move_to_column:        TODO
  close_issue:           TODO
  add_label:             TODO      # fetch labelIds + append + updateIssue (idempotent)
  query_board:           TODO
  get_item_id:           TODO
  read_issue:            TODO
  verify_issue:          composed
  verify_board_placement: TODO

optional_ops:
  create_milestone:      TODO      # strategy-dependent (Project / Cycle / Label)
  add_sub_issue:         TODO      # native via parentId
```

**Contributor checklist:**
- [ ] Replace every `TODO` with a validated MCP tool name + parameter schema
- [ ] Verify against the current Linear MCP release (tool names may differ)
- [ ] Remove the `stub: true` frontmatter flag
- [ ] Remove the STUB banner at the top of the file
- [ ] Update [`README.md`](./README.md) selection table if the tool name matching pattern needs refinement
