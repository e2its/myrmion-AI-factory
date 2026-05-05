---
description: "Factory CODESIGN UX vision — application shell, style guide, design system, component library, navigation map. Use when: CODESIGN --vision command execution."
---

# CODESIGN Agent — Level 1: Global Vision Protocol

## Purpose
This instruction file defines the **Global UX Vision** protocols for the CODESIGN agent (🎩 PO Hat + 🎨 UX Hat). Vision is the first visual layer: before any feature is co-created, the application needs a unified visual identity.

**Vision artifacts** live in `docs/ux/vision/` and define the global visual contract that ALL frontend implementation MUST follow.

---

## Generated Vision Artifacts (6 files in `docs/ux/vision/`)

1. **`vision.md`** — Global vision manifesto with frontmatter (`status: DRAFT | APPROVED`)
2. **`app_shell.html`** — App Shell Mock (header, sidebar, footer, nav) — base visual template
3. **`style_guide.html`** — Interactive visual style guide (tokens, colors, typography, spacing)
4. **`page_templates.html`** — Page type templates (dashboard, list, detail, form, error, empty state)
5. **`component_library.html`** — Reusable component library
6. **`navigation_map.md`** — Navigation map with links between pages

---

## Aesthetic Quality Directives (D0-D9)

All vision artifacts MUST comply with these directives. They define the difference between "functional" and "professional" UI.

### D0: Visual DNA Loading
- Load `.claude/rules/ux-constitution.md` for project-level UX rules
- Load External Design System from `docs/ux/design-system/` if it exists
- Extract color palette, typography scale, spacing rhythm, border-radius tokens, shadow tokens
- If no DS exists, derive from `ux-constitution.md` or propose defaults with RDR

### D1: Spacing Discipline
- Use consistent spacing scale (e.g., 4px base: 4, 8, 12, 16, 24, 32, 48, 64)
- NO magic numbers — all spacing must reference the scale
- Padding inside components follows the same rhythm as margin between components
- Dense layouts allowed for dashboards, but must still follow the scale

### D2: Border-Radius Consistency
- Define ONE border-radius strategy (sharp: 0, soft: 4-6px, pill: 999px, mixed: per-component)
- Apply consistently: cards, buttons, inputs, modals, tags — all from the same token
- If brand guidelines specify border-radius, those win

### D3: Shadow / Elevation System
- Define elevation levels (0: flat, 1: subtle, 2: raised, 3: floating, 4: overlay)
- Map components to elevation: Cards=1, Dropdowns=3, Modals=4, Buttons=0
- Shadow color derived from primary palette (never pure black shadows)
- Dark mode: use lighter shadow or border-based elevation

### D4: Typography Scale
- Hierarchical type scale (e.g., 12, 14, 16, 18, 20, 24, 30, 36, 48)
- Maximum 2 font families (1 heading + 1 body)
- Line-height: 1.4-1.6 for body, 1.1-1.3 for headings
- Font weight: 400/500/600/700 only (avoid 100-300 for UI)

### D5: Color Usage Protocol
- Primary color: main actions, active states, links
- Secondary color: secondary actions, highlights, categories
- Neutral palette: text, backgrounds, borders, dividers (at least 5 shades)
- Semantic colors: success(green), warning(amber/orange), error(red), info(blue)
- Color contrast MUST meet WCAG 2.1 AA (4.5:1 normal text, 3:1 large text/UI)
- Never use color alone for meaning (add icons/text for colorblind users)

### D6: Micro-Interactions
- Button states: default → hover → active → disabled (all 4 MANDATORY)
- Form inputs: default → focus → error → disabled → readonly
- Loading states: skeleton screens preferred over spinners for content areas
- Transitions: 150-300ms ease-out for most UI transitions
- Touch feedback on mobile: visual response within 50ms

### D7: Decorative Elements
- Decorative elements must serve a purpose (visual hierarchy, branding, wayfinding)
- If using illustrations/patterns, ensure they don't compete with functional UI
- Decorative borders/lines should use neutral palette tokens
- Empty states SHOULD include illustration + helpful text + CTA

### D8: Icon Integration
- Use ONE icon library consistently (Lucide, Heroicons, Material Symbols, etc.)
- Icon size follows spacing scale (16, 20, 24, 32)
- Icons in buttons: leading position, same optical size as text
- Functional icons MUST have `aria-label` or `aria-hidden="true"` + visible text

### D9: Visual Quality Reference
- ❌ SPARTAN: plain text, no visual hierarchy, raw HTML feel, no padding, monochrome
- ✅ PROFESSIONAL: clear hierarchy, consistent spacing, brand colors, polished borders, balanced whitespace, purposeful shadows

---

