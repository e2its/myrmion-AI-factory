# Instrucciones de Uso — mi AI Factory (Custom Agents)

Referencia completa para instalar, configurar y operar el sistema de agentes SDLC.

---

## 1. Instalación y Requisitos

### Requisitos Previos

| Requisito | Versión Mínima | Notas |
|-----------|---------------|-------|
| **VS Code** | 1.99+ | Con GitHub Copilot habilitado |
| **GitHub Copilot** | Extensión activa | Plan Business, Enterprise o suscripción individual |
| **Modelo LLM** | Claude Opus 4.5+ | Configurado como preferencia (ver abajo) |
| **Git** | 2.x | Repositorio inicializado |
| **Shell Bash** | — | Linux / macOS / WSL en Windows |

### Instalación de Agentes

Los agentes se instalan **automáticamente** al clonar el repositorio. VS Code detecta los archivos `.agent.md` en `.github/agents/` y los registra como custom agents en Copilot Chat.

```bash
# 1. Clonar el repositorio
git clone https://github.com/e2its/mi-AI-Factory.git
cd mi-AI-Factory

# 2. Abrir en VS Code
code .

# 3. Verificar que aparece @Factory en Copilot Chat
#    Abrir Copilot Chat (Ctrl+Shift+I) → escribir @ → debe aparecer "Factory"
```

### Estructura de Archivos del Sistema de Agentes

```
.github/
├── copilot-instructions.md              # Gobernanza cross-cutting (cargado SIEMPRE)
├── agents/                              # 9 Custom Agents
│   ├── factory.agent.md                 # Orquestador visible (@Factory)
│   ├── audit.agent.md                   # Worker: Due Diligence
│   ├── setup.agent.md                   # Worker: Setup & Governance
│   ├── codesign.agent.md               # Worker: Co-Creation (PO↔UX)
│   ├── blueprint.agent.md              # Worker: Technical Design (ARCH↔QA)
│   ├── implement.agent.md              # Worker: Implementation (DEV↔REVIEW↔SEC)
│   ├── devops.agent.md                 # Worker: Infrastructure & Deployment
│   ├── qa.agent.md                     # Worker: Post-Staging Verification
│   └── backlog.agent.md               # Worker: Project Tracking & Issues
├── instructions/                        # 20 instrucciones detalladas (carga contextual)
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
├── skills/                              # 12 cross-agent skills (protocolos reutilizables)
│   ├── Factory-build-verification/      # BVL — test execution + auto-fix loop
│   ├── Factory-batch-interactivity/     # BIP — decisiones en lote
│   ├── Factory-incremental-persistence/ # IPP — persistencia incremental
│   ├── Factory-codebase-inventory/      # CIP — inventario DRY
│   ├── Factory-governance-loading/      # Zero Trust context recovery
│   ├── Factory-iteration-model/         # Cascading invalidation
│   ├── Factory-branching-strategy/      # SCM — branch enforcement
│   ├── Factory-agent-communication/     # ACP — verbosidad entre agentes
│   ├── Factory-commit-prompt/           # Commit convencional auto-generado
│   ├── Factory-worklog/                 # Audit trail JSONL per-feature
│   ├── Factory-memory-cache/            # MCP — capa de aceleración /memories/repo/
│   └── Factory-backlog-next-task/       # Next-Task Resolver con cache fast path
└── prompts/                             # 3 prompts de workflow reutilizables
    ├── create-feature.prompt.md
    ├── review-pr.prompt.md
    └── setup-project.prompt.md
```

### Configuración del Modelo LLM

Todos los agentes están configurados con preferencia de modelo:

```yaml
model: ['Claude Opus 4.6 (copilot)', 'Claude Opus 4.5 (copilot)']
```

VS Code usa el primer modelo disponible. Si Claude Opus 4.6 tiene rate limiting, hace fallback automático a Claude Opus 4.5. No se soportan otros modelos — el sistema requiere la capacidad de razonamiento de Claude Opus 4.x para funcionar correctamente.

### Verificación Post-Instalación

1. Abrir Copilot Chat en VS Code
2. Escribir `@` — debe aparecer **Factory** en la lista de agentes
3. Escribir `@Factory hola` — debe responder identificándose como el orquestador SDLC
4. Los 8 workers (audit, setup, codesign, blueprint, implement, devops, qa, backlog) son **invisibles** — se invocan únicamente a través de Factory via handoffs
5. El framework incluye **12 skills** cross-agent (protocolos reutilizables) y **3 prompts** de workflow

