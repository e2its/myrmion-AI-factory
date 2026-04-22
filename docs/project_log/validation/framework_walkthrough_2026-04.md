---
title: Framework Validation Walkthrough — Helix Testbed
evolution: EVOL-022
date: 2026-04-22
framework_version_at_capture: 2.5.0
status: DRAFT
author: EVOL-022
---

# Framework Validation Walkthrough — Helix Testbed

Simulación por escrito de un proyecto ficticio "Helix" atravesando el pipeline SDLC del framework AI Factory, con el único propósito de detectar gaps estructurales y guiar sus correcciones (EVOL-022).

No se ejecuta nada. Los hooks, scripts y comandos se auditan por inspección directa de los ficheros reales. Para cada fase se cita el fichero fuente al que se atribuye el comportamiento.

---

## 0. Alcance y método

- **Scope**: `.claude/commands/` (8), `.claude/instructions/` (20), `.claude/skills/` (14), `.claude/hooks/` (5), `scripts/` (8 + 3 git-hooks), `.context/templates/**` (materialización), `.github/workflows/` (2), [CLAUDE.md](../../../CLAUDE.md), `.context/governance_snapshot.md`.
- **Fuera de scope**: runtime real, tokens, LLM output, integraciones externas.
- **Método**: walkthrough narrativo en 7 fases (A-G), 3 matrices de cobertura, 13 escenarios adversos, registro de gaps con fix propuesto.

---

## 1. Testbed — "Helix"

SaaS B2B de formularios dinámicos con integración a CRM.

- Stack: Next.js 15 (App Router) + tRPC + Prisma/PostgreSQL + Tailwind en Vercel + Supabase, outbound HubSpot.
- `project_scope`: `full-stack`.
- `feature_phases_preset`: `full-sdlc` por defecto.

### Features

| # | FEAT-ID | scope | slicing | preset | Propósito de cobertura |
|---|---|---|---|---|---|
| F1 | `FORM-001` form-submit-endpoint | backend-only | monolithic | simplified | Trivial-Heuristic positiva (2 escenarios, 2 ops) |
| F2 | `FORM-002` dynamic-form-builder | full-stack | incremental | full-sdlc | 5 escenarios, 7 ops, CIP reuse sobre F1 |
| F3 | `INT-001` hubspot-sync | integration | incremental | full-sdlc | `consumes_contract: [FORM-001]`, cascade cross-feature |

---

## 2. Volumen I — Guion lineal

Cada paso usa plantilla fija: **Cmd / Skills / Instruction / Gates / RDR / Artefactos / Worklog / Branch / Canary / PASS / FAIL-gap**. Los pasos-ancla se narran en detalle; el resto se dejan compactos.

### Fase A — Bootstrap

#### A.1 — `/setup --init`
- **Cmd**: `/setup --init`
- **Skills**: IPP (skeleton `docs/setup.md`), RDR (Tier 0/1/2 batches Q1-Q26), ACP (entry announcement), Worklog (user_agent: SETUP), Branching (lock `setup/helix-bootstrap`).
- **Instruction**: [Factory-setup-discovery.instructions.md](../../../.claude/instructions/Factory-setup-discovery.instructions.md).
- **Pre-gate**: main-branch block (enforced by [check-branch-protection.sh](../../../.claude/hooks/check-branch-protection.sh) line 15).
- **RDR esperados (≥3 opciones cada uno)**:
  - `project_scope`: [full-stack | backend-only | frontend-only | integration]. Recomendación: full-stack.
  - Topología backend: [B1 monolithic-layered | B3 modular-monolith | B7 microservices-event-driven | B9 serverless]. Rec: B3.
  - Topología frontend: [F1 CSR-spa | F3 SSR-next | F5 islands]. Rec: F3 (Next.js).
  - IaC: [Terraform | Pulumi | CDK | Docker-Compose]. Rec: Terraform.
  - CI/CD: [GitHub Actions | GitLab CI | Jenkins]. Rec: GitHub Actions.
  - project_tracking.tool: [GitHub Projects | Linear | Jira | None-local]. Rec: GitHub Projects.
  - feature_phases_preset (Q27.2): [full-sdlc | simplified | single]. Rec: full-sdlc.
- **Artefactos**: `docs/setup.md` (phase: COMPLETED), `docs/project_log/adr/ADR-0000-setup-decisions.md`.
- **Worklog**: `{phase: SETUP, action: INIT_COMPLETED, user_agent: SETUP}`.
- **Branch**: `setup/helix-bootstrap`. Lock: `.context/locks/setup-helix-bootstrap.lock`.
- **Canary armado para A.2**: `_progress` frontmatter en `docs/setup.md` con `completed_sections[]`.
- **PASS si**: `docs/setup.md.phase == COMPLETED`, ADR-0000 existe, RDRs persistidos con opción ratificada verbatim.
- **FAIL-gap si**: un RDR se resuelve con <3 opciones, o falta el acta de ratificación en ADR-0000.

