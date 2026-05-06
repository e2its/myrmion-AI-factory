---
description: "Factory BACKLOG execution plan — dependency analysis, epic formation, execution ordering, memory cache protocol. Use when: BACKLOG --plan-execution, --update-execution, --sync-execution execution."
applicable_when:
  phase: [BACKLOG]
  command: [backlog]
---

# Backlog Execution Plan Protocol (v1.2.0)

> Loaded contextually by the `backlog` agent. Contains the protocol for generating and maintaining
> the execution plan that minimizes rework by grouping features into **Epics** by shared Bounded Context
> boundaries, then subdividing each epic into **Slices** (≤3 features) by shared Aggregate Root
> coupling. Each slice goes through the full CODESIGN→BLUEPRINT→IMPLEMENT→QA cycle independently.
>
> **Terminology (Agile standard):** What was previously called "Domain Cluster" is now an **Epic** —
> a cohesive group of features that share Bounded Context boundaries and are co-designed, contracted,
> and implemented together. This aligns with standard Agile nomenclature and enables epic-scoped branching.
>
> **Slices (v1.2.0):** Each epic is subdivided into **Slices** — small batches of 1-3 tightly-coupled
> features grouped by shared Aggregate Root. This prevents agent overload by limiting co-design scope
> to max 3 features at a time. Later slices consume contracts established by earlier slices.

---

## 0. PURPOSE & PRINCIPLES

### 0.1 Goal

Generate an **execution plan** organized by **Epics** (groups of features sharing Bounded Context boundaries) that:

1. **Minimizes rework** — co-design features within the same epic together, so contracts are stable before implementation begins.
2. **Maximizes efficiency** — parallelize CODESIGN within a slice, then fix contracts in BLUEPRINT, then implement sequentially against stable contracts.
3. **Respects dependencies** — enforce epic ordering (e.g., Auth before Business, Business before Cross-cutting).
4. **Limits agent scope** — subdivide epics into **Slices** (≤3 features) by shared Aggregate Root, so the agent system never has to co-design more than 3 features at once.

### 0.2 Core Principle: Slice-Sequential within Epic

```
Within each Epic, features are divided into Slices (1-3 features per slice, grouped by aggregate coupling):

  For each Slice (ordered by internal aggregate dependency):
    CODESIGN (co-design slice features together — max 3) →
    BLUEPRINT (fix slice contracts together) →
    IMPLEMENT (sequential — dependency order within slice) →
    QA (verify each feature in slice)

  Later slices consume contracts established by earlier slices.
  All slices within an epic share the same epic branch.
```

Cross-epic: strict dependency order — an epic's first slice does NOT start until its upstream epic(s) reach at minimum their last slice's BLUEPRINT APPROVED.

> **Why slices?** An epic with 6 features forces the agent to co-design all 6 simultaneously, leading to
> context overflow and errors. Slices cap this at 3 features, producing smaller, more focused co-design
> and contract-fixing sessions. The trade-off (contracts partially fixed per slice) is mitigated by
> ordering slices so foundational aggregates come first.

### 0.3 SSOT and Memory Cache (Dual-Mode)

> **Clarification.** This protocol runs in one of two modes determined by the user's Q27 answer at SETUP time. The two modes are **parallel branches** of the same protocol — not an exceptional path layered on a file-mode default. BACKLOG agent code that reads or writes plan state MUST branch on `project_tracking.tool` and call the adapter accordingly.

| Mode | Selected when | SSOT for ordering | Local artefact | Cache file |
| --- | --- | --- | --- | --- |
| **File mode** | `project_tracking.tool == "None"` | `docs/backlog/execution-plan.md` | `docs/backlog/execution-plan.md` + `docs/backlog/state.md` + `docs/backlog/issue-bodies/*.md` | `/memories/repo/execution-plan-cache.md` |
| **Board mode** | `project_tracking.tool != "None"` | The configured external board (read via `tool-adapter.md` → `query_board`) | `docs/backlog/project-config.json` only. **No** `execution-plan.md` is materialised in board mode — the board IS the plan | `/memories/repo/project-board-cache.md` |

**Core invariants applicable to both modes:**

