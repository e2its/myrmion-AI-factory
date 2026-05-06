---
description: "Factory BLUEPRINT approval validation — design review, test plan review, CIP artifact re-check gate. Use when: BLUEPRINT --approve execution."
applicable_when:
  phase: [BLUEPRINT]
  command: [blueprint]
---

# BLUEPRINT Agent — Validation, Commands & Cross-Agent Workflows

## Purpose
This instruction file defines the **Phase 3 Governance Validation**, remaining commands (`--refine`, `--approve`, `--adr`, `--review-conflict`), templates, and cross-agent workflows for the BLUEPRINT agent (🏗️ ARCH Hat + 🧪 QA Hat).

---

## Phase 3: Governance Validation (MANDATORY before --approve)

### 3.1 Contract Validation + Spectral Lint
- Validate ALL generated contract files against their format spec:
  - OpenAPI 3.1: valid YAML, required `openapi`, `info`, `paths` fields
  - GraphQL SDL: valid schema syntax, all types resolved
  - AsyncAPI 2.6+: valid channels, messages, schemas
  - gRPC Proto3: valid syntax, package declaration
- If `scripts/lint-contracts.sh` exists: run Spectral linting
- BLOCK if any contract is invalid

### 3.2 Cross-Feature Endpoint Collision Detection
Two types of collision:
- **Slug collision**: Same CONTRACT_SLUG used by different features
- **Endpoint collision**: Different slugs but overlapping paths

```yaml
FOR EACH new_endpoint IN generated_contracts:
  FOR EACH existing_endpoint IN contracts/**/*:
    IF same_slug AND different_feature:
      COLLISION: "Slug '{{slug}}' already used by {{existing_feature}}"
    
    IF paths_match(new_endpoint.path, existing_endpoint.path) AND same_method:
      COLLISION: "Path '{{path}}' {{method}} conflicts with {{existing_slug}}"

paths_match(pathA, pathB):
  # Normalize path params: /users/{id} == /users/{userId}
  # Compare segments: exact match OR both are params
  RETURN normalized_pathA == normalized_pathB
```

### 3.3 UX Constitution Validation
- If `.claude/rules/ux-constitution.md` exists:
  - Verify design.md component architecture references style_guide tokens
  - Verify mock-referenced components exist in vision component_library
  - Verify navigation integration with navigation_map.md

### 3.4 System Resources Validation
- If `config/system_resources.json` exists:
  - Verify all external integrations in design.md Section 5 are registered
  - Verify integration protocols match system_resources entries

### 3.5 Protected Code Compliance
- If `config/protected-paths.json` exists:
  - Verify design.md does NOT plan modifications to RED ZONE paths
  - If modifications needed: trigger RED ZONE Modification Protocol

### 3.6 Test Coverage Validation
- Verify every spec.feature scenario has ≥1 test case in test_plan.md
- Verify every contract endpoint has ≥1 integration test (TC-API-XX)
- Verify WCAG accessibility tests exist for UI features
- BLOCK if coverage gaps found

### 3.7 Inter-Domain Contract Completeness
- Read design.md Section 4 (Cross-Domain Dependencies)
- Verify ALL dependencies with status "MISSING" have been resolved
- If any dependency has status "PENDING": WARN (not blocking, but flag)
- BLOCK if any dependency has no contract reference AND no ADR justifying it

### 3.8 Coherence Validation (CVP — BLOCKING)

Cross-artifact coherence validation between CODESIGN and BLUEPRINT deliverables. See `.claude/skills/Factory-coherence-validation/SKILL.md` for full protocol.

```yaml
FUNCTION blueprint_coherence_gate(FEATURE_ID):
  # Invoke CVP with CODESIGN_BLUEPRINT scope
  # Validates: spec.feature ↔ design.md, user_journey.md ↔ data model,
  #            mock.html ↔ Component Inventory, journey steps ↔ endpoints,
  #            scenarios ↔ test_plan.md, endpoints ↔ integration tests

  cvp_result = cvp_coherence_gate(FEATURE_ID, "CODESIGN_BLUEPRINT", "BLUEPRINT")

  IF NOT cvp_result.passed:
    ❌ BLOCK: "Coherence validation failed — upstream artifacts are inconsistent"
    # CVP gate already showed detailed gap report and remediation actions
    STOP

  # Embed coherence matrix summary in design.md → ## Coherence Validation section
  APPEND_SECTION(design.md, "## Coherence Validation", cvp_result.matrix.summary)
  LOG: "CVP: {cvp_result.matrix.summary.passed}/{cvp_result.matrix.summary.total_checks} checks passed"
```