#### A.2 — `/setup --generate`
- **Skills**: IPP (checkpoint saves), GCRP (genera `governance_snapshot.md`), CIP (bootstrap `config/codebase_inventory.json`), ACP, Worklog, Branching.
- **Instruction**: [Factory-setup-materialization.instructions.md](../../../.claude/instructions/Factory-setup-materialization.instructions.md).
- **Artefactos**: `docs/constitution.md`, `.claude/rules/*.instructions.md`, `config/{protected-paths,allowlist,codebase_inventory,system_resources}.json`, `.claude/commands/`, `.claude/instructions/`, `.claude/skills/`, `.claude/hooks/`, `.github/workflows/`, `scripts/`, árbol `src/`, `.context/governance_snapshot.md`.
- **Checkpoints bloqueantes**: 3 (templates-resolved → rules-generated → snapshot-regenerated).
- **PASS si**: `scripts/validate-governance.sh` retorna 0 tras materialization; snapshot banner aparece en siguiente sesión.

#### A.3 — SessionStart banner tras materialization
- **Hook**: [scripts/validate-governance.sh --banner](../../../scripts/validate-governance.sh) wired en [.claude/settings.json](../../../.claude/settings.json) línea 8.
- **Evento**: primer prompt de la sesión siguiente al materialization.
- **PASS si**: imprime "Governance loaded: constitution {hash8}, setup {hash8} | SDLC-first triage: ON" (variant downstream; meta usa otro banner).

#### A.4 — UserPromptSubmit freshness check
- **Hook**: [scripts/governance-onprompt.sh](../../../scripts/governance-onprompt.sh) en [.claude/settings.json](../../../.claude/settings.json) línea 18.
- **Dispara**: en cada prompt, compara MD5 de `docs/constitution.md` + `docs/setup.md` vs `governance_snapshot.md` frontmatter.
- **Bloqueante**: exit 2 si stale → prompt rechazado con mensaje "Governance snapshot stale".

#### A.5 — `/audit --software` (opcional, antes o durante)
- **Instruction**: [Factory-audit-checklist.instructions.md](../../../.claude/instructions/Factory-audit-checklist.instructions.md).
- **Artefacto**: `docs/software_audit.md` con `verdict: GO|NO_GO|GO_WITH_CONDITIONS`.
- **Branching**: `audit/helix-initial`.

### Fase B — Visión producto

#### B.1 — `/codesign --vision`
- **Skills**: IPP, RDR (identidad visual, paleta, tipografía, layout global), ACP, Worklog.
- **Instruction**: [Factory-codesign-vision.instructions.md](../../../.claude/instructions/Factory-codesign-vision.instructions.md).
- **Branch**: `feature/UX-VISION-global-app-design`.
- **Artefactos**: `docs/ux/vision/{vision.md, app_shell.html, style_guide.html, page_templates.html, component_library.html, navigation_map.md}`.
- **PASS si**: vision.md APPROVED + todos los assets presentes.
- **FAIL-gap si** (project_scope=backend-only): CODESIGN --vision debería ser N/A. El framework debe reconocerlo y skipear esta fase. Verificar en codesign command qué dice sobre scope.

### Fase C — Backlog

#### C.1 — `/backlog --init-board`
- **Skills**: ACP, Worklog.
- **Instruction**: [Factory-backlog-operations.instructions.md](../../../.claude/instructions/Factory-backlog-operations.instructions.md).
- **Modo externo (GitHub Projects)**: crea proyecto, columnas Kanban desde preset. Persiste `docs/backlog/project-config.json` (no state.md).

#### C.2 — `/backlog --plan-feature FORM-001 "form-submit-endpoint"` ×3
- Para cada feature, expande `feature_phases_preset`:
  - F1 (simplified): 3 issues (spec, implement, qa).
  - F2, F3 (full-sdlc): 8 issues cada una (codesign, blueprint, contract-freeze, devops, implement, preventive-sweep, qa, smoke-e2e).
- **PASS si**: 3 + 8 + 8 = 19 issues creadas en el board, sin huérfanos.

### Fase D — F1 trivial (monolithic)

#### D.1 — `/codesign --start FORM-001`
- **Skills**: IPP (M-07 per-scenario atomic), RDR (scope decision, slicing strategy), CIP (Phase 0.5: domain concepts "FormSubmission" check), Iteration-detection-gate, Worklog, Branching, ACP, Commit-prompt.
- **Instruction**: [Factory-codesign-feature.instructions.md](../../../.claude/instructions/Factory-codesign-feature.instructions.md).
- **Branch**: `feature/FORM-001-form-submit-endpoint`.
- **RDR críticos**:
  - `scope`: recomendado `backend-only` (sin UI). Opciones: [backend-only | integration | full-stack].
  - `slicing_strategy`: recomendado `monolithic` (Trivial-Heuristic positiva: 2 escenarios, 2 ops, scope ≠ full-stack). Opciones: [monolithic | incremental].
- **Scope Compatibility Gate** (EVOL-019): `feature.scope=backend-only ⊆ project_scope=full-stack` → OK.
- **Artefactos**: `docs/spec/FORM-001/{spec.feature, user_journey.integration.md, mock.html N/A}`.
- **Nota**: `mock.html` es N/A para backend-only. `user_journey.integration.md` (no `user_journey.md`).
- **PASS si**: spec.feature frontmatter contiene `scope: backend-only`, `slicing_strategy: monolithic`, status DRAFT.

