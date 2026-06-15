---
name: factory-coherence-validation
description: "Factory Coherence Validation Protocol (CVP) — cross-artifact traceability and completeness verification. Ensures upstream deliverables are coherent, complete, and mutually consistent before downstream agents consume them. Use when: BLUEPRINT --approve, IMPLEMENT --plan, or QA --verify need to validate upstream artifact alignment."
applicable_when:
  phase: [BLUEPRINT, IMPLEMENT, QA]
---

# COHERENCE VALIDATION PROTOCOL (CVP) — CROSS-ARTIFACT TRACEABILITY

> **Shared Protocol** — Referenced by: BLUEPRINT, IMPLEMENT, QA agents.
> Before an agent consumes upstream deliverables, it MUST validate that those deliverables are mutually coherent, complete, and traceable. Each agent invokes CVP with a different SCOPE that determines which artifact pairs are checked.
> CVP is the semantic counterpart to CIP (which enforces DRY). CVP enforces COHERENCE across the artifact chain.

**Applies to:** `BLUEPRINT` (validates CODESIGN↔BLUEPRINT alignment), `IMPLEMENT` (validates full CODESIGN↔BLUEPRINT↔IMPLEMENT chain), `QA` (validates end-to-end traceability)

---

## WHY THIS PROTOCOL EXISTS

Each agent in the SDLC pipeline produces artifacts that downstream agents consume as inputs. Existing gates validate **status** (is it APPROVED?) and **iteration** (is it stale?), but do NOT validate **semantic coherence** — whether the artifacts actually align in content. Examples of gaps CVP catches:

- A Gherkin scenario in `spec.feature` with no corresponding component in `design.md`
- A data field in `user_journey.md` Data Schemas absent from `design.md` data model
- A UI component in `mock.html` with no entry in `design.md` Component Inventory
- A user journey step requiring an API call with no matching contract endpoint
- A contract endpoint with no corresponding test case in `test_plan.md`
- A test case in `test_plan.md` with no implementation task in `dev_plan.md`

---

## CVP SCOPE LEVELS

Each invoking agent declares a scope that controls which checks execute:

```yaml
CVP_SCOPES:
  CODESIGN_BLUEPRINT:
    # Invoked by: BLUEPRINT --approve (Phase 3.8)
    # Validates: CODESIGN artifacts ↔ BLUEPRINT artifacts
    checks:
      - scope_consistency_across_artifacts   # scope field matches across spec.feature/design.md/test_plan.md/dev_plan.md
      - consumes_contract_resolution         # every FEAT-XXX in spec.feature.consumes_contract resolves to an APPROVED upstream with frozen contract files
      - slice_map_presence                   # EVOL-036 — slice_map.md exists + well-formed (RDR≥3) when slicing_strategy==incremental; absent when monolithic
      - increment_plan_presence              # increment_plan.md exists with well-formed frontmatter; slicing_strategy inherited from spec.feature
      - scenario_to_component        # spec.feature scenarios → design.md components
      - data_schema_to_data_model    # user_journey.md schemas → design.md data model
      - ui_component_to_inventory    # mock.html components → design.md Component Inventory (applicable_when scope in [full-stack, frontend-only])
      - journey_step_to_endpoint     # user_journey.md (OR user_journey.integration.md when scope in [backend-only, integration]) steps → contract endpoints
      - scenario_to_test_coverage    # spec.feature scenarios → test_plan.md test cases
      - contract_to_test_coverage    # contract endpoints → test_plan.md integration tests
      - increment_deployability              # each increment declares deployable:production + acceptance checklist + DAG acyclic
      - increment_to_scenario_coverage       # every spec.feature scenario appears in exactly one increment (no orphan, no duplicate)
      - increment_to_contract_coverage       # every contract operation appears in exactly one increment (no orphan, no duplicate)
      - monolithic_heuristic                 # applicable_when slicing_strategy==monolithic — § 3 Escape Declaration present + heuristic satisfied
      - slice_to_increment_coverage          # EVOL-036 — every slice realized by ≥1 increment (cascade_source), bidirectional + scenario consistency
      - slice_seam_resolution                # EVOL-036 — each depends_on_slice/depends_on_feature resolves + DAG + seam present (4 fail-modes)
      - slice_immutability_consistency       # EVOL-036 — per-scenario freeze partition well-formed; no MERGED increment orphaned; vacuous pre-BLUEPRINT

  CODESIGN_BLUEPRINT_IMPLEMENT:
    # Invoked by: IMPLEMENT --plan (Step 0.5)
    # Validates: all of CODESIGN_BLUEPRINT PLUS implementation coverage
    includes: CODESIGN_BLUEPRINT
    checks:
      - contract_to_task             # contract endpoints → dev_plan.md tasks
      - test_case_to_task            # test_plan.md test cases → dev_plan.md test tasks
      - ui_component_to_task         # design.md UI components → dev_plan.md frontend tasks (applicable_when scope in [full-stack, frontend-only])
      - data_model_to_task           # design.md entities → dev_plan.md Phase A tasks
      - reliability_test_to_task     # test_plan.md § 2.2 Reliability Testing rows → dev_plan.md § Reliability Tests tasks (applicable_when scope in [backend-only, integration])
      - increment_to_task            # each increment has ≥1 [INC-N.*.M] task in dev_plan.md (applicable_when slicing_strategy==incremental)

  FULL_CHAIN:
    # Invoked by: QA --verify (Pre-Verification Gate)
    # Validates: end-to-end traceability CODESIGN → BLUEPRINT → IMPLEMENT → QA
    includes: CODESIGN_BLUEPRINT_IMPLEMENT
    checks:
      - scenario_to_qa_check         # spec.feature scenarios → qa_report checklist items
      - task_completion_to_qa        # dev_plan.md completed tasks → qa verification scope
```

---

## CVP MASTER GATE

```yaml
# Helper: resolve full check list for a scope (recursively expand includes + own checks)
FUNCTION resolve_scope_checks(scope, visited = SET()):
  IF scope IN visited:
    RETURN []
  visited.add(scope)

  resolved = []
  IF "includes" IN CVP_SCOPES[scope]:
    FOR EACH included_scope IN CVP_SCOPES[scope].includes:
      FOR EACH check IN resolve_scope_checks(included_scope, visited):
        IF check NOT IN resolved:
          resolved.push(check)

  FOR EACH check IN CVP_SCOPES[scope].checks:
    IF check NOT IN resolved:
      resolved.push(check)

  RETURN resolved

FUNCTION cvp_coherence_gate(FEATURE_ID, scope, invoking_agent):
  # This gate MUST execute at the designated integration point for each agent.
  # It reads upstream artifacts and builds a traceability matrix.
  # BLOCKING on CRITICAL gaps. WARNING on non-critical gaps.

  base_path = "docs/spec/{FEATURE_ID}"

  # Step 0: Load artifacts based on scope
  artifacts = {}
  artifacts.spec_feature = READ("{base_path}/spec.feature")
  artifacts.user_journey = READ("{base_path}/user_journey.md")
  artifacts.mock_html = READ("{base_path}/mock.html")
  artifacts.design_md = READ("{base_path}/design.md")
  artifacts.test_plan = READ("{base_path}/test_plan.md")
  artifacts.increment_plan = READ_IF_EXISTS("{base_path}/increment_plan.md")  # may be absent on pre-slicing features
  artifacts.slice_map = READ_IF_EXISTS("{base_path}/slice_map.md")            # EVOL-036 — present only when slicing_strategy==incremental

  IF scope IN [CODESIGN_BLUEPRINT_IMPLEMENT, FULL_CHAIN]:
    artifacts.dev_plan = READ("{base_path}/dev_plan.md")

  IF scope == FULL_CHAIN:
    artifacts.qa_report = LATEST("{base_path}/qa/qa_report_final_*.md") OR NULL

  # Step 1: Extract traceable elements
  elements = extract_traceable_elements(artifacts, scope)

  # Step 2: Resolve full check list (expand includes recursively)
  all_checks = resolve_scope_checks(scope)

  # Step 3: Execute checks
  results = []
  FOR EACH check IN all_checks:
    result = execute_check(check, elements, artifacts)
    results.push(result)

  # Step 3: Classify results
  critical_gaps = FILTER(results, severity == CRITICAL)
  warnings = FILTER(results, severity == WARNING)
  passed = FILTER(results, severity == PASS)

  # Step 4: Build coherence matrix
  matrix = build_coherence_matrix(results, elements, scope)

  # Step 5: Gate decision
  IF critical_gaps.length > 0:
    ❌ BLOCK: "CVP Coherence Gate FAILED — {critical_gaps.length} critical gap(s) detected"
    SHOW: format_gap_report(critical_gaps, warnings)
    SUGGEST: remediation_actions(critical_gaps, invoking_agent)
    STOP

  IF warnings.length > 0:
    ⚠️ WARN: "CVP passed with {warnings.length} warning(s)"
    SHOW: format_gap_report([], warnings)
    LOG: "CVP_PASSED_WITH_WARNINGS — {warnings.length} non-critical gaps"

  IF critical_gaps.length == 0:
    ✅ PASS: "CVP Coherence Gate PASSED — {passed.length}/{results.length} checks verified"
    LOG: "CVP_PASSED — scope: {scope}, agent: {invoking_agent}"

  RETURN { passed: critical_gaps.length == 0, matrix: matrix, results: results }
```

---

## CHECK DEFINITIONS

### Check 0a: `scope_consistency_across_artifacts` (CRITICAL)

The `scope` frontmatter field must match across every downstream artefact of the feature. Drift (e.g. spec.feature says `backend-only` but design.md says `full-stack`) is silent corruption — a downstream agent may run scope-aware logic against the wrong scope.

