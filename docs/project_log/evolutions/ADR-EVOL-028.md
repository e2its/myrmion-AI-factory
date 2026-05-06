---
version: 0.1.0
date: 2026-05-06
changelog:
  - "0.1.0: Skeleton — RDR ratifications persisted (E2+E3 injection point, applicable_when vocabulary phase/scope/change_type/command/always + path_glob + framework, ambos espejados meta↔template, drop ADR backfill since constitution materialises [LAW]). Status: proposed."
adr_number: EVOL-028
title: Applicability Discovery Protocol (ADP) — salience por discovery vivo, no por listas estáticas
status: proposed
type: framework-evolution
scope: global
---

# ADR-EVOL-028: Applicability Discovery Protocol (ADP)

## Context

Observación reportada por el usuario: durante la ejecución de un comando, los agentes pierden gobernanza **antes** de cualquier summarization. El contexto se vuelve difuso, las rules cargadas se olvidan, las DCs aplicables no se invocan. El mecanismo actual de lazy-load (skills via `description:` consumido por el harness, DCs filtradas por `applicable_when:`, instructions cargadas on-demand por commands) **no se respeta en la práctica** — el agente las tiene cargadas pero la atención del modelo se la lleva el último prompt.

ADR-EVOL-026 (accepted 2026-05-05) ya identificó este patrón a nivel constitucional ("on-demand discipline failed post-summarization") y lo resolvió ampliando el snapshot curado de 1-2 KB a 2-4 KB. Esto blinda los `[LAW]` constitucionales y los DCs universales (`applicable_when: always`) frente a la summarization, pero **no aborda la disciplina por-comando** — qué subset del corpus de instructions / skills / DCs condicionales aplica a la tarea inmediata, y la garantía explícita de que el agente lo enumere antes de actuar.

Diagnóstico de raíz: existe la metadata pero no la **disciplina de invocación explícita**. Cualquier solución basada en listas pre-computadas de aplicabilidad en cada `commands/*.md` choca con la naturaleza viva del framework — los DCs crecen, las instructions se añaden, los `[LAW]` constitucionales evolucionan vía ADR-amend-constitution. Una lista estática se vuelve obsoleta el día siguiente.

## Decision

Adoptar el **Applicability Discovery Protocol (ADP)** como disciplina universal de inicio de comando. Tres componentes:

### 1. Contrato uniforme `applicable_when:`

Vocabulario único, ejes ortogonales, AND implícito por eje, OR dentro de un eje (semántica idéntica al campo ya existente en `defect-prevention.md`):

| Eje | Valores | Significado |
|-----|---------|-------------|
| `phase` | `[CODESIGN, BLUEPRINT, IMPLEMENT, QA, DEVOPS, SETUP, BACKLOG, AUDIT]` | Fase SDLC |
| `scope` | `[frontend-only, backend-only, full-stack, infra]` | Alcance del feature |
| `change_type` | `[feature, fix, docs, chore, refactor]` | Tipo de cambio (derivable de la rama) |
| `command` | lista libre (ej. `[implement, /implement --build]`) | Comando concreto |
| `path_glob` | lista de globs (ej. `["**/*.py", "src/**/*.ts"]`) | Patrones de archivo a los que aplica una rule técnica |
| `framework` | lista de frameworks/stacks (ej. `[django, react, fastapi]`) | Stack del proyecto |
| `always` | `true` | Aplica siempre — equivalente a sin filtro |

`always: true` es mutuamente excluyente con cualquier otro eje en la misma entrada. Una entrada sin `applicable_when:` se trata como `always: true` (back-compat con archivos pre-EVOL-028 durante la ventana de migración).

Aplica a: `.claude/instructions/*.instructions.md`, `.claude/skills/Factory-*/SKILL.md` (estructurales solamente), `.claude/rules/defect-prevention.md` entries (ya existe `applicable_when:` con phase/scope; se extiende a path_glob/framework). **NO aplica a ADRs** — los ADRs son registro histórico; sus `[LAW]` operacionales viven en `constitution.md` / snapshot, que es lo que el discovery escanea como ley viva.

