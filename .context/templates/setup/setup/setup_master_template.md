---
version: 2.1.0
date: 2026-04-21
changelog:
  - "2.1.0: feat(EVOL-019): project_scope field added (dual-axis scope model) — full-stack | backend-only | frontend-only | integration"
  - "2.0.0: Tripartite architecture support"
  - "1.0.0: Initial template"
phase: DISCOVERY | PLANNING | EXECUTION | COMPLETED
status: NEEDS_INFO | READY
retry_count: 0
mode: GREENFIELD | BROWNFIELD
project_scope: full-stack | backend-only | frontend-only | integration
language: EN | ES
last_update: [TIMESTAMP]
---

# 🏗️ Architecture Roadmap & Blueprint

## 1. Context & Business Goal
- **Goal:** [Defined in Phase 1]
- **Language:** [Detected/Defined]
- **Deployment:** [Cloud/On-Prem]

## 2. Execution Plan (The Queue)
> Dynamic list. The agent resolves the first item and moves it to Logs.
- [ ] (Empty when completed)

## 3. Decisions Log (Resolved)

### 0. AI Budget & Governance
- **AI Budget Tier:** [Starter: <$500/month | Professional: $500-$2K/month | Enterprise: $2K-$10K/month | Unlimited: >$10K/month]
- **Monthly Budget Limit:** [$X USD/month]
- **Budget Tracking:** Enabled (cross-feature accumulation, 80% warning threshold, monthly reset with history archive)

### 0.1 Project Scope (EVOL-019 — dual-axis scope model)
- **Project Scope:** [full-stack | backend-only | frontend-only | integration]
- **Compatibility with feature.scope:**
  - `full-stack` → any feature.scope (full-stack | backend-only | frontend-only | integration)
  - `backend-only` → feature.scope in [backend-only, integration] only
  - `frontend-only` → feature.scope in [frontend-only] only
  - `integration` → feature.scope in [backend-only, integration] only
- **Materialization impact:** When `project_scope in [backend-only, integration]`, SETUP skips frontend directory scaffolding, UX rules (`ux-constitution`, `frontend_architecture_compatibility`), vision artifacts, and frontend-specific CI jobs. When `frontend-only`, SETUP skips backend directory scaffolding, backend rules, and backend-specific CI jobs. See `Factory-setup-materialization.instructions.md § 4.2.6 Scope-Keyed Conditional Materialization`.

### 0.2 Default Slicing Strategy (Incremental Dev Plan)
- **Default slicing strategy:** [incremental | monolithic] — applied to every new feature unless spec.feature overrides. Default `incremental` (recommended). `monolithic` sets the project default but individual features still require trivial-heuristic approval at `BLUEPRINT --start` (`≤2 scenarios AND ≤3 contract operations AND scope ≠ full-stack`).
- **Resolution:** Discovery asks this after Project Scope. Greenfield projects start at `incremental` unless the team explicitly opts out. Brownfield projects may start `monolithic` if the legacy surface is small and then migrate per-feature.
- **Authoring impact:** Every new `spec.feature` inherits this default into its `slicing_strategy` frontmatter field. Authors can override per-feature at CODESIGN time. BLUEPRINT enforces the trivial-heuristic regardless of the project default.

### A. Backend Architecture
- **Macro Topology (Backend):** 
  - [Modular Monolith: Traditional | Modular by Bounded Contexts | Microkernel with Plugins]
  - [Microservices: Pure REST | gRPC | Event-Driven (Async) | SOA with ESB]
  - [Serverless: AWS Lambda | Azure Functions | GCP Functions | Cloudflare Workers]
  - [Peer-to-Peer]
  - [Broker/Pipeline: RabbitMQ | Kafka | Azure Service Bus]
- **Internal Pattern (Backend):** [Onion | Hexagonal | Layered | MVC | Feature-based]
- **Monthly Base Cost:** [$X] (calculated from topology selection)

