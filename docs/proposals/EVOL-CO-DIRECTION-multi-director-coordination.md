---
title: EVOL-CO-DIRECTION — Multi-Director Coordination Protocol (exploration)
status: exploration
date: 2026-05-18
author: Claude (spawned from EVOL-034 split, session 2026-05-18)
parent_proposal: EVOL-034-framework-downstream-awareness.md
empirical_inputs:
  - e2its/Nexus-Tech-Link ADR-0003 (cross_territory_scope local convention)
  - EVOL-034 deferred findings: 1-axis (cross_territory_scope), 3 (Check 3 false-positives), 4 (changelog re-introduction)
subsumed_primitives:
  - field: framework_core_excluded_in_downstream
    origin: EVOL-034 Theme C / Finding #3
    recast: "implied by territory model — files in co-director's territory"
  - field: changelog_policy
    origin: EVOL-034 Theme C RDR-4 / Finding #4
    recast: "per-territory governance metadata convention"
  - field: adr_exemption_axes
    origin: EVOL-034 Theme C RDR-5 / Finding #1 axis
    recast: "primitive of the territory model, not standalone axis list"
phase: RFC
deferred_until: design convergence (no deadline)
produces: chain of numbered EVOLs (estimated 3-5) after RFC phase converges
---

# Multi-Director Coordination Protocol — exploration

## What this is

NOT an EVOL. An **RFC / design exploration** track spawned when EVOL-034 scope reduction surfaced a deeper architectural question:

> Should Factory natively support **multi-director topologies** where Factory coordinates with a peer AI framework (Lovable, Bolt, V0, Replit, equivalent) operating on shared or adjacent territory in a nested-repo topology?

This document captures the design surface, the empirical inputs, and the open questions. It does NOT propose a solution — that's the work of the RFC phase that follows.

## Genesis

