---
name: factory-iteration-model
description: "Factory Iteration Model — domain-driven incremental development, change classification, version vs iteration, cascade invalidation. Use when: handling upstream spec changes, delta iterations, or version bumps."
applicable_when:
  always: true
---

# ITERATION MODEL (Domain-Driven Incremental Development)

> **Shared Protocol** — Referenced by: Factory, CODESIGN, BLUEPRINT, IMPLEMENT, DEVOPS, QA agents.
> Feature IDs represent domains, bounded contexts, or logical components — NOT individual use cases. Features evolve iteratively through additive refinements (iterations) or structural changes (versions).

---

## Iteration vs Version

| Aspect | Iteration (`CODESIGN --refine` → DELTA/FORCE_DELTA) | Version (new Feature ID) |
|---------|-----------------------------------------------|-------------------------|
| **Trigger** | Add/improve/extend use cases | Fundamental redesign or breaking-only |
| **Feature ID** | Same (e.g., AUTH-001) | New (e.g., AUTH-001-v2) |
| **Artifacts** | Evolve cumulatively (delta) | Copied as fresh start |
| **Downstream** | Delta updates (only affected) | Full regeneration |
| **Example** | Add OAuth to Auth domain | Rewrite Auth from scratch |
| **iteration: N** | Incremented in spec.feature frontmatter | N/A (new feature) |

---

## Change Classification Protocol (Executed by CODESIGN Agent)

When `CODESIGN --refine` receives feedback on an APPROVED spec with downstream work, it classifies each proposed change:

### Level 1: Structural Classification (Deterministic)

```yaml
DELTA (additive - does not break existing downstream):
  - New Scenario: added to spec.feature
  - New NFR in initial.md
  - New API endpoint (without modifying existing ones)
  - New OPTIONAL entity/field

BREAKING_CANDIDATE (potentially breaks downstream):
  - New Given/When/Then step at the END of existing scenario
  - Modify Given/When/Then of existing scenario
  - Change business rule in existing scenario
  - Add REQUIRED field to existing entity

BREAKING (always breaks downstream):
  - Delete complete Scenario
  - Modify existing API contract (remove field, change type)
  - Change field type of existing entity
  - Rename core entity
```

### Level 2: Cross-Reference Downstream (for BREAKING_CANDIDATE)

```yaml
FOR EACH modified_scenario IN proposed_changes WHERE type == "BREAKING_CANDIDATE":
  scenario_id = modified_scenario.name
  
  test_mapped   = GREP(test_plan.md, scenario_id)
  design_mapped = GREP(design.md, scenario_id)
  dev_mapped    = GREP(dev_plan.md, scenario_id)
  code_search_roots = [${BACKEND_BASE_PATH}, ${FRONTEND_BASE_PATH}, ${TESTS_BASE_PATH}]
  code_mapped       = GREP(code_search_roots, scenario_id)
  
  IF test_mapped OR design_mapped OR dev_mapped OR code_mapped:
    → BREAKING CHANGE CONFIRMED (affected: [list])
  ELSE:
    → PROMOTE TO DELTA (scenario not consumed downstream)
```

### Level 3: Decision (Executed by CODESIGN Agent)

```yaml
breaking_count = COUNT(confirmed_breaking)
delta_count    = COUNT(delta_changes)

IF breaking_count == 0:
  MODE: ITERATION → Open new iteration automatically

ELIF breaking_count > 0 AND delta_count > 0:
  MODE: HYBRID → Offer options:
    1. SPLIT: Delta as iteration + Breaking as auto-scaffold new FEATURE_ID
    2. ALL_REVISE: All as new version with new Feature ID
    3. FORCE_DELTA: Accept impact, propagate as iteration with selective invalidation

ELIF breaking_count > 0 AND delta_count == 0:
  MODE: REVISE → New Feature ID (pure breaking)
```

---

## Downstream Iteration Detection Protocol (MANDATORY - ALL AGENTS)

**Applies to:** `BLUEPRINT`, `QA`, `IMPLEMENT`, `DEVOPS`

### Iteration Detection Gate (BLOCKING — runs BEFORE any command that reads upstream artifacts)

```yaml
FUNCTION iteration_detection_gate(FEATURE_ID, current_agent, command):
  # This gate MUST be the FIRST operation in any command that reads feature artifacts.
  # It BLOCKS execution if upstream artifacts have been modified since this agent's
  # last sync, preventing stale-data processing.

  # Commands that require this gate:
  GATED_COMMANDS = [
    "BLUEPRINT --start", "BLUEPRINT --refine", "BLUEPRINT --approve",
    "IMPLEMENT --plan", "IMPLEMENT --build", "IMPLEMENT --refine", "IMPLEMENT --fix",
    "DEVOPS --configure", "DEVOPS --deploy", "DEVOPS --provision",
    "QA --verify"
  ]

  IF command NOT IN GATED_COMMANDS:
    ✅ SKIP gate — command does not read upstream artifacts
    RETURN

  # Execute Steps 0-4 below
  # If gap detected → PROMPT user (DELTA/FULL/SKIP)
  # If Upstream Sync Gate fails (Step 4) → ❌ BLOCK with specific redirect
  # Only after all steps pass → ✅ PROCEED with command execution
```

**Execute BEFORE any command that reads upstream artifacts:**

