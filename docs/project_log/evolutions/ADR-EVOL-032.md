---
id: ADR-EVOL-032
title: --refine deepening + MCP-docs scan banner
date: 2026-05-16
status: accepted
---

# ADR-EVOL-032: `--refine` deepening across CODESIGN / BLUEPRINT / IMPLEMENT + MCP-docs scan banner

## Context

The `--refine` flow across the three SDLC commands was uneven and underspecified:

- **CODESIGN `--refine`** carried rich machinery (Tripartite Alignment re-run, Change Classification, CIP Re-Check) but the changelog only lived on `spec.feature`; `mock.html` and `user_journey.md` had none. No formal step to inspect what's already implemented before iterating.
- **BLUEPRINT `--refine`** had NO dedicated instruction — only a 2-line stub at `.claude/commands/blueprint.md:31-32`. The mandate existed; the protocol didn't. No introspection of implementation state. No mechanism for "designed but never built" carry-over.
- **IMPLEMENT `--refine`** had the richest protocol (`[ADJ-N]` / `[D.N]` delta tasks, `based_on_iteration` tracking, upstream artefact validation) but did NOT explicitly call CVP at refine time — only implicitly via BVL at build end.
- **No iteration-ID schema** crossed artefacts. Each artefact carried its own scalar `iteration: N` and a markdown `## Changelog` table; impossible to mechanically join "this refinement of `spec.feature`" ↔ "this refinement of `design.md`" ↔ "this refinement of `dev_plan.md`".
- **No MCP-docs awareness** at BLUEPRINT `--start`/`--refine` or IMPLEMENT `--build`/`--refine`. The agent had access to docs MCPs (context7, aws-knowledge, etc.) but the framework didn't instruct it to consult them before generating design/code, nor surface which were available.

The user explicitly enumerated the desired sub-steps for each `--refine` (4 for CODESIGN, 8 for BLUEPRINT, 6 for IMPLEMENT) and required a mandatory MCP-docs scan + on-screen banner at the 4 entry points.

## Decision

Ship as one EVOL across 3 phases on `feature/EVOL-032-refine-deepening-mcp-scan`:

- **Phase 1 — Iteration model groundwork (dual-format, additive).** Canonical `ITER-{FEAT}-{N}` ID schema as cross-artefact join key. 8 artefact templates gain frontmatter `iterations: []` array (entries: id, iteration, date, source, classification, scope_summary, downstream_impact, anchor, rdr_rounds, converged, impl_state_snapshot, cascade_source, mcp_consulted). `design.md` additionally gains `pending_design_items: []` (BLUEPRINT impl-state probe carry-over slot). `factory-iteration-model` § Canonical Iteration ID Schema + cascade contract (`pending_iteration = iterations[-1].iteration` of upstream) + dual-format read protocol (`read_iteration_state()` wrapper — array-aware when present, falls back to scalar). `factory-incremental-persistence` § Iteration Append Pattern with `_progress.iteration_in_flight` marker + 5-save crash-safe sequence. Three gate instructions route iteration reads through the dual-format wrapper. New `scripts/check-iteration-id-format.sh` CI gate. New `scripts/migrate-iteration-frontmatter.sh` (opt-in, idempotent) converts legacy artefacts. Capability flag `governance_features.iterations_array_v1: 1.0.0` in the manifest. `framework_version` bumps 4.4.0 → 5.0.0 (BREAKING because the capability flag is a new gate contract; legacy scalar reads remain compatible for one minor version).

- **Phase 2 — `--refine` deepening.** CODESIGN Iteration Execution restructured into 4 sub-steps (1.1 impl-state probe → 1.2 iterative RDR loop on Disparity Resolution Protocol → 1.3 apply → 1.4 aggregated changelog on `spec.feature` + `user_journey.md` + `mock.html` via `append_iteration_entry`). NEW INSTRUCTION `Factory-blueprint-refine.instructions.md` (8 steps: locate → design state → dependencies → impl-state probe (auto) → update with gaps → MCP-docs → apply → aggregated changelog). IMPLEMENT `--refine` Refine section augmented: delta tasks carry `origin: ITER-{FEAT}-{N}` + `task_class: NEW | EXISTING | MODIFIED | CARRIED_OVER`; `design.md.pending_design_items[]` (BLUEPRINT carry-over) become CARRIED_OVER delta tasks; CVP gate moved to AFTER delta generation (sequencing correction — running BEFORE would validate stale `dev_plan.md` against new spec); iteration entry persisted with `delta_tasks` checklist read by `--build`. The three command files gain enumerated sub-step lists pointing at the canonical instructions.

