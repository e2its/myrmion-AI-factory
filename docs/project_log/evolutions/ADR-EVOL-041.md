---
id: ADR-EVOL-041
title: Journey-first — user journey redesign, CODESIGN business purity, machine-anchored experience spec
date: 2026-08-15
status: accepted
---

# ADR-EVOL-041: Journey-first user journey redesign

## Context

A three-agent diagnostic @ main fcef19d confirmed the thesis: the artefacts named "user journey" are not user journeys. `user_journey_template.md` (184 L) and `user_journey.integration.md` (203 L) are Event-Storming data-contract documents — step = Actor/Command/Event/Screen/DataIn/DataOut, saturated with implementation detail (`decimal(18,2)`, `JWT`, `mTLS`, FE/BE tiers in mermaid, SIGTERM). Experience vocabulary across ~30k lines of governance: `pain point` 0, `emotion` 0, `empathy` 0, `delight` 0. The only personas live in `design_ux.md` — a template verified 100% orphaned (0 generators, 2 self-labelled "legacy" readers, 18 dangling refs, untouched since the initial commit). The `### Paso N` anchor shipped as "parser-canonical" (EVOL-027) is validated by no executable. E2E/smoke runs on 4 disjoint anchoring models, including an invented `US-N.M` grammar matching nothing upstream. 20 concrete drifts catalogued (D1-D20), several hard-blocking backend-only features today (smart-redirect dead-lock, ~15 gates hard-coded to `user_journey.md`). Zero generated instances exist in this repo.

Binding user principle (PRINCIPIO-0, verbatim): "quien usa codesign solo sabe y puede validar negocio. el resto de cosas que se generen fuera de ahi van a ser validaciones falsas." MASS-fork convergence explicitly discarded as a criterion.

## Decision

One EVOL, seven RDR-ratified decisions:

- **DEC-1 — Single file, 100% business.** One `user_journey.md`: Part I Experience (personas, steps with Goal/Does/Sees/Feels 1-5/Pain/Ease, mermaid `journey` per persona, named paths, machine anchors step→BDD scenario and step→mock action) + Part II Conceptual Domain Contract (actions/outcomes, business fields as name+meaning+obligation+plain-language values, business rules, third parties & guarantees). Zero technical types, tiers, or protocols.
- **DEC-2 — Absorb the integration variant.** One template, one output filename for all scopes. Backend scopes: personas = business callers; reliability expressed as business guarantees; the technical Reliability Contract migrates to `design.md`. `user_journey.integration.md` dies. Kills drift classes D8/D9/D10/D14/D15 at the root.
- **DEC-3 — Business field table + real § 7.4.** Journey Part II field grammar: `Campo | Significado | Obligatorio | Valores posibles | Ejemplo` (plain language). `design_template.md` GAINS § 7.4 Schema Constraints (previously a phantom section the BLUEPRINT instruction wrote but the template lacked) as the machine typing record (`locked_fields`). Existence authority (H-15) reads the journey; typing authority (H-11 and all type consumers) reads design § 7.4.
- **DEC-4 — E2E/smoke anchors on test cases; journey contributes route composition.** SMOKE-{N} = one journey path expanded transitively step→scenario→TC. `US-N.M` and `TC-UX-XX` phantom grammars die; test_plan ID grammar unified; CVP gains the transitive journey↔test_plan link.
- **DEC-5 — Deterministic grammar validator + semantic CVP.** New `scripts/check-journey-grammar.sh` (+ SETUP-delivered template mirror, lock-step pair) born with a red-proving self-test. CVP journey checks re-scoped to semantics only, consuming the script's mechanical verdict.
- **DEC-6 — `design_ux.md` deprecated and purged** (validated 100% legacy). Personas/experience goals absorbed by journey Part I; 18 dangling refs redirected or removed.
- **DEC-7 — All 20 drifts ride in this single EVOL** (user verbatim: "todo en un solo evol"), D1 and D18 included.

## Consequences

- `user_journey_template.md` takes a MAJOR (2.0.0): the Event-Storming step grammar is replaced; Section 3 typed Data Schemas are replaced by the Part II business field table. Downstream projects with v1 instances migrate at their own realignment pace (framework ships no instance migration — this repo has none).
- `user_journey.integration.md`, `design_ux.md`, `smoke_e2e_integration_template.md` manifest entries are REMOVED.
- `design.md` becomes the sole technical formalisation point: § 7.4 Schema Constraints (new, real), § Reliability Contract (migrated), § technical sequence diagram (migrated).
- PO sign-off becomes meaningful by construction: every signed statement is business-verifiable (LAW-16).
- The smoke gate keeps its position (DEVOPS dev-deploy → QA --verify) but its blocks are journey paths expanded to test-plan TCs — one ID space end to end.
- `framework_version` 5.9.0 → 5.10.0 (MINOR per INVARIANT 1, feature branch; the breaking surface is carried by the template entries' own MAJOR bumps).

## Alternatives considered

Experience-only artefact (contract fully to BLUEPRINT) — rejected: strips the PO of field-existence authority, the one thing they CAN validate (inverts H-15). Two CODESIGN files — rejected: same signer, no validation gain, doubles LAW-09/IPP/hook wiring, repeats the design_ux orphan pattern. Keep two journey templates — rejected: the dual-filename split is the proven root cause of drift classes D8/D9/D10/D14/D15. LLM-only validation — rejected: fail-open drift class (D2/D3/D13) stays alive; machine-verifiable anchors require an executable. Semantic types retained in journey — rejected: partial PRINCIPIO-0 violation, signer still signs types they cannot validate.

## Operational Rule

Constitutional amendment shipped in this PR: new universal **[LAW-16] CODESIGN Business Purity** added to the Governance Rules corpus of BOTH CLAUDE.md files (law_corpus_mirror). See `CLAUDE.md` + `.context/templates/setup/claude/CLAUDE.md`.
