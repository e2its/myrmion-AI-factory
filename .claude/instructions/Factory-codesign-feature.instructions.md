---
description: "Factory CODESIGN feature co-creation — BDD/Gherkin spec, mock HTML, user journey, Tripartite Alignment, 12-point validation. Use when: CODESIGN --start or --refine execution."
applicable_when:
  phase: [CODESIGN]
  command: [codesign]
---

# CODESIGN Agent — Level 2: Feature Co-Creation Protocol

## Purpose
This instruction file defines the **Per-Feature Co-Creation** protocols for the CODESIGN agent (🎩 PO Hat + 🎨 UX Hat). A single agent with dual personality iterates dynamically producing three co-created artifacts per feature.

**Feature artifacts** live in `docs/spec/{{FEATURE_ID}}/`.

---

## Generated Feature Artifacts (3 files per feature)

1. **`spec.feature`** — Co-created Gherkin specification (🎩 PO leads, 🎨 UX validates)
2. **`mock.html`** — Co-created interactive visual mockup (🎨 UX leads, 🎩 PO validates) — inherits shell from vision, includes state toggles + journey-step navigation
3. **`user_journey.md`** — Simplified Event Storming with typed Data Schemas (co-created)

The `user_journey.md` Data Schemas are the **source of truth** for data contracts — downstream agents formalize but do NOT invent business fields.

---

## Shared Frontmatter Structure

All three artifacts share these frontmatter fields:
```yaml
status: DRAFT | NEEDS_INFO | APPROVED | DEPRECATED | CANCELLED | SUPERSEDED
feature_id: "{{FEATURE_ID}}"
scope: full-stack | backend-only | frontend-only | integration   # dual-axis — set at --start, immutable after APPROVED
iteration: 1              # Incremented on each --refine in Iteration Mode
last_iteration_scope: ""  # Summary of last iteration changes
created_at: ISO_8601
updated_at: ISO_8601
```

Additional per-artifact fields:
- `spec.feature`: `scenarios_count`, `nfr_count`, `consumes_contract: []` (upstream FEAT-XXX deps; resolved at BLUEPRINT --start)
- `mock.html`: `pages_count`, `states_count`, `wcag_status` — only generated when `scope in [full-stack, frontend-only]`
- `user_journey.md`: `schemas_version`, `actors`, `commands`, `events`, `read_models` — for backend-only / integration scopes use `user_journey.integration.md` variant instead

**Scope axis.** `scope` is set once at `--start` (default inherited from `project_scope` in governance snapshot) and becomes immutable after auto-approval. `--refine` cannot change `scope` — a scope change requires rejecting the feature and restarting with the new scope. See § Scope Compatibility Gate in `--start` for the validator.

---

## Event Storming Discovery Protocol (BIP — Complete Proposal)

> **BIP Mode:** Instead of asking phase-by-phase questions, the agent generates a COMPLETE Event Storming proposal based on the feature description, user context, and CIP inventory. All 7 phases are proposed at once (batch between agents). Factory presents key decision points to the user via RDR (one at a time).

### Phase 0.5: CIP Domain Concept Check (MANDATORY — BLOCKING GATE before Event Storming)

```yaml
# CIP GATE — Do NOT skip this step. Execute BEFORE Event Storming.
inventory = READ("config/codebase_inventory.json")

IF inventory IS MISSING:
  materialization = READ("docs/setup.md").materialization_complete
  IF materialization == true:
    ❌ BLOCK: "Codebase inventory required but missing. Run: SETUP --reconcile-inventory"
    APPEND_TO_WORKLOG: CIP_BLOCKED
    STOP
  ELSE:
    ⚠️ WARN: "Codebase inventory not found. CIP check degraded (pre-materialization)."
    LOG CIP_SKIPPED in worklog
    PROCEED to Phase 1 (with CIP_SKIPPED flag)
ELSE:
  # Execute CIP domain concept matching
  domain_concepts = EXTRACT_DOMAIN_CONCEPTS(inventory)
  # domain_concepts = entities, events, commands, services from existing features
  
  FOR EACH new_concept IN discovered_concepts_during_phases_2_5:
    matches = MATCH_4_CRITERIA(new_concept, domain_concepts)
    IF matches.length > 0:
      RDR per overlap: REUSE_EXISTING / RENAME_NEW / MERGE / KEEP_BOTH
      # For cross-domain: ACKNOWLEDGE_CROSS_DOMAIN / SHARED_KERNEL
    
  LOG: "CIP Gate: {N} concepts checked, {M} overlaps resolved"
```

### Business Language Translation Protocol

When presenting Event Storming results to the user (via BIP RDR walk), ALL technical DDD/ES terminology MUST be translated to business language in `session.language`. The agent generates proposals using internal DDD model, but Factory presents to the user with humanized labels.

```yaml
# Translation map: DDD/ES concept → business-language presentation (keyed by session.language)
BUSINESS_LANGUAGE:
  Actor:
    es: "Quién participa"
    en: "Who participates"
  Command:
    es: "Acción del usuario"
    en: "User action"
  Event:
    es: "Qué pasa como resultado"
    en: "What happens as a result"
  ReadModel:
    es: "Lo que el usuario ve"
    en: "What the user sees"
  DataSchema:
    es: "Los datos que se manejan"
    en: "The data involved"
  Policy:
    es: "Regla de negocio"
    en: "Business rule"
  ExternalSystem:
    es: "Sistema externo conectado"
    en: "Connected external system"
  Aggregate:
    es: "Entidad principal"
    en: "Main entity"               # Never shown to user
  BoundedContext:
    es: "Área de negocio"
    en: "Business area"             # Never shown to user

# Presentation rules:
# 1. NEVER use DDD terms in user-facing text
# 2. Natural verb phrases: es: "El usuario envía un pedido" NOT "CommandDiscovered: SubmitOrder"
# 3. Natural event phrases: es: "Se registró el pedido" NOT "Event: OrderSubmitted"
# 4. Schema fields: technical types + inline explanation in session.language
# 5. Decision Batch `simplified`: describe ES phases in business terms:
#    P1: "Identificar quiénes usan..." / "Identify who uses..."
#    P2: "Definir qué acciones..." / "Define what actions..."
#    P3: "Qué pasa cuando..." / "What happens when..."
#    P4: "Qué información necesita ver..." / "What information needs..."
#    P5: "Qué datos se necesitan..." / "What data is needed..."
#    P6: "Reglas automáticas..." / "Automatic business rules..."
#    P7: "Servicios externos..." / "External services..."

# When session.explanation_level == "EXPERT": show DDD terms alongside business terms
# Example (es): "Acción del usuario (Command): El usuario envía un pedido → SubmitOrder"
# Example (en): "User action (Command): The user submits an order → SubmitOrder"
```

### Phase 1: Actor Discovery (🎩 PO hat)
- Identify ALL actors who interact with this feature
- Actor types: Human (end user, admin, etc.), System (cron, event bus), External (third-party API)
- Each actor gets a name and brief role description

### Phase 2: Command Discovery (🎩 PO hat)
- For each actor: what actions can they perform?
- Commands = intentions/verbs (e.g., "Submit Order", "Approve Request")
- Each command has: actor, trigger, input data schema ref

### Phase 3: Event Discovery (🎩↔🎨 alternating)
- For each command: what events are produced?
- Events = past-tense facts (e.g., "OrderSubmitted", "RequestApproved")
- 🎩 defines event semantics, 🎨 identifies UI reactions to events

### Phase 4: Read Model Discovery (🎩↔🎨 alternating)
- What data views does the UI need?
- Read Models = derived/projected data for display
- 🎩 defines business content, 🎨 defines display structure

