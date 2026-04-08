# Instrucciones de Uso — mi AI Factory (Claude Code)

Referencia completa para instalar, configurar y operar el sistema SDLC agentic con Claude Code.

---

## 1. Instalación y Requisitos

### Requisitos Previos

| Requisito | Versión Mínima | Notas |
|-----------|---------------|-------|
| **Claude Code** | CLI, VS Code extension, JetBrains extension, o Desktop app | Cualquier interfaz soportada |
| **Modelo LLM** | Claude Opus 4.6 | Requerido para razonamiento complejo del framework |
| **Git** | 2.x | Repositorio inicializado |
| **Shell Bash** | — | Linux / macOS / WSL en Windows |

### Instalación

El framework se activa automáticamente al abrir el repositorio con Claude Code. Claude lee `CLAUDE.md` en la raíz y registra los slash commands desde `.claude/commands/`.

```bash
# 1. Clonar el repositorio
git clone https://github.com/e2its/mi-AI-Factory-for-Claude.git
cd mi-AI-Factory-for-Claude

# 2. Ejecutar Claude Code (CLI)
claude

# 3. O abrir en VS Code / JetBrains con la extensión de Claude Code instalada
#    Claude Code detecta CLAUDE.md automáticamente
```

### Estructura de Archivos del Framework

```
CLAUDE.md                                    # Gobernanza root (cargado SIEMPRE)
.claude/
├── commands/                                # 8 Slash Commands (uno por fase SDLC)
│   ├── audit.md                             # /audit — Due Diligence
│   ├── setup.md                             # /setup — Setup & Governance
│   ├── codesign.md                          # /codesign — Co-Creation (PO↔UX)
│   ├── blueprint.md                         # /blueprint — Technical Design (ARCH↔QA)
│   ├── implement.md                         # /implement — Implementation (DEV↔REVIEW↔SEC)
│   ├── devops.md                            # /devops — Infrastructure & Deployment
│   ├── qa.md                                # /qa — Post-Staging Verification
│   └── backlog.md                           # /backlog — Project Tracking & Issues
├── instructions/                            # 20 instrucciones detalladas (carga contextual)
│   ├── Factory-protocol-smart-redirect.instructions.md
│   ├── Factory-protocol-iop-intent-map.instructions.md
│   ├── Factory-audit-checklist.instructions.md
│   ├── Factory-audit-complexity.instructions.md
│   ├── Factory-setup-discovery.instructions.md
│   ├── Factory-setup-materialization.instructions.md
│   ├── Factory-setup-upgrade.instructions.md
│   ├── Factory-codesign-vision.instructions.md
│   ├── Factory-codesign-feature.instructions.md
│   ├── Factory-blueprint-design.instructions.md
│   ├── Factory-blueprint-validation.instructions.md
│   ├── Factory-implement-plan.instructions.md
│   ├── Factory-implement-build.instructions.md
│   ├── Factory-implement-review-checks.instructions.md
│   ├── Factory-devops-configure.instructions.md
│   ├── Factory-devops-provision-deploy.instructions.md
│   ├── Factory-qa-verify.instructions.md
│   ├── Factory-backlog-operations.instructions.md
│   ├── Factory-backlog-execution-plan.instructions.md
│   └── Factory-backlog-next-task.instructions.md
├── skills/                                  # 12 cross-cutting skills (protocolos reutilizables)
│   ├── Factory-build-verification/          # BVL — test execution + auto-fix loop
│   ├── Factory-incremental-persistence/     # IPP — persistencia incremental
│   ├── Factory-codebase-inventory/          # CIP — inventario DRY
│   ├── Factory-governance-loading/          # Zero Trust context recovery
│   ├── Factory-iteration-model/             # Cascading invalidation
│   ├── Factory-branching-strategy/          # SCM — branch enforcement
│   ├── Factory-agent-communication/         # ACP — verbosidad controlada
│   ├── Factory-commit-prompt/               # Commit convencional auto-generado
│   ├── Factory-worklog/                     # Audit trail JSONL per-feature
│   ├── Factory-memory-cache/                # MCP — capa de aceleración /memories/repo/
│   ├── Factory-coherence-validation/        # CVP — cross-artifact validation
│   └── Factory-backlog-next-task/           # Next-Task Resolver con cache fast path
└── settings.json                            # Configuración de permisos
.context/
└── templates/                               # Templates de materialización (SETUP --generate)
```

### Verificación Post-Instalación

1. Abrir Claude Code (CLI: `claude`, o vía extensión IDE)
2. Escribir `/` — deben aparecer los 8 comandos del framework (audit, setup, codesign, blueprint, implement, devops, qa, backlog)
3. Escribir `/setup --init` para iniciar un proyecto nuevo
4. Claude lee `CLAUDE.md` automáticamente en cada conversación (contiene gobernanza cross-cutting)

---

## 2. Arquitectura del Sistema

### Modelo Single Agent + Slash Commands

