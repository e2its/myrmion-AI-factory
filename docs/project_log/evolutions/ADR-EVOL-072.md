---
id: ADR-EVOL-072
title: "Product laws for APIs and UIs: one error code per meaning, CRUD-First single and batch, canonical components, delivered artefacts never deleted"
date: 2026-11-06
status: accepted
---

# ADR-EVOL-072: Product laws for APIs and UIs

## Context

This ADR implements issue #126 (epic #112, train row 6b). It was verified on `main` at framework 8.22.0.

A downstream project proved four product laws generic. The framework ships none of them as a checked rule:

- **Error codes.** `rules/api-standards.md` gives the error shape `{code, message, details, trace_id}` and says the code stays constant across locales. No catalog exists, and nothing checks that a code means one thing.
- **CRUD-First.** `rules/contract-first-policy.md` § CRUD-First names the CRUD table and four extension patterns: a custom action, a nested resource, a bulk operation, search by query. An operation outside them declares nothing. `x-crud-exception` exists nowhere.
- **Canonical components.** `rules/ux-constitution.md` says nothing about importing the canonical components and the mock primitives, or about the mock's vocabulary.
- **Deletion.** `rules/immutability_policy.md` says «`--cancel` does not delete artifacts, only marks them terminal». That is prose only. `scripts/gates/frontmatter.py` (member `frontmatter-lock`) skips a deleted file.

Further facts:

- **One contract reader.** `scripts/gates/freeze.py` is the only reader of `contracts/openapi/**` today (`CONTRACT_RE`, `_load`, `_walk`). Its docstring hands parity to the contract parity reader of #124.
- **Defect rows.** Validator V13 refuses a universal row with no gate. § Promotion 2 of `rules/defect-prevention.md` keeps a class without a gate in the issue that builds its gate. A row that applies to some projects only is bound through a registry option's `configures → defect_prevention.classes`; Q11 binds DC-18 that way. An unbound row is dropped at materialisation.
- **Scope.** Q4.5 `project_scope` takes full-stack, backend-only, frontend-only or integration. The `applicable_when` scope vocabulary has no `integration`, so scope binding goes through the registry and the manifest, never through frontmatter. `ux-constitution.md` is skipped for backend-only and integration.
- **#138** (Wave 5, depends on #126) builds the component-catalog class-usage gate: the one gate for the canonical-components invariant.

## Decision

1. **Error-code catalog (API scope).**
   - **Template:** `contracts/errors.yaml`, landing with `stack_conditional: project_scope IN [full-stack, backend-only, integration]`.
   - **Shape:** one entry per meaning, `CODE: {meaning, status}`. It is seeded with the generic codes the API rules already name, plus `BATCH_TOO_LARGE` (413), the one code for a batch over its size cap.
   - **Use:** a contract response names its codes as `x-error-codes: [CODE, …]`.
   - **Rule body:** `api-standards.md` § Error codes. There is one code per meaning, and every code is in the catalog. A new meaning gets a new entry, and an entry is never reused for another meaning.
2. **CRUD-First single and batch, kept or declared (API scope).**
   - **Owner's decision (2026-11-06):** «el crud debe ser doble. single operation y batch»; the reading confirmed verbatim: «si, eso es». Every resource exposes eight operations — create, list, read, update (PUT or PATCH), delete, bulk-create, bulk-update, bulk-delete; batch read is the filtered list — or declares each omission.
   - **Rule body:** `contract-first-policy.md` § Completeness and exceptions. A missing operation is declared on the resource's path item (the collection's or an item's): `x-crud-exception: <reason>` for every omission, or `{<operation>: <reason>}` per omission. An operation outside the CRUD table and the four extension patterns carries `x-crud-exception: <reason>` on the operation.
   - **Resource:** a CRUD-shaped collection, or the parent of an item path. A POST-only path after a `{param}` with no direct child path is a custom action, not a resource.
   - **Batch behaviour (RDR «1», 2026-11-06):** a batch operation states a size cap (`maxItems`, over it refused whole with `413 BATCH_TOO_LARGE`), per-item authorization (an item the caller may not touch answers `NOT_FOUND`, as a missing one does, so the batch reveals nothing), a named failure mode (`all-or-nothing` or `per-item`) and a safe retry (an `Idempotency-Key` scoped to the caller and the route, bound to the body), in `contract-first-policy.md` § Bulk Operations. Read at review by the security lens (`security_policy.md` points to it, OWASP API1 and API4); no gate.
   - **CRUD-shaped**, decided mechanically:
     - Strip leading `api` and `v<N>` segments (`v1`, `v1.0`, `v2beta`). The rest alternates literal collections and single `{param}`s, starting with a collection: two literals or two params in a row are not CRUD-shaped.
     - A path ending in a collection takes GET or POST. A path ending in a `{param}` takes GET, PUT, PATCH or DELETE.
     - Also allowed: `POST …/{param}/<verb>` (custom action) and `POST|PATCH|DELETE …/<collection>/bulk-<verb>` (bulk). Search uses query parameters, so its path is a collection.
     - Anything else declares its reason.
