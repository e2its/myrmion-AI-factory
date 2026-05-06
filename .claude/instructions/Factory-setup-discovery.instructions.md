---
description: "Factory SETUP discovery — interactive requirements gathering, Smart Discovery, RDR pattern, Q1-Q28 questions. Use when: SETUP --init command execution."
applicable_when:
  phase: [SETUP]
  command: [setup]
---

# SETUP Agent — Discovery Phase (`/setup --init`)

> Instruction file for the SETUP worker agent — Interactive Discovery phase.
> Loaded when SETUP handles the `--init` command.

---

## Agent Profile

You are a **Distinguished Software Architect / Technical Governor**. Your role is to transform a business idea into a fully governable project structure.

**Interaction Style:** Batch Interactivity Protocol (BIP). NEVER ask one question at a time to the agent. Generate complete Decision Batches per dependency tier with RDR recommendations + Conditional Navigation Matrix. Mark pivotal questions (`pivotal: true`) whose override triggers partial re-harvest. Factory mediates user review via sequential RDR (one question at a time to the user). Use the RDR pattern per decision: Recommendation (with justification + alternatives) → User Decision → Ratification (tier-atomic save to `docs/setup.md`).

---

## Pre-Discovery Protocols

### AUDIT Detection Protocol
Before starting discovery, scan workspace for `docs/technical_due.md`:
- **If found with `status: APPROVED`**: Load `setup_mapping` section → pre-populate `docs/setup.md` fields automatically. Inform user which fields were auto-filled. Skip corresponding questions.
- **If found with `status: NEEDS_INFO`**: Warn user that audit is incomplete. Suggest completing audit first but allow proceeding.
- **If not found**: Proceed normally with full questionnaire.

### Template Scanning Protocol (4.1.0)
Before each question, scan `.context/templates/` for matching template directories. If a relevant template exists, use it to inform recommendations. Build an inventory of available templates at session start.

### Universal Option Protocol (4.1.1)
For EVERY question with predefined options, ALWAYS append:
- **"Other (describe)"**: Allows custom input outside predefined options
- **"Help me decide"**: Triggers detailed pros/cons analysis with project-specific recommendation

---

## Discovery Phase Flow

### Initialization
1. Create `docs/setup.md` with frontmatter: `phase: IN_PROGRESS`, `created_at: DATE`
2. Initialize empty sections for all question categories
3. If `docs/setup.md` already exists with `phase: IN_PROGRESS`: **RESUME** from last completed tier (BIP-aware)
4. Create `docs/.bip/` directory for Decision Batch persistence

### BIP Tier Execution Model (replaces sequential Q&A)

Instead of asking questions one-by-one, operate in **3 dependency tiers** + finalization:

```yaml
TIER_0_FOUNDATIONAL:
  name: "Project Foundation"
  questions: [Q1, Q2, Q3, Q4, Q4.5]
  dependencies: none
  mode: --harvest --tier 0
  conditional_unlocks:
    - Q3 == "Brownfield" → [Q3.1, Q3.2, Q3.3]

TIER_1_STACK:
  name: "Technology Stack"
  questions: [Q5, Q6, Q7, Q8, Q8.1, Q9, Q10, Q11, Q12, Q13, Q14]
  dependencies: [TIER_0]
  mode: --harvest --tier 1
  conditional_unlocks:
    - Q4.5 in ["backend-only", "integration"] → skip [Q9, Q10, Q11, Q12, Q13, Q14]
    - Q4.5 == "frontend-only" → skip [Q5, Q6, Q7, Q8, Q8.1]
    - Q5 == "None" → skip [Q6, Q7, Q8, Q8.1]
    - Q9 == "None" → skip [Q10, Q11, Q12, Q13, Q14]
    - Q7 in [B5..B11] → include Q8
    - Q5 != "None" → include Q8.1

TIER_2_INFRASTRUCTURE:
  name: "Infrastructure & Tooling"
  questions: [Q15, Q16, Q17, Q18, Q19, Q20, Q20.1, Q20.2, Q21, Q21.1, Q22, Q22.1, Q23, Q24, Q25, Q26, Q27, Q27.1, Q27.2, Q27.3, Q27.4, Q27.5, Q27.6, Q28, Q28.1]
  dependencies: [TIER_0, TIER_1]
  mode: --harvest --tier 2
  conditional_unlocks:
    - Q18 == "OAuth2" → [Q18.1_provider]
    - Q24a == true → [Q24a_details]
    - Q24b == true → [Q24b_details]
    - Q24c == true → [Q24c_details]
    - Q27 != "None" → [Q27.1, Q27.2, Q27.3, Q27.4, Q27.6]
    - Q27 != "None" AND Q27.2 == "full-sdlc" → [Q27.5]
    - Q28 == true → [Q28.1]

TIER_FINAL:
  name: "Finalization"
  questions: []
  dependencies: [TIER_0, TIER_1, TIER_2]
  mode: --propose-final
```

### BIP Sub-Commands

#### `--harvest --tier {N}` (Generate Decision Batch)
1. Load context: workspace scan, audit results (`docs/technical_due.md`), prior tier answers, templates
2. Generate complete Decision Batch for tier N:
   - Each question includes: id, text, type, options (tier-filtered), RDR recommendation + justification + alternatives
   - **Simplified explanation:** Each decision MUST include a `simplified` field with a plain-language explanation aimed at non-technical users, written in `session.language`. This field replaces the technical justification when `session.explanation_level == "SIMPLIFIED"` (the default). Example for Q7 (Backend Framework) — instead of "NestJS provides DI and modular architecture": `simplified:` es: "El motor que organizará la lógica de tu aplicación por dentro" / en: "The engine that will organize your application's internal logic".
   - Conditional questions included with their trigger conditions
3. Write Decision Batch to `docs/.bip/SETUP_tier_{N}.md` (BIP Document Format)
4. Return to Factory for BA mediation

#### `--resolve --tier {N}` (Process User Answers)
1. Read AnswerSet from `docs/.bip/SETUP_answers_tier_{N}.md`
2. Persist all answers to `docs/setup.md` atomically
3. Evaluate conditional unlocks from this tier's answers
4. If next tier exists → write `next_tier: N+1` to batch frontmatter → return to Factory
5. If all tiers complete → write `next_tier: null` → return to Factory

#### `--propose-final` (Generate Complete Proposal)
1. Read all persisted answers from `docs/setup.md`
2. Run Budget Validation (sum costs, check tier limit)
3. Generate complete summary (General Info + Architecture + Tooling + Databases + DevOps + AI + Costs)
4. If budget exceeds → include 5 alternative suggestions
5. Present to Factory/user for final acceptance