### Phase 5: Data Schema Definition (🎩 PO hat)
- For each Command (DataIn) and ReadModel (DataOut): define typed schema
- Field format: `fieldName: Type [constraints]`
- Types: string, number, boolean, date, datetime, email, url, enum(values), array(Type), object(Schema)
- Constraints: [required], [optional], [min:N], [max:N], [pattern:regex], [unique]
- **ALL schemas must be complete** — no `TODO` or `TBD` fields allowed at approval time

### Phase 6: Policy Discovery (🎩 PO hat)
- Business rules triggered by events
- Policies = "When X happens, then Y must occur"
- Cross-domain policies flagged for BLUEPRINT attention

### Phase 7: External System Discovery (🎩↔🎨 alternating)
- Third-party integrations, external APIs
- For each external system: direction (inbound/outbound/bidirectional), data exchanged, protocol
- 🎨 identifies UI impact of external system states (loading, error, timeout)

---

## PO↔UX Dynamic Iteration Cycle (Internal — no user interaction)

After the Event Storming proposal is accepted by the user (via BIP), PO and UX iterate internally on the three artifacts until convergence:

```yaml
CYCLE:
  🎩 PO writes/refines spec.feature scenarios from accepted Event Storming
  🎨 UX updates mock.html to visualize scenarios
  🎩 PO validates mock matches business intent
  🎨 UX validates spec covers all UI interactions
  BOTH update user_journey.md with any new schemas/flows
  CHECK: Tripartite Alignment Protocol
  IF aligned: EXIT CYCLE → present to Factory/user for review
  IF not aligned: RESOLVE internally → CONTINUE CYCLE
```

---

## Interactive Mock Protocol (IMP v1.0.0 — Stack-Agnostic)

