---
id: ADR-EVOL-069
title: "Decision and loop hygiene — a decision stays an RDR under auto mode, approved frontmatter is locked, a premise is checked at its source, an orphan ADR is caught"
date: 2026-10-20
status: accepted
---

# ADR-EVOL-069: Decision and loop hygiene

## Context

This ADR implements issue #123 (epic #112, train row 5a, with EVOL-065). It was verified on `main` at framework 8.15.0.

- **Auto mode.**
  - `planning.py` records a plan approved in `auto` mode on purpose, because the plan dialog still asks the user (observed 2026-10-08).
  - No rule says that a decision still goes through an RDR while auto mode runs the execution.
- **Approved frontmatter is not locked.**
  - The frontmatter of an approved artefact is read only at HEAD (`common.read_frontmatter`). Nothing compares it with the base.
  - The flows rewrite it legitimately and often:
    - CODESIGN refine flips the status `APPROVED → DRAFT` and back;
    - a cascade sets `pending_iteration`, `cascade_*` and `invalidated_*`, or flips the status to `INVALIDATED`;
    - the build moves `BUILDING → IMPLEMENTED_AND_VERIFIED` and the counters;
    - every iteration append touches `iterations` and `_progress`;
    - the DEVOPS approval writes `approved_at` and `approved_by`.
- **The plan critic does not check premises.** Its remit covers coverage, deployability, reachable cases and invented business facts. It does not check that a premise holds at a source. The lens canary (EVOL-059) covers the four work critics, not the plan critic.
- **No check catches an orphan ADR.** In this repository one accepted ADR (ADR-EVOL-031) is named by no other tracked file.
- **Not a defect: a review loop that does not converge.** `rounds.work` and `rounds.plan_gate` already bound every loop and hand the leftover to the user. No detector is added (DC-29).

## Decision

1. **Auto mode runs execution; a decision is still posed as RDR.**
   - The sentence enters the `RDR Universal` section of both `CLAUDE.md` files. The `universal_clause_mirror` pair holds them identical.
   - A vocabulary assertion in the meta suite turns red when the sentence is missing.
