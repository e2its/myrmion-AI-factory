---
id: ADR-EVOL-071
title: "The data and migrations pack: shipped migrations immutable, an ADR tag per destructive step, one connection factory, seeds through the owner"
date: 2026-11-06
status: accepted
---

# ADR-EVOL-071: The data and migrations pack

## Context

This ADR implements issue #125 (epic #112, train row 6d). It was verified on `main` at framework 8.24.0.

A project with a database gets a migration rule (`rules/database.md`) and a validator script (`scripts/validate-migrations.sh`). The pieces do not hold together:

- **The validator does not do what the rule says.**
  - It greps 13 fixed directories for forbidden words. It never reads the `-- ADR: ADR-XXXX` tag the rule defines (`database.md:55-58`), so a sanctioned destructive step fails exactly like an accident.
  - It scans down sections too, so every expand step's down `DROP` fails.
  - Only QA runs it (`Factory-qa-verify:67, :525, :738`). The rule claims CI enforcement (`database.md:29`), but no CI, profile or seal wires it.
- **Nothing protects a shipped migration.** An edit to a migration already applied somewhere goes unseen.
- **Two rules contradict each other.** `database.md:24` mandates a down script per migration, and DEVOPS offers an automatic rollback (`Factory-devops-provision-deploy:446-447`). The down of a `DROP COLUMN` recreates the column empty: an automatic rollback of a destructive step is itself a destructive decision, taken by a machine.
- **The seed pipeline bypasses the owner.** It writes tables directly (`UPSERT … INTO entity.table_or_collection`, `TRUNCATE` on `FORCE_RESEED`; `:523-611`). That contradicts the data family's invariant «every write goes through the owning module» (`defect-prevention.md:28`).
- **One connection factory is no rule.** A downstream instantiation built a ratchet of direct database access outside its base repository. The ratchet grew when its baseline was deleted and re-seeded, until the reference became the baseline's copy at the merge base. That is the issue's «a re-seed never raises a baseline».
- **The migration tool is never asked.** `{{DB_MIGRATION_TOOL}}` (`database.md:20`) has no source; the registry marks it `pending #125`.

## Decision

**Owner's decision on rollback (RDR «1», 2026-11-06):** an automatic rollback never undoes a destructive data step. It undoes code, traffic and the reversible (expand) steps. A destructive (contract) step is fixed forward, or a person decides a restore from backup. The issue's fixed input holds: the agent never decides a destructive infrastructure operation.

1. **One reader: `gate.py data`, a light profile member.**
   - The reader is `scripts/gates/data.py`, lock-step mirrored. It needs no build and no database, so it runs on every push and in CI.
   - It replaces `scripts/validate-migrations.sh`, which retires (one command out, one in). The bash grep cannot compare against the base, read the seed registry or hold a baseline.
   - It is n/a in the framework repo, and in a project whose `docs/setup.md` holds no `database.migrations_tool`. The answer is read in its one home, never copied into config.
2. **Migrations, per adapter.** The tool selects an adapter: a data row naming its file globs, its up/down markers and its destructive and locking calls. SQL text is scanned in every adapter. Only the up part is judged. **Red when:**
   - **(a) A shipped migration changed.** A migration file present at the merge-base differs, or is gone, at HEAD. The base tree is the ledger of shipped migrations; no second ledger file can drift from it.
   - **(b) A destructive step has no tag.** A destructive step of a new migration (drop, rename, retire, truncate, unbounded delete) carries no `ADR: ADR-NNN` tag on its line or in the comment block above it. A tag must name a decision record that exists with `status: accepted`: `FDR: <feature>/FDR-NNNN` — the feature's record that `/blueprint --fdr` writes, the default for a schema change — or `ADR: ADR-NNN` for a project-wide record. This is the existing tag, checked step by step, widened to the framework's two record types (critic round 1).
   - **(c) An index locks a live PostgreSQL table.** A new index on a table that the same migration did not create is built without `CONCURRENTLY` (or its DSL twin). The same tag excuses it.
   - **(d) The ledger is not reconciled.** Two migrations of one directory claim one version (an up/down pair excepted), or two Alembic revisions share a parent (two heads).
   - Each new migration's class — `expand`, or `contract` when it holds a destructive step — is listed in `--json`. DEVOPS reads it there; no agent classifies.
