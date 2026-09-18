# PO package — operator runbook

How to run CODESIGN with a Product Owner who works outside the repository, in a Claude Desktop project. This file is self-sufficient: it works before the `factory-po-intake` skill is installed (the skill arrives with `factory-sync.sh`, not with SETUP). When the skill is present it drives these same steps.

## This project

Resolved by `SETUP --generate`. Update this block by hand if the configuration changes later (section 8).

- Project: **{{PROJECT_NAME}}**
- Package mode: **{{PO_PACKAGE_MODE}}** (`full` = design system and features · `features-only`)
- Design-system cards come from: **{{DS_CARDS_SOURCE}}**
- Rebuild command: `{{DS_REBUILD_COMMAND}}`
- CI workflow: {{DS_CI_WORKFLOW_STATUS}}

Active design-system section: **{{DS_ACTIVE_SECTION}}**

## Requirements

- Python 3.10 or later, with PyYAML: `python3 -m pip install pyyaml`.
- Check both at once: `python3 subproducts/po-package/validate_po_return.py --selftest` — `0 failure(s)` means ready.
- The PO needs only Claude Desktop.

## The loop

```
  Factory                PO (Claude Desktop)            Factory
 ┌─────────┐   zip →    ┌──────────────────┐   zip →   ┌──────────────────────┐
 │ build   │            │ one feature, or  │           │ validate · ratify ·  │
 │ package │            │ the design system│           │ sync · plan catalog  │
 └─────────┘            └──────────────────┘           └──────────────────────┘
```

Nothing the PO returns is applied automatically, and nothing is regenerated: what is ratified is taken in as written.

## 1. Build the package

First the roadmap export. Ask the agent for it: *"export the roadmap for the PO package"*. It reads the board through `/backlog --status` (the adapter, never the tracker directly) and writes `roadmap.json` outside the repository: a JSON list of `{"id", "name", "summary"}` for every feature on the board that has no `docs/spec/<ID>/` folder yet. Then:

```bash
python3 subproducts/po-package/build_po_package.py --roadmap ../roadmap.json
```

The builder reads the repository and writes **outside** it: a staging tree in the system temp folder (or `PO_PACKAGE_OUT`, or `--out`) and a zip in `~/Downloads` (or `--zip-dir`). It never calls the tracker. Without `--roadmap` the package simply carries no roadmap.

Before sending, read what it printed: the feature count, the card count, and every `WARNING`. An empty glossary means no journey could be read — fix that first, the closed-vocabulary rule has nothing to hold.

## 2. Set up the Claude Desktop project

The zip carries its own `README.md` for the PO. In short: new project → paste **all** of `PROJECT-INSTRUCTIONS.md` into the project instructions → upload `00-core/`, `10-design-system/`, `30-templates/` to the knowledge → do **not** upload `20-features/` (attached per chat). For design-system work: a second project with `PROJECT-INSTRUCTIONS-VISION.md`.

Smoke test: ask the project which features are specified and which are only on the roadmap. If it cannot tell, the knowledge did not index.

## 3. While the PO works

Ask for small, frequent returns. Two or three features are reviewed in a day; a large return takes weeks and the product moves underneath it. One design-system change per return: a design-system return is adopted whole or sent back whole.

## 4. Validate the return

```bash
python3 subproducts/po-package/validate_po_return.py --selftest
python3 subproducts/po-package/validate_po_return.py --zip ~/Downloads/<return>.zip
```

Run `--selftest` first, every time: this tooling sits outside the governed surface and the self-test is its only net. The validator judges **form and coherence, never merit**. Journey form is judged by `scripts/check-journey-grammar.sh`, the same gate CODESIGN applies to its own output.

