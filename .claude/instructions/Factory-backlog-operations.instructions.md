---
applyTo: "backlog"
description: "Factory BACKLOG operations — issue naming, body templates, board management, project configuration. Use when: BACKLOG --init-board, --plan-feature, --create-issue, --move, --status execution."
---

# Backlog Manager — Operations Reference

> Loaded contextually by the `backlog` agent. Contains all operational protocols, conventions, and templates for issue management.

---

## 0. SINGLE SOURCE OF TRUTH (SSOT)

> **Invariant:** There MUST be exactly ONE source of truth for backlog state. The operating mode is determined by `project_tracking.tool` from SETUP.

| Mode | Condition | Source of Truth | Local Artifacts |
| --- | --- | --- | --- |
| **External** | `tool != "None"` | The configured external tool (name from SETUP Q27) | Only `docs/backlog/project-config.json` (connection params) |
| **Local** | `tool == "None"` | Local files | `docs/backlog/state.md` + `docs/backlog/issue-bodies/*.md` |

**External mode:** Do NOT create or update `state.md` or `issue-bodies/`. Pass issue body content inline to the tool CLI/API (not via local files). The external tool is the canonical record.

**Local mode:** Do NOT create `project-config.json`. All issue state lives in `state.md`. Body content persisted in `issue-bodies/`. No API calls to external tools.

---

## 1. SETUP-DRIVEN CONFIGURATION

All constants are derived from SETUP --init decisions in `docs/setup.md`. This section describes the **field mappings**.

```yaml
# Read from governance snapshot (## Setup Configuration) or fallback to docs/setup.md
project_tracking:
  tool: "{{project_tracking_tool}}"           # Q27: any tool name (free text) or "None" for local-only mode
  board_columns:                               # Q27.1: Kanban columns
    - "{{col_1}}"                              # Default: Todo
    - "{{col_2}}"                              # Default: In Progress
    - "{{col_3}}"                              # Default: Review
    - "{{col_4}}"                              # Default: Done
  feature_phases: "{{preset_string}}"          # Q27.2: Preset string — "full-sdlc" | "simplified" | "single"
                                               # BACKLOG expands preset into phase objects at runtime (see § 1.1)
  milestone_strategy: "{{milestone_strategy}}" # Q27.3: phase-based | sprint-based | none
  naming_convention: "{{naming_convention}}"   # Q27.4: FEAT-NNN | USR-NNN | custom prefix
```

### 1.1 Feature Phases: Preset → Expanded Phase Objects

SETUP Q27.2 persists a **preset string** in `project_tracking.feature_phases`. The BACKLOG agent expands this into the structured phase object list at runtime:

| Preset | Phases | Issue Count |
| --- | --- | --- |
| **full-sdlc** | codesign → blueprint → devops → implement → qa | 5 |
| **simplified** | spec → implement → qa | 3 |
| **single** | one issue per feature | 1 |

**Expansion example (`full-sdlc`):**
```yaml
# Runtime expansion performed by BACKLOG agent — NOT stored in setup.md
- { suffix: 1, label: "codesign",  title_pattern: "[{ID}] CODESIGN: Spec BDD + UX Mock — {name}" }
- { suffix: 2, label: "blueprint", title_pattern: "[{ID}] BLUEPRINT: Architecture + Test Plan — {name}" }
- { suffix: 3, label: "devops",    title_pattern: "[{ID}] DEVOPS: Infrastructure — {name}" }
- { suffix: 4, label: "implement", title_pattern: "[{ID}] IMPLEMENT: Code + Tests — {name}" }
- { suffix: 5, label: "qa",        title_pattern: "[{ID}] QA: Verification — {name}" }
```

---

## 2. RUNTIME CONSTANTS (External mode only — post --init-board)

> **SSOT:** This section applies ONLY in external mode (`project_tracking.tool != "None"`). In local mode, no external connection config is needed.

> **🔒 SECURITY INVARIANT — ZERO CREDENTIALS:** `project-config.json` MUST NEVER contain credentials, API tokens, passwords, or secrets. Authentication is handled entirely by the CLI tool (e.g., `gh auth login`) or the MCP server — the framework never touches credentials. Only non-sensitive identifiers (project IDs, field IDs, repo slugs) are persisted.

After `--init-board` creates the external project, persist these to `docs/backlog/project-config.json`:

```json
{
  "tool": "{{project_tracking_tool}}",
  "integration": "cli",
  "cli_command": "{{cli_binary}}",
  "project_ids": {},
  "board_field_mapping": {}
}
```

- `tool` — The exact tool name from SETUP Q27 (e.g., `"GitHub Projects"`, `"Jira"`, `"Linear"`, or any user-specified tool)
- `integration` — **Enum: `"cli"` or `"mcp"`**. How the agent interacts with the tool. `"cli"` = authenticated CLI binary; `"mcp"` = MCP server. Exactly one value — never both.
- `cli_command` — The CLI binary name (e.g., `"gh"`, `"jira"`, `"linear"`) — must be pre-authenticated by the user. **Only when `integration == "cli"`**; set to `null` when `integration == "mcp"`.
- `project_ids` — Non-sensitive tool-specific identifiers populated by `--init-board` (e.g., project node ID, repo slug). Schema depends on the tool. **No secrets.**
- `board_field_mapping` — Tool-specific field/column IDs populated by `--init-board` (e.g., status field ID, column option IDs). Schema depends on the tool.

The exact fields inside `project_ids` and `board_field_mapping` are determined by the **tool-adapter** (`docs/backlog/tool-adapter.md`) materialized during `SETUP --generate`.

---

## 3. ISSUE NAMING CONVENTIONS

### 3.1 Feature Issues (strict ordering per feature_phases)

Title pattern from `feature_phases[N].title_pattern` with variables:
- `{ID}` → Feature ID (e.g., `FEAT-001`, `USR-001` — from naming_convention)
- `{name}` → Feature name provided by user

### 3.2 Infrastructure Issues (prefix `[INFRA]`)

| Pattern | Label |
| --- | --- |
| `[INFRA] {description}` | `infra` |
| `[DATA] {description}` | `test-data` |

### 3.3 Refinement / Extension Issues

Append sequential suffix to phase label:

```
[{ID}] CODESIGN-R1: Refinement — {description}
[{ID}] BLUEPRINT-R1: Extension — {description}
```

Labels: same phase label + `enhancement`.

---

## 4. LABELS

### Phase Labels (auto-created from feature_phases)

Generated from `feature_phases[N].label`: e.g., `codesign`, `blueprint`, `devops`, `implement`, `qa`

### Milestone Labels (auto-created from milestone_strategy)

- Phase-based: `phase-1`, `phase-2`, `phase-3`...
- Sprint-based: `sprint-1`, `sprint-2`...

### Status Labels

`blocked`, `enhancement`, `bug`

---

## 5. BODY FILE CONVENTIONS

> **SSOT:** Body files are ONLY created in **local mode** (`project_tracking.tool == "None"`). In external mode, body content is generated in-memory and passed inline to the tool's CLI/API — the external tool holds the canonical body. The same templates below are used to generate the inline content, but NO files are persisted locally.

### Storage Path (local mode only)

`docs/backlog/issue-bodies/`

### Naming Pattern

- Features: `{id_lower}-{S}-{stage}.md`
  - `{id_lower}` = `{ID}` lowercased, hyphens and zero-padding preserved (e.g., `FEAT-001` → `feat-001`)
  - Example: `feat-001-1-codesign.md` for `{ID} = FEAT-001`, phase suffix `S = 1`, stage `codesign`
- Infra: `infra-{slug}.md`

### Body File Template — Feature Issue

```markdown
## What is needed?

{One paragraph describing what this phase needs to deliver for this feature.}

## Visual context and UX

{Only for codesign issues. Reference design system, pages, mobile-first, WCAG.}

## Stack guardrails

- **{Key}**: {Constraint} — {rationale}
  {List 3-5 key technical constraints from constitution.md and rules/}

## Factory command

`{AGENT} --{command} {ID}`

## Prerequisites

- {List prior issues that must be complete}

## Definition of Done

- [ ] {Artifact 1 with path}
- [ ] {Artifact 2 with path}
- [ ] {Validation criteria}
```

### Body File Template — Refinement Issue

```markdown
## What is being refined?

{Feature and bounded context being refined. Reference original issues.}

## Requested changes

1. {Change 1}
2. {Change 2}

## Impact on existing artifacts

- `docs/spec/{ID}/spec.feature` — {what changes}
- `docs/spec/{ID}/design.md` — {what changes}

## Factory command

`{AGENT} --refine {ID} "{feedback summary}"`

## Prerequisites

- Original issue #{N} completed

## Definition of Done

- [ ] Artifacts updated to reflect the changes
- [ ] Downstream cascade verified
- [ ] Tests updated
```