```yaml
FUNCTION check_scope_consistency_across_artifacts(elements):
  # Read scope from every available artefact. Legacy artefacts without the field
  # degrade gracefully: missing scope is treated as "unknown" and surfaces as a WARNING-severity
  # recommendation to add the field, not a CRITICAL blocker.
  scopes = {}
  IF elements.spec_feature IS PRESENT:
    scopes.spec = elements.spec_feature.frontmatter.scope OR "unknown"
  IF elements.design IS PRESENT:
    scopes.design = elements.design.frontmatter.scope OR "unknown"
  IF elements.test_plan IS PRESENT:
    scopes.test_plan = elements.test_plan.frontmatter.scope OR "unknown"
  IF elements.dev_plan IS PRESENT:
    scopes.dev_plan = elements.dev_plan.frontmatter.scope OR "unknown"
  IF elements.increment_plan IS PRESENT:
    scopes.increment_plan = elements.increment_plan.frontmatter.scope OR "unknown"

  # The authoritative scope is spec.feature.scope. All others must match it.
  authoritative = scopes.spec OR "unknown"

  FOR EACH (artefact, value) IN scopes:
    IF artefact == "spec": CONTINUE
    IF value == "unknown":
      YIELD { check: "scope_consistency_across_artifacts", severity: WARNING,
              source: "{artefact}.frontmatter.scope",
              gap: "Missing scope field (legacy artefact)",
              remediation: "Re-run the generating agent to refresh frontmatter with scope field; or add scope manually inheriting from spec.feature.scope ({authoritative})" }
      CONTINUE
    IF value != authoritative:
      YIELD { check: "scope_consistency_across_artifacts", severity: CRITICAL,
              source: "{artefact}.frontmatter.scope = '{value}'",
              gap: "Scope mismatch: spec.feature says '{authoritative}', {artefact} says '{value}'",
              remediation: "Re-sync via the responsible agent's --refine (BLUEPRINT --refine {ID} for design.md/test_plan.md; IMPLEMENT --refine {ID} for dev_plan.md). Scope is IMMUTABLE after CODESIGN auto-approval — mismatch indicates a hand-edit or a stale artefact needing cascade sync." }
    ELSE:
      YIELD { check: "scope_consistency_across_artifacts", severity: PASS,
              source: artefact, target: "scope={value} matches spec.feature" }
```

### Check 0b: `consumes_contract_resolution` (CRITICAL)

Every `FEAT-XXX` declared in `spec.feature.consumes_contract` must resolve to an upstream feature whose design.md is at least APPROVED and whose contract artefacts exist under `contracts/**` (OpenAPI / AsyncAPI / GraphQL SDL / Protobuf). Missing upstreams or not-yet-frozen contracts are silent failures that only surface at IMPLEMENT time via the Consumes-Contract Upstream Freeze Gate — CVP catches them earlier at BLUEPRINT --approve.

This check is complementary to the BLUEPRINT `--start` Consumes-Contract Resolution Gate and the IMPLEMENT `--plan` Consumes-Contract Upstream Freeze Gate. Those two gates BLOCK; this CVP check flags the same gaps with traceability matrix output so they appear on the coherence report.

```yaml
FUNCTION check_consumes_contract_resolution(elements):
  spec = elements.spec_feature
  IF spec IS NULL: RETURN
  upstream_features = spec.frontmatter.consumes_contract OR []

  IF upstream_features IS EMPTY:
    YIELD { check: "consumes_contract_resolution", severity: PASS,
            source: "spec.feature.consumes_contract",
            target: "no upstream dependencies declared" }
    RETURN

  FOR EACH upstream_id IN upstream_features:
    # Step 1 — upstream feature must exist with APPROVED design.md
    upstream_design_path = "docs/spec/{upstream_id}/design.md"
    upstream_design = READ_IF_EXISTS(upstream_design_path)
    IF upstream_design IS NULL:
      YIELD { check: "consumes_contract_resolution", severity: CRITICAL,
              source: "spec.feature.consumes_contract[{upstream_id}]",
              gap: "Upstream feature {upstream_id} has no design.md at {upstream_design_path}",
              remediation: "Produce the upstream feature first (CODESIGN --start {upstream_id} → BLUEPRINT --approve {upstream_id}), or remove {upstream_id} from consumes_contract" }
      CONTINUE
    upstream_status = upstream_design.frontmatter.status
    IF upstream_status NOT IN ["APPROVED", "IMPLEMENTED_AND_VERIFIED"]:
      YIELD { check: "consumes_contract_resolution", severity: CRITICAL,
              source: "spec.feature.consumes_contract[{upstream_id}]",
              gap: "Upstream {upstream_id} design.md status is '{upstream_status}', not APPROVED — downstream cannot safely bind to a draft schema",
              remediation: "Wait for BLUEPRINT --approve {upstream_id}, or drop the dependency" }
      CONTINUE

    # Step 2 — upstream must have frozen contract files (scope-aware)
    upstream_scope = READ_IF_EXISTS("docs/spec/{upstream_id}/spec.feature").frontmatter.scope OR "full-stack"
    IF upstream_scope == "frontend-only":
      YIELD { check: "consumes_contract_resolution", severity: CRITICAL,
              source: "spec.feature.consumes_contract[{upstream_id}]",
              gap: "Upstream {upstream_id} has scope=frontend-only — frontend-only features own no contract to consume; this is a scope mismatch",
              remediation: "Point consumes_contract at the backend feature that owns the contract, or remove the entry" }
      CONTINUE
    upstream_contracts_dir = "docs/spec/{upstream_id}/contracts/"
    contract_files_root = GLOB("contracts/{openapi,graphql,grpc,asyncapi,webhooks}/**/{upstream_id}*/**/*.{yaml,yml,graphql,proto}")
    contract_files_per_feature = GLOB("{upstream_contracts_dir}**/*.{yaml,yml,graphql,proto}") IF DIR_EXISTS(upstream_contracts_dir) ELSE []
    contract_files = contract_files_root ∪ contract_files_per_feature
    IF contract_files IS EMPTY:
      YIELD { check: "consumes_contract_resolution", severity: CRITICAL,
              source: "spec.feature.consumes_contract[{upstream_id}]",
              gap: "Upstream {upstream_id} is APPROVED (scope={upstream_scope}) but has no frozen contract files under contracts/** or {upstream_contracts_dir}",
              remediation: "Verify upstream BLUEPRINT --approve produced contract artefacts. If contract-first-policy layout is at repo root, at least one file must match the upstream feature slug." }
      CONTINUE

    # Step 3 — optional, full-sdlc only — CONTRACT-FREEZE issue Done, not stale
    project_tracking = READ_IF_EXISTS(".context/governance_snapshot.md").setup_configuration.project_tracking OR {}
    IF project_tracking.feature_phases == "full-sdlc":
      ADAPTER = READ "docs/backlog/tool-adapter.md"
      upstream_cf_issue = ADAPTER.query_board() → find WHERE labels CONTAINS "phase:contract-freeze" AND title CONTAINS upstream_id
      IF upstream_cf_issue IS NULL:
        YIELD { check: "consumes_contract_resolution", severity: WARNING,
                source: "spec.feature.consumes_contract[{upstream_id}]",
                gap: "Upstream {upstream_id} has no CONTRACT-FREEZE issue on the board (full-sdlc preset would expect one)",
                remediation: "Run BACKLOG --plan-feature {upstream_id} to materialise the 8-phase preset with the gate" }
      ELSE IF upstream_cf_issue.status != "Done":
        YIELD { check: "consumes_contract_resolution", severity: CRITICAL,
                source: "spec.feature.consumes_contract[{upstream_id}]",
                gap: "Upstream {upstream_id} CONTRACT-FREEZE is not Done (status={upstream_cf_issue.status})",
                remediation: "Close upstream CONTRACT-FREEZE first" }
      ELSE IF "stale-after-cascade" IN upstream_cf_issue.labels:
        YIELD { check: "consumes_contract_resolution", severity: CRITICAL,
                source: "spec.feature.consumes_contract[{upstream_id}]",
                gap: "Upstream {upstream_id} CONTRACT-FREEZE is stale (label: stale-after-cascade)",
                remediation: "Run BLUEPRINT --refine {upstream_id} to re-sync contracts, then re-close its CONTRACT-FREEZE issue (removing the stale label). This feature's dev_plan.md may need a CASCADE_PENDING_ITERATION sync as well (see factory-iteration-model/SKILL.md § CASCADE_CONSUMERS)." }

    YIELD { check: "consumes_contract_resolution", severity: PASS,
            source: "spec.feature.consumes_contract[{upstream_id}]",
            target: "upstream APPROVED, contracts present, gate Done + current" }
```

### Check 0c: `increment_plan_presence` (CRITICAL)

`increment_plan.md` must exist and be well-formed once `spec.feature` declares `slicing_strategy` (default `incremental`). A missing or malformed plan blocks IMPLEMENT's per-increment consumption downstream. Pre-slicing features (legacy spec.feature without the field) degrade to a single implicit monolithic increment and raise a WARNING to adopt the field.

