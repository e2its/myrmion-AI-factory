# BLUEPRINT — Technical Co-Design

> **One planning stage (EVOL-048).** This command owns a planning phase — the design and the increment plan — so it **never enters the harness's plan mode** (`EnterPlanMode`): a second approval would appear to cover decisions the user never made. Its own RDRs and approval steps are the one stage; the pre-write gate (`gate.py plan`) treats its branch class as planned by this phase.

This command delegates by name to the phase agent `factory-blueprint` (`.claude/agents/factory-blueprint.md`; `spawn-policy: phase` — the main session spawns it on the writer family, `python3 scripts/gate.py agents --resolve --class phase`, and hands it its corpus digest; the Plan Gate's critic is spawned by the main session too, never by the phase agent) — ONE context carrying both concerns of the technical solution and its test strategy:
- **ARCH (architecture)**: Authoritative, patterns-focused, contract-first. Designs architecture, module boundaries, API contracts.
- **QA (test strategy)**: Skeptical, edge-case focused, coverage-driven. Designs test strategy, identifies failure modes, validates coverage.

Cross-pollination is inline: ARCH contracts inform QA test cases, QA edge cases refine ARCH error handling. Before `--approve`, the read-only `factory-plan-critic` gates the plan — at most `rounds.plan_gate` rounds, then the user adjudicates by RDR (`Factory-blueprint-design.instructions.md § Plan Gate`).

**Arguments:** $ARGUMENTS

## Step 0 — Applicability Roll-Call (MANDATORY)

Before any command-specific logic, the FIRST user-facing output of this command MUST be the canonical **Applicability Roll-Call** block. Invoke `factory-applicability-discovery` to produce it.

- Discovery is **live** — frontmatters scanned fresh from `.claude/instructions/*.instructions.md`, `.claude/skills/Factory-*/SKILL.md`, and `.claude/rules/defect-prevention.md` entries. New ADRs/DCs/instructions appear automatically the next turn.
- Block format and full algorithm: `.claude/skills/factory-applicability-discovery/SKILL.md` § Output.
- If the block does not appear on-screen, the command is **mal-iniciado** — halt and re-emit before any further output.
- This step runs BEFORE Step -1 (branch checkout). Step -1 still executes as the next mandatory pre-action gate.


## Commands

### `--start {ID}`
Begin technical design for a feature. PREREQUISITE: spec.feature + user_journey.md APPROVED (+ mock.html APPROVED for scope in [full-stack, frontend-only]), and (when `slicing_strategy: incremental`) `slice_map.md` APPROVED — BLUEPRINT refines CODESIGN's value-slices, it does not invent them. Absent slice_map on an incremental feature → BLOCK (run `/codesign` first).

**Full protocol:** See `.claude/instructions/Factory-blueprint-design.instructions.md`
- Architecture design (components, sequences, contracts)
- Test plan co-creation (unit, integration, E2E, security)
- Contract generation (OpenAPI/GraphQL/gRPC/AsyncAPI based on communication_style)
- **MCP Docs Scan banner (MANDATORY)** — emits `🔌 MCP Docs Scan — ...` as first line, consulted docs MCPs cited in design.md (see `.claude/skills/factory-mcp-docs-scan/SKILL.md`).

### `--refine {ID}`
Iterate on `design.md` / `test_plan.md` / `increment_plan.md` on upstream cascade or implementation-state drift.

**Full protocol:** See `.claude/instructions/Factory-blueprint-refine.instructions.md`.

**Eight sub-steps**:
- **2.1 Locate changes** — diff upstream since last cascade.
- **2.2 Analyze design state** — sections + contract ops + test categories affected.
- **2.3 Dependencies analysis** — extend Step -0.5 from `--start`; surface affected `consumes_contract` chains.
- **2.4 Impl-state probe (auto)** — fires when `dev_plan.md` has `[x]` tasks OR feature branch has commits beyond design. Classifies `drift | carry-over | emergent`.
- **2.5 Update design with gaps** — drift→modify (RDR if multi-option); carry-over→`pending_design_items[]` + `## Carried-Over Gaps`; emergent→ADR.
- **2.6 MCP-docs consultation** — invoke `factory-mcp-docs-scan` (banner mandatory as first line); populate `mcp_consulted: [...]` on iteration entry; cite consulted MCPs inline in design.md.
- **2.7 Apply changes** — IPP section-atomic saves; `CASCADE_PENDING_ITERATION` to dev/devops/contracts; `CASCADE_CONSUMERS` for contract changes.
- **2.8 Aggregated changelog** — `append_iteration_entry()` on all three artefacts with shared `ITER-{FEAT}-{N}` id.

### `--approve {ID}`
Final approval of design.md + test_plan.md. Enables IMPLEMENT. **This is the ONLY mandatory manual checkpoint.** Runs the Plan Gate first (`factory-plan-critic`, ≤ `rounds.plan_gate` rounds; open findings go to the user by RDR — no agent ratifies).

### `--adr {ID}`
Create Architecture Decision Record for significant design choices.

### `--review-conflict {ID}`
Review and resolve conflicts between design artifacts.

## Output
All files under `docs/spec/{ID}/`:
- `design.md` — Architecture design with component diagrams
- `test_plan.md` — Comprehensive test strategy with coverage matrix
- `increment_plan.md` — Contract-aware **refinement** of CODESIGN's `slice_map.md` value-slices (BLUEPRINT does NOT invent or value-reorder slices). Confirms `slicing_strategy` (`incremental` default, `monolithic` escape when Trivial-Heuristic holds). Each `### INC-N` realizes one slice via `cascade_source: SLICE-{FEAT}-N` (1:1 default; ≥2 only with an intra-slice layering RDR) and carries `scenarios_covered`, `contract_surface`, `depends_on`, `depends_on_slice`, `depends_on_feature`, `seam`, `deployable: production`, branch name. Canonical INC→INC DAG lives in § 1 `depends_on:`; § 3 ships a Mermaid mirror for human reviewers (non-authoritative). Sidecar of `design.md`, never folded in. Each `### INC-N` also declares `Estimated surface` / `Escape` / `Sub-increments` (EVOL-045 — over the ceiling → sub-increments on a train).
- Feature Decision Records (FDR) in `docs/spec/{ID}/fdr/` for feature-scoped binding decisions; project-wide ADRs amend `docs/constitution.md` and live in `docs/project_log/adr/`. Legacy projects with feature-scoped ADRs at `docs/spec/{ID}/adr/` continue to be read until migrated
- Contract files in `contracts/` (OpenAPI, GraphQL, gRPC, AsyncAPI)
- `contracts/feature_map.md` — Contract-to-feature tracing

## Validation
See `.claude/instructions/Factory-blueprint-validation.instructions.md` for the complete validation checklist.

## Key Principles
- DRY: Consult `config/codebase_inventory.json` before creating new technical artifacts (CIP Step -2)
- Contract-first: API contracts MUST be defined before implementation
- user_journey.md § 6 Business Fields is the source of truth for WHICH business fields exist (plain language, no types — LAW-16); ARCH derives all typing in design.md §§ 3.1/3.2 + § 7.4 and does NOT invent business fields
- After `--refine` → CASCADE_PENDING_ITERATION to dev_plan.md, devops_plan.md
- **Iteration Changelog:** Every `--refine` MUST append a changelog entry to design.md and test_plan.md documenting what changed, what triggered the change, and which downstream artifacts are affected. This changelog serves as reference for IMPLEMENT and DEVOPS.
- **Worklog Attribution:** `APPEND_TO_WORKLOG` with `user_agent: "BLUEPRINT"` — always the actual agent name.
- **User Communication:** Follow Agent Communication Protocol (`.claude/skills/factory-agent-communication/SKILL.md`) — entry announcement, phase milestones, completion summary.
- `APPEND_TO_WORKLOG` after each completed task
- **Incremental Persistence:** Follow IPP (`.claude/skills/factory-incremental-persistence/SKILL.md`) — skeleton-first write, section-atomic saves, resume-on-entry for design.md + test_plan.md + increment_plan.md (frontmatter + § 0 Refinement Record on completion / intra-slice layering ratification, each `§ 1` INC-N as its own atomic section, `§ 2` Monolithic Escape when applicable, `§ 3` human-readable Mermaid diagram on completion).

### Changelog Format (for --refine)
```markdown
## Changelog

| Date | Iteration | Source | Changes | Downstream Impact |
|------|-----------|--------|---------|-------------------|
| {ISO_DATE} | {N} → {N+1} | {CODESIGN spec change / architecture decision / QA finding} | {list of design/contract/test-plan changes} | {dev_plan.md, devops_plan.md — marked CASCADE_PENDING_ITERATION} |
```

## Pre-Command Protocol (MANDATORY)
- **Before ANY file modification**, execute the full **Step -1 Auto-Branch Checkout Protocol** from `.claude/skills/factory-branching-strategy/SKILL.md`
- This ensures correct branch checkout, cross-branch mismatch detection, dependency checks, and concurrency locking