#### D.2 — `/blueprint --start FORM-001`
- **Skills**: IPP (Pillar 1 skeleton de design.md + test_plan.md + increment_plan.md), RDR (design alternatives, contract style, slicing alternatives), CIP (Step -2 4-criteria), Iteration-detection-gate, Memory-cache, ACP, Worklog, Branching, Commit-prompt.
- **Instruction**: [Factory-blueprint-design.instructions.md](../../../.claude/instructions/Factory-blueprint-design.instructions.md).
- **Trivial-Heuristic Gate**: scenarios=2 ≤ 2, ops=2 ≤ 3, scope=backend-only ≠ full-stack → `monolithic` válido.
- **Artefactos**: `docs/spec/FORM-001/{design.md, test_plan.md, increment_plan.md (monolithic declaration)}`, `contracts/openapi/FORM-001-form-submit.yaml`.
- **CANARY**: IPP canary gate antes de cada section-write; CIP canary gate antes de CREATE.
- **FAIL-gap si**: `increment_plan.md` no se escribe porque el hook IPP no lo reconoce como tracked (verificar [check-ipp-compliance.sh](../../../.claude/hooks/check-ipp-compliance.sh) line 56-69 — **GAP G01**).

#### D.3 — `/blueprint --approve FORM-001`
- **CVP Gate**: Scope `CODESIGN_BLUEPRINT`. Checks críticos 0c, 13-16.
  - Check 0c `increment_plan_presence`: increment_plan.md existe ✓.
  - Check 13 `increment_deployability`: INC-1.deployable=production ✓.
  - Check 14 `increment_to_scenario_coverage`: 2/2 escenarios ✓.
  - Check 15 `increment_to_contract_coverage`: 2/2 ops ✓.
  - Check 16 `monolithic_heuristic`: satisfied ✓.
- **Status**: design.md → APPROVED, test_plan.md → APPROVED, increment_plan.md → APPROVED.
- **CONTRACT-FREEZE activated**: `contracts/openapi/FORM-001-form-submit.yaml` freeze (hash en frontmatter).

#### D.4 — `/devops --configure FORM-001`
- **Artefacto**: `docs/spec/FORM-001/devops_plan.md` (skeleton IaC Terraform + Vercel/Supabase env).

#### D.5 — `/implement --plan FORM-001`
- **CVP Gate**: Scope `CODESIGN_BLUEPRINT_IMPLEMENT`. Check 17 `increment_to_task`.
- **Branching Strategy** (monolithic): `feature/FORM-001-form-submit-endpoint` — 1 rama, 1 PR.
- **Task tagging**: `[A.1], [A.2], [B.N/A], [C.1], [C.2]` (monolithic format).
- **Artefacto**: `docs/spec/FORM-001/dev_plan.md`.

#### D.6 — `/implement --build FORM-001`
- **Skills**: BVL (task + phase + full gate), CIP canary, Iteration-model, Memory-cache (BVL commands cached), Worklog (per task), ACP (5 phase milestones: DEV phases A/C, REVIEW, SEC, Completion), Commit-prompt.
- **Phases**: A (domain/Prisma schema + ORM layer), C (integration/tRPC endpoint).
- **Completion Gate**: todos `[x]` → status `IMPLEMENTED_AND_VERIFIED`. Enforced by [check-completion-gate.sh](../../../.claude/hooks/check-completion-gate.sh).
- **PR**: draft → ready. Branch: `feature/FORM-001-form-submit-endpoint`.

#### D.7 — PR merge FORM-001
- Post-merge hook (conceptual): status increment → MERGED, stamp `Merged at: ...` en increment_plan.md.

#### D.8 — `/qa --verify FORM-001` (preset simplified: sin preventive-sweep ni smoke-e2e)
- **CVP Gate**: Scope `FULL_CHAIN`.
- **Artefacto**: `docs/spec/FORM-001/qa/qa_report_final_{ts}.md` (APPROVED).
- **PASS si**: DAST clean, scenarios verified, completion gate clean.

#### D.9 — `/devops --deploy FORM-001 --env prod`
- Post-PR-merge. Deploy Terraform + Next.js + Prisma migrations.

### Fase E — F2 compleja (incremental)

#### E.1 — `/codesign --start FORM-002`
- Similar a D.1 pero: `scope=full-stack`, `slicing_strategy=incremental`.
- **CIP hit en E.2 cuando aparece "FormSubmission" domain en scenarios** → CIP RDR ofrece [REUSE_EXISTING (extendiendo FORM-001) | EXTRACT_TO_SHARED | CREATE_NEW]. Recomendación: REUSE_EXISTING.
- **mock.html**: pixel-perfect de form builder UI.

#### E.2 — `/blueprint --start FORM-002`
- **Increment Plan Generation**: RDR con ≥3 alternativas de slicing:
  - Alt 1: 3 incrementos (A: DB + Form model, B: Builder UI + drag-drop, C: Submit flow). Recomendación.
  - Alt 2: 5 incrementos más finos.
  - Alt 3: 2 incrementos gruesos.