```yaml
FUNCTION check_increment_plan_presence(elements):
  spec = elements.spec_feature
  IF spec IS NULL:
    RETURN   # caller already flagged missing spec.feature elsewhere

  slicing = spec.frontmatter.slicing_strategy OR "MISSING"
  plan = elements.increment_plan   # may be NULL

  IF slicing == "MISSING":
    YIELD { check: "increment_plan_presence", severity: WARNING,
            source: "spec.feature.frontmatter.slicing_strategy",
            gap: "Legacy spec.feature has no slicing_strategy field — treated as implicit monolithic",
            remediation: "Add slicing_strategy: incremental (default) to spec.feature frontmatter and re-run BLUEPRINT --start to emit increment_plan.md" }
    RETURN

  IF plan IS NULL:
    YIELD { check: "increment_plan_presence", severity: CRITICAL,
            source: "docs/spec/{FEATURE_ID}/increment_plan.md",
            gap: "slicing_strategy='{slicing}' declared in spec.feature but increment_plan.md is absent",
            remediation: "Run BLUEPRINT --start {FEATURE_ID} to emit the Increment Plan (Increment Plan Generation sub-phase)" }
    RETURN

  # Plan exists — frontmatter integrity checks.
  # required_fields below are the MINIMAL contract this check enforces. Additional fields in the
  # template (last_update, based_on_iteration, based_on_schemas_version, pending_iteration,
  # pending_schemas_version, invalidated_increments, invalidated_by_iteration, invalidated_reason,
  # cascade_source, cascade_timestamp, rdr_rationale) are populated opportunistically — by BLUEPRINT
  # initial emission, by CASCADE_INCREMENT_INTERNAL, by CASCADE_PENDING_ITERATION — and SHOULD be
  # absent or null in a fresh plan. Their presence or absence is validated at iteration cascade
  # time (see factory-iteration-model), not here. Keep required_fields minimal to avoid coupling
  # Check 0c to the cascade lifecycle.
  fm = plan.frontmatter
  # NOTE (EVOL-036): rdr_ratified_at is NOT unconditionally required — it is legitimately null for the
  # DEFAULT 1:1 plan (no intra-slice layering RDR ran). It is gated conditionally below, not here.
  required_fields = ["id", "status", "slicing_strategy", "scope", "total_increments", "rdr_alternatives_considered"]
  missing = [f FOR f IN required_fields IF fm.get(f) IS NULL]
  IF missing NOT EMPTY:
    YIELD { check: "increment_plan_presence", severity: CRITICAL,
            source: "increment_plan.md.frontmatter",
            gap: "Missing required fields: {missing}",
            remediation: "Re-run BLUEPRINT --refine {FEATURE_ID} — the generator populates these fields automatically" }

  IF fm.slicing_strategy != slicing:
    YIELD { check: "increment_plan_presence", severity: CRITICAL,
            source: "increment_plan.md.frontmatter.slicing_strategy='{fm.slicing_strategy}'",
            gap: "Slicing strategy drift: spec.feature says '{slicing}', increment_plan says '{fm.slicing_strategy}'",
            remediation: "spec.feature is authoritative. Re-run BLUEPRINT --refine to regenerate increment_plan.md with the correct strategy" }

  # NOTE (EVOL-036): the mandatory ≥3 RDR moved UPSTREAM to CODESIGN's slice_map.md (capability-VALUE
  # slicing) — enforced by Check 0d slice_map_presence. increment_plan's `rdr_alternatives_considered`
  # now counts OPTIONAL intra-slice layering alternatives (0 when every slice maps 1:1), so it is NOT
  # gated here. BLUEPRINT REFINES authoritative slices into increments; it does not invent ≥3 slicings.
  # Conditional: rdr_ratified_at must be non-null ONLY when a layering RDR actually ran (alternatives >= 1).
  IF fm.status == "APPROVED" AND (fm.rdr_alternatives_considered OR 0) >= 1 AND fm.rdr_ratified_at IS NULL:
    YIELD { check: "increment_plan_presence", severity: CRITICAL,
            source: "increment_plan.md.frontmatter.rdr_ratified_at",
            gap: "An intra-slice layering RDR was recorded (rdr_alternatives_considered={fm.rdr_alternatives_considered}) but rdr_ratified_at is null",
            remediation: "A layering split requires verbatim user ratification — re-run BLUEPRINT --refine and ratify the layering choice" }

  YIELD { check: "increment_plan_presence", severity: PASS,
          source: "increment_plan.md",
          target: "present, {fm.total_increments} increments, slicing_strategy={fm.slicing_strategy}" }
```

### Check 0d: `slice_map_presence` (CRITICAL — EVOL-036)

`slice_map.md` is CODESIGN's authoritative capability-VALUE slicing. It must exist + be well-formed when `slicing_strategy == incremental`, and be absent when `monolithic`. The mandatory ≥3 slicing-value RDR lives HERE (moved upstream from increment_plan — Check 0c no longer gates it). Mirrors Check 0c structure.

```yaml
FUNCTION check_slice_map_presence(elements):
  spec = elements.spec_feature
  IF spec IS NULL: RETURN

  slicing = spec.frontmatter.slicing_strategy OR "MISSING"
  sm = elements.slice_map   # may be NULL

  IF slicing != "incremental":
    # monolithic / legacy-missing → no slice_map expected (vacuous PASS)
    IF sm IS NOT NULL:
      YIELD { check: "slice_map_presence", severity: WARNING,
              source: "docs/spec/{FEATURE_ID}/slice_map.md",
              gap: "slice_map.md present but slicing_strategy='{slicing}' (monolithic features carry no slice_map)",
              remediation: "Remove slice_map.md, or set slicing_strategy: incremental in spec.feature" }
    ELSE:
      YIELD { check: "slice_map_presence", severity: PASS, note: "slicing_strategy={slicing} — no slice_map expected" }
    RETURN

  IF sm IS NULL:
    # Grandfather (EVOL-036 backward-compat): a feature created BEFORE EVOL-036 already has an
    # increment_plan.md but no slice_map.md. Hard-blocking it would strand every in-flight incremental
    # feature on framework upgrade with no safe migration (re-running CODESIGN on a merged upstream risks
    # check_slice_immutability). Degrade to a migration advisory instead — MERGED increments are unaffected.
    IF elements.increment_plan IS NOT NULL:
      YIELD { check: "slice_map_presence", severity: WARNING,
              source: "docs/spec/{FEATURE_ID}/slice_map.md",
              gap: "Legacy incremental feature: increment_plan.md present but slice_map.md absent (pre-EVOL-036)",
              remediation: "Optional migration: run CODESIGN --refine {FEATURE_ID} to back-fill slice_map.md (the two-stage value authority). Already-MERGED increments are unaffected." }
      RETURN
    # New feature, pre-BLUEPRINT: slice_map MUST exist — CODESIGN emits it before BLUEPRINT refines.
    YIELD { check: "slice_map_presence", severity: CRITICAL,
            source: "docs/spec/{FEATURE_ID}/slice_map.md",
            gap: "slicing_strategy='incremental' but slice_map.md is absent — CODESIGN owns capability-value slicing",
            remediation: "Run CODESIGN --start {FEATURE_ID} (or --refine) to emit slice_map.md before BLUEPRINT refines it" }
    RETURN

  # Frontmatter integrity (minimal contract; RDR≥3 enforced here, not in increment_plan)
  fm = sm.frontmatter
  required_fields = ["id", "status", "slicing_strategy", "scope", "total_slices", "rdr_alternatives_considered", "rdr_ratified_at"]
  missing = [f FOR f IN required_fields IF fm.get(f) IS NULL]
  IF missing NOT EMPTY:
    YIELD { check: "slice_map_presence", severity: CRITICAL,
            source: "slice_map.md.frontmatter",
            gap: "Missing required fields: {missing}",
            remediation: "Re-run CODESIGN --refine {FEATURE_ID} — the generator populates these fields automatically" }

  IF fm.status == "APPROVED" AND fm.rdr_alternatives_considered < 3:
    YIELD { check: "slice_map_presence", severity: CRITICAL,
            source: "slice_map.md.frontmatter.rdr_alternatives_considered = {fm.rdr_alternatives_considered}",
            gap: "Approved slice_map with <3 slicing-value alternatives — factory-rdr mandates ≥3",
            remediation: "Re-run the slicing-value RDR via CODESIGN --refine {FEATURE_ID}" }

  IF fm.slicing_strategy != slicing:
    YIELD { check: "slice_map_presence", severity: CRITICAL,
            source: "slice_map.md.frontmatter.slicing_strategy='{fm.slicing_strategy}'",
            gap: "Slicing strategy drift: spec.feature says '{slicing}', slice_map says '{fm.slicing_strategy}'",
            remediation: "spec.feature is authoritative. Re-run CODESIGN --refine to regenerate slice_map.md" }

  YIELD { check: "slice_map_presence", severity: PASS,
          source: "slice_map.md",
          target: "present, {fm.total_slices} slices, rdr_alternatives={fm.rdr_alternatives_considered}" }
```

### Check 1: `scenario_to_component` (CRITICAL)

Every Gherkin scenario in `spec.feature` must map to at least one component/service in `design.md`.

```yaml
FUNCTION check_scenario_to_component(elements):
  scenarios = elements.spec_scenarios          # [{name, steps, tags}]
  components = elements.design_components      # [{name, type, module, responsibility}]

  FOR EACH scenario IN scenarios:
    # Extract domain actions from Given/When/Then steps
    domain_actions = EXTRACT_DOMAIN_ACTIONS(scenario.steps)
    matched = FALSE

    FOR EACH action IN domain_actions:
      FOR EACH component IN components:
        IF action SEMANTICALLY_RELATES_TO component.responsibility:
          matched = TRUE
          TRACE(scenario.name → component.name)
          BREAK

    IF NOT matched:
      YIELD { check: "scenario_to_component", severity: CRITICAL,
              source: "spec.feature: '{scenario.name}'",
              gap: "No component in design.md handles actions from this scenario",
              remediation: "BLUEPRINT --refine {ID} to add component coverage" }
    ELSE:
      YIELD { check: "scenario_to_component", severity: PASS,
              source: scenario.name, target: matched_components }
```

### Check 2: `data_schema_to_data_model` (CRITICAL)

Every field in `user_journey.md` Data Schemas must appear in `design.md` data model.

```yaml
FUNCTION check_data_schema_to_data_model(elements):
  uj_schemas = elements.user_journey_schemas     # [{entity, fields: [{name, type, constraints}]}]
  dm_entities = elements.design_data_model       # [{entity, fields: [{name, type, nullable, ...}]}]

  FOR EACH uj_entity IN uj_schemas:
    # Find matching entity in design data model
    dm_match = FIND(dm_entities, entity_name ~= uj_entity.entity)

    IF dm_match IS NULL:
      YIELD { check: "data_schema_to_data_model", severity: CRITICAL,
              source: "user_journey.md: entity '{uj_entity.entity}'",
              gap: "Entity not found in design.md data model",
              remediation: "BLUEPRINT --refine {ID} to add entity to data model" }
      CONTINUE

    FOR EACH field IN uj_entity.fields:
      field_match = FIND(dm_match.fields, name ~= field.name)
      IF field_match IS NULL:
        YIELD { check: "data_schema_to_data_model", severity: CRITICAL,
                source: "user_journey.md: '{uj_entity.entity}.{field.name}'",
                gap: "Field not found in design.md data model for entity '{dm_match.entity}'",
                remediation: "BLUEPRINT --refine {ID} to add field" }
      ELSE:
        YIELD { check: "data_schema_to_data_model", severity: PASS,
                source: "{uj_entity.entity}.{field.name}", target: "{dm_match.entity}.{field_match.name}" }
```

### Check 3: `ui_component_to_inventory` (CRITICAL for UI features)

Every interactive component in `mock.html` must have a corresponding entry in `design.md` Component Inventory.

