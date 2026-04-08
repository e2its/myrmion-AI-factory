**See detailed documentation**: [review_retry_tracking.md](.github/review_retry_tracking.md)

# 📋 Workflow Orchestration - Master Reference

**Validated Workflow Sequence (v8.2.0 - Dynamic Environments + Flexible DEVOPS + Merge-Before-Prod)**

---

### 🔍 AUDIT — Independent Technical Due Diligence (Outside Main Workflow)

```
AUDIT ──── can run at ANY time ────────────────────────────────────────────────────────────────────────────────────────────
           • Typically BEFORE /SETUP --init (brownfield assessment)
           • Or anytime to assess workspace health, risks, or vendor maturity
           • Does NOT require docs/constitution.md or any governance rules
           • Analyzes the actual workspace and organization reality
           • Output: docs/technical_due.md (optional input that can inform SETUP questions)
           • NEVER blocks the main workflow — fully autonomous
```

---

### 🚀 Main SDLC Workflow

```
SETUP (one-time) → CODESIGN --vision → CODESIGN (PO↔UX, auto-approves) → BLUEPRINT (ARCH↔QA, --approve required) → IMPLEMENT (plan → build: DEV↔REVIEW↔SEC per phase) → DEVOPS (deploy pre-prod envs) → QA (verify+DAST, auto-approves) → MERGE (PR → main + tag) → DEVOPS (deploy prod)
                                                                                                                       ↕
                                                                                                         DEVOPS (configure/approve/provision)
                                                                                                   can happen anytime after BLUEPRINT approval:
                                                                                                   before, during, or after IMPLEMENT
```

> **Dynamic Environments:** The environments in the pipeline (dev, staging, UAT, etc.) are NOT hardcoded.
> They are read from `docs/rules/ci-cd.instructions.md` `environments[]` configuration.
> A project may have `dev → prod` or `dev → staging → UAT → prod` — the pipeline adapts.
> The only invariant: **MERGE always happens BEFORE production deployment** (deploy from main/tag, never from feature branch).

## DEVOPS Integration Points (Flexible Positioning — v8.2.0)

DEVOPS configure/approve/provision can happen at **any point** after BLUEPRINT approval. The only hard prerequisite is `design.md APPROVED` + `test_plan.md APPROVED`. DEVOPS does NOT depend on IMPLEMENT.

- **Path A — Early (pre-IMPLEMENT)**: `/DEVOPS --configure {ID}` → `--provision {ID} --env {ENV}` before coding starts. Useful when developers need infrastructure (databases, queues) for local/integration testing during implementation.
- **Path B — Late (post-IMPLEMENT)**: `/DEVOPS --configure {ID}` → `--provision {ID} --env {ENV}` after code is built. Useful for simpler features or when infrastructure is already shared. **REQUIRED before deployment** — cannot deploy without an APPROVED `devops_plan.md` and provisioned environment.
- **Path C — Parallel**: `/DEVOPS --configure {ID}` after BLUEPRINT, `/DEVOPS --provision {ID} --env {ENV}` after IMPLEMENT. Mix and match as needed. (Env-scoped regeneration uses `/DEVOPS --provision --env {ENV}` without ID.)
- **Deployment (always post-IMPLEMENT)**: `/DEVOPS --deploy {ID} --env {PRE_PROD_ENV}` requires both `dev_plan.md: IMPLEMENTED_AND_VERIFIED` AND `devops_plan.md: APPROVED` with environment ACTIVE.
- **Post-MERGE**: `/DEVOPS --deploy {ID} --env {PROD_ENV}` — deploy to production **from main branch/tag** after PR merge and QA approval.

> **CRITICAL:** Production deployment happens AFTER merge to main (deploy from tag/main). Never deploy to production from a feature branch.

## Implementation Phase (IMPLEMENT)

A single agent with triple personality (💻 DEV hat ↔ 🔍 REVIEW hat ↔ 🛡️ SEC hat) owns the full lifecycle: planning (`--plan`) → implementation per phase A→B→C (`--build`). Within each phase:

1. **💻 DEV hat**: Implements code following TDD (RED → GREEN → REFACTOR)
2. **🔍 REVIEW hat**: Verifies governance compliance, quality, and design drift
3. **🛡️ SEC hat**: Scans for SAST vulnerabilities

Fix loops happen inline — if REVIEW or SEC finds issues, DEV hat fixes them immediately before next phase.

**Checkbox-Driven Execution:** All tasks in `dev_plan.md` use `- [ ]` checkboxes. Agents read unchecked items, execute, and mark `[x]` atomically. Four task types:
- **Original `[A/B/C.N]`**: Tasks from `--plan` — initial implementation
- **Delta `[D.N]`**: Tasks from `--refine` — upstream spec changes (iteration sync)
- **Adjustment `[ADJ-N]`**: Tasks from `--refine` — user feedback within scope
- **Fix `[FIX-N]`**: Tasks from `--fix` — bug fixes from QA rejection or smoke test failure

**Completion Gate:** Status cannot reach `IMPLEMENTED_AND_VERIFIED` unless ALL tasks are resolved: each task must be `[x]` (completed) or explicitly `@skip` with justification.

**QA↔FIX Loop:** When QA rejects → `IMPLEMENT --fix` generates `[FIX-N]` tasks → executes via TDD → returns to `IMPLEMENTED_AND_VERIFIED` → Factory Smart Redirect computes `QA --verify` as next step. Loop repeats until all checks pass.

**Key rules:**
- `/IMPLEMENT --plan` generates `dev_plan.md` (requires BLUEPRINT APPROVED)
- `/IMPLEMENT --build` consumes `dev_plan.md` from `--plan`
- Produces `peer_review_{timestamp}.md` + `sec_audit.md` (organized by phase)
- Creates Draft PR automatically at completion

## Co-Creation Phase (CODESIGN)

A single agent with dual personality (🎩 PO hat ↔ 🎨 UX hat) iterates dynamically producing three co-created artifacts:

- **spec.feature**: Gherkin specification (PO leads, UX validates)
- **mock.html**: Visual mockup (UX leads, PO validates)
- **user_journey.md**: Event Storming simplificado with typed Data Schemas (co-created)

The `user_journey.md` Data Schemas are the **source of truth** for data contracts — downstream agents formalize but do NOT invent business fields.

### Global Vision (Mandatory Pre-Step)

Before iterating individual features, `/CODESIGN --vision` generates app-level visual artifacts that ensure cross-feature consistency:

- **vision.md**: Manifiesto de visión global con frontmatter
- **app_shell.html**: App Shell Mock (header, sidebar, footer, nav) — plantilla visual base
- **style_guide.html**: Guía de estilo visual interactiva
- **page_templates.html**: Plantillas de página tipo (dashboard, list, detail, form, error, empty state)
- **component_library.html**: Librería de componentes reutilizables
- **navigation_map.md**: Mapa de navegación con enlaces entre páginas

**Always required** for projects with `frontend.framework != "None"`. Vision adapts its input mode based on available resources: External Design System, app mockup, existing code layout, or none (from scratch). The same 6 artifacts are always generated. Factory Smart Redirect computes `CODESIGN --vision` as next step after `SETUP --generate`.

**Template Composition:** After vision approval, `/CODESIGN --start` uses template composition — shell from `app_shell.html` + feature content injected into `<!-- FEATURE_CONTENT_SLOT -->`. This ensures all feature mocks share consistent header, nav, footer, and styles.

**Key rules:**
- `/CODESIGN --start` initiates the co-creation cycle
- Auto-approval (v8.2.0): when all 12 validations pass, artifacts are auto-approved
- After approval, **BLUEPRINT** (ARCH↔QA co-design) can begin

## Blueprint Phase (BLUEPRINT)

A single agent with dual personality (🏗️ ARCH hat ↔ 🧪 QA hat) co-designs the technical solution and test strategy simultaneously, producing two co-designed artifacts:

- **design.md**: Technical design with contracts, C4, inventory (🏗️ ARCH hat leads)
- **test_plan.md**: Test strategy with acceptance + edge cases (🧪 QA hat leads)

Cross-pollination is inline: ARCH contracts inform QA test cases, QA edge cases refine ARCH error handling.

**Key rules:**
- Requires `spec.feature` + `user_journey.md` + `mock.html` with `status: APPROVED`
- Both artifacts are co-designed in a single `/BLUEPRINT --start` session
- **IMPLEMENT cannot start** until `/BLUEPRINT --approve` marks both artifacts APPROVED
- 🏗️ ARCH hat derives technical contracts (API schemas, DB models) from user_journey.md Data Schemas
- 🏗️ ARCH hat can freely add technical fields (id, timestamps, audit) but needs RDR for business field modifications
- 🧪 QA hat only covers design-time test planning; post-staging verification stays with `/QA --verify`

## Agent Handoff Sequence

| # | Agent | Command | Output Points To | Auto-Trigger | Status |
|---|-------|---------|------------------|--------------|--------|
| 0.5 | CODESIGN | --vision | vision.md + app_shell.html + style_guide.html + page_templates.html + component_library.html + navigation_map.md | Manual (always required after SETUP for frontend projects) | DRAFT |
| 0.6 | CODESIGN | --vision-approve | Enables template composition for per-feature mocks | Manual | APPROVED |
| 1 | CODESIGN | --start | spec.feature + mock.html + user_journey.md (co-creation) | N/A | DRAFT |
| 2 | CODESIGN | --start / --refine | Auto-approves when 12/12 validations pass. BLUEPRINT (ARCH↔QA co-design) | Auto (v8.2.0) | APPROVED |
| 3 | BLUEPRINT | --start | design.md + test_plan.md (co-designed) | Manual | DRAFT |
| 3a | (BLUEPRINT 🏗️ ARCH hat) | co-design | Contracts, C4, inventory | Inline | CO-DESIGNING |
| 3b | (BLUEPRINT 🧪 QA hat) | co-design | Test strategy, edge cases | Inline | CO-DESIGNING |
| 4 | BLUEPRINT | --approve | design.md + test_plan.md ready | Manual | APPROVED |
| 5↓ | IMPLEMENT | --plan | dev_plan.md (implementation tasks) | Manual (requires BLUEPRINT APPROVED) | DRAFT |
|   | **↕ DEVOPS (flexible — any time after BLUEPRINT APPROVED, before/during/after IMPLEMENT)** | | | | |
| ↕ | DEVOPS | --configure | devops_plan.md + secrets (requires BLUEPRINT APPROVED, NOT IMPLEMENT). Auto-approves when 7/7 checks pass. | Auto (v8.2.0) | APPROVED |
| ↕ | DEVOPS | --provision [ID] --env {ENV} | With ID: feature infra. Without ID: full env regeneration from registry (v8.3.0) | Manual | PROVISIONED |
| 10 | IMPLEMENT | --build | Code + Review + SAST per phase | Manual (recommended after --plan) | BUILDING |
| 10a | (IMPLEMENT 💻 DEV hat) | per phase | Tests + Code (TDD) | Inline | IN_PROGRESS |
| 10b | (IMPLEMENT 🔍 REVIEW hat) | per phase | Governance + Quality check | Inline | PASS/FAIL |
| 10c | (IMPLEMENT 🛡️ SEC hat) | per phase | SAST scan | Inline | SECURE/VULNERABLE |
| 11 | IMPLEMENT | (completion) | peer_review + sec_audit + Draft PR | ✅ AUTO (Draft PR) | IMPLEMENTED_AND_VERIFIED |
| 12 | DEVOPS | --deploy --env {PRE_PROD_ENV} | Pre-production environment (env from ci-cd.instructions.md) | Manual (suggested by IMPLEMENT) | DEPLOYED |
| 13 | QA | --verify | Final E2E + compliance + DAST (🛡️ SEC hat). Checkbox-driven: generates `- [ ]` verification checklist, marks `[x]` on execution. Auto-approves when ALL checkboxes [x] AND verdict APPROVED. | Auto (v8.2.0) | APPROVED |
| 16 | - | MERGE | PR merge to main + version tag | Manual (PR workflow) | ✅ MERGED |
| 17 | DEVOPS | --deploy --env {PROD_ENV} | Production deployment **from main/tag** | Manual | DEPLOYED |