1. Exactly ONE SSOT per project — never both.
2. The memory cache is a read/write-through optimisation, never authoritative. On hash mismatch the agent re-reads the SSOT via the tool-adapter (board mode) or the file (file mode).
3. Cross-mode operations (e.g., migrating from file mode to board mode mid-project) are **not supported** — requires `SETUP --upgrade` with an explicit discovery re-answer for Q27.
4. The commands in § 1 below have the same name and contract in both modes; the adapter hides mode-specific details. The BACKLOG agent never dispatches on mode directly — it always delegates to the tool-adapter.

**File mode details (when Q27 == "None"):**
- `docs/backlog/execution-plan.md` is produced by `--plan-execution` as a structured markdown document with the format in § 3.1.
- `--update-execution` rewrites the checkbox state atomically and refreshes `execution-plan-cache.md`.
- The tool-adapter rendered from `none.md` maps `query_board` → "parse `state.md`" and `move_to_column` → "rewrite state.md row", so the BACKLOG agent code path is identical to board mode.

**Board mode details (when Q27 != "None"):**
- `docs/backlog/execution-plan.md` is **NOT** materialised by `SETUP --generate` or by `--plan-execution`. The entire document structure from § 3.1 is used only as an *in-memory* projection when computing cache state — never persisted to disk.
- `--plan-execution` materialises the plan directly onto the board via the tool-adapter: milestones (epics), labels (slices, phases, clusters), and issues (features + gates + retrospectives).
- `--update-execution` moves the relevant board item via `move_to_column` and refreshes `project-board-cache.md`.
- `--sync-execution` re-queries the board via `query_board`, reconstructs the in-memory plan, and rewrites `project-board-cache.md`. Any manual edits on the board are absorbed; any drift with the cache is reported and auto-corrected to match the board.

---

## 1. COMMANDS

| Command | Description (mode-agnostic contract) |
| --- | --- |
| `--plan-execution` | Analyse all planned features, compute dependency graph, form epics, materialise the plan on the configured SSOT (file or board), and refresh the memory cache |
| `--update-execution {step_ref}` | Mark a step as completed (`[x]` on file SSOT, `move_to_column` to Done on board SSOT). Recalculate progress summary and refresh cache |
| `--sync-execution` | Re-read the SSOT and refresh the memory cache. Use after manual edits to the file (file mode) or manual edits to the board (board mode). Flags and auto-corrects drift |

---

## 2. DEPENDENCY ANALYSIS PROTOCOL

### 2.1 Input Sources

The agent reads these artifacts to compute the dependency graph:

| Source | What it provides |
| --- | --- |
| `docs/setup.md` → `feature_list` | All planned features with IDs, names, bounded contexts |
| `docs/setup.md` → `bounded_contexts` | BC definitions and relationships |
| `docs/constitution.md` → `## Bounded Contexts` | Entity ownership, shared entities, cross-BC communication |
| `docs/backlog/state.md` or external board | Current issue state (which features already have issues) |
| `docs/spec/{ID}/spec.feature` (if exists) | Already-specified features — extract entity/event dependencies |
| `docs/spec/{ID}/design.md` (if exists) | Already-designed features — extract API contracts, shared services |

### 2.2 Dependency Graph Construction

```yaml
FUNCTION build_dependency_graph(features, bounded_contexts):
  graph = DirectedAcyclicGraph()

  FOR EACH feature IN features:
    node = {
      id: feature.id,
      name: feature.name,
      bcs: feature.bounded_contexts,   # List of BCs this feature touches
      entities: feature.entities,       # Entities it owns or consumes
      dependencies: []                  # Features it depends on
    }
    graph.add_node(node)

  # Rule 1: Entity dependency — if Feature A owns Entity X and Feature B consumes Entity X,
  #          then B depends on A
  FOR EACH pair (A, B) WHERE A.entities.owned ∩ B.entities.consumed ≠ ∅:
    graph.add_edge(A → B)  # B depends on A

  # Rule 2: BC dependency — if BC-Alpha depends on BC-Beta (from constitution),
  #          then features in BC-Alpha depend on features in BC-Beta
  FOR EACH (bc_dependent, bc_dependency) IN bounded_context_relationships:
    FOR EACH feature_dep IN features_in(bc_dependent):
      FOR EACH feature_base IN features_in(bc_dependency):
        graph.add_edge(feature_base → feature_dep)

  # Rule 3: Explicit dependency — from feature metadata (if declared)
  FOR EACH feature WITH explicit_dependencies:
    FOR EACH dep_id IN feature.explicit_dependencies:
      graph.add_edge(dep_id → feature.id)

  VALIDATE: graph has no cycles (DAG invariant)
  IF cycle detected:
    REPORT cycle path
    SUGGEST: break cycle by extracting shared entity into a Foundation epic

  RETURN graph
```

