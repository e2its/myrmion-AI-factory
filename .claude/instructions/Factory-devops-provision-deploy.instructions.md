---
description: "Factory DEVOPS provision and deploy — environment provisioning, deployment, rollback, teardown, pre-deploy status gate. Use when: DEVOPS --provision, --deploy, --rollback, --teardown execution."
---

# DEVOPS Agent — Provision, Deploy, Operations & Infrastructure

> Detailed instructions for infrastructure provisioning (`--provision`), deployment (`--deploy`), lifecycle operations (`--suspend`, `--resume`, `--rollback`, `--teardown`, `--status`), IaC generation, Dual-Mode resolution, and cross-agent integration.

## Dual-Mode Resolution Protocol (v8.3.0)

Many DEVOPS commands accept `[FEATURE_ID]` as OPTIONAL. This determines scope:

```yaml
FEATURE-SCOPED (FEATURE_ID required):
  --configure {ID}, --refine {ID}
  
DUAL-MODE (FEATURE_ID optional):
  --provision [ID] --env {E}, --deploy [ID] --env {E}
  --suspend [ID] --env {E}, --resume [ID] --env {E}
  --rollback [ID] --env {E}, --teardown [ID] --env {E}
  --status [ID]

FUNCTION resolve_command_scope(command, FEATURE_ID, ENV):
  IF FEATURE_ID provided:
    scope = "feature"
    affected_resources = infrastructure_registry.json
      .filter(r => r.feature_id == FEATURE_ID AND r.environment == ENV)
    base_path = "infra/features/{FEATURE_ID}/"
  ELSE:
    scope = "environment"
    affected_resources = infrastructure_registry.json
      .filter(r => r.environment == ENV)
    base_path = "infra/modules/" + "infra/features/*/"
  
  RETURN {scope, affected_resources, base_path}
```

---

## IaC Descriptor-Driven Generation (v9.0.0)

### Directory Model
```yaml
infra/
  modules/           # System-scope resources (shared across features)
    networking/
    database/
    cache/
    ...
  features/          # Feature-exclusive resources
    {FEATURE_ID}/
      {entry_point}  # main.tf, template.yaml, cdk stack, etc.
      variables.*
      outputs.*
```

### Generation Algorithm
```yaml
FOR EACH resource IN design.md Section 5 (Infrastructure Needs):
  
  Step 1: Registry Cross-Reference
    existing = infrastructure_registry.json.find(r => r.name == resource.name)
    IF existing AND existing.scope == "system":
      REUSE: Reference existing module (no duplication)
      CONTINUE
    IF existing AND existing.scope == "feature" AND existing.feature_id != FEATURE_ID:
      IF resource.consumers.count >= 2:
        PROMOTE to system scope (Infrastructure Registry Promotion Protocol)
  
  Step 2: Determine Scope
    IF resource.scope == "system" OR resource.consumers.count >= 2:
      target = "infra/modules/{resource.type}/"
    ELSE:
      target = "infra/features/{FEATURE_ID}/"
  
  Step 3: Generate IaC Files
    USE iac_descriptor to determine:
      - File format (HCL for Terraform, YAML for SAM/Pulumi, TypeScript for CDK)
      - Provider configuration pattern
      - State management configuration
      - Environment parameterization pattern
    
    GENERATE:
      {entry_point}: Resource definitions
      variables/parameters: Configurable values (sizing, naming, etc.)
      outputs: Connection strings, endpoints, ARNs
  
  Step 4: Validate
    EXECUTE: {iac_descriptor.commands.validate}
    IF errors: FIX and regenerate
  
  Step 5: Registry Update
    UPDATE infrastructure_registry.json:
      ADD/UPDATE resource entry with status, scope, feature_id, environment
```

