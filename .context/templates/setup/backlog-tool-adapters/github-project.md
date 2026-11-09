---
description: "Tool adapter for GitHub Projects (v2). Materialised by SETUP --generate into docs/backlog/tool-adapter.md when the derived project_tracking.adapter is github (EVOL-079)."
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

Requires gh **2.45.0 or later** (`gh project link`); check with `gh --version`. A distribution package can be older — install from https://cli.github.com/ instead.

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
  }
}
```

`{{PROJECT_NUMBER}}` and `{{PROJECT_NODE_ID}}` are captured during `--init-board` (§ 2, `create_project`). No field or option id is stored: the gate resolves the `Status` field and its options by name on every run.

---

## 2. Abstract Operations → gh CLI Commands

> **Invariant.** Every abstract operation declared in `Factory-backlog-operations.instructions.md` § 6.0 is listed below. The BACKLOG agent NEVER issues `gh` commands directly — it always goes through this table. Lifecycle operations (§ 2.2) run only through `python3 scripts/gate.py tracker`.

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

**Then link the board to the repository.** A Projects v2 board belongs to the owner, not to the repository, and adding issues as items does not link it — unlinked, it is missing from the repository's Projects tab:
```bash
gh project link {{PROJECT_NUMBER}} --owner {{ORG_OR_USER}} --repo {{REPO_SLUG}}
```
Idempotent (re-linking is harmless) and visibility-neutral (a private board stays private). A board created before this step existed: run the same command once.

**Verify** — must print `{{REPO_SLUG}}`. Ask the project, not the repository: a public repository may not list a private board.
```bash
gh api graphql -f query='query($id:ID!){ node(id:$id){ ... on ProjectV2 { repositories(first:50){ nodes { nameWithOwner } } } } }' -f id={{PROJECT_NODE_ID}} --jq '.data.node.repositories.nodes[].nameWithOwner'
```
**If the link or its verification fails, the board still exists.** Do not stop and never re-run `--init-board` — it would create a second board. Finish `configure_board`, persist the config, then report the board as created but NOT linked, with the link command to run on its own (§ 4).

#### `configure_board`
A new project's `Status` field carries GitHub's own default options. Make its options exactly `{{BOARD_COLUMNS}}` (Q27.1), in order; every column of `config/quality.json → tracker.flow` (Q27.7) must be one of them.

```bash
# the Status field id and its current options
gh project field-list {{PROJECT_NUMBER}} --owner {{ORG_OR_USER}} --format json \
  | jq '.fields[] | select(.name=="Status")'
```

`singleSelectOptions` replaces the whole list: an option kept passes its `id` (its items keep their value); a new column passes none; an option left out is deleted.

```bash
gh api graphql -f query='
  mutation {
    updateProjectV2Field(input:{fieldId:"<status_field_id>", singleSelectOptions:[
      {id:"<kept option id>", name:"<column>", color:GRAY, description:""},
      {name:"<new column>", color:BLUE, description:""}
    ]}) { projectV2Field { ... on ProjectV2SingleSelectField { options { id name } } } }
  }'
```

One entry per column of `{{BOARD_COLUMNS}}`, in order. `color` is one of `GRAY BLUE GREEN YELLOW ORANGE RED PINK PURPLE`. Nothing is persisted: the gate reads options by name.

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

# Kind labels (always created)
gh label create "kind:follow-up" --repo {{REPO_SLUG}} --color "c5def5" --force \
  --description "Deferred work spun out of a parent feature or retrospective (vs. accidental incomplete)"

# Appetite labels (created ONLY when {{APPETITE_SIZING_ENABLED}} == true)
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

`blocked-by:#{N}` labels are not created at `--init-board` time — the value `#{N}` is per-issue and not known until a cross-issue dependency is declared. Before applying one with `add_label` (which maps to `gh issue edit --add-label`), the label MUST already exist in the repo; GitHub rejects `--add-label` for unknown labels. Create the label explicitly:

```bash
gh label create "blocked-by:#<N>" --repo {{REPO_SLUG}} --color "cfd3d7" --force
```

`gh label create --force` is idempotent, so it is safe to call every time before the first `add_label` invocation with that value. Once created, the label persists for reuse on later issues. Automation layers that apply `blocked-by:#{N}` labels at scale should wrap the two commands into a single helper that always runs `gh label create … --force` first.

#### `create_milestone` (optional — used when `milestone_strategy != "none"`)
```bash
gh api repos/{{REPO_SLUG}}/milestones \
  -f title="<milestone_name>" \
  -f description="<optional description>" \
  -f state="open"
```

