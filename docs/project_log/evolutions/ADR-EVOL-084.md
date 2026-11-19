---
id: ADR-EVOL-084
title: "Design-system catalog — the component registry carries a design-system version, architecture, development and QA read it, and one gate rejects UI built outside it"
date: 2026-11-19
status: accepted
---

# ADR-EVOL-084: Design-system catalog

## Context

This ADR implements issue #138 (epic #112, Wave 5, destination T). It was verified on `main` at framework 10.8.0 (b10fbba).

### State today
- **The registry has no design-system version.** `docs/ux/component-registry.json` (schema `component_registry_v1`, owner `Factory-codesign-vision` § Component Registry) carries `version`, but that is the schema's version. Nothing says which design system a component belongs to, and nothing distinguishes v1 from v2.
- **Only the PO package reads the registry.** Its readers are the package builder, the return validator and, in prose, BLUEPRINT and IMPLEMENT review. BLUEPRINT, IMPLEMENT and QA work from `component_library.html`.
- **The canonical-components rule has no check.** `rules/ux-constitution.md` § 3 (EVOL-072) says: «the component-catalog class-usage gate is the one gate for this rule … Until it ships, the governance lens reads this rule at review.» No defect class covers mock vocabulary in shipped UI; DC-45 is free in the `ui` family.
- **The rebuild is GitHub-only and advisory.** `workflows/design-system-rebuild.github-actions.yml` is `continue-on-error`. It lands on `ci_cd.platform == "GitHub Actions" AND po_package.ds_rebuild_command != null`, with no frontend condition. `build_po_package.py` knows only its GitHub path (`WORKFLOW_PATH`).
- **Q29.1** (`po_package.ds_*`) is asked on `codesign.authoring == external AND project_scope IN [full-stack, frontend-only]`, with no `frontend.framework` condition.

## Decision

1. **The registry carries the design-system version.**
   - New top-level field `design_system_version` (semver). It starts at `1.0.0` when the registry is first written (CODESIGN vision or the SETUP external-DS migration).
   - Each entry gains `since`: the design-system version that introduced it.
   - The bump rule is the catalog's semver:
     - adding a component is MINOR, and the new entry's `since` is the new version;
     - removing a component, or changing an entry's `id` or `cip_name`, is MAJOR;
     - a refresh of `name`, `group` or `ds_anchor` needs no bump.
   - The writers keep their columns (`Factory-codesign-vision` table); each one that adds or removes an entry applies the bump in the same write.
   - The schema id stays `component_registry_v1`: the new fields are additive.
2. **One gate: `gate.py catalog`, a profile member.** It needs no build and no network, so it runs at the static round, at every push and in CI.
   - **Applies** when `config/quality.json` has a `catalog` block, `frontend.framework` is answered in `docs/setup.md`, and the registry exists. Otherwise n/a with its reason: the framework repo; no block (`SETUP --upgrade` adds it); no frontend; no registry yet (CODESIGN `--vision` or the SETUP external-DS migration writes it).
   - **What it reads:** the UI files the change touches against the diff base (`catalog.sources` globs minus `catalog.exclude`), each file read whole, plus the registry at HEAD and at the base.
   - **Red (a) — a component outside the catalog.** A component tag rendered in a UI file whose import comes from a package that is not the design system's (`catalog.packages`), or a design-system import whose name the registry does not list. PascalCase tags are resolved through the file's ES `import` statements; a kebab-case tag in a Vue file is matched to its PascalCase import. A hyphenated custom-element tag (Angular selectors, web components) is red unless the project declares its selector or its prefix is in `catalog.prefixes`. Names in `catalog.allow` (framework built-ins such as `Fragment`, `Suspense`, `RouterView`) are never judged.
   - **Red (b) — a local copy.** A component defined under a name that is a catalog component (`cip_name`) in any file other than its canonical home: its `config/codebase_inventory.json` path, or `catalog.home` when the inventory does not name it.
   - **Red (c) — the mock's vocabulary shipped.** A UI file carries a `catalog.mock_vocabulary` pattern. The template ships `data-component=` and `lorem ipsum` (case-insensitive); a project adds its mock-only class names there.
   - **Red (d) — the registry's version.** `design_system_version` absent or not semver; an entry without `since`, or with a `since` above the version; against the base, the version lower, an entry added without at least a MINOR bump or with `since` not the new version, an entry removed or its `id`/`cip_name` changed without a MAJOR bump.
   - **Fail-closed:** an unreadable registry, block or UI file is red with its reason (LAW-08). There is no advisory mode.
   - `--json` lists every finding with file, line, clause and tag. QA reads it.
