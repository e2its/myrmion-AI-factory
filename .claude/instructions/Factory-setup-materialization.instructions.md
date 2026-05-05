---
description: "Factory SETUP materialization — governance scaffolding, rule generation, constitution creation, --generate --resume. Use when: SETUP --generate command execution."
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

> **Implements:** Incremental Persistence Protocol (`.claude/skills/Factory-incremental-persistence/SKILL.md`) — Pillar 2 (Section-Atomic Saves).

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

> **Purpose:** Generate the file-based governance snapshot consumed by ALL agents at every command start.
> This file enables post-summarization governance recovery (see `.claude/skills/Factory-governance-loading/SKILL.md` Step 0).
> Embeds the operational law (`## [LAW]` sections of constitution + universal DCs) so cultural guidance is mechanically present from turn 1 — agents do not depend on disciplinary on-demand loading for the rules that govern every decision. ADRs are NOT loaded; they are historical records of why constitutional changes were made — see `.claude/skills/Factory-adr-management/SKILL.md`.

```yaml
FUNCTION generate_governance_snapshot():
  # Called AFTER constitution.md is materialized + rules generated + defect-prevention.md present.
  snapshot_path = ".context/governance_snapshot.md"

  # Hash inputs — frontmatter freshness signals
  constitution_hash = MD5(docs/constitution.md)
  setup_hash        = MD5(docs/setup.md)
  dcs_hash          = MD5(.claude/rules/defect-prevention.md)

  # Operational data (concise tables / structured fields)
  stack_config    = EXTRACT_STACK_CONFIG(docs/constitution.md)
  rules_manifest  = SCAN_RULES_DIRECTORY(.claude/rules/)
  protected_paths = READ_IF_EXISTS(config/protected-paths.json)
  environments    = EXTRACT_ENVIRONMENTS(.claude/rules/ci-cd.md)
  setup_config    = EXTRACT_SETUP_CONFIG(docs/setup.md)

  # Operational law — body extracted verbatim from constitution [LAW] sections
  law_sections    = EXTRACT_LAW_SECTIONS(docs/constitution.md)
                    # Contract: every heading matching /^## \[LAW\] .+$/ to next /^## / boundary.
                    # Subsections (###, ####) inside a [LAW] block are preserved verbatim.
                    # Headings without the [LAW] marker (preamble, governance index, references)
                    # are NOT extracted — they stay in constitution.md for on-demand reading.

  universal_dcs   = EXTRACT_UNIVERSAL_DCS(.claude/rules/defect-prevention.md)
                    # Filter: entries whose frontmatter has applicable_when: always.
                    # Scope-conditional entries (applicable_when: scope:* or stack:*) stay in
                    # defect-prevention.md and are filtered at agent-read time by each consumer
                    # per applicable_to + applicable_when (catalog § Mandatory Process Integration).

  WRITE(snapshot_path):
    ---
    constitution_hash: "{constitution_hash}"
    setup_hash: "{setup_hash}"
    dcs_hash: "{dcs_hash}"
    generated_at: "{ISO_8601}"
    generated_by: "SETUP --generate"
    framework_version: "{from_governance_versions.json}"
    ---

    # Governance Snapshot (Auto-Generated — DO NOT EDIT MANUALLY)
    > Read by agents at start of every command. Embeds operational law mechanically so
    > cultural guidance is present from turn 1 without on-demand discipline.
    > Regenerated by: SETUP --generate, SETUP --upgrade, any edit to
    > docs/constitution.md / docs/setup.md / .claude/rules/defect-prevention.md.
    > Source of truth: docs/constitution.md (single source). ADRs are historical records,
    > not loaded — see Factory-adr-management/SKILL.md for the amendment ceremony.

    ## Stack Configuration
    project_scope: {stack_config.project_scope}      # full-stack | backend-only | frontend-only | integration
    backend:
      runtime: {stack_config.backend.runtime}
      framework: {stack_config.backend.framework}
      webhooks: {stack_config.backend.webhooks}
    frontend:
      framework: {stack_config.frontend.framework}
    architecture:
      pattern: {stack_config.architecture.pattern}
      topology: {stack_config.architecture.topology}
      comm_style: {stack_config.architecture.comm_style}
    database:
      type: {stack_config.database.type}
    ci_cd:
      platform: {stack_config.ci_cd.platform}
    iac:
      tool: {stack_config.iac.tool}
    cloud:
      provider: {stack_config.cloud.provider}
    project_mode: {project_mode}

    ## Rules Manifest
    | Rule File | Severity | Validation | Applies When |
    |-----------|----------|------------|--------------|
    {FOR EACH rule IN rules_manifest:
      | {rule.filename} | {rule.severity} | {rule.validation_method} | {rule.applies_when} |
    }

    ## Protected Paths
    ### Red Zones (BLOCKING — ADR required)
    {FOR EACH path IN protected_paths.red_zones: - {path}}
    ### Yellow Zones (WARNING)
    {FOR EACH path IN protected_paths.yellow_zones: - {path}}

    ## Environments
    {FOR EACH env IN environments: - {env.name}: {env.url_pattern}}

    ## Setup Configuration
    > Source: docs/setup.md — operational flags read by downstream agents.
    > Included in snapshot so they survive context summarization.
    project_mode: {setup_config.project_mode}
    project_scope: {setup_config.project_scope}   # mirrors Stack Configuration for scope-aware agents
    ai_budget:
      tier: {setup_config.ai_budget.tier}
    project_tracking:
      tool: {setup_config.project_tracking.tool}
      feature_phases: {setup_config.project_tracking.feature_phases}
      milestone_strategy: {setup_config.project_tracking.milestone_strategy}
      gate_enforcement_mode: {setup_config.project_tracking.gate_enforcement_mode}   # Q27.5 — enforce | warn | off (default per Q3/Q27.2 recommendation; null when preset != full-sdlc)
      appetite_sizing_enabled: {setup_config.project_tracking.appetite_sizing_enabled}  # Q27.6 — boolean; materialises appetite label/field when true
    synthetic_data:
      enabled: {setup_config.synthetic_data.enabled}
      id_strategy: {setup_config.synthetic_data.id_strategy}

    ## Verification Commands
    > Auto-derived from Stack Configuration via BVL derive_commands_from_stack(stack_config).
    > Used by IMPLEMENT --build (Build Verification Loop). Override manually if non-standard tooling.
    > See: Factory-build-verification/SKILL.md
    test_single: {derive_commands_from_stack(stack_config).test_single}
    test_suite: {derive_commands_from_stack(stack_config).test_suite}
    lint: {derive_commands_from_stack(stack_config).lint}
    typecheck: {derive_commands_from_stack(stack_config).typecheck}
    build: {derive_commands_from_stack(stack_config).build}

    ## Active Constitution (Operational [LAW] sections — verbatim)
    > Source: docs/constitution.md. Extracted by `EXTRACT_LAW_SECTIONS()`.
    > Regex contract: `^## \[LAW\] .+$` to next `^## ` boundary. Subsections preserved.
    > Sections without `[LAW]` marker stay in constitution.md for on-demand reading.
    {FOR EACH section IN law_sections:

    {section.heading}

    {section.body}
    }

    ## Defect Prevention Catalog (Universal entries — applicable_when: always)
    > Source: .claude/rules/defect-prevention.md. Extracted by `EXTRACT_UNIVERSAL_DCS()`.
    > Scope-conditional entries (applicable_when: scope:* or stack:*) stay in
    > defect-prevention.md and are filtered at agent-read time per `applicable_to`.
    {FOR EACH dc IN universal_dcs:

    ### {dc.id} — {dc.title}

    **Severity:** {dc.severity}
    **Applicable to:** {dc.applicable_to}

    {dc.body}
    }

  SAVE(snapshot_path)
  MARK_TASK("governance_snapshot", COMPLETED)
  LOG: "Governance snapshot generated — {len(law_sections)} [LAW] sections, {len(universal_dcs)} universal DCs, {len(rules_manifest)} rules. Hashes: constitution={constitution_hash[:8]}, setup={setup_hash[:8]}, dcs={dcs_hash[:8]}"