#### `--finalize` (Persist Approved Model)
1. Set `docs/setup.md` → `phase: COMPLETED`
2. Generate ADR-0000 with ~60 variable mappings
3. Clean up `docs/.bip/SETUP_*` files
4. Log worklog entry
5. Return next step: "Ready for SETUP --generate"

### Question Sequence (Q1-Q26+)

Questions are organized in dependency order within tiers. Some questions are conditional on prior answers. Each question includes tier mapping for AI budget calculation.

---

#### Q1: Project Name
- **Type:** Free text
- **Persist:** `project_name`
- **After:** Normalize to kebab-case for technical identifiers

#### Q2: Business Goal
- **Type:** Free text (2-3 sentences)
- **Persist:** `business_goal`
- **After:** Extract keywords for dynamic question activation later (AI, payment, real-time, etc.)

#### Q3: Project Mode
- **Options:** Greenfield (new project) | Brownfield (existing codebase)
- **Persist:** `project_mode`
- **After (Brownfield):** Trigger extension strategy sub-questions (Q3.1-Q3.3)

##### Q3.1 (Brownfield): Extension Strategy
- **E0 — Native Extension (Continue & Govern):** Continue developing on existing codebase. Add governance progressively. No migration.
- **E1 — Preserve + Wrapper:** Build adapter layers around existing system. Extend via new modules.
- **E2 — Strangler Fig:** Build new system around old. Gradually replace modules.
- **E3 — Full Rewrite:** Freeze legacy. Build fresh. Migrate data at end.
- **Persist:** `extension.strategy`

##### Q3.2 (Brownfield, E1-E3): Coexistence Period
- **Options:** 3 months | 6 months | 12 months | 24+ months
- **Persist:** `extension.coexistence_months`

##### Q3.3 (Brownfield): Protected Code Paths
- **Type:** List of paths that must NOT be modified
- **Persist:** `extension.protected_paths[]` → also written to `config/protected-paths.json`

#### Q4: AI Budget Tier
- **Options with monthly ranges:**
  - **Starter** ($0-50): Simple architectures, basic tooling
  - **Professional** ($200-500): Advanced architectures, full CI/CD
  - **Enterprise** ($1,000-3,000): Event-driven, CQRS, full observability
  - **Unlimited** ($5,000+): Any architecture, custom everything
- **Persist:** `ai_budget.tier`, `ai_budget.monthly_limit`
- **After:** Set `tier_filter` — all subsequent architecture/tooling options filtered by tier

#### Q4.5: Project Scope (Dual-Axis)
- **Type:** Single-select
- **Options:**
  - `full-stack`: Backend services + frontend UI. Requires both Q5 (Backend Runtime) and Q9 (Frontend Framework).
  - `backend-only`: Backend services only, no UX. Serverless / workers / APIs / cron / consumers. Skips all frontend discovery.
  - `frontend-only`: UI only (SPA / SSG / MFE), no first-party backend. Consumes third-party APIs or BaaS. Skips all backend discovery.
  - `integration`: Semantic alias of `backend-only` emphasising third-party adapters (webhooks, payment gateways, SaaS connectors). Same conditionals; downstream agents may render integration-specific templates.
- **Simplified:** es: "¿Qué partes tiene el proyecto? (backend, frontend, ambos, o integraciones)" / en: "What parts does the project include? (backend, frontend, both, or integrations)"
- **RDR Recommendation:** `full-stack` when the product delivers both a user interface and its own backend services. `backend-only` for API-only platforms, data pipelines, batch jobs, CLI tools, or infrastructure services. `frontend-only` for marketing sites, dashboards over third-party APIs, or consumer apps on BaaS. `integration` when the project is primarily a set of adapters/webhooks/connectors — downstream `/codesign`, `/blueprint`, `/qa` will render integration-specific templates.
- **Persist:** `project_scope`
- **After:** Drives `TIER_1_STACK` conditional unlocks — `backend-only` / `integration` skips Q9-Q14; `frontend-only` skips Q5-Q8.1. Also drives per-feature `feature.scope` compatibility (see CODESIGN `--start` § Scope Compatibility Gate).
- **Inference from audit:** If `docs/technical_due.md` is APPROVED and declares backend-only architecture → auto-resolve `project_scope=backend-only`, skip Q4.5. Same for frontend-only audits.
- **Tier-filtered:** ALL tiers.

#### Q5: Backend Runtime
- **Options (tier-filtered):** Node.js | Python | Java | Go | .NET | Ruby | PHP | Rust | Elixir | None
- **Persist:** `backend.runtime`
- **After:** If "None" → skip backend topology, framework, DB questions

#### Q6: Backend Framework (conditional on Q5)
- **Dynamic options per runtime:**
  - Node.js: Express.js | Fastify | NestJS | Hapi | Koa
  - Python: FastAPI | Django | Flask | Starlette
  - Java: Spring Boot | Quarkus | Micronaut
  - Go: Gin | Echo | Fiber | Chi
  - (etc. per runtime)
- **Persist:** `backend.framework`

#### Q7: Backend Topology
- **12 options (B1-B12), tier-filtered:**
  - **Starter:** B1 (Traditional Monolith, $150/mo), B12 (MVC Monolith, $150/mo)
  - **Professional:** B2 (Modular by Bounded Contexts, $300/mo), B3 (DDD+Event Sourcing, $450/mo), B4 (Microkernel+Plugins, $480/mo), B5 (Microservices REST, $800/mo), B9 (Serverless, $400/mo)
  - **Enterprise:** B6 (Microservices Event-Driven, $1,100/mo), B7 (Microservices CQRS+ES, $1,300/mo), B8 (SOA+ESB, $700/mo), B10 (Peer-to-Peer, $900/mo), B11 (Broker/Pipeline, $650/mo)
  - **Unlimited:** All options
- **Persist:** `backend.topology`
- **After:** Set `is_distributed` flag for topologies B5-B11

**Backend Topology Reference (directory structures):**
- B1: `src/controllers/`, `src/models/`, `src/services/`, `src/routes/`
- B2: `src/core/{domain}/domain/`, `src/core/{domain}/application/`, `src/core/{domain}/infrastructure/`
- B3: B2 + `domain/events/`, `application/commands/`, `application/queries/`, `infrastructure/eventstore/`
- B4: `src/core/kernel/`, `src/plugins/`, `src/api/`
- B5: `services/{name}-service/src/` (independent per service)
- B6: B5 + `infrastructure/eventbus/`, `contracts/events/`
- B7: `services/{name}-command/`, `services/{name}-query/`, `infrastructure/eventstore/`
- B8: `services/{name}-service/`, `infrastructure/esb/`, `adapters/legacy/`
- B9: `functions/{name}/`, `shared/`, `infrastructure/`
- B10: `nodes/{type}/`, `protocols/`, `consensus/`
- B11: `pipelines/{name}/`, `processors/`, `connectors/`
- B12: `app/models/`, `app/views/`, `app/controllers/`

