---
name: Factory-pr-review
description: "Factory PR Review — five-axis review (code, code↔docs, API contracts, ADR, traceability) wired as a PUSH GATE (preflight before `git push`) and an assistive PR reviewer for already-pushed branches. Maps blockers to framework Hard Gates (CIP, CVP, IPP, BVL, GCRP). Use when: a Bash `git push` is about to fire (auto-invoked by hook) OR the user explicitly asks to review a branch / open PR."
---

# Factory PR Review — Push Gate + Assistive Reviewer (v1.0.0)

> **Shared Protocol** — Referenced by: ALL agents that ship code (IMPLEMENT, QA, DEVOPS, CODESIGN/BLUEPRINT for spec-bearing PRs) + the `check-push-preflight.sh` hook.
> Position in the SDLC: runs **immediately before `git push`** as a local quality gate. Does NOT replace human review on the PR — it complements it by catching blockers before they hit the PR.

## Why a push gate, not a merge gate

A merge gate (CI on PR) is too late: the work is already on the remote, the author has context-switched, and reviewers waste a round trip on findings the author could have caught locally. The push gate runs against `origin/{base}..HEAD`, exits non-zero on hard-blockers, and produces the same finding catalog the post-push review would. The assistive `--review {PR}` mode is kept for already-open PRs (ad-hoc review, second opinion, pre-merge final pass).

Hard-blocker exit semantics:
- exit 0 → no blockers, push proceeds
- exit 1 → blockers found, push blocked with humanised findings
- exit 2 → tooling failure (missing dep, repo state error) — NOT a blocker, push proceeds with warning

## When this skill activates

| Trigger | Mode | Entry point |
|---|---|---|
| `Bash` tool with command containing `git push` (and current branch is non-protected, non-empty diff vs base) | `--preflight` | `.claude/hooks/check-push-preflight.sh` (auto) |
| User: "review PR #N" / GitHub PR URL / "review this branch before push" | `--review` (or `--preflight` for unpushed branch) | manual skill invocation |
| User explicitly invokes `/pr-review` slash command (when materialised) | per-flag | manual |

The push hook is the **default integration**. Manual invocation is for the assistive cases.

## Operation modes

### Mode 1 — `--preflight` (push gate, default)

Runs locally against the current branch's diff vs its base. NEVER touches the remote. NEVER posts to a PR.

```bash
.claude/skills/Factory-pr-review/scripts/preflight.sh [--base origin/main] [--json]
```

Steps (executed by `preflight.sh`):
1. Resolve base (`origin/main` by default, or read from `.claude/rules/branching.instructions.md` `default_base_branch`).
2. Compute `git diff --name-only origin/{base}..HEAD`.
3. **Docs-only fast-lane** — if every changed path matches `**/*.md`, `docs/**`, `.context/templates/**`, `.gitignore` (and none under `.github/workflows/**`), exit 0 with `fast-lane: docs-only` note. Skip remaining checks.
4. Run `detect_change_type.py` → flags JSON.
5. Run `check_docs_sync.py --git-range origin/{base}..HEAD --json` → docs findings.
6. If `has_openapi: true`, run `check_openapi_diff.sh origin/{base} <spec-path>`.
7. If `has_asyncapi: true`, run `check_asyncapi_diff.sh origin/{base} <spec-path>`.
8. **Framework-aware checks** (run unconditionally — see § Framework-aware Hard Blocks below).
9. Aggregate findings; print summary; exit 1 if any blocker, 0 otherwise.

### Mode 2 — `--review {PR-URL or branch}`

Full audit against an open PR (or local branch). Produces the structured review (`assets/review_template.md`) and OPTIONALLY posts via `post_review.py` (only with explicit user confirmation — see Phase 6).

## Framework-aware Hard Blocks

These extend the generic hard blocks (`SKILL.md` Phase 4 in the upstream skill) with framework-specific gates. ALL apply universally; some are scoped to materialised projects vs the framework meta repo.

