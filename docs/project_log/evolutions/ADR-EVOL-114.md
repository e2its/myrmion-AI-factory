---
id: ADR-EVOL-114
title: "One CODESIGN exit per intent — --deprecate and --reset retire into --revise, --cancel and --refine; a terminal feature is never pending work"
date: 2026-10-20
status: accepted
---

# ADR-EVOL-114: One CODESIGN exit per intent

## Context

This ADR implements issue #181 (epic #112, train row 4b). It was verified on `main` at framework 8.13.0. Owner RDR «1» (2026-10-19) chose to simplify the orders that #117 declared in v8.12.5.

- **`--deprecate` is `--cancel` under another name.**
  - It writes `status: DEPRECATED`, `deprecated_at` and `deprecation_reason`, plus one worklog row (`rules/immutability_policy.md:381-398`, `Factory-codesign-feature:955-958`).
  - It deletes nothing and moves nothing on the board.
  - `--cancel` writes `CANCELLED` and logs its reason in the worklog. The policy reserves it for early stages (`immutability_policy.md:385-386`), so `--deprecate` existed only to cancel an approved feature.
- **`--reset` covers part of `--refine`'s job.** It moves `NEEDS_INFO` back to `DRAFT` and clears the blocking questions (`:960-963`). `--refine` (`:709-730`) has no status gate and never names `NEEDS_INFO`. Smart-redirect `:309` already routes `DRAFT|NEEDS_INFO` → `--refine`.
- **No step keeps a terminal feature out of pending work.**
  - The next-task resolver takes every `- [ ]` line in file mode (`Factory-backlog-next-task:450-451`) and every item outside the board's last column in board mode (`:452`).
  - It never reads the feature's `spec.feature` status.
  - A `CANCELLED` or `DEPRECATED` feature drops out only if someone moves its items by hand.
- **The readers list the terminal states separately and disagree with each other.**
  - Smart-redirect `:140,:157,:662,:689-693`.
  - IPP `:140`.
  - `Factory-codesign-feature:34,:963,:1055`.
  - `immutability_policy.md:555-557`, which names `CANCELLED` only.
  - README `:770,:786-787`.
- No script reads a feature's status, so the readers are instructions.

## Decision

1. **Three exits, one per intent.**
   - `--revise` opens a new version, as today.
   - `--cancel` abandons a feature at any non-terminal state (`DRAFT`, `NEEDS_INFO`, `APPROVED`). It writes `CANCELLED` into every feature artefact and logs the reason in the worklog.
   - `--refine` answers the blocking questions. On a `NEEDS_INFO` feature, once no blocking question is left open, the status returns to `DRAFT`; until then it stays `NEEDS_INFO`.
   - `--deprecate` and `--reset` leave `.claude/commands/codesign.md` and every shipped text.
2. **One terminal set, named at its home.** The spec status enum in `Factory-codesign-feature` becomes `DRAFT | NEEDS_INFO | APPROVED | CANCELLED | SUPERSEDED`.
   - A feature written before this change may carry a legacy `DEPRECATED`. It reads as `CANCELLED`: terminal, and never written again.
   - Every reader names the same set: smart-redirect, IPP, the CODESIGN, BLUEPRINT and QA guards, `immutability_policy.md`, README.
   - A line that still has to recognise the old value says "legacy" on that line.
3. **A terminal feature is never pending work.**
   - The next-task filter chain, shared by `--next-task` and `--eligible` in both modes, excludes a candidate whose feature's `spec.feature` status is terminal: `CANCELLED`, a status containing `SUPERSEDED`, or a legacy `DEPRECATED`.
   - `SUPERSEDED` is included because `--revise` copies v1's artefacts into v2, so v2 owns the work. Proposing v1's leftover items would duplicate it. The policy writes this status as `APPROVED (SUPERSEDED)`, which is why the check is "contains".
   - The candidate is excluded, not "blocked", and not counted as pending.
   - A candidate with no feature, or whose `spec.feature` is absent or unreadable, is not terminal. It stays, and the later gates judge it.
   - When every pending item is excluded, `--next-task` reports that no work is pending and names each terminal feature that still holds open items.
   - This also closes the `CANCELLED` gap.
