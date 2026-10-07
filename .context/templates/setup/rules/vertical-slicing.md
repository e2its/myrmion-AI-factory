---
description: "Vertical slicing — every feature ships as a chain of vertical increments, one PR each, each production-deployable; slice_map → increment_plan → dev_plan, the increment lifecycle, trains and the surface ceiling, the CVP checks, the iteration cascade."
applicable_when:
  path_glob:
    - "docs/spec/**/spec.feature"
    - "docs/spec/**/slice_map.md"
    - "docs/spec/**/increment_plan.md"
    - "docs/spec/**/dev_plan.md"
version: 1.0.0
date: 2026-10-07
changelog:
  - "1.0.0: feat(EVOL-064) — body moved verbatim from the project CLAUDE.md § Incremental Dev Plan (Vertical Slicing); CLAUDE.md keeps the always-on lines and a pointer here."
---

# Incremental Dev Plan (Vertical Slicing)

> Moved verbatim from `CLAUDE.md` § Incremental Dev Plan (Vertical Slicing) (EVOL-064). `CLAUDE.md` keeps the always-on lines; the detail lives here and is delivered at the point of edit.

Every feature ships as a chain of **vertical increments**. One PR per increment. Each increment, merged in isolation, leaves the product 100% functional and production-deployable. No feature-flag-OFF escape. This binds the whole pipeline — from spec to branching to iteration — so large features decompose into reviewable, rollback-safe units without losing traceability.

**Two-stage authority (EVOL-036).** CODESIGN owns capability-VALUE slicing; BLUEPRINT owns contract-decomposition. CODESIGN emits `slice_map.md` (which scenarios form each shippable vertical slice + user-value order); BLUEPRINT REFINES it into `increment_plan.md`, joining each increment to its slice via `cascade_source: SLICE-{FEAT}-N`. BLUEPRINT does NOT invent or value-reorder slices — single authority per concern.

**Strategy field.** `spec.feature.slicing_strategy: incremental | monolithic`. Default `incremental`. `monolithic` allowed only when **all** hold: `scenarios_count ≤ 2` AND `contract_operations ≤ 3` AND `scope ≠ full-stack`. BLUEPRINT `--start` enforces this Trivial-Heuristic Gate. Monolithic features carry NO slice_map.

**Stage-1 artefact (CODESIGN).** `docs/spec/{FEATURE_ID}/slice_map.md` — capability-VALUE slices `SLICE-{FEAT}-N`: `§ 0` Decision History, `§ 1` Slice Inventory (per slice: `value order`, `scenarios_covered` (exclusive+total), `journey_steps`, independence rationale, `depends_on_slice` (acyclic), `depends_on_feature`, integration `seam`, `Realized by increments` back-ref), `§ 2` seam table, `§ 3` slice-order Mermaid (non-authoritative). Generated at `CODESIGN --start` via the slicing-VALUE RDR (≥3 grouping alternatives, verbatim ratification). A slice has NO scalar status — its freeze is a per-scenario partition (see Iteration cascade).

**Stage-2 artefact (BLUEPRINT).** `docs/spec/{FEATURE_ID}/increment_plan.md` — sidecar of `design.md`, contract-aware **refinement** of slice_map. `§ 0` Refinement Record (slice→INC mapping, intra-slice layering, contract-forced deviations), `§ 1` Increments (each realizes one slice via `cascade_source: SLICE-{FEAT}-N`; declares `Status`, `scenarios_covered`, `contract_surface`, `depends_on` (canonical INC→INC DAG), `depends_on_slice`/`depends_on_feature`/`seam`, `deployable: production`, acceptance checklist, branch name), `§ 2` Monolithic Escape Declaration (only when monolithic), `§ 3` Human-readable Dependency Diagram (Mermaid, non-authoritative — derived from § 1 `depends_on:`). Generated at `BLUEPRINT --start` by mapping each slice 1:1 to an increment (≥2 only via an intra-slice layering RDR — the only slicing RDR surviving in BLUEPRINT).