## Key Transitions (Auto-triggered)

1. **IMPLEMENT --plan → IMPLEMENT --build** (recommended, not automatic)
2. **IMPLEMENT --build completes → Draft PR created** (automatic)
3. **IMPLEMENT --build completes → Smart Redirect Protocol** computes next steps from artifact frontmatter (dynamic, no hardcoded env)

## Key Decision Points

1. **CODESIGN auto-approval (v8.2.0)**: When all 12 validations pass during `--start`/`--refine`, artifacts are auto-approved. Unlocks BLUEPRINT.
2. **BLUEPRINT --approve**: The ONLY mandatory manual checkpoint. Unlocks BOTH `/IMPLEMENT --plan` AND `/DEVOPS --configure` (parallel tracks).
3. **DEVOPS --configure (flexible, auto-approves v8.2.0)**: Can run at any time after BLUEPRINT approval — before, during, or after IMPLEMENT. Auto-approves when 7/7 checks pass. Required before deployment but NOT before implementation.
4. **DEVOPS --deploy (always post-IMPLEMENT)**: Requires BOTH `dev_plan.md: IMPLEMENTED_AND_VERIFIED` AND `devops_plan.md: APPROVED` with environment ACTIVE.
5. **IMPLEMENT --build**: Inline review + SAST per phase (replaces sequential REVIEW→SEC)
6. **QA --verify (includes DAST, auto-approves v8.2.0)**: E2E + DAST scan on pre-prod (🛡️ SEC hat) — auto-approves when verdict APPROVED, unlocks merge

## File Sequence

```
docs/ux/vision/                        # Global Vision artifacts (CODESIGN --vision)
  ├── vision.md                        # Vision manifest with frontmatter
  ├── app_shell.html                   # App Shell (header, sidebar, footer, nav)
  ├── style_guide.html                 # Interactive style guide
  ├── page_templates.html              # Page type templates (dashboard, list, detail, form, error, empty)
  ├── component_library.html           # Reusable component library
  └── navigation_map.md                # Navigation map with page links

docs/spec/{{FEATURE_ID}}/
  ├── spec.feature (CODESIGN creates & approves)
  ├── mock.html (CODESIGN creates & approves — inherits shell from vision)
  ├── user_journey.md (CODESIGN creates & approves - Data Schema source of truth)
  │
  │── ┌─── BLUEPRINT (ARCH↔QA co-design) ─────────────┐
  │   │                                                  │
  ├── │  design.md (🏗️ ARCH hat leads, co-designed)      │
  ├── │  test_plan.md (🧪 QA hat leads, co-designed)     │
  ├── │  adr/ (🏗️ ARCH hat generates ADRs if needed)    │
  │   └──────────────────────────────────────────────────┘
  │
  ├── devops_plan.md (DEVOPS creates — optional, after BLUEPRINT)
  ├── dev_plan.md (IMPLEMENT creates — requires BLUEPRINT APPROVED)
  ├── src/ (IMPLEMENT implements)
  ├── tests/ (IMPLEMENT implements)
  │
  ├── review/ (IMPLEMENT 🔍 REVIEW hat creates reports)
  │   └── peer_review_{{timestamp}}.md
  │
  ├── qa/ (QA creates reports twice)
  │   ├── qa_report_{{timestamp}}.md (after plan)
  │   └── qa_report_final_{{timestamp}}.md (verify phase)
  │
  └── security/ (IMPLEMENT 🛡️ SEC hat creates reports)
      └── sec_audit_{{timestamp}}.md

infra/
  ├── modules/                         # Shared IaC modules (system scope, ≥2 consumers)
  └── features/{{FEATURE_ID}}/          # Feature-exclusive IaC (DEVOPS --provision creates)
      ├── {entry_point} (IaC via iac_descriptor: main.tf, Pulumi.yaml, cdk/, docker-compose.yml, etc.)
      ├── variables/config
      ├── outputs
      └── deployment_report_{{timestamp}}.md

config/
  └── infrastructure_registry.json      # Resource registry (scope, data_bearing, consumers)
```

