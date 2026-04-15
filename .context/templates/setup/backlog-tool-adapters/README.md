---
description: "Tool-adapter templates for the BACKLOG subsystem. SETUP --generate selects exactly one based on Q27 (project_tracking.tool) and materialises it into the target project as docs/backlog/tool-adapter.md."
---

# Backlog Tool-Adapter Templates

This directory contains per-tool adapter templates that map the **abstract operations** defined in `.claude/instructions/Factory-backlog-operations.instructions.md` § 6.0 to the concrete CLI/MCP commands or file operations needed for each tracker.

## Selection at SETUP --generate

The SETUP materialization phase reads `project_tracking.tool` from `docs/setup.md` (Q27 answer) and selects exactly one template:

| `project_tracking.tool` value | Template selected | Target file |
| --- | --- | --- |
| `"GitHub Projects"` (or any value matching `/github/i`) | [`github-project.md`](./github-project.md) | `docs/backlog/tool-adapter.md` |
| `"Jira"` (or any value matching `/jira/i`) | [`jira.md`](./jira.md) | `docs/backlog/tool-adapter.md` |
| `"Linear"` (or any value matching `/linear/i`) | [`linear.md`](./linear.md) | `docs/backlog/tool-adapter.md` |
| `"None"` | [`none.md`](./none.md) | `docs/backlog/tool-adapter.md` |
| Any other value | **Fallback:** materialise `none.md` AND emit a warning asking the user to contribute a dedicated adapter based on the `jira.md` / `linear.md` stubs | `docs/backlog/tool-adapter.md` |

## Adapter Contract

Every adapter MUST provide a command or procedure for each **required** abstract operation in § 6.0:

**Bootstrap:** `create_project`, `configure_board`, `create_label`
**Lifecycle:** `create_issue`, `add_to_board`, `move_to_column`, `close_issue`
**Query/verification:** `query_board`, `get_item_id`, `read_issue`, `verify_issue`, `verify_board_placement`

**Optional** (adapters MAY declare as no-op — BACKLOG then falls back to documented alternatives):
- `create_milestone` — skipped when `milestone_strategy == "none"` or the tool has no milestone concept
- `add_sub_issue` — skipped when the tool lacks sub-issue nesting; BACKLOG then treats gate issues as standalone siblings

## Placeholders

Templates use `{{PLACEHOLDER}}` notation for values resolved by SETUP --generate:

| Placeholder | Source | Example |
| --- | --- | --- |
| `{{PROJECT_NAME}}` | Q1 / `docs/setup.md` `project_name` | `mass` |
| `{{REPO_SLUG}}` | Derived from git remote / Q1 | `e2its/mass` |
| `{{ORG_OR_USER}}` | Derived from git remote / user input | `e2its` |
| `{{PROJECT_NUMBER}}` | Captured post-`create_project` during `--init-board` (not known at SETUP time — adapter includes capture instructions) | `4` |
| `{{CLI_BINARY}}` | Inferred from tool choice | `gh`, `jira`, `linear` |
| `{{MILESTONE_STRATEGY}}` | Q27.3 | `epic-based` |
| `{{BOARD_COLUMNS}}` | Q27.1 | `[Todo, In Progress, Review, Done]` |
| `{{NAMING_CONVENTION}}` | Q27.4 | `FEAT-NNN` |

Placeholders marked "captured post-init" remain in `{{...}}` form after materialization and are resolved into `docs/backlog/project-config.json` by the first `--init-board` run.

## Authoring a new adapter

To contribute a new adapter (e.g. Azure Boards, Shortcut, Notion):

1. Copy `jira.md` as a starting point (it documents every operation as a stub).
2. Fill in the concrete commands for each required op.
3. Declare which optional ops the tool supports (or `no-op`).
4. Add the `## Prerequisites` section with install + auth instructions.
5. Add the `## Troubleshooting` section with error patterns and fixes.
6. Register the tool name → template mapping in this README's selection table.
7. Add a matching branch in `.claude/instructions/Factory-setup-materialization.instructions.md` selector.

## What these templates are NOT

- **Not protocol instructions.** The BACKLOG protocol (how to plan, sequence, sync) lives in `.claude/instructions/Factory-backlog-*.instructions.md`. Adapters only contain tool-specific command translations.
- **Not credentials.** Adapters assume the user has pre-authenticated the CLI or configured the MCP server. The framework NEVER stores, reads, or transmits credentials.
- **Not stateful.** Adapters are pure command catalogues. All runtime state lives in `docs/backlog/project-config.json` and the memory cache.