### 2.3 Epic Formation

```yaml
FUNCTION form_epics(graph):
  epics = []

  # Step 1: Group features that share Bounded Contexts
  bc_groups = group_features_by_shared_bcs(graph.nodes)

  # Step 2: Merge overlapping groups (same BC appears in multiple groups)
  merged_groups = merge_overlapping_bc_groups(bc_groups)

  # Step 3: Assign epic ID and order by dependency depth (topological sort)
  FOR EACH group IN merged_groups:
    epic = {
      id: next_epic_id(),          # EPIC-{N} (e.g., EPIC-0, EPIC-1, EPIC-2)
      name: derive_epic_name(group.bcs),  # e.g., "Foundation (Auth + Organization)"
      bcs: group.bcs,
      features: group.features,
      dependencies: compute_epic_dependencies(group, graph),
      rationale: explain_why_grouped(group)
    }
    epics.append(epic)

  # Step 4: Topological sort epics by inter-epic dependencies
  ordered_epics = topological_sort(epics, by=epic.dependencies)

  RETURN ordered_epics
```

### 2.4 Slice Formation (within each Epic)

After epics are formed, each epic with >3 features is subdivided into **Slices** — small batches grouped by shared aggregate root coupling.

```yaml
FUNCTION form_slices(epic, graph):
  # Goal: break epic into batches of 1-3 tightly-coupled features
  # Each slice goes through the FULL SDLC pipeline (CODESIGN → BLUEPRINT → IMPLEMENT → QA)

  IF epic.features.length <= 3:
    # Small epic — single slice, no subdivision needed
    RETURN [{
      id: "{epic.id}.1",
      name: derive_slice_name(epic.features),  # e.g., "User Aggregate (login + reset)"
      features: epic.features,
      rationale: "Epic with ≤3 features — single slice",
      dependencies: []
    }]

  slices = []
  remaining = epic.features.copy()

  # Step 1: Extract aggregate roots from the epic's BCs
  # Read from constitution → bounded_contexts → aggregates
  aggregate_roots = []
  FOR EACH bc IN epic.bcs:
    FOR EACH aggregate IN bc.aggregates:
      IF aggregate.role == "aggregate":
        aggregate_roots.append(aggregate)

  # Step 2: Map each feature to its primary aggregate root
  # A feature's primary aggregate is the one it OWNS entities in (entities.owned)
  # If a feature owns entities in multiple aggregates, use the one with most owned fields
  feature_aggregate_map = {}
  FOR EACH feature IN epic.features:
    primary_agg = NULL
    max_fields = 0
    FOR EACH owned_entity IN feature.entities.owned:
      agg = find_aggregate_containing(owned_entity, aggregate_roots)
      IF agg IS NOT NULL AND owned_entity.attributes.length > max_fields:
        primary_agg = agg
        max_fields = owned_entity.attributes.length
    IF primary_agg IS NULL:
      # Feature only CONSUMES, doesn't own — assign to the consumed aggregate
      primary_agg = find_aggregate_for_consumed(feature.entities.consumed, aggregate_roots)
    feature_aggregate_map[feature.id] = primary_agg.name

  # Step 3: Group features by primary aggregate
  aggregate_groups = group_by(feature_aggregate_map)
  # e.g., { "User": [AUTH-001, AUTH-002], "Organization": [ORG-001, ORG-002], "Role": [RBAC-001] }

  # Step 4: Merge small groups (1 feature) into related groups if coupling exists
  FOR EACH group IN aggregate_groups WHERE group.length == 1:
    feature = group[0]
    # Check: does this feature consume entities from another group's aggregate?
    consumed_aggs = [find_aggregate_containing(e, aggregate_roots) FOR e IN feature.entities.consumed]
    best_merge_target = find_group_with_aggregate(consumed_aggs, aggregate_groups)
    IF best_merge_target IS NOT NULL AND best_merge_target.length < 3:
      best_merge_target.append(feature)
      aggregate_groups.remove(group)

  # Step 5: Split oversized groups (>3 features)
  final_groups = []
  FOR EACH group IN aggregate_groups:
    IF group.length > 3:
      # Order by entity dependency within the group, then split into batches of 3
      ordered = topological_sort_within_group(group, graph)
      FOR i IN range(0, len(ordered), 3):
        batch = ordered[i:i+3]
        final_groups.append(batch)
    ELSE:
      final_groups.append(group)

  # Step 6: Order slices by inter-slice aggregate dependency
  # If Slice A's aggregate is consumed by Slice B's features → A before B
  ordered_slices = topological_sort_slices(final_groups, graph)

  # Step 7: Assign slice IDs
  FOR i, slice_group IN enumerate(ordered_slices):
    slice = {
      id: f"{epic.id}.{i+1}",           # e.g., EPIC-1.1, EPIC-1.2, EPIC-1.3
      name: derive_slice_name(slice_group),  # e.g., "User Aggregate (login + reset)"
      features: slice_group,
      aggregate: primary_aggregate_of(slice_group),
      rationale: explain_why_sliced(slice_group),
      dependencies: compute_slice_dependencies(slice_group, ordered_slices, graph)
    }
    slices.append(slice)

  RETURN slices
```