```yaml
Step 0: Legacy-Safe Defaults
  # For artifacts created before the iteration model, fields may be missing.
  #   - spec.iteration: default = 1 if missing
  #   - artifact.based_on_iteration: default = 1 if missing
  #   - artifact.pending_iteration: default = NULL if missing
  #   - last_iteration_scope: default = "Initial version" if missing

Step 1: Read upstream spec.feature frontmatter
  Extract: iteration (default = 1 if missing)
  Extract: last_iteration_scope (default = "Initial version" if missing)

Step 1b: Read upstream user_journey.md frontmatter (if exists)
  Extract: schemas_version (default = 1 if missing)

Step 2: Read OWN artifact frontmatter
  Extract: based_on_iteration (default = 1 if missing)
  Extract: based_on_schemas_version (default = 1 if missing)
  Extract: pending_iteration (default = NULL if missing)
  Extract: pending_schemas_version (default = NULL if missing)
  Extract: invalidated_sections (default = [] if missing)

Step 3: Detect iteration gap (TWO sources)
  
  # Source A: Pull-based comparison
  pull_gap = (spec.iteration > artifact.based_on_iteration)
  
  # Source B: Push-based cascade
  push_gap = (artifact.pending_iteration IS NOT NULL AND artifact.pending_iteration > artifact.based_on_iteration)
  
  has_iteration_gap = pull_gap OR push_gap
  
  IF has_iteration_gap:
    target_iteration = MAX(spec.iteration, artifact.pending_iteration OR 0)
    iteration_gap = target_iteration - artifact.based_on_iteration
    
    PROMPT: |
      🔄 **ITERATION GAP DETECTED** (gap: {{iteration_gap}})
      
      spec.feature is at iteration {{spec.iteration}}, but your 
      {{ARTIFACT_NAME}} was built against iteration {{artifact.based_on_iteration}}.
      {{IF push_gap: "⚡ Upstream agent flagged this artifact as stale."}}
      
      Changes since your last sync:
      {{FOR EACH iter FROM artifact.based_on_iteration+1 TO target_iteration:}}
        Iteration {{iter}}: {{iter.scope_summary}}
      {{END FOR}}
      
      {{IF invalidated_sections.length > 0:}}
      ⚠️ Specifically invalidated sections: {{invalidated_sections}}
      {{END IF}}
      
      Options:
      1. DELTA: Update only affected sections (recommended for additive changes)
      2. FULL: Re-generate entire artifact from scratch
      3. SKIP: Proceed without sync (⚠️ traceability gap)
    
    WAIT_FOR_USER_CHOICE()
    
    IF choice == DELTA:
      UPDATE artifact frontmatter:
        based_on_iteration = target_iteration
        based_on_schemas_version = user_journey.schemas_version
        pending_iteration = NULL
        pending_schemas_version = NULL
        invalidated_sections = []
      # MANDATORY: Execute CASCADE_PENDING_ITERATION for own downstream
    
    IF choice == FULL:
      UPDATE artifact frontmatter: (same as DELTA)
      # MANDATORY: Execute CASCADE_PENDING_ITERATION for own downstream
    
    IF choice == SKIP:
      LOG: "⚠️ Traceability gap: {{ARTIFACT}} not synced with iteration {{target_iteration}}"
  
  ELSE:
    ✅ PROCEED normally

Step 4: Upstream Sync Gate (MANDATORY for IMPLEMENT and DEVOPS)
  IF current_agent IN [IMPLEMENT, DEVOPS]:
    Read: design.md frontmatter → pending_iteration, based_on_iteration
    Read: test_plan.md frontmatter → pending_iteration, based_on_iteration
    
    blueprint_stale = (design.md.pending_iteration IS NOT NULL AND design.md.pending_iteration > design.md.based_on_iteration)
                   OR (test_plan.md.pending_iteration IS NOT NULL AND test_plan.md.pending_iteration > test_plan.md.based_on_iteration)
                   OR (spec.iteration > design.md.based_on_iteration)
                   OR (spec.iteration > test_plan.md.based_on_iteration)
    
    IF blueprint_stale:
      ❌ BLOCK: "🛑 UPSTREAM NOT SYNCED — Run `BLUEPRINT --refine {{ID}}` first"
      STOP
```

---

## Downstream Cascade Invalidation Protocol (MANDATORY —)

When an upstream agent opens a new iteration or syncs its artifacts via DELTA/FULL, it MUST **push** `pending_iteration` to ALL existing downstream artifacts. This converts the pull-based model into a **push+pull hybrid**.

**Why:** Without push-based invalidation, downstream artifacts retain `status: APPROVED` after upstream changes. Smart Redirect sees these statuses and suggests progressing instead of re-syncing.

**Applies to:** ALL agents that perform `--refine` on APPROVED artifacts or sync via Downstream Iteration Detection.

### Cascade Completion Verification Gate (BLOCKING — runs AFTER every cascade execution)

