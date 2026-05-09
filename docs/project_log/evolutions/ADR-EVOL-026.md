---
version: 1.2.0
date: 2026-05-05
changelog:
  - "1.2.0: docs — full execution log added covering the entire branch (9 commits) and the three factory-pr-review passes that the EVOL underwent. Outcome table extended to reflect all closure items and review-driven mitigations. Decisions taken section consolidated. Without this update the ADR record only described the first commit; the review trail and subsequent fixes lived only in commit messages and governance_versions.json changelogs."
  - "1.1.0: feat(EVOL-026) closure commit — all initially deferred items addressed within this EVOL per user directive (no follow-ups). Materialised-project governance workflow YAML created for 7 CI platforms (GitHub Actions, GitLab CI, Bitbucket, Azure DevOps, AWS CodeBuild, GCP Cloud Build, Jenkins) under .context/templates/setup/workflows/governance-check.{platform}.{ext}, wired into Factory-setup-materialization § 4.2.6. dcs_hash freshness validation extended in validate-governance.sh --snapshot-freshness. governance-onedit.sh watcher extended to .claude/rules/defect-prevention.md."
  - "1.0.0: feat(EVOL-026) execution complete — all 19 initially-tracked tasks done. T2 tests (L1, L2, L4, L5) green on first or second iteration. Snapshot generator rewired, [LAW] markers applied, ADR/FDR templates split, factory-adr-management SKILL shipped, BLUEPRINT § 7.8 rewired, CI gate scripted + factory-sync extended, governance_versions.json bumped (8 entries + 8 new entries, framework_version 2.10.2 → 3.0.0). Status flipped to accepted for the EVOL record."
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

ADR PROPOSED → ACCEPTED transition triggers automatic constitution amendment via a new `factory-adr-management` SKILL with deterministic Accept Procedure (no agent judgement at accept time). Feature-scoped Decision Records (FDR, renamed from feature-scoped ADRs at `docs/spec/{ID}/adr/`) stay local to their feature spec and never amend the universal constitution.

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
- `.claude/instructions/Factory-blueprint-design.instructions.md` § 7.8 — read constitution sections instead of scanning ADRs; delegate to factory-adr-management List Active API for historical traceability.
- `.claude/skills/factory-adr-management/SKILL.md` — new skill with Propose / Accept / List Active procedures.
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
- **BLUEPRINT § 7.8:** rewired to read constitution sections; ADR scanning replaced by `factory-adr-management` List Active API call for historical traceability.
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
| 10 | BLUEPRINT § 7.8 rewired — reads constitution `[LAW]` from snapshot, FDRs from `docs/spec/{ID}/fdr/`, upstream FDRs via `consumes_contract`, optional historical ADR refs via factory-adr-management List Active API | done |
| 11 | `scripts/check-adr-constitution-sync.sh` created (executable, shellcheck-clean); shipped via `factory-sync.sh` | done |
| 12 | Materialised-project governance workflow YAML — closed in the EVOL-026 closure commit. 7 platform-specific templates created under `.context/templates/setup/workflows/governance-check.{platform}.{ext}` (GitHub Actions, GitLab CI, Bitbucket, Azure DevOps, AWS CodeBuild, GCP Cloud Build, Jenkins). Materialization wired in `Factory-setup-materialization.instructions.md` § 4.2.6 with the per-platform target table. SETUP --generate now picks the right one per `ci_cd.platform`. | done |
| 13 | L1 — `scripts/test-templates-static.sh` — 33 assertions green | done |
| 14 | L2 — `scripts/test-snapshot-extraction.sh` — 18 assertions green (extraction + idempotency) | done |
| 15 | L4 — `scripts/test-adr-accept.sh` — 14 assertions green across ADD / REPLACE / validation; one fix iteration needed for REPLACE regex (DOTALL spillover bug) | done |
| 16 | L5 — `scripts/test-check-adr-constitution-sync.sh` — 7 scenarios green (FAIL when expected, PASS when expected, bypass works) | done |
| 17 | `governance_versions.json` — `framework_version: 2.10.2 → 3.0.0`; 8 entries bumped (root CLAUDE → 12.0.0, Factory-setup-materialization → 3.0.0, Factory-setup-upgrade → 2.3.0, Factory-blueprint-design → 3.0.0, factory-sync → 1.5.3, claude/CLAUDE → 2.0.0, constitution_template → 3.0.0, adr_template tracked at 1.0.0); 7 new entries added (factory-adr-management SKILL, check-adr-constitution-sync.sh, 4 test scripts, fdr_template.md) | done |
| 18 | This file finalised, status flipped to accepted | done |
| 19 | L6 dogfood post-merge | pending (post-merge manual step) |

## Decisions taken during execution (worth flagging)

