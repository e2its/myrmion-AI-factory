---
description: "Factory IMPLEMENT peer review and security audit — code review checklist, OWASP checks, Zero Trust validation. Use when: IMPLEMENT review or security audit phase."
---

# IMPLEMENT Agent — REVIEW Hat, SEC Hat, Compliance & Finalization

> Detailed instructions for the REVIEW Hat (14 governance checks), SEC Hat (SAST), Static Mock Compliance, Visual Inspection Gate, and Build Finalization.

## REVIEW Hat Protocol (🔍)

Execute AFTER DEV Hat completes each phase. All 14 checks run per phase, filtered by feature scope.

### Scope Dispatch (runs BEFORE Step R.0)

```yaml
FUNCTION review_scope_dispatch():
  # Read feature scope from the authoritative artefact — spec.feature frontmatter
  feature_scope = READ("docs/spec/{FEATURE_ID}/spec.feature").frontmatter.scope OR "full-stack"
  has_ui             = feature_scope IN ["full-stack", "frontend-only"]
  has_backend_surface = feature_scope IN ["full-stack", "backend-only", "integration"]

  # applicable_when matrix (per check)
  check_applicability = {
    "#1  [ARCH-*]":       ALL scopes,
    "#2  [GOV-*]":        ALL scopes,
    "#2b [GOV-SHARED-*]": ALL scopes,
    "#2c [GOV-SEED-*]":   ALL scopes,
    "#2d [GOV-DC-*]":     ALL scopes (DC catalog is filtered per-DC by feature_scope — see Gap 18),
    "#3  [SEC-*]":        ALL scopes,
    "#4  [PATH-*]":       ALL scopes,
    "#5  [SCHEMA-*]":     ALL scopes,
    "#6  [TYPE-*]":       scope IN [full-stack]   # cross-layer mapping — requires FE + BE present
    "#7  [UX-*]":         scope IN [full-stack, frontend-only]   # all 11 sub-checks gated
    "#8  [MIGRATION-*]":  has_backend_surface     # migrations only apply when a backend + DB is in play
    "#9  [IAC-*]":        ALL scopes (infra may apply to any scope),
    "#10 [CFP-*]":        has_backend_surface     # contract-first-policy only meaningful when backend contracts exist (frontend-only features consume via #10 upstream resolver instead)
    "#11 [EXT-STRATEGY]": ALL scopes (brownfield-gated, orthogonal to scope),
    "#12 [ACL-EXT]":      has_backend_surface     # external system ACL only exists when there IS a service-to-service boundary
    "#13 [POLICY-*]":     ALL scopes,
    "#14 [DESIGN-*]":     ALL scopes,
  }

  # Scope-excluded checks are reported as "N/A (scope={value})" in peer_review report —
  # they are NOT silently skipped; REVIEW records the skip to the report so auditors see the dispatch.
  RETURN { feature_scope, has_ui, has_backend_surface, check_applicability }
```

When a check resolves as **N/A**, the report's § 3.X entry reads: `N/A — skipped under scope={feature_scope}` and contributes zero findings (0 blocker, 0 warning, 0 nitpick). Skipping is not silent — auditors reading the peer_review report see exactly which checks ran and why others did not.

### Step R.0: Governance Context Binding (GCD v2.2.0 — MANDATORY FIRST STEP)
```yaml
# governance_context + gcd_loaded received from Phase Loop caller (implement-build Step 0b).
# Fields available (when gcd_loaded == true):
#   arch_constraints   (7.1) → Check #1 (ARCH)
#   governance_rules   (7.2) → Check #2 (GOV): named rule IDs + compact constraints
#                               Covers: GOV-ARCH, GOV-SEC, GOV-TEST, GOV-API, GOV-DB,
#                               GOV-OBS, GOV-PERF, GOV-PRIV, GOV-STACK, GOV-REVIEW,
#                               GOV-STATE, GOV-IMMUT, GOV-CFP, GOV-IAC, GOV-FRONT, GOV-HTML
#   sast_patterns      (7.3) → SEC Hat: pre-compiled SAST for this stack
#   schema_constraints (7.4) → Check #5 (SCHEMA): locked business fields
#   contract_rules     (7.5) → Check #10 (CFP): contract paths + forbidden imports
#   ux_constraints     (7.6) → Check #7 (UX): vision refs, touch targets
#   coding_standards   (7.7) → DEV Hat: naming, file structure
#   mandatory_patterns (7.8) → Check #14 (DESIGN): architectural patterns + ADR bindings
# When gcd_loaded == false: equivalent data from raw rule files (fallback path).

FUNCTION bind_review_context(governance_context, gcd_loaded):
  IF gcd_loaded:
    # Bind GCD sub-sections to check-specific variables (for readability)
    arch_constraints   = governance_context.arch_constraints     # → Check #1
    gov_rules_index    = governance_context.governance_rules      # → Check #2
    sast_patterns      = governance_context.sast_patterns         # → SEC Hat
    schema_constraints = governance_context.schema_constraints    # → Check #5
    contract_rules     = governance_context.contract_rules        # → Check #10
    ux_constraints     = governance_context.ux_constraints        # → Check #7
    coding_standards   = governance_context.coding_standards      # → DEV Hat
    mandatory_patterns = governance_context.mandatory_patterns    # → Check #14
    LOG: "REVIEW context bound ✅ — 14 checks use GCD constraint IDs (GOV-*/ARCH-*/SAST-*/CFP-*/DESIGN-*)"
  ELSE:
    # Fallback: governance_context has raw rule data from implement-build Step 0b.
    # Bind the equivalent fields so downstream checks use the same interface.
    arch_constraints   = governance_context.arch_constraints     # raw arch rules (e.g., architecture.md)
    gov_rules_index    = governance_context.governance_rules      # raw governance rules index
    sast_patterns      = governance_context.sast_patterns         # stack-specific SAST patterns (fallback-loaded)
    schema_constraints = governance_context.schema_constraints    # raw schema constraints / rule files
    contract_rules     = governance_context.contract_rules        # raw contract rules / forbidden imports
    ux_constraints     = governance_context.ux_constraints        # UX governance from raw vision/rules
    coding_standards   = governance_context.coding_standards      # coding standards from rule files
    mandatory_patterns = governance_context.mandatory_patterns    # arch patterns + ADR bindings
    LOG: "REVIEW context bound (fallback) — checks reference raw rule files"
  
  RETURN { gcd_loaded, arch_constraints, gov_rules_index, sast_patterns, schema_constraints, contract_rules, ux_constraints, coding_standards, mandatory_patterns }
```

**Impact on check precision:**
- With GCD: Each check references a named constraint ID (`[ARCH-B2-001]`, `[GOV-SEC-003]`)  
- Without GCD: Checks reference rule files generically ("per architecture.md")  
- Named IDs make REVIEW findings precise, reproducible, and directly linkable to the design decision that generated them.

### Check #1: [ARCH-XX] Architecture Compliance
```yaml
# Source: design.md Section 7.1 (if GCD loaded) → arch_constraints
# Fallback: constitution.md architecture section
VERIFY:
  - Module boundaries respected per arch_constraints.module_boundaries_table
    (each forbidden cross-module import → BLOCKER [ARCH-{B_code}-{N}])
  - Dependency direction correct per arch_constraints.layer_rule
  - Layer separation enforced (no domain entity in presentation, no infra leak into domain)
  - Architecture pattern from design.md Section 1 faithfully implemented
  - Extension strategy compliance per arch_constraints.extension_strategy
    (E1/E2: legacy files untouched; E2: proxy pattern verified; E3: no legacy imports)
  
SEVERITY: BLOCKER if architectural boundary violated
CONSTRAINT_IDS: [ARCH-{topology_code}-{N}] — cite from Section 7.1
```

