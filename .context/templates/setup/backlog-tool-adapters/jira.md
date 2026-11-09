---
description: "Tool adapter for Jira (Cloud or Data Center). Materialised by SETUP --generate into docs/backlog/tool-adapter.md when the derived project_tracking.adapter is jira (EVOL-079)."
tool: "Jira"
integration: "cli | mcp"
cli_binary: "jira"
---

# Tool Adapter: Jira

Two paths, never mixed:

- **Lifecycle** (create, place, move, close, nest) — only `python3 scripts/gate.py tracker …`, over the Jira REST API. Never a hand-run transition.
- **Reads** by the agent — the transport in `docs/setup.md → project_tracking.transport` (Q27.8): `cli` (jira-cli) or `mcp` (Atlassian's remote server).

## 0. Prerequisites

### Site

| Site | API | Auth the gate sends |
| --- | --- | --- |
| Cloud (host under `atlassian.net`) | REST v3 | Basic: account email + API token |
| Data Center (any other host) | REST v2 | Bearer: personal access token |

### Token

`docs/setup.md → project_tracking.token` (Q27.9) names the vault entry — never the value. The vault exports it before a BACKLOG command:

- `JIRA_API_TOKEN` — the API token (Cloud) or personal access token (Data Center).
- `JIRA_USER_EMAIL` — Cloud only: the token's account email.

Use a bot account with rights on this one project. Nothing writes the token to a file.

### Transport `cli`

[jira-cli](https://github.com/ankitpokhrel/jira-cli) 1.7.0. It reads the same `JIRA_API_TOKEN`.

```bash
jira init                       # server URL, login, project; Data Center: JIRA_AUTH_TYPE=bearer
jira me                         # verify
```

### Transport `mcp`

Atlassian's remote MCP server, `https://mcp.atlassian.com/v2/mcp` — the `atlassian` row in the project's MCP servers. OAuth runs in the harness; no credential sits in the project. Cloud only: a Data Center site uses `cli`. Every call takes the site's `cloudId` (`getAccessibleAtlassianResources`).

### Required permissions

| Permission | Why |
| --- | --- |
| Browse Projects | reads, the gate's board read |
| Create Issues | `gate.py tracker --ensure` |
| Edit Issues | labels, `add_label` |
| Transition Issues | `gate.py tracker --start` / `--move` |
| Administer Projects (once) | `create_project`, `configure_board`, versions |

---

## 1. Runtime Config (written by `--init-board`)

```json
{
  "tool": "Jira",
  "project_ids": {
    "site": "https://<your-site>",
    "project_key": "{{JIRA_PROJECT_KEY}}",
    "board_id": "{{JIRA_BOARD_ID}}"
  }
}
```

No transition id is stored. The gate reads the board configuration: a column is the set of statuses mapped to it. A move takes the transition whose target status is in the flow column (`config/quality.json → tracker.flow`, Q27.7).

---

## 2. Abstract Operations

### 2.1 Bootstrap

#### `create_project` — manual
A Jira admin creates the project. `--init-board` records `site`, `project_key` and `board_id` (`jira board list` / `listJiraBoards`).

#### `configure_board` — manual
The board's columns are `{{BOARD_COLUMNS}}` (Q27.1). Every column of `tracker.flow` exists on the board, maps at least one status, and the workflow reaches it by a transition. Check: `python3 scripts/gate.py tracker --ensure <rows.json> --dry-run` names a missing column.

#### `create_label` — no-op
Jira labels are free strings; applying one creates it.

#### `create_milestone` — manual
A milestone is a version (Project settings → Releases), named per `milestone_strategy` (Q27.3). The gate sets it as the item's `fixVersions`, by id from the version's name. A missing version is red, never created by the gate.

### 2.2 Lifecycle — `gate.py tracker` only

| Operation | Command |
| --- | --- |
| `create_issue`, `add_to_board`, `add_sub_issue` | `python3 scripts/gate.py tracker --ensure <rows.json> [--dry-run]` |
| sub-increment items | `python3 scripts/gate.py tracker --ensure --sub-increments <F>` |
| phase start (In Progress) | `python3 scripts/gate.py tracker --start --feature <F> --phase <P> [--item <IDENT>] [--aligns AC-…]` |
| `move_to_column`, `close_issue` | `python3 scripts/gate.py tracker --move <IDENT> --to backlog\|ready\|in-progress\|done` |

- Rows file: a JSON list of `{title, ident?, body?, labels?, parent?, milestone?, state?}`. `body` is a file path; `state` defaults to `backlog`.
- An item with a `parent` is created as the project's sub-task type under it; any other as `Task` (else the first standard type).
- A Jira item cannot be linked to a parent after creation. An item under another parent is red — never re-parented.
- Re-running creates nothing: an item found by its ident (the title head) is left as it is. Two items on one ident: red.
- Done = the item sits in the flow's done column.

#### `add_label`

| cli | mcp |
| --- | --- |
| `jira issue edit <KEY> -l <label> --no-input` (appends) | `editJiraIssue` — add the label to `labels` |

Idempotent: a label already on the issue changes nothing.

### 2.3 Reads

| Operation | cli | mcp |
| --- | --- | --- |
| `query_board` | `jira issue list -q 'project = {{JIRA_PROJECT_KEY}}' --plain` | `searchJiraIssuesUsingJql` (`project = {{JIRA_PROJECT_KEY}}`) |
| `get_item_id` | the issue key | the issue key |
| `read_issue` | `jira issue view <KEY> --plain` | `getJiraIssue` |
| `verify_issue` | `read_issue` + compare | `read_issue` + compare |
| `verify_board_placement` | `read_issue` status vs the column's statuses | `getJiraIssue` + `getJiraBoardConfig` |

The gate re-reads every item it writes; its exit code is the placement proof.

---

## 3. Placeholder Resolution

| Placeholder | Resolved by | When |
| --- | --- | --- |
| `{{BOARD_COLUMNS}}` | SETUP --generate from Q27.1 | Materialisation |
| `{{JIRA_PROJECT_KEY}}` | `--init-board` | First init |
| `{{JIRA_BOARD_ID}}` | `--init-board` (`jira board list` / `listJiraBoards`) | First init |

---

## 4. Troubleshooting

| Symptom | Cause | Resolution |
| --- | --- | --- |
| `JIRA_API_TOKEN is not set` / `JIRA_USER_EMAIL is not set` | the vault did not export it | export from the entry `project_tracking.token` names |
| `Jira refused … (401/403)` | token expired, wrong account, or missing permission | new token in the vault; check § 0 permissions |
| `no transition into the `X` column` | the workflow cannot reach that column from the item's status | add the transition in the workflow, or fix `tracker.flow` |
| `the flow names column `X` and the board has none` | board columns ≠ `tracker.flow` | rename the board column or fix `tracker.flow` |
| `has no version `X`` | milestone not created | `create_milestone`, then re-run |
| re-run right after another tool created an item does not see it | Cloud search is eventually consistent; the gate reconciles only its own creations (`reconcileIssues`, then GET by key) | re-run in a few minutes; a doubled item is red, never silent |
| `has no sub-task issue type` | project without sub-tasks | an admin enables a sub-task type |
| `mcp` transport on Data Center | the remote server serves Cloud only | set `project_tracking.transport: cli` |

Data Center differs only in API v2, Bearer auth, `search` with `startAt` paging and a plain-text description.

---

## 5. Adapter Capabilities Declaration

```yaml
required_ops:
  create_project:        manual     # Jira admin
  configure_board:       manual     # board columns = tracker.flow, each reachable by a transition
  create_label:          no-op      # labels created on use
  create_issue:          gate       # gate.py tracker --ensure
  add_to_board:          gate       # implicit: a project issue is on its board
  move_to_column:        gate       # gate.py tracker --move / --start
  close_issue:           gate       # --move … --to done
  add_label:             native     # jira issue edit -l / editJiraIssue
  query_board:           native
  get_item_id:           native     # issue key
  read_issue:            native
  verify_issue:          composed
  verify_board_placement: native

optional_ops:
  create_milestone:      manual     # a version; the gate sets fixVersions by id
  add_sub_issue:         gate       # created as a sub-task under its parent; never re-parented
```
