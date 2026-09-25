---
id: ADR-EVOL-047
title: Deployment trigger by positive runtime surface, held by a parity gate
date: 2026-09-25
status: accepted
---

# ADR-EVOL-047: Deployment trigger by positive runtime surface

## Context

Issue #56, axis C of the 2026-09 evolution (#50). The framework's docs-only fast lane was expressed as an **exclusion** list — skip the machinery when every path in the diff matches an allowlist of things that do not matter — and it was conflated with a **commit-to-main permit** ("Docs-only fast-lane (commit-on-main + CI skip)", CLAUDE.md § Generation Standards 3 on both lock-step sides). An exclusion list is unbounded on the wrong side: every new path defaults to "deploys", and the one time it defaults wrong nobody notices, because the failure is a skipped deployment or a release cut for a typo. Downstream, the inversion caught a live defect: a data file the deployment scripts actually read sat in the ignore list. Measured here before design: the release-cutting workflows (`auto-tag`, meta and seven platform templates) fired on every push to `main` with a commit-message filter as the only gate, and nothing held any list to what `scripts/auto-tag.sh` really reads (the governance manifest). Decision authority delegated by the user on 2026-09-25.

## Decision

Agent-internal choices (pick + surviving risk):

- **The positive list is a key, asked at SETUP.** `config/quality.json → surface.runtime_surface` (Q33) — what a deployment or a release can change. Meta: the template tree, the framework core, the scripts, the config, `CLAUDE.md`. Two companion keys, each entry with its reason: `surface.always_deploy` — the hard exclusions that fire the machinery regardless of match (workflow definitions, because they execute in CI/CD; the inputs a deployment-time gate reads: `config/quality.json`, the governance manifest) — and `surface.declared_reads` — paths a deploying job reads outside the surface (parity exemptions). Rejected: a per-platform `paths:` filter in the YAML — seven copies of the list in seven syntaxes, a parity gate over YAML, and a second definition.
- **Every deploying / release workflow asks the reader first.** `python3 scripts/gate.py runtime-surface --changed --base HEAD^1` (the merge's first parent — a squash or a merge commit alike) is the first step of `auto-tag` on GitHub (meta and template: an output the machinery steps depend on) and on GitLab, Azure, Bitbucket, Cloud Build, CodeBuild and Jenkins (an early exit before the tag script). Exit 0 = touched → deploy / tag; 1 = untouched → the machinery skips and says so; 2 = could not judge → deploy (fail-closed towards deploying). An empty list deploys everything and the parity gate says the list is missing. `IMPLEMENT --build` at train close and `DEVOPS --deploy` on a merge ask the same call. Risk accepted: the workflow still starts a runner to ask (seconds), against seven YAML copies of the list.
- **A parity gate holds the list to reality.** `gate.py runtime-surface` (a member of the gate profile, so it runs at push and in CI): the deploying workflows (`auto-tag*`, `deploy*`, `release*` under the workflows directory — and, in the framework repo, the shipped templates) are read for path literals; every `scripts/*.sh|py` they run is read transitively; a literal that names something in the tree must match the surface or a hard exclusion, or be a declared read; a declared read nothing reads any more is a stale exemption — a finding. Risk: literal extraction is a heuristic over shell text — a path built from variables is invisible to it; the ADR says so, and a read the gate cannot see is a read the author declares.
- **The branch rule is untouched and restated on both lock-step sides.** Every change ships via branch and pull request, documentation included; there is no commit-to-main permit for any class of change. What a change outside the runtime surface saves is the machinery — the deploy / tag workflows, and the push-gate preflight's review lanes, which keep their own honest allowlist (documentation only; never workflow YAML nor the behavioural contracts). The old section title and the triage item that read as a permit were rewritten; the skills that echoed the permit were aligned.
- **Retired:** the "commit-on-main + CI skip" reading of the fast lane. Nothing in code implemented a skip — the auto-tag message filter was the accidental exclusion; it stays as a second guard behind the reader.

## Consequences

- New module `scripts/gates/runtime.py` (lock-step pair, delivered to projects); `gate.py runtime-surface [--changed --base B]`; a new profile member `runtime-surface` (no build, no database — light).
- `surface.runtime_surface` (Q33), `surface.always_deploy`, `surface.declared_reads` on both config sides; the setup template carries the slot; the materialisation invariant runs the parity gate on the materialised tree.
- Every `auto-tag` workflow (meta + seven templates) gated; `rules/ci-cd.md`, the build instruction, the branching skill and the DevOps instruction name the call.
- `framework_version` 7.3.0 → **7.4.0** (MINOR — additive; branch `feature/EVOL-047-runtime-surface`).
- No new LAW. Both `CLAUDE.md` sides: § Generation Standards 3 rewritten as "The branch rule and the runtime surface".

## Alternatives considered

Keep the exclusion list and add a linter for it — rejected: the wrong side stays unbounded. A `paths:` trigger per platform — rejected: seven definitions. Deciding deployment from the PR labels — rejected: a human choice where a measurement exists.

## Operational Rule

No LAW added. Meta `CLAUDE.md § Generation Standards 3` and project `CLAUDE.md § Generation Standards 3` restate the branch rule and describe the positive list, the hard exclusions with reasons, the parity gate and the honest review allowlist. Both lock-step sides updated; universal sections and the LAW corpus untouched.

## Verification record

`scripts/test-gates.sh` (33 unit tests; new: `changed` is untouched for documentation and touched for source, a hard exclusion fires regardless, `HEAD^1` is the CI shape, an empty list deploys everything and says so, a non-list surface and an exemption without a reason are faults; parity finds a read in the workflow itself and one two scripts deep, ignores comments and non-deploying workflows, honours declared reads, flags a stale exemption, is green once the surface covers the reads, and reports an empty surface; CLI exit codes). `scripts/materialize-synthetic.sh` (42 checks: parity green on the materialised deploying workflow; a docs-only merge is untouched with the branch rule restated; a `src/**` merge is touched; a stale exemption is red). Every workflow file parses (static test). `check-lockstep-pairs`, `validate-governance --base main`, ADR sync both directions, `gate.py profile --run` (the new member included), full T2 suite — green locally and in CI.
