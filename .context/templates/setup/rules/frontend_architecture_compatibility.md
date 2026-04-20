---
description: "Frontend architecture compatibility — SPA/MPA/SSR patterns, micro-frontend boundaries, shared state management."
---
# Frontend Architecture Compatibility Matrix

## Overview
This document defines the valid combinations between UX rendering strategies and frontend organization patterns. The **FSD + Atomic + Headless** pattern is the mandatory standard for internal organization, while rendering strategies determine WHERE and WHEN code is executed.

---

## Mandatory Standard Pattern

**Internal Pattern (Code Organization):** 
```
FSD (Feature-Sliced Design) + Atomic Design + Headless Components
```

**Components:**
1. **FSD (Feature-Sliced Design):** Folder structure by features/layers
2. **Atomic Design:** Component hierarchy (Atoms → Molecules → Organisms → Templates → Pages)
3. **Headless Components:** Logic/UI separation, components without coupled styles

**Rationale:**
- ✅ Scalability: Teams can work on independent features
- ✅ Reusability: Atomic Design facilitates component library
- ✅ Testability: Headless enables unit tests without rendering
- ✅ Consistency: Single pattern prevents code fragmentation

**No Custom Patterns:** To avoid combinatorial explosion, the internal pattern is NOT configurable.

---

## UX Strategy Options (Rendering Approach)

These strategies define **WHERE** the UI is rendered:

| Strategy | Rendering Location | Hydration | Use Case |
|----------|-------------------|-----------|----------|
| **SPA** | Client (Browser) | N/A | Interactive apps, dashboards, admin panels |
| **SSR (With hydration)** | Server + Client | ✅ Yes | Critical SEO + interactivity (e-commerce, blogs) |
| **SSR (Without hydration)** | Server only | ❌ No | Static content with simple forms |
| **Micro-Frontends** | Client (Independent per MFE) | Optional | Autonomous teams, large organizations |
| **Jamstack/SSG** | Build-time (CDN) | ❌ No | Static content (docs, marketing) |
| **Islands Architecture** | Server + Client Islands | ✅ Partial | Mostly static sites with targeted interactivity |

---

## Compatibility Matrix (5 Validated Combinations)

| UX Strategy | + Internal Pattern | Compatible? | Cost Increment | Notes |
|-------------|-------------------|-------------|----------------|-------|
| **SPA** | FSD + Atomic + Headless | ✅ Yes | +$100/month | Client rendering, global state via Redux/Context |
| **SSR (Hydration)** | FSD + Atomic + Headless | ✅ Yes | +$150/month | Next.js/Nuxt, Server Components + Client hydration |
| **SSR (Without hydration)** | FSD + Atomic + Headless | ✅ Yes | +$120/month | Less complex, no heavy JS bundle |
| **Micro-Frontends** | FSD + Atomic + Headless | ✅ Yes | +$400/month | Module Federation, each MFE uses same pattern |
| **Jamstack/SSG** | FSD + Atomic + Headless | ✅ Yes | +$80/month | Static generation, reusable components |
| **Islands** | FSD + Atomic + Headless | ✅ Yes | +$200/month | Astro/Qwik, interactive islands with standard pattern |

**All combinations are valid** because the internal pattern is standard and agnostic to rendering.

---

## Exclusion Rules (Incompatibilities)

### ⊗ Jamstack Puro + Runtime Database Access

**Problema:** SSG genera HTML en build-time. No puede consultar DB en runtime del cliente.

**Ejemplo Prohibido:**
```javascript
// ❌ INVALID en Jamstack puro
export default function ProductPage() {
  const [product, setProduct] = useState(null);
  
  useEffect(() => {
    fetch('/api/products/123') // Runtime API call
      .then(res => res.json())
      .then(setProduct);
  }, []);
  
  return <div>{product?.name}</div>;
}
```

**Valid Solution:**
```javascript
// ✅ VALID: Fetch en build-time
export async function getStaticProps() {
  const product = await fetchProductAtBuildTime(123);
  return { props: { product } };
}

export default function ProductPage({ product }) {
  return <div>{product.name}</div>;
}
```

**Alternative:** Use Islands Architecture for dynamic parts.

---

### ⊗ Micro-frontends + Monolithic SPA

**Problem:** Conceptually contradictory. MFEs are for decoupling teams, monolithic SPA centralizes everything.

**Clarification:**
- ✅ **Micro-frontends:** Each MFE IS an independent SPA → VALID
- ❌ **Micro-frontends + single monolithic SPA:** Architectural contradiction

**Correct Decision:**
```yaml
UX Strategy: Micro-Frontends
  - shell-app: SPA (host)
  - checkout-mfe: SPA (independiente)
  - catalog-mfe: SPA (independiente)
```

---

### ⚠️ Micro-frontends + SSR (Complex)

