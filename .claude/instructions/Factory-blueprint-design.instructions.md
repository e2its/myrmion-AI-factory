---
description: "Factory BLUEPRINT technical design — architecture, API contracts, test plan, OpenAPI/GraphQL/gRPC/AsyncAPI generation. Use when: BLUEPRINT --start or --refine execution."
applicable_when:
  phase: [BLUEPRINT]
  command: [blueprint]
---

# BLUEPRINT Agent — Design & Artifact Generation (Phases 0-2)

## Purpose
This instruction file defines the **Pre-Flight, Analysis, and Artifact Generation** protocols for the BLUEPRINT agent (🏗️ ARCH Hat + 🧪 QA Hat co-design). BLUEPRINT produces the technical design and test plan simultaneously, with cross-pollination: ARCH contracts inform QA test cases, QA edge cases refine ARCH error handling.

---

## Hat-Switching Rules

| Topic | Hat |
|-------|-----|
| Patterns, layers, contracts, C4, ADRs | 🏗️ ARCH |
| Testing strategy, edge cases, coverage, WCAG | 🧪 QA |
| Schemas, contract-to-test mapping, integration | Both |

---

## Required Inputs (13 Sources)

| Source | Status | Purpose |
|--------|--------|---------|
| `spec.feature` | APPROVED (mandatory) | Gherkin scenarios for design; `scope` and `consumes_contract` frontmatter |
| `user_journey.md` (or `user_journey.integration.md` for scope in [backend-only, integration]) | APPROVED (mandatory) | Data Schemas (source of truth for contracts); integration variant adds § 5 External Systems contract_slug backfill + § 6 Reliability Contract |
| `mock.html` | APPROVED (mandatory for scope in [full-stack, frontend-only]; N/A for backend-only/integration) | Visual reference for component architecture |
| Global UX Vision (`docs/ux/vision/`) | APPROVED (if scope in [full-stack, frontend-only]) | App shell, style guide, components, nav map |
| External Design System (`docs/ux/design-system/`) | If exists AND scope in [full-stack, frontend-only] | DS tokens, component library |
| `design_ux.md` (legacy) | If exists AND scope in [full-stack, frontend-only] | Legacy UX decisions |
| Governance rules (20+ files from `.claude/rules/`) | All applicable | Architecture, security, testing constraints |
| Protected code (`protected-paths.json`) | If exists | RED ZONE boundaries |
| `system_resources.json` | If exists | External integrations reference |
| `ux_decisions_log.md` | If exists AND scope in [full-stack, frontend-only] | Cross-feature UX decisions |
| @workspace | Always | Existing code patterns |
| `codebase_inventory.json` | If exists | DRY enforcement |
| **Upstream frozen contracts** | Mandatory when `spec.feature.consumes_contract` is non-empty | For each `FEAT-XXX` in `consumes_contract`: load the frozen contract file (OpenAPI / AsyncAPI / GraphQL / gRPC) from `contracts/*/FEAT-XXX/**`; this design MUST NOT redefine or extend those contracts. Resolution step below BLOCKS if any referenced upstream is not frozen. |

---

## Generated Outputs (9 Artifact Types)

1. **`design.md`** — Technical design (contracts, C4, component inventory, infra needs)
2. **`test_plan.md`** — Test strategy (acceptance, edge cases, integration, WCAG)
3. **`adr/`** — Architecture Decision Records for significant decisions
4. **OpenAPI 3.1 YAML** — `contracts/openapi/{SLUG}/v1.yaml` (REST APIs)
5. **GraphQL SDL** — `contracts/graphql/{SLUG}/schema.graphql` (GraphQL)
6. **AsyncAPI 2.6+** — `contracts/asyncapi/{SLUG}/asyncapi.yaml` (Event-based)
7. **gRPC Proto3** — `contracts/grpc/{SLUG}/service.proto` (gRPC)
8. **`feature_map.md`** — Cross-reference CONTRACT_SLUG → Feature ID → spec
9. **`increment_plan.md`** — Sidecar manifest of vertical increments (each = 1 PR that leaves product 100% functional); consumed by IMPLEMENT `--plan`

**Contract Slug Convention:** `{domain}-{capability}` in kebab-case. Stored as `x-feature-id` in contract metadata.

---

## Governance Context Loading (Steps 0-5)

### Step 0: Governance Snapshot Recovery (summarization-safe)
- READ `.context/governance_snapshot.md` (file-based, survives summarization)
- Compare `constitution_hash` in snapshot vs MD5 of `docs/constitution.md`
- If snapshot valid → governance loaded (1 file read). If stale/missing → full reload Steps 1-4 + regenerate snapshot
- See `governance-loading.md` Step 0 for full protocol

### Step 1: Load Constitution & Governance Index
- Parse stack (backend.runtime, frontend.framework, architecture, topology)
- Parse `<!-- METADATA -->` comments for rule applicability
- If Governance Index missing or PLACEHOLDER → BLOCK

### Step 2: Feature Context
- Detect feature language, stack from current files
- NOT used for rule filtering (project-level rules apply to ALL features)

### Step 3: Query Applicable Rules
- Technology-specific: load ONLY if file exists (file existence = stack match)
- All other rules: load unconditionally

### Step 4: Load Validation Templates
- Check `.context/validation_templatesBLUEPRINT_VALIDATION_TEMPLATE.md`
- Merge with applicable rules

### Step 5: Script-Based Validation Registry
- Mandatory scripts: `dependency-allowlist.sh`, `security-scan.sh`
- Conditional scripts based on stack (e.g., `validate-iac.sh` if iac_tool != None)

### Step 6: Defect Prevention Consultation

```yaml
# Consult the Defect Prevention Catalog filtered to this agent
feature_scope = READ("docs/spec/{FEATURE_ID}/spec.feature").frontmatter.scope OR "full-stack"   # pass to DPC Filter 2
applicable_dcs = consult_defect_catalog("BLUEPRINT", {feature_id: FEATURE_ID, feature_scope: feature_scope, stack: setup_md.stack})
STORE applicable_dcs IN context FOR use by Section 7 (GCD) and Section 4 (test_plan Edge Cases)

# Advisory projection: every applicable DC becomes an explicit design constraint
# and an explicit test-plan edge case. Blocking enforcement happens at --approve.
LOG: "BLUEPRINT DC consult: {applicable_dcs.length} entries applicable to this feature"
```

See `.claude/rules/defect-prevention.md` § Mandatory Process Integration § 2 for the canonical consultation protocol. The list is consumed during Section 7 (GCD) generation and the QA test plan (§ QA Test Plan Generation — Edge Cases section) and is enforced at `--approve` time (see the `--approve` gate below).

---

## Execution Guardrails

### CANCELLED Verification
- If `design.md` or `test_plan.md` has `status: CANCELLED` → HARD BLOCK

### Feature Concurrency Prevention
- Lock: `.context/locks/feature-{{FEATURE_ID}}.lock`
- BLOCK if lock exists (another agent working on this feature)

### Mandatory Branching
- Must be on `feature/{{FEATURE_ID}}-*` branch. BLOCK if on protected branch.

### Downstream Iteration Detection (v1.0.0 Dual-Source)
```yaml
# Source A: Pull-based comparison
pull_gap = (spec.iteration > design.based_on_iteration)

# Source B: Push-based cascade
push_gap = (design.pending_iteration IS NOT NULL AND design.pending_iteration > design.based_on_iteration)

has_gap = pull_gap OR push_gap

IF has_gap:
  PROMPT: Iteration gap detected. Options: DELTA / FULL / SKIP
  IF DELTA or FULL: Clear pending_iteration after sync. Execute CASCADE_PENDING_ITERATION to downstream.
```

### UX Artifacts Enrichment (5-Step Protocol — Before Design)
1. **Mock Visual Baseline**: Extract component tree, interaction points, data bindings from mock.html
2. **Global UX Vision**: Load app_shell.html, style_guide.html, page_templates.html, component_library.html, navigation_map.md
3. **External Design System**: Load DS tokens from `docs/ux/design-system/`
4. **Legacy UX Artifacts**: Load `design_ux.md` if exists (backward compatibility)
5. **Cross-Feature UX Decisions**: Load `ux_decisions_log.md` for precedent

---

## Command `--start {{ID}}` — Phase 0: Pre-Flight

### Consumes-Contract Resolution Gate (BLOCKING, runs FIRST in pre-flight)

