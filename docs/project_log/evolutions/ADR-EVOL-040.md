---
id: ADR-EVOL-040
title: Global CVP remediation — full-tree validator, unified delivery channel, LAW-NN corpus
date: 2026-08-04
status: accepted
---

# ADR-EVOL-040: Global CVP remediation

## Context

A global CVP-method analysis @ main ce4b818 (three read-only sweeps: manifest↔disk full, reference integrity, meta↔product seam) found 11 CRITICAL + 15 WARNING + 14 note. The CI-enforced surface was 100% clean; every defect lived in the manually-disciplined surface. Three root causes: (A) the manifest validator covered 5 of 8 governed trees, its extension filter blinded `.py/.ts/.yaml/.hbs/extensionless`, and diff-scoping made pre-existing orphans permanently invisible; (B) two delivery channels with no shared manifest — factory-sync's hardcoded script list vs SETUP's template auto-scan — so materialized CI invoked scripts SETUP never delivered; (C) the CLAUDE.md meta↔template pair had only 3 H2 sections under mechanical verification — accumulated drift produced ordinal 7 carrying two different laws and a truncated LAW-08 in meta.

Two binding user principles anchor every decision: (1) everything optimises for SETUP instantiation being perfect, reliable and secure — the definitive verification is the materialization surface, not meta validators; (2) the meta-framework is agnostic by definition until SETUP materializes it with SETUP-decided values — tool names live only in config resolution tables and discovery options.

## Decision

One PR, six commits (K1-K6), 40 findings → 37 fixed + 3 discarded with reason. Two RDR-ratified structural decisions:

- **RDR-1 — stable `LAW-NN` IDs, single namespace across the pair.** Rendered `N. **[LAW-NN] Title**: …` — the list ordinal is cosmetic, the ID is authoritative, assigned once, never renumbered or reused. Universal laws = same ID both files, bodies byte-identical (mechanically enforced by the new `law_corpus_mirror` pair type in `check-lockstep-pairs.sh`); context-specific laws declared in the pair's `meta_only`/`project_only` arrays (LAW-07 templates-hygiene + LAW-12 lock-step = meta; LAW-14 SETUP-scaffolding = project); LAW-01 carries a declared per-context addendum (`addendum_ids`); LAW-15 = the ADP vocabulary sections. Decisive argument: shipped skills are ONE artifact running in both contexts — before this, "LAW 12" meant lock-step in meta and code-review in a project. Project-minted laws use the disjoint `PLAW-NN` namespace.
- **RDR-2 — security-scan as a config-driven dispatcher materialized from SETUP decisions** (LAW-11/EVOL-033 pattern). New discovery Q23.2 (scanner: gitleaks default / trufflehog / custom / Skip) → `quality.json.security_scan` placeholders resolved at materialization → the script reads config, resolves the scanner command template, normalizes findings, never names a tool in code paths. Two-layer security: always-on fail-closed regex floor (`detect_change_type.py`, Block 3) + fail-open-NOISY scanner layer (mandatory 🔒 banner). `--require-scanner` preserves the pre-push fail-closed asymmetry; the hook's inline gitleaks (an agnosticism violation) delegates to the dispatcher. The historical 0-byte `scripts/security-scan.sh` — born empty at the initial commit while 4 consumers invoked it — dies.

Root-cause fixes: (A) `validate-governance.sh` 2.0.0 — TRACKED_DIRS ×10, full-tree CHECK 2 via `git ls-files`, 3-section TRACKED_PATHS/vmap, new CHECK 1c (dup paths / dup targets / missing target keys), welded to 26 new manifest entries in the same commit; (B) factory-sync's script list replaced by a manifest query over the new `delivery: sync|setup|both` field, 3 CI-invoked scripts template-ized with lockstep pairs, `coherence-context.json` finally materialized, delivery-closure Invariant added to materialization; (C) the LAW corpus above + § What Lives Where rewritten to match reality + declared-divergence doctrine (context divergence lives in pair `doc`/arrays, never implicit).

## Disposition table (40 findings)