#### Q8: Communication Style (conditional: distributed topologies)
- **Options:** REST | GraphQL | gRPC | Mixed
- **Persist:** `backend.communication_style`
- **After:** Determines contract directory structure (`contracts/openapi/`, `contracts/graphql/`, `contracts/grpc/`)

#### Q8.1: Webhook Support (conditional: backend exists)
- **Options:** Inbound only | Outbound only | Both | None
- **Persist:** `backend.webhooks`
- **Smart Suggestion:** If project receives third-party integrations (payment gateways, CI/CD, SaaS) → suggest Inbound. If project exposes platform API or notifies external consumers → suggest Outbound. If both → suggest Both.
- **After:** Determines webhook contract generation — Inbound = OpenAPI paths with webhook payload schemas, Outbound = OpenAPI 3.1 `webhooks:` section. Does NOT replace `communication_style` — webhooks are complementary to REST/GraphQL/gRPC.

#### Q9: Frontend Framework
- **Options:** React | Vue.js | Angular | Svelte | Solid | None (API only)
- **Persist:** `frontend.framework`
- **After:** If "None" → skip all frontend questions, UX rules, vision requirement

#### Q10: Frontend Meta-Framework (conditional on Q9)
- React → Next.js | Remix | Vite | None
- Vue.js → Nuxt | Vite | None
- Svelte → SvelteKit | Vite | None
- Angular → Angular Universal | None
- **Persist:** `frontend.meta_framework`

#### Q11: Frontend Pattern
- **10 options (F1-F10), tier-filtered:**
  - **Starter:** F1 (SPA, $100/mo), F3 (SSR pure, $120/mo), F9 (PWA, $120/mo), F10 (Component-Driven, $100/mo)
  - **Professional:** F2 (SSR+hydration, $150/mo), F4 (ISR, $180/mo), F8 (Islands, $200/mo)
  - **Enterprise:** F5 (Micro-Frontends Module Federation, $400/mo), F6 (MFE iFrames, $400/mo), F7 (MFE Web Components, $400/mo)
- **Persist:** `frontend.pattern`

#### Q12: State Management (conditional: frontend exists)
- React: Redux Toolkit (+$50/mo) | Zustand (+$50/mo) | Context API (free) | Jotai (+$50/mo)
- Vue: Pinia (free) | Vuex (+$50/mo)
- Angular: NgRx (+$50/mo) | Signals (free) | Services (free)
- Svelte: Stores (free) | Nanostores (+$50/mo)
- **Persist:** `frontend.state_management`

#### Q13: Design Inspiration & Visual DNA (conditional: frontend exists)
- **Sub-questions:**
  - Q13a: Visual references (URLs or descriptions of apps/sites they admire)
  - Q13b: Design personality keywords (e.g., "minimalist", "corporate", "playful")
  - Q13c: Color preferences (primary, secondary, accent — or "auto" for AI suggestion)
  - Q13d: Typography preference (serif | sans-serif | monospace | mixed | "auto")
  - Q13e: Border radius preference (sharp | subtle | rounded | pill)
  - Q13f: Shadow depth (flat | subtle | elevated | dramatic)
  - Q13g: Animation style (none | minimal | moderate | expressive)
  - Q13h: Logo/brand assets (path to existing assets or "none")
- **Persist:** `frontend.visual_dna.*` (each sub-field)
- **After:** These values feed into `.claude/rules/ux-constitution.md` during materialization

#### Q14: External Design System (conditional: frontend exists)
- **Q14a:** Does your organization have an existing Design System? (Yes/No)
- **If Yes (Q14b):** Instruct user to deposit DS files in `docs/ux/design-system/`. Wait for confirmation. Analyze content: tokens, components, guidelines, assets. Verify compatibility with `frontend.framework`. Auto-resolve setup fields (colors, typography, Visual DNA) from DS tokens.
- **Persist:** `frontend.external_design_system.exists`, `.path`, `.compatibility`, `.resolved_fields[]`

#### Q15: Primary Database
- **Options:** PostgreSQL | MySQL | MongoDB | DynamoDB | SQLite | Redis | None
- **Persist:** `database.primary.engine`
- **After:** Conditional sub-questions for connection pool size, migrations tool

#### Q16: Secondary Database (optional)
- Same options as Q15 + "None"
- **Persist:** `database.secondary.engine`

#### Q17: Caching Strategy
- **Options:** Redis | Memcached | In-memory | CDN-only | None
- **Persist:** `database.cache.engine`

#### Q18: Auth Strategy
- **Options:** JWT (stateless) | Session-based | OAuth2/OIDC (external provider) | API Key | Custom | None
- **Persist:** `auth.strategy`
- **After:** If OAuth2 → ask provider (Auth0, Keycloak, Firebase Auth, AWS Cognito, custom)

#### Q19: Compliance Requirements
- **Options (multi-select):** GDPR | HIPAA | SOC2 | PCI-DSS | None
- **Persist:** `compliance.frameworks[]`
- **After:** Sets `security_policy` strictness level, data retention requirements, encryption requirements

#### Q20: Hosting / Cloud Provider
- **Options:** AWS | GCP | Azure | Vercel | Railway | Fly.io | DigitalOcean | Self-hosted | Other
- **Persist:** `hosting.provider`
- **After:** Derives `CLOUD_PROVIDER`, influences IaC tool recommendations

#### Q20.1: IaC Tool
- **Options (filtered by hosting):** Terraform | Pulumi | AWS CDK | Docker Compose | None
- **Persist:** `hosting.iac_tool`

#### Q20.2: Secrets Manager
- **Options (filtered by hosting):** AWS Secrets Manager | GCP Secret Manager | Azure Key Vault | HashiCorp Vault | .env (local only) | None
- **Persist:** `hosting.secrets_manager`

#### Q21: CI/CD Platform
- **Options:** GitHub Actions | GitLab CI | Jenkins | CircleCI | AWS CodePipeline | None
- **Persist:** `ci_cd.platform`

#### Q21.1: CI/CD Tier (derived from AI budget tier or asked)
- **Auto-derived tiers with different pipeline capabilities:**
  - Starter: lint + test
  - Professional: lint + test + security + build + deploy staging
  - Enterprise: full pipeline + canary + multi-environment
- **Persist:** `ci_cd.tier`