> **Principle:** Mocks are visual references, not functional prototypes. They must be navigable and state-aware WITHOUT any external dependency — zero npm, zero dev server, zero framework coupling. The mock works by opening the HTML file in any browser (file:// protocol).

### Why Interactive Mocks

Static mocks force users to **imagine** behavior. Interactive mocks let users **experience** transitions, states, and navigation before approving. This reduces ambiguity for BLUEPRINT and IMPLEMENT.

### Mock HTML Structure

Every `mock.html` MUST follow this structure:

```html
<!DOCTYPE html>
<html lang="{{session.language}}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>[{{FEATURE_ID}}] {{feature_name}} — Interactive Mock</title>
  <style>
    /* ── Design System tokens from vision (inherited from style_guide.html) ── */
    :root { /* ... CSS custom properties from vision ... */ }
    
    /* ── IMP: State management (DO NOT MODIFY) ── */
    [data-state] { display: none; }
    [data-state].active { display: block; }
    
    /* ── IMP: Flow navigation bar ── */
    .imp-flow-nav { display: flex;
                    gap: var(--spacing-sm, 12px);
                    padding: var(--spacing-sm, 12px) var(--spacing-md, 16px);
                    background: var(--color-neutral-100);
                    border-bottom: 1px solid var(--color-neutral-300);
                    position: sticky; top: 0; z-index: 100; flex-wrap: wrap; }
    .imp-flow-nav a { text-decoration: none;
                      padding: var(--spacing-xs, 6px) var(--spacing-sm, 14px);
                      border-radius: var(--radius-sm, 6px);
                      font-size: var(--font-size-sm, 14px);
                      color: var(--color-neutral-700);
                      background: var(--color-neutral-200); }
    .imp-flow-nav a.imp-active { background: var(--color-primary);
                                  color: var(--color-on-primary, white); }
    
    /* ── IMP: State switcher bar ── */
    .imp-state-bar { position: fixed; bottom: 0; left: 0; right: 0;
                     background: var(--color-neutral-900);
                     padding: var(--spacing-xs, 8px) var(--spacing-md, 16px);
                     display: flex; gap: var(--spacing-xs, 8px);
                     align-items: center; z-index: 999; }
    .imp-state-bar span { color: var(--color-neutral-400);
                          font-size: var(--font-size-xs, 13px); }
    .imp-state-bar button { padding: var(--spacing-xxs, 4px) var(--spacing-sm, 12px);
                            border: 1px solid var(--color-border-subtle, #555);
                            background: transparent;
                            color: var(--color-text-muted, #ccc);
                            border-radius: var(--radius-xs, 4px);
                            cursor: pointer;
                            font-size: var(--font-size-xs, 13px); }
    .imp-state-bar button.imp-active { background: var(--color-primary);
                                        color: var(--color-on-primary, white);
                                        border-color: transparent; }
    
    /* ── IMP: Step sections ── */
    .imp-step { display: none;
                padding-bottom: var(--spacing-state-bar-offset, 60px); /* space for state bar */ }
    .imp-step.imp-visible { display: block; }
    
    /* ── App shell styles (from app_shell.html) ── */
    /* ... inherited layout ... */
  </style>
</head>
<body>

  <!-- ═══ IMP: Flow Navigation (auto-derived from user_journey.md steps) ═══ -->
  <nav class="imp-flow-nav" aria-label="User journey steps">
    <!-- One link per journey step. href = #step-{N} -->
    <a href="#step-1" class="imp-active">1. {{step_1_label}}</a>
    <a href="#step-2">2. {{step_2_label}}</a>
    <a href="#step-3">3. {{step_3_label}}</a>
    <!-- ... one per user_journey.md step ... -->
  </nav>

  <!-- ═══ App Shell (from app_shell.html) ═══ -->
  <!-- header, sidebar, footer inherited from vision -->

  <main>
    <!-- ═══ Step 1: {{step_1_label}} ═══ -->
    <section class="imp-step imp-visible" id="step-1">
      <!-- State: default (always present) -->
      <div data-state="default" class="active">
        <!-- Main content for this step -->
      </div>
      <!-- State: empty -->
      <div data-state="empty">
        <!-- Empty state UI (D7 directive: illustration + text + CTA) -->
      </div>
      <!-- State: loading -->
      <div data-state="loading">
        <!-- Loading state UI (D6 directive: skeleton screens preferred) -->
      </div>
      <!-- State: error -->
      <div data-state="error">
        <!-- Error state UI with retry action -->
      </div>
    </section>

    <!-- ═══ Step 2: {{step_2_label}} ═══ -->
    <section class="imp-step" id="step-2">
      <div data-state="default" class="active">...</div>
      <div data-state="empty">...</div>
      <div data-state="loading">...</div>
      <div data-state="error">...</div>
    </section>

    <!-- ... more steps from user_journey.md ... -->
  </main>

  <!-- ═══ IMP: State Switcher (fixed bottom bar) ═══ -->
  <div class="imp-state-bar" role="toolbar" aria-label="Mock state switcher">
    <span>State:</span>
    <button class="imp-active" data-switch-state="default">Default</button>
    <button data-switch-state="empty">Empty</button>
    <button data-switch-state="loading">Loading</button>
    <button data-switch-state="error">Error</button>
  </div>

  <!-- ═══ IMP: Interactivity Engine (vanilla JS — zero dependencies) ═══ -->
  <script>
    // PROTECTED-CODE START — IMP Engine v1.0.0
    (function() {
      'use strict';
      
      // ── State management ──
      function showState(state) {
        document.querySelectorAll('[data-state]').forEach(function(el) {
          el.classList.remove('active');
        });
        document.querySelectorAll('[data-state="' + state + '"]').forEach(function(el) {
          el.classList.add('active');
        });
        document.querySelectorAll('.imp-state-bar button').forEach(function(b) {
          b.classList.toggle('imp-active', b.getAttribute('data-switch-state') === state);
        });
      }
      
      // ── Step navigation (hash-based, with fallback) ──
      function navigate() {
        var hash = location.hash || '#step-1';
        document.querySelectorAll('.imp-step').forEach(function(s) {
          s.classList.remove('imp-visible');
        });
        var target = document.querySelector(hash);
        if (!target) {
          hash = '#step-1';
          location.hash = hash;
          target = document.querySelector(hash);
        }
        if (target) target.classList.add('imp-visible');
        document.querySelectorAll('.imp-flow-nav a').forEach(function(a) {
          a.classList.toggle('imp-active', a.getAttribute('href') === hash);
        });
      }
      
      // ── Event binding ──
      document.querySelectorAll('.imp-state-bar button').forEach(function(btn) {
        btn.addEventListener('click', function() {
          showState(this.getAttribute('data-switch-state'));
        });
      });
      window.addEventListener('hashchange', navigate);
      navigate();
    })();
    // PROTECTED-CODE END — IMP Engine v1.0.0
  </script>

</body>
</html>
```

### IMP Generation Rules

1. **One `<section class="imp-step">` per user_journey.md step.** The step label in the flow-nav comes from the journey step name.
2. **Four `data-state` divs per step** (minimum): `default`, `empty`, `loading`, `error`. Additional states allowed if the step has feature-specific states (e.g., `success`, `partial`, `expired`).
3. **States must match spec.feature scenarios.** Every error scenario → content in `data-state="error"`. Every empty-state scenario → content in `data-state="empty"`.
4. **Navigation between steps simulates the user journey.** Buttons/links that advance the flow should use `href="#step-N"` to navigate, matching the journey's expected progression.
5. **Action triggers use semantic HTML.** Buttons for commands (`<button>`), links for navigation (`<a>`), forms for data input (`<form>`). No `onclick` outside the IMP engine.
6. **CSS tokens from vision.** All visual styling uses CSS custom properties from `style_guide.html`. No hardcoded colors, spacing, or typography values.
7. **`states_count` frontmatter** = total number of unique `data-state` values across all steps (e.g., 4 steps × 4 states = 16, but if some steps add `success` state, total = 17).
8. **IMP Engine is PROTECTED CODE.** The `<script>` block between `PROTECTED-CODE START/END` markers is immutable — agents MUST NOT modify it.
9. **Stack-agnostic.** No framework imports, no npm packages, no build steps. Works with `file://` protocol in any browser. This mock is a reference for ANY frontend stack (React, Flutter, SwiftUI, HTMX, Blazor, etc.).
10. **Responsive.** Use CSS media queries in `<style>` to show mobile/tablet/desktop layouts. No JavaScript-based responsive logic.

### IMP Auto-Approval Validation Addenda

The Interactive Mock Protocol adds these requirements to the **12-point auto-approval validations** (CHECKs 1–12 in `codesign_auto_approve`):

- **CHECK 8 (Empty/Loading full-chain)**: Every `data-state="empty"` and `data-state="loading"` div must have actual content (not just placeholder text). Content must match the spec.feature scenario for that state.
- **CHECK 10 (No inline styles)**: IMP CSS classes (`imp-*`) are in the `<style>` block. No `style=""` attributes on IMP elements.
- **CHECK 11 (Empty/loading states)**: Verified automatically — every `imp-step` section MUST have at minimum `default` + `empty` + `loading` + `error` state divs. Missing states = auto-approval BLOCKER.

### IMP for Non-UI Features (scope-aware)

IMP (Interactive Mock Protocol) is **N/A** and mock.html is NOT generated when ANY of the following holds:

1. `feature_scope IN [backend-only, integration]` (per-feature axis — authoritative). The compatibility matrix guarantees this can only happen inside full-stack or backend-only/integration projects; the per-feature flag drives the decision.
2. `project_scope IN [backend-only, integration]` from governance snapshot (per-project axis). Scope compatibility gate in `--start` prevents any feature from requesting UI here.
3. `frontend.framework == "None"` (legacy condition; still honoured for projects that pre-date the scope model).

When IMP is N/A:
- mock.html is not generated (no file created; not DRAFT, not APPROVED — simply absent).
- Vision Gate is skipped (no `docs/ux/vision/` dependency).
- Tripartite Alignment degrades to SPEC↔JOURNEY pair only (see § Tripartite Alignment Protocol scope matrix).
- Auto-approval CHECK 2 / 5 / 6 / 8 / 10 / 11 resolve as N/A and do not count against `failures` (see § Auto-Approval Protocol).
- The journey artifact is `user_journey.integration.md` (backend-only/integration) or `user_journey.md` (legacy). Both carry the same Data Schema authority.

The spec.feature and the selected journey variant are sufficient downstream input for BLUEPRINT `--start` on non-UI features.

---

## Tripartite Alignment Protocol

**MANDATORY on every `--refine` and before auto-approval on `--start`/`--refine` (i.e., before status becomes APPROVED).**

Ensures bidirectional 100% alignment across all applicable artifacts. Zero edge cases or missing representations allowed — downstream agents (BLUEPRINT, IMPLEMENT) depend on this being COMPLETE.

**Scope-aware matrix:**

| feature_scope | Artifacts in play | Applicable checks |
|---|---|---|
| `full-stack` | spec.feature + mock.html + user_journey.md | ALL 6 bidirectional + Action/Navigation (7-8) + Error/Edge (9-10) — full protocol |
| `frontend-only` | spec.feature + mock.html + user_journey.md | ALL 6 bidirectional + Action/Navigation (7-8) + Error/Edge (9-10) — full protocol |
| `backend-only` | spec.feature + user_journey.integration.md | **Only SPEC↔JOURNEY + JOURNEY↔SPEC** (checks 3-4 below); checks involving mock (1, 2, 5, 6, 7-8, 10) are **N/A**. Error chain check (9) adapted: no UI error states; integration/DLQ/retry paths required instead (see CHECK 7 in Auto-Approval). |
| `integration` | spec.feature + user_journey.integration.md | Same as `backend-only`. |

Disparity resolution and verification summary apply uniformly; the `ALIGNMENT_SUMMARY.checks_passed` denominator changes by scope (N/10 for UI, N/3 for backend-only/integration).

### Six Bidirectional Alignment Checks

1. **SPEC→MOCK**: Every scenario in spec.feature has corresponding UI representation in mock.html
   - Happy path scenarios → interactive flows visible in mock
   - Error scenarios → error states/messages visible in mock
   - Edge case scenarios → boundary UI behavior shown (empty, max length, overflow)
2. **MOCK→SPEC**: Every interactive element in mock.html has corresponding scenario in spec.feature
   - Every button/link/form → trigger mapped to a Gherkin `When` step
   - Every navigation target → scenario covering that transition
   - Every conditional UI (show/hide, enable/disable) → scenario with `Given` precondition
3. **SPEC→JOURNEY**: Every scenario references events/commands/schemas in user_journey.md
   - Every `When` step → maps to a Command in user_journey.md
   - Every `Then` step → maps to an Event or ReadModel in user_journey.md
   - Every `Given` step with data → maps to a DataIn/DataOut schema
4. **JOURNEY→SPEC**: Every command/event in user_journey.md is exercised by at least one scenario
   - No orphan commands (defined but never triggered)
   - No orphan events (defined but never asserted)
   - No orphan policies (defined but never verified)
5. **MOCK→JOURNEY**: Every data display/input in mock.html maps to schemas in user_journey.md
   - Every form field → maps to a DataIn schema field (name + type match)
   - Every displayed data point → maps to a ReadModel/DataOut schema field
   - Every form validation message → maps to a schema constraint ([required], [min:N], etc.)
6. **JOURNEY→MOCK**: Every read model/data schema in user_journey.md has visual representation in mock.html
   - Every DataOut field → visible in display component
   - Every required DataIn field → has form input with required indicator
   - Every enum field → has select/radio with ALL enum values shown

### Action & Navigation Alignment Checks

7. **ACTION→COMMAND**: Every action trigger in mock.html (button click, form submit, link with side-effect) maps to exactly one Command in user_journey.md
   - Button label matches command intent (e.g., "Submit Order" → SubmitOrder command)
   - Form submit targets match command DataIn schema
   - Destructive actions (delete, cancel) have confirmation pattern in mock AND scenario
8. **NAVIGATION→EXITS**: Every navigation link in mock.html that targets another page/feature is documented as Cross-Module Exit
   - Internal navigation → route exists in spec.feature scenarios
   - External feature navigation → documented in all 3 artifacts
   - Back/breadcrumb navigation → consistent with page hierarchy
   - 404/not-found states for broken/invalid navigation targets

### Error & Edge Case Completeness Checks

9. **ERROR-FULL-CHAIN**: Every error path is represented end-to-end across all 3 artifacts
   - **Domain errors**: error event in user_journey.md → error scenario in spec.feature → error UI in mock.html
   - **Validation errors**: schema constraint ([required], [max:N]) → validation scenario → form error message in mock
   - **External system errors**: external system failure in user_journey.md → timeout/error scenario → fallback UI in mock
   - **Authorization errors**: restricted command → unauthorized scenario → access denied UI
10. **EMPTY-LOADING-FULL-CHAIN**: Critical entities have empty, loading, and error states in ALL 3 artifacts
    - **Empty state**: no-data scenario in spec.feature + empty event/readmodel in user_journey.md + empty UI in mock.html
    - **Loading state**: async operation in user_journey.md + loading scenario in spec.feature + spinner/skeleton in mock.html
    - **Partial failure**: multi-item operation where some succeed → partial state in all 3 artifacts

### Verification Summary Table

At the end of alignment verification, produce a summary (saved to artifact `_progress`):

```yaml
ALIGNMENT_SUMMARY:
  checks_passed: N/10
  gaps_found: []      # List of { check_id, artifact, missing_item, severity }
  gap_severity:
    BLOCKER: Must fix before approval (missing error chain, orphan command, unlinked action)
    WARNING: Should fix (missing loading state for non-critical entity)
  verdict: ALIGNED | GAPS_FOUND
```

### Disparity Resolution Protocol
When any check fails:
1. Identify the gap (which artifact is missing what)
2. Classify severity: BLOCKER or WARNING
3. BLOCKER gaps → Propose fix via 1-to-1 RDR → Apply fix → Re-run check
4. WARNING gaps → Log to `_progress.alignment_warnings` → Proceed (BLUEPRINT will handle)
5. Re-run ALL checks after fixes to catch cascading effects

---

## Command: `--start {{FEATURE_ID}}`

**Branch Strategy:** CREATES new feature branch from main. REQUIRES explicit Feature ID from user.

**Scope input:** Accepts `--scope={full-stack|backend-only|frontend-only|integration}`. When omitted, defaults to `project_scope` from the governance snapshot. The Scope Compatibility Gate below validates the combination before any artifact is generated.

### Scope Compatibility Gate (BLOCKING, runs BEFORE Vision Gate)

```yaml
FUNCTION scope_compatibility_gate(FEATURE_ID, requested_scope):
  # Snapshot writes project_scope into setup_configuration AND stack_configuration sections (see
  # Factory-setup-materialization § Checkpoint 3.1 generate_governance_snapshot). Read from the
  # setup_configuration section to match the codebase convention (e.g. project_tracking reads
  # in blueprint-design / coherence-validation use the same path). Stack_configuration fallback
  # kept for defense-in-depth if snapshot is partially written.
  project_scope = READ(".context/governance_snapshot.md").setup_configuration.project_scope OR READ(".context/governance_snapshot.md").stack_configuration.project_scope OR "full-stack"
  feature_scope = requested_scope OR project_scope   # default to project_scope when flag omitted

  # Compatibility matrix (plan § Model)
  COMPATIBLE = {
    "full-stack":    ["full-stack", "backend-only", "frontend-only", "integration"],
    "backend-only":  ["backend-only", "integration"],
    "frontend-only": ["frontend-only"],
    "integration":   ["backend-only", "integration"]
  }

  IF feature_scope NOT IN COMPATIBLE[project_scope]:
    ❌ BLOCK (humanised): "Feature scope `{feature_scope}` is not compatible with project scope `{project_scope}`.
      Compatible feature scopes for this project: {COMPATIBLE[project_scope]}.
      Resolution: rerun `/codesign --start {FEATURE_ID} --scope=<compatible>` or revisit `/setup --init` to widen project_scope (not recommended mid-project)."
    APPEND_TO_WORKLOG: {action: "--start", result: "BLOCKED", reason: "scope_incompatible", feature_scope, project_scope}
    STOP

  RETURN feature_scope
```

The resolved `feature_scope` is written to `spec.feature`, `user_journey.md` (or `user_journey.integration.md` when scope in [backend-only, integration]), and — after BLUEPRINT `--start` — to `design.md` and `test_plan.md`. It is immutable after auto-approval.

### Vision Gate (UI Features — scope-aware)
Runs ONLY when `feature_scope IN [full-stack, frontend-only]` AND `frontend.framework != "None"`:
- **BLOCKS** if `docs/ux/vision/vision.md` does not exist or is not `status: APPROVED`
- Template composition: `app_shell.html` shell wraps feature's `<main>` content in mock.html

When `feature_scope IN [backend-only, integration]`: Vision Gate is **N/A**. No mock.html is generated, no app_shell composition, no Visual DNA checks. `user_journey.md` is replaced by `user_journey.integration.md` (see template selector below).

### Template Selector

| feature_scope | spec.feature | mock.html | user_journey variant |
|---|---|---|---|
| `full-stack` | `codesign/gherkin_master_template.feature` | `codesign/mock-template.html` | `codesign/user_journey_template.md` |
| `frontend-only` | `codesign/gherkin_master_template.feature` | `codesign/mock-template.html` | `codesign/user_journey_template.md` |
| `backend-only` | `codesign/gherkin_master_template.feature` | **N/A — not generated** | `codesign/user_journey.integration.md` |
| `integration` | `codesign/gherkin_master_template.feature` | **N/A — not generated** | `codesign/user_journey.integration.md` |

### Execution Flow (BIP — Batch Interactivity Protocol)
1. **Phase 0.3: Scope Compatibility Gate** (see above). BLOCK if incompatible. Persist resolved `feature_scope` into `_progress` for downstream phases.
2. Validate prerequisites (constitution; ux-constitution + vision gate ONLY when `feature_scope IN [full-stack, frontend-only]`)
3. Phase 0.5: CIP Domain Concept Check
4. **Phase 0.6: Defect Prevention Consultation (Advisory; scope-aware)**
   ```yaml
   # Consult the Defect Prevention Catalog filtered to this agent
   has_ui = feature_scope IN ["full-stack", "frontend-only"]   # scope is the canonical UI predicate
   applicable_dcs = consult_defect_catalog("CODESIGN", {feature_id: FEATURE_ID, has_ui: has_ui, feature_scope: feature_scope})
   IF applicable_dcs is not empty:
     # Advisory only — no blocking
     SHOW user: "ℹ️ {count} DC entries apply to this CODESIGN scope. They will be projected into spec.feature § Defect-Prevention Notes as drafting hints."
     FOR EACH dc IN applicable_dcs:
       ADD to spec.feature § Defect-Prevention Notes (created if absent):
         "- DC-{N} ({dc.name}) — {dc.check}"
   ELSE:
     LOG: "No CODESIGN-applicable DCs in catalog"
   ```
   See `.claude/rules/defect-prevention.md` § Mandatory Process Integration § 1 for the canonical consultation protocol. Phase 2 adds integration DCs (idempotency, retry/backoff, circuit breaker, DLQ, graceful shutdown) for `feature_scope IN [backend-only, integration]`.
5. **BIP Tier PROPOSAL:** Generate complete Event Storming proposal (scope-aware: all 7 phases for `full-stack`/`frontend-only`; phases 1-3 + 5-7 for `backend-only`/`integration`, **Phase 4 Read Model Discovery is N/A** — there is no UI consuming the read model). Write to `docs/.bip/{FEATURE_ID}_tier_proposal.md`. Return to Factory for RDR mediation with user.
6. **BIP Tier ARTIFACTS:** After proposal accepted, generate artifacts per scope (Template Selector above). For `full-stack`/`frontend-only`: spec.feature + mock.html + user_journey.md (three artifacts, PO↔UX iteration cycle). For `backend-only`/`integration`: spec.feature + user_journey.integration.md (two artifacts, PO-only cycle — UX hat is inactive). Re-apply the Phase 0.6 DC hints to the generated `spec.feature` if they were not preserved.
7. Run Phase 3 completeness check (all DataIn/DataOut have defined schemas)
8. Save all artifacts with `status: DRAFT`
9. **BIP Tier ALIGNMENT:** Run Tripartite Alignment check (scope-aware — when mock.html is N/A, only SPEC↔JOURNEY + JOURNEY↔SPEC bidirectional checks apply; see § Tripartite Alignment Protocol). Present gaps to user via RDR for resolution.
10. Run Auto-Approval Protocol (below)

### Auto-Approval Protocol (v8.2.0 — eliminates separate --approve command)

```yaml
FUNCTION codesign_auto_approve(FEATURE_ID):
  # After --start or --refine produces converged artifacts,
  # auto-run the blocking validations. If ALL applicable pass → auto-approve.

  base_path = "docs/spec/{FEATURE_ID}"
  failures = []
  feature_scope = READ("{base_path}/spec.feature").frontmatter.scope
  has_ui = feature_scope IN ["full-stack", "frontend-only"]
  journey_file = has_ui ? "user_journey.md" : "user_journey.integration.md"

  # CHECK 0 — Scope compatibility gate (always-on; re-verify after --refine)
  CHECK 0: feature_scope is compatible with project_scope from governance snapshot
           (re-run scope_compatibility_gate; fail here if project_scope was changed after --start,
           which can happen only via a post-hoc edit to docs/setup.md — a governance-scope violation).

  # Run the Blocking Validations (scope-aware — UX checks are N/A when has_ui=false)
  CHECK 1: spec.feature valid Gherkin syntax
  CHECK 2: [has_ui ? "mock.html WCAG 2.1 AA compliant" : "N/A (scope=backend-only/integration — no mock.html)"]
  CHECK 3: {journey_file} schemas complete (no TODO/TBD fields)
  CHECK 4: Tripartite Alignment — scope-aware bidirectional checks
           • has_ui=true → 6 checks (SPEC↔MOCK + SPEC↔JOURNEY + MOCK↔JOURNEY)
           • has_ui=false → 2 checks (SPEC↔JOURNEY + JOURNEY↔SPEC only; mock-involving checks are N/A)
  CHECK 5: [has_ui ? "Action→Command alignment (every mock action maps to a journey command)" : "N/A (no mock.html)"]
  CHECK 6: [has_ui ? "Navigation→Exits alignment (every mock link has matching route/cross-module exit)" : "N/A (no mock.html)"]
  CHECK 7: Error full-chain
           • has_ui=true → domain + validation + external + auth + UI error state
           • has_ui=false → domain + validation + external + auth (no UI path); integration scope additionally requires retry/backoff + dead-letter + idempotency error paths
  CHECK 8: [has_ui ? "Empty/Loading full-chain (empty + loading + partial failure states in all 3 artifacts)" : "N/A (no mock.html); backend-only/integration must document empty-result + pending + timeout + partial-batch in spec.feature + {journey_file} § Section 2 (Journey Steps) instead"]
  CHECK 9: Cross-module exits documented in all applicable artifacts (3 when has_ui=true, 2 when has_ui=false)
  CHECK 10: [has_ui ? "No inline styles in mock.html (IMP `<style>` block and `imp-*` classes are allowed; `style=\"\"` attributes are not)" : "N/A (no mock.html)"]
  CHECK 11: [has_ui ? "Empty/loading states for critical entities in mock.html (every `imp-step` section has data-state divs for default + empty + loading + error at minimum)" : "N/A (no mock.html)"]
  CHECK 12: All Data Schemas have types and constraints for required fields

  # Integration-scope addendum (when feature_scope=integration):
  # CHECK 13 (Phase 2 material): external system contract declared in spec.feature § External Systems + {journey_file} § Section 5.

  FOR EACH check IN [0..12]:
    IF check FAILS (and is not N/A for this scope):
      failures.push(check)

  IF failures.length == 0:
    # All 12 validations passed — auto-approve all 3 artifacts
    FOR EACH artifact IN [spec.feature, mock.html, user_journey.md]:
      UPDATE_FRONTMATTER("{base_path}/{artifact}", "status", "APPROVED")
    LOG: "CODESIGN auto-approved: all 12 validations passed"
    APPEND_TO_WORKLOG:
      {"timestamp":"YYYY-MM-DD","phase":"Co-Creation","user_agent":"CODESIGN","action":"--start {{FEATURE_ID}}","result":"APPROVED","feature_id":"{{FEATURE_ID}}","observations":"3 artifacts created + auto-approved (12/12 validations passed) — BLUEPRINT now enabled"}
  ELSE:
    # Leave as DRAFT — show which validations failed
    LOG: "Auto-approval blocked: {failures.length} validation(s) failed"
    SHOW: "⚠️ Validations failed: {failures}. Refine artifacts and re-run `CODESIGN --start {ID}` or `CODESIGN --refine {ID}`."
    APPEND_TO_WORKLOG:
      {"timestamp":"YYYY-MM-DD","phase":"Co-Creation","user_agent":"CODESIGN","action":"--start {{FEATURE_ID}}","result":"COMPLETED","feature_id":"{{FEATURE_ID}}","observations":"3 artifacts created — status: DRAFT (auto-approval blocked: {failures.length}/12 validations failed: {failures})"}

  # Execute Smart Redirect Protocol
  state = compute_feature_state(FEATURE_ID)
  actions = compute_next_actions(state, FEATURE_ID)
  render_next_steps(actions, FEATURE_ID)
