---
description: "Factory IMPLEMENT dev plan — task decomposition, phase ordering (A/B/C), dependency mapping, IPP skeleton-first. Use when: IMPLEMENT --plan execution."
applicable_when:
  phase: [IMPLEMENT]
  command: [implement]
---

# IMPLEMENT Agent — Plan Command Instructions

> Detailed instructions for `IMPLEMENT --plan {{FEATURE_ID}}` — generates `dev_plan.md` with phased implementation checklist.

## Prerequisites (BLOCKING)

### BLUEPRINT Gate
```yaml
READ docs/spec/{FEATURE_ID}/design.md → status
READ docs/spec/{FEATURE_ID}/test_plan.md → status

IF design.md missing OR status != APPROVED:
  ❌ BLOCK: "Design not approved. Run BLUEPRINT --approve first."
IF test_plan.md missing OR status != APPROVED:
  ❌ BLOCK: "Test plan not approved. Run BLUEPRINT --approve first."
```

### CONTRACT-FREEZE Gate (full-sdlc preset only; scope-aware)

Enforces the CONTRACT-FREEZE hard gate from the 8-phase `full-sdlc` preset (see [Factory-backlog-operations.instructions.md](Factory-backlog-operations.instructions.md) § 1.1). Blocks `IMPLEMENT --plan` until the feature's API contracts are frozen and the contract test harness exists.

**Framing.** This gate is the **primary design output** for features with `scope IN [backend-only, integration]` — those features are *entirely defined* by the frozen contract surface (no UI, no mock.html to verify). For `scope=frontend-only` features there is typically **no own contract to freeze** (the feature consumes upstream contracts via `consumes_contract` — see the Consumes-Contract Upstream Freeze Gate below); the gate still runs but the "contract directory non-empty" check is relaxed to allow client-side type declarations only. For `scope=full-stack` the gate behaves as it did pre-EVOL-019.

```yaml
READ docs/setup.md → project_tracking.feature_phases
IF feature_phases != "full-sdlc":
  ✅ SKIP gate — simplified/single presets do not ship CONTRACT-FREEZE
  RETURN

# load feature scope for scope-aware checks
feature_scope = READ("docs/spec/{FEATURE_ID}/spec.feature").frontmatter.scope OR "full-stack"
has_backend_surface = feature_scope IN ["full-stack", "backend-only", "integration"]

# 1. Verify the contract-freeze backlog issue exists and is Done
ADAPTER = READ docs/backlog/tool-adapter.md
issue = ADAPTER.query_board() → find item WHERE labels CONTAINS "phase:contract-freeze" AND title CONTAINS FEATURE_ID

IF issue IS NULL:
  ❌ BLOCK: "CONTRACT-FREEZE gate issue missing for {FEATURE_ID}."
  SUGGEST: "Run BACKLOG --plan-feature {FEATURE_ID} to materialise the 8-phase preset."
  STOP

IF issue.status != "Done":
  IF has_backend_surface:
    ❌ BLOCK (humanised, backend-authoritative): "CONTRACT-FREEZE gate not passed for {FEATURE_ID} (current: {issue.status}).
      For scope=`{feature_scope}` this gate is the PRIMARY design output — the feature is defined by its frozen contract surface.
      Required artefacts under docs/spec/{FEATURE_ID}/contracts/ (filenames depend on SETUP stack — OpenAPI YAML, TypeScript interface files, GraphQL SDL, Protobuf, AsyncAPI event schemas) plus the contract test harness under tests/contract/{FEATURE_ID}/. Complete them, move the CONTRACT-FREEZE issue to Done, then re-run IMPLEMENT --plan."
  ELSE:
    # feature_scope == "frontend-only"
    ❌ BLOCK (humanised, consumer-view): "CONTRACT-FREEZE gate not passed for {FEATURE_ID} (current: {issue.status}).
      For scope=frontend-only, this gate validates that upstream contracts consumed by this feature are frozen AND that any client-side type declarations (generated from OpenAPI / SDL) are committed. Complete the gate issue, then re-run IMPLEMENT --plan.
      Note: the Consumes-Contract Upstream Freeze Gate (below) is the primary check for frontend-only features — this gate is the gate-of-record."
  STOP

# 2. Verify the frozen-contract directory exists and is non-empty (scope-adapted threshold)
contracts_dir = "docs/spec/{FEATURE_ID}/contracts/"
IF has_backend_surface:
  IF NOT DIR_EXISTS(contracts_dir) OR DIR_IS_EMPTY(contracts_dir):
    ❌ BLOCK: "CONTRACT-FREEZE issue is Done but {contracts_dir} is missing or empty — yet scope=`{feature_scope}` REQUIRES a frozen contract surface."
    SUGGEST: "Governance drift detected. Re-run the contract-freeze step to produce the frozen contract set."
    STOP
ELSE:
  # frontend-only: empty contracts/ is permitted (feature has no own contract; it consumes upstreams)
  IF DIR_EXISTS(contracts_dir) AND NOT DIR_IS_EMPTY(contracts_dir):
    LOG: "frontend-only feature ships client-side types under {contracts_dir}"
  ELSE:
    LOG: "frontend-only feature has no own contracts — relies on Consumes-Contract Upstream Freeze Gate"

# 3. Check the gate issue for the stale-after-cascade label (placed by iteration-model cascade
#    when an upstream change re-invalidated the contracts — see Factory-iteration-model/SKILL.md
#    § CASCADE_PENDING_ITERATION → contracts_freeze branch).
#    Contract files themselves (OpenAPI YAML, TypeScript interface, GraphQL SDL, Protobuf, etc.)
#    are the DSL native format and carry NO markdown frontmatter — the CONTRACT-FREEZE gate issue
#    is the single source of truth for their "frozen" status, NOT a per-file frontmatter read.
IF "stale-after-cascade" IN issue.labels:
  ❌ BLOCK: "CONTRACT-FREEZE gate was marked stale by an upstream cascade (label: stale-after-cascade)."
  SUGGEST: "Run BLUEPRINT --refine {FEATURE_ID} to re-sync the contracts, then reopen and re-close the CONTRACT-FREEZE issue (removing the stale label) to re-freeze."
  STOP

✅ PROCEED — contract-freeze issue is Done, contracts appropriate for scope, not stale
```

> **Rationale.** Without this gate, `IMPLEMENT --plan` reads `design.md` for contract references but the concrete contract files may be absent, outdated, or out of sync with the design. The MASS production retrospective recorded six cases of contract drift (class DC-6) where implementation proceeded against a stale or inferred contract and the bug surfaced only at QA. The gate eliminates that class entirely by making the frozen contract a hard prerequisite.

> **Trust model.** Contract files (OpenAPI YAML, TypeScript interface files, GraphQL SDL, Protobuf, etc.) live in their respective DSL formats without markdown frontmatter — there is no `status` field to read on a `.yaml` or `.ts` file. The CONTRACT-FREEZE gate issue being `Done` (and NOT carrying the `stale-after-cascade` label) IS the source of truth that the contracts under `docs/spec/{FEATURE_ID}/contracts/` are frozen and valid. Upstream changes that would invalidate the contracts trigger a cascade that relabels the gate issue and moves it back to Todo via the tool-adapter (see `Factory-iteration-model/SKILL.md` § CASCADE_PENDING_ITERATION → contracts_freeze branch). This gives a single, tool-agnostic, frontmatter-free validation point.

### Consumes-Contract Upstream Freeze Gate (BLOCKING, runs AFTER CONTRACT-FREEZE)

Validates that every upstream feature listed in `spec.feature.consumes_contract` has a frozen contract before this feature's implementation plan is generated. Without this gate, a downstream feature can implement against an APPROVED-but-not-yet-frozen upstream design, and the resulting code silently binds to a pre-freeze schema that the upstream may still change.

