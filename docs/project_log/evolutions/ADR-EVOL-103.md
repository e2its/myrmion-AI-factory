---
id: ADR-EVOL-103
title: "An accepted change aligns its artefact in the same pull request and is never reverted"
date: 2026-10-23
status: accepted
---

# ADR-EVOL-103: An accepted change aligns its artefact

## Context

This ADR implements issue #161 (epic #112, train row 5d, with #163 / ADR-EVOL-105). It was verified on `main` at framework 8.18.0.

- **No home for an accepted divergence.** The build loop's schema gate (Factory-implement-build § Law 6) already asks «accept the divergence or align with the authority». An accepted divergence leaves no record that a later reader, gate or critic can find, and nothing aligns the artefact.
- **"Decision log" and "standing delegation" are defined nowhere.** The closest record is the feature's worklog (`docs/project_log/features/{FEAT}.log.jsonl`, factory-worklog).
- **The fix flow is blind to it.** The `--fix` Scope Guard separates a bug fix from new behaviour. It never aligns the artefact that a fix contradicts, and it never forbids a revert.
- **The fidelity critic has no disposition.** It reports «specified X, built Y» and nothing more, so the natural cure is to revert the code.
- **A realignment costs a re-approval.** BLUEPRINT `--refine` leaves re-approval to `/blueprint --approve` whenever scope moved (Factory-blueprint-refine «Before exit»). CODESIGN refine drops `APPROVED → DRAFT`.
- **No gate compares a pull request with its artefacts.** No law sentence covers this. The next universal id is LAW-17.

## Decision

1. **One law.** `[LAW-17] Accepted change aligned`. The sentence is byte-identical in both CLAUDE.md files (`law_corpus_mirror`). Its body is `rules/branching.md § [LAW-17]`, next to the planning stage.
2. **One definition, in that body.**
   - **Accepted** means ratified by the user (the RDR's verbatim choice), or decided under a standing delegation and recorded in the decision log.
   - **Standing delegation** is an owner instruction that names a class of decisions the agent may take without asking. It is quoted verbatim with its date.
   - **Decision log** is the feature's worklog. An accepted change is one entry of `action: accepted-change` with these fields:
     - `id`: `AC-{FEAT}-{N}`.
     - `artefacts`: the written artefacts it contradicts.
     - `paths`: the code paths that carry it.
     - Exactly one of `rdr` (the verbatim choice) or `delegation` (the verbatim quote and its date).
3. **Same pull request, owner phase.** Each artefact type aligns through the phase that owns it:
   - Scenario, journey and mock: CODESIGN `--refine`.
   - Design and test plan: BLUEPRINT `--refine`.
   - A contract: its freeze.
   - A rule body: a rule-file edit plus a manifest bump.

   A form-only realignment (copy, layout, design-system vocabulary) cascades nothing. Every such spawn is an **alignment pass** (ADR-EVOL-105) whose `aligns:` names the entry id.
4. **Pre-approved realignment.** A refine records its iteration (LAW-09) with `changes: [{kind: accepted_change, ref: AC-…}]`. When every change of that iteration is of this kind, the artefact keeps `APPROVED`: no return to draft, no new approval. Any other change kind still goes through the approval gate.
5. **Fixes included.** The `--fix` Scope Guard and the build loop's divergence RDR do three things:
   - record the entry;
   - align the artefact in the same pull request;
   - never revert an accepted change to match a stale artefact.

   An accepted divergence is no longer left behind as a backlog issue.
6. **Critic.** The fidelity critic reads the decision log. A divergence that an entry covers is reported 🔴 `align the artefact` (blocking until aligned), never as a revert. The disposition lands in today's definition; #177 later moves it into the question catalog.
7. **One gate, `gate.py aligned`.** It is a new module, `scripts/gates/aligned.py`, lock-step with its template. It is a light and full profile member and needs no build. For every `accepted-change` entry that the branch adds to the decision log, it reports red when:
   - (a) the entry carries no `rdr` and no `delegation`;
   - (b) an artefact it names is not in the diff (**a stale artefact left in the pull request**);
   - (c) its `paths` equal the diff base (**a revert of an accepted change**);
   - (d) an artefact that was `APPROVED` at the base is not `APPROVED` at HEAD, while its latest iteration holds only `accepted_change` changes (**a registration-only realignment that drops the approved status**).
   - (e) a changed artefact's latest iteration carries an `accepted_change` whose `ref` names no ratified `accepted-change` entry in the decision log, whether this branch added it or an earlier one did (**a registration-only claim with no accepted change behind it**). Owner RDR «1», 2026-10-23, after the round-1 governance critic: «opcion 1».

   The gate judges every decision log the diff changes (`docs/project_log/features/*.log.jsonl`), whatever the branch is called, so a fix branch is judged too; the feature id comes from the log's file name. Owner RDR «1», 2026-10-23, after the round-1 correctness critic: «1».

   A branch with no decision log, such as this repo, is `n/a`. The block is humanised (LAW-08).

## Consequences

- An accepted change is recorded once, in the decision log. A gate, the critic and the next reader all find it there.
- The gate's checks are mechanical. The critic is still needed to classify a divergence that has no entry yet, and that judgment remains an LLM call.
- No new SETUP question and no new config key: the gate has no threshold.

## Alternatives considered

- **A separate `decisions.jsonl`.** This would be a second audit trail next to the worklog. Rejected (DC-29).
- **Revert detection by content hash at acceptance.** Any later legitimate edit to those paths would trip it. Rejected; «the paths still differ from the base» is enough.
- **A check-return rule on the critic's text.** This would need the log at check time and would judge prose. Rejected; the gate checks the record instead.

## Operational Rule

`[LAW-17] Accepted change aligned` — An accepted change aligns every written artefact it contradicts in the same pull request through the artefact's owner phase, and nothing reverts an accepted change to match a stale artefact. Body: `rules/branching.md`. Records: `ADR-EVOL-103`.

## Verification record

Red first, then green: `test_gates.py::Aligned` — (a) unratified entry, (b) stale artefact, (c) reverted paths, (d) registration-only realignment that drops APPROVED, (e) a registration-only claim whose `ref` names no ratified entry, a changed log judged on a fix branch, a proper entry green, no decision log n/a. The rule body also routes an external `--sync`, a contract re-freeze and a file-only artefact (owner phase). `gate.py aligned` is a light and full profile member. `gate.py laws --parity` and lock-step pass on LAW-17. Delivery: `factory-sync.sh` brings the gate; `SETUP --upgrade` brings `rules/branching.md` and the project CLAUDE.md entry.
