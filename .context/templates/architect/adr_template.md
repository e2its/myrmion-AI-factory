# Template C: Standalone ADR File (`docs/adr/ADR-{{NUMERO}}-{{TITULO-SLUG}}.md`)

```markdown
---
feature_id: {{FEATURE_ID}}
adr_number: {{NUMERO}}
title: {{TITULO}}
date: {{FECHA}}
status: accepted
---

# ADR-{{NUMERO}}: {{TITULO}}

## Context
> What problem or need motivated this decision?

{{DESCRIPCION_DEL_PROBLEMA}}

## Decision
> What was decided and why?

{{DECISION_TOMADA}}

**Alternatives considered:**
- Alternative 1: {{DESCRIPCION}} - Discarded because {{RAZON}}
- Alternative 2: {{DESCRIPCION}} - Discarded because {{RAZON}}

## Consequences
> System impact, advantages and trade-offs

**Positives:**
- {{VENTAJA_1}}
- {{VENTAJA_2}}

**Negatives / Trade-offs:**
- {{TRADEOFF_1}}
- {{TRADEOFF_2}}

## Compliance
> Verification of governance alignment

- ✅ Complies with `.context/constitution.md`: {{JUSTIFICACION}}
- ✅ Complies with `.context/rules/{{REGLA}}.md`: {{JUSTIFICACION}}

## Traceability
- **Origin feature:** {{FEATURE_ID}}
- **Related to:** ADR-{{OTROS_NUMEROS}} (if applicable)
- **Impacts:** `{{RUTAS_DE_CODIGO}}`
```