```
                    ┌─────────────────┐
        Usuario ───►│   Claude Code   │◄─── CLAUDE.md (siempre cargado)
                    │  (single agent) │
                    └──────┬──────────┘
                           │ slash commands (/command --args)
            ┌──────┬───────┼───────┬──────┬───────┬──────┬─────────┐
            ▼      ▼       ▼       ▼      ▼       ▼      ▼         ▼
         /audit  /setup /codesign /blueprint /implement /devops /qa /backlog
        (cada comando carga sus instrucciones y skills al ejecutarse)
```

- **Claude Code** es un agente único que asume diferentes roles según el slash command invocado
- Cada slash command define la personalidad, protocolos y reglas del rol correspondiente
- Las instrucciones detalladas en `.claude/instructions/` se cargan contextualmente por cada comando
- Los skills en `.claude/skills/` son protocolos cross-cutting reutilizables por todos los comandos
- `CLAUDE.md` se carga en TODAS las conversaciones (contiene gobernanza cross-cutting)

### Cómo Interactuar

Invocar comandos directamente como slash commands:

```
/codesign --start USR-001 "Login con OAuth"
/blueprint --start USR-001
/implement --build USR-001
```

O usar lenguaje natural — Claude identifica el intent y ejecuta el comando apropiado:
```
"quiero crear una feature de login con OAuth"
→ Claude ejecuta: /codesign --start {ID} "login con OAuth"
```

### Bucle de Persistencia

Los comandos **no fallan silenciosamente** — pausan y persisten estado:

1. Claude encuentra ambigüedad → Guarda artefacto con `status: NEEDS_INFO`
2. Lista preguntas específicas en el frontmatter del artefacto
3. Espera refinamiento del usuario → Usar `--refine` para responder
4. Resume ejecución desde el checkpoint guardado

---

## 3. Secuencia del Workflow (v8.2.0)

```
SETUP (one-time) → CODESIGN (PO↔UX, auto-approves 12/12) → BLUEPRINT (ARCH↔QA, --approve required) → IMPLEMENT (DEV↔REVIEW↔SEC + BVL) → DEVOPS (deploy pre-prod) → QA (verify, auto-approves) → MERGE (PR → main) → DEVOPS (deploy prod)
                                                              ↕
                                                DEVOPS (configure auto-approves/provision)
                                          puede ejecutarse en cualquier momento post-BLUEPRINT
```

**AUDIT** es independiente — puede ejecutarse en CUALQUIER momento. NUNCA bloquea el workflow principal.

**BACKLOG** es independiente — puede ejecutarse en CUALQUIER momento post-SETUP. Gestiona el tablero de proyecto, issues y tracking.

> **Auto-Aprobación (v8.2.0):** CODESIGN, DEVOPS `--configure` y QA `--verify` auto-aprueban cuando todas las validaciones pasan. BLUEPRINT `--approve` es el único checkpoint manual obligatorio.

> **Entornos Dinámicos:** Los entornos se leen de `docs/rules/ci-cd.md` `environments[]`. Un proyecto puede tener `dev → prod` o `dev → staging → UAT → prod`. El invariante: **MERGE siempre ocurre ANTES del deploy a producción**.

---

## 4. Referencia de Comandos

> Ejecutar en Claude Code: `/command --args` o describir en lenguaje natural.

### Pre-0. AUDIT (Technical Due Diligence) — Opcional

Rol: Auditor Técnico Senior. Evalúa el estado actual de un proyecto existente antes de iniciar gobernanza. Independiente del workflow principal.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `/audit --audit` | — | Auditoría técnica completa. Protocolo Scan-First. Master Checklist: Fase 0 (Idioma), Fase A (Governance/HR), Fase B (Arquitectura/Software), Fase C (Infraestructura), Fase D (Seguridad). Persistencia atómica: una sección por turno. Resumible via `status: NEEDS_INFO`. |
| `/audit --refine {SECTION_ID}` | ID de sección (P0, G1-G3, S1-S4, I1-I4, SEC1-SEC5) | Refinamiento de sección específica. |
| `/audit --approve` | — | Cierre de auditoría con veredicto `GO` / `NO_GO` / `GO_WITH_CONDITIONS`. |

Artefacto: `docs/technical_due.md`

### 0. SETUP (Setup & Governance)

Rol: Arquitecto/Gobernanza. Define constitución, reglas y scaffolding inicial.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `/setup --init` | — | Discovery con AI Budget + Brownfield auto-detection. Planning con 12 topologías backend, 10 patrones frontend. Execution con validación presupuesto. |
| `/setup --generate` | — | Solo con `phase: COMPLETED`. Materializa scaffolding tripartito (Backend/Frontend/Integration ACL). Incluye IaC Foundation Scaffolding. Crea MATERIALIZATION_REPORT.md con checklist de 60-80 tareas. |
| `/setup --generate --resume` | — | Continúa materialización interrumpida. Requiere MATERIALIZATION_REPORT.md. Lee checklist y continúa desde última tarea pendiente. |
| `/setup --migrate-legacy-setup` 🧪 | — | **EXPERIMENTAL.** Auto-migra setup.md antiguo a formato tripartito. Requiere score >85%. |
| `/setup --upgrade` | — | Actualiza artefactos de gobernanza a última versión del framework. 6 capas de seguridad. Smart Additive Merge. |
| `/setup --rollback-upgrade {TIMESTAMP}` | Timestamp de backup | Recupera el proyecto de un upgrade fallido. |