### Check #2: [GOV-XX] Governance Rules
```yaml
# Source: design.md Section 7.2 (if GCD loaded) → gov_rules_index
# Fallback: .claude/rules/ files (all applicable)
VERIFY:
  FOR EACH rule IN gov_rules_index.applicable_rules:
    VERIFY each constraint listed under rule.constraints
    IF constraint violated: BLOCKER [GOV-{rule.id}-{N}] citing the specific constraint
  
  # Build indexed map from applicable_rules list for O(1) lookup by rule ID
  rules_by_id = { rule.id: rule FOR rule IN gov_rules_index.applicable_rules }
  
  Specific always-checked items:
  - Naming conventions per rules_by_id["GOV-STACK"].constraints
  - File organization per rules_by_id["GOV-ARCH"].constraints
  - Test coverage >= rules_by_id["GOV-TEST"].coverage_threshold
  - Test file pattern matches rules_by_id["GOV-TEST"].test_file_pattern
  - Observability: required log fields per rules_by_id["GOV-OBS"].constraints
  - Privacy: PII fields handled per rules_by_id["GOV-PRIV"].constraints
  
SEVERITY: BLOCKER for CRITICAL rules, WARNING for MEDIUM
CONSTRAINT_IDS: [GOV-{rule_id}-{N}] — cite from Section 7.2
```

### Check #2b: [GOV-SHARED-XX] Shared Cross-Cutting Component Enforcement

```yaml
# Source: design.md Section 7.2b (if GCD loaded) → shared_components[]
# Fallback: constitution.md governance rules that prescribe mechanisms
# PURPOSE: Verify governance-mandated shared mechanisms (middleware, base classes)
# were implemented as SHARED components, not inlined per-module.

IF governance_context.shared_components EXISTS AND LENGTH > 0:
  FOR EACH component IN governance_context.shared_components:

    # Sub-check 1: Shared component exists at prescribed location
    IF NOT FILE_EXISTS(component.location):
      BLOCKER [GOV-SHARED-MISSING-{N}]:
        "Governance rule {component.rule_source} mandates shared component
         '{component.name}' at {component.location} — file not found."

    # Sub-check 2: Domain modules consume the shared component (not inline)
    IF component.component_type == "base_class":
      SCAN domain modules for classes of same type
      FOR EACH domain_class:
        IF NOT inherits_from(domain_class, component.name):
          BLOCKER [GOV-SHARED-INLINE-{N}]:
            "{domain_class} reimplements {component.responsibility} inline
             instead of inheriting from {component.name}."

    IF component.component_type == "middleware":
      SCAN app entrypoints for middleware registration
      IF component.name NOT registered:
        BLOCKER [GOV-SHARED-UNREG-{N}]:
          "Middleware '{component.name}' prescribed by {component.rule_source}
           is not registered in the application middleware stack."

SEVERITY: BLOCKER — shared mechanism violations are architectural drift
CONSTRAINT_IDS: [GOV-SHARED-{MISSING|INLINE|UNREG}-{N}]
```

### Check #2c: [GOV-SEED-ALIGNMENT] Synthetic Data Schema & Isolation

```yaml
# Triggers when the feature touches seed/synthetic data scripts OR migration/schema files.
# Verifies seed data alignment + deployment isolation using BVL-resolved test commands.
#
# Triggered by ANY of:
#   - feature_files INCLUDES seed script pattern (modified or new)
#   - feature_files INCLUDES migration/schema files (modified or new)
#   - feature_files INCLUDES packaging config that could loosen deployment scope

VERIFY:
  # Sub-check 1: seed schema alignment guardrail passes
  # Resolve seed alignment tests from the project's test suite via BVL commands.
  # Uses GLOB to find test files matching seed alignment naming convention,
  # then runs them via BVL's resolve_verification_commands().test_single.
  seed_alignment_tests = GLOB("tests/**/test_seed_*alignment*")
  IF seed_alignment_tests.length > 0:
    commands = resolve_verification_commands()  # From BVL
    seed_test_cmd = INTERPOLATE(commands.test_single, {test_file: seed_alignment_tests})
    RUN seed_test_cmd
    IF exit_code != 0:
      BLOCKER [GOV-SEED-ALIGNMENT-SCHEMA]:
        "Seed schema alignment test failed. Seed scripts drift from
         migration schemas. See test output for specific defects."

  # Sub-check 2: deployment isolation guardrail passes
  seed_isolation_tests = GLOB("tests/**/test_seed_*isolation*")
  IF seed_isolation_tests.length > 0:
    isolation_test_cmd = INTERPOLATE(commands.test_single, {test_file: seed_isolation_tests})
    RUN isolation_test_cmd
    IF exit_code != 0:
      BLOCKER [GOV-SEED-ALIGNMENT-DEPLOY]:
        "Seed deployment isolation test failed. Either packaging scope
         was loosened, or a seed file lost its fail-secure runtime guard."

  # Sub-check 3: every new seed script is registered in seed_registry.json
  FOR EACH new_seed IN feature_files MATCHING seed_script_pattern:
    READ config/seed_registry.json
    IF new_seed NOT REFERENCED in dependency_graph:
      BLOCKER [GOV-SEED-ALIGNMENT-REGISTRY]:
        "{new_seed} is not registered in config/seed_registry.json."

SEVERITY: BLOCKER — synthetic data integrity is a project-wide guarantee
CONSTRAINT_IDS: [GOV-SEED-ALIGNMENT-{SCHEMA|DEPLOY|REGISTRY}-{N}]
```

### Check #2d: [GOV-DEFECT-PREVENTION] Known Defect Pattern Scan

```yaml
# Scans modified files for known runtime defect patterns from the Defect
# Prevention Catalog. These patterns are invisible to static gates and
# were discovered empirically during deployment testing.
#
# This check runs EVERY phase, not conditionally. The catalog is small
# and the checks are fast (grep-level).
#
# Reference: .claude/rules/defect-prevention.md
# Detailed patterns: .claude/skills/Factory-preventive-sweep/SKILL.md

VERIFY:
  IF NOT FILE_EXISTS(".claude/rules/defect-prevention.md"):
    SKIP  # Project doesn't use DPC (pre-SETUP or opted out)

  READ .claude/rules/defect-prevention.md → dc_catalog
  # Catalog columns: DC | Name | Applicable When | Review Severity | Prevention Check

  FOR EACH modified_file IN phase_files:
    FOR EACH dc IN dc_catalog:
      IF modified_file SCOPE INTERSECTS dc.applicable_when:
        # Verify modified code satisfies the documented prevention check
        IF NOT CHANGE_SATISFIES(dc.prevention_check, modified_file):
          IF dc.review_severity == "BLOCKER":
            BLOCKER [GOV-DC-{dc.number}]:
              "Defect prevention check DC-{dc.number} ({dc.name}) not satisfied in {file}:{line}.
               Required prevention: {dc.prevention_check}.
               Reference: .claude/rules/defect-prevention.md"
          ELSE:
            WARNING [GOV-DC-{dc.number}]:
              "Potential defect pattern DC-{dc.number} ({dc.name}) in {file}:{line}. Verify prevention: {dc.prevention_check}."

SEVERITY: per-DC (BLOCKER or WARNING as defined in catalog Review Severity column)
CONSTRAINT_IDS: [GOV-DC-{N}]
REFERENCE: .claude/rules/defect-prevention.md
```

### Check #3: [SEC-XX] Security Patterns
```yaml
# Source: sast_patterns from GCD 7.3 (or fallback SAST library). Full scan in SEC Hat below.
VERIFY:
  - No hardcoded secrets (passwords, API keys, tokens) — SAST-SEC-01
  - No dangerous functions per sast_patterns.patterns (stack-specific)
  - Input validation on all user-facing endpoints — SAST-INJ-* applicable patterns
  - SQL parameterization (no string concatenation) — SAST-INJ-01
  - Output encoding on rendered content — SAST-INJ-02
  - CORS configuration correct per gov_rules_index["GOV-SEC"].constraints
  
SEVERITY: BLOCKER for any security violation
CONSTRAINT_IDS: [SAST-{category}-{N}] — cite from Section 7.3
```