### Serverless Function Resources (B9 Architecture)
```yaml
IF resource.type == "function" (from design.md):
  READ OpenAPI contract for x-serverless-* extensions:
    x-serverless-handler: handler path
    x-serverless-runtime: runtime (nodejs20.x, python3.12, etc.)
    x-serverless-memory: MB
    x-serverless-timeout: seconds
    x-serverless-trigger: {type: api-gateway|sqs|sns|s3|schedule, source: ...}
  
  GENERATE per iac_tool:
    SAM: AWS::Serverless::Function in template.yaml
    CDK: new lambda.Function() in stack
    serverless-framework: functions block in serverless.yml
  
  INCLUDE:
    - IAM policy linking (least privilege from contract operations)
    - Environment variables (from secrets_config references)
    - Trigger configuration
    - Dead letter queue (if async trigger)
```

### Static Site / Frontend Resources
```yaml
IF resource.type == "static_site" (from design.md):
  READ resource fields: framework, build_command, output_dir, base_path, ssr, engine

  # cloud_provider comes from constitution; engine comes from design.md resource declaration.
  # DEVOPS generates IaC using the same iac_descriptor pattern as other resource types.
  # No hardcoded cloud-provider or framework mappings — the engine field tells DEVOPS
  # what hosting model to provision.

  IF NOT ssr (SPA / static):
    GENERATE per iac_descriptor + engine:
      - Static asset hosting (object storage, CDN, or platform-managed)
      - SPA routing (fallback to index.html for client-side routing)
      - Cache policy: immutable assets (js/css/images) long TTL, index.html short TTL
      - Origin access control (private bucket + CDN access only, if applicable)

  IF ssr:
    GENERATE per iac_descriptor + engine:
      - Compute resource for SSR (container, function, or platform-managed)
      - Static asset layer (CDN or object storage for pre-built assets)
      - Routing: SSR handler for dynamic routes, static passthrough for assets

  INCLUDE (ALL variants):
    - Build pipeline: {build_command} → {output_dir}/
    - Environment variables (API URL, public keys — NEVER secrets in frontend)
    - base_path configuration (if != "/")
    - HTTPS/TLS certificate (per cloud_provider conventions)
    - Custom domain configuration (if applicable)
```

### Infrastructure Registry Promotion Protocol
```yaml
WHEN resource.consumers.count >= 2 (used by 2+ features):
  1. Move IaC from infra/features/{original_ID}/ → infra/modules/{resource_type}/
  2. Update ALL feature IaC files to reference module instead of local definition
  3. Update infrastructure_registry.json:
     scope: "feature" → "system"
     feature_id: null (system-scoped)
     consumers: [feature_1, feature_2, ...]
  4. Validate all references still resolve
  5. LOG promotion in worklog
```

### Data Protection for Data-Bearing Resources
```yaml
RULE: Resources with data_bearing: true in infrastructure_registry.json
REQUIRE confirmed backup before ANY destructive operation:
  --teardown: BLOCK until backup confirmed
  --provision (re-create): BLOCK until backup confirmed
  Destructive migration: BLOCK until backup confirmed

BACKUP VERIFICATION:
  1. Check backup exists and is recent (< 24h for prod, < 7d for non-prod)
  2. Verify backup is restorable (dry-run restore if possible)
  3. Require explicit user confirmation: "I confirm backup of {resource} is verified"
```

---

## `DEVOPS --provision [ID] --env {ENV}`

**Purpose**: Materialize infrastructure using IaC.
**Modes**: Feature-scoped (with ID) or Environment-scoped (without ID).

### Prerequisites
```yaml
Feature-scoped: devops_plan.md APPROVED + secrets_config CONFIGURED
Env-scoped: infrastructure_registry.json with resources for {ENV}
BOTH: {ENV} must exist in ci-cd.instructions.md environments[]
BLOCKER: Production env requires MERGE to main + QA APPROVED (via --verify auto-approval or legacy --approve)
```