**Status:** Technically possible, but high complexity.

**Budget Validation:**
- IF `budget_tier: starter` → ❌ **BLOCKED** (too expensive)
- IF `budget_tier: professional` → ⚠️ **WARNING** ("High complexity, consider pure SSR")
- IF `budget_tier: enterprise` → ✅ **ALLOWED**

**Required Technologies:**
- Module Federation SSR (Webpack 5)
- Shared state management cross-MFEs
- Streaming SSR coordination

**Cost:** +$550/month ($400 MFE + $150 SSR)

---

## Framework-Specific Constraints

### Angular → MVVM Forzado

**Rule:** If framework is Angular, the MVVM pattern is implicit in RxJS + Reactive Forms.

**Compatibility with Standard:**
```yaml
Frontend:
  Framework: Angular
  UX Strategy: SPA
  Internal Pattern: FSD + Atomic + Headless (Standard)
  Note: "Implicit MVVM in Angular, compatible with Atomic Design for components"
```

### React → Flexible (Hooks preferred)

**Rule:** React does not enforce a specific pattern.

**Recommendation:**
- ✅ Container/Presentational (hooks for logic)
- ✅ Atomic Design (functional components)
- ✅ Headless (custom hooks)

### Vue → MVVM Optional

**Rule:** Vue supports MVVM (Composition API) but does not enforce it.

**Compatibility:**
```yaml
Frontend:
  Framework: Vue 3
  UX Strategy: SSR (Nuxt)
  Internal Pattern: FSD + Atomic + Headless (Standard)
  Note: "Composition API for logic, SFC for components"
```

### Svelte → Pure Component-Based

**Rule:** Svelte compiles components to vanilla JS, no runtime.

**Compatibility:** ✅ Fully compatible with Atomic Design.

### Astro → Native Islands

**Rule:** Astro uses Islands Architecture by design.

**Compatibility:**
```yaml
Frontend:
  Framework: Astro
  UX Strategy: Islands Architecture
  Internal Pattern: FSD + Atomic + Headless (Standard)
  Note: "Islands use React/Vue/Svelte components with standard pattern"
```

---

## Decision Tree (UX Strategy)

### Question 1: Where is it primarily rendered?

```
A. Client (Browser) → SPA
B. Server (Node/Deno) → SSR or SSG
C. Hybrid → Islands
D. Build-time → Jamstack/SSG
E. Multiple independent teams → Micro-Frontends
```

### Question 2: Do you need critical SEO?

```
YES → SSR (with hydration) or SSG
NO → SPA
```

### Question 3: Is content mostly static?

```
YES + Frequent changes → SSG with ISR (Incremental Static Regeneration)
YES + Fixed content → Pure Jamstack/SSG
NO → SPA or SSR
```

### Question 4: Autonomous teams with independent deployments?

```
YES → Micro-Frontends
NO → SPA/SSR/SSG based on other criteria
```

### Question 5: Is JS bundle a problem? (Critical performance)

```
YES + Mostly static content → Islands Architecture
YES + Interactive app → SSR with aggressive code splitting
NO → SPA
```

---

## State Management Integration

### Redux/Context Compatible con Todas las Estrategias

| Strategy | State Management | Notes |
|----------|-----------------|-------|
| **SPA** | Redux / Zustand / Context | Global client state |
| **SSR (Hydration)** | Redux (SSR serialization) | Initial state from server |
| **SSR (Without hydration)** | N/A | No client state |
| **Micro-Frontends** | Redux cross-MFE / Global events | Complex shared state |
| **Jamstack/SSG** | N/A (build-time) | No runtime state |
| **Islands** | Nano stores / Signals | Local state per island |

**Recommendation:**
- SPA + medium/high complexity → **Redux** (+$50/month)
- SPA + low complexity → **Context API** ($0)
- SSR + critical state → **Redux with hydration** (+$50/month)
- Islands → **Nano Stores** ($0)

---

## Scaffolding Output per Strategy

### SPA + FSD + Atomic + Headless

```
src/
├── app/                    # FSD Layer: App
│   ├── providers/          # Context providers, Router
│   └── store/              # Redux store (if needed)
├── pages/                  # FSD Layer: Pages
│   └── HomePage/
├── features/               # FSD Layer: Features
│   └── auth/
│       ├── ui/             # Atomic: Organisms
│       ├── model/          # State, hooks
│       └── api/            # API calls
├── entities/               # FSD Layer: Entities
│   └── user/
├── shared/                 # FSD Layer: Shared
│   └── ui/                 # Atomic: Atoms, Molecules
│       ├── atoms/
│       ├── molecules/
│       └── headless/       # Headless components
└── widgets/                # FSD Layer: Widgets (Organisms + Templates)
```

### SSR (Next.js) + FSD + Atomic + Headless

