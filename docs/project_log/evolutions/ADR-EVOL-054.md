---
id: ADR-EVOL-054
title: Server-side branch protection per SCM platform — the branch rule defended where the hooks cannot reach
date: 2026-09-25
status: accepted
---

# ADR-EVOL-054: Server-side branch protection per SCM platform

## Context

Issue #79, the follow-up of #50 (EVOL-047, EVOL-051, EVOL-053). The framework states the branch rule in prose (`rules/branching.md`, `factory-branching-strategy`, both `CLAUDE.md` § Pre-Action Gate) and defends it **locally**: the PreToolUse hook blocks writes on a protected branch, `pre-commit` classifies the branch, `pre-push` runs the gate profile. Nothing defends it **on the server**. A clone without hooks, a `git push --no-verify`, an edit in the provider's web UI or a second machine writes to the default branch with no pull request and no CI. ADR-EVOL-051 and ADR-EVOL-053 declare it: "a push that bypasses the hook bypasses the loop" — the seal, the digests and the traceability gate are only as strong as the push that honours them. Found while closing #50: this repository's own GitHub ruleset forbade only force-push and deletion; "pull request required" had been left off for a docs fast-lane to `main` that EVOL-047 retired (it is on now: PR + the two governance checks). SETUP asks the CI platform (Q21) and never the SCM host — Bitbucket is not even an option although its CI templates exist — and materialises no protection.

## Decision

- **The SCM platform is a SETUP answer.** Q21.2 names the SCM host — `GitHub` | `GitLab` | `Bitbucket` | `Azure DevOps` | `Other` — apart from the CI platform (Q21 gains `Bitbucket Pipelines` and `Azure Pipelines`, whose templates exist). Persisted in `docs/setup.md` (`scm:`) and `config/quality.json → scm` (`platform`, `protected_branches` — the default branch by default —, `required_checks` — the governance check and, where it runs, the lock-step check —, `approvals` — a project decision, `0` for a single author, never invented). Placeholders `{{SCM_PLATFORM}}`, `{{SCM_REQUIRED_CHECKS}}`, `{{SCM_APPROVALS}}` resolved at `--generate`.
- **One runbook per platform, materialised.** `docs/scm/protection.md` lands from the template of the chosen platform (`.context/templates/setup/scm/protection.<platform>.md`, stack-conditional on `scm.platform`): the exact settings for the protected branch — pull request required, the required status checks, no force-push, no deletion, approvals as configured — in the platform's own vocabulary (GitHub rulesets; GitLab protected branches + merge request approvals + "pipelines must succeed"; Bitbucket branch permissions + merge checks; Azure DevOps branch policies + permissions) and a checklist a person can tick. `Other` gets the generic checklist.
- **Verified where there is an API, checklisted where there is not.** `python3 scripts/gate.py scm-protection` is the one reader: it reads `scm.platform` and the repository identity from `origin`, and — with a token in the environment (`GITHUB_TOKEN` / `GH_TOKEN`, `GITLAB_TOKEN`, `BITBUCKET_TOKEN`, `AZURE_DEVOPS_TOKEN`) — asks the platform's API for the protection of each protected branch, normalises it (pull request required, required checks, force-push blocked, deletion blocked, approvals) and judges it against the config: a missing setting is RED with the runbook path as the cure. Without a token it reports **n/a** with the checklist; an API error is a fault (exit 2), never a green. It is a member of the gate profile at the **`ci` control point only** — a local clone cannot see the server; at push and at the static round the member reports n/a with that reason. Adapters are functions of the platform key inside the reader (one definition; no platform switch elsewhere); a platform without an adapter (`Other`) is the checklist.
- **The rule names its server side.** `rules/branching.md` § Server-side protection and both `CLAUDE.md` § Pre-Action Gate: the hooks defend the rule locally; the server defends it per the runbook; a project whose server does not is running on prose. ADR-EVOL-051 and ADR-EVOL-053 point at this ADR as the closure of their bypass sentence. `DEVOPS --provision` runs the reader with the project's token as a provisioning step; QA's pre-verification checklist carries the item.

## Consequences

- The branch rule has a server side named, materialised and — where the platform exposes it — verified at CI; a project sees "n/a — no token" rather than a silent nothing, and a checklist it can tick.
- The framework repo is the first case: GitHub ruleset `main` — pull request required, the two governance checks required, no force-push, no deletion — applied on 2026-09-25 (recorded in the issue).
- Approvals, code-owner rules and merge strategies stay project decisions (keys); the reader judges only what the config asks.

## Alternatives considered

- **Write the protection through the API at SETUP** (`gh api -X PUT …`): rejected — a materialisation must never need a privileged token, and the setting belongs to the repository's administrators; the runbook + the reader is the honest split.
- **Verify at the push**: rejected — the local clone has no view of the server and no token by design; the `ci` control point has both.
- **One generic checklist, no adapters**: rejected — a checklist nobody verifies is prose again; the adapters exist where the API exists.

## Operational Rule

`rules/branching.md` (the body of the branching rule) gains § Server-side protection. No universal sentence changes.

## Verification record

`scripts/test-gates.sh` (55 unit tests; new `Scm`: origin parsing for the scp and https forms of GitHub, GitLab (nested groups), Bitbucket and Azure DevOps (`_git` and `v3` urls), the token names per platform; the GitHub adapter over rulesets green, every missing setting named — no pull-request rule, a check the server does not require, force-push and deletion open, approvals below the project's decision —, a ruleset in evaluation defends nothing, the legacy branch protection counts when present and its refusal (`administration` scope) is not a fault; the control points — push and static never ask the server (n/a with the five-item checklist), `ci` without a token is n/a with the checklist, never a green; an API error is a fault; `Other` is the checklist; a missing `scm` block is RED, `required: false` needs its reason, an unknown platform is RED; the GitLab (no one pushes, pipelines must succeed, force-push off, approval rules), Bitbucket (restrictions by kind) and Azure DevOps (policies readable, permissions unverifiable and on the checklist, never red) adapters green and red; the profile member; CLI exit codes). `scripts/test-validate-governance.sh` (9: colliding targets tolerated when every collider carries a distinct `stack_conditional`, the same conditional twice a violation). `scripts/materialize-synthetic.sh` (83 checks: the GitHub runbook lands at `docs/scm/protection.md` with its placeholders resolved; `scm-protection` n/a at the push and at `ci` without a token, the five-item checklist in the JSON). `check-lockstep-pairs` 72 files / 16 pairs (`scm.py` is a pair), `validate-governance --base origin/main`, ADR sync both directions, `manifest-parity`, `retired-terms`, `one-definition`, `runtime-surface`, `agents`, `seal --validate`, `digests`, `traceability`, `gate.py profile --run` at push (the member n/a with its reason) and at `ci` with a token against this repository's real ruleset (**green**: `main` protected as configured — the dogfood), `test-hooks.sh` 99, `test-code-review-gate.sh` 16, `test-templates-static.sh`, `test-measure.sh` 23, `test-po-package.sh` 126 — green locally.

{{REVIEW}}