```

---

## Command: `--refine {{FEATURE_ID}} "{{FEEDBACK}}"`

### Refine Execution Sequence
```yaml
# Step 1: Apply feedback (classify, route to PO/UX hats)
# Step 2: Compute refine_changes (diff of new vs existing concepts)
# Step 3: CIP Domain Concept Re-Check (CONDITIONAL — if new concepts detected):
#         CALL cip_refine_recheck(FEATURE_ID, refine_changes)
# Step 4: Change Classification Protocol (structural classification)
# Step 5: Iteration Execution (bump iteration, cascade, changelog)
# Step 6: Re-run Tripartite Alignment + auto-approval validations
```

### CIP Domain Concept Re-Check (CONDITIONAL — runs when refine introduces NEW concepts)

```yaml
FUNCTION cip_refine_recheck(FEATURE_ID, refine_changes):
  # This gate fires when --refine introduces NEW domain concepts
  # (new entities, events, commands, services) — not when modifying existing ones.
  # Prevents DRY violations when iterations add significant new domain scope
  # (e.g., job queue, new error categories, new storage services).

  new_concepts = EXTRACT_NEW_DOMAIN_CONCEPTS(refine_changes)
  # new_concepts = concepts NOT present in current spec.feature scenarios
  
  IF new_concepts.length == 0:
    ✅ SKIP — refine only modifies existing concepts
    RETURN

  inventory = READ("config/codebase_inventory.json")
  IF inventory IS MISSING:
    materialization = READ("docs/setup.md").materialization_complete
    IF materialization == true:
      ❌ BLOCK: "CIP inventory missing — cannot introduce NEW concepts after materialization. Run: SETUP --reconcile-inventory"
      LOG: "CIP_BLOCKED on --refine (inventory missing post-materialization; new concepts detected)"
      STOP
    ELSE:
      ⚠️ WARN: "CIP inventory missing pre-materialization — new concepts unchecked."
      LOG: "CIP_SKIPPED on --refine (inventory missing pre-materialization)"
      RETURN  # Degraded — pre-materialization only

  domain_concepts = EXTRACT_DOMAIN_CONCEPTS(inventory)
  overlaps = 0
  FOR EACH concept IN new_concepts:
    matches = MATCH_4_CRITERIA(concept, domain_concepts)
    IF matches.length > 0:
      overlaps += matches.length
      RDR per overlap: REUSE_EXISTING / RENAME_NEW / MERGE / KEEP_BOTH

  LOG: "CIP Refine Re-Check: {new_concepts.length} new concepts checked, {overlaps} overlaps resolved"
