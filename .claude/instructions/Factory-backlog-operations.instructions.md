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

| Preset | Phases | Issue Count | Gates |
| --- | --- | --- | --- |
| **full-sdlc** | codesign → blueprint → contract-freeze → devops → implement → preventive-sweep → qa → smoke-e2e | **8** | CONTRACT-FREEZE, PREVENTIVE-SWEEP, SMOKE-E2E |
| **simplified** | spec → implement → qa | 3 | — |
| **single** | one issue per feature | 1 | — |

> **Production default.** `full-sdlc` is the default preset for production features. The three extra phases (contract-freeze at suffix 3, preventive-sweep at suffix 6, smoke-e2e at suffix 8) act as hard gates enforced by downstream command instructions — they do NOT ship in `simplified` or `single` presets, which are reserved for prototypes and spikes where gate overhead is not justified.

**Expansion example (`full-sdlc`):**
```yaml
# Runtime expansion performed by BACKLOG agent — NOT stored in setup.md
- { suffix: 1, label: "codesign",         title_pattern: "[{ID}] CODESIGN: Spec BDD + UX Mock — {name}" }
- { suffix: 2, label: "blueprint",        title_pattern: "[{ID}] BLUEPRINT: Architecture + Test Plan — {name}" }
- { suffix: 3, label: "contract-freeze",  title_pattern: "[{ID}] CONTRACT-FREEZE: API contracts + test harness — {name}", gate: true, sub_issue_of: 5 }
- { suffix: 4, label: "devops",           title_pattern: "[{ID}] DEVOPS: Infrastructure — {name}" }
- { suffix: 5, label: "implement",        title_pattern: "[{ID}] IMPLEMENT: Code + Tests — {name}" }
- { suffix: 6, label: "preventive-sweep", title_pattern: "[{ID}] PREVENTIVE-SWEEP: Runtime defect scan — {name}",           gate: true, sub_issue_of: 5 }
- { suffix: 7, label: "qa",               title_pattern: "[{ID}] QA: Verification — {name}" }
- { suffix: 8, label: "smoke-e2e",        title_pattern: "[{ID}] SMOKE-E2E: Numbered smoke blocks on dev deploy — {name}",  gate: true, sub_issue_of: 5 }
```

**Gate semantics.** Phases marked `gate: true` are **hard blockers** enforced by upstream command instructions. Each gate issue must be Done before the downstream phase may start:

| Gate phase | Enforced by | Blocks |
| --- | --- | --- |
| CONTRACT-FREEZE (suffix 3) | [Factory-implement-plan.instructions.md](Factory-implement-plan.instructions.md) § Upstream Artifact Validation | `IMPLEMENT --plan` start — the feature's API contracts (OpenAPI / TS interfaces / GraphQL schema / whatever the stack uses) MUST be frozen and the contract test harness MUST exist |
| PREVENTIVE-SWEEP (suffix 6) | [Factory-devops-provision-deploy.instructions.md](Factory-devops-provision-deploy.instructions.md) § Pre-Deploy Checklist | `DEVOPS --deploy dev` — the Factory-preventive-sweep SKILL must have run against the feature's code (parallel scope sub-agents derived from DC catalog) and returned zero open C-severity findings |
| SMOKE-E2E (suffix 8) | [Factory-qa-verify.instructions.md](Factory-qa-verify.instructions.md) § Verify Preconditions | `QA --verify` pass — numbered manual smoke blocks derived from `user_journey.md` BDD scenarios must all pass on the dev-deployed build |

**Sub-issue nesting.** The three gate phases are logically **sub-issues of IMPLEMENT** (suffix 5). Adapters that declare `add_sub_issue: native` (e.g. `github-project.md`) materialise them as real sub-issues so holistic progress tracking on the board reflects feature completion. Adapters that declare `add_sub_issue: no-op` (e.g. `none.md`) materialise them as standalone siblings with a `> Parent: IMPLEMENT issue` cross-reference line in the body — the `--next-task` resolver reads the cross-reference to reconstruct the hierarchy.

**Iteration of the preset.** The 8-phase expansion was introduced by EVOL-014 (derived from the production experience of the first materialised product after months of real use: contract drift killed six features, fifteen runtime defects slipped past static gates into dev, and unstructured smoke testing produced inconsistent Done criteria). Projects materialised before EVOL-014 with the legacy 5-phase expansion keep their existing issue sets — gate issues are backfilled manually by `--plan-feature {ID}` when run on a pre-EVOL-014 feature.

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

> **Tool-agnostic schema.** The patterns below are the canonical title schema for all issues generated by the BACKLOG agent. The tool-adapter renders them into the target tool's native representation (GitHub Issue title, Jira summary, Linear title, `state.md` row, etc.) without changing the pattern itself.