```yaml
FUNCTION consumes_contract_upstream_freeze_gate(FEATURE_ID):
  spec = READ("docs/spec/{FEATURE_ID}/spec.feature")
  upstream_features = spec.frontmatter.consumes_contract OR []

  IF upstream_features IS EMPTY:
    ✅ SKIP — feature has no upstream contract dependencies
    RETURN

  ADAPTER = READ("docs/backlog/tool-adapter.md")
  project_tracking = READ("docs/setup.md").project_tracking

  FOR EACH upstream_id IN upstream_features:
    # Step 1 — upstream design.md must be APPROVED (or later)
    upstream_design = READ_IF_EXISTS("docs/spec/{upstream_id}/design.md")
    IF NOT EXISTS upstream_design:
      ❌ BLOCK: "consumes_contract references {upstream_id} but docs/spec/{upstream_id}/design.md does not exist.
        Resolution: produce the upstream feature first (`/codesign --start {upstream_id}` → `/blueprint --start {upstream_id}` → `/blueprint --approve {upstream_id}`) or remove {upstream_id} from spec.feature.consumes_contract."
      STOP
    IF upstream_design.frontmatter.status NOT IN ["APPROVED", "IMPLEMENTED_AND_VERIFIED"]:
      ❌ BLOCK: "consumes_contract references {upstream_id} but its design.md is in status `{upstream_design.status}`, not APPROVED.
        Downstream implementation against a non-APPROVED upstream design risks binding to a draft schema. Resolution: wait for `/blueprint --approve {upstream_id}` or drop the dependency."
      STOP

    # Step 2 — upstream contract directory is non-empty (scope-aware)
    upstream_scope = READ("docs/spec/{upstream_id}/spec.feature").frontmatter.scope OR "full-stack"
    IF upstream_scope == "frontend-only":
      ❌ BLOCK: "consumes_contract references {upstream_id} but its scope is `frontend-only` — frontend-only features have no own contract to consume.
        Resolution: point consumes_contract at the backend feature that owns the contract (trace upstream → backend dependency), or remove this entry."
      STOP
    # Align with BLUEPRINT Consumes-Contract Resolution Gate + CVP Check 0b — look at BOTH the
    # feature-local contracts dir AND root-level contracts/** (contract-first-policy layout).
    # Without this, BLUEPRINT --start could pass by finding contracts at repo root while
    # IMPLEMENT --plan would block — re-introducing the three-point gate asymmetry that
    # e8c9b0f fixed. All three enforcement points must search the same locations.
    upstream_contracts_dir = "docs/spec/{upstream_id}/contracts/"
    feature_local_contract_files = []
    IF DIR_EXISTS(upstream_contracts_dir) AND NOT DIR_IS_EMPTY(upstream_contracts_dir):
      feature_local_contract_files = GLOB("{upstream_contracts_dir}**/*.{yaml,yml,graphql,proto}")
    root_level_contract_files = GLOB("contracts/{openapi,graphql,grpc,asyncapi,webhooks}/**/{upstream_id}*/**/*.{yaml,yml,graphql,proto}")
    root_level_contract_files += GLOB("contracts/{openapi,graphql,grpc,asyncapi,webhooks}/**/{CONTRACT_SLUG_OF(upstream_id)}/**/*.{yaml,yml,graphql,proto}")
    IF feature_local_contract_files IS EMPTY AND root_level_contract_files IS EMPTY:
      ❌ BLOCK: "consumes_contract references {upstream_id} (status: APPROVED, scope: {upstream_scope}) but no frozen contract files found under {upstream_contracts_dir} OR contracts/**/{upstream_id}*/.
        Resolution: verify upstream BLUEPRINT --approve produced contract artefacts. Either location is accepted (feature-local under docs/spec/{upstream_id}/contracts/, or root-level under contracts/{openapi|graphql|grpc|asyncapi|webhooks}/<slug>/). Missing from both indicates contract-first-policy drift."
      STOP

    # Step 3 — upstream CONTRACT-FREEZE issue is Done + not stale (full-sdlc preset only)
    IF project_tracking.feature_phases == "full-sdlc":
      upstream_issue = ADAPTER.query_board() → find item WHERE labels CONTAINS "phase:contract-freeze" AND title CONTAINS upstream_id
      IF upstream_issue IS NULL:
        ⚠️ WARN (gate_enforcement_mode=warn): "Upstream {upstream_id} has no CONTRACT-FREEZE issue — proceeding under soft-landing."
        # fallthrough — enforce-mode projects treat this as a BLOCK
        IF project_tracking.gate_enforcement_mode == "enforce":
          ❌ BLOCK: "Upstream {upstream_id} has no CONTRACT-FREEZE issue and gate_enforcement_mode=enforce."
          STOP
      ELSE:
        IF upstream_issue.status != "Done":
          ❌ BLOCK (gate_enforcement_mode=enforce): "Upstream {upstream_id} CONTRACT-FREEZE issue is not Done (current: {upstream_issue.status}).
            Downstream cannot safely bind to a contract that is not frozen upstream. Complete `/blueprint --approve {upstream_id}` and move its CONTRACT-FREEZE issue to Done, then re-run IMPLEMENT --plan {FEATURE_ID}."
          STOP
        IF "stale-after-cascade" IN upstream_issue.labels:
          ❌ BLOCK: "Upstream {upstream_id} CONTRACT-FREEZE is stale (label: stale-after-cascade) — an upstream iteration invalidated the contract.
            Resolution: run `/blueprint --refine {upstream_id}` to re-sync, then re-close the CONTRACT-FREEZE issue (removing the stale label). After that, this feature's dev_plan.md will need a CASCADE_PENDING_ITERATION sync too (see Factory-iteration-model/SKILL.md)."
          STOP

  ✅ All consumed upstream contracts are frozen and current — proceed
```

**Pair with the BLUEPRINT-side gate.** The same `consumes_contract` list is validated at `BLUEPRINT --start` by the Consumes-Contract Resolution Gate (Phase 1) — that one runs before the downstream design is even drafted. This IMPLEMENT-side gate is the second enforcement point: the upstream must still be APPROVED + frozen + current at implementation time (a regression would be caught by the cascade labelling). Together they make consumes_contract a load-bearing primitive, not just a documentation field.

### UX Vision Gate (v12.0.0)
```yaml
READ docs/setup.md → frontend.framework
IF frontend.framework != "None":
  READ docs/ux/vision/vision.md → status
  IF NOT EXISTS OR status != APPROVED:
    ❌ BLOCK: "Global UX Vision required. Run CODESIGN --vision first."
  
  VERIFY existence of 5 complementary artifacts:
    - docs/ux/vision/app_shell.html
    - docs/ux/vision/style_guide.html
    - docs/ux/vision/page_templates.html
    - docs/ux/vision/component_library.html
    - docs/ux/vision/navigation_map.md
  IF any missing:
    ❌ BLOCK: "Vision artifacts incomplete."
```

### Immutability Check
```yaml
IF dev_plan.md EXISTS:
  READ status from frontmatter
  IF status IN [IMPLEMENTED_AND_VERIFIED, BUILDING]:
    ❌ BLOCK: "Cannot overwrite plan in status {status}."
    SUGGEST: "IMPLEMENT --refine {ID}" for adjustments
  IF status IN [READY, DRAFT, NEEDS_INFO]:
    ⚠️ WARN: "Plan already exists with status {status}. Overwrite?"
    WAIT for confirmation
```

### Parent Version Validation (Iteration Model)
```yaml
READ spec.feature frontmatter → iteration (default 1)
READ design.md frontmatter → based_on_iteration (default 1)

IF spec.iteration > design.md.based_on_iteration:
  ❌ BLOCK: "Blueprint is stale. Run BLUEPRINT --refine {ID} first."

IF dev_plan.md EXISTS:
  READ dev_plan.md → based_on_iteration
  IF spec.iteration > dev_plan.based_on_iteration:
    # Iteration gap detected
    OFFER options:
      DELTA: Update only affected sections (preserve completed work)
      FULL: Regenerate entire plan from scratch
      SKIP: Proceed without sync (⚠️ traceability gap)
```

