# Scripts

All scripts use DRY_RUN=1 by default. Use `--apply` or export DRY_RUN=0 to run for real.

## Lista de scripts

- check-structure.sh `<arch>` [--apply]
- lint-format.sh `<tech>` [--apply]
- test.sh [scope] [--apply]
- security-scan.sh [--semgrep] [--gitleaks] [--dast] [--dast-full] [--dast-api] [--apply]
- dependency-allowlist.sh [--apply]
- validate-gitignore.sh [--strict]
- check-integrations.sh [--strict] [--skip-connect] [--env `<file>`]
- install-hooks.sh [--force]
- hooks/commit-msg — Conventional commit format validation
- hooks/pre-commit — Protected branch guard, secret detection, governance validation
- hooks/pre-push — Force-push protection, full governance validation

## Quick Start Aligned to the Agentic Workflow

1) **Setup/Governance**: `validate-gitignore.sh` validates .gitignore compliance with mandatory security patterns (.env, .context/).
2) **PO/QA/Blueprint**: use `check-structure.sh <arch>` to validate scaffolding before coding.
3) **Develop (TDD)**: run `lint-format.sh <tech>` and `test.sh` (unit) in DRY_RUN by default.
4) **Final QA**: `lint-format.sh <tech>` + `test.sh` + `check-integrations.sh` to validate quality before Security.
5) **E2E QA (Staging)**: `test.sh e2e` (Playwright) or `test.sh api-e2e` (Newman) to validate user journeys post-deployment.
6) **Security (SAST)**: `security-scan.sh --semgrep --gitleaks` + `validate-gitignore.sh --strict` + `check-integrations.sh --strict` to verify integrity.
7) **Security (DAST)**: `TARGET_URL=https://staging.example.com security-scan.sh --dast` (baseline) or `--dast-full` (active scan) for dynamic scanning with OWASP ZAP.
8) **Dependencies**: `dependency-allowlist.sh` to verify against allowed/blocklist in `docs/constitution.md`.

Remember to record transitions and validations in the JSONL files per feature under `docs/project_log/features/*.log.jsonl` (the index `docs/project_log/workflow_log.json` is metadata only and must not be edited manually).

---

## test.sh - Test Runner

**Purpose:** Unified test execution with scope-based routing (unit, integration, e2e).

**⚠️ Initial State (Post-Scaffolding):**
After `/SETUP --generate`, this script validates test infrastructure but has NO tests to execute. Tests are generated ONLY during `/IMPLEMENT --build` following TDD strict cycle.

**Usage:**
```bash
./scripts/test.sh [scope] [--apply]
```

**Scopes:**
- `all` (default): Run all unit and integration tests (if any exist).
- `unit`: Run only unit tests (if any exist).
- `integration`: Run only integration tests (if any exist).
- `e2e` / `e2e-ui`: Run Playwright E2E tests for Web UI (requires `playwright.config.ts` + test specs).
- `api`: Run API integration tests in `tests/api/` (HTTP endpoint tests generated during `/IMPLEMENT --build` Phase A).
- `api-e2e`: Run Newman E2E tests for API (requires Newman + Postman collections).

**Examples:**
```bash
# Validate test infrastructure (no tests yet after scaffolding)
./scripts/test.sh

# Execute unit tests (after /IMPLEMENT --build creates them)
./scripts/test.sh unit --apply

# Dry-run Playwright E2E tests
./scripts/test.sh e2e

# Execute E2E tests on staging
BASE_URL=https://staging.example.com ./scripts/test.sh e2e --apply

# Dry-run API E2E tests with Newman
./scripts/test.sh api-e2e

# Execute API E2E tests
./scripts/test.sh api-e2e --apply
```

**Integration with QA Agent:**
- QA Agent uses `/QA --e2e {{FEATURE_ID}}` to trigger E2E tests post-staging deployment.
- Test results are parsed and included in `docs/spec/{{FEATURE_ID}}/qa/e2e_report_{{timestamp}}.md`.

---

## security-scan.sh - Security Scanner

**Purpose:** Orchestrates SAST (Semgrep, Gitleaks) and DAST (OWASP ZAP) security scans.

**Usage:**
```bash
./scripts/security-scan.sh [--semgrep] [--gitleaks] [--dast] [--dast-full] [--dast-api] [--apply]
```

**Flags:**
- `--semgrep`: Run Semgrep SAST (static code analysis for vulnerabilities).
- `--gitleaks`: Run Gitleaks (secret detection in code and git history).
- `--dast`: Run OWASP ZAP Baseline Scan (passive + spider, ~10 min).
- `--dast-full`: Run OWASP ZAP Full Scan (active attacks + AJAX spider, ~30 min).
- `--dast-api`: Run OWASP ZAP API Scan (OpenAPI/GraphQL schema import, ~15 min).
- `--apply`: Execute in production mode (default is DRY_RUN=1).

**DAST Requirements:**
- Docker must be installed and running.
- `TARGET_URL` environment variable must be set (staging/production URL).
- OWASP ZAP Docker image will be pulled automatically.