2. **Approved frontmatter changes only through its transitions.**
   - `gate.py frontmatter-lock --base` (`scripts/gates/frontmatter.py`, lock-step twin) is a profile member. It needs no build, so it is light and full. It reads every markdown or `.feature` file changed in the diff whose frontmatter `status` was approved at the base (`planning.APPROVED_STATES`). It compares the base frontmatter with the HEAD frontmatter.
   - A key that was added, removed or changed is red, unless it is one of the following:
     - the **iteration state** (LAW-09): `iterations`, `iteration`, `iteration_history` (legacy, read by the one iteration reader), `last_iteration_scope`, `pending_iteration`, `pending_reason`, `cascade_source`, `cascade_timestamp`, `cascade_scope`, `invalidated_sections`, `invalidated_increments`, `invalidated_slices`, `invalidated_by`, `invalidated_by_iteration`, `invalidated_reason`, `invalidated_at`, `pending_schemas_version`, `schemas_version`, `based_on_iteration`, `based_on_schemas_version`, `delta_mode`, `delta_tasks_added`;
     - the **build counters**: `increments` (dev_plan's per-increment status mirror), `total_tasks`, `tasks_completed`, `tasks_skipped`, `tasks_total`, `completed_at`, `verification`, `fix_cycle`, `fix_tasks_added`;
     - **persistence:** `_progress`, `updated_at`, `last_update`;
     - **approval:** `approved_at`, `approved_by` (#134);
     - **`status`**, moving to a value of the closed state vocabulary.
   - **A refine owns any key:** when the diff appends an iteration (LAW-09), read through the one reader `common.iteration_state`, every key may change. The status still moves only within the vocabulary.
   - The permitted set is one constant in the gate module. The iteration-model skill (LAW-09's body) names the lock and points at it.
   - #155 adds its delta-header `state` key to the set when it lands, in its own change.
3. **A premise is checked at its source.**
   - **The plan critic's remit:** every open premise of the plan is either verified at a source the critic can read, a repository file or a contract cited `file:line`, or returned unverified (🟡, `❓ unverified`).
   - An external premise (a library, a service, a provider) always comes back `❓ unverified — external`. The main session routes it to the docs reader, and the critic spawns nothing.
   - **The canary:**
     - the canary fixture gains a plan file with two planted defects: an external premise stated as verified, and a premise that a fixture file contradicts;
     - `canary.LENS_AGENT` gains the `plan` lens (`factory-plan-critic`);
     - the plan gate's spawn site asks `gate.py canary --plan` as the work rounds do.
4. **An orphan ADR is caught.**
   - **Direction C of `check-adr-constitution-sync.sh`:** an ADR added or modified in the diff, with status accepted, must be named by another tracked file. A project ADR is named by its id (`ADR-{N}`). A framework one is named as `ADR-EVOL-N` or `EVOL-N`.
   - Every orphan in the tree is listed as a notice, so an upgraded project's history never turns red.
   - ADR-EVOL-031 is cured with a reference where its rule is stated.

## Consequences

- **What stays legitimate:** a refine, a cascade, a build tick and an approval stay green. Any other edit to an approved artefact's frontmatter needs the phase's refine, which owns that change.
- **The plan critic is calibrated** like the work critics, and a red verdict never blocks (EVOL-059).
- **Upgrade path:**
  - `factory-sync.sh` delivers the gate, the canary, the plan critic and the skills.
  - `SETUP --upgrade` delivers the template `CLAUDE.md` clause and the profile member through the template scripts.

## Alternatives considered

- **A transition machine per artefact type.** Rejected (DC-29): the flows already define the transitions, and a key set with a closed status vocabulary catches every edit outside them.
- **A required-phrase mechanism in the lock-step checker.** Rejected: one assertion holds one sentence, and the mirror already holds both copies identical.
- **An orphan check over the whole tree, blocking.** Rejected: it would turn every upgraded project red for its history.

## Operational Rule

Auto mode runs execution, and a decision is still posed as an RDR. An approved artefact's frontmatter changes only through its permitted transitions. A plan premise is verified at a source or returned unverified. An accepted ADR is named by the record that uses it.

## Verification record

- **Red first:**
  - `test-materialization-surface.sh` group 7 → «RDR Universal lacks the auto-mode sentence», on both `CLAUDE.md` files.
  - `test_gates FrontmatterLock` → an import error, then failures. A later case for `iteration_history` failed until the key joined `PERMITTED`.
  - The canary test → there was no `plan` lens.
  - `test-check-adr-constitution-sync.sh` scenarios 14 and 15 (direction C, red and notice) → red.
- **Green:**
  - `test-gates.sh`: 136 tests;
  - the ADR-sync test: 15 scenarios;
  - `test-materialization-surface.sh`: 7 groups;
  - lock-step: 82 files;
  - `gate.py agents`, `canary --check`, `budget`, `manifest-parity`, `retired-terms`, `profile --run --control-point static`;
  - `frontmatter-lock --base origin/main` is ok on this repository;
  - `materialize-synthetic.sh`: an approved `design.md` with `scope` changed → red, with an `iterations` entry appended → green.
- **Deviations from the Decision:**
  - **What the lock compares:** the working tree against the merge base, like `digests.changed_paths`. The static round therefore sees uncommitted edits.
  - **The plan lens is owed by class:** a plan-critic spawn owes only `plan`, and a work critic never does.
  - **Fixture fix:** ADR-sync scenario 9's fixture ADR was a real orphan under direction C. Its constitution now names it.
  - **Cure:** ADR-EVOL-031 is now named in the README skills section, so the tree has no orphan left.
- **Review round 1, cured red-first:**
  - `PERMITTED` gains the keys the flows rewrite on an approved artefact: `increments`, `last_update`, `last_iteration_scope`, `invalidated_slices` and `pending_design_items`. A test pins every iteration-family key a shipped template declares.
  - A refine that changed a key outside `PERMITTED` was red, though the Consequences say a refine stays green. An appended iteration now unlocks the keys, read through `read_iteration_state` implemented once as `common.iteration_state`.
  - The lock reads markdown and `.feature` files only, so a binary or a YAML file is never a fault.
  - A frontmatter that no longer parses on an approved artefact is red.
  - The plan gate records `canary --seen --lens plan` after every real return, so the drift trigger fires for the plan critic.
- **Review round 2 (the cure only), cured red-first:**
  - `spec.feature` carries an approved frontmatter, so the lock reads it too;
  - tests pin both parse-fault branches: a HEAD that no longer parses is red, a base that never parsed is skipped;
  - the plan gate records `--seen` only for a delivered primary return, never a fallback.