### 3.0 Title Schema Reference

| Issue Class | Title Pattern | Variables |
| --- | --- | --- |
| Feature phase | `[{ID}] {PHASE}: {phase_description} — {name}` | `{ID}` from naming_convention; `{PHASE}` from `feature_phases[N].label` uppercased; `{phase_description}` from `feature_phases[N].title_pattern`; `{name}` user-provided |
| Feature refinement | `[{ID}] {PHASE}-R{k}: Refinement — {description}` | `{k}` sequential refinement index starting at 1 |
| Feature extension | `[{ID}] {PHASE}-R{k}: Extension — {description}` | Same as refinement |
| Slice integration gate | `[SLICE-{N.M}] INTEGRATION-TEST: {scope_description}` | `{N.M}` epic.slice index; `{scope_description}` cross-feature coupling focus |
| Epic retrospective gate | `[EPIC-{N}] RETROSPECTIVE: {focus_area}` | `{N}` epic index; `{focus_area}` retrospective theme |
| Infrastructure | `[INFRA] {description}` | — |
| Test data | `[DATA] {description}` | — |
| Cluster fix | `[{CLUSTER_ID}] {description}` | `{CLUSTER_ID}` e.g. `CLUSTER-001` for grouped hotfix batches |

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

### 3.4 Slice and Epic Gate Issues

Slice- and epic-level gate issues are created by `--plan-execution` alongside the feature phase issues when the selected preset includes integration-test and retrospective phases (see § 1.1).

| Pattern | Phase label | Scope |
| --- | --- | --- |
| `[SLICE-{N.M}] INTEGRATION-TEST: {scope_description}` | `integration-test` | One issue per slice, gates progression to the next slice within the same epic |
| `[EPIC-{N}] RETROSPECTIVE: {focus_area}` | `retrospective` | One issue per epic, gates progression to the next epic |

**Labels applied:**
- Slice integration-test: `phase:integration-test` + `slice:EPIC-{N}.{M}`
- Epic retrospective: `phase:retrospective` + no slice label (epic-scoped, not slice-scoped)

> **Gate semantics.** These issues are **hard gates** — the BACKLOG `--next-task` resolver refuses to return features from slice `{N.(M+1)}` until the `[SLICE-{N.M}] INTEGRATION-TEST` issue is Done, and refuses to return features from epic `{N+1}` until the `[EPIC-{N}] RETROSPECTIVE` issue is Done. The gates are standalone issues, not sub-issues.

**Deliverables per gate:**

| Gate | File deliverable | Board deliverable |
| --- | --- | --- |
| `[SLICE-{N.M}] INTEGRATION-TEST` | `docs/spec/SLICE-{N.M}/integration_test.md` (cross-feature test spec + results) + integration test code under `tests/integration/slice-{N.M}/` (stack-specific path) | Issue body contains scope, member features, Definition of Done checklist. Issue status = Done when all blocks pass. |
| `[EPIC-{N}] RETROSPECTIVE` | **No new file.** The gate's deliverable is 0+ new or updated entries in `docs/rules/defect-prevention.md` (the living defect catalog, consulted by DEV pre-write check and REVIEW Check #2d). If the epic revealed no new patterns, the count is zero and the gate still closes. | Issue body is the retrospective narrative itself (what happened, what was learned, links to any DC entries added). The issue body + its closure timestamp on the tracker serve as the historical record — no separate `lessons_learned.md` file is created. |

> **Why no `lessons_learned.md` per epic.** The framework deliberately keeps a single source of truth for "what we learned": the living catalog at `docs/rules/defect-prevention.md`. A separate per-epic markdown would duplicate narrative that nobody re-reads, while fragmenting the actionable DC entries across files. Narrative history lives on the tracker (issue body + closure date); actionable prevention lives in the rule file.

#### 3.4.1 Retrospective → Defect Prevention Catalog write-back procedure (EVOL-014)

Closing an `[EPIC-{N}] RETROSPECTIVE` gate issue is NOT a single "move to Done" operation. It is a structured two-step write:

**Step 1 — Narrative (issue body).** The BACKLOG agent, assisted by the user, populates the RETROSPECTIVE issue body with:

1. **What happened** — one paragraph per slice in the epic describing what shipped, what slipped, what surprised.
2. **What was learned** — bullet list of novel runtime / governance / architectural patterns observed during the epic that the existing Defect Prevention Catalog did NOT already cover.
3. **Candidate DC entries** — for each learning that meets the Discovery Protocol threshold (runtime-observable, reproducible, preventable by a concrete check), draft a new DC entry inline in the issue body using this block:

   ```markdown
   ### Candidate DC

   - **Name:** {short title}
   - **Applicable When:** {scope condition}
   - **Applicable To:** [{enum list from CODESIGN | BLUEPRINT | IMPLEMENT | REVIEW | DEVOPS | QA | AUDIT}]
   - **Severity:** {BLOCKER | WARNING}
   - **Check:** {what the prevention step verifies}
   - **Evidence:** {link to the feature / commit / issue where this pattern surfaced}
   ```

4. **Non-catalog learnings** — observations that are NOT DC-worthy (team dynamics, scheduling issues, dependency choices) stay in the narrative section only. They do not become rule entries.

**Step 2 — Write-back to `docs/rules/defect-prevention.md`.** For each `### Candidate DC` block in the issue body:

```yaml
FUNCTION retrospective_writeback(retrospective_issue, epic_id):
  # This is the canonical mechanism that closes the producer side of the DC loop.
  # Without it, the narrative in the issue body is dead prose and the catalog never grows.

  body = ADAPTER.read_issue(retrospective_issue) → .body
  candidates = parse_candidate_dc_blocks(body)

  IF candidates is empty:
    LOG: "Epic {epic_id} retrospective closed with zero new DC candidates — acceptable"
    RETURN

  READ docs/rules/defect-prevention.md → existing_catalog
  next_dc_number = max(existing_catalog.dc_numbers) + 1

  FOR EACH candidate IN candidates:
    # Dedup: skip candidates that overlap an existing DC by name similarity
    IF candidate is substantially covered by an existing DC:
      ADD comment to retrospective body: "Candidate merged into DC-{N}"
      CONTINUE

    # Materialise the entry
    APPEND to docs/rules/defect-prevention.md § The Defect Prevention Catalog (table):
      | DC-{next_dc_number} | {name} | {applicable_when} | {applicable_to} | {severity} | {check} |
    APPEND to § Project Discoveries section:
      ### DC-{next_dc_number} — {name}
      {full body: evidence link, when discovered, epic retrospective reference, worked example}

    next_dc_number += 1

  # Governance bump — see Generation Standards §7
  UPDATE docs/project_log/governance_versions.json → defect-prevention.md entry:
    version: bump minor (e.g. 2.0.0 → 2.1.0)
    changelog.append: "{YYYY-MM-DD}: EPIC-{N} retrospective added {count} DC entries ({dc_numbers})"

  # Worklog
  APPEND_TO_WORKLOG: {phase: "RETROSPECTIVE", action: "writeback", added_dcs: [...]}

  # Now the gate issue can move to Done
  ADAPTER.move_to_column(retrospective_issue, column="Done")
```

**Invariants:**

1. **The gate does NOT close without running the write-back.** Moving the RETROSPECTIVE issue to Done manually (without invoking the write-back procedure) is a governance violation, because the "zero candidates" branch is still a valid and explicit decision — it must be logged, not implied.
2. **Zero candidates is a valid outcome.** An epic that produced no novel patterns closes the gate cleanly with a narrative-only issue body and the explicit "no new DC candidates" log line.
3. **Write-back is additive and tool-agnostic.** It only appends to `docs/rules/defect-prevention.md` and bumps `governance_versions.json`. It does NOT touch per-feature artefacts, does NOT invoke any tool-adapter operation beyond `read_issue` + `move_to_column`, and does NOT trigger cascade invalidation (cataloging a new pattern is forward-only — it does not retroactively invalidate past work).
4. **Discovery Protocol alignment.** Write-back is the canonical execution of the Discovery Protocol documented in `docs/rules/defect-prevention.md` § 8. Agents that discover novel patterns during development (IMPLEMENT --fix, BVL failure, preventive sweep finding a pattern not in the catalog) SHOULD still add them immediately, not wait for the retrospective — but they MUST also mirror the addition into the current epic's retrospective issue body so the closing write-back is idempotent.

---

## 4. LABEL AND MILESTONE SCHEMA

> **Tool-agnostic schema.** These are the canonical label and milestone taxonomies. The tool-adapter maps them to each tool's native representation: GitHub labels/milestones, Jira labels/components/fix-versions, Linear labels/cycles, or rows in `docs/backlog/state.md` (local mode).

### 4.1 Label Taxonomy

