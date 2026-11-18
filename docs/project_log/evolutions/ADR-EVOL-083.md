---
id: ADR-EVOL-083
title: "Change in flight — a change request reopens definition through CODESIGN --refine, and the increment in progress is kept, never discarded"
date: 2026-11-18
status: accepted
---

# ADR-EVOL-083: Change in flight

## Context

This ADR implements issue #137 (epic #112, Wave 5). It was verified on `main` at framework 10.7.0 (7bf2a93).

### State today
- **Two texts disagree about a change that arrives mid-build.**
  - `factory-iteration-model` and `Factory-codesign-feature` say that `CODESIGN --refine` on an APPROVED spec with downstream work classifies each change (Levels 1–3). A DELTA, HYBRID-split or FORCE_DELTA change becomes an iteration of the same feature. `CASCADE_INCREMENT_INTERNAL` then:
    - keeps a BUILDING increment (`Pending iteration`), which completes first;
    - invalidates DRAFT and READY increments;
    - leaves MERGED increments to a follow-up increment.
  - `rules/immutability_policy.md` blocks `CODESIGN --refine` once downstream work exists and forces `--revise`, a new feature version. This appears in its Lock Table, Phases 1 and 2, `check_immutability`, Case 1 «Spec Change During Development», the FAQ and the example log. Case 1 even ends with «pause and work on v2».
  - The result is that a mid-build change can force the increment in progress to be superseded or paused. The issue rejects exactly that.
- **Three more texts stop the lane.**
  - `Factory-implement-build` Step 0a blocks `--build` once the spec iterated, so a kept increment could not finish.
  - The policy's Phase 2 blocks every `BLUEPRINT --refine` on an approved design, so the pending iteration could not be synced.
  - `--revise` claims nothing about an increment in progress, so a pure breaking change could still supersede it.