## Phase Gates (Quality & Security Checkpoints)

1. **Co-Creation Gate (CODESIGN)**: PO↔UX iterate dynamically until spec + mockup + user journey converge. All 3 artifacts APPROVED before BLUEPRINT
2. **Blueprint Phase (BLUEPRINT)**: ARCH↔QA co-design → technical solution + test strategy + **Section 5: Infrastructure Needs** (resource declarations with type, engine, scope, data_bearing, sizing) aligned before code (informed by user_journey Data Schemas)
3. **DEVOPS plan (flexible)**: Infrastructure planning — can happen at any point after BLUEPRINT approval. Reads Section 5 + `iac_descriptor` + `infrastructure_registry.json`. Does NOT depend on IMPLEMENT.
4. **IMPLEMENT plan gate**: Cannot start until BLUEPRINT APPROVED (design.md + test_plan.md). Can start independently of DEVOPS.
5. **IMPLEMENT build**: Per-phase verification (DEV↔REVIEW↔SEC inline)
6. **Pre-prod deployment**: DEVOPS deploys to pre-prod env(s) — requires BOTH `dev_plan.md: IMPLEMENTED_AND_VERIFIED` AND `devops_plan.md: APPROVED` + environment ACTIVE (env from ci-cd.instructions.md)
7. **DAST scan**: QA --verify includes DAST (🛡️ SEC hat) on pre-prod
8. **Shift-Right (QA verify)**: E2E tests + DAST + final compliance → production readiness
9. **Merge to main**: PR merge + version tag after QA approval
10. **Production deployment**: DEVOPS deploys to prod **from main/tag** after merge

---

## Smart Redirect Protocol (v1.0.0)

**ALL "next step" suggestions** after any agent command are computed dynamically by reading the **actual frontmatter status** of all feature artifacts. No hardcoded redirections.

See full protocol in `copilot-instructions.md` → **🧭 SMART REDIRECT PROTOCOL**.

**Key principle:** After every command, agents must:
1. Read frontmatter of ALL feature artifacts (spec.feature, mock.html, user_journey.md, design.md, test_plan.md, devops_plan.md, dev_plan.md, qa_report)
2. Compute the true workflow state from the artifact statuses
3. Suggest ONLY the correct next action(s) based on what actually exists and its status
4. NEVER suggest creating an artifact that already exists with status APPROVED
5. NEVER hardcode environment names — always read from `docs/rules/ci-cd.instructions.md`

---

## Important Notes