Artefactos: `docs/setup.md`, `docs/constitution.md`, `docs/rules/*`, `MATERIALIZATION_REPORT.md`

### 1. CODESIGN (Co-Creation: PO ↔ UX)

Rol: Doble personalidad (🎩 PO hat ↔ 🎨 UX hat). Co-crea especificación funcional, mockup visual y user journey.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `/codesign --vision` | — | Genera la visión global UX. Obligatorio para proyectos con frontend. 7 fases. |
| `/codesign --vision-refine "[FEEDBACK]"` | Feedback | Refinamiento de la visión global. |
| `/codesign --vision-approve` | — | Aprobación conjunta PO+UX de la visión global. |
| `/codesign --vision-propagate` | — | Propaga cambios de visión a mocks existentes. |
| `/codesign --start {ID}` | Feature ID | Inicia co-creación. Vision Gate para features con UI. Event Storming → spec ↔ mock ↔ journey hasta convergencia. Auto-aprueba si 12/12 validaciones pasan. |
| `/codesign --refine {ID} "[FEEDBACK]"` | Feedback | Refinamiento iterativo. Clasifica cambios DELTA/BREAKING. Auto-aprueba si 12/12 validaciones pasan. |

Artefactos per-feature: `docs/spec/{ID}/spec.feature`, `mock.html`, `user_journey.md`
Artefactos global vision: `docs/ux/vision/vision.md`, `app_shell.html`, `style_guide.html`, `page_templates.html`, `component_library.html`, `navigation_map.md`

### 2. BLUEPRINT (Co-Design: ARCH ↔ QA)

Rol: Doble personalidad (🏗️ ARCH hat ↔ 🧪 QA hat). Co-diseña arquitectura y estrategia de tests simultáneamente.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `/blueprint --start {ID}` | — | Co-diseña design.md + test_plan.md. Requiere CODESIGN APPROVED. Genera C4, contratos, Section 5: Infrastructure Needs. |
| `/blueprint --refine {ID} "[FEEDBACK]"` | Feedback | Refinamiento iterativo de diseño y/o tests. |
| `/blueprint --approve {ID}` | — | Aprobación conjunta ARCH+QA. Habilita IMPLEMENT. |
| `/blueprint --adr {ID} "[TITLE]" "[DECISION]"` | Título y decisión | Genera ADR standalone. |
| `/blueprint --review-conflict {ID}` | — | Arbitraje cuando peer review rechaza 3+ veces. |

Artefactos: `docs/spec/{ID}/design.md`, `test_plan.md`, contratos en `contracts/`

### 3. IMPLEMENT (Implementation: DEV ↔ REVIEW ↔ SEC)

Rol: Triple personalidad (💻 DEV ↔ 🔍 REVIEW ↔ 🛡️ SEC). Planifica + implementa + verifica + asegura por fases.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `/implement --plan {ID}` | — | Genera checklist de implementación (`dev_plan.md`) con tareas `- [ ] [A/B/C.N]`. Requiere BLUEPRINT APPROVED. |
| `/implement --refine {ID} "[FEEDBACK]"` | Feedback | Refinamiento del plan. Standard Refine genera tareas `[ADJ-N]`, Delta Iteration (v9.0.0) genera tareas `[D.N]`. |
| `/implement --build {ID}` | — | Implementación por fases: 💻 DEV (TDD + BVL) → 🔍 REVIEW → 🛡️ SEC (SAST). Build Verification Loop: ejecuta tests en terminal, parsea errores, auto-corrige (max 3 intentos). Full Verification Gate (tests + lint + typecheck + build) antes de `IMPLEMENTED_AND_VERIFIED`. Completion Gate: todas las tareas deben ser `[x]` o `@skip` con justificación. |
| `/implement --fix {ID} "[AYUDA]"` | Ayuda | Genera tareas `[FIX-N]` a partir de QA rejection o bloqueos. Ejecuta fix → marca `[x]`. |

Artefactos: `docs/spec/{ID}/dev_plan.md`, código fuente, `peer_review_{ts}.md`, `sec_audit.md`, Draft PR

### 4. DEVOPS (DevOps & Infrastructure)

Rol: SRE y Platform Engineer. Gestión de infraestructura, CI/CD y entornos.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `/devops --configure {ID}` | — | Genera plan de infraestructura (proceso guiado RDR). Auto-aprueba si 7/7 checks pasan. |
| `/devops --refine {ID} "{FEEDBACK}"` | Feedback técnico | Ajusta plan basado en feedback. |
| `/devops --provision [{ID}] --env {ENV}` | Environment | Materializa infraestructura. Con ID → feature-scoped. Sin ID → env-scoped. |
| `/devops --deploy [{ID}] --env {ENV}` | Environment | Despliega código. Requiere IMPLEMENT completado. Prod requiere MERGE + QA APPROVED. |
| `/devops --suspend [{ID}] --env {ENV}` | Environment | Suspende entorno para reducir costos. |
| `/devops --resume [{ID}] --env {ENV}` | Environment | Reanuda entorno suspendido. |
| `/devops --rollback [{ID}] --env {ENV}` | Environment | Revierte deployment. |
| `/devops --teardown [{ID}] --env {ENV}` | Environment | Destruye infraestructura. `data_bearing: true` requiere backup. |
| `/devops --status [{ID}]` | — | Dashboard de estado. |

