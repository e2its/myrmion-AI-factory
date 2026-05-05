---
version: 1.0.0
date: 2026-05-05
changelog:
  - "1.0.0: feat(EVOL-027) execution complete — all 5 fases shipped on feature/EVOL-027-downstream-governance-completeness. Fase 1 (agent_templates manifest + upgrade walk) → bc153c2. Fase 2 (rules-naming convention drop, sed sweep across 51 files) → c5ac49e. Fase 3 (real scripts/generate-governance-snapshot.sh + setup/scripts/ mirror) → a5e82da. Fase 4 (scripts/check-inventory-drift.sh + CI advisory step + SKILL.md § Drift Detection Gate) → c0742da. Fase 5 (parser-canonical user_journey templates) → b4c6730. framework_version 3.0.0 → 4.0.0 (BREAKING). Status remains proposed pending user ratification of execution; flip to accepted after review and merge."
  - "0.2.0: Fase 2 reframed — Gap #4 fix unified as full convention drop (C). `.instructions.md` suffix removed from `.claude/rules/` everywhere — source, target, meta repo, manifest, instruction refs. Eliminates source-vs-target asymmetry permanently instead of patching meta self-application. RDR ratification: user explicit reject of split-into-EVOL-028 (one-shot or never). Status remains proposed."
  - "0.1.0: Skeleton — RDR decision persisted (slug A: downstream-governance-completeness, single EVOL covering 5 gaps). Status: proposed."
adr_number: EVOL-027
title: Downstream governance completeness — agent-template propagation, rules-naming convention unification, snapshot+inventory drift tooling, parser-canonical user_journey
status: proposed
type: framework-evolution
scope: global
---

# ADR-EVOL-027: Downstream governance completeness

## Context

Feedback report from MASS (downstream materialised project) lists seven gaps observed in their materialised state. Triage in the framework meta repo confirmed five as real upstream gaps; two were declassified.

Critical finding during triage: the propagation contract that ships framework changes to materialised projects (`SETUP --upgrade`, `factory-sync.sh`, `governance_versions.json` manifest) only covers two trees — `framework_core` (instructions, skills, hooks, scripts, workflows, root `CLAUDE.md`) and `templates` (rules + setup tree). The remaining template trees consumed by agents — `.context/templates/{codesign,architect,develop,po,qa,security,ux}/**` — are not tracked in any manifest. Materialised projects receive a one-shot copy at `SETUP --generate` time and never receive subsequent upstream fixes. Result: any framework correction to those templates dies in upstream.

This explains the gap pattern in MASS — content gaps in agent-consumed templates plus a missing inventory-drift signal plus pseudocode-only governance script plus widespread broken instruction references. None of them propagate today even when fixed.

Five gaps confirmed in framework upstream (not just materialised in MASS):

1. `.context/templates/codesign/user_journey_template.md` ships a master-table format for journey steps. Downstream parsers (e.g. MASS) require parser-canonical step blocks (`### Paso N` + per-step `### Schema:` / `DataIn:` / `DataOut:` markers) for deterministic extraction. Current template forces every materialised project to patch locally.
2. `Factory-setup-materialization.instructions.md` Checkpoint 3.1 ships `generate_governance_snapshot()` as language-agnostic pseudocode. No real script exists in `scripts/` or `.context/templates/setup/scripts/`. Each materialised project re-implements a different way to compute the snapshot.
3. Rules-naming convention is asymmetric and self-contradictory. Source templates ship as `.context/templates/setup/rules/foo.md` (no suffix). Materialised projects' target is `.claude/rules/foo.instructions.md` (with suffix, per `Factory-setup-materialization.instructions.md:337,705` and manifest `target` fields). The meta repo's own `.claude/rules/` follows source format (no suffix), so the meta repo's Factory-* instructions referencing `foo.instructions.md` cannot be read by agents running on the meta repo itself (self-application broken). The asymmetry forces every consumer (`SETUP --generate`, `SETUP --upgrade`, `factory-sync.sh`, CI checks, 47+ string-literal refs across Factory-* instructions) to know about the rename. Cargo-cult convention from v9.0.0 with no operational benefit — the `.claude/rules/` directory already disambiguates rule files from other markdown.
4. `Factory-codebase-inventory` has cache-freshness via MD5 but no codebase-vs-inventory drift detection. CIP gate detects presence/cache, not content drift. No `check-inventory-drift.sh`, no CI workflow.
5. `governance_versions.json` does not track `.context/templates/{codesign,architect,develop,po,qa,security,ux}/**`. `Factory-setup-upgrade` therefore cannot propagate fixes in those trees to already-materialised projects.

