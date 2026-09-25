---
description: "CI/CD pipeline standards — workflow configuration, environment management, deployment gates, artifact handling. Applied when editing CI/CD configuration."
applicable_when:
  path_glob:
    - ".github/workflows/**"
    - "**/Jenkinsfile"
    - "**/.gitlab-ci.yml"
    - "**/azure-pipelines.yml"
version: 1.6.0
date: 2026-09-25
changelog:
  - "1.6.0: feat(EVOL-047) — deploying / release jobs ask gate.py runtime-surface --changed first; the branch rule is untouched."
  - "1.5.1: feat(EVOL-044) — frontmatter `version` realigned to this manifest entry (manifest-parity gate); YAML made parseable where needed."
  - "1.1.0: feat(EVOL-043) — hosts [PLAW-12] body (merged from the constitution template)"
  - "1.0.0: Initial template version"
---

# CI/CD Pipeline Rules & Configuration

> **Auto-generated from:** `docs/setup.md` decisions  
> **Platform:** {{CI_CD_PLATFORM}}  
> **Pipeline Depth:** {{PIPELINE_DEPTH}}  
> **Environment Strategy:** {{ENVIRONMENT_STRATEGY}}

## Pipeline Architecture

### Stages ({{PIPELINE_DEPTH}})

{{#if PIPELINE_DEPTH == "Basic"}}
1. **Lint & Format:** `scripts/lint-format.sh --apply`
2. **Unit Tests:** `scripts/test.sh` (coverage report)
3. **Build:** Compile artifacts, build Docker image
4. **Deploy Dev:** Push to Development environment
{{/if}}

{{#if PIPELINE_DEPTH == "Advanced"}}
1. **Lint & Format:** `scripts/lint-format.sh --apply`
2. **Unit Tests:** `scripts/test.sh` (≥80% coverage)
3. **Security Scan:** `scripts/security-scan.sh --secrets` (scanner per `config/quality.json.security_scan`; blocks on findings)
4. **Build:** Compile artifacts, build Docker image
5. **Integration Tests:** API + DB tests
6. **Deploy Dev:** Auto-deploy to development
7. **Deploy Staging:** Auto-deploy on release/* branches — every deploying / release-cutting job asks `python3 scripts/gate.py runtime-surface --changed` first and skips its machinery when the merge touched nothing on `config/quality.json → surface.runtime_surface` (the positive list; hard exclusions in `surface.always_deploy`; EVOL-047). The branch rule is untouched: every change ships via branch and pull request.
8. **Performance Tests:** Load testing on staging
9. **Deploy Prod:** Manual approval required
10. **Smoke Tests:** Health checks post-deploy
11. **Rollback:** Auto-rollback on health check failure
{{/if}}

## Quality Gates

| Stage | Threshold | Action on Failure |
|-------|-----------|-------------------|
| Unit Tests | Coverage ≥80% | Block merge |
| Security Scan | No HIGH/CRITICAL vulns | Block deploy |
| Integration Tests | 100% pass rate | Block staging deploy |
| Performance Tests | p95 <200ms | Alert + manual review |
| Smoke Tests (Prod) | All health endpoints 200 OK | Trigger auto-rollback |

## Secrets Management in Pipelines (Tier A — CI/CD Vault)

> **Mandate:** Pipeline secrets MUST use the native vault of the CI/CD orchestrator. NEVER inject secrets via `.env` files in pipelines.
> **Source of Truth:** `constitution.md` → `infrastructure.secrets_cicd`

### Secrets Injection by Platform

{{#if CI_CD_PLATFORM == "GitHub Actions"}}
**Vault:** GitHub Secrets (`Settings → Secrets and variables → Actions`)
```yaml
# In .github/workflows/ci.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      DATABASE_URL: ${{ secrets.DATABASE_URL }}
      API_KEY_STRIPE: ${{ secrets.API_KEY_STRIPE }}
    steps:
      - name: Deploy
        run: ./scripts/deploy.sh
        env:
          CLOUD_ACCESS_KEY: ${{ secrets.CLOUD_ACCESS_KEY }}
```
**Rules:**
- Store ALL deploy/build secrets in `Settings → Secrets → Actions`
- Use `environment` secrets for env-specific values (dev, staging, prod)
- NEVER echo `${{ secrets.* }}` in logs (GitHub auto-masks, but avoid explicitly)
- Use OIDC (`aws-actions/configure-aws-credentials`) for cloud auth instead of static keys when possible
{{/if}}

{{#if CI_CD_PLATFORM == "GitLab CI"}}
**Vault:** GitLab CI/CD Variables (`Settings → CI/CD → Variables`)
```yaml
# In .gitlab-ci.yml
deploy_staging:
  stage: deploy
  variables:
    DATABASE_URL: $DATABASE_URL      # From CI/CD Variables
    API_KEY_STRIPE: $API_KEY_STRIPE
  script:
    - ./scripts/deploy.sh
  environment:
    name: staging
```
**Rules:**
- Store ALL secrets in `Settings → CI/CD → Variables` (masked + protected)
- Use `environment` scope for env-specific values
- Enable `Protected` flag for prod secrets (only on protected branches)
- Enable `Masked` flag for all secrets (prevents log leaks)
{{/if}}

{{#if CI_CD_PLATFORM == "Azure DevOps"}}
**Vault:** Azure DevOps Variable Groups (`Pipelines → Library`)
```yaml
# In azure-pipelines.yml
variables:
  - group: 'production-secrets'
steps:
  - script: ./scripts/deploy.sh
    env:
      DATABASE_URL: $(DATABASE_URL)
      API_KEY_STRIPE: $(API_KEY_STRIPE)
```
**Rules:**
- Use Variable Groups linked to Azure Key Vault for runtime secrets
- Mark secrets as `isSecret: true` in variable definitions
- Use service connections for cloud auth (not static credentials)
{{/if}}

{{#if CI_CD_PLATFORM == "Bitbucket Pipelines"}}
**Vault:** Bitbucket Repository/Deployment Variables (`Repository settings → Pipelines → Variables`)
```yaml
# In bitbucket-pipelines.yml
pipelines:
  branches:
    main:
      - step:
          name: Deploy
          deployment: production
          script:
            - ./scripts/deploy.sh
          # Variables injected automatically from deployment environment
```
**Rules:**
- Store ALL secrets in `Repository settings → Pipelines → Repository variables` (secured)
- Use `Deployment variables` for environment-specific values (dev, staging, prod)
- Enable `Secured` flag for all secrets (masks in logs and hides value)
- Use OIDC with AWS/GCP/Azure for cloud auth when available
{{/if}}

{{#if CI_CD_PLATFORM == "Jenkins"}}
**Vault:** Jenkins Credentials Store (`Manage Jenkins → Manage Credentials`)
```groovy
// In Jenkinsfile
pipeline {
  environment {
    DATABASE_URL = credentials('database-url')
    API_KEY_STRIPE = credentials('stripe-api-key')
    CLOUD_CREDS = credentials('aws-deploy-creds')
  }
  stages {
    stage('Deploy') {
      steps {
        sh './scripts/deploy.sh'
      }
    }
  }
}
```
**Rules:**
- Store ALL secrets in Jenkins Credentials (type: Secret text, Username+Password, or Secret file)
- Use `credentials()` binding — NEVER `withEnv` with plain strings
- Use folder-scoped credentials for multi-project isolation
- Prefer HashiCorp Vault plugin for enterprise deployments
- NEVER print credentials with `echo` or `sh 'env'`
{{/if}}

{{#if CI_CD_PLATFORM == "AWS CodePipeline"}}
**Vault:** AWS Secrets Manager + IAM Roles
```yaml
# In buildspec.yml
version: 0.2
env:
  secrets-manager:
    DATABASE_URL: "prod/database:url"
    API_KEY_STRIPE: "prod/stripe:api_key"
phases:
  build:
    commands:
      - ./scripts/deploy.sh
```
**Rules:**
- Store ALL secrets in AWS Secrets Manager (or SSM Parameter Store for non-sensitive config)
- Use `env.secrets-manager` in buildspec for automatic injection
- CodeBuild IAM role must have `secretsmanager:GetSecretValue` permission (least privilege)
- Use IAM roles for cross-service auth — NEVER store AWS keys as secrets
- Enable secret rotation via Secrets Manager rotation lambdas
- Tag secrets with `Environment`, `Application`, `Owner` for audit
{{/if}}

{{#if CI_CD_PLATFORM == "GCP Cloud Build"}}
**Vault:** Google Secret Manager + IAM Service Accounts
```yaml
# In cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        export DATABASE_URL=$$(gcloud secrets versions access latest --secret=database-url)
        export API_KEY_STRIPE=$$(gcloud secrets versions access latest --secret=stripe-api-key)
        ./scripts/deploy.sh
availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/database-url/versions/latest
      env: DATABASE_URL
    - versionName: projects/$PROJECT_ID/secrets/stripe-api-key/versions/latest
      env: API_KEY_STRIPE
```
**Rules:**
- Store ALL secrets in Google Secret Manager
- Use `availableSecrets.secretManager` block for declarative injection (preferred)
- Cloud Build service account needs `roles/secretmanager.secretAccessor`
- Use Workload Identity Federation for external CI auth — NEVER export service account keys
- Enable automatic replication for multi-region availability
- Use `$$` escaping for Cloud Build variable substitution vs shell variables
{{/if}}

### Secrets Categories for CI/CD

| Category | Examples | Storage | Rotation |
|----------|----------|---------|----------|
| **Cloud Auth** | AWS_ACCESS_KEY_ID, AZURE_CREDENTIALS | CI/CD vault (prefer OIDC) | 90 days |
| **Registry** | DOCKER_TOKEN, NPM_TOKEN, GHCR_TOKEN | CI/CD vault | On compromise |
| **Deploy Keys** | SSH_DEPLOY_KEY, KUBECONFIG | CI/CD vault (protected) | 180 days |
| **App Secrets** | DATABASE_URL, API_KEY_* | CI/CD vault → injected at deploy | Per rotation policy |
| **Notification** | SLACK_WEBHOOK, PAGERDUTY_KEY | CI/CD vault | On compromise |

### Prohibited in CI/CD Pipelines

- ❌ `.env` files copied/mounted into pipeline jobs
- ❌ Secrets passed as plain-text build arguments
- ❌ Hardcoded credentials in pipeline YAML
- ❌ `echo $SECRET` or equivalent in pipeline scripts
- ❌ Secrets stored in repository variables without masking

### Integration with Runtime Vault (Tier B)

For secrets needed by the running application (not just the pipeline):
- CI/CD pipeline provisions/rotates secrets in the cloud vault during deployment
- Application reads from cloud vault at runtime (AWS SM, Azure KV, etc.)
- Pipeline uses Tier A credentials to authenticate TO the Tier B vault
- See `[PLAW-05]` in `.claude/rules/configuration.md` § Tiered Secrets Strategy for full policy

## [PLAW-12] Deployment & Environment Strategy
> Every deployment passes through the declared quality gates of its environment; production deploys require manual approval, and infrastructure changes are made only as code.

> **Mandate:** All deployments MUST pass through defined quality gates. Production deploys require manual approval.

### Environment Topology
> **Selected Strategy:** {{ENVIRONMENT_STRATEGY}} (defined in setup)

<!-- INFRASTRUCTURE_CONFIG_START
The following structured fields are used by /DEVOPS agent for governance-first infrastructure planning.
These fields are populated during /SETUP --generate based on user decisions.
If a field cannot be determined, it defaults to "unknown" and /DEVOPS will prompt during planning.
-->

### Infrastructure Configuration (Structured Fields)

```yaml
# Cloud & IaC Configuration (populated by /SETUP --generate)
infrastructure:
  cloud_provider: {{CLOUD_PROVIDER}}  # aws | azure | gcp | local | hybrid | unknown
  iac_tool: {{IAC_TOOL}}              # terraform | pulumi | aws-cdk | docker-compose | localstack | sam | unknown
  iac_descriptor:                      # Universal IaC meta-model (populated by /SETUP --generate from Q23)
    entry_point: {{IAC_ENTRY_POINT}}               # e.g., main.tf | Pulumi.yaml | cdk.json
    provider_config: {{IAC_PROVIDER_CONFIG}}        # e.g., provider.tf | Pulumi.aws.yaml
    state_management: {{IAC_STATE_MANAGEMENT}}      # e.g., backend "s3" | Pulumi Cloud | cdk-toolkit
    env_config_pattern: {{IAC_ENV_CONFIG_PATTERN}}  # e.g., envs/{env}.tfvars | Pulumi.{env}.yaml
    module_dir: {{IAC_MODULE_DIR}}                  # e.g., modules/ | packages/ | constructs/
    commands:
      validate: {{IAC_CMD_VALIDATE}}    # e.g., terraform validate | pulumi preview --diff
      plan: {{IAC_CMD_PLAN}}            # e.g., terraform plan | pulumi preview
      apply: {{IAC_CMD_APPLY}}          # e.g., terraform apply | pulumi up
      destroy: {{IAC_CMD_DESTROY}}      # e.g., terraform destroy | pulumi destroy
      format: {{IAC_CMD_FORMAT}}        # e.g., terraform fmt | pulumi (N/A)
  environments:                        # List of environments with per-env secrets config
    - name: {{ENV_1}}                  # e.g., dev
      hosting: {{ENV_1_HOSTING}}       # local | cloud | hybrid
      secrets_manager: {{ENV_1_SECRETS_MANAGER}}  # env-file | aws-secrets-manager | azure-keyvault | gcp-secret-manager | hashicorp-vault | doppler
    - name: {{ENV_2}}                  # e.g., staging
      hosting: {{ENV_2_HOSTING}}       # local | cloud | hybrid
      secrets_manager: {{ENV_2_SECRETS_MANAGER}}
    - name: {{ENV_3}}                  # e.g., prod
      hosting: {{ENV_3_HOSTING}}       # local | cloud | hybrid
      secrets_manager: {{ENV_3_SECRETS_MANAGER}}
  deployment_strategy: {{DEPLOYMENT_STRATEGY}}  # blue-green | canary | rolling | recreate | unknown
  secrets_manager_default: {{SECRETS_MANAGER}}  # Default/primary vault for non-local envs: aws-secrets-manager | azure-keyvault | gcp-secret-manager | hashicorp-vault | doppler | env-file | unknown
  secrets_cicd: {{SECRETS_CICD}}                  # github-secrets | gitlab-ci-variables | azure-devops-library | bitbucket-variables | jenkins-credentials | env-file | unknown

# Observability Stack
observability:
  metrics: {{OBSERVABILITY_METRICS}}      # prometheus | datadog | cloudwatch | elastic | unknown
  logging: {{OBSERVABILITY_LOGGING}}      # elk | cloudwatch | datadog | loki | unknown
  tracing: {{OBSERVABILITY_TRACING}}      # jaeger | zipkin | datadog | xray | unknown
  alerting: {{OBSERVABILITY_ALERTING}}    # pagerduty | opsgenie | slack | email | unknown

# Security Configuration
security:
  encryption_at_rest:
    required: {{ENCRYPTION_AT_REST}}      # true | false | unknown
  encryption_in_transit:
    required: {{ENCRYPTION_IN_TRANSIT}}   # true | false | unknown (default: true)
  network_policy: {{NETWORK_POLICY}}      # default-deny | allow-all | custom | unknown
```

<!-- INFRASTRUCTURE_CONFIG_END -->

{{#if ENVIRONMENT_STRATEGY == "Standard"}}
#### Standard: Dev → Staging → Production
- **Development:** Auto-deploy on merge to `main`
- **Staging:** Auto-deploy on merge to `release/*`
- **Production:** Manual approval after staging validation

| Environment | Purpose | Auto-Deploy | Quality Gates | Rollback |
|-------------|---------|-------------|---------------|----------|
| **Development** | Integration testing, agentic validation | ✅ On merge to `main` | Lint + Unit Tests (80%) | Manual |
| **Staging** | Pre-production validation, stakeholder review | ✅ On merge to `release/*` (if applicable) | Full test suite + Security scan + Integration tests | Manual |
| **Production** | Live user traffic | ❌ Manual approval required | All gates + Performance tests + Smoke tests post-deploy | Automated on health check failure |
{{/if}}

{{#if ENVIRONMENT_STRATEGY == "Minimal"}}
#### Minimal: Dev → Production
- **Development:** Auto-deploy on merge to `main`
- **Production:** Manual approval + 2-hour observation window

| Environment | Purpose | Auto-Deploy | Quality Gates | Rollback |
|-------------|---------|-------------|---------------|----------|
| **Development** | Integration testing | ✅ On merge to `main` | Lint + Unit Tests + Security scan | Manual |
| **Production** | Live user traffic | ❌ Manual approval + 2-hour observation window | All gates + Load tests + Smoke tests | Automated on health check failure |
{{/if}}

### Deployment Flow

#### Development Environment
- **Trigger:** Auto-deploy on merge to `main`
- **Validation:** Basic smoke tests (health endpoints 200 OK)
- **Purpose:** Fast feedback for agentic workflows and developer testing
- **Data:** Synthetic/anonymized data, refreshed daily

#### Staging Environment
- **Trigger:** Auto-deploy on `release/*` branch creation or manual trigger
- **Validation:** Full regression suite, security scan, integration tests
- **Purpose:** Pre-production validation, stakeholder demos, performance testing
- **Data:** Production-like dataset (anonymized), synced weekly

#### Production Environment
- **Trigger:** Manual approval after staging validation
- **Validation:** All quality gates + manual QA sign-off
- **Process:**
  1. Deploy to canary (10% traffic) → Monitor for 30min
  2. Expand to 50% traffic → Monitor for 30min
  3. Full rollout (100% traffic)
  4. Post-deploy smoke tests + health check monitoring
- **Rollback:** Automated if health checks fail within 15min window

### Environment Variable Management

#### Template Structure
- **Files:** `.env.example.dev`, `.env.example.staging`, `.env.example.prod`
- **Secrets:** NEVER commit actual values. Use placeholders in examples.

#### Naming Convention
```
{SERVICE}_{RESOURCE}_{PURPOSE}
```

**Examples:**
- `DB_PRIMARY_CONNECTION_STRING`
- `REDIS_CACHE_URL`
- `AUTH_JWT_SECRET`
- `STRIPE_API_KEY`

#### Secrets Management
- **Development:** Local `.env` file (gitignored)
- **Staging/Production:** [AWS Secrets Manager | HashiCorp Vault | Azure Key Vault | GitHub Secrets]
- **Rotation:** Automatic rotation every 90 days for production secrets
- **Access:** Least privilege (only services that need it)

### Infrastructure as Code (IaC)

#### Required for Production
- **Tools:** {{IAC_TOOL}} (see `iac_descriptor` in Infrastructure Configuration for commands and patterns)
- **Version Control:** All IaC in `infra/` directory, reviewed via PR
  - `infra/modules/` — System-scope modules (shared across 2+ features)
  - `infra/features/{FEATURE_ID}/` — Feature-exclusive IaC (single consumer)
- **State Management:** {{IAC_STATE_MANAGEMENT}} (remote state, never local in CI)
- **Change Process:** Plan → Review → Apply (never manual console changes)
- **Governance:** See `.claude/rules/iac.md` for naming, security, tagging, and module policies
- **Registry:** `config/infrastructure_registry.json` tracks all provisioned resources with scope (feature/system) and consumer tracking

#### Drift Detection
- **Schedule:** Daily automated drift detection
- **Action:** Alert + create ticket for remediation
- **Compliance:** Production infrastructure must match IaC definition

### Disaster Recovery

#### Backup Strategy
- **Database:** Automated daily backups, 30-day retention
- **Application State:** Stateless design (no local state to back up)
- **Configuration:** Versioned in git, immutable deployments

#### Recovery Time Objectives (RTO/RPO)
| Tier | System | RTO | RPO | Strategy |
|------|--------|-----|-----|----------|
| **Tier 1 (Critical)** | Payment processing, Auth | <15min | <5min | Active-active multi-region |
| **Tier 2 (Standard)** | Core application logic | <1hr | <15min | Active-passive with automated failover |
| **Tier 3 (Non-Critical)** | Analytics, reporting | <4hr | <1hr | Backup restoration |

## Platform-Specific Configuration

### {{CI_CD_PLATFORM}}

{{#if CI_CD_PLATFORM == "GitHub Actions"}}
**Pipeline File:** `.github/workflows/ci.yml`
```yaml
name: CI/CD Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: scripts/lint-format.sh --apply
      - name: Test
        run: scripts/test.sh
      - name: Security Scan
        run: scripts/security-scan.sh --secrets
  
  deploy-dev:
    needs: lint-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Development
        run: |
          # Deployment script here
          echo "Deploying to dev environment..."
```

**Auto-Tagging Workflow:** `.github/workflows/auto-tag.yml`
> Automatically creates SemVer tags and GitHub Releases on PR merge to main.
> See **SemVer Auto-Tagging** section below for details.
{{/if}}

{{#if CI_CD_PLATFORM == "GitLab CI"}}
**Pipeline File:** `.gitlab-ci.yml`
```yaml
stages:
  - lint
  - test
  - security
  - build
  - deploy

lint:
  stage: lint
  script:
    - scripts/lint-format.sh --apply

test:
  stage: test
  script:
    - scripts/test.sh
  coverage: '/TOTAL.*\s+(\d+%)$/'

security:
  stage: security
  script:
    - scripts/security-scan.sh --secrets

deploy_dev:
  stage: deploy
  script:
    - echo "Deploying to dev..."
  only:
    - main
```

**Auto-Tagging:** Included as `auto-tag` job in `.gitlab-ci.yml`.
> Automatically creates SemVer tags and GitLab Releases on merge to main.
> See **SemVer Auto-Tagging** section below for details.
{{/if}}

{{#if CI_CD_PLATFORM == "Azure DevOps"}}
**Pipeline File:** `azure-pipelines.yml`
```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: LintTest
    jobs:
      - job: QualityGates
        steps:
          - script: scripts/lint-format.sh --apply
            displayName: 'Lint & Format'
          - script: scripts/test.sh
            displayName: 'Unit Tests'
          - script: scripts/security-scan.sh --secrets
            displayName: 'Security Scan'

  - stage: DeployDev
    dependsOn: LintTest
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployToDev
        environment: development
        strategy:
          runOnce:
            deploy:
              steps:
                - script: echo "Deploying to dev..."
```

**Auto-Tagging Pipeline:** `azure-pipelines-auto-tag.yml`
> Automatically creates SemVer tags on PR merge to main.
> See **SemVer Auto-Tagging** section below for details.
{{/if}}

{{#if CI_CD_PLATFORM == "Bitbucket Pipelines"}}
**Pipeline File:** `bitbucket-pipelines.yml`
```yaml
image: node:20

pipelines:
  pull-requests:
    '**':
      - step:
          name: Quality Gates
          caches:
            - node
          script:
            - scripts/lint-format.sh --apply
            - scripts/test.sh
            - scripts/security-scan.sh --secrets

  branches:
    main:
      - step:
          name: Deploy to Dev
          deployment: development
          script:
            - echo "Deploying to dev..."
```

**Auto-Tagging:** Included as a step in `bitbucket-pipelines.yml` main branch pipeline.
> Automatically creates SemVer tags on merge to main.
> See **SemVer Auto-Tagging** section below for details.
{{/if}}

{{#if CI_CD_PLATFORM == "Jenkins"}}
**Pipeline File:** `Jenkinsfile`
```groovy
pipeline {
  agent any
  stages {
    stage('Lint & Format') {
      steps { sh 'scripts/lint-format.sh --apply' }
    }
    stage('Unit Tests') {
      steps { sh 'scripts/test.sh' }
    }
    stage('Security Scan') {
      steps { sh 'scripts/security-scan.sh --secrets' }
    }
    stage('Deploy Dev') {
      when { branch 'main' }
      steps { sh 'echo "Deploying to dev..."' }
    }
  }
}
```

**Auto-Tagging Pipeline:** `Jenkinsfile.auto-tag`
> Automatically creates SemVer tags on merge to main.
> Requires a separate Jenkins job pointing to `Jenkinsfile.auto-tag`.
> See **SemVer Auto-Tagging** section below for details.
{{/if}}

{{#if CI_CD_PLATFORM == "AWS CodePipeline"}}
**BuildSpec File:** `buildspec.yml`
```yaml
version: 0.2
phases:
  install:
    runtime-versions:
      nodejs: 20
  pre_build:
    commands:
      - scripts/lint-format.sh --apply
      - scripts/test.sh
      - scripts/security-scan.sh --secrets
  build:
    commands:
      - echo "Building artifacts..."
  post_build:
    commands:
      - echo "Deploying to dev..."
reports:
  test-results:
    files:
      - '**/*'
    base-directory: coverage
```

**Auto-Tagging BuildSpec:** `buildspec-auto-tag.yml`
> Requires a separate CodeBuild project triggered by CodePipeline on merge to main.
> See **SemVer Auto-Tagging** section below for details.
{{/if}}

{{#if CI_CD_PLATFORM == "GCP Cloud Build"}}
**Cloud Build Config:** `cloudbuild.yaml`
```yaml
steps:
  - name: 'node:20'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        scripts/lint-format.sh --apply
        scripts/test.sh
        scripts/security-scan.sh --secrets

  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/app:$SHORT_SHA', '.']

  - name: 'gcr.io/cloud-builders/gcloud'
    args: ['run', 'deploy', 'app', '--image', 'gcr.io/$PROJECT_ID/app:$SHORT_SHA', '--region', 'us-central1']
```

**Auto-Tagging Config:** `cloudbuild-auto-tag.yaml`
> Requires a separate Cloud Build trigger on push to `main` (post-merge).
> See **SemVer Auto-Tagging** section below for details.
{{/if}}

{{#if CI_CD_PLATFORM == "None"}}
**No CI/CD platform configured.** Use local scripts for all pipeline operations:
```bash
# Manual pipeline execution
scripts/lint-format.sh --apply
scripts/test.sh
scripts/security-scan.sh --secrets
scripts/auto-tag.sh --apply
```

**Auto-Tagging:** Run `scripts/auto-tag.sh --apply` manually after merging to main.
> See **SemVer Auto-Tagging** section below for details.
{{/if}}

## SemVer Auto-Tagging

### Automated Version Tagging

Version tagging is **fully automated** via the `scripts/auto-tag.sh` engine script,
triggered by the CI/CD platform on every merge to `main`.

**How it works:**
1. PR is merged to `main` (externally approved)
2. CI/CD platform detects the merge event
3. `scripts/auto-tag.sh --apply --ci` analyzes conventional commits since the last tag
4. Determines version bump type (MAJOR / MINOR / PATCH)
5. Creates annotated git tag and pushes to origin
6. Platform-specific post-tagging actions (release creation, notifications, etc.)

**Bump rules (from conventional commits):**

| Commit Pattern | Version Bump | Example |
|----------------|-------------|---------|
| `BREAKING CHANGE:` or `feat!:` | **MAJOR** (x.0.0) | `feat!: redesign auth API` |
| `feat:` or `feat(scope):` | **MINOR** (0.x.0) | `feat(USR-001): add OAuth login` |
| `fix:`, `docs:`, `refactor:`, `perf:`, `chore:`, `ci:`, `test:` | **PATCH** (0.0.x) | `fix(BUG-042): timeout error` |

**Files:**
- **Script (universal engine):** `scripts/auto-tag.sh` — Platform-agnostic SemVer logic (bash + git)
{{#if CI_CD_PLATFORM == "GitHub Actions"}}
- **Workflow:** `.github/workflows/auto-tag.yml` — Triggers on PR merge to main, creates GitHub Release
{{/if}}
{{#if CI_CD_PLATFORM == "GitLab CI"}}
- **Job:** `auto-tag` stage in `.gitlab-ci.yml` — Triggers on merge to main, creates GitLab Release via API
{{/if}}
{{#if CI_CD_PLATFORM == "Azure DevOps"}}
- **Pipeline:** `azure-pipelines-auto-tag.yml` — Triggers on "Merged PR" commits to main
{{/if}}
{{#if CI_CD_PLATFORM == "Bitbucket Pipelines"}}
- **Step:** Auto-tag step in `bitbucket-pipelines.yml` main branch pipeline
{{/if}}
{{#if CI_CD_PLATFORM == "Jenkins"}}
- **Pipeline:** `Jenkinsfile.auto-tag` — Requires a separate Jenkins job configured to trigger on merge
{{/if}}
{{#if CI_CD_PLATFORM == "AWS CodePipeline"}}
- **BuildSpec:** `buildspec-auto-tag.yml` — Requires a separate CodeBuild project in the pipeline
{{/if}}
{{#if CI_CD_PLATFORM == "GCP Cloud Build"}}
- **Config:** `cloudbuild-auto-tag.yaml` — Requires a separate Cloud Build trigger on push to main
{{/if}}

### Local Script Usage

```bash
# Dry-run: see what tag would be created
./scripts/auto-tag.sh

# Create and push tag manually
./scripts/auto-tag.sh --apply

# Create tag locally without pushing
./scripts/auto-tag.sh --apply --no-push

# CI mode: emit machine-parseable TAG=vX.Y.Z output
./scripts/auto-tag.sh --apply --ci
```

### Workflow Trigger Conditions

The auto-tag automation only runs when:
- Push target is `main` branch
- The commit message indicates a PR merge (`Merge pull request` or contains `(#`)

This prevents accidental tagging on direct pushes (which should be blocked by branch protection).

{{#if CI_CD_PLATFORM == "GitHub Actions"}}
### Platform Notes: GitHub Actions
- Uses `GITHUB_TOKEN` for tag push and release creation
- Release body auto-generated with categorized changelog (Features, Fixes, Other)
- Requires `contents: write` permission on the workflow
{{/if}}

{{#if CI_CD_PLATFORM == "GitLab CI"}}
### Platform Notes: GitLab CI
- Requires `GITLAB_TOKEN` CI/CD variable with `api` scope for release creation
- Uses GitLab Release API (`POST /projects/:id/releases`)
- Git push requires `GIT_PUSH_TOKEN` or deploy key with write access
{{/if}}

{{#if CI_CD_PLATFORM == "Azure DevOps"}}
### Platform Notes: Azure DevOps
- Detects merges via commit message pattern: `Merged PR \d+`
- Uses `$(System.AccessToken)` for git operations (requires `Contribute to tags` permission)
- Tag push requires `persistCredentials: true` on checkout step
{{/if}}

{{#if CI_CD_PLATFORM == "Bitbucket Pipelines"}}
### Platform Notes: Bitbucket Pipelines
- Detect merges by checking commit message pattern (`Merged in` or `Pull request #`)
- Git push uses Bitbucket's built-in SSH key or OAuth credentials
- Uses `atlassian/default-image:3` base image (includes git and bash)
{{/if}}

{{#if CI_CD_PLATFORM == "Jenkins"}}
### Platform Notes: Jenkins
- Requires `sshagent` or `withCredentials` block for git push permissions
- Configure webhook trigger: `Generic Webhook Trigger` plugin filtering on `refs/heads/main`
- Merge detection via `git log -1 --pretty=%s` pattern matching
{{/if}}

{{#if CI_CD_PLATFORM == "AWS CodePipeline"}}
### Platform Notes: AWS CodePipeline
- CodeBuild project needs IAM permissions: `codecommit:GitPush` (CodeCommit) or GitHub token in Secrets Manager
- GitHub token stored in AWS Secrets Manager, fetched via `env.secrets-manager` in buildspec
- Use `git-credential-helper` for HTTPS push or configure SSH key
- Consider using EventBridge rule to trigger the auto-tag CodeBuild project on PR merge events
{{/if}}

{{#if CI_CD_PLATFORM == "GCP Cloud Build"}}
### Platform Notes: GCP Cloud Build
- Cloud Build trigger must be configured for push to `main` branch
- Uses `gcr.io/cloud-builders/git` image for git operations
- Cloud Build service account needs `source.repos.writer` permission (Cloud Source Repos) or GitHub App connection
- GitHub token stored in Secret Manager, accessed via `availableSecrets.secretManager`
- Use `$$` prefix to escape Cloud Build substitution variables vs shell `$` variables
{{/if}}

{{#if CI_CD_PLATFORM == "None"}}
### Platform Notes: No CI/CD
- Run `scripts/auto-tag.sh --apply` manually after merging PRs to main
- Consider setting up a git hook (`post-merge`) as a lightweight automation
{{/if}}

## See Also
- `docs/constitution.md` — `[PLAW-12]` index entry (this file is its body)
- `.claude/rules/branching.md` for commit format and SemVer rules
{{#if CI_CD_PLATFORM == "GitHub Actions"}}
- `.github/workflows/auto-tag.yml` for the workflow implementation
{{/if}}
{{#if CI_CD_PLATFORM == "GitLab CI"}}
- `.gitlab-ci.yml` for the auto-tag job definition
{{/if}}
{{#if CI_CD_PLATFORM == "Azure DevOps"}}
- `azure-pipelines-auto-tag.yml` for the auto-tag pipeline
{{/if}}
{{#if CI_CD_PLATFORM == "Jenkins"}}
- `Jenkinsfile.auto-tag` for the auto-tag pipeline
{{/if}}
{{#if CI_CD_PLATFORM == "AWS CodePipeline"}}
- `buildspec-auto-tag.yml` for the auto-tag buildspec
{{/if}}
{{#if CI_CD_PLATFORM == "GCP Cloud Build"}}
- `cloudbuild-auto-tag.yaml` for the auto-tag config
{{/if}}
- `scripts/auto-tag.sh` for the universal auto-tag engine
- `SECURITY_POLICY.md` for security scan configurations