Milestone naming follows `milestone_strategy` from Q27.3 — see `Factory-backlog-operations.instructions.md` § 4.2.

---

### 2.2 Issue Lifecycle — `gate.py tracker` only

| Operation | Command |
| --- | --- |
| `create_issue`, `add_to_board`, `add_sub_issue` | `python3 scripts/gate.py tracker --ensure <rows.json> [--dry-run]` |
| sub-increment items | `python3 scripts/gate.py tracker --ensure --sub-increments <F>` |
| phase start (In Progress) | `python3 scripts/gate.py tracker --start --feature <F> --phase <P> [--item <IDENT>] [--aligns AC-…]` |
| `move_to_column`, `close_issue` | `python3 scripts/gate.py tracker --move <IDENT> --to backlog\|ready\|in-progress\|done` |

- Rows file: a JSON list of `{title, ident?, body?, labels?, parent?, milestone?, state?}`. `body` is a file path; `state` defaults to `backlog`.
- The gate creates with `gh issue create`, adds the item to the project, sets `Status` to the state's column and nests with `addSubIssue`. An open issue never added to the project is added, not created twice.
- Moving into the flow's done column closes the issue; moving out of it reopens it.
- An item under another parent is red — never re-parented. A parentless item is linked.
- Re-running creates nothing: an item found by its ident (the title head) is left as it is. Two items on one ident: red.
- Recovery from a partial run is a re-run of the same command — never a hand rollback.

#### `add_label`
```bash
gh issue edit <issue_number> --repo {{REPO_SLUG}} --add-label "<label_name>"
```

Used by the iteration-model cascade to mark gate issues as stale. The label must already exist (created at `--init-board` via `create_label` or on-demand via `gh label create`). Safe to call on an issue that already has the label — GitHub ignores duplicates.

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

Post-init values are written to `docs/backlog/project-config.json` and re-read on subsequent BACKLOG commands.

---

## 4. Troubleshooting

| Symptom | Cause | Resolution |
| --- | --- | --- |
| `gh: command not found` | CLI not installed | See § 0 Install |
| `error: not logged in` / `HTTP 401` | Not authenticated | `gh auth login --web --scopes "repo,project,read:org"` |
| `HTTP 403: Resource not accessible by integration` | Missing `project` scope | `gh auth refresh --scopes project,read:org` |
| `error: no projects found` | Wrong `{{ORG_OR_USER}}` in project-config.json | Verify with `gh project list --owner {{ORG_OR_USER}}`; re-run `--init-board` if project was deleted |
| `the flow names column `X` and the board has none` | `Status` options ≠ `tracker.flow` | `configure_board`, or fix `tracker.flow` |
| `the GitHub project has no single-select `Status` field` | board never configured | `configure_board` |
| `GitHub has no issue … right after creating it` | read-after-write lag | re-run the same command — nothing is created twice |
| `HTTP 429: rate limit exceeded` | Too many API calls | Wait for `X-RateLimit-Reset` header; batch `query_board` calls through the memory cache |
| `unknown command "link" for "gh project"` | gh older than 2.45.0 | Upgrade gh (§ 0), then run only the `gh project link` command from `create_project` — never re-run `--init-board` |
| `… has different owner from …` | Board and repository have different owners | GitHub links a board only to a repository of the same owner: `{{ORG_OR_USER}}` must be the owner in `{{REPO_SLUG}}` |
| `Could not resolve to a Repository with the name …` | The repository does not exist yet, or `{{REPO_SLUG}}` is wrong | Create or push the repository, then run only the `gh project link` command |

---

## 5. Adapter Capabilities Declaration

```yaml
required_ops:
  create_project:        native
  configure_board:       native
  create_label:          native
  create_issue:          gate       # gate.py tracker --ensure
  add_to_board:          gate       # the gate adds and places the item
  move_to_column:        gate       # gate.py tracker --move / --start
  close_issue:           gate       # --move … --to done (closes; leaving done reopens)
  add_label:             native     # gh issue edit --add-label
  query_board:           native
  get_item_id:           native
  read_issue:            native
  verify_issue:          composed   # read_issue + comparison
  verify_board_placement: native

optional_ops:
  create_milestone:      native     # via repos/{repo}/milestones
  add_sub_issue:         gate       # addSubIssue, through gate.py tracker --ensure
```

Sub-issue nesting is available: gate phases and sub-increments nest under their IMPLEMENT parent.