---

## Command: `--refine {{ID}} "{{FEEDBACK}}"`

### Refine Execution Sequence
```yaml
# Step 1: Classify feedback → affects design only, tests only, or both
# Step 2: Immutability Guard — check test_plan.md frozen sections
# Step 3: Compute refine_changes (diff of new vs existing artifacts)
# Step 4: CIP Artifact Re-Check (CONDITIONAL — if new artifacts detected):
#         CALL cip_refine_artifact_recheck(refine_changes, FEATURE_ID)
# Step 5: Endpoint Rescan Gate (if new endpoints)
# Step 6: Apply changes (ARCH hat for design.md, QA hat for test_plan.md)
# Step 7: Changelog append + CASCADE_PENDING_ITERATION
```

### Feedback Integration
- Classify feedback: affects design only, tests only, or both
- Route to appropriate hat(s) for processing

### Immutability Guard for test_plan.md
- If test_plan.md has sections marked as frozen: do NOT modify them
- Only add/modify non-frozen sections

### CIP Artifact Re-Check Gate (CONDITIONAL — runs when refine introduces NEW artifacts)

```yaml
FUNCTION cip_refine_artifact_recheck(refine_changes, FEATURE_ID):
  # This gate fires when --refine introduces NEW technical artifacts
  # (new services, repositories, controllers, UI components) — not when
  # modifying existing ones. Prevents DRY violations when iterations
  # expand the component inventory significantly.

  new_artifacts = FILTER(refine_changes, action == "new_artifact")
  # new_artifacts = services, entities, components NOT in current design.md Component Inventory

  IF new_artifacts.length == 0:
    ✅ SKIP — refine only modifies existing artifacts
    RETURN

  inventory = READ("config/codebase_inventory.json")
  IF inventory IS MISSING:
    materialization = READ("docs/setup.md").materialization_complete
    IF materialization == true:
      ❌ BLOCK: "CIP inventory missing — cannot introduce NEW artifacts after materialization. Run: SETUP --reconcile-inventory"
      LOG: "CIP_BLOCKED on --refine (inventory missing post-materialization; new artifacts detected)"
      STOP
    ELSE:
      ⚠️ WARN: "CIP inventory missing pre-materialization — new artifacts unchecked."
      LOG: "CIP_SKIPPED on --refine (inventory missing pre-materialization)"
      RETURN  # Degraded — pre-materialization only

  topology = READ(constitution.md, "architecture.topology")
  overlaps = 0
  FOR EACH artifact IN new_artifacts:
    reuse_category = classify_artifact_reuse_category(artifact.type, artifact.module, topology)
    candidates = find_inventory_matches(artifact, topology, reuse_category)
    # reuse_category constrains candidate scope: SHARED → cross-module, MODULE_LOCAL → same module only
    IF candidates.EXACT_MATCH.length > 0:
      ❌ BLOCK: "EXACT MATCH: '{candidates[0].name}' at '{candidates[0].path}' (category: {reuse_category})"
      RDR: REUSE / EXTEND / CREATE_NEW (justification required)
      overlaps += candidates.EXACT_MATCH.length
    IF candidates.SAME_DOMAIN.length > 0:
      ⚠️ WARN: "Similar artifact '{candidates[0].name}' in same domain (category: {reuse_category})"
      RDR: REUSE / EXTEND / CREATE_NEW
      overlaps += candidates.SAME_DOMAIN.length

  LOG: "CIP Refine Re-Check: {new_artifacts.length} new artifacts checked, {overlaps} overlaps resolved"
```