3. **One contract reader: the gate member `contracts`** (`scripts/gates/contracts.py`, light profile).
   - It reuses `freeze._load`, `freeze._walk` and `freeze.CONTRACT_RE`.
   - It reads the catalog and every contract, whole: uniqueness and completeness are properties of the whole.
   - **Older contracts (RDR «3», 2026-11-06):** the findings an installed project already carries are recorded once, at `SETUP --upgrade`, in `docs/project_log/crud_baseline.json` (`undeclared`, from `gate.py contracts --json`). The baseline only shrinks: an entry no longer found is red (remove it); an entry absent from the base's baseline whose finding the base's contract did not already carry is red (new debt never enters); a baseline git does not track is red. No new flag: the upgrade writes the `--json` list verbatim, and the gate checks it.
   - A file with no `openapi` / `swagger` / `paths` key (an example payload, a placeholder) is not judged for CRUD. A path that resolves outside the repository is red and never read.
   - Meanings normalise in any script (NFKC, casefold, Unicode word characters); a meaning that normalises to nothing is no meaning.
   - It reports n/a when neither exists.
   - **Red when:**
     - a code repeats in the catalog (a duplicate-aware line scan, because YAML keeps the last value);
     - two entries share a meaning, normalised for case, spacing and punctuation;
     - an entry has no meaning;
     - a contract names a code the catalog lacks, or names codes and no catalog exists;
     - a non-CRUD operation has no `x-crud-exception`, or an empty one;
     - a resource lacks one of its eight operations and declares no reason for it;
     - the baseline grows, keeps a paid entry, is unreadable or is untracked.
   - **Handover:** #124 extends this module with parity. It adds no second reader.
4. **A delivered artefact is never deleted (every project).**
   - `frontmatter-lock` gains a delete clause. A `.md` or `.feature` file is red when it is deleted, replaced by a link, or renamed to a name that is no artefact, and its `status` at the base is delivered (an approved state of `planning.APPROVED_STATES`, or `MERGED`) or terminal (CANCELLED, SUPERSEDED — `APPROVED (SUPERSEDED)` included: the trace of what was decided).
   - A rename to another `.md` or `.feature` name keeps the artefact. A base frontmatter the parser cannot read is judged by its `status:` line, never skipped.
   - Resolution: «mark it terminal (CANCELLED or SUPERSEDED); never delete it».
   - `immutability_policy.md` states the law and names the gate. A secret or a personal datum in a delivered artefact is redacted in place, the file kept; the secret is rotated, and erasing history is the owner's decision.
5. **Defect classes.**

   | DC | Family | Invariant | Gate | Lands |
   |---|---|---|---|---|
   | DC-36 | `boundary` | One error code, one meaning; every contract code is a catalog entry | `contracts` | API scope, bound by Q4.5 |
   | DC-37 | `boundary` | Every resource exposes CRUD single and batch; an omission or a non-CRUD operation declares `x-crud-exception` | `contracts` | API scope, bound by Q4.5 |
   | DC-38 | `process` | A delivered artefact is never deleted | `frontmatter-lock` | every project |

   Q4.5's full-stack, backend-only and integration options bind DC-36 and DC-37 (`configures → defect_prevention.classes`). A frontend-only project never receives them.