### Increment Plan Gate (BLOCKING)

IMPLEMENT `--plan` consumes `increment_plan.md` as a functional input — it is not merely validated by CVP, it drives the entire plan structure (one section per increment when `slicing_strategy == incremental`). Missing or non-APPROVED plan → BLOCK; per-increment statuses gate which increments are eligible to be planned in this run.

```yaml
READ spec_slicing = spec.feature.frontmatter.slicing_strategy OR "incremental"
READ increment_plan_path = "docs/spec/{FEATURE_ID}/increment_plan.md"

IF NOT FILE_EXISTS(increment_plan_path):
  ❌ BLOCK: "increment_plan.md missing. Run BLUEPRINT --start {FEATURE_ID} (or --refine if design.md is APPROVED)."

READ increment_plan.md → frontmatter (fm_plan) + § 1 increments (list of INC-N with status, scenarios_covered, contract_surface, depends_on, deployable)

IF fm_plan.status != "APPROVED":
  ❌ BLOCK: "increment_plan.md status='{fm_plan.status}' — BLUEPRINT --approve must complete first."

IF fm_plan.slicing_strategy != spec_slicing:
  ❌ BLOCK: "slicing_strategy drift: spec.feature says '{spec_slicing}', increment_plan says '{fm_plan.slicing_strategy}'. Re-run BLUEPRINT --refine."

# Determine which increments this --plan run will expand into dev_plan.md tasks
IF fm_plan.slicing_strategy == "monolithic":
  target_increments = increments   # single INC-1; preserve backward-compat task tags [A.M]/[B.M]/[C.M]
ELSE:
  # Incremental — only increments in DRAFT, READY, or INVALIDATED are eligible for planning
  # BUILDING → already in progress on a branch; skip (use --refine instead)
  # MERGED   → locked (see immutability_policy § Per-Increment Immutability)
  eligible = FILTER(increments, status IN ["DRAFT", "READY", "INVALIDATED"])
  blocked_by_status = FILTER(increments, status IN ["BUILDING", "MERGED"])
  IF eligible IS EMPTY:
    ❌ BLOCK: "No eligible increments to plan. {blocked_by_status.length} are BUILDING/MERGED."
  target_increments = TOPOLOGICAL_SORT(eligible, edge=depends_on)   # respects DAG
  LOG: "IMPLEMENT --plan will expand {target_increments.length} increment(s): {[i.id for i in target_increments]}"
```

### Defect Prevention Consultation

```yaml
# Consult the Defect Prevention Catalog filtered to this agent, project applicable DCs
# as mandatory tasks in dev_plan.md § DC Compliance.
feature_scope = READ("docs/spec/{FEATURE_ID}/spec.feature").frontmatter.scope OR "full-stack"   # pass to DPC Filter 2 so dev_plan § DC Compliance only contains scope-relevant tasks
applicable_dcs = consult_defect_catalog("IMPLEMENT", {feature_id: FEATURE_ID, feature_scope: feature_scope, stack: setup_md.stack})

IF applicable_dcs is not empty:
  ADD SECTION to dev_plan.md § DC Compliance (created if absent):
    FOR EACH dc IN applicable_dcs:
      ADD task:
        "- [ ] [DC-{dc.number}] Verify {dc.name}: {dc.check}"
        # Every DC becomes an explicit dev_plan task tracked by the BVL loop.
        # DEV hat pre-write check (Factory-implement-build) also reads the same catalog.

LOG: "IMPLEMENT DC consult: {applicable_dcs.length} entries projected into dev_plan § DC Compliance"
```

See `.claude/rules/defect-prevention.md` § Mandatory Process Integration § 3 for the canonical consultation protocol.

### Upstream Coherence Validation (CVP — Step 0.5)

Cross-artifact coherence validation across the CODESIGN↔BLUEPRINT↔IMPLEMENT chain. See `.claude/skills/Factory-coherence-validation/SKILL.md` for full protocol.

```yaml
FUNCTION implement_coherence_gate(FEATURE_ID):
  # Invoke CVP with CODESIGN_BLUEPRINT_IMPLEMENT scope
  # Validates: all CODESIGN↔BLUEPRINT checks PLUS
  #   contract endpoints → dev_plan.md tasks,
  #   test cases → dev_plan.md test tasks,
  #   UI components → dev_plan.md frontend tasks,
  #   data model entities → dev_plan.md Phase A tasks
  #
  # NOTE: On first --plan, dev_plan.md does not exist yet.
  # CVP runs in CODESIGN_BLUEPRINT scope (IMPLEMENT checks deferred).
  # On subsequent --plan (overwrite) or --refine, full scope applies.

  IF dev_plan.md EXISTS:
    scope = "CODESIGN_BLUEPRINT_IMPLEMENT"
  ELSE:
    scope = "CODESIGN_BLUEPRINT"

  cvp_result = cvp_coherence_gate(FEATURE_ID, scope, "IMPLEMENT")

  IF NOT cvp_result.passed:
    ❌ BLOCK: "Upstream artifacts are inconsistent — fix before planning"
    STOP

  # Embed coherence matrix summary in dev_plan.md → ## Upstream Coherence Validation
  # (deferred to after skeleton-first write — see IPP)
  STORE cvp_result FOR post_skeleton_embed
  LOG: "CVP: {cvp_result.matrix.summary.passed}/{cvp_result.matrix.summary.total_checks} checks passed"
```

## Architecture Context Loading

### Infrastructure Context
```yaml
FROM design.md Section 5 "Infrastructure Needs":
  EXTRACT required_resources[]:
    - type, engine, scope, data_bearing, sizing
  IF resources present:
    ANNOTATE plan with infrastructure dependency notes per phase
```

### Serverless Context (B9 Topology)
```yaml
# Governance Snapshot Recovery (INVARIANT 5): read snapshot first, fallback to constitution.
IF FILE_EXISTS(".context/governance_snapshot.md"):
  snapshot = READ(".context/governance_snapshot.md")
  EXTRACT: topology, runtime, framework, extension_strategy from snapshot.stack_config
  # Use snapshot values — fall through to constitution only for fields not in snapshot

READ constitution.md → architecture.topology
IF topology == "B9" (Serverless):
  READ design.md → resources WHERE type == "function"
  FOR EACH function resource:
    EXTRACT: handler, runtime, memory_mb, timeout_seconds, trigger, contract_slug
  READ OpenAPI contract via contract_slug:
    EXTRACT x-serverless-* extensions if present
  ANNOTATE Phase A tasks with function scaffolding + handler implementation
```

### Extension Strategy Context (Brownfield)
```yaml
READ constitution.md → extension.strategy
IF strategy == "E0" (Native Extension):
  ANNOTATE: "Follow existing codebase patterns. No wrappers."
IF strategy == "E1" (Preserve + Wrapper):
  ANNOTATE: "Wrap legacy code. Never modify legacy files directly."
IF strategy == "E2" (Strangler Fig):
  ANNOTATE: "New code proxies old. Gradual replacement."
IF strategy == "E3" (Full Rewrite):
  ANNOTATE: "Complete rewrite. No legacy dependencies."
```

### Mandatory Architectural Patterns + ADR Bindings (GCD Section 7.8)

> **Purpose:** Constitution and ADRs define mandatory shared components and implementation
> patterns (e.g., BaseRepository with auto tenant filter, TenantMiddleware). Without explicit
> task generation for these, IMPLEMENT satisfies constraints superficially (e.g., manual
> tenant filtering in each query instead of the prescribed BaseRepository auto-filter).