- **Empirical trigger:** nexus session 2026-05-18 surfaced 7 framework defects (EVOL-034). Three of them (Theme C: #1-axis, #3, #4) were originally framed as "downstream-awareness contract" but reflected a deeper pattern.
- **Trigger event for split:** during EVOL-034 RDR ratification, user noted that nexus + MASS are going independent forks → Theme C loses immediate driver → recognized that the underlying pattern (Factory + co-director on nested repos) is a class of usage that the framework does not natively support.
- **Insight:** Theme C primitives (`changelog_policy`, `adr_exemption_axes`, `framework_core_excluded_in_downstream`) are **workarounds for a missing abstraction**. The abstraction itself is the co-director protocol.

## The pattern (as observed in nexus)

```
~/dev/products/Nexus-Tech-Link/             ← Factory's project root
├── .git/                                    (Factory authors here)
├── CLAUDE.md                                (Factory's project-level constitution)
├── docs/                                    (Factory's territory: governance, ADRs, specs)
├── scripts/                                 (Factory's territory: tooling)
├── config/                                  (Factory's territory)
├── lovable/                                 (Lovable's territory: UI, components)
│   ├── src/components/                      (Lovable authors)
│   ├── src/pages/                           (Lovable authors)
│   └── ...
└── supabase/                                (Lovable's territory: BaaS schemas)
```

Two directors operate on the SAME git tree. Each has natural ownership of a subtree. Some files (root-level config, README, certain docs) live in soft-shared territory and need explicit cross-territory authorisation.

nexus' [ADR-0003 cross_territory_scope](nexus-side) was the local solution: ADRs declare `cross_territory_scope:` listing the authorised paths; either director MAY author in the other's default territory IF an accepted ADR grants the crossing.

## Empirical inputs re-interpreted

| Finding (EVOL-034 original framing) | Co-director re-framing |
|---|---|
| #1 (axis) "framework gate unaware of project ADR convention" | "Factory's Block 12 gate has no way to know which paths Lovable owns" |
| #3 "validate-governance.sh false-positives in downstream" | "Factory expects its own framework files; in a co-director repo, some don't exist because the other director owns those areas (or because the project deliberately split governance)" |
| #4 "factory-sync.sh re-introduces changelog frontmatter" | "Factory's materialisation conflicts with co-director's governance model (Lovable doesn't carry per-file changelogs)" |

Each finding is a manifestation of "Factory assumes sole authority; in reality it shares authority".

## Design surface — open questions

8 design areas surfaced during EVOL-034 split discussion. None are designed yet; this is the RFC backlog.

### 1. Territory model
- **Granularity:** path / glob / module / fileset / per-file frontmatter?
- **Declaration:** ADR (heavy ceremony, audit trail) vs `coherence-context.json` (single-file, mechanical) vs per-file frontmatter (distributed)?
- **Inheritance:** does ownership of `src/` imply ownership of all children? Override mechanism?
- **Default ownership:** what happens to a new file no rule covers?
- **Soft vs hard boundaries:** nexus' "soft" model allows ADR-authorised crossings; a "hard" model would forbid them entirely.

### 2. Conflict resolution
- Both directors want to author the same file in the same session: who wins?
- Branch separation per director vs shared branch with file-level discipline?
- File lock files (`*.author-locked`) vs ratification ceremony per cross-territory edit vs no enforcement (trust)?
- Federated PR review (both directors must sign)?

### 3. Governance federation
- Factory has constitution + LAWs + DCs + ADRs. Lovable has prompt + rules + (its own ADR equivalent?).
- Merge into one snapshot? Keep separate snapshots with cross-references? Each director loads only its own snapshot?
- When a Factory rule and a Lovable rule conflict, who wins?

### 4. Sync semantics across boundary
- `factory-sync.sh` updates Factory's territory. Does a parallel `lovable-sync` (or equivalent) exist?
- Order, atomicity, rollback when both run.
- Do the syncs see each other (e.g. factory-sync detects Lovable territory and skips, vs runs naively and corrupts)?

### 5. Branching strategy
- Single git tree with two directors editing different subtrees (current nexus model).
- Git submodules (Lovable's territory as separate repo).
- Nested independent repos (Factory at `~/dev/products/X/`, project at `~/dev/products/X/project/` with own `.git`) — the topology already mentioned in [Factory-protocol-cwd-discipline.instructions.md](../../.claude/instructions/Factory-protocol-cwd-discipline.instructions.md).
- Working trees (one repo, two checkouts).

### 6. PR ownership
- When a PR touches both territories: federated review (both directors must approve), per-territory PR split (one PR per director), or single owner-of-record per PR.
- How does Factory's `factory-pr-review` skill behave when the PR includes Lovable-authored files?

### 7. SETUP discovery
- How does Factory know a co-director is present? Marker file? `coherence-context.json` declaration? Detection by directory structure?
- At SETUP time, materialise territory map. With what RDRs?
- Q-discovery: cold-start without explicit declaration — does Factory ask or assume?

### 8. Lifecycle interleave
- Factory's `/blueprint` (design phase) + Lovable's iterative UI generation: sequential phases, parallel tracks with sync points, or callback-driven?
- When Factory's `/implement` would touch a file in Lovable's territory, does it: refuse, ratify, delegate?
- BVL/CVP/GCRP — do they respect territory boundaries when running checks?

## Subsumed primitives from EVOL-034 Theme C

When the co-director model converges, these EVOL-034-deferred fields become primitives of the new abstraction:

| EVOL-034 primitive | Re-cast within co-director model |
|---|---|
| `framework_core_excluded_in_downstream: [...]` | Implied by territory ownership — Factory's gates only check Factory's territory; co-director's files don't trigger warnings because they're outside scope. No explicit allowlist needed. |
| `changelog_policy: inline \| manifest` | Per-territory governance metadata convention — Factory declares its convention; co-director declares its own; no global policy required. |
| `adr_exemption_axes: [...]` | Territory exemption is a primitive of the territory model — `cross_territory_scope:` in an ADR is the **authorisation**, but the *mechanism* (who checks, who exempts) is the territory engine, not a generic axis list. |

## Process

### Phase 1 — RFC (this document expanded)

Tasks:
- Survey **Lovable's contract** (prompts, rules, deliverable structure, file conventions). Critical — without empirical detail, design is guesswork.
- Survey peers (Bolt, V0, Replit, equivalents) IF scope warrants more than the Factory + Lovable case.
- For each of the 8 design areas: enumerate alternatives, identify decision criteria, draft proposed RDRs.
- Decide: ONE-shot architectural model OR composable mini-models (territory + federation + lifecycle as independent layers)?

### Phase 2 — Design convergence

- Pick territory model (after RFC review by user).
- Sketch the chain of EVOLs needed to implement the chosen model (estimated 3-5).
- Each EVOL gets its own ratification scope; this exploration document closes when the chain is announced.

### Phase 3 — EVOL chain implementation

Probable order:
1. **EVOL-XXX-A:** SETUP discovery + territory model schema (RDRs: detection mechanism, declaration syntax, granularity)
2. **EVOL-XXX-B:** Gate awareness (factory-pr-review Block 12, validate-governance.sh Check 3, security-scan.sh) — replaces EVOL-034 deferred items
3. **EVOL-XXX-C:** factory-sync.sh federation (per-territory sync, cross-boundary handshakes) — replaces EVOL-034 Finding #4
4. **EVOL-XXX-D:** BLUEPRINT / IMPLEMENT lifecycle interleave (if scope warrants)
5. **EVOL-XXX-E:** PR review federation (if scope warrants)

## Open invitations

- **Empirical data needed:** sample Lovable workflow on a real co-director project. Do we have access to nexus' Lovable side, or another project? Without traces, the territory model is guesswork.
- **Stakeholder alignment:** is the framework owner commercially interested in supporting Lovable + Factory as a first-class combo, or is this exploration value-without-immediate-deployment?
- **Co-director scope:** which ones in scope? Lovable confirmed by nexus; Bolt / V0 / Replit / custom — optional or out?
- **Hard vs soft authority model:** nexus picked "soft" (ADR-authorised crossings). Is that the framework's preferred default, or do we want "hard" boundaries with explicit delegation?

## Status

**OPEN — exploration only.** No deadline. Spawns numbered EVOLs once Phase 2 design converges.

## Cross-references

- Parent proposal: [EVOL-034-framework-downstream-awareness.md](EVOL-034-framework-downstream-awareness.md) — deferred Theme C, RDR-4 + RDR-5
- Existing partial foundation: [Factory-protocol-cwd-discipline.instructions.md](../../.claude/instructions/Factory-protocol-cwd-discipline.instructions.md) — nested-repo CWD discipline already cataloged
- Existing schema: [config/coherence-context.json](../../config/coherence-context.json) — `context: meta|downstream` discriminator already exists; needs extension for `context: co-director-project` or similar
- nexus' local convention: e2its/Nexus-Tech-Link ADR-0003 (private repo) — primary empirical reference