### 2. Skill `Factory-applicability-discovery` — discovery vivo

Skill único responsable de producir el roll-call. En cada Step 0 de comando ejecuta:

```
1. read .context/governance_snapshot.md → ACTIVE LAWs + always-DCs
2. scan .claude/instructions/*.instructions.md → filter by applicable_when
3. scan .claude/skills/Factory-*/SKILL.md → filter by applicable_when
4. scan .claude/rules/defect-prevention.md entries → filter by applicable_when
5. compute discovery_hash (sha256 de los frontmatters scaneados)
6. emit applicability-rollcall block to user (on-screen)
```

El contexto del filtro deriva de: comando invocado, frontmatter `_progress.scope` del feature, branch name (→ change_type), stack del proyecto (`.context/setup.md` → framework). El discovery lee árboles vivos — **un DC nuevo o un [LAW] amendado entran al roll-call automáticamente al siguiente turn, sin tocar nada más**.

### 3. Roll-call block on-screen — Step 0 obligatorio

Cada `.claude/commands/*.md` incorpora una sección "Step 0 — Applicability Roll-Call" que invoca la skill y exige imprimir el block como **primer mensaje user-facing del comando**, antes de cualquier acción. El bloque tiene formato canónico fijo (≤25 líneas), inmune a las reglas de tono caveman del cuerpo del comando. Renderizado en pantalla obliga al agente a comprometerse y al usuario a poder vetar antes de actuar.

Formato canónico:

```
📋 Applicability Roll-Call — /implement --build · EVOL-XXX · phase=IMPLEMENT scope=backend-only change_type=feature

  ACTIVE LAWS (n)
    • <fuente> — <título> (<axis>=<value>)
  ACTIVE DCs (n)
    • <id> <título> (<axis>=<value>)
  ACTIVE INSTRUCTIONS (n)
    • <name>, <name>
  ACTIVE SKILLS (n)
    • <name>, <name>
  EXCLUDED (n)
    • <name> — <axis>=<value> ≠ <current>
  Discovery hash: <8-char> · <total> frontmatters scanned · <active> active · <excluded> excluded
```

### RDR ratifications (verbatim user choices)

- **Punto de inyección:** **E2 + E3** — skill `Factory-applicability-discovery` (E3) es la fuente única que printea el block; cada `commands/*.md` (E2) la invoca como Step 0 obligatorio. Rejected E1 (UserPromptSubmit hook como mecanismo primario) — ruido en cada turn no-comando, falsos positivos altos. Rejected solo-E2 (lógica embebida en commands) — anti-DRY, lógica duplicada en 8 archivos. Rejected solo-E3 (auto-invocación sin Step 0) — invisible al diff de commands, fácil de saltar. E1 queda como ampliación futura si E2+E3 prueba ser saltable en uso real.
- **Vocabulario:** mínimo (phase, scope, change_type, command, always) **+ path_glob + framework**. Path_glob cubre rules técnicas tipo "no SQL injection en `*.py`"; framework cubre rules condicionadas a stack ("usa async views en Django 4+"). Rejected `language` (redundante con path_glob), `environment` (fuera de scope inicial — DEVOPS-specific puede añadirse en EVOL futura), `tool` (todo el corpus asume Claude Code).
- **Scope:** **ambos espejados** meta-framework + proyectos materializados. El meta-framework también sufre el problema de salience al evolucionar EVOLs — el dogfooding aplica. Rejected solo-template (deja al meta sufriendo el problema) y solo-meta-primero (rompe la invariante de espejado meta↔template).
- **Backfill ADRs:** **DROP** — los ADRs son registros históricos; sus `[LAW]` operacionales ya viven en `constitution.md` / snapshot vía gate `check-adr-constitution-sync.sh`. Forzar `applicable_when:` retroactivo en archivos ADR los trataría como ley activa, contradiciendo ADR-EVOL-026. El discovery scanea snapshot/constitution + DCs + instructions + skills — no los ADRs.