```yaml
FUNCTION check_ui_component_to_inventory(elements):
  # Skip if no UI (non-frontend feature)
  IF elements.mock_components IS EMPTY:
    YIELD { check: "ui_component_to_inventory", severity: PASS, note: "No UI — skipped" }
    RETURN

  mock_components = elements.mock_components       # [{tag/class, role, data-attributes}]
  design_components = elements.design_ui_inventory # [{name, type, props, events}]

  FOR EACH mock_comp IN mock_components:
    matched = FIND(design_components, name ~= mock_comp.role OR type ~= mock_comp.tag)
    IF matched IS NULL:
      YIELD { check: "ui_component_to_inventory", severity: CRITICAL,
              source: "mock.html: component '{mock_comp.role}'",
              gap: "No matching component in design.md Component Inventory",
              remediation: "BLUEPRINT --refine {ID} to register UI component" }
    ELSE:
      YIELD { check: "ui_component_to_inventory", severity: PASS,
              source: mock_comp.role, target: matched.name }
```

### Check 4: `journey_step_to_endpoint` (CRITICAL)

Every user journey step that implies a system interaction must map to a contract endpoint.

```yaml
FUNCTION check_journey_step_to_endpoint(elements):
  journey_steps = elements.user_journey_steps      # [{step_id, action, system_interaction}]
  contract_endpoints = elements.contract_endpoints  # [{method, path, operation_id, contract_slug}]

  FOR EACH step IN journey_steps:
    IF step.system_interaction IS NULL:
      CONTINUE  # Pure UI navigation or user-only action

    matched = FIND(contract_endpoints,
      operation SEMANTICALLY_RELATES_TO step.system_interaction)

    IF matched IS NULL:
      YIELD { check: "journey_step_to_endpoint", severity: CRITICAL,
              source: "user_journey.md: step '{step.step_id}' — '{step.action}'",
              gap: "System interaction has no matching contract endpoint",
              remediation: "BLUEPRINT --refine {ID} to add endpoint for this interaction" }
    ELSE:
      YIELD { check: "journey_step_to_endpoint", severity: PASS,
              source: step.step_id, target: "{matched.method} {matched.path}" }
```

### Check 5: `scenario_to_test_coverage` (CRITICAL)

Every `spec.feature` scenario must have at least one test case in `test_plan.md`.

```yaml
FUNCTION check_scenario_to_test_coverage(elements):
  scenarios = elements.spec_scenarios
  test_cases = elements.test_plan_cases  # [{id, scenario_ref, type, description}]

  FOR EACH scenario IN scenarios:
    matched = FILTER(test_cases, scenario_ref ~= scenario.name)
    IF matched.length == 0:
      YIELD { check: "scenario_to_test_coverage", severity: CRITICAL,
              source: "spec.feature: '{scenario.name}'",
              gap: "No test case covers this scenario in test_plan.md",
              remediation: "BLUEPRINT --refine {ID} to add test coverage" }
    ELSE:
      YIELD { check: "scenario_to_test_coverage", severity: PASS,
              source: scenario.name, target: matched.map(tc => tc.id) }
```

### Check 6: `contract_to_test_coverage` (CRITICAL)

Every contract endpoint must have at least one integration test (TC-API-XX) in `test_plan.md`.

```yaml
FUNCTION check_contract_to_test_coverage(elements):
  endpoints = elements.contract_endpoints
  test_cases = elements.test_plan_cases

  FOR EACH endpoint IN endpoints:
    matched = FILTER(test_cases,
      type == "integration" AND description REFERENCES endpoint.path)
    IF matched.length == 0:
      YIELD { check: "contract_to_test_coverage", severity: CRITICAL,
              source: "Contract: {endpoint.method} {endpoint.path}",
              gap: "No integration test covers this endpoint in test_plan.md",
              remediation: "BLUEPRINT --refine {ID} to add API integration test" }
    ELSE:
      YIELD { check: "contract_to_test_coverage", severity: PASS,
              source: "{endpoint.method} {endpoint.path}", target: matched.map(tc => tc.id) }
```

### Check 7: `contract_to_task` (WARNING — IMPLEMENT scope)

Every contract endpoint should have a corresponding implementation task in `dev_plan.md`.

```yaml
FUNCTION check_contract_to_task(elements):
  endpoints = elements.contract_endpoints
  tasks = elements.dev_plan_tasks  # [{id, description, phase, checkbox_status}]

  FOR EACH endpoint IN endpoints:
    matched = FILTER(tasks,
      description REFERENCES endpoint.path OR description REFERENCES endpoint.operation_id)
    IF matched.length == 0:
      YIELD { check: "contract_to_task", severity: WARNING,
              source: "Contract: {endpoint.method} {endpoint.path}",
              gap: "No dev_plan.md task implements this endpoint",
              remediation: "Verify endpoint is covered by a broader task or add specific task" }
    ELSE:
      YIELD { check: "contract_to_task", severity: PASS,
              source: "{endpoint.method} {endpoint.path}", target: matched.map(t => t.id) }
```

### Check 8: `test_case_to_task` (WARNING — IMPLEMENT scope)

Every test case in `test_plan.md` should have a corresponding test-writing task in `dev_plan.md`.

```yaml
FUNCTION check_test_case_to_task(elements):
  test_cases = elements.test_plan_cases
  tasks = elements.dev_plan_tasks

  FOR EACH tc IN test_cases:
    matched = FILTER(tasks,
      description REFERENCES tc.id OR description REFERENCES tc.description)
    IF matched.length == 0:
      YIELD { check: "test_case_to_task", severity: WARNING,
              source: "test_plan.md: '{tc.id}'",
              gap: "No dev_plan.md task writes this test",
              remediation: "Verify test is covered by a batch task or add specific task" }
    ELSE:
      YIELD { check: "test_case_to_task", severity: PASS,
              source: tc.id, target: matched.map(t => t.id) }
```

### Check 9: `ui_component_to_task` (WARNING — IMPLEMENT scope)

Every UI component in `design.md` Component Inventory should have a corresponding frontend task.

```yaml
FUNCTION check_ui_component_to_task(elements):
  IF elements.design_ui_inventory IS EMPTY:
    YIELD { check: "ui_component_to_task", severity: PASS, note: "No UI — skipped" }
    RETURN

  components = elements.design_ui_inventory
  tasks = elements.dev_plan_tasks

  FOR EACH comp IN components:
    matched = FILTER(tasks, description REFERENCES comp.name AND phase IN ["B", "C"])
    IF matched.length == 0:
      YIELD { check: "ui_component_to_task", severity: WARNING,
              source: "design.md UI: '{comp.name}'",
              gap: "No dev_plan.md frontend task for this component",
              remediation: "Verify component is covered by a page-level task" }
    ELSE:
      YIELD { check: "ui_component_to_task", severity: PASS,
              source: comp.name, target: matched.map(t => t.id) }
```

### Check 10: `data_model_to_task` (WARNING — IMPLEMENT scope)

Every entity in `design.md` data model should have a Phase A task in `dev_plan.md`.

```yaml
FUNCTION check_data_model_to_task(elements):
  entities = elements.design_data_model
  tasks = elements.dev_plan_tasks

  FOR EACH entity IN entities:
    matched = FILTER(tasks,
      description REFERENCES entity.entity AND phase == "A")
    IF matched.length == 0:
      YIELD { check: "data_model_to_task", severity: WARNING,
              source: "design.md entity: '{entity.entity}'",
              gap: "No Phase A task for this entity in dev_plan.md",
              remediation: "Verify entity is covered by a broader data task" }
    ELSE:
      YIELD { check: "data_model_to_task", severity: PASS,
              source: entity.entity, target: matched.map(t => t.id) }
```

### Check 11: `scenario_to_qa_check` (WARNING — QA scope)

Every `spec.feature` scenario should have a corresponding QA checklist item.

```yaml
FUNCTION check_scenario_to_qa_check(elements):
  IF elements.qa_checklist IS NULL:
    # QA report not yet generated — skip (will be generated during --verify)
    YIELD { check: "scenario_to_qa_check", severity: PASS, note: "QA report pending — deferred" }
    RETURN

  scenarios = elements.spec_scenarios
  qa_items = elements.qa_checklist  # [{id, description, checked}]

  FOR EACH scenario IN scenarios:
    matched = FILTER(qa_items, description REFERENCES scenario.name)
    IF matched.length == 0:
      YIELD { check: "scenario_to_qa_check", severity: WARNING,
              source: "spec.feature: '{scenario.name}'",
              gap: "No QA checklist item traces to this scenario",
              remediation: "QA report should include verification for this scenario" }
    ELSE:
      YIELD { check: "scenario_to_qa_check", severity: PASS,
              source: scenario.name, target: matched.map(q => q.id) }
```

### Check 12: `task_completion_to_qa` (WARNING — QA scope)

Every completed dev_plan.md task should be within QA verification scope.

```yaml
FUNCTION check_task_completion_to_qa(elements):
  IF elements.qa_checklist IS NULL:
    YIELD { check: "task_completion_to_qa", severity: PASS, note: "QA report pending — deferred" }
    RETURN

  completed_tasks = FILTER(elements.dev_plan_tasks, checkbox_status == CHECKED)
  qa_items = elements.qa_checklist

  FOR EACH task IN completed_tasks:
    matched = FILTER(qa_items, description REFERENCES task.description OR description REFERENCES task.id)
    IF matched.length == 0:
      YIELD { check: "task_completion_to_qa", severity: WARNING,
              source: "dev_plan.md: '{task.id}'",
              gap: "Completed task has no corresponding QA verification item",
              remediation: "QA report should verify this implemented task" }
    ELSE:
      YIELD { check: "task_completion_to_qa", severity: PASS,
              source: task.id, target: matched.map(q => q.id) }
```

### Check 13: `increment_deployability` (CRITICAL)

Every increment in `increment_plan.md § 1` must declare `deployable: production`, carry a non-empty acceptance checklist, and the cross-increment `depends_on` graph must be acyclic. Feature-flag-OFF merges are not a valid deployability escape — flagged rollouts must be expressed as explicit follow-up increments with their own scenarios.

