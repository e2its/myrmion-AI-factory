---
description: "Factory BACKLOG operations — issue naming, body templates, board management, project configuration. Use when: BACKLOG --init-board, --plan-feature, --create-issue, --move, --status execution."
applicable_when:
  phase: [BACKLOG]
  command: [backlog]
---

# Backlog Manager — Operations Reference

> Loaded contextually by the `backlog` agent. Contains all operational protocols, conventions, and templates for issue management.

---

## 0. SINGLE SOURCE OF TRUTH (SSOT)

> **Invariant:** There MUST be exactly ONE source of truth for backlog state. The operating mode is the derived adapter `project_tracking.adapter` (`config/quality.json → tracker.adapter`; github | jira | none — EVOL-079).

| Mode | Condition | Source of Truth | Local Artifacts |
| --- | --- | --- | --- |
| **External** | `adapter != none` | The configured external tool (GitHub Projects or Jira) | Only `docs/backlog/project-config.json` (connection params) |
| **Local** | `adapter == none` | Local files | `docs/backlog/state.md` + `docs/backlog/issue-bodies/*.md` |

**The board moves through one command (EVOL-079).** Every lifecycle write — create, place, move, close, nest — is `python3 scripts/gate.py tracker` on every adapter; the agent reads through the adapter's read ops and never moves an item by hand. Columns are never literals: `config/quality.json → tracker.flow` names the board column for backlog, ready, in progress, done.

**External mode:** Do NOT create or update `state.md` or `issue-bodies/`. The issue body reaches the tool through `gate.py tracker --ensure`: the row's `body` is a scratch `.md` file the gate reads and never keeps (§ 5). The external tool is the canonical record.

**Local mode:** Do NOT create `project-config.json`. All issue state lives in `state.md`. Body content persisted in `issue-bodies/`. No API calls to external tools.

---

## 1. SETUP-DRIVEN CONFIGURATION

All constants are derived from SETUP --init decisions in `docs/setup.md`. This section describes the **field mappings**.

```yaml
# Read from governance snapshot (## Setup Configuration) or fallback to docs/setup.md
project_tracking:
  tool: "{{project_tracking_tool}}"           # Q27: free text — GitHub Projects | Jira | None (any other name → adapter none + WARN)
  adapter: "{{adapter}}"                       # derived from Q27: github | jira | none (EVOL-079)
  board_columns: ["{{col}}", …]                # Q27.1: Kanban columns — default [Backlog, Ready, In Progress, Done]
  flow: ["{{backlog}}", "{{ready}}", "{{in_progress}}", "{{done}}"]   # Q27.7 → config/quality.json → tracker.flow
  feature_phases: "{{preset_string}}"          # Q27.2: Preset string — "full-sdlc" | "simplified" | "single"
                                               # BACKLOG expands preset into phase objects at runtime (see § 1.1)
  milestone_strategy: "{{milestone_strategy}}" # Q27.3: epic-based | phase-based | sprint-based | none
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
# mode field (Q27.5): overrides project_tracking.gate_enforcement_mode per gate issue
# when present in the issue body frontmatter. When absent, the resolver uses the adapter-level
# default. Only gate phases carry a mode field — non-gate phases (codesign/blueprint/devops/
# implement/qa) are always hard by their command's own approval logic.
- { suffix: 1, label: "codesign",         title_pattern: "[{ID}] CODESIGN: Spec BDD + UX Mock — {name}" }
- { suffix: 2, label: "blueprint",        title_pattern: "[{ID}] BLUEPRINT: Architecture + Test Plan — {name}" }
- { suffix: 3, label: "contract-freeze",  title_pattern: "[{ID}] CONTRACT-FREEZE: API contracts + test harness — {name}", gate: true, sub_issue_of: 5, mode_default: "{{GATE_ENFORCEMENT_MODE}}" }
- { suffix: 4, label: "devops",           title_pattern: "[{ID}] DEVOPS: Infrastructure — {name}" }
- { suffix: 5, label: "implement",        title_pattern: "[{ID}] IMPLEMENT: Code + Tests — {name}" }
- { suffix: 6, label: "preventive-sweep", title_pattern: "[{ID}] PREVENTIVE-SWEEP: Runtime defect scan — {name}",           gate: true, sub_issue_of: 5, mode_default: "{{GATE_ENFORCEMENT_MODE}}" }
- { suffix: 7, label: "qa",               title_pattern: "[{ID}] QA: Verification — {name}" }
# suffix 8 is SCOPE-AWARE — BACKLOG --plan-feature picks ONE variant based on spec.feature.scope:
- { suffix: 8, label: "smoke-e2e-browser",     title_pattern: "[{ID}] SMOKE-E2E (Browser): User-journey scenarios on the pre-production deploy — {name}",         gate: true, sub_issue_of: 5, mode_default: "{{GATE_ENFORCEMENT_MODE}}", applicable_when: "feature.scope == 'frontend-only'" }
- { suffix: 8, label: "smoke-e2e-integration", title_pattern: "[{ID}] SMOKE-E2E (Integration): Caller-harness + state + observability — {name}",  gate: true, sub_issue_of: 5, mode_default: "{{GATE_ENFORCEMENT_MODE}}", applicable_when: "feature.scope in [backend-only, integration]" }
- { suffix: 8, label: "smoke-e2e-hybrid",      title_pattern: "[{ID}] SMOKE-E2E (Hybrid): Browser + API smoke on the pre-production deploy — {name}",             gate: true, sub_issue_of: 5, mode_default: "{{GATE_ENFORCEMENT_MODE}}", applicable_when: "feature.scope == 'full-stack'" }
# Legacy unscoped label — not emitted by new --plan-feature, but accepted by QA --verify Gate 4 for backward compatibility with projects materialised before the scope-aware variants:
# - { suffix: 8, label: "smoke-e2e", ... } [DEPRECATED — kept only for legacy project recognition]
```