**Examples:**
```bash
# Dry-run SAST scans (Semgrep + Gitleaks)
./scripts/security-scan.sh --semgrep --gitleaks

# Execute DAST baseline scan on staging
TARGET_URL=https://staging.example.com ./scripts/security-scan.sh --dast --apply

# Execute DAST full scan (with active attacks) on staging
TARGET_URL=https://staging.example.com ./scripts/security-scan.sh --dast-full --apply

# Execute DAST API scan with OpenAPI spec
TARGET_URL=https://api.staging.example.com ./scripts/security-scan.sh --dast-api --apply
```

**Integration with Security Agent:**
- `/IMPLEMENT --build` (🛡️ SEC hat) performs SAST scans inline per phase.
- `/QA --verify` (🛡️ SEC hat) performs DAST scans inline during post-staging verification (v8.0.0). Legacy: `/SEC --dast` is DEPRECATED.
- DAST reports are generated in `security/dast/reports/zap-report-{{timestamp}}.html`.
- High-risk vulnerabilities block merge/deployment automatically.

---

## validate-gitignore.sh - .gitignore Compliance Validator

**Purpose:** CI/CD validation gate to ensure .gitignore complies with mandatory security patterns.

**Usage:**
```bash
./scripts/validate-gitignore.sh [--strict]
```

**Checks:**
1. `.gitignore` file exists.
2. `.env` is ignored (CRITICAL - secrets protection).
3. `.context/agents/` is ignored (CRITICAL - agent protection).
4. `.env.example` is tracked (best practice).
5. Gitleaks scan (if installed) - detect committed secrets.
6. Stack-specific patterns (Node.js, Python).

**Flags:**
- `--strict`: Enable stricter validation (fail on warnings).

**Integration:**
- SETUP Agent generates `.gitignore` and this validation script during `/SETUP --generate`.
- Should be added to CI/CD workflows as pre-commit check.
- QA Agent runs this script during `/QA --verify` to ensure compliance.

---

## check-integrations.sh - System Resources Configuration Validator

**Purpose:** Validate `/config/system_resources.json` structure, schema compliance, and test connectivity to all active resources.

**Usage:**
```bash
./scripts/check-integrations.sh [FLAGS]
```

**Flags:**
- `--strict`: Fail on warnings (not just errors)
- `--skip-connect`: Skip connectivity tests (structure validation only)
- `--env <file>`: Load environment variables from specific file (default: `.env`)

**Exit Codes:**
- `0`: All validations passed
- `1`: Schema/structure errors found
- `2`: Credentials detected in config file (CRITICAL)
- `3`: Connectivity tests failed (active resources unreachable)

**What it validates:**
1. **File Existence**: Ensures `/config/system_resources.json` exists
2. **JSON Structure**: Validates JSON syntax
3. **Schema Compliance**: Checks all required fields are present
4. **Unique IDs**: Ensures no duplicate resource IDs
5. **No Credentials**: Scans for hardcoded secrets/passwords/keys
6. **Environment Variables**: Verifies referenced env vars exist
7. **Connectivity**: Tests connection to all `status: active` resources

**Examples:**
```bash
# Dry-run validation (structure + schema only)
./scripts/check-integrations.sh --skip-connect

# Full validation with connectivity tests
./scripts/check-integrations.sh

# Strict mode (warnings as errors)
./scripts/check-integrations.sh --strict

# Custom environment file
./scripts/check-integrations.sh --env .env.staging
```

**CI/CD Integration:**
```yaml
# GitHub Actions example
- name: Validate Integrations
  run: ./scripts/check-integrations.sh --strict
```

**Agent Integration:**
- **QA Agent** (`/QA --verify`): Runs this script during validation phase (BLOCKER on failure)
- **BLUEPRINT Agent** (`/BLUEPRINT --start`): References this validation in ADRs
- **IMPLEMENT Agent** (`/IMPLEMENT --build`): Ensures resources are added correctly

**Example Output:**
```
[INFO] Validating configuration file existence...
[SUCCESS] Configuration file found: /config/system_resources.json
[INFO] Validating JSON structure...
[SUCCESS] JSON structure is valid
[INFO] Validating schema compliance...
[SUCCESS] Schema compliance validated (8 resources found)
[INFO] Validating unique resource IDs...
[SUCCESS] All resource IDs are unique
[INFO] Scanning for hardcoded credentials...
[SUCCESS] No hardcoded credentials detected
[INFO] Testing connectivity to active resources...
[SUCCESS]   ✓ stripe-payment-api is reachable
[SUCCESS]   ✓ user-service-internal is reachable
[SUCCESS]   ✓ pg-primary-db is reachable

========================================
All validations passed successfully!
========================================
```

**Related Documentation:**
- Schema Reference: `.context/templates/setup/config/system_resources_schema.md`
- Template: `.context/templates/setup/config/system_resources.template.json`
- Constitution: `.context/constitution.md` (Configuration Hardcoding Prohibition section)