```yaml
FUNCTION check_increment_deployability(elements):
  plan = elements.increment_plan
  IF plan IS NULL: RETURN   # handled by Check 0c

  increments = elements.increments   # [{id, status, scope, scenarios_covered, contract_surface, depends_on, deployable, acceptance_checklist}]

  IF increments IS EMPTY:
    YIELD { check: "increment_deployability", severity: CRITICAL,
            source: "increment_plan.md § 1",
            gap: "Increment Plan has zero increments declared",
            remediation: "BLUEPRINT --refine {FEATURE_ID} — at least one INC-1 section required" }
    RETURN

  # Per-increment field validation
  FOR EACH inc IN increments:
    IF inc.deployable != "production":
      YIELD { check: "increment_deployability", severity: CRITICAL,
              source: "{inc.id}.deployable = '{inc.deployable}'",
              gap: "Increment declares deployable != production (found: '{inc.deployable}')",
              remediation: "Strict policy: every increment must ship serving real traffic. For flagged rollouts, express the flag as a NEW follow-up increment with its own scenarios instead." }

    IF inc.acceptance_checklist IS EMPTY:
      YIELD { check: "increment_deployability", severity: CRITICAL,
              source: "{inc.id}.acceptance",
              gap: "Increment has no acceptance checklist items",
              remediation: "Populate the acceptance block per the template (E2E / API / Reliability / CVP / no-TODO)" }

    IF inc.scenarios_covered IS EMPTY AND inc.contract_surface IS EMPTY:
      YIELD { check: "increment_deployability", severity: CRITICAL,
              source: "{inc.id}",
              gap: "Increment has neither scenarios nor contract ops — nothing to deploy",
              remediation: "Either populate scenarios_covered + contract_surface, or remove this increment" }

  # DAG acyclicity (Kahn's algorithm)
  inc_ids = { inc.id FOR inc IN increments }
  FOR EACH inc IN increments:
    FOR EACH dep IN inc.depends_on:
      IF dep NOT IN inc_ids:
        YIELD { check: "increment_deployability", severity: CRITICAL,
                source: "{inc.id}.depends_on",
                gap: "Depends on non-existent increment '{dep}'",
                remediation: "Fix dangling reference or add the missing increment" }

  cycle = DETECT_CYCLE_BY_TOPOLOGICAL_SORT(increments, edge=depends_on)
  IF cycle IS NOT NULL:
    YIELD { check: "increment_deployability", severity: CRITICAL,
            source: "increment_plan.md § 1 (depends_on edges)",
            gap: "Cyclic dependency detected: {cycle.path}",
            remediation: "Break the cycle by removing at least one depends_on edge, or merge the cyclic increments into a single increment" }

  # INC-1 must have no dependencies (root)
  root_candidates = FILTER(increments, depends_on IS EMPTY)
  IF root_candidates IS EMPTY:
    YIELD { check: "increment_deployability", severity: CRITICAL,
            source: "increment_plan.md § 1",
            gap: "No root increment (every increment has depends_on — implies a cycle or orphaned subtree)",
            remediation: "Mark the first increment with depends_on: []" }

  IF all_checks_passed:
    YIELD { check: "increment_deployability", severity: PASS,
            source: "increment_plan.md",
            target: "{increments.length} increments, all deployable:production, DAG acyclic, {root_candidates.length} root(s)" }
```

### Check 14: `increment_to_scenario_coverage` (CRITICAL)

Every `Scenario:` declared in `spec.feature` must appear in exactly one increment's `scenarios_covered` list. No scenario orphan (undeployed), no scenario duplicated across two increments (ambiguous ownership).

```yaml
FUNCTION check_increment_to_scenario_coverage(elements):
  plan = elements.increment_plan
  IF plan IS NULL: RETURN

  spec_scenarios = { s.name FOR s IN elements.spec_scenarios }   # canonical set from spec.feature
  increments = elements.increments

  # Build reverse map: scenario_name → [inc_ids that cover it]
  coverage_map = {}
  FOR EACH inc IN increments:
    FOR EACH scenario_name IN inc.scenarios_covered:
      coverage_map.setdefault(scenario_name, []).append(inc.id)

  # Orphans: in spec but not in any increment
  orphans = spec_scenarios - coverage_map.keys()
  FOR EACH orphan IN orphans:
    YIELD { check: "increment_to_scenario_coverage", severity: CRITICAL,
            source: "spec.feature: Scenario '{orphan}'",
            gap: "Scenario not assigned to any increment",
            remediation: "BLUEPRINT --refine {FEATURE_ID} — assign '{orphan}' to an existing increment or add a new increment for it" }

  # Duplicates: in multiple increments
  FOR EACH (scenario, inc_ids) IN coverage_map:
    IF inc_ids.length > 1:
      YIELD { check: "increment_to_scenario_coverage", severity: CRITICAL,
              source: "Scenario '{scenario}'",
              gap: "Covered by multiple increments: {inc_ids}",
              remediation: "Each scenario must have exactly one owning increment. Remove duplicates from all but one." }

  # Phantoms: in increment but not in spec.feature
  phantoms = coverage_map.keys() - spec_scenarios
  FOR EACH phantom IN phantoms:
    YIELD { check: "increment_to_scenario_coverage", severity: CRITICAL,
            source: "increment_plan.md: scenarios_covered references '{phantom}'",
            gap: "Referenced scenario does not exist in spec.feature",
            remediation: "Fix typo, or remove the phantom reference, or add the scenario to spec.feature" }

  IF orphans IS EMPTY AND all_counts_are_1 AND phantoms IS EMPTY:
    YIELD { check: "increment_to_scenario_coverage", severity: PASS,
            source: "spec.feature × increment_plan.md",
            target: "{spec_scenarios.length} scenarios, each covered by exactly one increment" }
```

### Check 15: `increment_to_contract_coverage` (CRITICAL)

Every contract operation (OpenAPI operationId, GraphQL root field, gRPC RPC, AsyncAPI message) produced by BLUEPRINT must appear in exactly one increment's `contract_surface`.

```yaml
FUNCTION check_increment_to_contract_coverage(elements):
  plan = elements.increment_plan
  IF plan IS NULL: RETURN

  # Extract canonical contract operations from contracts/**
  contract_ops = { op.canonical_id FOR op IN elements.contract_endpoints }   # method+path for REST, type.field for GraphQL, service.rpc for gRPC, channel.message for AsyncAPI

  IF contract_ops IS EMPTY:
    YIELD { check: "increment_to_contract_coverage", severity: PASS,
            source: "contracts/**",
            target: "no contract operations — check vacuously satisfied" }
    RETURN

  increments = elements.increments

  coverage_map = {}
  FOR EACH inc IN increments:
    FOR EACH op IN inc.contract_surface:
      coverage_map.setdefault(op, []).append(inc.id)

  orphans = contract_ops - coverage_map.keys()
  FOR EACH orphan IN orphans:
    YIELD { check: "increment_to_contract_coverage", severity: CRITICAL,
            source: "contracts/**: '{orphan}'",
            gap: "Contract operation not assigned to any increment",
            remediation: "BLUEPRINT --refine {FEATURE_ID} — assign '{orphan}' to an existing increment or add a new increment for it" }

  FOR EACH (op, inc_ids) IN coverage_map:
    IF inc_ids.length > 1:
      YIELD { check: "increment_to_contract_coverage", severity: CRITICAL,
              source: "Contract op '{op}'",
              gap: "Covered by multiple increments: {inc_ids}",
              remediation: "Each contract op must have exactly one owning increment" }

  phantoms = coverage_map.keys() - contract_ops
  FOR EACH phantom IN phantoms:
    YIELD { check: "increment_to_contract_coverage", severity: CRITICAL,
            source: "increment_plan.md: contract_surface references '{phantom}'",
            gap: "Referenced contract op does not exist in contracts/**",
            remediation: "Fix typo or remove the phantom reference" }

  IF orphans IS EMPTY AND all_counts_are_1 AND phantoms IS EMPTY:
    YIELD { check: "increment_to_contract_coverage", severity: PASS,
            source: "contracts/** × increment_plan.md",
            target: "{contract_ops.length} contract operations, each covered by exactly one increment" }
```

### Check 16: `monolithic_heuristic` (CRITICAL when `slicing_strategy == monolithic`)

When the Increment Plan declares `slicing_strategy: monolithic`, § 2 Monolithic Escape Declaration must be present AND the trivial-heuristic must actually be satisfied (≤2 scenarios AND ≤3 contract operations AND scope ≠ full-stack). Monolithic escape with heuristic violation is governance drift — the feature should be re-sliced.

```yaml
FUNCTION check_monolithic_heuristic(elements):
  plan = elements.increment_plan
  IF plan IS NULL: RETURN
  IF plan.frontmatter.slicing_strategy != "monolithic":
    YIELD { check: "monolithic_heuristic", severity: PASS, note: "slicing_strategy=incremental — check not applicable" }
    RETURN

  # Must have § 2 Monolithic Escape Declaration
  IF plan.section_2_monolithic_escape IS NULL:
    YIELD { check: "monolithic_heuristic", severity: CRITICAL,
            source: "increment_plan.md § 2",
            gap: "slicing_strategy=monolithic but § 2 Monolithic Escape Declaration is missing",
            remediation: "BLUEPRINT --refine {FEATURE_ID} — populate § 2 with the satisfied heuristic metrics" }
    RETURN

  # Verify heuristic metrics
  scenarios_count = elements.spec_scenarios.length
  ops_count = elements.contract_endpoints.length
  scope = elements.spec_feature.frontmatter.scope

  IF scenarios_count > 2:
    YIELD { check: "monolithic_heuristic", severity: CRITICAL,
            source: "spec.feature",
            gap: "Monolithic escape claimed but spec.feature has {scenarios_count} scenarios (>2 threshold)",
            remediation: "Switch spec.feature.slicing_strategy to 'incremental' and re-run BLUEPRINT --refine to emit a sliced Increment Plan" }

  IF ops_count > 3:
    YIELD { check: "monolithic_heuristic", severity: CRITICAL,
            source: "contracts/**",
            gap: "Monolithic escape claimed but feature has {ops_count} contract operations (>3 threshold)",
            remediation: "Switch to incremental slicing — the feature is above the trivial-heuristic threshold" }

  IF scope == "full-stack":
    YIELD { check: "monolithic_heuristic", severity: CRITICAL,
            source: "spec.feature.scope",
            gap: "Monolithic escape is forbidden for full-stack features regardless of size",
            remediation: "Switch to incremental slicing" }

  IF all_checks_passed:
    YIELD { check: "monolithic_heuristic", severity: PASS,
            source: "increment_plan.md § 2",
            target: "heuristic satisfied: {scenarios_count} scenarios, {ops_count} ops, scope={scope}" }
```

