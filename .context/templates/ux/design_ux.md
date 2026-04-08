---
status: DRAFT
feature_id: "{{FEATURE_ID}}"
created_at: "{{TIMESTAMP}}"
updated_at: "{{TIMESTAMP}}"
version: 1.0
parent_spec: ""  # Optional: For feature versioning (v2, v3, etc.)
wcag_compliant: false
iterations_required: 0
---

# UX Design: {{FEATURE_ID}}

## Section 0: UX Decision History (RDR Tracking)

> **Purpose:** Chronological record of all decisions made during UX design. Maintains traceability and context for future refinements.

- [{{DATE}}] **Decision:** {{DESCRIPTION}}
- [{{DATE}}] **Rationale:** {{JUSTIFICATION}}
- [{{DATE}}] **Auto-fix:** {{FIX_DESCRIPTION}}
- [{{DATE}}] **Feedback:** {{USER_FEEDBACK}}

---

## Section 1: Executive Summary

**Overview:**
{{BRIEF_DESCRIPTION_OF_UX_APPROACH}}

**User Personas:**
- **Persona 1:** {{NAME}} - {{DESCRIPTION}}
- **Persona 2:** {{NAME}} - {{DESCRIPTION}}

**Experience Goals:**
- {{GOAL_1}}
- {{GOAL_2}}
- {{GOAL_3}}

---

## Section 2: User Flows

> **Purpose:** Flow diagram for each Gherkin scenario, showing navigation and UI states.

### Flow 1: {{FLOW_NAME}}

```
[{{STARTING_STATE}}] → {{ACTION}} → [{{NEXT_STATE}}]
                           ↓ ({{ALTERNATIVE_PATH}})
                       [{{ERROR_STATE}}]
```

**Covered Scenarios:** spec.feature lines {{LINE_NUMBERS}}

**Involved Components:**
- {{COMPONENT_NAME}} ({{PATH}}) - {{REUSE_OR_CREATE}}

### Flow 2: {{FLOW_NAME}}

```
[{{STARTING_STATE}}] → {{ACTION}} → [{{NEXT_STATE}}]
```

**Covered Scenarios:** spec.feature lines {{LINE_NUMBERS}}

---

## Section 3: Component Inventory

> **Purpose:** Catalog of UI components to use/create, with reuse decisions.

| Required Component | Source | Variant | Decision | Notes |
|---------------------|--------|----------|----------|-------|
| {{COMPONENT_NAME}} | {{SOURCE_PATH}} | {{VARIANT}} | **REUTILIZAR** | {{NOTES}} |
| {{COMPONENT_NAME}} | NUEVO | {{VARIANT}} | **CREAR** | {{PATTERN_REFERENCE}} |

**Summary:**
- Reused Components: {{COUNT}}
- New Components: {{COUNT}}
- Efficiency: {{PERCENTAGE}}% reuse

---

## Section 4: Accessibility Checklist (WCAG 2.1 AA)

> **Purpose:** WCAG 2.1 AA compliance verification. All items must be ✅ before approval.

- [ ] **Color Contrast:** Ratio ≥ 4.5:1 for normal text (AA compliance)
  - {{ELEMENT}}: {{COLOR}} on {{BACKGROUND}} → {{RATIO}}:1
- [ ] **Touch Targets:** All interactive elements ≥ 44px
  - {{ELEMENT}}: {{SIZE}}px
- [ ] **Alt Text:** All images have descriptive alt
  - {{IMAGE}}: alt="{{TEXT}}"
- [ ] **Keyboard Navigation:** Logical tab order, focus visible
  - Tab order: {{ORDER}}
  - Focus indicator: {{STYLE}}
- [ ] **ARIA Labels:** Inputs with appropriate labels
  - {{INPUT}}: aria-label="{{LABEL}}"
- [ ] **Semantic HTML:** Correct use of HTML5 tags
  - Forms: {{TAGS}}
  - Headings: Correct hierarchy (h1 → h2 → h3)

**Validation:**
- Script: `scripts/ux-validation.sh --wcag mock.html`
- Result: {{PASS_OR_FAIL}}
- Iterations Required: {{NUMBER}}

---

## Section 5: Responsive Design Strategy

> **Purpose:** Adaptation strategy for different devices and breakpoints.

**Approach:** Mobile-first