---

## 2. Arquitectura del Sistema

### Modelo Hub-and-Spoke

```
                    ┌─────────────┐
        Usuario ───►│  @Factory   │◄─── copilot-instructions.md (siempre cargado)
                    │ (visible)   │
                    └──────┬──────┘
                           │ handoffs (send: false)
            ┌──────┬───────┼───────┬──────┬───────┬──────┬─────────┐
            ▼      ▼       ▼       ▼      ▼       ▼      ▼         ▼
         audit   setup  codesign blueprint implement devops  qa   backlog
        (invisible — solo accesibles via Factory)
```

- **Factory** es el ÚNICO agente invocable por el usuario (`user-invokable: true`)
- Los **workers** son invisibles (`user-invokable: false`)
- Factory clasifica el intent del usuario y hace handoff al worker correcto
- Cada handoff usa `send: false` — el usuario ve un botón para confirmar la delegación
- `copilot-instructions.md` se carga en TODAS las conversaciones (contiene gobernanza cross-cutting)
- Las instrucciones en `.github/instructions/` se cargan contextualmente según el agente activo

### Cómo Interactuar

Hay dos formas de invocar comandos:

**1. Lenguaje natural** — Factory clasifica el intent automáticamente:
```
@Factory quiero crear una feature de login con OAuth
→ Factory mapea a: CODESIGN --start {ID} "login con OAuth"
→ Presenta botón de handoff a CODESIGN
```

**2. Comando explícito** — Factory enruta directamente:
```
@Factory CODESIGN --start USR-001 "Login con OAuth"
→ Factory enruta a CODESIGN sin clasificación
```

### Bucle de Persistencia

Los agentes **no fallan silenciosamente** — pausan y persisten estado:

1. El agente encuentra ambigüedad → Guarda artefacto con `status: NEEDS_INFO`
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

## 4. Referencia de Comandos por Agente

> Ejecutar en Copilot Chat (VS Code) en modo agente: `@Factory [COMANDO]`

### Pre-0. AUDIT (Technical Due Diligence) — Opcional

Rol: Auditor Técnico Senior. Evalúa el estado actual de un proyecto existente antes de iniciar gobernanza. Independiente del workflow principal.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `AUDIT --audit` | — | Auditoría técnica completa. Protocolo Scan-First. Master Checklist: Fase 0 (Idioma), Fase A (Governance/HR), Fase B (Arquitectura/Software), Fase C (Infraestructura), Fase D (Seguridad). Persistencia atómica: una sección por turno. Resumible via `status: NEEDS_INFO`. |
| `AUDIT --refine {SECTION_ID}` | ID de sección (P0, G1-G3, S1-S4, I1-I4, SEC1-SEC5) | Refinamiento de sección específica. |
| `AUDIT --approve` | — | Cierre de auditoría con veredicto `GO` / `NO_GO` / `GO_WITH_CONDITIONS`. |

Artefacto: `docs/technical_due.md`

### 0. SETUP (Setup & Governance)

Rol: Arquitecto/Gobernanza. Define constitución, reglas y scaffolding inicial.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `SETUP --init` | — | Discovery con AI Budget + Brownfield auto-detection. Planning con 12 topologías backend, 10 patrones frontend. Execution con validación presupuesto. |
| `SETUP --generate` | — | Solo con `phase: COMPLETED`. Materializa scaffolding tripartito (Backend/Frontend/Integration ACL). Incluye IaC Foundation Scaffolding. Crea MATERIALIZATION_REPORT.md con checklist de 60-80 tareas. |
| `SETUP --generate --resume` | — | Continúa materialización interrumpida. Requiere MATERIALIZATION_REPORT.md. Lee checklist y continúa desde última tarea pendiente. |
| `SETUP --migrate-legacy-setup` 🧪 | — | **EXPERIMENTAL.** Auto-migra setup.md antiguo a formato tripartito. Requiere score >85%. |
| `SETUP --upgrade` | — | Actualiza artefactos de gobernanza a última versión del framework. 6 capas de seguridad. Smart Additive Merge. |
| `SETUP --rollback-upgrade {TIMESTAMP}` | Timestamp de backup | Recupera el proyecto de un upgrade fallido. |

Artefactos: `docs/setup.md`, `docs/constitution.md`, `docs/rules/*`, `MATERIALIZATION_REPORT.md`