---

## 6. ISSUE CREATION PROTOCOL

### 6.0 Tool-Adapter Protocol (External mode)

> The framework is **tool-agnostic**. Tool-specific CLI/MCP commands are NOT hardcoded in operational files. Instead, they are materialized by `SETUP --generate` into `docs/backlog/tool-adapter.md`, which contains the exact commands for the configured tool.

> **🔒 SECURITY:** The tool-adapter uses ONLY pre-authenticated CLI tools or MCP servers. The framework NEVER stores, reads, or transmits credentials. The user is responsible for authenticating the CLI/MCP before running BACKLOG commands (e.g., `gh auth login` for GitHub, Jira CLI login, Linear MCP server config).

**Before any external mode operation, the agent MUST:**
1. Read `docs/backlog/tool-adapter.md` for tool-specific CLI/MCP command patterns
2. **Execute Preflight Check (§ 6.0.2)** — verify CLI/MCP is installed, authenticated, and has required permissions. BLOCK if any check fails.
3. Read `docs/backlog/project-config.json` for runtime identifiers (post --init-board)
4. Substitute placeholders in tool-adapter commands with values from project-config.json and the current operation context
5. If a CLI/MCP command fails during execution → execute the **Error Resolution Protocol** (§ 6.0.1)

The tool-adapter defines commands for these abstract operations:
| Operation | Description |
| --- | --- |
| `create_issue` | Create an issue with title, body, labels, milestone, assignee |
| `add_to_board` | Add an issue to the project board |
| `move_to_column` | Move an issue to a specific board column |
| `create_project` | Create a new project/board |
| `configure_board` | Set up board columns from setup decisions |
| `query_board` | Query all items with their status |
| `get_item_id` | Get the board item ID for an issue |
| `verify_issue` | Verify an issue exists with expected title, labels, and status. Returns issue metadata for comparison |
| `verify_board_placement` | Verify an issue is on the project board in the expected column. Returns current column/status |
| `close_issue` | Close or delete an issue (used for rollback). Accepts issue number/ID |

> **Tech-Agnostic Invariant:** ALL operations above — including verification and rollback — are **abstract**. The tool-adapter materializes them with tool-specific CLI/MCP commands during `SETUP --generate`. The BACKLOG agent NEVER hardcodes tool-specific commands; it ALWAYS delegates to the tool-adapter. If a tool does not support an operation natively, the tool-adapter defines the closest equivalent or a composed multi-step workaround.

The tool-adapter also includes a `## Prerequisites` section with setup instructions and a `## Troubleshooting` section with error resolution guidance.

### 6.0.2 Preflight Check (MANDATORY — before any external operation)

The agent MUST verify the tool is operational **before** doing any work (generating content, reading configs, etc.):

```yaml
READ docs/backlog/project-config.json → integration

IF integration == "cli":
  STEP 1 — Binary exists:
    RUN: which {{cli_command}}     # e.g., which gh
    FAIL → error_category: "Not installed" → show install instructions from tool-adapter ## Prerequisites

  STEP 2 — Authenticated:
    RUN: {{verify_command}}         # e.g., gh auth status
    FAIL → error_category: "Not authenticated" → show auth instructions from tool-adapter ## Prerequisites

  STEP 3 — Permissions (if verify_command output includes scope info):
    CHECK: required scopes from tool-adapter ## Prerequisites → Required Permissions
    MISSING → error_category: "Insufficient permissions" → show scope update instructions

IF integration == "mcp":
  STEP 1 — MCP server configured:
    CHECK: MCP server name from tool-adapter ## Prerequisites exists in agent config
    FAIL → error_category: "MCP not configured" → show MCP setup instructions from tool-adapter ## Prerequisites

  STEP 2 — MCP server reachable:
    RUN: {{mcp_verify_command}}     # tool-adapter defines the verification command/call
    FAIL → error_category: "MCP server unreachable" → show connection troubleshooting
```

**If ANY step fails:**
1. Present the failure using the Error Resolution Protocol (§ 6.0.1) response format
2. **BLOCK** — do NOT proceed with the command
3. Wait for user confirmation that the issue is resolved
4. Re-run the failed step. If it passes → continue. If it fails again → ABORT with full diagnostic.

**Rationale:** Catching issues upfront avoids wasted work. Without this gate, the agent could spend time generating issue bodies, reading configs, and building commands — only to fail at execution because the CLI isn't installed.