```
src/
├── app/                    # Next.js App Router
│   ├── (marketing)/        # Route groups
│   │   └── page.tsx
│   └── api/                # API routes
├── features/               # FSD Features (shared con app/)
├── entities/
├── shared/
│   └── ui/
│       ├── atoms/
│       ├── molecules/
│       └── headless/
└── widgets/
```

### Micro-Frontends + Module Federation

```
apps/
├── shell-app/              # Host MFE
│   └── src/                # FSD + Atomic
├── checkout-mfe/           # Remote MFE
│   └── src/                # FSD + Atomic (independiente)
└── catalog-mfe/            # Remote MFE
    └── src/                # FSD + Atomic (independiente)
```

### Islands (Astro) + FSD + Atomic + Headless

```
src/
├── pages/                  # Astro pages (.astro)
├── components/             # Shared components
│   ├── islands/            # Client-side islands (.tsx/.vue)
│   └── static/             # Server-only components (.astro)
├── features/               # FSD Features
└── shared/
    └── ui/
        ├── atoms/
        ├── molecules/
        └── headless/
```

---

## Validation Checklist (Pre-Materialization)

- [ ] **UX_STRATEGY_SELECTED:** One rendering strategy chosen
- [ ] **INTERNAL_PATTERN_STANDARD:** Confirmed FSD + Atomic + Headless (no custom)
- [ ] **FRAMEWORK_COMPATIBILITY:** Chosen framework supports UX strategy
- [ ] **STATE_MANAGEMENT:** Decision made if applicable (Redux/Context/None)
- [ ] **EXCLUSION_RULES:** Verified that no incompatibility rules are violated
- [ ] **BUDGET_COMPLIANCE:** Incremental cost within AI budget
- [ ] **SEO_REQUIREMENTS:** If critical SEO, validated SSR/SSG selected

---

## Examples by Use Case

### E-Commerce (SEO + Interactividad)

```yaml
UX Strategy: SSR (With hydration)
Framework: Next.js
Internal Pattern: FSD + Atomic + Headless
State Management: Redux (cart)
Cost: +$200/month ($150 SSR + $50 Redux)
```

### Admin Dashboard (No SEO)

```yaml
UX Strategy: SPA
Framework: React
Internal Pattern: FSD + Atomic + Headless
State Management: Context API
Cost: +$100/month
```

### Marketing Site (Static, critical performance)

```yaml
UX Strategy: Jamstack/SSG
Framework: Astro
Internal Pattern: FSD + Atomic + Headless
State Management: N/A
Cost: +$80/month
```

### Documentation Site (Mostly static + interactive search)

```yaml
UX Strategy: Islands Architecture
Framework: Astro
Internal Pattern: FSD + Atomic + Headless
State Management: Nano Stores (search state)
Cost: +$200/month
```

### Enterprise Portal (Multiple teams)

```yaml
UX Strategy: Micro-Frontends
Framework: React (Module Federation)
Internal Pattern: FSD + Atomic + Headless (each MFE)
State Management: Redux cross-MFE
Cost: +$450/month ($400 MFE + $50 Redux)
Budget Required: Professional+ tier
```

---

## Integration with Constitution

**`.context/constitution.md`** must reference this document:

```json
{
  "frontend": {
    "ux_strategy": "SSR (With hydration)",
    "framework": "Next.js 14",
    "internal_pattern": "FSD + Atomic + Headless",
    "state_management": "Redux",
    "compatibility_policy": ".claude/rules/frontend_architecture_compatibility.instructions.md",
    "rationale_adr": "docs/adr/ADR-002-frontend-architecture.md"
  }
}
```

---

## Maintenance Policy

**Manual Update Required:** When new patterns are added (e.g., Qwik Resumability):

1. Update compatibility table
2. Add framework-specific constraints
3. Generate ADR documenting inclusion decision
4. Update checklist in `.context/templates/setup/frontend_topologies/NEW_PATTERN_CHECKLIST.md`

**Checklist Location:** `.context/templates/setup/frontend_topologies/NEW_PATTERN_CHECKLIST.md`

---

## Further Reading

- [Feature-Sliced Design](https://feature-sliced.design/)
- [Atomic Design by Brad Frost](https://bradfrost.com/blog/post/atomic-web-design/)
- [Headless Component Pattern](https://www.merrickchristensen.com/articles/headless-user-interface-components/)
- [Islands Architecture](https://jasonformat.com/islands-architecture/)
- [Micro-Frontends](https://micro-frontends.org/)
- [Next.js SSR](https://nextjs.org/docs/basic-features/pages)
- [Astro Islands](https://docs.astro.build/en/concepts/islands/)

---

**Version:** 1.0  
**Last Updated:** 2026-01-23  
**Maintained by:** Setup & Governance Agent