**Scope-aware smoke-e2e selection.** `BACKLOG --plan-feature {ID}` reads `docs/spec/{ID}/spec.feature` frontmatter `scope` field and materialises EXACTLY ONE suffix-8 variant based on the scope → label mapping:

| feature.scope | Phase label emitted | Smoke template (single — EVOL-041) |
|---|---|---|
| `frontend-only` | `phase:smoke-e2e-browser` | `.context/templates/qa/smoke_e2e_report_template.md` — browser mode |
| `backend-only`  | `phase:smoke-e2e-integration` | same template — caller-harness + state + observability mode |
| `integration`   | `phase:smoke-e2e-integration` | same template — caller-harness mode with MANDATORY SMOKE-REL-* reliability blocks |
| `full-stack`    | `phase:smoke-e2e-hybrid` | same template — hybrid (browser + backend surface) |
| (missing / legacy) | `phase:smoke-e2e` (legacy) | same template — default browser mode |

Only ONE suffix-8 issue is created per feature. If `spec.feature.scope` is missing or unreadable, `BACKLOG --plan-feature` falls back to the legacy `phase:smoke-e2e` label with a WARN and a suggestion to add `scope:` to spec.feature for scope-aware future runs.

**Gate semantics.** Phases marked `gate: true` are **hard blockers** enforced by upstream command instructions. Each gate issue must be Done before the downstream phase may start:

| Gate phase | Between | Enforced by | Blocks |
| --- | --- | --- | --- |
| CONTRACT-FREEZE (suffix 3) | BLUEPRINT → IMPLEMENT | [Factory-implement-plan.instructions.md](Factory-implement-plan.instructions.md) § Upstream Artifact Validation | `IMPLEMENT --plan` start — the feature's API contracts (OpenAPI / TS interfaces / GraphQL schema / whatever the stack uses) MUST be frozen and the contract test harness MUST exist (stack-specific, resolved from discovery answers). Kills contract drift between design and code. |
| PREVENTIVE-SWEEP (suffix 6) | IMPLEMENT → DEVOPS `--deploy --env {preproduction}` | [Factory-devops-provision-deploy.instructions.md](Factory-devops-provision-deploy.instructions.md) § Pre-Deploy Checklist | `DEVOPS --deploy --env {preproduction}` (`delivery.preproduction`, EVOL-106) — the factory-preventive-sweep SKILL must have run against the feature's code (parallel scope sub-agents derived from DC catalog) and returned zero open C-severity findings. Catches the class of defects invisible to static gates (unused imports, missing null checks, broken teardown, env-var drift). |
| SMOKE-E2E (suffix 8 — scope-aware variants: `smoke-e2e-browser` / `smoke-e2e-integration` / `smoke-e2e-hybrid`) | DEVOPS `--deploy --env {preproduction}` → QA `--verify` pass | [Factory-qa-verify.instructions.md](Factory-qa-verify.instructions.md) § Verify Preconditions | `QA --verify` pass — scope-appropriate smoke blocks must pass on the pre-production deploy. The cadence is the project's answer (`docs/setup.md → qa.smoke_cadence`, EVOL-077): this issue closes at feature close; with `per-slice` each increment closes on its own report (`smoke_e2e_report_{INC}.md`), never on a board issue. A walked case with no automated test is red (`gate.py traceability`). One SMOKE-{N} block per `user_journey.md § 3` Path (expanded Paso → BDD Scenario → test_plan TC). Frontend-only → browser mode. Backend-only/integration → caller-harness + downstream-state + observability mode, plus MANDATORY reliability blocks (SMOKE-REL-*, test_plan § 2.2 / design.md § Reliability Contract) for `integration`. Full-stack → hybrid. Replaces ad-hoc smoke with a reproducible DoD artefact. |

**Sub-issue nesting.** The three gate phases (phase labels: `phase:contract-freeze`, `phase:preventive-sweep`, `phase:smoke-e2e-*`) are logically **sub-issues of IMPLEMENT** (suffix 5). Their `--ensure` rows name `parent: "[{ID}] IMPLEMENT:"` and the gate nests them on every adapter (GitHub sub-issues, Jira sub-tasks, the `Parent` column of `state.md`) — the board reflects feature completion and `--next-task` reads the parent from the board.

**Sub-increment items (EVOL-045).** When `increment_plan.md § 1` declares sub-increments for an increment, each sub-increment is a backlog sub-item of the increment's IMPLEMENT issue — title `[{ID}] INC-{N} / SUB-{N}-{M}: {scope}`, created under it by `gate.py tracker --ensure --sub-increments {ID}` on every adapter. One PR per sub-item into the train.

**Iteration of the preset.** The 8-phase expansion was introduced (derived from the production experience of the first materialised product after months of real use: contract drift killed six features, fifteen runtime defects slipped past static gates into dev, and unstructured smoke testing produced inconsistent Done criteria). Projects materialised before EVOL-014 with the legacy 5-phase expansion keep their existing issue sets — gate issues are backfilled manually by `--plan-feature {ID}` when run on a legacy feature.

---

## 2. RUNTIME CONSTANTS (External mode only — post --init-board)

> **SSOT:** This section applies ONLY in external mode (`project_tracking.adapter != none`). In local mode, no external connection config is needed.

> **🔒 SECURITY INVARIANT — ZERO CREDENTIALS:** `project-config.json` MUST NEVER contain credentials, API tokens, passwords, or secrets. GitHub authenticates through `gh auth login`; Jira through the token the vault exports as `JIRA_API_TOKEN` (+ `JIRA_USER_EMAIL` on Cloud) — `project_tracking.token` names the vault entry, never the value. Only non-sensitive identifiers (project IDs, repo slugs, site, project key, board id) are persisted.

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