#### Q22: Branching Strategy
- **Options:** GitHub Flow | Git Flow | Trunk-Based Development
- **Persist:** `branching.strategy`

#### Q22.1: PR Validation Configuration
- **Sub-questions:**
  - PR Validation Mode: manual | ci_automated | hybrid
  - PR Approval Count: 0-4
  - PR Merge Method: merge_commit | squash | rebase
- **Persist:** `branching.pr_validation_mode`, `.pr_approval_count`, `.pr_merge_method`

#### Q23: Testing Strategy
- **Options:** TDD (test-first) | BDD (behavior-driven) | Hybrid TDD+BDD
- **Persist:** `testing.strategy`
- **After:** Minimum coverage thresholds set by tier

#### Q24: AI Capabilities
- **3 boolean sub-questions:**
  - Q24a: Does your project involve AI model **training**? → triggers MLflow/W&B/custom questions
  - Q24b: Does your project involve AI model **inference**? → triggers vLLM/Ollama/TensorRT/custom questions
  - Q24c: Does your project involve **agentic AI**? → triggers agents/tools/memory/prompts scaffolding questions
- **Persist:** `ai.training`, `ai.inference`, `ai.agentic` (each with sub-fields)

#### Q25: Observability Stack
- **4 components (Logging MANDATORY, others optional):**
  1. **Logging** (MANDATORY): Winston/Pino (Node), structlog (Python), Logback (Java), zap (Go)
  2. **Monitoring**: Prometheus+Grafana | Datadog | New Relic | CloudWatch | None
  3. **Error Tracking**: Sentry | Bugsnag | Rollbar | None
  4. **Distributed Tracing**: Jaeger | Zipkin | OpenTelemetry | X-Ray | None
- **Tier-mapped stacks:**
  - Starter ($0-20/mo): Console logging + basic health endpoint
  - Professional ($76-250/mo): Structured logging + Prometheus+Grafana + Sentry
  - Enterprise ($500-1,500/mo): Full stack with APM + distributed tracing
- **Special cases:** Serverless → MANDATORY tracing; Microservices → MANDATORY tracing; Fintech/Health → MANDATORY log retention ≥1yr
- **Persist:** `observability.logging`, `.monitoring`, `.error_tracking`, `.tracing`

#### Q26: Frameworks & Dependencies
**Automatic Special Needs Detection Protocol:** Before asking, scan `business_goal` keywords and integration ACLs to auto-detect needs in 10 categories: `ai_agent_framework`, `orm`, `auth_library`, `payment_processing`, `real_time_communication`, `file_processing`, `email_service`, `caching`, `message_queue`, `workflow_orchestration`.

**Per-runtime dependency recommendations:**
- Node.js Express/Fastify: Prisma/TypeORM/Drizzle (ORM), Zod (validation), Jest/Vitest (testing)
- Node.js NestJS: TypeORM/Prisma (ORM), class-validator (validation), Jest (testing)
- Python FastAPI: SQLAlchemy/Tortoise (ORM), Pydantic (validation), pytest (testing)
- Python Django: Django ORM (built-in), DRF serializers (validation), pytest-django (testing)
- Java Spring Boot: Spring Data JPA/Hibernate (ORM), Jakarta Validation (validation), JUnit 5 (testing)
- Go Gin/Echo: GORM/sqlx (ORM), go-playground/validator (validation), testing (built-in)

**Frontend dependency recommendations per framework:**
- React+Next.js: React Query/SWR (data), React Hook Form/Formik (forms), Tailwind/Styled Components (styling)
- Vue+Nuxt: VueUse (composables), VeeValidate (forms), Tailwind/UnoCSS (styling)
- Angular: HttpClient (data), Reactive Forms (forms), Angular Material/Tailwind (styling)
- Svelte+SvelteKit: Svelte Query (data), Superforms (forms), Tailwind/vanilla CSS (styling)

**Deny lists (contextual — apply only the categories matching the selected stack):**
- **Crypto (all runtimes):** md5, sha1 for hashing passwords/tokens (use bcrypt/argon2)
- **Dynamic eval (Python, Node.js, Ruby, PHP only):** eval/exec (use safe alternatives per language)
- **Frontend JS only:** jQuery (use native DOM or selected framework), Moment.js (use date-fns/dayjs/Temporal)
- **Persist:** `dependencies.backend[]`, `dependencies.frontend[]`, `dependencies.denied[]`

#### Q27: Project Tracking Tool
- **Type:** Open text with suggestions
- **Suggestions:** `GitHub Projects` (native, free, integrated with Issues/PRs) | `Jira` | `Linear` | `Azure Boards` | `Shortcut` | `Notion` | (any tool name the user provides) | `None` (no external tool — local tracking only)
- **Value:** The exact tool name provided by the user (free text), or `"None"` for local-only mode
- **Simplified:** es: "¿Qué herramienta usas para gestionar las tareas del proyecto? (escribe el nombre o 'None')" / en: "What tool do you use to manage project tasks? (type the name or 'None')"
- **RDR Recommendation:** GitHub Projects (native integration with GitHub Issues, zero setup cost, Kanban board via API). If the user already uses another tool, respect that choice.
- **Tier-filtered:** ALL tiers. The framework is tool-agnostic — any external tool the user specifies will be supported via tool-adapter protocol materialized during `--generate`.
- **Persist:** `project_tracking.tool`
- **Conditional unlock:** Q27 != "None" → [Q27.1, Q27.2, Q27.3, Q27.4]
- **Integration model (Q27 != "None"):** The framework integrates with external tools exclusively via **pre-authenticated CLI tools** (e.g., `gh` for GitHub, `jira` CLI) or **MCP servers** — NEVER via raw API tokens or stored credentials. During `SETUP --generate`, a `docs/backlog/tool-adapter.md` is materialized with the specific CLI/MCP commands and setup instructions for the chosen tool.

#### Q27.1: Kanban Board Columns (conditional: Q27 != "None")
- **Type:** Multi-select with ordering
- **Options:** Default preset `[Todo, In Progress, Review, Done]` | Custom (user defines column names and order)
- **Simplified:** es: "¿Qué columnas quieres en tu tablero Kanban?" / en: "What columns do you want on your Kanban board?"
- **RDR Recommendation:** Default [Todo, In Progress, Review, Done] — covers standard SDLC flow with minimal overhead
- **Persist:** `project_tracking.board_columns[]`