### B. Frontend Architecture
- **UX Strategy (Frontend):** 
  - [SPA]
  - [SSR: With hydration (Next.js/Nuxt) | Without hydration (pure SSR)]
  - [Micro-Frontends: Module Federation | Web Components | iFrames]
  - [Jamstack/SSG]
  - [Islands Architecture: Astro | Qwik]
- **Internal Pattern (Frontend):** [FSD + Atomic + Headless] (Standard - No modificable)
- **Styling:** [Tailwind]
- **State Management:** [Redux | Zustand | Context API | Nano Stores | None]
- **Monthly Incremental Cost:** [$X] (calculated from strategy selection)

### C. Integration Strategy
- **ACL Scope:** Global (location: `src/integration/acl/`)
- **Contract-First Policy:** Mandatory (contracts per service if distributed, monolithic if Modular Monolith)
- **Feature Flags:** Per-component (location: `flags/{FEATURE_ID}/{component}.yml`, manual rollout default, auto if budget>=enterprise)
- **Backend Aggregator ACL:** [Yes | No] (required if Microservices/SOA/Broker-Pipeline)
- **Total ACL Count:** [X integrations]
- **ACL Integration Cost:** [$X] ($50 per integration + $100 for aggregator if applicable)

### C.1 AI Capabilities
- **Training/Fine-tuning:** [Yes | No]
- **Inference Local (Self-hosted):** [Yes | No]
- **Agentic/RAG:** [Yes | No]
- **AI Components Cost:** [$X] (training + inference serving + agentic tooling)

### C.2 Dynamic Path Variables (Derived)
- **BACKEND_BASE_PATH:** [Derived from backend.topology]
- **BACKEND_MODULES_PATH:** [Derived from backend.topology + internal pattern]
- **FRONTEND_BASE_PATH:** [Derived from frontend.pattern]
- **INTEGRATION_BASE_PATH:** [Derived from backend.topology]
- **AI_BASE_PATH:** [Derived from backend.topology]
- **CONTRACTS_BASE_PATH:** [Derived from backend.topology, default: `contracts`]
- **~~CONTRACTS_NAMESPACE~~:** ~~REMOVED (v12.0.0)~~ — Contract directories use domain-name slugs (`contracts/{type}/{CONTRACT_SLUG}/`). See `contract-first-policy.instructions.md`.
- **CONFIG_BASE_PATH:** [Project root config path]
- **MONOREPO_APPS_PATH:** [Derived from project structure if monorepo]
- **SCRIPTS_BASE_PATH:** [Project root scripts path]
- **ML_BASE_PATH:** [Derived from backend.topology]
- **INFRA_BASE_PATH:** [Project root infrastructure path]

### D. Extension Strategy (IF Brownfield)
#### Backend Extension Strategy
- **Current Architecture:** [Detected from project scan]
- **Target Architecture:** [From Macro Topology decision]
- **Gap Analysis:** [Summary of architectural differences]
- **Extension Strategy:** [Preserve Current + Wrapper | Strangler Fig | Parallel Run | Big Bang]
- **Effort Estimate:** [$X USD, Y months]
- **Risk Level:** [Low | Medium | High]
- **Pros:** [Bullet list]
- **Cons:** [Bullet list]

#### Frontend Extension Strategy
- **Current Architecture:** [Detected from project scan]
- **Target Architecture:** [From UX Strategy decision]
- **Gap Analysis:** [Summary of architectural differences]
- **Extension Strategy:** [Preserve Current + Wrapper | Strangler Fig | Parallel Run | Big Bang]
- **Effort Estimate:** [$X USD, Y months]
- **Risk Level:** [Low | Medium | High]
- **Pros:** [Bullet list]
- **Cons:** [Bullet list]

