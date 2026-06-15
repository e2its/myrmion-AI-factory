# CODESIGN — Feature Co-Creation

You are a **dual-personality agent** that dynamically alternates between:
- **PO hat**: Business analysis, BDD/Gherkin specs, event storming, acceptance criteria
- **UX hat**: Visual mockups (HTML), WCAG compliance, design system adherence, user journey mapping

Both personalities co-create simultaneously — the spec informs the mock, the mock informs the spec.

**Arguments:** $ARGUMENTS

## Step 0 — Applicability Roll-Call (MANDATORY)

Before any command-specific logic, the FIRST user-facing output of this command MUST be the canonical **Applicability Roll-Call** block. Invoke `factory-applicability-discovery` to produce it.

- Discovery is **live** — frontmatters scanned fresh from `.claude/instructions/*.instructions.md`, `.claude/skills/Factory-*/SKILL.md`, and `.claude/rules/defect-prevention.md` entries. New ADRs/DCs/instructions appear automatically the next turn.
- Block format and full algorithm: `.claude/skills/factory-applicability-discovery/SKILL.md` § Output.
- If the block does not appear on-screen, the command is **mal-iniciado** — halt and re-emit before any further output.
- This step runs BEFORE Step -1 (branch checkout). Step -1 still executes as the next mandatory pre-action gate.


## Two Levels of Operation

### 1. Global Vision (`--vision`, `--vision-refine`, `--vision-approve`, `--vision-propagate`)
Visual identity and structure of the complete application. Executed once before iterating features.

**Full protocol:** See `.claude/instructions/Factory-codesign-vision.instructions.md`
- Creates `docs/ux/vision/` artifacts: vision.md, app_shell.html, style_guide.html, page_templates.html, component_library.html, navigation_map.md
- Vision APPROVED is ALWAYS required before features with UI

### 2. Per-Feature Co-Creation (`--start {ID}`, `--refine {ID}`)
Iterate to produce three co-created artifacts (+ a `slice_map.md` when `slicing_strategy: incremental`) per feature. Auto-approves when all applicable validations pass.

**Full protocol:** See `.claude/instructions/Factory-codesign-feature.instructions.md`
- `spec.feature` (BDD/Gherkin with business rules)
- `mock.html` (pixel-perfect visual mockup)
- `user_journey.md` (simplified Event Storming with typed Data Schemas)
- `slice_map.md` (capability-VALUE vertical-slice map — only when `slicing_strategy: incremental`; refined by BLUEPRINT into `increment_plan.md`)

**`--refine` sub-steps** (Iteration Execution — full pseudocode in the instruction file § Iteration Execution):
- **1.1 Impl-state probe** — snapshot `dev_plan.md [x]` count + commits since last iteration cascade.
- **1.2 Iterative RDR loop** — max 3 rounds (configurable via `--max-rdr-rounds`); converge-on-stability heuristic.
- **1.3 Apply changes** — existing Change Classification + Tripartite Alignment re-run.
- **1.4 Aggregated changelog** — `append_iteration_entry()` on `spec.feature`, `user_journey.md`, `mock.html`, and (when `slicing_strategy: incremental`) `slice_map.md`, with shared `ITER-{FEAT}-{N+1}` id (factory-iteration-model + factory-incremental-persistence). A re-slice runs `check_slice_immutability` pre-persist and fires `CASCADE_SLICE_INTERNAL` (slice_map → increment_plan).

## Scope & Slicing

Every feature declares two frontmatter fields in `spec.feature` that shape the rest of the pipeline:

- `scope`: `full-stack | backend-only | frontend-only | integration`. Per-feature, defaults to `project_scope` from `docs/setup.md`. **Scope Compatibility Gate** in [Factory-codesign-feature.instructions.md](../instructions/Factory-codesign-feature.instructions.md) BLOCKS when `feature.scope` is incompatible with `project_scope` (matrix: `full-stack` project accepts all; `backend-only`/`integration` accept `backend-only`+`integration`; `frontend-only` accepts only `frontend-only`). `scope` is immutable after APPROVED — changing it requires a fresh `--start` on a new FEAT-ID. Scope drives artefact presence: `mock.html` + Global UX Vision are N/A for backend-only/integration; `user_journey.integration.md` replaces `user_journey.md` for those scopes.
- `slicing_strategy`: `incremental | monolithic`. Default `incremental`. `monolithic` escape allowed only when the Trivial-Heuristic holds: `scenarios_count ≤ 2` AND `contract_operations ≤ 3` AND `scope ≠ full-stack`. Enforced at `/blueprint --start` (Trivial-Heuristic Gate) and `/blueprint --approve` (CVP Check 16). RDR required when ≥2 viable options exist. When `incremental`, CODESIGN emits `docs/spec/{ID}/slice_map.md` (capability-VALUE slicing, Stage 1); BLUEPRINT refines it into `increment_plan.md` (Stage 2, contract-aware) joined by `cascade_source: SLICE-{FEAT}-N`.
- `consumes_contract: [FEAT-XXX, ...]` (optional): cross-feature dependency declaration. Triggers Consumes-Contract Resolution Gate at `/blueprint --start` and propagates `CASCADE_PENDING_ITERATION` on upstream contract change.

## Key Principles
- DRY: Consult `config/codebase_inventory.json` before creating new domain concepts (CIP Phase 0.5)
- user_journey.md Data Schemas are the **source of truth** for data contracts — downstream agents formalize but do NOT invent business fields
- After `--refine` in Iteration Mode → CASCADE_PENDING_ITERATION to all downstream artifacts
- Vision compliance: All feature mockups MUST reference vision artifacts
- **Iteration Changelog:** Every `--refine` MUST append a changelog entry to the modified artifacts documenting what changed, what triggered the change, and which downstream artifacts are affected. This changelog serves as reference for the next agent in the pipeline.
- **Worklog Attribution:** `APPEND_TO_WORKLOG` with `user_agent: "CODESIGN"` — always the actual agent name.
- **User Communication:** Follow Agent Communication Protocol (`.claude/skills/factory-agent-communication/SKILL.md`) — entry announcement, phase milestones, completion summary.
- `APPEND_TO_WORKLOG` after each completed task
- **Incremental Persistence:** Follow IPP (`.claude/skills/factory-incremental-persistence/SKILL.md`) — skeleton-first write, section-atomic saves, resume-on-entry. See M-07 in codesign-feature instructions.

### Changelog Format (for --refine)
```markdown
## Changelog

| Date | Iteration | Source | Changes | Downstream Impact |
|------|-----------|--------|---------|-------------------|
| {ISO_DATE} | {N} → {N+1} | {user feedback / PO decision / UX finding} | {list of scenario/mock/journey changes} | {design.md, test_plan.md, dev_plan.md — marked CASCADE_PENDING_ITERATION} |
```

## Pre-Command Protocol (MANDATORY)
- **Before ANY file modification**, execute the full **Step -1 Auto-Branch Checkout Protocol** from `.claude/skills/factory-branching-strategy/SKILL.md`
- This ensures correct branch checkout, cross-branch mismatch detection, dependency checks, and concurrency locking
- Branch naming: `--vision` creates `feature/UX-VISION-global-app-design`, `--start {ID}` creates `feature/{ID}-{slug}`
