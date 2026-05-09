---
version: 1.0.0
date: 2026-05-08
changelog:
  - "1.0.0: feat(EVOL-029) execution complete — single-PR ship on feature/EVOL-029-qa-incremental-slicing. BVL v1.5.0 (full_verification_gate accepts increment_id), Factory-implement-build threads bvl_increment_id + plan-level aggregate after last slice closure, Factory-implement-review-checks emits peer_review_{INC-N}_{ts}.md when incremental, Factory-qa-verify Prerequisites Gate refactored to slice/aggregate dual-mode (3 new [QA-AGG-*] transversal checks + scope/increment_id/aggregates frontmatter on qa_report), Factory-protocol-smart-redirect state model gains qa_slice_reports + decision tree slice-aware. Templates: dev_plan derivation note, qa_report frontmatter extension, increment_plan acceptance gains qa_report_INC-N APPROVED checkbox. Constitution template ships [LAW] QA Per-Increment Alignment section. README state matrices + command tables updated. Backwards-compat strict for slicing_strategy: monolithic. Status flips proposed→accepted; constitution amendment is the [LAW] section already shipped in this PR (template), CI gate `check-adr-constitution-sync.sh` not applicable in meta-repo (no docs/constitution.md — ley universal vive en CLAUDE.md raíz; el template materializa downstream)."
  - "0.1.0: Skeleton — RDR ratifications persisted (QA per-slice alignment with existing increments[] sub-block; per-increment + aggregate report split; gate trigger = tasks [x] + peer_review_INC-N APPROVED + BVL clean per slice). Status: proposed."
adr_number: EVOL-029
title: QA Incremental por Slice — alineamiento del comando /qa --verify con el modelo per-increment
status: accepted
type: framework-evolution
scope: global
---

# ADR-EVOL-029: QA Incremental por Slice

## Context

A partir de EVOL-019 (slicing dual-axis) e iteraciones posteriores, IMPLEMENT divide el trabajo en **increments verticales** cuando `slicing_strategy: incremental`. Cada increment es un PR deployable independiente, con rama propia `feature/{ID}-inc-N-{slug}`, Acceptance Gate (`[INC-N.ACC.k]`) y status per-slice mecánico. El sub-bloque `increments: []` del frontmatter de `dev_plan.md` ya admite valores `READY | BUILDING | IMPLEMENTED_AND_VERIFIED | INVALIDATED` per increment, e IMPLEMENT --build flippa el slice individualmente al cerrar (Factory-implement-build.instructions.md § Completion Verification Gate).

**Síntoma reportado por el usuario:** lanzar `/qa --verify {ID}` cuando el feature aún tiene increments pendientes BLOQUEA con `dev_plan.md status is 'BUILDING', expected 'IMPLEMENTED_AND_VERIFIED'`. Resultado: increments ya MERGEados a main esperan a sus hermanos para ser verificados. No existe trayectoria QA real-incremental aunque el modelo de implementación SÍ lo es.

**Causa estructural:** asimetría entre datos y comando.
- Datos per-slice: `dev_plan.frontmatter.increments[INC-N].status` ya granular (Factory-implement-build § 619-761).
- Verificación BVL per-feature: `full_verification_gate(FEATURE_ID)` corre suite completa aun cuando un solo slice está siendo cerrado.
- Comando QA per-feature: Gate 1 lee SOLO el status global del documento (Factory-qa-verify.instructions.md § Prerequisites Gate, Gate 1).

EVOL-019 trajo la dimensión de slicing al data model; EVOL-028 cerró la disciplina de invocación con ADP. EVOL-029 cierra el último vacío: el comando QA queda alineado al modelo per-PR para que cada slice sea verificable independientemente, y el agregado del feature emerge al final como certificación cross-slice.

## Decision

Adoptar el **modelo QA per-increment alineado al sub-bloque `increments[]`** existente, evitando refactorizaciones de mini-features y manteniendo retrocompatibilidad estricta con `slicing_strategy: monolithic`.

### 1. Sintaxis del comando

`/qa --verify {FEATURE_ID} [{INC-N}]`. El segundo argumento opcional selecciona el modo:

| Modo | Trigger | Lectura del Gate 1 | Salida |
|------|---------|-------------------|--------|
| **Slice** | `INC-N` provisto | `dev_plan.frontmatter.increments[INC-N].status == "IMPLEMENTED_AND_VERIFIED"` | `qa_report_{INC-N}_{ts}.md` |
| **Aggregate** | sin `INC-N`, `slicing_strategy: incremental` | TODOS los `increments[].status == "IMPLEMENTED_AND_VERIFIED"` Y todos los `qa_report_{INC-N}_*.md` APPROVED | `qa_report_final_{ts}.md` con `aggregates: [...]` |
| **Aggregate (legacy)** | sin `INC-N`, `slicing_strategy: monolithic` | `dev_plan.status == "IMPLEMENTED_AND_VERIFIED"` (idéntico a pre-EVOL-029) | `qa_report_final_{ts}.md` |

### 2. Gate trigger per-slice (IMPLEMENT cierra el slice)