```yaml
FUNCTION load_mandatory_patterns(FEATURE_ID):
  mandatory_tasks = []
  
  # Step 1: Load from GCD Section 7.8 (preferred — BLUEPRINT pre-digested)
  # Match by stable section-number prefix because BLUEPRINT may emit
  # "### 7.8 Mandatory Architectural Patterns + ADR Bindings ..."
  gcd_section_78 = READ(design.md, "## Section 7" → subsection starting with "### 7.8")
  
  IF gcd_section_78 EXISTS:
    patterns = gcd_section_78.mandatory_patterns
    fdr_bindings = gcd_section_78.fdr_bindings OR gcd_section_78.adr_bindings  # adr_bindings is the legacy field name from pre-rewire BLUEPRINT
    invariants = gcd_section_78.implementation_invariants
    LOG: "Mandatory patterns loaded from GCD Section 7.8 ({patterns.length} patterns, {fdr_bindings.length} FDRs)"
  ELSE:
    # Fallback: Load directly from constitution [LAW] sections + feature-local FDRs (pre-GCD BLUEPRINT).
    # Source priority: docs/spec/{FEATURE_ID}/fdr/ (current) → docs/spec/{FEATURE_ID}/adr/ (legacy fallback for unmigrated projects).
    patterns = EXTRACT_LAW_SECTIONS(docs/constitution.md)  # operational [LAW] body extracted via regex; project-wide patterns live here
    fdr_bindings = []
    FOR EACH dir IN ["docs/spec/{FEATURE_ID}/fdr/", "docs/spec/{FEATURE_ID}/adr/"]:
      IF DIRECTORY_EXISTS(dir):
        FOR EACH record IN dir WHERE status IN ["accepted", "approved"]:
          fdr_bindings.APPEND(record)
    invariants = DERIVE_FROM(patterns + fdr_bindings)
    LOG: "Mandatory patterns loaded from constitution [LAW] sections + feature FDR files (fallback)"
  
  # Step 2: Cross-reference against design.md Section 2 Component Inventory
  component_inventory = READ(design.md, "## Section 2: Component Inventory")
  
  FOR EACH pattern IN patterns WHERE affects_feature == true:
    # Check if the mandatory component exists in the codebase
    existing = SEARCH(@workspace, pattern.name, pattern.type)
    
    IF existing IS NULL:
      # Component needs to be CREATED — generate explicit task
      mandatory_tasks.APPEND({
        task_id: "A.0.{sequential}",  # Phase A, priority 0 (before feature tasks)
        description: "Create shared {pattern.type}: {pattern.name}",
        details: pattern.description,
        enforcement: pattern.enforcement,
        constitution_ref: pattern.constitution_ref,
        scope: pattern.scope,
        phase: "A",
        priority: "PREREQUISITE"  # Must be done BEFORE feature-specific tasks that depend on it
      })
    ELSE:
      # Component exists — generate INTEGRATION task (verify usage, not bypass)
      mandatory_tasks.APPEND({
        task_id: "A.0.{sequential}",
        description: "Integrate with existing {pattern.name} ({pattern.type})",
        details: "Use existing {existing.path} — do NOT re-implement {pattern.enforcement}",
        phase: "A",
        priority: "PREREQUISITE"
      })
  
  # Step 3: Generate ADR binding tasks
  FOR EACH fdr IN fdr_bindings:
    FOR EACH component IN adr.mandatory_components:
      IF component NOT ALREADY IN mandatory_tasks:
        mandatory_tasks.APPEND({
          task_id: "A.0.{sequential}",
          description: "Implement {component} per {adr.id}: {adr.title}",
          details: adr.decision,
          constraints: adr.consequences,
          phase: "A",
          priority: "PREREQUISITE"
        })
  
  RETURN { mandatory_tasks, invariants }
```

## Dependency Analysis
```yaml
FROM design.md:
  EXTRACT external_dependencies (APIs, databases, services)
  EXTRACT internal_dependencies (modules, shared services)

FOR EACH dependency:
  CLASSIFY: available | needs_provisioning | needs_mock
  IF needs_provisioning:
    ADD prerequisite note: "Requires DEVOPS --provision before integration testing"
  IF needs_mock:
    ADD Phase A task: "Create mock/stub for {dependency}"
```

## Pre-Implementation Codebase Survey (CIP v1.0.0)

### Step S.1: Load Registry
```yaml
READ config/codebase_inventory.json
IF NOT EXISTS:
  ⚠️ WARN: "No codebase inventory. DRY checks will be limited."
  SKIP to Plan Generation
```

### Step S.2: Cross-Reference Planned Artifacts
```yaml
FROM design.md Section 2 "Component Inventory":
  EXTRACT planned_artifacts[] (services, repositories, controllers, components, etc.)

FOR EACH planned_artifact:
  SEARCH codebase_inventory.json using 4-Criteria Matching:
    1. EXACT_MATCH: name + type identical
    2. SAME_DOMAIN: same module + same type
    3. NEAR_DUPLICATE: >60% responsibility overlap
    4. NAME_SIMILAR: Levenshtein distance <3, same type
  
  IF match found:
    READ design.md Section 0 "Reuse Analysis" for existing RDR decision
    IF RDR exists: ANNOTATE task with REUSE/EXTEND context
    IF NO RDR: FLAG for resolution during --build (DRY Gate)
```

### Step S.3: Annotate Plan Tasks
```yaml
FOR EACH task in generated plan:
  IF task creates new artifact:
    ADD annotation: "CIP: {REUSE|EXTEND|CREATE_NEW} — from design.md Section 0"
  IF task has REUSE annotation:
    MODIFY task: "Integrate with existing {artifact_name} (add feature_id to consumers)"
```

## Feasibility Protocol

### Protected Path Conflict Detection
```yaml
READ config/protected-paths.json
FROM design.md: EXTRACT target_file_paths[]

FOR EACH path IN target_file_paths:
  IF path IN protected-paths.red_zones:
    ❌ BLOCK: "Implementation targets RED ZONE: {path}. ADR required."
    SUGGEST: "BLUEPRINT --adr {ID} 'Red zone modification: {path}'"
  IF path IN protected-paths.yellow_zones:
    ⚠️ WARN: "Implementation targets YELLOW ZONE: {path}. Extra review required."
    ANNOTATE: task with yellow_zone flag for REVIEW hat attention
```

## Plan Generation (Phase Structure)

### Strategy Branch: Monolithic vs Incremental

Plan generation forks on `fm_plan.slicing_strategy`:

**Monolithic (`slicing_strategy: monolithic`):** single implicit increment INC-1 covers the entire feature. Tasks retain the legacy flat tagging `[A.M]`, `[B.M]`, `[C.M]`. dev_plan.md has one `## Phase A`, one `## Phase B`, one `## Phase C` section. Completion gate trips when ALL Phase-A/B/C checkboxes are `[x]`.

**Incremental (`slicing_strategy: incremental`):** dev_plan.md has one `## Increment INC-N: {title}` section per increment in `target_increments` (ordered topologically by `depends_on`). Each increment section contains Phase A / Phase B / Phase C sub-sections inheriting the task shapes below, but with tags nested as `[INC-N.A.M]`, `[INC-N.B.M]`, `[INC-N.C.M]`. Completion gate is **per-increment** (see `### Per-Increment Completion Gate` below); the plan-level `status: IMPLEMENTED_AND_VERIFIED` is set only when EVERY target increment's gate passes.