4. **Installed projects are never rewritten.** A terminal artefact is immutable (`immutability_policy.md`), so no upgrade step rewrites `DEPRECATED`; the readers recognise it.
5. **The ratchet keeps the retired text out.** Both entries carry `record: ADR-EVOL-114` and exempt `docs/spec/**` and `docs/proposals/**`, because a project's own artefacts keep their history.
   - **The orders** go into `config/quality.json` and its template twin: `(CODESIGN|/codesign)` followed by `--deprecate` or `--reset`.
   - **The state** goes into the meta `config/quality.json` only: `DEPRECATED` on a line that does not say "legacy".
     - It scans every shipped text, `.context/templates/**` included, before that text reaches a project.
     - It is not shipped, because a project's own code uses the word in other senses (an API, an enum, a log level). Shipping it would turn the gate red on product code.
     - Framework files where the word has another meaning are exempt, each with its reason: inventory statuses, ADR statuses, API or contract deprecation.
     - An incidental feature-sense mention is reworded, not exempted.

6. **Governance sources.**
   - `CLAUDE.md` Generation Standards §4 gains the converse of its new-flag rule: a flag that repeats another's intent retires into it, and a `retired_terms` entry keeps it out.
   - The project `CLAUDE.md` template's Artifact States names the terminal states.

## Consequences

- One fewer state and two fewer orders.
  - `--cancel` covers both early abandonment and abandoning an approved feature.
  - `--refine` covers paused features.
- The next-task resolver gains one filter. A terminal feature with leftover open items is no longer proposed, whether the feature was cancelled or carries a legacy `DEPRECATED`.
- No new command, flag or script.
- `check-command-flags.py` turns any leftover `CODESIGN --deprecate|--reset` citation red once `codesign.md` drops them.
- **Upgrade path:**
  - `factory-sync.sh` delivers the command, the instructions, smart-redirect and IPP.
  - `SETUP --upgrade` delivers `rules/immutability_policy.md` and the template config with the orders entry.
  - A legacy feature stays terminal and stays green under the ratchet (`docs/spec/**` is exempt).
- The `DEPRECATED` values that mean something else are untouched: code inventory (`check-inventory-freshness.py`), ADR status, API deprecation.

## Alternatives considered

- **Upgrade migration (`DEPRECATED` → `CANCELLED` in `docs/spec/**`).** Rejected for two reasons:
  - It writes into terminal artefacts, which immutability forbids.
  - It leaves a window in which `factory-sync.sh` has delivered readers that no longer know the old value but `--upgrade` has not yet run.
- **A script that classifies feature status for the resolver.** Rejected: it would be a new command (CLAUDE.md §4), and one filter line in the shared chain is enough.
- **Keep `--deprecate` as an alias of `--cancel`.** Rejected: that is two words for one intent, which is the problem this change removes.

## Operational Rule

- CODESIGN has three exits on an existing feature: `--revise` (a new version), `--cancel` (abandon it, at any non-terminal state) and `--refine` (answer it; `NEEDS_INFO` → `DRAFT` once no blocking question is left open).
- The terminal feature states are `CANCELLED` and `SUPERSEDED`. A legacy `DEPRECATED` reads as `CANCELLED`.
- A terminal feature is never proposed as pending work.

## Verification record

- **Red first.**
  - `scripts/test-templates-static.sh` has a new "CODESIGN exits" block with three checks: the terminal-feature exclusion in next-task, NEEDS_INFO → DRAFT in `--refine`, and neither retired flag in `codesign.md`. All three were red before the edits (`L1: FAIL — 3 assertion(s) failed.`) and are green after them.
  - With the new config applied to the pre-change tree, `gate.py retired-terms` reports `FAIL — 25 occurrence(s)`. A planted line was red once per pattern, a line saying "legacy" passed, and `docs/spec/**` stayed silent.
  - `scripts/materialize-synthetic.sh` plants a legacy `docs/spec/F-OLD/spec.feature` (`status: DEPRECATED`, citing `/codesign --deprecate`) and expects green; it was red with the exemption removed. It also plants the same order in `docs/old-order.md` and expects red, with the file named.
- **Green:**
  - `gate.py retired-terms`, `check-command-flags.py`, `check-lockstep-pairs.sh`;
  - every T2 suite in `governance-check.yml`;
  - both synthetic fixtures (default: 117 passed);
  - `gate.py manifest --check` on the touched entries, `manifest-parity`, `discovery`;
  - `gate.py profile --run --base origin/main`.
- **Deviations:**
  - No gate code changed: the existing `retired-terms` reader expresses both patterns.
  - The meta orders entry also exempts `scripts/materialize-synthetic.sh`, which plants the retired order on purpose.
  - A NEEDS_INFO fixture adds nothing mechanical, because the transition is an instruction the agent follows. The static case holds the text of the transition.