3. **One connection factory.**
   - `config/quality.json → data.connection_factory` names the one module that builds connections. It is `null` until the first increment that builds the backend writes it.
   - A tracked code file outside the test roots, the migrations and the factory that constructs a connection (the driver calls, a data table per runtime) is a finding. A finding while the factory is `null` is red.
   - Older findings sit in `docs/project_log/data_baseline.json`. Like the CRUD baseline, it only shrinks against its merge-base copy, so deleting and re-seeding it cannot grow it.
4. **Seeds through the owner (`seed_registry_v2`).**
   - Each entity names its `owner`: a module function or API operationIds, for create and for delete. The registry names one `seeder`.
   - **Red when:** an entity has no owner; an owner cannot be found; a fixture is not JSON; the seeder or a fixture writes a table directly or opens a connection.
   - **DEVOPS:** the pipeline runs the seeder. A re-seed deletes only the seeded ids, through the owner. `FORCE_RESEED` is the owner's RDR, never the agent's. No `TRUNCATE`.
5. **Rollback.**
   - `database.md`: an expand step carries its down. A contract step carries its ADR tag, declares itself irreversible and ships after the code stops reading the old shape. «Keep last 3 reversible» goes.
   - DEVOPS: automatic rollback = code + traffic + the expand downs of the deployed range. When `gate.py data --base <previous deploy ref> --json` lists a contract migration in that range, nothing automatic touches the data.