- **Artefacto**: `increment_plan.md` con INC-1, INC-2, INC-3, cada uno con scenarios_covered, contract_surface, deployable:production.

#### E.3 — `/blueprint --approve FORM-002`
- CVP Checks 0c/13/14/15/16 pasan.
- INC-1.status: DRAFT → READY.

#### E.4 — `/implement --plan FORM-002`
- Task tagging incremental: `[INC-1.A.1], [INC-1.A.2], [INC-1.B.1], ... [INC-3.ACC.1]`.
- **Per-Increment Branching** (conceptual): `feature/FORM-002-inc-1-db-form-model`.

#### E.5 — `/implement --build FORM-002 INC-1`
- Ejecuta solo tasks INC-1.*.*. INC-1.status: READY → BUILDING.
- PR merge → INC-1.status: MERGED, stamp en increment_plan.md.
- **[SIMULATED-COMPACT]** entre tasks → IPP canary re-lee `_progress`, CIP canary re-lee inventory. Test de canary post-summarization.

#### E.6 — `/implement --build FORM-002 INC-2`
- Branch: `feature/FORM-002-inc-2-builder-ui`.
- Durante build: QA identifica edge case → `/codesign --refine FORM-002` con nuevo scenario.
- **CASCADE_PENDING_ITERATION** se dispara. **CASCADE_INCREMENT_INTERNAL**: INC-2 (BUILDING) queda con `pending_iteration: true`, INC-3 (DRAFT) intersectando scenario → INVALIDATED → forzado a DRAFT. INC-1 (MERGED) NO se invalida — se cascadea a follow-up increment INC-4.

#### E.7 — `/blueprint --refine FORM-002` → `/implement --refine FORM-002`
- Genera [D.N] delta tasks, [ADJ-N] adjustments.
- Plan-level status: DRAFT (from APPROVED) hasta re-approve.

#### E.8 — `/implement --build FORM-002 INC-2` (continúa)
- INC-2 pending_iteration clarificado → BUILDING → MERGED.

#### E.9 — `/implement --build FORM-002 INC-3`
- INC-3.status: DRAFT → READY → BUILDING → MERGED.

#### E.10 — `/implement --build FORM-002 INC-4` (follow-up)
- Additive, no version bump.

#### E.11 — PREVENTIVE-SWEEP (primer deploy)
- **Skill**: [Factory-preventive-sweep/SKILL.md](../../../.claude/skills/Factory-preventive-sweep/SKILL.md).
- Parallel sub-agents contra `.claude/rules/defect-prevention.md` DC catalog.
- Zero C-severity → pasa.

#### E.12 — `/devops --deploy FORM-002 --env dev`
- Smoke tests.

#### E.13 — SMOKE-E2E → `/qa --verify FORM-002`
- Manual smoke blocks desde user_journey.md BDD scenarios.

#### E.14 — Merge + prod deploy.

### Fase F — F3 integration + cascade cross-feature

#### F.1 — `/codesign --start INT-001`
- scope: integration. mock.html N/A. user_journey.integration.md.
- `consumes_contract: [FORM-001]`.

#### F.2 — `/blueprint --start INT-001`
- **Consumes-Contract Gate**: verifica FORM-001 APPROVED + contract file existe. ✓.

#### F.3 — Cambio upstream en FORM-001 (mock scenario): se añade un campo al contract.
- `/blueprint --refine FORM-001` (parchea contract). CVP detecta cambio.
- **CASCADE_CONSUMERS** (cross-feature): INT-001 pending_iteration = true.
- **[SIMULATED-COMPACT]** aquí. Post-resume: iteration_detection_gate en INT-001 re-ejecuta, detecta gap.

#### F.4 — `/blueprint --refine INT-001` resuelve delta. Re-approve.

#### F.5-F.8 — Implement + deploy + QA + merge INT-001.

### Fase G — Cierre

#### G.1 — `/backlog --status` — board agregado.
#### G.2 — `/audit --software` — revisión global.
#### G.3 — Release notes + tag automático via `.github/workflows/auto-tag.yml`.

---

## 3. Volumen II — Matrices de cobertura

### M1 — Skills × fases

| Skill | A | B | C | D | E | F | G | Primera invocación | Último paso |
|---|---|---|---|---|---|---|---|---|---|
| IPP | A.1 | B.1 | — | D.1 | E.1 | F.1 | — | A.1 | F.4 |
| RDR | A.1 | B.1 | — | D.1 | E.2 | F.1 | — | A.1 | F.4 |
| ACP | A.1 | B.1 | C.1 | D.1 | E.1 | F.1 | G.2 | A.1 | G.2 |
| Worklog | A.1 | B.1 | C.1 | D.1 | E.1 | F.1 | G.1 | A.1 | G.3 |
| GCRP | A.2 | B.1 | — | D.2 | E.2 | F.2 | G.2 | A.2 | G.2 |
| CIP | A.2 | — | — | D.1 | E.1 | F.1 | — | A.2 | F.1 |
| Branching | A.1 | B.1 | C.1 | D.1 | E.1 | F.1 | — | A.1 | F.6 |
| BVL | — | — | — | D.6 | E.5 | F.5 | — | D.6 | F.5 |
| CVP | — | — | — | D.3 | E.3 | F.2 | — | D.3 | F.4 |
| Iteration-model | — | — | — | — | E.6 | F.3 | — | E.6 | F.4 |
| Memory-cache | — | — | — | D.5 | E.4 | F.4 | — | D.5 | F.4 |
| Commit-prompt | A.1 | B.1 | C.1 | D.1 | E.1 | F.1 | G.3 | A.1 | G.3 |
| Preventive-sweep | — | — | — | — | E.11 | F.7 | — | E.11 | F.7 |
| Next-task | — | — | C.2 | — | — | — | G.1 | C.2 | G.1 |

