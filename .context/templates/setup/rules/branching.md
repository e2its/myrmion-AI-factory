---
description: "Branching strategy — branch naming, merge policy, PR requirements, commit message format, protected branches."
applicable_when:
  always: true
default_base_branch: main
version: 2.7.0
date: 2026-09-25
changelog:
  - "2.7.0: feat(EVOL-047) — post-merge actions and the main-branch line qualified by the runtime surface (gate.py runtime-surface --changed)."
  - "2.6.0: feat(EVOL-045) — frontmatter default_base_branch (read by gate.py diff-base); § Trains and sub-increments."
  - "2.5.1: feat(EVOL-044) — frontmatter `version` realigned to this manifest entry (manifest-parity gate); YAML made parseable where needed."
  - "2.1.0: feat(EVOL-043) — hosts [PLAW-11] body (merged from the constitution template; placeholder-bearing variant kept, hard-coded approval count dropped)"
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

## [PLAW-11] Branching Strategy & Version Control
> Every code change follows the declared branching model: no direct commits to protected branches, merges arrive through reviewed pull requests, versions are tagged by semantic rules.

> **Mandate:** All code changes MUST follow the defined branching model. Direct commits to protected branches are FORBIDDEN.

### Branch Model: {{BRANCHING_STRATEGY}}

#### GitHub Flow (Default)
**Branches:**
- `main`: Protected, always deployable, auto-tagged with semver on merge when the merge touches `surface.runtime_surface` (`gate.py runtime-surface --changed`, EVOL-047)
- `feature/{FEATURE_ID}-description`: Short-lived (<2 days)
- `hotfix/{ISSUE_ID}-description`: Urgent production fixes, fast-track to main

**Workflow (feature branch lifecycle):**
1. Create feature branch from latest `main`
2. Develop with frequent commits (conventional format, see below)
3. Open PR when ready, link to `docs/spec/{FEATURE_ID}/`
4. {{PR_APPROVAL_COUNT}} approval(s) {{PR_VALIDATION_LABEL}}
5. {{PR_MERGE_METHOD_LABEL}} to `main` → auto-deploy Dev → auto-tag semver — both only when the merge touches the runtime surface (`gate.py runtime-surface --changed`); a documentation merge still needs the PR, it just moves no machinery

#### Branch Naming Convention
```
{type}/{FEATURE_ID}-{short-description}

types: feature, bugfix, hotfix, docs
Examples:
  feature/USR-001-oauth-login
  bugfix/BUG-042-fix-timeout
  hotfix/CRIT-005-security-patch
```

#### Per-Increment Branch Naming (when `spec.feature.slicing_strategy: incremental`)

When a feature uses incremental slicing (the default), each **increment** declared in `docs/spec/{FEATURE_ID}/increment_plan.md § 1` opens its own feature branch — one PR per increment:

```
feature/{FEATURE_ID}-inc-{N}-{short-description}

Regex: ^feature/[A-Z][A-Z0-9]*-[0-9A-Z]+(?:-[0-9A-Z]+)*-inc-[0-9]+-[a-z0-9-]+$   (canonical: python3 scripts/gate.py branch-class)
Examples:
  feature/USR-001-inc-1-submit-claim
  feature/USR-001-inc-2-edit-claim
  feature/USR-001-inc-3-policy-check
```

**Concurrency.** Only ONE increment branch per feature may be open at a time (feature-level concurrency lock). The next increment starts only after the current one merges.

**Lifecycle.** Branch open triggers the increment's status to flip `READY → BUILDING` in `increment_plan.md § 1`. Merge to `main` (via PR) triggers the post-merge hook to flip `BUILDING → MERGED` and stamp `Merged at:`. See `.claude/skills/factory-branching-strategy/SKILL.md § Per-Increment Branching`.

**Monolithic escape.** When `slicing_strategy: monolithic` (permitted only if the feature satisfies the trivial-heuristic — ≤2 scenarios AND ≤3 contract operations AND `scope ≠ full-stack`), the legacy single-branch naming `feature/{FEATURE_ID}-{slug}` applies without the `-inc-N-` segment.