### 6.0.1 Error Resolution Protocol (CLI/MCP failures)

When ANY tool-adapter command fails, the agent MUST:

1. **Capture the error output** — read the full stderr/stdout from the failed command
2. **Classify the error** using the table below
3. **Present the user with**:
   - The exact command that failed
   - The error category and what it means in plain language
   - Step-by-step resolution instructions from the tool-adapter `## Troubleshooting` section
   - The exact command(s) to run to fix the issue
4. **Ask the user to confirm** when the fix is applied, then **retry the original command once**
5. If it fails again → show the raw error output and suggest the user check the tool-adapter `## Troubleshooting` section manually

**Error Classification:**

| Category | Detection Pattern | Resolution |
| --- | --- | --- |
| **Not installed** | `command not found`, `not recognized` | Provide install instructions from tool-adapter `## Prerequisites` |
| **Not authenticated** | `auth`, `login`, `401`, `403`, `unauthorized`, `token` | Provide auth command from tool-adapter `## Prerequisites` (e.g., `gh auth login`) |
| **Insufficient permissions** | `403`, `scope`, `permission denied`, `insufficient` | Explain which permissions/scopes are needed and how to grant them |
| **Network / connectivity** | `timeout`, `connection refused`, `ECONNREFUSED`, `network` | Suggest checking internet connection, proxy settings, or VPN |
| **Resource not found** | `404`, `not found`, `does not exist` | Verify project-config.json IDs are correct; may need `--init-board` re-run |
| **Rate limit** | `rate limit`, `429`, `too many requests` | Inform wait time and suggest retry after the cooldown period |
| **MCP server unavailable** | `mcp`, `server`, `connection`, `refused` | Provide MCP server startup instructions from tool-adapter `## Prerequisites` |
| **Unknown** | None of the above | Show raw error, reference tool-adapter `## Troubleshooting`, suggest user consult tool documentation |

**Response format to user:**
```
⚠️ El comando de {tool_name} ha fallado.

**Comando:** `{failed_command}`
**Error:** {error_category} — {one_line_explanation}

**Para resolverlo:**
1. {step_1}
2. {step_2}
...

Cuando lo hayas resuelto, confirma y reintento el comando.
```

### 6.1 Single Issue — External Mode

1. Generate body content in-memory using templates from § 5
2. Execute tool-adapter `create_issue` command with: title, body, labels, milestone, assignee
3. **MANDATORY — Parse output**: Extract issue number/URL from command output. If parsing fails → STOP and show raw output to user
4. **MANDATORY — Add to board**: Execute tool-adapter `add_to_board` with the captured issue number
5. **MANDATORY — Set status**: Execute tool-adapter `move_to_column` to place issue in initial column (first board_column, typically "Todo")
6. **MANDATORY — Verify**: Execute tool-adapter `verify_board_placement` with issue reference + expected column. If verification fails → retry once → if still fails, report error with full diagnostics

> **SSOT:** No local file persistence for body content in external mode.
> **INVARIANT:** Steps 2-6 form an atomic sequence. Skipping any step is a protocol violation.
> **Tech-Agnostic:** All commands (steps 2-6) are abstract operations from the tool-adapter. The agent NEVER constructs tool-specific CLI commands directly.

### 6.1L Single Issue — Local Mode

1. Generate body file in `docs/backlog/issue-bodies/{filename}.md` using templates from § 5
2. Assign a sequential local ID (e.g., `L-001`, `L-002`...)
3. Add entry to `docs/backlog/state.md` with: local ID, title, first column status, body file path
4. **MANDATORY — Verify**: Re-read `state.md` to confirm entry was written correctly with correct status

### 6.2 Full Feature (N issues per feature_phases)

Execute in strict phase order (suffix 1 → N). **Track progress for each phase.**

- **External mode**: For EACH phase, execute the full 6.1 sequence (steps 2-6). After each phase:
  - Log: `✅ Phase {suffix}/{total}: Issue #{number} created → board: {column}`
  - If any phase fails after retry → execute Rollback Protocol (close all previously created issues in this batch) → STOP
  - After ALL phases complete → run Final Verification Gate (§ 6.4)
- **Local mode**: For EACH phase, execute the full 6.1L sequence. After each phase:
  - Verify entry in `state.md`
  - If any phase fails → remove all previously created entries and body files → STOP
  - After ALL phases complete → re-read `state.md` to confirm all N entries present