Two MASS-reported gaps declassified during triage:

- "SessionStart loads ~90 KB full snapshot, harness truncates" — framework SessionStart hook is `validate-governance.sh --banner` (one line). Snapshot is loaded on demand by `Factory-governance-loading/SKILL.md` Step 0, not by SessionStart. The truncation observed in MASS is a project-local SessionStart customisation; redirected to MASS.
- "No canonical pre-flight pattern in upstream instructions" — partial pattern exists (`Factory-blueprint-design.instructions.md` Pre-Flight Resolution Gate, `check-push-preflight.sh`, `Factory-setup-upgrade` Step -1). Canonicalising as a cross-cutting protocol is a separate concern (cross-cutting protocol design vs. content fix) and warrants its own EVOL.

## Decision

Single EVOL bundling the five confirmed upstream gaps under a unifying objective: make the propagation contract complete enough that any framework-level fix in a template, script, or instruction reaches every materialised project via `SETUP --upgrade` + `factory-sync.sh`.

Five fases, executed atomically in one PR:

- **Fase 1 — Agent-template manifest extension (gap #5).** Add `agent_templates` section to `governance_versions.json` covering `.context/templates/{codesign,architect,develop,po,qa,security,ux}/**`. Extend `Factory-setup-upgrade.instructions.md` Step 2 + Step 3 to include this tree under the existing Smart Additive Merge contract. `factory-sync.sh` extended to mirror the new section. Pre-requisite for fase 5.
- **Fase 2 — Rules-naming convention unification (gap #3, C-style).** Drop `.instructions.md` suffix from `.claude/rules/` everywhere. (a) Manifest `target` fields rewritten from `.claude/rules/foo.instructions.md` to `.claude/rules/foo.md` for every rules entry. (b) `Factory-setup-materialization.instructions.md` Checkpoint and § Standard Rules rewritten — rules materialise as `.claude/rules/foo.md` directly, no rename step. (c) All 47+ string-literal references across `.claude/instructions/Factory-*.instructions.md` rewritten from `foo.instructions.md` to `foo.md` for `.claude/rules/` paths (Factory-* instruction filenames themselves keep their `.instructions.md` suffix — separate convention, separate concern). (d) `Factory-setup-upgrade.instructions.md` gains a `--migrate-legacy-setup` rule that detects `.claude/rules/foo.instructions.md` files in already-materialised projects and renames them to `foo.md` on next upgrade. (e) `factory-sync.sh` accepts both forms during transition window. Independent of other fases.
- **Fase 3 — Real governance-snapshot generator (gap #2).** Create `scripts/generate-governance-snapshot.sh` implementing the `Factory-setup-materialization.instructions.md` Checkpoint 3.1 pseudocode (and EXTRACT_LAW_SECTIONS / EXTRACT_UNIVERSAL_DCS contracts) as a deterministic shell+awk script. Replace pseudocode in instruction with reference to the script. Add manifest entry in `framework_core.scripts/generate-governance-snapshot.sh`. Ship via `factory-sync.sh`.
- **Fase 4 — Codebase-inventory drift detection (gap #4).** Create `scripts/check-inventory-drift.sh` mirroring the `validate-governance.sh` pattern: scan tracked code paths, compare against `config/codebase_inventory.json`, report drift entries. Add CI workflow (or extend governance-check) to invoke. Document invocation in `Factory-codebase-inventory/SKILL.md`. Add manifest entries.
- **Fase 5 — Parser-canonical user_journey template (gap #1).** Reformat `.context/templates/codesign/user_journey_template.md` from master-table to per-step blocks (`### Paso N` heading + `### Schema:` block + `DataIn:` / `DataOut:` markers). Cross-section traceability matrix preserved. Functions on top of fase 1 manifest extension so the fix actually reaches MASS via `--upgrade`.

`framework_version` bump: `3.0.0 → 4.0.0` (MAJOR — manifest schema gains a new top-level section `agent_templates` and the user_journey template format breaks any downstream parser written against the master-table format).

### RDR ratifications (verbatim user choices)

- **Slug:** A — `feature/EVOL-027-downstream-governance-completeness`. Captures the architectural objective (close the propagation cycle) without binding to MASS-as-origin (B) or to gap #5 alone (C).
- **Grouping:** single EVOL covering all five confirmed gaps. User explicitly directed "agrupa todos los gaps a solucionar en un solo evol". Rejected (a) two-EVOL split (027 propagation + 028 governance tooling) — duplicates ceremony without functional benefit; (b) per-gap EVOLs — six PRs with no shared rationale.
- **Gap #4 fix scope:** C — full convention unification (drop `.instructions.md` suffix from `.claude/rules/` everywhere). Rejected A (rename meta repo only) — leaves source-vs-target asymmetry forever and just patches meta self-application. Rejected B (drop fix from EVOL) — leaves bug open in MASS and meta. Rejected the "split into EVOL-028" suggestion explicitly per user: "no va a haber un evol-28 para esto, o lo hacemos ahora o no merece la pena hacerlo." Long-term reasoning: the asymmetry has no operational benefit (the directory already disambiguates), forces every script touching rules to know about the rename, and was the root cause of the MASS broken-refs report. The EVOL is already MAJOR (4.0.0) for unrelated reasons (manifest schema + journey format) — absorbing the convention flip on the same MAJOR boundary is the right tactical home.

## Scope

### Framework template changes (ship to materialised projects)

- `.context/templates/codesign/user_journey_template.md` — reformat to parser-canonical step blocks (fase 5).
- `.context/templates/setup/governance_versions.json` — add `agent_templates` section listing every file under `.context/templates/{codesign,architect,develop,po,qa,security,ux}/**` with version and checksum (fase 1). Bump `framework_version: 3.0.0 → 4.0.0`. Bump every touched file entry per Generation Standards §2.

### Framework instruction changes

- `.claude/instructions/Factory-setup-upgrade.instructions.md` — extend Step 2 (Unified Smart Additive Merge) and Step 3 (New File Handling) to walk `agent_templates` section. Document target paths under each materialised project's `.context/templates/{role}/`. Add legacy-rules-suffix migration rule: detect `.claude/rules/foo.instructions.md` in already-materialised projects and rename to `foo.md`.
- `.claude/instructions/Factory-setup-materialization.instructions.md` — Checkpoint 3.1 replaces pseudocode with reference to `scripts/generate-governance-snapshot.sh` (keep contract narrative). § Standard Rules and § Stack-conditional Rules: drop `.instructions.md` suffix from all materialise targets — rules ship to `.claude/rules/foo.md` directly.
- All `.claude/instructions/Factory-*.instructions.md` referencing `.claude/rules/{name}.instructions.md` — rewrite to `.claude/rules/{name}.md` (fase 2). Factory-* instruction filenames themselves keep `.instructions.md` suffix.

### Framework script changes

- `scripts/generate-governance-snapshot.sh` — new (fase 3).
- `scripts/check-inventory-drift.sh` — new (fase 4).
- `scripts/factory-sync.sh` — extend to mirror `agent_templates` section, the new `generate-governance-snapshot.sh`, and `check-inventory-drift.sh`.

### Framework skill changes

- `.claude/skills/Factory-codebase-inventory/SKILL.md` — document `check-inventory-drift.sh` invocation and integration with CIP Canary gate (fase 4).

### Framework workflow changes

- `.github/workflows/governance-check.yml` (or new `inventory-drift-check.yml`) — wire `check-inventory-drift.sh` (fase 4).

### Framework manifest changes

- `.context/templates/setup/governance_versions.json` — new `agent_templates` section + entries for the two new scripts + bumps for all touched files + `framework_version: 4.0.0`.

### Framework repo (meta) changes

- This file (`docs/project_log/evolutions/ADR-EVOL-027.md`) — final state at acceptance.
- Root `CLAUDE.md` — no functional change expected; if the manifest schema is referenced explicitly in INVARIANT 4 / Generation Standards §2, update wording to mention `agent_templates`.

### Out of scope (deferred)

- MASS gap #3 (full snapshot at SessionStart truncated by harness) — declassified as project-local SessionStart customisation, redirected to MASS.
- MASS gap #5 (canonical pre-flight pattern) — declassified as cross-cutting protocol concern; deserves its own EVOL.
- Backfill of `agent_templates` content drift in already-materialised projects — handled per-project via `SETUP --upgrade` after this EVOL ships. No mass migration tool.
- Materialised-project parsers that already consume the master-table user_journey format — out of scope; downstream projects update their parser as part of their own EVOL when they pull this MAJOR bump.

## Alternatives Considered

- **A — Single EVOL, single PR, all five gaps atomic.** **Chosen.** Manifest schema change + Factory-setup-upgrade extension + new scripts + content sweep + template reformat ship together. Coherent narrative, single MAJOR bump, single CI cycle.
- **B — Two-EVOL split (027 = #5+#1+#3 propagation/content; 028 = #2+#6 governance tooling).** Rejected — fase 1 (gap #5) is the keystone for fase 5 (gap #1); separating them creates ordering risk between two PRs. Tooling EVOL has no urgency to be separate.
- **C — Per-gap EVOL (5 separate PRs).** Rejected — five ADR ceremonies with no shared rationale; total ceremony cost dominates the actual change cost.
- **Fase 5 first (reformat user_journey) without fase 1 manifest extension.** Rejected — fix would die in upstream; MASS would still need a manual local patch. Defeats the unifying objective.
- **Add `agent_templates` to existing `templates` section instead of new section.** Rejected — `templates` section semantics are "rules + setup tree" (i.e. things SETUP --generate materialises directly). Agent templates have different propagation semantics (Smart Additive Merge across already-materialised projects), warranting their own section.
- **Implement `generate-governance-snapshot.sh` in Python instead of bash+awk.** Considered. Rejected — existing governance scripts in framework are bash+awk for portability (no Python dependency at SETUP time on minimal hosts). Python is acceptable when no awk equivalent exists; for snapshot extraction, awk suffices.

## Consequences

- **Materialised projects:** any future framework correction to agent-consumed templates (codesign / architect / develop / po / qa / security / ux) propagates via `SETUP --upgrade`. Drift between framework upstream and materialised downstream becomes detectable and resolvable through the standard upgrade ceremony.
- **MASS specifically:** receives gap #1 (parser-canonical journey template), gap #2 (real snapshot script), gap #3 (instruction-ref sweep), gap #4 (drift detection), gap #5 (manifest extension) on next `SETUP --upgrade` after this EVOL ships.
- **MAJOR bump (`3.0.0 → 4.0.0`):** breaking on three axes — manifest schema gains `agent_templates` section (downstream tooling parsing the manifest must handle the new section); user_journey template format changes (downstream parsers consuming the master-table layout break); rules-naming convention unified (downstream tooling expecting `.claude/rules/foo.instructions.md` paths must adapt to `foo.md`). Migration handled by `Factory-setup-upgrade --migrate-legacy-setup` rename rule. Single MAJOR boundary absorbs all three breaks.
- **Token footprint:** snapshot generator behaviour is functionally identical to the pseudocode contract; no growth in snapshot size. Drift-detection script runs as a workflow step (CI cost only).
- **Ceremony cost:** one EVOL, one PR, one ADR, one CI cycle. ADR is this file. Conventional commits per fase inside the PR for git-log readability.
- **Backfill responsibility:** materialised projects with prior local patches over the master-table user_journey format must re-merge their patches against the parser-canonical layout during their `SETUP --upgrade`. Smart Additive Merge surfaces the diff for user review per existing Factory-setup-upgrade contract.

## Constitution Amendment

> N/A. EVOL-027 modifies framework infrastructure (manifest schema, propagation contract, scripts, instructions, templates) — it is not itself a constitutional decision of any single materialised project. The framework's own root `CLAUDE.md` may receive a wording clarification on `agent_templates` if INVARIANT 4 references the manifest schema explicitly; that clarification is editorial, not a new operational law.

## Traceability

- Branch: `feature/EVOL-027-downstream-governance-completeness`
- Triggered by: MASS feedback report listing 7 gaps; framework triage on 2026-05-05 confirmed 5 as upstream gaps and declassified 2.
- Verification (planned): static template validation (manifest schema + reformatted journey template), unit test for `generate-governance-snapshot.sh` reproducibility against the existing snapshot in `.context/`, unit test for `check-inventory-drift.sh` against a synthetic drift fixture, manual `Factory-setup-upgrade` dry-run on a throwaway materialised project.
- Status: proposed. Acceptance flips this to `accepted` and triggers the manifest version bump per `scripts/check-adr-constitution-sync.sh` (or its meta-equivalent — this EVOL does not amend a project constitution; only the framework manifest is touched).

## Execution Outcome

| # | Task | Result | Commit |
|---|---|---|---|
| 1 | Branch `feature/EVOL-027-downstream-governance-completeness` from `origin/main` | done | — |
| 2 | ADR skeleton at status `proposed` capturing slug A + grouping ratifications | done | 72cf79b |
| 3 | Fase 2 reframe to full convention drop (C) ratified after triage of materialisation contract | done | b02ee9e |
| 4 | Fase 1 — `agent_templates` section added to `governance_versions.json` (30 entries covering codesign / architect / develop / peer_review / po / qa / security / ux); `Factory-setup-upgrade` Step 1 gains explicit Manifest Sections Walked table | done | bc153c2 |
| 5 | Fase 1 — `framework_version` bumped 3.0.0 → 4.0.0 (BREAKING — manifest schema gains new top-level section) | done | bc153c2 |
| 6 | Fase 2 — sed sweep across 19 Factory-* instructions, 4 Factory-* skills, 1 preflight.sh: `.claude/rules/foo.instructions.md` → `.claude/rules/foo.md` (47+ occurrences, 0 remaining) | done | c5ac49e |
| 7 | Fase 2 — manifest `target` fields rewritten for 25 `templates.rules/*` entries; `Factory-setup-materialization` Phase A/B/C drops the rename step (`.claude/rules/{name}.md` written directly); `Factory-setup-upgrade` § v4.0.0 migration rule added (idempotent, collision-safe `git mv` of legacy filenames during upgrade prologue) | done | c5ac49e |
| 8 | Fase 2 — sweep of cross-rule references in `.context/templates/setup/rules/*.md`, setup scripts (lint-format, security-scan, ux-validation, validate-iac, validate-migrations), `.context/utils/*.py`/`.sh`, README, constitution_template, claude/CLAUDE.md template, MATERIALIZATION_REPORT_TEMPLATE, adr_setup_template, two agent_templates (api_test, test_plan) | done | c5ac49e |
| 9 | Fase 2 — bumps: 20 framework_core entries (instructions + skills + preflight) + 23 templates entries (rules + scripts + constitution + claude template + utility templates + 2 agent_templates) all by MINOR | done | c5ac49e |
| 10 | Fase 3 — `scripts/generate-governance-snapshot.sh` written: portable MD5, frontmatter, Stack Configuration via 2-space-indent YAML parser (no PyYAML dep), Rules Manifest table from frontmatter scan, Protected Paths from JSON, Setup Configuration verbatim excerpt, Active Constitution `[LAW]` extract via the awk contract from L2 test, Defect Prevention universal entries; `--check` and `--quiet` modes | done | a5e82da |
| 11 | Fase 3 — Mirror at `.context/templates/setup/scripts/generate-governance-snapshot.sh`; `factory-sync.sh` base-scripts whitelist extended; `Factory-setup-materialization` Checkpoint 3.1 narrative replaces pseudocode-as-contract with reference to the script (pseudocode kept as normative documentation, not as a re-implementation guide) | done | a5e82da |
| 12 | Fase 4 — `scripts/check-inventory-drift.sh` written: STALE / PROMOTE / INVALID classification via JSON parse of `config/codebase_inventory.json`; `--json` for CI, `--warn-only` for advisory mode; graceful when inventory absent | done | c0742da |
| 13 | Fase 4 — Mirror at `.context/templates/setup/scripts/check-inventory-drift.sh`; `.github/workflows/governance-check.yml` gains advisory step (--warn-only); `Factory-codebase-inventory/SKILL.md` § Drift Detection Gate documents the new gate (classification table, invocation modes, scope boundary vs `SETUP --reconcile-inventory`) | done | c0742da |
| 14 | Fase 5 — `codesign/user_journey_template.md` Section 2 reformatted from master-table to per-step `### Paso N` blocks with labeled DataIn:/DataOut:/Schema fields | done | b4c6730 |
| 15 | Fase 5 — `codesign/user_journey.integration.md` reformatted to the same parser-canonical contract, with integration-specific fields (Trigger, Effect, Idempotency Key, Retry Policy) preserved per step; both `agent_templates.codesign/user_journey*.md` bumped 1.0.0 → 1.1.0 | done | b4c6730 |
| 16 | Manifest description-line entries v3.0.0 → 4.0.0 (Fase 1 / Fase 2 / Fase 5 markers) consolidated in a single BREAKING block | done | bc153c2, c5ac49e, b4c6730 |
| 17 | Status flip `proposed` → `accepted` with final ADR version bump | pending user ratification | — |
