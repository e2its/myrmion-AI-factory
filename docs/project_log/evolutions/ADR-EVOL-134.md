---
id: ADR-EVOL-134
title: "Ids that collide only red and counters that never hand-merge — scope-qualified ADR ids, duplicate ordinals red before merge, version counters re-derived against main"
date: 2026-11-20
status: accepted
---

# ADR-EVOL-134: Scope-qualified ids and re-derived counters

## Context

This ADR plans issue #242 (epic #112, wave 5, destination S). It is follow-up B of spike #139 (ADR-EVOL-085). It was checked on `origin/main` at framework 10.11.0 (71b0611).

- **Record ids are minted sequentially.** The ADR skill mints `N = max+1` per scope (`factory-adr-management` § Propose, step 1) and retries once on a collision it can see. Two branches cannot see each other: each mints `ADR-0031`, the two files have different slugs, git merges both, and the project ships one id twice. The same holds for `PLAW-{max+1}` at accept and for `FEAT-NNN` on the `none` tracker.
- **Readers pin the numeric shape.** `scripts/gates/freeze.py:51` reads `ADR-\d+` only. `check-adr-constitution-sync.sh` derives an ADR's id from the filename `ADR-(EVOL-)?N` or the frontmatter `id`, and the project template writes `adr_number`, not `id`.
- **Duplicates are not red where they live.**
  - `corpus.parse_law_index` reads a `PLAW-NN` declared twice without a word. `law-parity` is red only incidentally (a second body home).
  - A `PDC-NN` declared twice is already red: `corpus.catalog` refuses it.
  - The `none` board (`docs/backlog/state.md`) is read by `tracker.from_state`, which checks no duplicate `Local ID` and no feature phase declared twice. No profile member reads the board. `gate.py tracker` with no action is a fault.
- **Counters are not re-derived.**
  - `gate.py manifest --bump` is idempotent against the base. Nothing checks, outside the framework repo, that a changed governed file's entry advanced against main. In the framework repo `validate-governance.sh` CHECK 1b checks the entries, and CHECK 4 compares only the major digit of `framework_version`.
  - `contracts.py` compares no `info.version` against the base. A contract both branches bumped to the same number merges with that number kept.
  - ADR-EVOL-085's field rule is «the second to land absorbs». No artefact writes it down.

## Decision

1. **ADR ids are qualified by their owning scope.**
   - On a branch that names a feature (`gate.py branch-class` gives `feature_id`), the skill mints `ADR-{FEAT}-{N}`: `FEAT` is the branch's feature id, which is the tracker key when a tracker exists, and `N` counts that feature's ADRs. `adr_number` is `{FEAT}-{N}`. Only that feature's own branches can mint that id; two of them in parallel (sibling increments) still collide, and the collision is red at the push (item 2).
   - Any other branch (fix, chore, docs) keeps the next sequential number. A duplicate is red at the push (item 2).
   - `PLAW-NN` keeps its sequential mint; a duplicate is red (item 2), and the second to land renumbers its own law.
   - Every reader accepts both shapes. `freeze.ADR_ID` widens to `ADR-({FEATURE_ID}-)?N`, reusing `branch.FEATURE_ID`. The ADR-sync script names a record by `ADR-{adr_number}` as well as by its filename and its `id`. No shipped id is renamed.
2. **A duplicate ordinal is red before merge, in the one reader that already reads it.**
   - `PLAW-NN` or `LAW-NN` declared twice in the index: red in `corpus.parity` (the `law-parity` member).
   - An ADR id declared by two files: red in `check-adr-constitution-sync.sh` (the `adr-sync` member), when the diff adds one of the two files. A duplicate shipped before this gate stays as shipped: a shipped id is never renamed. Its id is the frontmatter `id`, else `ADR-{adr_number}`, else the filename.
   - `PDC-NN` declared twice: already red in `corpus.catalog` (the `budget` member). A test pins it.
   - `FEAT-NNN` on the `none` tracker: **owner RDR «1» (2026-11-20).** `gate.py tracker` called with no action reads the board and is red on a `Local ID` declared twice, or on one lifecycle item (`start`'s and `move`'s identity: `phase_ident` per phase and preset) matched by two rows. With the `github` or `jira` adapter it is `n/a`: the tracker mints the keys. With no tracker key, or no local board yet, it is `n/a`. A new profile member `board` runs it. It needs no build, no database and no network. Rejected: the check only inside `from_state` (red only when someone next moves a card, so a duplicate can reach main); a scope cut to #156 (the issue asks for «before merge»).
