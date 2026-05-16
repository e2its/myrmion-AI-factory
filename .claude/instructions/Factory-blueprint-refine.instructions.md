---
description: "Factory BLUEPRINT --refine — iterate design.md / test_plan.md / increment_plan.md on upstream cascade or implementation-state drift. Use when: /blueprint --refine execution."
applicable_when:
  phase: [BLUEPRINT]
  command: [blueprint]
  change_type: [feature, refactor, fix]
---

# BLUEPRINT Agent — `--refine` Protocol

## Purpose

Sync `design.md`, `test_plan.md`, `increment_plan.md`, and contracts when upstream (CODESIGN) cascades, when implementation drifted from the designed shape, or when new design requirements land. Eight steps, each persisted as part of a single `ITER-{FEAT}-{N}` iteration shared across all BLUEPRINT artefacts via the canonical iteration ledger.

## Hat-Switching Rules

Same as `--start`: 🏗️ ARCH leads design changes; 🧪 QA leads test plan changes; cross-pollination inline (ARCH contract change → QA contract test deltas; QA edge case → ARCH error-handling).

## Pre-Flight

Mandatory before any file modification:

1. **ADP Roll-Call** — `factory-applicability-discovery` (Step 0 of every command).
2. **Auto-Branch Checkout** — `factory-branching-strategy` Step -1 (current feature branch).
3. **CWD discipline** — every git invocation prefixes `cd <absolute-feature-root> &&` (factory-protocol-cwd-discipline).
4. **MCP-docs scan** — invoke `factory-mcp-docs-scan` and emit the banner before any step. `none detected` is a warning, not a block.
5. **Iteration ID allocation** — read `spec.feature.iterations[-1].id` (via `read_iteration_state()`); new entry `id = ITER-{FEAT_ID}-{spec.iterations[-1].iteration + 1}`. Set `_progress.iteration_in_flight = id` (factory-incremental-persistence § Iteration Append Pattern).

## Step 2.1 — Locate Changes

```yaml
upstream_changes = git diff --since=design.iterations[-1].cascade_timestamp \
                     -- spec.feature user_journey.md mock.html
direct_changes   = user_request OR backlog issue body
trigger = "cascade" IF upstream_changes ELSE "user-feedback"
```

Read upstream via `read_iteration_state()`. Emit findings to iteration body under `### Located Changes`.

## Step 2.2 — Analyze Current Design State

Read `design.md`, `test_plan.md`, `increment_plan.md` (sections + contracts in `contracts/`). Identify which design sections + which contract operations + which test categories the located changes touch.

## Step 2.3 — Dependencies Analysis

Reuse `Factory-blueprint-design § Step -0.5 Inter-Domain Dependency Analysis` against the refine context. Surface affected `consumes_contract` chains; for each, decide whether the refine triggers `CASCADE_CONSUMERS` (cross-feature) per `factory-iteration-model § CASCADE_CONSUMERS`.

## Step 2.4 — Implementation-State Probe (auto-trigger)

```yaml
probe_required = (dev_plan.md exists AND has any "[x]" task)
               OR (feature_branch_log_since(design.iterations[-1].cascade_timestamp) is non-empty)

IF probe_required:
  # Honors factory-protocol-cwd-discipline — absolute cd prefix
  src_files = list_files(src/spec/{FEAT_ID}/**) ∪ paths declared in design.md § File Manifest
  classify each file:
    drift      = implementation diverges from design.md spec
    carry-over = designed component absent from src/
    emergent   = src/ component absent from design.md
  persist findings to iteration body § Implementation-State Probe
```

If `none detected`, record `impl_state_snapshot: null` on the iteration entry.

## Step 2.5 — Update Design With Detected Gaps

| Gap class | Action |
|-----------|--------|
| drift | Modify `design.md` to reflect actual code. RDR (≥3 options) when multiple resolutions possible. |
| carry-over | Append entry to `design.md.frontmatter.pending_design_items[]` AND new `## Carried-Over Gaps` body section. Becomes input for IMPLEMENT `--refine` delta tasks. |
| emergent | Surface for ADR via `factory-adr-management` (significant design choice without record). |

