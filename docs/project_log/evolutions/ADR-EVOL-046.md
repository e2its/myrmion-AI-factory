---
id: ADR-EVOL-046
title: Gate profiles per control point — no gate is optional, it changes its point
date: 2026-09-25
status: accepted
---

# ADR-EVOL-046: Gate profiles per control point

## Context

Issue #55, axis B of the 2026-09 evolution (#50). The framework ran one gate set, all of it, everywhere: right for what reaches production, wrong for a sub-increment pushed to its train ten times a day. Downstream, roughly half of all agent clock was spent under gates, most of it re-running build- and database-dependent checks against a diff that could not have changed their outcome. The obvious fix — a "fast mode" that makes gates optional — is the failure mode to avoid. Measured on this repository before design: the pre-push hook ran a hard-coded loop of six gate members plus a separate governance step, the two workflows listed the same members again as steps, and three hooks and the preflight each kept their own list or regex of protected branches — four definitions of one fact. Decision authority delegated by the user on 2026-09-25.

## Decision

Agent-internal choices (pick + surviving risk):

- **One key, closed set, fail-closed, no override.** `delivery_mode` at the top level of the governance manifest (`.context/templates/setup/governance_versions.json` here; `docs/project_log/governance_versions.json` in a project — asked at SETUP Q32, persisted in `docs/setup.md` `delivery:`). Values `development` | `production`. `gate.py profile` is the only reader: an absent key, an unknown value or an unreadable manifest resolves to `production`; environment variables are never consulted (proven by test). Rejected: a key in `config/quality.json` (that file holds thresholds, not the project's delivery state) and an environment switch (the exact "optional gate" the issue forbids).
- **Profile = mode × branch class.** `light` only for a sub-increment pushed to its train while the mode is `development`; `full` for everything else — the train close, a plain branch, a malformed or unclassifiable name, a detached checkout, and every branch in production mode. The class comes from the EVOL-045 reader, so a misnamed branch cannot buy the light profile.
- **Members enumerated by property, once.** `scripts/gates/profile.py` lists every gate member with `needs_build`, `needs_database` and its owner. Light = the members that need neither: ADR sync, retired terms, budgets, law parity, currency, manifest parity, surface, secrets, the review and coherence markers, SAST, complexity, and in the framework repo the manifest drift validation and the applicability validator (meta-only members — a project has no framework manifest; the smoke said so on the first run). Full = every member, including the full verification loop (tests, lint, typecheck, build, format, seed alignment), the preventive sweep and the smoke. `gate.py profile --run` executes the script members at the push / CI control point with **all-report** semantics — every member reports, one verdict names every red member, what could not run and what the light profile skipped — and lists agent-run members as owed to their owner; it never stops at the first red. The light profile writes no seal; the seal the full loop writes (`bvl_result`, the push markers) is honoured by the full profile alone. Risk: the agent-run members are prose obligations (BVL, DEVOPS, QA), not executed by the reader — the table names them so the omission is visible, not silent.
- **One call everywhere.** The pre-push hook's governance step and its hard-coded gate loop became one call (`gate.py profile --run --control-point push`); both CI workflows replaced their step lists with the same call plus `gate.py one-definition`. The pre-push's own members are gone from the hook: the hook knows nothing about which gates exist. Rejected: keeping one CI step per member for attribution — the verdict names every member; a second list in YAML is a second definition.
- **No second definition, proven by a gate.** `gate.py one-definition` scans hooks, git hooks, workflows and the preflight (meta and template twins) for a protected-branch list, a branch regex, a read of `delivery_mode` or a mode environment override, and fails on any. It went red on the real repository first (seven findings: the edit hook's regex, the commit hook's and the pre-push's branch lists, the preflight's regex, and their template twins) and is green after every branch check was routed through `gate.py branch-class --protected`. Consequence accepted: the edit hook, the commit hook and the force-push guard **fail closed** when the reader is absent or broken — governance not delivered blocks the edit with the resolution named (factory-sync, or a shell-side fix, since the shell is not gated). The previous fail-open was a silent pass.
- **Control-point table** on both lock-step sides (project `CLAUDE.md § Control points and gate profiles`, meta `CLAUDE.md § Pre-Action Gate`): what commit, sub-increment push, train close, pull request to main, main itself and on-demand deployment owe in each mode, which seal each writes or honours, and the one-line return to production mode (`delivery_mode: production` in the manifest, one commit).

## Consequences

- New module `scripts/gates/profile.py` (lock-step pair, delivered to projects); `gate.py profile [--run] | one-definition`.
- Manifest key `delivery_mode` (meta: `development`); SETUP Q32; the project manifest shape gains the key; the setup template carries the slot.
- Hooks: `check-branch-protection.sh`, `pre-commit`, `pre-push` (force-push guard and the profile call), `preflight.sh` — no branch list or regex anywhere; the reader decides, fail-closed.
- `framework_version` 7.2.0 → **7.3.0** (MINOR — additive; branch `feature/EVOL-046-gate-profiles`).
- No new LAW. Both `CLAUDE.md` sides carry the table.

## Alternatives considered

A per-gate `optional_in_development` flag — rejected: that is the optional gate. Deriving the profile from the PR target on the remote — rejected: the push runs before the PR exists and the branch name already carries the class. A separate "fast" CI workflow — rejected: two workflows are two definitions.

## Operational Rule

No LAW added. Project `CLAUDE.md` gains § Control points and gate profiles; meta `CLAUDE.md § Pre-Action Gate` gains the same paragraph and table. Both lock-step sides updated; universal sections and the LAW corpus untouched.

## Verification record

`scripts/test-gates.sh` (31 unit tests; new: the mode fails closed on an unknown value, an absent key, an unreadable and an absent manifest and ignores `DELIVERY_MODE` / `FACTORY_MODE`; the profile is light only for a sub-increment in development mode and full for the train, a feature, a fix, main, an unknown name and every branch in production mode; the light members carry neither property; the run reports every member with one verdict, lists agent-run members as owed and is red without a diff base; the one-definition scan finds a branch list in a hook and a mode read in a workflow and ignores comments; CLI exit codes). `scripts/test-hooks.sh` (51: the edit hook blocks `main` and a train through the reader, blocks with the resolution named when the reader is absent or faulting; the pre-push runs the profile as one call, a red profile blocks, a member that could not run warns, no member runs outside the profile, a missing reader blocks the push). `scripts/materialize-synthetic.sh` (36 checks: a feature owes full, a sub-increment owes light, production mode makes it full, the profile runs every script member green in the scratch project, the materialised hooks and workflow keep no second definition). `gate.py one-definition` red on the real repository first (7 findings), green after. `check-lockstep-pairs`, `validate-governance --base main`, ADR sync both directions, `gate.py profile --run` on this branch, full T2 suite — green locally and in CI.