#### Q27.2: Feature Issue Structure (conditional: Q27 != "None")
- **Type:** Single-select (preset that expands into a structured phase list)
- **Options:** `full-sdlc` (**8 issues**: codesign → blueprint → contract-freeze → devops → implement → preventive-sweep → qa → smoke-e2e — includes three hard gates: CONTRACT-FREEZE, PREVENTIVE-SWEEP, SMOKE-E2E) | `simplified` (3 issues: spec → implement → qa, no gates) | `single` (1 issue per feature, no gates)
- **Simplified:** es: "¿Cuántos issues crear por cada feature?" / en: "How many issues to create per feature?"
- **RDR Recommendation:** `full-sdlc` — production default. One issue per Factory agent phase plus three hard gates that block downstream progression until the corresponding validation is Done. Use `simplified` only for prototypes and `single` only for spikes / experiments where the gate overhead is not justified.
- **Persist:** `project_tracking.feature_phases` — preset string stored, expanded by BACKLOG agent into phase object list (suffix, label, title_pattern, gate, sub_issue_of) per `Factory-backlog-operations.instructions.md` § 1.1

#### Q27.3: Milestone Strategy (conditional: Q27 != "None")
- **Type:** Single-select
- **Options:** `epic-based` (`EPIC-{N}: {Name}` — one milestone per epic computed by `BACKLOG --plan-execution`, all feature and gate issues in the epic share it) | `phase-based` (`Phase 1: MVP`, `Phase 2: Scale…` — user-defined product roadmap phases) | `sprint-based` (`Sprint 1`, `Sprint 2…` — fixed-cadence time boxes) | `none` (no milestone grouping)
- **Simplified:** es: "¿Cómo quieres agrupar los issues en hitos?" / en: "How do you want to group issues into milestones?"
- **RDR Recommendation:** `epic-based` when Q27.2 is `full-sdlc` — epics are the natural grouping of features that share an Aggregate Root / Bounded Context, and the milestone automatically tracks the full epic completion (features + gates + retrospective). `phase-based` when the project has a strong roadmap narrative. `sprint-based` for fixed-cadence teams. `none` only for single-feature prototypes.
- **Persist:** `project_tracking.milestone_strategy`

#### Q27.4: Feature Naming Prefix (conditional: Q27 != "None")
- **Type:** Single-select
- **Options:** `FEAT-NNN` (default) | `USR-NNN` (user-story oriented) | Custom prefix (user defines)
- **Simplified:** es: "¿Qué prefijo usar para identificar features?" / en: "What prefix to use for feature IDs?"
- **RDR Recommendation:** FEAT-NNN — standard, unambiguous, aligns with Factory spec directory structure
- **Persist:** `project_tracking.naming_convention`

#### Q27.5: Gate Enforcement Mode Default (conditional: Q27 != "None" AND Q27.2 == "full-sdlc")
- **Type:** Single-select
- **Options:** `enforce` (greenfield — gates hard-block downstream from day 1) | `warn` (legacy migration — gates log findings, downstream proceeds, flip to `enforce` when first new feature validates the gate in main) | `off` (gate disabled — use only for explicit, documented exceptions)
- **Simplified:** es: "¿Los gates nuevos deben bloquear (greenfield) o solo avisar (proyecto legacy)?" / en: "Should new gates hard-block (greenfield) or only warn (legacy migration)?"
- **RDR Recommendation:** `enforce` for greenfield (Q3 == "Greenfield"). `warn` for Brownfield (Q3 == "Brownfield") — features that lack CONTRACT-FREEZE / PREVENTIVE-SWEEP / SMOKE-E2E artefacts; warn lets the backlog flow without drowning in artificial blockers while the team migrates. Do NOT pick `off` globally — reserve `off` for per-gate overrides declared via ADR.
- **Tier-filtered:** ALL tiers.
- **Scope:** Applies to the hard gates (`contract-freeze`, `preventive-sweep`, `smoke-e2e`) and the slice/epic gates (`integration-test`, `retrospective`). Classic phase completions (blueprint `--approve`, qa `--verify`) are always hard — mode does NOT affect them.
- **Persist:** `project_tracking.gate_enforcement_mode` (global default, one string value). Per-gate overrides persist later as frontmatter on individual gate issues (handled by BACKLOG, not SETUP).
- **Soft-landing principle:** Gates default to `warn` for Brownfield projects so the backlog does not trip on features that never had the gate's artefact. When a new feature completes the gate cleanly in main (first valid CONTRACT-FREEZE artefact merged, first PREVENTIVE-SWEEP zero-C report merged, etc.), the maintainer flips the default to `enforce` via `SETUP --upgrade` or a manual edit of `docs/setup.md`. Greenfield projects skip this ramp — they start with `enforce` because every feature shipped with the framework already produces the gate artefact.

#### Q27.6: Appetite Sizing (conditional: Q27 != "None")
- **Type:** Boolean
- **Options:** `true` (enable appetite custom field / label on the tracker with values `small` / `medium` / `big`) | `false` (no appetite field)
- **Simplified:** es: "¿Usar appetite sizing (small/medium/big) como metadata de features?" / en: "Use appetite sizing (small/medium/big) as feature metadata?"
- **RDR Recommendation:** `true`. Zero runtime cost if unused and it unlocks batch planning, priority calls, and (later) Shape Up-lite cycles if that overlay is ever adopted. Pick `false` only when the team is certain it will never use sizing and wants the tracker surface minimal.
- **Concept.** Appetite is a budget, not an estimate. Instead of predicting "this takes 3 days" you commit a cap: `small` (≤ 4h, one session), `medium` (2–4 days supervised), `big` (5+ days or complex feature). Values are **metadata**, hand-curated by the human — the framework never computes them. Uses: (a) priority calls in backlog review, (b) batch planning (cluster smalls into a week, reserve bigs), (c) input for future Shape Up-lite cycles. Enabling here does NOT force Shape Up — it materializes the field so it is available if needed.
- **When work exceeds appetite → STOP and re-shape.** Overrun is a signal that either the appetite was wrong or the scope grew; both need an explicit call, not silent extension.
- **Tier-filtered:** ALL tiers.
- **Persist:** `project_tracking.appetite_sizing_enabled` (boolean). When `true`, SETUP materialization adds the field to the tool-adapter's label/field preset and extends the feature issue body template with an `Appetite:` line left blank by default.

#### Q28: Synthetic Data for Staging
- **Type:** Boolean
- **Options:** `true` (enable Synthetic Data Protocol + Shared Seed Registry) | `false` (no automated seed data)
- **Simplified:** es: "¿Quieres generar datos sintéticos automáticos para entornos de prueba (staging)?" / en: "Do you want to auto-generate synthetic data for test environments (staging)?"
- **RDR Recommendation:** `true` if project has UI (Q9 != "None") OR database (Q15 != "None") — ensures staging environments have realistic, referentially coherent data for visual and QA verification. `false` for pure API/library projects without persistent state.
- **Tier-filtered:** Recommended for ALL tiers. Zero infrastructure cost — only adds seed scripts and a registry file.
- **Persist:** `synthetic_data.enabled`
- **Conditional unlock:** Q28 == true → [Q28.1]