```yaml
FUNCTION generate_dev_plan_body(target_increments, fm_plan):
  IF fm_plan.slicing_strategy == "monolithic":
    WRITE "## Phase A: Backend / Core Logic" + EXPAND_PHASE_A_TASKS(full_feature_scope)
    WRITE "## Phase B: Frontend / UI"         + EXPAND_PHASE_B_TASKS(full_feature_scope) IF frontend.framework != "None"
    WRITE "## Phase C: Wiring / Integration"  + EXPAND_PHASE_C_TASKS(full_feature_scope)
    RETURN

  # Incremental — one section per increment, topologically ordered
  FOR EACH inc IN target_increments:
    WRITE "## Increment {inc.id}: {inc.title}"
    WRITE "> **Status:** {inc.status}"
    WRITE "> **Depends on:** {inc.depends_on}"
    WRITE "> **Branch:** feature/{FEATURE_ID}-inc-{N}-{slug}"
    WRITE "> **Deployable target:** production (acceptance from increment_plan.md § 1)"
    WRITE ""
    # Restrict task generation to THIS increment's scenario & contract scope
    inc_scope = {
      scenarios: inc.scenarios_covered,
      contract_ops: inc.contract_surface
    }
    WRITE "### Phase A: Backend / Core Logic" + EXPAND_PHASE_A_TASKS(inc_scope, tag_prefix="INC-{N}.A")
    WRITE "### Phase B: Frontend / UI"         + EXPAND_PHASE_B_TASKS(inc_scope, tag_prefix="INC-{N}.B") IF frontend.framework != "None"
    WRITE "### Phase C: Wiring / Integration"  + EXPAND_PHASE_C_TASKS(inc_scope, tag_prefix="INC-{N}.C")
    WRITE "### Increment {inc.id} Acceptance Gate"
    FOR EACH item IN inc.acceptance_checklist:
      WRITE "- [ ] [INC-{N}.ACC.{k}] {item.description}"
```

The task templates in Phase A / Phase B / Phase C below are authored as if for monolithic plans (no `INC-N` prefix shown). Under incremental generation, apply `tag_prefix` replacement: every `[A.M]` becomes `[INC-N.A.M]`, every `[B.M]` becomes `[INC-N.B.M]`, every `[C.M]` becomes `[INC-N.C.M]`. All reference paths (`design.md`, `contracts/**`, `test_plan.md`) stay identical — only the scoping filter changes which scenarios / ops each increment expands.

### Per-Increment Completion Gate (`slicing_strategy: incremental`)

Each increment closes independently. When all `[INC-N.*]` checkboxes inside Increment N's section are `[x]` AND the `[INC-N.ACC.*]` items are `[x]`:

1. UPDATE `increment_plan.md` § 1 INC-N frontmatter: `status: READY → BUILDING` at branch open; `BUILDING → MERGED` is set by the git merge hook (not by IMPLEMENT --plan).
2. UPDATE `dev_plan.md` frontmatter `increments[]` array: `{id: "INC-N", status: "IMPLEMENTED_AND_VERIFIED"}`.
3. Plan-level `status` transitions to `IMPLEMENTED_AND_VERIFIED` ONLY when every target increment is `IMPLEMENTED_AND_VERIFIED` AND every follow-up increment added later (if any) also closes.

Increment branches (`feature/{FEATURE_ID}-inc-N-{slug}`) are opened by Factory-branching-strategy; one PR per increment. Branch open is the trigger that flips the increment's `status` from `READY → BUILDING`. See `.claude/skills/Factory-branching-strategy/SKILL.md`.

### Phase A: Backend / Core Logic
```yaml
TASKS:
  # A.0: Mandatory Shared Components (from GCD 7.8 / Constitution / ADRs)
  # These tasks are generated by load_mandatory_patterns() above.
  # They MUST appear BEFORE feature-specific tasks because feature code depends on them.
  # Examples: BaseRepository, TenantMiddleware, GlobalErrorHandler, AuditLogger.
  # If a mandatory component already exists in the codebase, the task is INTEGRATION
  # (verify usage) rather than CREATION.
  A.0.N: Shared component tasks from mandatory patterns
    - Source: design.md Section 7.8 mandatory_patterns + fdr_bindings (legacy projects: adr_bindings)
    - Priority: PREREQUISITE — must complete before A.2+ tasks
    - CIP: Check codebase_inventory for existing shared components
    - Invariant: "{implementation_invariant from Section 7.8}"

  A.1: Contract Verification Gate
    - Verify OpenAPI/GraphQL/gRPC/AsyncAPI contract files exist per contract-first-policy
    - Validate contracts match design.md specifications
  
  A.2: Database / Data Layer
    - Schema migrations (if database changes in design.md)
    - Repository / data access layer
    - Seed data for testing
  
  A.3: Business Logic / Domain Services
    - Service implementations following design.md architecture
    - Business policy enforcement (from user_journey.md policies)
    - External system adapter implementations
  
  A.4: API Endpoints / Controllers
    - Implement routes from contract files
    - Request validation, error handling
    - Middleware/guards/interceptors
  
  A.5: Unit + Integration Tests (TDD)
    - One test per business rule
    - API integration tests against contract
    - Mock external dependencies
  
  A.6: Configuration
    - Environment variables setup
    - Feature flags (if applicable)
```

### Phase B: Frontend / UI (if frontend.framework != "None")
```yaml
TASKS:
  # B.0: Frontend Foundation (CSS/Design Token Scaffolding — v12.1.0)
  # These tasks MUST complete BEFORE any component implementation.
  # Without this foundation, components are generated with default/empty styles
  # instead of the project's design system tokens.
  # Priority: PREREQUISITE — must complete before B.1+ tasks.
  
  B.0: Frontend Foundation (CSS / Design Token Materialization)
    # PURPOSE: Materialize the COMPLETE CSS foundation so Phase B components
    # render with EXACT visual fidelity to mock.html. This is NOT just
    # "install framework" — it produces the full design token set, component
    # classes, and layout utilities that mock.html's CSS defines.
    # Without this, Phase B components render with generic utility guesses.
    # SOURCE OF TRUTH: design.md Section 6 (Frontend UI Contract).
    - B.0.1: CSS Toolchain Setup
      - Install CSS framework dependencies per constitution.md (stack config)
      - Configure build pipeline (postcss, preprocessors, etc.)
      - Verify framework compiles with empty config
    - B.0.2: Design Token Materialization (from design.md Section 6.1)
      - READ Section 6.1 token_mapping_table + semantic_alias_table
      - MATERIALIZE ALL tokens into the project's CSS entry point (globals.css or equivalent)
      - Include: scale tokens (full color palette), semantic aliases, typography, spacing, radii, effects
      - TRANSLATE tokens into the CSS framework's native format (varies per stack)
      - FALLBACK (no Section 6): READ style_guide.html directly for token extraction
    - B.0.3: Component Class Materialization (from design.md Section 6.6)
      - READ Section 6.6 (Required CSS Additions)
      - APPEND component-level classes to CSS entry point
      - These classes bridge mock.html CSS → framework-aware CSS
      - CRITICAL: Without component classes, each element requires composing 15+ utility classes — error-prone
    - B.0.4: Shared UI Component Scaffolding (from design.md Section 6.4)
      - READ Section 6.4 (Shared UI Components) → build_order_contract
      - CREATE shared component directory
      - CREATE utility helper (class merge function)
      - SCAFFOLD empty component files per build_order_contract
    - B.0.5: Foundation Verification Gate (BLOCKING)
      - BUILD frontend (verify no CSS import errors)
      - VERIFY: CSS entry point has tokens + component classes
      - VERIFY: root layout imports CSS entry point
      - VERIFY: shared component directory exists with stubs
      - IF any check fails → FIX immediately, do NOT proceed to B.1
    - Source: design.md Section 6 (Frontend UI Contract) + constitution.md (stack config)
    - CIP: Check codebase_inventory for existing CSS config / design token files

  B.1: Contract Consumption Gate
    - Verify API client generation from contracts
    - Type generation from OpenAPI/GraphQL schemas
  
  B.2: Shared UI Primitives (from design.md Section 6.4 shared_primitives)
    # SOURCE: design.md Section 6.4 build_order_contract → Blueprint Phase B.1 = shared primitives
    # NOTE: In this IMPLEMENT plan, shared primitives are Phase B.2 because B.1 is
    # reserved for the Contract Consumption Gate prerequisite.
    - For each primitive (Button, Input, Alert, Card, etc.):
      a. READ Section 6.3 mapping table for EXACT CSS framework classes
      b. READ component_library.html for API reference (props, variants)
      c. IMPLEMENT using the Section 6.3 mapping — NOT generic utility guesses
      d. Support ALL variants listed in Section 6.4
      e. Include all ARIA attributes from mock.html
    - REVIEW BLOCKER: using generic utility classes instead of Section 6.3 mapping
  
  B.3: Layout Compositions + Feature Pages
    # SOURCE: design.md Section 6.2 (Layout Contracts) + Section 6.5 (Page Compositions)
    - Implement layouts per Section 6.2 dom_contract (DOM nesting MUST match)
    - Implement pages by composing B.0 + B.2 shared components per Section 6.5
    - IMPLEMENT ALL states (default, loading, error, empty, + feature-specific)
    - Wire form validations to user_journey.md data schemas
    - State management per design.md
  
  B.4: Styling Verification + Responsive
    - VERIFY: all components use Section 6.3 mapping (NOT raw style_guide.html)
    - Responsive design per Section 6.2 responsive_contract
    - WCAG AA compliance per ux-constitution
  
  B.5: Frontend Tests
    - Component unit tests
    - E2E tests for user journeys
    - Accessibility tests (axe-core)
  
  B.6: Navigation Integration
    - Wire routes per UXD navigation (uxd.navigation.feature_placement)
    - Breadcrumb chain from UXD (uxd.navigation.breadcrumb_chain)
    - Feature placement in app shell per UXD shell_composition
```

