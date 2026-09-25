---
description: "Configuration standards — no hard-coded configuration, endpoints or credentials; system_resources.json, tiered secrets strategy (CI/CD vault, runtime vault, local .env), enforcement gates."
applicable_when:
  always: true
version: 1.0.0
date: 2026-09-25
changelog:
  - "1.0.0: feat(EVOL-043) — body home of [PLAW-05] Configuration Hardcoding Prohibition, moved from the constitution template"
---

# Configuration Hardcoding Prohibition

> **Auto-generated from** `docs/setup.md` decisions

## [PLAW-05] Configuration Hardcoding Prohibition
> No configuration value, infrastructure name, endpoint or credential lives in source code; each is externalised to configuration or to the secrets tier matching where it runs.

> **Mandate:** It is STRICTLY PROHIBITED to include configuration values, infrastructure, endpoints or credentials directly in the source code.

### Prohibited in Source Code
- ❌ **Configuration Values:** URLs, ports, hosts, timeouts, limits.
- ❌ **Infrastructure Configuration:** Bucket names, queues, topics, databases.
- ❌ **Endpoints:** API URLs (internal or external), service routes, webhooks.
- ❌ **Credentials:** API keys, tokens, passwords, certificates, secrets.
- ❌ **Environment-Specific Data:** Any data that varies between Dev/Staging/Prod.

### Externalization Strategy
1. **Configuration File:** `/config/system_resources.json` (machine-readable, version-controlled)
   - **Purpose:** Describes integrations, endpoints, infrastructure resources.
   - **Scope:** ALL external or internal resources that are not business code.
   - **Credentials:** ❌ NEVER in this file. See point 2.
   - **Schema Reference:** `.context/templates/setup/config/system_resources_schema.md`

2. **Secrets Management (Tiered Strategy):**
   - **Purpose:** Store credentials, API keys, tokens, certificates.
   - **Access:** Loaded at runtime, NEVER committed to git.
   - **Naming Convention:** `{SERVICE}_{RESOURCE}_{PURPOSE}` (e.g., `STRIPE_API_KEY`, `DB_PRIMARY_PASSWORD`).

   **Tier A — CI/CD Pipeline Secrets** (build, test, deploy phases):
   - **Storage:** Vault nativo del orquestador CI/CD (derivado de `ci_cd_strategy`).
     - GitHub Actions → GitHub Secrets (`${{ secrets.XXX }}`)
     - GitLab CI → GitLab CI/CD Variables (`$CI_VARIABLE`)
     - Azure DevOps → Azure DevOps Library / Variable Groups
     - Bitbucket Pipelines → Repository Variables
     - Jenkins → Jenkins Credentials Store
   - **Scope:** Secrets needed ONLY during the pipeline (deploy keys, registry tokens, cloud credentials for IaC).
   - **Rule:** NEVER inject via `.env` in CI/CD. Use the native orchestrator mechanism.

   **Tier B — Runtime/Product Secrets** (application at runtime, cloud/server):
   - **Storage:** Cloud provider vault or dedicated manager (field `secrets_manager` per-environment in Infrastructure Configuration).
     - AWS → AWS Secrets Manager / SSM Parameter Store
     - Azure → Azure Key Vault
     - GCP → Google Secret Manager
     - Multi-cloud / On-prem → HashiCorp Vault, Doppler
   - **Scope:** Secrets needed by the application at runtime (DB passwords, third-party API keys, OAuth secrets).
   - **Access Pattern:** Vault SDK or environment injection by the container/serverless orchestrator.
   - **Rule:** In environments running on cloud infrastructure or remote servers, ALWAYS use vault. NEVER `.env` files on remote servers.

   **Tier C — Local Development Secrets** (local machine):
   - **Storage:** `.env` file (local only) + `.gitignore` protection.
   - **Scope:** Same secrets as Tier B but for local execution (dev, manual testing, local staging, etc.).
   - **Rule:** `.env` is acceptable for any environment running on the developer's local machine or local infrastructure (docker-compose, localstack, minikube).
   - **Note:** A "staging" environment running locally (e.g., docker-compose) uses Tier C. A "dev" environment running on AWS uses Tier B. The tier depends on **where it runs**, not on the environment name.
   - **Companion:** `.env.example` committed with instructive placeholders (see Section 4 below).

3. **Environment Variables:** Referenced from vault or `.env` according to tier
   - **Pattern:** Code accesses secrets via the runtime's standard mechanism, the value is externalized:
     - Node.js: `process.env.STRIPE_API_KEY`
     - Python: `os.environ["STRIPE_API_KEY"]` / `os.getenv("STRIPE_API_KEY")`
     - Java/Kotlin: `System.getenv("STRIPE_API_KEY")` / Spring `@Value("${STRIPE_API_KEY}")`
     - Go: `os.Getenv("STRIPE_API_KEY")`
     - C#/.NET: `Environment.GetEnvironmentVariable("STRIPE_API_KEY")` / `IConfiguration`
   - **Cloud SDK Pattern (Tier B preferred):** In production, direct access to the vault via SDK is preferable to env vars:
     - AWS: `secretsmanager.GetSecretValue()`
     - Azure: `SecretClient.GetSecret()`
     - GCP: `SecretManagerServiceClient.AccessSecretVersion()`

### System Resources Configuration File

#### Location & Ownership
- **File:** `/config/system_resources.json`
- **Creation:** Generated during `/SETUP --generate` (empty or with base structure).
- **Maintenance:** `/ARCH` agents (integration design) and `/DEV` (resource implementation).
- **Validation:** `scripts/check-integrations.sh` executed in CI/CD and by `/QA` agent.
- **Template Reference:** `.context/templates/setup/config/system_resources.template.json`
- **Schema Documentation:** `.context/templates/setup/config/system_resources_schema.md`

#### Core Principles
- **Machine-Readable:** JSON format with strict schema validation.
- **No Credentials:** All secrets must be in the appropriate tier (CI/CD vault, cloud vault, or `.env` for local dev only), referenced via `envVars` field. See Tiered Secrets Strategy above.
- **Flexible Config:** Each resource has a `config` object for resource-specific settings.
- **Lifecycle Tracking:** Version, lastReviewed, status (active/deprecated/planned).
- **Traceability:** Owner, purpose, documentationUrl for audit and maintenance.

#### Usage Instructions
1. **During Setup** (`/SETUP --generate`): Create `/config/system_resources.json` using template structure
2. **During Blueprint** (`/BLUEPRINT --start`): Add integrations and infrastructure resources following schema
3. **During Development** (`/IMPLEMENT --build`): Add internal endpoints and service-specific configurations
4. **Adaptation Rule:** Follow the canonical schema structure but adapt `config` object fields based on:
   - Resource type (integration, database, queue, etc.)
   - Architecture pattern (monolith, microservices, serverless)
   - Specific technology stack decisions from setup

> **Complete Schema Definition:** See `.context/templates/setup/config/system_resources_schema.md`

### Enforcement
- **CI/CD Gate:** `scripts/check-integrations.sh` validates structure, schema compliance, and absence of credentials (BLOCKING).
- **Pre-Commit Hook:** `scripts/security-scan.sh --secrets` blocks commits with detected secrets (scanner per `config/quality.json.security_scan`; regex floor always on).
- **Code Review:** Any configuration hardcoding must be rejected in PR.

### Further Reading
- [12-Factor App - Config](https://12factor.net/config)
- [OWASP Configuration Management](https://owasp.org/www-project-proactive-controls/)