### 1. CODESIGN (Co-Creation: PO ↔ UX)

Rol: Doble personalidad (🎩 PO hat ↔ 🎨 UX hat). Co-crea especificación funcional, mockup visual y user journey.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `CODESIGN --vision` | — | Genera la visión global UX. Obligatorio para proyectos con frontend. 7 fases. |
| `CODESIGN --vision-refine "[FEEDBACK]"` | Feedback | Refinamiento de la visión global. |
| `CODESIGN --vision-approve` | — | Aprobación conjunta PO+UX de la visión global. |
| `CODESIGN --vision-propagate` | — | Propaga cambios de visión a mocks existentes. |
| `CODESIGN --start {ID}` | Feature ID | Inicia co-creación. Vision Gate para features con UI. Event Storming → spec ↔ mock ↔ journey hasta convergencia. Auto-aprueba si 12/12 validaciones pasan. |
| `CODESIGN --refine {ID} "[FEEDBACK]"` | Feedback | Refinamiento iterativo. Clasifica cambios DELTA/BREAKING. Auto-aprueba si 12/12 validaciones pasan. |

Artefactos per-feature: `docs/spec/{ID}/spec.feature`, `mock.html`, `user_journey.md`
Artefactos global vision: `docs/ux/vision/vision.md`, `app_shell.html`, `style_guide.html`, `page_templates.html`, `component_library.html`, `navigation_map.md`

### 2. BLUEPRINT (Co-Design: ARCH ↔ QA)

Rol: Doble personalidad (🏗️ ARCH hat ↔ 🧪 QA hat). Co-diseña arquitectura y estrategia de tests simultáneamente.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `BLUEPRINT --start {ID}` | — | Co-diseña design.md + test_plan.md. Requiere CODESIGN APPROVED. Genera C4, contratos, Section 5: Infrastructure Needs. |
| `BLUEPRINT --refine {ID} "[FEEDBACK]"` | Feedback | Refinamiento iterativo de diseño y/o tests. |
| `BLUEPRINT --approve {ID}` | — | Aprobación conjunta ARCH+QA. Habilita IMPLEMENT. |
| `BLUEPRINT --adr {ID} "[TITLE]" "[DECISION]"` | Título y decisión | Genera ADR standalone. |
| `BLUEPRINT --review-conflict {ID}` | — | Arbitraje cuando peer review rechaza 3+ veces. |

Artefactos: `docs/spec/{ID}/design.md`, `test_plan.md`, contratos en `contracts/`

### 3. IMPLEMENT (Implementation: DEV ↔ REVIEW ↔ SEC)

Rol: Triple personalidad (💻 DEV ↔ 🔍 REVIEW ↔ 🛡️ SEC). Planifica + implementa + verifica + asegura por fases.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `IMPLEMENT --plan {ID}` | — | Genera checklist de implementación (`dev_plan.md`) con tareas `- [ ] [A/B/C.N]`. Requiere BLUEPRINT APPROVED. |
| `IMPLEMENT --refine {ID} "[FEEDBACK]"` | Feedback | Refinamiento del plan. Standard Refine genera tareas `[ADJ-N]`, Delta Iteration (v9.0.0) genera tareas `[D.N]`. |
| `IMPLEMENT --build {ID}` | — | Implementación por fases: 💻 DEV (TDD + BVL) → 🔍 REVIEW → 🛡️ SEC (SAST). Build Verification Loop: ejecuta tests en terminal, parsea errores, auto-corrige (max 3 intentos). Full Verification Gate (tests + lint + typecheck + build) antes de `IMPLEMENTED_AND_VERIFIED`. Completion Gate: todas las tareas deben ser `[x]` o `@skip` con justificación. |
| `IMPLEMENT --fix {ID} "[AYUDA]"` | Ayuda | Genera tareas `[FIX-N]` a partir de QA rejection o bloqueos. Ejecuta fix → marca `[x]`. |

Artefactos: `docs/spec/{ID}/dev_plan.md`, código fuente, `peer_review_{ts}.md`, `sec_audit.md`, Draft PR

### 4. DEVOPS (DevOps & Infrastructure)