6. **Discovery.**
   - New Q15.1 `database.migrations_tool`, asked when the engine is PostgreSQL, MySQL or SQLite and a backend runtime exists. Its options are per runtime, and it fills `{{DB_MIGRATION_TOOL}}`.
   - **A new key-spec field, `decided_by {key, values}`, derives the key when an earlier answer decides it:** Django → «Django migrations». The derived key is never pending, is written beside the answers and is shown in the report (RDR C, #159). #129 adds Laravel the same way.
   - **The pack has one condition, `database.migrations_tool exists`.** It is the manifest condition of `rules/database.md`, the `when` of the derived classes and the gate's n/a.
   - MongoDB, DynamoDB, Redis, and a SQL database with no backend (#149) are stated as not covered in the setup report.
7. **Three universal classes, family `data`, gate `data`.** Each is selected through discovery (Promotion 5):
   - **DC-40:** a shipped migration never changes, and one version names one migration.
   - **DC-41:** every destructive or table-locking step carries its ADR tag.
   - **DC-42:** one connection factory, and seeds through the owner.
8. **The same change aligns every reader.** That covers QA verify, the `database.md` enforcement line, `Factory-implement-plan` C.5 (one task list; «call the owner's create»), `Factory-implement-build` (the factory path), `Factory-blueprint-design` (expand now, contract later), the README gate rows, the light-member lists of `CLAUDE.md` and `rules/branching.md`, `retired_terms` and the upgrade migration row.

## Consequences

- **What is proven on every push.** Shipped migrations are unchanged. Every destructive or locking step names an accepted ADR. One connection factory. Seeds through the owner.
- **What stays judgement.** Whether a contract step is safe to ship (the code no longer reads the old shape) stays with the ADR and the critics. The gate proves that the ADR exists, not that it is right.
- **What an upgrade brings.** An installed project gets the `data` block, a baseline of its existing direct connections, the seed registry's owners and the Q15.1 question. `validate-migrations.sh` and its callers go.
- **The data classes (`reference | environment`)** are #146's. A project in between seeds through the owner with no data class.

## Alternatives considered

- **Auto-rollback runs the down of a contract step.** Rejected (RDR «1»): the data does not come back.
- **Pause and ask at rollback time.** Rejected (RDR «1»): a failed deploy waits, and the pause must be built.
- **A ledger file of shipped migrations with checksums.** Rejected: the merge-base tree already is that ledger. A file would add a write per change and a second thing to reconcile.
- **Extending `validate-migrations.sh`.** Rejected: a bash grep cannot hold base comparisons, the registry and a baseline, and it would remain a second reader beside `gate.py`.
- **One union pattern list for every tool.** Rejected: DSL verbs collide across languages (`remove`, `drop`). The adapter row keeps each tool's verbs to its own files.
- **A class header per migration (`migration-class:`).** Rejected: it would be a second marker vocabulary. The class is derived from the steps.
- **Asking the tool of a Django project.** Rejected (RDR C): the framework decides it.

## Operational Rule

No new law. Every law sentence in `CLAUDE.md` is unchanged. The rule bodies that change are `database.md`, `defect-prevention.md` and its cases annex, and `branching.md`. Each change is a rule-file edit plus a manifest bump.

## Verification record

Recorded on 2026-11-07 on branch `feature/EVOL-071-data-migrations-pack`.

- **Unit tests, red first:** `test_gates.Data` 9/9 and `test_gates.Discovery` 62/62. The full suite runs 271 tests, OK, 2 skipped. Each red of the plan has its case:
  - a shipped migration edited, and one deleted;
  - an untagged DROP, a tag naming no ADR, a tag naming a proposed ADR;
  - a down part that stays green (Flyway, goose, Alembic, Knex, EF Core);
  - a PostgreSQL index that is not concurrent, a duplicate version, two Alembic heads;
  - the connection factory and its baseline (excused, new, stale, unreadable, missing factory);
  - seeds (v1, an entity with no owner, a missing module or function, an unknown operationId, a `.sql` fixture, an INSERT, a connection, a missing seeder, a missing fixture);
  - the Django-derived tool, `decided_by` validation, and a conditional derived class dropped only when its condition fails and no question is pending.
- **Mutants:** each `problems.append` in `data.py` was removed in turn. 20/20 were killed by `test_gates.Data`. Each of the 7 `decided_by` mutants in `discovery.py` was killed.
- **Synthetic materialisation, all 8 fixtures with `--answers`:** 8/8 green.
  - go (golang-migrate), java (Flyway), rust (sqlx-cli) and dotnet (EF Core migrations) land `.claude/rules/database.md` and DC-40..42.
  - default (no database) and frontend-only (PostgreSQL, no backend) land no `database.md`, and Q15.1 is not asked.
  - Both fixtures leave questions pending, so DC-40..42 stay as undecided, by the existing rule. The unit test proves the drop with nothing pending.
  - Both upgrade fixtures owe `data (EVOL-071)`.
- **Gates:** `gate.py discovery`, `manifest-parity`, `retired-terms`, `one-definition` and `agents` pass. So do `check-lockstep-pairs.sh` (88 files), `check-applicability-frontmatter.sh`, `check-adr-constitution-sync.sh`, `validate-governance.sh --base origin/main`, `test-hooks.sh` (202/0) and `test-snapshot-extraction.sh`.
- **Static profile:** `gate.py profile --run --control-point static`. The member `data` reports n/a in the framework repo.

### Critic round 1 cures (2026-11-07)

- **Decision tag:** a step names `FDR: <feature>/FDR-NNNN` (the default, `/blueprint --fdr`) or `ADR: ADR-NNN`. The record must be accepted. The owner ratifies it, never the agent.
- **Real layouts:**
  - Flyway `db/migration` and Liquibase `db/changelog` are covered.
  - Files that change by design (`R__`, the Liquibase master) are exempt from immutability. So are tools with their own ledger (Alembic, Diesel dated folders).
  - A down file is known by its form. The `U` prefix counts only for Flyway.
  - String literals no longer hide or fake comments.
  - The DSL twins of Alembic `batch_op`, Sequel, Doctrine, Phinx and Ecto are covered.
- **Text alignment (LAW-17):** review Check #8, factory-pr-review, QA 0d, the BVL seed gate, the DEVOPS rollback (fail-closed: a fault or `n/a` counts as `contract`), `rules/ci-cd.md` and upgrade step 4.
- **Discovery:** a `decided_by` key derives only where its question is owed.
- **Tests:** `test_gates.Data` 13/13; the full suite runs 275 tests, OK, 2 skipped.
  - The 4 new tests are red on the round-1 head. In the real-layouts test, 16 of 24 cases are red on that head; the other 8 cover adapters that already passed.
  - The seed test found a real fault: an `except OSError as e` shadowed the loop's entity.
- **Mutants:** 24/24 `problems.append` mutants in `data.py` are killed.
- **Checks:**
  - Synthetic: 8/8 fixtures green.
  - Gates `discovery`, `manifest-parity`, `retired-terms`, `one-definition` and `agents`, plus lock-step (88 files), applicability, ADR sync, `test-hooks` (202/0) and the snapshot test: all green.
- **The budget search:**
  - The data pack's globs bring the literal prefixes to 15. `worst_case_path` built every combination of them, and `gate.py budget` ran for more than ten minutes.
  - It now takes one pass per candidate: a prefix stays only when it adds a class, a prefix made redundant later is dropped, and equal scores take the shortest path. It runs in seconds.
  - A test caps `any_glob` calls at 200k over 18 prefixes. It is red with the old search.
  - The new worst-case path adds two rule pointers (`React.md`, `ux-constitution.md`). The DC-40..42 gate columns were shortened, and `pre_edit` measures 5979 of 6000.
