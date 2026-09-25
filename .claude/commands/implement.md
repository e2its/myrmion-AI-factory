# IMPLEMENT — Full Implementation Lifecycle

> **One planning stage (EVOL-048).** This command owns a planning phase — the implementation plan (`--plan` → dev_plan.md) — so it **never enters the harness's plan mode** (`EnterPlanMode`): a second approval would appear to cover decisions the user never made. Its own RDRs and approval steps are the one stage; the pre-write gate (`gate.py plan`) treats its branch class as planned by this phase.

This command delegates by name to the phase agent `factory-implement` (`.claude/agents/factory-implement.md`; `spawn-policy: phase` — the main session spawns it on the writer family, `python3 scripts/gate.py agents --resolve --class phase`, and hands it its corpus digest) for the plan and the increment bookkeeping. The build loop runs in the **main session** — no agent carries `Agent`, a subagent does not nest — which spawns by name (`rules/agents.md`):
- **the workers** (`factory-dev-backend` / `-frontend` / `-platform` / `-e2e`): pragmatic, TDD-first. Write code per surface.
- **the work critics** (`factory-critic-correctness` / `-governance` / `-fidelity`): read-only, pedantic governance guardians. Verify code quality, architecture compliance, and standards — they did not write the code.
- **the security lens** (`factory-critic-security`): read-only, paranoid, Zero Trust. Scans for vulnerabilities, enforces security policies.

One worker↔critic round per completed diff, then the user adjudicates. No subagent commits, no subagent decides.

**Arguments:** $ARGUMENTS

## Step 0 — Applicability Roll-Call (MANDATORY)

Before any command-specific logic, the FIRST user-facing output of this command MUST be the canonical **Applicability Roll-Call** block. Invoke `factory-applicability-discovery` to produce it.

- Discovery is **live** — frontmatters scanned fresh from `.claude/instructions/*.instructions.md`, `.claude/skills/Factory-*/SKILL.md`, and `.claude/rules/defect-prevention.md` entries. New ADRs/DCs/instructions appear automatically the next turn.
- Block format and full algorithm: `.claude/skills/factory-applicability-discovery/SKILL.md` § Output.
- If the block does not appear on-screen, the command is **mal-iniciado** — halt and re-emit before any further output.
- This step runs BEFORE Step -1 (branch checkout). Step -1 still executes as the next mandatory pre-action gate.


## Commands

### `--plan {ID}`

Beat 0 (EVOL-056): before the plan, the main session spawns the read-only `factory-docs-reader` on the libraries and services of the surface and hands its sources to `factory-implement`; every external claim in dev_plan.md cites its source (`Factory-implement-plan` § Beat 0).
Create implementation plan. PREREQUISITE: design.md + test_plan.md APPROVED. Vision APPROVED for frontend.

**Full protocol:** See `.claude/instructions/Factory-implement-plan.instructions.md`
- Decompose design into implementation phases (A: core domain/backend, B: frontend/UI when applicable, C: integration)
- Map test_plan.md test cases to implementation phases
- Generate `dev_plan.md` with ordered tasks, estimated effort, dependencies

### `--build {ID}`
Execute implementation. Iterates through phases A → B → C.

**Full protocol:** See `.claude/instructions/Factory-implement-build.instructions.md`
- **MCP Docs Scan banner (MANDATORY)** — emits `🔌 MCP Docs Scan — ...` as first line; the worker consults named docs MCPs before generating code for matching technologies (see `.claude/skills/factory-mcp-docs-scan/SKILL.md`).
- Per phase: the worker implements (TDD: test first → code → green) → the work critics verify (read-only, one round) → the security lens scans (SAST) → the user adjudicates what stays open
- Fix loops happen inline within each phase
- After ALL phases complete: Draft PR created automatically
- **Completion Gate:** ALL tasks in dev_plan.md MUST be `[x]` before status → `IMPLEMENTED_AND_VERIFIED`

### `--refine {ID}`
Handle upstream spec changes via Delta Iteration or user feedback. Only modifies files affected by the change.

**Full protocol:** See `.claude/instructions/Factory-implement-build.instructions.md` (Refine section)

