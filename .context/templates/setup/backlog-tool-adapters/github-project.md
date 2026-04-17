---
applyTo: "backlog"
description: "Tool adapter for GitHub Projects (v2). Materialised by SETUP --generate into docs/backlog/tool-adapter.md when project_tracking.tool matches /github/i."
tool: "GitHub Projects"
integration: "cli"
cli_binary: "gh"
---

# Tool Adapter: GitHub Projects

> **Materialisation note.** This file was rendered from `.context/templates/setup/backlog-tool-adapters/github-project.md` by `SETUP --generate` into `docs/backlog/tool-adapter.md`. Placeholders of the form `{{…}}` that remain after materialisation are resolved by the first `BACKLOG --init-board` run and persisted into `docs/backlog/project-config.json`.

## 0. Prerequisites

### Install

```bash
# macOS
brew install gh

# Debian/Ubuntu
sudo apt install gh

# Others: see https://cli.github.com/
```

### Authenticate

```bash
gh auth login --web --scopes "repo,project,read:org"
```

### Verify

```bash
gh auth status
```

Expected output contains `Logged in to github.com as {{ORG_OR_USER}}` and `Token scopes: 'project', 'read:org', 'repo'`.

### Required Permissions

| Scope | Why |
| --- | --- |
| `repo` | Create and read issues |
| `project` | Create and modify Project v2 boards |
| `read:org` | Resolve org-level project ownership when `{{ORG_OR_USER}}` is an organization |

---

## 1. Runtime Config (populated by `--init-board`)

```json
{
  "tool": "GitHub Projects",
  "integration": "cli",
  "cli_command": "gh",
  "project_ids": {
    "owner": "{{ORG_OR_USER}}",
    "repo": "{{REPO_SLUG}}",
    "project_number": "{{PROJECT_NUMBER}}",
    "project_node_id": "{{PROJECT_NODE_ID}}"
  },
  "board_field_mapping": {
    "status_field_id": "{{STATUS_FIELD_ID}}",
    "column_option_ids": {
      "Todo": "{{TODO_OPT_ID}}",
      "In Progress": "{{IN_PROGRESS_OPT_ID}}",
      "Review": "{{REVIEW_OPT_ID}}",
      "Done": "{{DONE_OPT_ID}}"
    }
  }
}
```

`{{PROJECT_NUMBER}}`, node IDs, and option IDs are captured during `--init-board` (§ 2, `create_project` + `configure_board`).

---

## 2. Abstract Operations → gh CLI Commands

> **Invariant.** Every abstract operation declared in `Factory-backlog-operations.instructions.md` § 6.0 is listed below. The BACKLOG agent NEVER issues `gh` commands directly — it always goes through this table.

### 2.1 Bootstrap

#### `create_project`
```bash
gh project create \
  --owner {{ORG_OR_USER}} \
  --title "{{PROJECT_NAME}}"
```

**Capture from output:**
- `project_number` → persist to `project_ids.project_number`
- Run `gh project view {{PROJECT_NUMBER}} --owner {{ORG_OR_USER}} --format json` and capture `.id` → `project_ids.project_node_id`

#### `configure_board`
GitHub Projects v2 creates a default `Status` field with `Todo | In Progress | Done`. To match Q27.1 `{{BOARD_COLUMNS}}`:

```bash
# List existing status field options and capture IDs
gh project field-list {{PROJECT_NUMBER}} --owner {{ORG_OR_USER}} --format json \
  | jq '.fields[] | select(.name=="Status")'
```

For each column in `{{BOARD_COLUMNS}}` not already present, add via the Projects v2 GraphQL API:

```bash
gh api graphql -f query='
  mutation($projectId:ID!, $fieldId:ID!, $name:String!) {
    updateProjectV2Field(input:{projectId:$projectId, fieldId:$fieldId, name:$name}) {
      projectV2Field { ... on ProjectV2SingleSelectField { id name options { id name } } }
    }
  }' -f projectId="{{PROJECT_NODE_ID}}" -f fieldId="{{STATUS_FIELD_ID}}" -f name="<column>"
```

Persist the resulting `option.id` values into `board_field_mapping.column_option_ids`.

#### `create_label`
```bash
gh label create "<name>" --repo {{REPO_SLUG}} --color "<hex>" --description "<desc>" --force
```

Required labels (materialised at init from Factory-backlog-operations.instructions.md § 4.1):