Artefactos: `docs/spec/{ID}/devops_plan.md`, `infra/features/{ID}/` (IaC), `deployment_report_{ts}.md`

**Guardrails de Ejecución:**
- **G0** Governance Load | **G1** Stack Coherence | **G2** Cost (>20% warn, >50% block)
- **G3** Secrets (prohibido hardcodear) | **G4** HA (features CRITICAL → multi-AZ)
- **G5** Environments (de governance, no hardcodeados) | **G6** Data Protection (backup antes de teardown)

### 5. QA (Quality Assurance — Post-Staging)

Rol: Certificación final post-code y verificación en entorno desplegado (incluye DAST via 🛡️ SEC hat).

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `/qa --verify {ID}` | — | Checkbox-driven: genera checklist `- [ ]` (`[QA-PRE-*]`, `[QA-GOV-*]`, `[QA-TC-*]`, `[QA-REG-*]`, `[QA-DAST-*]`), marca `[x]` al ejecutar. Auto-aprueba si ALL `[x]` AND veredicto APPROVED. Requiere entorno desplegado. |
| `/qa --reject {ID} "[MOTIVO]"` | Motivo | Genera items de remediación `[FIX-N]` → `/implement --fix`. |
| `/qa --e2e {ID}` | — | Ejecuta pruebas E2E. |

Artefactos: `docs/spec/{ID}/qa/qa_report_final_{ts}.md` (incluye Verification Checklist)

> **Nota:** La planificación de tests fue absorbida por BLUEPRINT (🧪 QA hat). QA se enfoca en verificación post-staging.

### 6. BACKLOG (Project Tracking & Issue Management) — Independiente

Rol: Gestor operativo del tablero de proyecto. Crea issues, organiza el Kanban y trackea features. Independiente del workflow principal (como AUDIT).

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `/backlog --init-board` | — | Inicializa el backlog. Modo externo: crea proyecto en herramienta externa + `project-config.json`. Modo local: crea `state.md` con tabla Kanban. |
| `/backlog --plan-feature {ID} "{name}"` | Feature ID + nombre | Crea el set de issues para una feature (fases configuradas en SETUP). Modo externo: vía API. Modo local: entries en `state.md` + body files. |
| `/backlog --create-issue "{title}"` | Título | Crea un issue custom individual. Modo externo: vía API. Modo local: entry en `state.md` + body file. |
| `/backlog --move {ISSUE_NUMS} --to {STATUS}` | Issues + columna destino | Mueve issues entre columnas del Kanban. Modo externo: API. Modo local: actualiza `state.md`. |
| `/backlog --status` | — | Muestra resumen del tablero con conteo de issues por columna. |
| `/backlog --plan-execution` | — | Analiza dependencias entre features, forma Epics por Bounded Context compartido y genera un plan de ejecución ordenado que minimiza retrabajo. Escribe `docs/backlog/execution-plan.md` + cache en `/memories/repo/`. |
| `/backlog --update-execution {step}` | Paso completado | Marca un paso del plan como completado, avanza el estado del epic y refresca el cache. |
| `/backlog --sync-execution` | — | Reconcilia el plan de ejecución con el estado actual del tablero. Detecta drift y lo corrige. |

Prerequisito: `docs/setup.md` con sección `project_tracking` (configurado durante `/setup --init` Q27).

Modo SSOT: Si `project_tracking.tool != "None"` → modo externo (la herramienta externa es la única fuente de verdad, sin `state.md` ni `issue-bodies/` locales). Si `project_tracking.tool == "None"` → modo local (`state.md` + `issue-bodies/` son la única fuente de verdad).

Artefactos (modo externo): `docs/backlog/project-config.json` (solo identificadores de conexión no sensibles y mapeo de campos — sin registro de issues, sin tokens).
Artefactos (modo local): `docs/backlog/state.md`, `docs/backlog/issue-bodies/*.md` (sin `project-config.json`).
Artefactos (plan de ejecución): `docs/backlog/execution-plan.md` (ordenación por Epics). Cache: `/memories/repo/execution-plan-cache.md`.

---

## 5. Pipeline Recomendado

### Fase Pre-0 (Opcional): Due Diligence Técnica

```
/audit --audit       → Escaneo + auditoría por secciones
/audit --approve     → Veredicto GO / NO_GO / GO_WITH_CONDITIONS
```

Si se ejecuta AUDIT, SETUP auto-detecta Brownfield y pre-llena datos.

