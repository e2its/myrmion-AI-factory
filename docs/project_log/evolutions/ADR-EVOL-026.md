---
version: 1.1.0
date: 2026-05-05
changelog:
  - "1.1.0: feat(EVOL-026) closure commit — all initially deferred items addressed within this EVOL per user directive (no follow-ups). Materialised-project governance workflow YAML created for 7 CI platforms (GitHub Actions, GitLab CI, Bitbucket, Azure DevOps, AWS CodeBuild, GCP Cloud Build, Jenkins) under .context/templates/setup/workflows/governance-check.{platform}.{ext}, wired into Factory-setup-materialization § 4.2.6. dcs_hash freshness validation extended in validate-governance.sh --snapshot-freshness. governance-onedit.sh watcher extended to .claude/rules/defect-prevention.md."
  - "1.0.0: feat(EVOL-026) execution complete — all 19 initially-tracked tasks done. T2 tests (L1, L2, L4, L5) green on first or second iteration. Snapshot generator rewired, [LAW] markers applied, ADR/FDR templates split, Factory-adr-management SKILL shipped, BLUEPRINT § 7.8 rewired, CI gate scripted + factory-sync extended, governance_versions.json bumped (8 entries + 8 new entries, framework_version 2.10.2 → 3.0.0). Status flipped to accepted for the EVOL record."
  - "0.1.0: Skeleton — RDR decisions persisted (A1/E2/T2/skill model). Status: proposed."
adr_number: EVOL-026
title: Governance single-source-of-truth — constitution single source, ADR amends, mechanical [LAW] embed
status: accepted
type: framework-evolution
scope: global
---

# ADR-EVOL-026: Governance single-source-of-truth

## Context

Incident reported in MASS (downstream materialised project): agent makes scope/architecture decisions without having loaded the technical culture (KISS/DRY/RULE narrative/prohibitions). Snapshot resumes with tables + bullets but does NOT embed the body of constitution. Policy says "on-demand for detail"; the agent forgets to trigger the load. Result: cultural drift, plausible decisions but not aligned with the project.

Root cause: model "active constitution = constitution.md base + ACCEPTED ADRs (supersede sections)" has two sources of truth. Knowing the active law requires reading N+1 files and applying mental supersession. The cache solution (snapshot) emits only summary, not body. The policy solution ("read on-demand") depends on agent discipline, not mechanism.

Confirmed in framework template (not only derived project): the literal phrase "1 file = full governance context" lives in `.claude/instructions/Factory-setup-materialization.instructions.md` Checkpoint 3.1, but the snapshot generator described there only emits summary (tables + bullets). Any project generated with `SETUP --generate` inherits the bug.

MASS will be patched independently due to large divergence from the framework — this EVOL closes the gap at template level for all future materialisations and for the framework itself.

## Decision

Single source of truth: `docs/constitution.md`. ADRs become historical records (context / alternatives / consequences / rationale of why a constitutional change was made). The active operational law lives only in constitution. Snapshot mechanically extracts and embeds operational sections marked `## [LAW]`. Defect-prevention.md universal entries (`applicable_when: always`) similarly embedded.

ADR PROPOSED → ACCEPTED transition triggers automatic constitution amendment via a new `Factory-adr-management` SKILL with deterministic Accept Procedure (no agent judgement at accept time). Feature-scoped Decision Records (FDR, renamed from feature-scoped ADRs at `docs/spec/{ID}/adr/`) stay local to their feature spec and never amend the universal constitution.

CI gate `scripts/check-adr-constitution-sync.sh` enforces invariant: any ADR transitioning to `status: accepted` in a PR must have `docs/constitution.md` modified in the same diff (bypass via commit message marker `[adr-backfill]`).

### RDR ratifications (verbatim user choices)