- **Phase 3 — MCP-docs scan + mandatory banner.** NEW SKILL `factory-mcp-docs-scan/SKILL.md`. Agent-side algorithm: introspect own tool registry (`mcp__*` prefix), intersect with explicit frontmatter allowlist (`context7, aws-knowledge, pulumi, claude_ai_*`), emit single-line banner mirroring Applicability Roll-Call style. Banner is MANDATORY first user-facing turn of each of the 4 entry commands; missing banner = `mal-iniciado`. Per-invocation scan (NOT cached across turns — MCP servers can crash mid-feature). `none detected` is a warning, never a block. Citation contract: when `docs_mcps` not empty, consumer must cite + populate `iterations[-1].mcp_consulted: [names]`. Wired at Factory-blueprint-design Step 0c, Factory-blueprint-refine Pre-Flight Step 4, Factory-implement-build Step 0a (`--refine`) + Step 0-MCP (`--build`). Commands gain MCP-Scan-Banner bullet items.

The whole EVOL ships atomically via `factory-sync.sh` (one governance bump) so a downstream project never sees a half-applied state.

**Alternatives considered:**
- Alternative 1: Split into 2 EVOLs (A: refine deepening + iteration model; B: MCP scan) — Discarded by RDR-A. Coherence advantage of one EVOL outweighs the smaller blast-radius of two.
- Alternative 2: Sidecar `iterations.jsonl` per feature for downstream queries (instead of in-file frontmatter array) — Discarded by RDR-B. Frontmatter+anchor keeps the artefact self-describing; sidecar would leave the artefact mute about its own history.
- Alternative 3: Opt-in `--probe-impl` flag for BLUEPRINT `--refine` impl-state probe — Discarded by RDR-C. Auto-trigger when `dev_plan.md` has `[x]` tasks OR feature branch has commits beyond design point is the smart default that avoids gap-by-forgotten-flag.
- Alternative 4: Universal MCP scan across all commands (CODESIGN, QA, DEVOPS too) — Discarded by RDR-D. CODESIGN produces spec/mock (not technical solutions); QA / DEVOPS scopes were out of the literal user request. Bounded to the 4 entry points where design/code materialises.

## RDR Decisions Ratified (2026-05-16)

| # | Question | Choice |
|---|----------|--------|
| A | EVOL scope | 1 EVOL in 3 phases on one branch, one PR. |
| B | Iteration model | Frontmatter `iterations: []` + in-file `## Iteration ITER-{FEAT}-{N}` anchored section. Co-exists with legacy `iteration: N` + `iteration_history[]` for one minor version. |
| C | BLUEPRINT impl-state probe trigger | Auto-trigger when `dev_plan.md` has any `[x]` task OR feature branch has commits beyond design point. |
| D | MCP scan reach | BLUEPRINT `--start`/`--refine` + IMPLEMENT `--build`/`--refine` — 4 entry points. CODESIGN out of scope. |

## Plan-Agent Risk Callouts Resolved

1. **Schema break for in-flight gates** (gates read scalar `iteration: N`). → Dual-format `read_iteration_state()` wrapper at every gate site; capability flag `iterations_array_v1` lets gates branch on capability rather than file version. Both shapes readable.
2. **Cascade scalar vs array contract.** → Defined: `pending_iteration` (scalar N on downstream) = `iterations[-1].iteration` of upstream. `cascade_source` accepts both ITER ID and legacy agent-name string.
3. **CVP sequencing was backwards in original draft** (CVP runs BEFORE delta task generation → validates stale dev_plan against new spec → guaranteed to fail). → Corrected: CVP runs AFTER delta generation, mirroring how BLUEPRINT `--approve` runs CVP after design is finalized. PREREQ: `design.md.pending_iteration` cleared by BLUEPRINT `--refine` first (Step 0a Upstream Sync Gate enforces).
4. **Atomic sync to avoid half-applied state in materialised projects.** → All 3 phases ship in one PR with one `framework_version` bump. No `--phase` flag.
5. **MCP-docs allowlist (not heuristic).** → Explicit `docs_mcp_allowlist` in skill frontmatter. Adding a docs MCP requires editing the skill. No regex / heuristic detection.
6. **`_progress.iteration_in_flight` marker** to survive mid-iteration interrupts. → New field in IPP `_progress`; 5-save crash-safe sequence in `factory-incremental-persistence § Iteration Append Pattern`; CI gate blocks merge when marker is left set.

## Consequences