**Celdas vacías esperadas**: GCRP no se carga en SETUP/AUDIT (by design); CIP no aplica en B (global vision). CVP no aplica hasta BLUEPRINT. BVL solo en IMPLEMENT. Iteration-model solo cuando hay --refine. Preventive-sweep solo en primer deploy / QA. Next-task solo en backlog.

**Cobertura**: 14/14 skills tocadas. ✓

### M2 — Instructions × comandos (resumen)

| Instruction | Comando que la carga |
|---|---|
| Factory-setup-discovery | `/setup --init` |
| Factory-setup-materialization | `/setup --generate` |
| Factory-setup-upgrade | `/setup --upgrade` |
| Factory-audit-checklist | `/audit --audit`, `/audit --software` |
| Factory-audit-complexity | `/audit --audit` (complexity scoring) |
| Factory-codesign-vision | `/codesign --vision` |
| Factory-codesign-feature | `/codesign --start`, `/codesign --refine` |
| Factory-blueprint-design | `/blueprint --start`, `/blueprint --refine` |
| Factory-blueprint-validation | `/blueprint --approve` |
| Factory-implement-plan | `/implement --plan` |
| Factory-implement-build | `/implement --build`, `/implement --refine`, `/implement --fix` |
| Factory-implement-review-checks | Hat=REVIEW durante `/implement --build` |
| Factory-qa-verify | `/qa --verify`, `/qa --reject`, `/qa --e2e` |
| Factory-devops-configure | `/devops --configure`, `/devops --refine` |
| Factory-devops-provision-deploy | `/devops --provision`, `/devops --deploy`, `/devops --rollback`, `/devops --status` |
| Factory-backlog-execution-plan | `/backlog --plan-execution`, `/backlog --sync-execution`, `/backlog --update-execution` |
| Factory-backlog-next-task | `/backlog --next-task`, `/backlog --eligible` |
| Factory-backlog-operations | `/backlog --init-board`, `/backlog --plan-feature`, `/backlog --move`, `/backlog --status`, `/backlog --create-issue` |
| Factory-protocol-iop-intent-map | (mapping only, no direct comando — IOP classifier) |
| Factory-protocol-smart-redirect | Factory routing (post-command) |

**Cobertura**: 20/20 instructions referenciadas. `protocol-iop-intent-map` y `protocol-smart-redirect` son cross-cutting (no 1:1 con comando). ✓

### M3 — Hard Gates × pasos

| Gate | Step activación | Step PASS | Step FAIL | Defender |
|---|---|---|---|---|
| CONTRACT-FREEZE | D.3 (blueprint --approve) | D.5 (implement --plan) | Adv#1 | Blueprint --approve sella frontmatter; implement --plan lee hash |
| PREVENTIVE-SWEEP | E.11 (pre-deploy dev) | E.12 | Adv#2 | Defined in [Factory-preventive-sweep/SKILL.md](../../../.claude/skills/Factory-preventive-sweep/SKILL.md) |
| SMOKE-E2E | E.13 (pre-qa) | E.13 | Adv#3 | user_journey.md BDD manual blocks |

### M4 — Canary gates × pasos post-summarization

| Canary | Step | Gate verifica |
|---|---|---|
| ipp_canary_gate | E.5, F.3 | Re-read `_progress` antes de cada section write |
| cip_canary_gate | E.2, F.1 | Re-read inventory filtered slice antes de CREATE |
| contract_canary_gate | F.3 | Re-read feature_map.md antes de contract write |
| cvp_coherence_gate | D.3, E.3, F.2 | Matrix completeness pre-approve/plan/verify |
| iteration_detection_gate | E.7, F.3 | Spec iteration vs artifact.based_on_iteration |
| verify_cascade_completion | E.6, F.3 | Post-cascade: todos downstream recibieron pending_iteration |

### M5 — Hooks × eventos