### Existing Endpoint Inventory Re-Scan Gate (BLOCKING — H-13)
```yaml
FUNCTION endpoint_rescan_gate(refine_changes, FEATURE_ID):
  # This gate MUST execute if --refine proposes ANY new endpoints.
  # Prevents creating endpoints that collide with other features.

  new_endpoints = FILTER(refine_changes, type == "new_endpoint")
  IF new_endpoints.length == 0:
    ✅ SKIP — no new endpoints proposed
    RETURN

  # Re-execute Step -1 from Phase 2 (Existing Endpoint Inventory)
  FOR EACH endpoint IN new_endpoints:
    collisions = SCAN_ALL_CONTRACTS(endpoint.path, endpoint.method)
    IF collisions.length > 0:
      ❌ BLOCK: "Endpoint collision detected: {endpoint.method} {endpoint.path}"
      SHOW: "Already exists in: {collisions[0].feature_id} ({collisions[0].contract_slug})"
      RDR: "Rename endpoint? Reuse existing? Create ADR for intentional overlap?"
      STOP

  ✅ No endpoint collisions — proceed with refine
```

### Re-Evaluation
- **Architecture-only**: 🏗️ ARCH updates design.md sections, re-validates contracts
- **Testing-only**: 🧪 QA updates test_plan.md, re-validates coverage
- **Mixed**: Both hats update their respective artifacts

### Traceability Update (10-Step Governance Update Protocol)
1. Read current design.md + test_plan.md frontmatter
2. Identify affected sections from feedback
3. Update affected sections only
4. Regenerate contract files if API changes
5. Update feature_map.md if contract slugs changed
6. Re-validate Phase 3 governance checks
7. Update Cross-Layer Type Mapping Table if schema changes
8. Update Infrastructure Needs if resource changes
9. Increment update counter in frontmatter
10. Save all modified artifacts atomically

### Iteration Changelog Gate (BLOCKING — M-03)
```yaml
FUNCTION verify_changelog_appended(design_md_path, refine_changes):
  # This gate MUST execute AFTER refine modifications and BEFORE Completion Summary.
  # --refine CANNOT complete without a changelog entry.

  changelog_section = READ(design_md_path, "## Changelog")
  IF changelog_section IS NULL:
    ❌ BLOCK: "design.md has no ## Changelog section — creating one"
    APPEND "## Changelog" section to design_md_path

  latest_entry = LAST_ROW(changelog_section)
  today = DATE_NOW()

  IF latest_entry IS NULL OR latest_entry.date != today:
    ❌ BLOCK: "No changelog entry for today's --refine"
    GENERATE changelog_entry FROM refine_changes
    APPEND changelog_entry to design_md_path changelog table
    LOG: "Changelog auto-appended for --refine"

  ✅ Changelog entry verified
```

### Iteration Changelog Format (MANDATORY in design.md)

Every `--refine` MUST append a changelog entry to `design.md`:

```markdown
## Changelog

| Date | Iteration | Source | Changes | Downstream Impact |
|------|-----------|--------|---------|-------------------|
| {ISO_DATE} | {N-1} → {N} | {spec iteration sync / user feedback / conflict resolution} | {list of modified sections, updated contracts} | {dev_plan CASCADE_PENDING, devops_plan CASCADE_PENDING, QA INVALIDATED} |
```

This changelog serves as:
- **Traceability:** What changed in the blueprint and why
- **Reference for IMPLEMENT:** Which delta tasks to generate in dev_plan.md
- **Reference for DEVOPS:** Which infrastructure may need re-planning

### Downstream Cascade Invalidation (v1.0.0)
After refine completes, execute `CASCADE_PENDING_ITERATION()`:
- Push `pending_iteration` to `dev_plan.md` (if exists)
- Push `pending_iteration` to `devops_plan.md` (if infrastructure affected)
- Push invalidation to QA reports (mark as INVALIDATED if APPROVED)
- Populate `invalidated_sections`, `cascade_source`, `cascade_timestamp`, `cascade_scope`