3. **One defect class: DC-45** (`ui`, BLOCKER): «Shipped UI uses catalog components from their home: no foreign component, no local copy, no mock vocabulary.» Gate: profile member `catalog`. Applicable To: BLUEPRINT, IMPLEMENT, REVIEW, QA. `rules/ux-constitution.md` § 3 «Check» names the gate and the class; the «until it ships» sentence goes.
4. **Architecture, development and QA read the catalog.**
   - BLUEPRINT design reads the registry (its components and `design_system_version`) when it designs UI. It designs with catalog components only. A component the catalog lacks is a design-system change, routed to CODESIGN `--vision-refine` by RDR; BLUEPRINT never adds one (LAW-16).
   - IMPLEMENT (the frontend worker) builds from the catalog's components, imported from their home, and runs `gate.py catalog` in its scoped red-first run.
   - QA reads `gate.py catalog --json` in its pre-verification gate and certifies against it. It does not re-judge the UI by reading it.
5. **The rebuild reaches Bitbucket.**
   - New template `workflows/design-system-rebuild.bitbucket.yml`, merged into `bitbucket-pipelines.yml` (`target_mode: merge`). It runs on the main branch and on demand (a custom pipeline), never on pull requests, like the GitHub job. It stays a producer: it builds the PO bundle and reports drift; the check is the gate.
   - Both rebuild templates gain `frontend.framework != None` in their condition.
   - `build_po_package.py` detects either platform's job when it reports mode 6C.
6. **Q29.1** `when` gains `frontend.framework != None`.
7. **Upgrade.** A migration row `catalog (EVOL-084)`:
   - adds the `catalog` block to `config/quality.json` when it is absent;
   - adds `design_system_version: "1.0.0"` and `since: "1.0.0"` per entry to an existing registry that lacks them.
   Installed projects get the gate through `factory-sync.sh` and the block through `SETUP --upgrade`.

### Sources
- `Factory-codesign-vision.instructions.md` § Component Registry: schema, writers, readers.
- `rules/ux-constitution.md` § 3 Canonical Components (EVOL-072): the policy this gate checks.
- `rules/defect-prevention.md`: `ui` family surface; DC-45 free.
- `scripts/gates/performance.py` `_scope`: the frontend applicability read (`answers()`, `surfaces()`).
- `governance_versions.json` templates: the Bitbucket `target_mode: merge` pattern (`auto-tag`, `deploy`, `governance-check`).
- Semantic Versioning 2.0.0: removal is incompatible (MAJOR), addition is compatible (MINOR).

## Consequences
- A frontend project's push is red when a touched UI file renders a component from a non-catalog package, redefines a catalog component, or ships mock vocabulary.
- A registry edit that adds or removes a component without its version bump is red.
- The design system's major version tells consumers when a catalog removal or rename happened.
- A project without a frontend gets no workflow, no registry field and no finding; the `catalog` block in `config/quality.json` is inert config there, as the `performance` block is.

## Honest limits
- **Changed files only.** The gate judges the UI files a change touches, each file whole. A file never touched again keeps an older violation. This is how an installed project adopts the gate without a backlog-wide stop.
- **No registry, no gate.** Before CODESIGN vision writes the registry, the gate is n/a. There are no mocks to build from before then.
- **Imports are read textually.** ES `import` statements are read. An import from the project's own sources is trusted: a project barrel that re-exports a foreign component is not followed. Dynamic imports, `require()` and global registration (`app.component(...)`) are not resolved.
- **Raw HTML is not judged.** A hand-written `<button>` beside a catalog `Button` is not detected. Mapping each catalog entry to the HTML it replaces is design-system data no registry holds today.
- **Mock vocabulary is pattern-matched.** The template ships two patterns; mock-only class names are the project's to add.
- **Version bumps are judged against the base.** Two branches that each add a component and bump MINOR from the same base both pass; the second to merge re-bumps when it rebases, like the governance manifest.

## Verification
- Budget: the DC-45 row fits `budgets.pre_edit` (5976 of 6000) because the DC-37 and DC-39 gate columns were shortened to the member and its command, as EVOL-071 did for DC-40..42.
- Red first: a component from a non-catalog package, a same-named local copy, `data-component=` in shipped UI, and a registry edit without its bump each fail `gate.py catalog`; the same tree with the cure is green.
- n/a cases: the framework repo, no block, no frontend, no registry.
- Synthetic materialisation: a frontend fixture lands the block and the gate; the frontend Bitbucket fixture with a rebuild command lands the step merged into `bitbucket-pipelines.yml`. A unit test pins both rebuild conditions (`frontend.framework != None`), the Q29.1 condition and the migration row.
- PO package selftest: a `bitbucket-pipelines.yml` carrying the step counts as the CI workflow (mode 6C).
- Upgrade fixture: an installed registry without the version fields gains them.
- Profile membership, lock-step, manifest-parity, ADR sync.