- **Strategy:** A1 — single EVOL, single PR, all changes atomic. Rejected A2 (phased) because without MASS urgency, a phased approach creates fragile intermediate state where snapshot loads constitution mechanically while the dual-source model persists.
- **Embed granularity:** E2 — curated embed by `## [LAW]` section convention + DC `applicable_when: always` filter. Rejected E1 (full-body) because verbosity scales with author discipline (the failure mode we are escaping). Rejected E3 (two-tier with SessionStart hook) because under prompt caching the cost difference vs E1 is marginal and it does not address verbosity, only relocates it.
- **ADR primitive:** SKILL with procedures, not slash command with flags. `Factory-adr-management/SKILL.md` exposes Propose Procedure, Accept Procedure, List Active ADRs API. Invoked by BLUEPRINT, AUDIT, IMPLEMENT, CODESIGN, DEVOPS, BACKLOG retrospective, or free-form turns. Authoring of `## Operational Rule` field is structured template work; Accept Procedure mechanically copies it to constitution as `## [LAW]` section. Zero agent judgement at accept time.
- **Test scope:** T2 — L1 (static template validation) + L2 (snapshot extraction unit test) + L4 (Accept Procedure simulation) + L5 (CI gate synthetic diffs) + L6 (post-merge dogfood). Rejected T1 (no L4) because Accept Procedure is the highest-complexity new piece. Rejected T3 (adds L3 materialization integration harness) because that is a separate capability (first materialization test in repo) and warrants its own EVOL.

## Scope

### Framework template changes (ship to materialised projects via SETUP --generate / SETUP --upgrade / factory-sync.sh)

- `.context/templates/setup/constitution/constitution_template.md` — add `## [LAW]` markers to operational sections (technology prohibitions, mandatory patterns, security baselines, cultural principles).
- `.context/templates/setup/claude/CLAUDE.md` — Mandatory Law #1 reformulated (constitution single source, ADR amends, FDR for feature-scoped); INVARIANT 2 simplified (snapshot embeds [LAW] sections, ADRs not loaded).
- `.context/templates/architect/adr_template.md` — frontmatter gains `target_section`, `amendment_kind`; sections gain mandatory `## Operational Rule` and auto-managed `## Constitution Amendment`.
- `.claude/instructions/Factory-setup-materialization.instructions.md` Checkpoint 3.1 — snapshot generator extracts only `^## \[LAW\]` sections + universal DCs.
- `.claude/instructions/Factory-setup-upgrade.instructions.md` — regen step uses new format.
- `.claude/instructions/Factory-blueprint-design.instructions.md` § 7.8 — read constitution sections instead of scanning ADRs; delegate to Factory-adr-management List Active API for historical traceability.
- `.claude/skills/Factory-adr-management/SKILL.md` — new skill with Propose / Accept / List Active procedures.
- `scripts/check-adr-constitution-sync.sh` — new CI gate.
- Template governance workflow YAML — wire CI gate.

### Framework repo (meta) changes

- Root `CLAUDE.md` — same Mandatory Law flip applied to the meta repo (the framework also eats its own dog food).
- Test scripts under `scripts/test-*` — L1, L2, L4, L5 (T2 scope).
- `.context/templates/setup/governance_versions.json` — bump every touched file + global `framework_version: 2.10.2 → 3.0.0` (MAJOR — breaking governance contract).
- This file (`docs/project_log/evolutions/ADR-EVOL-026.md`) — final state.

### Out of scope (deferred)

- L3 materialization integration harness — proposed as separate EVOL (framework testing infrastructure).
- Backfill of historical ADRs in already-materialised projects — handled per-project as needed using the `[adr-backfill]` bypass marker. No automated migration.
- Other rule files (`.claude/rules/*.instructions.md` other than defect-prevention.md) — stay on-demand. Embed cost vs criticality ratio does not justify in this EVOL.

## Alternatives Considered

- **A — Single-shot full-body embed.** All changes in one PR with ADRs as historical-only universally. Rejected (verbosity concern raised by user; full constitution body grows with author discipline).
- **B — Phased EVOL with skill extraction.** P1 mechanical fix to close MASS quickly; P2 model flip; P3 backfill. Rejected after MASS was decoupled from this EVOL — phasing without urgency creates fragile intermediate state.
- **C — Snapshot-only mechanical fix (defer model change).** Embed bodies but keep ADR-as-binding model. Rejected because the dual-source root cause persists and the bug recurs the moment an ADR contradicts constitution without amendment.
- **E1 — Full-body embed.** Trust constitutional authors to keep terse. Rejected (depends on author discipline; ~10-20k tokens in typical projects).
- **E3 — Two-tier (lean snapshot + SessionStart preload).** Adds hook + path. Rejected (under prompt caching, marginal token-cost difference; relocates verbosity without addressing it).
- **T1 — Minimum critical (skip Accept Procedure simulation).** Rejected (Accept Procedure is the highest-complexity new piece; leaving it untested would be a coverage hole).
- **T3 — Full integration harness.** Rejected (first materialization integration test in the repo is a separate capability; its scope justifies its own EVOL).
- **Slash command (`/adr` with `--propose`/`--accept`).** Considered for the ADR primitive. Rejected in favour of SKILL — disposes of CLI surface, allows invocation from any agent / command / free-form turn, fits the existing Factory-* SKILL pattern.
- **Per-feature ADR keeping universal binding semantics.** Rejected — pollutes universal constitution with feature-local invariants. Renamed to FDR (Feature Decision Record) with explicit feature-local scope.