Rol: SRE y Platform Engineer. Gestión de infraestructura, CI/CD y entornos.

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `DEVOPS --configure {ID}` | — | Genera plan de infraestructura (proceso guiado RDR). Auto-aprueba si 7/7 checks pasan. |
| `DEVOPS --refine {ID} "{FEEDBACK}"` | Feedback técnico | Ajusta plan basado en feedback. |
| `DEVOPS --provision [{ID}] --env {ENV}` | Environment | Materializa infraestructura. Con ID → feature-scoped. Sin ID → env-scoped. |
| `DEVOPS --deploy [{ID}] --env {ENV}` | Environment | Despliega código. Requiere IMPLEMENT completado. Prod requiere MERGE + QA APPROVED. |
| `DEVOPS --suspend [{ID}] --env {ENV}` | Environment | Suspende entorno para reducir costos. |
| `DEVOPS --resume [{ID}] --env {ENV}` | Environment | Reanuda entorno suspendido. |
| `DEVOPS --rollback [{ID}] --env {ENV}` | Environment | Revierte deployment. |
| `DEVOPS --teardown [{ID}] --env {ENV}` | Environment | Destruye infraestructura. `data_bearing: true` requiere backup. |
| `DEVOPS --status [{ID}]` | — | Dashboard de estado. |

Artefactos: `docs/spec/{ID}/devops_plan.md`, `infra/features/{ID}/` (IaC), `deployment_report_{ts}.md`

**Guardrails de Ejecución:**
- **G0** Governance Load | **G1** Stack Coherence | **G2** Cost (>20% warn, >50% block)
- **G3** Secrets (prohibido hardcodear) | **G4** HA (features CRITICAL → multi-AZ)
- **G5** Environments (de governance, no hardcodeados) | **G6** Data Protection (backup antes de teardown)

### 5. QA (Quality Assurance — Post-Staging)

Rol: Certificación final post-code y verificación en entorno desplegado (incluye DAST via 🛡️ SEC hat).

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `QA --verify {ID}` | — | Checkbox-driven: genera checklist `- [ ]` (`[QA-PRE-*]`, `[QA-GOV-*]`, `[QA-TC-*]`, `[QA-REG-*]`, `[QA-DAST-*]`), marca `[x]` al ejecutar. Auto-aprueba si ALL `[x]` AND veredicto APPROVED. Requiere entorno desplegado. |
| `QA --reject {ID} "[MOTIVO]"` | Motivo | Genera items de remediación `[FIX-N]` → IMPLEMENT `--fix`. |
| `QA --e2e {ID}` | — | Ejecuta pruebas E2E. |

Artefactos: `docs/spec/{ID}/qa/qa_report_final_{ts}.md` (incluye Verification Checklist)

> **Nota:** La planificación de tests fue absorbida por BLUEPRINT (🧪 QA hat). QA se enfoca en verificación post-staging.

### 6. BACKLOG (Project Tracking & Issue Management) — Independiente

Rol: Gestor operativo del tablero de proyecto. Crea issues, organiza el Kanban y trackea features. Independiente del workflow principal (como AUDIT).

| Comando | Argumentos | Descripción |
| --- | --- | --- |
| `BACKLOG --init-board` | — | Inicializa el backlog. Modo externo: crea proyecto en herramienta externa + `project-config.json`. Modo local: crea `state.md` con tabla Kanban. |
| `BACKLOG --plan-feature {ID} "{name}"` | Feature ID + nombre | Crea el set de issues para una feature (fases configuradas en SETUP). Modo externo: vía API. Modo local: entries en `state.md` + body files. |
| `BACKLOG --create-issue "{title}"` | Título | Crea un issue custom individual. Modo externo: vía API. Modo local: entry en `state.md` + body file. |
| `BACKLOG --move {ISSUE_NUMS} --to {STATUS}` | Issues + columna destino | Mueve issues entre columnas del Kanban. Modo externo: API. Modo local: actualiza `state.md`. |
| `BACKLOG --status` | — | Muestra resumen del tablero con conteo de issues por columna. |
| `BACKLOG --plan-execution` | — | Analiza dependencias entre features, forma Domain Clusters por Bounded Context compartido y genera un plan de ejecución ordenado que minimiza retrabajo. Escribe `docs/backlog/execution-plan.md` + cache en `/memories/repo/`. |
| `BACKLOG --update-execution {step}` | Paso completado | Marca un paso del plan como completado, avanza el estado del cluster y refresca el cache. |
| `BACKLOG --sync-execution` | — | Reconcilia el plan de ejecución con el estado actual del tablero. Detecta drift y lo corrige. |

