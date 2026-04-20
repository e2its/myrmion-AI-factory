---
description: "UX constitution — design system governance, WCAG compliance, component library standards, visual consistency. Applied when editing UX/component files."
applyTo: "**/docs/ux/**,**/src/components/**,**/*.{jsx,tsx,vue,svelte}"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# 🎨 UX Constitution & Interaction Policies

> **Status:** Ratified  
> **Source Authority:** "101 UX Principles" / Market Best Practices / WCAG 2.1  
> **Enforcement:** Mandatory for all views, components, and automated tests.  
> **Alignment:** Integrates with FSD, Tailwind CSS, Contract-First, and Accessibility policies.

---

## � I. Brand Identity & Layout Constitution

> **Purpose:** Define the visual identity and layout architecture that ensures coherence across all UI development. All agents MUST reference this section when implementing or reviewing frontend features.

### 1. Brand Tokens

**Policy:** All colors and typography MUST use brand tokens. Hardcoded values are prohibited according to `{{BRAND_ENFORCEMENT_LEVEL}}`.

#### 1.1 Color Palette

| Token | Value | CSS Variable | Tailwind Class | Usage |
|-------|-------|--------------|----------------|-------|
| Primary | `{{BRAND_PRIMARY_COLOR}}` | `--brand-primary` | `text-brand-primary`, `bg-brand-primary` | CTAs, links, primary actions |
| Secondary | `{{BRAND_SECONDARY_COLOR}}` | `--brand-secondary` | `text-brand-secondary`, `bg-brand-secondary` | Secondary actions, highlights |
| Accent | `{{BRAND_ACCENT_COLOR}}` | `--brand-accent` | `text-brand-accent`, `bg-brand-accent` | Emphasis, badges, notifications |
| Neutral Dark | `{{BRAND_NEUTRAL_DARK}}` | `--brand-neutral-dark` | `text-brand-neutral-dark`, `bg-brand-neutral-dark` | Primary text, dark backgrounds |
| Neutral Light | `{{BRAND_NEUTRAL_LIGHT}}` | `--brand-neutral-light` | `text-brand-neutral-light`, `bg-brand-neutral-light` | Light backgrounds, borders |

#### 1.2 Semantic Colors Strategy

**Strategy:** `{{BRAND_SEMANTIC_STRATEGY}}`