| # | Block | Scope | Source of truth |
|---|---|---|---|
| 1 | Public endpoint modified without spec change | both | `references/api-contract-rules.md` |
| 2 | Breaking change without major bump or migration note | both | `references/api-contract-rules.md` |
| 3 | Secrets in diff (regex patterns) | both | `scripts/detect_change_type.py` |
| 4 | High-severity security vulnerability (SQLi, RCE, auth bypass, persistent XSS) | both | `references/code-review-criteria.md` § 4 |
| 5 | Tests deleted without justification in PR description | both | `references/code-review-criteria.md` § 1 |
| 6 | Irreversible DB migrations without rollback script | downstream | `references/code-review-criteria.md` § SQL |
| 7 | **CIP violation**: new code artifact without `config/codebase_inventory.json` consultation | downstream | `Factory-codebase-inventory/SKILL.md` |
| 8 | **CVP violation**: spec-bearing change with broken upstream traceability (spec.feature ↔ user_journey ↔ design ↔ test_plan ↔ dev_plan ↔ increment_plan) | downstream | `Factory-coherence-validation/SKILL.md` |
| 9 | **IPP violation**: governance artifact written fully-formed on first write | both | `Factory-incremental-persistence/SKILL.md` (covered by `check-ipp-compliance.sh` PreToolUse — push gate re-asserts as defence in depth) |
| 10 | **Branch-protection drift**: branch name does not match an allowed working pattern (`feature/EVOL-*`, `feature/{ID}-*`, `fix/*`, `bugfix/*`, `hotfix/*`, `docs/*`, `chore/*`) | both | `Factory-branching-strategy/SKILL.md` |
| 11 | **Governance-bump miss** (framework meta only): change touches a file tracked in `.context/templates/setup/governance_versions.json` but the manifest does NOT change in the same diff | meta only | CLAUDE.md § Generation Standards #2 |
| 12 | **Protected-code modified**: diff touches a path listed in `config/protected-paths.json` OR a region between `PROTECTED-CODE START/END` markers | downstream | constitution.md + `config/protected-paths.json` |

Block 11 (Governance-bump miss) is the framework-meta equivalent of "missing CHANGELOG entry". It enforces the rule that lives in the root `CLAUDE.md` Generation Standards §2.

## Framework artefact ↔ docs sync matrix

Extends `references/docs-sync-checklist.md` with the framework's own artefacts. Only applies to materialised projects (the meta repo has no `docs/spec/` tree).

| Code change | Artefact that must update | Severity if missing |
|---|---|---|
| New / modified Gherkin scenario in `docs/spec/{ID}/` | `user_journey.md` + `test_plan.md` (CVP Check 1, 2) | **Blocker** |
| New / modified design contract operation | `design.md` § Contracts + OpenAPI/AsyncAPI under `contracts/` | **Blocker** |
| New / modified test_plan case | `dev_plan.md` task tags reference the case | Important |
| `slicing_strategy: incremental` feature ships without `increment_plan.md` APPROVED | (CVP Check 0c) | **Blocker** |
| Code change inside an `INC-N` MERGED scope (immutability) | (Per-Increment Immutability) | **Blocker** |
| New `INC-N` without `depends_on` graph entry | `increment_plan.md` § 2 DAG | Important |
| `feature.scope` ≠ scope of touched paths (full-stack vs frontend-only vs backend-only) | (Scope Compatibility Gate) | **Blocker** |

## Workflow (`--preflight`)

### Phase 1 — Branch + base resolution
```bash
current=$(git branch --show-current)
base=${BASE:-origin/main}  # or read from .claude/rules/branching.instructions.md
git fetch origin "${base#origin/}" --quiet
git diff --name-only "$base"..HEAD
```

If `current` is empty (detached HEAD) OR equals a protected branch name (`main`, `master`, `develop`, bare `hotfix`, `release/*`) → exit 2 with "preflight skipped: not on a working branch".