```yaml
FUNCTION CASCADE_PENDING_ITERATION(FEATURE_ID, new_iteration, affected_sections):
  base_path = "docs/spec/{FEATURE_ID}"
  
  # Always cascade to dev_plan.md
  IF FILE_EXISTS("{base_path}/dev_plan.md"):
    UPDATE_FRONTMATTER("{base_path}/dev_plan.md"):
      pending_iteration: {new_iteration}
      invalidated_sections: {affected_sections}
      cascade_source: "BLUEPRINT --refine"
      cascade_timestamp: "{ISO_8601}"
      cascade_scope: "design iteration sync"
  
  # Cascade to devops_plan.md only if infrastructure affected
  IF affected_sections CONTAINS "infrastructure" AND FILE_EXISTS("{base_path}/devops_plan.md"):
    UPDATE_FRONTMATTER("{base_path}/devops_plan.md"):
      pending_iteration: {new_iteration}
      cascade_source: "BLUEPRINT --refine"
      cascade_timestamp: "{ISO_8601}"
  
  # Invalidate QA reports
  FOR EACH qa_report IN GLOB("{base_path}/qa/qa_report_final_*.md"):
    IF READ_FRONTMATTER(qa_report, "status") == "APPROVED":
      UPDATE_FRONTMATTER(qa_report):
        status: INVALIDATED
        invalidated_by: "BLUEPRINT --refine cascade"
        invalidated_at: "{ISO_8601}"
```

- APPEND_TO_WORKLOG:
  ```json
  {"timestamp":"YYYY-MM-DD","phase":"Blueprint","user_agent":"BLUEPRINT","action":"--refine {{FEATURE_ID}}","result":"COMPLETED","feature_id":"{{FEATURE_ID}}","observations":"Affected: {{design|tests|both}} — cascade: {{downstream_artifacts_invalidated}}"}
  ```

---

## Command: `--approve {{ID}}`

### Scope Context Loading (runs FIRST)

```yaml
feature_scope = READ("docs/spec/{ID}/spec.feature").frontmatter.scope OR "full-stack"  # default when legacy artefact
has_ui = feature_scope IN ["full-stack", "frontend-only"]
has_backend_surface = feature_scope IN ["full-stack", "backend-only", "integration"]
consumes_contract = READ("docs/spec/{ID}/spec.feature").frontmatter.consumes_contract OR []
```

The Part 1-4 checks below are gated by these flags. Checks whose applicability matrix excludes the current scope resolve as **N/A** (not pass, not fail — structurally skipped and logged in the worklog as `skipped: scope`).

### 4-Part Validation (scope-aware)

**Part 1: ARCH Design Validation (🏗️ hat)**
- All design.md sections complete (no TODO/TBD)
- Contract files valid (Phase 3.1 passed) — **ELEVATED** when `has_ui == false`: contract completeness is the primary design output for backend-only/integration features; BLOCK if any contract file is missing, incomplete, or declared without `x-feature-id` metadata
- No endpoint collisions (Phase 3.2 passed)
- Cross-Domain Dependencies resolved (Phase 3.7 passed)
- **Consumes-Contract Integrity** — for each upstream `FEAT-XXX` in `spec.feature.consumes_contract`, verify § 7 Governance Constraints Digest contains the frozen contract reference (file path + x-feature-id). BLOCK when `has_ui == false` if any reference is missing (backend-only features are ENTIRELY defined by the contract surface — drift here is invisible to UX QA).
- Cross-Layer Type Mapping Table present and complete — **N/A** for `scope IN [backend-only, integration]`; use § 3.2 Wire-Format Mapping instead
- **Wire-Format Mapping Table (§ 3.2)** — applicable_when `scope IN [backend-only, integration]`; BLOCK if absent on those scopes (replaces § 3.1 Cross-Layer Type Mapping)
- Infrastructure Needs declared (Section 5)
- Extension Strategy documented (if brownfield)

