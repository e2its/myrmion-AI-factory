# EVOL-036 — Two-Stage Vertical Slicing (Critique-Hardened FINAL Plan)

Branch: `feature/EVOL-036-two-stage-vertical-slicing`. Evolution → full PR + CI + governance bump per sub-slice. Every behavioral-contract file (instructions/skills/commands/hooks) is a hard exclusion from the docs fast-lane (Generation Standards §3) → no fast-lane anywhere in this work. ADR-EVOL-036 is the local ceremony; on flip to `accepted` it MUST amend `CLAUDE.md` + templates in the SAME PR (`check-adr-constitution-sync.sh`; known-flaky scenario 3 per MEMORY — re-run is the workaround). EVOL-035 applies: every selected alternative below carries a FOR/AGAINST one-liner; genuinely open ones are the four ASSUMPTIONS surfaced as `open_questions`.

> **Critique disposition up front.** Three lenses ran. GOVERNANCE = APPROVE-WITH-BLOCKERS (3 blockers folded). PRODUCT/UX = REJECT (2 blockers folded — they force a model change: `modal`→`seam`, fallback-stub deleted, slice_map reframed as value hypothesis not contract authority). IMMUTABILITY = REJECT (3 blockers + 5 majors folded — they force the single largest design change: **slice immutability is a per-SCENARIO freeze partition, NOT a derived scalar status**; the cascade is split into a pre-persist gate + a forward cascade with explicit re-slice affected-set; ASSUMPTION-B is killed). Every blocker/major below is annotated `[CRIT-<lens>-<n>]` where the design changed.

---

## 0. Naming + cascade_source — two load-bearing decisions resolved up front (UNCHANGED, verified)

**Slice ID namespace = `SLICE-{FEAT}-{N}`** (feature-prefixed). Verified live: `SLICE-N.N` already exists (`CASCADE_SLICE_PEERS`, `factory-iteration-model/SKILL.md:649-681`, regex `/^slice:EPIC-\d+\.\d+$/`, resolves to `docs/spec/SLICE-N.N/integration_test.md`). Bare `SLICE-N` would collide. `SLICE-{FEAT}-{N}` mirrors `ITER-{FEAT}-{N}` and is distinct from epic-slice `SLICE-N.N`. The two-stage cascade fn is `CASCADE_SLICE_INTERNAL`, NOT `CASCADE_SLICE_PEERS`. Disambiguation note mandatory (§4c).

**Join key = per-increment `cascade_source: SLICE-{FEAT}-{N}`** (Rule 9 join primitive). Plan-level frontmatter `cascade_source` keeps its existing dual-use provenance-string semantics (already precedented — `cascade_source` accepts both an ITER ID and a legacy agent-name string). Reciprocal back-ref `**Realized by increments:** [...]` lives on the slice. Grep join: `grep "cascade_source: SLICE-{FEAT}-N" docs/spec/{FEAT}/increment_plan.md`.

---

## 1. slice_map.md artefact — schema + body

Path: `docs/spec/{FEATURE_ID}/slice_map.md`. Template path: **`.context/templates/codesign/slice_map_template.md`** (verified: `codesign/` dir exists and holds `gherkin_master_template.feature`, `user_journey_template.md`). Manifest section = **`agent_templates`** (verified: `architect/increment_plan_template.md`, `codesign/*` all live under `agent_templates`, NOT `templates`). Ships via factory-sync `[7/7]` recursive tree-sync — zero `factory-sync.sh` edit.

> **[CRIT-PRODUCT-2]** slice_map reframed. PRODUCT/UX blocker: CODESIGN has no contracts/design.md (BLUEPRINT outputs), so slicing from scenarios+journey is a hypothesis BLUEPRINT could override → churn. **Resolution (folds into the design, surfaces as ASSUMPTION-C RDR):** slice_map is a **value-grouping hypothesis** authored by CODESIGN — it owns *which capabilities form a shippable vertical and their USER-VALUE order*. BLUEPRINT owns *contract feasibility* and refines/re-orders ONLY when contract reality forces it, recording the deviation. This keeps a single authority per concern (capability-value = CODESIGN; contract-decomposition = BLUEPRINT) and removes the "double binding RDR" friction — see §3 collapse of the two RDRs to one ratification per concern.

> **ASSUMPTION-A (RDR, open):** template family `codesign/` vs `architect/`. GOVERNANCE-minor noted the cascade pair would straddle two families (`codesign/slice_map_template.md` → `architect/increment_plan_template.md`), a latent SETUP --upgrade per-family-walk cost. Recommend `codesign/` (CODESIGN owns the artefact; emitting-agent propagation). MUST document the cross-family cascade pair in the ADR + a one-line header comment in BOTH templates (`cascade pair: codesign/slice_map_template.md -> architect/increment_plan_template.md`). SLICE-1 acceptance asserts SETUP --upgrade Smart Additive Merge handles the new `agent_templates` entry.

