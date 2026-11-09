---
description: "Tool-adapter templates for the BACKLOG subsystem. SETUP --generate selects exactly one by the derived project_tracking.adapter and materialises it into the target project as docs/backlog/tool-adapter.md."
---

# Backlog Tool-Adapter Templates

Per-tool adapters: the **abstract operations** of `.claude/instructions/Factory-backlog-operations.instructions.md` § 6.0 → the tool's commands. Lifecycle operations (create, place, move, close, nest) run only through `python3 scripts/gate.py tracker` on every adapter; an adapter documents bootstrap and reads.

## Selection at SETUP --generate

`gate.py discovery --resolve` derives `project_tracking.adapter` from Q27 (`project_tracking.tool`). SETUP lands one template:

| Q27 answer | `project_tracking.adapter` | Template | Target file |
| --- | --- | --- | --- |
| `GitHub Projects` (contains `github`) | `github` | [`github-project.md`](./github-project.md) | `docs/backlog/tool-adapter.md` |
| `Jira` (contains `jira`) | `jira` | [`jira.md`](./jira.md) | `docs/backlog/tool-adapter.md` |
| `None` | `none` | [`none.md`](./none.md) | `docs/backlog/tool-adapter.md` |
| any other name | `none` + the resolver's WARN | [`none.md`](./none.md) | `docs/backlog/tool-adapter.md` |

A tracker with no adapter gets the whole `none` set (`docs/backlog/state.md`); the framework drives no board it has no executor for.

## Adapter Contract

Every adapter MUST provide a command or procedure for each **required** abstract operation in § 6.0:

**Bootstrap:** `create_project`, `configure_board`, `create_label`
**Lifecycle:** `create_issue`, `add_to_board`, `move_to_column`, `close_issue` — `gate.py tracker`
**Query/verification:** `query_board`, `get_item_id`, `read_issue`, `verify_issue`, `verify_board_placement`

**Optional** (adapters MAY declare as no-op — BACKLOG then falls back to documented alternatives):
- `create_milestone` — skipped when `milestone_strategy == "none"` or the tool has no milestone concept
- `add_sub_issue` — `gate.py tracker --ensure` with a `parent`; every shipped adapter nests (GitHub sub-issue, Jira parent, `none` parent column)

Board columns: `config/quality.json → tracker.flow` (Q27.7) names the column for backlog, ready, in progress, done. No adapter hard-codes a column name.

## Placeholders

Templates use `{{PLACEHOLDER}}` notation for values resolved by SETUP --generate:

| Placeholder | Source | Example |
| --- | --- | --- |
| `{{PROJECT_NAME}}` | Q1 / `docs/setup.md` `project_name` | `app` |
| `{{REPO_SLUG}}` | Derived from git remote / Q1 | `acme/app` |
| `{{ORG_OR_USER}}` | Derived from git remote / user input | `acme` |
| `{{PROJECT_NUMBER}}` | Captured post-`create_project` during `--init-board` (not known at SETUP time — adapter includes capture instructions) | `4` |
| `{{CLI_BINARY}}` | Inferred from tool choice | `gh`, `jira` |
| `{{MILESTONE_STRATEGY}}` | Q27.3 | `epic-based` |
| `{{BOARD_COLUMNS}}` | Q27.1 | `[Backlog, Ready, In Progress, Done]` |
| `{{NAMING_CONVENTION}}` | Q27.4 | `FEAT-NNN` |

Placeholders marked "captured post-init" remain in `{{...}}` form after materialization and are resolved into `docs/backlog/project-config.json` by the first `--init-board` run.

## Authoring a new adapter

A new tracker needs all of:

1. An executor in `scripts/gates/tracker.py` (read into the one board shape, apply, re-read).
2. Recorded responses under `scripts/fixtures/tracker/` and tests: parsing, idempotent re-run, flow mapping.
3. A `matches` value for `project_tracking.adapter` in the discovery registry, and the Q27 suggestion.
4. An adapter file here: prerequisites, bootstrap, reads, troubleshooting, capabilities.
5. A row in the selection table above and its manifest entry.

## What these templates are NOT

- **Not protocol instructions.** The BACKLOG protocol (how to plan, sequence, sync) lives in `.claude/instructions/Factory-backlog-*.instructions.md`. Adapters only contain tool-specific command translations.
- **Not credentials.** The framework stores no credential. GitHub uses the pre-authenticated `gh`; a Jira token comes from the vault into the environment (`project_tracking.token` names the entry); the MCP server authorises through OAuth in the harness.
- **Not stateful.** Adapters are pure command catalogues. Runtime ids live in `docs/backlog/project-config.json`; board state lives on the board (or `docs/backlog/state.md`).