### 6.3 After Creation — Project Board Update (External mode only)

> **SSOT:** This step applies ONLY in external mode. In local mode, `state.md` already reflects the board state.
> **NOTE:** In the improved protocol, board addition and status assignment are now part of the atomic § 6.1 sequence (steps 4-5). This section documents the legacy standalone flow — if § 6.1 steps 4-5 were already completed during creation, do NOT repeat them here.

1. Execute tool-adapter `add_to_board` command with the newly created issue reference
2. Execute tool-adapter `move_to_column` command to place the issue in the first column (e.g., Todo)
3. All commands use the pre-authenticated CLI/MCP — no credentials in the command arguments
4. **MANDATORY — Verify board placement**: Confirm issue appears on board with correct status

### 6.4 Final Verification Gate (MANDATORY — after --plan-feature)

After ALL issues in a `--plan-feature` batch are created, execute a full board query to verify:

```yaml
FUNCTION final_verification_gate(feature_id, expected_count, expected_issues):
  # Query full board state via tool-adapter abstract operations
  IF mode == "external":
    RUN: tool-adapter `query_board`    # Abstract — materialized per tool by SETUP
    PARSE: all items on board
  ELIF mode == "local":
    READ: docs/backlog/state.md

  # Check 1: Count
  actual_count = count issues matching feature_id
  IF actual_count != expected_count:
    ❌ REPORT: "Expected {expected_count} issues for {feature_id}, found {actual_count}"

  # Check 2: Status assignment (verify each issue is in expected column)
  FOR EACH expected_issue:
    IF mode == "external":
      RUN: tool-adapter `verify_board_placement` with issue reference + expected column
      PARSE: current column from response
    ELIF mode == "local":
      READ: issue's Status column from state.md

    IF issue NOT found:
      ❌ REPORT: "Issue '{expected_issue.title}' not found on board"
    ELIF current_column != expected_issue.expected_status:
      ❌ REPORT: "Issue #{issue.number} has status '{current_column}', expected '{expected_issue.expected_status}'"

  # Check 3: Labels (external mode)
  IF mode == "external":
    FOR EACH expected_issue:
      RUN: tool-adapter `verify_issue` with issue reference
      CHECK: phase label is present in response
      IF missing:
        ⚠️ WARN: "Issue #{issue.number} missing label '{expected_issue.phase_label}'"

  # Summary
  IF all checks pass:
    ✅ "Verification passed: {actual_count}/{expected_count} issues on board with correct status"
  ELSE:
    ⚠️ "Verification found discrepancies — review report above"
```

---

## 7. PROJECT BOARD OPERATIONS

### 7.1 Create Project (--init-board)

#### External Mode

1. **Verify CLI/MCP readiness**: Execute Preflight Check (§ 6.0.2). If it fails → resolve with user before proceeding.
2. **Execute tool-adapter `create_project`**: Create the project/board in the external tool
3. **Execute tool-adapter `configure_board`**: Set up board columns from `board_columns` setup decisions
4. **Retrieve project identifiers**: Extract non-sensitive IDs (project ID, field IDs, column option IDs) from command outputs
5. **Persist to `docs/backlog/project-config.json`**: Write the tool name, integration method, CLI command, project IDs, and field mappings — **zero credentials**
6. **Inform user**: Display the project URL and note any manual steps from the tool-adapter

#### Local Mode

Initialize `docs/backlog/state.md` with the Kanban table structure:

```markdown
---
last_updated: {date}
total_issues: 0
next_local_id: 1
board_columns: [{col_1}, {col_2}, {col_3}, {col_4}]
---

# Backlog State

## Board

| Local ID | Feature | Title | Status | Body File |
|----------|---------|-------|--------|-----------|
| — | — | — | — | — |

## Next Action

Run `BACKLOG --plan-feature` to create feature issues.
```

Create `docs/backlog/issue-bodies/.gitkeep` to track the directory.

### 7.2 Move Issues (--move)

#### External Mode

1. Read current board state via tool-adapter `query_board` to confirm issues exist and their current status
2. Execute tool-adapter `get_item_id` to resolve issue numbers to board item IDs
3. Read column option IDs from `project-config.json` → `board_field_mapping` (needed to map target column name to field value)
4. Execute tool-adapter `move_to_column` for each issue using the resolved field value from step 3
5. **MANDATORY — Verify each move**: Execute tool-adapter `verify_board_placement` for each issue to confirm status matches target column. Report per-issue result: `✅ #{N}: {old_status} → {new_status}` or `❌ #{N}: move failed`