### Phase C: Wiring / Integration
```yaml
TASKS:
  C.1: Backend ↔ Frontend Integration
    - API client wiring to frontend state
    - Error handling end-to-end
  
  C.2: Cross-Module Integration (if applicable)
    - Inter-domain communication via contracts (HTTP only, no direct imports)
    - Event listeners/publishers (if AsyncAPI contracts exist)
  
  C.3: Integration Testing
    - Full-stack integration tests
    - Contract compliance verification
  
  C.4: Configuration Finalization
    - Environment variable completeness check
    - CI/CD pipeline configuration (if needed)
  
  C.5: Synthetic Data for Staging (conditional — see Synthetic Data Protocol below)
    # Minimum tasks (applies to ALL modules when C.5 is REQUIRED):
    - [ ] C.5.1: Read migration/schema files for target tables and build a column manifest
           (prevention step — know the schema BEFORE writing seed generators)
    - [ ] C.5.2: Create seed data factory/generator with schema-aligned record shapes
           (every key matches a real column, every NOT NULL column is provided)
    - [ ] C.5.3: Implement INSERTs with schema-qualified table names + named parameters
           (no positional placeholders — prevents silent corruption from reordering)
    - [ ] C.5.4: Implement idempotent upsert logic (ON CONFLICT DO NOTHING / DO UPDATE)
    - [ ] C.5.5: Honor UNIQUE constraints across the generated row set
    - [ ] C.5.6: Honor CHECK constraints (enum values match the schema)
    - [ ] C.5.7: Implement reset command (teardown + re-seed in FK-reverse order)
    - [ ] C.5.8: Add fail-secure environment guard (refuse to run when env is unset/ambiguous)
    - [ ] C.5.9: Register in config/seed_registry.json (owned + consumed entities)
    - [ ] C.5.10: Add seed generator to guardrail test registration
    - [ ] C.5.11: Run seed alignment test suite locally and verify exit 0
           (BLOCKING — task cannot be marked [x] if guardrail fails)
    - [ ] C.5.12: Wire seed/reset to the dev/staging deployment pipeline
           (NEVER prod — enforced by both packaging exclusion + runtime guard)
```

### Synthetic Data Protocol (Staging / Preview Environments)

> **Trigger:** Feature has UI (vision APPROVED + mock.html) OR design.md specifies staging data needs.
> **Purpose:** Ensure staging environments have realistic, coherent data for visual verification and QA inspection.
> **Cross-Domain Guarantee:** Referential integrity across bounded contexts via Shared Seed Registry.

```yaml
FUNCTION evaluate_synthetic_data_need(FEATURE_ID):
  # Gate 0: Check if Synthetic Data Protocol is enabled (Q28)
  # Read from governance snapshot (survives summarization) — see INVARIANT 5
  synthetic_enabled = READ .context/governance_snapshot.md → Setup Configuration → synthetic_data.enabled
  IF NOT synthetic_enabled:
    RETURN SKIP  # Project opted out of synthetic data in SETUP
  
  has_ui = READ constitution.md → frontend.framework != "None"
  has_mock = FILE_EXISTS("docs/spec/{FEATURE_ID}/mock.html")
  data_schemas = READ user_journey.md → data_schemas[]
  staging_data = READ design.md → Section 5 "Infrastructure Needs" → staging_data

  IF (has_ui AND has_mock AND data_schemas.length > 0) OR staging_data.required:
    ADD Phase C task [C.5] with the following constraints:
    RETURN REQUIRED
  ELSE:
    RETURN SKIP
```

**Mandatory Properties (when C.5 is REQUIRED):**

| Property | Requirement | Implementation Pattern |
|----------|-------------|------------------------|
| **Idempotency** | Running seed twice must NOT duplicate data | Upsert (ON CONFLICT), check-before-insert, or deterministic IDs with IF NOT EXISTS |
| **Reset capability** | Full teardown + clean re-seed to a known baseline | Dedicated reset command/script: truncate target tables → re-seed (respecting FK order) |
| **Referential coherence** | All IDs across related entities must be valid and consistent | Use deterministic ID generation (sequential or UUID v5 with namespace) — build entity graphs respecting FK dependencies (parent → child order) |
| **Schema alignment** | Synthetic data must match `user_journey.md` Data Schemas | Field names, types, and constraints from Data Schemas are the source of truth |
| **Non-production guard** | Seed scripts must NEVER execute on production | Environment check gate: `IF env == production → ABORT` |
| **Cross-domain registration** | Feature's seed entities MUST be registered in Shared Seed Registry | Register owned entities + declare consumed entities (see below) |

**Task Decomposition Guidance:**
```yaml
# Minimum tasks for C.5:
- [ ] C.5.1: Create seed data factory/generator (entity graph with FK ordering)
- [ ] C.5.2: Implement idempotent upsert logic (safe re-runs)
- [ ] C.5.3: Implement reset command (teardown + re-seed)
- [ ] C.5.4: Add environment guard (block production execution)
- [ ] C.5.5: Register in Shared Seed Registry (owned + consumed entities)
- [ ] C.5.6: Wire seed/reset to deployment pipeline (DEVOPS post-deploy hook)
```

### Shared Seed Registry Protocol (Cross-Domain Referential Integrity)

> **Purpose:** Guarantee referential integrity across bounded contexts when multiple features
> contribute seed data to the same staging environment.
> **Artifact:** `config/seed_registry.json` — central graph of seed dependencies.

#### Registry Structure

```json
{
  "$schema": "seed_registry_v1",
  "shared_fixtures_dir": "config/seed_fixtures/_shared/",
  "shared_entities": {
    "{entity_name}": {
      "owner_domain": "{bounded_context}",
      "owner_feature": "{FEATURE_ID or _shared}",
      "fixture_path": "{relative path to fixture JSON/SQL}",
      "id_strategy": "deterministic_sequential | uuid_v5_namespace | natural_key",
      "id_config": { "prefix": "{prefix}", "namespace": "{ns}", "start": 1 },
      "table_or_collection": "{target table/collection name}",
      "count": 0,
      "consumers": ["{bounded_context_1}", "{bounded_context_2}"]
    }
  },
  "dependency_graph": {
    "{entity_A}": [],
    "{entity_B}": ["{entity_A}"],
    "{entity_C}": ["{entity_A}", "{entity_B}"]
  },
  "seed_order": ["{entity_A}", "{entity_B}", "{entity_C}"],
  "reset_order": ["{entity_C}", "{entity_B}", "{entity_A}"]
}
```