### Feature-Scoped Provisioning
```yaml
Phase 0: Resolve scope
  {scope, affected_resources, base_path} = resolve_command_scope(ID, ENV)

Phase 0b: Placeholder Pre-Flight
  EXECUTE Guardrail 7: SCAN_ENV_FILES_FOR_PLACEHOLDERS
  IF violations: ❌ BLOCK with detailed report

Phase 1: Generate IaC (if not exists)
  EXECUTE IaC Descriptor-Driven Generation for each resource
  OUTPUT: Files in infra/features/{FEATURE_ID}/

Phase 2: Dry-Run
  EXECUTE: {iac_descriptor.commands.plan} (terraform plan, pulumi preview, cdk diff, etc.)
  PRESENT changes to user for confirmation
  IF destructive changes on data-bearing resources: ❌ BLOCK until backup confirmed

Phase 3: Apply
  EXECUTE: {iac_descriptor.commands.apply}
  Monitor output for errors
  IF error: Provide troubleshooting guidance, DO NOT auto-retry without user consent

Phase 4: Healthcheck
  FOR EACH provisioned resource:
    VERIFY reachable/healthy (endpoint check, connection test, function invoke)
    TIMEOUT: 5 minutes per resource
    IF unhealthy: ⚠️ WARN with diagnostic info

Phase 5: State Update
  UPDATE infrastructure_registry.json:
    resource.environments[ENV].status: "ACTIVE"
    resource.environments[ENV].provisioned_at: {timestamp}
    resource.environments[ENV].endpoints: {actual endpoints}
  
  UPDATE devops_plan.md:
    environments[ENV].status: "ACTIVE"
```

### Environment-Scoped Provisioning
```yaml
Phase 0: Load Infrastructure Registry
  READ infrastructure_registry.json
  FILTER resources WHERE environment == ENV OR scope == "system"

Phase 1: Dependency Graph (Topological Sort)
  Build dependency graph from resources:
    Tier 0: Networking (VPC, subnets, security groups)
    Tier 1: Data stores (databases, caches, queues)
    Tier 2: Compute (services, functions, containers)
    Tier 3: Edge (API gateways, CDN, DNS, static_site frontends)
  
  PROVISION in tier order (0 → 1 → 2 → 3)
  Within each tier: parallel if no inter-dependencies

Phase 2: Sequential Tier Provisioning
  FOR EACH tier IN [0, 1, 2, 3]:
    FOR EACH resource IN tier:
      Generate IaC (if needed)
      Dry-run → User confirmation → Apply → Healthcheck
    
    IF any resource in tier fails:
      ❌ STOP provisioning of higher tiers
      OFFER: Retry failed resource, Skip and continue, Rollback tier

Phase 3: Post-Provision Validation
  VERIFY all tiers healthy
  VERIFY cross-resource connectivity (e.g., service can reach database)
  GENERATE summary report

Phase 4: Summary
  LIST all resources by tier with status
  REPORT total provisioning time and estimated cost
```

---

## `DEVOPS --deploy [ID] --env {ENV}`

**Purpose**: Deploy application code to provisioned infrastructure.
**Modes**: Feature-scoped (deploy specific service) or Env-scoped (deploy full app).

### Prerequisites
```yaml
BOTH: Environment ACTIVE (not SUSPENDED), IMPLEMENT --build completed
Pre-prod environments: No extra QA approval required
Production environment: MERGE to main completed + QA APPROVED (via --verify auto-approval, includes DAST since v8.0.0)
```