| Category | Pattern | Source | Example |
| --- | --- | --- | --- |
| **Phase** | `phase:{label}` | `feature_phases[N].label` — auto-created at `--init-board` from the expanded preset | `phase:codesign`, `phase:implement`, `phase:integration-test`, `phase:retrospective` |
| **Slice** | `slice:EPIC-{N}.{M}` | Computed by `--plan-execution` from the epic/slice graph | `slice:EPIC-1.1`, `slice:EPIC-1.2` |
| **Cluster** | `cluster:{id}` | Set manually on grouped hotfix issues | `cluster:CLUSTER-001` |
| **Milestone strategy** | See § 4.2 | `milestone_strategy` from Q27.3 | — |
| **Status** | `blocked`, `enhancement`, `bug`, `needs-rework-after-codesign` | Auto-created at `--init-board`; `needs-rework-after-codesign` applied manually when a downstream task lands before the upstream CODESIGN is finalized | — |

**Which labels apply to which issue class:**

| Issue class | `phase:*` | `slice:*` | Status label |
| --- | --- | --- | --- |
| Feature phase | ✅ (one) | ✅ (one) | ➕ optional |
| Feature refinement/extension | ✅ (same as parent) | ✅ (same as parent) | `enhancement` |
| Slice integration-test | `phase:integration-test` | ✅ (one) | ➕ optional |
| Epic retrospective | `phase:retrospective` | ❌ (epic-scoped, not slice) | ➕ optional |
| Infrastructure | `infra` | ❌ | ➕ optional |
| Test data | `test-data` | ❌ | ➕ optional |
| Cluster fix | `cluster:{id}` + phase of affected work | ➕ optional | `bug` |

### 4.2 Milestone Schema

Milestone naming follows `milestone_strategy` from Q27.3:

| Strategy | Pattern | Example | Grouping Semantics |
| --- | --- | --- | --- |
| `phase-based` (product roadmap phases) | `Phase {K}: {name}` | `Phase 1: MVP`, `Phase 2: Scale` | User-defined product roadmap milestones; features are assigned manually or by epic→phase mapping |
| `sprint-based` | `Sprint {K}` | `Sprint 1`, `Sprint 2` | Fixed-cadence time boxes |
| `epic-based` | `EPIC-{N}: {Name}` | `EPIC-1: Foundation — Auth + Org` | Automatically computed from `--plan-execution` epic graph; all issues in epic `{N}` (features + gates + retrospective) share this milestone |
| `none` | — | — | No milestone grouping |

**Cross-cutting milestone** (any strategy): for issues that do not belong to any epic/phase/sprint (infra, test data, standalone fixes), use the reserved pattern `CROSS-CUTTING: {Category}` — e.g. `CROSS-CUTTING: Infra + Governance + Tech-Debt`.

> **Discovery gap.** Q27.3 in `Factory-setup-discovery.instructions.md` currently offers only `phase-based | sprint-based | none`. The `epic-based` option is used by the slice/epic gate model and SHOULD be added as a fourth option in a subsequent EVOL-014 slice (together with the `full-sdlc` preset upgrade to 8 phases).

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

### Body File Template — Gate Issue (CONTRACT-FREEZE / PREVENTIVE-SWEEP / SMOKE-E2E / INTEGRATION-TEST / RETROSPECTIVE)

> **Gate issues are not phase commands.** They represent validation work that must be completed before a downstream command may run. The body template below makes that explicit via a `Gate type` line and a `Blocks` line — the BACKLOG `--next-task` resolver looks for these two lines when deciding whether to return a gate issue as "next task to complete" vs treating it as a runtime blocker against a different command.

```markdown
## Gate type

{contract-freeze | preventive-sweep | smoke-e2e | integration-test | retrospective}

## Blocks

{name of the downstream Factory command that cannot run until this gate closes}

Examples:
- contract-freeze → blocks `IMPLEMENT --plan {ID}`
- preventive-sweep → blocks `DEVOPS --deploy --env dev {ID}`
- smoke-e2e → blocks `QA --verify {ID}` auto-approval
- integration-test → blocks first `CODESIGN --start` of next slice in the epic
- retrospective → blocks first `CODESIGN --start` of the next epic

## What this gate validates

{One paragraph explaining what evidence must exist for the gate to close, in plain business terms.}

## Definition of Done

Gate-specific checklist — every item must be `[x]` before moving the issue to Done:

- [ ] {Artifact produced at expected path with expected frontmatter status (e.g., `docs/spec/{ID}/preventive_sweep_report.md` — status: APPROVED)}
- [ ] {Validation check 1 specific to this gate type}
- [ ] {Validation check 2}
- [ ] Zero open `stale-after-cascade` / `stale-after-slice-peer-iterated` labels on this issue (iteration-model cascade invariant)

## Resolution command

> Gate issues do NOT have a direct Factory slash-command to run. The work is performed via the tool, the skill, or the user action listed here. When complete, move the issue to Done via `BACKLOG --update-execution {step_ref}` or the equivalent tracker UI action.

{Literal instructions: "Run Factory-preventive-sweep skill against FEATURE_ID", "Execute the numbered smoke blocks on dev deploy", "Produce OpenAPI + contract harness", "Run retrospective write-back procedure (Factory-backlog-operations.instructions.md § 3.4.1)".}

## Cascade behaviour

When the iteration-model cascade reopens this gate (applying the `stale-after-cascade` label), the artifact the gate produced is marked `status: INVALIDATED` and the gate's DoD checklist must be re-validated in full — partial delta updates are NOT supported for gate artefacts.
```