### Frontmatter (mirror `increment_plan_template.md` cascade block; caveman)
```yaml
---
id: "{{FEATURE_ID}}"
status: DRAFT                    # DRAFT | APPROVED | INVALIDATED (plan-level enum, same 3 values as increment_plan)
scope: "{{SCOPE}}"               # inherited from spec.feature (immutable)
slicing_strategy: incremental    # slice_map ONLY emitted when incremental
schemas_version: 1
# Iteration ledger (Rule 9 — REQUIRED, refine-able artefact)
iteration: 1
iteration_history: []
iterations: []                   # ITER-{FEAT}-{N} canonical
based_on_iteration: 1
last_iteration_scope: "Initial slicing"
# Push-cascade fields (slice_map -> increment_plan forward invalidation)
pending_iteration: null
invalidated_slices: []           # mirror of invalidated_increments[]
invalidated_by_iteration: null
invalidated_reason: null
cascade_source: null             # provenance string (NOT the per-slice join)
cascade_timestamp: null
# Meta
total_slices: 0
rdr_rationale: ""
rdr_alternatives_considered: 0   # RDR >=3
rdr_ratified_at: null
created_at: "{{TIMESTAMP}}"
updated_at: "{{TIMESTAMP}}"
---
```

### Per-slice block (`### SLICE-{FEAT}-N`)
```
### SLICE-{{FEATURE_ID}}-1 — {{title}}
- **Value order:** 1                          # USER-VALUE order (CRIT-PRODUCT-2). NOT reliability — that is BLUEPRINT's intra-slice concern.
- **Scenarios covered:** [{{Scenario name}}, ...]   # subset of spec.feature; exclusive across slices
- **Journey steps covered:** [{{Paso N}}, ...]       # user_journey.md § 2
- **Independence rationale:** "ships standalone after its predecessors because {{...}}"
- **depends_on_slice:** []                  # [SLICE-{FEAT}-X] punctual intra-feature ORDERING dep
- **depends_on_feature:** []                # [FEAT-Y@SLICE-Y-Z] cross-feature dep (resolves like consumes_contract)
- **seam:** null                            # integration seam — see §2 (renamed from "modal")
- **Realized by increments:** []            # back-ref, filled by BLUEPRINT
# NOTE: slice has NO hand-set Status field. Freeze is a derived per-scenario partition — see § Slice Freeze Derivation.
```

> **[CRIT-IMMUTABILITY-1 + CRIT-IMMUTABILITY-6 + ASSUMPTION-B killed]** No `Status:` field on the slice. The original plan's "derived scalar status" (ASSUMPTION-B) is removed entirely: a scalar rollup is contradictory (§1 "any BUILDING" min-rollup vs §4a "monotone-max" max-rollup resolve a `{MERGED,DRAFT}` slice oppositely; monotone-max → MERGED → destroys partial-freeze, the whole point of goal 3). A slice does NOT have one status — it has a **per-scenario freeze partition** (§4). The empty-realizer bootstrap (slice emitted by CODESIGN before any increment exists) is therefore well-defined: empty partition = fully editable. CVP Check 20 no longer compares a scalar (which had no defined value); it checks the partition is consistent and vacuous pre-BLUEPRINT.

### Body sections (caveman/lean)
- **§0 Decision History** — RDR table `| # | Date | Hat | Question | Options | Decision | Rationale |` (copy `user_journey_template.md` pattern). Records the slicing-value RDR ratification + adversarial FOR/AGAINST one-liner.
- **§1 Slice Inventory** — invariants block (every scenario in exactly one slice; `depends_on_slice` acyclic DAG, root = `[]`; each slice ships standalone *with its predecessors*) + the `### SLICE-{FEAT}-N` blocks.
- **§2 Cross-Slice / Cross-Feature Dependencies + Seams** — the seam table (§2).
- **§3 Slice Order Diagram** — Mermaid `graph TD` from `depends_on_slice`, explicitly NON-AUTHORITATIVE.
- **§ Slice Freeze Derivation** — the per-scenario partition rule (§4, verbatim cross-ref).
- **§ Invariants Enforced by CVP** — names Checks 18/19/20.

`{{PLACEHOLDER}}` tokens only (Rule 7). Skeleton MUST emit a `## Iteration {id}` body anchor per `iterations[]` entry (§6 — `check-iteration-id-format.sh` rule 3).

---

## 2. Dependency + seam schema (BOTH artefacts) — `modal` renamed to `seam`, fallback deleted