**Six sub-steps**:
- **3.1 Locate changes** — Upstream Artifact Validation (existing); also read `design.md.pending_design_items[]` so BLUEPRINT carry-over becomes explicit delta tasks.
- **3.2 Analyze dev_plan state** — read frontmatter status + based_on_iteration; map upstream changes to affected phases/increments.
- **3.3 Coherence validation (CVP)** — `cvp_coherence_gate(FEATURE_ID, CODESIGN_BLUEPRINT_IMPLEMENT, IMPLEMENT)` **AFTER** delta task generation (validates the delta closes cross-artefact gaps; loop up to 3 rounds; mirrors BLUEPRINT --approve sequencing). PREREQ: `design.md.pending_iteration` cleared by BLUEPRINT --refine (Step 0a Upstream Sync Gate enforces).
- **3.4 MCP-docs consultation** — invoke `factory-mcp-docs-scan` (banner mandatory as first line); cite consulted MCPs in delta task descriptions; populate `mcp_consulted: [...]` on iteration entry.
- **3.5 Update dev_plan** — generate `[D.N]` / `[ADJ-N]` / `[CARRIED_OVER.N]` checkbox tasks tagged with `origin: ITER-{FEAT}-{N}` and `task_class: NEW | EXISTING | MODIFIED | CARRIED_OVER`.
- **3.6 Aggregated changelog as checklist** — `append_iteration_entry()` on `dev_plan.md` with `delta_tasks: [...]` field; --build reads unchecked items from BOTH legacy phase/increment sections AND iteration anchor as one completion total.

After refine: status → READY. Completion Gate applies to ALL tasks (original + delta + adjustment + fix + carried-over).

### `--finalize {ID}`
Plan-level aggregate retry. ONLY applicable under `slicing_strategy: incremental` when every entry of `dev_plan.frontmatter.increments[]` is `IMPLEMENTED_AND_VERIFIED` AND the global `dev_plan.status` is still `BUILDING` (the last-slice closure ran but the plan-level BVL aggregate failed). Re-runs `full_verification_gate(FEATURE_ID, null)` and, on PASSED, flips the global status. BLOCKS in any other state with humanized redirect (slice still pending → run `--build {ID} INC-N`; QA reject → `--fix {ID}`; nothing pending → already finalized).

**Full protocol:** See `.claude/instructions/Factory-implement-build.instructions.md` (Finalize section)
- Validate per-increment closure invariant (all increments[].status == IMPLEMENTED_AND_VERIFIED).
- Flip `dev_plan.status` to `IMPLEMENTED_AND_VERIFIED` FIRST (the last tracked write), then execute `full_verification_gate(FEATURE_ID, null)` once on those bytes (EVOL-051).
- On PASSED → the seal is green; worklog the transition; commit.
- On BLOCKED → revert the flip (fields removed, status BUILDING), emit the loop's findings; per-increment statuses remain untouched.

### `--fix {ID}`
Bug fix flow. Can be triggered by QA rejection or DEVOPS smoke test failure.

**Full protocol:** See `.claude/instructions/Factory-implement-build.instructions.md` (Fix section)
- Analyze failure source (QA report blockers, smoke test logs, user report)
- Generate `- [ ] [FIX-N]` checkbox tasks in dev_plan.md under new `## Fix Tasks` section
- Execute each fix task (TDD: reproduce → fix → green) → mark `[x]` on completion
- **Completion Gate applies to ALL tasks** (original + delta + adjustment + fix) — zero unchecked allowed
- After fix complete: dev_plan.md returns to `IMPLEMENTED_AND_VERIFIED`, qa_report set to `INVALIDATED`

## Output
All under `docs/spec/{ID}/`:
- `dev_plan.md` — Implementation plan with phases and tasks
- Source code following project architecture
- Tests (unit, integration) following TDD
- `peer_review_{ts}.md` — work-critic findings (correctness · governance · fidelity lenses)
- `sec_audit.md` — security lens analysis

## Incremental Dev Plan Integration

IMPLEMENT is **strategy-aware**. The entry point reads `spec.feature.slicing_strategy`:

- `incremental` (default): `--plan` emits `dev_plan.md` with one `## Increment INC-N` section per entry in `increment_plan.md`. Task tags follow `[INC-N.A.M]` / `[INC-N.B.M]` / `[INC-N.C.M]` + `[INC-N.ACC.k]` for acceptance. `--build {ID} INC-N` executes one increment at a time; branch per increment is `feature/{FEATURE_ID}-inc-N-{slug}` (one open branch per feature, concurrency lock reused). The plan-level `IMPLEMENTED_AND_VERIFIED` only fires when every target increment closes; individual increments transition through `DRAFT → READY → BUILDING → MERGED` monotonically. MERGED is terminal for that increment — further scope change goes into a Follow-up Increment.
- `monolithic` (Trivial-Heuristic escape, rare): legacy `[A.M]` / `[B.M]` / `[C.M]` task tagging, single feature branch `feature/{FEATURE_ID}-{slug}`, one PR.

**Increment Plan Gate** at `--plan`: BLOCK if `increment_plan.md` status ≠ APPROVED. `--refine` respects per-increment lifecycle — only `DRAFT` / `READY` may be invalidated by cascade; `MERGED` anchors production and cascades to a Follow-up Increment instead.

Canonical protocol: [Factory-implement-plan.instructions.md](../instructions/Factory-implement-plan.instructions.md) § Increment Plan Gate / § Strategy Branch. Immutability rules: `.claude/rules/immutability_policy.md § Per-Increment Immutability`.

## Review Checks
See `.claude/instructions/Factory-implement-review-checks.instructions.md` for the complete REVIEW + SEC checklist.

## Key Principles
- TDD: 1 Logic = 1 Unit Test. Test FIRST, code SECOND.
- DRY: Check `config/codebase_inventory.json` before creating new artifacts
- Security: Zero secrets in code, parameterized queries, input sanitization
- Traceability: `// Generated by Phase: IMPLEMENT | Feature: {ID}`
- **Completion Gate (two levels under `slicing_strategy: incremental`):**
  - **Per-increment:** NEVER flip `dev_plan.frontmatter.increments[INC-N].status` to `IMPLEMENTED_AND_VERIFIED` unless ALL `[INC-N.*]` tasks (incl. `[INC-N.ACC.k]`) are `[x]`, the increment's `peer_review_{INC-N}_*.md` is APPROVED, and BVL `full_verification_gate(FEATURE_ID, INC-N)` returns PASSED.
  - **Plan-level (derived):** the global `dev_plan.status: IMPLEMENTED_AND_VERIFIED` flips ONLY when every entry in `dev_plan.frontmatter.increments[]` has `status: IMPLEMENTED_AND_VERIFIED` AND a final aggregate loop run AFTER the flip (the flip is the last tracked write; a red loop reverts it — EVOL-051) (`full_verification_gate(FEATURE_ID, null)`) passes — never written manually.
  - Under `slicing_strategy: monolithic` the gate is single-level: all `[ ]` → `[x]`, then `dev_plan.status` flips (the last tracked write), then the one full loop seals the bytes and the commit follows (EVOL-051). Applies to ALL task types: original `[A/B/C.N]`, delta `[D.N]`, adjustment `[ADJ-N]`, and fix `[FIX-N]`.
- **Checkbox-Driven Execution:** Every actionable task (build, refine, fix) MUST be represented as a `- [ ]` checkbox in dev_plan.md BEFORE execution. Read unchecked items, execute them, and mark `[x]` atomically. No task completes without a checkbox.
- **Upstream Validation on --refine:** ALWAYS diff upstream artifacts against dev_plan references. New/modified upstream scenarios MUST produce delta tasks.
- **Iteration Changelog:** Every `--refine` MUST append a changelog entry to dev_plan.md (date, iteration, source of change, affected tasks, downstream impact).
- **Worklog Attribution:** `APPEND_TO_WORKLOG` with `user_agent: "IMPLEMENT"` — always the actual agent, never a default.
- **User Communication:** Follow Agent Communication Protocol (`.claude/skills/factory-agent-communication/SKILL.md`) — entry announcement, phase milestones (5 phases for --build), completion summary.
- `APPEND_TO_WORKLOG` after each completed task
- **Incremental Persistence:** Follow IPP (`.claude/skills/factory-incremental-persistence/SKILL.md`) — skeleton for dev_plan.md (--plan), task-atomic saves (--build), resume from first unchecked [ ] task.

## Pre-Command Protocol (MANDATORY)
- **Before ANY file modification**, execute the full **Step -1 Auto-Branch Checkout Protocol** from `.claude/skills/factory-branching-strategy/SKILL.md`
- This ensures correct branch checkout, cross-branch mismatch detection, dependency checks, and concurrency locking
