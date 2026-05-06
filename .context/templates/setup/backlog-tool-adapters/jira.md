---
description: "Tool adapter STUB for Jira (Atlassian Cloud / Server). Materialised by SETUP --generate into docs/backlog/tool-adapter.md when project_tracking.tool matches /jira/i. Contributors: fill in the concrete commands for each abstract operation, then remove the STUB banner."
tool: "Jira"
integration: "cli"
cli_binary: "jira"
stub: true
---

# Tool Adapter: Jira (STUB)

> ⚠️ **STUB ADAPTER.** This file is a template skeleton. Each abstract operation below lists the expected behaviour and a recommended CLI invocation, but the exact commands must be validated against your Jira instance (Cloud vs. Server, API version, installed `jira` CLI variant — `ankitpokhrel/jira-cli` is the reference).
>
> Once validated, remove this banner and the `stub: true` frontmatter.

## 0. Prerequisites

### Recommended CLI

[`ankitpokhrel/jira-cli`](https://github.com/ankitpokhrel/jira-cli) — Go-based, supports Jira Cloud and Server.

```bash
# macOS
brew install ankitpokhrel/jira-cli/jira-cli

# Linux: see https://github.com/ankitpokhrel/jira-cli/releases
```

### Authenticate

```bash
jira init        # prompts for server URL, email, API token
```

API token is generated at <https://id.atlassian.com/manage-profile/security/api-tokens>. The token is stored by the CLI in `~/.config/.jira/.config.yml` — the framework never reads it.

### Verify

```bash
jira me
```

### Required Permissions

| Permission | Why |
| --- | --- |
| Browse Projects | `read_issue`, `query_board` |
| Create Issues | `create_issue` |
| Edit Issues | `move_to_column`, `close_issue`, `add_sub_issue` |
| Manage Sprints (if sprint-based) | `create_milestone` when strategy is sprint-based |

---

## 1. Runtime Config (populated by `--init-board`)

```json
{
  "tool": "Jira",
  "integration": "cli",
  "cli_command": "jira",
  "project_ids": {
    "project_key": "{{JIRA_PROJECT_KEY}}",
    "board_id": "{{JIRA_BOARD_ID}}"
  },
  "board_field_mapping": {
    "status_transitions": {
      "Todo": "{{TRANSITION_ID_TODO}}",
      "In Progress": "{{TRANSITION_ID_IN_PROGRESS}}",
      "Review": "{{TRANSITION_ID_REVIEW}}",
      "Done": "{{TRANSITION_ID_DONE}}"
    }
  }
}
```

Jira transitions have IDs that vary per workflow — capture via `jira issue transition list` on a sample issue during `--init-board`.

---

## 2. Abstract Operations → Jira CLI Commands

### 2.1 Bootstrap

#### `create_project` — **MANUAL**
Jira project creation typically requires admin rights and custom workflows. **Recommend:** instruct the user to create the Jira project manually via the web UI, then supply the project key during `--init-board`.

#### `configure_board` — **STUB**
Column mapping in Jira depends on the workflow. The BACKLOG agent MUST query the workflow transitions for the configured project and map `{{BOARD_COLUMNS}}` to the closest matching transitions.

```bash
# TODO: implement
jira issue transition list --project {{JIRA_PROJECT_KEY}}
```

#### `create_label` — **STUB**
Jira labels are free-form strings on issues — they do not need pre-declaration. This operation is effectively a no-op (labels are created implicitly when applied to an issue).

#### `create_milestone` — **STUB (depends on strategy)**
- `epic-based`: create an Epic issue type to represent the milestone
- `sprint-based`: use Sprints (`jira sprint create`)
- `phase-based`: use Fix Versions (`jira version create`)

---

### 2.2 Issue Lifecycle

#### `create_issue` — **STUB**
```bash
# TODO: validate
jira issue create \
  --project {{JIRA_PROJECT_KEY}} \
  --type "Task" \
  --summary "<title>" \
  --body "<body>" \
  --label "<label1>" --label "<label2>" \
  --parent "<epic_key_if_any>"
```

#### `add_to_board` — **NO-OP**
Jira issues are automatically on the board for their project. No explicit add step.

#### `move_to_column` — **STUB**
```bash
# TODO: validate
jira issue move <issue_key> "<target_status>"
```

Uses the Jira transition API. The `{{TRANSITION_ID_*}}` mapping captured at init time selects the right transition.

#### `close_issue` — **STUB**
Move to `Done` status and optionally resolve:
```bash
jira issue move <issue_key> "Done"
```

#### `add_label` — **STUB**
Jira labels are free-form strings. Add a label to an existing issue:
```bash
# TODO: validate — Jira CLI may require a fetch-modify-update cycle instead of a direct add flag
jira issue edit <issue_key> --label "<label_name>"
```
Used by the iteration-model cascade (e.g., `stale-after-cascade`). Must be idempotent — if the label already exists on the issue, calling this is a no-op.

#### `add_sub_issue` — **STUB**
Jira has **Sub-tasks** (native sub-issue equivalent). Create the child as a sub-task of the parent:
```bash
# TODO: validate
jira issue create \
  --project {{JIRA_PROJECT_KEY}} \
  --type "Sub-task" \
  --parent "<parent_issue_key>" \
  --summary "<title>"
```

Note: this means sub-tasks are created directly, not converted from standalone issues. The `create_issue` implementation should accept an optional `parent_key` parameter and dispatch to the sub-task path when provided.

---

### 2.3 Query / Verification

#### `query_board` — **STUB**
```bash
# TODO: validate
jira issue list \
  --project {{JIRA_PROJECT_KEY}} \
  --status "~Done" \
  --plain --no-headers
```

Returns structured issue list. Parse into `{key, title, status, labels, parent}` rows.

#### `get_item_id` — **STUB**
Jira issue keys (e.g., `MASS-42`) are the native ID — return the key directly.

#### `read_issue` — **STUB**
```bash
jira issue view <issue_key> --plain
```

#### `verify_issue` — **COMPOSED**
Run `read_issue` and compare against expected metadata.

#### `verify_board_placement` — **STUB**
```bash
jira issue view <issue_key> --plain | grep "^Status:"
```

---

## 3. Placeholder Resolution

| Placeholder | Resolved by | When |
| --- | --- | --- |
| `{{JIRA_PROJECT_KEY}}` | User prompt during `--init-board` | First init |
| `{{JIRA_BOARD_ID}}` | `jira board list --project {{JIRA_PROJECT_KEY}}` | First init |
| `{{TRANSITION_ID_*}}` | `jira issue transition list` on a sample issue | First init |

---

## 4. Troubleshooting

| Symptom | Cause | Resolution |
| --- | --- | --- |
| `jira: command not found` | CLI not installed | See § 0 |
| `401 Unauthorized` | Expired API token | `jira init` to re-enter token |
| `Cannot transition issue` | Target status not in workflow | List transitions with `jira issue transition list <key>` and update mapping |
| `No Sub-task type in project` | Project doesn't have sub-task issue type | Ask Jira admin to enable Sub-task; meanwhile declare `add_sub_issue: no-op` in § 5 |

---

## 5. Adapter Capabilities Declaration

```yaml
required_ops:
  create_project:        manual    # admin action, not CLI-automatable
  configure_board:       TODO
  create_label:          no-op     # labels created implicitly
  create_issue:          TODO
  add_to_board:          no-op     # implicit
  move_to_column:        TODO
  close_issue:           TODO
  add_label:             TODO      # jira issue edit --label — validate idempotency
  query_board:           TODO
  get_item_id:           native    # issue key
  read_issue:            TODO
  verify_issue:          composed
  verify_board_placement: TODO

optional_ops:
  create_milestone:      TODO      # strategy-dependent
  add_sub_issue:         TODO      # via Sub-task issue type
```

**Contributor checklist:**
- [ ] Replace every `TODO` with a validated command
- [ ] Capture the Jira Cloud vs. Server differences if any
- [ ] Remove the `stub: true` frontmatter flag
- [ ] Remove the STUB banner at the top of the file
- [ ] Update [`README.md`](./README.md) selection table if the tool name matching pattern needs refinement
