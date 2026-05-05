---
description: "CI/CD pipeline standards — workflow configuration, environment management, deployment gates, artifact handling. Applied when editing CI/CD configuration."
applyTo: "**/.github/workflows/**,**/Dockerfile,**/docker-compose*.yml,**/.gitlab-ci.yml,**/Jenkinsfile"
version: 1.0.0
date: 2026-01-26
changelog:
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
3. **Security Scan:** `scripts/security-scan.sh --semgrep --gitleaks` (blocks on HIGH/CRITICAL)
4. **Build:** Compile artifacts, build Docker image
5. **Integration Tests:** API + DB tests
6. **Deploy Dev:** Auto-deploy to development
7. **Deploy Staging:** Auto-deploy on release/* branches
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
- See `constitution.md` § Tiered Secrets Strategy for full policy

## Environment Deployment

### {{ENVIRONMENT_STRATEGY}}

{{#if ENVIRONMENT_STRATEGY == "Standard"}}
- **Development:** Auto-deploy on merge to `main`
- **Staging:** Auto-deploy on merge to `release/*`
- **Production:** Manual approval after staging validation
{{/if}}

{{#if ENVIRONMENT_STRATEGY == "Minimal"}}
- **Development:** Auto-deploy on merge to `main`
- **Production:** Manual approval + 2-hour observation window
{{/if}}

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
        run: scripts/security-scan.sh --semgrep --gitleaks
  
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
    - scripts/security-scan.sh --semgrep --gitleaks

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
          - script: scripts/security-scan.sh --semgrep --gitleaks
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
            - scripts/security-scan.sh --semgrep --gitleaks

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
      steps { sh 'scripts/security-scan.sh --semgrep --gitleaks' }
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
      - scripts/security-scan.sh --semgrep --gitleaks
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
        scripts/security-scan.sh --semgrep --gitleaks

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
scripts/security-scan.sh --semgrep --gitleaks
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
- `constitution.md` § Deployment & Environment Strategy
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