### Pre-Deploy Status Gate (BLOCKING)
```yaml
# Formal status field checks — prevents deploying against incomplete builds.
# These are the same prerequisites documented in CLAUDE.md.

FUNCTION verify_deploy_prerequisites(FEATURE_ID, ENV):
  # 1. Environment must be ACTIVE
  env_status = READ config/infrastructure_registry.json → environments[ENV].status
  IF env_status != "ACTIVE":
    ❌ BLOCK: "Environment {ENV} is {env_status}. Use --resume if SUSPENDED."
    STOP

  # 2. dev_plan.md must be IMPLEMENTED_AND_VERIFIED (feature-scoped only)
  IF FEATURE_ID IS NOT NULL:
    dev_plan_status = READ docs/spec/{FEATURE_ID}/dev_plan.md → frontmatter.status
    IF dev_plan_status != "IMPLEMENTED_AND_VERIFIED":
      ❌ BLOCK: "dev_plan.md status is '{dev_plan_status}', expected 'IMPLEMENTED_AND_VERIFIED'. Run IMPLEMENT --build {FEATURE_ID} first."
      STOP

  # 3. devops_plan.md must be APPROVED (feature-scoped only)
  IF FEATURE_ID IS NOT NULL:
    devops_status = READ docs/spec/{FEATURE_ID}/devops_plan.md → frontmatter.status
    IF devops_status != "APPROVED":
      ❌ BLOCK: "devops_plan.md status is '{devops_status}', expected 'APPROVED'. Run DEVOPS --configure {FEATURE_ID} first."
      STOP

  # 4. Production requires MERGE + QA APPROVED
  IF ENV == production_env:  # from ci-cd.instructions.md environments[]
    # QA gate: feature-scoped lookup when FEATURE_ID present, env-scoped when null
    IF FEATURE_ID IS NOT NULL:
      qa_report = FIND latest docs/spec/{FEATURE_ID}/qa/qa_report_final_*.md
      IF qa_report NOT EXISTS OR qa_report.status != "APPROVED":
        ❌ BLOCK: "Production requires QA APPROVED. Run QA --verify {FEATURE_ID} first."
        STOP
    ELSE:
      # Env-scoped deploy (no feature): verify ALL pending features have QA APPROVED
      pending = FIND features in config/infrastructure_registry.json where env_status == "DEPLOYED" in pre-prod
      FOR EACH feat IN pending:
        qa_report = FIND latest docs/spec/{feat}/qa/qa_report_final_*.md
        IF qa_report NOT EXISTS OR qa_report.status != "APPROVED":
          ❌ BLOCK: "Feature {feat} lacks QA APPROVED. Run QA --verify {feat} first."
          STOP

    # Branch/merge validation (CI/tag-safe — avoids detached HEAD issues)
    # git branch --show-current returns empty in detached HEAD (CI/tag deploys)
    # Use commit ancestry check instead for robustness
    main_branch = DETECT main|master from git remote
    current_sha = git rev-parse HEAD
    is_on_main = git merge-base --is-ancestor {current_sha} {main_branch} AND git merge-base --is-ancestor {main_branch} {current_sha}
    is_tagged = git describe --exact-match --tags {current_sha} 2>/dev/null matches release pattern from ci-cd.instructions.md
    IF NOT is_on_main AND NOT is_tagged:
      ❌ BLOCK: "Production deployment requires MERGE to main or a release tag. Create PR first."
      STOP

  ✅ All deploy prerequisites verified — proceed
```