**Part 2: QA Test Plan Validation (🧪 hat)**
- All scenarios covered by test cases
- Edge cases documented
- Security test cases present
- Integration tests reference contract endpoints — **ELEVATED** when `has_ui == false`: every frozen contract endpoint MUST have ≥1 integration test case; coverage gaps BLOCK on backend-only/integration
- **Reliability test cases (test_plan.md § 2.2 Reliability Testing)** — applicable_when `scope IN [backend-only, integration]`; BLOCK if missing idempotency replay, retry-storm, circuit-breaker, or DLQ scenarios. Required entries: idempotency replay verification, retry/backoff validation, circuit breaker trip + half-open probe, dead-letter handling, graceful shutdown drain, structured-log correlation.
- Accessibility tests present (WCAG 2.1 AA) — **applicable_when `has_ui == true`**; N/A for backend-only/integration
- Visual-consistency tests (BRAND-*, LAYOUT-*, UX-*) — **applicable_when `has_ui == true`**; N/A for backend-only/integration (no visual surface to verify)

**Part 3: Cross-Validation (Both hats)**
- Every contract endpoint has ≥1 test case (applies to ALL scopes — universal)
- Every error in design.md has test scenario (applies to ALL scopes — universal)
- Test preconditions match design constraints (applies to ALL scopes — universal)
- No conflicting assumptions between design and test plan (applies to ALL scopes — universal)
- **Scope-consistency** — `spec.feature.scope`, `design.md.scope`, `test_plan.md.scope` (when present) MUST all match. Mismatch BLOCKS with message: "Scope inconsistency between upstream artefacts — re-sync via CODESIGN --refine."

**Part 4: Defect Prevention Catalog Gate (BLOCKING)**

```yaml
feature_scope = READ("docs/spec/{FEATURE_ID}/spec.feature").frontmatter.scope OR "full-stack"   # pass to DPC Filter 2 so --approve evaluates only scope-relevant BLOCKER DCs
applicable_dcs = consult_defect_catalog("BLUEPRINT", {feature_id: FEATURE_ID, feature_scope: feature_scope, stack: setup_md.stack})

FOR EACH dc IN applicable_dcs:
  IF dc.severity == "BLOCKER":
    # Every BLOCKER-severity DC applicable to BLUEPRINT must be explicitly addressed
    IF "DC-{dc.number}" NOT present in design.md § Constraints (or § Section 7 GCD — Defect Prevention Constraints sub-section):
      ❌ BLOCK: "Blueprint missing required DC-{dc.number} ({dc.name}) constraint."
      REDIRECT: "Run BLUEPRINT --refine {FEATURE_ID} to add the missing DC reference to design.md § Constraints."
      STOP
    IF "DC-{dc.number}" NOT present in test_plan.md § Edge Cases:
      ❌ BLOCK: "Test plan missing required DC-{dc.number} ({dc.name}) edge case."
      REDIRECT: "Run BLUEPRINT --refine {FEATURE_ID} to add the missing DC edge case to test_plan.md."
      STOP

# WARNING-severity DCs are projected during --start / --refine (advisory).
# --approve does NOT block on WARNING-severity DCs.
LOG: "DC Gate passed: {blocker_dc_count} BLOCKER DCs explicitly addressed"
```

See `.claude/rules/defect-prevention.md` § Mandatory Process Integration § 2 for the canonical protocol.

### Freezing
- Set `design.md` frontmatter: `status: APPROVED`
- Set `test_plan.md` frontmatter: `status: APPROVED`
- Both artifacts become reference documents for IMPLEMENT