1. **Templates split into ADR (project-wide) + FDR (feature-scoped).** Originally one template with a `scope` field would have worked, but two templates with distinct frontmatter and lifecycle make the semantic distinction explicit and reduce error-prone branching in the Accept Procedure.
2. **`dcs_hash` added to snapshot frontmatter and validated.** Closure commit extended `validate-governance.sh --snapshot-freshness` to compare `dcs_hash` against `.claude/rules/defect-prevention.md`, so the freshness gate flags drift in the universal-DC source the same way it flags constitution/setup drift.
3. **Materialised-project workflow YAML closed within this EVOL.** Originally deferred; closure commit added 7 platform-specific governance-check templates and wired them into Factory-setup-materialization § 4.2.6. SETUP --generate now picks the right workflow per `ci_cd.platform` and ships it with the ADR ↔ constitution sync gate as a step.
4. **Reference shell implementations of extraction + Accept Procedure live in the test scripts.** The actual SETUP / Accept consumers are agents following pseudocode; the test scripts provide a concrete, deterministic reference that asserts the contract holds on canonical fixtures.
5. **`governance-onedit.sh` extended to watch `defect-prevention.md`.** Closure commit added the third watched file alongside constitution.md and setup.md, completing the regen-trigger story for all three hashed governance sources.
6. **Mandatory Law #1 refactored to universal preamble + context-specific addendum (Q1 from review #1).** Previous root version carried a factual error ("amend either docs/constitution.md OR framework-shipped artefact" — but the meta repo has no docs/constitution.md). Refactor places a byte-identical preamble between root and template, with a single-line `*Framework-meta application:* / *Project application:*` addendum that legitimately diverges per context. `coherence-context.json universal_clause_mirror.doc` updated to declare the new structure.
7. **Governance-loaded confirmation visible at session start AND mid-session (B3 user request).** `validate-governance.sh --banner` detects context (meta vs downstream) and emits enriched banner with `dcs_hash` plus `[LAW] sections: N, universal DCs: M` parsed from the snapshot body. `governance-onprompt.sh` emits a positive `<governance-loaded snapshot="fresh" .../>` tag mid-session whenever the freshness gate passes, complementing the existing `<governance-warning reason="snapshot-stale">` block.
8. **adr/ → fdr/ sweep (I1 from review #1) plus regression cleanup (B6 from review #2).** First sweep updated 10 instruction/skill files to cite `docs/spec/{ID}/fdr/` as primary path with legacy `docs/spec/{ID}/adr/` fallback. Sweep accidentally left 8 stale field-name references (`adr_bindings` consumed in IMPLEMENT --build / --plan after BLUEPRINT § 7.8 was rewired to emit `fdr_bindings`). Review #2 caught the regression; mitigated in the same branch with backward-compatible `OR raw_section_78.adr_bindings` in the GCD fast-path.
9. **Q2 + I2 + I3 closed within this EVOL (review #2 follow-through).** Allowlist extended to permit `{{X}}` runtime placeholders in `.claude/instructions/**`, `.claude/commands/**`, and `.claude/skills/**` (matches the actual convention in those trees, which document agent-runtime substitution in pseudocode). factory-pr-review skill's `references/adr-policy.md` and `scripts/check_docs_sync.py` updated to cite `docs/project_log/adr/` (post-EVOL-016 path) and `docs/spec/{ID}/fdr/`. T2 test suite wired into the meta repo's `.github/workflows/governance-check.yml` so future PRs run the four `scripts/test-*.sh` automatically.

## Branch history (9 commits)

| # | Commit | Type | Summary |
|---|---|---|---|
| 1 | `53a7ac9` | `feat!(EVOL-026)` | Initial single-source-of-truth flip — snapshot generator rewrite, `[LAW]` markers, ADR/FDR template split, factory-adr-management SKILL, BLUEPRINT § 7.8 rewire, CI gate, T2 tests, manifest bumps to `3.0.0`. 17 files. |
| 2 | `1b053f8` | `feat(EVOL-026)` | Closure — 7 platform-specific governance-check workflow templates, `dcs_hash` freshness validation extended, `governance-onedit.sh` watcher extended to `defect-prevention.md`. 12 files. |
| 3 | `bfda0c2` | `fix(EVOL-026)` | Self-review #1 mitigations — lock-step drift on governance scripts (B1×2), root INVARIANT 2 sync (B2), REVIEW Check #14 contract break renamed `[DESIGN-ADR] → [DESIGN-FDR]` (B3), caveman cleanup of EVOL-026 narrative in 12+ framework files (B4), Phase 0 marker emitted (B5). 23 files. |
| 4 | `12c4590` | `fix(EVOL-026)` | Q1 from review #1 — Mandatory Law #1 refactored to universal preamble (byte-identical) + single-line context-specific addendum (E2 ratification). `coherence-context.json` updated to declare the new structure. 4 files. |
| 5 | `ceb43f0` | `feat(EVOL-026)` | B3 from user request — context-aware SessionStart banner (meta vs downstream) with `dcs_hash` + `[LAW]` / universal-DC counts. Mid-session `<governance-loaded ...>` tag emitted via `governance-onprompt.sh` when the freshness gate passes. 5 files. |
| 6 | `a402c00` | `fix(EVOL-026)` | I1 from review #1 — sweep `docs/spec/{ID}/adr/ → fdr/` across 10 instruction/skill files with explicit legacy-fallback notes. Variable rename `adr_bindings → fdr_bindings` in some lookup loops. 7 files. |
| 7 | `920a360` | `fix(EVOL-026)` | I1 sweep regression caught by factory-pr-review pass #2 — 8 sites in IMPLEMENT --build / --plan still consumed the renamed `adr_bindings` field. Restored with backward-compatible `OR raw_section_78.adr_bindings` legacy fallback in the GCD fast-path. 3 files. |
| 8 | `a1a4048` | `fix(EVOL-026)` | Q2 + I2 + I3 closure from review #2 — allowlist extended to `.claude/instructions/**`, `.claude/commands/**`, `.claude/skills/**` (Q2). `factory-pr-review` skill paths corrected post-EVOL-016 (I2). T2 governance suite wired into `.github/workflows/governance-check.yml` (I3). 5 files. |
| 9 | (this commit) | `docs(EVOL-026)` | Documentation closure — full execution log + review trail consolidated in this ADR. Aligns the ADR record with the branch history and the audit trail. |

## Review trail

The branch underwent three factory-pr-review passes during the session. Each pass executed Phase 0 (Coherence Audit) plus deterministic Phases 1-5 against the current state, applied mechanical mitigations under Phase 5.5 where applicable, and surfaced remaining findings for user decision.

**Pass #1** — after `1b053f8` (initial + closure commits).

| Finding | Severity | Disposition |
|---|---|---|
| B1 governance scripts not mirrored to template (×2) | 🔴 Blocker | Mitigated in `bfda0c2` |
| B2 root CLAUDE.md INVARIANT 2 stale wording | 🔴 Blocker | Mitigated in `bfda0c2` (initial framework-aware version) |
| B3 REVIEW Check #14 `[DESIGN-ADR]` consumed renamed field | 🔴 Blocker | Mitigated in `bfda0c2` (renamed to `[DESIGN-FDR]`, reads `fdr_bindings`) |
| B4 caveman drift — `EVOL-026` narrative leaked into operational files | 🔴 Blocker | Mitigated in `bfda0c2` (12+ sites cleaned) |
| B5 Phase 0 marker missing | 🔴 Blocker | Mitigated in `bfda0c2` (marker written) |
| Q1 Mandatory Law #1 root↔template divergence | ❓ Question | Resolved by user RDR (E2) → mitigated in `12c4590` |
| I1 `docs/spec/{ID}/adr/` references in 10 files | 🟡 Important | Resolved by user direction → mitigated in `a402c00` |

**Pass #2** — after `a402c00` (post-I1 sweep).

| Finding | Severity | Disposition |
|---|---|---|
| B6 I1 sweep regression — 8 stale `adr_bindings` field references in IMPLEMENT --build / --plan | 🔴 Blocker | Mitigated in `920a360` (legacy-compatible field rename) |
| I2 `docs/adr/` references in `factory-pr-review` skill (post-EVOL-016 path drift) | 🟡 Important | Resolved by user direction → mitigated in `a1a4048` |
| I3 T2 tests not wired into meta CI workflow | 🟡 Important | Resolved by user direction → mitigated in `a1a4048` |
| Q2 `{{X}}` placeholder allowlist coverage | ❓ Question | Resolved by user RDR (lectura a) → mitigated in `a1a4048` |

**Pass #3** — after `a1a4048` (post-Q2/I2/I3 closure).

| Detector | Result |
|---|---|
| 13a stale `[DESIGN-ADR]` | Clean |
| 13b stale `adr_bindings` field | Clean (only legacy-fallback citations remain) |
| 13c stale `docs/adr/` paths | Clean (only the legacy regex pattern remains in `ADR_DIR_PATTERNS`) |
| 14 placeholder leakage outside extended allowlist | Clean within the framework's operational tree; remaining hits are legitimate (meta-textual mention in CLAUDE.md, test-fixture content matching the placeholder convention, pre-existing `docs/project_log/` drift unrelated to EVOL-026) |
| 16-meta universal preamble byte-identity | MATCH |
| 16-meta governance scripts byte-identity | MATCH (governance-onedit, validate-governance, governance-onprompt, governance-oncompact) |
| 17 commit ↔ diff coherence | All 9 commits aligned with their stated changes |
| 18 bump severity ↔ change kind | `framework_version 2.10.2 → 3.0.0` MAJOR matches the breaking model flip; downstream entry bumps proportional |
| T2 tests | L1, L2, L4, L5 all PASS |

No new blockers. EVOL is internally coherent at branch HEAD.
