---
id: ADR-EVOL-070
title: "Contract parity: code, contract and test plan agree, proven by a gate"
date: 2026-11-06
status: accepted
---

# ADR-EVOL-070: Contract parity

## Context

This ADR implements issue #124 (epic #112, train row 6c). It was verified on `main` at framework 8.23.0.

Nothing mechanical proves that the code, the contract and the test plan agree. Each of the following is checked today by reading, if at all:

- **The code against its contract:** the routes, the DTO shapes and constraints, the route security, the statuses a handler raises, and the error codes it emits.
- **The registry against the contract:** `contracts/feature_map.md` has no version column. A downstream project found its registry rows pinned to versions the contracts had long left.
- **Contract tests:** «one contract test per operation before the build» appears nowhere.
- **The journey:** «every journey step covered by an operation» has no home. The test plan has no journey → operation table, and the journey must stay free of operations (LAW-16).

The hand-offs are already in the repo:

- `scripts/gates/contracts.py` («the contract parity reader (#124) extends this module»);
- `scripts/gates/freeze.py:15` («raised ⊆ declared … its parity clause, #124»);
- the freeze checklist of `Factory-blueprint-design` and `factory-plan-critic` («checklist only, until the contract parity reader lands»).

External facts (docs reader, 2026-11-06):

- **Code-derived emitters.** These frameworks emit an OpenAPI document from code:
  - FastAPI (`app.openapi()`), DRF with drf-spectacular, NestJS, Fastify;
  - springdoc, Quarkus, Micronaut;
  - ASP.NET Core (`Microsoft.Extensions.ApiDescription.Server`) and Swashbuckle;
  - flask-smorest, utoipa, huma.
- **Not code-derived.** Starlette (docstrings), Express with swagger-jsdoc (comments) and swag (comments, Swagger 2.0) emit nothing derived from code. Nothing was found for Hapi and Koa.
- **Raised errors.** No emitter infers the errors a handler raises: they appear only where they are annotated.
- **oasdiff.** `oasdiff diff a b --fail-on-diff --exclude-elements …` compares two local files. It is the tool the pr-review contract diff already runs.

## Decision

**Owner's decision (RDR «1», 2026-11-06):** generate the contract where the framework can, and observe the answers in the contract tests. No per-language code readers.

1. **Emitted ↔ authored: the loop member `contract-parity`.**
   - **Who gets it:** Q4.5 full-stack, backend-only and integration `configures` `verification.gates.contract-parity` (`python3 scripts/gate.py contracts --parity`).
   - **Why a flag on the one reader:** the parity needs a build and a tool, which the light profile never runs. So `--parity` is a loop member, and plain `contracts` stays a light member. One reader, two control points; no new command.
   - **The emit command:** `config/quality.json → contracts.emit` is a shell command that writes the emitted documents under `{out}`, mirroring `contracts/openapi/`.
     - SETUP writes `null`. The first increment that builds the backend writes the command, from the emitter table in `contract-first-policy.md` § Contract parity.
     - While the key is `null`, the member is red.
     - A framework with no code-derived emitter carries a dated skip (`verification.skips`, EVOL-067), which expires. The rule names the emitter library to adopt.
   - **The comparison:** each authored contract is compared with its emitted twin by `oasdiff diff --fail-on-diff`. Documentation elements and extensions are excluded.
     - The comparison covers the operations, the shapes and their constraints, `security`, the declared responses and `info.version`.
     - Both copies are normalised first: `servers` and `tags` are dropped, and the `openapi` line is set to the authored one. An emitter fills these on its own, and they promise nothing about behaviour.
     - A `$ref` must be local to its document (`#/…`). A contract split across files is out of this change.
     - A missing twin is red on either side.
     - Without oasdiff the member is red: parity never passes unproven.
2. **Observed answers: the same member.**
   - **Running the contract tests:** `--parity` runs them itself, with `CONTRACT_OBSERVED` naming a fresh directory.
     - The test files under `contracts.tests_root` (default `tests/api`, the TC-API home) are routed to their loop rows by the seal's own dispatch (`seal.scoped`, by `red_reads`). No second router.
     - No file routed to a row with `scoped` is red: parity never passes on tests it did not run.
     - A run is bounded by `contracts.timeout_s` (default 1800 s); a run over it is killed with its process group and is red.
   - **The record:** each response appends one JSON line, `{operation, status, code}`. The helper is a few lines per runtime in `develop/api_test_template.md`.
   - **Red when:**
     - an operation is unknown, or is answered by an operation the contract leaves unnamed;
     - an operationId names two operations of one document, or an operation has none;
     - a status is not declared on that operation (a range such as `4XX`, `default` and a local `$ref` response count as declared);
     - a code is outside the catalog, or outside the operation's `x-error-codes`;
     - an operation is never observed;
     - nothing was recorded;
     - a run failed or timed out.
3. **Three light clauses in `contracts.check`** (profile member `contracts`, no build):
   - **Registry version, whole tree.** Each ACTIVE row of `contracts/feature_map.md` states a `Version` equal to its contract's `info.version`. A registry without the column is red.
   - **One contract test per operation, change-scoped.** Every operation added since the merge-base is named in the `Operation` cell of a TC-API row of some `docs/spec/*/test_plan.md`.
     - `traceability` proves each case has its test, and the seal's `red` member proves that test red at the base.
     - Operations older than the base have passed a build, so no baseline is needed.
   - **Journey coverage, change-scoped.** A changed `test_plan.md` whose feature has a `user_journey.md` carries `### Journey coverage` (`| Paso | Operation |`).
     - Every `Paso N` has a row.
     - Each cell names an `operationId` of the tree, or `none — <reason>`.
     - The journey stays free of operations: `check-journey-grammar.sh` is unchanged.
4. **DC-39 `boundary`, universal (numbered by the framework).** «Request validation mirrors the contract: a constraint the contract declares and the handler omits, or the reverse, is a finding.» Its gate is the loop member `contract-parity`. The case goes in the annex, from a downstream instantiation.
   - Q4.5 binds it to the API scopes, like DC-36 and DC-37 (§ Promotion 5): the class lands exactly where its gate runs. A frontend-only project gets neither.
5. **Templates and rules.**
   - `contract-first-policy.md`: the registry table gains `Version`, and a new § Contract parity is added.
   - `qa/test_plan_template.md`: TC-API gains `Operation`, and a new `### Journey coverage` is added.
   - `develop/api_test_template.md`: the recorder.
   - The `config/quality.json` template: `contracts.emit`, `contracts.tests_root` and `contracts.timeout_s`.
   - The discovery registry: the Q4.5 row, plus two migration rows:
     - `contracts.emit`;
     - the registry `Version` column, filled from each `info.version` at `SETUP --upgrade`.
6. **The same change aligns every reader.** That covers the blueprint freeze checklist, the plan critic, CONTRACT-FREEZE in `Factory-implement-plan`, `Factory-implement-build` (the emit command and the recorder), the `freeze.py` and `contracts.py` docstrings, the README gate rows, and the control-point rows of `CLAUDE.md` and `rules/branching.md`.
7. **Meta CI proof.** A new job, `contract-parity`, installs oasdiff 1.15.2 (the release binary, checked by sha256) and runs `scripts/test-contract-parity.sh`. Each rule is red on its own mismatch, and everything agreeing is green.

## Consequences

- **What is proven.** In an API project, the shapes, constraints, security and declared responses of the code are proven equal to the contract on every full loop.
- **What is observed.** A status or an error code that the contract tests observe and the contract does not promise is red.
- **What stays unproven.** An error that no test provokes is not proven. The one-test-per-operation clause and the per-status TC-API rows bound this.
- **The cost to the project.** A project must declare an emit command, or carry a dated skip that expires. A framework with no code-derived emitter needs a library adopted.
- **Code-first contract details.** Code-side operationIds and the declared responses must match the contract, because the diff reports them. The rule says so.
- **What arrives at upgrade.** An installed project gets the registry `Version` column filled, `contracts.emit: null` and the loop member. Its next full loop is red until it declares the emit command.

## Alternatives considered

- **Observing everything in the tests, with no emitted diff.** One mechanism builds less, but it drops the issue's «step 1». The DTO and security parity would also depend on coverage. Rejected (RDR «1»).
- **Per-language static readers of raised errors.** This is the «matrix of adapters up front» the issue rejects. Rejected (RDR «1»).
- **A second diff tool, or a new wrapper script.** The issue rejects a second tool. Rejected: the gate calls the same `oasdiff` in its file form.
- **A new gate reader.** Rejected: `contracts.py` is the one contract reader.
- **Whole-tree test-per-operation and journey clauses with a baseline.** An operation older than the base already passed a build, and an untouched plan predates the law. Rejected: change-scoped clauses need no baseline.
- **Emit commands per framework in the registry.** The app's entry point is project-specific, so a registry command would carry an unresolved placeholder. Rejected: the agent writes the command at the first backend increment, from the rule's table.

## Operational Rule

No new law. Every law sentence in `CLAUDE.md` is unchanged. The rule bodies that change are `contract-first-policy.md`, `defect-prevention.md` and its cases annex. Each change is a rule-file edit plus a manifest bump.

## Verification record

Verified on branch `feature/EVOL-070-contract-parity`, 2026-11-06.

- **Unit cases, red first.** `ContractPlans` covers the three light clauses, and `ContractParity` covers the loop member. Each case was seen red before its code landed.
  - The registry: the Version column; a version that differs; a SUPERSEDED row; a fenced row; a missing file; a GraphQL row (a file only, missing → red); a non-string `info.version`.
  - Test per operation: a new operation with no TC-API row; a new unnamed operation; a UX row that does not count.
  - Journey coverage: a missing section; a missing step; an unknown operation; `none` without a reason; `Paso 01` on either side; a table under the next heading.
  - Parity: green; documentation, `servers`, `tags` and the `openapi` line are no parity; responses as written (`4XX`, `default`, `$ref`); duplicate and missing operationIds; the timeout (the stub leaves a grandchild holding the pipe; the whole tree stops in under 6 s, so killing only the shell would fail it); a bad `timeout_s`; a linked state folder; a file in the way; an emitted twin that differs, is missing or is extra; a `$ref` to another file (refused, never followed); each observation rule; `tests_root` absolute or with `..`; a helper with no test.
- **Mutants.** 42 mutants of `contracts.py`, one per branch above, run by a throwaway script against these classes (not committed; CI proves the cases, not the mutants). All 42 are killed.
  - Four survived the first run: the GraphQL missing file, an unnamed operation answered, `killpg` removed, and the journey's `Paso 01`. Each got its case.
  - Round 2 added six: `killpg` replaced by killing the shell alone (the grandchild case kills it), the YAML date, the self-referring anchor, the file at the state folder, the blank root, and the tags of `head` / `options` / `trace`.
- **The proof script.** `scripts/test-contract-parity.sh` passes on oasdiff 1.15.2. It never skips, and it is never vacuous. The CI job `contract-parity` runs it on the release binary, checked by sha256.
- **Full suite.** `test_gates.py`: 259 tests OK (2 skips, unrelated).
- **Synthetic materialisation, every fixture with `--answers`.**
  - default, dotnet-vue-codepipeline, go, java and rust carry the `contract-parity` member and DC-39.
  - frontend-only carries neither.
  - upgrade-8.12-api owes both migrations, DC-39 and the added `contract-parity` row.
  - upgrade-8.12 owes the migrations and no member.
  - 8/8 green.
- **Gates.** Lock-step (87 files), manifest parity, discovery, budget (one advisory WARN on the project CLAUDE.md, unchanged here), `validate-governance --base origin/main`, ADR sync and the static profile are all green.
- **Not run locally.** `test-sast-packs.sh` needs semgrep, which this machine lacks. CI proves it.
- **Deviations from the plan.**
  - `contracts.tests_root` defaults to `tests/api`, the TC-API home, not `tests/contract`: one home for the API tests.
  - The tests run through the seal's dispatch (`seal.scoped`), not through the `tests` row's `scoped` alone.
  - `servers`, `tags` and the `openapi` line are normalised. A raw diff reports differences an emitter makes on its own.
  - `contracts.timeout_s` bounds each run.
  - DC-39 lands by the Q4.5 scope, not in every project: it lands where its gate runs.
- **Round-1 critics (four lenses).** Their findings were cured in this change:
  - the `nosemgrep` reason on the declared command;
  - `{paths}` as files, not a folder;
  - the install line;
  - one test home;
  - the materialisation prose;
  - the GraphQL row;
  - `$ref` codes;
  - duplicate operationIds;
  - the Java and C# recorders;
  - the upgrade proof of the loop row;
  - this record.
- **Round-2 critics (the cure only, four lenses).** No 🔴. Their 🟡 and ❓ were cured in this change:
  - the shipped `_doc_parity` text named the old `tests.scoped` route;
  - the timeout case could not tell a whole-tree kill from killing the shell: the stub now leaves a grandchild;
  - a YAML date in a contract crashed the comparison copy: dates compare as text, and a self-referring anchor is a named red.
  - Mechanical informational cures: a file at the state folder is a named fault; a blank `tests_root` is refused; a killed group already gone is no crash, and the read after the kill is bounded; `head` / `options` / `trace` tags are normalised; an external `$ref` has its case; the CI download refuses a non-HTTPS redirect.