| Hook | Evento | Paso(s) |
|---|---|---|
| `scripts/validate-governance.sh --banner` | SessionStart | A.3 (cada session) |
| `scripts/governance-onprompt.sh` | UserPromptSubmit | A.4 (every prompt) |
| `scripts/governance-oncompact.sh` | PreCompact | E.5, F.3 (simulated compacts) |
| `.claude/hooks/check-branch-protection.sh` | PreToolUse Edit\|Write | A.1 (branch creation), Adv#9 |
| `.claude/hooks/check-concurrency-lock.sh` | PreToolUse Edit\|Write | A.1, Adv#10 |
| `.claude/hooks/check-governance-drift.sh` | PreToolUse Edit\|Write | A.2 (post-snapshot), Adv#6 |
| `.claude/hooks/check-completion-gate.sh` | PreToolUse Write | D.6 (completion), Adv#5 |
| `.claude/hooks/check-ipp-compliance.sh` | PreToolUse Write | D.2 (skeleton of increment_plan — **GAP G01**), Adv#8 |

---

## 4. Volumen III — 13 escenarios adversos

Cada escenario cita línea exacta del fichero defensor.

### Familia A — Gate violations

**Adv#1 — `/implement --plan FORM-001` antes de `/blueprint --approve`**
- Defensa: [Factory-implement-plan.instructions.md](../../../.claude/instructions/Factory-implement-plan.instructions.md) § prerequisite verification.
- PASS si: bloqueo con mensaje citando `design.md.status ≠ APPROVED`.

**Adv#2 — `/devops --deploy FORM-002 --env dev` sin PREVENTIVE-SWEEP previo**
- Defensa: [Factory-devops-provision-deploy.instructions.md](../../../.claude/instructions/Factory-devops-provision-deploy.instructions.md) + `.context/templates/setup/claude/CLAUDE.md` Hard Gates table line 76+.
- PASS si: block + instruction para ejecutar `/qa --sweep` o equivalente.

**Adv#3 — `/qa --verify FORM-002` sin manual smoke blocks ejecutados**
- Defensa: [Factory-qa-verify.instructions.md](../../../.claude/instructions/Factory-qa-verify.instructions.md) checklist completion gate.
- PASS si: unchecked `- [ ]` en smoke section impide APPROVED.

**Adv#4 — `/codesign --start BAD-001` sin feature en backlog**
- Defensa: iteration-detection-gate o backlog existence check.
- PASS si: RDR ofrece [crear en backlog ahora | cancelar].

### Familia B — Governance integrity

**Adv#5 — `dev_plan.md` escrito con status IMPLEMENTED_AND_VERIFIED pero `- [ ]` unchecked**
- Defensa: [check-completion-gate.sh](../../../.claude/hooks/check-completion-gate.sh) line 55-62.
- PASS si: exit 1 con mensaje "Completion gate failed for dev_plan.md. Found N unchecked item(s)".

**Adv#6 — Alguien edita `docs/constitution.md` sin regenerar snapshot, intenta Edit sobre otro file**
- Defensa: [check-governance-drift.sh](../../../.claude/hooks/check-governance-drift.sh) line 102-113.
- PASS si: WARNING (non-blocking) emite "Governance snapshot drift detected — constitution.md changed".

**Adv#7 — IPP canary tras resume: escrito de section ya presente en `_progress.completed_sections`**
- Defensa: [Factory-incremental-persistence/SKILL.md](../../../.claude/skills/Factory-incremental-persistence/SKILL.md) Pillar 3 (resume-on-entry).
- PASS si: skip silencioso + warning en logs "section already written".

**Adv#8 — Primer write de `increment_plan.md` con frontmatter _progress.completed_sections populated**
- Defensa esperada: [check-ipp-compliance.sh](../../../.claude/hooks/check-ipp-compliance.sh) line 56-69 allowlist + signal 1 detection.
- **FAIL-framework actual**: el allowlist NO incluye `increment_plan.md` → el hook hace early-exit en línea 80, el primer write masivo NO se bloquea. **GAP G01 BLOCKER**.

### Familia C — Concurrencia y scope

**Adv#9 — Edit sobre main branch**
- Defensa: [check-branch-protection.sh](../../../.claude/hooks/check-branch-protection.sh) line 15.
- PASS si: exit 1 con "BLOCKED: on protected branch 'main'".

**Adv#10 — Dos sesiones tocan `feature/FORM-002-*` concurrentemente**
- Defensa: [check-concurrency-lock.sh](../../../.claude/hooks/check-concurrency-lock.sh) line 38-52.
- PASS si: segunda sesión recibe "BLOCKED: Branch '...' is locked by another session (PID N)".

**Adv#11 — `feature.scope=frontend-only` en `project_scope=backend-only`**
- Defensa: Scope Compatibility Gate en [Factory-codesign-feature.instructions.md](../../../.claude/instructions/Factory-codesign-feature.instructions.md) § Scope Compatibility Gate.
- PASS si: block + RDR "cambia project scope, cambia feature scope, cancela".

### Familia D — Iteración y recovery

**Adv#12 — Intento de INVALIDATE de INC-1 que está en MERGED**
- Defensa: [Factory-iteration-model/SKILL.md](../../../.claude/skills/Factory-iteration-model/SKILL.md) CASCADE_INCREMENT_INTERNAL (MERGED excluido).
- PASS si: skip + cascade a follow-up increment en su lugar.