## Command: `--vision`

**Branch:** Creates `feature/UX-VISION-global-app-design`
**Lock:** `.context/locks/ux-vision.lock` (project-scoped)

### Prerequisites
- `docs/setup.md` with `phase: COMPLETED`
- `.claude/rules/ux-constitution.md` materialized
- `frontend.framework != "None"` in `docs/setup.md`
- **`project_scope IN [full-stack, frontend-only]`** (`docs/setup.md` `project_scope` field, mirrored in `.context/governance_snapshot.md § Stack Configuration`)

### Scope Guard (BLOCKING)

```yaml
FUNCTION vision_scope_guard():
  # Read from setup_configuration section (matches the codebase convention in
  # blueprint-design / coherence-validation; see Factory-setup-materialization § Checkpoint 3.1
  # generate_governance_snapshot where the snapshot writes project_scope into both
  # setup_configuration and stack_configuration sections). Stack_configuration fallback kept
  # for defense-in-depth.
  project_scope = READ(".context/governance_snapshot.md").setup_configuration.project_scope OR READ(".context/governance_snapshot.md").stack_configuration.project_scope OR "full-stack"

  IF project_scope IN ["backend-only", "integration"]:
    ❌ BLOCK (humanised): "CODESIGN --vision is not applicable for project_scope=`{project_scope}`.
      Global UX Vision defines the visual identity for first-party UI. Projects with scope `backend-only` or `integration` have no first-party UI — individual features run on per-feature scope `backend-only`/`integration` and skip mock.html.
      Resolution:
        • If this project genuinely needs UI, revisit `/setup --init` and widen project_scope to `full-stack` or `frontend-only`.
        • If a single feature needs UI inside an otherwise backend-only project, that is NOT supported by the compatibility matrix (see Project Scope & Feature Scope Taxonomy in CLAUDE.md). Split the feature into a frontend-only project that consumes the backend via contract."
    APPEND_TO_WORKLOG: {action: "--vision", result: "BLOCKED", reason: "scope_incompatible", project_scope}
    STOP
```

The guard runs immediately after the Prerequisites check and BEFORE any input-mode detection or artifact generation.

### Input Mode Detection (MANDATORY)

Before generating, detect available inputs to determine the generation mode:

```yaml
FUNCTION detect_vision_input_mode():
  has_external_ds = FILE_EXISTS("docs/ux/design-system/") AND DIRECTORY_NOT_EMPTY
  has_app_mockup = SCAN_FOR_APP_MOCKUP()  # User-provided full app mockup
  has_code_layout = SCAN_WORKSPACE_FOR_LAYOUT()  # Existing code with layout
  
  IF has_external_ds AND has_app_mockup:
    MODE = "MERGE"  # Merge DS tokens + mockup structure
  ELIF has_external_ds AND NOT has_app_mockup:
    MODE = "FROM_DS"  # Derive vision from DS tokens
  ELIF has_app_mockup AND NOT has_external_ds:
    MODE = "FROM_MOCKUP"  # Extract vision from existing mockup
  ELIF has_code_layout:
    MODE = "FROM_CODE"  # Extract vision from existing code layout
  ELSE:
    MODE = "FROM_SCRATCH"  # Build vision from ux-constitution + RDR
  
  RETURN MODE
```

### Code Layout Detection (if applicable)

Framework-aware, architecture-agnostic detection of existing layout in codebase. Two-pass scan:

1. **Framework-specific layout file patterns** — detect based on `frontend.framework` from constitution.md
2. **Semantic structural indicators** — detect shell regions (header, sidebar, footer, nav, main)

**Positive detection** if: ≥1 framework layout file found, OR ≥2 shell regions detected, OR template inheritance + region detected.

**Six Layout Archetypes:**
- **SKELETON:** Single root layout wrapping `{children}` (React/Next/Vue/Nuxt pattern)
- **SINGLE_WRAPPER:** One layout component applied globally (Angular `app.component`, Svelte `+layout`)
- **TEMPLATE_INHERITANCE:** Parent→child template chain (Django `base.html`→`extends`, Laravel Blade `@extends`)
- **MULTI_LAYOUT:** Multiple named layouts (Next.js route groups, Nuxt `definePageMeta({layout})`)
- **FLAT:** No layout system detected — all pages standalone
- **NON_TRADITIONAL:** Framework-specific pattern not matching above (detect and describe)

**Framework-Aware Extraction:** Scan targets vary by frontend framework:
- React/Next: `app/layout.*`, `src/layouts/`, `components/Layout*`
- Vue/Nuxt: `layouts/`, `App.vue`, `src/layouts/`
- Angular: `app.component.*`, `src/app/layout/`
- Svelte/SvelteKit: `+layout.svelte`, `src/routes/+layout*`
- Django: `templates/base*.html`, `templates/layouts/`
- Laravel: `resources/views/layouts/`, `resources/views/components/`