### Fase 0: Setup (Gobierno y Estructura)

```
/setup --init        → Discovery → Planning → Execution (interactivo)
/setup --generate    → Materializa scaffolding, constitución, reglas
```

### Fase 0.1 (Opcional): Iniciar Proyecto y Backlog

```
/backlog --init-board                              → Crea proyecto en herramienta configurada (o local)
/backlog --plan-feature USR-001 "Login con OAuth"  → Issues por feature
/backlog --plan-feature USR-002 "Dashboard"        → Issues por feature
/backlog --plan-execution                          → Analiza dependencias → genera plan de ejecución por Epics
```

### Fase 0.5: Global Vision (Obligatorio para proyectos con frontend)

```
/codesign --vision           → Genera identidad visual global
/codesign --vision-approve   → Aprueba visión
```

### Fase 1: Definición y Co-Creación (Pre-Code)

```
/codesign --start USR-001 "Login con OAuth"   → Co-crea spec + mock + journey (auto-aprueba si 12/12 OK)

/blueprint --start USR-001    → Co-diseña design.md + test_plan.md
/blueprint --approve USR-001  → Habilita IMPLEMENT (único checkpoint manual obligatorio)
```

### Fase 2: Implementación (Code)

```
/implement --plan USR-001    → Genera checklist (dev_plan.md)
/implement --build USR-001   → TDD + BVL (ejecución real) + Review + SAST por fase
```

### Fase 2.5: Infraestructura (Flexible — post-BLUEPRINT)

```
/devops --configure USR-001              → Plan de infra (auto-aprueba si 7/7 OK)
/devops --provision USR-001 --env dev    → Materializa infraestructura
```

### Fase 3: Certificación (Post-Code)

```
/devops --deploy USR-001 --env staging   → Deploy a pre-producción
/qa --verify USR-001                     → Tests + DAST (auto-aprueba si veredicto APPROVED)
```

### Fase 4: Merge y Producción

```
git push origin feature/USR-001-login-oauth      → Push a remote
# Crear PR → CI checks → approval → merge to main + tag

/devops --deploy USR-001 --env prod       → Deploy desde main/tag
```

---

## 6. Diagrama de Flujo Completo

```mermaid
graph TD
    Start([Usuario: Nueva Feature]) --> TddCheck{Due Diligence?}
    TddCheck -->|Sí, opcional| TddAudit[/audit --audit]
    TddAudit --> TddNeedsInfo{status: NEEDS_INFO?}
    TddNeedsInfo -->|Sí| TddRefine[/audit --refine SECTION]
    TddRefine --> TddAudit
    TddNeedsInfo -->|No| TddApprove[/audit --approve]
    TddApprove --> TddVerdict{Veredicto?}
    TddVerdict -->|GO / GO_WITH_CONDITIONS| Setup
    TddVerdict -->|NO_GO| NoGo([Proyecto No Viable])
    TddCheck -->|No| Setup{Setup Completado?}
    
    Setup -->|No| SetupInit[/setup --init]
    SetupInit --> SetupGen[/setup --generate]
    SetupGen --> VisionCheck{Frontend?}
    Setup -->|Sí| VisionCheck
    
    VisionCheck -->|Sí| CodesignVision[/codesign --vision]
    CodesignVision --> CodesignVisionApprove[/codesign --vision-approve]
    CodesignVisionApprove --> CodesignStart[/codesign --start ID]
    VisionCheck -->|No frontend| CodesignStart
    
    CodesignStart --> CodesignNeedsInfo{status: NEEDS_INFO?}
    CodesignNeedsInfo -->|Sí| CodesignRefine[/codesign --refine ID FEEDBACK]
    CodesignRefine --> CodesignStart
    CodesignNeedsInfo -->|No| CodesignAutoApprove{12/12 validaciones?}
    CodesignAutoApprove -->|Sí auto-approve 12/12| BlueprintStart[/blueprint --start ID]
    CodesignAutoApprove -->|No| CodesignFix[Corregir y re-refine]
    CodesignFix --> CodesignStart
    
    BlueprintStart --> BlueprintNeedsInfo{status: NEEDS_INFO?}
    BlueprintNeedsInfo -->|Sí| BlueprintRefine[/blueprint --refine ID FEEDBACK]
    BlueprintRefine --> BlueprintStart
    BlueprintNeedsInfo -->|No| BlueprintApprove[/blueprint --approve ID]
    
    BlueprintApprove --> ImplPlan[/implement --plan ID]
    ImplPlan --> ImplNeedsInfo{status: NEEDS_INFO?}
    ImplNeedsInfo -->|Sí| ImplRefine[/implement --refine ID FEEDBACK]
    ImplRefine --> ImplPlan
    ImplNeedsInfo -->|No| ImplBuild[/implement --build ID]
    
    ImplBuild --> ImplBlocked{status: BLOCKED?}
    ImplBlocked -->|Sí| ImplFix[/implement --fix ID AYUDA]
    ImplFix --> ImplBuild
    ImplBlocked -->|No| ImplDone{Build Complete?}
    ImplDone -->|No| ImplBuild
    ImplDone -->|Sí| DevOpsDeploy[/devops --deploy ID --env PRE_PROD]
    
    DevOpsDeploy --> QaVerify[/qa --verify ID]
    QaVerify --> QaPass{Tests OK?}
    QaPass -->|No| QaReject[/qa --reject ID MOTIVO]
    QaReject --> ImplFix2[/implement --fix ID]
    ImplFix2 --> ImplBuild
    QaPass -->|Sí auto-approve| MergePR[MERGE: PR → main + tag]
    MergePR --> DeployProd[/devops --deploy ID --env PROD]
    DeployProd --> End([Feature Completa])
    
    classDef checkpoint fill:#2ecc71,stroke:#27ae60,stroke-width:3px,color:#fff
    classDef needsInfo fill:#f39c12,stroke:#e67e22,stroke-width:2px,color:#fff
    classDef blocked fill:#e74c3c,stroke:#c0392b,stroke-width:2px,color:#fff
    
    class BlueprintApprove,ImplDone checkpoint
    class CodesignNeedsInfo,BlueprintNeedsInfo,ImplNeedsInfo,TddNeedsInfo needsInfo
    class ImplBlocked,NoGo blocked
```

