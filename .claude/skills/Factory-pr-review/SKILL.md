---
name: Factory-pr-review
description: "Factory PR Review — five-axis review (code, code↔docs, API contracts, ADR, traceability) wired as a PUSH GATE (preflight before `git push`) and an assistive PR reviewer for already-pushed branches. Maps blockers to framework Hard Gates (CIP, CVP, IPP, BVL, GCRP). Use when: a Bash `git push` is about to fire (auto-invoked by hook) OR the user explicitly asks to review a branch / open PR."
---

# Factory PR Review — Push Gate + Assistive Reviewer (v1.1.0)

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
| 13 | **Reference coherence**: rename in diff (skill/rule/instruction/command/path/heading) without lock-step propagation to mention sites — broken markdown links, divergent identifier spellings, anchor pointers to non-existent headings | both | Phase 0 Coherence Audit + `config/coherence-context.json` |
| 14 | **Placeholder leakage**: `{{X}}` token outside `audit.placeholder_allowlist_paths`. Meta allows under `.context/templates/**` only; downstream defaults to no allowlist (any `{{X}}` is a finding) | both | Phase 0 + `config/coherence-context.json` |
| 15 | **Manifest ↔ disk coherence**: `governance_versions.json` entry pointing to a path that does not exist OR file change without manifest entry update in the same diff. Inverse of Block 11 plus the disk-side check | both | Phase 0 + `config/coherence-context.json` + manifest path |
| 16-meta | **Meta ↔ template lock-step**: `.claude/X` changed without mirror at `.context/templates/setup/claude/X` (or vice-versa). Source of truth: `audit.lock_step_pairs` of type `meta_template_mirror` | meta only | Phase 0 + `config/coherence-context.json` |
| 16-downstream | **Code ↔ docs lock-step**: public artefact added/removed/renamed without catalog/index update in CLAUDE.md, docs/, or referenced rule/instruction files. Source of truth: `audit.lock_step_pairs` of type `rename_propagation` and `code_doc_lock_step` | downstream only | Phase 0 + `config/coherence-context.json` |
| 17 | **Commit ↔ diff coherence**: commit message claims a change that the diff does not show, or the diff carries a structural change the commit message omits (e.g. EVOL-N in commit ≠ branch's EVOL-N; new public field shipped under `chore:` prefix) | both | Phase 0 (semantic judgment) |
| 18 | **Bump severity ↔ change kind coherence**: `governance_versions.json` bump kind (PATCH/MINOR/MAJOR) does not match the actual nature of the diff (new feature → MINOR; breaking contract → MAJOR; bug fix only → PATCH). Inverse cross-check of Generation Standards §2 | both | Phase 0 (semantic judgment) |

Block 11 (Governance-bump miss) is the framework-meta equivalent of "missing CHANGELOG entry". It enforces the rule that lives in the root `CLAUDE.md` Generation Standards §2.

Blocks 13-18 are produced by **Phase 0 Coherence Audit** (semantic, agentic). 13-15 are deterministic-leaning but require the agent to interpret rename intent and lock-step pair semantics; 16 is split by context (one variant active per repo); 17-18 require semantic judgment over commit message + manifest bump kind. All six read their context-specific configuration from `config/coherence-context.json` (`audit.*` keys).

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

### Phase 0 — Coherence Audit (agentic, semantic)

Runs BEFORE all other phases when the diff is **governance-sensitive** (touches any path under `audit.root_sets` of `config/coherence-context.json`, minus `audit.exclusions`). For non-sensitive diffs (e.g. pure UI under `src/components/`, build-tooling-only), Phase 0 is skipped — go straight to Phase 1.

The audit is performed by the agent (Claude), NOT by a deterministic script. Reason: rename intent, lock-step semantics, commit↔diff coherence, and bump-severity judgment all require contextual reasoning that regex/grep cannot reliably perform without false negatives. The deterministic phases (1-6) stay deterministic and cheap; Phase 0 is the one phase that pays a model-call cost in exchange for completeness.

**Scope discipline**: Phase 0 reads ONLY (a) files in the diff and (b) files in the **collateral set** built in Step 0.3. It NEVER scans the whole repo. The collateral set is bounded by `audit.root_sets` minus `audit.exclusions`.

#### Step 0.0 — Skip checks
- Detached HEAD or protected branch → skip with note (defence-in-depth, not Phase 0's concern).
- Diff matches the docs-only fast-lane (CLAUDE.md Generation Standards §3) → skip Phase 0; existing fast-lane handles.
- `config/coherence-context.json` missing → emit humanised warning, treat as `downstream` with empty allowlists, continue.

#### Step 0.1 — Load context
Read `config/coherence-context.json`. Parse:
- `context` → `meta` | `downstream`. Selects which Block 16 variant is active and which lock-step pair types apply.
- `audit.root_sets` → directories the audit is allowed to scan when expanding to collateral.
- `audit.exclusions` → globs globally excluded.
- `audit.placeholder_allowlist_paths` → globs where `{{X}}` is permitted (Block 14).
- `audit.lock_step_pairs` → typed declarations driving Block 16 (`meta_template_mirror` for meta; `rename_propagation` + `code_doc_lock_step` for downstream).
- `audit.manifest_paths` → manifest location for Blocks 15/18.

#### Step 0.2 — Extract changed symbols from the diff
Run `git diff --name-status origin/{base}..HEAD` and `git log --format=%B origin/{base}..HEAD`. Extract:
- **Renamed paths** — git rename detection (`R{score}` entries).
- **Deleted paths** — files that disappeared.
- **Moved/renamed identifiers** — section headings changed in `.md` files (`-## OldName` paired with `+## NewName`); `name:` field changes in skill frontmatter; function/class definitions removed/added with similar names.
- **Public artefact names** — Factory-* skill names, rule names (basename of `.claude/rules/*.instructions.md`), instruction names, command names, hook script names.

Each extracted symbol → search term for Step 0.3.

#### Step 0.3 — Build collateral set
For each symbol from 0.2, run `git grep -l <symbol>` constrained to `audit.root_sets` minus `audit.exclusions`. Files that match AND are NOT in the diff = collateral set. Read those files in full. The set is naturally bounded — typical EVOLs touch ≤ 5 symbols and ≤ 30 collateral files.

#### Step 0.4 — Apply detectors 13-18
Run each detector against `diff ∪ collateral`. Routing:

| Detector | Inputs | Verdict cues |
|---|---|---|
| 13 Reference coherence | renames + collateral mentions | mention site uses old name → 🔴 Blocker; mention site uses new name → ✅; ambiguous (legitimate historical mention) → ❓ Question with proof of intentionality |
| 14 Placeholder leakage | diff files + `audit.placeholder_allowlist_paths` | `{{X}}` outside allowlist → 🔴 Blocker; inside allowlist → ✅ |
| 15 Manifest ↔ disk | manifest at `audit.manifest_paths.primary` + diff path list | manifest entry whose target does not exist → 🔴 Blocker; tracked file changed without manifest bump (in same diff) → 🔴 Blocker (Block 11 already covers this for meta — Block 15 is the inverse-direction check) |
| 16-meta | diff paths + `lock_step_pairs[type=meta_template_mirror]` | left changed without right (or vice versa) → 🔴 Blocker; both changed (or neither) → ✅ |
| 16-downstream | diff paths + `lock_step_pairs[type=rename_propagation, code_doc_lock_step]` | rename without propagation to scan_targets → 🔴 Blocker; new artefact without catalog entry → 🔴 Blocker; modified artefact without doc update → 🟡 Important |
| 17 Commit ↔ diff | commit message bodies + diff content | commit claims feature X but diff is refactor only → 🔴 Blocker; EVOL-N in commit ≠ branch's EVOL-N → 🔴 Blocker; diff carries new public field but commit prefix is `chore:` → 🟡 Important |
| 18 Bump severity ↔ change kind | manifest bump entries + diff content | new feature → manifest entry should be MINOR or higher (PATCH on additive feature → 🔴 Blocker); breaking contract change → MAJOR (MINOR on breaking → 🔴 Blocker); pure bug fix → PATCH (over-bump is 🟡 Important, not blocker) |

Each finding cites file/line/snippet/why/fix per the existing severity rubric (`references/severity-rubric.md`).

#### Step 0.5 — Emit marker
After Phase 0 completes (regardless of verdict count), write a marker file:

```
.claude/state/coherence-audit-${session_id}-${branch_sha}.marker
```

- `session_id` = Claude Code session identifier (provided by hook protocol).
- `branch_sha` = `git rev-parse HEAD` at audit time.

Marker body (JSON, single line):
```json
{"session_id":"...","branch_sha":"...","audited_at":"ISO-8601","governance_sensitive":true,"findings":{"blocker":N,"important":N,"nit":N,"question":N}}
```

The marker proves Phase 0 ran for this exact `(session, branch sha)` tuple. New commit (sha changes) or new session → marker invalidated → audit must re-run.

#### Step 0.6 — Verdict
- Any 🔴 Blocker → STOP. Surface findings to user with humanised resolution path. Do NOT write marker (or write marker with `"blocker": >0` and let preflight.sh refuse to proceed).
- 0 🔴, any 🟡/🟢/❓ → write marker with finding counts; advise user on the non-blocker findings; proceed to Phase 1.
- 0 findings → write marker; proceed to Phase 1 silently.

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

> **Scope note.** This skill is the **push gate**. It is NOT the inline 🔍 REVIEW hat that runs during `IMPLEMENT --build` (DEV ↔ REVIEW ↔ SEC). Those are governed by `.claude/rules/review-policy.md` and live inside the BVL cycle. The push gate is a downstream, independent concern: it runs at `git push` time on the cumulative branch diff, regardless of what happened during IMPLEMENT.

### Hierarchy (highest to lowest, on conflict)

1. **`docs/constitution.md`** — project constitution. The Hard-Gate categories (CIP, CVP, IPP, BVL, GCRP) are constitutional and cannot be disabled.
2. **ADRs** — `docs/project_log/adr/*.md` (project-wide) + `docs/spec/{ID}/adr/*.md` (feature-scoped). ADRs may refine, exempt, or extend the rule defaults below; they CANNOT relax constitutional gates.
3. **`.claude/rules/*.instructions.md`** — materialised at SETUP, evolved via ADR-backed updates only. These are the operational source of truth for each block category.
4. **Skill defaults** — last-resort fallback when none of the above is present (e.g. fresh project before SETUP --generate completes).

If a project rule disagrees with a skill default, the project rule wins. If an ADR documents a deviation from a project rule, the ADR wins. The skill NEVER imposes its own pattern over a project decision.

### Project rule files consumed by the push gate

Honest, narrow surface — only files the preflight script actually reads (or that drive a hard block deterministically). Everything else lives in the **NOT consumed** section below to prevent scope creep.

| Block / category | Authoritative file | What the push gate reads |
|---|---|---|
| Branch protection (Block 10), base branch | `.claude/rules/branching.instructions.md` | `default_base_branch` field (`origin/{x}`); branch-name regex (when present) for Block 10 validation. |
| Protected paths (Block 12) | `config/protected-paths.json` | Glob list — every changed path is matched against it; any match → 🔴 Blocker. |
| Protected code markers | `.claude/rules/protected-code.md` | The `PROTECTED-CODE START/END` marker convention. Push gate scans diff hunks; modifications inside a marker region → 🔴 Blocker. |
| ADR-driven exemptions | `docs/project_log/adr/*.md` (project-wide) + `docs/spec/{ID}/adr/*.md` (feature-scoped) | `pr_review_overrides:` frontmatter (see § ADR-driven exemptions below). |
| Governance manifest (meta only) | `.context/templates/setup/governance_versions.json` | Existence + diff-touched-without-update check (Block 11, framework meta only). |

That's it. Anything not in this list is NOT consumed. If the push gate were to start consuming a new rule file, that change ships in a new EVOL with explicit manifest entries.

### NOT consumed (different reviewer, different lifecycle)

Same disambiguation pattern as `review-policy.md`:

- `.claude/rules/review-policy.md` — BVL/IMPLEMENT 🔍 REVIEW hat policy (DEV ↔ REVIEW retry loop, escalation, override, environment-driven strictness). Different reviewer, different lifecycle.
- `.claude/rules/security_policy.md` — high-level project security policy (allowed crypto, PII handling, OWASP stance, threat model). Consumed by 🛡️ SEC hat in IMPLEMENT --build (SAST + dependency audit), QA --verify (DAST), and AUDIT (compliance dimension). The push gate's secret-pattern regexes are NOT here — they live in `scripts/detect_change_type.py` and may be extended only via skill changes (manifest-tracked), not via project rules.
- `.claude/rules/testing.md` — testing policy (coverage thresholds, framework choice, AAA pattern). Consumed by BVL during DEV ↔ REVIEW (coverage gate), IMPLEMENT --build (TDD enforcement), QA --verify (test-plan execution). The push gate's "tests-deleted-without-justification" check (Block 5) reads the diff alone, not the policy file.
- `.claude/rules/architecture.md` — layer dependency rules, module boundaries. Consumed by BLUEPRINT (design.md §7.8 Mandatory Patterns), BVL REVIEW hat (Check #1), AUDIT. The push gate does NOT enforce architecture; that is a deeper, design-time concern.
- `.claude/rules/contract-first-policy.md` + `.claude/rules/api-standards.md` — contract authoring + versioning policy. Consumed by BLUEPRINT (CONTRACT-FREEZE gate), `Factory-coherence-validation/SKILL.md` (CVP Check 14/15). The push gate's API contract checks (Blocks 1, 2) operate on the **spec files themselves** via oasdiff/asyncapi-cli; the policy text governs how specs are written, not how the push gate reads them.
- `.claude/rules/defect-prevention.md` — DC catalog. Consumed by every SDLC agent listed in each entry's `applicable_to:` field (see CLAUDE.md § Living Governance Catalogs). The push gate is NOT in the consumer list — defect prevention is a design-and-build-time concern, not a push-time one.
- `config/codebase_inventory.json` — component registry. Consumed by `Factory-codebase-inventory/SKILL.md` (CIP Canary at IMPLEMENT --build), AUDIT (DRY dimension). Block 7 in this skill (CIP) is a **policy reminder**, not a deterministic check — the push gate does NOT scan the inventory; it relies on the upstream CIP Canary having run during IMPLEMENT --build. If you push code that bypassed CIP Canary (e.g. edited outside Claude), the push gate will not catch it; QA --verify is the next gate.

The pattern: each rule file has ONE primary consumer. Multiple agents may read different slices, but ONE skill or SDLC phase owns the binding-decision authority. The push gate is deliberately narrow — it covers the things that are cheap and deterministic at push time, and defers everything else to its proper owner.

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
