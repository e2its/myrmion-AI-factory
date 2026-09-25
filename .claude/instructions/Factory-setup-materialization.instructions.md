---
description: "Factory SETUP materialization — governance scaffolding, rule generation, constitution creation, --generate --resume. Use when: SETUP --generate command execution."
applicable_when:
  phase: [SETUP]
  command: [setup]
---

# SETUP Agent — Materialization Phase (`/setup --generate`, `--generate --resume`)

> Instruction file for the SETUP worker agent — Physical project scaffolding and governance materialization.
> Loaded when SETUP handles `--generate` or `--generate --resume`.

---

## Prerequisites (BLOCKING)

Before any materialization work:
1. `docs/setup.md` must exist with `phase: COMPLETED` (discovery done)
2. `docs/project_log/adr/ADR-0000-setup-decisions.md` must exist (governance baseline)
3. `docs/project_log/workflow_log.json` must exist (create if missing)
4. Feature branch must be active (never materialize on main)

If any prerequisite fails → **BLOCK** with clear remediation message.

---

## Governance Checkpoints (3 MANDATORY)

### Checkpoint 1 — Pre-Materialization (BLOCKING)
- Validate ADR-0000 exists and is well-formed
- Initialize `docs/project_log/workflow_log.json` if missing
- Create `MATERIALIZATION_REPORT.md` with full task checklist (60-80 tasks)
- Each task starts as `[ ]`, transitions to `[✓]` upon completion

### Checkpoint 2 — Per-Task Logging (CONTINUOUS — IPP Pillar 2)

> **Implements:** Incremental Persistence Protocol (`.claude/skills/factory-incremental-persistence/SKILL.md`) — Pillar 2 (Section-Atomic Saves).

- After EACH completed task: `APPEND_TO_WORKLOG` with task details
- Update MATERIALIZATION_REPORT.md checklist: `[ ]` → `[✓]`
- Atomic saves: crash at any point allows resume from last `[✓]`
- **IPP compliance:** Each `[✓]` mark is an atomic save — NEVER batch multiple task completions before writing to disk

### Checkpoint 3 — Post-Materialization Validation (BLOCKING)
Validate 6 artifact categories exist and are well-formed:
1. `docs/constitution.md` — exists, no `{{placeholders}}` remaining
2. `.claude/rules/*.md` — at least core rules materialized, all with YAML frontmatter
3. Source directory structure — matches topology + pattern
4. CI/CD pipeline — exists for chosen platform
5. `docs/project_log/governance_versions.json` — snapshot created
6. `.context/governance_snapshot.md` — governance snapshot generated (see Checkpoint 3.1)

If ANY check fails → **BLOCK** completion, list failures, suggest fixes.

### Checkpoint 3.1 — Governance Snapshot Generation (MANDATORY)

The snapshot is produced by ONE script, never hand-written (EVOL-043 — the script is the contract):

```bash
bash scripts/generate-governance-snapshot.sh            # lite profile: what a session receives
```

- Inputs: `docs/constitution.md` (the law INDEX: `## [PLAW-NN]` · `> sentence` · `Body:` pointer · `Records:`), `docs/setup.md`, `.claude/rules/*.md` (frontmatter `applicable_when`; `defect-prevention.md` § Families), `config/protected-paths.json`, `config/quality.json` (`budgets.snapshot`), the governance manifest (`framework_version`).
- Output: `.context/governance_snapshot.md` — frontmatter hashes (`constitution_hash`, `setup_hash`, `dcs_hash`, `profile`), Stack Configuration, Rules Manifest, Protected Paths, Setup Configuration (verbatim frontmatter), **Law Index**, **Defect Families**. Law bodies and defect-class rows are NOT embedded: bodies are read at the point of action, classes are delivered per file by the pre-edit hook. `--profile full` appends both for review only.
- Exit: `0` written · `1` missing input (constitution / setup) · `2` tooling (python3, md5, `scripts/gate.py` absent) · `3` lite profile over `budgets.snapshot` — BLOCK the materialisation on 1/2/3 and say which.
- Corpus parsing is delegated to the one reader (`python3 scripts/gate.py snapshot-sections`); the same parser serves the resolver, the pre-edit hook and the parity gates. Full contract: factory-governance-loading SKILL § POST-LOAD; test: `scripts/test-snapshot-extraction.sh`.

### Self-Validation Prompt
Before finalizing, internally verify:
1. "Did I generate the constitution from the template?"
2. "Did I resolve ALL placeholders?"
3. "Did I create rules for the detected technology stack?"
4. "Did I scaffold directories matching the chosen topology?"
5. "Did I create a functional CI/CD pipeline?"

---

## Core Operating Principles

### Reliable Low Token Mode (4.2.0)
**Golden Rule:** NEVER rewrite templates from scratch. Always:
1. Read the template file from `.context/templates/setup/`
2. Perform semantic mapping of `docs/setup.md` values → template placeholders
3. Replace placeholders with resolved values
4. Write the result to the target path

This ensures consistency and avoids hallucinating content not in templates.

### Source Code Prohibition
**CRITICAL:** Do NOT generate source code files (services, controllers, repositories, adapters, components, pages, hooks) during materialization. Only create:
- Empty directories with `.gitkeep`
- Configuration files (tsconfig, jest.config, playwright.config, etc.)
- Type definition files (interfaces, enums, shared types)

Real source code is generated by `IMPLEMENT` during TDD cycle.

### Test Scaffolding Prohibition
Do NOT generate example test files (*.spec.ts, *.test.ts, base.page.ts). Only create:
- Testing configuration files
- Empty test directories with `.gitkeep`

---

## Materialization Sequence

### 4.2.1 Pre-Validation
Run 5 checks (warn but DO NOT BLOCK):
1. Git repo initialized
2. Node/Python/Java runtime available
3. Package manager available
4. No conflicting project structure
5. Sufficient disk space

### 4.2.1.1 Version Freshness Gate (BLOCKING if stale)

> **Purpose:** Ensure pinned versions from VVP (§ 4.1.3.1) are still fresh. If discovery was completed days/weeks ago, versions may have changed.

```yaml
READ docs/setup.md → stack_versions.resolved_at
IF (current_date - resolved_at) > 7 days:
  WARN: "Stack versions were pinned {N} days ago. Re-verifying..."
  RE-RUN VVP Step 2 (resolve versions via runtime queries)
  IF any version changed:
    PRESENT diff table to user:
      "| Component    | Pinned    | Current   | Action  |"
      "| {component}  | {old_ver} | {new_ver} | Update? |"
    UPDATE docs/setup.md → stack_versions with user-approved versions
ELSE:
  LOG: "Stack versions verified — {resolved_at} is fresh"
```

### 4.2.1.2 Version Pinning in Generated Artifacts

When generating configuration files, the agent MUST use the pinned versions from `docs/setup.md → stack_versions.components` — NEVER the LLM's "knowledge" of versions.

> **Stack-agnostic rule:** Only the config files relevant to the **selected stack** are generated. The table below maps artifact categories to their version source — apply only the rows matching the project's stack.

| Artifact Category | Version Source | Applies When |
| --- | --- | --- |
| Package manifest → runtime engine constraint | `stack_versions.components.{runtime}` | Runtime selected |
| Package manifest → dependency versions | `stack_versions.components.{package}` | Dependencies listed |
| Container image → base image tag | `stack_versions.components.{runtime}` | Containerized deployment |
| Dependency lock file / constraints file | `stack_versions.components.{package}` | Dependencies listed |
| Language version file (e.g., `.tool-versions`) | `stack_versions.components.{runtime}` | Runtime selected |
| IaC version constraint | `stack_versions.components.{iac_tool}` | IaC selected |
| CI/CD pipeline → runtime setup action | `stack_versions.components.{runtime}` | CI/CD configured |
| Docker Compose → service image tags | `stack_versions.components.{service}` | Infrastructure services selected |

**INVARIANT:** If a version is needed during materialization and `stack_versions` doesn't have it, the agent MUST resolve it via runtime query (same as VVP Step 2) — NEVER guess from LLM knowledge.

### 4.2.2 Constitution Generation
9-step process reading `docs/setup.md` → template → `docs/constitution.md`:
1. Read template from `.context/templates/setup/constitution/constitution_template.md`
2. Map project_name, business_goal, project_mode
3. Map backend stack (runtime, framework, topology, communication_style)
4. Map frontend stack (framework, meta_framework, pattern, state_management)
5. Map database configuration (primary, secondary, cache)
6. Map hosting/DevOps (provider, iac_tool, secrets_manager, ci_cd)
7. Map security/compliance settings
8. Map AI capabilities if enabled
9. Write final constitution to `docs/constitution.md`

**Placeholder Resolution:** Every `{{PLACEHOLDER}}` in template maps to a `docs/setup.md` field. If a field is empty/null, use the default from the template. Never leave unresolved `{{placeholders}}`.

### 4.2.3 Rules Generation
Dynamic template scanning with technology-specific best practices:

**Phase A — Standard Rules:**
Scan `.context/templates/setup/rules/` for all `.md` templates. For each template:
1. Read template content
2. Resolve placeholders from `docs/setup.md` + `docs/constitution.md`
3. Write to `.claude/rules/{rule_name}.md`

Standard rules materialized to `.claude/rules/`: `architecture.md`, `security_policy.md`, `testing.md`, `branching.md`, `ci-cd.md`, `database.md`, `observability.md`, `performance.md`, `ux-constitution.md`, `contract-first-policy.md`, `immutability_policy.md`, `ai_budget_tracker.md`, `ai_budget_governance.md`, `stateless.md`, `privacy.md`, `project-mode.md`, `configuration.md`, `i18n.md`, `documentation.md`, `dependencies.md`, `frontend_architecture_compatibility.md`, `html-css.md`. Config artefacts materialized to `config/`: `protected-paths.json`, `allowlist.json`, `quality.json` (see Quality Configuration below), `coherence-context.json` (copied as-is from `.context/templates/setup/config/coherence-context.json` — its `context: "downstream"` field is NEVER edited; consumed by factory-pr-review Phase 0).

**Phase B — Technology-Specific Best Practices:**
For each detected technology (backend.runtime, frontend.framework):
1. Check if `.context/templates/setup/rules/{technology}.md` exists
2. **FOUND:** Use template, resolve placeholders, write to `.claude/rules/{technology}.md`
3. **NOT_FOUND:** Auto-generate using 12-section structure with MANDATORY frontmatter:
   - **Step 3a — Generate frontmatter** using this exact structure (ADP-conformant per ADR-EVOL-028):
     ```yaml
     ---
     description: "{Technology} coding standards — naming conventions, patterns, error handling, testing. Applied automatically when editing {Technology} files."
     applicable_when:
       path_glob:
         - "{glob_1}"
         - "{glob_2}"
       framework: ["{technology_lc}"]
     version: 1.0.0
     date: {CURRENT_DATE}
     changelog:
       - "1.0.0: Auto-generated during SETUP materialization"
     ---
     ```
   - **Step 3b — Derive `path_glob` list** from technology name (factory-applicability-discovery scans these). Common mappings (one entry per glob — list form, NOT brace expansion):
     | Technology | `path_glob` entries |
     |------------|---------------------|
     | Python | `**/*.py` |
     | Node.js / JavaScript | `**/*.js`, `**/*.ts`, `**/*.mjs`, `**/*.cjs` |
     | React / Next.js | `**/*.jsx`, `**/*.tsx` |
     | Java | `**/*.java` |
     | C# / .NET | `**/*.cs`, `**/*.csx` |
     | Go | `**/*.go` |
     | Rust | `**/*.rs` |
     | Ruby | `**/*.rb` |
     | Kotlin | `**/*.kt`, `**/*.kts` |
     | Swift | `**/*.swift` |
     | PHP | `**/*.php` |
     | Vue | `**/*.vue` |
     | Angular | `**/*.ts`, `**/*.html` |
     | Svelte | `**/*.svelte` |
     For unlisted technologies: derive extensions from official language documentation. Always emit each extension as a separate list entry (the validator parses globs, brace expansion is not interpreted).
   - **Step 3c — Generate body** with 12-section structure:
     Naming conventions, file organization, error handling, logging, testing, security, performance, dependency management, documentation, versioning, deployment, monitoring
