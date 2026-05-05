---
version: 0.1.0
date: 2026-05-05
changelog:
  - "0.1.0: Skeleton — RDR decision persisted (slug A: downstream-governance-completeness, single EVOL covering 5 gaps). Status: proposed."
adr_number: EVOL-027
title: Downstream governance completeness — agent-template propagation, instruction-ref sweep, snapshot+inventory drift tooling, parser-canonical user_journey
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
3. Multiple `.claude/instructions/Factory-*.instructions.md` files reference `.claude/rules/{name}.instructions.md` paths that do not exist — actual rules ship under `.claude/rules/{name}.md` (no `.instructions.md` suffix). 47+ broken refs across `Factory-blueprint-design` (29), `Factory-implement-build` (7), `Factory-implement-review-checks` (7), `Factory-implement-plan` (2), `Factory-qa-verify` (2), `Factory-devops-configure` (1+).
4. `Factory-codebase-inventory` has cache-freshness via MD5 but no codebase-vs-inventory drift detection. CIP gate detects presence/cache, not content drift. No `check-inventory-drift.sh`, no CI workflow.
5. `governance_versions.json` does not track `.context/templates/{codesign,architect,develop,po,qa,security,ux}/**`. `Factory-setup-upgrade` therefore cannot propagate fixes in those trees to already-materialised projects.

Two MASS-reported gaps declassified during triage:

- "SessionStart loads ~90 KB full snapshot, harness truncates" — framework SessionStart hook is `validate-governance.sh --banner` (one line). Snapshot is loaded on demand by `Factory-governance-loading/SKILL.md` Step 0, not by SessionStart. The truncation observed in MASS is a project-local SessionStart customisation; redirected to MASS.
- "No canonical pre-flight pattern in upstream instructions" — partial pattern exists (`Factory-blueprint-design.instructions.md` Pre-Flight Resolution Gate, `check-push-preflight.sh`, `Factory-setup-upgrade` Step -1). Canonicalising as a cross-cutting protocol is a separate concern (cross-cutting protocol design vs. content fix) and warrants its own EVOL.

## Decision

Single EVOL bundling the five confirmed upstream gaps under a unifying objective: make the propagation contract complete enough that any framework-level fix in a template, script, or instruction reaches every materialised project via `SETUP --upgrade` + `factory-sync.sh`.

Five fases, executed atomically in one PR:

- **Fase 1 — Agent-template manifest extension (gap #5).** Add `agent_templates` section to `governance_versions.json` covering `.context/templates/{codesign,architect,develop,po,qa,security,ux}/**`. Extend `Factory-setup-upgrade.instructions.md` Step 2 + Step 3 to include this tree under the existing Smart Additive Merge contract. `factory-sync.sh` extended to mirror the new section. Pre-requisite for fase 5.
- **Fase 2 — Broken instruction-ref sweep (gap #3).** Replace `*.instructions.md` references with `*.md` everywhere they refer to `.claude/rules/` files. Single-purpose mechanical sweep across all `.claude/instructions/Factory-*.instructions.md`. Independent of other fases.
- **Fase 3 — Real governance-snapshot generator (gap #2).** Create `scripts/generate-governance-snapshot.sh` implementing the `Factory-setup-materialization.instructions.md` Checkpoint 3.1 pseudocode (and EXTRACT_LAW_SECTIONS / EXTRACT_UNIVERSAL_DCS contracts) as a deterministic shell+awk script. Replace pseudocode in instruction with reference to the script. Add manifest entry in `framework_core.scripts/generate-governance-snapshot.sh`. Ship via `factory-sync.sh`.
- **Fase 4 — Codebase-inventory drift detection (gap #4).** Create `scripts/check-inventory-drift.sh` mirroring the `validate-governance.sh` pattern: scan tracked code paths, compare against `config/codebase_inventory.json`, report drift entries. Add CI workflow (or extend governance-check) to invoke. Document invocation in `Factory-codebase-inventory/SKILL.md`. Add manifest entries.
- **Fase 5 — Parser-canonical user_journey template (gap #1).** Reformat `.context/templates/codesign/user_journey_template.md` from master-table to per-step blocks (`### Paso N` heading + `### Schema:` block + `DataIn:` / `DataOut:` markers). Cross-section traceability matrix preserved. Functions on top of fase 1 manifest extension so the fix actually reaches MASS via `--upgrade`.

`framework_version` bump: `3.0.0 → 4.0.0` (MAJOR — manifest schema gains a new top-level section `agent_templates` and the user_journey template format breaks any downstream parser written against the master-table format).

### RDR ratifications (verbatim user choices)

- **Slug:** A — `feature/EVOL-027-downstream-governance-completeness`. Captures the architectural objective (close the propagation cycle) without binding to MASS-as-origin (B) or to gap #5 alone (C).
- **Grouping:** single EVOL covering all five confirmed gaps. User explicitly directed "agrupa todos los gaps a solucionar en un solo evol". Rejected (a) two-EVOL split (027 propagation + 028 governance tooling) — duplicates ceremony without functional benefit; (b) per-gap EVOLs — six PRs with no shared rationale.

## Scope

### Framework template changes (ship to materialised projects)

- `.context/templates/codesign/user_journey_template.md` — reformat to parser-canonical step blocks (fase 5).
- `.context/templates/setup/governance_versions.json` — add `agent_templates` section listing every file under `.context/templates/{codesign,architect,develop,po,qa,security,ux}/**` with version and checksum (fase 1). Bump `framework_version: 3.0.0 → 4.0.0`. Bump every touched file entry per Generation Standards §2.

### Framework instruction changes

- `.claude/instructions/Factory-setup-upgrade.instructions.md` — extend Step 2 (Unified Smart Additive Merge) and Step 3 (New File Handling) to walk `agent_templates` section. Document target paths under each materialised project's `.context/templates/{role}/`.
- `.claude/instructions/Factory-setup-materialization.instructions.md` Checkpoint 3.1 — replace pseudocode with reference to `scripts/generate-governance-snapshot.sh`. Keep contract narrative for documentation purposes.
- All `.claude/instructions/Factory-*.instructions.md` referencing `.claude/rules/{name}.instructions.md` — rewrite to `.claude/rules/{name}.md` (fase 2).

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
- **MAJOR bump (`3.0.0 → 4.0.0`):** breaking on two axes — manifest schema gains `agent_templates` section (downstream tooling parsing the manifest must handle the new section); user_journey template format changes (downstream parsers consuming the master-table layout break). Both warrant the MAJOR.
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