---

## 7. Rutas de Excepción y Resolución

| Escenario | Estado Persistido | Comando de Recuperación |
|-----------|-------------------|------------------------|
| AUDIT sin evidencias para una sección | `technical_due.md → NEEDS_INFO` | `/audit --refine SECTION_ID "Datos..."` |
| AUDIT veredicto NO GO | `technical_due.md → APPROVED, verdict: NO_GO` | Revisar hallazgos con stakeholders |
| Spec ambigua | `spec.feature → NEEDS_INFO` | `/codesign --refine ID "Aclaraciones..."` |
| Architecture mapping faltante | `design.md → NEEDS_INFO` | `/blueprint --refine ID "Definir APIs..."` |
| Modificación RED ZONE | `design.md → BLOCKED` | `/blueprint --refine ID "ADR: Justificación..."` |
| Implementación bloqueada | `dev_plan.md → tarea BLOCKED` | `/implement --fix ID "Pista técnica..."` |
| Test falla 3 veces (3-Strike Rule) | `dev_plan.md → NEEDS_DECISION` | Bucle Recomendación/Decisión: reintentar, modificar, escalar |
| Vulnerabilidades SAST | `sec_audit.md → VULNERABLE` | Fix loop inline en `/implement --build` |
| Vulnerabilidades DAST | `qa_report.md → VULNERABLE` | Remediar → `/qa --verify ID` |
| Config hardcodeada | `qa_report.md → VULNERABLE` | Corregir → `/qa --verify ID` |
| Drift violation | `qa_report.md → BLOCKED` | `/blueprint --refine ID` o corregir y re-run |

---

## 8. Matrices de Transición de Estados

### `spec.feature` (CODESIGN)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `/codesign --start ID` | `DRAFT` o `NEEDS_INFO` |
| `NEEDS_INFO` | `/codesign --refine ID` | `DRAFT` o `NEEDS_INFO` |
| `DRAFT` | (auto-approve 12/12 OK) | `APPROVED` |
| `APPROVED` | `/codesign --refine ID` | `DRAFT` (nueva iteración) |

### `design.md` + `test_plan.md` (BLUEPRINT)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `/blueprint --start ID` | `DRAFT` o `NEEDS_INFO` |
| `NEEDS_INFO` | `/blueprint --refine ID` | `DRAFT` o `BLOCKED` |
| `DRAFT` | `/blueprint --approve ID` | `APPROVED` |
| `APPROVED` | `/blueprint --refine ID` | `DRAFT` (requiere ADR si RED ZONE) |

### `dev_plan.md` (IMPLEMENT)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `/implement --plan ID` | `DRAFT` o `NEEDS_INFO` |
| `NEEDS_INFO` | `/implement --refine ID` | `READY` |
| `READY` | `/implement --build ID` | `BUILDING` |
| `BUILDING` | `/implement --build ID` | `BUILDING` o `IMPLEMENTED_AND_VERIFIED` |
| `BUILDING` | (test falla 3×) | `NEEDS_DECISION` |
| `BUILDING` | `/implement --fix ID` | `BUILDING` |
| `IMPLEMENTED_AND_VERIFIED` | `/implement --refine ID` | `READY` (delta_mode) |
| `IMPLEMENTED_AND_VERIFIED` | `/implement --fix ID` | `BUILDING` (fix cycle) |

### `qa_report_{ts}.md` (QA)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `/qa --verify ID` | `APPROVED` (auto) o `REJECTED` |
| `REJECTED` | `/implement --fix ID` completes | `INVALIDATED` |
| `INVALIDATED` | `/qa --verify ID` | `APPROVED` (auto) o `REJECTED` |
| `APPROVED` | — | Terminal (habilita MERGE) |