### E. Operational Decisions
### E. Operational Decisions
- **Branching Strategy:** [GitHub Flow (default) | GitFlow | OneFlow | GitLab Flow | Trunk-Based Development]
- **Semantic Versioning:** [Enabled on main | Disabled]
- **Environment Strategy:** [Standard: Dev/Staging/Prod | Minimal: Dev/Prod | Custom: specify]
- **CI/CD Platform:** [GitHub Actions | GitLab CI | Jenkins | Azure Pipelines | None]
- **Pipeline Depth:** [Basic: lint/test/build | Advanced: +security/multi-env/rollback]
- **IDE Preference:** [VSCode | IntelliJ IDEA | PyCharm | None]
- **E2E Testing:** [Playwright (Web UI) | Newman (API) | Skip]
- **DAST Tools:** [OWASP ZAP | Skip]
- **Visual Regression:** [Enabled (Playwright Snapshots) | Disabled]
- **Stateless Strategy:** [Session Management: Redis/JWT | Cache: Redis Cluster/CDN | Idempotency: Keys/Deduplication]
- **Security Baseline:** [OWASP Top 10 Controls | Secrets: Vault/AWS Secrets | SAST: Semgrep/Gitleaks | Network: Zero Trust/mTLS]
- **Privacy Compliance:** [GDPR Art. 5+25 | PII Classification: Tier 1/2/3 | User Rights: Access/Erasure/Portability | Consent: Opt-In/Granular]
- **Documentation Standard:** [Python: Google Docstrings | JS/TS: TSDoc | Java: Javadoc | C#: XML Comments | Go: Godoc]

## 3.1. Budget Validation Summary
> Calculated automatically before materialization.
- **Total Monthly Cost:** [$X USD/month]
  - Backend Base Cost: [$X]
  - Frontend Incremental Cost: [$X]
  - ACL Integration Cost: [$X]
  - AI Components Cost: [$X]
  - Agentic Ops Cost: [$X]
  - Maintenance Cost: [$X]
  - Complexity Multiplier: [1.0x | 1.3x | 1.8x]
- **Budget Tier Limit:** [$Y USD/month]
- **Budget Status:** [✅ Within Budget | ⚠️ At 80% Warning | ❌ Exceeded]
- **Recommendations:** [If exceeded, list alternative configurations]

## 3.2. Validation Checklist (Pre-Materialization)
> Verified by the Architect before `phase: COMPLETED`.
- [ ] **AI_BUDGET_COMPLIANCE:** Budget tier selected, total cost calculated, within limit or alternatives provided
- [ ] **TOPOLOGY_COMPLIANCE:** Backend topology selected, frontend strategy chosen, integration ACL strategy defined
- [ ] **ARCHITECTURE_COMPATIBILITY:** Frontend strategy compatible with framework, no exclusion rules violated
- [ ] **EXTENSION_STRATEGY_COMPLIANCE:** (IF Brownfield) Backend and frontend extension strategies decided, impact analysis completed
- [ ] **BRANCHING_COMPLIANCE:** Branching strategy selected, branch protection rules defined, semver policy configured
- [ ] **ENVIRONMENT_COMPLIANCE:** Environment topology defined (Dev/Staging/Prod), auto-deploy rules per environment, .env templates planned
- [ ] **CI_CD_COMPLIANCE:** CI/CD platform selected, pipeline depth chosen (Basic/Advanced), quality gates defined
- [ ] **E2E_DAST_COMPLIANCE:** E2E testing framework configured (Playwright/Newman), DAST tools selected, visual regression enabled (if UI), Page Object Model structure defined
- [ ] **STATELESS_COMPLIANCE:** Services externalize session state, APIs are idempotent, cache is distributed
- [ ] **AI_CAPABILITY_COMPLIANCE:** AI capabilities declared (training/inference/agentic), scaffolding impact identified, integration wiring planned
- [ ] **SECURITY_BASELINE:** OWASP controls defined, secrets management strategy, SAST tools configured
- [ ] **PRIVACY_GDPR:** PII classification documented, user rights endpoints planned, logging masking enabled
- [ ] **DOCS_STANDARD:** Docstring format selected per language, C4 diagrams in design.md, ADRs for key decisions

## 4. Directory Structure & Rationale (Dynamic Map)
> Mandatory usage guide for Developer Agents. **The structure is composed additively** according to `backend.topology`, `frontend.pattern` and `ai_capability.*`.
| Path | Purpose | Constraint/Rule |
| :--- | :--- | :--- |
| `docs/spec/{{FEATURE_ID}}/` | Feature workspace: `initial.md` (PO input), `spec.feature` (PO Gherkin), `test_plan.md` (QA strategy), `design.md` (ARCH technical design), `dev_plan.md` (DEV tasks), `sec_audit.md` (SEC report) | Each agent writes to its designated file. |
| `{{BACKEND_BASE_PATH}}/` | Backend base (e.g., `src/` monolith, `services/` microservices, `functions/` serverless) | Selected by `backend.topology`. |
| `{{BACKEND_MODULES_PATH}}/` | Backend modules (e.g., `src/modules/` or per-service modules) | Generated by additive tree fragments. |
| `{{FRONTEND_BASE_PATH}}/` | Frontend base (e.g., `app/`, `src/`, `pages/`) | Selected by `frontend.pattern`. |
| `{{INTEGRATION_BASE_PATH}}/acl/` | Anti-Corruption Layer | Always present. |
| `{{INTEGRATION_BASE_PATH}}/backend_aggregator/` | API Gateway/BFF | Only if distributed backend. |
| `{{INTEGRATION_BASE_PATH}}/events/` | Async events & training jobs | Only if training enabled and backend present. |
| `{{AI_BASE_PATH}}/adapters/` | Model clients/adapters | Only if agentic + local inference enabled. |
| `{{FRONTEND_BASE_PATH}}/hooks/` | Frontend streaming hooks | Only if agentic enabled and frontend present. |
| `{{CONTRACTS_BASE_PATH}}/openapi/` | REST API contracts (empty) | Created whenever HTTP/REST APIs are present (REST is default, including Event-Driven topologies). Populated by `/BLUEPRINT --start` using `{CONTRACT_SLUG}`-named subdirectories. |
| `{{CONTRACTS_BASE_PATH}}/graphql/` | GraphQL contracts (empty) | Only if `backend.communication_style == GraphQL`. Populated by `/BLUEPRINT --start` using `{CONTRACT_SLUG}`-named subdirectories. |
| `{{CONTRACTS_BASE_PATH}}/grpc/` | gRPC Protocol Buffers (empty) | Only if `backend.communication_style == gRPC`. Populated by `/BLUEPRINT --start` using `{CONTRACT_SLUG}`-named subdirectories. |
| `{{CONTRACTS_BASE_PATH}}/asyncapi/` | AsyncAPI event schemas (empty) | Only if `backend.communication_style == Event-Driven` OR `topology IN [B3, B6, B7, B11]`. Populated by `/BLUEPRINT --start` using `{CONTRACT_SLUG}`-named subdirectories. |
| `{{CONFIG_BASE_PATH}}/model-serving.yaml` | Inference server config | Only if local inference enabled. |
| `{{MONOREPO_APPS_PATH}}/` | Entry points (monorepo) | Only if monorepo selected. |
| `{{SCRIPTS_BASE_PATH}}/` | Automation & Tooling | Adapted to new Stack. |
| `{{ML_BASE_PATH}}/data/` | ML datasets (raw/processed) | Only if training enabled. |
| `{{ML_BASE_PATH}}/training/` | Training pipelines | Only if training enabled. |
| `{{ML_BASE_PATH}}/experiments/` | Experiment tracking | Only if training enabled. |
| `{{INFRA_BASE_PATH}}/inference-server/` | Model serving runtime | Only if local inference enabled. |
| `{{AI_BASE_PATH}}/agents/` | Agent orchestration | Only if agentic enabled. |
| `{{AI_BASE_PATH}}/tools/` | Tooling integrations | Only if agentic enabled. |
| `{{AI_BASE_PATH}}/memory/` | Memory stores | Only if agentic enabled. |
| `{{AI_BASE_PATH}}/prompts/` | Prompt templates | Only if agentic enabled. |

## 5. Auto-Decisions
> Decisions forced by Architect after 3 strikes.
- (Empty)
