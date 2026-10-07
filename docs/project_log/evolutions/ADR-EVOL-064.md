---
id: ADR-EVOL-064
title: "Lean project CLAUDE.md — on-demand content leaves the template behind a pointer; a vertical-slicing rule; an advisory size budget"
date: 2026-10-07
status: accepted
---

# ADR-EVOL-064: Lean project CLAUDE.md

## Context

Issue #108. `.context/templates/setup/claude/CLAUDE.md` is 54 470 bytes (≈ 14 k tokens) and is re-read on every turn of every project materialised from it. Measured downstream: session floor (first-turn context) p50 69 k tokens. Under EVOL-063's 300 k compaction window that floor is 25–40 % of each turn and is reloaded after every compaction. A read-only analysis of every section (content already present elsewhere, references, always-on or on-demand) found about 16.8 KB whose content already lives in a skill, an instruction or a rule the consuming command loads — plus two "Framework Editor Invariants" subsections that address only an editor of this repository.

## Decision

RDR 2026-10-07, three questions; the user's verbatim answers:

- **Scope** — first pass: "Los proyectos ya existentes no se tocan. no entiendo bien la cuestion. solo se toca la template sin perder ni dinformacion ni fiabilidad."; re-posed under that constraint (A only what is already repeated elsewhere / B A plus a new rule file / D A now, B after measuring): "A. Solo lo ya repetido (Recommended)", then, before any template write: **"mejor opcion B"**.
- **Existing projects** — "lo dicho los proyectos ya instanciados no se tocan". `SETUP --upgrade` is unchanged: its `smart-additive-merge` of `claude/CLAUDE.md` keeps every existing section, so an installed project keeps its file as it is.
- **Size limit** — **"C. Límite solo aviso"**.

What ships:

- **The template only — scope B (analysis estimate ≈ 24 KB, −56 %; delivered 27 131 bytes, −50.2 % — the rest is always-on text the user's constraint keeps).** A paragraph leaves `.context/templates/setup/claude/CLAUDE.md` when its content already lives in a file the consuming command loads (replaced by a one-line pointer naming that file and section), or when it is on-demand content that moves verbatim to its new home: **§ Incremental Dev Plan** to a new rule `rules/vertical-slicing.md` (frontmatter `applicable_when`, delivered at the point of edit; CLAUDE.md keeps its two always-on lines — one PR per increment, every increment deployable, a MERGED increment immutable) and **§ Control points and gate profiles** to a new section of `rules/branching.md`; Generation Standards §1, the Workflow bullets, the Pre-Action planning paragraph, Currency and Templates condense to their pointers. Nothing is deleted: every moved sentence is found verbatim at its destination. Every H2 heading stays (merge anchors and the targets of "§ X" references); the mirrored sections (Communication Style, RDR Universal, Adversarial Reasoning) and § Governance Rules are untouched (`universal_clause_mirror`, `law_corpus_mirror`). Always-on text stays: triage, the pre-action gate, the invariants, the governance scope's first paragraphs, the version-bump rule, the branch rule, the RDR → IPP and ADP rows, "no agent ratifies".
- **Framework-editor text moves to the meta side.** The two "Framework Editor Invariants" subsections (Scope Taxonomy, Incremental Dev Plan) address an editor of this repository, never a project: they move verbatim to the PR review's docs-sync checklist (`.claude/skills/factory-pr-review/references/docs-sync-checklist.md`), where the meta review reads them.
- **An advisory size budget.** `budgets.claude_md_advisory` (bytes) in `config/quality.json` (meta and template): `gate.py budget` measures the `CLAUDE.md` re-read every turn; over the key is a **warning row** — never red, never a block — and the summary line `gate.py budget` prints (and the profile board shows beside the passing member) names it. An absent key is no row at all (an installed project whose config predates the key stays green). The framework repo measures the template it ships; a project its own `CLAUDE.md` (a synced template tree is not its file).
- **The record of where each paragraph went** is the table in § Verification record: section, bytes before and after, destination.

Risk: a pointer that names a section that does not exist, or content judged duplicated that was not — every removed paragraph's destination is checked by hand against the destination file and listed; the review lenses re-check the ledger. Risk: a pointer read late — the content moved is only what the consuming command's own instruction already loads.

## Consequences

- A project generated after this release receives the lighter file; an installed project keeps its own (`--upgrade` only adds sections).
- The review lanes and gates are unchanged; `gate.py budget` gains one advisory row.
- `framework_version` MINOR.

## Alternatives considered

- **A — only what is already repeated elsewhere** (−31 %, ≈ 37.5 KB) — first chosen, then replaced by B before any write: the template stays far from the measured target.
- **C — trimming always-on text too** (−63 %) — dropped: it cuts what must hold before any command runs and after a compaction; the user's constraint is no loss of reliability.
- **Retiring sections in installed projects on `--upgrade`** — rejected by the user: installed projects are not touched.
- **A blocking size budget** — rejected by the user (advisory only).

## Operational Rule

No universal sentence changes. The template's on-demand paragraphs become pointers; the meta `CLAUDE.md` § What Lives Where names the editor invariants' new home.

## Verification record

Template: 54 470 → **27 131 bytes** (−50.2 %; 26 903 before the review's restorations); all 17 H2 headings kept; Communication Style, RDR Universal, Adversarial Reasoning, Governance Rules, Context Preservation Invariants, SDLC-First Triage and Post-Action byte-identical. The advisory key is `28000` (the delivered size plus ~4 % headroom — a key the file exceeds on day one would warn on every push and stop being read); the target ≈ 24 KB of the analysis would have cut always-on text, which the user's constraint forbids.

Where each paragraph went (moved verbatim unless noted):

| Template section | Destination |
| --- | --- |
| Governance Scope ¶3 (hook mechanics) | `factory-governance-loading/SKILL.md` § Always-On Enforcement (already present); tier 5 and the resolution path kept in the template |
| Workflow bullets | condensed in place; CODESIGN authoring detail in `.claude/commands/codesign.md` and `Factory-codesign-sync` |
| Hard Gates table + gate sentences | `Factory-backlog-operations.instructions.md` § 1.1 gate table (Between column, phase labels added; the `full-sdlc`-only sentence already at its line 58) |
| Control points and gate profiles (EVOL-046) | `rules/branching.md` § Control points and gate profiles |
| Scope Taxonomy (axis table, cross-feature contracts, per-scope artefacts) | `Factory-codesign-feature.instructions.md` § Scope taxonomy (dual-axis); the compatibility matrix stays (INVARIANT 5 reads it) |
| Incremental Dev Plan body | `rules/vertical-slicing.md` (new; `applicable_when.path_glob` over `docs/spec/**/{spec.feature,slice_map.md,increment_plan.md,dev_plan.md}`); the always-on lines stay |
| Both Framework Editor Invariants | `.claude/skills/factory-pr-review/references/docs-sync-checklist.md` (meta only) |
| Generation Standards §1 (template lookup table) | `rules/documentation.md` § Template lookup |
| Generation Standards §3 mechanics | `rules/ci-cd.md` (one edit: "the Pre-Action Gate below" → "`CLAUDE.md` § Pre-Action Gate"); the branch-rule sentence stays |
| Pre-Action planning paragraph (EVOL-048) | `rules/branching.md` |
| Core Protocols skill rows | each skill's own frontmatter `description` (the harness lists it every turn); ADP, RDR → IPP, the agents pointer (with EVOL-063's window) and "no agent ratifies" stay |
| Living Governance Catalogs consumers table | `rules/defect-prevention.md` § Consultation (already present, more complete) |
| Artifact States: Currency, Component Registry | condensed in place; detail in `Factory-codesign-vision` § Component Registry |
| Templates / subproducts | condensed; `subproducts/*/RUNBOOK.md` |

A line-level sweep found 40 original lines not present verbatim in the template or any rule, instruction or skill: each is condensed in place or present in substance at the destination above (the review's fidelity lens checks each one). Red-first: `materialize-synthetic.sh` without the new rule — 109 passed, 1 failed (`vertical-slicing rule not delivered or not applicable`); with it — 110 passed. `test_gates.py::Budget::test_claude_md_advisory_warns_never_blocks` red, then green. Suites on the delivered bytes: test-gates OK, test-hooks 121, materialize-synthetic 110, lock-step 76 / 16, applicability (47 files), materialization surface, validate-governance, ADR sync, manifest-parity (36), the static round — green. Manifest: seventeen entries, one new (`rules/vertical-slicing.md` 1.0.0), `framework_version` 8.11.0 → 8.12.0, written by `gate.py manifest --bump`.

**Round 1 (sonnet, `max`, tier medium — 20 files, ~550 lines).** Security, governance: no findings. Fidelity 🟡: the subproducts line lost its enumeration (no product module, no framework module, no test root; neutral in governance, quality, verification loop) — present nowhere a project receives → restored in the template. Correctness ❓ ×3 (traced, confirmed here): the advisory measured the synced template in a project, never its own `CLAUDE.md` → the framework repo (`context == meta`) measures the template, a project its `CLAUDE.md`, a downstream fixture holding the template tree proves it; the WARN was invisible wherever the gate runs (the member passes, the board printed a bare ✓) → `budget.summary` names every advisory warning on the verdict line and the profile board shows a passing member's warning line (`profile._warn_line`); the synthetic assertion matched `vertical-slicing.md` under EXCLUDED too → it reads the resolver's JSON `active.rules` (red when the rule's glob stops matching, green with it). Informational cured: the three rules' frontmatter changelog and date; "the prompt and edit hooks always exit 0" kept in the template; the ADR's headline size, the absent-key wording, the hard-gate row. Reliability of the moved body: with no `--paths`, `path_glob` matches against the tracked tree, so once a project holds any `spec.feature` or plan the rule is in every command's Roll-Call (QA and CVP included); before the first spec it arrives at the point of edit. Left informational: the SKILL's always-on table has no tier-5 row (the template names it, as before); the runtime-surface prose now binds on CI files (its readers stay in the template and decide); the docs-sync checklist also reaches projects as an on-demand pr-review reference, its blocks scoped "only relevant if editing the framework repo".
**Round 2 (sonnet, `high`, tier medium — the one re-check, on the cures).** Correctness, fidelity: no findings. Leftovers cured and accepted under the written default (`rules/agents.md § The bounded loop`): the advisory's doc strings and the ADR bullet name the meta/project split; "trade safety for velocity intentionally" restored beside Q27.2; the manifest lines rewritten so each entry's line carries the feature and its cures (an idempotent bump had replaced the feature line with the cure line). Checked: the template carries no `{{…}}` placeholder, so a fresh project's `CLAUDE.md` lands at the template's size, under the key.