3. **The second branch to land re-derives every version counter.**
   - **The written rule** (`rules/branching.md` § Merge Strategy): after its rebase on main, the second branch re-runs each counter's tool. That is `gate.py manifest --bump` for each moved entry, which is idempotent against the new base, and a contract `info.version` above main's. A version is never merged by hand.
   - **Governance manifest:** `gate.py manifest --check` with no `--entry` derives the entries from the change: each manifest-tracked file the change touches, as the tree on disk against the merge-base (the seal's tree delta, which needs no `verification` key). Each entry must stand above the base. A project's own data (`content_type: project_data`, reached by its target: the board, the constitution, the backlog config) is no counter: its entry versions the delivered template, and `SETUP --upgrade` never modifies the project's values. A `stack_configured` file the project edits (its rules, `config/quality.json`, `docs/setup.md`) still owes its counter: the project CLAUDE.md §2 already asks for it and `manifest-parity` reads its frontmatter. In the framework repo a target only names where a template lands, so a target hit there is no counter of the repo's own file (the meta `.gitignore`). In the framework repo, where the manifest carries `framework_core`, `framework_version` must also stand above the base when any entry moved. A new profile member `versions` runs `gate.py manifest --check --base {base}`. A file no entry tracks is skipped; a deleted file is skipped.
   - **Contract semver:** the `contracts` member gains a `versions` row. A contract changed since the merge-base whose base copy carries `info.version` must carry a different one. When both are dotted numbers (at most ten parts of at most nine digits), the new one must be greater. A contract new since the base has no counter to re-derive.
   - Neither is a new command or a new flag: `--check` and `tracker` keep their flags, and only their empty case gains a meaning. RDR «1» ratified the `tracker` read mode under CLAUDE.md §4.

The skill (`factory-adr-management`), the ADR template, `rules/branching.md` and the control-point table in `CLAUDE.md` state the same rules. `CLAUDE.md` names this record there.

## Consequences

- Two feature branches can each write ADRs without coordinating. A fix branch that mints a sequential id still collides, but the collision is red at its push and never reaches main.
- A project that edited a governed file without bumping its entry is now red at the push. The project CLAUDE.md §2 already asks for the bump; the gate makes it mechanical.
- Every contract change needs an `info.version` change, and the registry row follows (`contracts` registry clause).
- In the framework repo, `versions` and `governance` CHECK 1b both check entries against the base. CHECK 1b stays: it also guards the manifest's own integrity.
- A reservation mechanism is not built. If one is ever needed, it is #156's channel.

## Verification

- `scripts/gates/test_gates.py` gains cases, each red first:
  - `freeze` reads `ADR-FEAT-009-1` as a record.
  - Two `PLAW-03` entries in a constitution make `parity` red.
  - A duplicate `PDC` in the catalog is red (pinned).
  - `tracker.check` is red on a duplicate `Local ID` and on two `CODESIGN` rows for one feature. It is `n/a` on github and with no tracker key.
  - `manifest.check` with no entry is red on a changed file whose entry was hand-merged to the base's number. It is red on `framework_version` not above the base when an entry moved (meta). It is green after a re-run bump.
  - `contracts` is red on a changed contract kept at the base's `info.version`, and green when it is above; a huge version only has to change.
  - `branch-class` names the feature id of a plain feature or epic branch; a fix branch names none.
  - `manifest.check` owes no counter for a project's `project_data` file nor for a framework-repo target hit, and owes one for a governed file at a target.
- `scripts/test-check-adr-constitution-sync.sh` gains:
  - two files declaring `ADR-0031`, red;
  - two branch-born `ADR-FEAT-001-1` and `ADR-FEAT-002-1`, green;
  - a qualified accepted ADR named by `adr_number`, not orphaned;
  - a duplicate whose file name git would quote (an accented slug), red;
  - two sibling branches of one feature minting one qualified id, red;
  - a duplicate shipped before the gate with one file edited, green;
  - an accented ADR accepted with no constitution diff, red;
  - a record deleted and a near-copy added under a taken id, red.
- The synthetic materialisation (`--answers`), on the materialised tree:
  - two branches that mint the same `FEAT-NNN` on the `none` board are red after the second merge;
  - two ADRs born on two features never collide;
  - a manifest entry bumped on two branches and hand-merged is red, and green after `manifest --bump` re-derives it.
- A mutation sweep in scratch copies must kill each of these mutants:
  - the qualifier dropped from `ADR_ID`;
  - no duplicate check in `parity`;
  - `adr_number` not read;
  - the board check skipping `Local ID`;
  - the derived entries empty;
  - the framework clause off;
  - the contract version compared as equal-only;
  - and, for the round-1 cure: project data owing a counter, a meta target hit owing one, the index read quoted, every edited record judged, `adr_number` unread in `adr_id`, a plain feature branch naming no id, the dotted version unbounded.
