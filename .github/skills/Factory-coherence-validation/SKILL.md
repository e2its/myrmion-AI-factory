---
name: Factory-coherence-validation
description: "Factory Coherence Validation Protocol (CVP) — cross-artifact traceability and completeness verification. Ensures upstream deliverables are coherent, complete, and mutually consistent before downstream agents consume them. Use when: BLUEPRINT --approve, IMPLEMENT --plan, or QA --verify need to validate upstream artifact alignment."
---

# COHERENCE VALIDATION PROTOCOL (CVP v1.0.0) — CROSS-ARTIFACT TRACEABILITY

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
      - scenario_to_component        # spec.feature scenarios → design.md components
      - data_schema_to_data_model    # user_journey.md schemas → design.md data model
      - ui_component_to_inventory    # mock.html components → design.md Component Inventory
      - journey_step_to_endpoint     # user_journey.md steps → contract endpoints
      - scenario_to_test_coverage    # spec.feature scenarios → test_plan.md test cases
      - contract_to_test_coverage    # contract endpoints → test_plan.md integration tests

  CODESIGN_BLUEPRINT_IMPLEMENT:
    # Invoked by: IMPLEMENT --plan (Step 0.5)
    # Validates: all of CODESIGN_BLUEPRINT PLUS implementation coverage
    includes: CODESIGN_BLUEPRINT
    checks:
      - contract_to_task             # contract endpoints → dev_plan.md tasks
      - test_case_to_task            # test_plan.md test cases → dev_plan.md test tasks
      - ui_component_to_task         # design.md UI components → dev_plan.md frontend tasks
      - data_model_to_task           # design.md entities → dev_plan.md Phase A tasks

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

  # IMPLEMENT scope additions
  IF scope IN [CODESIGN_BLUEPRINT_IMPLEMENT, FULL_CHAIN]:
    elements.dev_plan_tasks = PARSE_DEV_PLAN_TASKS(artifacts.dev_plan)
    # Each: {id, description, phase, checkbox_status, dependencies}

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
| Any artifact-modifying command returns to Factory | `factory.agent.md` POST-COMMAND protocol | Auto-detected via `cvp_auto_scope()` |

### ON_DEMAND Mode (Diagnostic — user-requested)

| Trigger | IOP Category | Scope |
|---------|-------------|-------|
| User asks "verify coherence for {ID}" | `FRAMEWORK_COMMAND` | Auto-detected via `cvp_auto_scope()` |

---

## PERFORMANCE NOTES

- CVP reads artifact **bodies** (past frontmatter) — this is by design, as semantic coherence requires content analysis
- For large features with many scenarios/endpoints, CVP may consume significant context — agents should load artifacts incrementally (read sections, not full files) where possible
- CVP does NOT persist a separate `coherence_matrix.md` file — results are embedded in the invoking agent's artifact to avoid artifact proliferation