```yaml
FUNCTION verify_cascade_completion(FEATURE_ID, target_iteration, current_agent):
  # This gate MUST execute AFTER CASCADE_PENDING_ITERATION and BEFORE
  # the agent emits its Completion Summary. Verifies no downstream artifact
  # was missed by the cascade.

  base_path = "docs/spec/{FEATURE_ID}"
  expected_targets = DETERMINE_DOWNSTREAM(current_agent)
  missed_targets = []

  FOR EACH artifact_name IN expected_targets:
    IF artifact_name == "qa_report":
      latest = LATEST("{base_path}/qa/qa_report_final_*.md")
      IF latest AND READ_FRONTMATTER(latest, "status") == "APPROVED":
        ❌ missed_targets.push("qa_report (should be INVALIDATED)")
      CONTINUE

    path = "{base_path}/{artifact_name}"
    IF FILE_EXISTS(path):
      fm = READ_FRONTMATTER(path)
      IF fm.status NOT IN ["DRAFT", "NEEDS_INFO"]:  # Only check non-draft
        IF fm.pending_iteration IS NULL OR fm.pending_iteration < target_iteration:
          missed_targets.push(artifact_name)

  IF missed_targets.length > 0:
    ❌ BLOCK: "CASCADE INCOMPLETE — {missed_targets.length} downstream artifacts missed:"
    FOR EACH t IN missed_targets:
      SHOW: "  - {t}: pending_iteration not set to {target_iteration}"
    EXECUTE: CASCADE_PENDING_ITERATION(FEATURE_ID, target_iteration, ...)  # Auto-fix
    LOG: "CASCADE auto-corrected: re-pushed to {missed_targets}"

  ✅ Cascade verified — all downstream artifacts received pending_iteration
```