### Check 17: `increment_to_task` (WARNING — IMPLEMENT scope)

When `slicing_strategy == incremental`, every increment should have at least one `[INC-N.A.M]` / `[INC-N.B.M]` / `[INC-N.C.M]` task in `dev_plan.md`. An increment with zero tasks is either scaffolding debt (IMPLEMENT `--plan` not yet run) or a stale plan entry.

```yaml
FUNCTION check_increment_to_task(elements):
  IF elements.increment_plan IS NULL: RETURN
  IF elements.increment_plan.frontmatter.slicing_strategy != "incremental": RETURN
  IF elements.dev_plan_tasks IS NULL: RETURN   # IMPLEMENT --plan not yet run

  increments = elements.increments
  tasks_by_inc = {}
  FOR EACH task IN elements.dev_plan_tasks:
    # Task id format: [INC-N.A.M] / [INC-N.B.M] / [INC-N.C.M]
    inc_id = EXTRACT_INCREMENT_PREFIX(task.id)
    IF inc_id IS NOT NULL:
      tasks_by_inc.setdefault(inc_id, []).append(task)

  FOR EACH inc IN increments:
    task_count = tasks_by_inc.get(inc.id, []).length
    IF task_count == 0:
      YIELD { check: "increment_to_task", severity: WARNING,
              source: "{inc.id}",
              gap: "Increment has zero tasks in dev_plan.md",
              remediation: "Run IMPLEMENT --plan {FEATURE_ID} to generate layer tasks for this increment, or mark the increment INVALIDATED if obsolete" }
    ELSE:
      YIELD { check: "increment_to_task", severity: PASS,
              source: inc.id, target: "{task_count} task(s)" }
```

### Check 18: `slice_to_increment_coverage` (CRITICAL — EVOL-036)

The two-stage join: every `SLICE-{FEAT}-N` in slice_map.md must be realized by ≥1 increment citing it via `cascade_source`; every increment must cite a real slice; and the scenarios are consistent across the join. Reuses the Check 14 orphan/duplicate/phantom set-diff machinery, keyed on the `cascade_source` join.

```yaml
FUNCTION check_slice_to_increment_coverage(elements):
  slices = elements.slices
  IF slices IS EMPTY: 
    YIELD { check: "slice_to_increment_coverage", severity: PASS, note: "no slice_map (monolithic/pre-slicing) — not applicable" }
    RETURN
  increments = elements.increments
  IF increments IS EMPTY: RETURN   # pre-BLUEPRINT — handled by Check 13/0c; Check 18 needs realizers to join

  slice_ids = { s.id FOR s IN slices }

  # Build join: slice_id → [increment ids that cite it via cascade_source]
  realized = {}
  FOR EACH inc IN increments:
    realized.setdefault(inc.cascade_source, []).append(inc.id)

  # (a) every slice realized by ≥1 increment
  FOR EACH s IN slices:
    IF realized.get(s.id, []) IS EMPTY:
      YIELD { check: "slice_to_increment_coverage", severity: CRITICAL,
              source: "slice_map.md: {s.id}",
              gap: "Slice not realized by any increment (no increment with cascade_source: {s.id})",
              remediation: "BLUEPRINT --refine {FEATURE_ID} — map {s.id} to an increment, or remove the orphan slice via CODESIGN --refine" }

  # (b) every increment cites a real slice (no phantom cascade_source)
  FOR EACH inc IN increments:
    IF inc.cascade_source IS NULL OR inc.cascade_source NOT IN slice_ids:
      YIELD { check: "slice_to_increment_coverage", severity: CRITICAL,
              source: "increment_plan.md: {inc.id}.cascade_source='{inc.cascade_source}'",
              gap: "Increment cascade_source does not resolve to a real slice in slice_map.md",
              remediation: "Set cascade_source to a valid SLICE-{FEAT}-N (Rule 9 join key)" }

  # (c) scenario consistency: union of scenarios across realizing increments == slice scenarios
  FOR EACH s IN slices:
    realizing = FILTER(increments, inc.cascade_source == s.id)
    inc_scenarios = UNION(realizing.map(inc => inc.scenarios_covered))
    IF SET(inc_scenarios) != SET(s.scenarios_covered):
      YIELD { check: "slice_to_increment_coverage", severity: CRITICAL,
              source: "{s.id}",
              gap: "Scenario set drift between slice and its realizing increments: slice={s.scenarios_covered}, increments={inc_scenarios}",
              remediation: "Align the increments' scenarios_covered with the slice (BLUEPRINT --refine) — a slice and its realizers must cover the same scenarios" }

  IF no_gaps_yielded:
    YIELD { check: "slice_to_increment_coverage", severity: PASS,
            source: "slice_map.md × increment_plan.md",
            target: "{slices.length} slices, each realized; scenario sets consistent across cascade_source join" }
```

### Check 19: `slice_seam_resolution` (CRITICAL — EVOL-036)

Each `depends_on_slice` resolves to a real intra-feature slice AND the set forms a DAG (Kahn). Each `depends_on_feature: [FEAT-Y@SLICE-Y-Z]` resolves to a real upstream feature whose slice_map declares that slice AND whose design is APPROVED. Every declared dependency MUST carry a `seam`. Cross-feature reads widen the standing "CVP is per-feature" invariant — a ratified scope expansion (ADR-EVOL-036).

```yaml
FUNCTION check_slice_seam_resolution(elements):
  slices = elements.slices
  IF slices IS EMPTY:
    YIELD { check: "slice_seam_resolution", severity: PASS, note: "no slice_map — not applicable" }
    RETURN
  slice_ids = { s.id FOR s IN slices }

  FOR EACH s IN slices:
    # intra-feature ordering deps
    FOR EACH dep IN s.depends_on_slice:
      IF dep NOT IN slice_ids:
        YIELD { check: "slice_seam_resolution", severity: CRITICAL,
                source: "{s.id}.depends_on_slice",
                gap: "Depends on non-existent slice '{dep}'",
                remediation: "Fix the reference or add the missing slice (CODESIGN --refine)" }

    # cross-feature deps — FEAT-Y@SLICE-Y-Z, 4 fail-modes.
    # NOTE (cascade coverage): a cross-feature seam's iteration cascade is carried by the EXISTING
    # consumes_contract / CASCADE_CONSUMERS path (the per-slice gate explicitly disclaims cross-feature
    # locks). For that delegation to actually fire, the consuming feature SHOULD also declare FEAT-Y in
    # spec.feature.consumes_contract — if it does not, the depends_on_feature ordering is advisory only
    # (review-confirmed via the seam, not cascade-enforced). WARN when a depends_on_feature has no
    # matching consumes_contract entry.
    FOR EACH dep IN s.depends_on_feature:
      (feat_id, slice_ref) = PARSE_FEATURE_SLICE_REF(dep)   # "FEAT-Y@SLICE-Y-Z"
      up_design = READ_IF_EXISTS("docs/spec/{feat_id}/design.md")
      up_spec   = READ_IF_EXISTS("docs/spec/{feat_id}/spec.feature")
      IF up_spec IS NULL:
        # fail-mode 4 — referenced feature absent → WARN (mirror consumes_contract severity)
        YIELD { check: "slice_seam_resolution", severity: WARNING,
                source: "{s.id}.depends_on_feature='{dep}'",
                gap: "Referenced feature {feat_id} does not exist yet",
                remediation: "Create {feat_id} first, or drop the cross-feature dependency" }
        CONTINUE
      IF up_spec.frontmatter.slicing_strategy == "monolithic":
        # fail-mode 3 — monolithic upstream IS one vertical slice by definition → resolve to implicit SLICE-{feat}-1/INC-1 → PASS
        CONTINUE
      up_slice_map = READ_IF_EXISTS("docs/spec/{feat_id}/slice_map.md")
      IF up_slice_map IS NULL OR up_slice_map.frontmatter.status != "APPROVED" OR slice_ref NOT IN PARSE_SLICES(up_slice_map).ids:
        # fail-mode 2 — feature exists but slice_map absent/non-APPROVED OR slice missing → BLOCK
        YIELD { check: "slice_seam_resolution", severity: CRITICAL,
                source: "{s.id}.depends_on_feature='{dep}'",
                gap: "Upstream {feat_id} slice '{slice_ref}' is not resolvable (slice_map absent/non-APPROVED or slice missing)",
                remediation: "Wait for {feat_id} CODESIGN approval, or correct the @SLICE reference" }
        CONTINUE
      # fail-mode 1 — exists + slice_map APPROVED + slice present → PASS (also require design APPROVED)
      IF up_design IS NULL OR up_design.frontmatter.status NOT IN ["APPROVED", "IMPLEMENTED_AND_VERIFIED"]:
        YIELD { check: "slice_seam_resolution", severity: CRITICAL,
                source: "{s.id}.depends_on_feature='{dep}'",
                gap: "Upstream {feat_id} design is not APPROVED — cannot bind a cross-feature seam to an unfrozen contract",
                remediation: "Complete BLUEPRINT --approve {feat_id} first" }

    # every declared dependency must have a seam
    has_dep = (s.depends_on_slice NOT EMPTY) OR (s.depends_on_feature NOT EMPTY)
    IF has_dep AND s.seam IS NULL:
      YIELD { check: "slice_seam_resolution", severity: CRITICAL,
              source: "{s.id}",
              gap: "Slice declares a dependency but no seam (where the dep is consumed)",
              remediation: "Add seam { at, resolves } so review can confirm the ordering is real" }

  # DAG over depends_on_slice (reuse Check 13 Kahn)
  cycle = DETECT_CYCLE_BY_TOPOLOGICAL_SORT(slices, edge=depends_on_slice)
  IF cycle IS NOT NULL:
    YIELD { check: "slice_seam_resolution", severity: CRITICAL,
            source: "slice_map.md § 1 (depends_on_slice edges)",
            gap: "Cyclic slice dependency: {cycle.path}",
            remediation: "Break the cycle — slice ordering must be acyclic" }

  IF no_gaps_yielded:
    YIELD { check: "slice_seam_resolution", severity: PASS,
            source: "slice_map.md", target: "all slice deps resolve; DAG acyclic; seams present" }
```

