---
id: ADR-EVOL-136
title: "One owner per delivered file — sync replaces what the framework owns, upgrade never rewrites the project layer"
date: 2026-11-20
status: accepted
---

# ADR-EVOL-136: One owner per delivered file

## Context

This ADR plans issue #247 (epic #112, wave 5, destination S), follow-up F1 of spike #140 (ADR-EVOL-086, option 1: copy + sync, one owner per file). It was checked on `origin/main` at framework 10.13.0 (30b8449).

- **Ownership is prose today.**
  - The manifest's `upgrade_strategy` reads "Smart Additive Merge — ALL files" (`.context/templates/setup/governance_versions.json`).
  - SETUP `--upgrade` Step 2 merges every file by agent judgement, project rules included. Step 3 does the same for `CLAUDE.md` «with explicit user confirmation» and for `.claude/settings.json` by hand (`Factory-setup-upgrade.instructions.md`).
- **`factory-sync.sh` hardcodes its trees**: commands, instructions, skills, hooks, agents and the template tree.
  - Only scripts are derived from the manifest.
  - Orphan reports are prefix-filtered: instructions are counted twice, hooks report only `check-*`, commands are never checked, and a retired list is hardcoded.
  - `--preserve-local` is how a project keeps an edit to a delivered file.
- **No gate sees drift.** A framework file edited downstream is overwritten silently at the next sync.
- **The upgrade table contradicts the manifest.** It lists root `CLAUDE.md` under `framework_core` and calls the two sections mutually exclusive. The project's `CLAUDE.md` is `templates:claude/CLAUDE.md`, and hooks, agents and `delivery: both` scripts sit in both sections.
- **Readers to reuse:**
  - `coherence.manifest_parity` — member `manifest-parity`, light;
  - the registry migrations and Step 8b (#159);
  - `discovery.gates_upgrade`, whose semantics are: add what is absent, replace only a superseded literal, keep the rest.

## Decision

1. **One owner per delivered entry.**
   - Every `templates` and `agent_templates` entry, and every `framework_core` entry with `delivery` `sync` or `both`, carries `owner: framework | project | seam`. The owner names who owns the landed file.
     - **framework** — only the framework writes it.
     - **project** — a person, phase or agent writes it after it lands.
     - **seam** — both write it, keyed JSON.
   - `runtime_artefacts` have no source and are not delivered, so they carry no owner.
   - The `framework_core` entries under `.claude/{commands,instructions,skills,hooks,agents}` gain `delivery: sync`: the manifest, not a directory list, says what sync delivers.
   - The prose `upgrade_strategy` / `content_types` and the per-entry `upgrade_strategy` fields retire into the owner.
2. **Who owns what, from evidence.**
   - Rules and CI pipeline files are project-owned (ADR-EVOL-086 Q2: materialised bodies carry resolved values and project law).
   - Root `CLAUDE.md` is project-owned now (ADR-EVOL-086 target state). Until #248 (EVOL-137) splits it, its template moves are listed as owed to EVOL-137.
   - `.claude/settings.json` and `config/quality.json` are the two seams.
3. **One reader of the delivered set.**
   - `manifest.delivered()` maps each landed path to its source, owner and entry, preferring the template variant as sync does today.
   - `factory-sync.sh`, the synthetic materialisation and the SAST pack test read it.
   - A landed path is relative and has no `..` (`discovery.inside`, the one containment check). One outside the project is never delivered, never merged (`seams_upgrade` refuses it) and red in the owner rules.
4. **Sync delivers framework-owned files wholesale and records what it delivered.**
   - It writes each delivered source's `sha256` into the project's copy of the delivered manifest: one writer, no hash in the framework manifest.
   - Orphans are framework-owned paths the previous delivered manifest named and the new one does not. They are reported, never deleted.
   - `--preserve-local` retires (`retired_terms`, CLAUDE.md §4): `--dry-run` and the drift check cover its intent.
   - Sync exits non-zero when a delivered source is missing or the record cannot be written; before, it always exited 0.
5. **Project-owned files are written only by listed rows or answers.**
   - Upgrade lists `templates_to_refresh` (framework-owned, differing from delivery, copied by script) and `templates_moved` (project-owned, moved since the snapshot, reported "not written").
   - No generic merge runs. It would re-add sections a project deleted, and #247 rules out a project value changed by an upgrade.
   - A framework change reaches a project-owned file only through its own registry row, shown in the upgrade report before it is written.
   - Revisit trigger: a real upgrade reports a moved project template that no row carries.
6. **The seams merge by script, keyed and add-only.**
   - `discovery.seams_upgrade()` returns, per seam, the merged document and the `added`, `replaced` and `unresolved` keys.
   - **`settings.json`:**
     - an absent key or hook event is added whole;
     - a framework hook is known by its event, its matcher and the script it runs: it is added under the template's matcher when that matcher does not run it (one script may guard several matchers — the shell-write guards run under both `Edit|Write` and `Bash`);
     - only declared superseded literals are replaced: the bare command form and the #171 matcher.
   - **`quality.json`:**
     - an absent key path gets the template value with its placeholders resolved;
     - an unresolved one is listed for an RDR and not written;
     - lists are leaves.
   - An existing value is never changed, and a second run is a no-op.
7. **Drift is red, in the existing member.** `manifest-parity` in a project is red when:
   - a framework-owned landed file or a template source copy differs from its delivered `sha256`;
   - a framework-owned file is missing;
   - the delivered manifest carries no hashes;
   - a snapshot entry has no owner, naming the migration;
   - a stamped owner differs from the delivered one, naming the row that moves it.

   `subproducts/**` stay neutral in every gate. In the framework repo the check is n/a: the sources are the delivery. The drift check runs where the delivered manifest lives: the project's working copy, at commit and push. A project's CI clone carries no `.context/` (the materialised `.gitignore` excludes it), so there it is n/a — the push gate is its control point.

   In a project, parity and `manifest --bump` read the landed target, never the template source copy beside it. Sync has always delivered that copy, and the old order compared it first. A project's own drift was then invisible, and a bump moved the copy. The drift check now holds the copy.
8. **Validation in the framework repo** (`manifest-parity`). Red when:
   - a delivered entry has no owner, or a non-delivered entry has one;
   - an owner is outside the closed list;
   - a framework entry is not `universal` or carries `target_mode: merge`;
   - a seam's target is not JSON;
   - a project or seam entry is delivered by sync;
   - a landed path is absolute or climbs out with `..`;
   - one landed path has two owners.

   `gate.py manifest --new` copies the owner from its sibling.
9. **Upgrade path.**
   - One registry row, `owners (EVOL-136)` (`since` 10.14.0, `detect` `governance_features.owners_v1`), run by Step 8b. It stamps each snapshot entry's owner from the delivered manifest. It is idempotent.
   - Materialisation stamps owners from the start.
10. **No new command, flag or member.**

## Consequences

- `Factory-setup-upgrade` replaces the Step 2 merge, the Script Semantic Merge and the Step 3 `CLAUDE.md` / `settings.json` prose with the owner table. It also rewrites the contradictory section table.
- `upgrade_safety_protocol.md`, `/setup`, `factory-codebase-inventory`, `Factory-setup-materialization`, `README.md`, `gate.py` help, the meta `config/coherence-context.json` and the meta `CLAUDE.md` intro say the same. `--preserve-local` joins `retired_terms`. `rules/branching.md` needs no change: its «manifest parity» member is the one that grows.
- **Honest limits.**
  - The first sync after this ships reports no orphans: older delivered manifests carry no hashes.
  - Until #248 ships, a project receives no `CLAUDE.md` template change.
  - A forgotten row means a framework change never reaches a project-owned file. The report shows it; no gate forces it.
- **Upgrade.** Next sync and `SETUP --upgrade`: the row stamps owners; the seams merge.
- **Version kind.** MINOR (10.14.0). Retiring a flag with its replacement in place is a MINOR in this framework (EVOL-114 retired `--deprecate` and `--reset` at 8.14.0). The release notes name the downstream effects: `--preserve-local` exits 1, sync exits non-zero on an error, and a local edit of a framework-owned file is red until moved into a project-owned file.

## Verification

- **Unit tests (red first):**
  - owner rules;
  - `--new` copies the owner;
  - `delivered()` (a new delivered tree, an undelivered entry, the template variant, source copies);
  - drift (framework edit red, project edit green, source copy red, `subproducts` exempt, no hashes red, framework repo n/a);
  - snapshot owner missing or transition red;
  - seam cases for both files, idempotent, unreadable red;
  - the row owed then not owed;
  - `templates_to_refresh` / `templates_moved`;
  - a project reads the landed target, never the source copy (regression).
- **Synthetic materialisation with `--answers`:**
  - an aged project with project edits and one framework edit is red on drift;
  - after sync and the anchors, framework files are byte-identical to delivery;
  - project files are byte-identical except the seams' added keys;
  - a project's own command is kept;
  - owners are stamped;
  - a second run changes nothing;
  - `--preserve-local` exits 1.
- **Delivery tests:**
  - `test-sast-packs.sh` builds its delivered tree from `manifest.delivered()`;
  - `test-materialization-surface.sh` group 8: sync names no `.claude/<tree>` and only refuses `--preserve-local`;
  - the synthetic run delivers the framework with a real `factory-sync.sh`, not a hand copy.
- **Gates:** lock-step twins identical, manifest bumped.
