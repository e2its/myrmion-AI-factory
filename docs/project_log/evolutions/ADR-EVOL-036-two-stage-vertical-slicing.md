---
id: ADR-EVOL-036
title: Two-stage vertical slicing — slice_map from CODESIGN, refined by BLUEPRINT, with per-scenario slice immutability
date: 2026-06-15
status: accepted
---

# ADR-EVOL-036: Two-stage vertical slicing — slice_map from CODESIGN + per-scenario immutability

> **Status: accepted (SLICE-5, 2026-06-15).** Landed across 5 vertical sub-slices on `feature/EVOL-036-two-stage-vertical-slicing`. The accept PR carries the governance source (`CLAUDE.md` — Rule 9 extended in SLICE-1) in its diff to satisfy Governance Rule 1 + `check-adr-constitution-sync.sh`. Per RDR-4 no new universal LAW was added — slice immutability extends `immutability_policy.md` + `factory-iteration-model`. Full design: [docs/proposals/EVOL-036-two-stage-vertical-slicing.md](../../proposals/EVOL-036-two-stage-vertical-slicing.md).

## Context

The vertical-slice artefact (`increment_plan.md`, "each increment is a PR that leaves the product 100% functional") is born in BLUEPRINT — slicing is decided after contracts exist. The user asked to bring slicing forward to CODESIGN so slices are framed as user-value verticals from the start, with punctual cross-slice / cross-feature dependencies expressed as explicit ordering + integration seams, and the increment immutability model adapted so the new upstream artefact cannot violate production anchors.

A multi-agent design workflow (12 agents, 3 adversarial lenses) rejected the naïve v1 and forced the hardened model below. EVOL-035 (always-on adversarial reasoning) was applied throughout.

## Decision

Two-stage slicing with a single authority per concern.

- **Stage 1 — CODESIGN** emits a NEW artefact `slice_map.md` (template `.context/templates/codesign/slice_map_template.md`): a **capability-VALUE hypothesis** — which scenarios/journeys form each shippable vertical slice and their user-value order, with independence rationale, cross deps, and integration seams. Slice IDs are `SLICE-{FEAT}-{N}` (bare `SLICE-N` collides with the existing epic-slice `SLICE-N.N`).
- **Stage 2 — BLUEPRINT** refines `slice_map.md` into the contract-aware `increment_plan.md`, mapping each increment to its slice via `cascade_source: SLICE-{FEAT}-N`. BLUEPRINT owns contract-decomposition + feasibility and may re-order ONLY when contract reality forces it, recording the deviation. The monolithic Trivial-Heuristic stays in BLUEPRINT (contracts only exist there).
- **Dependencies + seams.** A cross-slice / cross-feature dependency is an **ORDERING** constraint (ship after predecessor merges), NOT a stub. `depends_on_slice` / `depends_on_feature` + a `seam` (where the dep is consumed). The earlier "modal/fallback" concept was deleted — shipping a stub to prod violates the strict "100% functional with predecessors" rule. `@SLICE` on a monolithic feature resolves to its implicit INC-1.
- **Immutability, one hop upstream (no fork).** Slice immutability is a **per-SCENARIO freeze partition**, not a derived scalar status: `merged_scenarios(slice) = ⋃ scenarios of its MERGED increments`. A re-slice whose diff touches a merged scenario is BLOCKED pre-persist and redirected to a follow-up slice; a `CODESIGN --revise` terminal escape handles genuinely destructive intent. `CASCADE_SLICE_INTERNAL` is forward-only (assignment-delta affected scenarios → delegates to the unchanged `CASCADE_INCREMENT_INTERNAL`, never tripping implicit_touch), acyclic (no write-back to slice_map), and guards the live trigger against double-invalidation.
- **CVP** gains Check 18 (slice↔increment coverage, bidirectional), Check 19 (seam resolution, incl. monolithic-sibling PASS), Check 20 (slice immutability consistency), Check 0d (slice_map presence). Wired at BLUEPRINT --approve AND the push preflight (factory-pr-review Block 8).

Shipped as **5 vertical sub-slices**, each an independently coherent + mergeable PR: (1) slice_map template + Rule 9 + IPP + manifest (inert foundation) → (2) CODESIGN producer → (3) BLUEPRINT refiner + authority migration → (4) immutability one-hop → (5) CVP + push-gate parity + ADR accept.

