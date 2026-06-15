---
id: "{{FEATURE_ID}}"
status: DRAFT                    # DRAFT | APPROVED | INVALIDATED
scope: "{{SCOPE}}"               # inherited from spec.feature (immutable)
slicing_strategy: incremental    # slice_map is emitted ONLY when incremental
schemas_version: 1
iteration: 1                     # scalar N (legacy read path)
iteration_history: []            # legacy
iterations: []                   # ITER-{FEAT}-{N} entries — see factory-iteration-model
based_on_iteration: 1
last_iteration_scope: "Initial slicing"
# Push-cascade (slice_map -> increment_plan forward invalidation)
pending_iteration: null
invalidated_slices: []
invalidated_by_iteration: null
invalidated_reason: null
cascade_source: null             # provenance string (NOT the per-slice join key)
cascade_timestamp: null
# Meta
total_slices: 0
rdr_rationale: ""
rdr_alternatives_considered: 0   # RDR >= 3
rdr_ratified_at: null
created_at: "{{TIMESTAMP}}"
updated_at: "{{TIMESTAMP}}"
---

# Slice Map: {{FEATURE_ID}} — {{FEATURE_NAME}}

> **Generado por:** CODESIGN Agent | Feature: {{FEATURE_ID}}
> **Authority:** capability-VALUE slicing — which capabilities form a shippable vertical, and their user-value order. CODESIGN owns this. BLUEPRINT refines it into the contract-aware `increment_plan.md` and may re-order ONLY when contract reality forces it (deviation recorded there).
> **Cascade pair:** `codesign/slice_map_template.md` -> `architect/increment_plan_template.md` (cross-family; SETUP --upgrade walks both).
> **Emitted only when** `slicing_strategy: incremental`. Monolithic features carry no slice_map.

---

## Section 0: Decision History

<!-- Chronological record of RDR decisions made during slicing. Each slicing decision carries the
     factory-adversarial-reasoning FOR/AGAINST one-liner in Rationale. -->

| # | Date | Hat | Question | Options | Decision | Rationale |
|---|------|-----|----------|---------|----------|-----------|
| 1 | {{DATE}} | 🎩 PO | — | — | — | — |

---

## Section 1: Slice Inventory

<!-- Invariants (CVP-enforced):
     - Every scenario in spec.feature appears in EXACTLY one slice (exclusive, total coverage).
     - `depends_on_slice` forms an acyclic DAG; the root slice has `depends_on_slice: []`.
     - Each slice ships standalone WITH its declared predecessors — 100% functional vertical, no stubs to prod.
     - A slice has NO hand-set status. Freeze is derived per-scenario from realizing increments
       (see § Slice Freeze Derivation). -->

### SLICE-{{FEATURE_ID}}-1 — {{title}}

- **Value order:** 1
- **Scenarios covered:** [{{Scenario name}}]
- **Journey steps covered:** [{{Paso N}}]
- **Independence rationale:** "ships standalone after its predecessors because {{...}}"
- **depends_on_slice:** []
- **depends_on_feature:** []
- **seam:** null
- **Realized by increments:** []   <!-- back-ref filled by BLUEPRINT; each cites cascade_source: SLICE-{{FEATURE_ID}}-1 -->

---

## Section 2: Cross-Slice / Cross-Feature Dependencies + Seams

<!-- A dependency is an ORDERING constraint (ship after the predecessor merges), NOT a stub.
     depends_on_slice:   [SLICE-{FEAT}-X]      intra-feature ordering.
     depends_on_feature: [FEAT-Y@SLICE-Y-Z]    cross-feature (extends consumes_contract; @SLICE on a
                                               monolithic feature resolves to its implicit INC-1).
     seam = WHERE the dependency is consumed, so review can confirm the ordering is real:
            { at: "<contract op | scenario | journey step>", resolves: "<SLICE-{FEAT}-X | FEAT-Y@SLICE-Y-Z>" } -->

| Slice | seam.at (contract op / scenario / journey step) | seam.resolves |
|-------|-------------------------------------------------|---------------|
| {{SLICE-ID}} | {{where consumed}} | {{SLICE-{FEAT}-X \| FEAT-Y@SLICE-Y-Z}} |

---

## Section 3: Slice Order Diagram

<!-- NON-AUTHORITATIVE — mechanically derived from § 1 `depends_on_slice`. The § 1 DAG is the source of truth. -->

```mermaid
graph TD
    S1[SLICE-{{FEATURE_ID}}-1]
```

---

## Slice Freeze Derivation

<!-- A slice has no scalar status. Its freeze is a per-scenario partition derived from realizing increments:
       merged_scenarios(slice) = ⋃ scenarios_covered of its increments whose status == MERGED.
     A re-slice that moves a scenario in merged_scenarios is BLOCKED pre-persist → open a follow-up slice
     (CODESIGN --revise for genuinely destructive intent). Empty realizers (pre-BLUEPRINT) = fully editable.
     Canonical rule: factory-iteration-model § Slice Freeze Derivation + rules/immutability_policy.md § Per-Slice Immutability. -->

---

## Invariants Enforced by CVP

<!-- Check 18 slice_to_increment_coverage · Check 19 slice_seam_resolution · Check 20 slice_immutability_consistency
     — factory-coherence-validation. -->