```yaml
FUNCTION consumes_contract_resolution_gate(FEATURE_ID):
  spec = READ("docs/spec/{FEATURE_ID}/spec.feature")
  upstream_features = spec.frontmatter.consumes_contract OR []

  IF upstream_features IS EMPTY:
    LOG: "No upstream contract dependencies declared"
    RETURN { resolved: [] }

  # Gate-mode resolution — same precedence as IMPLEMENT --plan Consumes-Contract Upstream Freeze Gate
  # and Next-Task Resolver Step 1.3.4.5: enforce (hard block) | warn (log + proceed) | off (skip).
  # Source: governance_snapshot.setup_configuration.project_tracking.gate_enforcement_mode.
  project_tracking = READ(".context/governance_snapshot.md").setup_configuration.project_tracking OR {}
  mode = project_tracking.gate_enforcement_mode OR "enforce"

  resolved = []
  FOR EACH upstream_id IN upstream_features:
    # Step 1 — upstream feature must exist and be in a post-BLUEPRINT state
    upstream_design = READ_IF_EXISTS("docs/spec/{upstream_id}/design.md")
    IF NOT EXISTS upstream_design:
      ❌ BLOCK (humanised): "consumes_contract references {upstream_id} but docs/spec/{upstream_id}/design.md does not exist.
        Resolution: either create the upstream feature first (`/codesign --start {upstream_id}` → `/blueprint --start {upstream_id} --approve`) or remove {upstream_id} from spec.feature.consumes_contract."
      STOP
    IF upstream_design.frontmatter.status NOT IN ["APPROVED", "IMPLEMENTED_AND_VERIFIED"]:
      ❌ BLOCK (humanised): "consumes_contract references {upstream_id} but its design.md is in status `{upstream_design.status}`, not APPROVED.
        Contract freeze requires upstream to be at least APPROVED. Resolution: wait for `/blueprint --approve {upstream_id}` or drop the dependency."
      STOP

    # Step 2 — upstream scope cannot be frontend-only (frontend-only has no own contract to consume)
    #         Symmetric with IMPLEMENT --plan Consumes-Contract Upstream Freeze Gate Step 2
    #         and Next-Task Resolver Step 1.3.4.5 check (b).
    upstream_scope = READ_IF_EXISTS("docs/spec/{upstream_id}/spec.feature").frontmatter.scope OR "full-stack"
    IF upstream_scope == "frontend-only":
      ❌ BLOCK (humanised): "consumes_contract references {upstream_id} but its scope is `frontend-only` — frontend-only features have no own contract to consume.
        Resolution: point consumes_contract at the backend feature that owns the contract (trace upstream → backend dependency), or remove this entry."
      STOP

    # Step 3 — locate frozen contract files
    contract_files = GLOB("contracts/{openapi,graphql,grpc,asyncapi,webhooks}/**/{upstream_id}*/**/*.{yaml,yml,graphql,proto}")
    contract_files += GLOB("contracts/{openapi,graphql,grpc,asyncapi,webhooks}/**/{CONTRACT_SLUG_OF(upstream_id)}/**/*.{yaml,yml,graphql,proto}")
    contract_files += GLOB("docs/spec/{upstream_id}/contracts/**/*.{yaml,yml,graphql,proto}")
    IF contract_files IS EMPTY:
      ❌ BLOCK (humanised): "consumes_contract references {upstream_id} (status: APPROVED, scope: {upstream_scope}) but no frozen contract files found.
        Expected at least one file under contracts/{openapi|graphql|grpc|asyncapi|webhooks}/<slug-of-{upstream_id}>/ or docs/spec/{upstream_id}/contracts/.
        Resolution: verify the upstream BLUEPRINT produced contract artefacts."
      STOP

    # Step 4 — CONTRACT-FREEZE gate closed + not stale (full-sdlc preset only)
    #         Symmetric with IMPLEMENT --plan Consumes-Contract Upstream Freeze Gate Step 3
    #         and Next-Task Resolver Step 1.3.4.5 checks (c-e). Honours gate_enforcement_mode.
    IF project_tracking.feature_phases == "full-sdlc":
      ADAPTER = READ "docs/backlog/tool-adapter.md"
      freeze_issue = ADAPTER.query_board() → find WHERE labels CONTAINS "phase:contract-freeze" AND title CONTAINS upstream_id

      IF freeze_issue IS NULL:
        IF mode == "enforce":
          ❌ BLOCK (humanised): "Upstream {upstream_id} has no CONTRACT-FREEZE issue on the board (full-sdlc preset expects one).
            Resolution: run `BACKLOG --plan-feature {upstream_id}` to materialise the 8-phase preset, then close its CONTRACT-FREEZE issue."
          STOP
        ELSE IF mode == "warn":
          ⚠️ WARN: "Upstream {upstream_id} has no CONTRACT-FREEZE issue (mode=warn). Proceeding under soft-landing; downstream cascade risk accepted."
        # mode == "off": silent
      ELSE IF freeze_issue.status != "Done":
        IF mode == "enforce":
          ❌ BLOCK (humanised): "Upstream {upstream_id} CONTRACT-FREEZE issue is not Done (status: {freeze_issue.status}).
            Downstream design cannot safely bind to a not-yet-frozen upstream contract.
            Resolution: complete `BLUEPRINT --approve {upstream_id}` and move its CONTRACT-FREEZE issue to Done, then re-run `BLUEPRINT --start {FEATURE_ID}`."
          STOP
        ELSE IF mode == "warn":
          ⚠️ WARN: "CONTRACT-FREEZE issue for {upstream_id} is not Done (status: {freeze_issue.status}). Proceeding under mode=warn — upstream contract may still change before freeze."
        # mode == "off": silent
      ELSE IF "stale-after-cascade" IN freeze_issue.labels:
        IF mode == "enforce":
          ❌ BLOCK (humanised): "Upstream {upstream_id} CONTRACT-FREEZE is stale (label: stale-after-cascade) — an upstream iteration invalidated the contract.
            Resolution: run `BLUEPRINT --refine {upstream_id}` to re-sync its contracts, then re-close the CONTRACT-FREEZE issue (removing the stale label)."
          STOP
        ELSE IF mode == "warn":
          ⚠️ WARN: "Upstream {upstream_id} CONTRACT-FREEZE is stale-after-cascade (mode=warn). Proceeding on superseded contract — CASCADE_PENDING_ITERATION will fire downstream."
        # mode == "off": silent

    resolved.push({ upstream_id, contract_files, upstream_scope })

  # Persist resolved contracts as read-only references into design.md § 7 (Governance Constraints Digest)
  RETURN { resolved: resolved }
```

**Three-point enforcement symmetry.** This gate, the IMPLEMENT `--plan` Consumes-Contract Upstream Freeze Gate, and the Next-Task Resolver Step 1.3.4.5 filter all check the SAME conditions (a-e) with the SAME gate-mode semantics (enforce/warn/off). A downstream feature that passes BLUEPRINT `--start` here will also pass IMPLEMENT `--plan`'s gate and will be returned as eligible by Next-Task — no redo-loop surprise caused by divergent checks between the three enforcement points.

The gate runs **before** Governance Context Loading (Steps 0-5) so that resolved contracts are available as read-only inputs when ARCH starts designing. It fails LOUDLY with humanised messaging per CLAUDE.md § Governance Rule 8.

### Architecture Context Loading
- Read `docs/constitution.md` for topology (B1-B12), patterns, stack
- Read all applicable rules from `.claude/rules/`
- Read `feature_scope` from `spec.feature` frontmatter — drives section applicability in design.md + test_plan.md and decides whether the UX Artifacts Enrichment 5-step protocol runs
- Detect project type: greenfield vs brownfield, monolith vs distributed

### Review Configuration
- Load review criteria from constitution.md
- Set up ARCH + QA validation checklists

### Immutability Validation
- Check `.claude/rules/immutability_policy.md`
- Validate no changes attempted on frozen artifacts

### Parent Version Detection
- If spec.feature references a parent feature (e.g., `parent: AUTH-001`)
- Load parent's design.md for architectural context continuity

---

## Command `--start {{ID}}` — Phase 1: Analysis & Clarification

### ARCH Context Analysis (🏗️ hat)
- Analyze spec.feature scenarios for architectural implications
- Map scenarios to component architecture
- Identify integration points (external systems, cross-domain deps)
- Assess complexity and propose patterns

### QA Critical Analysis (🧪 hat)
- Analyze spec.feature for testability  
- Identify edge cases not covered by scenarios
- Assess security testing needs
- Plan acceptance test structure

### BLUEPRINT Clarification Protocol ("The Loop")
- If ambiguities found in spec/journey/mock: ask 1-to-1 RDR questions
- Each question: Recommendation → Decision → Ratification → Save → Next
- Maximum 5 clarification questions before proceeding

---

## Command `--start {{ID}}` — Phase 2: Artifact Generation

### Step -2: CIP Codebase Artifact Inventory Scan (MANDATORY)

**Sub-step -2a: Load Inventory & Topology**
```yaml
inventory = READ("config/codebase_inventory.json")
IF NOT EXISTS:
  ⚠️ WARN: "Codebase inventory not found. Reuse analysis skipped."
  LOG CIP_SKIPPED in worklog
  IF docs/setup.md has materialization_complete: true:
    ⚠️ ADVISORY: "Inventory should exist. Consider: SETUP --reconcile-inventory"
  SKIP to Phase 2 artifact generation (no reuse analysis possible)
topology = READ(constitution.md, "architecture.topology")
```

**Sub-step -2b: Extract Planned Artifacts**
- From spec.feature scenarios: services, controllers, repositories
- From user_journey.md schemas: domain entities, DTOs
- From mock.html: UI components
- Each artifact: name, type, module, projected_path, responsibility

**Sub-step -2c: Domain-Aware Reuse Analysis**
For each planned artifact:
```yaml
reuse_category = classify_artifact_reuse_category(type, module, topology)
  # SHARED: ui_component, utility, middleware, guard, pipe, hook → cross-domain OK
  # DOMAIN_INTERNAL: service, entity, repository, adapter → DDD isolation
  # MODULE: controller, module → depends on architecture

# Domain Isolation Gate
IF both planned + existing are DOMAIN_INTERNAL AND different_module:
  → NOT a DRY violation (DDD boundary)
  → Only flag if identical name (CROSS_DOMAIN_COLLISION)

# 4-Criteria Matching (O(1) JSON lookup, no file scanning)
candidates = find_inventory_matches(planned_artifact, topology):
  1. EXACT_MATCH: name + type identical (confidence: 1.0)
  2. SAME_DOMAIN: same module + same type (confidence: 0.8)
  3. NEAR_DUPLICATE: >60% responsibility overlap (confidence: overlap score)
  4. NAME_SIMILAR: Levenshtein distance <3, same type (confidence: 0.5)
```