**Breakpoints (defined in ux-constitution.instructions.md):**
- **Mobile:** < 640px (base, no media query)
- **Tablet:** ≥ 640px
- **Desktop:** ≥ 1024px
- **Wide Desktop:** ≥ 1280px

**Layout by Breakpoint:**

| Viewport | Layout | Grid | Notes |
|----------|--------|------|-------|
| Mobile (< 640px) | {{LAYOUT}} | {{GRID}} | {{NOTES}} |
| Tablet (≥ 640px) | {{LAYOUT}} | {{GRID}} | {{NOTES}} |
| Desktop (≥ 1024px) | {{LAYOUT}} | {{GRID}} | {{NOTES}} |
| Wide (≥ 1280px) | {{LAYOUT}} | {{GRID}} | {{NOTES}} |

**Image Optimization:**
- Lazy loading: `loading="lazy"` on images below fold
- Responsive images: `srcset` con 1x, 2x, 3x variants
- Formats: WebP con fallback PNG/JPEG

---

## Section 6: Design Tokens Application

> **Purpose:** Mapping of abstract tokens from ux-constitution.instructions.md to concrete usage in this feature. Includes Brand Identity tokens (Section I) and Visual DNA (Section I-bis).

### 6.1 Color Tokens (from ux-constitution.instructions.md Section I.1)
- `var(--primary)`: {{HEX_VALUE}} → Usado en {{USAGE}}
- `var(--primary-hover)`: {{HEX_VALUE}} → Estado hover
- `var(--secondary)`: {{HEX_VALUE}} → {{USAGE}}
- `var(--accent)`: {{HEX_VALUE}} → {{USAGE}}
- `var(--semantic-error)`: {{HEX_VALUE}} → Error messages
- `var(--semantic-success)`: {{HEX_VALUE}} → Success messages
- `var(--semantic-warning)`: {{HEX_VALUE}} → Alerts
- `var(--semantic-info)`: {{HEX_VALUE}} → Information

**Color Distribution (per Directive 5):**
| Role | Target % | Actual Usage in This Feature |
|------|----------|------------------------------|
| Primary | 10-15% | {{ACTUAL_USAGE}} |
| Secondary | 5-10% | {{ACTUAL_USAGE}} |
| Accent | 3-5% | {{ACTUAL_USAGE}} |
| Neutral | 50-60% | {{ACTUAL_USAGE}} |

### 6.2 Typography Tokens (from ux-constitution.instructions.md Section I.2)
- `var(--font-heading)`: {{FONT_FAMILY}} → Headings
- `var(--font-body)`: {{FONT_FAMILY}} → Body text
- `var(--text-4xl)`: {{SIZE}} → h1 hero
- `var(--text-3xl)`: {{SIZE}} → h1 page
- `var(--text-xl)`: {{SIZE}} → h2 section
- `var(--text-lg)`: {{SIZE}} → h3 card
- `var(--text-base)`: {{SIZE}} → Body text
- `var(--text-sm)`: {{SIZE}} → Metadata, labels
- `var(--text-xs)`: {{SIZE}} → Help text, captions

**Typography Contrast Level:** {{VISUAL_DNA_TYPOGRAPHY_CONTRAST}}
| Element | Weight Class | Tracking | Leading |
|---------|-------------|----------|---------|
| h1 | {{WEIGHT}} | tracking-tight | leading-tight |
| h2 | {{WEIGHT}} | {{TRACKING}} | leading-tight |
| body | font-normal | tracking-normal | leading-relaxed |
| metadata | {{WEIGHT}} | {{TRACKING}} | leading-normal |

### 6.3 Spacing Tokens (from ux-constitution.instructions.md Section I.3 + I-bis.5)
- Base unit: 4px
- `spacing-1`: 4px → {{USAGE}}
- `spacing-2`: 8px → {{USAGE}}
- `spacing-4`: 16px → {{USAGE}}
- `spacing-6`: 24px → {{USAGE}}
- `spacing-8`: 32px → {{USAGE}}

**Spacing Philosophy:** `{{VISUAL_DNA_SPACING_PHILOSOPHY}}`
**Visual Density:** `{{VISUAL_DNA_VISUAL_DENSITY}}`

| Context | Token Applied | Value |
|---------|--------------|-------|
| Section padding (vertical) | {{TOKEN}} | {{VALUE}} |
| Card internal padding | {{TOKEN}} | {{VALUE}} |
| Grid gap | {{TOKEN}} | {{VALUE}} |
| Form field spacing | {{TOKEN}} | {{VALUE}} |