- `tool` — The exact tool name from SETUP Q27 (`"GitHub Projects"` or `"Jira"`)
- `integration` — **Enum: `"cli"` or `"mcp"`**. How the agent READS the tool (Jira: Q27.8 `project_tracking.transport`). Writes go through `gate.py tracker` either way.
- `cli_command` — The CLI binary name (`"gh"`, `"jira"`). **Only when `integration == "cli"`**; `null` when `integration == "mcp"`.
- `project_ids` — Non-sensitive identifiers populated by `--init-board`, read by `gate.py tracker`: GitHub `owner`, `repo`, `project_number` (`project_node_id` when known); Jira `site`, `project_key`, `board_id`. **No secrets.**
- `board_field_mapping` — optional; the gate resolves the Status field, its options and the Jira transitions by name at each run and stores no id.

The exact fields inside `project_ids` and `board_field_mapping` are determined by the **tool-adapter** (`docs/backlog/tool-adapter.md`) materialized during `SETUP --generate`.

---

## 3. ISSUE NAMING CONVENTIONS

> **Tool-agnostic schema.** The patterns below are the canonical title schema for all issues generated by the BACKLOG agent. The tool-adapter renders them into the target tool's native representation (GitHub Issue title, Jira summary, `state.md` row) without changing the pattern itself.

### 3.0 Title Schema Reference

| Issue Class | Title Pattern | Variables |
| --- | --- | --- |
| Feature phase | `[{ID}] {PHASE}: {phase_description} — {name}` | `{ID}` from naming_convention; `{PHASE}` from `feature_phases[N].label` uppercased; `{phase_description}` from `feature_phases[N].title_pattern`; `{name}` user-provided |
| Feature refinement | `[{ID}] {PHASE}-R{k}: Refinement — {description}` | `{k}` sequential refinement index starting at 1 |
| Feature extension | `[{ID}] {PHASE}-R{k}: Extension — {description}` | Same as refinement |
| Catalog component | `[{ID}] COMPONENT: {component_name}` | `{ID}` = the foundational Component Catalog feature (`docs/ux/component-registry.json` `catalog_feature`); `{component_name}` = registry `name`. First round only — later components use the Feature extension pattern on the IMPLEMENT phase |
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
| `[EPIC-{N}] RETROSPECTIVE` | **No new file.** The gate's deliverable is 0+ new or updated entries in `.claude/rules/defect-prevention.md` (the living defect catalog, consulted by DEV pre-write check and REVIEW Check #2d). If the epic revealed no new patterns, the count is zero and the gate still closes. | Issue body is the retrospective narrative itself (what happened, what was learned, links to any DC entries added). The issue body + its closure timestamp on the tracker serve as the historical record — no separate `lessons_learned.md` file is created. |

> **Why no `lessons_learned.md` per epic.** The framework deliberately keeps a single source of truth for "what we learned": the living catalog at `.claude/rules/defect-prevention.md`. A separate per-epic markdown would duplicate narrative that nobody re-reads, while fragmenting the actionable DC entries across files. Narrative history lives on the tracker (issue body + closure date); actionable prevention lives in the rule file.

#### 3.4.1 Retrospective → Defect Prevention Catalog write-back procedure

Closing an `[EPIC-{N}] RETROSPECTIVE` gate issue is NOT a single "move to Done" operation. It is a structured two-step write:

**Step 1 — Narrative (issue body).** The BACKLOG agent, assisted by the user, populates the RETROSPECTIVE issue body with:

1. **What happened** — one paragraph per slice in the epic describing what shipped, what slipped, what surprised.
2. **What was learned** — bullet list of novel runtime / governance / architectural patterns observed during the epic that the existing Defect Prevention Catalog did NOT already cover.
3. **Candidate DC entries** — for each learning that meets the Discovery Protocol threshold (runtime-observable, reproducible, preventable by a concrete check), draft a new DC entry inline in the issue body using this block:

   ```markdown
   ### Candidate DC

   - **Name:** {short title}
   - **Family:** {one id from defect-prevention.md § Families}
   - **Invariant:** {one line, ≤ budgets.dc_invariant_max_chars}
   - **Gate:** {mechanical check that proves it, or —}
   - **Paths:** {globs the DC governs, or *}
   - **Applicable To:** [{enum list from CODESIGN | BLUEPRINT | IMPLEMENT | REVIEW | DEVOPS | QA | AUDIT}]
   - **Severity:** {BLOCKER | WARNING}
   - **Origin / Story / Detection:** {the narrative — lands in defect-prevention-cases.md}
   - **Evidence:** {link to the feature / commit / issue where this pattern surfaced}
   ```

4. **Non-catalog learnings** — observations that are NOT DC-worthy (team dynamics, scheduling issues, dependency choices) stay in the narrative section only. They do not become rule entries.

**Step 2 — Write-back to `.claude/rules/defect-prevention.md`.** For each `### Candidate DC` block in the issue body:

```yaml
FUNCTION retrospective_writeback(retrospective_issue, epic_id):
  # This is the canonical mechanism that closes the producer side of the DC loop.
  # Without it, the narrative in the issue body is dead prose and the catalog never grows.

  body = ADAPTER.read_issue(retrospective_issue) → .body
  candidates = parse_candidate_dc_blocks(body)

  IF candidates is empty:
    LOG: "Epic {epic_id} retrospective closed with zero new DC candidates — acceptable"
    RETURN

  READ .claude/rules/defect-prevention.md → existing_catalog
  next_pdc = max(existing_catalog PDC-NN numbers, default 0) + 1    # the project's own namespace (Discovery Protocol); DC-NN is the framework's

  FOR EACH candidate IN candidates:
    # Dedup: skip candidates that overlap an existing DC by name similarity
    IF candidate is substantially covered by an existing DC:
      ADD comment to retrospective body: "Candidate merged into {id}"
      CONTINUE

    # Materialise the entry
    APPEND to .claude/rules/defect-prevention.md § Defect Classes (table, 7 columns):
      | PDC-{next_pdc} | `{family}` | {invariant} | {gate} | {paths} | {applicable_to} | {severity} |
    APPEND to .claude/rules/defect-prevention-cases.md:
      ### PDC-{next_pdc} — {name}
      **Origin:** {evidence link, when discovered, epic retrospective reference}
      **Story:** {story}
      **Detection:** {detection, worked example}

    next_pdc += 1

  # Governance bump — the canonical framework rule is enforced by the governance-check CI
  # workflow (.github/workflows/governance-check.yml). Every change to a tracked rule file
  # MUST bump its entry in governance_versions.json — python3 scripts/gate.py manifest --bump --entry <path> --level … (EVOL-061; state only, EVOL-118).
  UPDATE docs/project_log/governance_versions.json → defect-prevention.md entry:
    version: bump minor (e.g. 2.0.0 → 2.1.0)
  # the why — "EPIC-{N} retrospective added {count} DC entries ({dc_ids})" — goes in the commit message

  # Worklog
  APPEND_TO_WORKLOG: {phase: "RETROSPECTIVE", action: "writeback", added_dcs: [...]}

  # Now the gate issue can move to Done — the flow's done column, through the one mover
  RUN python3 scripts/gate.py tracker --move "[EPIC-{N}] RETROSPECTIVE:" --to done
```

**Invariants:**

1. **The gate does NOT close without running the write-back.** Moving the RETROSPECTIVE issue to Done manually (without invoking the write-back procedure) is a governance violation, because the "zero candidates" branch is still a valid and explicit decision — it must be logged, not implied.
2. **Zero candidates is a valid outcome.** An epic that produced no novel patterns closes the gate cleanly with a narrative-only issue body and the explicit "no new DC candidates" log line.
3. **Write-back is additive and tool-agnostic.** It only appends to `.claude/rules/defect-prevention.md` and bumps `governance_versions.json`. It does NOT touch per-feature artefacts, does NOT touch the board beyond `read_issue` + one `gate.py tracker --move … --to done`, and does NOT trigger cascade invalidation (cataloging a new pattern is forward-only — it does not retroactively invalidate past work).
4. **Discovery Protocol alignment.** Write-back is the canonical execution of the Discovery Protocol documented in `.claude/rules/defect-prevention.md` § Discovery Protocol; a class worth every project is proposed upstream (§ Promotion). Agents that discover novel patterns during development (IMPLEMENT --fix, BVL failure, preventive sweep finding a pattern not in the catalog) SHOULD still add them immediately, not wait for the retrospective — but they MUST also mirror the addition into the current epic's retrospective issue body so the closing write-back is idempotent.

---

## 4. LABEL AND MILESTONE SCHEMA

> **Tool-agnostic schema.** These are the canonical label and milestone taxonomies. The tool-adapter maps them to each tool's native representation: GitHub labels/milestones, Jira labels/fix-versions, or rows in `docs/backlog/state.md` (local mode).

### 4.1 Label Taxonomy

| Category | Pattern | Source | Example |
| --- | --- | --- | --- |
| **Phase** | `phase:{label}` | `feature_phases[N].label` — auto-created at `--init-board` from the expanded preset. Scope-aware variants for suffix 8: `phase:smoke-e2e-browser`, `phase:smoke-e2e-integration`, `phase:smoke-e2e-hybrid` — exactly ONE variant materialised per feature, selected by `spec.feature.scope`. | `phase:codesign`, `phase:implement`, `phase:integration-test`, `phase:retrospective`, `phase:smoke-e2e-browser` |
| **Scope** | `scope:{value}` | Applied at `--plan-feature {ID}` time based on `spec.feature.scope` frontmatter. Exactly ONE scope label per feature, applied uniformly to ALL phase issues of that feature (not per-phase). Enables scope-based board filtering, cross-scope metrics, and `--eligible` pool filtering when a user wants to work only within one scope (e.g. `--eligible --filter=scope:backend-only`). When `spec.feature.scope` is missing or unreadable (legacy features), the label is NOT applied — legacy features continue without scope classification. | `scope:full-stack`, `scope:backend-only`, `scope:frontend-only`, `scope:integration` |
| **Slice** | `slice:EPIC-{N}.{M}` | Computed by `--plan-execution` from the epic/slice graph | `slice:EPIC-1.1`, `slice:EPIC-1.2` |
| **Cluster** | `cluster:{id}` | Set manually on grouped hotfix issues | `cluster:CLUSTER-001` |
| **Milestone strategy** | See § 4.2 | `milestone_strategy` from Q27.3 | — |
| **Status** | `blocked`, `enhancement`, `bug`, `needs-rework-after-codesign` | Auto-created at `--init-board`; `needs-rework-after-codesign` applied manually when a downstream task lands before the upstream CODESIGN is finalized | — |
| **Kind** | `kind:follow-up` | Set manually on issues that capture deferred work spun out from a parent feature or retrospective. Signals "known deferred, not accidental incomplete". | `kind:follow-up` |
| **Kind** | `kind:component-catalog` | Applied by the `factory-po-intake` catalog beat to every issue that builds a design-system component with no code primitive yet. NOT pre-created at `--init-board`: `create_label` (idempotent) before the first `add_label`, same rule as `blocked-by`. | `kind:component-catalog` |
| **Blocked-by** | `blocked-by:#{N}` | Set manually (or by `--plan-execution` when an explicit cross-feature dependency is declared) on issues that MUST NOT be picked up until the referenced issue is Done. Consumed by the `--next-task` resolver as a hard filter. Multiple `blocked-by:#N` labels on the same issue are AND-ed: all referenced issues must be Done. | `blocked-by:#42`, `blocked-by:#101` |
| **Appetite** *(conditional on Q27.6 == true)* | `appetite:{small\|medium\|big}` | Hand-curated by the human on feature issues. Metadata only — never computed. When Q27.6 == false the labels are not materialised. | `appetite:small`, `appetite:medium`, `appetite:big` |