**Adv#13 — BVL falla 3 attempts consecutivos en el mismo task**
- Defensa: [Factory-build-verification/SKILL.md](../../../.claude/skills/Factory-build-verification/SKILL.md) max_attempts=3 → escalate.
- PASS si: abort `--build`, genera `[FIX-N]` tasks, RDR [refine vs escalate vs skip-test (requires justification)].

### Ramas pendientes

**Adv#14 — Branch `hotfix/critical-bug` para trabajo legítimo**
- Defensa esperada: hook DEBE permitir (CLAUDE.md declara `hotfix/{slug}` válido).
- **FAIL-framework actual**: [check-branch-protection.sh](../../../.claude/hooks/check-branch-protection.sh) line 15 regex `hotfix(/.+)?` BLOQUEA `hotfix/critical-bug`. **GAP G02 HIGH**.

---

## 5. Gap Registry

Cada gap listado con ID, categoría, severidad, fichero afectado, fix propuesto y (tras aplicar) SHA del commit.

| ID | Categoría | Severidad | Fichero | Descripción | Fix aplicado | Status |
|---|---|---|---|---|---|---|
| G01 | BROKEN_GATE | BLOCKER | `.claude/hooks/check-ipp-compliance.sh` | `increment_plan.md` faltaba en case allowlist. Manifest v2.5.0 afirmó haberlo añadido pero solo llegó al template; el meta quedó con drift. | Añadido `*/docs/spec/*/increment_plan.md` al case; orden armonizado lock-step con template. Bump hook meta 1.0.0 → 1.1.0. | [FIXED] |
| G02 | BROKEN_GATE | HIGH | `.claude/hooks/check-branch-protection.sh` + template counterpart | Regex `hotfix(/.+)?` bloqueaba `hotfix/{slug}`, patrón de trabajo válido según CLAUDE.md + INVARIANT 1. | Regex ajustado a `hotfix` (bare) + `release(/.+)?` preservado. Aplicado meta + template. Bumps 1.0.0 → 1.0.1. | [FIXED] |
| G03 | MISSING_TRACKING | HIGH | `.context/templates/setup/governance_versions.json` `framework_core` | `scripts/validate-governance.sh`, `governance-onprompt.sh`, `governance-oncompact.sh`, `auto-tag.sh` no registrados pese a CLAUDE.md §2. | 4 entradas añadidas a framework_core v1.0.0 con changelog backfill EVOL-022. | [FIXED] |
| G04 | DOC_DRIFT | MEDIUM | `.claude/commands/blueprint.md` § Output | Omitía `increment_plan.md`. | Añadido en § Output + IPP principle. Bump 1.0.0 → 1.1.0. | [FIXED] |
| G05 | DOC_DRIFT | MEDIUM | `.claude/commands/implement.md` | No documentaba slicing_strategy, task tagging `[INC-N.*]`, per-increment branching, Increment Plan Gate. | Añadida § Incremental Dev Plan Integration. Bump 1.0.0 → 1.1.0. | [FIXED] |
| G06 | DOC_DRIFT | MEDIUM | `.claude/commands/codesign.md` | No documentaba `feature.scope` enum, Scope Compatibility Gate, `slicing_strategy`. | Añadida § Scope & Slicing. Bump 1.0.0 → 1.1.0. | [FIXED] |
| G07 | DOC_DRIFT | LOW | `CLAUDE.md` + `.context/templates/setup/claude/CLAUDE.md` | "BLOCK if on main/master/develop/release/hotfix" ambiguo vs lista de working patterns. | Aclarado: "Base branches are blocked: main, master, develop, bare hotfix, and any release". INVARIANT 1 meta armonizado con `hotfix/*` → PATCH. Typo `Commcation` restaurado. Bump CLAUDE.md 11.3.0 → 11.4.0, template claude/CLAUDE.md 1.3.1 → 1.4.0. | [FIXED] |

**Gaps totales**: 7 detectados, 7 resueltos (1 BLOCKER, 2 HIGH, 3 MEDIUM, 1 LOW).

### Consolidación adicional (user-driven, no-gap)

Durante el walkthrough el usuario reforzó la regla "framework meta NO auto-construye con su propio SDLC → cambios del framework viven solo en template". Consolidación extra aplicada:

- `§ Project Scope & Feature Scope Taxonomy (EVOL-019 — framework authorship view)` — eliminada de `CLAUDE.md` meta. Contenido de lock-step absorbido en `.context/templates/setup/claude/CLAUDE.md § Project Scope & Feature Scope Taxonomy → ### Framework Editor Invariants (lock-step)` reducido a delta (file paths + warnings).
- `§ Incremental Dev Plan (EVOL-021 — framework authorship view)` — eliminada de `CLAUDE.md` meta. Contenido absorbido análogamente.
- `INVARIANT 5` meta simplificado — nota de scope eliminada; queda solo "feature = EVOL-* branch".
- `Core Protocols` tabla meta — fila RDR simplificada a `(Recommendation → Decision)` con aclaración de que la tercera R (Ratification → IPP artefact) no aplica en este repo.
- Framework version 2.5.0 → 2.6.0 (MINOR, consolidación + gap fixes).

---

## 6. Fix Log

