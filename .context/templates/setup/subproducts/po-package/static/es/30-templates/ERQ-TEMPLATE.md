---
erq_id: "ERQ-FEAT-XXX-01"            # ERQ-<id de feature>-<dos dígitos>; para el design system: ERQ-VISION-01
target: "feature"                    # feature | vision
feature_id: "FEAT-XXX"               # se omite cuando target es vision
feature_name: "Nombre de la feature"
feature_state: "specified"           # specified | roadmap
scope: "${project_scope}"            # full-stack | frontend-only | backend-only | integration
author: "Nombre del Product Owner"
date: "AAAA-MM-DD"
based_on_package: "${package_id}"

# delta    = añade o afina sin romper nada de lo que funciona
# breaking = cambia un significado, quita algo, o vuelve obligatorio lo que no lo era
classification: "delta"

# Un bloque por cambio. `kind` es uno de:
#   usability | new_field | new_step | new_concept | new_rule | new_component
#   business_rule | copy | route | removal | rename
changes:
  - id: "C1"
    kind: "new_field"
    target: "Concept: NombreDelConcepto"
    summary: "Una línea: qué cambia."
    business_reason: "Qué problema real resuelve. Sin esto el cambio no se puede valorar."
    reuse_checked: "Qué busqué en el glosario o en la base de componentes, y por qué no servía."
    impact: "delta"

# TODO nombre que no esté en 00-core/domain-glossary.md va aquí.
# Una lista vacía significa que no has inventado nada — la mejor de las noticias.
new_names:
  - name: "nombre_campo_nuevo"
    kind: "field"                    # field | concept | persona | rule
    why_not_reused: "Busqué X e Y; ninguno significa esto porque…"

# Sólo en retornos de design system: todo componente que no esté en 10-design-system/components.md.
new_components: []
#  - id: "stepper"
#    name: "Stepper"
#    why_not_reused: "Tabs y Progress no muestran una secuencia que hay que completar en orden."

# Lo que no supiste decidir. Dejarlo abierto es legítimo; inventarse la respuesta no.
open_questions:
  - "…"
---

# Petición de evolución

## Qué problema estamos resolviendo

## Qué propongo

## Cambio a cambio

### C1 — título

- **Qué cambia:**
- **Por qué:**
- **Qué reutilizo:**
- **Qué es nuevo:**
- **Qué pasa con lo que ya existe:**

## Lo que NO he tocado, y por qué

## Alternativas que consideré

| Alternativa | A favor | En contra | Por qué no |
|---|---|---|---|