### Check 20: `slice_immutability_consistency` (CRITICAL — EVOL-036)

The per-scenario freeze partition (factory-iteration-model § Slice Freeze Derivation) must be well-formed: no scenario is both MERGED-frozen and re-assigned, and no MERGED increment is orphaned by a slice_map edit. Does NOT compare a scalar status (none exists). **Vacuous when zero realizing increments** (pre-BLUEPRINT bootstrap). Delegates transition-legality to `immutability_policy.check_slice_immutability()`.

```yaml
FUNCTION check_slice_immutability_consistency(elements):
  slices = elements.slices
  increments = elements.increments
  IF slices IS EMPTY: 
    YIELD { check: "slice_immutability_consistency", severity: PASS, note: "no slice_map — not applicable" }
    RETURN
  IF increments IS EMPTY:
    # pre-BLUEPRINT bootstrap — empty realizer partition is vacuously consistent
    YIELD { check: "slice_immutability_consistency", severity: PASS, note: "zero realizing increments — partition vacuously consistent" }
    RETURN

  slice_ids = { s.id FOR s IN slices }

  # (1) No MERGED increment orphaned: its parent slice still exists and still owns its scenarios (Check 18(c) cross-link).
  FOR EACH inc IN increments WHERE inc.status == "MERGED":
    parent = inc.cascade_source
    IF parent NOT IN slice_ids:
      YIELD { check: "slice_immutability_consistency", severity: CRITICAL,
              source: "{inc.id} (MERGED)",
              gap: "MERGED increment orphaned — its slice '{parent}' no longer exists in slice_map.md (a re-slice deleted a frozen slice)",
              remediation: "MERGED scenarios are frozen wherever they sit. Restore the slice or use CODESIGN --revise (new feature version)." }
    ELSE:
      slice = FIND(slices, id == parent)
      missing = SET(inc.scenarios_covered) - SET(slice.scenarios_covered)
      IF missing NOT EMPTY:
        YIELD { check: "slice_immutability_consistency", severity: CRITICAL,
                source: "{inc.id} (MERGED) → {parent}",
                gap: "Re-slice moved MERGED scenario(s) {missing} out of their owning slice",
                remediation: "A MERGED scenario is frozen in place — revert the re-slice, add a follow-up slice, or CODESIGN --revise" }

  # (2) Partition well-formedness: a scenario frozen by a MERGED realizer must not also be claimed by a different slice.
  merged_scenarios = UNION(increments WHERE status==MERGED → scenarios_covered)
  FOR EACH sc IN merged_scenarios:
    owning_slices = FILTER(slices, sc IN s.scenarios_covered)
    IF owning_slices.length > 1:
      YIELD { check: "slice_immutability_consistency", severity: CRITICAL,
              source: "scenario '{sc}'",
              gap: "MERGED-frozen scenario assigned to multiple slices: {owning_slices.ids}",
              remediation: "A frozen scenario belongs to exactly one slice — resolve the duplicate" }

  # (3) Acyclicity: the cascade must not have written back to slice_map (no cascade_source edge slice→slice).
  #     CASCADE_SLICE_INTERNAL writes DOWNWARD only (increment_plan); the MERGED back-constraint is the
  #     pre-persist gate, not a cascade write. Delegate transition-legality to immutability_policy.
  #     (Structural assertion — no slice frontmatter should carry an increment-sourced cascade edge.)

  IF no_gaps_yielded:
    YIELD { check: "slice_immutability_consistency", severity: PASS,
            source: "slice_map.md × increment_plan.md",
            target: "freeze partition well-formed; no MERGED increment orphaned; {merged_scenarios.length} frozen scenario(s)" }
```

---

## ELEMENT EXTRACTION

```yaml
FUNCTION extract_traceable_elements(artifacts, scope):
  elements = {}

  # From spec.feature
  elements.spec_scenarios = PARSE_GHERKIN_SCENARIOS(artifacts.spec_feature)
  # Each scenario: {name, steps: [{keyword, text}], tags: []}

  # From user_journey.md
  elements.user_journey_schemas = PARSE_DATA_SCHEMAS_SECTION(artifacts.user_journey)
  # Each schema: {entity, fields: [{name, type, constraints}]}
  elements.user_journey_steps = PARSE_JOURNEY_STEPS(artifacts.user_journey)
  # Each step: {step_id, action, system_interaction, ui_state}

  # From mock.html
  elements.mock_components = PARSE_INTERACTIVE_COMPONENTS(artifacts.mock_html)
  # Each component: {tag, role, data_attributes, journey_step_ref}

  # From design.md
  elements.design_components = PARSE_COMPONENT_ARCHITECTURE(artifacts.design_md)
  # Each: {name, type, module, responsibility, interfaces}
  elements.design_data_model = PARSE_DATA_MODEL(artifacts.design_md)
  # Each entity: {entity, fields: [{name, type, nullable, pk, fk_ref}]}
  elements.design_ui_inventory = PARSE_UI_COMPONENT_INVENTORY(artifacts.design_md)
  # Each: {name, type, props, events, page}

  # From contract files (source-of-truth under contracts/**, referenced by design.md)
  contract_files = RESOLVE_CONTRACT_FILES_REFERENCED_IN_DESIGN(artifacts.design_md, "contracts/")
  elements.contract_endpoints = PARSE_CONTRACT_ENDPOINTS(contract_files)
  # Each: {method, path, operation_id, contract_slug, request_schema, response_schema}

  # From test_plan.md
  elements.test_plan_cases = PARSE_TEST_CASES(artifacts.test_plan)
  # Each: {id, scenario_ref, type, description, priority}

  # From increment_plan.md (may be NULL on pre-slicing legacy features)
  IF artifacts.increment_plan IS NOT NULL:
    elements.increment_plan = artifacts.increment_plan   # keep the raw artefact for frontmatter-level checks
    elements.increments = PARSE_INCREMENTS(artifacts.increment_plan)
    # Each increment: {
    #   id,                     # e.g. "INC-1", "INC-2"
    #   status,                 # DRAFT | READY | BUILDING | MERGED | INVALIDATED
    #   scope_description,      # free-text "- **Scope:**" line
    #   scenarios_covered,      # list of scenario names referenced (must match spec.feature)
    #   contract_surface,       # list of canonical contract op ids
    #   depends_on,             # list of other increment IDs
    #   deployable,             # must be "production" under strict policy
    #   functional_definition,  # free-text "- **Functional definition:**"
    #   acceptance_checklist,   # list of {checked: bool, description: str}
    #   branch,                 # "feature/{FEATURE_ID}-inc-N-{slug}"
    #   merged_at,              # ISO timestamp or null — set by merge hook
    #   layer_tasks             # list of [INC-N.A.M]/[INC-N.B.M]/[INC-N.C.M] task ids declared here (mirror of dev_plan tags)
    # }
  ELSE:
    elements.increment_plan = NULL
    elements.increments = []

  # From slice_map.md (EVOL-036 — may be NULL on monolithic / pre-slicing features)
  IF artifacts.slice_map IS NOT NULL:
    elements.slice_map = artifacts.slice_map   # raw artefact for frontmatter-level checks (Check 0d)
    elements.slices = PARSE_SLICES(artifacts.slice_map)
    # Each slice: {
    #   id,                     # "SLICE-{FEAT}-1"
    #   value_order,            # int
    #   scenarios_covered,      # list of scenario names (must match spec.feature; exclusive across slices)
    #   journey_steps,          # list of journey step refs
    #   depends_on_slice,       # list of SLICE-{FEAT}-X (intra-feature ordering DAG)
    #   depends_on_feature,     # list of "FEAT-Y@SLICE-Y-Z" (cross-feature)
    #   seam,                   # { at, resolves } or null
    #   realized_by             # list of INC ids (back-ref filled by BLUEPRINT)
    # }
  ELSE:
    elements.slice_map = NULL
    elements.slices = []

  # IMPLEMENT scope additions
  IF scope IN [CODESIGN_BLUEPRINT_IMPLEMENT, FULL_CHAIN]:
    elements.dev_plan_tasks = PARSE_DEV_PLAN_TASKS(artifacts.dev_plan)
    # Each: {id, description, phase, checkbox_status, dependencies}
    # For incremental slicing, id prefix encodes ownership: "[INC-{N}.{layer}.{M}]" where layer ∈ {A,B,C}

  # QA scope additions
  IF scope == FULL_CHAIN AND artifacts.qa_report IS NOT NULL:
    elements.qa_checklist = PARSE_QA_CHECKLIST(artifacts.qa_report)
    # Each: {id, description, checked}

  RETURN elements
```

---

## COHERENCE MATRIX OUTPUT

