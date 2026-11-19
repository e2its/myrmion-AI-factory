---
id: ADR-EVOL-086
title: "Framework as a dependency: one owner per delivered file, so an upgrade never rewrites the project layer"
date: 2026-11-19
status: proposed
---

# ADR-EVOL-086: One owner per delivered file

## Context

Spike for issue #140 (epic #112, Wave 5, destination S). Verified on `feature/EVOL-084-design-system-catalog`, framework 10.9.0. No framework change in this spike.

**The issue's premise is half true.** `factory-sync.sh` does leave the project layer alone (`scripts/factory-sync.sh:24-29`). `SETUP --upgrade` does not — it writes into project files by design:

- **Root `CLAUDE.md`** — template `claude/CLAUDE.md` → target `CLAUDE.md`, `smart-additive-merge` (`.context/templates/setup/governance_versions.json:448-453`), merged by the agent with «explicit user confirmation» (`Factory-setup-upgrade.instructions.md:455`). The template carries **zero** `{{…}}` placeholders (28 KB, all framework prose) — it is framework-owned content parked in a project file. The upgrade table also lists root `CLAUDE.md` under `framework_core` (`Factory-setup-upgrade:119`), contradicting the manifest, where it sits in `templates`.
- **`.claude/settings.json`** — `merge-preserve` (manifest `:412-417`): framework hook wiring and project `permissions`/`model`/`env` in one file; the merge is prose the agent runs (`Factory-setup-upgrade:456-464`).
- **`config/quality.json`** — `stack_configured` (manifest `:489-493`); upgrade adds framework blocks into it (`Factory-setup-upgrade:326, 433`); sync only warns that they are missing (`factory-sync.sh:385-390`).
- **`docs/setup.md`** — answers back-filled by the generic upgrade step (`Factory-setup-upgrade:212`, #159 phase 2).
- **`.claude/rules/**`** — 37 rule templates; 18 carry placeholders, 19 none. Project law bodies (`[PLAW-NN]`, `Body:` pointers — `constitution_template.md:15-43`) and project defect classes (`{{DC_ENTRIES}}`, `rules/defect-prevention.md:49,82-85`) live in the same tree and some of the same files.
- **A project is told to edit a framework file.** «Add project-specific gates as further members in `scripts/gates/profile.py`» (`workflows/governance-check.github-actions.yml:13`); `profile.py` is a synced lock-step file (`config/coherence-context.json` pair `scripts/gates/*.py`), so the next sync overwrites the edit unless `--preserve-local` (`factory-sync.sh:39,192-195`).

**What sync ships** (`factory-sync.sh:12-22, 338-443`): `.claude/{commands,instructions,skills,hooks,agents}` (hardcoded dirs), scripts by manifest query (`delivery: sync|both`, `:406-438`, 95 entries), the full `.context/templates` tree (258 files, 5.1 MB). Framework-owned surface in a project ≈ 360 files, ≈ 7.5 MB.

**What runs outside Claude Code and needs the files in the repo:** the git hooks call `scripts/gate.py` (`scripts/hooks/pre-push:39-61`); every CI template runs `python3 scripts/gate.py profile --run` after a plain checkout (`governance-check.github-actions.yml:30,51`). The upgrade's generic step and the snapshot read the registry and the framework manifest from the delivered template tree (`Factory-setup-upgrade:212`; `scripts/gates/profile.py:82`).

**Lock-step never crosses the boundary.** It is META-ONLY and self-guards to a no-op outside the framework repo (`scripts/check-lockstep-pairs.sh:5-10, 43-46`); 17 pairs, all meta↔template (`config/coherence-context.json` `audit.lock_step_pairs`). Downstream, two manifests already coexist: the delivered framework manifest (`.context/templates/setup/governance_versions.json`) and the project snapshot (`docs/project_log/governance_versions.json`, `factory-sync.sh:135-136`; `profile.py:82`). Universal laws are parsed from root `CLAUDE.md` (`scripts/gates/corpus.py:58-59,140-143`).

**Neighbours, not re-decided here:** #159 (EVOL-102) owns the question registry, the answer home (`docs/setup.md` frontmatter), the generic upgrade question (phase 2, shipped v8.17.0) and `--reconfigure` (phase 3, ships with #148). #139 (team mode) owns multi-author state. #186 owns before/after measurement in an adopting project.

## Questions

1. **Packaging options** — compared below (plugin from a marketplace, plugin vendored in the repo, package manager, submodule/subtree, copy+sync with a boundary).
2. **What stays project-side** — under every option: `CLAUDE.md` (project part), `docs/**` (setup, constitution, specs, project log, project snapshot), `config/**`, `.claude/settings.json` (permissions, model, env), `.claude/rules/**` materialised bodies with their resolved values and every `PLAW`/`PDC`, `.mcp.json`, CI pipeline files after materialisation, `src/ tests/ infra/ contracts/ migrations/`. No plugin or package can carry `CLAUDE.md` or rules: a plugin-root `CLAUDE.md` is not loaded ([plugins-reference § Standard layout](https://code.claude.com/docs/en/plugins-reference)).
3. **Lock-step and manifest across the boundary** — lock-step stays meta-only (it already is). The framework manifest stays the one list of delivered files; it gains one field, the owner, and sync derives every tree from it (today only scripts are derived, `factory-sync.sh:406-423`). The project snapshot keeps recording delivered versions.
4. **Migration for installed projects** — one registry migration row run by the generic upgrade (#159 Step 8b): split root `CLAUDE.md`, move project gate members out of `profile.py`, stamp owners. See Consequences.
5. **Answers and materialised config survive the switch** — under the recommendation nothing moves: answers stay in `docs/setup.md` frontmatter (#159), config in `config/quality.json`. Under a plugin/package switch they also stay, but every reader of the registry and manifest must find the framework tree outside the repo.
6. **Does `SETUP --upgrade` still re-ask unanswered questions?** Yes, unchanged under the recommendation (`gate.py discovery --resolve`, `Factory-setup-upgrade:212`). Under a marketplace plugin the registry lives in the plugin cache; `${CLAUDE_PLUGIN_ROOT}` is **not** in the Bash tool's environment ([plugins-reference § Environment variables](https://code.claude.com/docs/en/plugins-reference)), so every scripted read needs a new locator.

## Decision to take (RDR)

### In plain words

Hoy, cuando un proyecto actualiza el método, la herramienta de copia no toca nada del proyecto, pero el paso de actualización sí reescribe archivos del proyecto: el documento de instrucciones principal, la configuración de permisos, la configuración de calidad y algunas reglas. Ocurre porque esos archivos mezclan dos dueños: un trozo es del método y otro es del proyecto. Ahora toca decidirlo porque el equipo de un cliente va a trabajar sobre esos archivos y no puede perder sus cambios en cada actualización.

Caminos:

1. **Dejar claro quién es dueño de cada archivo, sin cambiar cómo se entrega (recomendado).** Cada archivo entregado declara su dueño. Lo que es del método se reemplaza entero. Lo que es del proyecto no se toca, salvo para añadir algo que falta, y eso se enseña antes. Coste: el proyecto sigue guardando una copia del método (unos 360 archivos) y cada actualización sigue trayendo un cambio grande. Hay una migración única para los proyectos ya instalados.
2. **Distribuirlo como extensión instalable de Claude desde un catálogo.** Coste: hay que cambiar el nombre de todas las órdenes y agentes. Cada persona tiene que instalarla en cada copia del proyecto. En las sesiones en la nube no se instala sola. Además, los controles automáticos del servidor de integración no la ven, así que una parte del método seguiría copiándose al proyecto: serían dos canales en lugar de uno.
3. **Extensión de Claude guardada dentro del propio proyecto, en una sola carpeta.** Tiene una ventaja: la configuración de permisos queda solo para el proyecto. Coste: el mismo cambio de nombres que en el camino 2, y las organizaciones que bloquean extensiones no gestionadas la desactivan sin avisar. Sigue habiendo copia.
4. **Paquete de un gestor de paquetes para la parte de controles.** Coste: hay que publicar y mantener un paquete. Las instrucciones para los agentes se siguen copiando. Son dos canales y no arregla los archivos mezclados.
5. **Submódulo de git que apunta a una versión del método.** Coste: hay que montar una versión «para distribuir» del método y configurar los siete sistemas de integración. Es fácil olvidar actualizar el submódulo. Claude solo busca en carpetas fijas, así que acaba siendo el camino 3.

Ninguna forma de empaquetar arregla por sí sola los archivos con dos dueños. Lo que lo arregla es separar los dueños, y eso hay que hacerlo con cualquiera de los cinco caminos. Por eso se recomienda el 1: es el que construye menos y no rompe nada de lo que ya funciona.

### Technical

**Evidence (summary).** The project layer is written by the upgrade because 5 delivered targets have mixed ownership (Context). External facts, from [plugins-reference](https://code.claude.com/docs/en/plugins-reference), [plugins/components](https://code.claude.com/docs/en/plugins/components.md), [plugins/loading](https://code.claude.com/docs/en/plugins/loading.md) and [marketplace-reference](https://code.claude.com/docs/en/plugins/marketplace-reference.md):
- A plugin ships skills, commands, agents, hooks (`hooks/hooks.json`, merged with settings hooks), MCP/LSP servers, output styles, workflows, monitors, `bin/` (on the Bash tool's PATH). No `CLAUDE.md`, no rules, no permissions.
- Every component is namespaced `<plugin>:<name>`. In this repo that touches 141 slash-command references and 25 files that name `factory-*` agents.
- Plugin agents ignore `permissionMode`, `hooks` and `mcpServers`.
- Versions: the manifest `version` pins; without one the version is the commit SHA. A marketplace `ref` can be a full SHA (Claude Code ≥ 2.1.324); a plugin `github`/`url`/`git-subdir` source takes `sha`.
- A project enables a plugin through `enabledPlugins`/`extraKnownMarketplaces` in `.claude/settings.json`. An external-source plugin is fetched only when user, local, flag or managed settings set it `true`, so each clone runs `claude plugin install … --scope project`. Cloud sessions do not add repository-listed marketplaces.
- A directory with `.claude-plugin/plugin.json` under the project's `.claude/skills/` loads in place as `<name>@skills-dir`. It needs workspace trust, loads only from the primary working directory, and is skipped silently under managed `strictPluginOnlyCustomization` or a `strictKnownMarketplaces` list without `skills-dir`.
- `CLAUDE.md` `@path` imports inside the working directory load without an approval dialog (max 4 hops). `.claude/rules/` is read recursively ([memory](https://code.claude.com/docs/en/memory)).
- pip hash-checking needs every requirement pinned and hashed ([pip secure installs](https://pip.pypa.io/en/stable/topics/secure-installs/)).

**Adversarial pass on the recommendation (option 1).**
- *FOR, governance:* the manifest is already the one list of delivered files (LAW-01). Ownership is one field on it, and sync derives every tree from it, as it already does for scripts. Lock-step is untouched (LAW-12, meta-only). Git hooks and CI keep in-repo paths, so `gate.py one-definition` and the profile hold. #159 keeps answers and the generic upgrade, and this spike adds no question.
- *FOR, product:* zero onboarding change. It works in CI, cloud sessions and managed orgs, needs no rename, and fits PHP/Node stacks with no new package manager (python3 is already required — `pre-push:53`).
- *AGAINST, governance:* copying stays, so a project can still edit a framework file. Answer: a gate flags a framework-owned file that differs from its delivered version — red, not silent. Do-less check: is that gate needed? The rule «sync replaces framework-owned files wholesale» already restores them, but silently. The gate is what turns a lost edit into a visible finding. Keep it, as one profile member, not a new tool. The seams (`settings.json`, `quality.json`) stay two-owner files. Answer: they become declared seams with a scripted, keyed, add-only merge — LAW-03 reuse of the existing keyed hook merge and the `gates_upgrade` script.
- *AGAINST, product:* the repo still carries about 7.5 MB of framework files, and upgrade PRs stay large. That is today's cost and not a regression. The `CLAUDE.md` split moves universal law into an imported file, so `corpus.py:143`, the banner (`validate-governance.sh:79-101`) and the snapshot must follow the import. That is a real change, and it stays one reader.
- *Do-less lens:* the plugin options need the same ownership split **plus** a namespace rename, a second delivery channel for CI and git hooks, and a locator for the plugin root. Option 1 builds strictly less. The recommendation survives.

**Options** (G = SDLC governance, P = product):

| # | Option | G pros | G cons | P pros | P cons |
|---|---|---|---|---|---|
| 1 | **Copy+sync, one owner per file** (minimal) | one manifest field; lock-step, CI, hooks unchanged; #159 untouched | copy can drift → one gate; two declared seams | no onboarding change; CI, cloud, managed orgs | ~360 files copied; large upgrade diffs; one-time migration |
| 2 | Marketplace plugin + in-repo gate kit | version pinned by SHA | two channels (plugin + repo copy for gate.py, hooks, templates); plugin root not in Bash env; rename of 141 refs and 25 agent-name files, `gate.py agents` | `settings.json` hooks leave the project file | per-clone install; cloud sessions skip it; no per-component override documented ❓ |
| 3 | Plugin vendored at `.claude/skills/<name>/` (skills-dir) | one framework directory; CI sees it | same rename; skipped under managed plugin-only policy | hooks out of `settings.json`; no per-clone install | trust + primary-dir limits; still a copy |
| 4 | Package (pip/npm) for the gate kit, copy for agent files | hashed pins | two channels; a publishing pipeline; mixed files unsolved | — | private registry per client; Python packaging in non-Python stacks |
| 5 | git submodule / subtree of a framework dist tree | commit pinned by gitlink | a dist build; `submodules:` on 7 CI templates; discovery paths force option 3's shape | — | forgotten `submodule update`; subtree drags history |

**Recommendation: option 1.** Main tradeoff: the framework is still copied into each repository, in exchange for no rename, no second channel and no onboarding change. Surviving risk: two seam files (`settings.json`, `config/quality.json`) stay two-owner — mechanical and add-only, but not pure project files. Revisit trigger: #186's measurement shows upgrade cost that comes from copy volume, not from ownership. Then option 3 is the next candidate; the split built here is its prerequisite.

## Consequences

- **What lands in a materialised project:**
  - Each delivered entry declares `owner: framework | project | seam`.
  - Framework-owned files are replaced wholesale, and orphans are reported.
  - Project-owned files are never written by sync. Upgrade writes them only through registry migrations or answers, add-only, each listed in the upgrade report before it is written.
  - Root `CLAUDE.md` becomes project-owned: one `@` import of a framework-owned file plus the project's own sections.
  - Project gate members live in a project-owned file that `profile.py` reads.
  - A light-profile member is red when a framework-owned file differs from its delivered version.
- **Which answer selects it:** none. This is framework core, so every project gets it and no registry question is added.
- **Upgrade path:** one registry migration row (`since` = the shipping version), run by #159's generic Step 8b:
  - **(a) Split root `CLAUDE.md`.** Content equal to the recorded template version goes to the framework file. Every other section stays in the project file. A section that matches neither = one RDR.
  - **(b) Move project gate members.** Members found in `profile.py` that are absent from the delivered version move to the project file.
  - **(c) Stamp owners** in the project snapshot.
  - Idempotent.
- **Synthetic proof:**
  1. Materialise a fixture at the previous framework version with `--answers`.
  2. Edit project-owned files and add one gate member to `profile.py`.
  3. Run sync and upgrade.
  4. Assert:
     - project-owned files are byte-identical except the listed add-only keys;
     - framework-owned files are byte-identical to delivery;
     - the gate member survives in the project file;
     - law parity reads the imported file;
     - a second run changes nothing.

## Follow-up issues

**F1 — One owner per delivered file: sync replaces, upgrade never rewrites the project layer**
- Goal: every file a project receives has one declared owner, and sync and upgrade obey it.
- We want:
  - an owner on every manifest entry, validated (no entry without one);
  - sync deriving every tree from the manifest, with no hardcoded directory list;
  - framework-owned files replaced wholesale;
  - project-owned files written only by listed, add-only migrations or answers, reported before writing;
  - `settings.json` and `config/quality.json` as declared seams merged by script, keyed and add-only;
  - a red member when a framework-owned file differs from its delivered version;
  - the upgrade table's `framework_core`/`templates` contradiction removed.
- We do not want:
  - an LLM merge of any project file;
  - a project value changed by an upgrade;
  - `--preserve-local` as the way a project keeps its work.
- How it reaches a project: no answer — framework core. Lands with the next sync and upgrade. Upgrade path: migration row stamps owners. Synthetic proof as in Consequences.
- Depends on: #159 phase 2 (shipped). Phases with #159 phase 3: until it ships, `--reconfigure` does not exist; when it ships, it writes answers through F1's add-only path.

**F2 — Framework instructions out of the project's CLAUDE.md**
- Goal: the project's `CLAUDE.md` holds only the project's text; universal instructions arrive in a framework-owned file it imports.
- We want:
  - the split;
  - every reader of universal law, the banner and the snapshot following the import, in the same change;
  - the lock-step pair re-pointed to the new template path;
  - the migration step (a) with its RDR for an unclassifiable section.
- We do not want:
  - two copies of universal law;
  - a project section lost or moved without an RDR.
- How it reaches a project: no answer. The migration row lands it. Synthetic proof: an old-version fixture with a project-added section, kept after upgrade.
- Depends on: F1.

**F3 — No project edit inside a framework file**
- Goal: every place the framework tells a project to extend it is a project-owned file.
- We want:
  - project gate members in a project-owned file read by the profile;
  - the CI template comment re-pointed;
  - a sweep of the instructions, skills and templates for other «edit this framework file» instructions, each given a project-owned home;
  - migration step (b).
- We do not want:
  - a project gate member lost on sync;
  - a second member list.
- How it reaches a project: no answer. The migration row moves existing members. Synthetic proof: a member added to `profile.py` in a fixture survives sync and upgrade.
- Depends on: F1.

## Honest limits

- No plugin prototype was built or loaded. Plugin facts come from the docs pages cited, read on 2026-11-19.
- ❓ unverified — external: there is no documented way for a project to disable one hook, skill or agent of an enabled plugin (only plugin-level `enabledPlugins`). This is inferred from the absence of such a mechanism in the pages read.
- ❓ unverified — external: a git submodule checked out under `.claude/skills/<name>/` loads as a skills-dir plugin. The docs speak of a directory; submodules are not mentioned.
- The sizes (≈360 files, ≈7.5 MB) are this repository's trees, not a downstream measurement. The upgrade-cost trigger depends on #186.
- The rename blast radius (141 refs, 25 files) is a grep count, not a full audit.
- Whether the banner hash and `corpus.py` should read the imported file or its rendered sum is left to F2.