### `technical_due.md` (AUDIT)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `/audit --audit` | `NEEDS_INFO` |
| `NEEDS_INFO` | `/audit --audit` | `NEEDS_INFO` o `DRAFT` |
| `DRAFT` | `/audit --approve` | `APPROVED` |
| `APPROVED` | `/audit --refine SECTION` | `DRAFT` (requiere re-aprobación) |

> Estado `CANCELLED` es terminal en todos los artefactos — bloquea cualquier operación.

---

## 9. Glosario de Estados (Frontmatter)

### Estados generales de artefactos

| Estado | Significado |
| --- | --- |
| `DRAFT` | Borrador completo, esperando revisión o auto-aprobación. |
| `NEEDS_INFO` | Agente pausado, requiere `--refine` del usuario. |
| `APPROVED` | Documento congelado y validado. Habilita siguiente fase. |
| `REJECTED` | (QA) Verificación rechazada. Requiere `/implement --fix`. |
| `COMPLETED` | Proceso o fase finalizado con éxito. |
| `BLOCKED` | Tarea imposible sin ayuda externa. |
| `CANCELLED` | Feature cancelada. Estado terminal. |
| `DEPRECATED` | Feature reemplazada por nueva versión. Preservada para audit trail. |
| `SUPERSEDED` | (ADR) Decisión arquitectónica reemplazada por ADR posterior. |
| `CASCADE_PENDING_ITERATION` | Artefacto downstream invalidado por cambio upstream. Requiere `--refine`. |

### Estados de IMPLEMENT (dev_plan.md)

| Estado | Significado |
| --- | --- |
| `READY` | Plan listo para `--build`. |
| `BUILDING` | Implementación en progreso — TDD + Review + SAST por fase. |
| `IMPLEMENTED_AND_VERIFIED` | Código completado; habilita DEVOPS deploy y QA verify. |
| `VULNERABLE` | (SEC) Bloqueo por fallos de seguridad activos. |
| `SKIPPED` | Tarea temporalmente omitida (debe resolverse antes de completar build). |

### Estados de DEVOPS (environments)

| Estado | Significado |
| --- | --- |
| `NOT_PROVISIONED` | Entorno definido pero no provisionado aún. |
| `ACTIVE` | Entorno provisionado y operativo. |
| `SUSPENDED` | Entorno pausado. Requiere `--resume`. |
| `DESTROYED` | Entorno destruido (`--teardown` completado). |

### Estados de QA (reports)

| Estado | Significado |
| --- | --- |
| `INVALIDATED` | Report invalidado por cambios upstream. |

### Estados de CIP (inventory artifacts)

| Estado | Significado |
| --- | --- |
| `PLANNED` | Artefacto registrado en inventario, aún no implementado. |
| `IMPLEMENTED` | Artefacto del inventario ya existe en código. |

### Estados de AUDIT (due diligence)

| Estado | Significado |
| --- | --- |
| `GO` | Veredicto positivo. Proyecto viable. |
| `GO_WITH_CONDITIONS` | Viable con condiciones/mitigaciones requeridas. |
| `NO_GO` | No viable. Riesgos inaceptables. |

---

## 10. Sistema de Gobernanza Dinámica

### Governance Index (`docs/constitution.md`)

Registro central auto-generado durante `/setup --generate`:
- Contiene metadata por regla: type, validation_method, severity, agents aplicables
- Governance snapshot: `.context/governance_snapshot.md` — file-based cache, summarization-safe (see `Factory-governance-loading/SKILL.md`)
- Verification commands: auto-derivados del stack config para BVL (test, lint, typecheck, build)

### Protocolos Cross-Cutting (Skills)

El framework incluye 12 protocolos inteligentes reutilizables por todos los comandos:

| Protocolo | Versión | Objetivo |
|-----------|---------|----------|
| **Build Verification Loop (BVL)** | v1.0.0 | Ejecución real de tests en terminal, parseo de errores, auto-fix (max 3 intentos), Full Verification Gate (tests + lint + typecheck + build). Usa BVL Commands Cache (`/memories/repo/`) |
| **Incremental Persistence (IPP)** | v1.0.1 | Skeleton-first write, section-atomic saves, resume-on-entry. Sobrevive a context summarization |
| **Codebase Inventory (CIP)** | v1.2.0 | Inventario DRY cross-command. CIP Canary gate previene duplicación post-summarization. Usa Inventory Cache (`/memories/repo/`) |
| **Governance Loading (GCRP)** | v2.2.0 | Zero Trust context recovery. Dual-hash snapshot (constitution + setup). Summarization-safe |
| **Iteration Model** | v2.0.0 | Domain-driven incremental dev. Cascading invalidation automático al cambiar specs upstream |
| **Branching Strategy (SCM)** | v1.0.1 | Branch enforcement, merge policy, concurrency locks, auto-checkout protocol |
| **Agent Communication (ACP)** | v2.0.0 | Verbosidad controlada: entry announcement, phase milestones, completion summary |
| **Commit Prompt** | v1.0.0 | Commit convencional auto-generado post-comando |
| **Worklog** | v1.0.0 | Audit trail JSONL per-feature. Action registration, phase mapping |
| **Memory Cache Protocol (MCP)** | v1.0.0 | Capa de aceleración unificada via `/memories/repo/`. Caches para: Feature State, BVL Commands, CIP Inventory, Execution Plan |
| **Coherence Validation (CVP)** | v1.0.0 | Cross-artifact traceability and completeness validation |
| **Backlog Next-Task Resolver** | v1.1.0 | Determina el siguiente paso ejecutable desde el plan de ejecución. Fast path via cache en `/memories/repo/` |