```yaml
FUNCTION CASCADE_PENDING_ITERATION(FEATURE_ID, target_iteration, target_schemas_version, affected_scopes):
  base_path = "docs/spec/{{FEATURE_ID}}"
  
  # Determine downstream artifacts based on current agent
  downstream_artifacts = DETERMINE_DOWNSTREAM(current_agent):
    
    IF current_agent == "CODESIGN":
      targets = []
      IF FILE_EXISTS("{{base_path}}/design.md"): targets.push("design.md")
      IF FILE_EXISTS("{{base_path}}/test_plan.md"): targets.push("test_plan.md")
      IF FILE_EXISTS("{{base_path}}/dev_plan.md"): targets.push("dev_plan.md")
      IF FILE_EXISTS("{{base_path}}/devops_plan.md"): targets.push("devops_plan.md")
      # frozen contracts invalidate on scenario/schema/contract changes
      IF DIR_EXISTS("{{base_path}}/contracts/") AND ("new_scenario" IN affected_scopes OR "schema_change" IN affected_scopes OR "contract_change" IN affected_scopes):
        targets.push("contracts_freeze")
      # runtime reports invalidate on anything upstream of IMPLEMENT
      IF FILE_EXISTS("{{base_path}}/preventive_sweep_report.md"): targets.push("preventive_sweep_report")
      IF FILE_EXISTS("{{base_path}}/smoke_e2e_report.md"): targets.push("smoke_e2e_report")
      RETURN targets
    
    IF current_agent == "BLUEPRINT":
      targets = []
      IF FILE_EXISTS("{{base_path}}/dev_plan.md"): targets.push("dev_plan.md")
      IF FILE_EXISTS("{{base_path}}/devops_plan.md") AND "infra_change" IN affected_scopes:
        targets.push("devops_plan.md")
      IF GLOB_EXISTS("{{base_path}}/qa/qa_report_final_*.md"):
        targets.push("qa_report")
      # BLUEPRINT owns the frozen contract set; any contract-relevant change invalidates it
      IF DIR_EXISTS("{{base_path}}/contracts/") AND ("schema_change" IN affected_scopes OR "contract_change" IN affected_scopes OR "new_scenario" IN affected_scopes):
        targets.push("contracts_freeze")
      # runtime reports invalidate on any blueprint change that reaches code
      IF FILE_EXISTS("{{base_path}}/preventive_sweep_report.md"): targets.push("preventive_sweep_report")
      IF FILE_EXISTS("{{base_path}}/smoke_e2e_report.md"): targets.push("smoke_e2e_report")
      RETURN targets
    
    IF current_agent == "IMPLEMENT":
      targets = []
      IF GLOB_EXISTS("{{base_path}}/qa/qa_report_final_*.md"):
        targets.push("qa_report")
      # every code change invalidates runtime scans and smoke blocks
      IF FILE_EXISTS("{{base_path}}/preventive_sweep_report.md"): targets.push("preventive_sweep_report")
      IF FILE_EXISTS("{{base_path}}/smoke_e2e_report.md"): targets.push("smoke_e2e_report")
      RETURN targets
    
    IF current_agent == "DEVOPS":
      targets = []
      # re-deploy to dev invalidates the smoke blocks captured against the previous build
      IF FILE_EXISTS("{{base_path}}/smoke_e2e_report.md") AND "redeploy_dev" IN affected_scopes:
        targets.push("smoke_e2e_report")
      RETURN targets

  # Push pending_iteration to each downstream artifact
  FOR EACH artifact_name IN downstream_artifacts:
    
    IF artifact_name == "qa_report":
      # QA reports: mark as INVALIDATED instead of pending_iteration
      latest_report = LATEST("{{base_path}}/qa/qa_report_final_*.md")
      IF latest_report AND READ_FRONTMATTER(latest_report, "status") == "APPROVED":
        UPDATE_FRONTMATTER(latest_report, {
          status: "INVALIDATED",
          invalidated_by_iteration: target_iteration,
          invalidated_reason: "Upstream artifacts changed: {{affected_scopes}}"
        })
      CONTINUE

    IF artifact_name == "contracts_freeze":
      # frozen contracts cannot be patched — the entire frozen set is marked
      # INVALIDATED and the CONTRACT-FREEZE gate issue must re-run to produce a new freeze.
      # Also flag the backlog issue itself so --next-task sees the gate as re-open.
      FOR EACH contract_file IN LIST_FILES("{{base_path}}/contracts/"):
        fm = READ_FRONTMATTER(contract_file)
        IF fm.status == "APPROVED":
          UPDATE_FRONTMATTER(contract_file, {
            status: "INVALIDATED",
            invalidated_by_iteration: target_iteration,
            invalidated_reason: "Upstream changed: {{affected_scopes}}"
          })
      # Reopen the CONTRACT-FREEZE gate issue on the backlog via tool-adapter
      ADAPTER = READ "docs/backlog/tool-adapter.md"
      gate_issue = ADAPTER.query_board() → find WHERE labels CONTAINS "phase:contract-freeze" AND title CONTAINS FEATURE_ID
      IF gate_issue AND gate_issue.status == "Done":
        ADAPTER.move_to_column(gate_issue, column="Todo")
        ADAPTER.add_label(gate_issue, "stale-after-cascade")
      CONTINUE

    IF artifact_name IN ["preventive_sweep_report", "smoke_e2e_report"]:
      # runtime reports are point-in-time artefacts; any upstream change makes them
      # untrustworthy. Mark INVALIDATED and reopen the corresponding gate issue on the board.
      report_path = "{{base_path}}/{{artifact_name}}.md"
      IF FILE_EXISTS(report_path):
        fm = READ_FRONTMATTER(report_path)
        IF fm.status == "APPROVED":
          UPDATE_FRONTMATTER(report_path, {
            status: "INVALIDATED",
            invalidated_by_iteration: target_iteration,
            invalidated_reason: "Upstream changed: {{affected_scopes}}"
          })
      gate_label = "phase:preventive-sweep" IF artifact_name == "preventive_sweep_report" ELSE "phase:smoke-e2e"
      ADAPTER = READ "docs/backlog/tool-adapter.md"
      gate_issue = ADAPTER.query_board() → find WHERE labels CONTAINS gate_label AND title CONTAINS FEATURE_ID
      IF gate_issue AND gate_issue.status == "Done":
        ADAPTER.move_to_column(gate_issue, column="Todo")
        ADAPTER.add_label(gate_issue, "stale-after-cascade")
      CONTINUE

    artifact_path = "{{base_path}}/{{artifact_name}}"
    current_frontmatter = READ_FRONTMATTER(artifact_path)
    
    # Skip if already in-progress
    IF current_frontmatter.status IN ["DRAFT", "NEEDS_INFO"]:
      CONTINUE
    
    # Guard: don't overwrite higher pending_iteration
    IF current_frontmatter.pending_iteration IS NOT NULL AND current_frontmatter.pending_iteration >= target_iteration:
      CONTINUE
    
    UPDATE_FRONTMATTER(artifact_path, {
      pending_iteration: target_iteration,
      pending_schemas_version: target_schemas_version,
      invalidated_sections: COMPUTE_AFFECTED_SECTIONS(artifact_name, affected_scopes),
      cascade_source: "{{current_agent}}",
      cascade_timestamp: "{{ISO_8601_TIMESTAMP}}",
      cascade_scope: affected_scopes
    })

  RETURN downstream_artifacts


FUNCTION COMPUTE_AFFECTED_SECTIONS(artifact_name, affected_scopes):
  IF artifact_name == "design.md":
    sections = []
    IF "new_scenario" IN affected_scopes OR "schema_change" IN affected_scopes:
      sections.push("contracts", "data_model", "api_endpoints")
    IF "ui_restyling" IN affected_scopes:
      sections.push("component_architecture", "frontend_contracts")
    IF "infra_change" IN affected_scopes:
      sections.push("infrastructure_needs")
    IF "policy_change" IN affected_scopes:
      sections.push("business_rules", "error_handling")
    RETURN sections
  
  IF artifact_name == "test_plan.md":
    sections = []
    IF "new_scenario" IN affected_scopes: sections.push("acceptance_tests", "integration_tests")
    IF "schema_change" IN affected_scopes: sections.push("contract_tests", "data_validation_tests")
    IF "ui_restyling" IN affected_scopes: sections.push("visual_regression_tests", "accessibility_tests", "component_tests")
    IF "policy_change" IN affected_scopes: sections.push("business_rule_tests", "edge_case_tests")
    RETURN sections
  
  IF artifact_name == "dev_plan.md":
    sections = []
    IF "new_scenario" IN affected_scopes: sections.push("new_tasks_required")
    IF "schema_change" IN affected_scopes: sections.push("data_layer_tasks", "contract_tasks")
    IF "ui_restyling" IN affected_scopes: sections.push("frontend_tasks", "component_tasks", "style_tasks")
    IF "contract_change" IN affected_scopes: sections.push("api_tasks", "integration_tasks")
    IF "infra_change" IN affected_scopes: sections.push("infra_tasks", "config_tasks")
    IF "policy_change" IN affected_scopes: sections.push("business_logic_tasks", "validation_tasks")
    RETURN sections
  
  IF artifact_name == "devops_plan.md":
    sections = []
    IF "infra_change" IN affected_scopes: sections.push("resource_definitions", "sizing", "networking")
    IF "new_scenario" IN affected_scopes AND "infra_change" IN affected_scopes:
      sections.push("scaling_config")
    RETURN sections

  # frozen / point-in-time artefacts have no section-level granularity.
  # They are fully regenerated when any upstream scope invalidates them.
  IF artifact_name IN ["contracts_freeze", "preventive_sweep_report", "smoke_e2e_report"]:
    RETURN ["entire_artifact"]

  RETURN []
```