| Gap | Paths editados | Manifest bump | SHA |
|---|---|---|---|
| G01 | `.claude/hooks/check-ipp-compliance.sh` | `framework_core.hooks/check-ipp-compliance.sh` 1.0.0 → 1.1.0 | (this PR) |
| G02 | `.claude/hooks/check-branch-protection.sh` + `.context/templates/setup/claude/hooks/check-branch-protection.sh` | `framework_core.hooks/check-branch-protection.sh` 1.0.0 → 1.0.1 + `templates.claude/hooks/check-branch-protection.sh` 1.0.0 → 1.0.1 | (this PR) |
| G03 | `.context/templates/setup/governance_versions.json` (4 new entries in framework_core) | 4 entries at 1.0.0 (backfill) | (this PR) |
| G04 | `.claude/commands/blueprint.md` | `framework_core.commands/blueprint.md` 1.0.0 → 1.1.0 | (this PR) |
| G05 | `.claude/commands/implement.md` | `framework_core.commands/implement.md` 1.0.0 → 1.1.0 | (this PR) |
| G06 | `.claude/commands/codesign.md` | `framework_core.commands/codesign.md` 1.0.0 → 1.1.0 | (this PR) |
| G07 | `CLAUDE.md` + `.context/templates/setup/claude/CLAUDE.md` | `framework_core.CLAUDE.md` 11.3.0 → 11.4.0 + `templates.claude/CLAUDE.md` 1.3.1 → 1.4.0 | (this PR) |
| Consolidation | Same two CLAUDE.md files | Already counted in G07 bumps above | (this PR) |

`framework_version`: 2.5.0 → 2.6.0 (MINOR).

---

## 7. Checklist "framework sano" (22 ítems)

Cobertura estructural:
- [x] 8 comandos Factory tocados en guion.
- [x] 14 skills tocadas (ver M1).
- [x] 20 instructions referenciadas (ver M2).
- [x] 5 hooks `.sh` + 3 scripts governance activados (ver M5).
- [x] 3 hard gates ejercitados (D.3, E.11, E.13).
- [x] 6 canary gates armados (ver M4, incluyendo 2 [SIMULATED-COMPACT]).

Coherencia de artefactos:
- [ ] Cada artefacto del guion atribuido a una sola skill (pendiente verificación post-fixes).
- [x] `contract.lock` tiene `/blueprint --approve` upstream directo (D.3).
- [x] Worklog append-only en todo el guion.
- [x] RDRs del guion tienen ≥3 opciones + recomendación justificada.

Iteración y cascade:
- [x] Cambio en FORM-001 propaga PENDING_ITERATION a INT-001 (F.3).
- [x] INC-1 MERGED no se invalida (Adv#12, cascade a follow-up).
- [x] Iteration-model distingue version vs iteration (E.10 follow-up vs DELTA/MAJOR).

Ramas negativas:
- [x] 13 escenarios adversos + 1 bonus (Adv#14) narrados con ficheros defensores.
- [x] Cada escenario tiene RDR de recovery o path de escalation.

Saneamiento:
- [x] Todos los comandos existen en `.claude/commands/` (8/8).
- [x] Todas las skills existen en `.claude/skills/` (14/14).
- [x] Todas las instructions existen en `.claude/instructions/` (20/20).
- [x] Todos los hooks existen en `.claude/hooks/` (5/5).
- [x] Los 3 presets (`full-sdlc`, `simplified`, `single`) tocan al menos 1 feature (F1=simplified, F2/F3=full-sdlc; single no se toca en el guion — gap cosmético documentable).
- [x] Los 4 `project_scope` aparecen; las combinaciones con `feature.scope` ejercitadas en F1-F3 cumplen compatibility matrix.
- [ ] Commit-prompt tras cada comando (pendiente validación tras fixes aplicados).

---

## 8. Riesgos metodológicos

- Los hooks NO se ejecutan: auditoría por inspección directa del `.sh`. Para cada Adv#N se cita la línea del hook. Si la línea no existe o no implementa la lógica → gap real.
- Canary gates simulados ([SIMULATED-COMPACT] en E.5, F.3): se verifica el contrato en IPP/CIP SKILL.md, no el runtime.
- Sandbox en memoria: no se materializa Helix en `/tmp`. Compensación: inspección cruzada de `.context/templates/setup/**` y `governance_versions.json` para validar que rutas declaradas existen y placeholders están completos.
- Inventario 100%: cada `.md` / `.sh` citado en este doc existe en filesystem — el inventario de paths en § 0 es exhaustivo contra `find` ejecutado 2026-04-22.

---

## 9. Referencias clave

- [CLAUDE.md](../../../CLAUDE.md) — marco meta-framework
- [.context/templates/setup/claude/CLAUDE.md](../../../.context/templates/setup/claude/CLAUDE.md) — template downstream (lo que ven los proyectos materializados)
- [.context/templates/setup/governance_versions.json](../../../.context/templates/setup/governance_versions.json) — manifest de versiones
- [.claude/settings.json](../../../.claude/settings.json) — wiring de hooks
- Todos los ficheros citados línea-a-línea en Vol III adversarios.
