---
id: ADR-EVOL-102
title: "SETUP discovery as data, phase 1 — one question registry, one answer home, one condition grammar and evaluator, the snapshot's stack keys"
date: 2026-10-20
status: accepted
---

# ADR-EVOL-102: SETUP discovery as data — phase 1

## Context

Issue #159 (epic #151, train #112 row 4), verified on `main` at framework 8.12.6. #143, which aligned the literals, has shipped.

- **No grammar or evaluator for conditions.** An LLM reads the 52 manifest `stack_conditional` values (24 distinct, 10 keys), the discovery unlocks (`Factory-setup-discovery` tier lists :54-87) and the 11 `IF setup_md.…` steps of materialisation (:341-627) as free text.
  - Two matchers exist. `scripts/materialize-synthetic.sh:51-71` is meta-only. `validate-governance.sh` CHECK 1c is a collision check.
  - `scripts/test-discovery-literals.sh` was shipped as "the interim guard until the answer registry and its validator (#159) replace it". It parses the instruction's `**Options:**` / `**Persist:**` lines.
- **Answers have no single home.** Only Q21.2 and Q29–Q34 have frontmatter slots in `setup/setup_master_template.md`. Every other answer is prose that materialisation reads as `setup_md.<key>`.
- **The snapshot reads its stack keys from the wrong file.** `scripts/gates/corpus.py:454-470` reads them from the constitution frontmatter, which carries none, so every snapshot prints `(no stack keys …)`. The `STACK_KEYS` names have drifted from the persisted keys (`iac`, `cloud`, `architecture`).
- **Tier lists are copied, and the copies are stale.**
  - `.claude/commands/setup.md:27-31`.
  - `factory-batch-interactivity/SKILL.md:288-325`: Tier 0 has no Q4.5, Tier 1 skips have no Q8.1 and no scope rules, and Tier 2 ends at Q26.
  - The discovery instruction's own tier list cites Q18.1 and Q24a/b/c, which have no section.
- **Some persisted keys have no reader** (`branching.pr_validation_mode`, `observability.*`, …).

## Decision

Owner RDR, 2026-10-20, on how the evaluator is called (CLAUDE.md Generation Standards §4). Four options were posed; the owner's choice, verbatim: **«3 · --resolve + --eval (Recommended)»**. Registry format: JSON, owner RDR «1» (2026-10-09, recorded on #159). The rule for which questions are asked: owner RDR C — «la regla es preguntar todo lo que no es deducible o condicionado por una respuestas anterior».

### 1 · The registry
- **Home.** `.context/templates/setup/setup/discovery_registry.json`. It is a manifest `templates` entry with `target: null` (consumed in place) and `content_type: universal`.
- **Same path everywhere.** `factory-sync.sh` step 7 syncs the full `.context/templates/` tree, so the path is the same in the framework repo and in every project.
- **Questions.** Each entry: `{id, tier: 0|1|2, since: semver, when?: <condition>, keys: {<dotted.key>: <spec>}}`.
  - `since` is the framework version that introduced the question. It is computed from git history (the first commit carrying the question's heading in the discovery instruction, read against that commit's `framework_version`). Phase 2's upgrade reads it. A dependant that adds an entry before phase 2 sets it at birth.
