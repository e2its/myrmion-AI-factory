---
title: EVOL-PROPOSAL — Framework Downstream-Awareness (analysis & design)
status: proposed
date: 2026-05-18
author: Claude (drafted from nexus session 2026-05-18)
source: e2its/Nexus-Tech-Link PRs #13–#18; ADR-0003 Traceability
covers_findings_full: [2, 5, 6, 7]
covers_findings_partial: [1]   # field-name half only; axis half deferred
deferred_findings:
  - finding: 1
    aspect: axis (cross_territory_scope)
    target: EVOL-CO-DIRECTION
  - finding: 3
    target: EVOL-CO-DIRECTION
  - finding: 4
    target: EVOL-CO-DIRECTION
proposes_evols: [EVOL-034]
spawns_exploration: EVOL-CO-DIRECTION-multi-director-coordination.md
branch: docs/evol-proposal-downstream-awareness
ratified_rdrs:
  - id: RDR-1
    date: 2026-05-18
    choice: "Option B (single EVOL covering all 7 findings)"
    user_verbatim: "podriamo agrupar todo en un PR evolutivo, no creo que sea muy pesado"
    later_refinement: "Scope reduced same day to Themes A + B only; Theme C deferred to EVOL-CO-DIRECTION track. Single-EVOL principle still holds for the reduced scope."
  - id: RDR-2
    date: 2026-05-18
    choice: "Option A (`paths`, flat array)"
    user_verbatim: "cual es tu recomendacion? → A; me encaja este split"
    rationale: "Nexus + MASS forking off as independent forks → no legacy fleet to migrate → pick cleanest contract over backward compat."
deferred_rdrs:
  - id: RDR-4
    target: EVOL-CO-DIRECTION
    reason: "changelog policy becomes a natural primitive of co-director governance federation; designing without active consumer = guesswork."
  - id: RDR-5
    target: EVOL-CO-DIRECTION
    reason: "ADR exemption axes become primitives of the territory model, not standalone framework contract."
open_rdrs: [RDR-3]
---

# Framework Downstream-Awareness — analysis & design

Pre-ratification proposal. RDR-1 ratified → single EVOL-034. RDR-2 ratified → Option A. Theme C (3 findings) deferred to [EVOL-CO-DIRECTION](EVOL-CO-DIRECTION-multi-director-coordination.md) exploration. After RDR-3 ratification, this proposal hands off to `docs/project_log/evolutions/ADR-EVOL-034-framework-downstream-awareness.md` and triggers `feature/EVOL-034-framework-downstream-awareness`.

## TL;DR

7 findings analyzed across 3 themes. RDR-1 ratified single-EVOL approach; further scope reduction same day when user noted nexus + MASS are going independent forks → Theme C (downstream-awareness contract) loses immediate driver → deferred to EVOL-CO-DIRECTION where its primitives are redesigned as natural building blocks of a multi-director protocol.

| Theme | Findings | Nature | Disposition |
|---|---|---|---|
| **A — Lock-step drift** | #5, #6, #7 | Meta script fixed but template not backported | **EVOL-034 sub-task 1** |
| **B — Schema incoherence** | #1 (field), #2 | Same JSON read with different shapes/names by different consumers | **EVOL-034 sub-task 2** |
| **(infrastructure)** | — | Lock-step pair enforcement to prevent recurrence | **EVOL-034 sub-task 3** |
| **C — Downstream-awareness contract** | #1 (axis), #3, #4 | Framework assumes meta invariants; needs explicit contract | **DEFERRED → EVOL-CO-DIRECTION** |

## Validation — ground truth per finding

All file paths verified against `mi-AI-Factory-for-Claude` HEAD (`main` @ 971dd28, 2026-05-18). Validation kept for all 7 findings even though 3 defer — empirical evidence remains valid for the EVOL-CO-DIRECTION inputs.