### Deployment Phases
```yaml
Phase 0: Pre-Deploy Status Gate (BLOCKING)
  verify_deploy_prerequisites(FEATURE_ID, ENV)
  # Returns only if all status checks pass

Phase 1: Scope Resolution
  {scope, affected_resources} = resolve_command_scope(ID, ENV)
  DETERMINE deployment targets (which services/functions to deploy)

Phase 2: Pre-Flight
  VERIFY environment ACTIVE (if SUSPENDED: suggest --resume first)
  EXECUTE Guardrail 7: Placeholder scan on deployment configs
  VERIFY build artifacts exist (from IMPLEMENT --build)
  VERIFY contract files haven't changed since last build

Phase 3: Build Artifacts
  Per architecture topology:
    Monolith (B1): Build single deployable
    Microservices (B2-B4): Build per-service containers/packages
    Serverless (B9): Package per-function
    Modular Monolith (B8): Build single deployable with module verification
  
  Per resource type:
    static_site (SPA): Run {build_command}, collect {output_dir}/
    static_site (SSR): Build container image or package function
  
  TAG artifacts with: feature_id, git_sha, timestamp, environment

Phase 4: Deploy with Strategy
  READ deployment_strategy from devops_plan.md:
  
  blue-green:
    1. Deploy to inactive slot
    2. Run smoke tests against inactive
    3. IF pass: Switch traffic to new slot
    4. IF fail: No switch, inactive remains old
    5. Keep old slot for instant rollback
  
  canary:
    1. Deploy to canary (small % traffic)
    2. Monitor metrics (errors, latency) for N minutes
    3. IF healthy: Gradually increase traffic (10% → 50% → 100%)
    4. IF degraded at any step: Rollback canary immediately
  
  rolling:
    1. Deploy to instances one-by-one (or batch)
    2. Health check each instance after deploy
    3. IF instance unhealthy: Stop rolling, rollback that instance
    4. Continue until all instances updated

Phase 5: Post-Deploy Verification
  RUN smoke tests (basic endpoint checks)
  VERIFY metrics within normal range
  VERIFY no error spike in logs
  
  # Synthetic Data Seeding (non-production only — see Seed Pipeline Protocol)
  # Gate: Only if synthetic_data.enabled == true (Q28)
  # Read from governance snapshot (survives summarization) — see INVARIANT 5
  synthetic_enabled = READ .context/governance_snapshot.md → Setup Configuration → synthetic_data.enabled
  IF ENV != production AND synthetic_enabled:
    RUN seed_pipeline_protocol(FEATURE_ID, ENV)
  
  IF verification fails:
    OFFER: Auto-rollback, Manual investigation, Retry deploy
  
  IF verification passes:
    GENERATE docs/spec/{FEATURE_ID}/devops/deployment_report_{timestamp}.md
    NOTIFY: "Deployment successful to {ENV}"

### Deployment Report Template (`deployment_report_{{timestamp}}.md`)

```yaml
---
status: SUCCESS | FAILED | ROLLED_BACK
feature_id: "{{FEATURE_ID}}"
environment: "{{ENV}}"
deployment_strategy: blue-green | canary | rolling
git_sha: "{{COMMIT_SHA}}"
branch: "{{BRANCH_NAME}}"
deployed_at: "{{ISO_8601}}"
deployed_by: DEVOPS
duration_seconds: N
---

## Deployment Summary
- **Feature:** {{FEATURE_ID}}
- **Environment:** {{ENV}}
- **Strategy:** {{blue-green|canary|rolling}}
- **Git SHA:** {{COMMIT_SHA}}
- **Duration:** {{N}} seconds

## Deployment Configuration
| Setting | Value |
|---------|-------|
| Strategy | {{strategy}} |
| Target instances | {{N}} |
| Health check timeout | {{N}}s |
| Rollback strategy | {{auto|manual}} |

## Build Artifacts
| Artifact | Type | Tag | Size |
|----------|------|-----|------|
| {{service_name}} | container/package/function | {{tag}} | {{size}} |

## Deployment Execution Log
| Phase | Status | Duration | Details |
|-------|--------|----------|---------|
| Pre-flight checks | PASS/FAIL | {{N}}s | {{details}} |
| Artifact build | PASS/FAIL | {{N}}s | {{details}} |
| Deploy to target | PASS/FAIL | {{N}}s | {{details}} |
| Health check | PASS/FAIL | {{N}}s | {{details}} |
| Traffic switch | PASS/FAIL | {{N}}s | {{details}} |

## Smoke Test Results
| Test | Endpoint | Expected | Actual | Result |
|------|----------|----------|--------|--------|
| Health check | /health | 200 | {{code}} | PASS/FAIL |
| API readiness | /api/ready | 200 | {{code}} | PASS/FAIL |

## Metrics Verification
| Metric | Baseline | Post-Deploy | Status |
|--------|----------|-------------|--------|
| Error rate | {{N}}% | {{N}}% | OK/DEGRADED |
| P95 latency | {{N}}ms | {{N}}ms | OK/DEGRADED |
| Memory usage | {{N}}MB | {{N}}MB | OK/ELEVATED |