Una entrada `increments[INC-N]` transiciona a `IMPLEMENTED_AND_VERIFIED` solo cuando se cumplen TRES condiciones:

1. Todas las tasks `[INC-N.A.M]`, `[INC-N.B.M]`, `[INC-N.C.M]` y `[INC-N.ACC.k]` están `[x]` (Acceptance Gate completo).
2. Existe `peer_review_{INC-N}_*.md` con `status: APPROVED` (review per-slice — naming nuevo en EVOL-029).
3. `BVL full_verification_gate(FEATURE_ID, "INC-N")` retorna `PASSED` (BVL v1.5.0 — scope filtrado al increment para tests + lint; typecheck/build/format/SAST siguen siendo repo-wide).

El status global del feature deriva: `IMPLEMENTED_AND_VERIFIED` global SOLO cuando todos los increments están IMPLEMENTED_AND_VERIFIED Y un BVL aggregate adicional `full_verification_gate(FEATURE_ID, null)` pasa. Esta capa cross-slice atrapa regresiones que una verificación per-slice no puede ver.

### 3. Reportes — split per-slice + agregado

Cada slice produce su propio reporte (`qa_report_INC-N_{ts}.md`) con checklist filtrado: `[QA-TC-*]` solo para `Scenarios covered` del increment, `[QA-REL-*]` solo para contracts en `Contract surface`. Los reportes son artefactos IPP independientes (skeleton-first, section-atomic, resume-on-entry independiente).

El reporte final agregado (`qa_report_final_{ts}.md`) emite TRES bloques nuevos `[QA-AGG-*]`:

- `[QA-AGG-1]`: Cross-slice regression suite (BVL aggregate scope=feature).
- `[QA-AGG-2]`: Per-slice qa_report aggregation — verifica que cada `qa_report_{INC-N}_*.md` está APPROVED y no INVALIDATED.
- `[QA-AGG-3]`: CVP `feature_completion` full-chain coherence.

El agregado documenta los reportes consumidos vía `aggregates: [...]` frontmatter (lista de paths). MERGE → prod sigue gateado por el agregado APPROVED, exactamente como antes para features monolíticos.

### 4. Compatibilidad con `slicing_strategy: monolithic`

Estrictamente retrocompatible. `/qa --verify {ID}` sin INC-N en feature monolítico:
- Gate 1 lee `dev_plan.status` global (sin tocar `increments[]`).
- Genera `qa_report_final_{ts}.md` con scope=`feature` y `aggregates: []`.
- BVL gate corre con `increment_id=null` — exactamente la firma v1.4.0.

## Alternatives Considered

### Alt-A — Estado intermedio compartido `SLICE_VERIFIED` en status global

`dev_plan.status` ganaría un valor adicional `SLICE_VERIFIED` que se acumula entre slices; cuando todos verificados → `IMPLEMENTED_AND_VERIFIED`. **Rechazado:** rompe simetría con el modelo per-PR (un increment ya MERGEado no debe esperar a sus hermanos para tener status QA). Introduce un eje nuevo de máquina de estados que duplica información ya disponible en `increments[].status`.

### Alt-B — Mini-features (cada increment con su propio dev_plan.md, spec.feature derivada)

Cada increment recibe `dev_plan_INC-N.md` independiente; QA opera tal cual sobre ese plan. Simetría perfecta CODESIGN/IMPLEMENT/QA pero **rechazado:** refactor mayor (boilerplate per-increment, duplicación de frontmatter, más superficie de cascada cuando upstream cambia, divergencia con CODESIGN que opera per-feature). El usuario explícitamente lo descartó por coste.

### Alt-C — `--verify --partial` con flag override

`/qa --verify {ID} --partial INC-N` con override del Gate 1. **Rechazado:** workaround menos limpio que el argumento posicional, no invita a la disciplina per-slice y no resuelve la generación de reportes per-slice (sigue produciendo un único `qa_report_final` con scope ambiguo).

## Operational Rule

> **[LAW] QA Per-Increment Alignment:** When `slicing_strategy: incremental`, `dev_plan.status` global is **derived** — it MUST NOT be written manually. Per-slice transitions MUST be applied to `dev_plan.frontmatter.increments[INC-N].status`. `/qa --verify {ID} {INC-N}` is REQUIRED for each increment that has reached `IMPLEMENTED_AND_VERIFIED` per-entry; the aggregate `/qa --verify {ID}` is BLOCKED until every per-slice `qa_report_{INC-N}_*.md` exists with `status: APPROVED`. The plan-level `IMPLEMENTED_AND_VERIFIED` global flips only after the aggregate BVL `full_verification_gate(FEATURE_ID, null)` passes following the last slice closure.

This rule materialises into the project constitution as a `## [LAW] QA Per-Increment Alignment` section (ADR Accept Procedure — factory-adr-management), via the constitution_template.md update shipped in this same PR.

## Consequences

### Positive

