---
id: ADR-EVOL-045
title: Increment trains and the per-PR surface ceiling
date: 2026-09-25
status: accepted
---

# ADR-EVOL-045: Increment trains and the per-PR surface ceiling

## Context

Issue #54, axis A of the 2026-09 evolution (#50). The framework slices work vertically (slice map at CODESIGN, increment plan at BLUEPRINT), but the unit a reviewer receives was unbounded: an increment could reach any size and review quality collapsed past a certain diff. Downstream, capping the reviewable unit **per pull request** was the change that most reduced review rounds and rework. An estimate alone is a wish — the cap has to be measured at push. A second, quieter defect: every gate, review and script derived "what changed" against its own idea of the base (`origin/main` literals in the pre-push hook, preflight, the review skills, the security scan, the ADR-sync gate, the verdict templates) — one definition was needed before a branch could have a base other than main. Decision authority delegated by the user on 2026-09-25.

## Decision

Agent-internal choices (pick + surviving risk):

- **The reviewable unit is the sub-increment; its size is a key.** `config/quality.json → surface.ceiling_files / ceiling_lines`, asked at SETUP (Q31, RDR default 30 / 800), never a digit in prose. Meta ceilings are wide (400 / 40000) because an evolution ships the template tree and its meta twin in one PR — recorded in the key's `_doc`. Rejected: a ceiling per feature (the reviewer holds a PR, not a feature) and a ceiling per increment (an increment is a product unit, not a review unit).
- **The plan estimates before building.** Every `### INC-N` of `increment_plan.md` declares `Estimated surface:` (paths · ~files · ~lines — the same ruler the gate uses), `Escape:` and, only when over a ceiling, `Sub-increments:` (`SUB-{N}-{M}`, scope by task group / scenario, its own estimate, its branch). BLUEPRINT Step B.4 ratifies estimate and split by RDR (≥3 splits, the seam as the argument, two registers); CVP Check 21 `surface_declared` warns on an increment without an estimate. Risk: the estimate is an LLM guess — the push-time measurement is the backstop, not the estimate.
- **Trains.** A per-increment branch whose plan declares sub-increments is a **train**: opened once from the base branch, it receives sub-increment merges only (one PR each from `feature/{ID}-inc-{N}-{slug}-sub-{M}`, branched from the train), and closes to the base branch by one PR. Protected like a base branch: the PreToolUse hook asks `gate.py branch-class --protected`. The suffix scheme was chosen so the feature-id regex stops before the lowercase `-inc-`: `-sub-{M}` never enters the id, and the existing per-increment regex still matches the train. One full verification loop and one deployment per train (none when its diff touches no `surface.runtime_surface` glob; `[]` = every train deploys); a sub-increment runs its scoped task tests and the REVIEW hat only. The closure artefacts land through the last sub-increment's PR into the train — the train takes no direct commit. Rejected: closing the train on the train itself (contradicts its protection) and a full loop per sub-increment (the cost the issue wants to remove).
- **One diff base, fail-closed.** `gate.py diff-base` is the only definition: a sub-increment measures against its train; everything else against `default_base_branch` (branching rule frontmatter, else main); an unrecognised branch name is **red (exit 1)**, not an infrastructure fault (exit 2) — otherwise a misnamed branch would sail through every "warn and proceed" lane. Consumers refactored: pre-push (step 4 + the factory-pr-review lane), preflight, `certify` / `currency` defaults, the review skills, the security scan, the ADR-sync gate, `validate-governance`, the verdict templates. CI passes the PR base ref explicitly (a PR checkout is a detached HEAD with no branch name to classify).
- **The real surface is measured at push, no exclusion list.** `gate.py surface` counts files + lines (added + deleted) of `git diff --numstat base...HEAD`; over either ceiling blocks (pre-push step 4, preflight Block 21 `surface-over-ceiling`, CI) unless a commit in the range carries `Surface-Escape: <term>` with `term ∈ surface.escapes` — a closed list (generated-code · vendored-dependency · mass-rename · lockfile · migration-baseline · framework-sync); any other term is red even when the diff is under the ceiling, so the vocabulary cannot drift silently. Extending it is a decision record. Rejected: an exclusion list for generated files (it would become the place where surface hides).
- **Backlog and measurement.** A sub-increment is a sub-item of the increment's IMPLEMENT issue through `add_sub_issue` (adapters without it degrade to the existing `> Parent: #N` line); `measure.py` rolls sub-increment branches up into their train (commits, review rounds, sub-PRs).
- **Retired:** nothing — the phrase "too many increments" never existed as a gate; a feature has as many increments as its surface needs.

## Consequences

- New module `scripts/gates/branch.py` (lock-step pair, delivered to projects); `gate.py branch-class | diff-base | surface`; `certify` / `currency` take their base from the resolver.
- `config/quality.json → surface` on both sides; SETUP Q31; the increment plan template carries the three keys; `increment_plan.md` gains sub-increment entries, `dev_plan.md` gains `### Sub-increment` groups and `sub_increments` frontmatter.
- `framework_version` 7.1.0 → **7.2.0** (MINOR — additive; branch `feature/EVOL-045-increment-trains`).
- No new LAW. Meta `CLAUDE.md § Pre-Action Gate` and project `CLAUDE.md § Incremental Dev Plan` each carry one paragraph; the branching skill § Trains is the body.

## Alternatives considered

A ceiling enforced only by CI — rejected: the gate must run where the work happens; CI applies the same verdict. Measuring only files, or only lines — rejected: each alone is gameable (one file of 3 000 lines; 200 one-line renames). A git-notes escape instead of a commit trailer — rejected: notes do not travel with a PR. Deriving the diff base from the PR target on the remote — rejected: the push runs before the PR exists; the name is the only local fact.

## Operational Rule

No LAW added. Project `CLAUDE.md § Incremental Dev Plan` gains "Trains and the surface ceiling"; meta `CLAUDE.md § Pre-Action Gate` names the train protection, the sub-increment pattern, the one diff base and the surface ceiling. Both lock-step sides updated; universal sections and the LAW corpus untouched.

## Verification record

`scripts/test-gates.sh` (27 unit tests; new: every class of the grammar and train protection, the one diff base (sub → train, everything else → the default base, `default_base_branch` honoured, unknown → red, current branch classified), surface under / over files / over lines / unknown escape red even under the ceiling / valid escape / a sub-increment measured against its train not main / missing key = fault; CLI exit codes for the three subcommands and `currency` without a base). `scripts/test-hooks.sh` (49: + a train blocks Edit/Write with the sub-increment branch named, the sub-increment and a plain increment pass; pre-push step 4 with a red surface blocks). `scripts/materialize-synthetic.sh` (29 checks: surface ok on a small diff, RED over the materialised `ceiling_files`, a `Surface-Escape` from the closed list passes, a train is protected, a sub-increment's base is its train, an unrecognised name is red). `python3 subproducts/measure/measure.py --selftest` (a train with two subs rolls up). `check-lockstep-pairs`, `validate-governance --base main`, ADR sync both directions, `gate.py budget / retired-terms / laws --parity / currency / manifest-parity / surface`, full T2 suite — green locally and in CI.