| # | Finding | Sev | Disposition |
|---|---|---|---|
| 1 | setup-materialization:336 constitution path missing `constitution/` segment | C | FIXED K2 |
| 2 | blueprint-design:89 malformed validation-template path | C | FIXED K3 (canonical `{AGENT}_VALIDATION_TEMPLATE.md` form; dir is downstream-synthesized per materialization :1206) |
| 3 | detect_change_type.py no manifest entry | C | FIXED K1 |
| 4 | auto-tag.yml duplicate entries, divergent versions | C | FIXED K1 (short key survives, max version, changelog union; CHECK 1c guards) |
| 5 | governance-check.yml duplicate entries, divergent changelogs | C | FIXED K1 (idem) |
| 6 | Bitbucket templates target collision | C | FIXED K1 (`target_mode: merge` declared; CHECK 1c blocks undeclared) |
| 7 | 6 scripts/ files untracked incl. 0-byte shipped security-scan.sh | C | FIXED K1 (entries) + K4 (dispatcher content) |
| 8 | LAW ordinal 7 = two different laws meta vs template | C | FIXED K3 (LAW-07 meta / LAW-14 project) |
| 9 | coherence-context.json never materialized despite manifest promise | C | FIXED K2 (materialization § 4.2.3) |
| 10 | check-adr-constitution-sync.sh + check-inventory-freshness.py CI-invoked, no template | C | FIXED K2 (template sources + lockstep pairs + delivery both) |
| 11 | template CLAUDE.md references extinct `.claude/rules/*.instructions.md` family | C | FIXED K2 (template coherence-context globs) — the CLAUDE.md INVARIANT-2/Living-Catalogs mentions verified: already `*.md` form |
| 12 | phantom generate-applicability-context.sh in shipped skill | C | FIXED K2 (ref removed; regen = SETUP --upgrade) |
| 13 | 14 template-tree files untracked | W | FIXED K1 (absorbed by root cause A weld) |
| 14 | .context/utils partial coverage ×3 | W | FIXED K1 |
| 15 | .context/schemas untracked ×2 | W | FIXED K1 |
| 16 | meta .claude/settings.json untracked | W | FIXED K1 (tracked: wires governance hooks, lockstep left-side) |
| 17 | inventory-drift.yml entry in wrong section, no target | W | FIXED K1 |
| 18 | 4 target-less template script/hook entries | W | FIXED K1 |
| 19 | 6 synced-no-template scripts | W | FIXED K2 (3 template-ized, 3 reclassified delivery:sync with role note) |
| 20 | LAW 12 text enumerated 2 universal_sections vs config's 3 | W | FIXED K3 (enumeration dropped — config is the single source) |
| 21 | LAW-08 Humanized Blocking truncated in meta | W | FIXED K3 (template text wins, now mechanically mirrored) |
| 22 | INVARIANT 5 divergence undeclared | W | FIXED K3 (declared in law_corpus_mirror pair doc + What Lives Where) |
| 23 | Generation Standards §3 wording drift | W | DECLARED K3 (context-specific per What Lives Where; fast-lane allowlist line listed framework-only) |
| 24 | § What Lives Where inaccurate | W | FIXED K3 (rewritten to reality + declared-divergence doctrine) |
| 25 | __pycache__/*.pyc synced downstream | W | FIXED K2 (deleted + sync_tree prune + .gitignore) |
| 26 | 9 manifest entries version-bumped without changelog line | W | FIXED K1 (backfilled) |
| 27 | 10 ascending-order changelogs | W | FIXED K1 (flipped newest-first) |
| 28 | last_updated stale | W | FIXED K6 |
| 29 | V-3 changelog line without version prefix | W | FIXED K1 |
| 30 | `.context/setup.md` legacy paths (applicability SKILL + allowlist.json) | W | FIXED K2 |
| 31 | phantom lint-contracts.sh ref | W | FIXED K2 (ref removed; dispatcher --contracts is the path) |
| 32 | {{X}} fixtures in scripts/test-* outside Detector-14 allowlist | W | FIXED K3 (allowlist += scripts/test-*) |
| 33 | $schema v1 vs manifest_version 2.x | W | FIXED K1 ($schema → governance_versions_v2; zero consumers of v1 literal) |
| 34 | § anchor "Canonical Iteration ID Schema" imprecise (×2 files) | n | FIXED K3 |
| 35 | GWP heading case drift | n | FIXED K3 |
| 36 | immutability landmark cited as heading | n | FIXED K3 (template :177 → § Per-Increment Immutability) |
| 37 | INVARIANT-1 feat/* dropped in meta | n | FIXED K3 |
| 38 | phantom `claude` role dir in meta § Templates | n | FIXED K3 |
| 39 | stale "and the other three" CI comment | n | FIXED K1 |
| 40a | ADR-EVOL-028 `.context/setup.md` mention | n | DISCARDED — ADRs are immutable historical records (LAW-01 model); editing history breaks provenance |
| 40b | iop-intent-map / backlog "Rules 1-7/1-3" | n | DISCARDED — algorithm-local rule numbering, not constitutional ordinals; renaming would harm, not help |
| 40c | `.claude/X` schematic notation in pr-review Block 16 row | n | DISCARDED — intentional pattern notation, not a path |

## Consequences

- The manifest is now COMPLETE and structurally trustworthy → factory-sync can (and does) query it as the delivery source of truth. Any branch cut before this PR that adds a governed-tree file without an entry will fail full-tree CHECK 2 on rebase — expected, announced in the PR.
- Universal-law drift between the CLAUDE.md pair is now a CI failure (law_corpus_mirror, 11 self-test cases), not a review-discipline hope. Context divergence must be DECLARED.
- A fresh `SETUP --generate` delivers every script its own materialized CI invokes (delivery-closure Invariant + T3 surface test `scripts/test-materialization-surface.sh`).
- `security-scan.sh` template entry takes a MAJOR (3.0.0): `--semgrep`/`--gitleaks` flags removed (agnosticism). No in-repo callers; downstream direct callers flagged via SETUP --upgrade.
- `framework_version` 5.8.0 → 5.9.0 (MINOR): LAW re-tagging is presentation (ordinals stay; the only 3 ordinal refs migrated in-PR; snapshot extraction contract untouched); everything else additive with back-compat aliases.

## Alternatives considered

Full logs in `docs/proposals/EVOL-040-cvp-remediation.md` §2. Headlines: per-root-cause PR split (rejected: validator hardening and manifest cleanup are mutually dependent — the weld); shared renumbering with context blocks and per-context ordinal mapping tables (rejected: fragility survives, every future ref pays a context qualifier); removing security-scan (rejected: cuts capability 4 consumers specify); full manifest-driven sync rewrite (rejected DC-29: directory-glob categories already correct).

## Operational Rule

Constitutional amendment shipped in this PR: the Governance Rules corpus of BOTH CLAUDE.md files re-rendered with stable `[LAW-NN]` IDs (this restructure IS the amendment); meta LAW-12 body updated to cite the config-declared pair types; § What Lives Where rewritten. See `CLAUDE.md` + `.context/templates/setup/claude/CLAUDE.md`.