### Check #4: [PATH-XX] Protected Paths
```yaml
READ config/protected-paths.json:
  FOR EACH modified_file:
    IF file IN red_zones:
      CHECK for ADR approving modification
      IF no ADR: ❌ BLOCKER: "RED ZONE violation"
    IF file IN yellow_zones:
      FLAG for extra review attention
  
SEVERITY: BLOCKER for red_zone, WARNING for yellow_zone
```

### Check #5: [SCHEMA-XX] Schema Compliance
```yaml
# Source: design.md Section 7.4 (if GCD loaded) → schema_constraints
# Fallback: user_journey.md Data Schemas (direct read)
VERIFY data structures match schema_constraints.entities (or user_journey.md):
  # schema_constraints.entities is a list of {name, locked_fields} objects (from GCD Section 7.4)
  entities_by_name = { e.name: e FOR e IN schema_constraints.entities }
  FOR EACH entity/DTO/model in implementation:
    COMPARE fields against entities_by_name[entity_name].locked_fields
    
    Technical fields EXEMPT (free to add):
      schema_constraints.exempt_technical_fields
      (id, uuid, created_at, updated_at, deleted_at, version, audit fields, pagination metadata)
    
    Business fields MUST MATCH locked_fields:
      Field names, types, required/optional must align with schema
      IF business field differs: ❌ BLOCKER [SCHEMA-{entity}-{N}] (requires RDR via CODESIGN --refine)
  
SEVERITY: BLOCKER for business field mismatch
CONSTRAINT_IDS: [SCHEMA-{entity_name}-{N}] — cite from Section 7.4
```

#### [SCHEMA-TEST] Test Data Type Compliance
```yaml
# Source: GCD 7.4 type_format_registry + contract schemas (format fields)
# Test fixtures/mocks/stubs MUST use values conforming to declared domain types.

# Format normalization map (OpenAPI → internal canonical names)
FORMAT_NORMALIZATION = {
  "date-time": "iso-datetime",
  "date": "iso-date",
  "uri": "uri",
  "uuid": "uuid",
  "email": "email",
  "phone": "phone"
}

FUNCTION normalize_format(raw_format):
  RETURN FORMAT_NORMALIZATION[raw_format] IF raw_format IN FORMAT_NORMALIZATION ELSE raw_format

# Step 1: Build expected type registry
type_registry = {}
IF schema_constraints.type_format_registry IS NOT NULL:
  FOR EACH entry IN schema_constraints.type_format_registry:
    type_registry[entry.field_pattern] = normalize_format(entry.format)
FOR EACH entity IN schema_constraints.entities:
  FOR EACH field IN entity.locked_fields WHERE field.format IS NOT NULL:
    type_registry["{entity.name}.{field.field}"] = normalize_format(field.format)

# Step 2: Augment from contract schemas (OpenAPI/GraphQL format fields)
FOR EACH contract_file IN contracts/:
  EXTRACT fields with explicit format: (uuid, email, date-time, date, uri)
  NORMALIZE each format via normalize_format() before merging
  MERGE into type_registry

# Pattern-aware lookup function
FUNCTION lookup_expected_format(type_registry, field_name):
  # Precedence: 1. Exact match → 2. Wildcard patterns (most specific wins)
  IF type_registry[field_name] IS NOT NULL:
    RETURN type_registry[field_name]

  best_format = NULL
  best_specificity = -1

  FOR EACH pattern, fmt IN type_registry:
    IF pattern CONTAINS "*":
      IF field_name GLOB_MATCHES pattern:
        specificity = LENGTH(pattern REPLACE "*" WITH "")
        IF specificity > best_specificity:
          best_format = fmt
          best_specificity = specificity

  RETURN best_format

# Step 3: Scan test files for type violations
FOR EACH test_file IN feature test directory:
  FOR EACH assignment/literal IN test_file WHERE assigns mock/fixture/stub data:
    field_name = EXTRACT field name from assignment context
    # Normalize qualified field names (e.g., User.id, user->id) to terminal segment
    normalized_field = LAST_PATH_SEGMENT(field_name, delimiters=[".", "->", "::"])
    expected_format = lookup_expected_format(type_registry, field_name)
    IF expected_format IS NULL:
      expected_format = lookup_expected_format(type_registry, normalized_field)
    IF expected_format IS NOT NULL:
      actual_value = EXTRACT assigned value
      # Negative test exemption
      # Skip validation for intentionally invalid test data:
      #   - Test function/method name contains "invalid", "malformed", "bad", "reject", "fail"
      #   - Variable/fixture name prefixed with "invalid_" or "bad_"
      #   - Comment annotation: # @schema-test-exempt: negative test
      IF test_context IS negative_test_fixture:
        SKIP — intentional invalid data for validation testing
        CONTINUE
      VALIDATE actual_value conforms to expected_format:
        uuid: MATCHES /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
        email: MATCHES /^[^@]+@[^@]+\.[^@]+$/
        iso-datetime: MATCHES /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
        iso-date: MATCHES /^\d{4}-\d{2}-\d{2}$/
        uri: MATCHES /^https?:\/\//
        phone: MATCHES /^\+?[\d\s-]+$/
      IF NOT VALID:
        ⚠️ WARNING: "[SCHEMA-TEST-{N}] Test data type mismatch: field '{field_name}' "
                   "expects format '{expected_format}' but test uses '{actual_value}'. "
                   "This masks type validation bugs at runtime."
        # Escalate to BLOCKER if the field is a primary identifier or foreign key
        IF normalized_field MATCHES "*_id" OR normalized_field == "id":
          ❌ BLOCKER: "[SCHEMA-TEST-{N}] Identifier field '{field_name}' uses non-{expected_format} "
                     "literal in test. IDs with wrong format will fail validation, FK lookups, "
                     "and cross-service calls at runtime."

SEVERITY: BLOCKER for identifier fields, WARNING for other typed fields
CONSTRAINT_IDS: [SCHEMA-TEST-{N}]
```

### Check #6: [TYPE-XX] Cross-Layer Type Mapping
<!-- applicable_when: scope in [full-stack] — requires both frontend and backend layers; scope=frontend-only + scope=backend-only + scope=integration resolve this check as N/A. -->

```yaml
VERIFY type consistency across layers:
  API contract types ↔ Service layer types ↔ Database schema types ↔ Frontend types
  
  FOR EACH data flow path:
    TRACE type transformations through all layers
    VERIFY no implicit type coercion or data loss
    VERIFY nullable handling consistent
  
SEVERITY: BLOCKER for type mismatch causing data loss
```

### Check #7: [UX-*] UX Compliance (11 Sub-Checks)
<!-- applicable_when: scope in [full-stack, frontend-only] — entire block (all 11 sub-checks) resolves as N/A when scope in [backend-only, integration]. -->

> **Scope gate.** All 11 UX sub-checks below presuppose a UI surface (mock.html + app_shell + component_library). When `feature_scope IN [backend-only, integration]`, skip the entire Check #7 block, record one `N/A — skipped under scope={value}` line in peer_review § 3.7, and move to Check #8. The scope dispatcher (top of this instruction file) already performs this filter — individual sub-checks below do not re-validate scope.

#### [UX-STRUCT] Structure Compliance
```yaml
VERIFY mock.html DOM structure faithfully implemented:
  - Semantic HTML tags match (header, main, nav, section, article, footer)
  - Nesting hierarchy preserved
  - Component decomposition matches mock extraction
```