**Which labels apply to which issue class:**

| Issue class | `phase:*` | `scope:*` | `slice:*` | Status label | `kind:follow-up` | `blocked-by:#N` | `appetite:*` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Feature phase | ✅ (one) | ✅ (one — mirrors spec.feature.scope) | ✅ (one) | ➕ optional | ➕ optional | ➕ optional | ➕ optional (feature-scoped; typically on CODESIGN issue) |
| Feature refinement/extension | ✅ (same as parent) | ✅ (same as parent — scope inherited) | ✅ (same as parent) | `enhancement` | ➕ optional | ➕ optional | ❌ (inherits from parent) |
| Catalog component | `phase:implement` | `scope:frontend-only` | ➕ optional | `kind:component-catalog` | ❌ | ➕ optional | ❌ |
| Slice integration-test | `phase:integration-test` | ❌ (slice can span multiple scopes) | ✅ (one) | ➕ optional | ❌ | ➕ optional | ❌ |
| Epic retrospective | `phase:retrospective` | ❌ (epic spans scopes) | ❌ (epic-scoped, not slice) | ➕ optional | ❌ | ➕ optional | ❌ |
| Infrastructure | `infra` | ➕ optional (when infra is scope-specific: `scope:backend-only` for worker provisioning, `scope:frontend-only` for CDN config) | ❌ | ➕ optional | ➕ optional | ➕ optional | ➕ optional |
| Test data | `test-data` | ➕ optional (seed fixtures can be scope-flavoured) | ❌ | ➕ optional | ➕ optional | ➕ optional | ❌ |
| Cluster fix | `cluster:{id}` + phase of affected work | ➕ optional (inherit from affected feature) | ➕ optional | `bug` | ➕ optional | ➕ optional | ❌ |

> **Appetite label materialisation.** The three `appetite:*` labels are created at `--init-board` via `create_label` ONLY when `project_tracking.appetite_sizing_enabled == true` (Q27.6). The adapter `## Appetite` section rendered by SETUP materialisation (Factory-setup-materialization.instructions.md § Step 6.2.1) documents this. When Q27.6 == false, omit the labels entirely — do not create them with zero usage.
>
> **Blocked-by label creation.** The `blocked-by:#{N}` label is NOT pre-created at `--init-board` because the value `#{N}` is per-issue. **`add_label` does NOT auto-create missing labels** — on GitHub, `gh issue edit --add-label` and `gh issue create --label` reject unknown labels (Jira creates a label on first use). The BACKLOG agent (or any automation wrapping it) MUST explicitly call `create_label` for `blocked-by:#{N}` **before** the first `add_label` invocation with that value. `create_label` is idempotent on every supported adapter (GitHub via `gh label create … --force`; other tools via their native upsert). Once created, the label persists for reuse on later issues.
>
> **`kind:follow-up` vs `enhancement`.** `enhancement` flags that an issue is an incremental addition to an already-delivered feature. `kind:follow-up` flags that an issue was intentionally spun out of a larger scope to defer the work (typical source: RETROSPECTIVE gate splitting an oversized bucket, or a scope-carve-out during CODESIGN). An issue can carry both labels simultaneously.

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

> **SSOT:** Body files are ONLY kept in **local mode** (`project_tracking.adapter == none`). In external mode the body is written to a scratch file the gate reads (`--ensure` row `body`) and is never kept — the external tool holds the canonical body. A body outside `issue-bodies/` is copied there as `L-NNN.md`; one already there is pointed at.

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
{codesign issues, when `docs/setup.md` `codesign.authoring: external`: replace the line above with — "Authored by the PO in the Product Owner package (`subproducts/po-package/RUNBOOK.md`). Enters the repo with `/codesign --sync {ID}`."}

## Prerequisites

- {List prior issues that must be complete}

## Definition of Done

- [ ] {Artifact 1 with path}
- [ ] {Artifact 2 with path}
- [ ] {Validation criteria}

{Render the next section ONLY when `project_tracking.appetite_sizing_enabled == true` (Q27.6). Feature-scoped — typically filled on the CODESIGN phase issue. Refinement / extension / gate issues inherit from the parent feature and do NOT include this section.}

## Appetite

- **Bucket:** {small | medium | big — or blank until decided}
- **Rationale:** {one line: why this bucket — complexity, risk, or scope cap}

> Appetite is a BUDGET, not an estimate. `small` ≤ 4h; `medium` 2–4 days supervised; `big` 5+ days or complex feature. Overruns stop work — re-shape or split.
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

### Body File Template — Catalog Component Issue

```markdown
## What is needed?

Build the code primitive for design-system component **{component_name}** (`{ds_anchor}`).

## Source of truth

- Design: `docs/ux/vision/component_library.html#{id}` — states, variants, tokens
- Registry entry: `docs/ux/component-registry.json` → `{id}` (status `PLANNED` once this issue exists)

## Definition of Done

- [ ] Primitive implemented with every state shown in the library, tokens only
- [ ] Registered in `config/codebase_inventory.json` as `type: ui_component`
- [ ] Registry entry: `cip_name` set, `status: IMPLEMENTED`
```

Parent: the IMPLEMENT issue of the catalog feature (the `--ensure` row's `parent`; the gate nests it on every adapter).

### Body File Template — Gate Issue (CONTRACT-FREEZE / PREVENTIVE-SWEEP / SMOKE-E2E / INTEGRATION-TEST / RETROSPECTIVE)

> **Gate issues are not phase commands.** They represent validation work that must be completed before a downstream command may run. The body template below makes that explicit via a `Gate type` line and a `Blocks` line — the BACKLOG `--next-task` resolver looks for these two lines when deciding whether to return a gate issue as "next task to complete" vs treating it as a runtime blocker against a different command.

```markdown
## Gate type