```

#### Extraction Function Contracts (deterministic, language-agnostic pseudocode)

```yaml
FUNCTION EXTRACT_LAW_SECTIONS(constitution_path):
  # Returns: ordered list of {heading, body} blocks where heading matches /^## \[LAW\] .+$/.
  # Body = all lines after the heading up to (but excluding) the next /^## / boundary or EOF.
  # Subsection markers (###, ####) inside a block are kept literally.
  # Empty list if no markers found (treat as configuration error in CI).
  lines = READ(constitution_path).splitlines()
  blocks = []
  current = NULL
  FOR line IN lines:
    IF line MATCHES /^## \[LAW\] (.+)$/:
      IF current: blocks.append(current)
      current = {heading: line, body: []}
    ELIF line MATCHES /^## /:
      IF current: blocks.append(current); current = NULL
    ELIF current:
      current.body.append(line)
  IF current: blocks.append(current)
  RETURN blocks  # body field is joined with "\n" at write time

FUNCTION EXTRACT_UNIVERSAL_DCS(dc_catalog_path):
  # Returns: ordered list of {id, title, severity, applicable_to, body} entries
  # whose frontmatter contains applicable_when: always.
  # DC entry format (defect-prevention.md): each entry is a `### DC-N — {title}` block
  # with a YAML-frontmatter-style metadata block immediately after, then prose body.
  # Scope-conditional entries (applicable_when: scope:* or stack:*) are EXCLUDED.
  entries = PARSE_DC_CATALOG(dc_catalog_path)
  RETURN [e FOR e IN entries IF e.applicable_when == "always"]
