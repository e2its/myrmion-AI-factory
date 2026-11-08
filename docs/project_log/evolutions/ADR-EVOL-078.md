---
id: ADR-EVOL-078
title: "Artefact coherence tightening — the journey agrees with itself, a PO return is judged on its diff, every increment exits on measurable criteria"
date: 2026-11-08
status: accepted
---

# ADR-EVOL-078: Artefact coherence tightening

## Context

This ADR implements issue #132 (epic #112, Wave 3). It was verified on `main` at framework 9.1.0.

- **The journey diagram is only present, not right.** `scripts/check-journey-grammar.sh` § 8b asks that Section 2 carry a mermaid `journey` block. It never compares the block with the steps. A diagram can show three steps scored 5 while the steps say two, scored 2 and 4.
- **The header is not compared with the body.** The frontmatter `feature_id` and `scope` are checked for presence and vocabulary only.
- **Emotions are checked for format only.** `Feels` must be `N/5`. Nothing ties a low score to a named pain, a pain to its ease, or a pain to the Section 4 map.
- **A PO return is judged on what it did not change.** `subproducts/po-package/validate_po_return.py` judges every returned file whole. A finding already present in the repo's synced copy comes back to the PO as if the PO had made it.
- **Increments have no measurable exit.** The increment template's `Acceptance` items are generic prose («All assigned scenarios pass E2E»), and INC-2 says «(same checklist as INC-1)». The templates contain no exit criterion that a reader can measure on its own.
- **A missing estimate only warns.** CVP Check 21 `surface_declared` is a WARNING. An increment without its estimate reaches the push, where the real surface is measured, with the work already built.
- **#120** mapped the downstream class «drift from the journey» to DC-34. DC-34's gate column does not name the journey check.

## Decision

### RDR — the severity of a missing estimate (2026-11-08)

Options posed:
1. **Blocking and mechanical:** a rule in `gate.py train`, which CVP Check 21 delegates to, CRITICAL at `BLUEPRINT --approve` and at push.
2. WARNING, as today.
3. Retire Check 21: the push measures the real surface.

Recommendation: 1. The split RDR needs the estimate before building. Surviving risk: an old plan touched again must add its estimate. Owner's choice, verbatim: «1 Bloquear, mecánico».

### RDR — which increments the exit and surface clauses judge (2026-11-08)

Raised by the round-1 critics: a plan written before 9.2.0 has BUILDING or MERGED increments with prose acceptance and no estimate, and the immutability policy forbids editing them — the first touch of such a plan would be red with no cure short of `CODESIGN --revise`.

Options posed:
1. **Skip frozen increments:** (h) and (i) skip an increment whose `**Status:**` is BUILDING or MERGED; DRAFT, READY, INVALIDATED and an absent status are judged.
2. Judge only the increments whose section the diff changes.
3. Judge every increment, as delivered in round 1.

Recommendation: 1 — one condition, consistent with the immutability policy; clause (e) already reads MERGED. Surviving risk: a frozen increment whose criteria were never measurable closes unmeasured. Owner's choice, verbatim: «1 Saltar congelados».

### RDR — `external-deps` on the diff judgement (2026-11-08)

Raised by the round-1 security critic: the exemption rests on «raised at the next CODESIGN gate», which is false for `external-deps` — the host allowlist is enforced only by the PO validator, so a tightened allowlist would never bite on an already-synced mock.

Options posed:
1. **Always judge it:** drop `external-deps` from the subtractable checks.
2. Keep it exempt, and name every left-out finding in the report.
3. Add an external-host check to CODESIGN auto-approval, and keep the exemption.

Recommendation: 1 — the smallest change that keeps the one enforcement point. Surviving risk: after an allowlist tightening the PO sees old errors in their mock. Owner's choice, verbatim: «1 Always judge it».

### 1. The journey agrees with itself (`scripts/check-journey-grammar.sh`)

Three clauses join the one journey check. No new script, and no new gate.

- **8c — the diagram matches the steps.**
  - Every Section 2 `journey` block is read. Each task line is `label: score: actors`, and its score is 1..5.
  - Tasks are grouped by their first actor, which is the persona. A persona's task count equals its `### Paso` count.
  - The k-th task's score equals the `Feels` of that persona's k-th step.
- **1b — the header matches the body.**
  - `feature_id` equals the H1 id (`# User Journey: {id} — …`).
  - A UI scope has at least one `#step-N` Mock Action.
  - When `spec.feature` is present and declares `scope:`, both scopes are equal.
- **5b — the emotions hold their invariants.**
  - `Feels` ≤ 2 names a `Pain`.
  - A `Pain` names its `Ease`.
  - Every step with a `Pain` has a Section 4 row, and every Section 4 row names an existing step with a `Pain`.

The LAW-16 tripwire (§ 10) is unchanged. The messages carry business words only. This script is DC-34's journey gate, the one gate of the journey-drift class.