```

### Change Classification Protocol (when refining APPROVED specs with downstream work)

**Level 1: Structural Classification (Deterministic)**

```
DELTA (additive - does not break existing downstream):
  - New Scenario added
  - New NFR
  - New API endpoint (without modifying existing)
  - New OPTIONAL entity/field

BREAKING_CANDIDATE (potentially breaks downstream):
  - New Given/When/Then step at END of existing scenario
  - Modify Given/When/Then of existing scenario
  - Change business rule in existing scenario
  - Add REQUIRED field to existing entity

BREAKING (always breaks downstream):
  - Delete complete Scenario
  - Modify existing API contract (remove field, change type)
  - Change field type of existing entity
  - Rename core entity
```

**Level 2: Cross-Reference Downstream** (for BREAKING_CANDIDATEs)
- Check test_plan.md, design.md, dev_plan.md, and code for references to modified scenarios
- If referenced downstream: BREAKING CONFIRMED
- If not referenced: PROMOTE TO DELTA

**Level 3: Decision**
- `breaking_count == 0` → **ITERATION**: Open new iteration automatically
- `breaking > 0 AND delta > 0` → **HYBRID**: Offer SPLIT / ALL_REVISE / FORCE_DELTA
- `breaking > 0 AND delta == 0` → **REVISE**: New Feature ID

### Auto-Split Protocol (HYBRID mode, option 1)
- Delta changes: applied as new iteration to current feature
- Breaking changes: auto-scaffolded as new Feature ID
- Original feature: breaking scenarios marked `@superseded_by(NEW_ID)`

### Iteration Execution
- Increment `iteration` counter in spec.feature frontmatter
- Add to `iteration_history` with date and scope
- Update `last_iteration_scope`
- **MANDATORY: Append Iteration Changelog entry** to spec.feature (see format below)
- Re-run Tripartite Alignment Protocol
- **MANDATORY: Execute CASCADE_PENDING_ITERATION** to push `pending_iteration` to ALL downstream artifacts (design.md, test_plan.md, dev_plan.md, devops_plan.md)

### CASCADE Verification Gate (BLOCKING — runs AFTER every --refine iteration bump)

```yaml
FUNCTION verify_cascade_executed(FEATURE_ID, new_iteration):
  # This gate MUST execute AFTER cascade and BEFORE emitting Completion Summary.
  # It verifies that ALL existing downstream artifacts received pending_iteration.
  base_path = "docs/spec/{FEATURE_ID}"
  cascade_failures = []

  FOR EACH artifact IN [design.md, test_plan.md, dev_plan.md, devops_plan.md]:
    path = "{base_path}/{artifact}"
    IF FILE_EXISTS(path):
      fm = READ_FRONTMATTER(path)
      IF fm.pending_iteration != new_iteration:
        cascade_failures.push(artifact)

  IF cascade_failures.length > 0:
    ❌ BLOCK: "CASCADE INCOMPLETE — {cascade_failures.length} artifacts not updated:"
    FOR EACH f IN cascade_failures:
      SHOW: "  - {f}: pending_iteration != {new_iteration}"
    EXECUTE: CASCADE_PENDING_ITERATION(FEATURE_ID, new_iteration)  # Auto-fix
    LOG: "CASCADE auto-corrected: re-pushed to {cascade_failures}"

  ✅ CASCADE verified — all downstream artifacts notified