```bash
# Phase labels (from feature_phases expansion)
for phase in codesign blueprint contract-freeze devops implement preventive-sweep qa smoke-e2e integration-test retrospective; do
  gh label create "phase:${phase}" --repo {{REPO_SLUG}} --color "0366d6" --force
done

# Status labels
gh label create "blocked"     --repo {{REPO_SLUG}} --color "b60205" --force
gh label create "enhancement" --repo {{REPO_SLUG}} --color "a2eeef" --force
gh label create "bug"         --repo {{REPO_SLUG}} --color "d73a4a" --force
gh label create "needs-rework-after-codesign" --repo {{REPO_SLUG}} --color "fbca04" --force

# Kind labels (EVOL-015 — always created)
gh label create "kind:follow-up" --repo {{REPO_SLUG}} --color "c5def5" --force \
  --description "Deferred work spun out of a parent feature or retrospective (vs. accidental incomplete)"

# Appetite labels (EVOL-015 — created ONLY when {{APPETITE_SIZING_ENABLED}} == true)
if [ "{{APPETITE_SIZING_ENABLED}}" = "true" ]; then
  gh label create "appetite:small"  --repo {{REPO_SLUG}} --color "bfdadc" --force \
    --description "Budget cap ≤ 4h, one session"
  gh label create "appetite:medium" --repo {{REPO_SLUG}} --color "7057ff" --force \
    --description "Budget cap 2–4 days supervised"
  gh label create "appetite:big"    --repo {{REPO_SLUG}} --color "5319e7" --force \
    --description "Budget cap 5+ days or complex feature — re-shape if overrun"
fi
```

Slice labels (`slice:EPIC-{N}.{M}`) and cluster labels (`cluster:{id}`) are created on-demand by `--plan-execution`, not at init time.

`blocked-by:#{N}` labels (EVOL-015) are created on-demand the first time they are applied via `add_label` — `gh label create` is idempotent with `--force`, so the adapter calls it right before `gh issue edit --add-label` when applying a new `blocked-by:#{N}` value for the first time. The label persists for reuse on later issues.

#### `create_milestone` (optional — used when `milestone_strategy != "none"`)
```bash
gh api repos/{{REPO_SLUG}}/milestones \
  -f title="<milestone_name>" \
  -f description="<optional description>" \
  -f state="open"
```

Milestone naming follows `milestone_strategy` from Q27.3 — see `Factory-backlog-operations.instructions.md` § 4.2.

---

### 2.2 Issue Lifecycle

#### `create_issue`
```bash
gh issue create \
  --repo {{REPO_SLUG}} \
  --title "<title>" \
  --body-file "<tempfile>" \
  --label "<label1>,<label2>,..." \
  --milestone "<milestone_title>"
```

**Capture from output:** issue URL → parse trailing `/<number>` for `issue_number`. Then run `gh issue view <number> --repo {{REPO_SLUG}} --json id` to capture `node_id` for sub-issue nesting.

#### `add_to_board`
```bash
gh project item-add {{PROJECT_NUMBER}} \
  --owner {{ORG_OR_USER}} \
  --url "https://github.com/{{REPO_SLUG}}/issues/<issue_number>"
```

**Capture from output:** the item ID → needed for `move_to_column`.

#### `move_to_column`
```bash
gh project item-edit \
  --id "<item_id>" \
  --field-id "{{STATUS_FIELD_ID}}" \
  --project-id "{{PROJECT_NODE_ID}}" \
  --single-select-option-id "<column_option_id from board_field_mapping>"
```

#### `close_issue`
```bash
gh issue close <issue_number> --repo {{REPO_SLUG}} --reason "<completed|not_planned>"
```

#### `add_label`
```bash
gh issue edit <issue_number> --repo {{REPO_SLUG}} --add-label "<label_name>"
```

Used by the iteration-model cascade to mark gate issues as stale. The label must already exist (created at `--init-board` via `create_label` or on-demand via `gh label create`). Safe to call on an issue that already has the label — GitHub ignores duplicates.

#### `add_sub_issue` (optional — REQUIRED for `full-sdlc` with gate sub-issue nesting)
GitHub Projects supports sub-issues via the `addSubIssue` GraphQL mutation. Both parent and child must be referenced by node ID (captured post-`create_issue`).

```bash
gh api graphql -f query='
  mutation($parentId:ID!, $childId:ID!) {
    addSubIssue(input:{issueId:$parentId, subIssueId:$childId}) {
      issue { number }
      subIssue { number }
    }
  }' -f parentId="<parent_node_id>" -f childId="<child_node_id>"
```

Used by `--plan-feature` under `full-sdlc` to nest CONTRACT-FREEZE, PREVENTIVE-SWEEP, and SMOKE-E2E under IMPLEMENT so GitHub's Sub-issues progress field tracks feature completion holistically.