4. Apply technology-specific deny lists and mandatory patterns

**Phase B.1 — Defect Prevention Catalog (Stack-Aware Materialization):**

The `defect-prevention.md` template uses a `{{DC_ENTRIES}}` placeholder that MUST be populated with starter defect classes based on the project's stack. These are defects that **pass all static gates** but **break at runtime** — the gap between static verification and deployed behavior. Each entry renders ONE row in the catalog table (7 columns) and ONE case in the annex `defect-prevention-cases.md`.

**Schema note:** every entry carries `family` (one of the catalog `## Families` ids), `invariant` (one line, ≤ `budgets.dc_invariant_max_chars`, no `|`), `gate` (the mechanical check that proves it, or `—`), `paths` (globs the DC governs; `["*"]` = universal, embedded in the governance snapshot), `applicable_to` (enum list of the SDLC agents that MUST consult this entry — `CODESIGN`, `BLUEPRINT`, `IMPLEMENT`, `REVIEW`, `DEVOPS`, `QA`, `AUDIT`; most entries are `[IMPLEMENT, REVIEW]`; UX patterns add `CODESIGN`; architectural add `BLUEPRINT`; infra add `DEVOPS`; test-surface add `QA`; enduring patterns add `AUDIT`), `severity`, and `case` (`origin`, `story`, `detection` — the narrative, never in the row). Scope filtering is by `paths`: a backend-only feature never touches `src/**/frontend/**`, so UI rows never fire for it. The starter DCs below use sensible defaults — projects extend them via the Discovery Protocol.