```

### CASCADE_PENDING_ITERATION (Explicit Frontmatter Updates)

```yaml
FUNCTION CASCADE_PENDING_ITERATION(FEATURE_ID, new_iteration):
  base_path = "docs/spec/{FEATURE_ID}"
  
  FOR EACH downstream_artifact IN [design.md, test_plan.md, dev_plan.md, devops_plan.md]:
    path = "{base_path}/{downstream_artifact}"
    IF FILE_EXISTS(path):
      UPDATE_FRONTMATTER(path):
        pending_iteration: {new_iteration}
        cascade_source: "CODESIGN --refine"
        cascade_timestamp: "{ISO_8601}"
        cascade_scope: "spec iteration {old} → {new_iteration}"
      LOG: "CASCADE: {downstream_artifact} → pending_iteration: {new_iteration}"
    ELSE:
      LOG: "CASCADE SKIP: {downstream_artifact} does not exist yet"
```
- APPEND_TO_WORKLOG:
  ```json
  {"timestamp":"YYYY-MM-DD","phase":"Co-Creation","user_agent":"CODESIGN","action":"--refine {{FEATURE_ID}}","result":"COMPLETED","feature_id":"{{FEATURE_ID}}","observations":"Iteration {{N}} — classification: {{DELTA|BREAKING|HYBRID}} — cascade: {{affected_artifacts}}"}
  ```

### Iteration Changelog Format (MANDATORY in spec.feature)

Every `--refine` that bumps the iteration MUST append a changelog entry to `spec.feature`:

```markdown
## Changelog

| Date | Iteration | Classification | Changes | Downstream Impact |
|------|-----------|---------------|---------|-------------------|
| {ISO_DATE} | {N-1} → {N} | {DELTA/BREAKING/HYBRID} | {list of added/modified/removed scenarios} | {CASCADE_PENDING_ITERATION targets} |
```

This changelog serves as:
- **Traceability:** What changed between iterations and why
- **Reference for BLUEPRINT:** Which scenarios need design/test updates
- **Reference for IMPLEMENT:** Which delta tasks to generate

---

## Command: `--revise {{FEATURE_ID}}`

Creates a new Feature ID from an existing one (for pure BREAKING changes):
- Copies existing artifacts as starting point
- Marks original scenarios as `@superseded_by(NEW_ID)`
- New feature has `iteration: 1` (fresh start)
- Original feature remains APPROVED but with superseded scenarios marked read-only

---

## Terminal State Commands

### `--cancel {{FEATURE_ID}}`
- Sets `status: CANCELLED` in all 3 artifacts
- CANCELLED is a **terminal state** — no agent can modify these artifacts
- Logs cancellation reason in worklog

### `--deprecate {{FEATURE_ID}}`
- Sets `status: DEPRECATED` in all 3 artifacts
- DEPRECATED is a **terminal state** — no agent can modify these artifacts
- Used when feature is replaced by a newer version

### `--reset {{FEATURE_ID}}`
- Resets artifacts back to `status: DRAFT` from `NEEDS_INFO`
- Clears blocking questions
- Does NOT work on APPROVED, CANCELLED, or DEPRECATED artifacts

---

## WCAG 2.1 AA Auto-Repair Protocol

When WCAG violations are found in `mock.html`:

```yaml
MAX_ITERATIONS = 3