### 2. A PO return is judged on its diff (`validate_po_return.py`)

- **The last synced version** is what the repo holds: `features.spec_root/{F}/` and `design_system.vision_root/`. `/codesign --sync` is its only writer.
- **The comparison.** The validator runs the content checks on the return, then runs the same checks on the repo's copy of each returned file, with the same ERQ. A finding with the same place, check and message in both was already there. It is left out, counted and stated: «N finding(s) left out: unchanged since the last sync». In JSON it is `outside_diff`.
- **Only content checks are compared.** These are `gherkin`, `journey-grammar`, `name-new-undeclared`, `field-new-undeclared`, `a11y-basics`, `mock-states`, `vision-tokens-declared`, `vision-components-parseable` and `vision-component-undeclared`. Structure, manifest, ERQ, zip safety, self-check, infrastructure, `vision-files` and `new-name-unjustified` are about the return itself, so they are always judged. `external-deps` is always judged too: this validator is the host allowlist's one enforcement (RDR above).
- **A new feature** has no repo copy, so all of it is diff.

### 3. Every increment exits on measurable criteria (`gate.py train`)

`gate.py train` already reads every changed `increment_plan.md`. Two clauses join it.

- **(h) exit criteria.**
  - Each INC's `**Acceptance` block carries at least one item of its own (`- [ ]` or `- [x]`).
  - Each item names its measure in backticks: a scenario, a contract operation, a case id or a command. An empty span or a `{{placeholder}}` is no measure.
  - A scenario title or a contract operation in backticks must be the INC's own (`Scenarios covered`, `Contract surface`). An item that measures another INC's delivery is red.
- **(i) surface declared** (the first RDR above). Unless the plan is `slicing_strategy: monolithic`, every INC carries `Estimated surface:` with `~files` and `~lines`, and every `SUB-` row its `~files · ~lines`.
- **Every changed plan is judged**, with or without sub-increments. An INC whose `**Status:**` is BUILDING or MERGED is skipped: a frozen increment is never edited (second RDR above). Each problem opens with its clause, `(h)` or `(i)`.
- **The template.** `increment_plan_template.md` names the block «Acceptance — exit criteria (each measurable on its own)», writes every item with its measure, and gives INC-2 its own list.
- **CVP.** Check 13 delegates its mechanical layer to (h). Check 21 becomes CRITICAL, joins the `BLUEPRINT --approve` scope and the push preflight subset, and delegates to (i). `Factory-blueprint-design` self-verify and `rules/vertical-slicing.md` say the same.

### 4. DC-34 names the journey gate

- **Gate:** `scripts/check-journey-grammar.sh` (the row names it; the annex in `rules/defect-prevention-cases.md` says what it checks — the row's cell is held by the pre-edit delivery budget).
- **Paths:** `docs/spec/**/user_journey.md`.
- **Applicable To:** CODESIGN.

## Consequences

- A journey whose diagram, header or emotions contradict its steps is red at CODESIGN approval. It is also red wherever CVP runs the journey check (BLUEPRINT, IMPLEMENT), and in a PO return.
- A PO hears only about what the PO changed. A finding that predates the return stays a finding of the repo's copy, raised at the next CODESIGN gate — except an external reference, always judged.
- An increment plan is red at push when an exit criterion names no measure, measures another increment, or an increment has no estimate.
- **Installed projects** get the checks through `factory-sync.sh`, and the templates and `po-package` through `SETUP --upgrade`. No discovery question is asked. An approved journey or plan that nobody touches is not re-judged by the push gate. A refine runs the check, and the artefact is fixed in that refine.

## Residual risks

- **A measure is checked for its form, not its truth.** A backticked command that does not exist passes (h). The lens and the verify gate judge whether the criterion was met.
- **The diagram match is positional per persona.** Two steps of one persona swapped in the diagram with equal scores pass. Labels are free text and are not compared.
- **The diff is found by comparing findings, not text.** A step renumbered by an insert makes old findings look new. A file-level finding (an image without `alt`) the copy already carries hides a second one the return adds; both are warnings.
- **A frozen increment is not re-measured.** One approved before 9.2.0 with prose criteria closes as it was written. The status is the plan's own word, as for clause (e): a new increment marked BUILDING dodges (h) and (i), and only the plan's review sees it.

## Alternatives considered

- **A line diff of the returned files.** Rejected: a finding is not tied to a line, and a file-level finding would have no diff to anchor it.
- **A new member for exit criteria.** Rejected: `gate.py train` already reads every changed plan, and a member per field is a second reader of one artefact.
- **Grandfathering approved journeys.** Rejected: the issue does not want a journey that passes while its diagram contradicts its steps.

## Operational Rule

No new law. Every law sentence in `CLAUDE.md` is unchanged. The light-profile member line in `CLAUDE.md` now names what `train` judges. The other changes are script, template, skill and instruction edits, each with its manifest bump.