### Vision Phases (V.1-V.7)

#### Phase V.1: Business Context + Input Ingestion (🎩 PO hat) — BIP Harvest
- Read `docs/setup.md` for project context (industry, target users, brand info)
- Load available inputs per detected MODE
- Extract color palette, typography, component inventory from available sources
- If FROM_SCRATCH: Generate a **BIP Decision Batch** with all foundational visual decisions (industry feel, density preference, color mood, spacing rhythm, icon library) + Conditional Navigation Matrix. Mark pivotal questions (`pivotal: true`). Write to `docs/.bip/UX-VISION_tier_visual_dna.md`. Return to Factory for RDR mediation. Factory presents each visual decision to the user one-by-one via RDR.

#### Phase V.2: App Shell (🎨 UX hat)
- Generate `app_shell.html` — the base visual skeleton
- Define: header (logo, nav, user menu), sidebar (if applicable), main content area, footer
- Responsive breakpoints (mobile-first)
- Apply Directives D0-D9 to shell

#### Phase V.3: Style Guide (🎨 UX hat)
- Generate `style_guide.html` — interactive token reference
- Sections: Colors (palette + semantic), Typography (scale + samples), Spacing (scale + examples), Borders, Shadows, Icons
- Each token has: name, CSS variable, visual sample, usage notes

#### Phase V.4: Page Templates (🎩↔🎨 alternating)
- Generate `page_templates.html` — at least 4 core templates:
  - Dashboard (cards, charts, KPIs)
  - List/Table (data grid, filters, pagination)
  - Detail/View (content display, actions)
  - Form (inputs, validation, submission)
- Optional: Error page, Empty state, Loading skeleton
- Templates inherit app_shell structure

#### Phase V.5: Component Library (🎨 UX hat)
- Generate `component_library.html` — reusable base components
- MUST include: Button (variants), Input (types), Card, Modal, Table, Badge/Tag, Alert/Toast, Dropdown/Select
- Each component: default + hover + active + disabled states
- Components use style_guide tokens

#### Phase V.6: Navigation Map (🎩 PO hat)
- Generate `navigation_map.md` — application navigation structure
- Map pages/sections with links between them
- Define primary nav, secondary nav, breadcrumbs strategy
- Must have ≥3 pages/sections

#### Phase V.7: WCAG Convergence (Both hats)
- Validate ALL vision artifacts against WCAG 2.1 AA
- Color contrast verification (4.5:1 text, 3:1 UI)
- Touch target sizes (≥44px)
- Keyboard navigation plan
- Screen reader landmarks in app_shell
- Run WCAG Auto-Repair if violations found (max 3 iterations)

---

## Command: `--vision-refine "[FEEDBACK]"`

- Load all 6 vision artifacts
- Apply feedback changes
- Re-run WCAG validation on affected artifacts
- Maintain consistency across all artifacts after changes
- Atomic persistence: save each modified artifact immediately

---

## Command: `--vision-approve`

### Blocking Validations (ALL must pass)
1. WCAG 2.1 AA compliant across all HTML artifacts
2. No inline styles (all styling via CSS variables/classes referencing style_guide tokens)
3. `navigation_map.md` has ≥3 pages/sections
4. `component_library.html` has base components (Button, Input, Card minimum)
5. All artifacts exist and are non-empty

### On Approval
- Update `vision.md` frontmatter: `status: APPROVED`
- Enables template composition in `--start` (features inherit app_shell)
- Log in worklog

---

## Command: `--vision-propagate`

**Prerequisite:** `vision.md` with `status: APPROVED`

- Scans all existing feature `mock.html` files in `docs/spec/*/`
- Recomposes the shell of each mock (header, sidebar, footer, nav) from latest `app_shell.html`
- Preserves `<main>` content of each feature mock
- Reports modified files
- Use when vision was refined/updated after features were already created

---

## Cross-Agent Vision Consumption

| Agent | Vision Artifacts Used | Purpose |
|-------|----------------------|---------|
| CODESIGN --start | app_shell.html, component_library.html | Template composition for feature mock.html |
| BLUEPRINT | app_shell.html, component_library.html, style_guide.html | Component architecture, layout patterns, design tokens |
| IMPLEMENT --plan | All 6 artifacts | Vision Gate prerequisite check |
| IMPLEMENT --build | All 6 artifacts | Frontend MUST materialize vision faithfully |
| IMPLEMENT REVIEW | component_library.html, style_guide.html | [UX-VISION] check: reuse, token consistency |
