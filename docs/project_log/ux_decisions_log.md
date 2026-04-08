# 🎨 UX DECISIONS LOG

**Purpose:** Centralized registry of UX design decisions across all features. Enables cross-feature consistency tracking and brand governance.

**Updated:** Auto-updated by `/CODESIGN --start`, `/CODESIGN --refine` (auto-approval), `/BLUEPRINT --adr` (when triggered by UX)

---

## 📊 DECISION TRACKING TABLE

| Fecha | Feature ID | Decisión | Rationale | Aplicada en | ADR (si aplica) | Estado |
|-------|-----------|----------|-----------|-------------|-----------------|---------|
| *Ejemplo* | USR-001 | Color primario cambiado de `#007bff` a `#1e40af` | Mayor contraste WCAG AA (ratio 4.8:1) | design_ux.md, mock.html | ADR-0042 | APPROVED |
| *Ejemplo* | USR-003 | Botón CTA 48px altura (antes 44px) | Accesibilidad táctil Android (Material Design 3) | design_ux.md Section 4 | N/A | APPROVED |
| *Ejemplo* | BUG-015 | Modal backdrop opacity 60% → 50% | Reducir fatiga visual en sesiones largas | design_ux.md tokens | N/A | APPROVED |

---

## 🛡️ DECISIONES DE BRAND (Requieren ADR)

**Criterio de ADR:** Brand changes >20% según brand_tokens en `docs/rules/ux-constitution.md`

**Proceso:**
1. `/CODESIGN --start` detecta drift >20% durante auto-repair WCAG
2. Auto-dispatch: `/BLUEPRINT --adr {{FEATURE_ID}} "UX Brand Change: {{DESCRIPTION}}"`
3. `/BLUEPRINT --refine {{FEATURE_ID}} --constitution` actualiza brand tokens
4. `/CODESIGN --start` o `--refine` auto-aprueba y registra decisión aquí con ADR link

| Fecha | Feature ID | Cambio de Brand | % Drift | ADR | Constitución Actualizada |
|-------|-----------|-----------------|---------|-----|--------------------------|
| *Ejemplo* | USR-007 | Nueva paleta de colores (Dark Mode) | 35% | ADR-0055 | ✅ docs/constitution.md#brand_tokens |
| *Ejemplo* | USR-012 | Tipografía Inter → Geist Sans | 25% | ADR-0061 | ✅ docs/rules/ux-constitution.md |

---

## 🧩 COMPONENT REUSE REGISTRY

**Purpose:** Track component reuse decisions to prevent duplication. Logged by `/CODESIGN --start` during component inventory phase.

| Feature ID | Component | Decision | Source | Justification |
|-----------|-----------|----------|--------|---------------|
| *Ejemplo* | USR-001 | Button Primary | REUTILIZAR | src/components/ui/Button.tsx | Ya implementa variante `variant="primary"` con ARIA |
| *Ejemplo* | USR-002 | Alert Banner | CREAR NUEVO | N/A | Requerimiento específico: multi-line + icon + close button (no existe) |
| *Ejemplo* | USR-005 | Form Input | REUTILIZAR | src/components/forms/Input.tsx | Soporta validation states (error, success) y help text |
| *Ejemplo* | BUG-008 | Modal Confirm | ADAPTAR | src/components/modals/Modal.tsx | Agregar variant="confirm" con botones predefinidos |

---

## 📐 RESPONSIVE DESIGN DECISIONS

**Breakpoints Registry:** Track deviations from standard breakpoints defined in `docs/rules/ux-constitution.md`

| Feature ID | Breakpoint Override | Standard | Override | Rationale | Approved By |
|-----------|-------------------|----------|----------|-----------|-------------|
| *Ejemplo* | USR-010 | Tablet breakpoint | 768px | 820px | Dashboard requiere 4 columnas en iPad Pro landscape | ARCH |

---

## ♿ ACCESSIBILITY EXCEPTIONS

**WCAG 2.1 AA Deviations:** Document any intentional non-compliance (requires ADR approval)

| Feature ID | WCAG Criterion | Standard | Exception | ADR | Justification |
|-----------|----------------|----------|-----------|-----|---------------|
| *Ejemplo* | USR-014 | 1.4.3 Contrast (Minimum) | 4.5:1 | 4.2:1 | ADR-0070 | Brand logo watermark decorativo (no informativo) |

---

## 🔄 ITERATIVE REFINEMENTS

**RDR Loop Tracking:** Document iterative refinements from `/CODESIGN --refine` commands

| Feature ID | Iteration | Feedback Type | Changes Applied | Validated By |
|-----------|-----------|---------------|-----------------|--------------|
| *Ejemplo* | USR-003 | Refinement 1 | PO: "CTA debe ser más prominente" | Aumentado font-size a `text-lg`, agregado shadow-md | UX |
| *Ejemplo* | USR-003 | Refinement 2 | ARCH: "Inconsistente con design system" | Cambiado a clases estándar del design system | UX + ARCH |

---

## 📋 USAGE NOTES

**For UX Agent:**
- Auto-log entries during `/CODESIGN --start` (component decisions, WCAG fixes)
- Auto-log during `/CODESIGN --start` or `--refine` auto-approval (final decision with feature_id)
- Auto-log during `/CODESIGN --refine` (iterative changes)

**For ARCH Agent:**
- Reference this log during `/BLUEPRINT --adr` for brand change context
- Update "Constitución Actualizada" column after constitution edits

**For REVIEW Agent:**
- Cross-reference design_ux.md decisions with this log during `/IMPLEMENT --build` (🔍 REVIEW hat)
- Flag inconsistencies between feature decisions and project-wide decisions

**For QA Agent:**
- Use "Accessibility Exceptions" as baseline for `/QA --e2e` WCAG audits
- Validate that exceptions have valid ADR links

---

## 🔍 AUDIT TRAIL

**Entry Format:**
```markdown
| YYYY-MM-DD | FEATURE_ID | Brief decision summary | Why this decision was made | File(s) affected | ADR-XXXX or N/A | APPROVED/PENDING/REJECTED |
```

**Auto-Populated Fields:**
- `Fecha`: Timestamp from workflow_log.md entry
- `Feature ID`: Extracted from command context
- `Estado`: Synced with design_ux.md frontmatter `status`

**Manual Entries:**
- Project-wide design system changes (requires ARCH approval)
- Brand guideline updates (requires ADR + constitution update)

---

**Last Updated:** {{GENERATED_DATE}} by `/CODESIGN --start {{FEATURE_ID}}`