FOR iteration IN 1..MAX_ITERATIONS:
  violations = SCAN_WCAG(mock.html)
  IF violations.length == 0:
    BREAK  # Compliant
  
  FOR EACH violation IN violations:
    IF violation.type == "contrast":
      AUTO_FIX: Adjust color to meet 4.5:1 ratio (darken/lighten nearest compliant value)
    IF violation.type == "touch_target":
      AUTO_FIX: Increase element size to ≥44px
    IF violation.type == "missing_alt":
      AUTO_FIX: Add descriptive alt text based on context
    IF violation.type == "missing_label":
      AUTO_FIX: Add aria-label or visible label
    IF violation.type == "missing_landmark":
      AUTO_FIX: Add appropriate ARIA landmark role
  
  SAVE mock.html

IF violations still exist after MAX_ITERATIONS:
  REPORT: List remaining violations for manual resolution
  SET mock.html wcag_status: "PARTIAL"
```

---

## Brand Drift Detection

On every `--refine`:
- Compare mock.html visual tokens against `style_guide.html` from vision
- Compare mock.html shell structure against `app_shell.html`
- If drift detected (hardcoded colors, non-token fonts, shell mismatch):
  - ⚠️ WARN with specific drift locations
  - AUTO_FIX where possible (replace hardcoded value with token)
  - Flag remaining drift for UX hat review

---

## Scenario-Level Supersession (Granular Immutability)

When HYBRID SPLIT or FORCE_DELTA modifies existing scenarios:

```gherkin
@superseded_by(NEW_FEATURE_ID, scenario="Modified scenario name")
@superseded_at(YYYY-MM-DD)
Scenario: Original scenario name
  Given ...
  When ...
  Then ...
```

**Rules:**
- Superseded scenarios are READ-ONLY — no agent can modify them
- Active scenarios continue evolving through iterations
- Downstream agents SKIP superseded scenarios during DELTA sync

---

## Cross-Agent Integration

| From Agent | Trigger | CODESIGN Action |
|-----------|---------|-----------------|
| SETUP | `--generate` completed + frontend != None | Factory Smart Redirect computes `--vision` as next step |
| CODESIGN --vision-approve | Vision APPROVED | Enables `--start` with template composition |
| CODESIGN auto-approval | All 3 artifacts APPROVED | Enables `BLUEPRINT --start` |
| CODESIGN --refine (Iteration) | spec.iteration bumped | Execute `CASCADE_PENDING_ITERATION` to all downstream |
| BLUEPRINT | Schema derivation | user_journey.md Data Schemas = source of truth |
| IMPLEMENT REVIEW | Mock fidelity check | [UX-*] sub-checks including [UX-VISION] |

---

## Error Handling

| Error | Response |
|-------|----------|
| Vision not approved + UI feature | BLOCK with "Run `CODESIGN --vision-approve` first" |
| Feature ID missing | BLOCK with "Feature ID required per project naming policy" |
| Spec invalid Gherkin | 🎩 PO auto-fixes syntax, re-validates |
| WCAG violation in mock | Run WCAG Auto-Repair Protocol (max 3 iterations) |
| Schema incomplete at approve | BLOCK with list of incomplete schemas |
| Tripartite misalignment | Run Disparity Resolution Protocol per gap |
| CANCELLED/DEPRECATED feature | HARD BLOCK — terminal state, no modifications allowed |

---

## Mandatory Laws (Procedural Gates)

1. **Protected Blocks**: NEVER modify code between `PROTECTED-CODE START` and `PROTECTED-CODE END` or paths in `config/protected-paths.json`
2. **Constitutional Supremacy**: The stack in `docs/constitution.md` is LAW
3. **Regulatory Compliance**: Follow styles/guidelines in .claude/rules/ (specifically: ux-constitution.md, branching.md, privacy.md, immutability_policy.md, ai_budget_tracker.md, frontend_architecture_compatibility.md, html-css.md)

### Data Schema Authority Gate (BLOCKING — H-15)
```yaml
FUNCTION verify_schema_authority(FEATURE_ID, proposed_data_fields):
  # Runs when BLUEPRINT or IMPLEMENT proposes data fields for contracts/models.
  # user_journey.md Data Schemas are the SOLE source of truth for business fields.
  uj_path = "docs/spec/{FEATURE_ID}/user_journey.md"
  IF NOT FILE_EXISTS(uj_path):
    ❌ BLOCK: "user_journey.md not found — cannot validate data fields"
    STOP

  uj_schemas = READ(uj_path, "Data Schemas")

  FOR EACH field IN proposed_data_fields:
    IF field.category == "business":  # name, email, role, status, etc.
      IF field.name NOT IN uj_schemas:
        ❌ BLOCK: "Business field '{field.name}' not found in user_journey.md Data Schemas"
        SHOW: "Downstream agents formalize but do NOT invent business fields"
        RDR: "Add field to user_journey.md via CODESIGN --refine {FEATURE_ID}?"
        STOP
    # Technical fields (id, created_at, updated_at, hash) are free — no check needed

  ✅ All business fields validated against user_journey.md
```

### Atomic Persistence Gate (BLOCKING — M-07, IPP-compliant)

> **Implements:** Incremental Persistence Protocol (`.claude/skills/factory-incremental-persistence/SKILL.md`) — Pillars 1, 2, 3.

**Pillar 1 — Skeleton-First Write (before content generation):**
```yaml
FUNCTION codesign_skeleton_first(FEATURE_ID):
  base_path = "docs/spec/{FEATURE_ID}"
  
  # Create skeletons for ALL 3 artifacts BEFORE generating content
  FOR EACH artifact IN [user_journey.md, spec.feature, mock.html]:
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
            last_agent: "CODESIGN"
            last_command: "--start {FEATURE_ID}"
            resumable: true
        body: SECTION_HEADERS_WITH_PENDING_MARKERS(artifact)
      SAVE(path)  # IMMEDIATE
  LOG: "Skeletons created for {FEATURE_ID}: 3 artifacts"
```

**Pillar 2 — Section-Atomic Saves (during generation):**
```yaml
FUNCTION enforce_atomic_persistence(artifact_path, section_id, content):
  # Runs AFTER every section completion. Save MUST happen immediately.
  # Never leave unsaved state across user interaction.
  REPLACE_SECTION(artifact_path, section_id, content)
  
  UPDATE_FRONTMATTER(artifact_path):
    _progress.completed_sections: APPEND(section_id)
    _progress.pending_sections: REMOVE(section_id)
    _progress.current_phase: "{next_section_or_complete}"
    updated_at: "{ISO_8601}"
  
  SAVE(artifact_path)  # IMMEDIATE — no batching

  # Verify save was successful
  IF FILE_MODIFIED_TIME(artifact_path) < NOW() - 5_SECONDS:
    ❌ BLOCK: "Atomic save failed for {artifact_path} — file not updated"
    RETRY: SAVE(artifact_path)
    IF still failed: ESCALATE to user

  LOG: "Section saved: {section_id} in {artifact_path}"
  # Rule: NEVER hold multiple unsaved sections in memory
  # Rule: NEVER batch saves across multiple artifacts
  # Rule: NEVER continue to next section until current section is on disk