## Consequences

- **Materialised projects:** governance is loaded mechanically — agents see `[LAW]` sections of constitution + universal DCs from turn 1, no on-demand discipline required. Cultural drift mitigated.
- **ADR ceremony:** authoring an ADR requires filling structured `## Operational Rule` field at PROPOSE; Accept Procedure mechanically writes amendment to constitution. CI gate blocks accept-without-amendment PRs.
- **Token footprint:** snapshot grows from ~1-2k tokens (digest) to ~2-4k tokens (curated embed) per typical project. Under prompt caching, amortised across turns.
- **BLUEPRINT § 7.8:** rewired to read constitution sections; ADR scanning replaced by `Factory-adr-management` List Active API call for historical traceability.
- **MAJOR bump (`2.10.2 → 3.0.0`):** breaking governance contract — Mandatory Law #1 reformulated, snapshot format changed, ADR template schema changed.
- **Backfill responsibility:** materialised projects with prior ACCEPTED ADRs need a one-shot backfill PR using `[adr-backfill]` marker (per-project, manual). Framework repo greenfield — only `ADR-EVOL-016.md` exists and is itself a meta-evolution record, not a project decision overriding framework constitution.
- **No regression in CI hash freshness checks:** `validate-governance.sh` continues to validate `constitution_hash` + `setup_hash` (no schema change to those fields).

## Constitution Amendment

> N/A for this ADR. EVOL-026 modifies framework infrastructure (templates, skills, scripts, instructions) — it is not itself a constitutional decision of any single materialised project. The framework's own root `CLAUDE.md` Mandatory Law text is updated as part of this EVOL but the framework does not have a `docs/constitution.md` of its own (governance-self-application is via `CLAUDE.md` directly).

## Traceability

- Branch: `feature/EVOL-026-governance-single-source`
- Triggered by: MASS incident report, root-cause analysis by user (5 May 2026). MASS will be patched independently due to large divergence — this EVOL closes the gap at template level for all future materialisations and for the framework itself.
- Verification: tests under `scripts/test-{templates-static,snapshot-extraction,adr-accept,check-adr-constitution-sync}.sh` (T2 scope) all green. Manual smoke runs confirmed on first or second iteration.
- Post-merge dogfood (pending): regenerate framework's own `.context/governance_snapshot.md` with new format + verify session-start banner + governance-onprompt behaviour. The framework does not have a `docs/constitution.md` of its own (it self-governs via root `CLAUDE.md`), so the dogfood is limited to confirming the snapshot-format change does not break the materialisation paths the framework consumes.
- Status: accepted.

## Execution Outcome