---

### 2.3 Query / Verification

#### `query_board`
```bash
gh project item-list {{PROJECT_NUMBER}} \
  --owner {{ORG_OR_USER}} \
  --format json \
  --limit 500
```

**Parses to:** list of `{content: {number, title, state, labels, milestone}, status, parent_issue}`. This is the authoritative board snapshot consumed by `--sync-execution` and `--next-task`.

#### `get_item_id`
```bash
gh project item-list {{PROJECT_NUMBER}} --owner {{ORG_OR_USER}} --format json \
  | jq -r --argjson num <issue_number> '.items[] | select(.content.number==$num) | .id'
```

#### `read_issue`
```bash
gh issue view <issue_number> --repo {{REPO_SLUG}} \
  --json number,title,body,labels,milestone,state,url
```

#### `verify_issue`
Run `read_issue` and compare returned `title`, `labels`, `milestone.title`, `state` against the expected values supplied by the caller. Return `{ok: true}` or `{ok: false, mismatches: [...]}`.

#### `verify_board_placement`
```bash
gh project item-list {{PROJECT_NUMBER}} --owner {{ORG_OR_USER}} --format json \
  | jq --argjson num <issue_number> \
       '.items[] | select(.content.number==$num) | {status: .status, column: .fieldValues.Status}'
```

Returns `{status, column}` for the given issue, or `null` if not on the board.

---

## 3. Placeholder Resolution

| Placeholder | Resolved by | When |
| --- | --- | --- |
| `{{PROJECT_NAME}}` | SETUP --generate from `docs/setup.md` Q1 | Materialisation |
| `{{REPO_SLUG}}` | SETUP --generate from git remote `origin` | Materialisation |
| `{{ORG_OR_USER}}` | SETUP --generate from `{{REPO_SLUG}}` split | Materialisation |
| `{{BOARD_COLUMNS}}` | SETUP --generate from Q27.1 | Materialisation |
| `{{PROJECT_NUMBER}}` | `--init-board` via `create_project` | First init |
| `{{PROJECT_NODE_ID}}` | `--init-board` via `gh project view --format json` | First init |
| `{{STATUS_FIELD_ID}}` | `--init-board` via `gh project field-list` | First init |
| `{{TODO_OPT_ID}}`, `{{IN_PROGRESS_OPT_ID}}`, … | `--init-board` via `configure_board` | First init |

Post-init values are written to `docs/backlog/project-config.json` and re-read on subsequent BACKLOG commands.

---

## 4. Troubleshooting

| Symptom | Cause | Resolution |
| --- | --- | --- |
| `gh: command not found` | CLI not installed | See § 0 Install |
| `error: not logged in` / `HTTP 401` | Not authenticated | `gh auth login --web --scopes "repo,project,read:org"` |
| `HTTP 403: Resource not accessible by integration` | Missing `project` scope | `gh auth refresh --scopes project,read:org` |
| `error: no projects found` | Wrong `{{ORG_OR_USER}}` in project-config.json | Verify with `gh project list --owner {{ORG_OR_USER}}`; re-run `--init-board` if project was deleted |
| `addSubIssue` returns `Node not found` | Child issue was created but `read_issue` not called to capture `node_id` | Always run `gh issue view --json id` after `create_issue` to capture the node ID before calling `add_sub_issue` |
| `item-edit` returns `Cannot update field`, `invalid option ID` | `column_option_ids` in project-config.json are stale (project was recreated) | Re-run `configure_board` to refresh the mapping |
| `HTTP 429: rate limit exceeded` | Too many API calls | Wait for `X-RateLimit-Reset` header; batch `query_board` calls through the memory cache |

---

## 5. Adapter Capabilities Declaration

```yaml
required_ops:
  create_project:        native
  configure_board:       native
  create_label:          native
  create_issue:          native
  add_to_board:          native
  move_to_column:        native
  close_issue:           native
  add_label:             native     # gh issue edit --add-label
  query_board:           native
  get_item_id:           native
  read_issue:            native
  verify_issue:          composed   # read_issue + comparison
  verify_board_placement: native

optional_ops:
  create_milestone:      native     # via repos/{repo}/milestones
  add_sub_issue:         native     # via addSubIssue GraphQL mutation
```

When `add_sub_issue` is `native`, the BACKLOG agent is free to use sub-issue nesting for gate phases. If the adapter were to downgrade it to `no-op`, gate issues would be materialised as standalone siblings instead.