{{#if BRAND_SEMANTIC_STRATEGY == "framework-defaults"}}
Semantic colors use {{STYLING_SYSTEM}} defaults:
- Success: `green-500` / `--color-success`
- Warning: `amber-500` / `--color-warning`
- Error: `red-500` / `--color-error`
- Info: `blue-500` / `--color-info`
{{else}}
Custom semantic colors (brand-aligned):
- Success: `{{BRAND_SUCCESS_COLOR}}` / `--brand-success`
- Warning: `{{BRAND_WARNING_COLOR}}` / `--brand-warning`
- Error: `{{BRAND_ERROR_COLOR}}` / `--brand-error`
- Info: `{{BRAND_INFO_COLOR}}` / `--brand-info`
{{/if}}

#### 1.3 Typography

| Role | Font Family | Fallback Stack | Tailwind Class |
|------|-------------|----------------|----------------|
| Primary (Headings) | `{{BRAND_PRIMARY_FONT}}` | `{{BRAND_FONT_STACK}}` | `font-brand-primary` |
| Secondary (Body) | `{{BRAND_SECONDARY_FONT}}` | `system-ui, sans-serif` | `font-brand-secondary` |

#### 1.4 Brand Assets

| Asset | Path | Status |
|-------|------|--------|
| Logo (Primary) | `{{BRAND_LOGO_PATH}}` | {{#if BRAND_LOGO_PROVIDED}}Provided{{else}}Placeholder - Update via `/CODESIGN --start`{{/if}} |
| Favicon | `{{BRAND_FAVICON_PATH}}` | {{#if BRAND_FAVICON_PROVIDED}}Provided{{else}}Placeholder{{/if}} |

**Logo Usage Rules:**
- Minimum size: 32x32px
- Clear space: 8px minimum around logo
- Do NOT stretch, rotate, or recolor
- Use SVG format when possible for scalability

---

### 2. Dark Mode Configuration

**Status:** {{#if BRAND_DARK_MODE_ENABLED}}✅ Enabled{{else}}❌ Disabled{{/if}}

{{#if BRAND_DARK_MODE_ENABLED}}
#### 2.1 Dark Mode Tokens

| Token | Light Mode | Dark Mode | CSS Variable |
|-------|------------|-----------|--------------|
| Background | `{{BRAND_NEUTRAL_LIGHT}}` | `{{BRAND_DARK_BACKGROUND}}` | `--brand-bg` |
| Text Primary | `{{BRAND_NEUTRAL_DARK}}` | `{{BRAND_DARK_TEXT}}` | `--brand-text` |
| Primary | `{{BRAND_PRIMARY_COLOR}}` | `{{BRAND_PRIMARY_DARK}}` | `--brand-primary` |
| Surface | `#FFFFFF` | `{{BRAND_DARK_SURFACE}}` | `--brand-surface` |

#### 2.2 Implementation

```css
/* Light mode (default) */
:root {
  --brand-primary: {{BRAND_PRIMARY_COLOR}};
  --brand-bg: {{BRAND_NEUTRAL_LIGHT}};
  --brand-text: {{BRAND_NEUTRAL_DARK}};
}

/* Dark mode */
:root.dark, [data-theme="dark"] {
  --brand-primary: {{BRAND_PRIMARY_DARK}};
  --brand-bg: {{BRAND_DARK_BACKGROUND}};
  --brand-text: {{BRAND_DARK_TEXT}};
}
```

**Toggle Implementation:** Use `prefers-color-scheme` media query with user preference override stored in localStorage.
{{/if}}

---

### 3. Layout Architecture

**App Shell Configuration:**
- Persistent Header: {{LAYOUT_PERSISTENT_HEADER}}
- Persistent Footer: {{LAYOUT_PERSISTENT_FOOTER}}
- Sidebar Scope: `{{LAYOUT_SIDEBAR_SCOPE}}` (global | per_section)

#### 3.1 Section Layouts

| Section | Layout Component | Nav Pattern | Routes |
|---------|------------------|-------------|--------|
{{#each LAYOUT_SECTIONS}}
| {{name}} | `{{layout}}` | {{nav_pattern}} | `{{routes}}` |
{{/each}}

#### 3.2 Layout Component Requirements

Each Layout Component MUST:
1. Apply brand tokens consistently (colors, fonts)
2. Implement responsive behavior (mobile-first)
3. Include accessibility landmarks (`<header>`, `<main>`, `<nav>`, `<footer>`)
4. Support dark mode toggle if `{{BRAND_DARK_MODE_ENABLED}}`

**Reference Implementations:**
- `src/components/layouts/{{PRIMARY_LAYOUT}}Layout.tsx`
- `src/components/layouts/AuthLayout.tsx` (always required)

---

### 4. Brand Enforcement Policy

**Enforcement Level:** `{{BRAND_ENFORCEMENT_LEVEL}}`

| Level | Behavior | Applied To |
|-------|----------|------------|
| **BLOCKER** | Hardcoded colors/fonts = PR rejection | All branches |
| **WARNING** | Detect & report, allow with justification | All branches |
| **MIXED** | BLOCKER on main/release, WARNING on feature | Per-branch |

#### 4.1 Validation Patterns

**Prohibited Patterns (detected by Review Agent and `scripts/ux-validation.sh`):**

```regex
# Hardcoded colors
#[0-9A-Fa-f]{3,8}
rgb\([0-9, ]+\)
rgba\([0-9, .]+\)
hsl\([0-9, %]+\)

# Hardcoded fonts (Tailwind)
font-\['[^']+'\]

# Hardcoded fonts (CSS-in-JS)
fontFamily:\s*["'][^"']+["']
```

**Allowed Patterns:**
- `text-brand-primary`, `bg-brand-secondary` (Tailwind tokens)
- `var(--brand-primary)` (CSS variables)
- `theme.colors.brand.primary` (JS theme object)

#### 4.2 Exception Process

If a hardcoded value is necessary (e.g., third-party library override):
1. Document in code comment: `// BRAND-EXCEPTION: [reason]`
2. Add to `.claude/rules/brand-exceptions.instructions.md`
3. Get approval in PR review

---

### 5. Internationalization UI Standards

> **Scope:** {{I18N_SCOPE}} <!-- None | Basic | Full | Enterprise -->
> **Default Locale:** {{I18N_DEFAULT_LOCALE}}

{{#if I18N_SCOPE != "None"}}

#### 5.1 Text Content Policy

**Policy:** All user-facing text MUST use translation functions. Hardcoded strings are prohibited.

**Allowed Patterns:**
```jsx
// React (react-i18next / next-intl)
{t('common.save_button')}
{formatMessage({ id: 'errors.required_field' })}

// Vue (vue-i18n)
{{ $t('common.save_button') }}

// Svelte (svelte-i18n)
{$_('common.save_button')}
```

**Prohibited Patterns:**
```jsx
// ❌ Hardcoded strings
<button>Save</button>
<p>Please enter your email</p>
{error && "Something went wrong"}
```

**Exceptions (allowed without translation):**
- Technical logs (console.log, logger.debug)
- Developer-facing error messages in catch blocks
- Test data and fixtures
- Brand names and proper nouns (documented in `locales/common/proper-nouns.json`)

#### 5.2 Locale Selector Placement

**Position:** {{I18N_LOCALE_SELECTOR_POSITION}} <!-- header | footer | settings | auto -->

| Position | UX Pattern | Recommended For |
|----------|------------|-----------------|
| Header (top-right) | Globe icon + dropdown | Consumer apps, frequent switching |
| Footer | Text link with current locale | Marketing sites, SEO focus |
| Settings | Deep in user preferences | Enterprise apps, infrequent switching |
| Auto | Detect from browser, allow override | Most apps (recommended default) |

#### 5.3 Date/Time/Number Display

**Policy:** Use `Intl` APIs for all formatting. Never hardcode date formats.

```jsx
// ✅ Correct
{new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(date)}
{new Intl.NumberFormat(locale, { style: 'currency', currency }).format(amount)}

// ❌ Prohibited
{date.toLocaleDateString()} // Implicit locale
{amount.toFixed(2)} + ' €'  // Hardcoded currency
```

{{#if I18N_SCOPE == "Full" || I18N_SCOPE == "Enterprise"}}
#### 5.4 Currency Display

**Strategy:** {{I18N_CURRENCY_STRATEGY}}

| Element | Display | Example (EUR) | Example (USD) |
|---------|---------|---------------|---------------|
| Product price | Currency symbol + amount | €29,99 | $29.99 |
| Order total | Explicit currency code | 29,99 EUR | 29.99 USD |
| Currency selector | Flag + code | 🇪🇺 EUR | 🇺🇸 USD |

**Decimal Separators:** Respect locale conventions (`,` for EU, `.` for US).
{{/if}}

{{#if I18N_RTL_SUPPORT == "Yes"}}
#### 5.5 RTL (Right-to-Left) Support

**Status:** ✅ Enabled

**CSS Requirements:**
```css
/* Use logical properties instead of physical */
margin-inline-start: 1rem;  /* ✅ Instead of margin-left */
padding-inline-end: 0.5rem; /* ✅ Instead of padding-right */
inset-inline-start: 0;      /* ✅ Instead of left: 0 */
```

**Directional Icons:** Must flip for RTL (arrows, chevrons, progress indicators).

**Testing:** Include `ar-SA` or `he-IL` in visual regression tests.
{{/if}}

{{/if}}

---

## 🧬 I-bis. Visual DNA & Design Language

> **Purpose:** Define the aesthetic identity and visual personality that guides ALL design decisions. This section ensures visual consistency beyond mere color/font compliance — it governs the "feel" of the product: spacing rhythm, depth, roundness, animation, and decorative intent.
> **Source:** Extracted during `/SETUP --init` (Q10b: Design Inspiration) from reference websites analysis.

{{#if DESIGN_INSPIRATION_EXISTS}}

### 1. Design Inspiration References

| # | Reference URL | Style Description |
|---|---------------|-------------------|
{{#each DESIGN_INSPIRATION_URLS}}
| {{@index}} | `{{url}}` | {{style_description}} |
{{/each}}

**Usage:** These references serve as the aesthetic north star. When making visual decisions not explicitly covered by tokens below, lean toward the style of these references.

{{else}}

### 1. Design Inspiration References

> No design inspiration was configured during setup. Visual DNA defaults are applied based on project sector. Run `/SETUP --init` with Q10b to configure design inspiration for a more tailored aesthetic.

{{/if}}

### 2. Border-Radius System

**Style:** `{{VISUAL_DNA_BORDER_RADIUS}}`
<!-- Values: sharp | subtle | rounded | pill -->

| Token | Value | CSS Variable | Tailwind Extend | Usage |
|-------|-------|-------------|-----------------|-------|
| radius-sm | `{{VISUAL_DNA_RADIUS_SM}}` | `--radius-sm` | `rounded-brand-sm` | Buttons, inputs, small elements |
| radius-md | `{{VISUAL_DNA_RADIUS_MD}}` | `--radius-md` | `rounded-brand-md` | Cards, dropdowns, panels |
| radius-lg | `{{VISUAL_DNA_RADIUS_LG}}` | `--radius-lg` | `rounded-brand-lg` | Modals, dialogs, hero sections |
| radius-xl | `{{VISUAL_DNA_RADIUS_XL}}` | `--radius-xl` | `rounded-brand-xl` | Feature cards, full-width sections |
| radius-full | `{{VISUAL_DNA_RADIUS_FULL}}` | `--radius-full` | `rounded-full` | Avatars, badges, pills, toggles |

**Consistency Rule:** Cards/modals are ONE step rounder than buttons/inputs. Never mix radius styles arbitrarily.

**Implementation:**
```css
:root {
  --radius-sm: {{VISUAL_DNA_RADIUS_SM}};
  --radius-md: {{VISUAL_DNA_RADIUS_MD}};
  --radius-lg: {{VISUAL_DNA_RADIUS_LG}};
  --radius-xl: {{VISUAL_DNA_RADIUS_XL}};
  --radius-full: 9999px;
}
```

### 3. Elevation & Shadow System

**Depth Style:** `{{VISUAL_DNA_SHADOW_DEPTH}}`
<!-- Values: flat | subtle | layered | dramatic -->

| Level | Name | Value | CSS Variable | Usage |
|-------|------|-------|-------------|-------|
| 0 | ground | `none` | `--shadow-none` | Page background, inline elements |
| 1 | resting | `{{VISUAL_DNA_SHADOW_SM}}` | `--shadow-sm` | Cards at rest, input fields |
| 2 | interactive | `{{VISUAL_DNA_SHADOW_MD}}` | `--shadow-md` | Cards on hover, buttons, dropdowns |
| 3 | elevated | `{{VISUAL_DNA_SHADOW_LG}}` | `--shadow-lg` | Modals, popovers, toasts |
| 4 | overlay | `{{VISUAL_DNA_SHADOW_XL}}` | `--shadow-xl` | Full-screen overlays, floating elements |

**Hover Rule:** ALL elevatable elements MUST transition to the next shadow level on hover with `transition-shadow duration-200`.

**Implementation:**
```css
:root {
  --shadow-sm: {{VISUAL_DNA_SHADOW_SM}};
  --shadow-md: {{VISUAL_DNA_SHADOW_MD}};
  --shadow-lg: {{VISUAL_DNA_SHADOW_LG}};
  --shadow-xl: {{VISUAL_DNA_SHADOW_XL}};
}
```

### 4. Animation & Transition Tokens

**Animation Style:** `{{VISUAL_DNA_ANIMATION_STYLE}}`
<!-- Values: none | subtle | fluid | expressive -->

| Token | Duration + Easing | CSS Variable | Tailwind Extend | Usage |
|-------|-------------------|-------------|-----------------|-------|
| transition-fast | `{{VISUAL_DNA_ANIM_FAST}}` | `--transition-fast` | `transition-fast` | Hover states, focus rings, toggles |
| transition-base | `{{VISUAL_DNA_ANIM_BASE}}` | `--transition-base` | `transition-base` | Card hover, dropdown open, page nav |
| transition-slow | `{{VISUAL_DNA_ANIM_SLOW}}` | `--transition-slow` | `transition-slow` | Modals, overlays, section reveals |
| easing-default | `{{VISUAL_DNA_EASING}}` | `--easing-default` | — | Default easing for all transitions |

**Rule:** ALL interactive elements MUST include `transition-*` classes. No abrupt state changes.

**Implementation:**
```css
:root {
  --transition-fast: {{VISUAL_DNA_ANIM_FAST}};
  --transition-base: {{VISUAL_DNA_ANIM_BASE}};
  --transition-slow: {{VISUAL_DNA_ANIM_SLOW}};
  --easing-default: {{VISUAL_DNA_EASING}};
}
```

### 5. Visual Density & Spacing Philosophy

**Density:** `{{VISUAL_DNA_VISUAL_DENSITY}}`
<!-- Values: compact | comfortable | spacious -->

**Spacing Philosophy:** `{{VISUAL_DNA_SPACING_PHILOSOPHY}}`
<!-- Values: dense | comfortable | spacious -->

| Context | compact | comfortable | spacious |
|---------|---------|------------|----------|
| Section padding (vertical) | `py-6` | `py-12` | `py-16 lg:py-24` |
| Section padding (horizontal) | `px-4` | `px-6` | `px-8` |
| Card internal padding | `p-3` | `p-6` | `p-8` |
| Grid gap | `gap-2` | `gap-4 lg:gap-6` | `gap-6 lg:gap-8` |
| Form field spacing | `space-y-2` | `space-y-4` | `space-y-6` |
| Heading margin-bottom | `mb-2` | `mb-4` | `mb-6` |
| Paragraph margin-bottom | `mb-2` | `mb-3` | `mb-4` |

**Whitespace Ratio:** `{{VISUAL_DNA_WHITESPACE_RATIO}}`
<!-- Values: tight | balanced | generous -->

**Rule:** Whitespace is an intentional design element. Between major sections, use spacer dividers or background color alternation to create visual rhythm.

### 6. Decorative Elements Policy

**Level:** `{{VISUAL_DNA_DECORATIVE_ELEMENTS}}`
<!-- Values: minimal | moderate | rich -->

| Element | minimal | moderate | rich |
|---------|---------|----------|------|
| Section dividers | `border-neutral-100` hairline | Styled `border-b-2 border-primary/20` | Decorated with icons/dots/SVG ornaments |
| Section backgrounds | Solid alternating `bg-white`/`bg-neutral-50` | Gradient tints `from-primary/5 to-transparent` | Bold gradients, SVG patterns |
| Empty states | Text + icon only | Text + illustrated icon + CTA | Full illustration + animated icon + CTA |
| Loading states | Spinner | Skeleton screens | Animated skeleton with shimmer |

### 7. Gradient Usage Policy

**Level:** `{{VISUAL_DNA_GRADIENT_USAGE}}`
<!-- Values: none | accents-only | hero-sections | pervasive -->

| Context | none | accents-only | hero-sections | pervasive |
|---------|------|-------------|---------------|-----------|
| Hero sections | Solid background | Solid background | `bg-gradient-to-br from-primary/90 to-secondary/80` | Full gradient |
| Buttons (primary) | Solid `bg-primary` | `bg-gradient-to-r from-primary to-primary-dark` | Gradient | Gradient |
| Buttons (secondary) | Solid | Solid | Solid | Subtle gradient tint |
| Card backgrounds | Solid white | Solid white | Solid white | Subtle gradient shimmer |
| Text (hero headline) | Solid color | Solid color | `bg-clip-text text-transparent bg-gradient-to-r` | Gradient text |

### 8. Icon Style Standard

**Style:** `{{VISUAL_DNA_ICON_STYLE}}`
<!-- Values: outlined | filled | duotone | mixed -->

| Style | Recommended Library | CDN |
|-------|-------------------|-----|
| outlined | Heroicons Outline / Lucide | `<script src="https://unpkg.com/lucide@latest"></script>` |
| filled | Heroicons Solid | Include inline SVG from heroicons.com |
| duotone | Phosphor Icons | `<script src="https://unpkg.com/@phosphor-icons/web"></script>` |
| mixed | Heroicons Outline (nav) + Solid (active) | Inline SVG per icon |

**Rules:**
- Size: `w-5 h-5` for inline icons, `w-6 h-6` for nav icons, `w-16 h-16` for empty states
- Spacing: `gap-2` between icon and text in buttons/links
- Must include ARIA: `aria-hidden="true"` for decorative icons, `role="img" aria-label="..."` for meaningful icons

### 9. Color Temperature & Palette Harmony

**Temperature:** `{{VISUAL_DNA_COLOR_TEMPERATURE}}`
<!-- Values: cool | warm | neutral | vibrant -->

**Typography Contrast:** `{{VISUAL_DNA_TYPOGRAPHY_CONTRAST}}`
<!-- Values: low | medium | high -->

**Heading Weight Scale:**
| Contrast | h1 | h2 | h3 | body | metadata |
|----------|----|----|----|----|----------|
| low | 600 | 500 | 500 | 400 | 400 |
| medium | 700 | 600 | 500 | 400 | 300 |
| high | 800 | 700 | 600 | 400 | 300 |

**Heading Tracking:**
- h1: `tracking-tight` (all contrast levels)
- h2: `tracking-tight` (high) / `tracking-normal` (medium/low)
- body: `tracking-normal`
- metadata: `tracking-wide` (high) / `tracking-normal` (medium/low)

---

## 🏛️ II. Global Layout & Structural Laws

### 1. The Layout Component Law
**Policy:** No page shall define its own structural shell. All pages **MUST** be wrapped in a reusable **Layout Component**.

**Implementation:**
- Use layouts defined in Section I.3 (Layout Architecture)
- `DashboardLayout`: Sidebar + Header + Content Area.
- `AuthLayout`: Centered Card + Background.
- `SettingsLayout`: Sidebar navigation + Form Area.

**Reasoning:** Ensures consistent navigation state, padding, and responsive behavior across the entire application (DRY Principle).

**Enforcement:**
- **Architect Agent:** Verifies layout components exist in `design.md` before approval.
- **Developer Agent:** Uses existing layouts from `src/components/layouts/`.

---

### 2. The Responsive Mandate (Principle 100)
**Policy:** "Does it work on mobile?" is obsolete. It **MUST** work on mobile.

**Rule:** All grids must collapse to single-column on mobile viewports (<768px). Horizontal scrolling is strictly prohibited for main content (allowed only for specific data tables or carousels).

**Mobile-First Design:**
- Base styles target 320px viewport (smallest modern mobile).
- Use Tailwind's `md:`, `lg:`, `xl:` breakpoints to enhance for larger screens.
- Test all features on real mobile devices or simulators before approval.

**Enforcement:**
- **QA Agent:** Adds responsive testing to test matrix (320px, 768px, 1024px, 1920px breakpoints).
- **CI/CD:** Lighthouse CI runs mobile audits (score ≥90).

---

### 3. The Grid & Spacing System
**Policy:** Magic numbers are banned. All spacing (margin, padding) must use a standardized scale.

**8px Grid System:**
- Base unit: `8px` (defined as `--spacing-unit`)
- Scale: `4px, 8px, 16px, 24px, 32px, 40px, 48px, 64px`
- Tailwind mapping: `space-1` (4px), `space-2` (8px), `space-4` (16px), etc.

**Grid Alignment:**
- Use CSS Grid (`display: grid`) or Flexbox for layouts.
- 12-column grid for complex layouts (Tailwind: `grid-cols-12`).
- Avoid pixel-perfect positioning (`position: absolute` with hardcoded values).

**Enforcement:**
- **Strict Mode:** CI/CD blocks merges if raw pixel values (e.g., `p-[13px]`) are used instead of token-based utilities.
- **Tailwind Config Validation:** `scripts/ux-validation.sh` checks that all spacing values in `tailwind.config.js` derive from `--spacing-unit`.

---

## ♻️ III. Component Reuse Policy (The Atomic Standard)

### 1. The Rule of Two
**Policy:** If a UI pattern appears **twice**, it must be refactored into a reusable component.

**Governance (Aligned with FSD 2-Layer Model):**
- **Shared UI Layer (`src/components/ui/`):** Atoms (Button, Input, Label, Icon, Card, Badge).
- **Feature UI Layer (`src/features/{domain}/components/`):** Organisms (CheckoutForm, ProductCard, UserProfile).

**Before Creating New Components:**
1. Scan `src/components/ui/` for existing atoms.
2. Compose from atoms before creating new molecules.
3. Document in Storybook (see Section IX).

**Enforcement:**
- **Architect Agent:** During `--plan`, searches `src/components/ui/` for reusable atoms before allowing new component creation.
- **Developer Agent:** References UX Constitution's component inventory before implementation.

---

### 2. Composition Over Inheritance
**Policy:** Build complex components by composing smaller "Atoms," not by creating monolithic "Mega-Components" with 50 props.

**Example:**
```tsx
// ❌ BAD: Monolithic UserCard with 20 props
<UserCard name={...} avatar={...} status={...} badge={...} />

// ✅ GOOD: Composed from atoms
<Card>
  <Avatar src={user.avatar} />
  <Typography variant="h3">{user.name}</Typography>
  <Badge status={user.status} />
</Card>
```

**Reasoning:** Composition reduces coupling, improves testability, and enables token efficiency for AI agents (smaller component context).

---

## 🧪 IV. Testability & QA Governance (The Automation Law)

### 1. The Selector Hierarchy (Principle of Stability)
**Policy:** Tests must NEVER rely on CSS classes (`.btn-primary`) or DOM structure (`div > div > button`). Styles change; Behavior is permanent.

**Mandate:** Developers (and AI) must select elements in this order of priority (Playwright/Testing-Library standard):

1. **By Role (Accessibility):** `getByRole('button', { name: 'Save' })` — Best practice, mimics user behavior.
2. **By Label/Text:** `getByLabelText('Email')` or `getByText('Welcome')`.
3. **By Test ID (The Escape Hatch):** `getByTestId('user-settings-card')` — Only when semantic selection is impossible.

**Alignment:** Reinforces existing policy in `.context/rules/frontend.md`.

---

### 2. The `data-testid` Mandate
**Rule:** Any interactive element or container that does not have a unique semantic text/role (e.g., a specific `div` in a grid, a dynamic icon, or a container wrapper) **MUST** have a `data-testid` attribute.

**Naming Convention:** `kebab-case` prefixed by context.
- ✅ `data-testid="hero-cta-button"`
- ✅ `data-testid="product-list-item-123"`
- ❌ `id="testButton"` (Do not use generic IDs).

**Example:**
```tsx
// Dynamic icon without semantic role
<div data-testid="notification-bell-icon">
  <BellIcon count={unreadCount} />
</div>
```

---

### 3. Critical Flow Tagging
**Policy:** All elements involved in "Golden Path" flows (Sign Up, Checkout, Critical Settings) must be explicitly tagged if their text content is dynamic or subject to frequent copy changes.

**Example:**
```tsx
// Button text might change ("Save", "Saving...", "Saved")
<button data-testid="profile-save-button">
  {isSaving ? 'Saving...' : 'Save Profile'}
</button>
```

**Enforcement:**
- **QA Agent:** Verifies critical flow elements have `data-testid` in test plan.

---

## 🎨 V. Typography & Visual Hierarchy

### 1. The "Two Typeface" Limit (Principle 8)
**Guideline:** Maximum of **two** typefaces recommended.
- **Primary:** Headings/Titles (Brand personality).
- **Secondary:** Body Copy (Legibility focused).

**System Fonts:** Prefer system-native font stacks for performance (Principle 9):
```css
font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
```

**Rationale:** Reduces font-loading overhead, improves FCP (First Contentful Paint).

**Enforcement:** **Advisory** (documented guideline, not CI/CD blocking).

---

### 2. Hierarchy by Size & Weight (Principle 10)
**Guideline:** Never use color alone to denote hierarchy. Use **Size** and **Weight**.

**Semantic Heading Structure:**
- `<h1>`: Page Titles (one per page).
- `<h2>`: Section Headers.
- `<h3>`: Card/Group Headers.
- `<h4>`-`<h6>`: Subsections (rarely needed).

**Typography Scale (Modular Scale, Ratio 1.25):**
| Level | Font Size | Tailwind Class | Use Case |
|-------|-----------|----------------|----------|
| H1 | 32px (2rem) | `text-3xl` | Page Title |
| H2 | 24px (1.5rem) | `text-2xl` | Section Header |
| H3 | 20px (1.25rem) | `text-xl` | Card Header |
| Body | 16px (1rem) | `text-base` | Default Text |
| Small | 14px (0.875rem) | `text-sm` | Metadata |

**Minimum Body Text:** 16px is the absolute minimum for body text (Principle 11).

**Enforcement:** **Advisory** (no ESLint rules, but documented in Storybook style guide).

---

## 👆 VI. Interaction & Control Policies

### 1. The Button Law (Principles 13, 14, 15)
**Affordance:** Buttons must look like buttons. Flat design must not strip away "clickability" cues (shadow, border, background).

**Tailwind Example:**
```tsx
// ✅ GOOD: Clear button affordance
<button className="bg-primary text-white px-4 py-2 rounded shadow hover:shadow-lg">
  Save
</button>

// ❌ BAD: Looks like plain text
<button className="text-blue-500">Save</button>
```

**Hit Area:** Minimum tappable area is **44x44px** (Mobile Standard, WCAG 2.5.5).
```tsx
// Ensure minimum touch target
<button className="min-w-[44px] min-h-[44px]">
  <Icon />
</button>
```

**Labeling:** "Click here" is banned. Use action-oriented labels: "Save Profile", "Delete Account".

**Enforcement:**
- **QA Agent:** Validates touch targets in accessibility testing.
- **Architect Agent:** Reviews button labels for clarity.

---

### 2. Navigation Logic
**Hamburger Menus:** Prohibited on Desktop. Visible navigation links are mandatory for ample screen real estate (Principle 29).

**Pattern:**
```tsx
// Mobile: Hamburger menu
// Desktop: Horizontal nav links
<nav>
  {/* Mobile */}
  <button className="md:hidden" data-testid="mobile-menu-toggle">
    <MenuIcon />
  </button>
  
  {/* Desktop */}
  <ul className="hidden md:flex space-x-4">
    <li><a href="/dashboard">Dashboard</a></li>
    <li><a href="/settings">Settings</a></li>
  </ul>
</nav>
```

**Breadcrumbs:** Mandatory for any hierarchy deeper than 2 levels (Principle 77).
```tsx
// Example: Dashboard > Users > Edit Profile
<Breadcrumb>
  <BreadcrumbItem href="/dashboard">Dashboard</BreadcrumbItem>
  <BreadcrumbItem href="/dashboard/users">Users</BreadcrumbItem>
  <BreadcrumbItem current>Edit Profile</BreadcrumbItem>
</Breadcrumb>
```

**Links:** Links must look like links (Underlined or distinct color/weight) (Principle 30).
```tsx
// ✅ GOOD: Clear link styling
<a href="/help" className="text-primary underline hover:no-underline">
  Help Center
</a>
```

---

### 3. Feedback & State (Principles 61, 63)
**Determinate Action:** Use a **Linear Progress Bar** if time is known.
```tsx
<ProgressBar value={uploadProgress} max={100} />
```

**Indeterminate Action:** Use a **Spinner** if time is unknown.
```tsx
<Spinner aria-label="Loading..." />
```

**Skeleton Screens:** Preferred over spinners for content loading (improves perceived performance).
```tsx
<div className="animate-pulse">
  <div className="h-4 bg-gray-200 rounded w-3/4 mb-2" />
  <div className="h-4 bg-gray-200 rounded w-1/2" />
</div>
```

**Destructive Actions:** Must require a secondary confirmation or offer an "Undo" toast notification (Principle 21).
```tsx
// ✅ GOOD: Confirmation dialog
<AlertDialog>
  <AlertDialogTrigger asChild>
    <button className="bg-red-600">Delete Account</button>
  </AlertDialogTrigger>
  <AlertDialogContent>
    <AlertDialogTitle>Are you sure?</AlertDialogTitle>
    <AlertDialogDescription>
      This action cannot be undone.
    </AlertDialogDescription>
    <AlertDialogAction onClick={handleDelete}>Delete</AlertDialogAction>
    <AlertDialogCancel>Cancel</AlertDialogCancel>
  </AlertDialogContent>
</AlertDialog>
```

---

## 📝 VII. Form & Input Constitution

### 1. Validation Policy (Principle 51)
**Timing:** Validate **Inline** and **Immediately** (onBlur), not just on Submit.

**Feedback:** Error messages must appear next to the specific field, not in a generic "Error" banner at the top (Principle 52).

**Example:**
```tsx
<FormField>
  <Label htmlFor="email">Email</Label>
  <Input
    id="email"
    type="email"
    onBlur={validateEmail}
    aria-invalid={!!errors.email}
    aria-describedby={errors.email ? "email-error" : undefined}
  />
  {errors.email && (
    <ErrorMessage id="email-error">{errors.email}</ErrorMessage>
  )}
</FormField>
```

**Enforcement:**
- **QA Agent:** Verifies inline validation in test plan.

---

### 2. Input Selection Rules
**Dropdowns:** Banned for < 4 options. Use **Radio Buttons** or **Segmented Controls** instead (Principle 20).

**Example:**
```tsx
// ❌ BAD: Dropdown for 3 options
<select>
  <option>Small</option>
  <option>Medium</option>
  <option>Large</option>
</select>

// ✅ GOOD: Radio buttons
<RadioGroup>
  <RadioGroupItem value="small" id="size-small" />
  <Label htmlFor="size-small">Small</Label>
  <RadioGroupItem value="medium" id="size-medium" />
  <Label htmlFor="size-medium">Medium</Label>
  <RadioGroupItem value="large" id="size-large" />
  <Label htmlFor="size-large">Large</Label>
</RadioGroup>
```

**Native Controls:** Always use specific HTML input types (`type="email"`, `type="tel"`, `type="date"`) to trigger the correct mobile keyboard (Principle 39).

**Labels:** Placeholders are NOT labels. All inputs must have visible labels (Principle 72).
```tsx
// ❌ BAD: Placeholder as label
<input type="email" placeholder="Email" />

// ✅ GOOD: Explicit label
<label htmlFor="email">Email</label>
<input id="email" type="email" placeholder="john@example.com" />
```

---

## ♿ VIII. Accessibility (The Non-Negotiables)

### 1. Contrast & Color (Principle 64, 69)
**Ratio:** Text must meet WCAG 2.1 AA standards (4.5:1 contrast ratio minimum for normal text, 3:1 for large text).

**Color Independence:** Never use color alone to convey state (e.g., Error state must have a red color AND an icon/text message).

**Example:**
```tsx
// ❌ BAD: Color alone
<span className="text-red-600">Error</span>

// ✅ GOOD: Color + icon + text
<div className="flex items-center gap-2 text-red-600">
  <AlertIcon aria-hidden="true" />
  <span>Error: Invalid email format</span>
</div>
```

**Enforcement:**
- **CI/CD:** Lighthouse CI checks contrast ratios (blocks merge if violations).
- **QA Agent:** Axe-core audits color contrast.

---

### 2. Focus & Navigation
**Focus State:** Never remove outline (`outline: none`) without replacing it with a custom focus indicator.

**Tailwind Example:**
```tsx
// ✅ GOOD: Custom focus ring
<button className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2">
  Submit
</button>
```

**Tab Order:** Logical tab flow (Left → Right, Top → Bottom) is mandatory.
- Use `tabindex="0"` for custom interactive elements.
- NEVER use `tabindex` > 0 (disrupts natural tab order).

**Keyboard Navigation:** All interactive elements must be keyboard accessible.
- Links: `Enter` to activate.
- Buttons: `Enter` or `Space` to activate.
- Dropdowns: `Arrow keys` to navigate, `Enter` to select.

**Enforcement:**
- **QA Agent:** Adds keyboard navigation tests to test matrix.

---

### 3. Screen Reader Support
**Semantic HTML First:** Use native elements (`<button>`, `<a>`, `<input>`) before ARIA.

**ARIA Labels (When Needed):**
```tsx
// Icon-only button
<button aria-label="Close dialog">
  <CloseIcon aria-hidden="true" />
</button>

// Loading state
<div role="status" aria-live="polite" aria-busy="true">
  Loading content...
</div>
```

**Landmark Roles:** Use semantic HTML5 elements with implicit roles.
- `<header>` → `role="banner"`
- `<nav>` → `role="navigation"`
- `<main>` → `role="main"`
- `<footer>` → `role="contentinfo"`

**Enforcement:**
- **Axe-core:** Validates ARIA usage (CI/CD gate).

---

## 🗣️ IX. Terminology & Copy (Principle 89)

### 1. Standardized Nomenclature
**Authentication:**
- ✅ Use **"Sign In / Sign Out"**.
- ❌ Banned: "Log In", "Log On", "Login" (noun vs verb confusion).

**User Action:**
- ✅ Use **"Forgot Password?"**.
- ❌ Banned: "Reset Pass", "Help".

**Voice:** Use Active Voice ("Post Comment"). Avoid Passive Voice ("Comment will be posted") (Principle 94).

**Microcopy Guidelines:**
- Be concise (max 3 words for buttons).
- Be action-oriented ("Save Changes" not "Submit").
- Be human ("Oops! Something went wrong" not "Error 500").

**Enforcement:**
- **Product Owner Agent:** Reviews copy during `--spec` phase.
- **Advisory:** No automated enforcement.

---

## 📐 X. Design System Documentation (Storybook Integration)

### 1. Component Inventory (Recommended)
**Policy:** All reusable components in `src/components/ui/` SHOULD have Storybook stories.

**Purpose:**
- **Visual Regression Testing:** Chromatic/Playwright snapshots detect unintended UI changes.
- **Living Documentation:** Designers and developers reference the same source of truth.
- **Isolation Testing:** Components are tested in isolation from business logic.

**Storybook Structure:**
```
src/components/ui/
├── Button/
│   ├── Button.tsx
│   ├── Button.stories.tsx  # Storybook story
│   └── Button.test.tsx
└── Input/
    ├── Input.tsx
    ├── Input.stories.tsx
    └── Input.test.tsx
```

**Story Example:**
```tsx
// Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = {
  title: 'UI/Button',
  component: Button,
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof Button>;

export const Primary: Story = {
  args: {
    variant: 'primary',
    children: 'Save Profile',
  },
};

export const Destructive: Story = {
  args: {
    variant: 'destructive',
    children: 'Delete Account',
  },
};
```

**Enforcement:**
- **Recommended:** Architect Agent suggests Storybook during `--plan` if component count > 10.
- **CI/CD:** Visual regression tests run on Storybook builds (optional).

---

### 2. Design Token Documentation
**Policy:** `tailwind.config.js` should be documented in Storybook as a "Design Tokens" page.

**Example:**
```tsx
// .storybook/stories/DesignTokens.stories.mdx
import { Meta, ColorPalette, Typeset } from '@storybook/blocks';

<Meta title="Foundation/Design Tokens" />

# Design Tokens

## Spacing (8px Grid)
- `space-1`: 4px
- `space-2`: 8px
- `space-4`: 16px
- `space-6`: 24px

## Colors
<ColorPalette>
  <ColorItem title="Primary" colors={['#0066CC']} />
  <ColorItem title="Danger" colors={['#DC2626']} />
</ColorPalette>

## Typography
<Typeset />
```

---

## 🔬 XI. Validation & Enforcement

### 1. Blueprint Agent Checkpoints (`/BLUEPRINT --start`)
Before approving design, Architect MUST verify:
- [ ] Layout components defined (Dashboard/Auth/Settings).
- [ ] Component reuse checked (scan `src/components/ui/` for existing atoms).
- [ ] Tailwind config uses design tokens (no hardcoded values).
- [ ] Semantic HTML structure documented (headings hierarchy).
- [ ] Touch targets ≥44px for mobile interactions.
- [ ] Focus indicators defined for interactive elements.

---

### 2. QA Agent Checkpoints (`/QA --verify`)
QA Verification Checklist MUST include:

#### UX & Accessibility Section
| ID | Test Case | Tool | Expected Result |
|----|-----------|------|-----------------|
| UX-01 | Mobile responsive (320px, 768px, 1024px) | Manual + BrowserStack | No horizontal scroll, readable text |
| UX-02 | Touch targets ≥44x44px | Manual inspection | All buttons/links compliant |
| A11Y-01 | WCAG 2.1 AA compliance | Axe-core | 0 violations |
| A11Y-02 | Color contrast ratios | Lighthouse CI | All text ≥4.5:1 (body), ≥3:1 (large) |
| A11Y-03 | Keyboard navigation | Manual testing | All actions accessible via Tab/Enter/Space |
| A11Y-04 | Screen reader compatibility | NVDA/VoiceOver | All interactive elements announced |

---

### 3. CI/CD Gates (`scripts/ux-validation.sh`)
**Strict Mode Enforcement:**
- **Tailwind Token Validation:** Blocks merge if raw pixel values (e.g., `p-[13px]`) detected.
- **Axe-core Audit:** Blocks merge if accessibility violations found.
- **Lighthouse CI:** Blocks merge if Accessibility score <90 or Performance score <85.
- **Visual Regression:** (Optional) Chromatic blocks merge if Storybook snapshots differ without approval.

**Script Location:** `scripts/ux-validation.sh` (see Section XI).

---

## 📋 XII. Summary & Quick Reference

### Component Checklist
- [ ] Composed from existing atoms (check `src/components/ui/`).
- [ ] Uses design tokens (no hardcoded px values).
- [ ] Has `data-testid` if no semantic selector available.
- [ ] Keyboard accessible (Tab, Enter, Space).
- [ ] Focus indicator visible (Tailwind `focus:ring`).
- [ ] Touch target ≥44x44px (mobile).
- [ ] Color contrast ≥4.5:1 (text), ≥3:1 (large text).
- [ ] Responsive (tested at 320px, 768px, 1024px).
- [ ] Storybook story created (recommended).

### Testing Selector Priority
1. `getByRole('button', { name: 'Save' })`
2. `getByLabelText('Email')`
3. `getByText('Welcome')`
4. `getByTestId('user-settings-card')` (escape hatch)

### Accessibility Minimum (WCAG 2.1 AA)
- Contrast: 4.5:1 (body), 3:1 (large text)
- Touch targets: ≥44x44px
- Keyboard navigation: All actions
- Screen readers: Semantic HTML + ARIA labels

### Performance Budgets
- FCP: <1.5s
- LCP: <2.5s
- CLS: <0.1
- Bundle size: <200KB (initial JS, gzipped)

---

## 🎨 XIII. UX Agent Governance Rules (NEW)

> **Enforced by:** `/CODESIGN --start`, `/CODESIGN --refine` (auto-approval on 9/9 validations)  
> **Applies to:** Mock generation, design_ux.md artifacts, cross-agent validations  
> **Severity:** BLOCKER (A, C), WARNING (D), MANDATORY (B)

### Rule A: CSS Styling Restrictions (BLOCKER)

**Policy:** Embedded styles and inline styles are PROHIBITED in all mock.html artifacts.

**Rationale:**
- Violates maintainability principle (styles scattered across files)
- Breaks design token governance (hardcoded values bypass brand constitution)
- Complicates responsive design (media queries inline are anti-pattern)
- Hinders testability (styles not inspectable via framework utilities)

**Allowed:**
- Framework CSS classes ONLY (Tailwind, Bootstrap, etc. as defined in `docs/constitution.md`)
- CSS variables from brand tokens (`var(--brand-primary)`)
- External stylesheets linked via `<link>` (for framework builds)

**Forbidden:**
```html
<!-- ❌ BLOCKER: Embedded styles -->
<style>
  .button { background: #007bff; padding: 12px; }
</style>

<!-- ❌ BLOCKER: Inline styles -->
<button style="background: #007bff; padding: 12px;">Click</button>
```

**Correct:**
```html
<!-- ✅ APPROVED: Framework classes -->
<button class="bg-primary hover:bg-primary-hover py-3 px-4 rounded-md">Click</button>
```

**Enforcement:**
- `/CODESIGN --start`: Auto-check generated mock.html for `<style>` tags or `style=""` attributes
- `/IMPLEMENT --build` (🔍 REVIEW hat): Add UX_DRIFT validation rule to scan for style violations
- CI/CD: `scripts/ux-validation.sh --style-check` blocks merge if violations found

**Exceptions:**
- Framework configuration ONLY (Tailwind config, theme customization) in `<style>` tag
- Must be documented in design_ux.md Section 6 (Design Tokens Application)
- Requires ARCH approval via comment in mock.html

---

### Rule B: WCAG 2.1 AA Auto-Repair (MANDATORY)

**Policy:** All mock.html artifacts MUST achieve WCAG 2.1 AA compliance through automated repair loop.

**Process:**
1. **Initial Generation:** `/CODESIGN --start` creates mock.html with best-effort accessibility
2. **Validation:** Execute `scripts/ux-validation.sh --wcag`
3. **Auto-Repair Loop:** If violations detected:
   - Iteration 1: Adjust colors, touch targets, ARIA attributes
   - Iteration 2: Refine layout, font sizes, semantic tags
   - Iteration 3: Final attempt with aggressive fixes
4. **RDR Fallback:** If 3 iterations fail to converge:
   - Update design_ux.md status → `NEEDS_INFO`
   - Document violations in Section 4 (Accessibility Checklist)
   - Enter RDR loop with UX stakeholder: `/CODESIGN --refine {{FEATURE_ID}} "{{FEEDBACK}}"`
5. **Finalization:** Once compliant, set `wcag_compliant: true` in design_ux.md frontmatter

**Validation Criteria:**
- Color contrast ≥4.5:1 (body text), ≥3:1 (large text ≥18pt)
- Touch targets ≥44x44px (mobile viewports)
- All interactive elements have ARIA labels or semantic roles
- Keyboard navigation functional (Tab, Enter, Space, Esc)
- No auto-playing media without user control

**Enforcement:**
- `/CODESIGN --start` / `--refine` auto-approval: BLOCKS if `wcag_compliant: false`
- `/QA --verify`: Inherits WCAG checklist from design_ux.md Section 4
- CI/CD: `scripts/ux-validation.sh --wcag` runs in PR checks (non-blocking WARNING)

**Severity:** MANDATORY (non-blocking during development, BLOCKER at approval)

---

### Rule C: Brand Drift Detection & ADR Trigger (BLOCKER)

**Policy:** Brand token changes >20% from constitution REQUIRE architectural decision record.

**Detection Method:**
1. **Baseline:** Load brand tokens from `docs/constitution.md` and `.claude/rules/ux-constitution.instructions.md`
2. **Comparison:** During WCAG auto-repair, check if color/typography adjustments exceed threshold:
   - **Colors:** Hue shift >30°, Saturation change >25%, Lightness change >20%
   - **Typography:** Font family change, size change >2 steps (e.g., `text-base` → `text-xl`)
3. **Threshold:** If cumulative changes >20% of brand token set, trigger ADR workflow

**ADR Workflow:**
```yaml
IF brand_drift > 20%:
  PAUSE: /CODESIGN --vision-refine execution
  AUTO-DISPATCH: /BLUEPRINT --adr {{FEATURE_ID}} "UX Brand Change: {{DESCRIPTION}}"
  WAIT: ADR approval (ADR-XXXX created)
  AUTO-DISPATCH: /BLUEPRINT --refine {{FEATURE_ID}} --constitution
  RESUME: /CODESIGN --vision-refine with updated constitution
  LOG: docs/project_log/ux_decisions_log.md (with ADR link)
```

**Example Trigger:**
```yaml
Feature: USR-042 (Dark Mode Toggle)
Baseline: Primary color #1e40af (blue-700)
Auto-Repair: Changed to #2563eb (blue-600) for contrast
Drift Calculation: Lightness +15% (BELOW threshold)
Action: Continue without ADR

Feature: USR-055 (Rebrand to Purple)
Baseline: Primary color #1e40af (blue-700)
Auto-Repair: Changed to #7c3aed (violet-600) for brand refresh
Drift Calculation: Hue shift 60° (ABOVE threshold)
Action: Trigger ADR, update constitution
```

**Enforcement:**
- `/CODESIGN --start`: Auto-calculate drift after each WCAG iteration
- `/CODESIGN --start` / `--refine` auto-approval: BLOCKS if drift >20% AND no ADR link in design_ux.md Section 0 (Historial)
- `/BLUEPRINT --review-conflict`: Validates ADR exists before approving constitution changes

**Severity:** BLOCKER (prevents approval without governance)

---

### Rule D: JavaScript Restrictions in Mocks (WARNING)

**Policy:** mock.html MAY contain vanilla JavaScript ONLY for toggle states (<50 lines). NO business logic.

**Rationale:**
- Mocks are visual representations, not functional prototypes
- Business logic belongs in implementation phase (`/IMPLEMENT --build`)
- Complex JS in mocks creates maintenance debt

**Allowed Behaviors:**
- Mobile menu open/close (`data-toggle="mobile-menu"`)
- Modal show/hide (`data-toggle="modal"`, `data-close="modal-id"`)
- Alert banner dismiss (`data-close="alert-banner"`)
- Tab switching (visual state only, no data fetching)
- Accordion expand/collapse

**Forbidden:**
- API calls (`fetch()`, `axios`)
- Form validation logic (beyond native HTML5 `required`)
- State management (Redux, Zustand)
- Routing logic (`window.location`, `pushState`)
- Data transformations, calculations

**Template Pattern:**
```html
<script>
  // Toggle mobile menu (ALLOWED)
  document.querySelectorAll('[data-toggle="mobile-menu"]').forEach(trigger => {
    trigger.addEventListener('click', () => {
      document.getElementById('mobile-menu').classList.toggle('hidden');
    });
  });
  
  // Business logic (FORBIDDEN)
  // ❌ fetch('/api/users').then(res => res.json()).then(data => ...)
</script>
```

**Enforcement:**
- `/CODESIGN --start`: Count JavaScript lines, WARN if >50
- `/IMPLEMENT --plan`: Identifies mock.html JS that needs real implementation
- `/IMPLEMENT --build` (🔍 REVIEW hat): Flags business logic in mock.html as UX_DRIFT violation

**Severity:** WARNING (advisory, non-blocking)

---

### Rule E: Component Reuse Mandate (MANDATORY)

**Policy:** Before creating NEW components, `/CODESIGN --start` MUST scan `@workspace (src/components)` for reusable candidates.

**Process:**
1. **Inventory Scan:** Query @workspace for existing UI components
2. **Comparison:** Match Gherkin requirements to component capabilities
3. **Decision Matrix:** REUTILIZAR vs. CREAR vs. ADAPTAR
4. **Documentation:** Record in design_ux.md Section 3 (Component Inventory)

**Decision Criteria:**
- **REUTILIZAR:** Component exists AND covers 90%+ of requirements
- **ADAPTAR:** Component exists AND covers 60-89% (add variant/prop)
- **CREAR:** No component exists OR <60% match

**Enforcement:**
- `/CODESIGN --start`: MANDATORY component scan before mock generation
- `/IMPLEMENT --plan`: Cross-references design_ux.md Section 3 to avoid duplication
- `/BLUEPRINT --start`: Validates component decisions align with architecture

**Severity:** MANDATORY (process requirement, non-blocking)

---

### Cross-Agent Integration Points

**For `/QA --verify`:**
- Load design_ux.md Section 4 (Accessibility Checklist) as test baseline
- Inherit WCAG validation criteria for E2E tests
- Validate mock.html touch targets match design_ux.md specifications

**For `/IMPLEMENT --plan`:**
- Load design_ux.md Section 3 (Component Inventory) to identify implementation targets
- Use mock.html as visual reference (NOT executable code)
- Implement JavaScript behaviors described in design_ux.md, NOT mock.html

**For `/IMPLEMENT --build` (🔍 REVIEW hat):**
- Compare implementation to mock.html for visual drift
- Validate brand token usage matches design_ux.md Section 6
- Check for style violations (Rule A enforcement)

**For `/IMPLEMENT --build` (🛡️ SEC hat):**
- Scan mock.html for XSS vectors (user-generated content rendering)
- Validate ARIA attributes don't leak sensitive information
- Check localStorage/sessionStorage usage in mock.html JS

---

## Section XIV: Global Vision Artifacts (Shell → Feature Inheritance)

> **Purpose:** Governs the Global Vision artifacts produced by `/CODESIGN --vision` and the template composition model that ensures cross-feature visual consistency. When a Global Vision exists and is APPROVED, all per-feature mocks MUST inherit the shell (header, nav, footer, styles) from the vision's `app_shell.html`.

### XIV.1 Vision Artifact Governance

```yaml
VISION_ARTIFACTS:
  location: docs/ux/vision/
  artifacts:
    vision.md:
      purpose: "Global vision manifest — describes design direction, principles, and decisions"
      frontmatter: [status, version, created_at, approved_at, visual_dna_hash]
      immutability: "After APPROVED, changes require /CODESIGN --vision-refine + --vision-approve cycle"
    
    app_shell.html:
      purpose: "App Shell template — header, sidebar, footer, navigation structure"
      rules:
        - "MUST use ONLY {{CSS_FRAMEWORK}} utility classes (NO inline styles)"
        - "MUST include <!-- FEATURE_CONTENT_SLOT --> marker inside <main>"
        - "MUST meet WCAG 2.1 AA for all shell elements"
        - "Navigation links MUST use relative paths to docs/spec/{{FEATURE_ID}}/mock.html"
        - "JavaScript in shell < 30 lines (toggle nav, responsive menu only)"
    
    style_guide.html:
      purpose: "Interactive style guide — color palette, typography, spacing, elevation"
      rules:
        - "Tokens MUST align with ux-constitution.instructions.md Section I-bis (Visual DNA)"
        - "If External DS exists, tokens inherit from DS (DS wins except WCAG violations)"
    
    page_templates.html:
      purpose: "Page layout templates — dashboard, list view, detail, form, error, empty state"
      rules:
        - "Each template MUST use the app_shell.html shell structure"
        - "Templates define content area layout patterns, NOT shell elements"
    
    component_library.html:
      purpose: "Reusable UI component library — buttons, cards, forms, modals, alerts, tables"
      rules:
        - "Components MUST follow ux-constitution.instructions.md Section V (Component Architecture)"
        - "Each component MUST have ARIA annotations and data-testid"
        - "Components MUST be framework-CSS-only (no inline styles)"
    
    navigation_map.md:
      purpose: "Navigation structure map — page hierarchy, links between sections"
      rules:
        - "MUST have ≥3 pages defined"
        - "Each page entry includes: path, title, parent, icon, access_level"
        - "Links between pages enable visual navigation across feature mocks"
```

### XIV.2 Template Composition Model (Shell → Feature)

```yaml
TEMPLATE_COMPOSITION_RULES:
  
  # When vision exists and is APPROVED:
  composition_mode:
    trigger: "docs/ux/vision/vision.md status == APPROVED"
    shell_source: "docs/ux/vision/app_shell.html"
    content_slot: "<!-- FEATURE_CONTENT_SLOT -->"
    
    mock_generation:
      - "Shell (header, nav, footer, <head>, scripts) → COPIED from app_shell.html"
      - "Feature content → GENERATED per feature inside <main> slot"
      - "Shell elements are READ-ONLY — feature agents MUST NOT modify them"
      - "If shell modification is needed → /CODESIGN --vision-refine"
    
    frontmatter_additions:
      - "vision_based: true"
      - "vision_version: {{vision.md.version}}"
  
  # When NO vision exists (legacy or backend-only):
  standalone_mode:
    trigger: "vision.md does NOT exist OR status != APPROVED"
    template: ".context/templates/codesign/mock-template.html"
    behavior: "Full mock generated with generic shell per feature"

  # Shell immutability enforcement:
  shell_protection:
    - "Feature mock shell sections MUST NOT be modified by /IMPLEMENT, /CODESIGN --refine, or any downstream agent"
    - "Shell drift detection: compare mock.html shell with app_shell.html — differences are BLOCKERS"
    - "Shell updates propagate via /CODESIGN --vision-propagate (replaces shell in all feature mocks)"
```

### XIV.3 Vision Update Propagation

```yaml
PROPAGATION_RULES:
  
  trigger: "/CODESIGN --vision-refine followed by --vision-approve"
  
  propagation_command: "/CODESIGN --vision-propagate"
  
  behavior:
    - "Scans all docs/spec/*/mock.html files with vision_based: true"
    - "For each: replaces shell sections (header, nav, footer, head) with updated app_shell.html"
    - "Preserves <main> content (feature-specific content untouched)"
    - "Updates vision_version in each mock.html frontmatter"
    - "Generates propagation report with list of updated mocks"
  
  protection:
    - "Feature <main> content is NEVER modified during propagation"
    - "If a feature mock has custom shell modifications (shell_customized: true), WARN and skip"
    - "Downstream agents (IMPLEMENT) are notified via pending_iteration cascade if affected"
```

---

## 📚 Further Reading

- **UX Principles:** "101 UX Principles" (Will Grant)
- **Accessibility:** WCAG 2.1 Guidelines (https://www.w3.org/WAI/WCAG21/quickref/)
- **Testing:** Testing Library Best Practices (https://testing-library.com/docs/queries/about)
- **Responsive Design:** Every Layout (https://every-layout.dev/)
- **Performance:** Web.dev Performance (https://web.dev/performance/)
- **Storybook:** Component Driven Development (https://www.componentdriven.org/)

---

## 🔗 Related Policies

- `.context/rules/frontend.md` — React/Next.js patterns
- `.context/rules/html-css.md` — Semantic HTML, CSS best practices
- `.context/rules/contract-first-policy.md` — API contracts
- `.context/constitution.md` — Technology governance
- `.context/agents/ARCHITECT.AGENT.MD` — Design validation
- `.context/agents/QA.AGENT.MD` — Testing standards

---

**Last Updated:** 2026-01-21  
**Version:** 1.0.0  
**Maintained By:** Setup Agent (auto-generated during materialization phase)