```

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
1. Read template from `.context/templates/setup/constitution_template.md`
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

Standard rules materialized to `.claude/rules/`: `architecture.md`, `security_policy.md`, `testing.md`, `branching.md`, `ci-cd.md`, `database.md`, `observability.md`, `performance.md`, `ux-constitution.md`, `contract-first-policy.md`, `immutability_policy.md`, `ai_budget_tracker.md`, `ai_budget_governance.md`, `stateless.md`, `privacy.md`, `frontend_architecture_compatibility.md`, `html-css.md`. Config artefacts materialized to `config/`: `protected-paths.json`, `allowlist.json`.

**Phase B — Technology-Specific Best Practices:**
For each detected technology (backend.runtime, frontend.framework):
1. Check if `.context/templates/setup/rules/{technology}.md` exists
2. **FOUND:** Use template, resolve placeholders, write to `.claude/rules/{technology}.md`
3. **NOT_FOUND:** Auto-generate using 12-section structure with MANDATORY frontmatter:
   - **Step 3a — Generate frontmatter** using this exact structure:
     ```yaml
     ---
     description: "{Technology} coding standards — naming conventions, patterns, error handling, testing. Applied automatically when editing {Technology} files."
     applyTo: "{glob_pattern}"
     version: 1.0.0
     date: {CURRENT_DATE}
     changelog:
       - "1.0.0: Auto-generated during SETUP materialization"
     ---
     ```
   - **Step 3b — Derive `applyTo` glob** from technology name. Common mappings:
     | Technology | `applyTo` glob |
     |------------|----------------|
     | Python | `**/*.py` |
     | Node.js / JavaScript | `**/*.{js,ts,mjs,cjs}` |
     | React / Next.js | `**/*.{jsx,tsx}` |
     | Java | `**/*.java` |
     | C# / .NET | `**/*.{cs,csx}` |
     | Go | `**/*.go` |
     | Rust | `**/*.rs` |
     | Ruby | `**/*.rb` |
     | Kotlin | `**/*.{kt,kts}` |
     | Swift | `**/*.swift` |
     | PHP | `**/*.php` |
     | Vue | `**/*.vue` |
     | Angular | `**/*.{ts,html,component.ts}` |
     | Svelte | `**/*.svelte` |
     For unlisted technologies: derive extensions from official language documentation. Use `**/*.{ext}` pattern. If multiple extensions exist, combine with comma: `**/*.{ext1,ext2}`.
   - **Step 3c — Generate body** with 12-section structure:
     Naming conventions, file organization, error handling, logging, testing, security, performance, dependency management, documentation, versioning, deployment, monitoring
4. Apply technology-specific deny lists and mandatory patterns

**Phase B.1 — Defect Prevention Catalog (Stack-Aware Materialization):**

The `defect-prevention.md` template uses a `{{DC_ENTRIES}}` placeholder that MUST be populated with starter defect classes based on the project's stack. These are defects that **pass all static gates** but **break at runtime** — the gap between static verification and deployed behavior.

**Schema note:** each DC entry includes an `applicable_to` field — an enum list of the SDLC agents that MUST consult this entry. Valid values: `CODESIGN`, `BLUEPRINT`, `IMPLEMENT`, `REVIEW`, `DEVOPS`, `QA`, `AUDIT`. An entry can be consumed by multiple agents. Most entries end up with `[IMPLEMENT, REVIEW]` (classic code patterns); UX/accessibility patterns add `CODESIGN`; architectural patterns add `BLUEPRINT`; infra patterns add `DEVOPS`; test-surface patterns add `QA`; and any enduring pattern should add `AUDIT` so external audits pick it up. The starter DCs below use sensible defaults — projects may extend them via the Discovery Protocol.

```yaml
FUNCTION materialize_defect_prevention(setup_md, constitution_md):
  dc_entries = []
  dc_number = 1

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
  # Each entry describes a PATTERN (stack-neutral) with stack-specific
  # manifestations listed inside the prevention text. The `applicable_when`
  # scope condition still gates which concrete projects consume the entry at
  # runtime — a pure library project with no CI won't trigger DC-PIPE, etc.

  # DC: Pipeline short-circuit silently skips downstream gates
  # Universal — applies to any CI/build/BVL script that chains commands via pipes
  # Example manifestations: bash `find … | grep -q` under `set -o pipefail` (SIGPIPE
  # kills producer, gate silently passes); PowerShell pipelines with
  # $ErrorActionPreference = "Stop"; Python subprocess pipes with check=True;
  # Make rules with `$(shell … | …)`; Jenkins `sh` steps; GitLab script blocks.
  ADD DC: {
    name: "Pipeline short-circuit silently skips downstream gates",
    applicable_when: "Authoring CI / build / verification scripts that chain producers and consumers via shell pipes, Make recipes, or platform script blocks",
    applicable_to: ["IMPLEMENT", "REVIEW", "DEVOPS", "AUDIT"],
    prevention: "Never gate on a raw `producer | consumer -q` idiom. Under shell pipefail (and equivalents) the consumer can close the pipe early, the producer dies with SIGPIPE and the gate silently passes while its precondition is unmet. Use explicit boolean tests on captured output (e.g. `[ -n \"$(producer -print -quit)\" ]`), a named helper, or the ecosystem's idiomatic `set_check` primitive. Dry-run every gate with a precondition that should fail and verify the gate actually fails.",
    review_severity: "BLOCKER"
  }

  # DC: Identity-argument no-op transforms
  # Universal — applies to string transforms, template rendering, DOM assertions
  # Example manifestations: JS `padEnd("")`/`padStart("")`/`replace(empty, …)` returning input;
  # Python `str.format("")`; Java `String.format("")`; CSS class concat with empty string;
  # i18n fallback `""`; test-side: asserting only the label wrapper while children render empty.
  ADD DC: {
    name: "Identity-argument no-op in string / DOM transforms",
    applicable_when: "Calling padding, trimming, replacement, formatting, template, or class-concat functions with a parameter that may legitimately be empty, null, or zero",
    applicable_to: ["IMPLEMENT", "REVIEW", "QA"],
    prevention: "Many ecosystems return the input unchanged when the transform parameter is an identity value (empty string, zero-length array, null delimiter). The call looks correct and type-checks cleanly. Guard the parameter OR assert a post-condition on the output (expected length, substring presence, rendered element count) — never trust the call itself. For UI component tests, every rendered element MUST be asserted in the DOM, not just the wrapper label: a zero-input render passes label-only assertions while delivering a blank surface to the user.",
    review_severity: "BLOCKER"
  }

  # DC: Framework-layer validation errors invisible to application logs
  # Universal — applies to any layered system with validation ahead of handler
  # Example manifestations: FastAPI/Pydantic 422 responses invisible to app logs;
  # Express middleware Zod/Joi rejections; Spring @Valid pre-controller errors;
  # ASP.NET Core model binding failures; GraphQL schema validation; gRPC reflection;
  # API Gateway request validation (AWS/Kong/Nginx/Apigee); WAF rules; ModSecurity.
  ADD DC: {
    name: "Framework-layer validation errors invisible to application logs",
    applicable_when: "Any system with schema, DTO, or request validation performed by a middleware, gateway, WAF, or framework layer ahead of the application handler",
    applicable_to: ["BLUEPRINT", "IMPLEMENT", "DEVOPS", "QA", "AUDIT"],
    prevention: "A 4xx spike with NO corresponding ERROR line in application logs is almost always a contract / DTO / schema mismatch between client and server — not a bug in the use case code. Diagnosis playbook: (1) diff the request payload against the declared schema; (2) only enter use case code after that has been ruled out. Prevention: configure the validation layer (middleware, gateway, framework error handler) to emit a structured log entry with the validation detail before returning the 4xx, so application observability sees the event. Document which error classes are filtered at the gateway vs reaching the handler.",
    review_severity: "WARNING"
  }

  # DC: Mutation APIs with replace semantics reset omitted fields
  # Universal — applies to shared-state mutation against cloud, directory, ERP, REST, K8s, etc.
  # Example manifestations: AWS `update-function-configuration` resetting env vars not passed;
  # Azure ARM PUT replacing whole resource; GCP `resource.update` default replace;
  # Kubernetes `kubectl apply` vs `patch` semantics; Terraform replace triggers;
  # LDAP / Active Directory `Set-ADUser` clearing array attributes; SAP BAPIs;
  # REST PUT on aggregate roots; GraphQL mutations without input defaults.
  ADD DC: {
    name: "Mutation APIs with replace semantics reset omitted fields",
    applicable_when: "Any code path that mutates shared external state via an update / PUT / replace endpoint — cloud control planes, directory services, ERP / CRM objects, Kubernetes resources, REST PUT endpoints, GraphQL mutations, IaC providers",
    applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS", "AUDIT"],
    prevention: "Never call a mutation endpoint with a partial payload while assuming omitted fields are preserved. Many endpoints are replace-whole-state, not patch-delta — the omitted fields get reset to defaults or removed. Mandatory pattern: read-current-state → merge delta → submit merged payload. Document each integration's semantics (replace vs patch) in the adapter / integration doc. Where the ecosystem offers both (e.g. K8s `apply` vs `patch`), codify which one is allowed and why.",
    review_severity: "BLOCKER"
  }

  # DC: Composite network symptoms require layered root-cause triage
  # Universal — applies to any project with a network boundary
  # Example manifestations: browser "blocked by CORS policy" has 4+ causes
  # (missing Access-Control-Allow-Origin; authorizer short-circuit returning before
  # CORS middleware; redirect stripping CORS headers; method not in allowMethods);
  # TLS handshake failures (cert, SNI, cipher, protocol version); 502/504 (upstream
  # down, timeout, DNS, routing); connection refused (port, firewall, bind, service
  # down); auth fails (token expired, audience mismatch, clock skew, bad signature);
  # Kerberos (7+ distinct causes); mTLS handshake.
  ADD DC: {
    name: "Composite network symptoms require layered root-cause triage",
    applicable_when: "Debugging a single network-layer symptom reported by the client, browser, or upstream service",
    applicable_to: ["BLUEPRINT", "IMPLEMENT", "DEVOPS", "QA"],
    prevention: "A single symptom class (CORS blocked, 502 Bad Gateway, connection refused, auth fail, TLS handshake) typically has 3+ distinct root causes spread across application / middleware / infrastructure / client configuration. Random edits in the application layer cannot fix middleware or infrastructure causes. For each symptom class, maintain a decision tree that captures raw evidence first (e.g. `curl -i -X OPTIONS …` for CORS; `openssl s_client -connect …` for TLS; platform access logs for 502; packet capture when needed), then disambiguates the layer before code changes. Document the tree per symptom in `.claude/rules/` or runbook — add entries as new symptom classes surface.",
    review_severity: "WARNING"
  }

  # ============================================================================
  # INTEGRATION / BACKEND-ONLY DCS — shipped when
  # project_scope IN [full-stack, backend-only, integration]
  # ============================================================================
  # These 7 DCs target the defect cluster specific to features that process
  # requests without a first-party UI (APIs, workers, webhooks, consumers, cron).
  # Each entry uses the v2.2.0 DPC `feature_scope` filter to restrict consultation
  # to [backend-only, integration] features. Full-stack features are EXCLUDED — a
  # full-stack feature that needs reliability-flavoured concerns (idempotency,
  # retry, circuit breaker, DLQ, graceful shutdown) should be sliced into a
  # dedicated backend-only or integration feature per the compatibility matrix
  # (the full-stack project still accepts it). This keeps the DC constraint set
  # aligned with the test_plan § 2.2 Reliability Testing and dev_plan § Reliability
  # Tests sections, which are themselves applicable_when scope in
  # [backend-only, integration] — avoiding the mismatch where a full-stack feature
  # would be gated on DCs but have no reliability test infrastructure.
  # Guard the whole BLOCK by project_scope (not feature_scope) because SETUP
  # materialisation runs BEFORE any feature exists — the catalog ships once, per
  # project. The per-feature filter happens later at consult_defect_catalog time.
  # Don't materialise any of them into frontend-only projects.
  IF setup_md.project_scope IN ["full-stack", "backend-only", "integration"]:

    # DC: Missing idempotency keys on mutating operations
    # Applies to: any inbound mutation (HTTP, queue consumer, webhook inbound)
    ADD DC: {
      name: "Missing idempotency keys on mutating operations",
      applicable_when: "Designing or implementing an inbound endpoint / handler that mutates shared state (payment processing, order creation, resource provisioning, webhook inbound, queue consumer)",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "QA"],
      feature_scope: ["backend-only", "integration"],
      prevention: "Every mutating operation that can be retried by the caller MUST accept an idempotency key (HTTP `Idempotency-Key` header, message attribute, or body field). Key format: UUID v4 minimum, or natural composite key (e.g. customer_id + external_ref). Store a short-TTL dedupe record (key → response_hash, response_payload) in the same transactional boundary as the side-effect. Replay returns cached response, never re-executes. BLOCKER when mutation has no dedupe strategy and caller is a retry-enabled client (browser retry, mobile retry, queue at-least-once delivery, webhook retry).",
      review_severity: "BLOCKER"
    }

    # DC: Retries without exponential backoff + jitter
    ADD DC: {
      name: "Retries without exponential backoff + jitter",
      applicable_when: "Calling a downstream service, queue broker, or external API that can transiently fail",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS", "QA"],
      feature_scope: ["backend-only", "integration"],
      prevention: "Every remote call MUST declare: max attempts (default 5 for idempotent, 0-1 for non-idempotent without idempotency key), base delay (e.g. 2s), exponential factor (e.g. 2x), jitter (random 0-50% of computed delay). No tight-loop retries, no fixed-interval retries — both cause thundering-herd outages when the downstream recovers. Use the platform's native retry primitive (AWS SDK retry strategy, Polly for .NET, tenacity for Python, p-retry for Node) rather than hand-rolling. Emit `retry_count` metric per call.",
      review_severity: "BLOCKER"
    }

    # DC: Missing circuit breaker on unreliable downstreams
    ADD DC: {
      name: "Missing circuit breaker on unreliable downstreams",
      applicable_when: "Calling a downstream that has a history of outages, rate limits, or SLA breaches (any third-party API, cross-region DB, federated auth provider)",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS"],
      feature_scope: ["backend-only", "integration"],
      prevention: "Wrap calls to unreliable downstreams in a circuit breaker with: failure threshold (e.g. 5 failures in 30s window), open duration (e.g. 60s), half-open probe strategy (single request, re-close on success, re-open on failure). Without the breaker, the caller's retry logic turns every downstream outage into a thundering-herd cascade and a cost spike (per-request pricing APIs). Metrics: `circuit_state` gauge (0=closed, 1=half-open, 2=open), `circuit_trips` counter. Use platform primitives (Polly / resilience4j / Hystrix / opossum).",
      review_severity: "BLOCKER"
    }

    # DC: Missing structured logging + trace propagation on integration hops
    ADD DC: {
      name: "Missing structured logging + trace propagation on integration hops",
      applicable_when: "Implementing any handler that receives OR emits a request spanning service boundaries",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS", "QA", "AUDIT"],
      feature_scope: ["backend-only", "integration"],
      prevention: "Every handler MUST: (1) emit structured logs (JSON) with at minimum `trace_id`, `correlation_id`, `feature_id`, `idempotency_key`, `error_code` (when error). (2) Propagate trace context on outbound calls using W3C Trace Context (`traceparent` / `tracestate` headers) OR the ecosystem equivalent (B3 for OpenTracing, X-Amzn-Trace-Id for AWS, X-Cloud-Trace-Context for GCP). (3) Accept inbound trace context and continue the trace rather than starting a new one. Without propagation, a failed integration request spanning 3 services appears as 3 unrelated log entries — root cause analysis costs hours instead of minutes.",
      review_severity: "WARNING"
    }

    # DC: API contract versioning without backward-compat strategy
    ADD DC: {
      name: "API contract versioning without backward-compat strategy",
      applicable_when: "Publishing a contract (OpenAPI / AsyncAPI / gRPC / GraphQL SDL) that external consumers depend on — any scope=integration feature, or scope=backend-only feature that has at least one external consumer in consumes_contract",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS"],
      feature_scope: ["backend-only", "integration"],
      prevention: "Contract versions MUST follow a declared strategy: (a) URI versioning (/v1/, /v2/) for REST, (b) package-level versioning (package myapi.v1) for gRPC, (c) schema-evolution rules (additive fields only; never remove/rename without deprecation) for AsyncAPI/Avro/Protobuf, (d) `@deprecated` + sunset dates for GraphQL. Breaking change WITHOUT a new major version + deprecation window = silent consumer breakage. Document the strategy in design.md § 2 Constraints + ADR. REVIEW blocks on: field removals without deprecation; type narrowing of request fields; type widening of response fields without opt-in.",
      review_severity: "BLOCKER"
    }

    # DC: Missing dead-letter queue handling for async consumers
    ADD DC: {
      name: "Missing dead-letter queue handling for async consumers",
      applicable_when: "Implementing a queue consumer, event handler, or webhook inbound endpoint that can fail permanently (max retries exhausted, poison message)",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "DEVOPS", "QA"],
      feature_scope: ["backend-only", "integration"],
      prevention: "Every async consumer MUST have a dead-letter destination declared at infra level (SQS DLQ, RabbitMQ dead-letter exchange, Kafka DLQ topic, EventBridge rule with failure pattern). Max-retries threshold MUST send the failed message WITH FULL CONTEXT (original payload + retry history + last error + timestamp) to the DLQ — not just drop it silently. Replay tooling MUST exist (runbook + script) so operators can re-enqueue after fixing root cause. Without DLQ, a single poison message blocks the queue indefinitely OR gets silently dropped after retry exhaustion, and the data loss is invisible until downstream reports missing records weeks later.",
      review_severity: "BLOCKER"
    }

    # DC: Missing graceful shutdown (SIGTERM / drain) handling
    ADD DC: {
      name: "Missing graceful shutdown (SIGTERM / drain) handling",
      applicable_when: "Implementing a long-running service, worker, queue consumer, or cron job — any process that can be terminated by the orchestrator mid-request",
      applicable_to: ["IMPLEMENT", "REVIEW", "DEVOPS"],
      feature_scope: ["backend-only", "integration"],
      prevention: "On SIGTERM, the service MUST: (1) stop accepting new requests / messages (close listener or set drain flag). (2) Mark health endpoint as unhealthy (orchestrator stops routing to this instance). (3) Complete or checkpoint in-flight work within the drain window (configurable, default 30s; orchestrator-coordinated: Kubernetes terminationGracePeriodSeconds, AWS ALB deregistration delay). (4) Exit 0 when drained, or 143 on drain timeout (signal-exit convention). Without graceful shutdown: in-flight requests are killed mid-transaction, leaving partial database writes, unacked messages, and 502 responses to callers. Exit behaviour belongs to the runtime entry point (not use-case code) — verify at service boundary.",
      review_severity: "BLOCKER"
    }

  # ============================================================================
  # STACK-CONDITIONAL DCS — only materialize when the project matches the scope
  # ============================================================================

  # DC: Async handler in serverless entry point
  # Q7 backend.topology == "B9" (Serverless)
  IF setup_md.backend.topology == "B9":
    ADD DC: {
      name: "Async handler in serverless entry point",
      applicable_when: "Writing a serverless function handler",
      applicable_to: ["IMPLEMENT", "REVIEW", "DEVOPS", "AUDIT"],
      prevention: "Verify handler signature matches the serverless runtime contract. Some runtimes do not auto-await async handlers — use sync wrapper + async runtime.",
      review_severity: "BLOCKER"
    }

  # DC: Missing frontend context providers
  # Q9 frontend.framework != "None"
  IF setup_md.frontend.framework != "None":
    ADD DC: {
      name: "Missing frontend context providers",
      applicable_when: "Using a context-based hook in a component",
      applicable_to: ["IMPLEMENT", "REVIEW"],
      prevention: "Before using a context-based hook, verify its Provider exists in the component tree (root layout or parent). Missing Provider = silent null or runtime crash.",
      review_severity: "BLOCKER"
    }

  # DC: Post-action navigation gaps
  # Q9 frontend.framework != "None" AND Q11 frontend.pattern uses client-side routing (F1, F2, F4, F8, F9)
  IF setup_md.frontend.framework != "None" AND setup_md.frontend.pattern IN ["F1", "F2", "F4", "F8", "F9"]:
    ADD DC: {
      name: "Post-action navigation gaps",
      applicable_when: "Writing form onSubmit/onSuccess handlers",
      applicable_to: ["CODESIGN", "IMPLEMENT", "REVIEW", "QA"],
      prevention: "Every form submission success MUST include navigation (router.push/replace/redirect). Without it, user sees stale form.",
      review_severity: "WARNING"
    }

  # DC: Session/state rehydration on mount
  # Q11 frontend.pattern uses SSR/hydration (F2 = SSR+hydration, F4 = ISR)
  IF setup_md.frontend.pattern IN ["F2", "F4"]:
    ADD DC: {
      name: "Session/state rehydration on mount",
      applicable_when: "Writing auth hooks or session state initialization",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW"],
      prevention: "Auth/session hooks MUST check for existing sessions on mount. Initial loading state MUST be true (assume loading until proven otherwise).",
      review_severity: "WARNING"
    }

  # DC: Responsive design / mobile gaps
  # Q9 frontend.framework != "None"
  IF setup_md.frontend.framework != "None":
    ADD DC: {
      name: "Responsive design / mobile gaps",
      applicable_when: "Writing dashboard layouts, data tables, or navigation",
      applicable_to: ["CODESIGN", "IMPLEMENT", "REVIEW", "QA"],
      prevention: "Layouts MUST include a mobile toggle. Tables MUST have horizontal scroll wrapper. No fixed widths without responsive breakpoints.",
      review_severity: "WARNING"
    }

  # DC: Frontend env var injection mismatch
  # Q9 frontend.framework != "None" AND Q7 backend.topology == "B9" (serverless IaC manages env vars)
  IF setup_md.frontend.framework != "None" AND setup_md.backend.topology == "B9":
    ADD DC: {
      name: "Frontend env var injection mismatch",
      applicable_when: "Reading environment variables in frontend code",
      applicable_to: ["IMPLEMENT", "REVIEW", "DEVOPS"],
      prevention: "When reading a frontend env var in code, verify it is declared AND injected by the IaC/deployment configuration. Missing injection = undefined at runtime.",
      review_severity: "BLOCKER"
    }

  # DC: Hooks ordering violation
  # Q9 frontend.framework IN ["React", "Vue.js", "Solid"] — frameworks with hook/composition model
  # Note: Angular uses decorators (no hook ordering issue), Svelte uses stores (no hook ordering issue)
  IF setup_md.frontend.framework IN ["React", "Vue.js", "Solid"]:
    ADD DC: {
      name: "Hooks ordering violation",
      applicable_when: "Writing components with hooks/composables",
      applicable_to: ["IMPLEMENT", "REVIEW"],
      prevention: "ALL hook/composable calls MUST be placed BEFORE any conditional return. Hooks after conditional returns cause runtime errors (different call order between renders).",
      review_severity: "BLOCKER"
    }

  # DC: Backend-frontend contract mismatch
  # Applies when project has BOTH backend AND frontend AND uses contract-first policy
  # Contract-first policy is always materialized as .claude/rules/contract-first-policy.md
  # when both backend and frontend exist (Phase A standard rules)
  IF setup_md.frontend.framework != "None" AND setup_md.backend.runtime != "None":
    ADD DC: {
      name: "Backend-frontend contract mismatch",
      applicable_when: "Writing API client calls (frontend) or route handlers (backend)",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "QA", "AUDIT"],
      prevention: "Every frontend API call MUST match the backend route: same path, same method, same field names. Cross-reference against the contract file.",
      review_severity: "BLOCKER"
    }

  # DC: External identity ID != internal DB primary key
  # Q18 auth.strategy == "OAuth2/OIDC (external provider)" — external provider manages identity
  # Also applies when auth.strategy == "JWT (stateless)" AND an external IdP is configured (Q18 follow-up)
  IF setup_md.auth.strategy == "OAuth2/OIDC (external provider)":
    ADD DC: {
      name: "External identity ID != internal DB primary key",
      applicable_when: "Writing use cases/services that receive identity claims from auth tokens",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "AUDIT"],
      prevention: "When receiving an identity claim (sub, oid, uid) from an external auth provider, ALWAYS use a dedicated lookup method (e.g., get_by_external_id). NEVER pass the external ID to a get_by_id() that queries the internal DB primary key.",
      review_severity: "BLOCKER"
    }

  # DC: Cross-module direct data access
  # Q7 backend.topology NOT IN ["B1", "B12"] — any architecture with module boundaries
  IF setup_md.backend.topology NOT IN ["B1", "B12", "None"]:
    ADD DC: {
      name: "Cross-module direct data access",
      applicable_when: "Writing data access code (SQL, ORM queries, repository methods)",
      applicable_to: ["BLUEPRINT", "IMPLEMENT", "REVIEW", "AUDIT"],
      prevention: "A module MUST NOT access another module's tables/collections directly. Use ports/interfaces + adapters, API calls, or domain events. Enforced by contract-first policy.",
      review_severity: "BLOCKER"
    }

  # Materialize: render DC entries into the template table format
  # Table columns MUST match the catalog schema (v2.0.0):
  #   DC | Name | Applicable When | Applicable To | Severity | Check
  FOR EACH dc IN dc_entries:
    applicable_to_rendered = "[" + join(dc.applicable_to, ", ") + "]"
    RENDER as: "| DC-{dc_number} | {dc.name} | {dc.applicable_when} | {applicable_to_rendered} | {dc.review_severity} | {dc.prevention} |"
    dc_number += 1
  REPLACE {{DC_ENTRIES}} with rendered rows
  WRITE to .claude/rules/defect-prevention.md