## Step 2.6 — MCP-Docs Consultation (per scope)

For each technology/framework named in the refine scope: query the relevant docs MCP (context7, aws-knowledge, etc. — exact set surfaced by the scan banner). Cite findings inline in iteration body § MCP Findings + populate `mcp_consulted: [...]` on the iteration entry.

## Step 2.7 — Apply Changes

Use IPP section-atomic saves:
- Edit affected `design.md` sections (per `Factory-incremental-persistence § Pillar 2`).
- Edit affected `test_plan.md` categories.
- Edit affected `increment_plan.md § 1` increments (per-increment immutability rules apply — MERGED never invalidates, BUILDING requires --pause, DRAFT/READY flip to INVALIDATED — see `factory-iteration-model § CASCADE_INCREMENT_INTERNAL`).
- Re-generate / patch contracts in `contracts/` (when contract operations changed → re-open CONTRACT-FREEZE gate via tool-adapter).
- Execute `CASCADE_PENDING_ITERATION` (factory-iteration-model) to `dev_plan.md` / `devops_plan.md` / runtime reports.
- For contract changes → execute `CASCADE_CONSUMERS` against any downstream feature whose `spec.feature.consumes_contract` references this feature.

## Step 2.8 — Aggregated Changelog (Append Iteration Entry)

For each modified artefact (`design.md`, `test_plan.md`, `increment_plan.md`) invoke `append_iteration_entry()` (factory-incremental-persistence § Iteration Append Pattern). All three artefacts share the **same** `id: ITER-{FEAT}-{N}` and `cascade_source: ITER-{FEAT}-{N}` of the upstream entry that triggered the refine. Each iteration body section ends with a `Downstream Impact:` line listing the cascade targets actually written.

Worklog entry per modified artefact: `APPEND_TO_WORKLOG` with `iteration_id: ITER-{FEAT}-{N}` and `user_agent: "BLUEPRINT"`.

Clear `_progress.iteration_in_flight = null` (final step of the IPP append pattern).

## Completion Verification Gate

Before exit:
1. `verify_cascade_completion(FEAT_ID, target_iteration, "BLUEPRINT")` (factory-iteration-model § Cascade Completion Verification Gate).
2. `cvp_coherence_gate(FEAT_ID, CODESIGN_BLUEPRINT, BLUEPRINT)` — re-validates spec↔design↔test alignment post-refine.
3. CI gate `scripts/check-iteration-id-format.sh` — local dry-run.
4. Status transitions: `design.md.status` and `test_plan.md.status` flip back from `INVALIDATED` (if set by cascade) to the value they held pre-cascade (typically `APPROVED`). Re-approval is NOT automatic — explicit `/blueprint --approve` is still required when scope expanded; advisory note in completion summary.

## Output Schema (per iteration entry)

```yaml
- id: ITER-{FEAT}-{N}
  iteration: {N}
  date: {ISO_8601}
  source: cascade | user-feedback | impl-gap-probe | rdr-ratification
  scope_summary: "one-line"
  changes:
    - kind: design_section_modified | test_category_added | contract_op_changed | increment_invalidated | carried_over_added | emergent_flagged_for_adr
      ref: "Section 3.2" | "TC-API-04" | "POST /auth/refresh" | "INC-2" | "AuditLogger component" | ...
  downstream_impact: [dev_plan.md, devops_plan.md, contracts/]
  anchor: "#iter-{N}"
  rdr_rounds: {n}   # only when step 2.5 drift resolution required RDR
  converged: true
  impl_state_snapshot:
    tasks_done: {n}
    commits_since_last_iter: {n}
  cascade_source: ITER-{FEAT}-{upstream_N}
  mcp_consulted: [context7, aws-knowledge, ...]
```