### Phase 2 — Change classification
Run `scripts/detect_change_type.py --git-range "$base"..HEAD --check-secrets`. The flags drive which references the agent loads when surfacing findings.

### Phase 3 — Per-axis analysis
Apply this routing table (load reference + run script):

| Active flag | Load reference | Run script |
|---|---|---|
| `has_code` | `references/code-review-criteria.md` | — |
| `has_openapi` | `references/api-contract-rules.md` | `scripts/check_openapi_diff.sh` |
| `has_asyncapi` | `references/api-contract-rules.md` | `scripts/check_asyncapi_diff.sh` |
| any code or public-facing | `references/docs-sync-checklist.md` | `scripts/check_docs_sync.py` |
| `is_breaking_candidate` or `has_dependencies` | `references/adr-policy.md` | — |
| always | `references/changelog-policy.md` | — |
| always | `references/severity-rubric.md` | — |
| framework meta repo | governance-bump check (Block 11) | grep `governance_versions.json` in diff |

### Phase 4 — Hard-block enforcement
The 12 hard blocks in § Framework-aware Hard Blocks. Each one is a deterministic pass/fail. The agent does NOT downgrade these — they are blocks by definition of the rubric.

### Phase 5 — Review generation
Use `assets/review_template.md` for the JSON structure. In `--preflight` mode the review is printed locally; in `--review` mode it is rendered to Markdown via `post_review.py`.

Required structure (severity buckets):
1. Summary (2-3 sentences) — what the change does + verdict.
2. 🔴 Blockers — push-blocking. File/line/snippet/why/fix per item.
3. 🟡 Important — should be fixed; doesn't block push.
4. 🟢 Nits — author decides.
5. ❓ Questions — legitimate doubts.
6. 👏 Praise — what's well done.
7. 📋 Documentation checklist (from `references/docs-sync-checklist.md`).

### Phase 6 — Publication (`--review` mode only)
Use `scripts/post_review.py` to publish on the platform. **NEVER** without explicit user confirmation — an incorrect review on GitHub is publicly visible. The push-gate (`--preflight`) NEVER publishes.

## Review principles

- **Severity over volume**: 3 real blockers > 30 nits.
- **Approve if it improves codebase health**, even if not perfect.
- **Ask before stating** when unsure: "Is it intentional that…?" beats "This is wrong".
- **Cite evidence**: line number, code snippet, command to reproduce. "I think there's a problem in X" doesn't cut it.
- **Be specific with proposals**: "consider using X" beats "this could be improved".
- **Don't duplicate what a linter catches**. If ESLint/Ruff/golangci-lint will flag it, it's not human review work.
- **Don't comment style if a formatter exists** (Prettier, Black, gofmt). The formatter wins.

## Iron law: don't claim without verifying

Before flagging a finding as a verified blocker, the skill MUST be able to show:
- The exact file and line.
- The actual code snippet (not paraphrased).
- An explanation of **why** it's a problem in THIS codebase (not generic).
- A concrete fix proposal.

If you can't verify one of these four points, downgrade to "Question".

## Integration with other Factory protocols

| Protocol | Interaction |
|---|---|
| `Factory-branching-strategy` | Push gate is downstream of the Pre-Action Gate. Does NOT re-validate branch creation; assumes the branch exists and is non-protected. Reads `default_base_branch` from `.claude/rules/branching.instructions.md`. |
| `Factory-codebase-inventory` (CIP) | Block 7 maps directly to CIP Canary; preflight checks for new code artefacts that are not registered in `config/codebase_inventory.json`. |
| `Factory-coherence-validation` (CVP) | Block 8 invokes a subset of CVP checks (0a/0c/1/2/13-17) when `docs/spec/{ID}/**` is touched. Full CVP runs at BLUEPRINT --approve / IMPLEMENT --plan / QA --verify; preflight runs the cheap subset locally. |
| `Factory-incremental-persistence` (IPP) | Block 9 is already enforced by `check-ipp-compliance.sh` at PreToolUse Write. Preflight re-asserts as defence in depth (in case the file was created outside Claude). |
| `Factory-build-verification` (BVL) | Preflight does NOT re-run BVL (tests already passed at `IMPLEMENT --build`). It checks that test files are not deleted and that new logic has accompanying tests (heuristic). |
| `Factory-governance-loading` (GCRP) | Block 11 (governance-bump miss, meta only) enforces the same rule as GCRP § Governance Write Protocol (GWP). Preflight computes the diff against `governance_versions.json` and blocks if a tracked file changed without a manifest update. |
| `Factory-commit-prompt` | Preflight runs AFTER commit (push time), so commit messages are immutable at this point. Validates Conventional Commits format on the new commits in `origin/{base}..HEAD`. |