**Sub-step -2d: RDR per Reuse Candidate (1-to-1, NEVER batch)**
- For SHARED / same-domain matches: REUSE / EXTEND / CREATE_NEW (with mandatory ADR)
- For CROSS_DOMAIN_COLLISION: RENAME / SHARED_KERNEL (with ADR) / KEEP_BOTH (with ADR)

**Sub-step -2e: Summary**
- Log all decisions in `design.md Section 0: "Reuse Analysis"`

### Step -1: Existing Endpoint Inventory Scan (MANDATORY)

**Sub-step -1a: Full Contract Scan**
- Scan 100% of existing contracts across ALL directories:
  - `contracts/openapi/` → REST endpoints
  - `contracts/graphql/` → GraphQL operations
  - `contracts/grpc/` → gRPC services
  - `contracts/asyncapi/` → Event channels
- Build complete endpoint inventory

**Sub-step -1b: Reuse Analysis**
- Compare needed capabilities (from spec.feature scenarios) against existing endpoints
- Match by: path pattern, operation semantics, data schema overlap
- For each needed capability: REUSE / EXTEND / NEW_ENDPOINT assessment

**Sub-step -1c: Reuse Decision (RDR per candidate)**
- Each candidate gets individual RDR decision
- Document in design.md

**Sub-step -1d: Inventory Summary**
- Summary of endpoints to REUSE, EXTEND, and CREATE

### Step -0.5: Inter-Domain Dependency Analysis (MANDATORY)

**Step A**: Extract ALL cross-domain/module dependencies from spec.feature and user_journey.md
**Step B**: Classify each as sync (REST/GraphQL/gRPC), async (AsyncAPI), or webhook (inbound/outbound) based on topology + communication_style + webhooks setting from constitution.md
**Step C**: Verify contract existence per dependency (scan contracts/ directory, including contracts/webhooks/)
**Step D**: Generate `design.md Section 4: "Cross-Domain Dependencies"` table with: dependency, type (sync/async/webhook-in/webhook-out), contract_ref, status (EXISTS/MISSING/PENDING)

### Contract Generation (MANDATORY)

**Step 0**: Determine required formats from constitution.md:
- `backend.communication_style` → REST → OpenAPI, GraphQL → SDL, gRPC → Proto3
- If topology is event-based (B3, B6, B7, B11) → ALSO generate AsyncAPI
- If `backend.webhooks` != None → ALSO generate webhook contracts:
  - Inbound → OpenAPI 3.1 `paths:` in `contracts/webhooks/inbound/{SLUG}/v1.yaml`
  - Outbound → OpenAPI 3.1 `webhooks:` section in `contracts/webhooks/outbound/{SLUG}/v1.yaml`

**Step 2pre**: Derive CONTRACT_SLUG per `contract-first-policy.md`:
- Format: `{domain}-{capability}` in kebab-case
- Example: `auth-login`, `order-management`, `notification-email`

**Step 2a**: CREATE contract file(s) following spec + rules:
- OpenAPI 3.1: paths, schemas, responses, error codes
- GraphQL SDL: types, queries, mutations, subscriptions
- AsyncAPI 2.6+: channels, messages, schemas
- gRPC Proto3: service definitions, message types
- Webhook inbound: OpenAPI 3.1 paths with payload schemas + signature security scheme
- Webhook outbound: OpenAPI 3.1 `webhooks:` section with event payload schemas

**Step 2b**: Inline metadata in each contract:
- `x-feature-id: {{FEATURE_ID}}`
- `x-contract-slug: {{SLUG}}`
- `x-generated-by: BLUEPRINT`

**Step 2c**: Update `contracts/feature_map.md`:
- Add row: SLUG → Feature ID → contract path → spec reference

**Step 2d**: Reference contracts in design.md Section 3

### Schema Derivation Policy
- **Source of truth**: `user_journey.md` Data Schemas
- **Technical fields FREE**: id, created_at, updated_at, version, audit fields → ARCH adds freely
- **Business fields LOCKED**: Any field from journey schemas → ARCH formalizes but does NOT invent
- **If ARCH needs a business field not in journey** → RDR explaining why → If approved, update journey schemas
- **Cross-Layer Type Mapping Table**: MANDATORY in design.md — maps journey types → API types → DB types → UI types

### Infrastructure Needs Declaration (design.md Section 5)
```yaml
infrastructure_needs:
  resources:
    - name: "resource_name"
      type: "database | cache | queue | storage | function | service | static_site"
      engine: "resource-type-specific; derived from constitution and ARCH decisions"
      scope: "feature | shared"
      data_bearing: true | false
      sizing:
        min: "description"
        recommended: "description"
  
  # For static_site resources (frontend SPA/SSR/SSG):
  # framework, build_command, output_dir, base_path, ssr (true|false)
  
  # For B9 (Serverless) projects, function resources include:
  # handler, runtime, memory, timeout, trigger, contract_slug, endpoints
  
  external_integrations:
    - name: "integration_name"
      direction: "inbound | outbound | bidirectional"
      protocol: "REST | GraphQL | gRPC | WebSocket | SMTP"
      contract_ref: "contracts/openapi/slug/v1.yaml"
  
  constraints:
    - "description of infrastructure constraint"
  
  # Frontend Hosting Declaration (for projects with frontend.framework != None)
  # ARCH MUST declare a static_site resource when the constitution specifies a frontend framework.
  # Without this declaration, DEVOPS has no vocabulary to provision frontend hosting.
  # See: Frontend Hosting Auto-Declaration section below for the auto-generation protocol.
  # Additional fields for static_site: framework, build_command, output_dir, base_path, ssr
  # All values derived from constitution or asked via RDR — never hardcoded.

  # Synthetic Data Declaration (for staging/preview environments)
  # ARCH must declare if this feature requires seeded data for non-production.
  # This feeds IMPLEMENT C.5 (Synthetic Data Protocol) and DEVOPS (Seed Pipeline).
  staging_data:
    required: true | false
    entities:
      - name: "{entity_name}"
        owns: true | false           # true = this feature creates the seed fixture
        consumes_from: "{FEATURE_ID or _shared}"  # if owns: false
        estimated_count: N            # records needed for realistic staging
        fk_dependencies: ["{parent_entity_1}", "{parent_entity_2}"]
    notes: "Any special considerations (offline sync states, temporal data, etc.)"
```

### Section 6: Frontend UI Contract (MANDATORY — if frontend.framework != "None") (v2.4.0)

> **Purpose:** Bridge the gap between UX Vision artifacts (mock.html, style_guide.html, component_library.html) and IMPLEMENT Phase B. Without this section, developers build components with generic utility classes instead of reproducing the mock's precise visual design. This section produces an actionable, machine-readable contract that Phase B MUST follow.
>
> **Prerequisites:** UX Vision APPROVED, mock.html APPROVED, component_library.html loaded.
> **When to generate:** After completing Section 5 (Infrastructure Needs), before Section 7 (GCD).

```yaml
FUNCTION generate_frontend_ui_contract(FEATURE_ID, mock_html, vision_artifacts):
  # Produces design.md Section 6 with 6 sub-sections.
  # The contract maps mock.html visual design → implementation-ready specifications.
  # IMPLEMENT Phase B.0 / Step 0c.1 materializes the CSS foundation from this contract.
  # IMPLEMENT Phase B builds components using this contract's mapping tables.
```

#### 6.1 Design Token Catalog

Read the `:root {}` block from `mock.html` and classify every CSS custom property:

```yaml
token_categories:
  SCALE_TOKEN: color palette values (e.g., --primary-950..100, --accent-*)
  SEMANTIC_TOKEN: purpose-named aliases (e.g., --bg-page, --bg-card, --border, --color-primary)
  TYPOGRAPHY_TOKEN: font families, sizes (e.g., --font-sans, --font-size-xs..2xl)
  SPACING_TOKEN: spacing, radii (e.g., --spacing-xs..xl, --radius-sm..full)
  EFFECT_TOKEN: shadows, glows (e.g., --shadow-sm..lg, --shadow-glow)

OUTPUT:
  token_mapping_table: | Mock Token | Value | CSS Framework Key | Usage |
  semantic_alias_table: | Semantic Purpose | Mock Variable | Framework Class | Value Source |
```

#### 6.2 Layout Contracts

Extract the DOM structure and CSS classes for each layout type used by the feature:

```yaml
FOR EACH layout_type IN mock_html (auth_layout, app_layout, dashboard, etc.):
  EXTRACT:
    dom_contract: root → child nesting chain with CSS classes
    css_mapping: each CSS class → equivalent framework utility classes
    responsive_contract: breakpoint-specific overrides
  OUTPUT as structured table per layout type
```

#### 6.3 Component Class → CSS Framework Mapping

The **core** of the UI Contract. For every CSS class in `mock.html`:

```yaml
FOR EACH css_class IN mock_html (excluding implementation-prefixed classes):
  PRODUCE: | Mock CSS Class | Framework Equivalent | Notes |
  # The framework equivalent is the EXACT set of utility classes that reproduce the visual.
  # IMPLEMENT Phase B MUST use these mappings, not generic alternatives.
  # REVIEW BLOCKER if Phase B uses generic utility guesses instead of this mapping.
```

#### 6.4 Shared UI Components

Cross-reference `mock.html` CSS classes against `component_library.html`:

```yaml
FOR EACH component:
  CLASSIFY: VISION_REUSE (from component_library.html) | FEATURE_ONLY
  DEFINE build_order_contract:
    Phase B.1: Shared primitives (Button, Input, Alert, Card, etc.)
    Phase B.2: Auth/feature-specific compositions
    Phase B.3: App shell compositions (Layout, Sidebar, Header)
    Phase B.4: Feature pages (composed from B.1-B.3 components)
  FOR EACH shared primitive:
    LIST: variants, props, mock_classes reference
```