### CIP Codebase Inventory Update Gate (BLOCKING — M-04)
```yaml
FUNCTION cip_update_gate(FEATURE_ID):
  # This gate MUST execute during --approve BEFORE setting status to APPROVED.
  # --approve CANNOT complete if CIP inventory is not updated.

  READ design.md Section 2 (Component Inventory)
  inventory_path = "config/codebase_inventory.json"

  IF NOT FILE_EXISTS(inventory_path):
    ⚠️ WARN: "Codebase inventory not found — creating empty inventory"
    CREATE inventory_path with empty artifacts[]

  planned_count = component_inventory.length
  registered_count = 0

  FOR EACH planned_artifact IN component_inventory:
    existing = FIND(inventory, name == planned_artifact.name AND module == planned_artifact.module)
    IF existing IS NULL:
      APPEND to codebase_inventory.json: {
        name: planned_artifact.name,
        type: planned_artifact.type,
        module: planned_artifact.module,
        path: planned_artifact.projected_path,
        feature_ids: [FEATURE_ID],
        responsibility: planned_artifact.description,
        interfaces: planned_artifact.interfaces,
        status: "PLANNED",
        registered_by: "BLUEPRINT",
        registered_at: NOW()
      }
      registered_count += 1
    ELSE:
      # Update existing entry with this feature_id
      IF FEATURE_ID NOT IN existing.feature_ids:
        existing.feature_ids.push(FEATURE_ID)

  UPDATE codebase_inventory.json last_updated timestamp
  LOG: "CIP Gate: {registered_count}/{planned_count} artifacts registered, {planned_count - registered_count} already existed"

  # Verify the update persisted
  inventory_after = READ(inventory_path)
  FOR EACH planned_artifact IN component_inventory:
    IF NOT FIND(inventory_after, name == planned_artifact.name):
      ❌ BLOCK: "CIP update failed — '{planned_artifact.name}' not found in inventory after update"
      STOP

  ✅ CIP inventory updated — --approve can proceed
```

- APPEND_TO_WORKLOG:
  ```json
  {"timestamp":"YYYY-MM-DD","phase":"Blueprint","user_agent":"BLUEPRINT","action":"--approve {{FEATURE_ID}}","result":"APPROVED","feature_id":"{{FEATURE_ID}}","observations":"design.md + test_plan.md APPROVED — CIP inventory updated — IMPLEMENT now enabled"}
  ```

---

## Command: `--adr {{ID}}`

### Feature Decision Record (FDR) Generation Modes
- **Standalone**: `--fdr {{FEATURE_ID}}` (legacy alias `--adr` accepted during migration) — interactive feature-scoped decision creation
- **Auto-triggered**: During `--start` or `--refine` when significant feature-local architectural decisions are made
- For project-wide constitutional decisions, use the `Factory-adr-management` skill — those amend `docs/constitution.md` and live at `docs/project_log/adr/`

### FDR Numbering
- Sequential: FDR-0001, FDR-0002, ...
- Stored in: `docs/spec/{{FEATURE_ID}}/fdr/FDR-XXXX-*.md` (legacy projects continue to read `docs/spec/{{FEATURE_ID}}/adr/ADR-XXXX-*.md` until migrated)

### ADR Template
```markdown
# ADR-XXXX: [Title]

## Status
PROPOSED | ACCEPTED | DEPRECATED | SUPERSEDED

## Context
[What is the issue that we're seeing that is motivating this decision?]

## Decision
[What is the change that we're proposing and/or doing?]

## Consequences
### Positive
- [List positive consequences]

### Negative
- [List negative consequences]

### Risks
- [List risks and mitigations]

## References
- Feature: {{FEATURE_ID}}
- Spec: docs/spec/{{FEATURE_ID}}/spec.feature
- Design: docs/spec/{{FEATURE_ID}}/design.md
```

### Governance Updates After ADR
- If ADR affects constitution.md: update relevant section
- If ADR adds allowed technology: update `dependency-allowlist.json`
- If ADR modifies protected paths: update `protected-paths.json`

---

## Command: `--review-conflict {{ID}}`

### Trigger
- Escalation after 3 IMPLEMENT rejections for the same section
- IMPLEMENT REVIEW hat cannot resolve disagreement with DEV hat

### Process
1. **Root Cause Analysis**: Read rejection history from IMPLEMENT review artifacts
2. **Identify Conflict**: Is it design issue, implementation misunderstanding, or scope gap?
3. **Binding Decision** (one of):
   - **REDESIGN**: ARCH modifies design.md to accommodate implementation reality
   - **CLARIFY**: ARCH provides additional clarification/examples in design.md
   - **OVERRIDE**: ARCH confirms design is correct, IMPLEMENT must comply (with justification)
4. **ADR**: Document resolution as ADR for traceability
5. **Reset Counter**: Clear IMPLEMENT rejection counter for this section

---

## RED ZONE Modification Protocol

When IMPLEMENT or any agent needs to modify a file in `protected-paths.json` RED ZONE:

### 3-Question Protocol
1. "What exactly needs to change and why?" (gather context)
2. "Can this be achieved WITHOUT modifying the protected file?" (explore alternatives)
3. "What is the blast radius of this change?" (assess impact)

### Decision
- **REJECT** (preferred): Propose extension pattern (adapter, wrapper, plugin)
- **APPROVE** (exceptional): Requires:
  - ADR created via `--adr`
  - `protected-paths.json` updated to document the approved exception
  - Detailed impact assessment in ADR

---

## Output Templates

### Template A: Design Gaps Report
```markdown
## Design Gaps Identified
| # | Gap | Severity | Affected Section | Resolution |
|---|-----|----------|-----------------|------------|
| 1 | ... | HIGH     | Contracts       | ...        |
```

### Template B: Design Document (master template)
- Section 0: Reuse Analysis (CIP decisions)
- Section 1: Architecture Overview (C4 diagrams in Mermaid)
- Section 2: Component Inventory (with types, modules, interfaces)
- Section 3: API Contracts (with cross-references to contract files)
- Section 4: Cross-Domain Dependencies (dependency table)
- Section 5: Infrastructure Needs (resources, integrations, constraints)
- Section 6: Data Model (entities, relationships, Cross-Layer Type Mapping)
- Section 7: Security Architecture (auth, encryption, access control)
- Section 8: Error Handling Strategy (error codes, recovery patterns)

### Template C: ADR Template (see --adr section above)

### Template D: Test Plan Gaps Report
```markdown
## Test Coverage Gaps
| # | Gap | Type | Related Scenario | Priority |
|---|-----|------|-----------------|----------|
| 1 | ... | Edge Case | SC-003 | HIGH |
```

### Template E: Test Plan Document (master template)
- Section 1: Acceptance Tests (per scenario)
- Section 2: Technical Tests (negative, security, performance)
- Section 2.1: API Integration Tests (TC-API-XX per endpoint)
- Section 3: Accessibility Tests (WCAG 2.1 AA)
- Section 4: Test Environment Requirements
- Section 5: Test Data Requirements

### Template F: QA Report Template
- Summary: pass/fail/skip counts
- Per-test: ID, description, status, evidence, notes

---

## Visual Standards

### Mermaid C4 Diagrams
- Use Mermaid syntax for all architecture diagrams
- Context (Level 1): System boundary + external actors + external systems
- Container (Level 2): Internal containers + technology + communication
- Component (Level 3): Internal components per container + interfaces

---

## Cross-Agent Workflows

| Flow | From → To | Trigger | Data |
|------|----------|---------|------|
| 1 | CODESIGN → BLUEPRINT | `--approve` | 3 APPROVED artifacts |
| 2 | BLUEPRINT → IMPLEMENT | `--approve` | design.md + test_plan.md APPROVED |
| 3 | BLUEPRINT → IMPLEMENT | `--review-conflict` | Binding resolution |
| 4 | BLUEPRINT → QA | `--approve` | test_plan.md for verification reference |
| 5 | BLUEPRINT → DEVOPS | `--approve` | design.md Section 5 (Infrastructure Needs) |

---

## Mandatory Laws

1. **Protected Blocks**: NEVER modify code between `PROTECTED-CODE START` and `PROTECTED-CODE END` or paths in `config/protected-paths.json`
2. **Constitutional Supremacy**: The stack in `docs/constitution.md` is LAW
3. **Regulatory Compliance**: Follow styles/guidelines in ALL loaded .claude/rules/ files (BLUEPRINT loads 20+ rules — explicitly listed in agent's Governance Context Loading Step 3)
4. **Contract-First**: API contracts are generated BEFORE implementation. No implementation without contract.
5. **Schema Authority**: user_journey.md Data Schemas are source of truth. Business fields locked — technical fields free.
6. **Incremental Persistence (IPP)**: Follow `.claude/skills/Factory-incremental-persistence/SKILL.md` — skeleton-first write, section-atomic saves, resume-on-entry. See `blueprint-design.md` for BLUEPRINT-specific IPP implementation.
7. **One Question at a Time**: RDR protocol — never batch questions