## Per-context behaviour

### Framework meta repo (this repo)
- Block 11 (governance-bump miss) is **active**.
- Blocks 7-8-12 are **inactive** (no `docs/spec/`, no `codebase_inventory.json`, no `protected-paths.json` in the meta — the framework IS the protected code, governed by Block 11 instead).
- Docs-only fast-lane allowlist matches CLAUDE.md Generation Standards §3 verbatim.

### Materialised projects (downstream)
- All 12 blocks active.
- Docs-only fast-lane only when the project's own `CLAUDE.md` declares it (defaults to OFF).
- `config/protected-paths.json` consulted for Block 12.
- `docs/spec/{ID}/` artefacts drive Block 8 (CVP subset).

## Hook wiring (push gate)

`.claude/settings.json` (and template counterpart) registers a PreToolUse hook on `Bash`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/check-push-preflight.sh"
          }
        ]
      }
    ]
  }
}
```

The hook script reads stdin JSON, extracts `tool_input.command`, matches `/(^|\s|;|&&|\|\|)git\s+push(\s|$)/`, and on match runs `scripts/preflight.sh`. Non-`git push` commands pass through unchanged. Hard-blockers cause the hook to exit 1 with a humanised message; the agent sees the block and reports it to the user instead of the raw script output.

## Project rules and ADR precedence — MANDATORY

The skill is framework code; it ships identical to every project. **Project-specific behaviour comes from project rules and ADRs**, NOT from skill defaults.

### Hierarchy (highest to lowest, on conflict)

1. **`docs/constitution.md`** — project constitution. The Hard-Gate categories (CIP, CVP, IPP, BVL, GCRP) are constitutional and cannot be disabled.
2. **ADRs** — `docs/project_log/adr/*.md` (project-wide) + `docs/spec/{ID}/adr/*.md` (feature-scoped). ADRs may refine, exempt, or extend the rule defaults below; they CANNOT relax constitutional gates.
3. **`.claude/rules/*.instructions.md`** — materialised at SETUP, evolved via ADR-backed updates only. These are the operational source of truth for each block category.
4. **Skill defaults** — last-resort fallback when none of the above is present (e.g. fresh project before SETUP --generate completes).

If a project rule disagrees with a skill default, the project rule wins. If an ADR documents a deviation from a project rule, the ADR wins. The skill NEVER imposes its own pattern over a project decision.

### Project rule files consumed

| Block / category | Authoritative rule file | What the skill reads |
|---|---|---|
| Branch protection (Block 10), base branch | `.claude/rules/branching.instructions.md` | Branch patterns regex, default base branch, merge policy |
| Review strictness levels, exclusion globs, retry policy, override mechanism | `.claude/rules/review-policy.md` | `review_levels_by_environment`, `review_exclusions[]`, `override` config |
| Secrets patterns, security gates (Block 3, 4) | `.claude/rules/security_policy.md` | Project-specific secret regexes (extend skill defaults) |
| Test policy (Block 5) | `.claude/rules/testing.md` | "1 Logic = 1 Unit Test", coverage thresholds, deletion rules |
| Protected code (Block 12) | `.claude/rules/protected-code.md` + `config/protected-paths.json` | Protected globs, PROTECTED-CODE markers |
| DRY / CIP (Block 7) | `config/codebase_inventory.json` | Component registry for reuse check |
| API contract policy (Block 1, 2) | `.claude/rules/contract-first-policy.md` + `.claude/rules/api-standards.md` | Spec location overrides (e.g. `contracts/openapi/v3/main.yaml` instead of repo-root `openapi.yaml`), versioning policy |
| Architecture compliance | `.claude/rules/architecture.md` | Layer dependency rules, module boundaries |
| Defect prevention (DC catalog) | `.claude/rules/defect-prevention.md` | Project-specific runtime defect classes |

### ADR-driven exemptions

ADRs may declare frontmatter exemptions consumed by the push gate:

```yaml
---
status: accepted
date: 2026-04-28
decision-makers: [ARCH]
pr_review_overrides:
  block_1_public_endpoint_without_spec: scoped
  block_1_spec_paths: ["contracts/openapi/v3/*.yaml"]
  block_8_cvp_subset: ["0a", "0c", "1", "2", "13", "14", "15"]   # disable check 16 for this project
---
```

The skill reads `pr_review_overrides:` from every ADR under `docs/project_log/adr/` (project-wide) and `docs/spec/{ID}/adr/` (feature-scoped, when the diff is feature-bounded). Project-wide ADRs override skill defaults; feature-scoped ADRs override project-wide rules within the feature scope only. Anything not declared in an override stays at the rule-file default.

A project that wants to disable a check entirely declares it in an ADR (which is itself reviewed and ratified). There is no per-developer escape hatch — bypassing the gate without an ADR is a governance-scope violation.

### Strictness levels

`review-policy.md` declares `review_levels_by_environment` (STRICT / STANDARD / RELAXED). The push gate maps levels to behaviour:

| Level | Block scope | Important findings | Nits |
|---|---|---|---|
| STRICT | All 12 blocks active | Surfaced + counted | Surfaced |
| STANDARD | All blocks active except aesthetic | Surfaced + counted | Suppressed |
| RELAXED | Only blocks 3 (secrets), 4 (high-sev security), 12 (protected) active | Suppressed | Suppressed |

The level for the current branch is derived from the branch's target environment (read from `.claude/rules/ci-cd.instructions.md` or branch naming convention). Default: STANDARD.

## Customisation (deprecated path)

A project can also create `references/local-policy.md` in its copy of the skill, but this is **deprecated** in favour of the rule + ADR mechanism above. The rule + ADR path is governance-tracked (manifest-bumped, ADR-ratified) whereas a `local-policy.md` is an opaque skill-local override. Use it only for one-off experiments; promote to a rule + ADR before merging to main.

## Skill structure

```
Factory-pr-review/
├── SKILL.md                          ← this file (orchestrator + push-gate spec)
├── README.md                         ← installation + framework integration
├── references/
│   ├── severity-rubric.md            ← blocker/important/nit + Hard-Gate mapping
│   ├── code-review-criteria.md       ← per-axis criteria + DRY/CIP linkage
│   ├── docs-sync-checklist.md        ← code↔docs + framework artefact matrix
│   ├── api-contract-rules.md         ← OpenAPI/AsyncAPI + breaking changes
│   ├── adr-policy.md                 ← ADR location: docs/project_log/adr/
│   └── changelog-policy.md           ← CHANGELOG + governance_versions.json (meta)
├── scripts/
│   ├── preflight.sh                  ← orchestrator (push gate entry point)
│   ├── detect_change_type.py         ← classifies the diff
│   ├── check_openapi_diff.sh         ← oasdiff wrapper
│   ├── check_asyncapi_diff.sh        ← asyncapi diff wrapper
│   ├── check_docs_sync.py            ← drift detection (code ↔ docs)
│   └── post_review.py                ← publishes review on platform (manual only)
└── assets/
    └── review_template.md            ← JSON + Markdown final review template
```