- **CODESIGN**: A single agent with dual personality (🎩 PO hat + 🎨 UX hat) produces spec + mock + journey together
- **BLUEPRINT**: A single agent with dual personality (🏗️ ARCH hat + 🧪 QA hat) co-designs design.md + test_plan.md together
- **QA has dual roles**: Blueprint (🧪 QA hat in BLUEPRINT, plan phase) + Shift-Right (`/QA --verify`, post-staging)
- **IMPLEMENT**: Single agent with 3 hats (💻 DEV ↔ 🔍 REVIEW ↔ 🛡️ SEC), owns full lifecycle: planning (`--plan`) → implementation per phase A→B→C (`--build`)
- **Review retry tracking**: Handled inline by IMPLEMENT (3 rejections per phase → BLUEPRINT escalation)
- **user_journey.md is Data Schema source of truth**: ARCH hat derives contracts from it, not the other way around
- **Schema Drift**: REVIEW hat in IMPLEMENT checks implementation against user_journey.md Data Schemas. Business field mismatches are BLOCKERS
- **SAST inline, DAST in QA --verify**: SAST runs per-phase inside IMPLEMENT. DAST runs within `/QA --verify` (🛡️ SEC hat) on staging.
- **PR lifecycle**: Draft PR created at end of `/IMPLEMENT --build`. PR set to **Ready for Review** after QA approvals.
- **Merge policy**: PRs are merged using **merge commits only** (never squash, never rebase), aligned with branching.instructions.md.
- **IaC is descriptor-driven**: DEVOPS uses `iac_descriptor` meta-model from constitution.md (6 universal concepts). No hardcoded IF/ELIF for IaC tools.
- **IaC creation chain**: SETUP (scaffolds `infra/` dirs + `iac_descriptor` + `infrastructure_registry.json`) → BLUEPRINT (Section 5: Infrastructure Needs in design.md) → DEVOPS --configure (reads Section 5 + descriptor + registry) → DEVOPS --provision [ID] (creates IaC files in `infra/features/{ID}/` or regenerates full env from registry)
- **Dual-mode commands (v8.3.0)**: `--provision`, `--deploy`, `--suspend`, `--resume`, `--rollback`, `--teardown`, `--status` accept optional FEATURE_ID. With ID → feature-scoped. Without ID → env-scoped. Useful for monoliths, disaster recovery, full-env operations.
- **Data Protection (Guardrail 6)**: Resources with `data_bearing: true` in Infrastructure Registry require confirmed backup before teardown/destructive migration.
- **IaC governance validation**: `scripts/validate-iac.sh --strict` enforces naming, secrets, documentation. `scripts/validate-migrations.sh --strict` validates migration safety.

## Review Retry Tracking (Deadlock Prevention)

When IMPLEMENT 🔍 REVIEW hat rejects code with BLOCKERS:
1. 💻 DEV hat executes fix → increments `review_attempt_count` in `dev_plan.md`
2. After fixes, DEV hat re-submits to REVIEW hat
3. If rejection happens AGAIN and `review_attempt_count >= 3`:
   - ❌ Escalation to `/BLUEPRINT --review-conflict {{FEATURE_ID}}`
   - Recommendation: Blueprint agent (🏗️ ARCH hat) resolves misalignment between design.md and review requirements
   - Output: "Max review attempts exceeded. Design/implementation mismatch detected."

**Purpose**: Prevents infinite review loops when design is fundamentally misaligned with requirements

---

## Intelligent Orchestration Protocol (IOP v1.0.0)

**ALL user interactions** — whether explicit commands, natural language requests, or ad-hoc operations — are subject to the same governance standards. The system detects user intent and routes accordingly:

| Category | Description | Governance Level |
|----------|-------------|-----------------|
| **FRAMEWORK_COMMAND** | Maps to a single agent command (e.g., "design USR-001" → `/BLUEPRINT --start USR-001`) | Full: PRE-ROUTING + agent + POST-COMMAND |
| **FRAMEWORK_SEQUENCE** | Maps to ordered sequence of commands (e.g., "build complete feature") | Full: Multi-step orchestration via Smart Redirect |
| **GOVERNANCE_BOUND_OPERATION** | Ad-hoc file modifications (bug fixes, refactoring, config changes) | Equivalent: branching + locks + protected paths + rules + worklog + commit |
| **SCM_OPERATION** | Source control operations (commit, push, PR, merge, branch) | Branch-aware: naming conventions, merge enforcement, conventional commits |
| **READ_ONLY** | Information queries (explain, status, search) | None: direct answer |

**Key principle:** No file modification in the codebase is exempt from project governance, even if the operation doesn't map to a framework command.

See full protocol in `copilot-instructions.md` → **🚦 INTELLIGENT ORCHESTRATION PROTOCOL**.