Prerequisito: `docs/setup.md` con sección `project_tracking` (configurado durante SETUP --init Q27).

Modo SSOT: Si `project_tracking.tool != "None"` → modo externo (la herramienta externa es la única fuente de verdad, sin `state.md` ni `issue-bodies/` locales). Si `project_tracking.tool == "None"` → modo local (`state.md` + `issue-bodies/` son la única fuente de verdad).

Artefactos (modo externo): `docs/backlog/project-config.json` (solo identificadores de conexión no sensibles y mapeo de campos — sin registro de issues, sin tokens).
Artefactos (modo local): `docs/backlog/state.md`, `docs/backlog/issue-bodies/*.md` (sin `project-config.json`).
Artefactos (plan de ejecución): `docs/backlog/execution-plan.md` (ordenación por Domain Clusters). Cache: `/memories/repo/execution-plan-cache.md`.

---

## 5. Pipeline Recomendado

### Fase Pre-0 (Opcional): Due Diligence Técnica

```
@Factory AUDIT --audit       → Escaneo + auditoría por secciones
@Factory AUDIT --approve     → Veredicto GO / NO_GO / GO_WITH_CONDITIONS
```

Si se ejecuta AUDIT, SETUP auto-detecta Brownfield y pre-llena datos.

### Fase 0: Setup (Gobierno y Estructura)

```
@Factory SETUP --init        → Discovery → Planning → Execution (interactivo)
@Factory SETUP --generate    → Materializa scaffolding, constitución, reglas
```

### Fase 0.1 (Opcional): Iniciar Proyecto y Backlog

```
@Factory BACKLOG --init-board                              → Crea proyecto en herramienta configurada (o local)
@Factory BACKLOG --plan-feature USR-001 "Login con OAuth"  → Issues por feature
@Factory BACKLOG --plan-feature USR-002 "Dashboard"        → Issues por feature
@Factory BACKLOG --plan-execution                          → Analiza dependencias → genera plan de ejecución por Domain Clusters
```

### Fase 0.5: Global Vision (Obligatorio para proyectos con frontend)

```
@Factory CODESIGN --vision           → Genera identidad visual global
@Factory CODESIGN --vision-approve   → Aprueba visión
```

### Fase 1: Definición y Co-Creación (Pre-Code)

```
@Factory CODESIGN --start USR-001 "Login con OAuth"   → Co-crea spec + mock + journey (auto-aprueba si 12/12 OK)

@Factory BLUEPRINT --start USR-001    → Co-diseña design.md + test_plan.md
@Factory BLUEPRINT --approve USR-001  → Habilita IMPLEMENT (único checkpoint manual obligatorio)
```

### Fase 2: Implementación (Code)

```
@Factory IMPLEMENT --plan USR-001    → Genera checklist (dev_plan.md)
@Factory IMPLEMENT --build USR-001   → TDD + BVL (ejecución real) + Review + SAST por fase
```

### Fase 2.5: Infraestructura (Flexible — post-BLUEPRINT)

```
@Factory DEVOPS --configure USR-001              → Plan de infra (auto-aprueba si 7/7 OK)
@Factory DEVOPS --provision USR-001 --env dev    → Materializa infraestructura
```

### Fase 3: Certificación (Post-Code)

```
@Factory DEVOPS --deploy USR-001 --env staging   → Deploy a pre-producción
@Factory QA --verify USR-001                     → Tests + DAST (auto-aprueba si veredicto APPROVED)
```

### Fase 4: Merge y Producción

```
git push origin feature/USR-001-login-oauth      → Push a remote
# Crear PR → CI checks → approval → merge to main + tag

@Factory DEVOPS --deploy USR-001 --env prod       → Deploy desde main/tag
```

---

## 6. Diagrama de Flujo Completo