### 6.4 Border-Radius Tokens (from ux-constitution.instructions.md Section I-bis.2)

**Border-Radius Style:** `{{VISUAL_DNA_BORDER_RADIUS}}`

| Element | Token | Value | Tailwind Class |
|---------|-------|-------|----------------|
| Buttons | `var(--radius-sm)` | {{VALUE}} | `rounded-brand-sm` |
| Cards | `var(--radius-md)` | {{VALUE}} | `rounded-brand-md` |
| Modals | `var(--radius-lg)` | {{VALUE}} | `rounded-brand-lg` |
| Avatars | `var(--radius-full)` | 9999px | `rounded-full` |

### 6.5 Shadow & Elevation Tokens (from ux-constitution.instructions.md Section I-bis.3)

**Shadow Depth:** `{{VISUAL_DNA_SHADOW_DEPTH}}`

| Level | Name | Token | Value | Usage in This Feature |
|-------|------|-------|-------|-----------------------|
| 1 | resting | `var(--shadow-sm)` | {{VALUE}} | {{USAGE}} |
| 2 | interactive | `var(--shadow-md)` | {{VALUE}} | {{USAGE}} |
| 3 | elevated | `var(--shadow-lg)` | {{VALUE}} | {{USAGE}} |
| 4 | overlay | `var(--shadow-xl)` | {{VALUE}} | {{USAGE}} |

### 6.6 Animation & Transition Tokens (from ux-constitution.instructions.md Section I-bis.4)

**Animation Style:** `{{VISUAL_DNA_ANIMATION_STYLE}}`

| Token | Duration + Easing | Usage in This Feature |
|-------|------------------|-----------------------|
| `transition-fast` | {{VALUE}} | {{USAGE}} (hover states, toggles) |
| `transition-base` | {{VALUE}} | {{USAGE}} (card hover, dropdown open) |
| `transition-slow` | {{VALUE}} | {{USAGE}} (modals, overlays) |

**Micro-interactions Applied:**
- Cards: `hover:shadow-{{NEXT_LEVEL}} hover:-translate-y-0.5 transition-all duration-{{BASE}}`
- Buttons: `hover:shadow-{{NEXT_LEVEL}} transition-all duration-{{FAST}}`
- Focus states: `focus:ring-2 focus:ring-primary/20 focus:ring-offset-2`

### 6.7 Decorative Elements & Gradients (from ux-constitution.instructions.md Section I-bis.6 & I-bis.7)

**Decorative Level:** `{{VISUAL_DNA_DECORATIVE_ELEMENTS}}`
**Gradient Usage:** `{{VISUAL_DNA_GRADIENT_USAGE}}`

| Element | Treatment Applied |
|---------|------------------|
| Section dividers | {{TREATMENT}} |
| Section backgrounds | {{TREATMENT}} (alternating pattern) |
| Hero section | {{TREATMENT}} |
| Button accents | {{TREATMENT}} |
| Empty states | {{TREATMENT}} |

### 6.8 Icon Style (from ux-constitution.instructions.md Section I-bis.8)

**Icon Style:** `{{VISUAL_DNA_ICON_STYLE}}`
**Library Used:** {{ICON_LIBRARY}} via CDN
**Size Scale:** `w-4 h-4` (inline), `w-5 h-5` (standard), `w-6 h-6` (nav), `w-16 h-16` (empty states)

---

## Section 7: Integration with Backend (Optional)

> **Purpose:** (If feature has API) Mapping of API contracts (design.md) to UI.

**API Endpoints Used:**
- {{METHOD}} {{ENDPOINT}} → {{UI_ACTION}}

**Data Binding:**
- {{UI_ELEMENT}} → {{ data_structure }}

**Loading States:**
- {{LOADING_INDICATOR}} visible while {{ASYNC_OPERATION}}

---

## Appendix: Mock Reference

**Mock File:** `docs/spec/{{FEATURE_ID}}/mock.html`

**Framework CSS:** {{CSS_FRAMEWORK}} (classes used)

**Vanilla JS:** < 50 lines (toggle states, basic form validation)

**WCAG Compliance:** {{STATUS}} (verified by ux-validation.sh)

---

**Generated by:** `/CODESIGN --start {{FEATURE_ID}}`
**Last updated:** {{TIMESTAMP}}