### Cascade Trigger Points

```yaml
CASCADE_TRIGGERS:

  # 1. CODESIGN --refine (Iteration Mode on APPROVED spec)
  ON_CODESIGN_REFINE_ITERATION:
    new_iteration = spec.feature.iteration
    new_schemas_version = user_journey.schemas_version
    affected_scopes = CLASSIFY_CHANGE_SCOPES(codesign_changes)
    affected_scenarios = EXTRACT_AFFECTED_SCENARIOS(codesign_changes)   # list of Scenario names touched
    affected_contract_ops = []                                          # CODESIGN doesn't alter contracts — contracts change only via BLUEPRINT
    CASCADE_PENDING_ITERATION(FEATURE_ID, new_iteration, new_schemas_version, affected_scopes)
    CASCADE_SLICE_PEERS(FEATURE_ID, new_iteration, affected_scopes)
    CASCADE_INCREMENT_INTERNAL(FEATURE_ID, new_iteration, affected_scopes, affected_scenarios, affected_contract_ops)

  # 2. BLUEPRINT --refine (Syncing design.md + test_plan.md)
  ON_BLUEPRINT_SYNC_COMPLETE:
    affected_scopes = CLASSIFY_BLUEPRINT_CHANGES(blueprint_changes)
    affected_scenarios = EXTRACT_AFFECTED_SCENARIOS_FROM_TEST_PLAN(blueprint_changes)
    affected_contract_ops = EXTRACT_AFFECTED_CONTRACT_OPS(blueprint_changes)   # operations added / removed / signature-changed
    CASCADE_PENDING_ITERATION(FEATURE_ID, spec.iteration, schemas_version, affected_scopes)
    CASCADE_SLICE_PEERS(FEATURE_ID, spec.iteration, affected_scopes)
    CASCADE_INCREMENT_INTERNAL(FEATURE_ID, spec.iteration, affected_scopes, affected_scenarios, affected_contract_ops)

  # 3. IMPLEMENT --refine (Syncing dev_plan.md via Delta Iteration)
  ON_IMPLEMENT_SYNC_COMPLETE:
    affected_scopes = ["implementation_changed"]
    CASCADE_PENDING_ITERATION(FEATURE_ID, spec.iteration, schemas_version, affected_scopes)
    CASCADE_SLICE_PEERS(FEATURE_ID, spec.iteration, affected_scopes)
    # Implementation-only changes do NOT invalidate increment scope — the plan's § 1 (scenarios /
    # contracts / depends_on) is untouched. Skip CASCADE_INCREMENT_INTERNAL here; per-increment
    # dev_plan.md tasks re-sync through the normal DELTA/FULL path.

  # 4. IMPLEMENT --build / --fix complete
  #    Code changed — runtime-dependent reports are now stale regardless of spec/design drift.
  ON_IMPLEMENT_BUILD_COMPLETE:
    affected_scopes = ["code_changed"]
    CASCADE_PENDING_ITERATION(FEATURE_ID, spec.iteration, schemas_version, affected_scopes)
    CASCADE_SLICE_PEERS(FEATURE_ID, spec.iteration, affected_scopes)

  # 5. DEVOPS --deploy --env dev complete
  #    A new dev build replaces the one the smoke blocks were captured against.
  ON_DEVOPS_REDEPLOY_DEV:
    affected_scopes = ["redeploy_dev"]
    CASCADE_PENDING_ITERATION(FEATURE_ID, spec.iteration, schemas_version, affected_scopes)
    # Slice integration tests are smoke-dependent when multiple slice peers share a dev env
    CASCADE_SLICE_PEERS(FEATURE_ID, spec.iteration, affected_scopes)

  # 6. BLUEPRINT --approve on an UPDATED contract
  #    When an upstream feature re-freezes its contract (contract signature / schema / semantics
  #    changed), every downstream feature that declares the upstream in spec.feature.consumes_contract
  #    is now binding to a superseded contract. Cascade across the dependency graph.
  ON_BLUEPRINT_CONTRACT_CHANGE:
    # Trigger firing conditions:
    #   (a) BLUEPRINT --approve emits a CONTRACT_CHANGED signal when the upstream's contracts/**
    #       content hash differs from the previous CONTRACT-FREEZE snapshot, OR
    #   (b) operator re-opens an upstream's CONTRACT-FREEZE issue with the stale-after-cascade
    #       label (manual contract-change attestation).
    # upstream_feature_id is the feature whose contract just changed.
    CASCADE_CONSUMERS(upstream_feature_id, spec.iteration, schemas_version, ["contract_change"])


# Cross-feature cascade via consumes_contract
FUNCTION CASCADE_CONSUMERS(upstream_feature_id, target_iteration, schemas_version, affected_scopes):
  # Cross-feature cascade: when feature A's contract changes, every downstream feature B whose
  # spec.feature.consumes_contract list contains A must be marked CASCADE_PENDING_ITERATION.
  # This is NOT a slice-peer cascade (CASCADE_SLICE_PEERS) — it is a contract-consumer cascade
  # that spans slices, epics, and time. A consumer declared three months ago still gets the
  # cascade today if the frontmatter still references the upstream.

  # 1. Find all downstream consumers — scan every spec.feature in docs/spec/
  downstream_consumers = []
  FOR EACH spec_path IN GLOB("docs/spec/*/spec.feature"):
    downstream_id = EXTRACT_FEATURE_ID(spec_path)
    IF downstream_id == upstream_feature_id: CONTINUE   # don't cascade to self
    consumes = READ_FRONTMATTER(spec_path).consumes_contract OR []
    IF upstream_feature_id IN consumes:
      downstream_consumers.push(downstream_id)

  IF downstream_consumers IS EMPTY:
    LOG: "CASCADE_CONSUMERS: no downstream features declare {upstream_feature_id} in consumes_contract — no cascade"
    RETURN

  LOG: "CASCADE_CONSUMERS: upstream={upstream_feature_id} has {len(downstream_consumers)} downstream consumers: {downstream_consumers}"

  # 2. For each downstream consumer, push the cascade through its own downstream artefacts +
  #    re-open its CONTRACT-FREEZE gate (downstream's contract may need to re-freeze against
  #    the new upstream shape). Affected scope "contract_change" signals that BLUEPRINT --refine
  #    MUST re-sync design.md, test_plan.md, and the contract test harness — dev_plan.md task
  #    hashes will likely need touching too because integration points changed.
  FOR EACH consumer_id IN downstream_consumers:
    # Reuse the existing per-feature cascade machinery — pending_iteration on the consumer's
    # design.md / test_plan.md / dev_plan.md / smoke_e2e_report / qa_report triggers DELTA or
    # FULL sync at the next command touch on that feature.
    CASCADE_PENDING_ITERATION(consumer_id, target_iteration, schemas_version, affected_scopes)

    # 3. Re-open the consumer's CONTRACT-FREEZE gate so the Consumes-Contract Upstream Freeze
    #    Gate (Factory-implement-plan.instructions.md § Consumes-Contract Upstream Freeze Gate) blocks IMPLEMENT --plan
    #    on the consumer until the consumer's own contract re-freezes against the new upstream.
    ADAPTER = READ "docs/backlog/tool-adapter.md"
    consumer_cf_issue = ADAPTER.query_board() → find WHERE labels CONTAINS "phase:contract-freeze" AND title CONTAINS consumer_id
    IF consumer_cf_issue AND consumer_cf_issue.status == "Done":
      ADAPTER.move_to_column(consumer_cf_issue, column="Todo")
      ADAPTER.add_label(consumer_cf_issue, "stale-after-cascade")
      LOG: "CASCADE_CONSUMERS: re-opened CONTRACT-FREEZE for consumer {consumer_id} (stale-after-cascade applied)"

    # 4. If the upstream was a slice peer, the slice integration test is also stale — but that is
    #    already handled by CASCADE_SLICE_PEERS called from the original cascade trigger. Do not
    #    double-trigger here.

  LOG: "CASCADE_CONSUMERS complete: {len(downstream_consumers)} downstream features cascaded due to {upstream_feature_id} contract change"


FUNCTION CASCADE_INCREMENT_INTERNAL(FEATURE_ID, target_iteration, affected_scopes, affected_scenarios, affected_contract_ops):
  # Per-increment cascade. When a feature whose spec or design changes has slicing_strategy=incremental,
  # the cascade is SELECTIVE: only increments that carry the touched scenarios or contract operations are
  # invalidated, not the whole plan. This is the mechanism that makes incremental slicing compatible with
  # the Iteration Model — a 3-increment plan where INC-1 is MERGED and INC-2 is BUILDING must not be
  # wholesale invalidated when the user refines INC-3's scenarios.
  #
  # Lives alongside CASCADE_PENDING_ITERATION (which keeps touching dev_plan.md / test_plan.md / devops_plan.md
  # globally for implementation-level re-sync) and CASCADE_SLICE_PEERS (which is cross-feature within a slice
  # — unrelated to the per-increment concept).

  plan_path = "docs/spec/{FEATURE_ID}/increment_plan.md"
  IF NOT FILE_EXISTS(plan_path): RETURN   # pre-slicing feature — nothing per-increment to touch

  plan_fm = READ_FRONTMATTER(plan_path)
  IF plan_fm.slicing_strategy != "incremental":
    RETURN   # monolithic plans cascade through the plan-level pending_iteration path only

  increments = PARSE_INCREMENTS(plan_path)   # § 1 entries with id, status, scenarios_covered, contract_surface
  invalidated = []
  warnings = []

  FOR EACH inc IN increments:
    # Does the change touch this increment?
    scenario_overlap  = NOT_EMPTY(inc.scenarios_covered ∩ affected_scenarios)
    contract_overlap  = NOT_EMPTY(inc.contract_surface  ∩ affected_contract_ops)
    implicit_touch    = (affected_scenarios IS EMPTY AND affected_contract_ops IS EMPTY)
                        # When CLASSIFY_CHANGE_SCOPES signals change but no specific element can be
                        # attributed (e.g. broad "policy_change"), fall back to touching every
                        # non-MERGED increment conservatively.

    IF NOT (scenario_overlap OR contract_overlap OR implicit_touch):
      CONTINUE   # increment survives this cascade

    # Transition policy per status (see immutability_policy.md § Per-Increment Immutability)
    IF inc.status == "MERGED":
      # MERGED increments are NEVER invalidated — their scope is production history, not rework target.
      # Surface the collision so the operator can propose a follow-up increment (Follow-up Increment Rule).
      warnings.push({
        id: inc.id,
        reason: "MERGED increment overlaps changed scenarios/contracts — add a follow-up increment instead of invalidating",
        touched_scenarios: inc.scenarios_covered ∩ affected_scenarios,
        touched_contract_ops: inc.contract_surface ∩ affected_contract_ops
      })
      CONTINUE

    IF inc.status == "BUILDING":
      # A branch is open with tasks in progress. We cannot silently invalidate without losing work.
      # Mark the increment as needing resync but DO NOT flip status yet — the operator must --pause
      # the branch first (enforced by immutability_policy).
      UPDATE_INCREMENT_FIELD(plan_path, inc.id, "pending_iteration", target_iteration)
      UPDATE_INCREMENT_FIELD(plan_path, inc.id, "pending_reason", "Affected by upstream change — pause branch and run IMPLEMENT --refine {FEATURE_ID} {inc.id}")
      warnings.push({
        id: inc.id,
        reason: "BUILDING increment carries uncommitted work — pause + --refine required",
        pending_iteration: target_iteration
      })
      CONTINUE

    # DRAFT, READY, INVALIDATED → flip to INVALIDATED and record the cascade
    UPDATE_INCREMENT_FIELD(plan_path, inc.id, "status", "INVALIDATED")
    UPDATE_INCREMENT_FIELD(plan_path, inc.id, "invalidated_by_iteration", target_iteration)
    UPDATE_INCREMENT_FIELD(plan_path, inc.id, "invalidated_reason", "Scenarios/contracts changed: {affected_scopes}")
    invalidated.push(inc.id)

  # Roll up into plan frontmatter
  UPDATE_FRONTMATTER(plan_path, {
    pending_iteration: target_iteration,
    invalidated_increments: UNION(plan_fm.invalidated_increments, invalidated),
    cascade_source: "CASCADE_INCREMENT_INTERNAL",
    cascade_timestamp: NOW_ISO(),
    cascade_scope: affected_scopes
  })

  # Mirror into dev_plan.md — the IMPLEMENT consumer needs to see the invalidation
  dev_plan_path = "docs/spec/{FEATURE_ID}/dev_plan.md"
  IF FILE_EXISTS(dev_plan_path):
    UPDATE_FRONTMATTER(dev_plan_path, {
      invalidated_increments: UNION(READ_FRONTMATTER(dev_plan_path).invalidated_increments, invalidated)
    })

  # Plan-level status: only flip to INVALIDATED if EVERY non-MERGED increment is invalidated
  non_merged = FILTER(increments, status != "MERGED")
  IF non_merged IS NOT EMPTY AND ALL(non_merged, inc.id IN (plan_fm.invalidated_increments ∪ invalidated)):
    UPDATE_FRONTMATTER(plan_path, { status: "INVALIDATED" })
    LOG: "CASCADE_INCREMENT_INTERNAL: plan-level status flipped to INVALIDATED — all non-MERGED increments invalidated"

  # Emit operator-facing summary
  IF invalidated IS NOT EMPTY:
    LOG: "CASCADE_INCREMENT_INTERNAL: invalidated {invalidated.length} increment(s): {invalidated}"
  FOR EACH w IN warnings:
    LOG: "CASCADE_INCREMENT_INTERNAL: WARN {w.id} — {w.reason}"

  RETURN { invalidated: invalidated, warnings: warnings }


# Horizontal cascade within a slice
FUNCTION CASCADE_SLICE_PEERS(FEATURE_ID, target_iteration, affected_scopes):
  # Slice-level cascade: when a feature that belongs to a slice iterates, the slice's
  # cross-feature integration test is stale because the feature's contract/behaviour may have
  # shifted. This is NOT a "downstream-within-the-same-feature" cascade — it is a horizontal
  # cascade across slice peers that share an integration suite.

  # 1. Resolve the slice that contains this feature (label-driven, tool-agnostic)
  ADAPTER = READ "docs/backlog/tool-adapter.md"
  feature_issue = ADAPTER.query_board() → find WHERE title CONTAINS FEATURE_ID AND labels CONTAINS "phase:implement"
  IF feature_issue IS NULL: RETURN   # feature not yet in backlog — nothing to cascade
  slice_label = FIRST(feature_issue.labels) MATCHING /^slice:EPIC-\d+\.\d+$/
  IF slice_label IS NULL: RETURN    # feature not in a slice — nothing to cascade

  # 2. Locate the slice integration-test artefact and its gate issue
  slice_ref = slice_label.replace("slice:EPIC-", "SLICE-")  # e.g. SLICE-1.2
  integration_spec = "docs/spec/{{slice_ref}}/integration_test.md"

  IF FILE_EXISTS(integration_spec):
    fm = READ_FRONTMATTER(integration_spec)
    IF fm.status == "APPROVED":
      UPDATE_FRONTMATTER(integration_spec, {
        status: "INVALIDATED",
        invalidated_by_iteration: target_iteration,
        invalidated_reason: "Slice peer {{FEATURE_ID}} iterated: {{affected_scopes}}"
      })

  # 3. Reopen the slice integration-test gate issue on the board
  gate_issue = ADAPTER.query_board() → find WHERE labels CONTAINS "phase:integration-test" AND title CONTAINS slice_ref
  IF gate_issue AND gate_issue.status == "Done":
    ADAPTER.move_to_column(gate_issue, column="Todo")
    ADAPTER.add_label(gate_issue, "stale-after-slice-peer-iterated")


FUNCTION CLASSIFY_CHANGE_SCOPES(changes):
  scopes = []
  IF changes affect Gherkin scenarios: scopes.push("new_scenario")
  IF changes affect user_journey.md Data Schemas: scopes.push("schema_change")
  IF changes affect mock.html visual structure: scopes.push("ui_restyling")
  IF changes affect business rules/policies: scopes.push("policy_change")
  IF changes imply new infrastructure needs: scopes.push("infra_change")
  IF changes affect API contracts or data flow: scopes.push("contract_change")
  # Even purely visual changes must cascade (affect frontend tasks, visual regression, etc.)
  IF scopes.length == 0: scopes.push("minor_update")
  RETURN scopes
```