## Scope

### Framework instruction changes

- `.claude/instructions/Factory-*.instructions.md` (20 archivos) — añadir frontmatter `applicable_when:` a cada uno (Fase 2). Mayoría serán `command in [...]` + `phase in [...]`.

### Framework skill changes

- `.claude/skills/Factory-applicability-discovery/SKILL.md` — **nuevo** (Fase 1). Implementa el algoritmo de discovery vivo y produce el block canónico.
- `.claude/skills/Factory-*/SKILL.md` (subset estructurales) — añadir `applicable_when:` opcional donde corresponda (ej. `Factory-build-verification` → `phase: [IMPLEMENT]`). Skills puramente protocolarias (Factory-rdr, Factory-agent-communication, Factory-incremental-persistence) quedan como `always: true` o sin frontmatter (default `always`).

### Framework command changes

- `.claude/commands/{setup,implement,blueprint,codesign,devops,audit,qa,backlog}.md` (8 archivos) — Step 0 obligatorio "Applicability Roll-Call" como primera sección del flow del comando.

### Framework constitutional changes

- `CLAUDE.md` (root meta) — sección "Applicability Discovery" en `## Core Protocols` con vocabulario `applicable_when:` y la regla "todo command emite roll-call on-screen como primer mensaje".
- `.context/templates/setup/claude/CLAUDE.md` — espejo idéntico (regla universal).

### Framework script changes

- `scripts/check-applicability-frontmatter.sh` — **nuevo** (Fase 1 o Fase 2). Valida sintaxis de `applicable_when:` en todos los árboles. CI hard gate.

### Framework manifest changes

- `.context/templates/setup/governance_versions.json` — añadir entradas para `Factory-applicability-discovery` (skill + template), `check-applicability-frontmatter.sh` (script + template); bumpear MINOR las 20 instructions y los skills estructurales tocados; bumpear MINOR los 8 commands; MINOR para `CLAUDE.md` raíz y template. `framework_version`: 4.0.0 → **4.1.0** (MINOR — funcionalidad nueva no breaking; el contrato `applicable_when:` ausente se trata como `always: true`, garantizando back-compat).

### Out of scope

- Backfill `applicable_when:` en archivos ADR-EVOL-* o ADRs de proyectos materializados — los ADRs son registro histórico, no ley viva.
- PreToolUse hook que bloquea Edit/Write si Step 0 no se emitió — diferido a EVOL futura si E2+E3 prueba ser saltable.
- Filtrado por `path_glob:` en tiempo de edición de archivo — diferido. En esta EVOL `path_glob:` se usa para discovery de command-start (entries con path_glob compatible con el scope se incluyen en ACTIVE).
- Eje `environment` (dev/staging/prod) — fuera de scope inicial. Si DEVOPS lo necesita, EVOL futura.

## Alternatives Considered

- **A — Solo añadir `applicable_when:` cosmético sin discovery skill ni Step 0.** Rejected — documenta intención pero no soluciona salience. El agente sigue ignorando lo que tiene cargado.
- **B — Lista pre-computada en cada `commands/*.md` ("ACTIVE rules en /implement: ...").** Rejected — congela el día que se escribe; ADRs nuevos, DCs nuevos, instructions nuevas no entran sin edición manual de los 8 commands. Mata la naturaleza viva del framework.
- **C — Hook UserPromptSubmit como mecanismo primario.** Rejected — discovery se ejecutaría en cada turn, no solo en commands; ruido alto, falsos positivos. Queda como ampliación futura si E2+E3 falla.
- **D — Solo-E3 (skill auto-invocada sin Step 0 en commands).** Rejected — invisible al diff de commands, más fácil de saltar.
- **E — Backfilleo retroactivo de `applicable_when:` en ADRs.** Rejected — trata ADRs como ley activa, contradice ADR-EVOL-026 (constitution es la ley materializada).
- **F — Vocabulario extendido (path_glob + framework + language + environment + tool).** Rejected en este alcance — `language` redundante con path_glob, `environment` y `tool` fuera de necesidad inmediata. Vocabulario mínimo extensible.