{contract-freeze | preventive-sweep | smoke-e2e | integration-test | retrospective}

## Mode

{enforce | warn | off}

> Q27.5. Optional per-gate override. When absent, the resolver falls back to
> `project_tracking.gate_enforcement_mode` (adapter-level default). `enforce` = hard
> block; `warn` = log and proceed; `off` = disabled (ADR-documented exception only).

## Blocks

{name of the downstream Factory command that cannot run until this gate closes}

Examples:
- contract-freeze → blocks `IMPLEMENT --plan {ID}`
- preventive-sweep → blocks `DEVOPS --deploy --env {preproduction} {ID}`
- smoke-e2e → blocks `QA --verify {ID}` auto-approval
- integration-test → blocks first `CODESIGN --start` of next slice in the epic
- retrospective → blocks first `CODESIGN --start` of the next epic

## What this gate validates

{One paragraph explaining what evidence must exist for the gate to close, in plain business terms.}

## Definition of Done

Gate-specific checklist — every item must be `[x]` before moving the issue to Done:

- [ ] {Artifact produced at expected path with expected frontmatter status (e.g., `docs/spec/{ID}/review/preventive_sweep_{YYYYMMDD}.md` — status: COMPLETED, not_delivered empty)}
- [ ] {Validation check 1 specific to this gate type}
- [ ] {Validation check 2}
- [ ] Zero open `stale-after-cascade` / `stale-after-slice-peer-iterated` labels on this issue (iteration-model cascade invariant)

### DoD Variants by Gate Type and Scope

For SMOKE-E2E gate issues specifically, the DoD checklist is **scope-aware** — derived from `spec.feature.scope` at `--plan-feature` time:

**phase:smoke-e2e-browser** (scope=frontend-only):
- [ ] `docs/spec/{ID}/smoke_e2e_report.md` exists, status: APPROVED, scope frontmatter matches `frontend-only`
- [ ] Every SMOKE-{N} block (one per `user_journey.md § 3` Path, expanded Paso → BDD Scenario → test_plan TC) executed on the pre-production deploy, all verdicts PASS
- [ ] Zero console errors during smoke execution (captured in evidence logs)
- [ ] Visual-navigation checks pass (app_shell + page_templates + component_library fidelity)
- [ ] Visual cases: with a browser MCP (`qa.browser_mcp`), every `[QA-VIS-{CASE}]` PASS (screenshot, zero console errors, layout against the mock) — run by the `factory-qa` agent on the isolated profile (EVOL-077)
- [ ] WCAG 2.1 AA quick pass on smoked flows (no critical/serious violations)
- [ ] Zero open `stale-after-*` labels on this issue