#### Local Mode

1. Read current `state.md` to confirm issue IDs exist
2. Update the `Status` column for the specified local IDs in `docs/backlog/state.md`
3. **MANDATORY — Verify**: Re-read `state.md` to confirm status values were updated correctly

### 7.3 Board Status (--status)

#### External Mode

Execute tool-adapter `query_board` command to retrieve all items with their current status column. Parse the output and display the summary table. Include issue count per column and total.

#### Both Modes — Display Format

```
| Column       | Count | Issues |
|-------------|-------|--------|
| Todo         | 5     | #10, #11, #12, #13, #14 |
| In Progress  | 2     | #7, #8 |
| Review       | 1     | #6 |
| Done         | 3     | #1, #2, #3 |
```

In local mode, "Issues" column shows local IDs (e.g., `L-001`, `L-002`).

---

## 8. STATE TRACKING (Local mode only)

> **SSOT:** This section applies ONLY in **local mode** (`project_tracking.tool == "None"`). In external mode, the external tool IS the state tracker — do NOT create or update `state.md`.

Path: `docs/backlog/state.md`

This file IS the backlog in local mode. It serves as both the issue registry and the Kanban board. Update it after every operation:

```markdown
---
last_updated: {date}
total_issues: {N}
next_local_id: {N+1}
board_columns: [Todo, In Progress, Review, Done]
---

# Backlog State

## Board

| Local ID | Feature | Title | Status | Body File |
|----------|---------|-------|--------|-----------|
| L-001 | FEAT-001 | [FEAT-001] CODESIGN: Spec BDD + UX Mock — Auth | Todo | issue-bodies/feat-001-1-codesign.md |
| L-002 | FEAT-001 | [FEAT-001] BLUEPRINT: Architecture — Auth | Todo | issue-bodies/feat-001-2-blueprint.md |

## Next Action

{What should be done next}
```

---

## 9. GOVERNANCE ALIGNMENT

This agent respects the Factory governance framework:

- **SSOT Invariant**: Exactly one source of truth per § 0 — external tool XOR local files, never both
- **Constitution**: `docs/constitution.md` — stack constraints
- **Rules**: `docs/rules/*` — specific regulations per area
- **Spec structure**: `docs/spec/{FEAT-ID}/` — per-feature artifacts
- **Feature map**: `contracts/feature_map.md` — BC↔contract mapping

When creating issue bodies (inline for external mode, or as files for local mode), reference:
1. The originating Factory command
2. The governance rules that apply
3. The bounded context being modified
4. Impact on downstream artifacts (cascade)

---

## 10. EXECUTION PLAN (Cross-Reference)

> **Full protocol:** See `Factory-backlog-execution-plan.instructions.md` for the complete execution plan protocol.

The execution plan (`docs/backlog/execution-plan.md`) organizes feature delivery by **Epics** — groups of features that share Bounded Context boundaries. Each epic is subdivided into **Slices** (≤3 features) grouped by shared Aggregate Root coupling. This minimizes rework and agent overload by:

1. **Co-designing** features in the same slice together (max 3 at a time)
2. **Fixing contracts** for the slice together (BLUEPRINT phase)
3. **Implementing sequentially** against stable contracts (IMPLEMENT phase)
4. **Completing each slice's full pipeline** before starting the next slice

### 10.1 Integration Points

| Operation | Execution Plan Action |
| --- | --- |
| `--plan-feature` | After creating issues, update execution-plan.md step lines with issue references |
| `--move {ISSUES} --to Done` | Suggest `--update-execution` to mark corresponding plan steps as complete |
| `--status` | Include execution plan progress summary if plan exists |

### 10.2 Memory Cache

The execution plan state is cached in `/memories/repo/execution-plan-cache.md` for fast next-task resolution. The cache is a **read/write-through** optimization — the disk file (`docs/backlog/execution-plan.md`) remains the single source of truth. See the execution plan instruction file for cache operations.

### 10.3 Commands (delegated to execution plan instruction)

| Command | Description |
| --- | --- |
| `--plan-execution` | Analyze dependencies, form epics, generate execution-plan.md |
| `--update-execution {step}` | Mark step complete, update progress, refresh cache |
| `--sync-execution` | Reconcile plan with board state, rebuild cache |