#### 6.5 Page Composition Contracts

For each page/step in the mock:

```yaml
FOR EACH page_section IN mock_html:
  DEFINE:
    composition_tree: which shared components compose this page
    states: [default, loading, error, empty, + feature-specific states]
    state_rendering_pattern: conditional rendering order
```

#### 6.6 Required CSS Additions

Identify CSS property sets from `mock.html` that are NOT expressible as single utility classes:

```yaml
OUTPUT: list of @layer components entries needed in globals.css
  # These bridge mock.html CSS → framework-aware CSS
  # ADDITIVE: Phase A.0 MUST merge into globals.css without removing existing tokens
```

---

### Section 7: Governance Constraints Digest (GCD) Generation (MANDATORY — v2.3.0)

> **Purpose:** BLUEPRINT has already loaded ALL applicable governance rules (Steps 0-5). Instead of IMPLEMENT re-loading the same 20+ rule files independently, BLUEPRINT emits a pre-digested, feature-scoped constraint set into `design.md Section 7`. IMPLEMENT reads ONE section and gets everything it needs for DEV + REVIEW + SEC hats.
>
> **When to generate:** After completing Section 6, before finalizing `design.md`.
> **Format:** Inline markdown table + YAML blocks. NEVER prose. Machine-readable IDs for each constraint.

```yaml
FUNCTION generate_governance_constraints_digest(FEATURE_ID, stack_context, governance_context):
  # Reads the SAME governance context already loaded by BLUEPRINT (Steps 0-5).
  # Produces design.md Section 7 with 7 sub-sections.
  # No additional file reads — reuses what's already in memory.
```

#### 7.1 Architecture Constraints → REVIEW [ARCH]

Extract from `constitution.md`: topology code, layer ordering, module boundary rules, extension strategy. Produce `module_boundaries_table` and `forbidden_patterns` list.

#### 7.2 Governance Rules Index → REVIEW [GOV]

Compact extraction of actionable constraints from each applicable governance rule file. Each entry: Rule ID, Source file, Key constraints. Stack-conditional rules that don't match are listed under `not_applicable`.

#### 7.2b Shared Cross-Cutting Components → REVIEW [GOV-SHARED]

When a governance rule mandates a shared mechanism (middleware, base class, interceptor), extract it as an explicit implementation requirement. Each entry: id, rule_source, component_type, name, location, responsibility, enforcement level.

**Governance mechanism rule:** Satisfying a constraint by inlining logic in each module is a REVIEW BLOCKER `[GOV-SHARED-INLINE]`.

#### 7.3 SAST Patterns → SEC Hat

Pre-compile stack-specific SAST patterns so SEC hat does not re-derive them. Each pattern: id, description, detection pattern, CWE, severity, OWASP category.

#### 7.4 Schema Constraints → REVIEW [SCHEMA]

Extract from `user_journey.md` Data Schemas. Business fields are LOCKED. Technical fields (id, timestamps, audit) are exempt.

#### 7.5 Contract-First Rules → REVIEW [CFP]

Extract from design.md Section 3 (Contracts). Contract paths, forbidden direct cross-module imports.

#### 7.6 UX Constraints → REVIEW [UX]

Conditional on `frontend.framework != "None"`. Vision artifact requirements, touch target minimums, WCAG level, component reuse mandate, feature nav placement.

#### 7.7 Coding Standards → DEV Hat

Extract from stack-specific rule + constitution: naming patterns, module structure, test file patterns, key lint rules.

#### GCD Finalization

```yaml
AFTER generating all sub-sections:
  gcd_hash = governance_snapshot.frontmatter.constitution_hash[:8]
  UPDATE design.md frontmatter:
    governance_digest_generated: true
    governance_digest_version: "{gcd_hash}"
  SAVE via IPP section-atomic save

RELIABILITY:
  - Same-source: GCD reuses governance context already loaded by BLUEPRINT (Steps 0-5)
  - Hash-validated: IMPLEMENT Step 0b compares digest hash against current snapshot
  - Graceful degradation: If Section 7 absent, IMPLEMENT loads governance from raw files
```

---

### Extension Strategy Sections (Brownfield Projects)

**E0 (Native Extension)**: Governance overlay alongside existing code. No adapter layer.

**E1 (Preserve + Wrapper)**: ACL/Facade patterns. Design includes:
- Wrapper interface definitions
- Data transformation mappings (legacy ↔ new)
- Adapter component specifications

**E2 (Strangler Fig)**: Progressive replacement. Design includes:
- Router configuration (which routes go to legacy vs new)
- Dual-write patterns for data consistency
- Feature toggle specifications
- Migration sequence (which modules first)

### Integration ACL Strategy (Distributed Backends)
- BackendAggregatorACL: single API gateway aggregating multiple backend services
- Per-service client definitions
- Circuit breaker configuration
- Fallback behavior specifications

### External System Adapters
For each external system identified in `user_journey.md Section 5`:
- Adapter interface definition
- Error handling strategy (timeout, retry, circuit breaker)
- Data transformation (external format ↔ internal format)
- Mock/stub specification for testing

### Frontend Hosting Auto-Declaration (MANDATORY when frontend.framework != None)

```yaml
# RULE: If frontend.framework != None, BLUEPRINT MUST auto-declare a static_site resource in design.md Section 5.

FUNCTION auto_declare_frontend_resource():
  frontend_framework = READ constitution.md → frontend.framework
  IF frontend_framework == None OR frontend_framework == "None":
    RETURN  # No frontend → no resource needed

  # Check if a static_site resource already exists in resources[]
  existing = resources[].find(r => r.type == "static_site")
  IF existing:
    RETURN  # Already declared (e.g., by explicit ARCH decision)

  # Read available constitution fields (all populated by SETUP discovery + materialization)
  cloud_provider = READ constitution.md → infrastructure.cloud_provider
  iac_tool = READ constitution.md → infrastructure.iac_tool
  frontend_pattern = READ constitution.md → frontend.pattern
  meta_framework = READ constitution.md → frontend.meta_framework

  # Derive rendering mode from frontend.pattern (discovered in SETUP Q11)
  # F1=SPA, F2=SSR+hydration, F3=SSR pure, F4=ISR, F9=PWA, F10=Component-Driven → all derivable
  ssr = frontend_pattern IN ["F2", "F3", "F4"]  # SSR-capable patterns

  # ARCH proposes hosting engine via RDR based on constitution fields.
  # There are NO hardcoded engine mappings — the agent uses cloud_provider,
  # iac_tool, frontend_pattern, and meta_framework as context to recommend.
  ASK via RDR:
    R: "Your project uses {frontend_framework} (pattern {frontend_pattern}) on {cloud_provider}.
        I recommend a frontend hosting setup appropriate for {'SSR' IF ssr ELSE 'SPA/static'} delivery.
        What hosting engine should I declare?"
    D: Wait for user decision → engine
    R: Save engine to resource declaration

  ASK via RDR:
    R: "What is the build command for your frontend? (default: npm run build)"
    D: Wait for user decision → build_command (default: "npm run build")

  ASK via RDR:
    R: "What is the build output directory? (default: dist)"
    D: Wait for user decision → output_dir (default: "dist")

  APPEND to resources[]:
    name: "frontend_app"
    type: "static_site"
    engine: {engine}
    scope: "shared"
    data_bearing: false
    framework: {frontend_framework}
    build_command: {build_command}
    output_dir: {output_dir}
    base_path: "/"
    ssr: {ssr}
    sizing:
      min: "Single-origin hosting"
      recommended: "CDN-backed hosting with CI/CD pipeline"
```

### QA Test Plan Generation (🧪 hat)

**Level 1: Business/Acceptance Tests**
- One test case per spec.feature scenario
- Test ID format: `TC-{SCENARIO_NUMBER}` (e.g., TC-001, TC-002)
- Maps: Scenario → Preconditions → Steps → Expected Result

**Level 2: Technical Tests**
- Negative tests (invalid inputs, boundary values)
- Security tests (injection, XSS, CSRF, auth bypass)
- Performance tests (load, stress if applicable)
- Concurrency tests (if applicable)

**Section 2.1: API Integration Tests**
- Test ID format: `TC-API-{NUMBER}`
- Per contract endpoint: happy path + error paths
- Request/response validation against contract schemas
- Authentication/authorization test coverage

**Section 3: Accessibility Tests**
- WCAG 2.1 AA compliance tests per mock.html page
- Keyboard navigation tests
- Screen reader compatibility
- Color contrast verification

### Cross-Pollination (MANDATORY)
- ARCH contracts → QA generates contract tests
- QA edge cases → ARCH adds error handling to design
- ARCH patterns → QA generates pattern compliance tests
- QA security concerns → ARCH adds security architecture sections

### Increment Plan Generation (MANDATORY)