**Slice coupling criteria (priority order):**

1. **Shared Aggregate Root** — features that CRUD the same aggregate root entity MUST be in the same slice
2. **Direct Entity Dependency** — Feature A owns Entity X, Feature B consumes Entity X → same slice (or B's slice ordered after A's)
3. **Shared API Contract Root** — features mapping to the same REST resource or GraphQL type
4. **Max slice size: 3 features** — hard cap. If an aggregate has >3 features, split into sequential slices with the most foundational features first

---

## 3. EXECUTION PLAN GENERATION

> **Mode scoping.** Sections 3.1–3.3 below describe the **file-mode** rendering of the plan — the markdown document layout and the step reference format. In **board mode** this document structure is used only as an in-memory projection when computing the `project-board-cache.md` entries; nothing is persisted to `docs/backlog/execution-plan.md`. Each file operation in the pseudocode (READ / UPDATE of `execution-plan.md`) has a board-mode counterpart routed through the tool-adapter: `query_board` for reads, `create_issue` / `move_to_column` / `add_sub_issue` for writes. The BACKLOG agent SHOULD NOT branch on the mode in its own code — it delegates to the adapter, which materialises the mode-specific commands.

### 3.1 Plan Structure

The generated `docs/backlog/execution-plan.md` follows this template:

```markdown
# Execution Plan by Epics

> **Principle:** Minimize rework across features and domains.
> Each epic is subdivided into **Slices** (≤3 features) grouped by shared Aggregate Root.
> Each slice goes through the full CODESIGN → BLUEPRINT → IMPLEMENT → QA cycle before advancing to the next.
> This caps the agent's scope at a maximum of 3 concurrent features.
>
> **Usage:** The Backlog agent consults this file to determine execution order.
> Each `[x]` checkbox marks a completed step. Issues are referenced for traceability.
>
> **Branching:** Each epic has a shared branch (`epic/EPIC-{N}-{slug}`). All features in the epic
> (across all slices) are worked on that branch, avoiding continuous merges to main.

---

## Epic 0 — UX Vision (UI prerequisite)

- [ ] `CODESIGN --vision` — Global UX Vision

## Epic {N} — {Epic Name} (`EPIC-{N}`)

> **BCs:** {list of bounded contexts}
> **Rationale:** {rationale for grouping}
> **Dependencies:** {upstream epic dependencies}
> **Branch:** `epic/EPIC-{N}-{slug}`
> **Slices:** {count} ({total features} features)

### Slice {N}.1 — {Aggregate/Focus} ({FEAT-IDs})

> **Aggregate Root:** {primary aggregate}
> **Coupling:** {why these features are in the same slice}
> **Internal dependencies:** none (foundational slice)

#### CODESIGN

- [ ] `CODESIGN --start {FEAT-ID}` — {Feature Name} · #{issue_number}
{repeat for each feature in slice — max 3}

#### BLUEPRINT

- [ ] `BLUEPRINT --start {FEAT-ID}` · #{issue_number}
- [ ] `BLUEPRINT --approve {FEAT-ID}` · #{issue_number}
{repeat for each feature in slice}

#### IMPLEMENT + QA

- [ ] `IMPLEMENT --plan {FEAT-ID}` · #{issue_number}
- [ ] `IMPLEMENT --build {FEAT-ID}` · #{issue_number}
- [ ] `DEVOPS --configure {FEAT-ID}` · #{issue_number}
- [ ] `QA --verify {FEAT-ID}` · #{issue_number}
{repeat for each feature in dependency order within slice}

### Slice {N}.2 — {Aggregate/Focus} ({FEAT-IDs})

> **Aggregate Root:** {primary aggregate}
> **Coupling:** {why these features are in the same slice}
> **Internal dependencies:** Slice {N}.1 (consumes contracts of {aggregate})

#### CODESIGN
...
#### BLUEPRINT
...
#### IMPLEMENT + QA
...

{repeat for each slice in epic}

---

{repeat for each epic}

## Ad-hoc issues (no epic)

{Infrastructure, bug, and standalone issues not tied to an epic}

---

## Progress summary

| Epic | Slice | Total steps | Completed | Status |
|------|-------|-------------|-----------|--------|
| EPIC-{N} — {Name} | {N}.1 — {Focus} | {total} | {completed} | {emoji status} |
| | {N}.2 — {Focus} | {total} | {completed} | {emoji status} |
| **Total** | | **{sum}** | **{sum}** | |
```

### 3.2 Issue Reference Resolution

When the backlog already has issues created (via `--plan-feature`), the execution plan MUST reference them:

- **External mode**: Issue numbers from the external tool (e.g., `#7`, `#13`)
- **Local mode**: Local IDs from `state.md` (e.g., `L-001`, `L-002`)
- **No issues yet**: Omit the `· #{number}` suffix — it will be added when `--plan-feature` creates the issues

### 3.3 Step Reference Format

Each checkbox line uniquely identifies a step with:
```
- [ ] `{AGENT} --{command} {FEAT-ID}` — {description} · #{issue}  <!-- {date} -->
```

The `<!-- {date} -->` comment is appended when the step is marked complete.

---

## 4. MEMORY CACHE PROTOCOL

> **Mode scoping.** Cache location and invalidation rules differ between modes — file mode uses `/memories/repo/execution-plan-cache.md` and invalidates on `execution-plan.md` hash change; board mode uses `/memories/repo/project-board-cache.md` and invalidates on `query_board` snapshot hash change. The cache content schema is the same (see § 4.2). All pseudocode below assumes file mode for concreteness — the board-mode counterpart substitutes `query_board()` where `READ execution-plan.md` appears and `move_to_column()` where `UPDATE execution-plan.md` appears.

### 4.1 Cache Location

```
/memories/repo/execution-plan-cache.md
```

### 4.2 Cache Content

The cache stores a **compact state summary** — NOT a copy of the full plan. This minimizes memory usage while enabling fast next-task resolution.

```markdown
# Execution Plan Cache

> Auto-generated by BACKLOG agent. Source of truth: docs/backlog/execution-plan.md
> Last synced: {ISO timestamp}
> Plan hash: {MD5 of execution-plan.md}

## Active Epic

- epic: EPIC-{N}
- name: {Epic Name}
- branch: epic/EPIC-{N}-{slug}
- active_slice: {N}.{M}
- slice_name: {Slice Focus}
- slice_phase: {CODESIGN|BLUEPRINT|IMPLEMENT|QA}

## Next Step

- step: `{AGENT} --{command} {FEAT-ID}`
- issue: #{number}
- slice: {N}.{M}
- blocked_by: {none | step reference}

## Progress

| Epic | Slice | Total | Done | Status |
|------|-------|-------|------|--------|
{compact progress table}

## Recent Completions (last 5)

- {step_ref} — {date}
{...}
```