## RDR Decisions Ratified (2026-06-15)

| # | Question | Choice | Rationale |
|---|---|---|---|
| 1 | Where does slicing originate? | Two-stage: CODESIGN slice_map → BLUEPRINT increment_plan | Slice = user-value unit (CODESIGN domain); contract surface unknown there → BLUEPRINT refines. Single authority per stage. |
| 2 | Cross-slice / cross-feature deps | Explicit declaration + integration seam | Keeps each slice independently shippable; deps mechanical/greppable; extends `consumes_contract`. |
| 3 (C) | Slicing-authority placement | Split: CODESIGN owns capability-VALUE; BLUEPRINT owns contract-decomposition + feasibility veto | One authority per concern; removes double-binding RDR; monolithic heuristic needs contracts (BLUEPRINT-only). |
| 4 (D) | Per-slice immutability law placement | Extend `immutability_policy.md` + `factory-iteration-model` (no new CLAUDE.md LAW) | Goal 3 says "extend the existing MERGED-anchor rule", which already lives there; avoids lock-step mirror burden. |
| 5 (A) | slice_map_template family | `codesign/` (emitting-agent ownership) | CODESIGN owns the artefact; document the cross-family cascade pair in ADR + template header comments. |
| 6 (Check 19) | Cross-feature dep on a monolithic feature | `FEAT-Y@SLICE-Y-Z` resolves to implicit INC-1 → PASS | Author references any feature uniformly without knowing its strategy. |

## Alternatives Considered

- Full slicing authority to CODESIGN (RDR-3 Option B): rejected — no contracts at CODESIGN → premature/infeasible slicing BLUEPRINT cannot fix.
- slice_map purely advisory, slicing stays in BLUEPRINT (RDR-3 Option C): rejected — weakest; slices not first-class; defeats the EVOL.
- Slice immutability as a derived scalar status (design v1, ASSUMPTION-B): rejected by the immutability lens — a scalar rollup is self-contradictory (min vs max) and destroys partial freeze. Replaced by the per-scenario freeze partition.
- "modal" with graceful-degradation fallback (design v1): rejected by the product lens — ships stubs to prod; renamed to ordering-only `seam`.
- New CLAUDE.md universal LAW for per-slice immutability (RDR-4 Option B/C): rejected — lock-step burden; the rule extends an existing one.

## Consequences

**Positives:** slices framed as user value from CODESIGN; single authority per concern; immutability extended without forking the iteration model; each EVOL sub-slice independently mergeable (dogfoods the model).

**Negatives / Trade-offs:** slice_map is a hypothesis BLUEPRINT can override (recorded deviation) — two artefacts to keep coherent (mitigated by CVP Checks 18-20). Cross-family cascade pair (codesign/ → architect/) adds a SETUP --upgrade per-family walk (documented in both template headers). Authority migration must flip ALL old-authority assertions in one PR (SLICE-3) or two artefacts claim the same authority.

## Operational Rule

```
Under slicing_strategy: incremental, CODESIGN emits docs/spec/{FEAT}/slice_map.md —
the capability-VALUE slicing authority (which scenarios/journeys form each vertical
slice; user-value order; independence; depends_on_slice / depends_on_feature; seams).
BLUEPRINT refines it into increment_plan.md, joining each increment to its slice via
cascade_source: SLICE-{FEAT}-N, and may re-order only when contract reality forces it
(deviation recorded). A slice has no scalar status; its freeze is the per-scenario
partition merged_scenarios = ⋃ scenarios of its MERGED increments. A re-slice touching
a merged scenario is blocked pre-persist and redirected to a follow-up slice.
CVP Checks 18/19/20/0d enforce coverage, seam resolution, and immutability consistency
at BLUEPRINT --approve and the push preflight.
```

## Constitution Amendment

> Applied (this ADR is `accepted`, SLICE-5). Rule 9 (Canonical Iteration ID) gained `slice_map.md` in the refine-able-artefact list — done in SLICE-1 in BOTH `CLAUDE.md` and `.context/templates/setup/claude/CLAUDE.md` (Rule 9 is not a lock-step universal_section; edited by hand, kept identical). No new universal LAW (RDR-4 = extend `immutability_policy.md` + `factory-iteration-model`). The accept PR carries the governance source in its diff to satisfy `check-adr-constitution-sync.sh`.
