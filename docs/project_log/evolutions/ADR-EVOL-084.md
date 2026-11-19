---
id: ADR-EVOL-084
title: "Design-system catalog — the component registry carries a design-system version, architecture, development and QA read it, and one gate rejects UI built outside it"
date: 2026-11-19
status: accepted
---

# ADR-EVOL-084: Design-system catalog

## Context

This ADR implements issue #138 (epic #112, Wave 5, destination T). It was verified on `main` at framework 10.8.0 (b10fbba) and rebased on 10.8.1 (c3ebac5).

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
     - a refresh of `name`, `group` or `ds_anchor` needs no bump;
     - binding a built component (`cip_name` null → name, written by PO intake) needs no bump: the catalog does not change.
   - The writers keep their columns (`Factory-codesign-vision` table); each one that adds or removes an entry applies the bump in the same write.
   - The schema id stays `component_registry_v1`: the new fields are additive.
2. **One gate: `gate.py catalog`, a profile member.** It needs no build and no network, so it runs at the static round, at every push and in CI.
   - **Applies** when `config/quality.json` has a `catalog` block, `frontend.framework` is answered in `docs/setup.md`, and the registry exists. Otherwise n/a with its reason: the framework repo; no block (`SETUP --upgrade` adds it); no frontend; no registry yet (CODESIGN `--vision` or the SETUP external-DS migration writes it).
   - **What it reads:** the UI files the change touches against the diff base (`catalog.sources` globs minus `catalog.exclude`), each file read whole, plus the registry at HEAD and at the base.
   - **Red (a) — a component outside the catalog.** A component tag rendered in a UI file whose import comes from a package that is not the design system's (`catalog.packages`), or a design-system import whose name the registry does not list. PascalCase tags are resolved through the file's ES `import` statements; a kebab-case tag in a Vue file is matched to its PascalCase import. A hyphenated custom-element tag (Angular selectors, web components) is red unless the project declares its selector, its prefix is in `catalog.prefixes`, or it is a global built-in in `catalog.allow` (`router-outlet`, `router-view`; kebab or Pascal form).
     - Never judged: an import from the project's own tree (a relative or rooted path, an alias, a `catalog.local` prefix) and an import from the UI framework's own packages (`catalog.frameworks`: the union of the supported frameworks' packages, so `Suspense` from `react` or `RouterLink` from `vue-router` passes). A name is never exempt by itself: `Switch` from another library is judged like any component.
     - A URL, a protocol-relative `//host` or a scheme specifier (`https:`, `npm:`) is never the project's own.
     - A `<Name` glued to an identifier, `)`, `]` or `.` is a type argument (`useState<ReactNode>`), not a tag; a type-only import binds nothing.
     - The home (`catalog.home`) is exempt from (a): it is the catalog's implementation and wraps what it likes (a dialog over a headless primitive). (b) and (c) still read it.
     - `catalog.packages` and `catalog.prefixes` are answered at SETUP: new question **Q14.1** (since 10.9.0, asked where a frontend exists). Without them, every design-system import would be red; the SETUP question rule asks every answer no earlier one derives.
   - **Red (b) — a local copy.** A component defined under a name that is a catalog component (`cip_name`) in any file other than its canonical home: its `config/codebase_inventory.json` path, or `catalog.home` when the inventory does not name it.
   - **Red (c) — the mock's vocabulary shipped.** A UI file carries a `catalog.mock_vocabulary` pattern. The template ships `data-component=` and `lorem ipsum` (case-insensitive); a project adds its mock-only class names there.
   - **Red (d) — the registry's version.** `design_system_version` absent or not semver; an entry without `since`, or with a `since` above the version; against the base, the version lower, an entry added without at least a MINOR bump or with `since` not the new version, an entry removed or its `id`/`cip_name` changed without a MAJOR bump.
   - **Fail-closed:** an unreadable registry, block or UI file is red with its reason (LAW-08). Every key of the block is validated before any file is read, so a malformed block is red on every change; `sources` must be non-empty. A registry the base has and HEAD does not is red: deleting it is a MAJOR change, not a way out of the gate. There is no advisory mode.
   - Every registry or inventory value the gate prints passes the one sanitiser (`_clean`): a planted control byte or newline never reaches the CI log.
   - The import reader is linear: the clause starts on a non-space and every blank run is bounded.
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
   - The Bitbucket step stages the bundle in `/tmp/ds-bundle` (the builder refuses a folder inside the repository) and copies it into the clone for the artifact.
   - Bitbucket hands every repository variable to every step: the step unsets the framework's own credentials (`BITBUCKET_TOKEN`, `CONFLUENCE_API_TOKEN`, `CONFLUENCE_USER_EMAIL`) before the project's command runs. Other secrets stay secured Deployment variables, as the deploy template already says. Scrubbing the whole environment (`env -i`) was rejected: it breaks the project's toolchain (PATH extras, proxies, caches).
   - A merged step list lands before the target's first manual step (`trigger: manual` holds every step after it), so the rebuild on `main` never waits behind the production button.
   - The step merges into a deploying file and reads paths the deploy never ships: materialisation (and the upgrade) declares them in `surface.declared_reads` (`subproducts/po-package/**`, `ds-bundle/**`) so `gate.py runtime-surface` stays green.
6. **Q29.1** `when` gains `frontend.framework != None`.
7. **Upgrade.** A migration row `catalog (EVOL-084)`:
   - asks Q14.1 (pending where a frontend exists) and adds the `catalog` block to `config/quality.json` when it is absent;
   - adds `design_system_version: "1.0.0"` and `since: "1.0.0"` per entry to an existing registry that lacks them (an executable block in the upgrade instruction, proven by the harness).
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
- **Imports are read textually.** ES `import` statements are read, comments and strings included. An import from the project's own sources is trusted: a project barrel that re-exports a foreign component is not followed. Dynamic imports, `require()` and global registration (`app.component(...)`) are not resolved. A default or namespace import is judged by its local name.
- **Raw HTML is not judged.** A hand-written `<button>` beside a catalog `Button` is not detected. Mapping each catalog entry to the HTML it replaces is design-system data no registry holds today.
- **Mock vocabulary is pattern-matched.** The template ships two patterns; mock-only class names are the project's to add.
- **The UI framework's packages are trusted wholesale.** `catalog.frameworks` ships the union of the supported frameworks; a framework the list lacks (an "Other" answer) is the project's to add.
- **A type argument is told from a tag by its shape.** A name glued to the word before it and closed by `>` at once (`useState<T>`, `FC<P>`) is a type argument. Text glued to an element (`Hi<Icon />`) stays a tag; `Save<Icon>` closed at once is read as a type argument and missed. `Promise<Card | null>` with a value-imported `Card` is read as a tag and is red; `import type` cures it. A missed tag passes silently, a misread one is red with its cure, so the rule leans red.
- **Bare specifiers are packages.** `Components/Button` (no `./`, `@/`, `~/`, `#` or `$` prefix and not in `catalog.local`) is judged as a foreign package. Name a bare project alias in `catalog.local`.
- **The design system wins over a framework's scope.** `@angular/material` in `catalog.packages` is judged against the registry, though `@angular` is in `catalog.frameworks`.
- **The rebuild artifact reaches later steps.** Bitbucket hands `ds-bundle/**` to the later steps of the `main` pipeline, the production deploy included. The bundle is built on `main` by the project's own command, and the deploy executor ships what its stage commands build, so it carries no trust the deploy lacks.
- **Only the framework's credentials are unset.** The rebuild step unsets the three it injects, above the project's toolchain line. A built document store's credential names, or any other repository variable, are the project's to keep as secured Deployment variables.
- **Version bumps are judged against the base.** Two branches that each add a component and bump MINOR from the same base both pass; the second to merge re-bumps when it rebases, like the governance manifest.

## Verification
- Budget: the DC-45 row fits `budgets.pre_edit` (5976 of 6000) because the DC-37 and DC-39 gate columns were shortened to the member and its command, as EVOL-071 did for DC-40..42.
- Red first: a component from a non-catalog package, a same-named local copy, `data-component=` in shipped UI, and a registry edit without its bump each fail `gate.py catalog`; the same tree with the cure is green.
- n/a cases: the framework repo, no block, no frontend, no registry.
- Synthetic materialisation: a frontend fixture lands the block and the gate; the frontend Bitbucket fixture with a rebuild command lands the step merged into `bitbucket-pipelines.yml`. A unit test pins both rebuild conditions (`frontend.framework != None`), the Q29.1 condition and the migration row.
- PO package selftest: a `bitbucket-pipelines.yml` carrying the step counts as the CI workflow (mode 6C).
- Upgrade: the migration's executable block versions an 8.x registry and a second run changes nothing (harness); the 8.12 fixtures owe the migration and DC-45.
- Bitbucket: the frontend fixture's merged `main` pipeline runs the rebuild before the manual production step, and `gate.py runtime-surface` is green with Bitbucket's deploying file and the declared read; the PO selftest runs the template's own script lines (exit 0, bundle copied in) and a pipeline without the job is not 6C.
- Linear time: a 40 000-blank run after `import` is read in under 2 s.
- Round 2: text glued to an element is judged, a design-system package under a framework's scope is judged against the registry (both red on the round-1 cure), and a canary where the project's toolchain line goes sees none of the framework's credentials (PO selftest).
- Profile membership, lock-step, manifest-parity, ADR sync.