---

## Scenario-Level Supersession (Granular Immutability)

When a HYBRID SPLIT or FORCE_DELTA modifies existing scenarios, supersession applies **per-scenario**, not per-feature:

```gherkin
# In spec.feature of AUTH-001 (after AUTH-002 takes over modified scenarios)

@superseded_by(AUTH-002, scenario="User validates credentials with OAuth")
@superseded_at(2026-02-06)
Scenario: User validates credentials
  Given ...
  When ...
  Then ...

# This scenario remains ACTIVE in AUTH-001
Scenario: User logs out
  Given ...
```

**Rules:**
- Superseded scenarios are READ-ONLY (no agent can modify them)
- Active scenarios continue evolving through iterations
- Downstream agents SKIP superseded scenarios during DELTA sync

---

## Iteration Frontmatter Extension

```yaml
# spec.feature frontmatter (UPSTREAM — source of truth)
iteration: 3
iteration_history:
  - iteration: 1
    date: 2026-02-01
    scope: "Initial: Login, Logout, Session"
  - iteration: 2 
    date: 2026-02-04
    scope: "Added OAuth login scenario"
  - iteration: 3
    date: 2026-02-06  
    scope: "Added MFA scenario, extended Session with refresh token"
last_iteration_scope: "Added MFA scenario, extended Session with refresh token"

# user_journey.md frontmatter (UPSTREAM — data contract source of truth)
schemas_version: 2

# Downstream artifacts (design.md, test_plan.md, dev_plan.md, devops_plan.md)
# Sync tracking fields (MANDATORY)
based_on_iteration: 2
based_on_schemas_version: 1
# Push-based cascade fields
pending_iteration: 3                  # NULL when synced
pending_schemas_version: 2            # NULL when synced
invalidated_sections: ["TC-003"]
cascade_source: "CODESIGN"
cascade_timestamp: "2026-02-06T10:30:00Z"
cascade_scope:
  - "ui_restyling"
  - "schema_change"

# Lifecycle rules:
# pending_iteration WRITTEN BY: CODESIGNBLUEPRINTIMPLEMENT --refine (cascade)
# pending_iteration READ BY: Downstream Detection, Smart Redirect, agent guardrails
# pending_iteration CLEARED BY: downstream agent after DELTA or FULL sync

# QA report special handling:
status: "INVALIDATED"
invalidated_by_iteration: 3
invalidated_reason: "Upstream artifacts changed: [ui_restyling, schema_change]"
```

