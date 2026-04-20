---
description: "Branching strategy — branch naming, merge policy, PR requirements, commit message format, protected branches."
version: 2.0.0
date: 2026-01-26
changelog:
  - "2.0.0: PR validation mode, approval count, merge method configurable via SETUP Q22.1"
  - "1.0.0: Initial template version"
---

# Branching Strategy & Version Control Rules

> **Auto-generated from:** `docs/setup.md` decisions  
> **Strategy Selected:** {{BRANCHING_STRATEGY}}  
> **SemVer Enabled:** {{SEMVER_ENABLED}}  
> **PR Validation Mode:** {{PR_VALIDATION_MODE}}  
> **PR Approvals Required:** {{PR_APPROVAL_COUNT}}  
> **PR Merge Method:** {{PR_MERGE_METHOD}}

## Branch Model: {{BRANCHING_STRATEGY}}

### GitHub Flow (Default)
**Branches:**
- `main`: Protected, always deployable, auto-tagged with semver
- `feature/{FEATURE_ID}-description`: Short-lived (<2 days)
- `hotfix/{ISSUE_ID}-description`: Urgent production fixes

**Workflow:**
1. Create feature branch from latest `main`
2. Develop with frequent commits (conventional format)
3. Open PR when ready, link to `docs/spec/{FEATURE_ID}/`
4. {{PR_APPROVAL_COUNT}} approval(s) {{PR_VALIDATION_LABEL}}
5. {{PR_MERGE_METHOD_LABEL}} to `main` → auto-deploy Dev → auto-tag semver

### Branch Naming Convention
```
{type}/{FEATURE_ID}-{short-description}

types: feature, bugfix, hotfix, docs
Examples:
  feature/USR-001-oauth-login
  bugfix/BUG-042-fix-timeout
  hotfix/CRIT-005-security-patch
```

### Protection Rules
**main branch:**
- ❌ Direct commits forbidden
- ✅ Require PR with {{PR_APPROVAL_COUNT}} approval(s)
{{PR_CI_CHECKS_RULE}}
- ✅ Merge method: {{PR_MERGE_METHOD}}

### PR Validation Policy
- **Mode:** `{{PR_VALIDATION_MODE}}`
  - `manual`: PR required. Human approval only. CI may run but is informational, not blocking.
  - `ci_automated`: PR required. Human approvals + ALL CI checks MUST pass before merge.
  - `hybrid`: PR required. Human approvals required. CI runs but is NOT blocking.
- **Approvals Required:** {{PR_APPROVAL_COUNT}}
- **Merge Method:** {{PR_MERGE_METHOD}} (`merge_commit` | `squash` | `rebase`)

## Semantic Versioning
**Format:** `v{MAJOR}.{MINOR}.{PATCH}`

**Auto-Tagging Logic (CI/CD):**
- `BREAKING CHANGE:` or `feat!:` → MAJOR bump
- `feat:` → MINOR bump
- `fix:`, `docs:`, `refactor:`, `perf:` → PATCH bump

## Commit Message Format
```
{type}({FEATURE_ID}): {description}

{optional body}

Ref: {FEATURE_ID}
BREAKING CHANGE: {description if applicable}
```

**Types:** feat, fix, docs, refactor, test, chore, ci, perf

## CI/CD Integration
**Pre-Merge Checks:**
{{PR_CI_CHECKS_DETAIL}}

**Post-Merge Actions:**
- Auto-tag with semver
- Auto-deploy to Development environment
- Update changelog

## See Also
- `.context/constitution.md` § Branching Strategy
- `.claude/rules/ci-cd.instructions.md` for pipeline details