**phase:smoke-e2e-integration** (scope=backend-only OR integration):
- [ ] `docs/spec/{ID}/smoke_e2e_report.md` exists, status: APPROVED, scope frontmatter matches `backend-only` or `integration`
- [ ] Every SMOKE-{N} block (one per `user_journey.md § 3` Path — caller-persona routes) executed on the pre-production deploy, all verdicts PASS with caller request + downstream state + observability triple-verified
- [ ] Structured logs emitted with mandatory fields (`trace_id`, `correlation_id`, `feature_id`, `idempotency_key`, `error_code`) — grep confirms presence in the pre-production log sink
- [ ] Trace propagation end-to-end: a single `trace_id` spans every hop (caller → our service → downstream systems); verified in trace backend
- [ ] Metrics dashboard green during smoke window (the deploy's `gate.py performance --run --site` verdict green, `error_rate` == 0 on success path)
- [ ] **Scope=integration ONLY** — reliability blocks MANDATORY: SMOKE-REL-IDEMP PASS (idempotency replay), SMOKE-REL-RETRY PASS (exponential backoff + retry_count metric), SMOKE-REL-DLQ PASS (DLQ routes with full context, replay tooling works), SMOKE-REL-SHUTDOWN PASS (graceful SIGTERM drain, exit 0)
- [ ] Zero downstream orphaned state after smoke (no zombie rows, no stuck queue messages, no leaked locks)
- [ ] Zero open `stale-after-*` labels on this issue

**phase:smoke-e2e-hybrid** (scope=full-stack):
- [ ] `docs/spec/{ID}/smoke_e2e_report.md` exists, status: APPROVED, scope frontmatter matches `full-stack`
- [ ] Browser-side smoke blocks PASS (UI-persona Paths from user_journey.md § 3)
- [ ] API-side smoke blocks PASS (caller-persona Paths / TC-API set — caller + state + observability triple-verified for each)
- [ ] Cross-layer contract validated: request payloads from browser match the frozen contract; responses match design.md § Cross-Layer Type Mapping (no type drift between FE and BE)
- [ ] Data persists across layers: browser action → backend mutation → backend read → browser display shows the expected value
- [ ] WCAG quick pass on browser-side scenarios
- [ ] Visual cases: with a browser MCP (`qa.browser_mcp`), every `[QA-VIS-{CASE}]` PASS (EVOL-077)
- [ ] Zero open `stale-after-*` labels on this issue

**phase:smoke-e2e** (legacy projects):
- Uses the generic DoD above (artefact + validation checks + zero stale labels). Projects can opt in to scope-aware DoD by adding `scope` to spec.feature frontmatter, which causes `--plan-feature` on the next feature to emit the scoped variant label.

The other gate types (CONTRACT-FREEZE, PREVENTIVE-SWEEP, INTEGRATION-TEST, RETROSPECTIVE) carry gate-specific DoD lines that are scope-agnostic — they operate on contract / DC / cross-feature-integration / epic-closure concerns that do not change meaning with scope. The `--plan-feature` materialiser renders the generic DoD template above for those gates.

## Resolution command

> Gate issues do NOT have a direct Factory slash-command to run. The work is performed via the tool, the skill, or the user action listed here. It opens with `python3 scripts/gate.py tracker --start --feature {ID} --phase contract-freeze|preventive-sweep|smoke` and closes with `BACKLOG --update-execution {step_ref}` (§ 6.5).

{Literal instructions: "Run factory-preventive-sweep skill against FEATURE_ID", "Execute the numbered smoke blocks on the pre-production deploy", "Produce OpenAPI + contract harness", "Run retrospective write-back procedure (Factory-backlog-operations.instructions.md § 3.4.1)".}

## Cascade behaviour

When the iteration-model cascade reopens this gate (applying the `stale-after-cascade` label), the artifact the gate produced is marked `status: INVALIDATED` and the gate's DoD checklist must be re-validated in full — partial delta updates are NOT supported for gate artefacts.
```

> **How `--next-task` resolves a gate issue.** The resolver parses the issue body looking for the `## Gate type` and `## Blocks` lines. If a candidate command matches a `Blocks` target and the matching gate issue is not Done (or carries a `stale-after-*` label), the resolver returns the gate issue itself with `why_now = "gate blocks {candidate.command}"`. The resolver surfaces the `Resolution command` field as the concrete next action for the user, instead of a Factory slash-command (which gates intentionally lack).

---

## 6. ISSUE CREATION PROTOCOL

### 6.0 Tool-Adapter Protocol (External mode)

> The framework is **tool-agnostic**. Tool-specific CLI/MCP commands are NOT hardcoded in operational files. Instead, they are materialized by `SETUP --generate` into `docs/backlog/tool-adapter.md`, which contains the exact commands for the configured tool.

> **🔒 SECURITY:** The framework NEVER stores a credential. GitHub: `gh auth login`. Jira: the vault exports the token as `JIRA_API_TOKEN` (+ `JIRA_USER_EMAIL` on Cloud) for the gate and jira-cli; the MCP transport authorises through OAuth in the harness.

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
| `configure_board` | ✅ | Set up board columns from `board_columns` (Q27.1); every `tracker.flow` column must exist |
| `create_label` | ✅ | Create a label with name and (optional) color. Used to materialize the full label taxonomy (§ 4.1) at init time |
| `create_milestone` | ⚠️ optional | Create a milestone/fix-version with a name. Skipped when `milestone_strategy == "none"` or when the tool has no native milestone concept |

**Issue lifecycle operations — one command on every adapter (EVOL-079).** Create, place, move, close and nest are `python3 scripts/gate.py tracker`; no adapter carries them as hand commands and the agent never runs a tool's write call:

| Need | Command |
| --- | --- |
| Create the missing items, each in its state's column, a parentless child linked | `gate.py tracker --ensure FILE [--dry-run]` — FILE is a JSON list of rows `{title, ident?, body?, labels?, parent?, milestone?, state?}` (`body` a markdown path; in external mode a scratch file, never `docs/backlog/`; `ident` defaults to the title head — pass the full title when items share a head, e.g. `[F] COMPONENT:`) |
| Sub-increment items of a train (EVOL-045) | `gate.py tracker --ensure --sub-increments F` (rows from `increment_plan.md § 1`) |
| A phase starts | `gate.py tracker --start --feature F --phase P [--item IDENT] [--aligns AC-F-N]` (§ 6.5) |
| Any other move | `gate.py tracker --move IDENT --to backlog\|ready\|in-progress\|done` (done closes; leaving done reopens) |
| Stale marker after a cascade | `add_label` — the adapter's command (a label, not a column) |

The gate reads the board, plans only what is missing, writes, re-reads the keys it wrote and plans again: a board already in the wanted state plans nothing, so **a re-run is the recovery** — nothing is rolled back. Red, never silent: two items on one ident, a child under another parent (never re-parented), a parent that does not exist, a column `tracker.flow` names that the board lacks, a write the board did not take.

**Query and verification operations** (called by `--next-task`, `--status`, Final Verification Gate § 6.4):
| Operation | Required | Description |
| --- | --- | --- |
| `query_board` | ✅ | Query all items with their status, labels, milestone, and (if supported) sub-issue parent |
| `get_item_id` | ✅ | Get the board item ID for an issue |
| `read_issue` | ✅ | Read a single issue's title, body, labels, milestone, and state |
| `verify_issue` | ✅ | Verify an issue exists with expected title, labels, and status. Returns issue metadata for comparison |
| `verify_board_placement` | ✅ | Verify an issue is on the project board in the expected column. Returns current column/status |

> **Tech-Agnostic Invariant:** ALL read operations above are **abstract**. The tool-adapter materializes them with tool-specific CLI/MCP commands during `SETUP --generate`. The BACKLOG agent NEVER hardcodes tool-specific commands; it ALWAYS delegates to the tool-adapter. For **required** operations, if a tool does not support them natively, the tool-adapter MUST define a composed multi-step workaround. For **optional** operations, the tool-adapter MAY declare them as no-ops — the BACKLOG agent then falls back to the documented alternative. Writes are never here: every lifecycle write is `gate.py tracker` (§ 6.0).

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

### 6.1 Single Issue (every adapter)

1. Generate body content using templates from § 5 into a markdown file (local mode: `docs/backlog/issue-bodies/` is written by the gate; external mode: a scratch file)
2. Write one row and run `python3 scripts/gate.py tracker --ensure FILE` — the gate creates, places in the row's state column (default backlog), nests and verifies by re-reading
3. Red → read the reason, fix the cause (§ 6.0.1 for a tool failure), re-run the same command

### 6.2 Full Feature (N issues per feature_phases)

One rows file, suffix order 1 → N, the gate phases with `parent` = the IMPLEMENT title head; one `gate.py tracker --ensure FILE`. A failure mid-batch leaves the created items in place: fix the cause and re-run — the items already there plan nothing. Then run the Final Verification Gate (§ 6.4).

### 6.3 Board placement

Part of `--ensure` (§ 6.1): nothing to repeat.

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

### 6.5 Phase start and ratified realignment (EVOL-079)

Every phase command opens with `python3 scripts/gate.py tracker --start --feature F --phase P` before its first artefact write: the phase's item moves to the `in-progress` column. A Done item is red — reworking delivered work is a refinement item (`{head}-R<k>:`, § 3.3), never a reopened one — unless the change is a ratified realignment (LAW-17): `--aligns AC-F-N` names the accepted change and the item stays Done. `--item IDENT` names an item that is not the phase's own (a refinement, a sub-increment). A gate item opens the same way (`--phase contract-freeze|preventive-sweep|smoke`, § 5 Gate Issue).

**Done.** A phase command never closes its own item: `BACKLOG --update-execution {step_ref}` does, on every adapter (`gate.py tracker --move IDENT --to done`; GitHub closes the issue, `none` rewrites the row).

---

## 7. PROJECT BOARD OPERATIONS

### 7.1 Create Project (--init-board)

#### External Mode

1. **Verify CLI/MCP readiness**: Execute Preflight Check (§ 6.0.2). If it fails → resolve with user before proceeding.
2. **Execute tool-adapter `create_project`**: Create the project/board in the external tool
3. **Execute tool-adapter `configure_board`**: Set up board columns from `board_columns` setup decisions
4. **Retrieve project identifiers**: the keys the gate reads — GitHub `owner`, `repo`, `project_number` (and `project_node_id`); Jira `site`, `project_key`, `board_id`. No field, option or transition id: the gate resolves columns by name at run time
5. **Persist to `docs/backlog/project-config.json → project_ids`**: those keys, the tool name and the integration method — **zero credentials**
6. **Inform user**: Display the project URL and note any manual steps from the tool-adapter

#### Local Mode

Initialize `docs/backlog/state.md` with the Kanban table structure:

```markdown
---
last_updated: {date}
total_issues: 0
next_local_id: 1
board_columns: [{Q27.1 columns}]
---

# Backlog State

## Board

| Local ID | Feature | Title | Status | Labels | Milestone | Parent | Body File |
|----------|---------|-------|--------|--------|-----------|--------|-----------|
| — | — | — | — | — | — | — | — |

## Next Action

Run `BACKLOG --plan-feature` to create feature issues.
```

Create `docs/backlog/issue-bodies/.gitkeep` to track the directory.

### 7.2 Move Issues (--move)

`python3 scripts/gate.py tracker --move IDENT --to backlog|ready|in-progress|done` per item, on every adapter. The gate resolves the column from `tracker.flow`, writes, re-reads and reports `<key> → <column>` (or `<key> already <column>`); red names what the board refused.

### 7.3 Board Status (--status)

#### External Mode

Execute tool-adapter `query_board` command to retrieve all items with their current status column. Parse the output and display the summary table, columns in `board_columns` order. Include issue count per column and total.

#### Both Modes — Display Format

```
| Column       | Count | Issues |
|-------------|-------|--------|
| Backlog      | 5     | #10, #11, #12, #13, #14 |
| Ready        | 1     | #6 |
| In Progress  | 2     | #7, #8 |
| Done         | 3     | #1, #2, #3 |
```

In local mode, "Issues" column shows local IDs (e.g., `L-001`, `L-002`).

---

## 8. STATE TRACKING (Local mode only)

> **SSOT:** This section applies ONLY in **local mode** (`project_tracking.adapter == none`). In external mode, the external tool IS the state tracker — do NOT create or update `state.md`.

Path: `docs/backlog/state.md`

This file IS the backlog in local mode. It serves as both the issue registry and the Kanban board. Only `gate.py tracker` writes its rows (§ 6.0):

```markdown
---
last_updated: {date}
total_issues: {N}
next_local_id: {N+1}
board_columns: [Backlog, Ready, In Progress, Done]
---

# Backlog State

## Board

| Local ID | Feature | Title | Status | Labels | Milestone | Parent | Body File |
|----------|---------|-------|--------|--------|-----------|--------|-----------|
| L-001 | FEAT-001 | [FEAT-001] CODESIGN: Spec BDD + UX Mock — Auth | Backlog | phase:codesign | EPIC-1: Auth | — | docs/backlog/issue-bodies/feat-001-1-codesign.md |
| L-002 | FEAT-001 | [FEAT-001] BLUEPRINT: Architecture — Auth | Backlog | phase:blueprint | EPIC-1: Auth | — | docs/backlog/issue-bodies/feat-001-2-blueprint.md |

## Next Action

{What should be done next}
```

---

## 9. GOVERNANCE ALIGNMENT

This agent respects the Factory governance framework:

- **SSOT Invariant**: Exactly one source of truth per § 0 — external tool XOR local files, never both
- **Constitution**: `docs/constitution.md` — stack constraints
- **Rules**: `.claude/rules/*` — specific regulations per area
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
| `--move {IDENT} --to done` | Suggest `--update-execution` to mark corresponding plan steps as complete |
| `--status` | Include execution plan progress summary if plan exists |

### 10.2 Memory Cache

The execution plan state is cached in `/memories/repo/execution-plan-cache.md` for fast next-task resolution. The cache is a **read/write-through** optimization — the disk file (`docs/backlog/execution-plan.md`) remains the single source of truth. See the execution plan instruction file for cache operations.

### 10.3 Commands (delegated to execution plan instruction)

| Command | Description |
| --- | --- |
| `--plan-execution` | Analyze dependencies, form epics, generate execution-plan.md |
| `--update-execution {step}` | Mark step complete, update progress, refresh cache |
| `--sync-execution` | Reconcile plan with board state, rebuild cache |
