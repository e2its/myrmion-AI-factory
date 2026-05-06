---
description: "Infrastructure as Code standards — Terraform/CloudFormation patterns, state management, module structure. Applied when editing IaC files."
applicable_when:
  path_glob:
    - "**/terraform/**"
    - "**/*.tf"
    - "**/cloudformation/**"
    - "**/pulumi/**"
    - "**/k8s/**"
    - "**/*.yaml"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Infrastructure as Code (IaC) Governance

> **Auto-generated from** `docs/setup.md` decisions  
> **Scope:** All IaC artifacts in `infra/`  
> **Tool:** {{IAC_TOOL}} ({{IAC_LANGUAGE}})

## IaC Tool Descriptor (Source of Truth)

The IaC tool descriptor is defined in `docs/constitution.md` section `infrastructure.iac_descriptor`.
All DEVOPS agent operations MUST use the descriptor to determine commands, paths and patterns — never hardcoded IF/ELIF chains.

```yaml
iac_descriptor:
  tool: "{{IAC_TOOL}}"
  language: "{{IAC_LANGUAGE}}"
  entry_point: "{{IAC_ENTRY_POINT}}"           # e.g., main.tf, Pulumi.yaml, cdk.json, docker-compose.yml
  provider_config: "{{IAC_PROVIDER_CONFIG}}"    # e.g., provider "aws" block, Pulumi.yaml provider, cdk.context.json
  state_management: "{{IAC_STATE_MGMT}}"        # e.g., backend "s3", Pulumi SaaS, cdk bootstrap, local volume
  env_config_pattern: "{{IAC_ENV_PATTERN}}"     # e.g., *.tfvars, Pulumi.{env}.yaml, docker-compose.{env}.yml
  module_dir: "{{IAC_MODULE_DIR}}"              # e.g., modules/, src/constructs/, N/A
  commands:
    validate: "{{IAC_CMD_VALIDATE}}"            # e.g., terraform validate, pulumi preview, cdk synth
    plan: "{{IAC_CMD_PLAN}}"                    # e.g., terraform plan, pulumi preview, cdk diff
    apply: "{{IAC_CMD_APPLY}}"                  # e.g., terraform apply, pulumi up, cdk deploy
    destroy: "{{IAC_CMD_DESTROY}}"              # e.g., terraform destroy, pulumi destroy, cdk destroy
    format: "{{IAC_CMD_FORMAT}}"                # e.g., terraform fmt, N/A, N/A
```

## Directory Structure

```
infra/
├── modules/              # Shared/system-level IaC modules (promoted from features)
│   ├── networking/
│   ├── database/
│   └── compute/
├── features/             # Feature-exclusive IaC (scope: single feature)
│   └── {FEATURE_ID}/
│       ├── {{IAC_ENTRY_POINT}}
│       ├── environments/
│       │   └── {{IAC_ENV_PATTERN}}
│       └── {{IAC_MODULE_DIR}}  (if applicable)
└── environments/         # Environment-level orchestration (optional)
    └── {env}/
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Module directories | `kebab-case` | `user-auth`, `payment-gateway` |
| Resource names | `{project}-{env}-{resource}-{purpose}` | `myapp-prod-rds-users` |
| Variable names | Tool convention (`snake_case` for HCL, `camelCase` for TS) | `db_instance_type`, `dbInstanceType` |
| Environment files | Per `env_config_pattern` from descriptor | `prod.tfvars`, `Pulumi.prod.yaml` |
| Tag: `managed_by` | Always present, value = `{{IAC_TOOL}}` | `managed_by: terraform` |
| Tag: `feature_id` | Always present for feature-exclusive resources | `feature_id: USR-001` |
| Tag: `scope` | `system` or `feature` | `scope: system` |

## Module Governance

- **Reusability:** Modules in `infra/modules/` MUST be parameterized (no hardcoded values)
- **Versioning:** Modules SHOULD be versioned if referenced by multiple features
- **Documentation:** Each module MUST have a README.md with inputs, outputs and usage example
- **Promotion:** Feature-exclusive IaC is promoted to `infra/modules/` when a second consumer is detected (see Infrastructure Registry)

## State Management

- State MUST be remote for non-local environments (per `state_management` in descriptor)
- State locking MUST be enabled to prevent concurrent modifications
- State files MUST NEVER be committed to version control
- Each environment MUST have isolated state (no shared state across envs)
- State encryption at rest is MANDATORY for production

## Security Policy

- **ZERO secrets in IaC files:** Scanning enforced by `scripts/validate-iac.sh` and Guardrail 3
- **Forbidden patterns:** `password=`, `api_key=`, `secret=`, `AWS_ACCESS_KEY_ID=`, private keys
- Secrets MUST be referenced via the `secrets_manager` defined per environment in constitution.md
- IAM / RBAC policies MUST follow least-privilege principle
- Network policies MUST restrict ingress to known CIDRs (no `0.0.0.0/0` in production)
- TLS/HTTPS MUST be enforced for all non-local environments

## Tagging Policy

All provisioned resources MUST include these tags:

| Tag | Required | Source |
|-----|----------|--------|
| `project` | Yes | `docs/constitution.md` project name |
| `environment` | Yes | Target environment name |
| `managed_by` | Yes | IaC tool name from descriptor |
| `feature_id` | Yes (if feature-scoped) | Feature ID from branch |
| `scope` | Yes | `system` or `feature` |
| `cost_center` | If budget tracking enabled | From `ci-cd.instructions.md` |
| `created_at` | Recommended | ISO 8601 timestamp |

## Testing & Validation

- `validate` command (from descriptor) MUST pass before any `plan` or `apply`
- `format` command (from descriptor) SHOULD be enforced in CI if available
- `plan` command MUST be executed with user confirmation before `apply`
- Dry-run is MANDATORY before any destructive operation
- `scripts/validate-iac.sh` MUST pass in CI pipeline (secrets scan + naming + tagging)

## Data Protection in IaC

- Resources flagged as `data_bearing: true` in Infrastructure Registry require:
  - Backup configuration (retention per `database.instructions.md` Backup & DR policy)
  - Encryption at rest enabled
  - Deletion protection enabled in production
  - Snapshot before any destructive operation (`--teardown`, `--rollback`)
- `DROP`, `DESTROY` or equivalent operations on data-bearing resources require explicit user confirmation + ADR

## Cost Governance

- Estimated costs MUST be documented in `devops_plan.md` per environment
- Cost alerts at thresholds defined in `.claude/rules/ci-cd.md`
- Ephemeral environments auto-destroyed after `auto_destroy_hours`
- Persistent non-prod environments auto-suspended after `auto_sleep_minutes`
- Production environments exempt from auto-suspension

## Further Reading