#### IMPLEMENT Responsibilities (C.5.5 — Registry Registration)

```yaml
FUNCTION register_seed_entities(FEATURE_ID):
  registry_path = "config/seed_registry.json"
  
  # Step 1: Load or create registry
  IF NOT FILE_EXISTS(registry_path):
    CREATE registry with $schema + empty shared_entities/dependency_graph
  registry = READ(registry_path)
  
  # Step 2: Read feature's data model from design.md
  entities = READ design.md → Section 2 Component Inventory → data entities
  schemas = READ user_journey.md → data_schemas[]
  
  # Step 3: Classify each entity
  FOR EACH entity IN entities:
    IF entity is NEW to registry (not in shared_entities):
      # Register as OWNED by this feature
      registry.shared_entities[entity.name] = {
        owner_domain: entity.module,
        owner_feature: FEATURE_ID,
        fixture_path: "config/seed_fixtures/{FEATURE_ID}/{entity.name}.json",
        id_strategy: DERIVE_FROM(entity.primary_key_type),
        table_or_collection: entity.table_name,
        count: DERIVE_FROM(entity.sizing or default 20),
        consumers: []
      }
    ELSE:
      # Entity already registered — this feature CONSUMES it
      registry.shared_entities[entity.name].consumers.APPEND(entity.module)
  
  # Step 4: Build dependency graph from FK relationships
  FOR EACH entity IN entities:
    fk_targets = EXTRACT foreign_keys FROM entity schema
    registry.dependency_graph[entity.name] = fk_targets.map(fk → fk.target_entity)
  
  # Step 5: Topological sort → seed_order (parents first) + reset_order (children first)
  registry.seed_order = TOPOLOGICAL_SORT(registry.dependency_graph)
  registry.reset_order = REVERSE(registry.seed_order)
  
  # Step 6: Validate no circular dependencies
  IF CYCLE_DETECTED(registry.dependency_graph):
    ❌ BLOCK: "Circular FK dependency detected: {cycle_path}"
    SUGGEST: "Break cycle using nullable FK or deferred constraint"
  
  # Step 7: Create fixture files
  FOR EACH owned_entity (owner_feature == FEATURE_ID):
    CREATE fixture file at fixture_path:
      - Generate deterministic data from user_journey.md Data Schemas
      - Use declared id_strategy for reproducible IDs
      - Reference parent entities by their registered IDs (from fixture files)
  
  SAVE(registry_path)  # IMMEDIATE
```

#### Cross-Domain Integrity Validation (build-time)

```yaml
FUNCTION validate_seed_integrity():
  # Run during IMPLEMENT --build and DEVOPS --deploy (non-production)
  registry = READ("config/seed_registry.json")
  
  # Check 1: All consumers have providers
  FOR EACH entity, deps IN registry.dependency_graph:
    FOR EACH dep IN deps:
      IF dep NOT IN registry.shared_entities:
        ❌ FAIL: "{entity} depends on {dep} which has no registered seed fixture"
  
  # Check 2: FK reference validity across fixture files
  FOR EACH entity IN registry.seed_order:
    fixture = READ(registry.shared_entities[entity].fixture_path)
    FOR EACH record IN fixture:
      FOR EACH fk_field IN record WHERE fk_field IN dependency_graph[entity]:
        parent_entity = dependency_graph[entity][fk_field]
        parent_fixture = READ(parent_entity.fixture_path)
        parent_ids = parent_fixture.map(r → r.id)
        IF record[fk_field] NOT IN parent_ids:
          ❌ FAIL: "Orphan FK: {entity}.{fk_field}={record[fk_field]} → {parent_entity} has no such ID"
  
  # Check 3: ID uniqueness per entity
  FOR EACH entity IN registry.shared_entities:
    fixture = READ(entity.fixture_path)
    ids = fixture.map(r → r.id)
    IF ids.length != UNIQUE(ids).length:
      ❌ FAIL: "Duplicate IDs in {entity}: {duplicates}"
  
  # Check 4: Schema compliance
  FOR EACH entity IN registry.shared_entities:
    IF entity has matching user_journey.md schema:
      VALIDATE fixture fields against schema (types, required, constraints)
  
  ✅ All checks pass → seed data is referentially coherent across all domains
```

## UX Artifacts Integration (Vision + Feature)

### Global Vision References (V.1–V.6) — UXD Fast-Path (v12.1.0)

> **Source:** `design.md Section 7.6: UX Vision Digest (UXD)`. BLUEPRINT pre-digested all 5 vision
> HTML/MD artifacts into a compact structured section. IMPLEMENT reads ONE section — no raw HTML loading.
> Fallback to raw HTML files ONLY if UXD is absent (pre-v12.1.0 BLUEPRINT).

```yaml
FUNCTION load_ux_vision_context(FEATURE_ID):
  uxd = READ(design.md, "## Section 7" → "### 7.6")
  
  IF uxd EXISTS AND uxd.uxd_version EXISTS:
    # UXD FAST-PATH: All vision data pre-digested by BLUEPRINT
    V.1: shell_composition = uxd.shell_composition  # app_shell structure, regions, landmarks
    V.2: design_tokens = uxd.design_tokens  # colors, typography, spacing, breakpoints
    V.3: page_templates = uxd.page_templates  # template types + feature_template_type
    V.4: component_library = uxd.component_library  # reusable components for REUSE classification
    V.5: navigation = uxd.navigation  # nav tree + feature_placement + breadcrumbs
    V.6: mock_analysis = uxd.mock_component_analysis  # VISION_REUSE vs FEATURE_NEW per component
    LOG: "UXD fast-path HIT ✅ — vision context loaded from design.md Section 7.6 (skipped 5 HTML files)"
    RETURN { uxd, uxd_loaded: true }
  
  ELSE:
    # FALLBACK: Load raw vision files (pre-v12.1.0 BLUEPRINT)
    LOG: "⚠️ UXD not found in design.md Section 7.6 (pre-v12.1.0 BLUEPRINT). Loading raw HTML files."
    V.1: READ app_shell.html → Determine shell composition (header, sidebar, footer)
    V.2: READ style_guide.html → Extract design tokens (CSS variables, color palette, typography scale)
    V.3: READ page_templates.html → Identify which template type this feature uses
    V.4: READ component_library.html → Catalog available components for REUSE
    V.5: READ navigation_map.md → Determine feature placement in navigation hierarchy
    V.6: Cross-reference navigation_map entries with feature routes from design.md
    LOG: "UXD fast-path MISS — loaded 5 raw vision files (consider: BLUEPRINT --refine {FEATURE_ID})"
    RETURN { uxd: null, uxd_loaded: false }
```

### Feature-Specific References (B.1–B.8)

> **Note:** B.4, B.5 use UXD data (shell_composition, component_library) when uxd_loaded == true.
> B.1, B.6, B.8 still require mock.html (feature-specific, NOT in UXD).

```yaml
B.1: Load mock.html → Extract visual structure (DOM hierarchy, CSS classes, accessibility attrs)
B.2: Load spec.feature → Map scenarios to frontend interactions
B.3: Load user_journey.md → Extract data schemas for form fields, display components
B.4: Verify mock.html inherits vision shell correctly:
     IF uxd_loaded: compare mock DOM against uxd.shell_composition.shell_regions
     ELSE: compare against app_shell.html
B.5: Compare mock components against component library → classify REUSE vs NEW:
     IF uxd_loaded: use uxd.mock_component_analysis (pre-classified by BLUEPRINT)
     ELSE: compare against component_library.html
B.6: Extract responsive breakpoints from mock.html @media queries:
     IF uxd_loaded: cross-reference against uxd.design_tokens.breakpoints
B.7: Validate WCAG requirements from ux-constitution.md
B.8: Map error scenarios from spec.feature to mock error states
```