### 4.3 Cache Operations

```yaml
# READ-THROUGH: Check cache first, fall back to disk
FUNCTION get_next_step():
  cache = READ /memories/repo/execution-plan-cache.md
  plan_raw = READ docs/backlog/execution-plan.md
  plan_hash = MD5(plan_raw)
  IF cache exists AND cache.plan_hash == plan_hash AND cache.last_synced is recent (< 1 hour):
    RETURN cache.next_step
  ELSE:
    plan = PARSE(plan_raw)
    next = compute_next_step(plan)
    UPDATE cache with next + progress + plan_hash
    RETURN next

# WRITE-THROUGH: Update disk first, then cache
FUNCTION mark_step_complete(step_ref):
  # 1. Disk update (source of truth)
  UPDATE docs/backlog/execution-plan.md: step_ref checkbox → [x], append date comment
  UPDATE docs/backlog/execution-plan.md: recalculate progress summary table

  # 2. Cache update
  next = compute_next_step(updated_plan)
  UPDATE /memories/repo/execution-plan-cache.md with:
    - new next_step
    - updated progress
    - step_ref added to recent_completions

# FULL SYNC: Re-derive cache from disk
FUNCTION sync_cache():
  plan = READ docs/backlog/execution-plan.md
  PARSE all checkboxes (completed vs pending)
  COMPUTE active_epic, active_slice, next_step, progress
  WRITE /memories/repo/execution-plan-cache.md
```

### 4.4 Cache Invalidation

The cache is invalidated (must be re-synced) when:

1. `--plan-execution` generates a new plan
2. `--plan-feature` creates issues that need to be referenced in the plan
3. Manual edits to `execution-plan.md` detected (hash mismatch)
4. `--sync-execution` explicitly requested by user

---

## 5. UPDATE PROTOCOL (`--update-execution`)

### 5.1 Step Completion

```yaml
FUNCTION update_execution(step_ref):
  # step_ref can be:
  #   - Exact command: "CODESIGN --start FEAT-001"
  #   - Feature + phase: "FEAT-001 CODESIGN"
  #   - Auto (from last Factory command completion)

  READ docs/backlog/execution-plan.md
  FIND matching checkbox line
  IF not found:
    WARN: "Step '{step_ref}' not found in execution plan"
    RETURN

  IF already checked ([x]):
    INFO: "Step '{step_ref}' already marked complete"
    RETURN

  # Mark complete
  REPLACE "- [ ]" with "- [x]" on matching line
  APPEND " <!-- {current_date} -->" comment

  # Recalculate progress summary
  RECOMPUTE progress_summary table
  UPDATE docs/backlog/execution-plan.md

  # Update memory cache
  CALL sync_cache()

  # Report
  DISPLAY: "✅ {step_ref} completado — {epic_progress}"
```

### 5.2 Auto-Update Integration

When any Factory agent command completes successfully, the BACKLOG agent can be notified to auto-update the execution plan. This is triggered by the Factory orchestrator's post-command protocol:

```yaml
# In Factory post-command hook (Smart Redirect):
IF docs/backlog/execution-plan.md exists:
  completed_command = "{AGENT} --{command} {FEAT-ID}"
  SUGGEST: "BACKLOG --update-execution '{completed_command}'"
```

---

## 6. SYNC PROTOCOL (`--sync-execution`)

### 6.1 Full Reconciliation