| # | Task | Result |
|---|---|---|
| 1 | Branch `feature/EVOL-026-governance-single-source` from `origin/main` | done |
| 2 | `[LAW]` markers on 12 operational sections of `constitution_template.md` (Governance Index left informational); UTF-8 mojibake fixed in Security by Design heading; frontmatter bumped to 3.0.0 | done |
| 3 | `Factory-setup-materialization.instructions.md` Checkpoint 3.1 rewritten — frontmatter gains `dcs_hash`; obsolete sections removed; `## Active Constitution (Operational [LAW] sections — verbatim)` and `## Defect Prevention Catalog (Universal entries)` added; `EXTRACT_LAW_SECTIONS` and `EXTRACT_UNIVERSAL_DCS` contracts documented | done |
| 4 | `Factory-setup-upgrade.instructions.md` Step 4 regen step extended for new format and legacy v < 3.0.0 path | done |
| 5 | Template `CLAUDE.md` INVARIANT 2 simplified — snapshot embeds `[LAW]` sections, ADRs not loaded as governance; freshness over `constitution_hash` + `setup_hash` + `dcs_hash` | done |
| 6 | Template `CLAUDE.md` Mandatory Law #1 reformulated — constitution single source; ADR amends; FDR for feature-scoped | done |
| 7 | Root `CLAUDE.md` Mandatory Law applied to meta repo — framework dogfoods the model | done |
| 8 | `adr_template.md` rewritten with new schema (`target_section`, `amendment_kind`, `## Operational Rule`, `## Constitution Amendment`); new `fdr_template.md` for feature-scoped decisions | done |
| 9 | `Factory-adr-management/SKILL.md` created — Propose / Accept / List Active ADRs procedures, ADR vs FDR decision matrix, invocation patterns for BLUEPRINT / AUDIT / IMPLEMENT / BACKLOG / free-form | done |
| 10 | BLUEPRINT § 7.8 rewired — reads constitution `[LAW]` from snapshot, FDRs from `docs/spec/{ID}/fdr/`, upstream FDRs via `consumes_contract`, optional historical ADR refs via Factory-adr-management List Active API | done |
| 11 | `scripts/check-adr-constitution-sync.sh` created (executable, shellcheck-clean); shipped via `factory-sync.sh` | done |
| 12 | Materialised-project governance workflow YAML — closed in the EVOL-026 closure commit. 7 platform-specific templates created under `.context/templates/setup/workflows/governance-check.{platform}.{ext}` (GitHub Actions, GitLab CI, Bitbucket, Azure DevOps, AWS CodeBuild, GCP Cloud Build, Jenkins). Materialization wired in `Factory-setup-materialization.instructions.md` § 4.2.6 with the per-platform target table. SETUP --generate now picks the right one per `ci_cd.platform`. | done |
| 13 | L1 — `scripts/test-templates-static.sh` — 33 assertions green | done |
| 14 | L2 — `scripts/test-snapshot-extraction.sh` — 18 assertions green (extraction + idempotency) | done |
| 15 | L4 — `scripts/test-adr-accept.sh` — 14 assertions green across ADD / REPLACE / validation; one fix iteration needed for REPLACE regex (DOTALL spillover bug) | done |
| 16 | L5 — `scripts/test-check-adr-constitution-sync.sh` — 7 scenarios green (FAIL when expected, PASS when expected, bypass works) | done |
| 17 | `governance_versions.json` — `framework_version: 2.10.2 → 3.0.0`; 8 entries bumped (root CLAUDE → 12.0.0, Factory-setup-materialization → 3.0.0, Factory-setup-upgrade → 2.3.0, Factory-blueprint-design → 3.0.0, factory-sync → 1.5.3, claude/CLAUDE → 2.0.0, constitution_template → 3.0.0, adr_template tracked at 1.0.0); 7 new entries added (Factory-adr-management SKILL, check-adr-constitution-sync.sh, 4 test scripts, fdr_template.md) | done |
| 18 | This file finalised, status flipped to accepted | done |
| 19 | L6 dogfood post-merge | pending (post-merge manual step) |

## Decisions taken during execution (worth flagging)

1. **Templates split into ADR (project-wide) + FDR (feature-scoped).** Originally one template with a `scope` field would have worked, but two templates with distinct frontmatter and lifecycle make the semantic distinction explicit and reduce error-prone branching in the Accept Procedure.
2. **`dcs_hash` added to snapshot frontmatter and validated.** Closure commit extended `validate-governance.sh --snapshot-freshness` to compare `dcs_hash` against `.claude/rules/defect-prevention.md`, so the freshness gate flags drift in the universal-DC source the same way it flags constitution/setup drift.
3. **Materialised-project workflow YAML closed in EVOL-026.** Originally deferred; closure commit added 7 platform-specific governance-check templates and wired them into Factory-setup-materialization § 4.2.6. SETUP --generate now picks the right workflow per `ci_cd.platform` and ships it with the EVOL-026 ADR ↔ constitution sync gate as a step.
4. **Reference shell implementations of extraction + Accept Procedure live in the test scripts.** The actual SETUP / Accept consumers are agents following pseudocode; the test scripts provide a concrete, deterministic reference that asserts the contract holds on canonical fixtures.
5. **`governance-onedit.sh` extended to watch `defect-prevention.md`.** Closure commit added the third watched file alongside constitution.md and setup.md, completing the regen-trigger story for all three hashed governance sources.