#### [UX-ARIA] Accessibility Attributes
```yaml
VERIFY ARIA implementation:
  - All interactive elements have appropriate roles
  - aria-label, aria-describedby on form fields
  - aria-live regions for dynamic content
  - Focus management on modals/dialogs
  - Skip navigation links present
```

#### [UX-CSS] Styling Compliance
```yaml
VERIFY styling matches vision + mock:
  - CSS custom properties from style_guide.html used (not hardcoded values)
  - Color tokens match vision palette
  - Typography scale from vision applied
  - Spacing consistent with vision grid
```

#### [UX-TOUCH] Touch Target Compliance
```yaml
# Source: design.md Section 7.6 ux_constraints.touch_target_minimum (if GCD loaded)
VERIFY:
  - All interactive elements ≥ {ux_constraints.touch_target_minimum | 44×44px} touch target
  - Adequate spacing between touch targets
  - No overlapping interactive elements
```

#### [UX-TEST] Frontend Test Coverage
```yaml
VERIFY:
  - Component tests exist for each UI component
  - E2E tests cover user journey scenarios from spec.feature
  - Accessibility tests (axe-core) pass
  - Test coverage meets minimum threshold from testing.md
```

#### [UX-REUSE] Component Reuse
```yaml
VERIFY no duplicate components:
  - Check component_library.html for existing equivalent
  - Check codebase_inventory.json for existing components
  - IF duplicate found: ❌ BLOCKER: "Component exists in vision library. REUSE."
```

#### [UX-DRY] UI Component DRY (Domain-Aware)
```yaml
READ constitution.md → architecture.topology
UI components are ALWAYS "SHARED" category (cross-feature reuse MANDATORY)

VERIFY:
  - No duplicated UI components across features
  - Shared components extracted to common directory
  - Feature-specific components clearly scoped
  
SEVERITY: BLOCKER if duplicating vision library component
```

#### [UX-RESP] Responsive Design
```yaml
VERIFY responsive breakpoints:
  - Mobile, tablet, desktop breakpoints from ux-constitution.md
  - Layout adapts correctly at each breakpoint
  - No horizontal overflow on mobile
  - Images and media responsive
```

#### [UX-BRAND] Brand Consistency (from Vision)
```yaml
VERIFY brand elements from vision:
  - Logo usage per style_guide.html
  - Brand colors applied correctly
  - Typography hierarchy preserved
  - Iconography consistent
```

#### [UX-LAYOUT] Layout Compliance
```yaml
VERIFY layout matches page_templates.html:
  - Correct template type used (dashboard, list, detail, form, error)
  - Grid/flexbox structure matches template
  - Content zones in correct positions
```

#### [UX-VISION] Vision Fidelity (v12.0.0) — CRITICAL
```yaml
VERIFY global vision artifacts are faithfully materialized:

  Shell Fidelity:
    - app_shell.html structure preserved (header, sidebar, footer, nav)
    - Shell composition inherits from vision, not custom-built
  
  Page Template Adherence:
    - Correct template type from page_templates.html used
    - Layout structure matches template specification
  
  Component Library Reuse:
    - BLOCKER: Creating component that exists in component_library.html
    - Must reference and reuse vision components
  
  Token Consistency:
    - BLOCKER: Hardcoding colors/fonts when style_guide.html tokens exist
    - CSS custom properties from vision must be used
  
  Navigation Integration:
    - Feature correctly placed per navigation_map.md
    - Routes match navigation hierarchy
    - Active states/breadcrumbs correct

SEVERITY: BLOCKER for shell duplication, token hardcoding, component duplication
```

### Check #8: [MIGRATION-XX] Migration Safety
<!-- applicable_when: scope in [full-stack, backend-only, integration] — frontend-only features have no DB migrations to audit. -->

```yaml
IF implementation includes database migrations:
  VERIFY:
    - Migration is reversible (has down/rollback function)
    - No data loss in migration
    - Large table migrations use batching
    - Indexes created before queries that need them
  
  IF brownfield (extension strategy E1/E2):
    VERIFY legacy data compatibility preserved
```

### Check #9: [IAC-XX] Infrastructure Compliance
```yaml
IF implementation modifies infrastructure files (infra/):
  VERIFY against .claude/rules/iac.md:
    - Naming conventions followed
    - Modules properly structured
    - Security groups/IAM follow least privilege
    - Tags applied per governance
    - No hardcoded secrets in IaC (per DEVOPS Guardrail 3)
```

### Check #10: [CFP-XX] Contract-First Policy (4 Sub-Checks)
<!-- applicable_when: scope in [full-stack, backend-only, integration] — contract-first-policy governs backend-owned contracts; frontend-only features are consumers (validated via BLUEPRINT Consumes-Contract Resolution Gate + IMPLEMENT Consumes-Contract Upstream Freeze Gate instead). -->


#### [CFP-IMPORT] Cross-Domain Import Detection
```yaml
# Source: design.md Section 7.5 (if GCD loaded) → contract_rules.cross_domain_import_forbidden_from
# Fallback: constitution.md architecture.topology
IF arch_constraints.topology_code IN domain-model architectures (B2-B8, B10-B11):
  FORBIDDEN_MODULES = contract_rules.cross_domain_import_forbidden_from (if GCD) OR derive from topology
  SCAN for direct imports across module boundaries:
    PATTERNS (stack-adaptive):
      TypeScript: import.*from.*['"].*modules/{other_module}
      Python: from.*modules\.{other_module}.*import
      Java: import.*modules\.{other_module}
      Go: import.*modules/{other_module}
    
    IF cross-domain import found:
      ❌ BLOCKER: "Direct cross-domain import detected. Use HTTP contract."
      SUGGEST: "Call via API client generated from contract file."
```

#### [CFP-REF] Contract Reference Compliance
```yaml
VERIFY all API calls reference contract files:
  FOR EACH HTTP client call in implementation:
    TRACE to contract source (OpenAPI/GraphQL/gRPC)
    IF no contract reference: ❌ BLOCKER: "API call without contract."
```

#### [CFP-UNDECL] Undeclared Endpoint Detection
```yaml
SCAN for endpoints not declared in any contract:
  FOR EACH route/handler/controller in implementation:
    MATCH against OpenAPI paths / GraphQL operations / gRPC services
    IF not found in contracts: ❌ BLOCKER: "Undeclared endpoint."
```

#### [CFP-EVENT] Event Contract Compliance
```yaml
IF AsyncAPI contracts exist:
  VERIFY event publishers match asyncapi.yaml channels
  VERIFY event consumers match asyncapi.yaml subscribe operations
  VERIFY message schemas match asyncapi.yaml message definitions
```

### Check #11: [EXT-STRATEGY] Extension Strategy Compliance (3 Sub-Checks)

#### [EXT-CONVENTION] Convention Alignment
```yaml
READ constitution.md → extension.strategy
IF E0 (Native): VERIFY new code follows existing codebase patterns
IF E1 (Preserve+Wrapper): VERIFY legacy code untouched, wrappers used
IF E2 (Strangler Fig): VERIFY proxy pattern, no direct legacy modification
IF E3 (Full Rewrite): VERIFY no legacy dependencies imported
```

#### [EXT-LEGACY] Legacy Protection
```yaml
IF strategy IN [E1, E2]:
  VERIFY no modifications to files in legacy scope
  VERIFY adapter/wrapper interfaces shield new code from legacy
```

#### [EXT-FLAGS] Feature Flag Usage
```yaml
IF strategy IN [E1, E2]:
  VERIFY feature flags gate new behavior
  VERIFY rollback possible via flag toggle
```