### Categorías de Reglas

**Críticas (todos los proyectos):** `architecture.md`, `stateless.md`, `security_policy.md`, `protected-code.md`, `contract-first-policy.md`, `testing.md`
- +`ux-constitution.md` (si UI), +`database.md` (si BD), +`api-standards.md` (si APIs)

**Tech-Specific (solo si stack coincide):** `python.md`, `React.md`, `java.md`, `node.md`, `csharp.md`

**Filosofía**: Si el archivo de regla existe en `docs/rules/` → aplica a TODAS las features (project-level, no feature-level).

### Validación Híbrida

| Tipo | Qué Valida | Ejemplo |
|------|-----------|---------|
| **Semántica (LLM)** | Patrones de código, violaciones arquitectónicas | `pickle.loads()`, `eval()`, `dangerouslySetInnerHTML`, SQL injection, rutas absolutas |
| **Script (Determinística)** | Dependencias, configuración, secrets | `dependency-allowlist.sh`, `check-integrations.sh`, `security-scan.sh` |

### Checkpoints de Validación Obligatorios

| Checkpoint | Qué Se Valida |
|-----------|--------------|
| `/blueprint --approve` | Contratos, UX compliance, protected code, system resources |
| `/implement --build` (REVIEW) | Patrones de seguridad, arquitectura, accesibilidad, protected paths |
| `/implement --build` (SEC) | SAST patterns, secrets, vulnerabilidades |
| `/qa --verify` | dependency-allowlist (BLOCKING), integration config, DAST |

### Modelo Tolerancia Cero

- **GREEN ZONES (Código Nuevo):** CRITICAL/HIGH violations → BLOCK inmediatamente con reporte YAML
- **RED ZONES (Código Legacy):** Sin validación (exempt). Modificaciones requieren ADR approval

---

## 11. Arquitectura de Caché en Memoria (MCP v1.0.0)

El framework utiliza `/memories/repo/` como capa de aceleración para eliminar lecturas redundantes de archivos entre comandos. Los archivos en disco siguen siendo la fuente de verdad (SSOT).

### Caches Activos

| Cache | Ubicación | Fuente (SSOT) | Usado Por | Invalidación |
|-------|-----------|---------------|-----------|--------------|
| **Feature State** | `/memories/repo/feature-state-cache.md` | `docs/spec/*/` frontmatters | Smart Redirect | Cambio de status en cualquier artefacto |
| **BVL Commands** | `/memories/repo/bvl-commands-cache.md` | `.context/governance_snapshot.md` | `/implement --build`, `--fix` | Cambio en governance snapshot |
| **CIP Inventory** | `/memories/repo/codebase-inventory-cache.md` | `config/codebase_inventory.json` | `/blueprint`, `/implement`, `/codesign` | Modificación del inventario |
| **Execution Plan** | `/memories/repo/execution-plan-cache.md` | `docs/backlog/execution-plan.md` | Next-Task Resolver | `--plan-execution`, `--update-execution`, `--sync-execution` |

### Principios de Diseño

1. **SSOT en disco** — Los artefactos en disco son SIEMPRE la fuente autoritativa. Los caches son aceleradores, nunca fuentes primarias.
2. **Write-Through** — Cuando un comando modifica un artefacto fuente, actualiza el cache correspondiente inmediatamente.
3. **Validación por Hash** — Cada cache almacena el hash de su fuente. Se valida al leer; si es stale → se regenera desde la fuente.
4. **Degradación Graceful** — Si un cache falla, se cae al path lento (lectura directa). NUNCA se bloquea un comando por fallo de cache.
5. **Sin dependencias cruzadas** — Los caches leen de fuentes, NUNCA de otros caches.

Ver skill `Factory-memory-cache/SKILL.md` para el protocolo completo.

---

## 12. Inmutabilidad y Versionado

Una vez que los artifacts son **APPROVED** con downstream work APPROVED, se vuelven **inmutables**.

### Solución: Versionado Automático

```
Original:     USR-001
Revisión 1:   USR-001-v2
Revisión 2:   USR-001-v3
Hotfix:       USR-001-v2.1 (solo emergencias de seguridad)
```

### Comando: `/codesign --revise`

```
/codesign --revise USR-001 "Agregar autenticación OAuth"
```

- Crea `docs/spec/USR-001-v2/` con parent links
- Marca `USR-001` como `APPROVED (SUPERSEDED)`
- Herencia de artifacts downstream (test_plan, design) disponible
- Máximo 1 versión activa (linearidad forzada)

Ver `docs/rules/immutability_policy.md` para reglas completas.