- Slices ya MERGEados a main son QA-verificables sin esperar a sus hermanos. Reduce el lead time real-incremental al verdadero throughput de IMPLEMENT.
- Modelo per-PR cohesivo: branch + PR + peer_review + BVL + qa_report todos per-slice; agregado sólo en el último cierre.
- Los reportes per-slice son citables independientemente — auditorías pueden trazar exactamente qué se verificó cuándo, slice por slice.
- BVL per-slice reduce el tiempo de la suite de tests cuando solo una rebanada cambió (lint + tests filtrados); typecheck/build/format/SAST se mantienen repo-wide para no debilitar gates de compilación/seguridad.
- Compatibilidad estricta con monolithic — proyectos pre-EVOL-029 no requieren migración.

### Negative / Trade-offs

- Tres archivos de instructions tocados (Factory-build-verification/SKILL.md, Factory-implement-build.instructions.md, Factory-implement-review-checks.instructions.md) más Factory-qa-verify.instructions.md y los dos commands. Superficie de drift mayor durante 1-2 sprints hasta que materialise en proyectos downstream.
- Naming nuevo `peer_review_{INC-N}_{ts}.md` — proyectos downstream materializados con framework < EVOL-029 verán el cambio en el siguiente `setup --upgrade`. La transición es one-shot: un feature en vuelo puede mantener `peer_review_{ts}.md` global; los nuevos increments emiten el nombre nuevo. Smart Redirect maneja ambos.
- `[QA-AGG-3]` (CVP feature_completion) introduce dependencia adicional sobre Factory-coherence-validation/SKILL.md — verificada inline al ejecutar el agregado.

### Risk Assessment

- **Technical Risk:** Low. Cambio mecánico aditivo: `full_verification_gate` gana un parámetro opcional con default null (idéntico al comportamiento previo); QA Gate 1 ramifica según presencia de INC-N. Tests downstream cubren ambos paths.
- **Adoption Risk:** Low-Medium. Operadores acostumbrados a `/qa --verify {ID}` sin INC-N seguirán funcionando en monolithic; en incremental el bloqueo del Gate 1 redirige humanamente con `Run /qa --verify {FEATURE_ID} {INC-N} for each pending slice.` (Humanized Blocking).
- **Compatibility Risk:** Low. Retrocompatibilidad estricta con `slicing_strategy: monolithic` (verificado en plan de validación end-to-end del feature/EVOL-029-qa-incremental-slicing branch, paso 8).

## Compliance

### Constitution Alignment

- ✅ Aligns with KISS: extensión mínima (un argumento opcional + un campo de frontmatter); no rediseña el modelo de increments.
- ✅ Aligns with DRY: reutiliza `READ_FRONTMATTER`, `COLLECT_ALL_SOURCE_FILES`, IPP, ACP — ningún helper nuevo masivo.
- ✅ Aligns with Constitutional Supremacy: la Operational Rule materializa en el constitution_template.md vía Accept Procedure (mismo PR).
- ✅ Aligns with Humanized Blocking: bloqueos del Gate 1 redirigen en lenguaje de negocio con la siguiente acción.

### Rules Alignment

- ✅ branching.md: ramas `feature/{FEATURE_ID}-inc-N-{slug}` ya soportadas por factory-branching-strategy.
- ✅ testing.md: suite per-slice respeta el principio "tests before merge" — un slice no se cierra sin BVL clean.
- ✅ review-policy.md: peer_review APPROVED sigue siendo gate; ahora también per-slice.
- ✅ immutability_policy.md § Per-Increment Immutability: una vez slice MERGED el qa_report_INC-N queda inmutable (INVALIDATED si upstream cambia y dispara cascada).

## Traceability

- **Generated by:** Free-form chat — user gap report 2026-05-08.
- **Plan file:** `/home/e2its/.claude/plans/he-detectado-un-gap-snug-floyd.md` (ratified before implementation).
- **Branch:** `feature/EVOL-029-qa-incremental-slicing`.
- **Related ADRs:** EVOL-019 (slicing dual-axis — introduced increments[]), EVOL-028 (ADP — frontmatter discovery contract reused for `applicable_when:` on instructions/skills modified here).
- **Impacts:**
  - `.claude/skills/factory-build-verification/SKILL.md` (BVL v1.5.0)
  - `.claude/instructions/Factory-implement-build.instructions.md` (Completion Gate threading)
  - `.claude/instructions/Factory-implement-review-checks.instructions.md` (peer_review naming)
  - `.claude/instructions/Factory-qa-verify.instructions.md` (Prerequisites Gate refactor)
  - `.claude/instructions/Factory-protocol-smart-redirect.instructions.md` (qa_slice_reports state + decision tree)
  - `.claude/commands/qa.md`, `.claude/commands/implement.md`
  - `.context/templates/develop/dev_plan_template.md`, `.context/templates/qa/qa_report_template.md`, `.context/templates/architect/increment_plan_template.md`
  - `.context/templates/setup/constitution/constitution_template.md` (new `[LAW]` section)
  - `README.md` (command tables + state matrices)
- **Status:** proposed → accepted (status flip in same PR per CI gate `check-adr-constitution-sync.sh`).
- **Last Updated:** 2026-05-08
