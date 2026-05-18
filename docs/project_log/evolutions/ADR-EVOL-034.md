---
id: ADR-EVOL-034
title: Framework downstream-awareness — lock-step hardening + schema canonicalisation
date: 2026-05-18
status: proposed
---

# ADR-EVOL-034: Framework downstream-awareness — lock-step hardening + schema canonicalisation

## Context

The nexus session on 2026-05-18 surfaced 7 framework defects in a single sweep (e2its/Nexus-Tech-Link PRs #13–#18, ADR-0003 § Traceability). Empirical validation against meta HEAD identified three distinct root-cause themes:

- **Theme A — Lock-step drift** (Findings #5, #6, #7). Meta script fixed but template not backported (or vice versa). `coherence-context.json` v1.2.0 declares `lock_step_pairs` semantically but ships no automated check.
- **Theme B — Schema incoherence** (Findings #1 field name, #2). `config/protected-paths.json` is read by three consumers with two different field names (`.paths` vs `.red_zones`) and two shape assumptions (flat array vs object-of-arrays).
- **Theme C — Downstream-awareness contract** (Findings #1 axis, #3, #4). Framework assumes meta invariants; downstream needs explicit contract.

Same session, the user announced that nexus and MASS are going independent forks → Theme C loses its immediate driver → deferred to a separate exploration track (EVOL-CO-DIRECTION) where its primitives are redesigned as natural building blocks of a multi-director protocol rather than retrofitted as standalone contract fields.

Full design analysis lives in `docs/proposals/EVOL-034-framework-downstream-awareness.md` (merged via PR #34); RFC for the deferred Theme C lives in `docs/proposals/EVOL-CO-DIRECTION-multi-director-coordination.md`.

## Decision

Ship EVOL-034 as a single feature branch covering Themes A + B + meta-only lock-step enforcement infrastructure. Roughly nine files touched. Risk: Low. All changes deterministic and reversible.

Sub-tasks (in-EVOL order — deterministic first, then schema canonicalisation, then enforcement):

- **Sub-task 1 — Lock-step backports (Theme A).**
  Template `scripts/auto-tag.sh:58` ← `--match 'v*'` from meta:60 (Finding #6 — non-semver tag breaks parse pipeline under `set -u`). Template `scripts/auto-tag.sh:124,126` ← `|| true` (or switch to `git log -n 20` native) from meta:190,192 (Finding #7 — `git log | head` SIGPIPE under pipefail). Meta `.github/workflows/auto-tag.yml:57` fix awk SIGPIPE (Finding #5 — `echo "$OUTPUT" | awk '/^TAG=/{print $2; exit}'` → exit 141). Template workflow variants `auto-tag.bitbucket.yml:33` + `auto-tag.gitlab-ci.yml:37` same SIGPIPE fix. Template `auto-tag.github-actions.yml:43` — replace `grep -oP` with portable equivalent (GNU-only PCRE is non-portable).

- **Sub-task 2 — Schema canonicalisation (Theme B).**
  Field name and shape canonicalised per ratified RDR-1 = Option A (`paths`, flat array). `factory-pr-review/scripts/preflight.sh:309-321` unchanged (already reads `.paths`); `scripts/security-scan.sh:210` (meta + template) jq becomes `.paths[]`; template `protected-paths.json` renames `red_zones` → `paths`. Three consumers in agreement on one field, one shape.

- **Sub-task 3 — Lock-step enforcement (new infrastructure) — META-ONLY.**
  New `scripts/check-lockstep-pairs.sh` iterating `config/coherence-context.json § lock_step_pairs`, asserting parity between each meta script and its template counterpart. Header marked `# META-ONLY: do not ship to downstream materialised projects`; self-guard exits 0 silently if `.context/templates/setup/` not present (belt-and-braces against future copy-paste leaks). New `.github/workflows/lockstep-check.yml` invoking the script on every PR. Extend meta-only `config/coherence-context.json` v1.2.0 → v1.3.0 (additive `lock_step_pairs: [{meta, template}, ...]` array). Template `.context/templates/setup/config/coherence-context.json` NOT touched — schemas legitimately diverge (template will carry territory primitives from EVOL-CO-DIRECTION; meta carries lock-step pairs).

**Scope notes:**
- Sub-task 3 is entirely meta-only. Lock-step pairs exist only in the meta-framework (a script lives twice — once as meta tool, once as template that ships to downstream). In a materialised project, the meta/template distinction collapses and the gate has no work to do. Propagation prevented mechanically: everything lives at meta root, not under `.context/templates/setup/`; `factory-sync.sh` only syncs from the templates tree.
- Manifest-gap backfills may be necessary for files touched by sub-tasks 1 + 2 that are not yet registered in `framework_core` (e.g. `.github/workflows/auto-tag.yml`, `scripts/security-scan.sh`, factory-pr-review SKILL artefacts). Backfills tracked per sub-task commit with explicit `backfill:` prefix in the changelog entry.

## RDR Decisions Ratified (2026-05-18)

RDRs renumbered within this ADR per `factory-rdr` SKILL § Algorithm (sequential per artefact). Proposal-scope RDR-1 (split decision) and RDR-2 / RDR-3 are persisted in PR #34; proposal-scope RDR-4 + RDR-5 deferred to EVOL-CO-DIRECTION. ADR-scope numbering below.

| # | Question | Choice | Rationale |
|---|---|---|---|
| 1 | `protected-paths.json` canonical shape (proposal RDR-2) | `paths` flat array | nexus + MASS forking off as independent forks → no legacy fleet to migrate → cleanest contract over backward compat. Recommendation A accepted verbatim. |
| 2 | Lock-step enforcement venue (proposal RDR-3) | CI workflow `.github/workflows/lockstep-check.yml` | Cheapest reliable enforcement; runs on every PR uniformly with no per-developer setup. Option B (BVL integration) ruled out pre-ratification as incoherent (BVL ships to downstream, gate is meta-only). |

## Alternatives Considered

- Alternative 1 — Two EVOLs (proposal RDR-1 Option A): deterministic fixes + contract additions. Rejected by user on review-burden grounds.
- Alternative 2 — Three EVOLs (proposal RDR-1 Option C): split Theme A further. Rejected as EVOL inflation.
- Alternative 3 — Keep Theme C inside EVOL-034: rejected post nexus/MASS fork announcement (designing contract without active consumer = guesswork).
- Alternative 4 — BVL integration for lock-step gate (proposal RDR-3 Option B): rejected — meta-only gate cannot coherently live in a downstream-shipped skill.
- Alternative 5 — Pre-commit hook (proposal RDR-3 Option C): not chosen — bootstrap friction; may be added later as additional defense in depth.
- Alternative 6 — Script-only with no gate (proposal RDR-3 Option D): rejected — empirical evidence (3 of 7 findings caused by drift) shows discipline alone is insufficient.

## Consequences

**Positives:**
- Six framework bugs fixed in one sweep (#2, #5, #6, #7 plus field-name half of #1; lock-step recurrence prevented going forward).
- `protected-paths.json` schema unified across three internal consumers: one field, one shape, zero ambiguity.
- Lock-step drift now mechanically gated via CI; the same defect class cannot silently recur. The empirical signal that motivated the EVOL becomes structurally impossible.
- Sub-task 3 is meta-only by construction — no propagation surface. Defense in depth (header `# META-ONLY` marker + self-guard) protects against future copy-paste leaks.

**Negatives / Trade-offs:**
- `protected-paths.json` field rename in template only. No live consumer thanks to nexus + MASS forking, but any new downstream project materialised before this EVOL merges would carry the old shape. Mitigation: SETUP `--upgrade` handles the delta when those future projects sync.
- Schemas of meta vs template `coherence-context.json` legitimately diverge after this EVOL (meta has `lock_step_pairs`; template does not). Future schema changes must explicitly choose meta-only vs propagating. Documented inline.
- Theme C primitives (changelog policy, ADR exemption axes, downstream-excluded files) remain in workaround territory until EVOL-CO-DIRECTION matures.

## Compliance

- Generation Standards §2: every framework-core file touched bumped + changelog line added in the same commit. Manifest-gap backfills (where prior framework_core registration was missing) prefixed with `backfill:` in the changelog entry.
- Pre-Action Gate: change shipped on `feature/EVOL-034-framework-downstream-awareness` branch off `origin/main`.
- RDR Universal: all decisions ratified verbatim in chat, persisted in proposal PR #34 and this ADR.
- Constitutional Supremacy: this ADR's Constitution Amendment section (below) adds a new framework-only `[LAW]` block to `CLAUDE.md` covering the lock-step pair integrity contract.
- Communication Style (caveman, no version refs in artefact bodies): all EVOL-034 and version references confined to commit messages, this ADR, and manifest changelogs.

## Operational Rule

```
Files modified in the meta-framework MUST stay in lock-step with their template
counterparts. The list of meta↔template pairs is declared in
config/coherence-context.json § lock_step_pairs. The CI workflow
.github/workflows/lockstep-check.yml invokes scripts/check-lockstep-pairs.sh
on every PR; the gate fails CI if any registered pair has diverged.

config/protected-paths.json uses a single canonical field `paths` containing
a flat array of glob patterns. All consumers (factory-pr-review Block 12,
security-scan.sh, downstream materialised projects) read this field with
the same shape.

The lock-step enforcement infrastructure (script + workflow + lock_step_pairs
field in meta's coherence-context.json) is META-ONLY by construction. It is
not propagated to materialised projects: lock-step pairs are a meta-framework
concept that disappears post-materialisation. Defense in depth: header marker
`# META-ONLY` in script + workflow; script self-guards exit 0 if
.context/templates/setup/ absent.
```

## Constitution Amendment

> **MANDATORY when this ADR transitions to `status: accepted`** (Governance Rule 1 — CLAUDE.md). The same PR that flips `status:` to `accepted` MUST apply the edit below to the relevant governance source. CI gate `scripts/check-adr-constitution-sync.sh` blocks the PR if no governance source is in the diff alongside the status flip.

- **Section affected:** `CLAUDE.md` (root meta only). One new framework-only `[LAW]` block added under § Governance Rules:
  - **LAW 12** — Lock-step Pair Integrity. Meta scripts and their template counterparts declared in `config/coherence-context.json § lock_step_pairs` MUST stay in lock-step. Enforced by `scripts/check-lockstep-pairs.sh` invoked from `.github/workflows/lockstep-check.yml` on every PR. Infrastructure is META-ONLY (defense in depth: header marker + self-guard); not propagated to materialised projects.
- **Before:** Governance Rules ended at LAW 11 (MCP-Docs Scan Banner).
- **After:** LAW 12 appended.
- **Template mirror:** NO — this LAW is framework-only by design. `.context/templates/setup/claude/CLAUDE.md` NOT updated. This is the framework-only branch of "What Lives Where"; rationale documented inline in the LAW body (lock-step pairs only exist in meta).
- **Constitution version bump:** none (this `meta` repo has no `docs/constitution.md`; universal/meta LAWs live in `CLAUDE.md`).
- **Changelog entry:** the `framework_version` bump in `governance_versions.json` carries the cross-reference.