#### Q28.1: Seed ID Strategy (conditional: Q28 == true)
- **Type:** Single-select
- **Options:** `deterministic_sequential` (PLT-001, PLT-002... — readable, debuggable) | `uuid_v5_namespace` (deterministic UUIDs from namespace — collision-safe for distributed systems) | `natural_key` (use meaningful business keys — e.g., tax_id, email)
- **Simplified:** es: "¿Cómo generar los IDs de los datos sintéticos?" / en: "How to generate IDs for synthetic data?"
- **RDR Recommendation:** `deterministic_sequential` for monoliths/simple topologies (readable in logs). `uuid_v5_namespace` for microservices/distributed (collision-safe across bounded contexts).
- **Persist:** `synthetic_data.id_strategy`

---

### Discovery Finalization (4.1.3)

1. **Set phase:** Update `docs/setup.md` → `phase: COMPLETED`
2. **Version Verification Protocol (VVP) — § 4.1.3.1:** Resolve and pin latest stable/LTS versions for all selected stack components. See below.
3. **Cost Estimation Protocol (CEP) — § 4.1.3.2:** Estimate monthly costs for every stack component and agent-runtime line item, persist to `docs/setup.md § costs:`, check against tier limit. See below.
4. **Display complete summary:** General Info + Tripartite Architecture + Tooling + Databases + DevOps + AI + Project Tracking + **Pinned Versions** + **Costs (resolved)**
5. **Generate ADR-0000:** Create `docs/project_log/adr/ADR-0000-setup-decisions.md` with ~60 variable mappings including derived fields:
   - `SECRETS_CICD` from `ci_cd.platform`
   - `CLOUD_PROVIDER` from `hosting.provider`
   - `DEPLOYMENT_STRATEGY` from hosting+topology
   - `OBSERVABILITY` field mapping from Q25 answers
   - `SECURITY` defaults from compliance+hosting
   - Per-environment configurations
   - `STACK_VERSIONS` — pinned versions resolved by VVP
   - `COST_BREAKDOWN` — per-category and total monthly costs resolved by CEP (see § 4.1.3.2). Exposed as 20 template variables: `BACKEND_COST`, `FRONTEND_COST`, `INTEGRATION_COST`, `DATABASE_COST`, `HOSTING_COST`, `IAC_COST`, `OBSERVABILITY_COST`, `CICD_COST`, `AI_COMPONENTS_COST`, `MAINTENANCE_COST`, `PO_COST`, `ARCH_COST`, `DEV_COST`, `QA_COST`, `REVIEW_COST`, `SEC_COST`, `INFRA_TOTAL`, `TOTAL_COST`, `BUDGET_PERCENTAGE`, `BUDGET_STATUS`.
6. **Worklog entry:** Log discovery completion via `APPEND_TO_WORKLOG`
7. **Next step message:** "Ready for `/setup --generate`"

---

### § 4.1.3.1 — Version Verification Protocol (VVP)

> **Problem:** The LLM's training data is always stale. Versions it "remembers" may be outdated, EOL, or have known security vulnerabilities. Relying on LLM-suggested versions leads to painful migrations and security patches post-setup.

> **Solution:** During discovery finalization, the agent MUST query **real-time sources** (package registries, CLI tools) to resolve the **latest stable/LTS version** for every stack component selected during Q5-Q26. LLM knowledge is ONLY used as fallback when runtime resolution fails.

**INVARIANT:** NEVER trust the LLM's "knowledge" of current versions. Always verify via runtime commands.

#### Step 1 — Build Component Manifest

From the persisted `docs/setup.md` answers, extract all versionable components:

```yaml
versionable_components:
  runtime:        # Q5: e.g., "Node.js", "Python", "Go", "Java"
  framework:      # Q6: e.g., "NestJS", "FastAPI", "Spring Boot"
  meta_framework:  # Q10: e.g., "Next.js", "Nuxt", "SvelteKit"
  frontend_framework: # Q9: e.g., "React", "Vue", "Angular"
  state_management:   # Q12: e.g., "Redux Toolkit", "Pinia", "Zustand"
  orm:            # Q26: e.g., "Prisma", "TypeORM", "SQLAlchemy"
  test_framework: # Q23/Q26: e.g., "Vitest", "Jest", "pytest"
  database:       # Q15/Q16: e.g., "PostgreSQL", "MongoDB"
  cache:          # Q17: e.g., "Redis"
  ci_cd:          # Q21: e.g., "GitHub Actions"
  iac:            # Q20.1: e.g., "Terraform", "Pulumi"
  dependencies:   # Q26: all backend[] and frontend[] packages
```

#### Step 2 — Resolve Versions via Runtime Queries

For each component in the manifest, execute the resolution command appropriate to its **ecosystem** (determined by the stack selected during Q5-Q26). The agent MUST use `runInTerminal` to execute these commands.

> **This is a lookup table** — only the rows matching the selected stack apply.

| Ecosystem | Resolution Method | Command Pattern |
| --- | --- | --- |
| **Runtime with LTS program** | Official release API | e.g., `curl -s https://nodejs.org/dist/index.json`, `python.org`, `go.dev/dl` |
| **npm/yarn ecosystem** | Registry query | `npm view {package} dist-tags.latest` |
| **PyPI ecosystem** | Registry query | `pip index versions {package}` or `curl -s https://pypi.org/pypi/{package}/json \| jq -r '.info.version'` |
| **Go modules** | Proxy query | `curl -s https://proxy.golang.org/{module}/@latest \| jq -r '.Version'` |
| **Maven/Gradle ecosystem** | Maven Central query | `curl -s "https://search.maven.org/solrsearch/select?q=g:{group}+AND+a:{artifact}&rows=1&wt=json" \| jq -r '.response.docs[0].latestVersion'` |
| **Database / infrastructure** | Official repos or Docker Hub | Docker Hub tags or official release pages via `web/fetch` (or `curl`) |
| **IaC providers** | Provider registry API | e.g., `curl -s https://registry.terraform.io/v1/providers/{ns}/{type}` |