- **Key spec.** Exactly one of:
  - `options` — the closed literals;
  - `options_by` — `{key, values: {<parent literal>: [...]}}`, for a value list that depends on another answer, such as Q6 by `backend.runtime`;
  - `free` — one of `text | number | list | path | command | vault_name`.

  A spec may add `record_only: "<reason>"`. A `free: text` spec may add `suggestions`, the literals the question offers and the only ones a condition may compare it to (Q27's tracker names).
- **Derived values.** A top-level `derived: {<key>: {from: "<how>"}}` holds values that earlier answers decide, such as `verification.gates` and `traceability.home`. They are never asked and are listed in the setup report.
- **Left out of phase 1, each with its first consumer:**
  - `recommend` and `catalog` arrive with #144.
  - `fills` (the placeholders a key fills) arrives with the phase-2 placeholder baseline.

### 2 · One grammar, one evaluator
- **The module.** `scripts/gates/discovery.py`, plus its template twin, which the `scripts/gates/*.py` lock-step glob already covers.
- **The grammar is closed:**
  ```
  condition := conj (" OR " conj)*                    # AND binds tighter; no parentheses (none needed today)
  conj      := clause (" AND " clause)*
  clause    := KEY " exists" | KEY ("=="|"!=") VALUE | KEY (" IN "|" NOT IN ") "[" VALUE ("," VALUE)* "]"
  VALUE     := "…" | null | true | false | number | bare-token
  ```
- **Answers.** The answers are `docs/setup.md` frontmatter, flattened to dotted keys.
  - A missing key reads as `null`: not yet asked, or skipped by its question's `when`.
  - `!=` and `NOT IN` hold only for a key that holds an answer. A null key never "differs" (a backend-only project never satisfies `frontend.framework != None`); test it with `== null`.
  - `exists` holds when the key, or a key under it, has a value other than `null`, `"None"`, `""` or an empty list.
  - A list answer may only be tested with `exists`.
- **CLI:**
  - `python3 scripts/gate.py discovery` validates (§4).
  - `python3 scripts/gate.py discovery --resolve [--answers FILE] [--json]` prints, for one answer set:
    - the **pending questions** in tier order: their `when` holds and a key is unanswered;
    - the manifest **template entries that land and those skipped**.

    `FILE` is the fixture shape `{"answers": {<dotted key>: value}}`. The default is the frontmatter.
  - `python3 scripts/gate.py discovery --eval '<condition>' [--answers FILE]` evaluates one condition. Exit 0 = holds, 1 = does not hold, 2 = a fault (unparseable, unknown key, a literal outside the options, an absent or unreadable answer home, `--answers` or `--json` without a mode). `--resolve` holds every `when` and `stack_conditional` to the registry the same way, and faults instead of skipping.
- **Consumers in phase 1:**
  - the discovery instruction's unlocks, through `--resolve`;
  - materialisation's template selection (`:995`), through `--resolve`;
  - materialisation's 11 conditional steps, through `--eval`, rewritten in the grammar without the `setup_md.` prefix;
  - the synthetic materialiser, through `--resolve`, replacing its inline matcher.

### 3 · One answer home
- `docs/setup.md` frontmatter holds every answer under its key, nested YAML. The template carries one `null` slot per registry key and per derived key.
- Body sections keep rationale and derived values, never an answer value.
- Discovery writes each tier's answers to the frontmatter (IPP section-atomic).
- **The snapshot.** It reads `docs/setup.md` frontmatter. `STACK_KEYS` becomes a short tuple of flat dotted keys: `project_mode`, `project_scope`, `backend.runtime`, `backend.framework`, `backend.topology`, `frontend.framework`, `frontend.meta_framework`, `frontend.pattern`, `database.primary.engine`, `hosting.provider`, `hosting.iac_tool`, `ci_cd.platform`. Each must be a registry key.
- **In the framework repo** there is no `docs/setup.md`, so the snapshot prints `# (no stack keys in docs/setup.md frontmatter)`.

### 4 · The validator
`gate.py discovery` is a light, framework-repo-only member of the profile. Every rule below is red-proved in `scripts/gates/test_gates.py`.
- **V1 · Schema.**
  - Ids and keys are unique.
  - The tier and the free kind come from their closed lists.
  - `since` is at or below `framework_version`.
  - Every `options_by` parent literal is one of the parent's options.
- **V2 · A single admissible option** with no derivation is red. That value is derived (RDR C).
- **V3 · An answer able to carry a secret is red.** That is a key whose name has a credential token (`password`, `passwd`, `secret`, `token`, `credential(s)`, `apikey`/`api_key`, `private_key`) and whose spec is not `free: vault_name`.
- **V4 · A persisted key with no consumer and no `record_only` reason is red.**
  - A consumer is a tracked file under the consumer roots that names the key literally. The roots are `scripts/**`, `.claude/{instructions,skills,commands,hooks}/**`, `.context/templates/**`, `.github/workflows/**` and `config/**`.
  - These never count: the discovery instruction, the registry, the setup template and the manifest's changelogs.
- **V5 · Conditions.** Every registry `when`, every manifest `stack_conditional` and every materialisation `--eval` condition must parse. Each key must be a registry or derived key (a prefix only with `exists`). Each literal must be one of that key's options (a free-text key: its `suggestions`), or `null`. A condition naming a key or literal absent from the registry is red.
- **V6 · Parity with the discovery instruction.** In both directions, every question id matches a `#### Q<id>` heading, every `**Options:**` line matches the registry's options, and every `**Persist:**` line matches its keys.
- **V7 · Parity with the template frontmatter.** Every registry and derived key has a slot. Every answer slot is a registry key; the declared non-answer slots are `version`, `date`, `changelog`, `phase`, `status`, `retry_count` and `last_update`.
- **V8 · The consumer-literal checks of `test-discovery-literals.sh`**, read from the registry instead of the instruction's prose. They cover verification-loop rows, DEVOPS enums and labels, the infrastructure-registry schema, the shipped scripts and the dependency readers. The script and its manifest entry are retired, and `governance-check.yml` runs the gate instead.
- **V9 · Snapshot keys.** Every `STACK_KEYS` entry is a registry key.

### 5 · Copies become pointers
- **The tier lists.** The discovery instruction's tier block (:54-87), `setup.md:27-31` and the BIP skill's tier lists become one pointer each to the registry and to `--resolve`. The question wording and the `**Options:**` / `**Persist:**` lines stay, held by V6.
- **Undefined questions.** Q18.1 and Q24a/b/c are cited only in the replaced tier list, so the citations go. Their consumers, if any, belong to phase 2's placeholder baseline.

### 6 · The fixture runner
- `scripts/materialize-synthetic.sh` selects through `--resolve --answers FIXTURE`.
- It writes the fixture's answers into the landed `docs/setup.md` frontmatter.
- It asserts that `gate.py snapshot-sections` in the synthetic tree prints every answered `STACK_KEYS` entry.
- Both fixtures (`default`, `dotnet-vue-codepipeline`) land the same tree as before this change, with their `expect` lists unchanged.

## Consequences
- **What lands in projects.**
  - `factory-sync.sh` ships the registry, the evaluator and the instructions.
  - A new `SETUP --generate` asks in registry order, writes every answer to the frontmatter and selects templates and steps deterministically.
- **Intermediate state after phase 1.**
  - Placeholders and `SETUP --upgrade` are unchanged. `Factory-setup-upgrade:124` still reads `stack_conditional` as prose, because a project materialised before this change has no frontmatter answers for `--resolve` to read.
  - Phase 2 back-fills the keys, then moves the upgrade to `--resolve`. Until then, an installed project's snapshot shows only `project_mode` and `project_scope`, an improvement on today's none.
- **Retired script.** `scripts/test-discovery-literals.sh` (manifest `delivery: sync`) leaves the framework. `factory-sync.sh`'s orphan detection names a project's stale copy, and the gate replaces it.
- **Framework version.** MINOR bump, 8.12.6 → 8.13.0. A manifest entry for each new file; every touched entry is bumped.
- **Risks.**
  - A consumer search that is too loose, where a mention counts as a read. The roots exclude documentation, and a `record_only` reason is reviewed.
  - A `since` computed from history that predates a question's real introduction. It errs toward older, so phase 2 asks less, never more. A key the project lacks is still asked through the pending list.

## Alternatives considered
- **Evaluator calls.** RDR above.
  - Option 1, `--eval` plus `--select`: about 20 unlock calls per SETUP, and phase 2 would need its own flag.
  - Option 2, `--select`, `--pending` and `--eval`: one more flag.
  - Option 4, a module only: conditions stay LLM-read.
- **Declared `consumers` per key**, rejected. It is more data, and it drifts unless re-verified. The repository search with a `record_only` override builds less.
- **A registry-driven snapshot flag (`snapshot: true` per question)**, rejected. Which answers the snapshot shows is a presentation choice of the reader, not question data. V9 holds the tuple to the registry.
- **Moving `--upgrade` in phase 1**, rejected. Without back-fill it would skip every stack template of an installed project.

## Operational Rule
- A question, an option or a condition is added in the registry. The discovery instruction carries its wording and its `**Options:**` / `**Persist:**` lines.
- `gate.py discovery` holds the two together, along with every condition in the manifest and in materialisation.
- No agent evaluates a condition by reading it. It asks `gate.py discovery --resolve` or `--eval`.

## Verification record

Delivered 2026-10-20 on `feature/EVOL-102-discovery-as-data`, framework 8.12.6 → 8.13.0.

- **Registry.** 55 questions (tier 0: 8, tier 1: 11, tier 2: 36), 89 persisted keys and 9 derived keys. `since` comes from git history; a question older than the framework's version reset reads `1.0.0`.
- **Record-only keys (15).** Each carries its reason in the registry. Most wait for phase 2's placeholder baseline, which is where their readers will live: `compliance.frameworks`, `database.cache.engine`, `database.secondary.engine`, `extension.coexistence_months`, `extension.protected_paths`, `frontend.external_design_system.resolved_fields`, `frontend.state_management`, `hosting.secrets_manager`, `observability.error_tracking`, `observability.logging`, `observability.monitoring`, `observability.tracing`, `quality.security_scan.fail_on`, `quality.security_scan.report_format`, `testing.strategy`.
- **Validator.** `python3 scripts/gate.py discovery` is green on the repository. Each rule V1–V9 and each DoD red is proved red in `scripts/gates/test_gates.py` (class `Discovery`).
- **Snapshot.** `Cli.test_cli_exit_codes` now reads `runtime: Go` from the fixture's `docs/setup.md`, while the constitution says `Python`, and leaves out a null key. Both fixtures' synthetic snapshots show every answered stack key.
- **Same tree.** Before and after this change, `default.json` lands 166 targets and skips 29, a 164-file tree. `dotnet-vue-codepipeline.json` lands 164 and skips 31, a 162-file tree. The file lists diff empty.
- **Two changes beyond the ADR, found while delivering it:**
  - A question counts as asked once any of its keys holds an answer; null means not yet asked. Otherwise a sibling left null on purpose (Q14's path, Q29.1's directory, Q23.1 on Skip) would keep its question pending forever.
  - The template's slots that held option lists or defaults (`project_mode`, `project_scope`, Q21.2, Q29–Q34) are `null`. A value there would read as an answer and the question would never be asked. The recommendations stay in the discovery instruction (RDR C: a default is a recommendation, never a reason to skip).

## Phase 2 — every placeholder has a source; the upgrade asks what a project lacks

Delivered with train row 5b (epic #112, plan ADR-EVOL-067), 2026-10-21, framework 8.16.0 → 8.17.0. Phase 3 (`--reconfigure`, the MCP target) ships with its first consumers.

### Decision

1. **Placeholder sources live in the registry.**
   - A key spec may carry `fills: [TOKEN…]`, and so may a `derived` entry.
   - `constants` holds framework values and runtime tokens (`RANGE` is filled by a script at run time).
   - `placeholder_baseline` holds the rest, each entry either `pending #NNN` (#147, #125, #145) or `unsourced`.
   - **V10:** every UPPER_SNAKE token in a template that lands has exactly one source. The baseline only shrinks: an entry now sourced is red, and an entry naming no token is red. This is the traceability baseline's pattern.
   - V4 counts a key's `fills` as a reader, because the template that carries the token reads the answer.
2. **Upgrade clauses become `migrations` rows**, each `{id, since, detect, apply}`.
   - `detect` is a project file plus a JSON pointer, where a markdown file is read as its frontmatter, or `always`.
   - `apply` is an anchor in the upgrade instruction.
   - **V11** checks every row and every anchor.
   - The 11 Step 8 clauses and the iterations-array migration are rows.
3. **`--resolve` reports the upgrade.**
   - It adds `pending_since` and `placeholders` for the answer set.
   - Against a project, it also reports `project_version`, `migrations_owed` (project version below `since` and the pointer missing, or `always`), `templates_to_add` and `templates_to_remove`.
   - An answer outside its options is a fault, exit 2.
4. **One generic upgrade step (8b):**
   1. back-fill each pending key from the recorded `docs/setup.md` body when the mapping is unambiguous, otherwise an RDR;
   2. ask the rest of `pending`, in tier order;
   3. run the migrations owed;
   4. offer template additions, and offer removals by RDR only.
5. **§0.2 default slicing is removed** from the setup template: no question asked it and no reader used it.

### Verification record

- **Registry:**
  - 54 keys fill 95 tokens;
  - 6 new derived keys carry slots in the template;
  - 58 constants;
  - a baseline of 178 tokens (13 pending, 165 unsourced);
  - 12 migrations.
- **Red first:** `Discovery` covers V10 (an unsourced token, a token with two sources, a stale entry), V11, `migrations_owed`, template additions and removals, an answer outside its options, and `fills` as a reader. All are red before and green after (56 tests).
- **The upgrade fixture.** `scripts/fixtures/synthetic-answers/upgrade-8.12.json` is a project at 8.12.0 with answers missing. `--resolve` lists exactly its 31 pending questions and exactly the migrations its `expect.migrations` names (the `always` rows of EVOL-067 included); the owed path is proved by the unit test. CI runs it beside the default and dotnet fixtures.
- **One check, not two.** `test-materialization-surface.sh` check 3 delegates to V10.