```yaml
FUNCTION materialize_defect_prevention(setup_md, constitution_md):
  dc_entries = []

  # --- Field reference: setup_md fields come from docs/setup.md (SETUP --init Q answers) ---
  # backend.topology: Q7 → B1..B12
  # backend.runtime: Q5 → Node.js, Python, Java, Go, etc.
  # frontend.framework: Q9 → React, Vue.js, Angular, Svelte, Solid, None
  # frontend.pattern: Q11 → F1..F10
  # auth.strategy: Q18 → "JWT (stateless)", "Session-based", "OAuth2/OIDC (external provider)", etc.

  # ============================================================================
  # UNIVERSAL META-PATTERNS — shipped on every project regardless of stack
  # ============================================================================
  # Derived from empirical post-deploy defect clusters across multiple stacks.
  # Each entry describes a PATTERN (stack-neutral); stack-specific manifestations
  # live in the case story. `paths` gates which files consume the row at runtime —
  # a pure library project with no CI never touches `.github/**`, so DC-PIPE never fires.

  # DC: Pipeline short-circuit silently skips downstream gates
  ADD DC: {
    name: "Pipeline short-circuit silently skips downstream gates",
    family: "infra",
    invariant: "No gate rests on a raw producer-to-consumer pipe; every gate tests captured output and demonstrably fails when its precondition is unmet.",
    gate: "—",
    paths: [".github/**", "scripts/**", "**/*.sh", "**/*.ps1", "**/Makefile", "**/Jenkinsfile", "**/.gitlab-ci.yml"],
    applicable_to: ["IMPLEMENT", "REVIEW", "DEVOPS", "AUDIT"],
    severity: "BLOCKER",
    case: {
      origin: "bash `find … | grep -q` under `set -o pipefail`: SIGPIPE kills the producer, the gate silently passes while its precondition is unmet.",
      story: "Authoring CI / build / verification scripts that chain producers and consumers via shell pipes, Make recipes, or platform script blocks. Manifestations: PowerShell pipelines with `$ErrorActionPreference = \"Stop\"`; Python subprocess pipes with check=True; Make rules with `$(shell … | …)`; Jenkins `sh` steps; GitLab script blocks. Under shell pipefail (and equivalents) the consumer can close the pipe early, the producer dies with SIGPIPE and the gate silently passes.",
      detection: "Never gate on a raw `producer | consumer -q` idiom. Use explicit boolean tests on captured output (e.g. `[ -n \"$(producer -print -quit)\" ]`), a named helper, or the ecosystem's idiomatic `set_check` primitive. Dry-run every gate with a precondition that should fail and verify the gate actually fails."
    }
  }

  # DC: Identity-argument no-op transforms
  ADD DC: {
    name: "Identity-argument no-op in string / DOM transforms",
    family: "runtime",
    invariant: "A transform called with a possibly-empty parameter is guarded or its output asserted; UI tests assert every rendered element, not only the wrapper label.",
    gate: "—",
    paths: ["src/**", "tests/**"],
    applicable_to: ["IMPLEMENT", "REVIEW", "QA"],
    severity: "BLOCKER",
    case: {
      origin: "JS `padEnd(\"\")` / `padStart(\"\")` / `replace(empty, …)` returning the input unchanged; label-only DOM assertions passing on a blank surface.",
      story: "Calling padding, trimming, replacement, formatting, template, or class-concat functions with a parameter that may legitimately be empty, null, or zero. Many ecosystems return the input unchanged when the transform parameter is an identity value (empty string, zero-length array, null delimiter). The call looks correct and type-checks cleanly. Manifestations: Python `str.format(\"\")`; Java `String.format(\"\")`; CSS class concat with empty string; i18n fallback `\"\"`; test-side: asserting only the label wrapper while children render empty.",
      detection: "Guard the parameter OR assert a post-condition on the output (expected length, substring presence, rendered element count) — never trust the call itself. For UI component tests, every rendered element MUST be asserted in the DOM, not just the wrapper label: a zero-input render passes label-only assertions while delivering a blank surface to the user."
    }
  }

  # DC: Framework-layer validation errors invisible to application logs
  ADD DC: {
    name: "Framework-layer validation errors invisible to application logs",
    family: "boundary",
    invariant: "Every validation layer ahead of the handler (middleware, gateway, WAF, framework) emits a structured log entry before returning its 4xx.",
    gate: "—",
    paths: ["src/**/api/**", "src/**/middleware/**", "src/**/handlers/**", "infra/**"],
    applicable_to: ["BLUEPRINT", "IMPLEMENT", "DEVOPS", "QA", "AUDIT"],
    severity: "WARNING",
    case: {
      origin: "A 4xx spike with NO corresponding ERROR line in application logs — a contract / DTO / schema mismatch between client and server, not a bug in the use case code.",
      story: "Any system with schema, DTO, or request validation performed by a middleware, gateway, WAF, or framework layer ahead of the application handler. Manifestations: FastAPI/Pydantic 422 responses invisible to app logs; Express middleware Zod/Joi rejections; Spring @Valid pre-controller errors; ASP.NET Core model binding failures; GraphQL schema validation; gRPC reflection; API Gateway request validation (AWS/Kong/Nginx/Apigee); WAF rules; ModSecurity.",
      detection: "Diagnosis playbook: (1) diff the request payload against the declared schema; (2) only enter use case code after that has been ruled out. Prevention: configure the validation layer (middleware, gateway, framework error handler) to emit a structured log entry with the validation detail before returning the 4xx, so application observability sees the event. Document which error classes are filtered at the gateway vs reaching the handler."
    }
  }

  # DC: Mutation APIs with replace semantics reset omitted fields
  ADD DC: {
    name: "Mutation APIs with replace semantics reset omitted fields",
    family: "boundary",
    invariant: "No partial payload reaches an update / PUT / replace endpoint; every mutation of shared external state is read-current → merge delta → submit merged.",
    gate: "—",
    paths: ["src/**/adapters/**", "src/**/clients/**", "src/**/integrations/**", "infra/**"],
    applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS", "AUDIT"],
    severity: "BLOCKER",
    case: {
      origin: "AWS `update-function-configuration` resetting every env var not passed in the call.",
      story: "Any code path that mutates shared external state via an update / PUT / replace endpoint — cloud control planes, directory services, ERP / CRM objects, Kubernetes resources, REST PUT endpoints, GraphQL mutations, IaC providers. Manifestations: Azure ARM PUT replacing the whole resource; GCP `resource.update` default replace; Kubernetes `kubectl apply` vs `patch` semantics; Terraform replace triggers; LDAP / Active Directory `Set-ADUser` clearing array attributes; SAP BAPIs; REST PUT on aggregate roots; GraphQL mutations without input defaults. Many endpoints are replace-whole-state, not patch-delta — the omitted fields get reset to defaults or removed.",
      detection: "Never call a mutation endpoint with a partial payload while assuming omitted fields are preserved. Mandatory pattern: read-current-state → merge delta → submit merged payload. Document each integration's semantics (replace vs patch) in the adapter / integration doc. Where the ecosystem offers both (e.g. K8s `apply` vs `patch`), codify which one is allowed and why."
    }
  }

  # DC: Composite network symptoms require layered root-cause triage
  ADD DC: {
    name: "Composite network symptoms require layered root-cause triage",
    family: "process",
    invariant: "A network symptom (CORS, 502, refused, auth, TLS) is triaged by layer from captured evidence before any code changes.",
    gate: "—",
    paths: ["*"],
    applicable_to: ["BLUEPRINT", "IMPLEMENT", "DEVOPS", "QA"],
    severity: "WARNING",
    case: {
      origin: "Browser \"blocked by CORS policy\" with 4+ distinct causes chased by random application-layer edits.",
      story: "Debugging a single network-layer symptom reported by the client, browser, or upstream service. A single symptom class (CORS blocked, 502 Bad Gateway, connection refused, auth fail, TLS handshake) typically has 3+ distinct root causes spread across application / middleware / infrastructure / client configuration. Manifestations: CORS (missing Access-Control-Allow-Origin; authorizer short-circuit returning before CORS middleware; redirect stripping CORS headers; method not in allowMethods); TLS handshake failures (cert, SNI, cipher, protocol version); 502/504 (upstream down, timeout, DNS, routing); connection refused (port, firewall, bind, service down); auth fails (token expired, audience mismatch, clock skew, bad signature); Kerberos (7+ distinct causes); mTLS handshake. Random edits in the application layer cannot fix middleware or infrastructure causes.",
      detection: "For each symptom class, maintain a decision tree that captures raw evidence first (e.g. `curl -i -X OPTIONS …` for CORS; `openssl s_client -connect …` for TLS; platform access logs for 502; packet capture when needed), then disambiguates the layer before code changes. Document the tree per symptom in `.claude/rules/` or runbook — add entries as new symptom classes surface."
    }
  }

  # ============================================================================
  # INTEGRATION / BACKEND-ONLY DCS — shipped when
  # project_scope IN [full-stack, backend-only, integration]
  # ============================================================================
  # These 7 DCs target the defect cluster specific to features that process
  # requests without a first-party UI (APIs, workers, webhooks, consumers, cron).
  # Their `paths` are boundary surfaces (api / handlers / adapters / consumers /
  # workers / contracts) — a feature fires them only when it touches those files,
  # which keeps the constraint set aligned with test_plan § 2.2 Reliability Testing
  # and dev_plan § Reliability Tests (themselves applicable to scope IN
  # [backend-only, integration]). A full-stack feature that needs reliability-
  # flavoured concerns (idempotency, retry, circuit breaker, DLQ, graceful shutdown)
  # should be sliced into a dedicated backend-only or integration feature per the
  # compatibility matrix (the full-stack project still accepts it).
  # Guard the whole BLOCK by project_scope because SETUP materialisation runs
  # BEFORE any feature exists — the catalog ships once, per project. The per-file
  # filter happens later at consult_defect_catalog time.
  # Don't materialise any of them into frontend-only projects.
  IF setup_md.project_scope IN ["full-stack", "backend-only", "integration"]:

    # DC: Missing idempotency keys on mutating operations
    ADD DC: {
      name: "Missing idempotency keys on mutating operations",
      family: "boundary",
      invariant: "Every retryable mutating operation accepts an idempotency key; the dedupe record lives in the side-effect's transaction and replay returns the cached response.",
      gate: "Reliability test: replayed request returns the cached response, never re-executes (`test_plan § 2.2`)",
      paths: ["src/**/api/**", "src/**/handlers/**", "src/**/consumers/**", "src/**/webhooks/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "QA"],
      severity: "BLOCKER",
      case: {
        origin: "Retry-enabled callers (browser retry, mobile retry, queue at-least-once delivery, webhook retry) re-executing payments, orders and provisioning.",
        story: "Designing or implementing an inbound endpoint / handler that mutates shared state (payment processing, order creation, resource provisioning, webhook inbound, queue consumer). BLOCKER when the mutation has no dedupe strategy and the caller is a retry-enabled client.",
        detection: "Every mutating operation that can be retried by the caller MUST accept an idempotency key (HTTP `Idempotency-Key` header, message attribute, or body field). Key format: UUID v4 minimum, or natural composite key (e.g. customer_id + external_ref). Store a short-TTL dedupe record (key → response_hash, response_payload) in the same transactional boundary as the side-effect. Replay returns cached response, never re-executes."
      }
    }

    # DC: Retries without exponential backoff + jitter
    ADD DC: {
      name: "Retries without exponential backoff + jitter",
      family: "boundary",
      invariant: "Every remote call declares max attempts, base delay, exponential factor and jitter through the platform retry primitive; no tight-loop or fixed-interval retry.",
      gate: "Reliability test: transient failure produces the declared backoff schedule; `retry_count` metric emitted per call (`test_plan § 2.2`)",
      paths: ["src/**/adapters/**", "src/**/clients/**", "src/**/integrations/**", "src/**/consumers/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS", "QA"],
      severity: "BLOCKER",
      case: {
        origin: "Thundering-herd outage when a downstream recovers under tight-loop or fixed-interval retries.",
        story: "Calling a downstream service, queue broker, or external API that can transiently fail. No tight-loop retries, no fixed-interval retries — both cause thundering-herd outages when the downstream recovers.",
        detection: "Every remote call MUST declare: max attempts (e.g. 5 for idempotent, 0-1 for non-idempotent without idempotency key), base delay (e.g. 2s), exponential factor (e.g. 2x), jitter (random 0-50% of computed delay). Use the platform's native retry primitive (AWS SDK retry strategy, Polly for .NET, tenacity for Python, p-retry for Node) rather than hand-rolling. Emit `retry_count` metric per call."
      }
    }

    # DC: Missing circuit breaker on unreliable downstreams
    ADD DC: {
      name: "Missing circuit breaker on unreliable downstreams",
      family: "boundary",
      invariant: "Every call to an unreliable downstream is wrapped in a circuit breaker with failure threshold, open duration and half-open probe; state and trips are metered.",
      gate: "Observability check: `circuit_state` gauge and `circuit_trips` counter exist per downstream",
      paths: ["src/**/adapters/**", "src/**/clients/**", "src/**/integrations/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS"],
      severity: "BLOCKER",
      case: {
        origin: "Caller retry logic turning every downstream outage into a thundering-herd cascade and a cost spike on per-request pricing APIs.",
        story: "Calling a downstream that has a history of outages, rate limits, or SLA breaches (any third-party API, cross-region DB, federated auth provider).",
        detection: "Wrap calls to unreliable downstreams in a circuit breaker with: failure threshold (e.g. 5 failures in 30s window), open duration (e.g. 60s), half-open probe strategy (single request, re-close on success, re-open on failure). Metrics: `circuit_state` gauge (0=closed, 1=half-open, 2=open), `circuit_trips` counter. Use platform primitives (Polly / resilience4j / Hystrix / opossum)."
      }
    }

    # DC: Missing structured logging + trace propagation on integration hops
    ADD DC: {
      name: "Missing structured logging + trace propagation on integration hops",
      family: "boundary",
      invariant: "Every boundary-crossing handler emits structured JSON logs with trace and correlation ids and propagates W3C Trace Context (or platform equivalent) outbound.",
      gate: "Observability check: `trace_id` present on every log line of one cross-service request",
      paths: ["src/**/api/**", "src/**/handlers/**", "src/**/adapters/**", "src/**/consumers/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS", "QA", "AUDIT"],
      severity: "WARNING",
      case: {
        origin: "A failed integration request spanning 3 services appearing as 3 unrelated log entries — root cause analysis costs hours instead of minutes.",
        story: "Implementing any handler that receives OR emits a request spanning service boundaries.",
        detection: "Every handler MUST: (1) emit structured logs (JSON) with at minimum `trace_id`, `correlation_id`, `feature_id`, `idempotency_key`, `error_code` (when error). (2) Propagate trace context on outbound calls using W3C Trace Context (`traceparent` / `tracestate` headers) OR the ecosystem equivalent (B3 for OpenTracing, X-Amzn-Trace-Id for AWS, X-Cloud-Trace-Context for GCP). (3) Accept inbound trace context and continue the trace rather than starting a new one."
      }
    }

    # DC: API contract versioning without backward-compat strategy
    ADD DC: {
      name: "API contract versioning without backward-compat strategy",
      family: "boundary",
      invariant: "Every published contract follows a declared versioning strategy; no breaking change without a new major version and a deprecation window.",
      gate: "factory-pr-review axis 3 (API contracts) · REVIEW Check #2d on contract diffs",
      paths: ["**/contracts/**", "**/*.openapi.*", "**/*.asyncapi.*", "**/*.proto", "**/*.graphql", "src/**/api/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS"],
      severity: "BLOCKER",
      case: {
        origin: "Breaking change shipped WITHOUT a new major version + deprecation window = silent consumer breakage.",
        story: "Publishing a contract (OpenAPI / AsyncAPI / gRPC / GraphQL SDL) that external consumers depend on — any scope=integration feature, or scope=backend-only feature that has at least one external consumer in consumes_contract.",
        detection: "Contract versions MUST follow a declared strategy: (a) URI versioning (/v1/, /v2/) for REST, (b) package-level versioning (package myapi.v1) for gRPC, (c) schema-evolution rules (additive fields only; never remove/rename without deprecation) for AsyncAPI/Avro/Protobuf, (d) `@deprecated` + sunset dates for GraphQL. Document the strategy in design.md § 2 Constraints + ADR. REVIEW blocks on: field removals without deprecation; type narrowing of request fields; type widening of response fields without opt-in."
      }
    }

    # DC: Missing dead-letter queue handling for async consumers
    ADD DC: {
      name: "Missing dead-letter queue handling for async consumers",
      family: "boundary",
      invariant: "Every async consumer declares a dead-letter destination at infra level, forwards exhausted messages with full context, and ships replay tooling.",
      gate: "Infra check: a DLQ resource is declared per consumer (`devops_plan § Reliability Checks`)",
      paths: ["src/**/consumers/**", "src/**/workers/**", "src/**/webhooks/**", "infra/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS", "QA"],
      severity: "BLOCKER",
      case: {
        origin: "A single poison message blocking the queue indefinitely, or silently dropped after retry exhaustion — data loss invisible until downstream reports missing records weeks later.",
        story: "Implementing a queue consumer, event handler, or webhook inbound endpoint that can fail permanently (max retries exhausted, poison message).",
        detection: "Every async consumer MUST have a dead-letter destination declared at infra level (SQS DLQ, RabbitMQ dead-letter exchange, Kafka DLQ topic, EventBridge rule with failure pattern). Max-retries threshold MUST send the failed message WITH FULL CONTEXT (original payload + retry history + last error + timestamp) to the DLQ — not just drop it silently. Replay tooling MUST exist (runbook + script) so operators can re-enqueue after fixing root cause."
      }
    }

    # DC: Missing graceful shutdown (SIGTERM / drain) handling
    ADD DC: {
      name: "Missing graceful shutdown (SIGTERM / drain) handling",
      family: "runtime",
      invariant: "On SIGTERM the process stops intake, reports unhealthy, drains in-flight work within the configured window, and exits 0 (drained) or 143 (timeout).",
      gate: "Reliability test: SIGTERM during an in-flight request ends in a drained exit (`test_plan § 2.2`)",
      paths: ["src/**/main.*", "src/**/server.*", "src/**/entrypoint*", "src/**/workers/**", "src/**/consumers/**", "src/**/jobs/**"],
      applicable_to: ["IMPLEMENT", "REVIEW", "DEVOPS"],
      severity: "BLOCKER",
      case: {
        origin: "Orchestrator termination mid-request: in-flight requests killed mid-transaction, partial database writes, unacked messages, 502 responses to callers.",
        story: "Implementing a long-running service, worker, queue consumer, or cron job — any process that can be terminated by the orchestrator mid-request. Exit behaviour belongs to the runtime entry point (not use-case code) — verify at service boundary.",
        detection: "On SIGTERM, the service MUST: (1) stop accepting new requests / messages (close listener or set drain flag). (2) Mark health endpoint as unhealthy (orchestrator stops routing to this instance). (3) Complete or checkpoint in-flight work within the drain window (configurable; orchestrator-coordinated: Kubernetes terminationGracePeriodSeconds, AWS ALB deregistration delay). (4) Exit 0 when drained, or 143 on drain timeout (signal-exit convention)."
      }
    }

  # ============================================================================
  # STACK-CONDITIONAL DCS — only materialize when the project matches the scope
  # ============================================================================

  # DC: Async handler in serverless entry point
  # Q7 backend.topology == "B9" (Serverless)
  IF setup_md.backend.topology == "B9":
    ADD DC: {
      name: "Async handler in serverless entry point",
      family: "runtime",
      invariant: "Every serverless handler signature matches the runtime contract; async handlers the runtime does not await are wrapped in a sync entry point.",
      gate: "—",
      paths: ["src/**/handlers/**", "src/**/functions/**", "**/serverless.*", "infra/**"],
      applicable_to: ["IMPLEMENT", "REVIEW", "DEVOPS", "AUDIT"],
      severity: "BLOCKER",
      case: {
        origin: "A serverless runtime that does not auto-await async handlers — the function returns before the work finishes.",
        story: "Writing a serverless function handler.",
        detection: "Verify handler signature matches the serverless runtime contract. Some runtimes do not auto-await async handlers — use sync wrapper + async runtime."
      }
    }

  # DC: Missing frontend context providers
  # Q9 frontend.framework != "None"
  IF setup_md.frontend.framework != "None":
    ADD DC: {
      name: "Missing frontend context providers",
      family: "ui",
      invariant: "Every context-based hook used in a component has its Provider mounted above it (root layout or parent).",
      gate: "—",
      paths: ["src/**/frontend/**", "**/*.tsx", "**/*.jsx", "**/*.vue", "**/*.svelte"],
      applicable_to: ["IMPLEMENT", "REVIEW"],
      severity: "BLOCKER",
      case: {
        origin: "Context hook rendered outside its Provider — silent null or runtime crash.",
        story: "Using a context-based hook in a component.",
        detection: "Before using a context-based hook, verify its Provider exists in the component tree (root layout or parent). Missing Provider = silent null or runtime crash."
      }
    }

  # DC: Post-action navigation gaps
  # Q9 frontend.framework != "None" AND Q11 frontend.pattern uses client-side routing (F1, F2, F4, F8, F9)
  IF setup_md.frontend.framework != "None" AND setup_md.frontend.pattern IN ["F1", "F2", "F4", "F8", "F9"]:
    ADD DC: {
      name: "Post-action navigation gaps",
      family: "ui",
      invariant: "Every form submission success handler navigates (push / replace / redirect); the user never lands on a stale form.",
      gate: "—",
      paths: ["src/**/frontend/**", "**/*.tsx", "**/*.jsx", "**/*.vue", "**/*.svelte"],
      applicable_to: ["CODESIGN", "IMPLEMENT", "REVIEW", "QA"],
      severity: "WARNING",
      case: {
        origin: "Successful submit with no navigation — the user sees the stale form and resubmits.",
        story: "Writing form onSubmit/onSuccess handlers under client-side routing.",
        detection: "Every form submission success MUST include navigation (router.push/replace/redirect). Without it, user sees stale form."
      }
    }

  # DC: Session/state rehydration on mount
  # Q11 frontend.pattern uses SSR/hydration (F2 = SSR+hydration, F4 = ISR)
  IF setup_md.frontend.pattern IN ["F2", "F4"]:
    ADD DC: {
      name: "Session/state rehydration on mount",
      family: "ui",
      invariant: "Auth and session hooks check for an existing session on mount and start in loading=true until proven otherwise.",
      gate: "—",
      paths: ["src/**/frontend/**", "src/**/auth/**", "src/**/hooks/**", "**/*.tsx", "**/*.jsx"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW"],
      severity: "WARNING",
      case: {
        origin: "Hydrated page flashing the logged-out state for an authenticated user.",
        story: "Writing auth hooks or session state initialization under SSR / hydration.",
        detection: "Auth/session hooks MUST check for existing sessions on mount. Initial loading state MUST be true (assume loading until proven otherwise)."
      }
    }

  # DC: Responsive design / mobile gaps
  # Q9 frontend.framework != "None"
  IF setup_md.frontend.framework != "None":
    ADD DC: {
      name: "Responsive design / mobile gaps",
      family: "ui",
      invariant: "Every layout has a mobile toggle, every table a horizontal-scroll wrapper, and no fixed width lacks a responsive breakpoint.",
      gate: "QA SMOKE-E2E at a mobile viewport (Chrome DevTools MCP)",
      paths: ["src/**/frontend/**", "**/*.tsx", "**/*.jsx", "**/*.vue", "**/*.svelte", "**/*.css", "**/*.scss"],
      applicable_to: ["CODESIGN", "IMPLEMENT", "REVIEW", "QA"],
      severity: "WARNING",
      case: {
        origin: "Dashboards, data tables and navigation unusable on a phone viewport.",
        story: "Writing dashboard layouts, data tables, or navigation.",
        detection: "Layouts MUST include a mobile toggle. Tables MUST have horizontal scroll wrapper. No fixed widths without responsive breakpoints."
      }
    }

  # DC: Frontend env var injection mismatch
  # Q9 frontend.framework != "None" AND Q7 backend.topology == "B9" (serverless IaC manages env vars)
  IF setup_md.frontend.framework != "None" AND setup_md.backend.topology == "B9":
    ADD DC: {
      name: "Frontend env var injection mismatch",
      family: "infra",
      invariant: "Every env var read in frontend code is declared AND injected by the IaC / deployment configuration.",
      gate: "Infra check: declared frontend env keys ⊇ keys read in code (`devops_plan § Verification Script`)",
      paths: ["src/**/frontend/**", "infra/**", "**/.env*", "**/serverless.*"],
      applicable_to: ["IMPLEMENT", "REVIEW", "DEVOPS"],
      severity: "BLOCKER",
      case: {
        origin: "Frontend reading an env var the serverless IaC never injects — undefined at runtime.",
        story: "Reading environment variables in frontend code when serverless IaC manages env vars.",
        detection: "When reading a frontend env var in code, verify it is declared AND injected by the IaC/deployment configuration. Missing injection = undefined at runtime."
      }
    }

  # DC: Hooks ordering violation
  # Q9 frontend.framework IN ["React", "Vue.js", "Solid"] — frameworks with hook/composition model
  # Note: Angular uses decorators (no hook ordering issue), Svelte uses stores (no hook ordering issue)
  IF setup_md.frontend.framework IN ["React", "Vue.js", "Solid"]:
    ADD DC: {
      name: "Hooks ordering violation",
      family: "ui",
      invariant: "Every hook / composable call sits before any conditional return; call order is identical across renders.",
      gate: "Lint: rules-of-hooks (project ESLint or equivalent)",
      paths: ["**/*.tsx", "**/*.jsx", "**/*.vue"],
      applicable_to: ["IMPLEMENT", "REVIEW"],
      severity: "BLOCKER",
      case: {
        origin: "A hook after a conditional return — different call order between renders, runtime error.",
        story: "Writing components with hooks/composables. Angular uses decorators and Svelte uses stores — no hook ordering issue there.",
        detection: "ALL hook/composable calls MUST be placed BEFORE any conditional return. Hooks after conditional returns cause runtime errors (different call order between renders)."
      }
    }

  # DC: Backend-frontend contract mismatch
  # Applies when project has BOTH backend AND frontend AND uses contract-first policy
  # Contract-first policy is always materialized as .claude/rules/contract-first-policy.md
  # when both backend and frontend exist (Phase A standard rules)
  IF setup_md.frontend.framework != "None" AND setup_md.backend.runtime != "None":
    ADD DC: {
      name: "Backend-frontend contract mismatch",
      family: "boundary",
      invariant: "Every frontend API call matches the backend route in path, method and field names, cross-referenced against the contract file.",
      gate: "factory-pr-review axis 3 (API contracts)",
      paths: ["src/**/api/**", "src/**/frontend/**", "**/contracts/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "QA", "AUDIT"],
      severity: "BLOCKER",
      case: {
        origin: "Client call and route handler drifting apart (path, method, field names) while both compile.",
        story: "Writing API client calls (frontend) or route handlers (backend).",
        detection: "Every frontend API call MUST match the backend route: same path, same method, same field names. Cross-reference against the contract file."
      }
    }

  # DC: External identity ID != internal DB primary key
  # Q18 auth.strategy == "OAuth2/OIDC (external provider)" — external provider manages identity
  # Also applies when auth.strategy == "JWT (stateless)" AND an external IdP is configured (Q18 follow-up)
  IF setup_md.auth.strategy == "OAuth2/OIDC (external provider)":
    ADD DC: {
      name: "External identity ID != internal DB primary key",
      family: "data",
      invariant: "An external identity claim (sub, oid, uid) is resolved only through a dedicated external-id lookup, never passed to a primary-key lookup.",
      gate: "—",
      paths: ["src/**/auth/**", "src/**/services/**", "src/**/use_cases/**", "src/**/usecases/**", "src/**/repositories/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "AUDIT"],
      severity: "BLOCKER",
      case: {
        origin: "External provider `sub` passed to `get_by_id()` against the internal primary key — wrong or missing user.",
        story: "Writing use cases/services that receive identity claims from auth tokens issued by an external provider.",
        detection: "When receiving an identity claim (sub, oid, uid) from an external auth provider, ALWAYS use a dedicated lookup method (e.g., get_by_external_id). NEVER pass the external ID to a get_by_id() that queries the internal DB primary key."
      }
    }

  # DC: Cross-module direct data access
  # Q7 backend.topology NOT IN ["B1", "B12"] — any architecture with module boundaries
  IF setup_md.backend.topology NOT IN ["B1", "B12", "None"]:
    ADD DC: {
      name: "Cross-module direct data access",
      family: "data",
      invariant: "No module reads or writes another module's tables or collections directly; access goes through ports + adapters, API calls or domain events.",
      gate: "—",
      paths: ["src/**/repositories/**", "src/**/models/**", "**/*.sql", "src/**"],
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "AUDIT"],
      severity: "BLOCKER",
      case: {
        origin: "A module querying a sibling module's tables — hidden coupling that breaks on the next schema change.",
        story: "Writing data access code (SQL, ORM queries, repository methods) in any architecture with module boundaries. Enforced by contract-first policy.",
        detection: "A module MUST NOT access another module's tables/collections directly. Use ports/interfaces + adapters, API calls, or domain events."
      }
    }

  # Materialize: one row per entry into the catalog table, one case per entry into the annex.
  # Row columns MUST match the template header:
  #   DC | Family | Invariant | Gate | Paths | Applicable To | Severity
  reserved  = ids already present in the template § Defect Classes (starter rows DC-18, DC-27, DC-28, DC-29)
  dc_number = 1
  rows = []; cases = []
  FOR EACH dc IN dc_entries:
    WHILE "DC-{dc_number}" IN reserved: dc_number += 1
    ASSERT dc.family IN template § Families
    ASSERT len(dc.invariant) <= budgets.dc_invariant_max_chars AND "\n" NOT IN dc.invariant AND "|" NOT IN dc.invariant
    rows.append("| DC-{dc_number} | `{dc.family}` | {dc.invariant} | {dc.gate} | {join(map(backtick, dc.paths), ', ')} | {join(dc.applicable_to, ', ')} | {dc.severity} |")
    cases.append("### DC-{dc_number} — {dc.name}\n\n**Origin:** {dc.case.origin}\n\n**Story:** {dc.case.story}\n\n**Detection:** {dc.case.detection}\n")
    dc_number += 1
  REPLACE {{DC_ENTRIES}} with rows (one per line)
  WRITE to .claude/rules/defect-prevention.md
  COPY template rules/defect-prevention-cases.md → .claude/rules/defect-prevention-cases.md; APPEND cases after the starter cases
```

**Phase C — Global Validation:**
After all rules generated, validate:
- All materialized files in `.claude/rules/` end with `.md` (no `.instructions.md` suffix — convention unified)
- All materialized files contain YAML frontmatter with `description:` field
- All **technology-specific** rules (Phase A language rules + Phase B) contain `applicable_when:` with `path_glob:` (a list of globs) and optionally `framework:`
- Cross-cutting rules (architecture, security_policy, branching, defect-prevention, etc.) declare `applicable_when: { always: true }` or omit the block entirely (treated as `always: true` for back-compat)
- Run `scripts/check-applicability-frontmatter.sh` — closed vocabulary validator (CI hard gate per ADR-EVOL-028). MUST exit 0
- No cross-rule contradictions
- All referenced tools/frameworks match `docs/setup.md` selections
- Technology-specific rules don't conflict with architecture rules

**Phase D — Applicability context (EVOL-043):** nothing is materialised. The one resolver (`python3 scripts/gate.py applicable`) reads its static axes from `docs/setup.md` frontmatter (`project_scope`, `backend.framework`, `frontend.framework`) and its dynamic axes from the runtime; a separate context file would be a second definition. Verify after Scripts Materialization: `python3 scripts/gate.py applicable --phase SETUP --format rollcall` prints a roll-call with the materialised laws and families.

### 4.2.4 Tripartite Scaffolding
Additive tree algorithm — builds directory structure from composable fragments:

**Step 0 — Dynamic Path Derivation:**

Resolve every base-path placeholder used downstream into a concrete project-relative path, and **persist the result into `docs/setup.md` under a new `paths:` section** so every subsequent consumer reads from a single source of truth instead of each re-deriving the path.

**Instructions (no lookup table — the agent uses standard ecosystem conventions for the selected stack):**

1. **For each of the following placeholders, resolve a concrete path** — derived from the discovery answers using well-known conventions of the selected runtime/framework/topology/pattern. The agent MUST use its knowledge of the target ecosystem's idiomatic layout (e.g., Java uses `src/main/java`, Angular uses `src/`, Next.js App Router uses `app/`, Go uses `cmd/` + `internal/`, microservices use a flat `services/` tree, serverless uses `functions/`, etc.). Do not hardcode `src/` for everything.

   | Placeholder | Driven primarily by | Typical when ambiguous |
   | --- | --- | --- |
   | `{{BACKEND_BASE_PATH}}` | Q5 runtime + Q7 topology | Monolith → runtime's idiomatic root; distributed → `services/`; serverless → `functions/` |
   | `{{BACKEND_MODULES_PATH}}` | Q7 topology | Modular topologies → `{backend_base}/modules`; pure monolith → `{backend_base}` |
   | `{{FRONTEND_BASE_PATH}}` | Q9 framework + Q10 meta-framework + Q11 pattern | Framework's idiomatic root; micro-frontend patterns → `apps/` |
   | `{{INTEGRATION_BASE_PATH}}` | Q7 topology | Monolith → `{backend_base}/shared`; distributed → top-level `integration/` |
   | `{{AI_BASE_PATH}}` | Q24a/b/c AI capabilities | Under `{backend_base}/ai` when any AI capability is enabled; null otherwise |
   | `{{ML_BASE_PATH}}` | Q24a training | Top-level `ml/` when training is enabled; null otherwise |
   | `{{CONTRACTS_BASE_PATH}}` | Fixed | Always `contracts/` (cross-stack) |
   | `{{CONFIG_BASE_PATH}}` | Fixed | Always `config/` |
   | `{{SCRIPTS_BASE_PATH}}` | Fixed | Always `scripts/` |
   | `{{INFRA_BASE_PATH}}` | Q20 hosting + Q20.1 iac_tool | Always `infra/` (dir exists even without IaC) |
   | `{{MONOREPO_APPS_PATH}}` | Project structure (detected or declared) | `apps/` when monorepo; null otherwise |
   | `{{TESTS_BASE_PATH}}` | Q5 runtime | Runtime's idiomatic test root (e.g., Java's `src/test/java`, Go's inline `_test.go` → null, Ruby's `spec/` or `test/`, etc.) |

2. **When the convention is ambiguous** (e.g., Python can use either `src/` or `app/` depending on the framework; Ruby can use `spec/` for RSpec or `test/` for Minitest; the user may have a non-standard preference), **invoke RDR** (Recommendation → Decision → Ratification):
   - Present the agent's recommendation with justification ("Next.js App Router defaults to `app/` since v13; classic `pages/` is legacy").
   - Offer 2-3 alternatives.
   - Persist the chosen path as an ADR entry under `docs/project_log/adr/ADR-0000-setup-decisions.md § Path Decisions`.

3. **Brownfield override** (Q3 == `After`). Paths for existing projects MUST be discovered from the current workspace via the AUDIT scan or Q3.3 Protected Code Paths answer. The user's existing layout wins over any convention. Log each override as an ADR entry.

4. **Persist the resolved map** to `docs/setup.md`:

   ```yaml
   # docs/setup.md — added by SETUP --generate Step 0
   paths:
     backend_base:       "{resolved value}"
     backend_modules:    "{resolved value}"
     frontend_base:      "{resolved value or null}"
     integration_base:   "{resolved value}"
     ai_base:            "{resolved value or null}"
     ml_base:            "{resolved value or null}"
     contracts_base:     "contracts"
     config_base:        "config"
     scripts_base:       "scripts"
     infra_base:         "infra"
     monorepo_apps:      "{resolved value or null}"
     tests_base:         "{resolved value or null}"
   ```

5. **Substitute downstream placeholders.** With `setup_md.paths` populated, every downstream consumer template that contains `{{*_BASE_PATH}}` gets rendered with the concrete value from `setup_md.paths` in the same placeholder resolution pass that handles stack-specific placeholders (§ 4.2.1.2 Version Pinning and § 6.2 Adapter Placeholder Resolution). Any `{{*_BASE_PATH}}` that remains literal after this pass is a governance drift — BLOCK with a "dangling base path" diagnostic.

> **Rationale.** Before EVOL-014 this step was a 2-line stub ("Never hardcode `src/`") with no concrete wiring. The setup_master_template.md § C.2 listed the placeholder names but their resolution was left to each downstream consumer, which meant either silent drift (different files assuming different paths) or outright dangling placeholders in materialized output. Persisting the derived map in `setup.md` closes the loop: one source of truth, one derivation point, every consumer reads the same value. The framework is tech-agnostic by design — the derivation uses the agent's ecosystem knowledge rather than a hardcoded lookup table, so adding support for a new runtime/framework doesn't require editing this instruction file.

**Step 1 — Base Tree:**
Create common directories with `.gitkeep`:
```
docs/spec/
docs/project_log/adr/
docs/project_log/ai_budget_history/
docs/ux/vision/
config/
scripts/
contracts/
```

**Step 2 — Backend Fragments (CONDITIONAL — by topology B1-B12):**
IF `project_scope in [full-stack, backend-only, integration]` (Q4.5) AND `backend.runtime != "None"` (Q5):
  Add topology-specific directories matching the reference structures from discovery (see setup-discovery.md for B1-B12 directory maps).
ELSE: SKIP — project_scope excludes backend or runtime is None.

**Step 3 — Frontend Fragments (CONDITIONAL — by pattern F1-F10):**
IF `project_scope in [full-stack, frontend-only]` (Q4.5) AND `frontend.framework != "None"` (Q9):
  Add pattern-specific directories. For micro-frontends (F5-F7): create per-app subdirectories.
ELSE: SKIP — project_scope excludes frontend or framework is None.

> **Scope-keyed conditional materialisation.** `project_scope` is the primary guard; the stack answers (Q5/Q9) are the secondary consistency check. Discovery enforces the compatibility (e.g. `project_scope=backend-only` cannot coexist with `frontend.framework != "None"`), so in practice both checks agree — the double-guard exists to make the intent explicit at materialisation time and to fail loudly if a hand-edited `docs/setup.md` diverges.

**Step 4 — Integration Layer (ACL):**
Add `src/shared/` or equivalent anti-corruption layer directories based on topology.

**Step 5 — AI Capabilities (conditional):**
If `ai.training`, `ai.inference`, or `ai.agentic` enabled:
- `src/ai/models/`, `src/ai/pipelines/`, `src/ai/agents/`, `src/ai/tools/`, `src/ai/prompts/`

**Step 6 — Backlog Scaffolding (conditional on project_tracking.tool — SSOT):**

The scaffolded artifacts depend on the SSOT mode and, in every mode, include a **tool-adapter** rendered from the canonical per-tool templates in `.context/templates/setup/backlog-tool-adapters/`.

### Step 6.1 — Adapter Template Selection (MANDATORY — all modes)

Read `project_tracking.tool` from `docs/setup.md` (Q27) and pick exactly one template using case-insensitive regex matching:

| `project_tracking.tool` pattern | Template source | Integration |
| --- | --- | --- |
| `/github/i` (e.g. "GitHub Projects", "GitHub") | `.context/templates/setup/backlog-tool-adapters/github-project.md` | `cli` (`gh`) |
| `/jira/i` | `.context/templates/setup/backlog-tool-adapters/jira.md` | `cli` (`jira`) — **stub** |
| `/linear/i` | `.context/templates/setup/backlog-tool-adapters/linear.md` | `mcp` — **stub** |
| `"None"` (exact, case-sensitive) | `.context/templates/setup/backlog-tool-adapters/none.md` | `file` |
| Any other value (fallback) | `.context/templates/setup/backlog-tool-adapters/none.md` | `file` |

> **Fallback behaviour.** When the user answered Q27 with a tool name that has no dedicated adapter (e.g. "Azure Boards", "Shortcut", "Notion"), SETUP materialises the `none.md` template as a safe default and emits a WARN-level diagnostic: `Q27 tool "{tool}" has no dedicated adapter — materialising local file mode. To add native integration, author an adapter based on .context/templates/setup/backlog-tool-adapters/jira.md and register it in README.md § Selection.` The user keeps a working backlog (local mode) and the warning stays in the setup worklog until an adapter lands.

### Step 6.2 — Placeholder Resolution at Materialisation

The selected template contains `{{PLACEHOLDER}}` tokens. SETUP resolves the subset that are known at materialisation time and leaves the rest untouched for `--init-board` to capture on first run.

**Resolvable at materialisation (always substitute):**

| Placeholder | Source |
| --- | --- |
| `{{PROJECT_NAME}}` | `docs/setup.md` Q1 `project_name` |
| `{{REPO_SLUG}}` | `git remote get-url origin` parsed to `owner/repo`; if no remote, prompt the user |
| `{{ORG_OR_USER}}` | First segment of `{{REPO_SLUG}}` |
| `{{BOARD_COLUMNS}}` | `project_tracking.board_columns` from Q27.1 — rendered as a JSON array |
| `{{MILESTONE_STRATEGY}}` | `project_tracking.milestone_strategy` from Q27.3 |
| `{{NAMING_CONVENTION}}` | `project_tracking.naming_convention` from Q27.4 |
| `{{GATE_ENFORCEMENT_MODE}}` | `project_tracking.gate_enforcement_mode` from Q27.5 — `enforce` / `warn` / `off`; emitted as a comment inside the adapter so users can see the active mode without re-reading `setup.md`. When Q27.2 != `full-sdlc` the field is `null` and the adapter renders `# gate_enforcement_mode: n/a (preset has no gates)` |
| `{{APPETITE_SIZING_ENABLED}}` | `project_tracking.appetite_sizing_enabled` from Q27.6 — boolean; drives § Step 6.2.1 (appetite label/field materialisation) |
| `{{CLI_BINARY}}` | Inferred from the adapter frontmatter `cli_binary` field |

### Step 6.2.1 — Appetite Field Materialisation (conditional: Q27.6 == true)

When `project_tracking.appetite_sizing_enabled == true`, the BACKLOG agent must have an appetite label/field available on the tracker at `--init-board` time. SETUP materialisation does NOT create the label in the external tool (that happens at `--init-board` via `create_label`) — it only records the requirement so BACKLOG emits it.

Render the following fragment inside the materialised `docs/backlog/tool-adapter.md` under a new `## Appetite` section (append after the existing adapter body, before any `## Troubleshooting` section):

```markdown
## Appetite (Q27.6 = true)

This project uses appetite sizing as feature metadata. Three hand-curated values:

- `appetite:small` — ≤ 4h budget, one session
- `appetite:medium` — 2–4 day budget, supervised
- `appetite:big` — 5+ day budget, complex feature

Values are metadata (human-set, not framework-computed). Use for priority calls, batch
planning, and — if Shape Up-lite cultural overlay is later adopted — cycle composition.
Enabling does NOT force Shape Up.

BACKLOG --init-board MUST register the three labels via `create_label` (or the tool's
native equivalent) alongside the phase / status labels. The feature issue body template
adds an `Appetite:` line (blank by default — fill when the value is known).
```

When `appetite_sizing_enabled == false`, SKIP this section entirely — the rendered adapter contains no Appetite block.

### Step 6.2.2 — Gate Enforcement Mode Materialisation (conditional: Q27.2 == "full-sdlc")

When `project_tracking.feature_phases == "full-sdlc"`, render the following fragment inside `docs/backlog/tool-adapter.md` under a new `## Gate Enforcement Mode` section:

```markdown
## Gate Enforcement Mode (Q27.5)

**Default mode for gates:** `{{GATE_ENFORCEMENT_MODE}}`

Scope: `contract-freeze`, `preventive-sweep`, `smoke-e2e`, `integration-test`, `retrospective`.
Classic phase completions (blueprint `--approve`, qa `--verify`) are unaffected — they are always hard.

Modes:
- `enforce` — gate BLOCKS its downstream command until the gate issue is Done. Production default for greenfield.
- `warn` — gate does NOT block; the `--next-task` resolver emits a WARN line and returns the downstream command anyway. Used during Brownfield migration while features that predate the gate flow through the board. Flip to `enforce` once the first new feature produces the gate artefact in main.
- `off` — gate is disabled. Do NOT use as global default. Reserved for per-gate overrides declared in an ADR (e.g. a legacy codepath that will never have the gate artefact).

**Per-gate override.** Individual gate issues can override the default by populating the `## Mode` section inside the gate issue body with a single token `enforce`, `warn`, or `off`. The gate body template in `Factory-backlog-operations.instructions.md` § 5 defines this section. When the value is present and valid, the resolver (`Factory-backlog-next-task.instructions.md` § 1.3.5) uses the issue-level value; otherwise it falls back to this adapter-level default.

**Flip procedure (warn → enforce).** After the first feature under the framework merges to main with the gate artefact complete:
1. Update `docs/setup.md` → `project_tracking.gate_enforcement_mode: enforce`
2. Re-run `SETUP --upgrade` to regenerate the governance snapshot and this adapter section
3. Commit with `chore(governance): flip gate enforcement mode warn → enforce`
```

When `feature_phases != "full-sdlc"`, SKIP this section — the rendered adapter omits the `## Gate Enforcement Mode` block because simplified / single presets have no gates.

**Captured post-init (leave `{{…}}` verbatim):**

Placeholders such as `{{PROJECT_NUMBER}}`, `{{PROJECT_NODE_ID}}`, `{{STATUS_FIELD_ID}}`, option IDs, `{{JIRA_PROJECT_KEY}}`, `{{LINEAR_TEAM_ID}}`, etc. are resolved during the first `BACKLOG --init-board` run and persisted into `docs/backlog/project-config.json`. Any `{{…}}` token not listed in the "resolvable at materialisation" table above MUST remain unchanged in the materialised `tool-adapter.md`.

### Step 6.3 — Artifact Layout

**If `project_tracking.tool != "None"` (External mode):**
```
docs/backlog/
docs/backlog/project-config.json    # from .context/templates/setup/backlog/project-config.json
docs/backlog/tool-adapter.md         # RENDERED from selected adapter template (§ 6.1 + § 6.2)
```
> No `state.md` or `issue-bodies/` — the external tool is the single source of truth.

**If `project_tracking.tool == "None"` (Local mode):**
```
docs/backlog/
docs/backlog/issue-bodies/
docs/backlog/issue-bodies/.gitkeep   # keep directory tracked until BACKLOG creates body files
docs/backlog/state.md               # from .context/templates/setup/backlog/state.md
docs/backlog/tool-adapter.md         # RENDERED from none.md adapter (§ 6.1 + § 6.2)
```
> No `project-config.json` — no external API to connect to. The `tool-adapter.md` is still emitted so the BACKLOG agent has a uniform lookup surface across both modes.

### Step 6.4 — Invariants

1. **`docs/backlog/tool-adapter.md` is always rendered.** Both modes emit it. The adapter is the single lookup surface the BACKLOG agent uses for every operation, including file-mode operations in local mode.
2. **Never copy a stub without a WARN.** If the selected template has `stub: true` in its frontmatter (currently `jira.md` and `linear.md`), SETUP MUST emit a WARN diagnostic and leave the STUB banner intact in the rendered file so the user knows the adapter needs contributor validation before use.
3. **Never embed credentials.** The rendered `tool-adapter.md` MUST NOT contain API tokens, passwords, or secrets. Authentication is handled entirely by the user via CLI login or MCP server configuration. The adapter references only the CLI binary name and non-sensitive identifiers.
4. **Never hand-write adapter commands.** If the user requests a tool with no adapter template, always fall back to `none.md` with the warning above — do NOT inline-generate a new adapter on the fly. New adapters must live as committed template files so they survive across projects.

**Step 6.5 — Seed Registry Scaffolding (conditional: synthetic_data.enabled == true):**
Create Shared Seed Registry and fixture directories:
```
config/seed_registry.json            # Empty registry scaffold (see template below)
config/seed_fixtures/
config/seed_fixtures/_shared/        # Cross-feature shared entities (foundational data)
config/seed_fixtures/_shared/.gitkeep
```

Seed Registry scaffold template:
```json
{
  "$schema": "seed_registry_v1",
  "shared_fixtures_dir": "config/seed_fixtures/_shared/",
  "default_id_strategy": "{{synthetic_data.id_strategy}}",
  "shared_entities": {},
  "dependency_graph": {},
  "seed_order": [],
  "reset_order": []
}
```

**Step 7 — Validation:**
Verify no duplicate directories, all `.gitkeep` files present.

### 4.2.5 Integration Wiring
**CONFIGURATION ONLY** — no source code. 3 scenarios:
1. Backend + Frontend (same repo): Configure build tools, shared types directory
2. Backend only: Configure API documentation generation
3. Frontend only: Configure mock API/stubs directory

### 4.2.6 Other Artifacts

**CI/CD Pipeline (100% functional from scaffolding):**
Generate platform-specific pipeline from template:
- GitHub Actions: `.github/workflows/ci.yml`
- GitLab CI: `.gitlab-ci.yml`
- Jenkins: `Jenkinsfile`
- CircleCI: `.circleci/config.yml`
- AWS CodePipeline: `buildspec.yml`
Pipeline includes stages matching `ci_cd.tier` (lint, test, security, build, deploy per environment from `ci-cd.md`).

**Governance Workflow (100% functional from scaffolding):**
In addition to the CI pipeline, materialise the platform-specific governance check workflow that runs the ADR ↔ constitution sync gate (`scripts/check-adr-constitution-sync.sh`) on every PR / MR targeting `main`. Source templates live at `.context/templates/setup/workflows/governance-check.{platform}.{ext}`:

| `ci_cd.platform` | Source template | Materialised path |
|---|---|---|
| `github-actions` | `governance-check.github-actions.yml` | `.github/workflows/governance-check.yml` |
| `gitlab-ci` | `governance-check.gitlab-ci.yml` | `.gitlab/governance-check.yml` (or merge into `.gitlab-ci.yml`) |
| `bitbucket` | `governance-check.bitbucket.yml` | `bitbucket-pipelines.yml` (merge `pull-requests:` block) |
| `azure-devops` | `governance-check.azure-devops.yml` | `governance-check-pipeline.yml` |
| `aws-codebuild` | `governance-check.aws-codebuild.yml` | `buildspec-governance.yml` |
| `gcp-cloudbuild` | `governance-check.gcp-cloudbuild.yaml` | `cloudbuild-governance.yaml` |
| `jenkins` | `governance-check.jenkins.groovy` | `Jenkinsfile.governance` |

The workflow MUST be wired so that any PR transitioning an ADR file under `docs/project_log/adr/` from `status: proposed` to `status: accepted` without modifying `docs/constitution.md` in the same diff fails the gate. Bypass is via the `[adr-backfill]` commit-message marker (one-shot historical migration only). Additional governance gates are added as steps in the same workflow — do NOT split into multiple workflows per gate.

**IaC Foundation (conditional on `hosting.iac_tool != None`):**
- Create `infra/modules/`, `infra/features/`
- Initialize `config/infrastructure_registry.json`
- Materialize `.claude/rules/iac.md`
- Copy IaC scripts from templates

**Codebase Inventory Protocol (CIP):**
- Greenfield: Create empty `config/codebase_inventory.json` with `{ "version": "1.0.0", "bootstrap_mode": "greenfield", "artifacts": [] }`
- Brownfield: Execute BOOTSTRAP_CODEBASE_INVENTORY (targeted grep_search + file_search with framework-specific patterns to detect existing artifacts)

**Inventory Reconciliation Bootstrap:**
- Materialise `config/inventory_aliases.json` from `.context/templates/setup/config/inventory_aliases.json`. The template ships with empty `bc_alias` / `bc_feature` / `cross_bc_features` / `canonical_path_globs` — populate these from Discovery answers (bounded contexts list, feature ownership, canonical source-tree layout).
- When the file stays empty, `scripts/check-inventory-freshness.py` and `scripts/reconcile_inventory.py` degrade gracefully (orphan scan disabled, registration is a no-op). Materialise to enable the inventory-drift CI gate.

**Inventory Drift Workflow (conditional on `ci_cd.platform`):**
Mirror the Governance Workflow shape — pick the platform-specific source from `.context/templates/setup/workflows/inventory-drift.{platform}.{ext}` and materialise it as `.github/workflows/inventory-drift.yml` (or the platform equivalent). The workflow is a blocking gate that runs `scripts/check-inventory-freshness.py` on every PR / MR touching `src/`, `config/codebase_inventory.json`, `config/inventory_aliases.json`, the freshness script itself, or the workflow file. The current template tree ships only the `github-actions` variant — if the project's `ci_cd.platform` is anything else, materialisation skips this workflow until a platform-specific variant lands.

**System Resources Configuration:**
- Create `config/system_resources.json` following schema `.context/templates/setup/config/system_resources_schema.md`
- READ the schema to extract ALL required root-level and resource-level fields
- Initial content: empty `resources` array with all required root fields populated
- Resources are populated later by BLUEPRINT (integrations) and IMPLEMENT (endpoints)

**Quality Configuration (config/quality.json):**
- Materialise `config/quality.json` from `.context/templates/setup/config/quality.json` resolving the two placeholders against Q23.1 answers:
  - `{{COMPLEXITY_MCP_SERVER}}` ← `quality.complexity.mcp_server` (`semgrep` | custom server name | `null` when Skip)
  - `{{COMPLEXITY_MCP_TOOL_NAME}}` ← `quality.complexity.mcp_tool_name` (`scan_complexity` for Semgrep | custom tool name | `null` when Skip)
- When user picked **Skip**: write `null` (JSON literal, not the string `"null"`) for both placeholders AND set `complexity.enabled=false`. The skill `factory-complexity-check` short-circuits to `{ok: true, reason: "disabled"}` and never invokes any MCP. The file is still materialised so the project can enable later by editing.
- All other fields (`thresholds`, `bvl_gate`, `pr_blocker`, `source_extensions`) keep template defaults unless Discovery captured overrides. Defaults: `soft=10`, `hard=15` (McCabe), `bvl_gate=true`, `pr_blocker=false`.
- Resolve the three security-scanner placeholders against Q23.2 answers (EVOL-040 RDR-2):
  - `{{SECURITY_SCANNER}}` ← `quality.security_scan.scanner` (`gitleaks` | `trufflehog` | custom name | `null` when Skip)
  - `{{SECURITY_SCANNER_COMMAND}}` ← `quality.security_scan.secrets_command` (from the Q23.2 resolution table | custom template | `null` when Skip)
  - `{{SECURITY_SCANNER_INSTALL_HINT}}` ← `quality.security_scan.install_hint`
- Resolve the surface placeholders — bare tokens replaced by JSON values: `{{SURFACE_CEILING_FILES}}` ← `surface.ceiling_files` · `{{SURFACE_CEILING_LINES}}` ← `surface.ceiling_lines` (Q31, integers) · `{{RUNTIME_SURFACE}}` ← `surface.runtime_surface` (Q33, a JSON array of glob strings — the positive list every deploying workflow asks through `gate.py runtime-surface --changed`, EVOL-047). `surface.escapes` (the closed vocabulary) and `surface.declared_reads` keep template defaults. Two more bare tokens resolve from Q21 (`ci_cd.platform`) — the CI platform's own workflow files, one definition for the hard exclusion and for the parity scan:

  | Platform | `{{CI_WORKFLOW_PATHS}}` (hard exclusion — workflow definitions) | `{{DEPLOYING_WORKFLOWS}}` (the release / deploy files the parity gate reads) |
  |---|---|---|
  | GitHub Actions (and None) | `[".github/workflows/**"]` | `[".github/workflows/auto-tag.yml", ".github/workflows/deploy*.yml", ".github/workflows/release*.yml"]` |
  | GitLab CI | `[".gitlab-ci*.yml", ".gitlab/**"]` | `[".gitlab-ci-auto-tag.yml"]` |
  | Azure DevOps | `["azure-pipelines*.yml", "governance-check-pipeline.yml"]` | `["azure-pipelines-auto-tag.yml"]` |
  | Bitbucket Pipelines | `["bitbucket-pipelines.yml"]` | `["bitbucket-pipelines.yml"]` |
  | Jenkins | `["Jenkinsfile*"]` | `["Jenkinsfile.auto-tag"]` |
  | AWS CodePipeline / CodeBuild | `["buildspec*.yml"]` | `["buildspec-auto-tag.yml"]` |
  | GCP Cloud Build | `["cloudbuild*.yaml"]` | `["cloudbuild-auto-tag.yaml"]` |

  Add the project's own deploy workflows to `deploying_workflows` when DEVOPS creates them. The `planning` block (EVOL-048 — governed paths, the documentation exemption and its gate-input carve-out, the exempt branch classes, the adoption window) keeps template defaults; edit `governed_paths` when the stack keeps runtime code elsewhere. Its hooks (`check-plan-approval.sh`, `record-plan-approval.sh`) land with `settings.json`. **Invariant:** `python3 scripts/gate.py runtime-surface` is green on the materialised tree (the parity gate: at least one deploying workflow found; every path it or its scripts read is on the list, a hard exclusion or a declared read), else BLOCK. Read by `python3 scripts/gate.py surface` (pre-push, preflight Block 21, CI) and by BLUEPRINT's surface estimate.
- When user picked **Skip** on Q23.2: write `null` (JSON literal, not the string `"null"`) for all three placeholders AND set `security_scan.enabled=false`. The dispatcher `scripts/security-scan.sh --secrets` degrades to the 🔒 disabled banner; the regex floor (detect_change_type.py, pr-review Block 3) stays active. The file is still materialised so the project can enable later by editing.
- This file is consumed by `factory-complexity-check` (BVL post-test step), `factory-pr-review` (axis 6 — complexity; Step 0-bis — code_review; Block 3 floor is config-free), `factory-code-review` (code_review block) and `scripts/security-scan.sh` (security_scan block). `factory-sync.sh` deliberately does NOT touch `config/`; `SETUP --upgrade` owns delta propagation.

**Environment Variables (Secret Placeholder Convention):**
- Generate `.env.example` with `REPLACE_ME_<description>` format for all required secrets
- NEVER generate `.env` with real values
- Format: `DATABASE_URL=REPLACE_ME_database_connection_string`
- These placeholders are EXEMPT from Zero-TODO policy and detected by DEVOPS Guardrail 7

**Scripts Materialization:**
Copy ALL scripts from `.context/templates/setup/scripts/` → `scripts/` (recursively — `scripts/gates/*.py` is the one governance reader's package, `scripts/hooks/*` the git hooks):
- Auto-scan template directory (no hardcoded list)
- Stack conditionals from `governance_versions.json` filter scripts by stack
- `stack_configured` scripts resolve placeholders
- `chmod +x` for all `.sh` files
- **Invariant (EVOL-040):** after the copy, every `templates::scripts/**` manifest entry with `delivery` ∈ {`setup`, `both`} MUST exist under the target `scripts/` path. If any is missing → BLOCK with the entry key and the expected path. This mirrors the hooks Invariant below — a materialised workflow invoking a script SETUP did not deliver is a broken-first-CI defect class (CVP CRITICAL 9-10).

**Subproducts Materialization (`.context/templates/setup/subproducts/` → `subproducts/`) — EVOL-052 / EVOL-042:**
Deliverable-generation tooling: imported by no product or framework module, outside the project's governed trees and test roots, each with a `--selftest`. Members: `po-package` (conditional on Q29), `measure` (always).
- **`measure/` (EVOL-042, always):** copy the WHOLE `subproducts/measure/` tree; `universal` files byte-identical; resolve placeholders ONLY in `measure.config.json`: `{{MEASURE_RETENTION_DAYS}}` ← `measurement.retention_days` (Q30) · `{{MEASURE_REPORT_INTERVAL_DAYS}}` ← `measurement.report_interval_days` (Q30) — bare integers replacing the token (the token is unquoted JSON). **Invariant:** `measure.config.json` parses as JSON with zero `{{…}}`; `python3 subproducts/measure/measure.py --selftest` prints `0 failure(s)`, else BLOCK. **Written next steps (MANDATORY):** fill the `## Measurement — next steps` block of `MATERIALIZATION_REPORT.md` (baseline command, interval, where the before/after table goes).
- **`po-package/`:** SKIP entirely when `po_package.mode == "off"` (Q29 `internal`). Otherwise copy the WHOLE `subproducts/po-package/` tree — auto-scan, no hardcoded list. `universal` files are copied BYTE-IDENTICAL (never translate, never reword: the zip prose carries build-time `${var}` variables the builder fills; canonical headings must stay literal).
- Resolve placeholders ONLY in the `stack_configured` files — `po-package.config.json`, `RUNBOOK.md`, `RUNBOOK.es.md`:

  | Placeholder | Source (`docs/setup.md`) |
  |---|---|
  | `{{PROJECT_NAME}}` | Q1 `project_name` |
  | `{{BUSINESS_GOAL}}` | § 1 Context & Business Goal, one sentence, JSON-escaped |
  | `{{PROJECT_SCOPE}}` | `project_scope` (Q4.5) |
  | `{{PROJECT_LANGUAGE}}` | `language`, lowercased (`en` \| `es`) |
  | `{{FEATURE_ID_PATTERN}}` | derived from `project_tracking.naming_convention` (Q27.4): `FEAT-NNN` → `^FEAT-\\d{3,}$` (JSON-escaped backslash). Q27 == "None" → `^[A-Z][A-Z0-9]*-\\d{3,}$` |
  | `{{PO_PACKAGE_MODE}}` | `po_package.mode` (Q29): `full` \| `features-only` |
  | `{{DS_CODE_CARDS_DIR}}` | `po_package.ds_code_cards_dir` (Q29.1) |
  | `{{DS_REBUILD_COMMAND}}` | `po_package.ds_rebuild_command` (Q29.1) |
  | `{{DS_CARDS_SOURCE}}` | `po_package.ds_cards_source` (Q29.1): `vision` \| `code-manual` \| `code-rebuild` \| `defer` |
  | `{{DS_ACTIVE_SECTION}}` | DERIVED: no code cards folder → `6A` · command AND workflow materialised (below) → `6C` · any other folder (run by asking Claude, or a command with no workflow) → `6B` |
  | `{{DS_CI_WORKFLOW_STATUS}}` | DERIVED: `6C` → `installed at .github/workflows/design-system-rebuild.yml` · else `not installed — {reason}` (`no rebuild command configured` \| `ci_cd.platform is not GitHub Actions` \| `added by hand later, see section 8`) |

- In `po-package.config.json`, when `{{DS_CODE_CARDS_DIR}}` / `{{DS_REBUILD_COMMAND}}` do not apply: write `null` (JSON literal replacing the QUOTED token, not the string `"null"`) — same rule as `config/quality.json`. In the runbooks the same absent command renders as `none`.
- **Optional workflow:** materialise `.context/templates/setup/workflows/design-system-rebuild.github-actions.yml` → `.github/workflows/design-system-rebuild.yml` ONLY when `ci_cd.platform == github-actions` AND `po_package.ds_rebuild_command != null`. Advisory job; other platforms run the same builder command by hand (RUNBOOK § 6B).
- **Invariant:** after this step `subproducts/po-package/RUNBOOK.md` MUST exist with ZERO `{{…}}` left, and `po-package.config.json` MUST parse as JSON. Else BLOCK — a project materialised without its written operating instructions is a broken delivery.
- **Self-test:** run `python3 subproducts/po-package/validate_po_return.py --selftest`. Red ⇒ BLOCK (the journey gate `scripts/check-journey-grammar.sh` must already be delivered by Scripts Materialization).
- **Written next steps (MANDATORY):** fill in `MATERIALIZATION_REPORT.md` the block `## PO package — next steps` and repeat it in the closing briefing (ACP): authoring mode, the active design-system case (`6A`/`6B`/`6C`) and why, the runbook path, the first command (`python3 subproducts/po-package/build_po_package.py`), and the note that the `factory-po-intake` skill + `/codesign --sync` arrive with `factory-sync.sh` — the runbook works without them.

**Claude Code Materialization (`.context/templates/setup/claude/` → project root + `.claude/`):**

1. `.context/templates/setup/claude/CLAUDE.md` → `CLAUDE.md` (project root)
   - `smart-additive-merge` upgrade strategy: if `CLAUDE.md` already exists at the target, merge new structural additions (new sections, new bullet points) into it without overwriting user edits. On fresh `--generate`, target will not exist → write the template as-is.
   - This is the **materialized-project variant** of `CLAUDE.md`. The framework repo itself uses a different `CLAUDE.md` (meta-maintenance variant) that is NOT synced to downstream projects.

2. `.context/templates/setup/claude/settings.json` → `.claude/settings.json`
   - `merge-preserve` upgrade strategy: target file holds user-owned content (e.g. `permissions`, `model`, `env`). Merge the framework-owned `hooks` block (SessionStart, UserPromptSubmit, PreCompact, PreToolUse) into the existing file without touching other keys.
   - Fresh `--generate`: write the template as-is.
   - Idempotent: re-materialisation only adds missing hook entries; never removes user-added matchers or commands.

3. `.context/templates/setup/claude/hooks/*.sh` → `.claude/hooks/*.sh`
   - Copy ALL `.sh` files from the template directory — auto-scan, no hardcoded list.
   - `chmod +x` for all copied scripts.
   - Fresh `--generate`: write as-is.
   - `--upgrade`: overwrite each script with the template version. These scripts are framework-owned primitives — the target version is authoritative. No user customisation expected; project-specific branch protocol lives in constitution + ADRs, not in hook scripts. Current chain (PreToolUse): `check-branch-protection.sh`, `check-concurrency-lock.sh`, `check-governance-drift.sh`, `check-completion-gate.sh`, `check-ipp-compliance.sh`, `check-push-preflight.sh`. The first four match `Edit|Write`; `check-completion-gate.sh` and `check-ipp-compliance.sh` match `Write` only; `check-push-preflight.sh` matches `Bash` only (Factory PR Review push gate — invokes the factory-pr-review skill's `scripts/preflight.sh` when the Bash command is `git push`).
   - **Invariant:** every hook referenced from `.claude/settings.json` MUST exist at the target path after this step. Post-materialisation check: for each `bash .claude/hooks/X.sh` command in the merged settings.json, verify the file exists. If any is missing → BLOCK with diagnostic listing the missing scripts.
   - **Skill-dependency note (Factory PR Review):** `check-push-preflight.sh` is silent if `.claude/skills/factory-pr-review/` is absent — it passes the `git push` through unchanged. Skills are NOT materialised by `SETUP --generate`; they propagate via `factory-sync.sh`. A fresh project lands the hook + the settings.json wiring; the gate activates the first time `factory-sync.sh` (or `SETUP --upgrade` followed by `factory-sync.sh`) installs the skill.

Rationale: `.claude/settings.json` was previously untouched by `factory-sync.sh` ("project-owned"), leaving downstream projects with no governance-always-on hooks unless the user added them manually. Templating `settings.json` closes that gap; templating `CLAUDE.md` avoids shipping framework-specific guidance (meta-maintenance mode, EVOL-* workflow) to project users who should see SDLC-first guidance instead. Templating the hook scripts under `claude/hooks/` closes the follow-up gap where a fresh `SETUP --generate` would materialise a `settings.json` pointing at hook scripts that never existed in the target repo (Copilot PR #7 review round 2).

**.gitignore:** Generate from template, add framework-specific entries.

**E2E Config:** Only configuration files (playwright.config.ts, etc.), NO test files.

### 4.2.7 Budget Calculation and Cost Placeholder Resolution

**Input.** `docs/setup.md § costs:` — populated by the Cost Estimation Protocol (CEP) during Discovery Finalization. See `Factory-setup-discovery.instructions.md` § 4.1.3.2 for the producer logic.

**Invariant.** Materialization does NOT re-estimate costs. It consumes the `costs:` block from `setup.md` as a single source of truth. If `costs:` is missing or any field is `null`, materialization BLOCKS with diagnostic `Cost Estimation Protocol did not run or produced an incomplete breakdown. Re-run SETUP --init and complete Discovery Finalization before --generate.`

**Resolution pass.** Every downstream template that contains a `{{*_COST}}` or `{{BUDGET_*}}` placeholder gets rendered with the concrete value from `setup_md.costs`. The canonical placeholder → field map lives in `Factory-setup-discovery.instructions.md` § 4.1.3.2 Step 5. Materialization applies the same map here:

```yaml
FUNCTION resolve_cost_placeholders(template_content, setup_md):
  costs = setup_md.costs  # produced by CEP

  IF costs IS NULL OR costs.totals.total_monthly IS NULL:
    ❌ BLOCK: "CEP did not run. Re-run SETUP --init Discovery Finalization."
    STOP

  substitutions = {
    "{{BACKEND_COST}}":        costs.infrastructure.backend,
    "{{FRONTEND_COST}}":       costs.infrastructure.frontend,
    "{{INTEGRATION_COST}}":    costs.infrastructure.integration,
    "{{DATABASE_COST}}":       costs.infrastructure.databases,
    "{{HOSTING_COST}}":        costs.infrastructure.hosting,
    "{{IAC_COST}}":            costs.infrastructure.iac,
    "{{OBSERVABILITY_COST}}":  costs.infrastructure.observability,
    "{{CICD_COST}}":           costs.infrastructure.cicd,
    "{{AI_COMPONENTS_COST}}":  costs.infrastructure.ai_components,
    "{{MAINTENANCE_COST}}":    costs.infrastructure.maintenance,
    "{{INFRA_TOTAL}}":         costs.totals.infra_total,
    "{{PO_COST}}":             costs.agent_tokens.po,
    "{{ARCH_COST}}":           costs.agent_tokens.arch,
    "{{DEV_COST}}":            costs.agent_tokens.dev,
    "{{QA_COST}}":             costs.agent_tokens.qa,
    "{{REVIEW_COST}}":         costs.agent_tokens.review,
    "{{SEC_COST}}":            costs.agent_tokens.sec,
    "{{TOTAL_COST}}":          costs.totals.total_monthly,
    "{{ESTIMATED_MONTHLY_COST}}": costs.totals.total_monthly,   # legacy alias
    "{{BUDGET_PERCENTAGE}}":   costs.totals.budget_percentage,
    "{{BUDGET_STATUS}}":       costs.totals.status,
    "{{BUDGET_RISK}}":         costs.totals.risk,
    "{{BUDGET_RISK_MITIGATION}}": costs.totals.risk_mitigation,
    "{{BUDGET_ALIGNMENT}}":    "verified" IF costs.totals.status != "EXCEEDS_BUDGET" ELSE "override pending"
  }

  rendered = template_content
  FOR placeholder, value IN substitutions:
    rendered = rendered.replace(placeholder, str(value))

  # Dangling check — any {{*_COST}} or {{BUDGET_*}} that survives is a governance drift
  IF rendered matches /\{\{[A-Z_]*(COST|BUDGET[A-Z_]*)\}\}/:
    ❌ BLOCK: "Dangling cost placeholder in rendered template: {match}. Missing from CEP substitution map."
    STOP

  RETURN rendered
```

**Application scope.** The resolution pass runs during materialization of every template that contains cost placeholders. At the time of writing, those are:

- `.context/templates/setup/adr/adr_setup_template.md` — rendered into `docs/project_log/adr/ADR-0000-setup-decisions.md` (§ Cost Analysis block)
- `.context/templates/setup/setup/MATERIALIZATION_REPORT_TEMPLATE.md` — rendered into `MATERIALIZATION_REPORT.md` at the repo root (§ Cost Breakdown + § Agent Costs + § Budget Summary)

Any future template that adopts a `{{*_COST}}` or `{{BUDGET_*}}` placeholder is automatically covered by this pass — no additional wiring needed.

**Budget breach handling.** If `costs.totals.status == "EXCEEDS_BUDGET"`, materialization does NOT block — the user already accepted the breach during Discovery Finalization and the 5-alternative dialog happened there. Materialization simply renders the `status: EXCEEDS_BUDGET` value into templates so the generated `MATERIALIZATION_REPORT.md` displays a prominent warning block, and logs an ADR entry under `ADR-0000-setup-decisions.md § Budget Override`.

> **Rationale.** § 4.2.7 was a 12-line stub listing 9 cost categories without specifying where the values came from or how they reached the generated artifacts. The 20+ `{{*_COST}}` placeholders in `adr_setup_template.md` and `MATERIALIZATION_REPORT_TEMPLATE.md` were dangling — they would materialise as literal `{{…}}` strings in production artifacts. CEP (new producer in discovery) + this resolution pass (new consumer in materialization) close the loop. The substitution map is a single-responsibility template-variable surface; dollar values live per-project in `docs/setup.md`, never in a committed rule file.

### 4.2.8 .context Preservation
**NEVER clean up** `.context/` directory during materialization. It contains:
- Agent source files (used as reference)
- Templates (used for upgrades)
- Migration artifacts

### 4.2.9 Rules Manifest & Special Integrations
`docs/constitution.md` carries NO Governance Index (index form since constitution template 4.0.0: one `## [PLAW-NN]` entry per law — `> sentence` + `Body:` pointer + `Records:`). The rules manifest is produced by Checkpoint 3.1 (`SCAN_RULES_DIRECTORY(.claude/rules/)` → snapshot § Rules Manifest); per-rule applicability is each rule file's own `applicable_when:` frontmatter (ADP) — never metadata comments in the constitution.

**Body-home check (BLOCKING):** every `Body:` pointer in `docs/constitution.md` resolves to a materialised file that contains the same `## [PLAW-NN]` heading followed by the byte-identical `> sentence` line. Unresolved pointer or sentence mismatch → materialisation error, fix before Checkpoint 3.1.

**Special Integration — UX Constitution (scope-aware):**
If `project_scope in [full-stack, frontend-only]` AND `frontend.framework != "None"`, populate `.claude/rules/ux-constitution.md` with:
- Brand Identity from Visual DNA (Q13)
- Layout preferences (border radius, shadows, animations)
- Pixel-level mapping of Visual DNA to CSS variables

When `project_scope in [backend-only, integration]`, SKIP ux-constitution materialisation entirely — no `ux-constitution.md`, no Visual DNA processing, no design-system merge. Downstream CODESIGN `--vision` is blocked by `Factory-codesign-vision.instructions.md § Prerequisites` (scope guard).

**Special Integration — External Design System:**
If `frontend.external_design_system.exists == true`:
1. **Semantic Merge:** DS tokens → ux-constitution.md (DS takes precedence except WCAG/security violations → create RDR)
2. **Component Migration:** Compatible components → project folder structure + register in `docs/ux/component-registry.json` (schema + writer rules: `Factory-codesign-vision.instructions.md` § Component Registry; `origin: external_ds`, `status: DESIGNED`) + protect in `protected-paths.json`
3. **Tokens-Only:** Extract design tokens, create CSS custom properties file

**Branching Rule Placeholders:**
Populate `.claude/rules/branching.md` with PR validation settings from Q22.1 (`pr_validation_mode`, `pr_approval_count`, `pr_merge_method`).

### 4.2.9b Dynamic Validation Template Generation
Generate per-agent validation templates based on coverage analysis:
- For each agent (DEV, ARCH, REVIEW, QA, SEC): analyze which rules apply
- Create `.context/validation_templates/{AGENT}_VALIDATION_TEMPLATE.md`
- Include cache key (MD5 of constitution.md) for invalidation

### 4.2.10 Finalization

**Git Hooks Auto-Installation (MANDATORY):**
After all governance files are materialized, automatically install git hooks to enforce
branch protection and commit conventions at the git level:
```yaml
FUNCTION auto_install_hooks():
  IF FILE_EXISTS("scripts/install-hooks.sh"):
    result = Execute: bash scripts/install-hooks.sh
    LOG: "Git hooks auto-installed during SETUP --generate"
    IF result.skipped_hooks_count > 0:
      WARN: "Some existing git hooks were detected as custom and were NOT overwritten. Review .git/hooks/ to ensure your bespoke logic is compatible with Factory's governance hooks."
  ELSE:
    WARN: "scripts/install-hooks.sh not found — git hooks not installed. Branch protection relies on agent-level enforcement only."
```
This ensures that even operations outside the slash command are blocked from committing directly to `main`.

**Governance Versions Snapshot (5 steps):**
1. Read `.context/templates/setup/governance_versions.json` (framework reference)
2. For each file in snapshot, compute MD5 of the materialized version
3. Create `docs/project_log/governance_versions.json` — the project manifest. Shape (declared, EVOL-044): `framework_version` (the framework version materialised), `delivery_mode` ← `docs/setup.md` frontmatter `delivery.mode` (Q32 — `development` | `production`, EVOL-046; the one key `python3 scripts/gate.py profile` reads, fail-closed to `production` when absent — so a forgotten key silently makes every push owe the full profile, never less), `templates` (the framework manifest's `templates` map, key → `{version, target, content_type, stack_conditional}`, filtered to the entries that landed — the source of truth every governed file's frontmatter `version:` must equal; `gate.py manifest-parity` reads it) and `files` (target → `{template_source, checksum}`, what `validate-upgrade-integrity.sh` compares at upgrade).
4. Record framework version, materialization timestamp
5. This snapshot enables future `--upgrade` to detect drift vs customization

**State Update:**
- Set `docs/setup.md` → `materialization_complete: true`
- Set `MATERIALIZATION_REPORT.md` → `status: COMPLETED`

**Final Logging:**
`APPEND_TO_WORKLOG` with summary of all generated files.

**User Notification:**
Display grouped list of all generated files with brief description per category.

---

## Resumability (`--generate --resume` — IPP Pillar 3)

> **Implements:** Incremental Persistence Protocol (`.claude/skills/factory-incremental-persistence/SKILL.md`) — Pillar 3 (Resume-on-Entry).

```yaml
FUNCTION setup_resume_check():
  IF MATERIALIZATION_REPORT.md exists AND status == "IN_PROGRESS":
    checklist = READ(MATERIALIZATION_REPORT.md)
    last_incomplete = FIND_FIRST(checklist, "[ ]")
    completed = COUNT(checklist, "[✓]")
    total = COUNT(checklist, ALL_TASKS)
    
    VALIDATE docs/setup.md hash hasn't changed (drift prevention)
    LOG: "RESUME: MATERIALIZATION — {completed}/{total} tasks done, resuming from task {last_incomplete.id}"
    
    RESUME_FROM(last_incomplete)
    RETURN "RESUMED"
  RETURN "FRESH"
```

**Rules:**
1. Read checklist, find last incomplete task `[ ]`
2. Validate `docs/setup.md` has NOT changed since last run (drift prevention)
3. Continue from last incomplete task
4. Do NOT overwrite already-generated files without confirmation
5. Update checklist incrementally after each task
6. Finish with `status: COMPLETED` only if ALL tasks are `[✓]`

**Use case:** Overcoming token limits across multiple sessions. Each session picks up where the last left off.

## [LAW-14] SETUP scaffolding
> SETUP generation creates directories and configuration only — never source or test files.

NEVER generate source code or test files during `SETUP --generate`. Only directories, configuration, governance (constitution index, rules, hooks, scripts, subproducts) and the manifest. The first line of product code is born in IMPLEMENT, under a plan.