### Vision Fidelity Rule
```yaml
ANNOTATE all Phase B tasks with:
  "Vision Binding: Frontend implementation MUST faithfully materialize the approved vision.
   Source: design.md Section 7.6 UX Vision Digest (UXD) — pre-digested by BLUEPRINT.
   
   REVIEW hat [UX-VISION] will validate:
   - Shell fidelity (uxd.shell_composition — regions, landmarks, CSS classes)
   - Page template adherence (uxd.page_templates.feature_template_type)
   - Component library reuse (uxd.component_library — no duplicates of vision components)
   - Token consistency (uxd.design_tokens — CSS variables translated to stack config in B.0)
   - Navigation integration (uxd.navigation.feature_placement — correct route and breadcrumb)
   
   BLOCKER violations:
   - Duplicating a component classified as VISION_REUSE in uxd.mock_component_analysis
   - Hardcoding colors/fonts/spacing when design tokens exist in uxd.design_tokens
   - Shell structure deviation from uxd.shell_composition.shell_regions"
```

## Output: dev_plan.md

### Frontmatter
```yaml
---
status: READY
feature_id: "{FEATURE_ID}"
created_at: "{ISO_8601}"
based_on_iteration: {spec.iteration}
based_on_schemas_version: {user_journey.schemas_version}
slicing_strategy: "{fm_plan.slicing_strategy}"   # inherited from increment_plan.md — drives plan body structure
pending_iteration: null
pending_schemas_version: null
invalidated_sections: []
invalidated_increments: []        # list of INC-N ids invalidated by CASCADE_INCREMENT_INTERNAL (incremental only)
cascade_source: null
review_status: null
sec_status: null
phases:                           # populated when slicing_strategy == monolithic
  A: { tasks: N, estimated_complexity: "medium" }
  B: { tasks: N, estimated_complexity: "medium" }
  C: { tasks: N, estimated_complexity: "low" }
increments:                       # populated when slicing_strategy == incremental; empty list when monolithic
  - id: "INC-1"
    status: "READY"               # READY | BUILDING | IMPLEMENTED_AND_VERIFIED | INVALIDATED (mirror of increment_plan.md § 1 INC-N status; READY-or-later only — DRAFT stays in increment_plan.md)
    tasks: { A: N, B: N, C: N, ACC: N }
  - id: "INC-2"
    status: "READY"
    tasks: { A: N, B: N, C: N, ACC: N }
total_tasks: N
---
```

### Task Format — Monolithic (`slicing_strategy: monolithic`)
```markdown
## Phase A: Backend / Core Logic

- [ ] A.1: Contract Verification Gate
  - Contracts: [list from contract-first-policy]
  - CIP: {REUSE|EXTEND|CREATE_NEW annotation}

- [ ] A.2: Database migrations
  - Schema: {from design.md data model}
  - Tests: {from test_plan.md}

[... etc]
```

### Task Format — Incremental (`slicing_strategy: incremental`)
```markdown
## Increment INC-1: User can submit a claim
> **Status:** READY
> **Depends on:** []
> **Branch:** feature/{FEATURE_ID}-inc-1-submit-claim
> **Deployable target:** production (acceptance from increment_plan.md § 1)

### Phase A: Backend / Core Logic

- [ ] [INC-1.A.1] Contract Verification Gate
  - Contracts: contracts/openapi/claims/v1.yaml → POST /claims
  - CIP: {REUSE|EXTEND|CREATE_NEW annotation}

- [ ] [INC-1.A.2] Database migration — claims table

### Phase B: Frontend / UI
- [ ] [INC-1.B.1] ClaimForm component
  - Ref: design.md § UI Inventory → ClaimForm

### Phase C: Wiring / Integration
- [ ] [INC-1.C.1] E2E happy path — submit claim

### Increment INC-1 Acceptance Gate
- [ ] [INC-1.ACC.1] All assigned scenarios pass E2E
- [ ] [INC-1.ACC.2] CVP increment_deployability PASS
- [ ] [INC-1.ACC.3] No TODO markers in INC-1 code paths

## Increment INC-2: User can edit a submitted claim
> **Status:** READY
> **Depends on:** [INC-1]
> **Branch:** feature/{FEATURE_ID}-inc-2-edit-claim
...
```

**Task Tag Regex (machine-consumable):**
- Monolithic: `^\[([ABC])\.(\d+)\]`
- Incremental: `^\[INC-(\d+)\.([ABC]|ACC)\.(\d+)\]`

These regexes are the source of truth for CVP Check 17 (`increment_to_task`), BVL task matching, and QA coverage reporting. All downstream consumers parse task IDs via these patterns.

## Incremental Persistence (IPP-compliant — MANDATORY)

> **Implements:** Incremental Persistence Protocol (`.claude/skills/Factory-incremental-persistence/SKILL.md`) — Pillars 1, 2, 3.

**Pillar 1 — Skeleton-First Write:**
```yaml
FUNCTION implement_plan_skeleton(FEATURE_ID):
  path = "docs/spec/{FEATURE_ID}/dev_plan.md"
  IF NOT FILE_EXISTS(path):
    WRITE_SKELETON(path):
      frontmatter:
        status: DRAFT
        feature_id: "{FEATURE_ID}"
        created_at: "{ISO_8601}"
        _progress:
          current_phase: "skeleton"
          completed_sections: []
          pending_sections: ["phase_A", "phase_B", "phase_C", "ux_refs", "cip_annotations"]
          decisions: []
          last_agent: "IMPLEMENT"
          last_command: "--plan {FEATURE_ID}"
          resumable: true
      body: PHASE_HEADERS_WITH_PENDING_MARKERS()
    SAVE(path)  # IMMEDIATE
```

**Pillar 2 — Section-Atomic Saves (per phase group):**
```yaml
# Save after completing EACH phase's task group:
FOR EACH phase IN [A, B, C]:
  tasks = GENERATE_PHASE_TASKS(phase)
  WRITE_PHASE_SECTION(path, phase, tasks)
  UPDATE_FRONTMATTER(path):
    _progress.completed_sections: APPEND("phase_{phase}")
    _progress.pending_sections: REMOVE("phase_{phase}")
    _progress.current_phase: "{next_phase}"
    updated_at: "{ISO_8601}"
  SAVE(path)  # IMMEDIATE — phase is on disk before generating next
```

**Pillar 3 — Resume-on-Entry:**
```yaml
FUNCTION implement_plan_resume(FEATURE_ID):
  path = "docs/spec/{FEATURE_ID}/dev_plan.md"
  IF FILE_EXISTS(path):
    fm = READ_FRONTMATTER(path)
    IF fm._progress IS NOT NULL AND fm._progress.pending_sections.length > 0:
      LOG: "RESUME: dev_plan.md — {fm._progress.completed_sections.length} sections done"
      RECOVER_DECISIONS(fm._progress.decisions)
      RESUME_FROM(fm._progress.pending_sections[0])
      RETURN "RESUMED"
  RETURN "FRESH"
```

**Finalization (status → READY):**
```yaml
# When all phases generated → finalize _progress
UPDATE_FRONTMATTER(path):
  status: READY
  _progress: null  # Plan complete, tasks are the checkboxes now
SAVE(path)
```

## Post-Plan Actions
```yaml
APPEND_TO_WORKLOG: |
  {"timestamp":"YYYY-MM-DD","phase":"Dev (Planning)","user_agent":"IMPLEMENT","action":"--plan {FEATURE_ID}","result":"COMPLETED","feature_id":"{FEATURE_ID}","observations":"dev_plan.md created — {total_tasks} tasks across phases A/B/C — status: READY"}

# Return to Factory — Smart Redirect computes next steps from artifact state
RETURN_TO_FACTORY(FEATURE_ID)
```