> **How `--next-task` resolves a gate issue.** The resolver parses the issue body looking for the `## Gate type` and `## Blocks` lines. If a candidate command matches a `Blocks` target and the matching gate issue is not Done (or carries a `stale-after-*` label), the resolver returns the gate issue itself with `why_now = "gate blocks {candidate.command}"`. The resolver surfaces the `Resolution command` field as the concrete next action for the user, instead of a Factory slash-command (which gates intentionally lack).

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

**Bootstrap operations** (called by `--init-board`):
| Operation | Required | Description |
| --- | --- | --- |
| `create_project` | ✅ | Create a new project/board and return its identifiers |
| `configure_board` | ✅ | Set up board columns from `board_columns` (Q27.1) |
| `create_label` | ✅ | Create a label with name and (optional) color. Used to materialize the full label taxonomy (§ 4.1) at init time |
| `create_milestone` | ⚠️ optional | Create a milestone/fix-version/cycle with a name. Skipped when `milestone_strategy == "none"` or when the tool has no native milestone concept |

**Issue lifecycle operations** (called by `--plan-feature`, `--create-issue`, `--update-execution`, and by cascade invalidation):
| Operation | Required | Description |
| --- | --- | --- |
| `create_issue` | ✅ | Create an issue with title, body, labels, milestone, assignee |
| `add_to_board` | ✅ | Add an issue to the project board |
| `move_to_column` | ✅ | Move an issue to a specific board column |
| `close_issue` | ✅ | Close or delete an issue (used for rollback). Accepts issue number/ID |
| `add_label` | ✅ | Apply an existing label to an existing issue (e.g., `stale-after-cascade`, `stale-after-slice-peer-iterated`). Used by [Factory-iteration-model/SKILL.md](Factory-iteration-model/SKILL.md) § CASCADE_PENDING_ITERATION to mark gate issues as stale after an upstream cascade reopens them. Distinct from `create_label` (which creates the label definition at `--init-board`). Tools MUST either implement this natively or provide a composed fallback (e.g., fetching the existing labels, appending, and issuing a full update) |
| `add_sub_issue` | ⚠️ optional | Nest a child issue under a parent issue. Used when a preset declares sub-issue nesting (e.g. gate phases nested under IMPLEMENT). Tools without native sub-issue support SHOULD implement a fallback (e.g. Jira sub-tasks, Linear parent-child, or a prominent cross-link in the body) — or declare the operation as a no-op, in which case the gates become standalone siblings |

**Query and verification operations** (called by `--next-task`, `--status`, Final Verification Gate § 6.4):
| Operation | Required | Description |
| --- | --- | --- |
| `query_board` | ✅ | Query all items with their status, labels, milestone, and (if supported) sub-issue parent |
| `get_item_id` | ✅ | Get the board item ID for an issue |
| `read_issue` | ✅ | Read a single issue's title, body, labels, milestone, and state |
| `verify_issue` | ✅ | Verify an issue exists with expected title, labels, and status. Returns issue metadata for comparison |
| `verify_board_placement` | ✅ | Verify an issue is on the project board in the expected column. Returns current column/status |

> **Tech-Agnostic Invariant:** ALL operations above — including verification, rollback, and optional nesting — are **abstract**. The tool-adapter materializes them with tool-specific CLI/MCP commands during `SETUP --generate`. The BACKLOG agent NEVER hardcodes tool-specific commands; it ALWAYS delegates to the tool-adapter. For **required** operations, if a tool does not support them natively, the tool-adapter MUST define a composed multi-step workaround. For **optional** operations, the tool-adapter MAY declare them as no-ops — the BACKLOG agent then falls back to the documented alternative (e.g. standalone sibling gates instead of sub-issues).

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
⚠️ The {tool_name} command failed.

**Command:** `{failed_command}`
**Error:** {error_category} — {one_line_explanation}

**To resolve:**
1. {step_1}
2. {step_2}
...

Once you have resolved it, confirm and I will retry the command.
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