---

## Canonical Iteration ID — `ITER-{FEAT}-{N}`

Capability flag `governance_features.iterations_array_v1` in the governance manifest gates presence of `iterations[]` per project.

### Entry shape

```yaml
- id: ITER-AUTH-001-3                 # ^ITER-[A-Z0-9]+(-[A-Z0-9]+)*-\d+$
  iteration: 3                        # N suffix of id
  date: 2026-05-16T10:30:00Z
  source: user-feedback               # user-feedback | cascade | impl-gap-probe | rdr-ratification | mcp-docs-finding
  classification: DELTA               # DELTA | BREAKING | HYBRID (CODESIGN only)
  scope_summary: "one-line summary"
  changes: [{kind: scenario_added, ref: "User enables MFA"}]
  downstream_impact: [design.md, test_plan.md]
  anchor: "#iter-3"                   # body MUST carry matching `## Iteration {id} {#iter-N}`
  rdr_rounds: 2                       # 0 when not applicable
  converged: true
  impl_state_snapshot: {tasks_done: 14, commits_since_last_iter: 7}
  cascade_source: ITER-AUTH-001-3     # join key: downstream entry's cascade_source == upstream entry's id
  mcp_consulted: [context7, aws-knowledge]
```

**Rules**
- `FEAT` portion = `spec.feature.feature_id` verbatim.
- `N` monotonic per feature. Next N = `max(iterations[].iteration) + 1` on `spec.feature`.
- Cross-artefact join = same `id` on upstream entry and downstream `cascade_source`.

### Cascade contract

Scalar `pending_iteration` (CASCADE signal) = `iterations[-1].iteration` of upstream artefact. `cascade_source` accepts both ITER ID and legacy agent-name string.

### Dual-format read

Every gate reading `iteration` / `iteration_history` / `pending_iteration` routes through:

```yaml
FUNCTION read_iteration_state(artifact_path):
  fm = READ_FRONTMATTER(artifact_path)
  IF fm.iterations NOT EMPTY:
    latest = fm.iterations[-1]
    RETURN { n: latest.iteration, id: latest.id, history: fm.iterations, source: "array" }
  ELSE:
    RETURN { n: fm.iteration OR 1,
             id: "ITER-{spec.feature_id}-{fm.iteration OR 1}",   # synthesized, not persisted
             history: fm.iteration_history OR [],
             source: "scalar-legacy" }
```

Direct `fm.iteration` access in any gate is a violation.