### Check #12: [ACL-EXT] External System ACL Compliance (3 Sub-Checks)
<!-- applicable_when: scope in [full-stack, backend-only, integration] — ACL audits are specific to service-to-service boundaries, which frontend-only features do not create (they consume APIs via client-side fetch, not via ACL adapters). -->


#### [ACL-IMPORT] External System Import Control
```yaml
VERIFY external system access goes through declared adapters:
  No direct SDK calls outside adapter layer
  Adapter interfaces defined in design.md followed
```

#### [ACL-IMPL] Adapter Implementation
```yaml
VERIFY adapter follows Anti-Corruption Layer pattern:
  External models translated to internal models
  No external types leaking into domain layer
```

#### [ACL-LEAK] Abstraction Leak Detection
```yaml
VERIFY no external service concepts leak into domain:
  External error types wrapped
  External data structures mapped to domain entities
  Queue/topic names abstracted behind configuration
```

### Check #13: [POLICY-XX] Business Policy Compliance (3 Sub-Checks)

#### [POLICY-COV] Policy Coverage
```yaml
READ user_journey.md → policies[]
VERIFY each business policy has implementation:
  - Guard/middleware/validator implementing the rule
  - Test verifying the rule enforcement
```

#### [POLICY-TEST] Policy Test Alignment
```yaml
VERIFY policy tests match test_plan.md acceptance criteria:
  Each acceptance scenario has at least one test
  Edge cases from test_plan.md covered
```

#### [POLICY-AUTH] Authorization Policy
```yaml
IF policies include authorization rules:
  VERIFY role-based access control implemented per design.md
  VERIFY unauthorized access returns 403 (not 404 for security)
  VERIFY audit trail for sensitive operations
```

### Check #14: [DESIGN-XX] Design Materialization Fidelity (v3.0.0)

> **Purpose:** Verifies that ALL mandatory shared components from design.md Section 2
> (Component Inventory) and Section 7.8 (Mandatory Architectural Patterns + ADR Bindings)
> have been actually materialized in code and are used as prescribed — not bypassed by ad-hoc
> implementations. This check closes the gap where IMPLEMENT satisfies constraints
> superficially (e.g., manual tenant filtering instead of the prescribed BaseRepository).

#### [DESIGN-COMP] Component Inventory Materialization
```yaml
# Source: design.md Section 2 (Component Inventory) + Section 7.8 (if GCD loaded) → mandatory_patterns
# Fallback: design.md Section 2 + constitution.md architecture patterns + ADRs

READ design.md → Section 2 "Component Inventory"
  EXTRACT all_planned_components[]:
    FOR EACH component: name, type, module, scope (shared|feature), status (planned|existing)

VERIFY materialization:
  FOR EACH component IN all_planned_components WHERE scope == "shared":
    # These are shared components that design.md prescribed for cross-cutting concerns
    SEARCH @workspace for component.name (file name, class/function definition)
    IF NOT FOUND:
      ❌ BLOCKER: "[DESIGN-COMP-{N}] Shared component '{component.name}' ({component.type}) "
                 "prescribed in design.md Section 2 was NOT materialized. "
                 "Feature code may be implementing this concern ad-hoc."
      SUGGEST: "Create {component.name} as a shared {component.type} and refactor "
               "feature code to use it."
    ELSE:
      # Verify it's actually USED by feature code (not just created but bypassed)
      SEARCH @workspace for imports/usage of component.name in feature module
      IF NOT USED BY FEATURE:
        ❌ BLOCKER: "[DESIGN-COMP-{N}] Shared component '{component.name}' exists but is "
                   "NOT used by feature code. Feature implements this concern ad-hoc."
        SUGGEST: "Refactor feature code to use existing {component.name} instead of "
                 "implementing {component.type} logic directly."

SEVERITY: BLOCKER for unmaterialized or bypassed shared components
```

#### [DESIGN-PATTERN] Mandatory Pattern Compliance
```yaml
# Source: design.md Section 7.8 (if GCD loaded) → mandatory_patterns
# Fallback: constitution.md architecture patterns + ADRs

IF mandatory_patterns IS NOT NULL:
  FOR EACH pattern IN mandatory_patterns.patterns WHERE affects_feature == true:
    VERIFY pattern enforcement:
      CASE pattern.type == "base_class":
        # Verify all entities of the dependent type extend/use the base class
        # Example: All repositories MUST extend BaseRepository
        dependents = FIND_ALL(@workspace, type matching pattern.enforcement target)
        FOR EACH dependent IN dependents:
          IF NOT EXTENDS_OR_USES(dependent, pattern.name):
            ❌ BLOCKER: "[DESIGN-PAT-{N}] {dependent.name} does NOT extend/use "
                       "{pattern.name} as required by {pattern.constitution_ref}. "
                       "Enforcement: {pattern.enforcement}"
      
      CASE pattern.type == "middleware":
        # Verify middleware is registered in the middleware chain and provides
        # the declared context (e.g., tenant_id in request.state)
        middleware_chain = FIND(@workspace, middleware registration/pipeline)
        IF pattern.name NOT IN middleware_chain:
          ❌ BLOCKER: "[DESIGN-PAT-{N}] Middleware '{pattern.name}' is NOT registered "
                     "in the middleware chain as required by {pattern.constitution_ref}."
        # Verify downstream code uses middleware-provided context (not direct extraction)
        IF pattern.name CONTAINS "tenant" OR pattern.name CONTAINS "Tenant":
          SCAN for anti-patterns:
            # Feature handlers directly extracting from JWT/claims instead of
            # consuming middleware-injected context
            direct_extractions = GREP(@workspace, pattern:
              'claims\["tenant_id"\]|claims\.tenant_id|jwt.*tenant|token.*tenant'
              EXCLUDING middleware files themselves)
            IF direct_extractions.count > 0:
              ❌ BLOCKER: "[DESIGN-PAT-{N}] Found {direct_extractions.count} instances "
                         "of direct tenant_id extraction from claims/JWT. "
                         "Per {pattern.constitution_ref}, tenant context MUST flow "
                         "via {pattern.name} middleware injection."
      
      CASE pattern.type == "shared_service" OR pattern.type == "guard" OR pattern.type == "interceptor":
        # Verify the shared service/guard exists and is used
        EXISTS = SEARCH(@workspace, pattern.name)
        IF NOT EXISTS:
          ❌ BLOCKER: "[DESIGN-PAT-{N}] Shared {pattern.type} '{pattern.name}' "
                     "required by {pattern.constitution_ref} was NOT created."

SEVERITY: BLOCKER for pattern violations
CONSTRAINT_IDS: [DESIGN-PAT-{N}] — cite from Section 7.8 pattern IDs
```

#### [DESIGN-FDR] FDR Binding Compliance
```yaml
# Source: design.md Section 7.8 fdr_bindings (if GCD loaded)
# Fallback: docs/spec/{FEATURE_ID}/fdr/*.md (status: accepted)
# Legacy fallback: docs/spec/{FEATURE_ID}/adr/ (when fdr/ tree absent)

IF mandatory_patterns.fdr_bindings IS NOT NULL:
  FOR EACH fdr IN mandatory_patterns.fdr_bindings:
    FOR EACH component IN fdr.mandatory_components:
      EXISTS = SEARCH(@workspace, component)
      IF NOT EXISTS:
        ❌ BLOCKER: "[DESIGN-FDR-{fdr.id}] FDR '{fdr.title}' mandates component "
                   "'{component}' which was NOT implemented. "
                   "Binding rule: {fdr.binding_rule}"

    FOR EACH constraint IN fdr.consequences:
      VERIFY_CONSTRAINT(constraint, @workspace):
        IF constraint implies "no direct {X}": SCAN for violations
        IF constraint implies "always use {Y}": VERIFY usage exists
      IF VIOLATED:
        ❌ BLOCKER: "[DESIGN-FDR-{fdr.id}] FDR constraint violated: '{constraint}'"

# mandatory_patterns.historical_adr_refs is informational only — never validated.
# Project-wide [LAW] enforcement lives in [DESIGN-PAT] via mandatory_patterns.

SEVERITY: BLOCKER for FDR binding violations
```