6. **Canonical components (UI scope).**
   - `ux-constitution.md` gains § Canonical components. The UI imports the canonical components and the mock primitives and never redefines them. The mock's vocabulary never ships.
   - It lands where `ux-constitution.md` lands: a project with a frontend.
   - **Intermediate state, stated:** this rule's gate, defect row and red test are #138's, the one gate for this invariant (V13, § Promotion 2). Until #138 ships, the rule is read at review. No second gate lands here.
7. **Q36 `domain.monetary_amounts`** (`true` / `false`).
   - Asked only when `project_scope IN [full-stack, backend-only, integration]`.
   - The recommendation reads Q2 (purpose) and the audit. It is a recommendation, never an inference.
   - On `true`, `rules/monetary-amounts.md` lands (`stack_conditional: domain.monetary_amounts == true`). It describes a value object: an integer in minor units plus an ISO 4217 currency, no floats, arithmetic within one currency, and explicit rounding by a named mode. It bounds the value at the edge: a string amount `pattern: '^-?[0-9]{1,18}$'`, a currency `'^[A-Z]{3}$'`. It gives one short snippet per backend runtime that has a SAST pack.
   - It is domain guidance, not a law: no gate and no defect class.
8. **Upgrade.** One migration row, the CRUD baseline seed; the rest rides on #159.
   - `SETUP --upgrade` asks the questions a project never answered: Q36 when Q4.5 selects it, and Q4.5 itself when unanswered.
   - It lands the templates the project lacks (`templates_to_add`) and adds the bound defect rows (`defect_classes.to_add`).
   - The `contracts` member arrives with `scripts/gates/**` through factory-sync. The registry row `contracts baseline (EVOL-072)` (`since` 8.23.0, `detect` `docs/project_log/crud_baseline.json#/undeclared`) makes `migrations_owed` name the seed; its anchor `Factory-setup-upgrade` § contracts writes `gate.py contracts --json` → `undeclared` verbatim to the baseline, so an installed project is green on arrival with its older findings visible; no older contract names codes. Both upgrade fixtures expect the row.
   - `upgrade-8.12-api.json` proves the answered-scope path: Q36 pending, `contracts/errors.yaml` and DC-36..38 owed. `upgrade-8.12.json` proves the unanswered one: Q4.5 pending, Q36 not asked.
9. **Consistency.** `Factory-blueprint-design` (contract authoring) and `Factory-implement-build` (contract check) say the same things:
   - codes come from the catalog;
   - a new meaning adds an entry;
   - every resource exposes CRUD single and batch, or declares each omission, and a non-CRUD operation declares its reason;
   - a batch operation states its four behaviours, and its handler keeps them.

   The README lists the new member. The contract template in `contract-first-policy.md` carries the three bulk routes and their schemas.

## Consequences

- An API project's codes stay one per meaning, checked on every push. A duplicate code, a duplicate meaning or an undeclared code is red before review.
- Every departure from CRUD-First, and every missing single or batch operation, carries its reason in the contract, where the reviewer reads it.
- An installed project's older findings sit in a baseline that only shrinks: visible debt, nothing red on arrival, nothing new admitted.
- Deleting a delivered artefact is red in every project. Closing it means marking it terminal.
- A project that uses `x-error-codes` must keep the catalog. A project that never names codes in its contracts still has the catalog checked for uniqueness.
- The CRUD shape and the resource are path heuristics. A REST design that is CRUD in spirit but not in shape declares its reason once, per operation; a singleton or a read-only resource declares its omissions once, as one string.
- The batch behaviours are reviewed, not gated: a contract that declares `maxItems` proves nothing about the code.
- The canonical-components rule is reviewed, not gated, until #138 ships.
- `api-standards.md` § Error codes and `contract-first-policy.md` § Completeness and exceptions land in every project, frontend-only included. They govern how a contract is written; a project without a contract tree has the member n/a and no DC-36/37 row. A scope conditional in those bodies would be LLM-materialised and unproven by the synthetic run.
- The CRUD clause reads the root `paths` only: a `$ref`'d path item, `webhooks` and `callbacks` are not judged. The duplicate-code scan reads column-0 block keys; a flow-style catalog keeps YAML's last value.