| Verdict | What to do |
|---|---|
| GREEN | Reviewable. Go to section 5. Green is not accepted. |
| RED on form | Send the report back to the PO, unedited. |
| RED that names the journey gate's infrastructure | Nothing goes back to the PO: restore `scripts/check-journey-grammar.sh` and run again. |
| GREEN with `…-new-undeclared` warnings | A name not in the glossary and not declared. Check it against the glossary with the PO before ratifying: an invented name where one exists is the most expensive defect a return can carry. |
| GREEN with open questions | Settle them with the PO before section 5. |
| Exit code 2 | The tool could not do its job (configuration, repository, a fault of its own). It is not a verdict about the return: nothing goes to the PO. `PO_PACKAGE_DEBUG=1` adds the stack trace; the exit code stays 2. |

Never fix the PO's documents to turn a red into a green. A translated heading means the instructions did not land; patching it silently guarantees the same error next round.

## 5. Ratify, sync, plan the catalog

1. **Read the evolution request before the artefacts.** Check every `reuse_checked` against `00-core/domain-glossary.md`, `docs/ux/component-registry.json` and `config/codebase_inventory.json`.
2. **One decision per change** (RDR: at least three options, a recommendation, the user's choice recorded). Never classify in bulk.
3. **Write the drop zone**: copy each ratified target to `docs/ux/po-return/VISION/` or `docs/ux/po-return/<ID>/`, and write `docs/ux/po-return/INTAKE.md` with the verdict, the ratified targets, the rejected changes and the decisions.
4. **Sync, one target at a time:**

   ```
   /codesign --sync VISION
   /codesign --sync <ID>
   ```

   `--sync` adopts what was ratified as written and adds only what the factory owns (header, iteration ledger, change classification, cascade). It never regenerates and never edits PO content: a finding sends the target back as `NEEDS_INFO` and leaves `docs/spec/<ID>/erq/<erq_id>.findings.md` — send its PO items to the PO, unedited. The evolution request and your decisions are kept next to it, so they outlive the drop zone. Leave the drop zone uncommitted: `--sync` adopts from it, commits the adoption and deletes it. In this project `/codesign --start` and `/codesign --refine` are closed and point here.
5. **A new feature whose CODESIGN item is not eligible on the board** is not synced because it arrived. Park the material in a refinement issue with `/backlog --create-issue`. Arrival is not scheduling.
6. **Component catalog.** After a design-system sync, every component in `docs/ux/component-registry.json` with status `DESIGNED` and no `backlog_ref` is missing build work. The first time: decide whether to create the foundational catalog feature, then `/backlog --plan-feature <ID> "Component Catalog"` and one `/backlog --create-issue "[<ID>] COMPONENT: <name>"` per component (labels `phase:implement`, `scope:frontend-only`, `kind:component-catalog`). Afterwards: one refinement issue per new component. Write `backlog_ref` and `PLANNED` back to the registry. Everything goes through `/backlog`; never call the tracker directly.

## 6. Design-system cards

The package ships one preview card per component in `10-design-system/cards/`. Only one of the three sections below applies to this project — the one named under **This project**.

### 6A — cards from the vision only

No code cards folder is configured. Cards are cut from `docs/ux/vision/component_library.html` and `style_guide.html`, one per `data-component` / `data-token-group` anchor. Nothing else to run. Each card's footer names the code primitive that materialises the component, taken from the registry joined with the codebase inventory.

### 6B — cards rebuilt from code, outside CI

A project tool renders the real components into the cards folder named in the configuration (`design_system.code_cards.dir`). Refresh that folder whenever components change, and always before building a package. Two ways; **This project** says which applies.

**Rebuild command `none` — you ask Claude (the usual).** Ask Claude to run your design-system-from-code tool into that folder, then build. The builder says the cards were taken `as found — NOT refreshed`: expected here, it only reminds you to refresh first.

```bash
python3 subproducts/po-package/build_po_package.py --mode ds-only --check-drift --out ../ds-bundle
python3 subproducts/po-package/build_po_package.py --roadmap ../roadmap.json
```

**A rebuild command is configured — the builder runs it.** `--rebuild` runs the tool first:

```bash
python3 subproducts/po-package/build_po_package.py --mode ds-only --rebuild --check-drift --out ../ds-bundle
python3 subproducts/po-package/build_po_package.py --rebuild --roadmap ../roadmap.json
```

Per component, a card rendered from code wins over the vision card, so the PO sees what the application really renders as soon as a component exists. Components with no code yet keep their vision card. If the command fails or times out, the builder warns loudly and uses vision cards: it never blocks. The command runs without a shell, from the repository root.

### 6C — cards rebuilt in CI (workflow installed)

Same as 6B with a rebuild command — a tool you can only run by asking Claude cannot run in CI — and `.github/workflows/design-system-rebuild.yml` runs the rebuild and the drift check on every push to the main branch and on demand. It is advisory: it never fails the pipeline. Download the bundle from the run's artefacts, or run the 6B commands locally. Before building a package, still pass `--rebuild` so the package matches the code of the day.

### Reading the drift report

| Finding | Meaning | What to do |
|---|---|---|
| `code-card-unregistered` | Code renders a component the design system does not know | Add it to the design system, or remove it from code |
| `implemented-without-code-card` | The registry says built, nothing renders | The rebuild tool does not cover it, or the status is wrong |
| `candidate-implemented` | The registry says designed or planned, and code already renders it | Reconcile the registry to `IMPLEMENTED` (section 5.6) |
| `drift: not applicable` | No code cards folder is configured (case 6A, or a project with no design system) | Nothing. `--strict` has nothing to fail on |
| `drift: NOT COMPUTED — …` | A code cards folder is configured, so drift applies, but it could not be measured in this run (the rebuild failed, the folder yielded no card, there is no vision yet, or the project authors no design system) | Read the `WARNING` lines above it. Under `--strict` this exits 1: an unmeasured drift is not a pass |
| `code cards: N taken … as found — NOT refreshed` | Cards on disk were used without running the tool | Refresh them before trusting the drift lines: ask Claude to run your tool, or pass `--rebuild` when a rebuild command is configured |

### Mirror in Claude Design (optional)

`/design-sync` publishes `10-design-system/` to a design-system project in Claude Design. It is a one-way mirror, started by you. Nothing here waits for it and no gate depends on it.

## 7. Close the loop

Rebuild the package so the PO works on the new state, not on the one sent last time. Send the PO a short written account: what went in, what did not and why, what stays open. Without it the next return repeats the same errors.

## 8. Changing case later

- **Turning cards from code on after `vision` or `defer`:** set `design_system.code_cards.dir` in `subproducts/po-package/po-package.config.json`, and `rebuild_command` only if your tool has a terminal command. You are now in 6B.
- **Adding the CI workflow** (needs a rebuild command): copy `.context/templates/setup/workflows/design-system-rebuild.github-actions.yml` to `.github/workflows/design-system-rebuild.yml`. You are now in 6C.
- **Then update the "This project" block above.** The builder compares that block with the configuration and the workflow's presence on every run and warns when they disagree.

## 9. What breaks and how it shows

| Symptom | Cause | Fix |
|---|---|---|
| The validator refuses to start and names placeholders | The config was never materialised | Run `SETUP --generate`, or pass `--config` |
| `journey-grammar-infra` | `scripts/check-journey-grammar.sh` is missing or cannot run | Restore it with `factory-sync.sh`; a return cannot be judged without it |
| Every mock is red on `external-deps` | The project loads a host the templates do not | Add it to `mock.allowed_external_hosts` in the config |
| The package ships whole-file cards | The vision has no `data-component` anchors | Add them through a design-system return |
| Every code card is skipped: `does not open with the card marker` | Your cards tool writes another format | Each card must be an HTML file whose first line is `<!-- @dsCard group="…" -->`: have the tool write it; if it cannot, report it to the framework |
| The glossary is empty | No journey could be read | Run the journey gate on each feature folder |
| `/codesign --sync` says to run the intake first | `docs/ux/po-return/INTAKE.md` is missing, not green, or does not list the target | Go back to section 5.3 |