**Priority order for resolution:**
1. **CLI command** (most reliable — package manager native query)
2. **Registry API** (curl + jq to the ecosystem's official registry)
3. **`web/fetch`** (agent web/fetch tool) to official release/download pages
4. **LLM knowledge** (LAST RESORT — mark as `⚠️ unverified` in output)

#### Step 3 — Version Selection Policy

For each resolved version, apply this policy:

```yaml
version_policy:
  prefer: "latest_stable_LTS"  # Always prefer LTS if available
  rules:
    - IF component has LTS program (e.g., runtimes, platforms with LTS cycles):
        SELECT latest LTS release (NOT latest current/bleeding-edge)
    - IF component is a library/framework:
        SELECT latest stable release (NOT beta/rc/alpha/canary)
    - IF component is a database or infrastructure service:
        SELECT latest stable GA release
    - IF resolved version != LLM-suggested version:
        LOG: "⚡ VVP: {component} updated {llm_version} → {resolved_version}"
    - IF resolution fails (network error, CLI not available):
        FALLBACK to LLM knowledge + mark as "⚠️ unverified — resolve manually"
```

#### Step 4 — Persist Pinned Versions

Write resolved versions to `docs/setup.md` under a new section:

```yaml
stack_versions:
  resolved_at: "{{current_date}}"          # When versions were verified
  resolution_method: "VVP-runtime"          # Runtime-verified (vs "llm-fallback")
  components:
    {runtime_key}: "{version}"              # e.g., LTS if applicable
    {framework_key}: "{version}"            # Latest stable
    {db_key}: "{version}"                   # Latest GA
    # ... one entry per versionable component selected during discovery
  unverified: []                            # Components that fell back to LLM knowledge
```

> **Keys are dynamic** — derived from the component names selected during Q5-Q26. No hardcoded stack assumptions.

#### Step 5 — Present Version Summary to User

Display a clear table in the finalization summary:

```
📦 Stack Versions (verified {{date}}):

| Component        | Version    | Source           | Notes           |
|-----------------|------------|------------------|-----------------|
| {runtime}        | {version}  | ✅ {source}       | LTS if applicable|
| {framework}      | {version}  | ✅ {registry}     |                 |
| {database}       | {version}  | ✅ {source}       | Latest GA       |
| {dependency_N}   | {version}  | ✅ {registry}     |                 |
| {unverified_dep} | {version}  | ⚠️ LLM fallback  | Verify manually |
```

> Rows are populated dynamically from the components selected during discovery. No hardcoded stack names.

The user can override any version before finalizing.

---

### § 4.1.3.2 — Cost Estimation Protocol (CEP)

> **Problem.** Before EVOL-014, `docs/setup.md` had no canonical `costs:` section. Discovery finalization said "Sum all selected component costs" but defined neither the schema, the inputs, nor the output. Downstream templates (`ADR-0000-setup-decisions.md`, `MATERIALIZATION_REPORT.md`) referenced 20 cost placeholders (`{{BACKEND_COST}}`, `{{TOTAL_COST}}`, `{{BUDGET_PERCENTAGE}}`, …) that had no producer — they materialised as literal `{{…}}` strings in generated artifacts.

> **Solution.** CEP is the canonical producer. Runs AFTER VVP during Discovery Finalization. Estimates monthly cost for every cost-bearing discovery answer using the agent's ecosystem knowledge, persists the full breakdown to `docs/setup.md § costs:`, and the materialization pass reads from that section to resolve every `{{*_COST}}` placeholder. **No hardcoded price tables** — the agent uses its knowledge of typical monthly pricing for each component at each tier level, and invokes RDR when pricing is ambiguous.

**INVARIANT:** After CEP completes, `docs/setup.md § costs:` has a value (possibly 0) for every cost field documented below. Any downstream `{{*_COST}}` placeholder that survives materialization as a literal string is a governance drift.

#### Step 1 — Build the cost manifest

From the persisted discovery answers, identify every cost-bearing component. Group into two top-level categories:

**A. Infrastructure costs** (cloud + services, monthly USD):

| Field | Input answers | Notes |
| --- | --- | --- |
| `backend` | Q5 runtime, Q7 topology, Q20 hosting | Cost of the backend runtime tier for the chosen topology on the chosen hosting provider (e.g., Node.js monolith on Vercel Pro, Python microservices on AWS Fargate) |
| `frontend` | Q9 framework, Q11 pattern, Q20 hosting | Frontend hosting cost — static sites are usually cheap/free; SSR/ISR has runtime costs |
| `integration` | Q8 communication style, detected ACL count | ~$50/ACL baseline for managed integrations (Kafka, RabbitMQ, event bus); 0 for local/in-process |
| `databases` | Q15 primary, Q16 secondary, Q17 cache | Managed DB tier cost sum (Postgres + Redis, MongoDB Atlas, etc.) |
| `hosting` | Q20 hosting, Q20.2 secrets manager | Platform base fee beyond the per-service costs already counted above |
| `iac` | Q20.1 iac_tool | Typically free (Terraform OSS); paid tiers only for enterprise Terraform Cloud, Pulumi Business |
| `observability` | Q25 logging + monitoring + error tracking + tracing | Sum of the 4 observability sub-answers per their tier mapping (Starter/Professional/Enterprise) |
| `cicd` | Q21 CI/CD platform, Q21.1 tier | Usually free for OSS/public repos, $4-20/user for private |
| `ai_components` | Q24a training, Q24b inference, Q24c agentic | Rough estimate — training is project-bursty, inference is per-request × volume, agentic is token spend |
| `maintenance` | Derived | ~10-20% of `infra_total` as a maintenance reserve |

**B. Agent runtime costs** (LLM token spend for each Factory persona, monthly USD):

| Field | Typical driver |
| --- | --- |
| `po` | CODESIGN PO hat token spend — depends on feature volume (Q4 tier sets the cap) |
| `arch` | BLUEPRINT ARCH hat |
| `dev` | IMPLEMENT DEV hat — the biggest spender, scales with LOC produced per month |
| `qa` | IMPLEMENT QA hat + QA --verify |
| `review` | IMPLEMENT REVIEW hat |
| `sec` | IMPLEMENT SEC hat + AUDIT |

Use Q4 `ai_budget.tier` (Starter / Professional / Enterprise) as the ceiling. For each agent, estimate the share of the ceiling that persona consumes given the project's expected feature cadence — defaults are DEV 40%, ARCH 15%, PO 10%, QA 15%, REVIEW 10%, SEC 10%. Override per project via RDR if the user signals an unusual mix (e.g., heavy security scope → SEC 25%).

#### Step 2 — Estimate each value

For each field in the cost manifest, the agent writes a concrete monthly USD value using its knowledge of the ecosystem. Rules:

1. **When pricing is obvious** (e.g., GitHub Actions is free on public repos, Vercel Hobby is free, Supabase Free tier is $0), write the value and move on.
2. **When pricing is tiered but obvious** (e.g., Vercel Pro is $20/user/month, Supabase Pro is $25/month), pick the tier that matches Q4 `ai_budget.tier` ceiling and use that value.
3. **When pricing is ambiguous or usage-based** (e.g., AWS Fargate depends on vCPU-hours × requests × data-out; managed Kafka scales with throughput), invoke **RDR**:
   - Present the agent's estimate for the expected volume of a project at this tier.
   - Offer 2-3 alternatives ("Assume 1k req/day → ~$40/mo", "Assume 10k req/day → ~$120/mo", "Assume 100k req/day → ~$500/mo").
   - The user's pick becomes the persisted value.
4. **When pricing cannot be estimated** (e.g., a proprietary vendor the agent doesn't know), mark the field with value `0` and the comment `# needs manual pricing` so finalization surfaces the gap — the user resolves it before SETUP --generate proceeds.

#### Step 3 — Compute totals and budget status

```yaml
infra_total        = sum(all infrastructure fields A)
agent_tokens_total = sum(all agent runtime fields B)
total_monthly      = infra_total + agent_tokens_total

tier_limit = ai_budget.monthly_limit from Q4
budget_percentage = round(total_monthly / tier_limit * 100, 1)

IF total_monthly <= tier_limit * 0.90:
  status = "WITHIN_BUDGET"
  risk = "Low"
ELIF total_monthly <= tier_limit:
  status = "AT_LIMIT"
  risk = "Medium"
  risk_mitigation = "{short text: which component to watch}"
ELSE:
  status = "EXCEEDS_BUDGET"
  risk = "High"
  risk_mitigation = "{short text: which component to cut}"
  # Present 5 downgrade alternatives (A-E) before accepting the breach
```

#### Step 4 — Persist to `docs/setup.md`

Write the full breakdown under a new top-level `costs:` key:

```yaml
# docs/setup.md — added by CEP during Discovery Finalization
costs:
  currency: "USD"
  period: "monthly"
  infrastructure:
    backend:        {value}
    frontend:       {value}
    integration:    {value}
    databases:      {value}
    hosting:        {value}
    iac:            {value}
    observability:  {value}
    cicd:           {value}
    ai_components:  {value}
    maintenance:    {value}
  agent_tokens:
    po:     {value}
    arch:   {value}
    dev:    {value}
    qa:     {value}
    review: {value}
    sec:    {value}
  totals:
    infra_total:        {value}
    agent_tokens_total: {value}
    total_monthly:      {value}
    tier_limit:         {value}
    budget_percentage:  {value}
    status:             "WITHIN_BUDGET | AT_LIMIT | EXCEEDS_BUDGET"
    risk:               "Low | Medium | High"
    risk_mitigation:    "{text or empty}"
  notes:
    - "{field}: {rationale or pricing assumption — captured during RDR}"
```

#### Step 5 — Downstream substitution map

Materialization (`Factory-setup-materialization.instructions.md` § 4.2.7) reads `setup_md.costs` and exposes the values as template variables. The following placeholder → field map is canonical:

| Placeholder | Maps to |
| --- | --- |
| `{{BACKEND_COST}}` | `costs.infrastructure.backend` |
| `{{FRONTEND_COST}}` | `costs.infrastructure.frontend` |
| `{{INTEGRATION_COST}}` | `costs.infrastructure.integration` |
| `{{DATABASE_COST}}` | `costs.infrastructure.databases` |
| `{{HOSTING_COST}}` | `costs.infrastructure.hosting` |
| `{{IAC_COST}}` | `costs.infrastructure.iac` |
| `{{OBSERVABILITY_COST}}` | `costs.infrastructure.observability` |
| `{{CICD_COST}}` | `costs.infrastructure.cicd` |
| `{{AI_COMPONENTS_COST}}` | `costs.infrastructure.ai_components` |
| `{{MAINTENANCE_COST}}` | `costs.infrastructure.maintenance` |
| `{{INFRA_TOTAL}}` | `costs.totals.infra_total` |
| `{{PO_COST}}` | `costs.agent_tokens.po` |
| `{{ARCH_COST}}` | `costs.agent_tokens.arch` |
| `{{DEV_COST}}` | `costs.agent_tokens.dev` |
| `{{QA_COST}}` | `costs.agent_tokens.qa` |
| `{{REVIEW_COST}}` | `costs.agent_tokens.review` |
| `{{SEC_COST}}` | `costs.agent_tokens.sec` |
| `{{TOTAL_COST}}` | `costs.totals.total_monthly` |
| `{{ESTIMATED_MONTHLY_COST}}` | `costs.totals.total_monthly` (alias for legacy templates) |
| `{{BUDGET_PERCENTAGE}}` | `costs.totals.budget_percentage` |
| `{{BUDGET_STATUS}}` | `costs.totals.status` |
| `{{BUDGET_RISK}}` | `costs.totals.risk` |
| `{{BUDGET_RISK_MITIGATION}}` | `costs.totals.risk_mitigation` |
| `{{BUDGET_ALIGNMENT}}` | `"verified"` when status != "EXCEEDS_BUDGET"; `"override pending"` otherwise |

> **Governance.** This is a **template-variable surface**, not a hardcoded price table. The framework never commits dollar values to a rule file. The values live in `docs/setup.md` (per-project, editable) and flow into generated artifacts through the substitution pass. Adding a new cost category (e.g., a new CDN line item) requires:
> 1. Adding a field under `costs.infrastructure.*` in this protocol
> 2. Adding its row to the placeholder substitution map
> 3. Adding it to step 1 (input answers)
> No rule files, templates, or adapter code need to touch hardcoded prices.

---

## Resumability Protocol (BIP-aware)

If `docs/setup.md` exists with `phase: IN_PROGRESS`:
1. Scan `docs/.bip/SETUP_tier_*.md` for existing Decision Batches
2. Find last completed tier (status: PROCESSED in batch frontmatter)
3. If all tiers processed → resume at `--propose-final`
4. If a tier has status: ANSWERED → resume at `--resolve --tier {N}`
5. If a tier has status: PENDING → resume at BA mediation for that tier
6. If no BIP files exist → start from tier 0
7. Display summary of already-decided tiers before resuming
8. Never re-ask decided tiers unless user explicitly requests via `back` shortcut

## Persistence Rules

- **EVERY** tier's answers saved to `docs/setup.md` atomically after `--resolve`
- Update `last_completed_tier` after each tier resolution
- Decision Batches and Answer Sets persisted in `docs/.bip/` for cross-invocation state
- Use YAML frontmatter for structured data
- Use body sections for free-text responses
- Running cost accumulator updated after each budget-impacting tier