## Alternatives considered

- **A gate per law (`error-codes`, `crud`).** That means two readers of the same contract tree, and #124 would add a third. Rejected: one contract reader.
- **Extending `freeze` with the new checks.** `freeze` judges change against an approved plan. Catalog uniqueness is a property of the whole tree. Rejected: two concerns in one member.
- **A CRUD clause on the contracts a change touches only.** It builds least and blocks nothing, but an older departure nobody edits stays undeclared forever (#126 «we do not want»). Rejected by the owner (RDR «3»).
- **The whole tree with no baseline.** Every installed API project is red on arrival until each older finding is declared. Rejected (RDR «3»).
- **CRUD single only, batch recognised but not owed.** The downstream law it came from asks completeness without batch. Rejected by the owner: «el crud debe ser doble».
- **A gate on the batch behaviours.** A declared `maxItems` proves nothing about the code. Rejected (RDR «1»): the rule text, read by the security lens.
- **A new member for deletions.** `frontmatter-lock` already reads the approved artefacts at the base. Rejected: a second reader of the same state.
- **Binding the API rows by `applicable_when`.** The scope vocabulary has no `integration`. Rejected: the registry binding covers all three API scopes.
- **A UI gate here.** #138 owns the component-catalog gate. Rejected: «two gates for the same invariant».
- **The money object as a law.** It is a domain choice, and a project without money has no surface for it. Rejected (#126 «we do not want»).

## Operational Rule

No new law. Every law sentence in `CLAUDE.md` is unchanged. The rule bodies that change: `api-standards.md`, `contract-first-policy.md`, `ux-constitution.md`, `immutability_policy.md`, `defect-prevention.md` and its cases annex, and the new guide `monetary-amounts.md`. Each change is a rule-file edit plus a manifest bump.

## Verification record

Verified on 2026-11-06, on `feature/EVOL-072-product-laws`.

- **Red first.** Each clause has a unit case in `scripts/gates/test_gates.py` (classes `Contracts`, `FrontmatterLock`) that fails without its code. Mutants proven red:
  - completeness off;
  - the baseline growth check off;
  - the untracked-baseline check off;
  - the `$ref` skip off;
  - the unreadable-contract exclusion off;
  - the lenient base read swapped for the strict one;
  - the entry validation off;
  - the merge-base read off;
  - the `$ref` bulk skip off.
- **Unit suite:** `python3 scripts/gates/test_gates.py`, OK (2 skipped).
- **Synthetic materialisation**, every fixture with `--answers` plus the plain run, all green:
  - default, dotnet-vue-codepipeline, frontend-only, go, java, rust;
  - upgrade-8.12, where Q4.5 is pending;
  - upgrade-8.12-api, where Q36, the catalog, DC-36..38 and the `contracts baseline (EVOL-072)` migration are owed.
- **Gates:** `gate.py discovery` (V1–V13), `check-lockstep-pairs.sh` (87 files), `manifest-parity`, `budget`, `check-adr-constitution-sync.sh`, `check-applicability-frontmatter.sh`, `gate.py profile --run --control-point static`.
- **Critics:**
  - Rounds 1 and 2 ran with four lenses on the change-scoped design.
  - The owner then changed behaviour: RDR «3», «el crud debe ser doble», RDR «1». So review started again at round 1, on the new bytes, with four lenses.
  - The 🔴 (the upgrade seed had no registry row), the 🟡s and the ❓s were cured.
  - Round 2 read the cure only. Security and governance found nothing.
  - Correctness raised two ❓, both cured with a red-first case:
    - the merge-base read of the base baseline had no test (`test_baseline_reads_the_merge_base`);
    - a `$ref` bulk path was reported missing.
  - Fidelity raised one 🟡: the cure's batch, redaction and money details were missing from this record. They are now aligned in §1, §2, §4 and §7, and the control-point table names the baseline.
  - Mechanical leftovers were accepted by the adjudication default.