**Increment lifecycle.** `DRAFT → READY → BUILDING → MERGED` + `→ INVALIDATED` branch from DRAFT/READY only. Transitions are monotonic — no regression. MERGED is terminal for that increment: further change to its scope requires either `CODESIGN --revise` (feature version bump) or a **Follow-up Increment** (additive, non-overlapping scenarios; no bump). See `.claude/rules/immutability_policy.md § Per-Increment Immutability`.

**Branching.** `feature/{FEATURE_ID}-inc-N-{slug}` per increment, merged as independent PR. One branch open at a time per feature (concurrency lock). Merge hook stamps `Merged at:` and flips status.

**Trains and the surface ceiling (EVOL-045).** The reviewable unit is bounded **per pull request** by `config/quality.json → surface.ceiling_files / ceiling_lines` (SETUP Q31; keys, never digits in prose). BLUEPRINT estimates every increment's surface (paths · ~files · ~lines, ratified by RDR) and splits an over-ceiling increment into sub-increments; the per-increment branch then becomes a **train** — protected like a base branch, receiving one PR per sub-increment `feature/{FEATURE_ID}-inc-N-{slug}-sub-M` (branched from the train), closed to the base branch by one PR when every sub-increment has landed. One full verification loop and one deployment per train (none when its diff touches no `surface.runtime_surface` glob), never per sub-increment. **One diff base** for every gate, review and measurement: `python3 scripts/gate.py diff-base` (a sub-increment → its train; else the default base branch; an unrecognised name is red). The push measures the real surface — `gate.py surface`: files + lines of the diff, no exclusion list — and blocks over the ceiling unless a commit trailer `Surface-Escape: <term>` names one of the closed `surface.escapes` (extending the list is a decision record). CVP Check `21` `surface_declared` warns on an increment without an estimate. See `.claude/skills/factory-branching-strategy/SKILL.md § Trains`.

**Consumption.** `IMPLEMENT --plan` reads `increment_plan.md`, emits `dev_plan.md` with one `## Increment INC-N` section per increment. Task tags: `[INC-N.A.M]` / `[INC-N.B.M]` / `[INC-N.C.M]` + `[INC-N.ACC.k]` acceptance. Plan-level `IMPLEMENTED_AND_VERIFIED` only when every target increment closes. Monolithic preserves legacy `[A.M]`/`[B.M]`/`[C.M]` tagging for backward compat.

**Enforcement gates.** CVP at `BLUEPRINT --approve` (and the local push preflight, factory-pr-review Block 8): Check `0c` `increment_plan_presence`, Check `0d` `slice_map_presence`, Check `13` `increment_deployability`, Check `14` `increment_to_scenario_coverage`, Check `15` `increment_to_contract_coverage`, Check `16` `monolithic_heuristic`, Check `18` `slice_to_increment_coverage`, Check `19` `slice_seam_resolution`, Check `20` `slice_immutability_consistency` (all CRITICAL) + Check `17` `increment_to_task` and Check `21` `surface_declared` (WARNING at IMPLEMENT scope). See `.claude/skills/factory-coherence-validation/SKILL.md`.

**Iteration cascade.** Upstream changes propagate selectively via `CASCADE_INCREMENT_INTERNAL` — only increments whose scenarios/contracts overlap with the change flip to `INVALIDATED`. MERGED increments never invalidate (they anchor production); BUILDING increments get `pending_iteration` and must `--pause` before resync. A CODESIGN re-slice fires `CASCADE_SLICE_INTERNAL` (forward-only `slice_map → increment_plan`, assignment-delta) and is blocked pre-persist by `check_slice_immutability` when it touches a MERGED-frozen scenario (→ follow-up slice or `CODESIGN --revise`). See `factory-iteration-model § Slice Freeze Derivation`.