```

**Pillar 3 — Resume-on-Entry (on --start or --refine):**
```yaml
FUNCTION codesign_resume_check(FEATURE_ID, command):
  base_path = "docs/spec/{FEATURE_ID}"
  
  FOR EACH artifact IN [user_journey.md, spec.feature, mock.html]:
    path = "{base_path}/{artifact}"
    IF FILE_EXISTS(path):
      fm = READ_FRONTMATTER(path)
      IF fm._progress IS NOT NULL AND fm._progress.pending_sections.length > 0:
        LOG: "RESUME: {artifact} has {fm._progress.completed_sections.length} done, {fm._progress.pending_sections.length} pending"
        RECOVER_DECISIONS(fm._progress.decisions)
        RESUME_FROM(fm._progress.pending_sections[0])
        RETURN "RESUMED"
  
  RETURN "FRESH"  # No in-progress artifacts found
```

**Decision Persistence (on every RDR):**
```yaml
# Every RDR answer is persisted IMMEDIATELY to the artifact where it applies
FUNCTION persist_rdr_decision(artifact_path, question, recommendation, user_choice):
  decision = { id: "RDR-{seq}", question, recommendation, user_choice, timestamp: "{ISO_8601}" }
  UPDATE_FRONTMATTER(artifact_path, "_progress.decisions", APPEND(decision))
  # Also inline: <!-- RDR-{N}: {question} → {user_choice} -->
  SAVE(artifact_path)  # IMMEDIATE
```

**Finalization (on approval):**
```yaml
# When artifact reaches APPROVED, clean _progress (no longer needed for resume)
FUNCTION finalize_codesign_artifact(artifact_path):
  UPDATE_FRONTMATTER(artifact_path):
    status: APPROVED
    _progress: null  # REMOVE — artifact complete
  SAVE(artifact_path)
  # Inline RDR comments remain for downstream traceability
```

### Tripartite Alignment Canary (BLOCKING — M-08, summarization-safe)

> **Problem:** CODESIGN generates 3 artifacts in dependency order (user_journey.md → spec.feature → mock.html). If summarization occurs between artifacts, the agent loses the content of the upstream artifact from memory and writes the downstream artifact without referencing actual schemas, events, or scenarios → **cross-artifact drift**.

> **Solution:** Before writing each downstream artifact, re-read the **key contract data** from the upstream artifact(s) already on disk. The file is the source of truth — not conversation memory.

> **Cost:** ~150-300 tokens per cross-artifact check (reading schemas/events summary, NOT full file).

```yaml
FUNCTION tripartite_alignment_canary(FEATURE_ID, target_artifact):
  base_path = "docs/spec/{FEATURE_ID}"
  
  # Determine what upstream data this artifact needs
  IF target_artifact == "spec.feature":
    # spec.feature depends on user_journey.md (commands, events, schemas, policies)
    uj_path = "{base_path}/user_journey.md"
    IF FILE_EXISTS(uj_path):
      uj = READ_SECTIONS(uj_path, ["commands", "events", "data_schemas", "policies"])
      upstream_contract = {
        commands: EXTRACT_NAMES(uj.commands),       # e.g., ["SubmitOrder", "CancelOrder"]
        events: EXTRACT_NAMES(uj.events),           # e.g., ["OrderSubmitted", "OrderCancelled"]
        schemas: EXTRACT_SCHEMA_NAMES(uj.schemas),  # e.g., ["OrderDataIn", "OrderReadModel"]
        policies: EXTRACT_NAMES(uj.policies)        # e.g., ["AutoConfirmUnder50"]
      }
      RETURN { upstream: upstream_contract, source: "user_journey.md" }
    ELSE:
      ⚠️ WARN: "user_journey.md not found — spec.feature has no upstream to verify"
      RETURN { upstream: null }
  
  IF target_artifact == "mock.html":
    # mock.html depends on BOTH user_journey.md (schemas) AND spec.feature (scenarios, errors)
    upstream_contract = {}
    
    uj_path = "{base_path}/user_journey.md"
    IF FILE_EXISTS(uj_path):
      uj = READ_SECTIONS(uj_path, ["data_schemas", "read_models"])
      upstream_contract.schemas = EXTRACT_SCHEMA_NAMES(uj.schemas)
      upstream_contract.read_models = EXTRACT_NAMES(uj.read_models)
    
    spec_path = "{base_path}/spec.feature"
    IF FILE_EXISTS(spec_path):
      spec = READ_SECTIONS(spec_path, ["scenarios"])
      upstream_contract.scenarios = EXTRACT_SCENARIO_NAMES(spec.scenarios)
      upstream_contract.error_scenarios = FILTER(spec.scenarios, s => s.contains("error") OR s.contains("fail") OR s.contains("invalid"))
    
    RETURN { upstream: upstream_contract, source: "user_journey.md + spec.feature" }
  
  IF target_artifact == "user_journey.md":
    # user_journey.md is the ROOT — no upstream dependency
    RETURN { upstream: null }

# Integration: call BEFORE writing each artifact's content sections
FUNCTION codesign_write_with_alignment(FEATURE_ID, target_artifact, section_id, content):
  # Step 1: IPP Canary (section-level — already mandatory)
  ipp_canary_gate("{base_path}/{target_artifact}", section_id)
  
  # Step 2: Alignment Canary (cross-artifact — re-read upstream from disk)
  alignment = tripartite_alignment_canary(FEATURE_ID, target_artifact)
  
  IF alignment.upstream IS NOT NULL:
    # Verify the content being written actually references upstream data
    # This is a SOFT check — warns but doesn't block (agent may be writing a section
    # that legitimately doesn't reference all upstream items)
    LOG: "Alignment canary: writing {target_artifact}/{section_id} with upstream from {alignment.source}"
    LOG: "  Available: {alignment.upstream}"
    # The agent now has fresh upstream data in context, even after summarization
  
  # Step 3: Proceed with atomic save
  enforce_atomic_persistence("{base_path}/{target_artifact}", section_id, content)
```

**When does it fire:**
- `--start`: Before writing spec.feature content (re-reads user_journey.md), before writing mock.html content (re-reads both)
- `--refine`: Before modifying any downstream artifact section (re-reads upstream to detect drift)
- Does NOT fire for user_journey.md writes (it's the root artifact — no upstream)

**What it catches:**
- Post-summarization schema amnesia: agent forgot the exact field names/types from user_journey.md
- Error scenario gaps: agent forgot which error events exist when writing mock error states
- Scenario↔UI drift: agent forgot scenario names when building mock.html interactive elements
- The 6-check Tripartite Alignment Protocol runs AFTER all artifacts are done; this canary prevents drift DURING generation

### One Question at a Time Gate (BLOCKING — L-03)
```yaml
FUNCTION enforce_single_question_rdr():
  # Runs BEFORE every RDR (Requirement Decision Request).
  # CODESIGN must NEVER batch multiple questions in a single prompt.
  IF pending_questions.length > 1:
    ❌ BLOCK: "RDR violation: {pending_questions.length} questions batched. Process one at a time."
    current_question = pending_questions.SHIFT()  # Take first only
    PRESENT: current_question
    WAIT for answer
    SAVE answer immediately (atomic persistence)
    THEN: Process remaining questions one by one
  ELSE:
    PRESENT: pending_questions[0]
    WAIT for answer
    SAVE answer immediately

  # Rule: One question → wait → save → next. Always.
```
