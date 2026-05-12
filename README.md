# mi AI Factory for Claude

[![License: EULA](https://img.shields.io/badge/License-EULA-blue.svg)](./EULA.md)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai/claude-code)

> **Governed Agentic SDLC System**: A single Claude Code agent orchestrates the complete Software Development Life Cycle with built-in governance, security, and quality gates via slash commands.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Architecture](#architecture)
5. [Workflow Sequence](#workflow-sequence-preset-full-sdlc)
6. [Command Reference](#command-reference)
7. [Recommended Pipeline](#recommended-pipeline)
8. [Complete Workflow Diagram](#complete-workflow-diagram)
9. [Exception Routes and Recovery](#exception-routes-and-recovery)
10. [State Transition Matrices](#state-transition-matrices)
11. [State Glossary](#state-glossary)
12. [Dynamic Governance System](#dynamic-governance-system)
13. [Memory Cache Architecture](#memory-cache-architecture)
14. [Immutability and Versioning](#immutability-and-versioning)
15. [Directory Structure](#directory-structure)
16. [Security](#security)
17. [Troubleshooting](#troubleshooting)
18. [License](#license)
19. [Support](#support)

---

## Overview

This system transforms Claude Code into a **governed SDLC orchestrator** using slash commands (`.claude/commands/`). A single agent assumes specialized roles — 6 covering the main SDLC phases plus 2 independent operational commands (AUDIT and BACKLOG) — supported by cross-cutting skill protocols and contextual instruction files.

### Key Features

- **Single Agent + Slash Commands**: 8 specialized commands invoked via `/command --args` — no multi-agent coordination overhead.
- **Natural Language + Commands**: Say what you need or use explicit slash commands — Claude routes everything.
- **Constitution-Driven**: All decisions validated against `docs/constitution.md` (generated during setup).
- **Contract-First Development**: API contracts (OpenAPI, GraphQL, gRPC, AsyncAPI, webhooks) defined and linted before implementation.
- **Build Verification Loop (BVL)**: Tests executed in terminal, errors parsed and auto-fixed (max 3 attempts). Full Verification Gate (tests + lint + typecheck + build) before completion.
- **Security by Design**: OWASP Top 10 + SAST/DAST built into workflow (inline, not post-facto).
- **TDD Enforcement**: Red-Green-Refactor-**Verify** cycle mandatory for all code (BVL closes the loop).
- **Immutable Specifications**: Version-controlled requirements with full audit trail.
- **Anti-Drift Protection**: RED ZONES prevent modification of framework/third-party code.
- **Project Tracking**: Integrated backlog management with external tools or local files.
- **Defect Prevention Catalog**: Living catalog of runtime patterns invisible to static gates; consumed by every SDLC agent.

---

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| **Claude Code** | CLI, VS Code extension, JetBrains extension, or Desktop app | Any supported interface |
| **Claude model** | Claude Opus 4.x | Required for the framework's reasoning complexity |
| **Git** | 2.x | Initialized repository |
| **Bash-compatible shell** | — | Linux / macOS / WSL on Windows |

---

## Installation

The framework activates automatically when opening the repository with Claude Code. Claude reads `CLAUDE.md` from the root and registers slash commands from `.claude/commands/`.

```bash
# 1. Clone the repository
git clone https://github.com/e2its/mi-AI-Factory-for-Claude.git
cd mi-AI-Factory-for-Claude

# 2. Run Claude Code (CLI)
claude

# 3. Or open in VS Code / JetBrains with the Claude Code extension installed.
#    Claude Code auto-detects CLAUDE.md.
```

### Framework File Structure

```
CLAUDE.md                                    # Root governance (always loaded)
.claude/
├── commands/                                # 8 slash commands (one per SDLC phase)
│   ├── audit.md                             # /audit  — Due Diligence
│   ├── setup.md                             # /setup — Setup & Governance
│   ├── codesign.md                          # /codesign — Co-Creation (PO ↔ UX)
│   ├── blueprint.md                         # /blueprint — Technical Design (ARCH ↔ QA)
│   ├── implement.md                         # /implement — Implementation (DEV ↔ REVIEW ↔ SEC)
│   ├── devops.md                            # /devops — Infrastructure & Deployment
│   ├── qa.md                                # /qa — Post-Staging Verification
│   └── backlog.md                           # /backlog — Project Tracking & Issues
├── instructions/                            # Detailed instructions (contextual load)
│   ├── Factory-protocol-smart-redirect.instructions.md
│   ├── Factory-protocol-iop-intent-map.instructions.md
│   ├── Factory-audit-checklist.instructions.md
│   ├── Factory-audit-complexity.instructions.md
│   ├── Factory-setup-discovery.instructions.md
│   ├── Factory-setup-materialization.instructions.md
│   ├── Factory-setup-upgrade.instructions.md
│   ├── Factory-codesign-vision.instructions.md
│   ├── Factory-codesign-feature.instructions.md
│   ├── Factory-blueprint-design.instructions.md
│   ├── Factory-blueprint-validation.instructions.md
│   ├── Factory-implement-plan.instructions.md
│   ├── Factory-implement-build.instructions.md
│   ├── Factory-implement-review-checks.instructions.md
│   ├── Factory-devops-configure.instructions.md
│   ├── Factory-devops-provision-deploy.instructions.md
│   ├── Factory-qa-verify.instructions.md
│   ├── Factory-backlog-operations.instructions.md
│   ├── Factory-backlog-execution-plan.instructions.md
│   └── Factory-backlog-next-task.instructions.md
├── skills/                                  # Cross-cutting skills (reusable protocols)
│   ├── Factory-build-verification/          # BVL — test execution + auto-fix loop
│   ├── Factory-incremental-persistence/     # IPP — incremental persistence
│   ├── Factory-codebase-inventory/          # CIP — DRY inventory
│   ├── Factory-governance-loading/          # GCRP — Zero Trust context recovery
│   ├── Factory-iteration-model/             # Cascading invalidation
│   ├── Factory-branching-strategy/          # SCM — branch enforcement
│   ├── Factory-agent-communication/         # ACP — controlled verbosity
│   ├── Factory-commit-prompt/               # Auto-generated conventional commits
│   ├── Factory-worklog/                     # Per-feature JSONL audit trail
│   ├── Factory-memory-cache/                # MCP — acceleration layer at /memories/repo/
│   ├── Factory-coherence-validation/        # CVP — cross-artifact validation
│   ├── Factory-preventive-sweep/            # Runtime defect sweep pre-deploy
│   └── Factory-backlog-next-task/           # Next-task resolver with cache fast path
└── settings.json                            # Permission configuration
.context/
└── templates/                               # Materialization templates (SETUP --generate)
```

### Post-Installation Verification

1. Open Claude Code (CLI: `claude`, or via IDE extension).
2. Type `/` — the 8 framework commands should appear (audit, setup, codesign, blueprint, implement, devops, qa, backlog).
3. Type `/setup --init` to bootstrap a new project.
4. Claude reads `CLAUDE.md` automatically on every conversation (contains cross-cutting governance).

---

## Architecture

### Single Agent + Slash Commands Model

```
                    ┌─────────────────┐
        User ───────►│   Claude Code   │◄─── CLAUDE.md (always loaded)
                    │  (single agent) │
                    └──────┬──────────┘
                           │ slash commands (/command --args)
            ┌──────┬───────┼───────┬──────┬───────┬──────┬─────────┐
            ▼      ▼       ▼       ▼      ▼       ▼      ▼         ▼
         /audit  /setup /codesign /blueprint /implement /devops /qa /backlog
        (each command loads its instructions and skills on invocation)
```

- **Claude Code** is a single agent that assumes different roles depending on the slash command invoked.
- Each slash command defines the role's personality, protocols, and rules.
- Detailed instructions in `.claude/instructions/` are loaded contextually per command.
- Skills in `.claude/skills/` are cross-cutting protocols reusable by every command.
- `CLAUDE.md` loads on EVERY conversation (contains cross-cutting governance).

### How to Interact

Invoke commands directly as slash commands:

```
/codesign --start USR-001 "OAuth login"
/blueprint --start USR-001
/implement --build USR-001
```

Or use natural language — Claude identifies the intent and runs the appropriate command:

```
"I want to create an OAuth login feature"
→ Claude runs: /codesign --start {ID} "OAuth login"
```

### Persistence Loop

Commands **do not fail silently** — they pause and persist state:

1. Claude encounters ambiguity → saves the artifact with `status: NEEDS_INFO`.
2. Lists specific questions in the artifact's frontmatter.
3. Waits for user refinement → use `--refine` to answer.
4. Resumes execution from the saved checkpoint.

---

## Workflow Sequence (preset `full-sdlc`)

```
SETUP (one-time)
  → CODESIGN (PO↔UX, auto-approves 12/12)
  → BLUEPRINT (ARCH↔QA, --approve required)
  → CONTRACT-FREEZE          [hard gate — blocks IMPLEMENT --plan]
  → DEVOPS --configure
  → IMPLEMENT (DEV↔REVIEW↔SEC + BVL)
  → PREVENTIVE-SWEEP         [hard gate — blocks DEVOPS --deploy dev]
  → QA (verify, auto-approves)
  → SMOKE-E2E                [hard gate — blocks QA --verify pass]
  → MERGE (PR → main)
  → DEVOPS (deploy prod)
```

Each `full-sdlc` feature expands into **8 backlog issues**. Three are hard gates:

- **CONTRACT-FREEZE** — freezes API contracts (OpenAPI, TS interfaces, GraphQL schema, etc., stack-specific) and the contract test harness before `IMPLEMENT --plan`.
- **PREVENTIVE-SWEEP** — runtime defect scan post-IMPLEMENT via a parallel scope-sized skill; zero open C-severity findings to pass.
- **SMOKE-E2E** — numbered manual smoke blocks derived from `user_journey.md` BDD scenarios, executed on the dev-deployed build before `QA --verify` can pass.

Two additional gates operate at the epic/slice level:

- **SLICE-INTEGRATION-TEST** — closes each slice (≤3 features sharing a Bounded Context / Aggregate Root); blocks the start of the next slice.
- **EPIC-RETROSPECTIVE** — mandatory at epic close; blocks the start of the next epic. Includes write-back to the Defect Prevention Catalog (lessons → DC entries).

Presets `simplified` (3 issues: spec → implement → qa, no gates) and `single` (1 issue, no gates) are reserved for prototypes and spikes where gate overhead is not justified.

**AUDIT** is independent — runs at ANY time. It NEVER blocks the main workflow.

**BACKLOG** is independent — runs at ANY time after SETUP. It manages the project board, issues, and tracking.

> **Auto-Approval:** CODESIGN, DEVOPS `--configure`, and QA `--verify` auto-approve when all validations pass. `BLUEPRINT --approve` is the only mandatory manual checkpoint for the classic phases. Auto-approval does NOT bypass hard gates — each gate issue must be Done before the downstream command starts.

> **Gate Enforcement Modes:** each gate has a mode (`enforce` / `warn` / `off`) configured at SETUP. Greenfield projects start in `enforce` from day 1. Brownfield projects can start in `warn` and flip to `enforce` once the first new feature validates the gate artefact in main.

> **Dynamic Environments:** environments are read from `.claude/rules/ci-cd.md` `environments[]`. A project may have `dev → prod` or `dev → staging → UAT → prod`. The invariant: **MERGE always occurs BEFORE the production deploy**.

---

## Command Reference

> Invoke in Claude Code: `/command --args`, or describe the intent in natural language.

### Pre-0. AUDIT (Technical Due Diligence) — Optional

Role: Senior Technical Auditor. Evaluates the current state of an existing project before governance kicks in. Independent of the main workflow.

| Command | Arguments | Description |
| --- | --- | --- |
| `/audit --audit` | — | Full technical audit. Scan-First protocol. Master Checklist: Phase 0 (Language), Phase A (Governance / HR), Phase B (Architecture / Software), Phase C (Infrastructure), Phase D (Security). Atomic persistence: one section per turn. Resumable via `status: NEEDS_INFO`. |
| `/audit --refine {SECTION_ID}` | Section ID (P0, G1-G3, S1-S4, I1-I4, SEC1-SEC5) | Refinement of a specific section. |
| `/audit --approve` | — | Audit closure with verdict `GO` / `NO_GO` / `GO_WITH_CONDITIONS`. |

Artifact: `docs/technical_due.md`.

### 0. SETUP (Setup & Governance)

Role: Architect / Governance. Defines constitution, rules, and initial scaffolding.

| Command | Arguments | Description |
| --- | --- | --- |
| `/setup --init` | — | Discovery with AI budget + Brownfield auto-detection. Planning with 12 backend topologies and 10 frontend patterns. Execution with budget validation. |
| `/setup --generate` | — | Only with `phase: COMPLETED`. Materializes tripartite scaffolding (Backend / Frontend / Integration ACL). Includes IaC foundation scaffolding. Creates `MATERIALIZATION_REPORT.md` with a 60–80 task checklist. |
| `/setup --generate --resume` | — | Continues an interrupted materialization. Requires `MATERIALIZATION_REPORT.md`. Reads the checklist and resumes from the last pending task. |
| `/setup --migrate-legacy-setup` 🧪 | — | **EXPERIMENTAL.** Auto-migrates a legacy `setup.md` to the tripartite format. Requires a score > 85%. |
| `/setup --upgrade` | — | Upgrades governance artifacts to the latest framework version. 6 safety layers. Smart Additive Merge. |
| `/setup --rollback-upgrade {TIMESTAMP}` | Backup timestamp | Recovers the project from a failed upgrade. |

Artifacts: `docs/setup.md`, `docs/constitution.md`, `.claude/rules/*`, `MATERIALIZATION_REPORT.md`.

### 1. CODESIGN (Co-Creation: PO ↔ UX)

Role: Dual personality (🎩 PO hat ↔ 🎨 UX hat). Co-creates the functional specification, the visual mockup, and the user journey.

| Command | Arguments | Description |
| --- | --- | --- |
| `/codesign --vision` | — | Generates the global UX vision. Mandatory for projects with a frontend. 7 phases. |
| `/codesign --vision-refine "[FEEDBACK]"` | Feedback | Refinement of the global vision. |
| `/codesign --vision-approve` | — | Joint PO+UX approval of the global vision. |
| `/codesign --vision-propagate` | — | Propagates vision changes to existing mocks. |
| `/codesign --start {ID}` | Feature ID | Starts co-creation. Vision Gate for UI features. Event Storming → spec ↔ mock ↔ journey until convergence. Auto-approves when 12/12 validations pass. |
| `/codesign --refine {ID} "[FEEDBACK]"` | Feedback | Iterative refinement. Classifies changes as DELTA or BREAKING. Auto-approves when 12/12 validations pass. |

Per-feature artifacts: `docs/spec/{ID}/spec.feature`, `mock.html`, `user_journey.md`.
Global vision artifacts: `docs/ux/vision/vision.md`, `app_shell.html`, `style_guide.html`, `page_templates.html`, `component_library.html`, `navigation_map.md`.

### 2. BLUEPRINT (Co-Design: ARCH ↔ QA)

Role: Dual personality (🏗️ ARCH hat ↔ 🧪 QA hat). Co-designs architecture and test strategy simultaneously.

| Command | Arguments | Description |
| --- | --- | --- |
| `/blueprint --start {ID}` | — | Co-designs `design.md` + `test_plan.md` + `increment_plan.md`. Requires CODESIGN APPROVED. Produces C4, contracts, Section 5 (Infrastructure Needs). Emits the Increment Plan via RDR (≥3 slicing alternatives; user ratifies verbatim). |
| `/blueprint --refine {ID} "[FEEDBACK]"` | Feedback | Iterative refinement of design, tests and/or the Increment Plan. |
| `/blueprint --approve {ID}` | — | Joint ARCH+QA approval. Runs CVP Coherence Gate (13 checks in CODESIGN_BLUEPRINT scope, incl. increment_deployability, increment_to_scenario_coverage, increment_to_contract_coverage). Enables IMPLEMENT. |
| `/blueprint --adr {ID} "[TITLE]" "[DECISION]"` | Title and decision | Generates a standalone ADR. |
| `/blueprint --review-conflict {ID}` | — | Arbitration when peer review rejects 3+ times. |

Artifacts: `docs/spec/{ID}/design.md`, `test_plan.md`, `increment_plan.md`, contracts under `contracts/`.

### 3. IMPLEMENT (Implementation: DEV ↔ REVIEW ↔ SEC)

Role: Triple personality (💻 DEV ↔ 🔍 REVIEW ↔ 🛡️ SEC). Plans + implements + verifies + secures per phase.

| Command | Arguments | Description |
| --- | --- | --- |
| `/implement --plan {ID}` | — | Generates the implementation checklist (`dev_plan.md`). Requires BLUEPRINT APPROVED. Under `slicing_strategy: incremental` emits one `## Increment INC-N` section per increment with `[INC-N.A.M]` / `[INC-N.B.M]` / `[INC-N.C.M]` tasks + `[INC-N.ACC.k]` acceptance gate; under `monolithic` preserves legacy `[A/B/C.N]` tags. |
| `/implement --refine {ID} "[FEEDBACK]"` | Feedback | Plan refinement. Standard Refine produces `[ADJ-N]` tasks; Delta Iteration produces `[D.N]` tasks. |
| `/implement --build {ID}` | — | Phased implementation: 💻 DEV (TDD + BVL) → 🔍 REVIEW → 🛡️ SEC (SAST). Build Verification Loop: runs tests in terminal, parses errors, auto-corrects (max 3 attempts). Full Verification Gate (tests + lint + typecheck + build) — under `slicing_strategy: incremental` runs scope-filtered per slice before flipping `dev_plan.frontmatter.increments[INC-N].status: IMPLEMENTED_AND_VERIFIED`; the global `dev_plan.status` is **derived** and only flips after the last slice closure passes a plan-level BVL aggregate. Completion Gate: every task must be `[x]` or `@skip` with justification. |
| `/implement --fix {ID} "[HELP]"` | Help | Generates `[FIX-N]` tasks from QA rejection or blockers. Executes fix → marks `[x]`. |

Artifacts: `docs/spec/{ID}/dev_plan.md`, source code, `peer_review_{ts}.md` (or `peer_review_{INC-N}_{ts}.md` per-slice when incremental), `sec_audit.md`, Draft PR.

### 4. DEVOPS (DevOps & Infrastructure)

Role: SRE and Platform Engineer. Manages infrastructure, CI/CD, and environments.

| Command | Arguments | Description |
| --- | --- | --- |
| `/devops --configure {ID}` | — | Generates the infrastructure plan (RDR-guided). Auto-approves when 7/7 checks pass. |
| `/devops --refine {ID} "{FEEDBACK}"` | Technical feedback | Adjusts the plan based on feedback. |
| `/devops --provision [{ID}] --env {ENV}` | Environment | Materializes infrastructure. With `{ID}` → feature-scoped. Without `{ID}` → env-scoped. |
| `/devops --deploy [{ID}] --env {ENV}` | Environment | Deploys code. Requires IMPLEMENT complete. Production requires MERGE + QA APPROVED. |
| `/devops --suspend [{ID}] --env {ENV}` | Environment | Suspends the environment to reduce cost. |
| `/devops --resume [{ID}] --env {ENV}` | Environment | Resumes a suspended environment. |
| `/devops --rollback [{ID}] --env {ENV}` | Environment | Rolls back a deployment. |
| `/devops --teardown [{ID}] --env {ENV}` | Environment | Destroys infrastructure. `data_bearing: true` requires a backup. |
| `/devops --status [{ID}]` | — | Status dashboard. |

Artifacts: `docs/spec/{ID}/devops_plan.md`, `infra/features/{ID}/` (IaC), `deployment_report_{ts}.md`.

**Execution Guardrails:**

- **G0** Governance Load | **G1** Stack Coherence | **G2** Cost (> 20% warn, > 50% block)
- **G3** Secrets (hardcoding forbidden) | **G4** HA (CRITICAL features → multi-AZ)
- **G5** Environments (from governance, never hardcoded) | **G6** Data Protection (backup before teardown)

### 5. QA (Quality Assurance — Post-Staging)

Role: Final post-code certification and verification in a deployed environment (includes DAST via the 🛡️ SEC hat).

| Command | Arguments | Description |
| --- | --- | --- |
| `/qa --verify {ID} [{INC-N}]` | Optional `INC-N` | Checkbox-driven: generates the `[ ]` checklist (`[QA-PRE-*]`, `[QA-GOV-*]`, `[QA-TC-*]`, `[QA-REG-*]`, `[QA-DAST-*]`, plus `[QA-AGG-*]` in aggregate mode for incremental features), marks `[x]` as it executes. **Slice mode** (`INC-N` provided): verifies a single increment that has reached `IMPLEMENTED_AND_VERIFIED` per-entry — checklist filtered to scenarios assigned to the slice; required for incremental features before the aggregate. **Aggregate mode** (no `INC-N`): final feature-level verification; for incremental features requires every `qa_report_{INC-N}_*.md` already APPROVED. Auto-approves when ALL `[x]` AND verdict APPROVED. Requires a deployed environment. |
| `/qa --reject {ID} "[REASON]"` | Reason | Generates remediation items `[FIX-N]` → `/implement --fix`. |
| `/qa --e2e {ID}` | — | Runs E2E tests. |

Artifacts: `docs/spec/{ID}/qa/qa_report_{INC-N}_{ts}.md` (per-slice, slicing_strategy=incremental) and/or `docs/spec/{ID}/qa/qa_report_final_{ts}.md` (aggregate / sole report for monolithic). The aggregate report cross-references slice reports via the `aggregates:` frontmatter.

> **Note:** Test planning was absorbed by BLUEPRINT (🧪 QA hat). QA focuses on post-staging verification.

### 6. BACKLOG (Project Tracking & Issue Management) — Independent

Role: Project board operations manager. Creates issues, organizes the Kanban, and tracks features. Independent of the main workflow (like AUDIT).

| Command | Arguments | Description |
| --- | --- | --- |
| `/backlog --init-board` | — | Initializes the backlog. **External mode:** creates a project in the external tool + `project-config.json`. **Local mode:** creates `state.md` with the Kanban table. |
| `/backlog --plan-feature {ID} "{name}"` | Feature ID + name | Creates the issue set for a feature (phases configured during SETUP). External mode: via API. Local mode: entries in `state.md` + body files. |
| `/backlog --create-issue "{title}"` | Title | Creates a single custom issue. External mode: via API. Local mode: entry in `state.md` + body file. |
| `/backlog --move {ISSUE_NUMS} --to {STATUS}` | Issues + target column | Moves issues between Kanban columns. External mode: API. Local mode: updates `state.md`. |
| `/backlog --status` | — | Shows a board summary with issue counts per column. |
| `/backlog --plan-execution` | — | Analyzes feature dependencies, forms Epics by shared Bounded Context. **External mode:** projects the plan onto the board (milestones + labels + ordering). **Local mode:** writes `docs/backlog/execution-plan.md`. Cache at `/memories/repo/`. |
| `/backlog --update-execution {step}` | Completed step | Marks a step complete. **External mode:** advances the issue's status on the board. **Local mode:** updates the checklist in `execution-plan.md`. Refreshes the cache. |
| `/backlog --sync-execution` | — | Reconciles the plan with SSOT. **External mode:** rebuilds `project-board-cache.md` from `query_board`, reports drift without touching files. **Local mode:** reconciles `execution-plan.md` with `state.md`. |
| `/backlog --next-task` | — | **Push mode.** Returns the single next executable step (agent + command + evidence) chosen by the framework. Used by Smart Redirect post-command and automations. |
| `/backlog --eligible [--limit N]` | Optional cap | **Pull mode.** Returns the FULL set of items you could pick up right now (respecting intra-feature prereq + `blocked-by:#{N}` + gate mode). Default `--limit 20`; `--limit unlimited` to see everything. READ-ONLY (no writes, no persisted state). |

Prerequisite: `docs/setup.md` with a `project_tracking` section (configured during `/setup --init` Q27–Q27.6).

**SSOT mode:** if `project_tracking.tool != "None"` → external mode (the external board IS the plan — **`execution-plan.md` does NOT exist on disk**). If `project_tracking.tool == "None"` → local mode (`state.md` + `issue-bodies/` + `execution-plan.md` are the only sources of truth).

Artifacts (external mode): `docs/backlog/project-config.json` (non-sensitive connection identifiers and field mapping only — no issue registry, no tokens). Cache: `/memories/repo/project-board-cache.md`.
Artifacts (local mode): `docs/backlog/state.md`, `docs/backlog/issue-bodies/*.md`, `docs/backlog/execution-plan.md`. Cache: `/memories/repo/execution-plan-cache.md`.

---

## Incremental Dev Plan (Vertical Slicing)

Every feature ships as a sequence of **vertical increments**. Each increment is a single PR that leaves the product 100% functional and production-deployable on merge — no feature-flag-OFF escape, no half-done slices. This replaces the legacy "one big implementation branch per feature" model with a serial chain of small, mergeable, user-observable deliverables.

**Authoring.** `BLUEPRINT --start` emits `docs/spec/{ID}/increment_plan.md` (sidecar to `design.md`). The Increment Plan declares, per increment: `scenarios_covered`, `contract_surface`, `depends_on` (DAG), `deployable: production`, an acceptance checklist, and the branch name. BLUEPRINT runs the **Increment Slicing RDR** — it presents ≥3 alternative slicings (by sub-journey / by entity / by risk tier / happy-path-first / read-then-write / …), recommends one, and the user ratifies verbatim.

**Strategy frontmatter (`spec.feature`).** `slicing_strategy: incremental | monolithic`. Default `incremental`. `monolithic` is permitted ONLY when the **trivial-heuristic** passes: ≤2 scenarios AND ≤3 contract operations AND `scope` ≠ `full-stack`. BLUEPRINT blocks the escape otherwise.

**Consumption.** `IMPLEMENT --plan` reads the Increment Plan and emits `dev_plan.md` with one `## Increment INC-N` section per increment (topologically ordered by `depends_on`). Each section contains layered tasks tagged `[INC-N.A.M]` / `[INC-N.B.M]` / `[INC-N.C.M]` plus an `### Increment INC-N Acceptance Gate` with `[INC-N.ACC.k]` items.

**Branching.** One branch per increment — `feature/{FEATURE_ID}-inc-N-{slug}` — merged as an independent PR. Only one increment branch per feature is open at a time (existing concurrency lock). Branch open flips the increment's status `READY → BUILDING`; merge hook stamps `Merged at:` and flips `BUILDING → MERGED`.

**Enforcement.** Four CRITICAL CVP checks at `BLUEPRINT --approve`: `increment_deployability`, `increment_to_scenario_coverage`, `increment_to_contract_coverage`, `monolithic_heuristic`. Per-increment immutability (see `.claude/rules/immutability_policy.md § Per-Increment Immutability`) locks MERGED increments and routes changes through either `CODESIGN --revise` (new feature version) or a **Follow-up Increment** (additive, non-overlapping scenarios — no version bump).

**Iteration cascade.** `CASCADE_INCREMENT_INTERNAL` (see `.claude/skills/factory-iteration-model/SKILL.md`) propagates upstream changes selectively: only increments whose `scenarios_covered` or `contract_surface` overlap with the change are flagged `INVALIDATED`. MERGED increments are never invalidated — they anchor production history; a follow-up increment carries the change forward.

---

## Recommended Pipeline

### Pre-0 (optional): Technical Due Diligence

```
/audit --audit       → Scan + sectioned audit
/audit --approve     → Verdict GO / NO_GO / GO_WITH_CONDITIONS
```

When AUDIT runs, SETUP auto-detects Brownfield and pre-fills data.

### Phase 0: Setup (Governance and Structure)

```
/setup --init        → Discovery → Planning → Execution (interactive)
/setup --generate    → Materializes scaffolding, constitution, rules
```

### Phase 0.1 (optional): Bootstrap Project Board and Backlog

```
/backlog --init-board                              → Creates the project on the configured tool (or local)
/backlog --plan-feature USR-001 "OAuth login"      → Feature issue set
/backlog --plan-feature USR-002 "Dashboard"        → Feature issue set
/backlog --plan-execution                          → Analyzes dependencies → generates execution plan by Epics
```

### Phase 0.5: Global Vision (mandatory for frontend projects)

```
/codesign --vision           → Generates the global visual identity
/codesign --vision-approve   → Approves the vision
```

### Phase 1: Definition and Co-Creation (Pre-Code)

```
/codesign --start USR-001 "OAuth login"     → Co-creates spec + mock + journey (auto-approves when 12/12 OK)

/blueprint --start USR-001    → Co-designs design.md + test_plan.md
/blueprint --approve USR-001  → Enables IMPLEMENT (the only mandatory manual checkpoint)
```

### Phase 2: Implementation (Code)

```
/implement --plan USR-001          → Generates the checklist (dev_plan.md)
/implement --build USR-001         → TDD + BVL (real execution) + Review + SAST per phase
                                     Under slicing_strategy: incremental, run once per slice
                                     (one open INC-N branch at a time). BVL runs scope-filtered
                                     per slice; the plan-level aggregate runs on the last closure.
```

### Phase 2.5: Infrastructure (flexible — post-BLUEPRINT)

```
/devops --configure USR-001              → Infrastructure plan (auto-approves when 7/7 OK)
/devops --provision USR-001 --env dev    → Materializes infrastructure
```

### Phase 3: Certification (Post-Code)

```
/devops --deploy USR-001 --env staging   → Deploys to pre-production
/qa --verify USR-001 INC-1               → Per-slice verification (slicing_strategy=incremental)
                                           Repeat for each slice; required before the aggregate.
/qa --verify USR-001                     → Aggregate / final verification
                                           For monolithic features this is the only QA call.
```

### Phase 4: Merge and Production

```
git push origin feature/USR-001-login-oauth      → Push to remote
# Open PR → CI checks → approval → merge to main + tag

/devops --deploy USR-001 --env prod       → Deploy from main/tag
```

---

## Complete Workflow Diagram

```mermaid
graph TD
    Start([User: new feature]) --> TddCheck{Due Diligence?}
    TddCheck -->|Yes, optional| TddAudit[/audit --audit]
    TddAudit --> TddNeedsInfo{status: NEEDS_INFO?}
    TddNeedsInfo -->|Yes| TddRefine[/audit --refine SECTION]
    TddRefine --> TddAudit
    TddNeedsInfo -->|No| TddApprove[/audit --approve]
    TddApprove --> TddVerdict{Verdict?}
    TddVerdict -->|GO / GO_WITH_CONDITIONS| Setup
    TddVerdict -->|NO_GO| NoGo([Project not viable])
    TddCheck -->|No| Setup{Setup complete?}

    Setup -->|No| SetupInit[/setup --init]
    SetupInit --> SetupGen[/setup --generate]
    SetupGen --> VisionCheck{Frontend?}
    Setup -->|Yes| VisionCheck

    VisionCheck -->|Yes| CodesignVision[/codesign --vision]
    CodesignVision --> CodesignVisionApprove[/codesign --vision-approve]
    CodesignVisionApprove --> CodesignStart[/codesign --start ID]
    VisionCheck -->|No frontend| CodesignStart

    CodesignStart --> CodesignNeedsInfo{status: NEEDS_INFO?}
    CodesignNeedsInfo -->|Yes| CodesignRefine[/codesign --refine ID FEEDBACK]
    CodesignRefine --> CodesignStart
    CodesignNeedsInfo -->|No| CodesignAutoApprove{12/12 validations?}
    CodesignAutoApprove -->|Yes, auto-approve 12/12| BlueprintStart[/blueprint --start ID]
    CodesignAutoApprove -->|No| CodesignFix[Fix and re-refine]
    CodesignFix --> CodesignStart

    BlueprintStart --> BlueprintNeedsInfo{status: NEEDS_INFO?}
    BlueprintNeedsInfo -->|Yes| BlueprintRefine[/blueprint --refine ID FEEDBACK]
    BlueprintRefine --> BlueprintStart
    BlueprintNeedsInfo -->|No| BlueprintApprove[/blueprint --approve ID]

    BlueprintApprove --> ImplPlan[/implement --plan ID]
    ImplPlan --> ImplNeedsInfo{status: NEEDS_INFO?}
    ImplNeedsInfo -->|Yes| ImplRefine[/implement --refine ID FEEDBACK]
    ImplRefine --> ImplPlan
    ImplNeedsInfo -->|No| ImplBuild[/implement --build ID]

    ImplBuild --> ImplBlocked{status: BLOCKED?}
    ImplBlocked -->|Yes| ImplFix[/implement --fix ID HELP]
    ImplFix --> ImplBuild
    ImplBlocked -->|No| ImplDone{Build complete?}
    ImplDone -->|No| ImplBuild
    ImplDone -->|Yes| DevOpsDeploy[/devops --deploy ID --env PRE_PROD]

    DevOpsDeploy --> QaVerify[/qa --verify ID]
    QaVerify --> QaPass{Tests OK?}
    QaPass -->|No| QaReject[/qa --reject ID REASON]
    QaReject --> ImplFix2[/implement --fix ID]
    ImplFix2 --> ImplBuild
    QaPass -->|Yes, auto-approve| MergePR[MERGE: PR → main + tag]
    MergePR --> DeployProd[/devops --deploy ID --env PROD]
    DeployProd --> End([Feature complete])

    classDef checkpoint fill:#2ecc71,stroke:#27ae60,stroke-width:3px,color:#fff
    classDef needsInfo fill:#f39c12,stroke:#e67e22,stroke-width:2px,color:#fff
    classDef blocked fill:#e74c3c,stroke:#c0392b,stroke-width:2px,color:#fff

    class BlueprintApprove,ImplDone checkpoint
    class CodesignNeedsInfo,BlueprintNeedsInfo,ImplNeedsInfo,TddNeedsInfo needsInfo
    class ImplBlocked,NoGo blocked
```

> The diagram shows the classic loop. The three hard gates (CONTRACT-FREEZE, PREVENTIVE-SWEEP, SMOKE-E2E) and the two epic/slice gates (SLICE-INTEGRATION-TEST, EPIC-RETROSPECTIVE) plug into the sequence as blocking backlog issues between the phases listed in [Workflow Sequence](#workflow-sequence-preset-full-sdlc). They do not appear inline here to keep the diagram focused on the classic phase loop.

---

## Exception Routes and Recovery

| Scenario | Persisted State | Recovery Command |
|----------|-----------------|------------------|
| AUDIT without evidence for a section | `technical_due.md → NEEDS_INFO` | `/audit --refine SECTION_ID "Data..."` |
| AUDIT verdict NO_GO | `technical_due.md → APPROVED, verdict: NO_GO` | Review findings with stakeholders |
| Ambiguous spec | `spec.feature → NEEDS_INFO` | `/codesign --refine ID "Clarifications..."` |
| Missing architecture mapping | `design.md → NEEDS_INFO` | `/blueprint --refine ID "Define APIs..."` |
| RED ZONE modification | `design.md → BLOCKED` | `/blueprint --refine ID "ADR: Justification..."` |
| Blocked implementation | `dev_plan.md → task BLOCKED` | `/implement --fix ID "Technical hint..."` |
| Test fails 3× (3-Strike Rule) | `dev_plan.md → NEEDS_DECISION` | Recommendation/Decision loop: retry, modify, or escalate |
| SAST vulnerabilities | `sec_audit.md → VULNERABLE` | Inline fix loop in `/implement --build` |
| DAST vulnerabilities | `qa_report.md → VULNERABLE` | Remediate → `/qa --verify ID [INC-N]` (slice or aggregate, depending on origin) |
| Hardcoded config | `qa_report.md → VULNERABLE` | Fix → `/qa --verify ID [INC-N]` |
| Drift violation | `qa_report.md → BLOCKED` | `/blueprint --refine ID` or fix and re-run |

---

## State Transition Matrices

### `spec.feature` (CODESIGN)

| Current State | Valid Command | Next State |
|---------------|---------------|------------|
| — | `/codesign --start ID` | `DRAFT` or `NEEDS_INFO` |
| `NEEDS_INFO` | `/codesign --refine ID` | `DRAFT` or `NEEDS_INFO` |
| `DRAFT` | (auto-approve 12/12 OK) | `APPROVED` |
| `APPROVED` | `/codesign --refine ID` | `DRAFT` (new iteration) |

### `design.md` + `test_plan.md` (BLUEPRINT)

| Current State | Valid Command | Next State |
|---------------|---------------|------------|
| — | `/blueprint --start ID` | `DRAFT` or `NEEDS_INFO` |
| `NEEDS_INFO` | `/blueprint --refine ID` | `DRAFT` or `BLOCKED` |
| `DRAFT` | `/blueprint --approve ID` | `APPROVED` |
| `APPROVED` | `/blueprint --refine ID` | `DRAFT` (ADR required if RED ZONE) |

### `dev_plan.md` (IMPLEMENT)

| Current State | Valid Command | Next State |
|---------------|---------------|------------|
| — | `/implement --plan ID` | `DRAFT` or `NEEDS_INFO` |
| `NEEDS_INFO` | `/implement --refine ID` | `READY` |
| `READY` | `/implement --build ID` | `BUILDING` |
| `BUILDING` | `/implement --build ID` | `BUILDING` or `IMPLEMENTED_AND_VERIFIED` |
| `BUILDING` | (test fails 3×) | `NEEDS_DECISION` |
| `BUILDING` | `/implement --fix ID` | `BUILDING` |
| `IMPLEMENTED_AND_VERIFIED` | `/implement --refine ID` | `READY` (delta_mode) |
| `IMPLEMENTED_AND_VERIFIED` | `/implement --fix ID` | `BUILDING` (fix cycle) |

> Under `slicing_strategy: incremental` the plan-level state shown above is **derived**: it stays at `BUILDING` until every entry of `dev_plan.frontmatter.increments[]` has reached `IMPLEMENTED_AND_VERIFIED` AND a plan-level BVL aggregate passes. Per-slice transitions live on `increments[INC-N].status` and follow `READY → BUILDING → IMPLEMENTED_AND_VERIFIED → MERGED` (the merge is recorded by the SCM hook, not by IMPLEMENT).

### `qa_report_{ts}.md` (QA)

| Current State | Valid Command | Next State |
|---------------|---------------|------------|
| — | `/qa --verify ID` | `APPROVED` (auto) or `REJECTED` |
| `REJECTED` | `/implement --fix ID` completes | `INVALIDATED` |
| `INVALIDATED` | `/qa --verify ID` | `APPROVED` (auto) or `REJECTED` |
| `APPROVED` | — | Terminal (enables MERGE) |

### `technical_due.md` (AUDIT)

| Current State | Valid Command | Next State |
|---------------|---------------|------------|
| — | `/audit --audit` | `NEEDS_INFO` |
| `NEEDS_INFO` | `/audit --audit` | `NEEDS_INFO` or `DRAFT` |
| `DRAFT` | `/audit --approve` | `APPROVED` |
| `APPROVED` | `/audit --refine SECTION` | `DRAFT` (re-approval required) |

> `CANCELLED` is terminal across every artifact — it blocks any operation.

---

## State Glossary

### General artifact states

| State | Meaning |
| --- | --- |
| `DRAFT` | Complete draft, pending review or auto-approval. |
| `NEEDS_INFO` | Agent paused, requires `--refine` from the user. |
| `APPROVED` | Document frozen and validated. Enables the next phase. |
| `REJECTED` | (QA) Verification rejected. Requires `/implement --fix`. |
| `COMPLETED` | Process or phase finished successfully. |
| `BLOCKED` | Task not achievable without external help. |
| `CANCELLED` | Feature cancelled. Terminal state. |
| `DEPRECATED` | Feature superseded by a new version. Kept for audit trail. |
| `SUPERSEDED` | (ADR) Architectural decision superseded by a later ADR. |
| `CASCADE_PENDING_ITERATION` | Downstream artifact invalidated by an upstream change. Requires `--refine`. |

### IMPLEMENT states (`dev_plan.md`)

| State | Meaning |
| --- | --- |
| `READY` | Plan ready for `--build`. |
| `BUILDING` | Implementation in progress — TDD + Review + SAST per phase. |
| `IMPLEMENTED_AND_VERIFIED` | Code complete; enables DEVOPS deploy and QA verify. |
| `VULNERABLE` | (SEC) Blocked by active security findings. |
| `SKIPPED` | Task temporarily omitted (must be resolved before the build completes). |

### DEVOPS states (environments)

| State | Meaning |
| --- | --- |
| `NOT_PROVISIONED` | Environment defined but not provisioned yet. |
| `ACTIVE` | Environment provisioned and operating. |
| `SUSPENDED` | Environment paused. Requires `--resume`. |
| `DESTROYED` | Environment destroyed (`--teardown` complete). |

### QA states (reports)

| State | Meaning |
| --- | --- |
| `INVALIDATED` | Report invalidated by upstream changes. |

### CIP states (inventory artifacts)

| State | Meaning |
| --- | --- |
| `PLANNED` | Artifact registered in the inventory, not yet implemented. |
| `IMPLEMENTED` | Inventory artifact that already exists in code. |

### AUDIT states (due diligence)

| State | Meaning |
| --- | --- |
| `GO` | Positive verdict. Project viable. |
| `GO_WITH_CONDITIONS` | Viable with required conditions/mitigations. |
| `NO_GO` | Not viable. Unacceptable risks. |

---

## Dynamic Governance System

### Governance Index (`docs/constitution.md`)

Central auto-generated registry during `/setup --generate`:

- Contains per-rule metadata: type, validation method, severity, applicable agents.
- Governance snapshot: `.context/governance_snapshot.md` — file-based cache, summarization-safe (see `Factory-governance-loading/SKILL.md`).
- Verification commands: auto-derived from the stack config for BVL (test, lint, typecheck, build).

### Governance always-on enforcement (4-tier)

The governance snapshot covers the "what is loaded" question, but it is a passive artifact — it can go stale silently and it evaporates from context across compaction cycles. Four Claude Code hooks make governance demonstrably always-on in any session turn:

| Tier | Trigger | Hook | What it does | Failure mode |
|------|---------|------|--------------|--------------|
| **1 — Visible** | `SessionStart` | `scripts/validate-governance.sh --banner` | Prints `Governance loaded: constitution {hash8}, setup {hash8} \| SDLC-first triage: ON` on session open. If the snapshot is missing, prints a remediation hint instead. | Non-blocking (informational). |
| **2 — Advisory** | `UserPromptSubmit` | `scripts/governance-onprompt.sh` → `validate-governance.sh --snapshot-freshness` | Per prompt: recomputes MD5 of `docs/constitution.md` + `docs/setup.md`, compares to the snapshot frontmatter. On drift, emits `<governance-warning reason="snapshot-stale">…</governance-warning>` on stdout — the agent regenerates inline (factory-governance-loading SKILL § Step 1 POST-LOAD) or runs `/setup --upgrade`. | Advisory only — never blocks the prompt. Carve-out: prompts starting with `/setup*` bypass the gate. Silent no-op when the project is not yet initialized. |
| **3 — Attribution** | `PostToolUse Edit\|Write` → `UserPromptSubmit` | `scripts/governance-onedit.sh` writes `.claude/state/governance-source-edited-{session_id}.marker` listing the changed paths; the next `scripts/governance-onprompt.sh` emits `<governance-source-edited paths="...">` with cause attribution + explicit regen instruction, then consumes the marker. Suppresses the tier-2 `<governance-warning>` for that prompt — the agent already knows why the snapshot is stale. | Marker write degrades silently when neither `jq` nor `python3` is available; tier 2 then fires its plain warning instead. |
| **4 — Resilient** | `PreCompact` → `UserPromptSubmit` | `scripts/governance-oncompact.sh` writes `.claude/state/governance-reload-{session_id}.marker`; the next `scripts/governance-onprompt.sh` emits the snapshot wrapped in `<governance-reload>...</governance-reload>` on stdout, which Claude Code appends to the next turn as additional context, then consumes the marker. | Post-compaction re-injection is lossy if `PreCompact` never fires (some IDE harnesses). Tiers 1 + 2 + 3 still operate. |

**Why 4 tiers (and not 1):** tier 1 makes governance visible so the user can spot when it fails to load. Tier 2 surfaces drift as an advisory the agent can act on without livelocking on the very session that produced it. Tier 3 attributes the cause when the staleness was self-inflicted (an EVOL/ADR edit) so the agent gets a richer instruction instead of a generic warning. Tier 4 survives summarization — without it, the snapshot would evaporate from the LLM's window after compaction even while the snapshot file on disk is still valid.

**Marker scoping.** Both markers (`governance-reload-{session_id}.marker` and `governance-source-edited-{session_id}.marker`) live under `.claude/state/` — inside the Claude Code hook namespace, gitignored, and suffixed with the session ID passed in the hook stdin JSON. Two Claude sessions running against the same repo cannot collide on each other's replays.

**Smoke tests** (project-local):

1. Open a fresh session → the banner line is printed.
2. Edit `docs/constitution.md` from inside the agent without regenerating the snapshot → the next prompt receives `<governance-source-edited paths="docs/constitution.md">` with regen instruction (no plain warning). Edit it from outside the agent (manual `vi`) and the next prompt receives the plain `<governance-warning reason="snapshot-stale">` instead — both paths reach the agent, neither blocks.
3. Force a conversation long enough to trigger `PreCompact` → the following turn contains `<governance-reload>…</governance-reload>` with the full snapshot in context.

See [scripts/validate-governance.sh](scripts/validate-governance.sh), [scripts/governance-onprompt.sh](scripts/governance-onprompt.sh), [scripts/governance-onedit.sh](scripts/governance-onedit.sh), [scripts/governance-oncompact.sh](scripts/governance-oncompact.sh), and [.claude/settings.json](.claude/settings.json).

**Companion: IPP runtime binding.** The same PostToolUse → UserPromptSubmit marker pattern powers a parallel enforcement chain for the Incremental Persistence Protocol. `check-ipp-compliance.sh` (PreToolUse Write) drops `.claude/state/ipp-first-write-{session_id}.marker` after a legitimate skeleton write; `governance-onedit.sh` Block 2 (PostToolUse Edit\|Write) detects Pillar 2 violations (filled sections outpacing `_progress.completed_sections`) and drops `.claude/state/ipp-pillar2-{session_id}.marker`; `governance-onprompt.sh` Block 2b (UserPromptSubmit) emits `<ipp-reminder>` (teaching, post-skeleton) and `<ipp-warning reason="pillar-2-violation">` (corrective) tagged blocks on stdout, consuming the markers. The chain is independent of the four governance-source tiers and operates on artefact-integrity concerns. See [factory-incremental-persistence/SKILL.md § Runtime Binding](.claude/skills/factory-incremental-persistence/SKILL.md) for the canonical specification.

### Scope model — project scope + feature scope

The framework governs two orthogonal scope axes:

| Axis | Lives in | Set at | Drives |
|------|----------|--------|--------|
| **Project scope** | `docs/setup.md` `project_scope` field + governance snapshot | `/setup --init` (once per project) | Materialisation conditionals (frontend vs backend scaffolding, UX Constitution), discovery-question unlocks, CODESIGN `--vision` availability |
| **Feature scope** | `spec.feature` frontmatter `scope` field | `/codesign --start --scope=…` (per feature; defaults to project_scope) | Per-feature agent behaviour (Scope Compatibility Gate, Template Selector, Tripartite Alignment), auto-approval N/A paths, DC filtering, REVIEW check filtering, QA smoke template variant, DEVOPS target derivation, Preventive Sweep DC filter, backlog `scope:*` label + smoke-e2e-* phase variant |

**Enum:** `full-stack | backend-only | frontend-only | integration`. `integration` is the semantic alias of `backend-only` emphasising third-party adapters (webhooks, payment gateways, SaaS connectors, cron jobs, queue consumers).

**Compatibility matrix** (enforced at CODESIGN `--start` by the Scope Compatibility Gate):

| project_scope \ feature.scope | full-stack | backend-only | frontend-only | integration |
|---|---|---|---|---|
| `full-stack`    | ✅ | ✅ | ✅ | ✅ |
| `backend-only`  | ❌ | ✅ | ❌ | ✅ |
| `frontend-only` | ❌ | ❌ | ✅ | ❌ |
| `integration`   | ❌ | ✅ | ❌ | ✅ |

**Cross-feature contracts:** `spec.feature.consumes_contract: [FEAT-XXX]` declares upstream-frozen-contract dependencies. Enforced at three points — BLUEPRINT `--start` Consumes-Contract Resolution Gate, IMPLEMENT `--plan` Consumes-Contract Upstream Freeze Gate, and the Next-Task Resolver cross-feature filter. Iteration Model cascade (`ON_BLUEPRINT_CONTRACT_CHANGE` → `CASCADE_CONSUMERS`) re-opens every downstream consumer's CONTRACT-FREEZE when an upstream contract iterates.

#### Example — backend-only integration feature inside a full-stack project

```
# Setup (one-time, sets project_scope)
/setup --init
   # Q4.5: project_scope = full-stack  (project also has a UI for other features)

# Create a backend-only integration feature (e.g. Stripe webhook handler)
/codesign --start FEAT-039 --scope=backend-only
   # Scope Compatibility Gate: full-stack project accepts backend-only feature ✅
   # Template Selector:
   #   spec.feature             → gherkin_master_template.feature
   #   user_journey.integration → user_journey.integration.md (caller-side flows, reliability contract)
   #   mock.html                → N/A (skipped; no UI)
   # Auto-approval: 12-check gate degrades to ~6 applicable checks (UX checks N/A)

/blueprint --start FEAT-039
   # Reads feature.scope=backend-only from spec.feature frontmatter
   # Produces: design.md (contract-first, § 3.2 Wire-Format Mapping replaces § 3.1 Cross-Layer Type Mapping)
   #           test_plan.md (includes § 2.2 Reliability Testing: REL-IDEMP, REL-RETRY, REL-CB, REL-DLQ, REL-SHUTDOWN, REL-OBS)
   #           OpenAPI 3.1 webhook contract in contracts/webhooks/inbound/stripe/v1.yaml

/blueprint --approve FEAT-039
   # Part 1 ARCH elevates contract-completeness (backend-only has no UI surface to fall back on)
   # Part 2 QA: visual-consistency tests N/A; reliability tests BLOCKER if missing

# CONTRACT-FREEZE issue Done → IMPLEMENT gate unlocks

/backlog --plan-feature FEAT-039
   # Materialises 8 phase issues; suffix 8 gets phase:smoke-e2e-integration label (scope=backend-only → integration variant)
   # All 8 issues also get scope:backend-only label

/devops --configure FEAT-039
   # Scope-aware target derivation: function → serverless (Lambda); compute → worker
   # Reliability DCs consulted: idempotency, retry, DLQ, graceful shutdown all projected into devops_plan.md § Reliability Checks

/implement --plan FEAT-039
   # CONTRACT-FREEZE gate + Consumes-Contract Upstream Freeze Gate pass
   # dev_plan.md includes § Reliability Tests (7 RED-phase tasks)
   # REVIEW dispatcher filters UX checks to N/A; contract/DRY/security/reliability all active

/implement --build FEAT-039
   # REVIEW Check #7 [UX-*] reports "N/A — skipped under scope=backend-only" in peer_review § 3.7

# PREVENTIVE-SWEEP sub-agents filter DCs by scope → only backend + cross-cutting + infra scopes swept

/qa --verify FEAT-039
   # SMOKE-E2E gate: scope-aware smoke template selected (smoke_e2e_integration_template.md)
   # SMOKE-REL-* blocks MANDATORY (for scope=integration); test_plan § 2.2 rows verified
   # Verification checklist includes QA-REL-1..7 reliability items
```

#### Example — frontend-only feature consuming the backend-only feature's frozen contract

```
/codesign --start FEAT-042 --scope=frontend-only --consumes-contract=FEAT-039
   # Scope Compatibility Gate: full-stack project accepts frontend-only feature ✅
   # Declares upstream dependency on FEAT-039 (the backend integration)

/blueprint --start FEAT-042
   # Consumes-Contract Resolution Gate: verifies FEAT-039 design.md APPROVED + contracts/** non-empty ✅
   # Loads FEAT-039 frozen contract, surfaces read-only into design.md § 7 GCD
   # Produces UI components against the real endpoint shape — no invented fields

# If FEAT-039 contract changes later (upstream re-approval):
#   Iteration Model ON_BLUEPRINT_CONTRACT_CHANGE → CASCADE_CONSUMERS finds FEAT-042 in consumes_contract
#   → FEAT-042 design.md / test_plan.md / dev_plan.md marked CASCADE_PENDING_ITERATION
#   → FEAT-042 CONTRACT-FREEZE issue re-opened with stale-after-cascade label
#   → BLUEPRINT --refine FEAT-042 required before IMPLEMENT can continue
```

#### Example — backend-only PROJECT (no UI anywhere)

```
/setup --init
   # Q9: frontend.framework = None → Q4.5 inference: project_scope auto-resolves to backend-only
   # SETUP skips: ux-constitution materialization, frontend rules, frontend directory scaffolding, frontend discovery Q10-Q14

/codesign --start FEAT-001
   # Scope Compatibility Gate: project_scope=backend-only rejects --scope=full-stack / --scope=frontend-only
   # Default feature.scope = backend-only (inherited from project)
   # --scope=integration also accepted (semantic alias)

# CODESIGN --vision is BLOCKED by the Scope Guard (backend-only projects have no UI surface)

# ... rest of lifecycle identical to the backend-only feature flow above (every feature gets phase:smoke-e2e-integration)
```

### SDLC-first triage (MANDATORY)

Complements governance always-on with a **behavioural** rule: every user request — slash command or free-form chat — must first be classified against the SDLC command catalogue. If the request maps to a command, the agent announces the routing in one line and executes the command instead of the raw action; if it does not map, the agent articulates in one line why it does not map before acting directly. Silence is a governance-scope violation.

The rule lives in two places depending on context (framework/project split):

- [.context/templates/setup/claude/CLAUDE.md § SDLC-First Triage](.context/templates/setup/claude/CLAUDE.md) — the materialized-project variant (SDLC-first is the default; carve-outs for read-only, docs-only fast-lane, trivial edits).
- [CLAUDE.md § Meta-Framework Triage](CLAUDE.md) — the framework-repo variant (meta-maintenance is the default; SDLC routing is the rare exception).
- [.claude/instructions/Factory-protocol-iop-intent-map.instructions.md](.claude/instructions/Factory-protocol-iop-intent-map.instructions.md) — the canonical technical classifier (IOP v1.1.0) that both variants point at.

### Cross-Cutting Skills (Protocols)

The framework ships protocols reusable by every command:

| Skill | Purpose |
|-------|---------|
| **Build Verification Loop (BVL)** | Real test execution in terminal, error parsing, auto-fix (max 3 attempts), Full Verification Gate (tests + lint + typecheck + build). Uses BVL Commands Cache (`/memories/repo/`). |
| **Incremental Persistence (IPP)** | Skeleton-first write, section-atomic saves, resume-on-entry. Survives context summarization. |
| **Codebase Inventory (CIP)** | Cross-command DRY inventory. CIP Canary gate prevents duplication post-summarization. Uses Inventory Cache (`/memories/repo/`). |
| **Governance Loading (GCRP)** | Zero Trust context recovery. Dual-hash snapshot (constitution + setup). Summarization-safe. |
| **Iteration Model** | Domain-driven incremental development. Cascading invalidation on upstream spec changes. |
| **Branching Strategy (SCM)** | Branch enforcement, merge policy, concurrency locks, auto-checkout protocol. |
| **Agent Communication (ACP)** | Controlled verbosity: entry announcement, phase milestones, completion summary. |
| **Commit Prompt** | Auto-generated conventional commit messages post-command. |
| **Worklog** | Per-feature JSONL audit trail. Action registration and phase mapping. |
| **Memory Cache Protocol (MCP)** | Unified acceleration layer via `/memories/repo/`. Caches for Feature State, BVL Commands, CIP Inventory, and the Execution Plan. |
| **Coherence Validation (CVP)** | Cross-artifact traceability and completeness validation. |
| **Backlog Next-Task Resolver** | Dual-mode resolver: push (`--next-task`, single item) and pull (`--eligible`, full pool). Shared filters: intra-feature prereq + `blocked-by:#{N}` + gate-mode fallback (enforce/warn/off). Fast path via cache at `/memories/repo/`. |
| **Defect Prevention Catalog (DPC)** | Living catalog of runtime defect patterns invisible to static gates. Consumed by 7 agents (CODESIGN, BLUEPRINT, IMPLEMENT, REVIEW, DEVOPS, QA, AUDIT) filtered by `applicable_to`. Discover-catalog-prevent loop closed by the `[EPIC-{N}] RETROSPECTIVE` write-back. Universal starter DCs (pipeline SIGPIPE, identity no-op, framework validation invisible, mutation replace semantics, composite network triage) + stack-conditional DCs. |
| **Preventive Sweep** | Pre-deploy runtime defect scan via parallel Explore sub-agents — one per non-overlapping scope derived from the DPC. Zero open C-severity findings required to approve. |

### Rule Categories

**Critical (every project):** `architecture.md`, `stateless.md`, `security_policy.md`, `protected-code.md`, `contract-first-policy.md`, `testing.md`.

- `+ ux-constitution.md` (when UI exists), `+ database.md` (when a DB exists), `+ api-standards.md` (when APIs exist).

**Tech-Specific (only when the stack matches):** `python.md`, `React.md`, `java.md`, `node.md`, `csharp.md`, …

> **Philosophy:** if a rule file exists in `.claude/rules/` → it applies to EVERY feature (project-level, not feature-level).

### Hybrid Validation

| Type | What it Validates | Example |
|------|-------------------|---------|
| **Semantic (LLM)** | Code patterns, architectural violations | `pickle.loads()`, `eval()`, `dangerouslySetInnerHTML`, SQL injection, absolute paths |
| **Script (deterministic)** | Dependencies, configuration, secrets | `dependency-allowlist.sh`, `check-integrations.sh`, `security-scan.sh` |

### Mandatory Validation Checkpoints

| Checkpoint | What it Validates |
|-----------|-------------------|
| `/blueprint --approve` | Contracts, UX compliance, protected code, system resources |
| `/implement --build` (REVIEW) | Security patterns, architecture, accessibility, protected paths |
| `/implement --build` (SEC) | SAST patterns, secrets, vulnerabilities |
| `/qa --verify` | dependency-allowlist (BLOCKING), integration config, DAST |

### Zero-Tolerance Model

- **GREEN ZONES (new code):** CRITICAL / HIGH violations → BLOCK immediately with a YAML report.
- **RED ZONES (legacy code):** no validation (exempt). Modifications require ADR approval.

---

## Memory Cache Architecture

The framework uses `/memories/repo/` as an acceleration layer to eliminate redundant file reads between commands. On-disk files remain the source of truth (SSOT).

### Active Caches

| Cache | Location | Source (SSOT) | Consumed by | Invalidation |
|-------|----------|---------------|-------------|--------------|
| **Feature State** | `/memories/repo/feature-state-cache.md` | `docs/spec/*/` frontmatters | Smart Redirect | Status change on any artifact |
| **BVL Commands** | `/memories/repo/bvl-commands-cache.md` | `.context/governance_snapshot.md` | `/implement --build`, `--fix` | Governance snapshot change |
| **CIP Inventory** | `/memories/repo/codebase-inventory-cache.md` | `config/codebase_inventory.json` | `/blueprint`, `/implement`, `/codesign` | Inventory modification |
| **Execution Plan** | `/memories/repo/execution-plan-cache.md` | `docs/backlog/execution-plan.md` (local mode) | Next-Task Resolver | `--plan-execution`, `--update-execution`, `--sync-execution` |
| **Project Board** | `/memories/repo/project-board-cache.md` | External tracker (board mode) | Next-Task Resolver | Any board mutation via adapter |

### Design Principles

1. **SSOT on disk (or board).** On-disk artifacts (or the board in external mode) are ALWAYS the authoritative source. Caches are accelerators, never primary sources.
2. **Write-Through.** When a command mutates a source artifact, it updates the matching cache immediately.
3. **Hash validation.** Every cache stores its source hash; reads validate the hash; stale entries regenerate from the source.
4. **Graceful degradation.** Cache failures fall back to the slow path (direct read). NEVER block a command on a cache failure.
5. **No cross dependencies.** Caches read from sources, NEVER from other caches.

See `Factory-memory-cache/SKILL.md` for the complete protocol.

---

## Immutability and Versioning

Once an artifact is **APPROVED** with downstream work APPROVED, it becomes **immutable**.

### Solution: Automatic Versioning

```
Original:     USR-001
Revision 1:   USR-001-v2
Revision 2:   USR-001-v3
Hotfix:       USR-001-v2.1 (security emergencies only)
```

### Command: `/codesign --revise`

```
/codesign --revise USR-001 "Add OAuth authentication"
```

- Creates `docs/spec/USR-001-v2/` with parent links.
- Marks `USR-001` as `APPROVED (SUPERSEDED)`.
- Downstream artifact inheritance (test_plan, design) available.
- Maximum one active version (forced linearity).

See `.claude/rules/immutability_policy.md` for the full rules.

---

## Directory Structure

### Project Structure (after `/setup --generate`)

```
docs/
├── technical_due.md                # (optional) AUDIT report
├── setup.md                        # Setup state tracker
├── constitution.md                 # Project constitution (tech stack, rules)
├── rules/                          # Technology-specific governance rules
├── spec/{FEATURE_ID}/              # Per-feature workspace
│   ├── spec.feature                #   Gherkin BDD (CODESIGN)
│   ├── mock.html                   #   Visual mockup (CODESIGN)
│   ├── user_journey.md             #   Event Storming + Data Schemas (CODESIGN)
│   ├── design.md                   #   Architecture (BLUEPRINT)
│   ├── test_plan.md                #   Test strategy (BLUEPRINT)
│   ├── dev_plan.md                 #   Implementation plan (IMPLEMENT)
│   ├── devops_plan.md              #   Infrastructure plan (DEVOPS)
│   ├── adr/                        #   Architecture Decision Records
│   └── qa/                         #   QA verification reports
├── backlog/                        # Project tracking (BACKLOG — SSOT mode-dependent)
│   ├── project-config.json         #   External mode: non-sensitive connection params
│   ├── state.md                    #   Local mode: feature issue registry + Kanban
│   └── issue-bodies/               #   Local mode: issue body markdown files
├── ux/vision/                      # Global UX vision artifacts
└── project_log/                    # Worklog, migration reports
contracts/                          # API contracts (OpenAPI, GraphQL, gRPC, AsyncAPI)
config/                             # system_resources.json, infrastructure_registry.json
infra/                              # Infrastructure as Code (modules/ + features/)
scripts/                            # Automation & CI/CD scripts
src/ (or apps/)                     # Source code (created by IMPLEMENT, not by scaffolding)
tests/                              # Test infrastructure (config only — tests created by IMPLEMENT)
```

### Scaffolding Philosophy

**What `/setup --generate` creates:** directory structure, configuration files (100% functional), type definitions, documentation, CI/CD pipelines, declarative schemas.

**What it does NOT create:** source code, components, test files, business logic, API routes — all generated by `/implement --build` during the TDD cycle.

This ensures CI/CD pipelines pass from day 1 (no stub code = no lint/compile errors).

---

## Security

| Control | Tool | When |
|---------|------|------|
| **SAST** | Semgrep, custom patterns | `/implement --build` (per phase, inline) |
| **Secret scanning** | Gitleaks, regex patterns | `/implement --build` + `/qa --verify` |
| **DAST** | OWASP ZAP | `/qa --verify` (post-staging) |
| **Dependency audit** | `dependency-allowlist.sh` | `/qa --verify` (BLOCKING) |
| **Secret management** | `.env` (local) + Vault/cloud (prod) | Always — hardcoded secrets = BLOCK |

---

## Troubleshooting

**Slash commands not appearing?**

- Verify Claude Code is installed and active (CLI: `claude`, or IDE extension).
- Check `CLAUDE.md` exists in the repository root.
- Check `.claude/commands/` contains the command `.md` files.

**Command stuck in `NEEDS_INFO`?**

- Check the artifact frontmatter for pending questions.
- Use `/command --refine {ID} "Your answer"` to unblock.

**RED ZONE violation blocking a build?**

- Create an ADR: `/blueprint --adr {ID} "Justification for protected code change"`.

---

## License

e2its is an unregistered trademark used as a project and domain identifier. The holder of the domain e2its.com retains all rights over the software and the brand, without implying official registration.

This software is provided under a custom End User License Agreement (EULA). See [EULA.md](./EULA.md) for details.

---

## Support

- **Issues**: GitHub Issues.
- **Discussions**: GitHub Discussions.
- **Core docs**: [CLAUDE.md](CLAUDE.md), [EULA.md](EULA.md). The project constitution is materialised per target project at `docs/constitution.md` by `/setup --generate` — it does not exist in this framework repository.