## Rollback Information
- **Rollback available:** YES/NO
- **Previous version:** {{git_sha|tag}}
- **Rollback method:** {{blue-green switch|redeploy previous|restore snapshot}}
- **Estimated rollback time:** {{N}} seconds

## Post-Deploy Notes
{{Any observations, warnings, or follow-up items}}
```
```

---

## Seed Pipeline Protocol (Non-Production Post-Deploy)

> **Purpose:** Ensure non-production environments have referentially coherent synthetic data
> after every deployment, using the Shared Seed Registry for cross-domain integrity.
> **Artifact:** `config/seed_registry.json` (maintained by IMPLEMENT C.5.5)
> **Guard:** NEVER executes on production environments.

```yaml
FUNCTION seed_pipeline_protocol(FEATURE_ID, ENV):
  # GATE 1: Production guard (BLOCKING — absolute)
  IF ENV == production OR ENV matches production-like pattern:
    LOG: "⛔ Seed pipeline SKIPPED — production environment"
    RETURN SKIP
  
  # GATE 2: Registry existence
  registry_path = "config/seed_registry.json"
  IF NOT FILE_EXISTS(registry_path):
    LOG: "⚠️ No seed registry found — skipping synthetic data"
    RETURN SKIP
  
  registry = READ(registry_path)
  
  # STEP 1: Detect seed state (idempotency at pipeline level)
  existing_count = CHECK_ENTITY_COUNTS(registry.shared_entities)
  
  IF existing_count > 0 AND NOT ENV_VAR("FORCE_RESEED"):
    LOG: "Data exists ({existing_count} entities). Skipping seed. Set FORCE_RESEED=true to override."
    # Still run integrity validation even if not re-seeding
    GOTO STEP 4
  
  # STEP 2: Reset if FORCE_RESEED (teardown in reverse FK order)
  IF ENV_VAR("FORCE_RESEED"):
    LOG: "FORCE_RESEED=true — teardown in reverse dependency order"
    FOR EACH entity IN registry.reset_order:
      TRUNCATE entity.table_or_collection
      # reset_order is children-first (reverse topological) — no FK violations
  
  # STEP 3: Seed in topological order (parents first)
  FOR EACH entity IN registry.seed_order:
    fixture = READ(registry.shared_entities[entity].fixture_path)
    UPSERT fixture INTO entity.table_or_collection:
      strategy: ON_CONFLICT(id) DO UPDATE  # Idempotent
    LOG: "Seeded {entity}: {fixture.length} records"
  
  # STEP 4: Cross-domain referential integrity validation (BLOCKING)
  validation_result = validate_seed_integrity_runtime(registry)
  IF validation_result.failed:
    ❌ DEPLOYMENT WARNING: "Seed data integrity check FAILED"
    LOG errors: validation_result.errors[]
    OFFER: "Rollback deployment? Data is inconsistent."
  ELSE:
    LOG: "✅ Seed integrity validated: {validation_result.entities_checked} entities, {validation_result.fk_checks} FK checks, 0 orphans"

FUNCTION validate_seed_integrity_runtime(registry):
  errors = []
  entities_checked = 0
  fk_checks = 0
  
  FOR EACH entity IN registry.seed_order:
    entities_checked += 1
    
    # Check 1: Orphan FK detection
    FOR EACH dep IN registry.dependency_graph[entity]:
      fk_checks += 1
      orphan_count = QUERY:
        SELECT count(*) FROM {entity.table}
        LEFT JOIN {dep.table} ON {entity.table}.{fk_col} = {dep.table}.id
        WHERE {dep.table}.id IS NULL
      IF orphan_count > 0:
        errors.push("Orphan FK: {entity}.{fk_col} → {dep}: {orphan_count} orphans")
    
    # Check 2: Minimum entity count (from registry)
    actual_count = QUERY: SELECT count(*) FROM {entity.table}
    expected_count = registry.shared_entities[entity].count
    IF actual_count < expected_count:
      errors.push("Insufficient data: {entity} has {actual_count}/{expected_count} records")
  
  RETURN { failed: errors.length > 0, errors, entities_checked, fk_checks }
```