After CVP execution, a summary matrix is available (not persisted as a separate file — embedded in the invoking agent's output artifact):

```yaml
FUNCTION build_coherence_matrix(results, elements, scope):
  matrix = {
    timestamp: NOW(),
    scope: scope,
    summary: {
      total_checks: results.length,
      passed: FILTER(results, severity == PASS).length,
      warnings: FILTER(results, severity == WARNING).length,
      critical: FILTER(results, severity == CRITICAL).length
    },
    traces: []  # Successful source→target mappings
    gaps: []    # Failed checks with remediation
  }

  FOR EACH result IN results:
    IF result.severity == PASS:
      matrix.traces.push({ source: result.source, target: result.target, check: result.check })
    ELSE:
      matrix.gaps.push({ source: result.source, gap: result.gap, severity: result.severity,
                          check: result.check, remediation: result.remediation })

  RETURN matrix
```

### Matrix Embedding Points

The coherence matrix summary is embedded (not as a separate file) within the invoking agent's artifact:

| Agent | Artifact | Section |
|-------|----------|---------|
| BLUEPRINT | `design.md` | Appended as `## Coherence Validation` before approval stamp |
| IMPLEMENT | `dev_plan.md` | Appended as `## Upstream Coherence Validation` after prerequisites |
| QA | `qa_report_final_{ts}.md` | Added as `[QA-CVP-1]` checklist group before test execution |

---

## REMEDIATION ACTIONS

```yaml
FUNCTION remediation_actions(gaps, invoking_agent):
  # Group gaps by responsible agent based on originating artifact (source field)
  codesign_gaps = FILTER(gaps, source STARTS_WITH "spec.feature" OR source STARTS_WITH "user_journey.md")
  blueprint_gaps = FILTER(gaps, source STARTS_WITH "design.md" OR source STARTS_WITH "test_plan.md")
  implement_gaps = FILTER(gaps, source STARTS_WITH "dev_plan.md")

  actions = []

  IF invoking_agent == "BLUEPRINT":
    # BLUEPRINT can self-fix blueprint gaps, but codesign gaps require upstream
    IF codesign_gaps.length > 0:
      actions.push("CODESIGN --refine {ID} to address {codesign_gaps.length} spec gap(s)")
    IF blueprint_gaps.length > 0:
      actions.push("Fix {blueprint_gaps.length} gap(s) in current BLUEPRINT --approve cycle")

  IF invoking_agent == "IMPLEMENT":
    IF codesign_gaps.length > 0 OR blueprint_gaps.length > 0:
      actions.push("BLUEPRINT --refine {ID} to address upstream gap(s) first")
    IF implement_gaps.length > 0:
      actions.push("Adjust dev_plan.md to cover {implement_gaps.length} missing task(s)")

  IF invoking_agent == "QA":
    IF codesign_gaps.length > 0 OR blueprint_gaps.length > 0 OR implement_gaps.length > 0:
      actions.push("⚠️ Upstream gaps detected in verified feature — escalate to Factory")

  RETURN actions
```

---

## SEMANTIC MATCHING STRATEGY

CVP uses semantic matching (not exact string comparison) to relate elements across artifacts:

```yaml
FUNCTION SEMANTICALLY_RELATES_TO(source_text, target_text):
  # Strategy 1: Direct keyword overlap
  source_tokens = TOKENIZE(NORMALIZE(source_text))
  target_tokens = TOKENIZE(NORMALIZE(target_text))
  overlap = INTERSECTION(source_tokens, target_tokens)
  IF overlap.length / source_tokens.length >= 0.5:
    RETURN TRUE

  # Strategy 2: Domain concept matching
  source_concepts = EXTRACT_DOMAIN_CONCEPTS(source_text)
  target_concepts = EXTRACT_DOMAIN_CONCEPTS(target_text)
  IF INTERSECTION(source_concepts, target_concepts).length > 0:
    RETURN TRUE

  # Strategy 3: Camel/snake case decomposition
  source_parts = DECOMPOSE_IDENTIFIER(source_text)  # "UserProfile" → ["user", "profile"]
  target_parts = DECOMPOSE_IDENTIFIER(target_text)
  IF INTERSECTION(source_parts, target_parts).length >= 2:
    RETURN TRUE

  RETURN FALSE
```

---

## INVOCATION MODES

CVP supports three invocation modes — each determines **when** CVP fires and **who** triggers it:

```yaml
CVP_INVOCATION_MODES:

  # Mode 1: GATE (existing — embedded in agent commands)
  GATE:
    trigger: Hardcoded call sites within specific agent commands
    who_executes: The agent running the command (BLUEPRINT, IMPLEMENT, QA)
    scope: Declared explicitly by the call site
    blocking: YES — CRITICAL gaps block the command
    call_sites:
      - BLUEPRINT --approve → Phase 3.8 → CODESIGN_BLUEPRINT
      - IMPLEMENT --plan → Step 0.5 → CODESIGN_BLUEPRINT_IMPLEMENT
      - QA --verify → Pre-Verification Gate → FULL_CHAIN

  # Mode 2: AUTO (post-command — Factory-triggered)
  AUTO:
    trigger: Factory POST-COMMAND protocol, after any agent command that modifies
             artifacts under docs/spec/{ID}/
    who_executes: Factory delegates to the RETURNING agent (or next downstream agent)
    scope: Auto-detected via cvp_auto_scope()
    blocking: NO — AUTO mode is ADVISORY (warnings only, never blocks)
    purpose: Continuous coherence monitoring. Catches drift introduced by --refine,
             --build, or any artifact-modifying command BETWEEN the GATE checkpoints.
    skip_conditions:
      - Command just executed a GATE-mode CVP (avoid double-run)
      - Command is READ_ONLY or SCM_OPERATION (no artifacts modified)
      - No spec.feature exists yet for the feature (pre-CODESIGN)
    output: Brief coherence summary in Factory Return Briefing (not persisted in artifacts)

  # Mode 3: ON_DEMAND (user-requested)
  ON_DEMAND:
    trigger: User asks for coherence verification via natural language
    who_executes: Factory routes to the most advanced agent for the feature's current state
    scope: Auto-detected via cvp_auto_scope()
    blocking: NO — ON_DEMAND is DIAGNOSTIC (full report, no blocking)
    intents:
      - "verify coherence for {ID}"
      - "check consistency of {ID}"
      - "validate artifacts for {ID}"
      - "are the specs coherent for {ID}?"
      - "coherence report for {ID}"
    output: Full coherence matrix displayed to user. Not embedded in artifacts.
    agent_routing:
      # Route to the most downstream agent that has artifacts
      IF dev_plan.md exists → IMPLEMENT (can read all upstream)
      ELIF design.md exists → BLUEPRINT (can read CODESIGN + own artifacts)
      ELSE → CODESIGN (only CODESIGN artifacts exist)
```

### Auto-Scope Detection

```yaml
FUNCTION cvp_auto_scope(FEATURE_ID):
  # Determines the appropriate CVP scope based on which artifacts exist.
  # Used by AUTO and ON_DEMAND modes (GATE mode declares scope explicitly).

  base_path = "docs/spec/{FEATURE_ID}"

  has_spec = FILE_EXISTS("{base_path}/spec.feature")
  has_design = FILE_EXISTS("{base_path}/design.md")
  has_dev_plan = FILE_EXISTS("{base_path}/dev_plan.md")
  has_qa_report = GLOB_EXISTS("{base_path}/qa/qa_report_final_*.md")

  IF NOT has_spec:
    RETURN NULL  # No CODESIGN artifacts — CVP not applicable

  IF has_qa_report OR (has_dev_plan AND READ_FRONTMATTER("{base_path}/dev_plan.md", "status") == "IMPLEMENTED_AND_VERIFIED"):
    RETURN FULL_CHAIN

  IF has_dev_plan:
    RETURN CODESIGN_BLUEPRINT_IMPLEMENT

  IF has_design:
    RETURN CODESIGN_BLUEPRINT

  RETURN NULL  # Only spec.feature — need at least design.md for cross-artifact checks
```

### Factory AUTO-Mode Integration

```yaml
# Executed by Factory POST-COMMAND: after worklog, before commit prompt + Smart Redirect.

FUNCTION cvp_post_command_auto(FEATURE_ID, completed_command, returning_agent):

  # Skip conditions
  IF FEATURE_ID IS NULL:
    RETURN  # No feature context (e.g., SETUP, AUDIT, BACKLOG)

  IF completed_command IN CVP_GATE_COMMANDS:
    RETURN  # GATE-mode CVP already ran during this command
    # CVP_GATE_COMMANDS = ["BLUEPRINT --approve", "IMPLEMENT --plan", "QA --verify"]

  IF NOT FILE_EXISTS("docs/spec/{FEATURE_ID}/spec.feature"):
    RETURN  # Pre-CODESIGN — nothing to validate

  # Auto-detect scope
  scope = cvp_auto_scope(FEATURE_ID)
  IF scope IS NULL:
    RETURN  # Insufficient artifacts for cross-validation

  # Execute CVP in advisory mode
  # Factory DELEGATES to returning_agent (respects Identity Anchor)
  result = DELEGATE_TO(returning_agent):
    cvp_coherence_gate(FEATURE_ID, scope, returning_agent)

  # Format advisory output (non-blocking)
  IF result.passed:
    APPEND TO Return Briefing: "✅ CVP coherence: {result.matrix.summary.passed}/{result.matrix.summary.total_checks} checks passed"
  ELSE:
    warnings = result.matrix.summary.warnings
    critical = result.matrix.summary.critical
    APPEND TO Return Briefing: "⚠️ CVP coherence: {critical} critical, {warnings} warning(s) — run `verify coherence for {FEATURE_ID}` for full report"

  # AUTO mode NEVER blocks. It surfaces issues for user awareness.
```

---

## INTEGRATION POINTS (Quick Reference)

### GATE Mode (Blocking — embedded in agent commands)

| Agent | Command | CVP Call Site | Scope |
|-------|---------|---------------|-------|
| BLUEPRINT | `--approve {ID}` | Phase 3.8 (after 3.7, before approval stamp) | `CODESIGN_BLUEPRINT` |
| IMPLEMENT | `--plan {ID}` | Step 0.5 (after prerequisites, before task decomposition) | `CODESIGN_BLUEPRINT_IMPLEMENT` |
| QA | `--verify {ID}` | Pre-Verification Gate (after iteration detection, before checklist generation) | `FULL_CHAIN` |

### AUTO Mode (Advisory — Factory post-command)

| Trigger | Location | Scope |
|---------|----------|-------|
| Any artifact-modifying command returns to Factory | CLAUDE.md POST-ACTION protocol | Auto-detected via `cvp_auto_scope()` |

### ON_DEMAND Mode (Diagnostic — user-requested)

| Trigger | IOP Category | Scope |
|---------|-------------|-------|
| User asks "verify coherence for {ID}" | `FRAMEWORK_COMMAND` | Auto-detected via `cvp_auto_scope()` |

---

## PERFORMANCE NOTES

- CVP reads artifact **bodies** (past frontmatter) — this is by design, as semantic coherence requires content analysis
- For large features with many scenarios/endpoints, CVP may consume significant context — agents should load artifacts incrementally (read sections, not full files) where possible
- CVP does NOT persist a separate `coherence_matrix.md` file — results are embedded in the invoking agent's artifact to avoid artifact proliferation