> **[CRIT-PRODUCT-1]** PRODUCT/UX blocker: the original `modal.fallback` ("how the slice degrades gracefully / stubs the seam to ship standalone") **ships stubs to prod**, directly violating `increment_plan_template.md:4,63-64` ("strict — no feature-flag-OFF escape; 100% functional = works taken alone WITH PREDECESSORS"). Also `modal` collides with the UI modal in `mock-template.html` / `mock-feature-content-template.html` (verified). **Resolution:**
> - **Delete the `fallback`/stub concept.** A cross-slice dep is an **ORDERING** constraint, not a stubbing one: the slice ships *after* its predecessor merges. Independence = "100% functional taken alone WITH its declared predecessors", identical to the increment contract.
> - **Rename `modal` → `seam`.** Avoids the UI-modal namespace collision.
> - Cross-FEATURE deps reuse the existing `consumes_contract` gate semantics (the predecessor feature's contract must be APPROVED/frozen before the consuming slice can build).

**Dependency lists** (identical names in slice_map per-slice AND increment_plan per-increment):
- `depends_on_slice: [SLICE-{FEAT}-X]` — punctual intra-feature ordering dep.
- `depends_on_feature: [FEAT-Y@SLICE-Y-Z]` — cross-feature dep (`@SLICE` extends the `consumes_contract` primitive).

**Seam (integration point)** — declares WHERE the dependency is consumed so review can confirm the ordering is real:
```
- **seam:** { at: "<contract op | scenario | journey step where the dep is consumed>",
              resolves: "<SLICE-{FEAT}-X | FEAT-Y@SLICE-Y-Z>" }
```
- In **slice_map**: capability-level seam (one per declared dep; null when no deps).
- In **increment_plan**: same `depends_on_slice` / `depends_on_feature` / `seam` fields on the realizing `### INC-N`, co-located with the existing `**Depends on:**` field (which keeps modelling intra-feature INC→INC DAG edges only). Null-defaulted so empty increments stay one-liners.

CVP verifies the seam *resolves to a real predecessor/external feature* (Check 19, mechanical). It cannot prove the ordering makes the slice independently functional — that is a design-judgement gap the EVOL-035 FOR/AGAINST pass surfaces during the slicing RDR, not a gate.

---

## 3. Two-stage flow (CODESIGN → BLUEPRINT)

### Stage 1 — CODESIGN emits slice_map (capability-value authority)
File: `Factory-codesign-feature.instructions.md`.
1. **§ Generated Feature Artifacts** — bump "3 files" → 4; add `slice_map.md` (emitted only when `slicing_strategy==incremental`).
2. **--start Execution Flow** — insert **new step 9.5 "Slice Map Generation"** between step 9 (BIP Tier ALIGNMENT) and step 10 (Auto-Approval). Rationale: slicing needs the converged scenario+journey set (post-Tripartite) and slice_map MUST be inside the APPROVED/frozen set (pre-auto-approval) so it inherits the immutability anchor. Step 9.5 algorithm:
   - Read scenarios (`Scenario:`/`Scenario Outline:`, exclude `Background:`) from `spec.feature` + journey steps (`user_journey.md § 2 ### Paso N`) + `scope`.
   - Run adversarial FOR/AGAINST (EVOL-035) on each slice-grouping candidate.
   - **ONE slicing-value RDR** with ≥3 grouping alternatives (which scenarios/journeys → each SLICE, **USER-VALUE order**, independence rationale, cross deps + seams). Each slice = a fullstack vertical (scope-aware: backend-only/integration slices are backend/integration verticals, NOT skipped — reuse the existing mock.html scope-N/A pattern only for UI-specific fields).
   - Emit `slice_map.md` via IPP skeleton-first / section-atomic.
   - **SLICE_IMMUTABILITY_GATE runs HERE, PRE-PERSIST** (see §4 — `[CRIT-IMMUTABILITY-7]`). On `--refine` re-slice, validate against `merged_scenarios` BEFORE the section write; BLOCK + redirect to follow-up slice if the diff touches a frozen scenario. This is NOT a cascade write — it produces no edge (acyclicity, `[CRIT-IMMUTABILITY-9]`).
   - Self-Check: every scenario in exactly one slice (exclusive); `depends_on_slice` DAG acyclic; each slice has independence_rationale; each declared dep has a seam.
3. **Auto-Approval Protocol (`codesign_auto_approve`)** — add a 13th CHECK: slice_map exclusive scenario coverage + well-formed (validated AND frozen with the APPROVED set; generating after approval escapes the anchor).
4. **Atomic Persistence Gate** — extend the `[user_journey.md, spec.feature, mock.html]` loops to include `slice_map.md` (`codesign_skeleton_first` + `codesign_resume_check`).
5. **--refine** — add `slice_map.md` to the 1.4 aggregated changelog (`codesign.md` — append to `spec.feature, user_journey.md, mock.html`) and to CASCADE handling: a slice_map re-slice fires `CASCADE_SLICE_INTERNAL` (§4). slice_map is now both a CASCADE consumer of spec.feature/user_journey AND a producer for increment_plan.

### Stage 2 — BLUEPRINT consumes slice_map, refines into increment_plan
File: `Factory-blueprint-design.instructions.md § Increment Plan Generation` (Steps A-D verified at the live offsets).
- **New Step A0 "slice_map Ingestion Gate"** (before Step A): READ `docs/spec/{ID}/slice_map.md`; humanised BLOCK if absent when incremental ("CODESIGN must emit slice_map.md first — run /codesign"); load SLICE-N entries.
- **Step A Trivial-Heuristic / monolithic** — KEEP IN BLUEPRINT. **[CRIT-PRODUCT-2 confirmation]:** verified the heuristic's `ops_count` is computed from `contracts/**`, which only exist after BLUEPRINT — CODESIGN structurally cannot run it. So the monolithic FEASIBILITY decision stays in BLUEPRINT. CODESIGN's slice_map *declares* the slice count (1-slice slice_map = monolithic intent); BLUEPRINT *verifies* it against contracts. ASSUMPTION-C resolution = option (c): CODESIGN declares, BLUEPRINT re-asserts via the existing heuristic, CVP cross-validates `total_slices==1 AND heuristic holds`. The `ops_count=0` frontend-only vacuous case survives.
- **Step B — GUT the ≥3-alternatives slice-INVENTION RDR.** Replace with **"Slice Refinement"**: BLUEPRINT does NOT invent or value-reorder slices. It maps each authoritative `SLICE-{FEAT}-N` → one (or, only with RDR justification, more) contract-aware `INC`. The surviving RDR is **intra-slice contract layering** when a single slice admits ≥2 viable increment decompositions (e.g. read-then-write inside the slice). The reliability>cost ranking rule survives but applies to intra-slice layering ONLY. **If contract reality forces a re-order/re-group of CODESIGN's value-order, BLUEPRINT records the deviation in §0 (refinement record) — it does not silently override** (single-authority discipline).
- **Step C** — each emitted INC sets `cascade_source: SLICE-{FEAT}-N` + the seam fields; BLUEPRINT fills the slice's `**Realized by increments:**` back-ref. §0 Slicing Rationale becomes a **refinement record** (which SLICE each INC realizes + intra-slice layering justification + any contract-forced deviation from CODESIGN value-order). `rdr_alternatives_considered` redefined to count intra-slice layering alternatives (≥1 when a slice splits; not stranded). Worklog action `BLUEPRINT.increment_plan.rdr_ratified` kept, now = layering ratification.
- **Step D self-check** — ADD: every `SLICE-{FEAT}-N` maps to ≥1 INC; every INC `cascade_source` resolves to a real slice; every seam resolves to a declared predecessor SLICE or external feature@slice. KEEP existing scenario/contract exclusive-coverage + DAG + deployability invariants (IMPLEMENT consumes these verbatim — unchanged).

**What moves OUT of BLUEPRINT:** slice-VALUE-invention authority (which scenarios form which slice, user-value order, independence rationale, cross-slice deps) → CODESIGN. BLUEPRINT retains contract surface, layer tasks, DAG, intra-slice layering RDR, and contract-feasibility veto (recorded as deviation).

> **[CRIT-GOVERNANCE-2] DRY / single-authority — ALL-OR-NOTHING migration.** Verified THREE live canonical assertions that BLUEPRINT/increment_plan owns scenario slicing; ALL must flip in ONE slice (SLICE-3) or two artefacts claim the same authority (Rule 1 + Rule 3 violation):
> - (a) `gherkin_master_template.feature:37-41` — "Every Scenario below will be assigned to EXACTLY ONE increment ... at BLUEPRINT --start (Increment Slicing RDR)".
> - (b) `user_journey_template.md:23` — "BLUEPRINT distributes the scenarios".
> - (c) `blueprint.md` command (prereq + the increment_plan line) — currently reads as the slicing authority.
> ALSO rewrite: `increment_plan_template.md` §0 wording + `immutability_policy.md` § Per-Increment lead-in to say BLUEPRINT **REFINES authoritative slices into contract-aware increments (no slice invention)**. SLICE-3 ends with a `factory-pr-review` Block-13 reference-coherence sweep over the strings `Increment Slicing RDR` / `distributes the scenarios` to prove no orphaned old-authority claim survives.

Command files: `codesign.md` (4th artefact + Stage-1 slicing protocol + decision-authority migration + changelog cascade). `blueprint.md` (slice_map APPROVED prereq; reword increment_plan to "contract-aware refinement of slice_map slices, `cascade_source: SLICE-{FEAT}-N`, no slice invention"; IPP order §0 → refinement rationale).

---

## 4. Immutability adaptation — per-SCENARIO freeze partition (NOT a scalar status), one-hop, no fork

File: `factory-iteration-model/SKILL.md`. This section is rewritten wholesale from the original plan per the three IMMUTABILITY blockers.

### 4a. Slice Freeze Derivation — per-scenario partition (`[CRIT-IMMUTABILITY-1]`, `[CRIT-IMMUTABILITY-6]`)
A slice has NO scalar status. Define, over the feature's increments (grep `cascade_source` + per-INC `Status:`):
```
merged_scenarios  = ⋃ INC.scenarios_covered  for INC where INC.status == MERGED
locked_scenarios  = ⋃ INC.scenarios_covered  for INC where INC.status == BUILDING
# everything else (DRAFT/READY/INVALIDATED/no-realizer) is freely re-sliceable
```
Empty-realizer bootstrap (CODESIGN-time, pre-BLUEPRINT): `realizers==[]` ⇒ both sets empty ⇒ fully editable. "1..N partially frozen" emerges naturally: a slice with a MERGED realizer covering `{s1}` and a DRAFT realizer covering `{s2}` freezes `s1`, leaves `s2` re-sliceable. A cosmetic display status MAY be shown but is NEVER gated on.

### 4b. SLICE_IMMUTABILITY_GATE — pre-persist, scenario-set-based (`[CRIT-IMMUTABILITY-2]`, `[CRIT-IMMUTABILITY-7]`)
Lives in CODESIGN --refine's PRE-persist validation path (step 9.5 / Atomic Persistence Gate), invoked BEFORE the slice_map section write — analogous to `immutability_policy.check_increment_immutability` being called at command entry, NOT inside the cascade.
```
FUNCTION check_slice_immutability(FEATURE_ID, proposed_slice_map):
  merged_scenarios = compute over feature increments (grep cascade_source + Status:MERGED)
  reslice_diff = scenarios REMOVED/MOVED/RE-LABELLED between persisted and proposed slice_map
  IF reslice_diff ∩ merged_scenarios != ∅:
     BLOCK (humanised) → "Scenario {s} is in production (MERGED). Add a follow-up slice instead."
     REDIRECT to Follow-up Slice Rule (additive SLICE-{FEAT}-N+1, non-overlapping, depends_on existing)
  # BUILDING + DRAFT/READY are NOT blocked here — they are handled by the FORWARD cascade (4c),
  # delegating to CASCADE_INCREMENT_INTERNAL's existing per-status table (NOT collapsed to "block").
  # TOCTOU guard: re-grep Status:MERGED IMMEDIATELY before write; abort if merged_scenarios grew.
```
This is `immutability_policy.md:94-96` (scope exclusivity on append) lifted to scenarios verbatim. A MERGED scenario is frozen **wherever it currently sits** — the predicate is scenario-membership, not slice-id (which is too coarse: re-slicing moves scenarios between slices, so a slice-id key can let a MERGED-owned scenario slip into a DRAFT slice and orphan its increment).

> **[CRIT-IMMUTABILITY-7] timing.** The gate is a PRE-persist reject/redirect, so it never has to roll back a persisted re-slice. **[CRIT-IMMUTABILITY-8] BUILDING.** The gate does NOT collapse `{MERGED, BUILDING}` into "block". MERGED → block + follow-up. BUILDING → delegate to the forward cascade's existing table (pending_iteration + --pause), matching the increment layer exactly (no harder-than-increment fork). **[CRIT-IMMUTABILITY-8] TOCTOU.** Optimistic re-grep of `Status:MERGED` immediately before write.

### 4c. CASCADE_SLICE_INTERNAL — forward only, explicit affected-set, idempotent (`[CRIT-IMMUTABILITY-3]`, `[CRIT-IMMUTABILITY-9]`)
The original "delegate to CASCADE_INCREMENT_INTERNAL UNCHANGED" is a FORK hidden in the INPUT semantics: a pure re-slice produces an EMPTY gherkin text-diff, so `EXTRACT_AFFECTED_SCENARIOS` returns empty → trips the `implicit_touch` fallback (`SKILL.md:579-582`) → wholesale invalidation of every non-MERGED increment. Fix:
```
FUNCTION CASCADE_SLICE_INTERNAL(FEATURE_ID, target_iteration):
  # FORWARD ONLY. NEVER writes back to slice_map (acyclicity invariant — header note).
  affected_scenarios = scenarios whose SLICE ASSIGNMENT changed (assignment-delta, NOT text-delta)
  IF affected_scenarios IS EMPTY: RETURN   # pure no-op re-approval — no invalidation
  # delegate the per-status TRANSITION TABLE (MERGED→warn+follow-up, BUILDING→pending+pause,
  # DRAFT/READY/INVALIDATED→invalidate) to CASCADE_INCREMENT_INTERNAL, but pass the EXPLICIT
  # assignment-delta set so implicit_touch (:579) is NEVER reached.
  RETURN CASCADE_INCREMENT_INTERNAL(FEATURE_ID, target_iteration, ["reslice"], affected_scenarios, [])
```
The function body of `CASCADE_INCREMENT_INTERNAL` is reused verbatim (goal-3 mandate honoured — no parallel transition table); only the INPUT is a precisely-computed assignment-delta. Header note (mandatory): *"CASCADE_SLICE_INTERNAL writes DOWNWARD only (increment_plan); it NEVER writes back to slice_map. The MERGED back-constraint is a pre-persist gate (4b), not a cascade write — so the cascade graph spec.feature → slice_map → increment_plan → dev_plan is strictly acyclic per refine event."*

### 4d. Wire into trigger — guard the existing :453 call (`[CRIT-IMMUTABILITY-3]`)
`ON_CODESIGN_REFINE_ITERATION` (`:445-453`) already calls `CASCADE_INCREMENT_INTERNAL` unconditionally at `:453`. On a re-slice-only refine, leaving it live means double-invalidation (once via `CASCADE_SLICE_INTERNAL`'s assignment-delta, once via the original text-delta+implicit-touch). Fix:
```
ON_CODESIGN_REFINE_ITERATION:
  ...
  CASCADE_SLICE_INTERNAL(FEATURE_ID, new_iteration)               # NEW — assignment-delta path
  IF the refine changed ONLY slice assignment (no scenario TEXT change):
     SKIP the existing CASCADE_INCREMENT_INTERNAL(:453)            # slice path already handled it
  ELSE:
     CASCADE_INCREMENT_INTERNAL(... affected_scenarios=text-delta ...)   # unchanged path for text edits
```
Idempotency: running the cascade twice on the same re-slice invalidates the same set (assignment-delta is deterministic; no implicit_touch). Monolithic guard: `CASCADE_INCREMENT_INTERNAL` already returns early when `slicing_strategy != incremental` (`:568`) — degenerate single-slice slice_map no-ops.

### 4e. Convergence / terminal escape (`[CRIT-IMMUTABILITY-4]`)
A genuinely destructive re-slice intent (e.g. "split `s1`, currently in MERGED INC-1") cannot be satisfied by a follow-up slice (which forbids touching merged scenarios) — operator would deadlock. Mirror the increment model's slicing-flip escape (`immutability_policy.md:101`): the ONLY legal path to alter a MERGED scenario's decomposition is **`CODESIGN --revise`** (new feature version; v2 slice_map starts fresh; v1 merged slices are audit history). State this explicitly in § Follow-up Slice Rule as the terminal escape.

### 4f. Disambiguation note (`[CRIT-GOVERNANCE]`)
Near `CASCADE_SLICE_PEERS` (`:649-681`): `CASCADE_SLICE_INTERNAL` (vertical, intra-feature, slice_map→increment_plan) ≠ `CASCADE_SLICE_PEERS` (horizontal, cross-feature epic-slice integration suite). Different concepts, different namespaces.

### 4g. immutability_policy.md (template-only — `.claude/rules/immutability_policy.md` does NOT exist; `[CRIT-GOVERNANCE-5]` drop dead hedge)
File: `.context/templates/setup/rules/immutability_policy.md`.
- Add **§ Per-Slice Immutability** after Per-Increment (`:96`): freeze is a per-scenario partition derived from realizing increments (4a); plan-level frontmatter + §0 frozen at approval; per-slice scenario membership editable until a realizing increment reaches MERGED, at which point that scenario freezes wherever it sits → changes require a follow-up slice or `CODESIGN --revise`.
- Add **Follow-up Slice Rule** mirroring Follow-up Increment Rule (`:77-88`), inheriting the SAME Phase-4 QA-verify lock window.
- Add `check_slice_immutability()` to the pseudocode region (the scenario-set predicate from 4b).
- Add a slice_map row to the Lock Table (`:30-37`).

> **[CRIT-IMMUTABILITY-5] cross-feature Phase-4 lock.** Scope the Phase-4 lock to per-feature realizers ONLY. A slice realized across multiple features (via `depends_on_feature`) has no single Phase-4 anchor: feature A's follow-up rule freezes against A's own QA --verify independently of feature B. Cross-feature deps do NOT propagate the QA lock — they are governed by the existing `consumes_contract` / `CASCADE_CONSUMERS` path (`SKILL.md:502-550`), not the per-slice gate. State explicitly to avoid a phantom global lock.

---

## 5. CVP — new checks + push-gate parity (`[CRIT-GOVERNANCE-1]`)

File: `factory-coherence-validation/SKILL.md`. Register in `CVP_SCOPES.CODESIGN_BLUEPRINT.checks` (verified live list) so they fire at BLUEPRINT --approve and transitively at IMPLEMENT --plan / QA --verify via the includes-chain.

- **Check 18 `slice_to_increment_coverage` (CRITICAL, bidirectional)** — (a) every `SLICE-{FEAT}-N` realized by ≥1 increment citing it via `cascade_source`; (b) every increment cites a real slice; (c) scenario consistency: `⋃ scenarios_covered across increments realizing SLICE-N == slice's scenarios_covered`. Reuse Check 14 orphan/duplicate/phantom set-diff machinery.
- **Check 19 `slice_seam_resolution` (CRITICAL)** — each `depends_on_slice` resolves to a real SLICE in the same slice_map AND forms a DAG (reuse Check 13 Kahn); each `depends_on_feature: [FEAT-Y@SLICE-Y-Z]` resolves to a real upstream feature whose slice_map declares that slice AND whose design is APPROVED (reuse Check 0b `consumes_contract_resolution`). Every declared dep MUST have a `seam`. **Three fail-modes** (`[CRIT-GOVERNANCE-6]`):
  1. referenced feature exists, slice_map present + slice present + APPROVED → PASS.
  2. referenced feature exists but slice_map absent/non-APPROVED OR slice missing → BLOCK.
  3. **referenced feature has `slicing_strategy: monolithic` → resolve `@SLICE` to the implicit single increment (`SLICE-{FEAT}-1`/INC-1) and PASS** — a monolithic feature IS one vertical slice by definition (else false-positive CRITICAL).
  4. referenced feature absent → WARN (mirror `consumes_contract` severity).
- **Check 20 `slice_immutability_consistency` (CRITICAL)** — the per-scenario freeze partition is well-formed (no scenario both MERGED-frozen and re-assigned); no MERGED increment orphaned by a slice_map edit (parent slice still exists, still owns its scenarios — Check 18(c) cross-link). **Vacuous when `total realizing increments == 0`** (`[CRIT-IMMUTABILITY-6]` — pre-BLUEPRINT bootstrap). Delegate transition-legality to `immutability_policy.check_slice_immutability()`. Does NOT compare a scalar status (none exists). Asserts the cascade wrote no edge back to slice_map (acyclicity, `[CRIT-IMMUTABILITY-9]`).

Plumbing:
- **Check 0d `slice_map_presence`** (mirror Check 0c `increment_plan_presence`) — slice_map.md exists + well-formed frontmatter when `slicing_strategy==incremental`; required_fields enforce RDR≥3. Register in `CODESIGN_BLUEPRINT.checks`.
- **`cvp_coherence_gate` Step 0** — add `artifacts.slice_map = READ_IF_EXISTS("{base_path}/slice_map.md")`.
- **`extract_traceable_elements`** — parse slice_map into `elements.slices` (id/scenarios_covered/journey_steps/depends_on_slice/depends_on_feature/seam/realized_by). Without this the checks fail-open silently.
- **Cross-feature read** (`depends_on_feature`): document explicitly in the ADR as a **deliberate widening of the standing "CVP is per-feature" invariant** (`[CRIT-GOVERNANCE-6]`) — a ratified scope expansion, not an accident.
- **Vacuity:** monolithic / 1-slice features pass vacuously (mirror Check 15/16 patterns).

> **[CRIT-GOVERNANCE-1] PUSH-GATE PARITY (blocker).** `factory-pr-review` Block 8 runs a HARDCODED CVP subset — verified the literal string `(0a/0c/1/2/13-17)` at `SKILL.md:328`, referenced again at `:328`/per-context §. This is a SEPARATE authority from the CVP scope registry. SLICE-5 MUST edit that subset string to include `0d/18/19/20` (e.g. `(0a/0c/0d/1/2/13-20)`) and update the prose. **Verify `scripts/preflight.sh`** — if it hardcodes the same subset, edit + bump it too. Without this, the new checks fire at BLUEPRINT --approve but NOT at the local push preflight — the §7 "push-gate parity" goal is false.

> **[CRIT-GOVERNANCE-5] monotonic side-fix — own RDR, NOT bundled.** Verified: `increment_plan_template.md` § Invariants item 5 `increment_status_monotonic` says "Enforced by CVP" but CVP has NO such function (only `immutability_policy.check_increment_immutability` enforces monotonicity). This doc/impl drift is real. **Do NOT bundle a new CVP function into EVOL-036.** Resolution = reword the template line to "delegated to `immutability_policy.check_increment_immutability`" (1-line, no new surface, the `increment_plan_template.md` bump already exists). Authoring an actual CVP function is a SEPARATE `fix/` branch, out of EVOL-036 scope. Check 20 then inherits the consistent "delegate to immutability_policy" stance.

---

## 6. IPP — slice_map persistence (`[CRIT-GOVERNANCE-4]` reframe)

File: `factory-incremental-persistence/SKILL.md`.
- **Pillar 2 save-unit table** — add row: `CODESIGN | slice_map.md | "Frontmatter + §0 Decision History frozen at RDR ratification; each §1 SLICE-{FEAT}-N as its own atomic section; §2 seam table; §3 slice-order Mermaid (non-authoritative) on completion"`.
- **CODESIGN Per-Agent summary** — `--start`: `skeleton slice_map.md → save §0 at RDR ratification → save each §1 SLICE-N → save §2 seam table → save §3 diagram`. `--refine`: `append iterations[] via Iteration Append Pattern + CASCADE_SLICE_INTERNAL (slice_map→increment_plan, assignment-delta)`.
- **Resume-on-entry** — identical `resume_or_start()` semantics; slice_map carries `_progress` + `iterations[]` + `iteration_in_flight`, terminal at APPROVED.
- **Iteration Append Pattern** — cover slice_map (5-save idempotent + `iteration_in_flight` marker).
- **Hook allowlist** — add `slice_map.md` to the `docs/spec/{ID}/{...}` governance artefact allowlist.

> **[CRIT-GOVERNANCE-4] check-iteration-id-format.sh — NO allowlist exists.** Verified: the script is GLOB-driven — it scans ANY file with an `iterations:` frontmatter block and enforces (rule 3) a body anchor `## Iteration {id}` for `.md`. The original plan's "verify its artefact allowlist; if hardcoded add slice_map.md" rests on a list that does not exist. **Correct obligation (inverse):** `slice_map_template.md`'s skeleton AND the IPP Iteration Append Pattern MUST WRITE the `## Iteration ITER-{FEAT}-{N}` body anchor for every `iterations[]` entry, or CI fails on slice_map's first iteration. No script edit. Add a smoke assertion to `scripts/test-templates-static.sh` that the slice_map skeleton + a sample iteration round-trips through `check-iteration-id-format.sh`.

---

## 7. Governance — files, manifest, ADR, Rule 9, lock-step

### CLAUDE.md Rule 9 — universal, mirror in BOTH files
Insert `slice_map.md` into the refine-able-artefacts parenthetical BEFORE `increment_plan.md`:
`(\`spec.feature\`, \`user_journey.md\`, \`mock.html\`, \`slice_map.md\`, \`design.md\`, \`test_plan.md\`, \`increment_plan.md\`, \`dev_plan.md\`)`.
Mirror in `.context/templates/setup/claude/CLAUDE.md`. Rule 9 is universal (drift = bug) but is NOT inside the lock-step `universal_sections` → `check-lockstep-pairs.sh` will NOT catch the drift → **mirror by HAND**.

### Lock-step considerations (`[CRIT-GOVERNANCE-3]` stale premise corrected)
> **[CRIT-GOVERNANCE-3] blocker.** Verified live `config/coherence-context.json` → `universal_clause_mirror.universal_sections` now has **THREE** entries: `## Communication Style — MANDATORY`, `## RDR Universal — MANDATORY`, `## Adversarial Reasoning — MANDATORY` (the third added by merged EVOL-035). The original plan reasoned from a stale 2-section model. EVOL-036 touches NONE of the three H2 bodies (slice_map, CVP checks, cascade fn, seam fields all sit outside them) — so `check-lockstep-pairs.sh` stays green and the Rule-9 "mirror by hand" conclusion holds. BUT the plan MUST enumerate all three (read the config live, NOT Rule 12 prose). Separately flag: CLAUDE.md Rule 12's "(currently ## Communication Style + ## RDR Universal)" enumeration is ITSELF stale vs the config — out of EVOL-036 scope, note for a `docs/fix` follow-up; do NOT silently inherit the wrong count.
- Confirm against `config/coherence-context.json § audit.lock_step_pairs` before editing (also has 3 `meta_template_mirror` byte-identical pairs — verify none of those scripts are touched).

> **ASSUMPTION-D (RDR, open):** does slice immutability need a NEW CLAUDE.md universal LAW, or is extending `immutability_policy.md` + iteration-model sufficient? Recommend the LATTER (no new LAW, no lock-step burden — goal 3 says "extend the existing MERGED-anchor rule", which already lives in `immutability_policy.md` + the iteration-model skill). Surfacing because a new universal LAW would pull lock-step in.

### governance_versions.json bumps (ALL same commit per touched-file slice — Generation Standards §2; `framework_version 5.4.0 → 5.5.0` MINOR — verified current 5.4.0)
**framework_core (MINOR each, live versions verified):** `CLAUDE.md` 13.3.0→13.4.0; `commands/codesign.md` 1.3.0→1.4.0; `commands/blueprint.md` 1.5.1→1.6.0; `instructions/Factory-codesign-feature.instructions.md` 2.9.1→2.10.0; `instructions/Factory-blueprint-design.instructions.md` 3.4.1→3.5.0; `skills/factory-coherence-validation/SKILL.md` 1.3.4→1.4.0; `skills/factory-iteration-model/SKILL.md` 2.5.1→2.6.0; `skills/factory-incremental-persistence/SKILL.md` 2.3.2→2.4.0; `skills/factory-pr-review/SKILL.md` 1.7.0→1.8.0 (Block-8 subset + Hard-Gate row).
**agent_templates (MINOR each):** `architect/increment_plan_template.md` (per-INC cascade_source/seam + §0 reword + monotonic line reword) MINOR; `codesign/gherkin_master_template.feature` MINOR (slicing-note rewrite); `codesign/user_journey_template.md` MINOR (slicing-note rewrite). **NEW:** `codesign/slice_map_template.md` @ `1.0.0`, `content_type: universal`, `target: ".context/templates/codesign/slice_map_template.md"`, changelog `"1.0.0: feat(EVOL-036) initial — slice_map.md scaffold for two-stage vertical slicing (CODESIGN value slices -> BLUEPRINT increment_plan)."`.
**templates (MINOR):** `rules/immutability_policy.md` 1.3.1→1.4.0; `claude/CLAUDE.md` 3.2.0→3.3.0.
**Possibly touched — verify before claiming "unchanged" (`[CRIT-GOVERNANCE-5]`):** if any slice_map reference lands in `Factory-blueprint-validation.instructions.md` or `Factory-implement-plan.instructions.md`, bump them too. `scripts/preflight.sh` + `scripts/test-templates-static.sh` if edited (5).
Per-slice PR end-check: run `git diff --name-only origin/main..HEAD` against `governance_versions.json` keys and assert every touched tracked path has a bump + changelog line (catch pre-push; `governance-check.yml` is the CI backstop). High count (~14) — easy to miss one.

### ADR-EVOL-036
`docs/project_log/evolutions/ADR-EVOL-036-two-stage-vertical-slicing.md` (model on `ADR-EVOL-*` siblings). Records: slicing-authority migration (CODESIGN owns capability-VALUE slices, BLUEPRINT refines contract-decomposition + holds feasibility veto); the per-scenario freeze-partition decision (NOT scalar status); the deliberate widening of "CVP is per-feature" for cross-feature seam reads; the four ratified ASSUMPTIONS (A naming/family, B killed, C monolithic-in-BLUEPRINT, D no-new-LAW). Lands `proposed` with SLICE-1; flips `accepted` with SLICE-5, amending CLAUDE.md/templates in the SLICE-5 PR (`check-adr-constitution-sync.sh`; flaky-scenario-3 re-run workaround).

### factory-sync.sh — NO EDIT
`sync_tree` `[7/7]` recursively syncs `.context/templates`; `slice_map_template.md` propagates automatically.

### Template note-comment edits (coherence — part of the ALL-OR-NOTHING §3 migration)
- `gherkin_master_template.feature:37-41` — rewrite Incremental-Slicing Note: slice_map.md (CODESIGN, capability-value) is the FIRST slicing stage feeding increment_plan.md (BLUEPRINT, contract-level), NOT direct scenario→increment.
- `user_journey_template.md:23` — reference slice_map.md (capability-value slices) as producer, refined by BLUEPRINT into increment_plan.md.

### factory-pr-review (push gate parity)
`factory-pr-review/SKILL.md` — (a) edit the Block-8 CVP subset string to include `0d/18/19/20`; (b) add a Hard-Gate row: `slicing_strategy: incremental feature without slice_map.md APPROVED → Blocker (CVP slice_map_presence)`. Update `references/docs-sync-checklist.md`.

---

## 8. Vertical-slice breakdown of EVOL-036 itself

See `slice_breakdown`. Order strictly 1 → 2 → 3 → 4 → 5. ADR-EVOL-036 `proposed` with SLICE-1, `accepted` with SLICE-5.