## Consequences

- **Salience reforzada:** cada comando empieza con un commitment escrito, on-screen, que enumera lo aplicable. El agente no puede alegar que olvidó una rule listada en el roll-call inicial.
- **Framework vivo preservado:** un DC nuevo añadido a `defect-prevention.md` con `applicable_when: phase in [IMPLEMENT]` aparece en ACTIVE en el siguiente `/implement --build` sin tocar comandos ni skills. Una instruction nueva con `applicable_when: command in [implement]` igual.
- **Auditabilidad:** el discovery_hash en el block detecta drift — si frontmatters cambian mid-session, el hash cambia y el siguiente turn re-discovery.
- **Coste por turn:** discovery escanea ~50-70 frontmatters (instructions + skills + DCs). Lectura barata (solo header YAML). Cacheable dentro del mismo command.
- **MINOR bump (`4.0.0 → 4.1.0`):** funcionalidad nueva no-breaking. Entries sin `applicable_when:` se interpretan como `always: true` durante migración — back-compat garantizada.
- **Plan de retirada:** si tras 2-3 semanas el ADP no reduce violaciones percibidas o introduce más fricción que valor, EVOL de retirada. El backfill de `applicable_when:` puede mantenerse como metadata neutra.
- **Riesgo conocido:** el agente puede emitir el block y luego ignorarlo (teatro). Mitigación incremental — empezar con E2+E3 (declaración voluntaria); si falla en uso real, ampliar con E1 (PreToolUse hook bloqueante) en EVOL posterior.

## Constitution Amendment

> **Yes** — esta EVOL introduce una operational rule universal: "todo comando emite Applicability Roll-Call on-screen como primer mensaje, antes de cualquier acción". Se materializa en `CLAUDE.md` (meta repo) `## Core Protocols` y en `.context/templates/setup/claude/CLAUDE.md` (template, espejo) en el mismo PR que flipa el ADR a `accepted`. La regla es marcada con `[LAW]` para que el snapshot generator la extraiga al curado constitucional.

## Traceability

- Branch: `feature/EVOL-028-applicability-discovery-protocol`
- Triggered by: usuario reporta "el contexto se vuelve difuso y los agentes olvidan aplicar rules antes de summarization" (chat 2026-05-06).
- Verification (planned, ver Verificación end-to-end del plan): integration tests (4 hard gates) — roll-call on-screen, living-entity test (DC nuevo aparece next turn), filtro por scope, filtro por path_glob; capa behavioral (best-effort, no bloquea); capa no-regresión (BVL + banner + freshness intactos).
- Status: **proposed**. Acceptance flips a `accepted` cuando Fase 1 esté implementada y revisada — gate `check-adr-constitution-sync.sh` exigirá amendment de `CLAUDE.md` en el mismo commit del flip.

## Execution Outcome

| # | Task | Result | Commit |
|---|---|---|---|
| 1 | Branch `feature/EVOL-028-applicability-discovery-protocol` from `origin/main` | done | — |
| 2 | ADR skeleton at status `proposed` capturing 4 RDR ratifications | in progress | (this commit) |
| 3 | Fase 1 — Skill `Factory-applicability-discovery` written (meta + template) | pending | — |
| 4 | Fase 1 — Vocabulary `applicable_when:` documented in `CLAUDE.md` (meta + template) | pending | — |
| 5 | Fase 1 — `scripts/check-applicability-frontmatter.sh` written + CI gate | pending | — |
| 6 | Fase 2 — Backfill `applicable_when:` en 20 instructions | pending | — |
| 7 | Fase 2 — Backfill `applicable_when:` en skills estructurales | pending | — |
| 8 | Fase 3 — Step 0 wired en los 8 commands | pending | — |
| 9 | Manifest bumps + `framework_version` 4.0.0 → 4.1.0 | pending | — |
| 10 | Status flip `proposed` → `accepted` con CLAUDE.md amendment | pending | — |