```yaml
FUNCTION sync_execution():
  # 1. Read current plan from disk
  plan = READ docs/backlog/execution-plan.md
  IF not found:
    ERROR: "No execution plan found. Run BACKLOG --plan-execution first."
    RETURN

  # 2. Parse all steps
  steps = PARSE all checkbox lines from plan

  # 3. Cross-reference with board state (if external mode)
  IF mode == "external":
    board_state = QUERY board via tool-adapter
    FOR EACH step IN steps:
      IF step.issue exists in board_state:
        IF board_state[step.issue].status == "Done" AND step.checkbox == "[ ]":
          WARN: "Step for #{step.issue} is Done on board but unchecked in plan"
          SUGGEST: mark as [x]

  # 4. Rebuild cache
  CALL sync_cache()

  # 5. Report
  DISPLAY progress_summary
  DISPLAY any discrepancies found
```

---

## 7. INTEGRATION WITH `--plan-feature`

When `--plan-feature` creates issues for a feature, the agent MUST check if an execution plan exists and update issue references:

```yaml
# After --plan-feature creates issues:
IF docs/backlog/execution-plan.md exists:
  FOR EACH created_issue IN batch:
    FIND matching step in execution-plan.md (by FEAT-ID + phase)
    IF found AND step has no issue reference:
      APPEND " · #{issue_number}" to the step line
  CALL sync_cache()
```

---

## 8. INTEGRATION WITH NEXT-TASK RESOLVER

The Next Task Resolver (Factory-backlog-next-task) reads `docs/backlog/execution-plan.md` as its primary source. The memory cache accelerates this:

```yaml
# Next Task Resolver enhanced flow:
STEP 0: READ /memories/repo/execution-plan-cache.md
IF cache.next_step exists AND cache is fresh:
  RETURN cache.next_step (fast path)
ELSE:
  FALL THROUGH to standard STEP 0-6 from next-task protocol
  CALL sync_cache() after resolution
```

---

## 9. GUARDRAILS

1. **DAG Invariant**: The dependency graph MUST be a Directed Acyclic Graph. If circular dependencies are detected, BLOCK and report.
2. **SSOT (Dual-Mode)**: Exactly ONE source of truth per project. In **file mode** (Q27 == "None") it is `docs/backlog/execution-plan.md`. In **board mode** (Q27 != "None") it is the configured external board read via the tool-adapter's `query_board`. Memory cache is always an optimisation, never authoritative. See § 0.3.
3. **Issue-Plan Consistency**: Every feature issue created by `--plan-feature` SHOULD have a corresponding step in the execution plan (file mode) or on the board with the correct phase label (board mode).
4. **No Phantom Steps**: Do NOT add steps for features that don't exist in setup.md feature list.
5. **Epic Boundaries**: A feature belongs to exactly one epic. If it spans multiple BCs, assign it to the epic of its primary BC.
6. **UX Vision Gate**: If the project has a frontend, Epic 0 (UX Vision) MUST be the first epic and MUST complete before any feature epic's CODESIGN phase.
7. **Slice Size Cap**: A slice MUST contain at most 3 features. If an aggregate has >3 features, split into sequential slices ordered by entity dependency.
8. **Slice Ordering**: Within an epic, slices are ordered by aggregate dependency (foundational aggregates first). A slice's CODESIGN does NOT start until the preceding slice's BLUEPRINT is APPROVED AND the preceding slice's `[SLICE-{N.M}] INTEGRATION-TEST` gate (full-sdlc preset) is Done.
9. **Slice Completeness**: A slice MUST complete its full 8-phase `full-sdlc` pipeline (CODESIGN → BLUEPRINT → CONTRACT-FREEZE → DEVOPS → IMPLEMENT → PREVENTIVE-SWEEP → QA → SMOKE-E2E) plus its slice integration-test gate before the next slice starts CODESIGN. Exception: two slices with NO aggregate coupling MAY run in parallel.
10. **Epic Completeness**: An epic is Done when every slice inside it is Done AND the `[EPIC-{N}] RETROSPECTIVE` gate is Done. The next epic's first slice does NOT start CODESIGN until both hold.
11. **Gate enforcement is the resolver's job, not this protocol's**: `--plan-execution` materialises the plan including all gate issues; the `--next-task` resolver ([Factory-backlog-next-task.instructions.md](Factory-backlog-next-task.instructions.md) § 1.3.5) enforces the gates at query time. This protocol is a PLAN producer, not a runtime enforcer.