#### [DESIGN-INVARIANT] Implementation Invariant Verification
```yaml
# Source: design.md Section 7.8 implementation_invariants

IF mandatory_patterns.implementation_invariants IS NOT NULL:
  FOR EACH invariant IN mandatory_patterns.implementation_invariants:
    # Each invariant is a natural-language rule like:
    #   "All repositories MUST extend BaseRepository — never implement tenant filtering manually"
    # Convert to verification:
    VERIFY_INVARIANT(invariant, @workspace):
      PARSE invariant for:
        positive_pattern: what MUST exist (e.g., "extend BaseRepository")
        negative_pattern: what MUST NOT exist (e.g., "manual tenant filtering")
      
      IF negative_pattern detected:
        ⚠️ WARNING: "[DESIGN-INV-{N}] Possible invariant violation: '{invariant}'"
        # Escalate to BLOCKER if pattern match is unambiguous
        IF confidence > 0.8:
          ❌ BLOCKER: "[DESIGN-INV-{N}] Implementation invariant violated: '{invariant}'"

SEVERITY: BLOCKER for confirmed violations, WARNING for suspected
```

### REVIEW Verification Loop (BVL-Integrated — Real Execution v1.1.1)

> **Purpose:** Static checks (#1-#14) read code. This loop **executes** real tools to verify
> that coverage, lint, and type compliance are real — not assumed from code inspection.
> Uses BVL's `resolve_verification_commands()` as the single source of truth for commands.

```yaml
FUNCTION review_verification_loop(phase, source_files, governance_context):
  commands = resolve_verification_commands()  # From BVL SKILL.md
  results = {}
  
  # 1. Test Coverage Verification (MANDATORY — closes GOV-TEST gap)
  IF commands.coverage IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.coverage, timeout: 120000)
    
    IF result.exit_code == 0 OR result.output CONTAINS "%":
      coverage_pct = EXTRACT_COVERAGE_PERCENTAGE(result.output):
        # Parse "Statements   : 85.71%" or "TOTAL    400    60    85%" patterns
        SCAN for lines matching /(\d+\.?\d*)%/
        EXTRACT the aggregate/total coverage percentage
      
      gov_test_rule = governance_context.governance_rules.rules_by_id["GOV-TEST"] IF governance_context.governance_rules.rules_by_id EXISTS ELSE NULL
      threshold = gov_test_rule.coverage_threshold OR 80
      
      IF coverage_pct < threshold:
        results.coverage = {
          status: "BLOCKER",
          finding: "[GOV-TEST-COV] Coverage {coverage_pct}% is below threshold {threshold}%",
          value: coverage_pct,
          threshold: threshold,
          remediation: "Add tests for uncovered paths. Run: {commands.coverage} to see uncovered lines."
        }
      ELSE:
        results.coverage = { status: "PASS", value: coverage_pct, threshold: threshold }
        LOG: "✅ REVIEW: Coverage {coverage_pct}% >= {threshold}% threshold"
    ELSE:
      results.coverage = {
        status: "WARNING",
        finding: "Coverage command failed — manual verification needed",
        output: result.output
      }
  ELSE:
    results.coverage = { status: "SKIPPED", reason: "No coverage command for stack" }
  
  # 2. Lint Re-Verification (MANDATORY — confirms BVL phase results still hold)
  IF commands.lint IS NOT NULL:
    phase_files = COLLECT_SOURCE_FILES(phase)
    lint_cmd = INTERPOLATE(commands.lint, {files: phase_files})
    result = RUN_IN_TERMINAL(lint_cmd, timeout: 30000)
    
    IF result.exit_code != 0:
      results.lint = {
        status: "BLOCKER",
        finding: "[GOV-LINT-001] Lint violations detected in Phase {phase}",
        output: TRUNCATE(result.output, MAX_LINES: 30),
        remediation: "Fix lint issues. Auto-fix available: {derive_autofix_command(commands.lint)}"
      }
    ELSE:
      results.lint = { status: "PASS" }
      LOG: "✅ REVIEW: Lint clean for Phase {phase}"
  ELSE:
    results.lint = { status: "SKIPPED", reason: "No lint command for stack" }
  
  # 3. Type Check Verification (if available)
  IF commands.typecheck IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.typecheck, timeout: 60000)
    
    IF result.exit_code != 0:
      results.typecheck = {
        status: "BLOCKER",
        finding: "[GOV-TYPE-001] Type errors detected",
        output: TRUNCATE(result.output, MAX_LINES: 30),
        remediation: "Fix type errors shown above."
      }
    ELSE:
      results.typecheck = { status: "PASS" }
      LOG: "✅ REVIEW: Type check clean"
  ELSE:
    results.typecheck = { status: "SKIPPED", reason: "No typecheck command for stack" }
  
  # 4. Full Test Suite Re-Run (confirms no regressions from REVIEW-triggered fixes)
  IF commands.test_suite IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.test_suite, timeout: 180000)
    
    IF result.exit_code != 0:
      results.test_suite = {
        status: "BLOCKER",
        finding: "[GOV-TEST-SUITE] Test suite regression after Phase {phase}",
        output: parse_test_output(result.output, commands).summary,
        remediation: "Fix failing tests before REVIEW can pass."
      }
    ELSE:
      results.test_suite = { status: "PASS" }
      LOG: "✅ REVIEW: Full test suite GREEN"
  
  RETURN results
```

### Step R.2: Aggregate Results (Static + Execution)
```yaml
Step R.2: Aggregate Results
  # Merge static check results (#1-#13) WITH verification loop results
  static_blockers = COLLECT all BLOCKER findings from checks #1-#14
  static_warnings = COLLECT all WARNING findings from checks #1-#14
  
  # Run verification loop (REAL EXECUTION)
  verification_results = review_verification_loop(phase, source_files, governance_context)
  
  execution_blockers = COLLECT findings WHERE status == "BLOCKER" FROM verification_results
  execution_warnings = COLLECT findings WHERE status == "WARNING" FROM verification_results
  
  blockers = static_blockers + execution_blockers
  warnings = static_warnings + execution_warnings

Step R.3: Determine Verdict
  IF blockers.length > 0:
    verdict = "BLOCKED"
    OUTPUT detailed blocker list with file:line references
    RETURN to DEV for fix loop
  
  IF warnings.length > 0:
    verdict = "PASS_WITH_WARNINGS"
    OUTPUT warning list
    PROCEED to SEC Hat (warnings documented but non-blocking)
  
  IF no issues:
    verdict = "CLEAN_PASS"
    PROCEED to SEC Hat

Step R.4: Generate Review Report Snippet
  FOR EACH phase:
    LOG check results (pass/warn/block per check category)

Step R.5: Fix Loop Control
  IF verdict == BLOCKED:
    DEV receives specific blockers with fix guidance
    DEV fixes → REVIEW re-runs ONLY affected checks
    Max 3 fix-review cycles per phase before escalation
```

---

## SEC Hat Protocol (🛡️)

Execute AFTER REVIEW Hat passes for each phase.

### SAST Scan (GCD v2.2.0)
```yaml
# SEC Hat uses same governance_context + gcd_loaded from Phase Loop (implement-build Step 0b).
# GCD path: sast_patterns pre-compiled with IDs. Fallback: derived from full SAST library.

IF gcd_loaded:
  PATTERNS = sast_patterns.patterns + sast_patterns.common_patterns
  LOG: "SAST GCD fast-path ✅ — using {count} pre-compiled patterns for {sast_patterns.backend_runtime}"
ELSE:
  # Fallback: patterns derived from full SAST library (loaded in implement-build Step 1)
  PATTERNS = sast_patterns  # already populated by Step 1 fallback
  LOG: "SAST GCD miss — derived patterns from full library"

FOR EACH pattern IN PATTERNS:
  SCAN implementation files
  IF match found:
    REPORT: "[{pattern.id}] {pattern.description} — {file}:{line} — CWE: {pattern.cwe} — {pattern.severity}"
    CITE: pattern.owasp
```

### SAST Full Pattern Library (Fallback — used when GCD absent)
```yaml
Category 1: Injection Attacks
  - SQL injection (string concatenation in queries)
  - Command injection (user input in exec/spawn/system)
  - Template injection (user input in template engines)
  - LDAP injection, XML injection, XPath injection

Category 2: Authentication & Authorization
  - Hardcoded credentials (passwords, keys, tokens)
  - Missing authentication on endpoints
  - Broken authorization (role checks missing)
  - Session management issues

Category 3: Cryptography
  - Weak algorithms (MD5, SHA1 for security)
  - Hardcoded encryption keys
  - Missing TLS/HTTPS enforcement
  - Insecure random number generation

Category 4: Data Exposure
  - Sensitive data in logs (PII, credentials)
  - Stack traces exposed to users
  - Verbose error messages with internal details
  - Missing data masking

Category 5: Configuration
  - Debug mode enabled in non-dev
  - CORS wildcard (*) in non-dev
  - Missing security headers (CSP, X-Frame-Options, etc.)
  - Open redirects

Category 6: Mock HTML Security (Frontend)
  - dangerouslySetInnerHTML without sanitization
  - Script injection via user-rendered content
  - Insecure iframe sources
  - Missing Content-Security-Policy directives

Category 7: ARIA Security Audit
  - ARIA attributes that could be manipulated for phishing
  - Misleading aria-labels on interactive elements
  - Hidden content accessible via assistive tech containing sensitive info

Category 8: Brand Impersonation Detection
  - Fake login forms mimicking third-party brands
  - Unauthorized use of external brand assets
  - Deceptive UI patterns (dark patterns)
```

### Parent Regression Check
```yaml
IF brownfield (extension strategy E1/E2/E3):
  VERIFY:
    - No existing tests broken by new code
    - No existing functionality altered unless explicitly in scope
    - Legacy adapter contracts preserved
```

### SEC Verification Loop (BVL-Integrated — Real Execution v1.1.1)

> **Purpose:** SAST pattern matching above is static (agent reads code). This loop **executes**
> real security tools to catch vulnerabilities that pattern matching alone cannot detect:
> dependency CVEs, real secret leaks, and supply-chain risks.
> Uses BVL's `resolve_verification_commands()` as the single source of truth for commands.

```yaml
FUNCTION sec_verification_loop(phase, source_files):
  commands = resolve_verification_commands()  # From BVL SKILL.md
  results = {}
  
  # 1. Dependency Vulnerability Audit (MANDATORY — catches known CVEs)
  IF commands.dependency_audit IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.dependency_audit, timeout: 60000)
    
    vulnerabilities = parse_audit_output(result.output):
      # Parse tool-specific output formats
      SCAN for severity indicators: critical, high, moderate/medium, low
      COUNT vulnerabilities by severity
      EXTRACT: package_name, installed_version, vulnerability_id, severity, fix_version
    
    IF vulnerabilities.critical_count > 0 OR vulnerabilities.high_count > 0:
      results.dependency_audit = {
        status: "BLOCKER",
        finding: "[SEC-DEP-001] {vulnerabilities.critical_count} critical + {vulnerabilities.high_count} high vulnerabilities found",
        details: vulnerabilities.top_10,  # Show top 10 most severe
        remediation: "Update vulnerable packages. Run package manager update for affected dependencies.",
        cwe: "CWE-1104",  # Use of Unmaintained Third-Party Components
        owasp: "A06"  # Vulnerable and Outdated Components
      }
    ELIF vulnerabilities.medium_count > 0:
      results.dependency_audit = {
        status: "WARNING",
        finding: "[SEC-DEP-002] {vulnerabilities.medium_count} medium vulnerabilities found",
        details: vulnerabilities.summary
      }
    ELSE:
      results.dependency_audit = { status: "PASS" }
      LOG: "✅ SEC: Dependency audit clean"
  ELSE:
    results.dependency_audit = { status: "SKIPPED", reason: "No audit command for stack" }
    LOG: "⚠️ SEC: Dependency audit skipped — no tool available. Consider installing: npm audit / pip-audit / cargo audit"
  
  # 2. Secret Scanning (MANDATORY — catches leaked credentials)
  IF commands.secret_scan IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.secret_scan, timeout: 30000)
    
    # Tool-based scan (gitleaks/trufflehog)
    IF result.output CONTAINS "Finding" OR result.output CONTAINS "secret" OR result.output CONTAINS "leak":
      secrets_found = parse_secret_scan_output(result.output):
        EXTRACT: file_path, line_number, rule_id, description
        COUNT total findings
      
      IF secrets_found.count > 0:
        results.secret_scan = {
          status: "BLOCKER",
          finding: "[SEC-SECRET-001] {secrets_found.count} potential secrets detected",
          details: secrets_found.findings,
          remediation: "Remove hardcoded secrets. Use environment variables or vault.",
          cwe: "CWE-798",  # Use of Hard-coded Credentials
          owasp: "A02"  # Cryptographic Failures
        }
      ELSE:
        results.secret_scan = { status: "PASS" }
    ELSE:
      results.secret_scan = { status: "PASS" }
      LOG: "✅ SEC: Secret scan clean"
  
  ELSE:
    # Fallback: regex-based secret scan when no dedicated tool is available
    LOG: "⚠️ SEC: No secret scanner (gitleaks/trufflehog). Running regex fallback."
    
    phase_files = COLLECT_SOURCE_FILES(phase)
    secret_patterns = [
      'password\s*[:=]\s*["\x27][^$\n{]{8,}',
      'api[_-]?key\s*[:=]\s*["\x27][^$\n{]{8,}',
      'secret\s*[:=]\s*["\x27][^$\n{]{8,}',
      'token\s*[:=]\s*["\x27][^$\n{]{8,}',
      'private[_-]?key\s*[:=]\s*["\x27][^$\n{]{8,}',
      'AWS_SECRET_ACCESS_KEY\s*[:=]\s*["\x27][A-Za-z0-9/+=]{20,}',
      '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'
    ]
    
    FOR EACH file IN phase_files:
      # Exclude test files, fixtures, .env.example from false positives
      IF file MATCHES /(test|spec|fixture|mock|\.env\.example|\.env\.template)/: SKIP
      
      content = READ(file)
      FOR EACH pattern IN secret_patterns:
        matches = REGEX_SEARCH(content, pattern, CASE_INSENSITIVE)
        IF matches.length > 0:
          results.secret_scan = {
            status: "BLOCKER",
            finding: "[SEC-SECRET-002] Potential hardcoded secret in {file}:{line}",
            pattern: pattern,
            remediation: "Replace with environment variable: process.env.{KEY} / os.environ['{KEY}']",
            cwe: "CWE-798",
            owasp: "A02"
          }
    
    IF results.secret_scan IS NULL:
      results.secret_scan = { status: "PASS" }
  
  RETURN results
```

### SEC Verdict (Static + Execution)
```yaml
IF vulnerabilities found:
  # Merge SAST static findings + verification loop results
  sast_findings = COLLECT all pattern-match findings from SAST scan
  
  # Run verification loop (REAL EXECUTION)
  sec_verification = sec_verification_loop(phase, source_files)
  
  execution_findings = COLLECT findings FROM sec_verification WHERE status IN ["BLOCKER", "WARNING"]
  all_findings = sast_findings + execution_findings
  
  FOR EACH vulnerability IN all_findings:
    CLASSIFY: CRITICAL, HIGH, MEDIUM, LOW
    PROVIDE remediation:
      "File: {file}:{line}
       Issue: {description}
       Fix: {specific remediation code suggestion}
       Reference: {CWE/OWASP reference}"
  
  IF any CRITICAL or HIGH:
    verdict = "BLOCKED"
    RETURN to DEV for fix loop
  
  IF only MEDIUM/LOW:
    verdict = "PASS_WITH_FINDINGS"
    LOG findings for tracking
    PROCEED (non-blocking but documented)

ELSE:
  # No SAST pattern matches — still run verification loop for dependencies + secrets
  sec_verification = sec_verification_loop(phase, source_files)
  
  execution_blockers = COLLECT findings FROM sec_verification WHERE status == "BLOCKER"
  
  IF execution_blockers.length > 0:
    verdict = "BLOCKED"
    FOR EACH blocker IN execution_blockers:
      SHOW: "{blocker.finding} — {blocker.remediation}"
    RETURN to DEV for fix loop
  
  verdict = "CLEAN_PASS"
```

---

## Step 1.5: Static Mock Compliance Check

Execute AFTER all phases complete (post-Phase C).

```yaml
FOR EACH mock.html file related to feature:
  
  Step 1: Load mock expectations
    PARSE mock.html → extract expected DOM structure, CSS classes, ARIA attributes
  
  Step 2: Compare with implementation
    DIFF mock expectations vs actual rendered output
    CHECK: All mock interactions have corresponding code
    CHECK: All error states from mock are handled
  
  Step 3: Report discrepancies
    IF structural differences found:
      CLASSIFY: cosmetic (WARNING) vs functional (BLOCKER)
      Cosmetic: minor spacing, slightly different class names
      Functional: missing components, wrong interactions, broken accessibility
  
  Step 4: Resolution
    IF BLOCKER discrepancies:
      DEV fixes to match mock
      RE-RUN check
```

---

## Step 2: Visual Inspection Gate

Execute AFTER Static Mock Compliance passes.

```yaml
Step 2.1: Environment Check
  IF DEVOPS environment available (dev/staging):
    SUGGEST: "Deploy to {DEV_ENV} for visual verification"
    SUGGEST: "DEVOPS --deploy {ID} --env {DEV_ENV}"
  ELSE:
    PROCEED with static analysis only
    LOG: "Visual inspection deferred — no environment available"

Step 2.2: Journey Walkthrough
  FOR EACH scenario in spec.feature:
    TRACE user journey through implementation:
      1. Start at entry point (from navigation_map.md)
      2. Follow each Given/When/Then step
      3. Verify UI state matches mock at each step
      4. Verify data flows match user_journey.md schemas

Step 2.3: Graceful Degradation
  VERIFY:
    - Loading states shown during async operations
    - Error boundaries catch component failures
    - Offline/degraded mode handling (if applicable)
    - Empty states for lists/tables with no data
```

---

## Step 3: Build Finalization

Execute AFTER all phases verified + mock compliance + visual inspection.

### 3.1: Generate Review Report
```yaml
CREATE docs/spec/{FEATURE_ID}/peer_review_{timestamp}.md:
  - Summary of all REVIEW findings per phase
  - Resolved blockers
  - Remaining warnings (with justifications)
  - Code quality metrics
```

### 3.2: Generate Security Audit
```yaml
CREATE docs/spec/{FEATURE_ID}/sec_audit.md:
  - SAST scan results per phase
  - Resolved vulnerabilities
  - Remaining findings (MEDIUM/LOW with risk acceptance)
  - Compliance status per security_policy.md
```

### 3.3: Update dev_plan.md
```yaml
UPDATE dev_plan.md frontmatter:
  status: IMPLEMENTED_AND_VERIFIED
  review_status: PASSED (or PASSED_WITH_WARNINGS)
  sec_status: PASSED (or PASSED_WITH_FINDINGS)
  completed_at: {ISO_8601}
  all tasks: [x] marked
```

### 3.4: Pre-Finalization Checklist (15 Items)
```yaml
VERIFY before marking complete:
  [ ] 1. All dev_plan.md tasks marked [x]
  [ ] 2. Zero BLOCKER findings from REVIEW
  [ ] 3. Zero CRITICAL/HIGH findings from SEC
  [ ] 4. All tests passing (unit + integration + E2E)
  [ ] 5. Test coverage meets threshold from testing.md
  [ ] 6. No TODO/FIXME in business-critical code
  [ ] 7. All contracts implemented (OpenAPI/GraphQL/gRPC/AsyncAPI)
  [ ] 8. Schema compliance verified (user_journey.md)
  [ ] 9. Protected paths not violated
  [ ] 10. Traceability comments present in generated files
  [ ] 11. .env.example updated with all required variables
  [ ] 12. No cross-domain direct imports (contract-first)
  [ ] 13. Vision fidelity verified (if frontend)
  [ ] 14. Design materialization fidelity verified (shared components + ADR bindings)
  [ ] 15. Peer review report generated
  [ ] 16. Security audit report generated
```

### 3.5: CIP Update (Codebase Inventory)
```yaml
FUNCTION update_codebase_inventory_on_build(FEATURE_ID):
  READ config/codebase_inventory.json
  
  # Transition PLANNED → IMPLEMENTED for this feature's artifacts
  FOR EACH artifact IN registry WHERE status == "PLANNED" AND feature_id IN feature_ids:
    UPDATE status: "IMPLEMENTED"
    UPDATE path: actual_file_path (may differ from projected path)
  
  # Register NEW artifacts discovered during TDD
  FOR EACH new_artifact discovered during build:
    IF NOT IN registry:
      APPEND to registry:
        name, type, module, path, feature_ids: [FEATURE_ID],
        responsibility, interfaces, status: "IMPLEMENTED",
        registered_by: "IMPLEMENT", registered_at: {ISO_8601}
  
  # Update multi-feature artifacts
  FOR EACH artifact IN registry WHERE REUSE decision applies:
    IF FEATURE_ID NOT IN artifact.feature_ids:
      APPEND FEATURE_ID to artifact.feature_ids
  
  UPDATE registry.last_updated
  SAVE config/codebase_inventory.json
```

### 3.6: Lock Cleanup
```yaml
DELETE .context/locks/feature-{FEATURE_ID}.lock
LOG: "Feature lock released"
```

### 3.7: Draft PR
```yaml
EXECUTE Post-Command Commit Prompt (if files modified)
CREATE Draft PR:
  Title: feat({FEATURE_ID}): {description}
  Body: Links to spec, design, test_plan, dev_plan
  Status: DRAFT (during build) → Ready for Review (after build completes)
```

### 3.8: Smart Redirect
```yaml
# Return to Factory — Smart Redirect Protocol computes next steps
# from artifact frontmatter state. Agents NEVER hardcode suggestions.
RETURN_TO_FACTORY(FEATURE_ID)
# Factory executes: compute_feature_state → compute_next_actions → render_next_steps
```

---

## Templates Reference

```yaml
Templates available for generation:
  Template A: dev_plan.md (implementation plan with phases)
  Template B: peer_review_{timestamp}.md (REVIEW hat report)
  Template C: sec_audit.md (SEC hat report)
  Template D: Phase-specific task checklist
  Template E: Test file scaffolding (per framework)
  Template F: API client generation (from contract)
  Template G: Component scaffolding (from mock extraction)
  Template H: Migration file scaffolding

Snippets:
  Snippet 1: Traceability header comment
  Snippet 2: TDD cycle template
  Snippet 3: adapter pattern scaffolding

Config:
  review_config.json: Configures which checks are BLOCKER vs WARNING per project
```
