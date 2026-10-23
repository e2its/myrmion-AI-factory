---
id: ADR-EVOL-104
title: "A train stacks its changes by file"
date: 2026-10-23
status: accepted
---

# ADR-EVOL-104: A train stacks its changes by file

## Context

This ADR implements issue #162 (epic #112, train row 5e, with #184 / ADR-EVOL-115). It was verified on `main` at framework 8.19.0.

- **The split weighs nothing but the ceiling.** BLUEPRINT Step B.4 (Factory-blueprint-design) splits an over-ceiling increment «at task-group / scenario boundaries». Its RDR shows ~files and ~lines per alternative, and nothing about how often a file comes back.
- **A sub-increment row names no paths.** The increment-plan template's row is `SUB-{N}-{M}: {scope} · ~files · ~lines · branch · status`. With no paths in the row, a re-touch cannot be counted.
- **Found work has no landing rule.** The build loop (Factory-implement-build) closes the sub in BUILDING. No rule routes a cure or a close debt to the pending sub that already owns its files.
- **Ledgers.** No instruction orders a manifest or inventory write per sub. No rule keeps a ledger to one write per train either.
- **Gate timing.** No rule orders a concern's enforcing gate after the last sub that touches that concern.
- **Measure.** `measure` reads git only for rework subjects. It reports per train the commits, review rounds and sub branches, never files touched again.

## Decision

1. **The row names its files and its order.** The template's sub-increment row gains these fields:
   - `paths [globs]`: the files it touches, on the push gate's ruler;
   - `after [SUB-…]`: the subs it depends on (dependency order);
   - `concerns [names]`: the concerns its sites carry;
   - `enables [names]`: the concerns whose blocking gate it turns on.
2. **The split groups by file.** Step B.4 stacks the changes a file needs into as few subs as the dependency order allows: a shared component before its consumers, and a concern's enforcing gate after its last site. The RDR shows, for each alternative, the figures that `gate.py train --figures` counts: subs (rounds paid), unique paths, path-touches and re-touch. They sit beside the surface estimate.
3. **One reader: `scripts/gates/train.py`.** It is lock-step with its template, runs as `gate.py train`, and is a light and full profile member that needs no build. It judges every `docs/spec/*/increment_plan.md` the diff changes. It reports red when:
   - (a) **stackable re-touch:** a path glob is listed in two subs where neither is in the other's `after` closure, and the two subs' summed estimate fits both ceilings;
   - (b) **early gate:** a sub `enables` a concern while a sub whose `concerns` carry it is not in its `after` closure;
   - (c) **ledger per sub:** a sub-increment branch's diff touches a path in `config/quality.json → train.close_ledgers` while another sub of its train is not `MERGED`.
   
   Globs are compared as normalised strings. Overlap between two different globs is not judged. The ceilings and the ledger list are keys, never digits.
4. **Found work lands where its files are pending.** A cure, a close debt or a routed task found during a train lands in the pending (`READY` or `BUILDING`) sub whose `paths` cover its files. Only when none exists does the build loop open a new sub, through the split's RDR.
5. **Ledgers once per train.** Every path in `train.close_ledgers` is written by the train-close sub only. The default is the governance manifest and the codebase inventory. The increment plan's status lines stay per sub: they are per-sub truth.
6. **Measured.** `measure` reads each train's first-parent history (one squash commit per sub). Per train it reports the subs, the unique files, the file-touches and the re-touch (file-touches minus unique files, the figure `gate.py train --figures` counts). The before/after window runs in the adopting project.
7. **No new SETUP question.** The ceiling is Q31 and the ledger list is a config key.

## Consequences

- A file is opened, verified and reviewed in as few subs as its dependency order allows. No gate is relaxed, and no sub goes over the ceiling.
- (a) cannot see glob overlap, so the critic still judges two globs that name the same file.
- The plan carries more per row. Those fields are what a script counts.

## Alternatives considered

- **A minimum-re-touch optimiser in the gate.** It would plan in a script what the agent plans and the person ratifies. Rejected (DC-29). The gate refuses only a re-touch that could have been stacked.
- **Derive the sub status from git and stop writing the plan per sub.** That changes the branching skill's contract for no measured gain on this issue. Rejected.
- **A second planning artefact for the stacking.** The issue forbids it. The split's RDR already exists.

## Operational Rule

No new law. The body of `rules/vertical-slicing.md § Trains and the surface ceiling` is edited (a rule-file edit plus a manifest bump).

## Verification record

Red first, then green, in `test_gates.py::Train`:
- (a) two independent subs sharing a glob;
- (a) a shared glob allowed by `after`;
- (a) a shared glob allowed when stacking would exceed a ceiling;
- (b) an enabling sub before a site sub;
- (c) a ledger in a non-last sub's diff;
- n/a without a changed plan.

The measure selftest is red first on a fixture train with a re-touch. Delivery: `factory-sync.sh` brings the gate and the instructions. `SETUP --upgrade` brings the rule body and the template.
