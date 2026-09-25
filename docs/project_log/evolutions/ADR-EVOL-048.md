---
id: ADR-EVOL-048
title: One planning stage — never zero, never two
date: 2026-09-25
status: accepted
---

# ADR-EVOL-048: One planning stage

## Context

Issue #57, axis F of the 2026-09 evolution (#50). A plan is a governance artefact: it pre-commits the work, and the harness's plan approval is a real user ratification. Two opposite failures were observed downstream and the framework had no notion of either: **zero stages** — work on a branch class with no planning phase of its own (a fix, a platform chore) reaching governed paths with no plan and no approval, so the first the user saw of a decision was the diff — and **two stages** — a command that already owns a planning phase entering plan mode again, producing an approval marker that appears to cover decisions the user never made. Decision authority delegated by the user on 2026-09-25; in this framework repo the ADR of an evolution is the branch's plan artefact, and this one was written before the first governed write of its branch.

## Decision

Agent-internal choices (pick + surviving risk):

- **A pre-write gate on governed paths, one reader.** `scripts/gates/planning.py` behind `gate.py plan --path <file>` and the PreToolUse hook `check-plan-approval.sh` (Edit|Write): a write to a governed path on a branch class that has no planning phase of its own requires an approved plan; without one it blocks with the blocking exit status (2, stderr) and a humanised reason naming the resolution (LAW-08). Configuration in `config/quality.json → planning`: `governed_paths` (globs), `docs_exempt` (documentation targets need no plan), `gate_inputs` (documents a gate reads — the constitution, the setup record, the rules, the config, the manifest — governed like code, the carve-out from the exemption), `exempt_classes`, `plan_artefact`, `adoption_window_minutes`. Precedence: a gate input is governed whatever its extension; then the documentation exemption; then the governed globs.
- **Branch classes enumerated, fail closed.** The classes exempt because a framework phase owns their plan are listed — in a project: `feature`, `increment`, `train`, `sub-increment`, `epic` (CODESIGN, BLUEPRINT and IMPLEMENT --plan own their plan artefacts and their own gates) — and **every unlisted class is gated**: `fix`, `docs`, `chore`, `breaking`, a protected branch, an unrecognised name. In the framework repo no class is exempt: an evolution branch has no framework phase; its plan artefact is `docs/project_log/evolutions/ADR-{ID}.md` in `status: accepted`, written first.
- **Approval is a marker written only on the user's approval** — the PostToolUse hook `record-plan-approval.sh` on the harness's `ExitPlanMode` tool (which completes only when the user approves) writes `.claude/state/plan-approved-<branch>.json`; the recorder refuses any input that is not that hook event. Or the branch's own plan artefact in an approved state. A plan approved just before the branch is cut (the marker carries the branch it was approved on, typically `main`) is **adopted once**, by the first gated branch born to receive it, within `adoption_window_minutes`; adoption rewrites the marker to that branch — single use — and an expired one is said, never silently used. Risk: the marker is a file under `.claude/state/` (gitignored); an agent could write one from the shell. The recorder's refusal and the audit trail (the marker names its source and session) make that a visible fraud, not a silent one.
- **Documentation targets are exempt, except gate inputs.** `**/*.md` and `docs/**` need no plan; the constitution, `docs/setup.md`, the rules, `config/**`, the governance manifest are inputs of gates and stay governed. Rejected: exempting every `.md` — the constitution is a `.md`.
- **A command that owns a planning phase never enters plan mode.** CODESIGN, BLUEPRINT and IMPLEMENT `--plan` state it in their command files; the IOP states the rule for every command. One stage, never two.
- **An advisory before the block.** The prompt-submit hook asks `gate.py plan --status` and emits `<planning-warning>` when the session is on a gated class with no approval, so the user is never surprised by the refusal.

## Consequences

- New module `scripts/gates/planning.py` (lock-step pair, delivered); `gate.py plan --path | --status | --record`; two hooks (`check-plan-approval.sh`, `record-plan-approval.sh`) wired in both `settings.json`; `planning` block on both config sides; the prompt-submit advisory in both `governance-onprompt.sh`.
- `framework_version` 7.4.0 → **7.5.0** (MINOR — additive; branch `feature/EVOL-048-one-planning-stage`).
- No new LAW. Both `CLAUDE.md` sides: § Pre-Action Gate gains "One planning stage".
- In this repo, every evolution branch now writes its ADR before its first governed write — the discipline this session adopts from here on.

## Alternatives considered

A plan marker written by the agent on its own judgement — rejected: that is zero stages with a receipt. Gating every write (documentation included) — rejected: a README typo owes a branch and a PR, not a plan. Exempting `fix/*` because fixes are small — rejected: the observed zero-stage failure was exactly a fix reaching governed paths.

## Operational Rule

No LAW added. Meta and project `CLAUDE.md § Pre-Action Gate` gain the "One planning stage" paragraph. Both lock-step sides updated; universal sections and the LAW corpus untouched.

## Verification record

`scripts/test-gates.sh` (36 unit tests; new: governed precedence — a gate input under docs is governed, a documentation path is exempt, a rule is a gate input even as `.md`, an absolute path is relativised, a missing `planning` block is a fault; a feature passes by phase; every unlisted class (`fix`, `chore`, `docs`, `breaking`, an unrecognised name, `main`) is gated and blocks a governed write with the resolution named, passes a documentation write and blocks a gate input; the recorder refuses a payload that is not the harness's `ExitPlanMode` event and writes the marker from one; a `main` approval is adopted once by the first gated branch, refused by the second, never adopted from another working branch's marker, said as expired outside the window, and never consumed by the advisory; an unreadable marker is no approval; the plan artefact approves only in an approved state and only for its own branch; CLI exit codes). `scripts/test-hooks.sh` (76: the pre-write hook blocks a governed write on `fix/gated` with exit 2 and the resolution, passes a documentation write, blocks a gate input under docs, passes an empty payload, passes after the delivered recorder wrote the marker from an `ExitPlanMode` payload and refuses a forged one through the envelope, passes a feature branch, blocks when the reader is absent; the prompt hook carries `<planning-warning>` on a gated unapproved branch and not on a feature branch). `scripts/materialize-synthetic.sh` (48 checks: on the scratch project a feature's governed write passes by class, a fix's is blocked, its documentation write passes, the delivered recorder's approval unblocks it; both hooks land executable). `check-lockstep-pairs`, `validate-governance --base main`, ADR sync both directions, `gate.py one-definition`, `gate.py profile --run`, full T2 suite — green locally and in CI.