**Positives:**
- Cross-artefact iteration history mechanically queryable (`grep cascade_source: ITER-X-N docs/spec/X/`).
- BLUEPRINT `--refine` catches drift / carry-over / emergent gaps between design and code that previously slipped silently into IMPLEMENT.
- CVP at IMPLEMENT `--refine` catches gaps in the delta itself — no more "delta tasks generated but cross-artefact gaps remain" failure mode that only surfaced at build end.
- Mandatory MCP-docs banner makes documentation consultation visible and citable, raising the floor of "I used training-data assumptions" silently slipping into design / implementation.
- Carry-over slot (`pending_design_items[]`) closes the long-standing "designed-but-never-built" leak (Plan-Agent gap #2 surfaced during exploration).

**Negatives / Trade-offs:**
- Schema migration. Existing materialised projects (Nexus-Tech-Link, MASS) must run `SETUP --upgrade`; the upgrade invokes `migrate-iteration-frontmatter.sh` (opt-in per feature, skips `status: BUILDING`). Some features will live in dual-format limbo for a minor version cycle.
- 38 framework artefact files received a cosmetic prose cleanup pass in the same EVOL (separate `chore` commit) to align with the long-standing "no version refs in artefact bodies" rule. Mass diff; git blame walks an extra hop on the touched files.
- `_progress.iteration_in_flight` marker adds one more field to IPP frontmatter. Resume-on-entry logic gains a third branch (`ALREADY_PERSISTED`).

## Compliance

- ✅ Complies with `CLAUDE.md` § Generation Standards #2: every framework-core file touched bumped + changelog line added in the same commit. `framework_version` bumped 4.4.0 → 5.0.0 with `feat!:` prefix to satisfy auto-tag MAJOR detection.
- ✅ Complies with `CLAUDE.md` § Pre-Action Gate: change shipped on `feature/EVOL-032-refine-deepening-mcp-scan` branch off `origin/main`.
- ✅ Complies with `CLAUDE.md` § RDR Universal: 4 strategic decisions ratified by the user via `AskUserQuestion`, captured verbatim in the table above; persistence is this ADR + commit messages + governance_versions.json entries.
- ✅ Complies with `CLAUDE.md` § Constitutional Supremacy: this ADR's Constitution Amendment section adds two new `[LAW]` sections to `CLAUDE.md` (Iteration ID convention + MCP-docs scan mandate) and mirrors byte-identical universal additions to `.context/templates/setup/claude/CLAUDE.md`.
- ✅ Complies with `CLAUDE.md` § Communication Style (caveman + no version refs in artefact bodies): the same EVOL includes a separate `chore` commit stripping `(vN.N.N)` decorations, `pre-/post-EVOL-NNN` prose, and similar version-talk from 38 framework files.

## Operational Rule

```
Every refine-able artefact (spec.feature, user_journey.md, mock.html, design.md,
test_plan.md, increment_plan.md, dev_plan.md) carries a frontmatter `iterations: []`
array whose entries follow the canonical schema ITER-{FEAT}-{N} per
factory-iteration-model. Downstream entries cross-reference upstream via
cascade_source: {upstream_id}, providing a mechanical join key for queries.

BLUEPRINT --start / --refine and IMPLEMENT --build / --refine MUST emit the
factory-mcp-docs-scan banner as the first user-facing line of every invocation.
Missing banner = mal-iniciado. The scan is per-invocation (never cached across
turns) and uses an explicit allowlist (no heuristic detection).
```

## Constitution Amendment

> **MANDATORY when this ADR transitions to `status: accepted`** (Governance Rule 1 — CLAUDE.md).
> The same PR that flips `status:` to `accepted` MUST apply the edits below to the relevant governance source. CI gate `scripts/check-adr-constitution-sync.sh` blocks the PR if no governance source is in the diff alongside the status flip.

- **Section affected:** `CLAUDE.md` (root meta) and `.context/templates/setup/claude/CLAUDE.md` (template). Two new universal `[LAW]` blocks added under § Governance Rules:
  - **LAW 9** — Canonical iteration ID + cross-artefact join: `ITER-{FEAT}-{N}` (`factory-iteration-model § Canonical Iteration ID Schema`).
  - **LAW 10** — Mandatory MCP-docs scan banner at BLUEPRINT `--start`/`--refine` + IMPLEMENT `--build`/`--refine` (`factory-mcp-docs-scan/SKILL.md`).
- **Before:** Governance Rules ended at LAW 8 (Humanized Blocking).
- **After:** LAW 9 + LAW 10 appended with full text mirroring the Operational Rule above. Both files updated byte-identical per "What Lives Where".
- **Constitution version bump:** none (this `meta` repo has no `docs/constitution.md`; the universal LAW lives in `CLAUDE.md`).
- **Changelog entry:** the `framework_version` bump 4.4.0 → 5.0.0 in `governance_versions.json` carries the cross-reference.