> **Purpose:** BLUEPRINT declares the vertical slicing strategy IMPLEMENT will follow. Each increment = 1 PR that leaves the product 100% functional and production-deployable on merge. Feature-flag-OFF merges are NOT a valid escape.
> **When:** After Cross-Pollination completes. All upstream artifacts (design.md, test_plan.md, contracts/**) must already be finalized at section-complete granularity.
> **Output:** `docs/spec/{{FEATURE_ID}}/increment_plan.md` (template: `.context/templates/architect/increment_plan_template.md`).

**Step A — Strategy Resolution:**
1. READ `spec.feature` frontmatter field `slicing_strategy` (default `incremental`).
2. IF `slicing_strategy == monolithic`:
   - Run the **Trivial-Heuristic Gate**:
     - `scenarios_count` = number of `Scenario:` / `Scenario Outline:` blocks in spec.feature (exclude `Background:`).
     - `ops_count` = total contract operations across `contracts/**` for this feature (OpenAPI operations + GraphQL root fields + gRPC RPCs + AsyncAPI messages).
     - `scope` = `spec.feature.scope`.
     - Gate passes **only if** `scenarios_count ≤ 2` AND `ops_count ≤ 3` AND `scope != "full-stack"`.
   - IF gate FAILS → BLOCK with humanized message:
     - "This feature is too large for a monolithic plan (N scenarios, M ops, scope=S). Set `slicing_strategy: incremental` in spec.feature and re-run --start. See `.context/templates/architect/increment_plan_template.md` § 3 for the heuristic."
   - IF gate PASSES → emit `increment_plan.md` with a single `INC-1` increment + § 3 Monolithic Escape Declaration populated. Skip Step B.
3. IF `slicing_strategy == incremental` → proceed to Step B (RDR).

**Step B — Increment Slicing RDR (Recommendation → Decision → Ratification):**

Follow `.claude/skills/factory-rdr/SKILL.md` canonical protocol. Slicing-specific invariants:
- Present **≥ 3 alternative slicings**. Typical families (pick ≥3, do NOT invent without justification):
  - `by-user-subjourney` — each increment ships one end-to-end capability of the user journey.
  - `by-data-entity` — each increment introduces one domain entity + its CRUD surface.
  - `by-capability-layer` — each increment adds a vertical capability (read → write → edit → delete).
  - `by-risk-tier` — lowest-risk / highest-observability first, risky/integration-heavy last.
  - `happy-path-first` — all happy paths across the feature in INC-1, edge cases in INC-N.
  - `read-then-write` — read-only surface first, mutating surface second, advanced last.
- Each alternative MUST declare: ordered increments, scenarios per increment, contract ops per increment, estimated PR size (tasks count), and a one-line deployability rationale.
- BLUEPRINT recommends **one** with a one-line justification (e.g., "alt 2 — each increment ships a self-contained read→write user loop without depending on future flags").
- User MUST ratify **verbatim** (per factory-rdr). A recommendation without user ratification is INCOMPLETE — BLOCK.
- Store ratification record in feature worklog: action `BLUEPRINT.increment_plan.rdr_ratified` with payload `{alternatives_presented: N, user_choice: "alt-k", rdr_ratified_at: iso}`.

**Step C — Increment Plan Emission (IPP-compliant):**

1. READ template `.context/templates/architect/increment_plan_template.md`.
2. Resolve placeholders:
   - `{{FEATURE_ID}}`, `{{SCOPE}}`, `[DATE]` from spec.feature + system clock.
   - `slicing_strategy`, `based_on_iteration`, `based_on_schemas_version` inherited from spec.feature (never recomputed).
   - § 1 **Increments** populated from ratified RDR choice: title, scenarios_covered, contract_surface, depends_on, functional_definition, acceptance checklist, branch convention, layer tasks left as placeholders for IMPLEMENT `--plan`.
   - § 2 **Dependency Graph** — emit Mermaid DAG from `depends_on` relations.
   - § 0 **Slicing Rationale** — populate with chosen strategy justification + summaries of ≥2 rejected alternatives + ratification timestamp.
   - § 3 **Monolithic Escape Declaration** — emit ONLY when `slicing_strategy == monolithic`; include heuristic metrics.
   - Frontmatter: `total_increments` = count of § 1 sections; `rdr_alternatives_considered` = number presented (≥3); `rdr_ratified_at` = ratification ISO timestamp; `status: DRAFT`.
3. Atomic-write `docs/spec/{{FEATURE_ID}}/increment_plan.md` via IPP (skeleton-first + section-atomic; see § Incremental Persistence below for the full loop).

**Step D — Self-Check Invariants (before proceeding to Section 7 GCD):**

BLUEPRINT MUST self-verify before exit:

- **Scenario coverage (exclusive):** every `Scenario:` in `spec.feature` appears in exactly one increment's `scenarios_covered`. No orphan, no duplicate.
- **Contract coverage (exclusive):** every contract operation in `contracts/**` appears in exactly one increment's `contract_surface`. No orphan, no duplicate.
- **DAG:** `depends_on` across all increments is acyclic (topological sort succeeds). INC-1 has `depends_on: []`. Every referenced ID exists.
- **Deployability:** every increment declares `deployable: production`. Any other value (e.g., `flagged_off`, `experimental`) → BLOCK. Feature-flag-OFF merges are NOT a valid escape. If the user argues for a flagged rollout, that MUST be expressed as an explicit follow-up increment with its own scenarios, not as an escape on a half-done slice.
- **Acceptance checklist shape:** each increment's acceptance block contains the template's standard checklist (E2E / API / Reliability / CVP / no-TODO).

Violations are **BUGS in the RDR output** — loop back to Step B with the specific violation surfaced to the user. Do NOT attempt to auto-correct.

**Step E — Worklog Registration:**

Register action `BLUEPRINT.increment_plan.emitted` with payload `{feature_id, slicing_strategy, total_increments, rdr_alternatives_considered, rdr_ratified_at}`. See `.claude/skills/factory-worklog/SKILL.md`.

**Output invariants at step end:**
- `docs/spec/{{FEATURE_ID}}/increment_plan.md` exists with `status: DRAFT`, well-formed frontmatter (all fields populated), § 0/§ 1/§ 2 fully written. § 3 only when `slicing_strategy == monolithic`.
- CVP gates `increment_deployability`, `increment_to_scenario_coverage`, `increment_to_contract_coverage` run at `--approve` (see `.claude/skills/factory-coherence-validation/SKILL.md`).

### Section 7: Governance Constraints Digest (GCD) Generation (MANDATORY — v2.3.0)

> **Purpose:** BLUEPRINT has already loaded ALL applicable governance rules (Steps 0-5). Instead of IMPLEMENT re-loading the same 20+ rule files independently, BLUEPRINT emits a pre-digested, feature-scoped constraint set into `design.md Section 7`. IMPLEMENT reads ONE section and gets everything it needs for DEV + REVIEW + SEC — reliably, with zero duplication.

**When to generate:** After completing Section 5 (Infrastructure Needs), before finalizing `design.md`.  
**Format:** Inline markdown table + YAML blocks. NEVER prose. Machine-readable IDs for each constraint.

```yaml
FUNCTION generate_governance_constraints_digest(FEATURE_ID, stack_context, governance_context):
  # Uses already-loaded governance from Steps 0-5 — no additional file reads
  
  WRITE design.md "## Section 7: Governance Constraints Digest"
  WRITE design.md "> Auto-generated by BLUEPRINT --start. Read by IMPLEMENT as single-file governance fast-path."
  WRITE design.md "> Constraint IDs are referenced by REVIEW hat checks (e.g., [GOV-ARCH-001])."
  
  # 7.1 Architecture Constraints (→ REVIEW Check #1: ARCH)
  EXTRACT from constitution.md:
    topology_code: "B{N}"  # e.g., B2, B5, B8
    topology_name: "{name}"  # e.g., Modular Monolith, Event-Driven Microservices
    layer_ordering: "{presentation → application → domain → infrastructure}"
    module_boundary_rules:  # per topology: which imports are ALLOWED vs FORBIDDEN
      FOR EACH module_pair:
        - source: "{module_A}" → target: "{module_B}": ALLOWED|FORBIDDEN
    extension_strategy: "E{N} — {name}"  # E0=Native, E1=Wrapper, E2=Strangler, E3=Rewrite
    protect_legacy: true|false  # E1/E2 only
  
  WRITE design.md "### 7.1 Architecture Constraints → REVIEW [ARCH]"
  WRITE design.md:
    topology: "{B_code} {name}"
    extension_strategy: "{E_code} {name}"
    layer_rule: "{ordering}"
    module_boundaries_table: | 
      | From | To | Rule |
      |------|----|------|
      | {module} | {module} | ALLOWED\|FORBIDDEN |
    forbidden_patterns:
      - "Direct cross-domain imports — use contract HTTP call"
      - "Domain entity in presentation layer"
      - "Infrastructure leak into domain"
  
  # 7.2 Governance Rules Index (→ REVIEW Check #2: GOV)
  # Compact extraction: only the actionable constraints, not full rule prose.
  # MUST cover ALL rule files in .claude/rules/ — not just a subset.
  # Missing rules cause IMPLEMENT to operate without constraints → quality gaps.
  EXTRACT key constraints from each applicable rule:
    GOV-ARCH:   architecture.md → naming conventions, file organization rules, layer ordering
    GOV-SEC:    security_policy.md → auth requirements, CORS, headers, session rules
    GOV-TEST:   testing.md → coverage threshold (%), required frameworks, file patterns
    GOV-API:    api-standards.md → versioning, status codes, pagination, error format
    GOV-DB:     database.md → migration policy, index requirements, FK rules (if DB exists)
    GOV-OBS:    observability.md → required log fields, trace headers, metrics
    GOV-PERF:   performance.md → SLA targets, caching rules, query limits
    GOV-PRIV:   privacy.md → PII field handling, data retention, masking requirements
    GOV-STACK:  {stack-specific rule e.g. node.md, python.md} → key naming/lint rules
    GOV-REVIEW: review-policy.md → review criteria, approval policies, review checklist scope
    GOV-STATE:  stateless.md → state management constraints, session handling, caching rules
    GOV-IMMUT:  immutability_policy.md → frozen artifacts, protected code block rules
    GOV-CFP:    contract-first-policy.md → contract-first enforcement, cross-domain import policy
    GOV-IAC:    iac.md → IaC naming, module structure, least privilege, tags (if infra exists)
    GOV-FRONT:  frontend_architecture_compatibility.md → frontend arch compatibility rules (if frontend)
    GOV-HTML:   html-css.md → HTML/CSS coding standards, semantic markup rules (if frontend)
  
  FOR EACH rule WITH stack_conditional:
    IF stack_conditional != match(stack_context): SKIP rule, add to "not_applicable" list
  
  WRITE design.md "### 7.2 Governance Rules Index → REVIEW [GOV]"
  WRITE design.md:
    applicable_rules:
      - id: "GOV-ARCH"
        source: ".claude/rules/architecture.md"
        constraints: ["{compact rule 1}", "{compact rule 2}"]
      - id: "GOV-SEC"
        source: ".claude/rules/security_policy.md"
        constraints: ["{constraint 1}", "{constraint 2}"]
      - id: "GOV-TEST"
        source: ".claude/rules/testing.md"
        coverage_threshold: "{N}%"
        test_framework: "{framework}"
        test_file_pattern: "{pattern}"
      - id: "GOV-REVIEW"
        source: ".claude/rules/review-policy.md"
        constraints: ["{review criteria}", "{approval count}", "{review scope rules}"]
      - id: "GOV-STATE"
        source: ".claude/rules/stateless.md"
        constraints: ["{session rule}", "{caching rule}", "{state constraint}"]
      - id: "GOV-IMMUT"
        source: ".claude/rules/immutability_policy.md"
        constraints: ["{frozen artifacts}", "{protected code block rules}"]
      - id: "GOV-CFP"
        source: ".claude/rules/contract-first-policy.md"
        constraints: ["{cross-domain import policy}", "{contract-first enforcement}"]
      - id: "GOV-IAC"
        source: ".claude/rules/iac.md"
        constraints: ["{IaC naming}", "{module structure}", "{least privilege}"]
        stack_conditional: "iac_tool != None"
      - id: "GOV-FRONT"
        source: ".claude/rules/frontend_architecture_compatibility.md"
        constraints: ["{frontend arch rules}"]
        stack_conditional: "frontend.framework != None"
      - id: "GOV-HTML"
        source: ".claude/rules/html-css.md"
        constraints: ["{semantic markup}", "{CSS standards}", "{responsive rules}"]
        stack_conditional: "frontend.framework != None"
      # ... (one entry per applicable rule)
    not_applicable: ["{rule_name}: {reason — e.g., no database in stack}"]
  
  # 7.3 SAST Patterns (→ SEC Hat) — stack-specific ONLY
  # Pre-compiles the exact patterns for THIS stack. SEC hat does not re-derive.
  # Source: security_policy.md + stack-specific rules (already loaded in Steps 0-5).
  # OWASP Top 10 coverage derived from the project's attack surface (API, frontend, data layer).
  DERIVE from governance rules already in memory:
    FOR backend.runtime: select applicable patterns (Python | TypeScript/JS | Java | Go)
    FOR frontend.framework (if exists): select frontend patterns
    ALWAYS include: Common patterns (hardcoded secrets, disabled TLS)
  
  WRITE design.md "### 7.3 SAST Patterns → SEC Hat"
  WRITE design.md:
    backend_runtime: "{runtime}"
    frontend_framework: "{framework | None}"
    patterns:
      - id: "SAST-INJ-01"
        description: "{pattern description}"
        detection: "{code pattern or AST pattern}"
        cwe: "CWE-{N}"
        severity: "CRITICAL|HIGH|MEDIUM|LOW"
        owasp: "A{N}"
      # ... (only patterns applicable to this stack)
    common_patterns:
      - id: "SAST-SEC-01"
        description: "Hardcoded secrets"
        detection: "password|api_key|secret.*=.*['\"][^$\n]{8,}"
        severity: "CRITICAL"
        owasp: "A02"
    applicable_owasp:
      - "A01 (Broken Access Control): {applicable check}"
      - "A02 (Cryptographic Failures): {applicable check}"
      - "A03 (Injection): {applicable check}"
      # ... only OWASP items relevant to this feature's surface area
  
  # 7.4 Schema Constraints (→ REVIEW Check #5: SCHEMA)
  EXTRACT from user_journey.md Data Schemas:
    FOR EACH entity IN data_schemas:
      business_fields: [field_name, type, required|optional]  # LOCKED
      # (Technical fields exempt: id, created_at, updated_at, version, audit fields)
  
  WRITE design.md "### 7.4 Schema Constraints → REVIEW [SCHEMA]"
  WRITE design.md:
    schemas_version: "{user_journey.schemas_version}"
    entities:
      - name: "{EntityName}"
        locked_fields:
          - field: "{name}" | type: "{type}" | format: "{format}" | required: true|false
        note: "Business fields LOCKED — deviation requires CODESIGN RDR"
    exempt_technical_fields: [id, created_at, updated_at, deleted_at, version, audit_fields]
    # Type Format Registry (for test data compliance)
    # Preserves domain type precision lost when normalizing to language primitives.
    # Source: user_journey.md Data Schemas + OpenAPI/contract format fields.
    # Consumed by: IMPLEMENT TDD (mock data generation), REVIEW Check #5 [SCHEMA-TEST].
    type_format_registry:
      - field_pattern: "*_id" | format: "uuid" | example: "550e8400-e29b-41d4-a716-446655440000"
      - field_pattern: "*email*" | format: "email" | example: "user@example.com"
      - field_pattern: "*_at" | format: "iso-datetime" | example: "2026-01-15T10:30:00Z"
      - field_pattern: "*_date" | format: "iso-date" | example: "2026-01-15"
      - field_pattern: "*url*" | format: "uri" | example: "https://example.com/resource"
      - field_pattern: "*uri*" | format: "uri" | example: "https://example.com/resource"
      - field_pattern: "*phone*" | format: "phone" | example: "+1-555-0100"
      # Entity-specific overrides (from user_journey.md):
      #   FOR EACH entity IN data_schemas:
      #     FOR EACH field WHERE field.type has domain precision (UUID, Email, URL, etc.):
      #       - field_pattern: "{entity.name}.{field.field}" | format: "{domain_format}" | example: "{valid_example}"
  
  # 7.5 Contract-First Constraints (→ REVIEW Check #10: CFP)
  EXTRACT from Section 3 (Contracts) of design.md already generated:
    contract_files: [{type, path}]
    forbidden_direct_imports: ["{module_A}", "{module_B}"]  # cross-domain
  
  WRITE design.md "### 7.5 Contract-First Rules → REVIEW [CFP]"
  WRITE design.md:
    contracts:
      - type: "OpenAPI|GraphQL|AsyncAPI|gRPC"
        path: "{contracts/...}"
        slug: "{slug}"
    cross_domain_import_forbidden_from: ["{module_name}"]
    all_cross_domain_calls_via: "HTTP client generated from contract file"
  
  # 7.6 UX Vision Digest (UXD) (→ REVIEW Check #7: UX + IMPLEMENT Phase B — frontend only)
  # PURPOSE: BLUEPRINT has already loaded ALL 5 vision HTML/MD artifacts in Step 0 (UX Artifacts
  # Enrichment). Instead of IMPLEMENT re-loading 5 large HTML files (2500+ tokens total) that
  # get lost to context summarization before Phase B, BLUEPRINT pre-digests the essential
  # structural data into this compact section. IMPLEMENT reads ONE section and gets everything
  # it needs for shell composition, styling, component reuse, and navigation — reliably.
  # This follows the SAME pattern as GCD (Section 7.1-7.5): pre-digest upstream → one read downstream.
  IF frontend.framework != "None":
    # 7.6.1 Shell Composition (from app_shell.html)
    EXTRACT from app_shell.html:
      shell_layout: "{layout_type — e.g., sidebar-left, top-nav, minimal, dashboard}"
      shell_regions:
        header: { exists: true|false, contains: ["{logo|nav|user-menu|search|...}"], height: "{value}" }
        sidebar: { exists: true|false, position: "left|right", width: "{value}", collapsible: true|false, contains: ["{nav-links|icons|...}"] }
        footer: { exists: true|false, contains: ["{copyright|links|...}"] }
        main: { container: "{class or structure}", padding: "{value}" }
      shell_css_classes: ["{class_1}", "{class_2}"]  # CSS classes used by the shell
      shell_landmarks: { banner: "{selector}", navigation: "{selector}", main: "{selector}", contentinfo: "{selector}" }
    
    # 7.6.2 Design Tokens (from style_guide.html)
    EXTRACT from style_guide.html → ALL CSS custom properties / design tokens:
      color_palette:
        primary: "{value}"         # --color-primary
        secondary: "{value}"       # --color-secondary
        accent: "{value}"          # --color-accent
        background: "{value}"      # --color-bg
        surface: "{value}"         # --color-surface
        text_primary: "{value}"    # --color-text
        text_secondary: "{value}"  # --color-text-secondary
        error: "{value}"           # --color-error
        warning: "{value}"         # --color-warning
        success: "{value}"         # --color-success
        # ... all color tokens from the style guide
      typography:
        font_family_primary: "{value}"
        font_family_mono: "{value}"
        scale: [  # font-size / line-height / weight per role
          { role: "h1", size: "{value}", line_height: "{value}", weight: "{value}" },
          { role: "h2", size: "{value}", line_height: "{value}", weight: "{value}" },
          { role: "body", size: "{value}", line_height: "{value}", weight: "{value}" },
          { role: "small", size: "{value}", line_height: "{value}", weight: "{value}" },
          # ... all typography roles
        ]
      spacing_scale:
        xs: "{value}"    # --spacing-xs
        sm: "{value}"    # --spacing-sm
        md: "{value}"    # --spacing-md
        lg: "{value}"    # --spacing-lg
        xl: "{value}"    # --spacing-xl
        2xl: "{value}"   # --spacing-2xl
      borders:
        radius_sm: "{value}"
        radius_md: "{value}"
        radius_lg: "{value}"
        radius_full: "{value}"
      shadows: ["{shadow_1}", "{shadow_2}", "{shadow_3}"]
      transitions: { default: "{value}", fast: "{value}", slow: "{value}" }
      breakpoints:
        sm: "{value}"    # mobile
        md: "{value}"    # tablet
        lg: "{value}"    # desktop
        xl: "{value}"    # wide
      css_custom_property_prefix: "{prefix — e.g., --app-, --ds-}"  # or empty if no prefix
    
    # 7.6.3 Page Templates (from page_templates.html)
    EXTRACT from page_templates.html:
      available_templates:
        - type: "{dashboard|list|detail|form|error|auth|landing|settings}"
          layout: "{grid|flex|single-column|multi-column}"
          regions: ["{page-header|filters|content-area|action-bar|pagination}"]
          css_classes: ["{class_1}", "{class_2}"]
        # ... one entry per template archetype
      feature_template_type: "{which template THIS feature should use based on spec.feature}"
    
    # 7.6.4 Component Library Inventory (from component_library.html)
    EXTRACT from component_library.html:
      reusable_components:
        - name: "{component_name — e.g., Button, Card, Modal, Table, TextInput, Select}"
          variants: ["{primary|secondary|outline|ghost}"]
          props: ["{size|disabled|loading|icon|...}"]
          css_class: "{class_name}"
          usage_notes: "{when to use this component}"
        # ... one entry per reusable component
      total_available: {count}
    
    # 7.6.5 Navigation Map (from navigation_map.md)
    EXTRACT from navigation_map.md:
      nav_structure:
        - label: "{section_label}"
          path: "{route}"
          icon: "{icon_name|null}"
          children:
            - label: "{child_label}"
              path: "{route}"
        # ... full navigation tree
      feature_placement:
        nav_entry: "{where this feature appears in navigation}"
        parent_section: "{parent nav section}"
        route_pattern: "{/feature-path/:id}"
      breadcrumb_chain: ["{Home}", "{Section}", "{Feature}"]
    
    # 7.6.6 Feature-to-Vision Cross-Reference
    # Map THIS feature's mock.html components against the component library
    mock_component_analysis:
      - mock_component: "{component from mock.html}"
        classification: "VISION_REUSE|FEATURE_NEW"
        library_match: "{component_library entry name|null}"
        notes: "{adaptation needed|direct reuse|new component required}"
      # ... one entry per component in mock.html
    
    WRITE design.md "### 7.6 UX Vision Digest (UXD) → REVIEW [UX] + IMPLEMENT Phase B"
    WRITE design.md:
      uxd_version: "1.0.0"
      vision_status: APPROVED
      vision_artifacts_source: [app_shell.html, style_guide.html, page_templates.html, component_library.html, navigation_map.md]
      # Shell
      shell_composition: {shell_layout, shell_regions, shell_css_classes, shell_landmarks}
      # Tokens
      design_tokens: {color_palette, typography, spacing_scale, borders, shadows, transitions, breakpoints, css_custom_property_prefix}
      # Templates
      page_templates: {available_templates, feature_template_type}
      # Components
      component_library: {reusable_components, total_available}
      # Navigation
      navigation: {nav_structure, feature_placement, breadcrumb_chain}
      # Feature-Level
      mock_component_analysis: {mock_component_analysis}
      # Constraints
      touch_target_minimum: "44×44px"
      wcag_level: "AA"
      blocker_violations:
        - "Duplicating a component that exists in vision library (use VISION_REUSE classification)"
        - "Hardcoding colors/fonts/spacing when design tokens exist (use css_custom_property_prefix + token names)"
        - "Shell structure deviation (header/sidebar/footer must match shell_composition)"
      note: >
        This UXD is the SINGLE SOURCE for IMPLEMENT Phase B.
        IMPLEMENT reads this section ONCE — it does NOT need to load any vision HTML files.
        design_tokens are translated to stack-native config during B.0 (Frontend Foundation).
        shell_composition is the binding reference for shell fidelity verification.
        component_library is the binding reference for component reuse classification.
  ELSE:
    WRITE design.md "### 7.6 UX Vision Digest (UXD) → N/A (no frontend in stack)"
  
  # 7.7 Coding Standards (→ DEV Hat)
  EXTRACT from stack-specific rule + constitution.md:
    naming_convention: "{camelCase|snake_case|PascalCase} per role"
    module_structure: "{directory layout}"
    test_file_pattern: "{e.g., *.spec.ts, test_*.py}"
    test_framework: "{jest|pytest|go test}"
    key_lint_rules: ["{rule_1}", "{rule_2}"]
  
  WRITE design.md "### 7.7 Coding Standards → DEV Hat"
  WRITE design.md:
    language: "{runtime/language}"
    naming:
      files: "{pattern}"
      classes: "{pattern}"
      functions: "{pattern}"
      constants: "{pattern}"
    module_structure: "{layout description}"
    test_file_pattern: "{pattern}"
    key_lint_rules: ["{rule}"]
  
  # 7.8 Mandatory Architectural Patterns + FDR Bindings (→ REVIEW Check #14: DESIGN + DEV Hat)
  # PURPOSE: Constitution `[LAW]` sections and feature-scoped FDRs define mandatory implementation
  # patterns (e.g., BaseRepository with auto tenant filter, middleware tenant_id injection, global
  # error handler, audit logging). These are NOT rules (.claude/rules/) — they are DESIGN
  # DECISIONS that dictate HOW code must be structured. Without this section, IMPLEMENT satisfies
  # constraints superficially (e.g., manual tenant filtering in each query instead of the
  # prescribed BaseRepository auto-filter).
  #
  # SOURCES:
  #   A) Constitution `[LAW]` sections — already loaded in the governance snapshot at
  #      `.context/governance_snapshot.md` § Active Constitution. Read from there directly
  #      (no need to re-scan constitution.md). Universal architectural law lives here.
  #   B) Feature Decision Records (FDR) at `docs/spec/{FEATURE_ID}/fdr/*.md` with
  #      `status: accepted` — feature-local binding patterns.
  #   C) Setup decisions from `.context/governance_snapshot.md` § Setup Configuration that
  #      affect implementation (e.g., multitenancy strategy, auth mechanism, synthetic data flag).
  #   D) Historical ADR traceability (read-only) via factory-adr-management List Active API —
  #      used to surface "why this [LAW] section is worded this way" in design.md notes.
  #      Historical ADRs are NEVER binding; only the resulting [LAW] sections in constitution are.

  # A. Read constitutional [LAW] from snapshot (already extracted by SETUP --generate /
  # SETUP --upgrade — see Factory-setup-materialization Checkpoint 3.1).
  law_sections = READ(".context/governance_snapshot.md") § "Active Constitution (Operational [LAW] sections — verbatim)"

  mandatory_patterns = []
  FOR EACH section IN law_sections:
    # Scan section body for: mandatory shared components, middleware requirements, base classes,
    # data access strategies, security enforcement patterns, cross-cutting concerns. The [LAW]
    # body is verbatim constitution text — parse domain-specific patterns per section topic
    # (Code Readability, Security by Design, etc.) and emit canonical entries:
    FOR EACH pattern IN extract_patterns_from_law(section):
      mandatory_patterns.APPEND({
        id: "PAT-{sequential}",
        name: "{pattern_name}",  # e.g., "BaseRepository", "TenantMiddleware", "GlobalErrorHandler"
        type: "{middleware|base_class|shared_service|guard|interceptor|adapter|factory}",
        scope: "{shared|per_module}",
        description: "{what it does}",
        enforcement: "{how — e.g., all repositories MUST extend BaseRepository}",
        law_section_ref: "{section.heading}",   # traceability back to the [LAW] section
        affects_feature: true|false             # whether this feature uses/needs this pattern
      })

  # Domain-specific extractions from [LAW] sections (preserved from prior contract).
  # Each conditional reads the relevant [LAW] section's body if present in the snapshot.

  # Multitenancy patterns (if a [LAW] section addresses multitenancy)
  IF any law_section addresses multitenancy:
    EXTRACT:
      isolation_strategy: "{row_level|schema|database}"
      tenant_source: "{middleware|header|jwt_claim|subdomain}"
      enforcement_mechanism: "{base_repository_filter|middleware_injection|db_policy|rls}"
      mandatory_components:
        - name: "{e.g., TenantMiddleware}"
          responsibility: "{e.g., extract tenant_id from JWT, inject into request context}"
        - name: "{e.g., BaseRepository}"
          responsibility: "{e.g., auto-add WHERE tenant_id = $1 on all queries}"

  # Auth/security patterns (typically in [LAW] Security by Design)
  IF [LAW] section "Security by Design" addresses auth:
    EXTRACT:
      auth_mechanism: "{jwt|session|oauth2|api_key}"
      mandatory_middleware: ["{auth_middleware}", "{rbac_guard}", ...]
      token_propagation: "{how auth context flows through layers}"

  # Cross-cutting concerns (error handling, logging, audit)
  IF any [LAW] section addresses cross-cutting concerns:
    EXTRACT:
      error_handling: "{global_handler|per_module|middleware}"
      logging: "{structured|middleware_injected|decorator}"
      audit: "{audit_trail_middleware|event_sourcing|db_trigger}"

  # B. Load feature-relevant FDRs (feature-scoped binding decisions)
  fdr_bindings = []
  fdr_dir = "docs/spec/{FEATURE_ID}/fdr/"
  IF DIRECTORY_EXISTS(fdr_dir):
    FOR EACH fdr_file IN fdr_dir:
      fdr = READ(fdr_file)
      IF fdr.status == "accepted":
        fdr_bindings.APPEND({
          id: fdr.fdr_number,                            # e.g., "FDR-003"
          title: fdr.title,
          binding_rule: fdr["## Binding Rule"].body,     # the operational text
          decision: fdr["## Decision"].body,             # rationale (informational)
          consequences: fdr["## Consequences"].negatives,
          mandatory_components: extract_mandatory_components(fdr["## Binding Rule"].body)
        })

  # B'. Load FDRs from upstream features whose contract this feature consumes
  # (cross-feature contract dependencies — see spec.feature.consumes_contract).
  IF spec.feature.consumes_contract not empty:
    FOR EACH upstream_feature_id IN spec.feature.consumes_contract:
      upstream_fdr_dir = "docs/spec/{upstream_feature_id}/fdr/"
      IF DIRECTORY_EXISTS(upstream_fdr_dir):
        FOR EACH fdr_file IN upstream_fdr_dir:
          fdr = READ(fdr_file)
          IF fdr.status == "accepted":
            fdr_bindings.APPEND({
              id: "{upstream_feature_id}/{fdr.fdr_number}",
              title: fdr.title + " (upstream)",
              binding_rule: fdr["## Binding Rule"].body,
              upstream_feature: upstream_feature_id
            })

  # C. Load setup decisions that affect implementation patterns
  setup_patterns = []
  IF FILE_EXISTS(".context/governance_snapshot.md"):
    EXTRACT from snapshot → Setup Configuration:
      IF synthetic_data.enabled: setup_patterns.APPEND("synthetic_data_seeding")
      # Other setup decisions that affect code patterns

  # D. (Optional) Historical ADR traceability via factory-adr-management
  # ONLY consulted when the agent wants to surface "why this [LAW] is worded this way" — these
  # are HISTORICAL records, NEVER binding. Active law lives in constitution [LAW] sections (A).
  historical_adr_refs = []
  IF design narrative wants to surface decision history:
    historical_adr_refs = factory-adr-management.list_active_adrs(feature_id=FEATURE_ID)
    # Returns refs only — no binding semantics derived from them.

  WRITE design.md "### 7.8 Mandatory Architectural Patterns + FDR Bindings → REVIEW [DESIGN] + DEV Hat"
  WRITE design.md:
    mandatory_patterns:
      - id: "PAT-{N}"
        name: "{pattern_name}"
        type: "{type}"
        scope: "{shared|per_module}"
        description: "{what it does}"
        enforcement: "{how — e.g., all repos MUST extend BaseRepository}"
        law_section_ref: "{[LAW] section heading from constitution}"
        affects_feature: true|false

    multitenancy: # (if applicable)
      isolation_strategy: "{strategy}"
      tenant_source: "{source}"
      enforcement_mechanism: "{mechanism}"
      mandatory_components:
        - name: "{component}" | responsibility: "{what it must do}"

    auth_patterns: # (if applicable)
      mechanism: "{auth_mechanism}"
      mandatory_middleware: ["{middleware_list}"]
      token_propagation: "{flow description}"

    cross_cutting: # (if applicable)
      error_handling: "{pattern}"
      logging: "{pattern}"
      audit: "{pattern}"

    fdr_bindings:                                           # feature-local binding decisions
      - id: "{FDR-NNN}"
        title: "{title}"
        binding_rule: "{the operational rule from FDR}"
        mandatory_components: ["{components this FDR requires}"]
        upstream_feature: "{upstream FEAT-ID if from consumes_contract, else null}"

    historical_adr_refs:                                    # informational only — NEVER binding
      - id: "{ADR-NNN}"
        title: "{title}"
        path: "{relative path}"
        accepted_at: "{ISO date}"
        # Active law lives in the [LAW] sections referenced above; ADRs are historical context only.

    implementation_invariants:
      - "All repositories MUST extend/use {BaseRepository} — never implement tenant filtering manually"
      - "Tenant context MUST flow via middleware injection — never extract directly from JWT in handlers"
      - "Cross-cutting concerns MUST use prescribed middleware chain — never implement ad-hoc"
      # (generated from [LAW] patterns + FDRs — feature-specific invariants)

    note: >
      DEV Hat: mandatory_patterns and implementation_invariants are BINDING. Every shared component
      listed here MUST be created (or verified existing) before feature-specific code that depends
      on it. REVIEW Check #14 [DESIGN] validates materialization fidelity — bypassing prescribed
      patterns is a BLOCKER. Sources of binding rules are constitution `[LAW]` sections (universal)
      and feature-scoped FDRs (this feature + any upstream consumed via `consumes_contract`).
      Historical ADRs are NOT binding — they are context for understanding why a `[LAW]` section
      is worded the way it is.
  
  # Finalize and SAVE Section 7 atomically
  # Compute GCD hash from the dual-hash identity used by governance_snapshot (GCRP compliant).
  # constitution_hash is the primary governance identity; we take the first 8 chars as a fingerprint.
  gcd_hash = governance_snapshot.frontmatter.constitution_hash[:8]
  
  UPDATE design.md frontmatter:
    _progress.completed_sections: APPEND("section_7_gcd")
    governance_digest_generated: true
    governance_digest_version: "{gcd_hash}"  # constitution_hash[:8] — matches GCRP dual-hash validation
  SAVE design.md  # IPP section-atomic save
  LOG: "GCD generated: design.md Section 7 (7.1 ARCH + 7.2 GOV + 7.3 SAST + 7.4 SCHEMA + 7.5 CFP + 7.6 UX + 7.7 CODING + 7.8 PATTERNS) — hash: {gcd_hash}"
```

**Reliability guarantees:**
- **Same-source:** The GCD uses the SAME governance context already loaded by BLUEPRINT (Steps 0-5). It does not re-read any files — it re-structures what is already in memory.
- **Hash-validated:** The `governance_digest_version` field stores `constitution_hash[:8]` from the governance snapshot. IMPLEMENT Step 0b compares this against the current snapshot's `constitution_hash` — if they diverge, IMPLEMENT falls back to direct governance loading and emits an advisory to re-run `BLUEPRINT --refine`.
- **Graceful degradation:** If Section 7 is absent (pre-v2.3.0 BLUEPRINT) or stale, IMPLEMENT loads governance from raw files. No workflow breakage.

### Incremental Persistence (IPP-compliant — MANDATORY)

> **Implements:** Incremental Persistence Protocol (`.claude/skills/factory-incremental-persistence/SKILL.md`) — Pillars 1, 2, 3.

**Pillar 1 — Skeleton-First Write (before content generation):**
```yaml
FUNCTION blueprint_skeleton_first(FEATURE_ID):
  base_path = "docs/spec/{FEATURE_ID}"
  
  FOR EACH artifact IN [design.md, test_plan.md, increment_plan.md]:
    path = "{base_path}/{artifact}"
    IF NOT FILE_EXISTS(path):
      WRITE_SKELETON(path):
        frontmatter:
          status: DRAFT
          feature_id: "{FEATURE_ID}"
          created_at: "{ISO_8601}"
          updated_at: "{ISO_8601}"
          _progress:
            current_phase: "skeleton"
            completed_sections: []
            pending_sections: [ARTIFACT_SECTIONS(artifact)]
            decisions: []
            last_agent: "BLUEPRINT"
            last_command: "--start {FEATURE_ID}"
            resumable: true
        body: SECTION_HEADERS_WITH_PENDING_MARKERS(artifact)
      SAVE(path)  # IMMEDIATE
  LOG: "Skeletons created for BLUEPRINT {FEATURE_ID}: design.md + test_plan.md"
```

**Pillar 2 — Section-Atomic Saves (during generation):**
```yaml
# Sections saved individually for IPP resilience

FOR EACH section IN artifact.sections:
  content = GENERATE(section)  # ARCH or QA hat co-creates
  REPLACE_SECTION(artifact_path, section.id, content)
  UPDATE_FRONTMATTER(artifact_path):
    _progress.completed_sections: APPEND(section.id)
    _progress.pending_sections: REMOVE(section.id)
    _progress.current_phase: "{next_section}"
    updated_at: "{ISO_8601}"
  SAVE(artifact_path)  # IMMEDIATE — no batching
  # Rule: NEVER continue to next section until current is on disk
```

**Pillar 3 — Resume-on-Entry (on --start or --refine):**
```yaml
FUNCTION blueprint_resume_check(FEATURE_ID, command):
  base_path = "docs/spec/{FEATURE_ID}"
  
  FOR EACH artifact IN [design.md, test_plan.md, increment_plan.md]:
    path = "{base_path}/{artifact}"
    IF FILE_EXISTS(path):
      fm = READ_FRONTMATTER(path)
      IF fm._progress IS NOT NULL AND fm._progress.pending_sections.length > 0:
        LOG: "RESUME: {artifact} — {fm._progress.completed_sections.length} done, {fm._progress.pending_sections.length} pending"
        RECOVER_DECISIONS(fm._progress.decisions)
        RESUME_FROM(fm._progress.pending_sections[0])
        RETURN "RESUMED"
  
  RETURN "FRESH"
```

**Finalization (on --approve):**
```yaml
FOR EACH artifact IN [design.md, test_plan.md, increment_plan.md]:
  UPDATE_FRONTMATTER(artifact_path):
    status: APPROVED
    _progress: null  # REMOVE — no resume needed
  SAVE(artifact_path)
```