```mermaid
graph TD
    Start([Usuario: Nueva Feature]) --> TddCheck{Due Diligence?}
    TddCheck -->|Sí, opcional| TddAudit[AUDIT --audit]
    TddAudit --> TddNeedsInfo{status: NEEDS_INFO?}
    TddNeedsInfo -->|Sí| TddRefine[AUDIT --refine SECTION]
    TddRefine --> TddAudit
    TddNeedsInfo -->|No| TddApprove[AUDIT --approve]
    TddApprove --> TddVerdict{Veredicto?}
    TddVerdict -->|GO / GO_WITH_CONDITIONS| Setup
    TddVerdict -->|NO_GO| NoGo([Proyecto No Viable])
    TddCheck -->|No| Setup{Setup Completado?}
    
    Setup -->|No| SetupInit[SETUP --init]
    SetupInit --> SetupGen[SETUP --generate]
    SetupGen --> VisionCheck{Frontend?}
    Setup -->|Sí| VisionCheck
    
    VisionCheck -->|Sí| CodesignVision[CODESIGN --vision]
    CodesignVision --> CodesignVisionApprove[CODESIGN --vision-approve]
    CodesignVisionApprove --> CodesignStart[CODESIGN --start ID]
    VisionCheck -->|No frontend| CodesignStart
    
    CodesignStart --> CodesignNeedsInfo{status: NEEDS_INFO?}
    CodesignNeedsInfo -->|Sí| CodesignRefine[CODESIGN --refine ID FEEDBACK]
    CodesignRefine --> CodesignStart
    CodesignNeedsInfo -->|No| CodesignAutoApprove{12/12 validaciones?}
    CodesignAutoApprove -->|Sí auto-approve 12/12| BlueprintStart[BLUEPRINT --start ID]
    CodesignAutoApprove -->|No| CodesignFix[Corregir y re-refine]
    CodesignFix --> CodesignStart
    
    BlueprintStart --> BlueprintNeedsInfo{status: NEEDS_INFO?}
    BlueprintNeedsInfo -->|Sí| BlueprintRefine[BLUEPRINT --refine ID FEEDBACK]
    BlueprintRefine --> BlueprintStart
    BlueprintNeedsInfo -->|No| BlueprintApprove[BLUEPRINT --approve ID]
    
    BlueprintApprove --> ImplPlan[IMPLEMENT --plan ID]
    ImplPlan --> ImplNeedsInfo{status: NEEDS_INFO?}
    ImplNeedsInfo -->|Sí| ImplRefine[IMPLEMENT --refine ID FEEDBACK]
    ImplRefine --> ImplPlan
    ImplNeedsInfo -->|No| ImplBuild[IMPLEMENT --build ID]
    
    ImplBuild --> ImplBlocked{status: BLOCKED?}
    ImplBlocked -->|Sí| ImplFix[IMPLEMENT --fix ID AYUDA]
    ImplFix --> ImplBuild
    ImplBlocked -->|No| ImplDone{Build Complete?}
    ImplDone -->|No| ImplBuild
    ImplDone -->|Sí| DevOpsDeploy[DEVOPS --deploy ID --env PRE_PROD]
    
    DevOpsDeploy --> QaVerify[QA --verify ID]
    QaVerify --> QaPass{Tests OK?}
    QaPass -->|No| QaReject[QA --reject ID MOTIVO]
    QaReject --> ImplFix2[IMPLEMENT --fix ID]
    ImplFix2 --> ImplBuild
    QaPass -->|Sí auto-approve| MergePR[MERGE: PR → main + tag]
    MergePR --> DeployProd[DEVOPS --deploy ID --env PROD]
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
| AUDIT sin evidencias para una sección | `technical_due.md → NEEDS_INFO` | `AUDIT --refine SECTION_ID "Datos..."` |
| AUDIT veredicto NO GO | `technical_due.md → APPROVED, verdict: NO_GO` | Revisar hallazgos con stakeholders |
| Spec ambigua | `spec.feature → NEEDS_INFO` | `CODESIGN --refine ID "Aclaraciones..."` |
| Architecture mapping faltante | `design.md → NEEDS_INFO` | `BLUEPRINT --refine ID "Definir APIs..."` |
| Modificación RED ZONE | `design.md → BLOCKED` | `BLUEPRINT --refine ID "ADR: Justificación..."` |
| Implementación bloqueada | `dev_plan.md → tarea BLOCKED` | `IMPLEMENT --fix ID "Pista técnica..."` |
| Test falla 3 veces (3-Strike Rule) | `dev_plan.md → NEEDS_DECISION` | Bucle Recomendación/Decisión: reintentar, modificar, escalar |
| Vulnerabilidades SAST | `sec_audit.md → VULNERABLE` | Fix loop inline en `IMPLEMENT --build` |
| Vulnerabilidades DAST | `qa_report.md → VULNERABLE` | Remediar → `QA --verify ID` |
| Config hardcodeada | `qa_report.md → VULNERABLE` | Corregir → `QA --verify ID` |
| Drift violation | `qa_report.md → BLOCKED` | `BLUEPRINT --refine ID` o corregir y re-run |

---

## 8. Matrices de Transición de Estados

### `spec.feature` (CODESIGN)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `CODESIGN --start ID` | `DRAFT` o `NEEDS_INFO` |
| `NEEDS_INFO` | `CODESIGN --refine ID` | `DRAFT` o `NEEDS_INFO` |
| `DRAFT` | (auto-approve 9/9 OK) | `APPROVED` |
| `APPROVED` | `CODESIGN --refine ID` | `DRAFT` (nueva iteración) |

### `design.md` + `test_plan.md` (BLUEPRINT)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `BLUEPRINT --start ID` | `DRAFT` o `NEEDS_INFO` |
| `NEEDS_INFO` | `BLUEPRINT --refine ID` | `DRAFT` o `BLOCKED` |
| `DRAFT` | `BLUEPRINT --approve ID` | `APPROVED` |
| `APPROVED` | `BLUEPRINT --refine ID` | `DRAFT` (requiere ADR si RED ZONE) |

### `dev_plan.md` (IMPLEMENT)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `IMPLEMENT --plan ID` | `DRAFT` o `NEEDS_INFO` |
| `NEEDS_INFO` | `IMPLEMENT --refine ID` | `READY` |
| `READY` | `IMPLEMENT --build ID` | `BUILDING` |
| `BUILDING` | `IMPLEMENT --build ID` | `BUILDING` o `IMPLEMENTED_AND_VERIFIED` |
| `BUILDING` | (test falla 3×) | `NEEDS_DECISION` |
| `BUILDING` | `IMPLEMENT --fix ID` | `BUILDING` |
| `IMPLEMENTED_AND_VERIFIED` | `IMPLEMENT --refine ID` | `READY` (delta_mode) |
| `IMPLEMENTED_AND_VERIFIED` | `IMPLEMENT --fix ID` | `BUILDING` (fix cycle) |

### `qa_report_{ts}.md` (QA)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `QA --verify ID` | `APPROVED` (auto) o `REJECTED` |
| `REJECTED` | `IMPLEMENT --fix ID` completes | `INVALIDATED` |
| `INVALIDATED` | `QA --verify ID` | `APPROVED` (auto) o `REJECTED` |
| `APPROVED` | — | Terminal (habilita MERGE) |

### `technical_due.md` (AUDIT)

| Estado Actual | Comando Válido | Estado Siguiente |
|--------------|---------------|-----------------|
| — | `AUDIT --audit` | `NEEDS_INFO` |
| `NEEDS_INFO` | `AUDIT --audit` | `NEEDS_INFO` o `DRAFT` |
| `DRAFT` | `AUDIT --approve` | `APPROVED` |
| `APPROVED` | `AUDIT --refine SECTION` | `DRAFT` (requiere re-aprobación) |

> Estado `CANCELLED` es terminal en todos los artefactos — bloquea cualquier operación.

---

## 9. Glosario de Estados (Frontmatter)

### Estados generales de artefactos

| Estado | Significado |
| --- | --- |
| `DRAFT` | Borrador completo, esperando revisión o auto-aprobación. |
| `NEEDS_INFO` | Agente pausado, requiere `--refine` del usuario. |
| `APPROVED` | Documento congelado y validado. Habilita siguiente fase. |
| `REJECTED` | (QA) Verificación rechazada. Requiere `IMPLEMENT --fix`. |
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

Registro central auto-generado durante `SETUP --generate`:
- Contiene metadata por regla: type, validation_method, severity, agents aplicables
- Governance snapshot: `.context/governance_snapshot.md` — file-based cache, summarization-safe (see `governance-loading.md`)
- Verification commands: auto-derivados del stack config para BVL (test, lint, typecheck, build)

### Protocolos Cross-Agent (Skills)

El framework incluye 12 protocolos inteligentes reutilizables por todos los agentes:

| Protocolo | Versión | Objetivo |
|-----------|---------|----------|
| **Build Verification Loop (BVL)** | v1.0.0 | Ejecución real de tests en terminal, parseo de errores, auto-fix (max 3 intentos), Full Verification Gate (tests + lint + typecheck + build). Usa BVL Commands Cache (`/memories/repo/`) |
| **Batch Interactivity (BIP)** | v1.2.0 | Decisiones en lote tier-based, no una-pregunta-a-la-vez. Disruption-Triggered Re-Harvest |
| **Incremental Persistence (IPP)** | v1.0.1 | Skeleton-first write, section-atomic saves, resume-on-entry. Sobrevive a context summarization |
| **Codebase Inventory (CIP)** | v1.2.0 | Inventario DRY cross-agent. CIP Canary gate previene duplicación post-summarization. Usa Inventory Cache (`/memories/repo/`) |
| **Governance Loading (GCRP)** | v2.2.0 | Zero Trust context recovery. Dual-hash snapshot (constitution + setup). Summarization-safe |
| **Iteration Model** | v2.0.0 | Domain-driven incremental dev. Cascading invalidation automático al cambiar specs upstream |
| **Branching Strategy (SCM)** | v1.0.1 | Branch enforcement, merge policy, concurrency locks, auto-checkout protocol |
| **Agent Communication (ACP)** | v2.0.0 | Verbosidad controlada: entry announcement, phase milestones, completion summary |
| **Commit Prompt** | v1.0.0 | Commit convencional auto-generado post-comando |
| **Worklog** | v1.0.0 | Audit trail JSONL per-feature. Action registration, phase mapping |
| **Memory Cache Protocol (MCP)** | v1.0.0 | Capa de aceleración unificada via `/memories/repo/`. Caches para: Feature State, BVL Commands, CIP Inventory, Execution Plan |
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
| `BLUEPRINT --approve` | Contratos, UX compliance, protected code, system resources |
| `IMPLEMENT --build` (REVIEW) | Patrones de seguridad, arquitectura, accesibilidad, protected paths |
| `IMPLEMENT --build` (SEC) | SAST patterns, secrets, vulnerabilidades |
| `QA --verify` | dependency-allowlist (BLOCKING), integration config, DAST |

### Modelo Tolerancia Cero

- **GREEN ZONES (Código Nuevo):** CRITICAL/HIGH violations → BLOCK inmediatamente con reporte YAML
- **RED ZONES (Código Legacy):** Sin validación (exempt). Modificaciones requieren ADR approval

---

## 11. Arquitectura de Caché en Memoria (MCP v1.0.0)

El framework utiliza `/memories/repo/` de VS Code Copilot como capa de aceleración para eliminar lecturas redundantes de archivos entre comandos. Los archivos en disco siguen siendo la fuente de verdad (SSOT).

### Caches Activos

| Cache | Ubicación | Fuente (SSOT) | Usado Por | Invalidación |
|-------|-----------|---------------|-----------|--------------|
| **Feature State** | `/memories/repo/feature-state-cache.md` | `docs/spec/*/` frontmatters | Smart Redirect, Factory | Cambio de status en cualquier artefacto |
| **BVL Commands** | `/memories/repo/bvl-commands-cache.md` | `.context/governance_snapshot.md` | IMPLEMENT `--build`, `--fix` | Cambio en governance snapshot |
| **CIP Inventory** | `/memories/repo/codebase-inventory-cache.md` | `config/codebase_inventory.json` | BLUEPRINT, IMPLEMENT, CODESIGN | Modificación del inventario |
| **Execution Plan** | `/memories/repo/execution-plan-cache.md` | `docs/backlog/execution-plan.md` | Next-Task Resolver, Factory | `--plan-execution`, `--update-execution`, `--sync-execution` |

### Principios de Diseño

1. **SSOT en disco** — Los artefactos en disco son SIEMPRE la fuente autoritativa. Los caches son aceleradores, nunca fuentes primarias.
2. **Write-Through** — Cuando un agente modifica un artefacto fuente, actualiza el cache correspondiente inmediatamente.
3. **Validación por Hash** — Cada cache almacena el hash de su fuente. Se valida al leer; si es stale → se regenera desde la fuente.
4. **Degradación Graceful** — Si un cache falla, el agente cae al path lento (lectura directa). NUNCA se bloquea un comando por fallo de cache.
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

### Comando: `CODESIGN --revise`

```
@Factory CODESIGN --revise USR-001 "Agregar autenticación OAuth"
```

- Crea `docs/spec/USR-001-v2/` con parent links
- Marca `USR-001` como `APPROVED (SUPERSEDED)`
- Herencia de artifacts downstream (test_plan, design) disponible
- Máximo 1 versión activa (linearidad forzada)

Ver `docs/rules/immutability_policy.md` para reglas completas.