### Deployment Report Extension (Seed Section)

When seed pipeline runs, append to `deployment_report_{timestamp}.md`:

```markdown
## Synthetic Data
- **Seed executed:** YES | NO (existing data) | SKIP (production)
- **Force reseed:** YES | NO
- **Entities seeded:** {{N}} (in topological order)
- **Registry:** config/seed_registry.json
- **Integrity validation:** PASS | FAIL
- **FK checks:** {{N}} checks, {{N}} orphans
- **Entity counts:**
| Entity | Expected | Actual | Status |
|--------|----------|--------|--------|
| {{entity}} | {{N}} | {{N}} | OK/WARN |
```

---

## `DEVOPS --suspend [ID] --env {ENV}`

**Purpose**: Suspend resources to reduce costs (compute stops, storage maintained).

```yaml
PREREQUISITES:
  Environment must be ACTIVE
  Production environment: ❌ CANNOT be suspended (always-on)

PROCESS:
  1. Resolve scope (feature or env)
  2. Calculate cost savings estimate
  3. CONFIRM: "Suspend {N} resources in {ENV}? Estimated savings: ${X}/day"
  4. FOR EACH resource:
     EXECUTE IaC-specific suspension:
       Containers/VMs: Stop (no compute charge, storage preserved)
       Databases: Stop instance (storage charges continue)
       Functions: No action needed (pay-per-use)
       Queues/Topics: No action needed (minimal idle cost)
  5. UPDATE registry: status → SUSPENDED
  6. UPDATE devops_plan.md: environments[ENV].status → SUSPENDED
```

---

## `DEVOPS --resume [ID] --env {ENV}`

**Purpose**: Resume suspended resources.

```yaml
PREREQUISITES: Resources with status SUSPENDED

PROCESS:
  1. Resolve scope (feature or env)
  2. CONFIRM: "Resume {N} resources in {ENV}? Cost resumes: ${X}/day"
  3. FOR EACH resource:
     Start compute resources
     Wait for healthcheck (timeout: 5 min per resource)
  4. VERIFY all endpoints responsive
  5. UPDATE registry: status → ACTIVE
  6. UPDATE devops_plan.md: environments[ENV].status → ACTIVE
```

---

## `DEVOPS --rollback [ID] --env {ENV}`

**Purpose**: Revert failed deployment to last known good state.

```yaml
TRIGGERS: Failed smoke tests, degraded metrics, incidents

PROCESS:
  1. Resolve scope
  2. READ deployment history from deployment_report_*.md files
  3. DETERMINE rollback target (previous successful deployment)
  4. EXECUTE rollback per strategy:
     
     blue-green: Switch traffic back to old slot (instant)
     canary: Destroy canary instances, restore full traffic to old version
     rolling: Redeploy previous version using same rolling strategy
  
  5. VERIFY rollback successful (healthcheck + smoke tests)
  6. GENERATE rollback entry in deployment history
  7. NOTIFY: "IMPLEMENT --fix {ID}" for code correction
```

---

## `DEVOPS --teardown [ID] --env {ENV}`

**Purpose**: Destroy infrastructure (irreversible for compute, backup required for data).

```yaml
BLOCKERS:
  Production environment: Triple confirmation required
    1. "Type environment name to confirm: ___"
    2. "Type DESTROY to confirm: ___"
    3. "Final confirmation: Are you sure? (yes/no)"
  
  Data-bearing resources: Backup verification MANDATORY
    SCAN registry for data_bearing: true
    FOR EACH data-bearing resource:
      REQUIRE: "Confirm backup of {resource} exists and is verified"

PROCESS:
  1. Resolve scope (feature or env)
  2. Confirm all blockers cleared
  3. EXECUTE destroy in REVERSE tier order (3 → 2 → 1 → 0):
     Tier 3 (Edge): Remove DNS, CDN, API Gateway
     Tier 2 (Compute): Destroy services, functions, containers
     Tier 1 (Data): Destroy databases, caches (after backup!)
     Tier 0 (Networking): Destroy VPC, subnets, Security Groups
  4. EXECUTE: {iac_descriptor.commands.destroy}
  5. UPDATE registry: status → DESTROYED, destroyed_at: timestamp
  6. UPDATE devops_plan.md: environments[ENV].status → DESTROYED
  7. CLEANUP: Remove IaC state files for destroyed resources
```

