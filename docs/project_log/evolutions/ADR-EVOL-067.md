---
id: ADR-EVOL-067
title: "Verification members as configuration — the loop names no stack, a skip leaves a trace that expires, the secret scanner proves it detects"
date: 2026-10-21
status: accepted
---

# ADR-EVOL-067: Verification members as configuration

## Context

This ADR implements issue #121 (epic #112, train row 5b, after EVOL-102 phase 2 and before EVOL-068). It was verified on `main` at framework 8.16.0.

- **The loop names stacks.** `factory-build-verification/SKILL.md:143-251` derives commands per runtime (`MATCH stack.backend.runtime`). A new stack means editing the skill. `docs/setup.md → verification.commands` overrides them, so commands live in two places.
- **`{{VERIFICATION_GATES}}` is prose.** `Factory-setup-materialization.instructions.md:980` describes the derivation. No table holds the per-stack rows. `scripts/materialize-synthetic.sh:108` hard-codes a Python map for every fixture, so the dotnet fixture gets Python commands.
- **A skip is printed, then lost.** `profile.py:189-193` prints the members it skipped. Nothing records which member was skipped, why, when, or until when.
- **"Never skip security" is prose only** (`security-scan.sh:126`, `discovery_registry.json:1090`). No code refuses a skipped `secrets`, `sast` or `sca` member.
- **Nothing proves the secret scanner still detects.** A scanner that is misconfigured, or one whose rules changed, passes silently.

This is the plan artefact of train row 5b (one plan, three commits: EVOL-102 phase 2, EVOL-067, EVOL-068).

## Decision

1. **Members come from the registry's `configures`.**
   - A registry key option may declare `configures: {"verification.gates": {<gate>: {command, scoped?, red_link?, report?}}}`. The keys are `backend.runtime`, `frontend.framework` and `security_scan.*`.
   - `gate.py discovery --resolve` merges the rows of the answered options into one `verification.gates`.
   - `reads` comes from the answered runtime surface plus the test roots.
   - Materialisation writes `{{VERIFICATION_GATES}}` from that output. The synthetic materialiser does the same, so each fixture gets its own stack's rows.
   - The rows cover the stacks the templates already cover. A new stack's rows ship with its platform pack (epic #151).
2. **The skill names no stack.** `derive_commands_from_stack()` and the `verification.commands` override go. The loop reads `verification.gates` only. The task loop's scoped run reads `tests.scoped`, with `{paths}`.
3. **A skip is data that expires.**
   - `config/quality.json → verification.skips` is a list of `{gate, reason, at, until}`. It is reviewed in the pull request like any other config change.
   - Whoever made the skip is the commit's author. No file names a person (PLAW-07).
   - A skipped gate is not owed while its `until` is in the future, and the loop lists it with its reason.
   - An expired skip makes the gate owed again, and the loop is red until the gate runs or the skip is renewed.
   - A skip of `secrets`, `sast` or `sca` (the closed set `SECURITY` in `seal.py`) fails `seal --validate` (LAW-04).
4. **The secret scanner proves it detects.**
   - When a `secrets` member is declared, `seal --run` first commits the canary's planted credential into a temporary git repository outside the tree. The value is decoded from base64 only there.
   - It runs `security_scan.secrets_command` in that repository.
   - No detection, or a scanner that cannot run, makes the run red with a humanised reason.
   - The credential is the lens canary's (`canary.py`), reused. At rest it stays encoded, so the repository's own scanner never sees it.
5. **Upgrade.**
   - A registry `migrations` row marked `always` (EVOL-102 phase 2) re-derives `verification.gates` on every upgrade.
   - A project row that differs from the derived one is kept, because the project wins. A `verification.commands` override moves into `verification.gates`. Neither is ever dropped.

## Consequences

- A new stack adds registry rows, never a skill edit. A test refuses a stack literal in the skill.
- A skip costs a reviewed config change, and it ends on its own date.
- Every full loop with a `secrets` member pays one scanner run on a one-file repository.
- **Declared gap:** `scripts/hooks/pre-commit` still skips gitleaks silently when the tool is missing. The full-loop canary catches a scanner that does not detect, and the pre-push secrets lane runs under `--require-scanner`.

## Alternatives considered

- **Per-stack row files selected by `stack_conditional`.** Rejected: the issue forbids a selection table beside the registry, and rows in files would need a merge step of their own.
- **A `seal --skip` flag.** Rejected: it adds a flag (Generation Standards §4), and a skip is a decision that belongs in a reviewed change.
- **A `by` field in the skip.** Rejected: it invites a person's name in a committed file, and the commit author already answers who.

## Operational Rule

The verification loop runs the members the project declares in `verification.gates`, derived from the registry. A skip is dated and expires, and a security member is never skipped. The secret scanner proves it detects on every full run.

## Verification record

Delivered on `feature/EVOL-067-verification-loop`, commit 2 of train row 5b (2026-10-21).

- **Red first** (`scripts/gates/test_gates.py`, 11 new cases):
  - an expired skip makes the loop red; a live skip is not owed and is listed with its reason;
  - a skip of `secrets`, `sast` or `sca`, or a malformed skip, fails `seal --validate`;
  - a member without `reads` is refused;
  - a stub scanner that detects is green, whether it exits 1 or a findings code such as trufflehog's 183; one that does not detect, cannot run, fails a clean commit or is killed by a signal makes `seal --run` red; no `secrets` member, no canary;
  - the planted credential is provider-shaped and above gitleaks' entropy floor; where gitleaks is installed, the real scanner detects it;
  - `--resolve` merges the `configures` rows into one `verification.gates`, one source per gate, conditional rows included;
  - V12: a `configures` row parses — known fields only, a command, `red` a bool.
- **`always` migration:** the upgrade-8.12 fixture owes `verification.gates (EVOL-067)`, asserted by its `expect.migrations`.
- **The skill names no stack:** a literal test refuses `pytest`, `npm`, `dotnet`, `mvn`, `gradle`, `go test`, `ruff`, `eslint`, `tsc` and `cargo` in `factory-build-verification/SKILL.md`.
- **Synthetic materialisations:** the default and dotnet fixtures each get their own stack's `verification.gates` (`expect.gates`); the dotnet fixture now runs the seal checks.
- **Battery:** every `scripts/test-*.sh`, lock-step pairs, `validate-governance.sh`, three synthetic materialisations, `gate.py discovery`, `manifest-parity` and `gate.py profile --run` — green.
- **Declared deviations:**
  - lint and typecheck run on the whole tree (no scoped variant);
  - .NET declares no test roots;
  - the frontend member is named `frontend-tests`;
  - the meta repo declares no `secrets` member (`seal.required: false`), so the canary runs only in materialised projects.