**Trains and sub-increments (EVOL-045).** An increment whose `increment_plan.md § 1` entry declares `Sub-increments:` ships as a **train**: its per-increment branch is protected like `main` (no direct commits — hook `check-branch-protection.sh` → `python3 scripts/gate.py branch-class --protected`), receives one PR per sub-increment and closes to the base branch by ONE PR.
Sub-increment branch: `feature/{FEATURE_ID}-inc-{N}-{slug}-sub-{M}` (M ≥ 1), created from the train, PR target = the train. Regex: `^feature/[A-Z][A-Z0-9]*-[0-9A-Z]+(?:-[0-9A-Z]+)*-inc-[0-9]+-[a-z0-9-]+-sub-[0-9]+$`.
Diff base for every gate, review and measurement: `python3 scripts/gate.py diff-base` (sub-increment → its train; else `default_base_branch` from this file's frontmatter).
Surface per PR (`python3 scripts/gate.py surface`, measured at push): over `surface.ceiling_files` / `surface.ceiling_lines` (`config/quality.json`) = red unless the commit trailer `Surface-Escape: <term>` names a term of `surface.escapes` (closed list).

#### Protection Rules
**main branch:**
- ❌ Direct commits forbidden
- ✅ Require PR with {{PR_APPROVAL_COUNT}} approval(s)
{{PR_CI_CHECKS_RULE}}
- ✅ Merge method: {{PR_MERGE_METHOD}} (linear history when `squash` or `rebase`)
- ✅ Require signed commits: GPG verification (recommended)

#### PR Validation Policy
- **Mode:** `{{PR_VALIDATION_MODE}}`
  - `manual`: PR required. Human approval only. CI may run but is informational, not blocking.
  - `ci_automated`: PR required. Human approvals + ALL CI checks MUST pass before merge.
  - `hybrid`: PR required. Human approvals required. CI runs but is NOT blocking.
- **Approvals Required:** {{PR_APPROVAL_COUNT}}
- **Merge Method:** {{PR_MERGE_METHOD}} (`merge_commit` | `squash` | `rebase`)

### Semantic Versioning (SemVer)
**Format:** `v{MAJOR}.{MINOR}.{PATCH}` (e.g., `v1.2.3`)

**Auto-Tagging on Main Merge (CI/CD analyzes commit messages):**
- `BREAKING CHANGE:` in commit body or `!` after type (e.g., `feat!:`) → MAJOR bump
- `feat:` → MINOR bump
- `fix:`, `docs:`, `refactor:`, `perf:` → PATCH bump

### Commit Message Format (Conventional Commits)
```
{type}({FEATURE_ID}): {description}

{optional body with detailed explanation}

Ref: {FEATURE_ID}
BREAKING CHANGE: {description if applicable}
```

**Types:**
- `feat`: New feature (triggers MINOR bump)
- `fix`: Bug fix (triggers PATCH bump)
- `docs`: Documentation changes
- `refactor`: Code restructuring without behavior change
- `test`: Test additions/modifications
- `chore`: Build/CI changes, dependency updates
- `ci`: Pipeline changes
- `perf`: Performance improvements

**Example:**
```
feat(USR-001): add OAuth2 social login

Integrate Google and GitHub OAuth2 providers using passport.js.
Users can now sign in with existing social accounts.

Ref: USR-001
```

### Merge Strategy
- **Method:** {{PR_MERGE_METHOD}} (`merge_commit` | `squash` | `rebase`) — set at SETUP, applied to every PR to `main`.
- **Squash rationale:** clean linear history, easy rollbacks, clear changelog generation; all feature branch commits become a single commit on `main`, the PR title becomes the commit message, body includes the PR description.
- **Exception — hotfix branches:** merge commit (preserve urgency context), immediate PATCH version bump, manual backport to release branches if applicable.

### CI/CD Integration
> **Complete pipeline details:** See `.claude/rules/ci-cd.md`

**Pre-Merge Checks:**
{{PR_CI_CHECKS_DETAIL}}

**Post-Merge Actions** (only when the merge touches `surface.runtime_surface` or a hard exclusion — `gate.py runtime-surface --changed`, EVOL-047; a documentation merge moves no machinery):
- Auto-tag with semver (based on commit analysis)
- Auto-deploy to Development environment
- Update changelog (auto-generated from conventional commits)

### Further Reading
- [GitHub Flow Guide](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

## See Also
- `docs/constitution.md` — `[PLAW-11]` index entry (this file is its body)
- `.claude/rules/ci-cd.md` for pipeline details