- **A change request is identified only in the PO-return lane.** The ERQ file is moved to `docs/spec/{ID}/erq/`, and its id rides `erq_id` on the iteration entry (`Factory-codesign-sync`).
- **The increment state is read by no gate.** The lifecycle (`DRAFT → READY → BUILDING → MERGED`, `{DRAFT, READY} → INVALIDATED → DRAFT`) and its monotonicity live only in LLM pseudocode (`check_increment_immutability`). `gate.py train` reads `**Status:**` only to skip frozen increments, so an unknown state passes silently.
- **Owner RDR «1» (2026-10-19, issue #137):** no new command or flag (meta `CLAUDE.md` §4). The change goes through `CODESIGN --refine` and the iteration model's cascade, and the increment stays on its branch. #117 retired the ghost flags `--pause` and `--override`.

## Decision

1. **One home for the lane: `factory-iteration-model` § Change in flight.** It holds:
   - **Entry.** `CODESIGN --refine {ID} "<change>"`, whoever brings the change: the person in the repo, or a PO return through `--sync`.
   - **Record.**
     - The change request id is `ERQ-{ID}-{NN}`, one family for both lanes. In the repo, NN is the next number over the feature's recorded `erq_id`s.
     - The id is written on the iteration entry (`erq_id`), with its `changes` and `classification`.
     - A Level-3 choice (HYBRID: SPLIT, ALL_REVISE or FORCE_DELTA) is an RDR, recorded as `source: rdr-ratification`.
     - The canonical entry shape gains `erq_id`.
   - **Effect.** The cascade's per-status table is unchanged:
     - BUILDING is kept on its branch, with `Pending iteration` and a `Pending reason` naming the ERQ id; it completes, then `IMPLEMENT --refine` takes the change;
     - DRAFT and READY become INVALIDATED;
     - MERGED gets a follow-up increment.
   - **REVISE (pure breaking).** The increment in progress still completes first, under the one-active-version rule. Discarding it is only the person's own `--cancel`, never forced.
2. **`gate.py train` reads the state.** Both clauses run on every changed increment plan, frozen increments included.
   - **(k) state known.**
     - Each `### INC-N` carries a `**Status:**` in `DRAFT | READY | BUILDING | MERGED | INVALIDATED`.
     - Each `SUB-` row carries a `status:` in `READY | BUILDING | MERGED`.
     - An absent or unknown value is red.
     - `**Pending iteration:**` is `null` or a positive integer, and is non-null only on BUILDING or MERGED. An increment not yet in progress is invalidated, not kept pending.
   - **(l) kept in progress.** The clause reads the plan at the merge-base with the diff base.
     - An INC or SUB that was BUILDING still exists and is BUILDING or MERGED.
     - One that was MERGED still exists and is MERGED.

     - An INC that this change marks INVALIDATED or drops (DRAFT or READY at the base) while a `feature/{ID}-inc-N-…` branch of it, its own or a sub's, is not merged into HEAD. BUILDING is written on the increment's own branch, never on the main branch, so a change cut from main sees READY: the open branch is what says the increment is in progress.

     A plan with no base version is not judged by the plan comparison.
   - **Placement.** No new gate and no new member: `train` already runs at the push, at the static round and in CI. The new row is `{FEAT} states`.
3. **One behaviour everywhere (LAW-17).**
   - `immutability_policy.md` admits `CODESIGN --refine` on an approved spec as a classified iteration and requires `--revise` only for REVISE. Case 1 is rewritten as a DELTA iteration with the increment kept.
   - `increment_plan_template.md` cites the lane on `Pending iteration` and gives invariant 5 its mechanical layer.
   - The CODESIGN refine step, the control-point rows, the README and the docs-sync checklist cite the one home.
   - `Factory-implement-build` Step 0a lets the kept increment finish on its iteration; the Delta refine clears its `Pending iteration` once it took the change.
   - The policy admits a downstream `--refine` that syncs a pending iteration (Phase 2, Phase 3, `check_immutability`), and the IMPLEMENT Approved row admits the classified iteration (a merged increment gets a follow-up increment).
   - `--revise` is blocked while an increment is in progress (policy and `Factory-codesign-feature`); the person may `--cancel` it.
   - The cascade binds `erq_id` from the spec's latest iteration through the one reader, and records an increment with an open branch as BUILDING before it decides.
   - The QA-certified row keeps `--revise`: after QA certifies, no increment is in progress, and the Follow-up Increment Rule already closes its window there.

### Alternatives rejected
- **A `--pause` or `--override` flag.** Rejected by the owner (RDR «1») and by meta `CLAUDE.md` §4. The existing commands carry the lane.
- **A new gate member for the state.** `train` is already the reader of increment plans at every control point. A second reader of the same file would be two homes.
- **An ERQ file in the repo lane.** The iteration entry already holds the change, its classification and the RDR. A second artefact would restate it. The PO lane keeps its file because that file is the PO's own artefact.

## Consequences
- A change that arrives mid-build no longer forces a new feature version. The increment in progress completes on its branch, and the change lands after it.
- An increment plan with an unrecorded or unknown state is red at the push. So is a plan whose increment in progress was discarded or whose merged increment regressed.
- **Delivered by materialisation.**
  - Framework core (skill, instructions, gates) reaches every project through `factory-sync.sh`.
  - The rule template and the plan template reach projects through `SETUP --generate` and `--upgrade`.
  - The state vocabulary is unchanged, so `--upgrade` needs no step.
  - No discovery question.

### Honest limits
- (l) compares the plan at the merge-base with the plan on disk. A branch that adds and discards an increment in progress inside its own commits is not seen.
- The open-branch read sees only the refs this clone knows (local and fetched remote branches). A branch never fetched is not seen; CI sees what its checkout fetched.
- A plan renamed or deleted is not judged. A git fault or timeout reading the base skips the plan comparison, and an unreadable ref list skips the branch read; the row note says so.
- The cascade's overlap judgement (which increments a change touches) is agent-executed. The gate checks the outcome, not the judgement.
- A plan written before states were recorded goes red at its next change, with a message naming the missing state.
- Two lanes number ERQ ids: a PO return brings its own NN. A collision with an in-repo NN is not checked mechanically.
- The policy's typo exception for `--refine` on an approved spec is gone: every change is classified, and a typo is a DELTA iteration.
- Plans held only in an External home are not read by `train` today (EVOL-080). (k) and (l) inherit that limit.
- That a `Pending iteration` names a recorded iteration is not checked mechanically. The record is the iteration entry that CODESIGN writes.

## Verification
- Red first against 10.7.0: `Train.test_a_change_in_flight_keeps_the_increment_in_progress` and `Train.test_an_unknown_increment_state_is_red`. Red first against the first cut: `Train.test_an_open_increment_branch_is_in_progress_whatever_the_plan_records` and the hardened state tokens.
- The synthetic materialisation's sub-increment plan records its states, and the profile run stays green there.
- The shipped plan template passes (k).
- The ghost-flag check (`scripts/test-check-command-flags.sh`) stays green.