```

**Phase C — Global Validation:**
After all rules generated, validate:
- All materialized files in `.claude/rules/` end with `.md` (no `.instructions.md` suffix — convention unified)
- All materialized files contain YAML frontmatter with `description:` field
- All **technology-specific** rules (Phase A language rules + Phase B) contain `applyTo:` with a valid glob pattern
- Cross-cutting rules (architecture, security_policy, branching, defect-prevention, etc.) are NOT required to have `applyTo`
- No cross-rule contradictions
- All referenced tools/frameworks match `docs/setup.md` selections
- Technology-specific rules don't conflict with architecture rules

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

**Step 6 — Backlog Scaffolding (conditional on project_tracking.tool — SSOT v1.0.0):**

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

**Codebase Inventory Protocol (CIP v1.0.0):**
- Greenfield: Create empty `config/codebase_inventory.json` with `{ "version": "1.0.0", "bootstrap_mode": "greenfield", "artifacts": [] }`
- Brownfield: Execute BOOTSTRAP_CODEBASE_INVENTORY (targeted grep_search + file_search with framework-specific patterns to detect existing artifacts)

**System Resources Configuration:**
- Create `config/system_resources.json` following schema `.context/templates/setup/config/system_resources_schema.md`
- READ the schema to extract ALL required root-level and resource-level fields
- Initial content: empty `resources` array with all required root fields populated
- Resources are populated later by BLUEPRINT (integrations) and IMPLEMENT (endpoints)

**Environment Variables (Secret Placeholder Convention v11.0.0):**
- Generate `.env.example` with `REPLACE_ME_<description>` format for all required secrets
- NEVER generate `.env` with real values
- Format: `DATABASE_URL=REPLACE_ME_database_connection_string`
- These placeholders are EXEMPT from Zero-TODO policy and detected by DEVOPS Guardrail 7

**Scripts Materialization:**
Copy ALL scripts from `.context/templates/setup/scripts/` → `scripts/`:
- Auto-scan template directory (no hardcoded list)
- Stack conditionals from `governance_versions.json` filter scripts by stack
- `stack_configured` scripts resolve placeholders
- `chmod +x` for all `.sh` files

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
   - `--upgrade`: overwrite each script with the template version. These scripts are framework-owned primitives — the target version is authoritative. No user customisation expected; project-specific branch protocol lives in constitution + ADRs, not in hook scripts. Current chain (PreToolUse): `check-branch-protection.sh`, `check-concurrency-lock.sh`, `check-governance-drift.sh`, `check-completion-gate.sh`, `check-ipp-compliance.sh`, `check-push-preflight.sh`. The first four match `Edit|Write`; `check-completion-gate.sh` and `check-ipp-compliance.sh` match `Write` only; `check-push-preflight.sh` matches `Bash` only (Factory PR Review push gate — invokes the Factory-pr-review skill's `scripts/preflight.sh` when the Bash command is `git push`).
   - **Invariant:** every hook referenced from `.claude/settings.json` MUST exist at the target path after this step. Post-materialisation check: for each `bash .claude/hooks/X.sh` command in the merged settings.json, verify the file exists. If any is missing → BLOCK with diagnostic listing the missing scripts.
   - **Skill-dependency note (Factory PR Review):** `check-push-preflight.sh` is silent if `.claude/skills/Factory-pr-review/` is absent — it passes the `git push` through unchanged. Skills are NOT materialised by `SETUP --generate`; they propagate via `factory-sync.sh`. A fresh project lands the hook + the settings.json wiring; the gate activates the first time `factory-sync.sh` (or `SETUP --upgrade` followed by `factory-sync.sh`) installs the skill.

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

> **Rationale.** Before EVOL-014, § 4.2.7 was a 12-line stub listing 9 cost categories without specifying where the values came from or how they reached the generated artifacts. The 20+ `{{*_COST}}` placeholders in `adr_setup_template.md` and `MATERIALIZATION_REPORT_TEMPLATE.md` were dangling — they would materialise as literal `{{…}}` strings in production artifacts. CEP (new producer in discovery) + this resolution pass (new consumer in materialization) close the loop. The substitution map is a single-responsibility template-variable surface; dollar values live per-project in `docs/setup.md`, never in a committed rule file.

### 4.2.8 .context Preservation
**NEVER clean up** `.context/` directory during materialization. It contains:
- Agent source files (used as reference)
- Templates (used for upgrades)
- Migration artifacts

### 4.2.9 Governance Index Generation
Scan all materialized rules and generate the Governance Index section in `docs/constitution.md`:

**Scan 6 categories:**
1. Architecture rules
2. Security rules
3. Testing rules
4. DevOps rules
5. Technology-specific rules
6. UX rules

**For each rule file, extract metadata:**
```yaml
type: narrative | structured_config
validation_method: semantic | script
applies_when: [stack conditions]
severity: CRITICAL | HIGH | MEDIUM
agents: [DEV, ARCH, REVIEW, QA, SEC]
validation_sections: [code sections to check]
validation_script: [script path if script-based]
```

**Special Integration — UX Constitution (scope-aware):**
If `project_scope in [full-stack, frontend-only]` AND `frontend.framework != "None"`, populate `.claude/rules/ux-constitution.md` with:
- Brand Identity from Visual DNA (Q13)
- Layout preferences (border radius, shadows, animations)
- Pixel-level mapping of Visual DNA to CSS variables

When `project_scope in [backend-only, integration]`, SKIP ux-constitution materialisation entirely — no `ux-constitution.md`, no Visual DNA processing, no design-system merge. Downstream CODESIGN `--vision` is blocked by `Factory-codesign-vision.instructions.md § Prerequisites` (scope guard).

**Special Integration — External Design System:**
If `frontend.external_design_system.exists == true`:
1. **Semantic Merge:** DS tokens → ux-constitution.md (DS takes precedence except WCAG/security violations → create RDR)
2. **Component Migration:** Compatible components → project folder structure + register in `docs/ux/component-registry.json` + protect in `protected-paths.json`
3. **Tokens-Only:** Extract design tokens, create CSS custom properties file

**Branching Rule Placeholders:**
Populate `.claude/rules/branching.md` with PR validation settings from Q22.1 (`pr_validation_mode`, `pr_approval_count`, `pr_merge_method`).

**Constitution Update:**
Replace PLACEHOLDER governance index section in `docs/constitution.md` with generated markdown containing all rule metadata.

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
3. Create `docs/project_log/governance_versions.json` with project-specific checksums
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

> **Implements:** Incremental Persistence Protocol (`.claude/skills/Factory-incremental-persistence/SKILL.md`) — Pillar 3 (Resume-on-Entry).

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
