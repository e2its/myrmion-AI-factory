# Template: Feature Decision Record (`docs/spec/{{FEATURE_ID}}/fdr/FDR-{{NUMERO}}-{{TITULO-SLUG}}.md`)

> Feature-scoped Decision Record. Used for binding decisions that apply WITHIN a single feature's scope.
> An FDR is read by BLUEPRINT § 7.8 alongside the relevant constitution `[LAW]` sections — it is binding for that feature only and does NOT amend the universal `docs/constitution.md`.
> For decisions that should change project-wide law, use `adr_template.md` instead.
> Lifecycle: `status: proposed` → `status: accepted` (flipped manually with the same RDR ceremony as ADRs but WITHOUT constitution amendment — the FDR text is itself the binding artefact).

```markdown
---
feature_id: {{FEATURE_ID}}
fdr_number: {{NUMERO}}
title: {{TITULO}}
date: {{FECHA}}
status: proposed
---

# FDR-{{NUMERO}}: {{TITULO}}
> Feature: {{FEATURE_ID}}

## Context
> What problem or need motivated this decision, scoped to this feature?

{{DESCRIPCION_DEL_PROBLEMA}}

## Decision
> What was decided and why? Full rationale, design narrative, references.

{{DECISION_TOMADA}}

**Alternatives considered:**
- Alternative 1: {{DESCRIPCION}} — Discarded because {{RAZON}}
- Alternative 2: {{DESCRIPCION}} — Discarded because {{RAZON}}

## Consequences
> Feature-local impact, advantages and trade-offs.

**Positives:**
- {{VENTAJA_1}}
- {{VENTAJA_2}}

**Negatives / Trade-offs:**
- {{TRADEOFF_1}}
- {{TRADEOFF_2}}

## Binding Rule
> Operational rule that applies WITHIN this feature's scope. Read by BLUEPRINT § 7.8
> when generating `design.md` for {{FEATURE_ID}} (and any feature whose `consumes_contract`
> list includes {{FEATURE_ID}}). Plain text, concise, executable.

{{REGLA_OPERATIVA_FEATURE_LOCAL}}

## Compliance
> Verification of alignment with the universal constitution and project rules.
> An FDR cannot contradict `docs/constitution.md` `[LAW]` sections — if your decision
> requires changing project-wide law, escalate to a project-wide ADR instead.

- ✅ Compatible with `docs/constitution.md`: {{JUSTIFICACION}}
- ✅ Complies with `.claude/rules/{{REGLA}}.instructions.md`: {{JUSTIFICACION}}

## Traceability
- **Origin feature:** {{FEATURE_ID}}
- **Related to:** FDR-{{OTROS_NUMEROS}}, ADR-{{OTROS_NUMEROS}} (if applicable)
- **Impacts:** `{{RUTAS_DE_CODIGO_O_AREAS_AFECTADAS_DENTRO_DE_LA_FEATURE}}`
```

## Why FDR, not "feature-scoped ADR"

The framework previously used the term "ADR" for both project-wide and feature-scoped decisions, which conflated two different concerns:

- **Project-wide ADR** — amends `docs/constitution.md`. Permanent, universal, accepted by ceremony with CI enforcement (EVOL-026).
- **Feature Decision Record (FDR)** — binding within a feature's scope only. Read by BLUEPRINT during design, never escalates to constitution amendment.

Renaming makes the distinction explicit: if a decision deserves universal law, it goes through the ADR ceremony; if it is feature-local, it stays as an FDR.

## What reads an FDR

- BLUEPRINT § 7.8 — when generating `design.md` for the owning feature, mandatory components and feature-local invariants are sourced from FDRs in `docs/spec/{{FEATURE_ID}}/fdr/`.
- BLUEPRINT, when generating design for a feature whose `consumes_contract` list includes `{{FEATURE_ID}}` — the upstream FDRs are surfaced as feature-relevant context.
- IMPLEMENT Review Check #14 (`[DESIGN-FDR]`, renamed from `[DESIGN-ADR]`) — verifies code under the feature respects FDR-declared mandatory components.

## What does NOT read an FDR

- The governance snapshot. FDRs are feature-local — they never enter the universal snapshot embed.
- Other features' BLUEPRINT (unless the dependency is declared via `consumes_contract`).