### Finding #1 — Block 12 unaware of `cross_territory_scope`
- **Confirmed.** Block 12 lives at [`.claude/skills/factory-pr-review/scripts/preflight.sh:309-321`](../../.claude/skills/factory-pr-review/scripts/preflight.sh#L309-L321).
- Reads `config/protected-paths.json` → **`.paths`** field (NOT `.red_zones` as the brief claimed). Pure Python `fnmatch` loop, no frontmatter scanning anywhere in the SKILL or its scripts.
- `cross_territory_scope` appears **zero times** in the framework codebase.
- Total blocks in SKILL: 19.
- **Two-aspect split:** field-name aspect (`.paths` vs `.red_zones`) → EVOL-034 Theme B. Axis aspect (cross_territory_scope ADR scanning) → EVOL-CO-DIRECTION.

### Finding #2 — security-scan.sh jq shape mismatch
- **Confirmed.** Both [`scripts/security-scan.sh:210`](../../scripts/security-scan.sh#L210) and [`.context/templates/setup/scripts/security-scan.sh:210`](../../.context/templates/setup/scripts/security-scan.sh#L210):
  ```bash
  RED_ZONE_PATTERNS=$(jq -r '.red_zones | to_entries[] | .value[]' "$PROTECTED_PATHS_FILE" ...)
  ```
- Template `protected-paths.json` declares `.red_zones` as a **flat array** (lines 2-14).
- jq expression expects **object-of-arrays**. Mismatch is internal to the framework — not introduced by downstream.

### Finding #3 — `validate-governance.sh` Check 3 stale-detection — DEFERRED
- **Confirmed.** [`scripts/validate-governance.sh:367-384`](../../scripts/validate-governance.sh#L367-L384) iterates `framework_core` entries, `warn()`s any path missing on disk. No conditional on `coherence-context.json § context`.
- Deferred to EVOL-CO-DIRECTION: in the co-director model this becomes "files in co-director's territory" — implied by territory model, not a separate allowlist field.

### Finding #4 — `factory-sync.sh` re-introduces `changelog:` frontmatter — DEFERRED
- **Confirmed.** [`scripts/factory-sync.sh:161-211`](../../scripts/factory-sync.sh#L161-L211) `sync_file()` is byte-identical `cp`. Zero post-processing.
- **29 template `.md` files** carry `changelog: [...]` frontmatter.
- Deferred to EVOL-CO-DIRECTION: in the co-director model this becomes "per-territory governance metadata convention" — Factory carries changelogs in its territory; co-director may have different convention.

### Finding #5 — auto-tag workflow SIGPIPE
- **Confirmed in meta — surprise.** [`.github/workflows/auto-tag.yml:57`](../../.github/workflows/auto-tag.yml#L57) uses `echo "$OUTPUT" | awk -F= '/^TAG=/{print $2; exit}'` → SIGPIPE under implicit pipefail.
- Templates `auto-tag.bitbucket.yml:33` + `auto-tag.gitlab-ci.yml:37` same pattern.
- Template `auto-tag.github-actions.yml:43` uses `grep -oP` (different bug — GNU-only PCRE).

### Finding #6 — `auto-tag.sh` LAST_TAG accepts non-semver
- **Confirmed in template only — surprise.** Meta [`scripts/auto-tag.sh:60`](../../scripts/auto-tag.sh#L60) ALREADY hardened: `--match 'v*'`.
- Template [`.context/templates/setup/scripts/auto-tag.sh:58`](../../.context/templates/setup/scripts/auto-tag.sh#L58) NOT hardened.
- **Pure lock-step drift.**

### Finding #7 — `auto-tag.sh git log | head` SIGPIPE
- **Confirmed in template only — surprise.** Meta `scripts/auto-tag.sh:190,192` mitigated with `|| true`. Template `:124,126` not mitigated.
- **Pure lock-step drift.**

## Root-cause analysis — three themes

### Theme A — Lock-step drift (Findings #5, #6, #7)

Meta scripts and their template counterparts diverge because there is no enforcement that a fix in one half also lands in the other. `coherence-context.json` v1.1.0 mentions `lock_step_pairs` semantically but ships **no automated check**.

Evidence: #6 + #7 show meta-ahead drift. #5 shows meta itself is broken while one template variant was partially refactored — bidirectional drift.

### Theme B — Schema incoherence (Findings #1 field-name, #2)

`config/protected-paths.json` has three consumers in the framework:
- `factory-pr-review/preflight.sh` reads `.paths` (flat array, fnmatch)
- `security-scan.sh` reads `.red_zones | to_entries[] | .value[]` (object-of-arrays)
- Template config defines `.red_zones` as flat array

Two field names. Two shape assumptions. One file. Internal contract failure that the downstream happened to expose.

### Theme C — Downstream-awareness contract → DEFERRED

Originally framed as "framework needs explicit contract for meta-vs-downstream behaviour". Re-interpreted post nexus/MASS fork announcement as **co-director coordination pattern** — primitives belong in a multi-director model (EVOL-CO-DIRECTION), not as standalone framework contract fields.

## Implementation — EVOL-034 (Themes A + B + enforcement)

**Scope:** Findings #2, #5, #6, #7 + field-name half of #1. Plus new lock-step-pair enforcement infrastructure to prevent Theme A recurrence.

### Sub-tasks

**1. Lock-step backports (Theme A — Findings #5, #6, #7):**
- Template `auto-tag.sh:58` ← `--match 'v*'` from meta:60 (Finding #6)
- Template `auto-tag.sh:124,126` ← `|| true` (or switch to `git log -n 20` native) from meta:190,192 (Finding #7)
- Meta `.github/workflows/auto-tag.yml:57` fix awk SIGPIPE (Finding #5)
- Template workflow variants `auto-tag.bitbucket.yml:33` + `auto-tag.gitlab-ci.yml:37` — same SIGPIPE fix
- Template `auto-tag.github-actions.yml:43` — replace `grep -oP` with portable equivalent

**2. Schema canonicalisation (Theme B — Findings #1 field + #2):**
- RDR-2 RATIFIED 2026-05-18 = Option A (`paths`, flat array)
- preflight.sh:309-321 unchanged (already reads `.paths`)
- security-scan.sh:210 (meta + template): jq becomes `.paths[]`
- Template `protected-paths.json`: rename `red_zones` → `paths`

**3. Lock-step enforcement (new infrastructure):**
- Ratify RDR-3 (gate venue)
- New script `scripts/check-lockstep-pairs.sh` iterating `coherence-context.json § lock_step_pairs`, asserting parity
- If RDR-3=A: new CI workflow `.github/workflows/lockstep-check.yml`
- If RDR-3=B: BVL `full_verification_gate` integration
- If RDR-3=C: pre-commit hook
- Extend `coherence-context.json` v1.1.0 → v1.2.0 (MINOR, additive) adding `lock_step_pairs: [{meta, template}, ...]`

### Manifest impact

| Path | Bump | Sub-task | Reason |
|---|---|---|---|
| `scripts/auto-tag.sh` | none | 1 | meta already correct |
| `.context/templates/setup/scripts/auto-tag.sh` | MINOR | 1 | backport hardening (#6 + #7) |
| `.github/workflows/auto-tag.yml` | PATCH | 1 | SIGPIPE fix (#5) |
| `.context/templates/setup/workflows/auto-tag.bitbucket.yml` | PATCH | 1 | SIGPIPE fix |
| `.context/templates/setup/workflows/auto-tag.gitlab-ci.yml` | PATCH | 1 | SIGPIPE fix |
| `.context/templates/setup/workflows/auto-tag.github-actions.yml` | PATCH | 1 | portable parse |
| `scripts/security-scan.sh` | PATCH | 2 | jq `.red_zones | to_entries…` → `.paths[]` |
| `.context/templates/setup/scripts/security-scan.sh` | PATCH | 2 | jq (lock-step) |
| `.context/templates/setup/config/protected-paths.json` | MAJOR | 2 | field rename `red_zones` → `paths` (no live consumer; future projects only) |
| `scripts/check-lockstep-pairs.sh` | NEW 1.0.0 | 3 | added to `framework_core` |
| `.github/workflows/lockstep-check.yml` | NEW 1.0.0 (if RDR-3=A) | 3 | added to `framework_core` |
| `config/coherence-context.json` | MINOR | 3 | add `lock_step_pairs` (additive, no contract break) |

### Lock-step pairs to register in `coherence-context.json`
- `scripts/auto-tag.sh` ↔ `.context/templates/setup/scripts/auto-tag.sh`
- `scripts/security-scan.sh` ↔ `.context/templates/setup/scripts/security-scan.sh`
- `config/coherence-context.json` ↔ `.context/templates/setup/config/coherence-context.json` (if both exist)
- (others surfaced by inventory pass — enumerate during implementation)

### SETUP RDRs introduced
**None.** All RDRs are meta-only. RDR-2 (schema canon) is internal; SETUP `--generate` just materialises the chosen shape. RDR-3 (enforcement venue) is meta-CI choice with no SETUP exposure. RDR-4 + RDR-5 deferred to EVOL-CO-DIRECTION.

### Downstream migration
- nexus + MASS announced as independent forks (2026-05-18) → no active downstream consumer → no factory-sync.sh migration impact.
- Future materialised projects start clean on canonicalised `paths` field.

### BVL / CVP / GCRP impact
- **BVL:** RDR-3=B option would add `check-lockstep-pairs.sh` to `full_verification_gate` Step 8.
- **CVP:** no change.
- **GCRP:** no change — snapshot doesn't consume `coherence-context.json` or `protected-paths.json` today.

### Risk
**Low.** All sub-tasks are deterministic, reversible. Schema changes: `protected-paths.json` field rename has no live consumer (forks); `coherence-context.json` addition is additive (v1→v1.2.0). No contract additions to lock in.

### Alternatives considered (not chosen)
- **Two EVOLs (RDR-1 Option A):** Rejected by RDR-1 ratification on review-burden grounds.
- **Three EVOLs (RDR-1 Option C):** Rejected as EVOL inflation.
- **Keep Theme C in EVOL-034:** Rejected 2026-05-18 — no active downstream consumer; contract design without consumer = guesswork; primitives belong in EVOL-CO-DIRECTION.

## RDR list

Per [factory-rdr SKILL § Algorithm](../../.claude/skills/factory-rdr/SKILL.md) RDR ids are sequential per artifact. This proposal is the artifact → RDR-1..5. RDR-1 is the meta-decision and persists in the proposal. RDR-2 + RDR-3 renumber into ADR-EVOL-034 as RDR-1 + RDR-2 when that ADR is authored. RDR-4 + RDR-5 transfer to EVOL-CO-DIRECTION.

| Proposal-scope id | Status | Destination |
|---|---|---|
| RDR-1 (split decision) | ✅ RATIFIED 2026-05-18 | proposal-meta, history only |
| RDR-2 (protected-paths shape) | ✅ RATIFIED 2026-05-18 = A | ADR-EVOL-034 as RDR-1 |
| RDR-3 (lock-step venue) | 🔓 OPEN | ADR-EVOL-034 as RDR-2 |
| RDR-4 (changelog policy) | ⏭️ DEFERRED 2026-05-18 | EVOL-CO-DIRECTION |
| RDR-5 (ADR exemption axes) | ⏭️ DEFERRED 2026-05-18 | EVOL-CO-DIRECTION |

### RDR-1 — overall split decision

**Status:** ✅ RATIFIED 2026-05-18 — user chose **Option B (single EVOL)**, verbatim: *"podriamo agrupar todo en un PR evolutivo, no creo que sea muy pesado"*.

Later refinement same day: scope reduced to Themes A + B (Theme C deferred to EVOL-CO-DIRECTION). Single-EVOL principle still holds for the reduced scope.

### RDR-2 — protected-paths.json canonical shape

**Status:** ✅ RATIFIED 2026-05-18 — user accepted recommendation **Option A (`paths`, flat array)**.

**User signal:** *"cual es tu recomendacion?"* → I recommended A given nexus + MASS forking off (no legacy fleet to protect) → user replied *"me encaja este split"* batching ratification with the EVOL-034 scope reduction.

**Rationale:** without active legacy fleet, "no rompe lo desplegado" stops being a factor → pick cleanest contract. `paths` is the more natural noun, matches Block 12's current read (zero preflight change), forces single flat shape.

| Option | Field name | Shape | Disposition |
|---|---|---|---|
| **A (RATIFIED)** | `paths` | flat array | Chosen — clean contract over compat |
| B | `red_zones` | flat array | Not chosen — was compat option |
| C | `red_zones` | object-of-arrays | Not chosen |
| D | accept both shapes via conditional jq | as-is | Not chosen — weakest contract |

### RDR-3 — lock-step enforcement venue 🔓 OPEN

| Option | Description |
|---|---|
| **A (recommended)** | CI workflow (`lockstep-check.yml`) — runs on every PR, fails CI on diff |
| B | BVL `full_verification_gate` integration — runs before commit |
| C | Pre-commit hook — strongest enforcement, per-developer install friction |

**Recommendation:** A. Meta runs CI on every PR; one-script workflow is cheapest and uniform. BVL is project-side and only weakly invoked in meta.

### RDR-4 — changelog policy default ⏭️ DEFERRED

**Status:** DEFERRED 2026-05-18 to [EVOL-CO-DIRECTION](EVOL-CO-DIRECTION-multi-director-coordination.md).

**Reason:** changelog policy was framed as a per-project preference for governance metadata. In the co-director model it becomes a per-territory governance metadata convention — Factory carries changelogs in its territory; co-director may follow a different convention in its territory. Designing it standalone now would lock a contract that the territory model will replace.

Options preserved here for historical context — they may inform but won't bind the EVOL-CO-DIRECTION redesign.

| Option | Default | Existing projects |
|---|---|---|
| A | `inline` | Unchanged; opt into `manifest` at SETUP --upgrade |
| B | `manifest` | Migration step strips changelog from existing inline projects |
| C | Drop the field — always inline | — |

### RDR-5 — ADR exemption axes mechanism ⏭️ DEFERRED

**Status:** DEFERRED 2026-05-18 to [EVOL-CO-DIRECTION](EVOL-CO-DIRECTION-multi-director-coordination.md).

**Reason:** ADR exemption axes were framed as a generic exception mechanism for cross-cutting project conventions. In the co-director model, the territory itself is the natural exemption primitive — Block 12 doesn't ask "is this exempted by some axis"; it asks "is this in Factory's territory or another director's?". Designing the axis mechanism standalone now would create a workaround that the territory model obsoletes.

Options preserved here for historical context.

| Option | Description |
|---|---|
| A | Generic `adr_exemption_axes: [<axis>...]` field, default `["cross_territory_scope"]` |
| B | Hardcode `cross_territory_scope` as the single axis |
| C | Don't add — Block 12 stays strict |

## Scope / cost / risk

| EVOL | Files touched | RDRs to ratify | Schema break | Implementation est. | Risk |
|---|---|---|---|---|---|
| 034 | ~9 files (6 backports + 2 schema canon + 2 new for enforcement) | RDR-3 only | `protected-paths.json` field rename (no live consumer); `coherence-context.json` additive v1.1→v1.2 | 1-2 sessions | Low |

## Implementation sequence

1. ✅ RDR-1 ratified 2026-05-18 = single EVOL.
2. ✅ RDR-2 ratified 2026-05-18 = Option A (`paths` flat).
3. ⏭️ RDR-4 + RDR-5 deferred 2026-05-18 to EVOL-CO-DIRECTION.
4. **🔓 Ratify RDR-3** — only remaining decision before branching.
5. Author `docs/project_log/evolutions/ADR-EVOL-034-framework-downstream-awareness.md` — renumbers RDR-2 → RDR-1, RDR-3 → RDR-2 within that ADR.
6. Branch `feature/EVOL-034-framework-downstream-awareness` off `origin/main`.
7. Implement in sub-task order (1 → 2 → 3). Bump manifest per sub-task to preserve commit-level traceability.
8. PR + review + merge + tag.

## Open questions (trimmed post-defer)

- **Block 12 audit log.** When ADR exemption suppresses a blocker, emit `[INFO] block-12 exempted: …`? Cheap, high audit value. Carries over to EVOL-CO-DIRECTION territory-exemption design.
- **MASS parallel findings — moot.** MASS announced as independent fork; no longer a framework consumer.

## Appendix — finding-to-disposition mapping

| Finding | Theme | EVOL-034 sub-task | EVOL-CO-DIRECTION (deferred) |
|---|---|---|---|
| #1 (field name `.paths` vs `.red_zones`) | B | 2 | — |
| #1 (axis cross_territory_scope) | C | — | ✓ Territory model primitive |
| #2 (jq shape) | B | 2 | — |
| #3 (Check 3 false-positives) | C | — | ✓ Governance federation primitive |
| #4 (changelog re-introduction) | C | — | ✓ Per-territory governance metadata primitive |
| #5 (workflow awk SIGPIPE) | A | 1 | — |
| #6 (auto-tag.sh LAST_TAG) | A | 1 | — |
| #7 (auto-tag.sh head SIGPIPE) | A | 1 | — |
| (cross-cutting) | — | 3 | — |