---

## `DEVOPS --status [ID]`

**Purpose**: Query current infrastructure and deployment status (read-only).

### Feature-Scoped (with ID)
```yaml
OUTPUT table:
  Resource | Type | Env | Status | Endpoint | Cost | Last Event
  ---------|------|-----|--------|----------|------|----------
  user-db  | RDS  | dev | ACTIVE | rds://.. | $5/d | Deployed 2h ago
  ...

  Deployment History: Last 5 deployments per env
  Secrets Status: configured/deferred/n-a per env
  Cost Summary: Total per env + trend
  Next Steps: Smart Redirect suggestions
```

### Environment-Scoped (without ID)
```yaml
OUTPUT global dashboard:
  == Environment: {ENV_1} ==
  Status: ACTIVE | SUSPENDED | DESTROYED
  Resources: {N} active, {M} total
  Last Deploy: {timestamp} by {agent}
  Cost: ${X}/day
  
  Resources by Scope:
    System: {list with status}
    Feature-specific: {grouped by feature_id}
  
  == Environment: {ENV_2} ==
  ...
  
  Global Cost: ${total}/month ({budget_pct}% of budget)
  Alerts: {any warnings or blockers}
```

---

## Integration with Other Agents

### QA → DEVOPS (DAST Execution)
```yaml
QA --verify requires active environment
  IF pre-prod SUSPENDED: Suggest DEVOPS --resume --env {ENV}
  IF NOT_PROVISIONED: Suggest DEVOPS --provision {ID} --env {ENV}
  QA SEC hat runs DAST against active deployment endpoint
```

### QA → DEVOPS (Integration Testing)
```yaml
QA --verify may need isolated test environment
  DEVOPS provides env endpoint URLs
  DEVOPS may provision test-specific resources (test database, mock services)
```

### BLUEPRINT → DEVOPS (Infrastructure Updates)
```yaml
BLUEPRINT --refine {ID} "Add Redis"
  → design.md Section 5 updated with new resource
  → CASCADE_PENDING_ITERATION marks devops_plan.md stale
  → Factory Smart Redirect computes next steps from artifact state
  → DEVOPS detects iteration gap, processes delta update
  → Re-provision detects IaC drift, applies incremental change
```

---

## Command Summary

| Command | Purpose | ID Required | Output |
|---------|---------|-------------|--------|
| `--configure {ID}` | Plan + secrets | YES | devops_plan.md |
| `--refine {ID}` | Adjust plan | YES | Updated plan |
| `--provision [ID] --env {E}` | Create infra | Optional | IaC files + registry |
| `--deploy [ID] --env {E}` | Deploy code | Optional | deployment_report |
| `--suspend [ID] --env {E}` | Pause resources | Optional | Cost savings |
| `--resume [ID] --env {E}` | Resume resources | Optional | Resources active |
| `--rollback [ID] --env {E}` | Revert deploy | Optional | Previous version |
| `--teardown [ID] --env {E}` | Destroy infra | Optional | Resources destroyed |
| `--status [ID]` | Query status | Optional | Dashboard |

---

## 5 Mandatory Laws

1. **Constitutional Supremacy**: Stack in constitution.md is LAW
2. **Regulatory Compliance**: Follow ALL 12 rules assigned to DEVOPS
3. **Zero Secrets**: NEVER hardcode secrets in IaC, configs, or plan files
4. **Governance-First**: ALL decisions derive from governance files
5. **Traceability**: `// Generated by Agent: DEVOPS | Feature: {ID}`
