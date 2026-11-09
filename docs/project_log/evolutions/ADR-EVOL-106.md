---
id: ADR-EVOL-106
title: "Proof at the close — each case proven by its test, each scenario traced, readiness for production shown on the pre-production stage"
date: 2026-11-09
status: accepted
---

# ADR-EVOL-106: Proof at the close

## Context

This ADR implements issue #164 (epic #112, Wave 3). It was verified on `main` at framework 10.1.0 (8de16b6). QAV means `.claude/instructions/Factory-qa-verify.instructions.md`. Each fact below cites its source.

### Case → test → evidence today
- **A case is a table row.** `traceability.declared()` (`scripts/gates/traceability.py:131-173`) reads every table whose first header is `ID`. The first cell is the case id, qualified `{plan folder}/{id}`. A `Tool` cell starting `Manual` marks a manual case.
  - No other column is read: no Given/When/Then, no status, no retired state.
  - The test plan has no clauses per case (`.context/templates/qa/test_plan_template.md:47,55,66`). AC rows carry `Gherkin Ref`, the exact `Scenario:` title (:45).
- **A link is a tag.** `links()` (:297-315) reads three homes: `pytest-marker`, `title-tag` (`[F/C]` opening a `test(`/`it(` title) and `junit-displayname`.
  - The gate proves that a tag exists. It never runs a test (ADR-EVOL-053).
- **The baseline is debt.** A shrink-only list (`docs/project_log/traceability_baseline.json`, :320-402) lets an unlinked case pass the push. Nothing stops certification while the baseline holds a feature's cases.
  - "Planned" is not a state: a declared, unlinked case is new debt and red at push unless it is baselined (:353-357).
- **QA ticks cases by hand.** `[QA-TC-*]` items are generated from `gate.py traceability --json` (QAV:489-513). They are ticked after "Evidence Request: ask the user for dynamic test logs" (QAV:649-651).
  - No gate reads a machine-readable test report. The only report a gate parses is LCOV (`seal.py:912`).
  - `qa.verdict` passes a ticked `[QA-TC-X] … UNLINKED (baseline)` (`scripts/gates/qa.py:132-150`).
- **Scenarios are not traced.** Nothing in `scripts/gates/` maps a `spec.feature` scenario to a case. CVP Check 5 (`factory-coherence-validation/SKILL.md:607-626`) is agent-run, with a fuzzy match.
- **End-to-end: Playwright only, and it links nothing.**
  - The shipped runner config is `.context/templates/setup/e2e/playwright.config.ts`. Its reporters write `test-results/results.json` and `test-results/junit.xml`, and nothing reads them.
  - The spec template names its case only in a comment. Its titles are `test('should …')`, so `title-tag` links nothing (`.context/templates/develop/e2e_spec_template.md:22-25`, `policies/e2e_testing.md:28`).
  - No `test.step` exists anywhere.
- **No end-to-end tool answer exists.** `E2E_TOOL` is `unsourced` (`discovery_registry.json:2513`). `gitignore.hbs:149` tests an `E2E_TESTING` token that no question fills.
  - `qa.browser_mcp` (Q23.5) is the agent's browser, not a test runner.

### Readiness today
- **The close deploys to `dev`.** That is IMPLEMENT's suggestion (`Factory-implement-build.instructions.md:811`), and QA Gate 0 reads `qa --ready --env dev` (QAV:66).
  - The shipped pipelines know `staging` and `production` (`workflows/deploy.github-actions.yml:38,93-139`, `deploy.bitbucket.yml:53-95`).
  - `rules/ci-cd.md:327-337` names Staging the pre-production stage.
- **One executor.** `delivery.run` (`scripts/gates/delivery.py:388-439`) runs, in order:
  1. validate;
  2. plan;
  3. the migration trace and migrate;
  4. apply;
  5. probe;
  6. measure performance;
  7. record. The lkg tag is written only when every performance row is green.
  
  Every environment runs the same steps from its adapter row (EVOL-081), so «production's order» already holds by construction.
- **Seeding runs after the deploy, outside the executor.** It is DEVOPS Phase 5 (`Factory-devops-provision-deploy.instructions.md:465-470,553-601`). Nothing records whether the stage held data before the upgrade.
- **No pending check after migrate.** `delivery.migrate` comes from the Q15.1 tool row (`discovery_registry.json:852-990`). Nothing asks the tool, after the real run, whether anything is still pending.
- **No plan states where an upgrade first meets data.** The increment plan template has no data line, and the design's § Reliability Questions is the ASVS matrix (RQ-1..5).
- **Stage literals are policed in prose only.** Guardrail 5 (`Factory-devops-configure.instructions.md:186-210`) forbids `staging`/`production` literals, but no gate implements it.
  - The adapter rows already hold every per-environment parameter value (`delivery.adapter_problems`, `delivery.py:106-139`).
- **Rollback is a free-text row.** The deployment report has `## Rollback Information` (`Factory-devops-provision-deploy.instructions.md:540-544`). Nothing states what a rollback cannot restore.
  - `data.migrations()` already classes every new migration as `expand` or `contract` (`data.py:19-20,461`). A contract step is forward-only.

### Clients and statuses today
- **Time-limited functions.** `hosting.type` (Q20.3, `container | function | cdn`, `discovery_registry.json:1318-1336`) is the signal.
  - The design's function resource carries `timeout_seconds` and `handler` (`.context/templates/architect/design_template.md:197-207`).
  - No check reads an external client's bound.
- **Statuses.** `contracts.parity()` `_observed` fails a status a contract test received and the contract does not declare (`contracts.py:676-678`). That is runtime only: a status no test provokes is never seen.
  - No rule reads the statuses the code raises, nor any status a design declares. The design template has no status table.
  - #124's closing note leaves «the code-side rule» to this issue.

## External facts (Beat 0)
- **Playwright JSON reporter.** Nesting: suites → specs → tests → results → steps. Only `test.step` steps are serialised; expect, pw:api, hook and fixture steps are dropped, and `category` is not emitted. A throw inside a step sets that step's `error`. Annotations `{type, description}` pass through on the test and the result (playwright `reporters/json.ts`, `types/testReporter.d.ts`, main).
- **JUnit reporter.** It never reads steps (`reporters/junit.ts`). Steps live only in the JSON report.
- **Negative control.** `page.route(glob, async r => { const resp = await r.fetch(); … await r.fulfill({response: resp, json}) })` patches a response. A per-run flag is `process.env` (docs: test-parameterize, class-route).
- **Semgrep CE 1.182.0** (probed in `semgrep/semgrep:1.182.0`, logged out):
  - The JSON carries no `extra.metavars`.
  - A rule `message` interpolates metavariables (`bound $C $R $A` → `bound 1 6 1`).
  - `metavariable-comparison: ($C + $R) > 30` compares two metavariables numerically.
- **Function platform limits.**
  - Lambda: default 3 s, max 900 s.
  - Azure Functions: Consumption 5/10 min; HTTP capped at 230 s.
  - Vercel (Fluid): 300 s default, 800 s max (Pro).
  - Cloud Run functions: HTTP up to 60 min.
  - SDK defaults are unbounded or long: botocore 60 s + 60 s; JS v3 `requestTimeout` 0; Java v2 `apiCallTimeout` unset; Go `Client.Timeout` 0; requests none; axios 0. The bound is therefore always written in code.
- **SDK bound forms per stack** (three docs-readers, 2026-11-09; context7 and the vendors' API pages):
  - **Units differ.** Python takes seconds (botocore, requests, httpx, azure-core kwargs). JavaScript takes milliseconds. Java takes `Duration`, .NET `TimeSpan`, Go `time.Duration`, Rust `Duration`.
  - **The attempt count is counted two ways.**
    - It includes the first try in: botocore `retries={"total_max_attempts": n}`, AWS JS v3 `maxAttempts` (= maxRetries + 1), AWS Rust `RetryConfig::standard().with_max_attempts(n)`, AWS Java v2 `retryStrategy(b -> b.maxAttempts(n))` and Azure JS Storage `retryOptions.maxTries`.
    - It counts retries only in: botocore `retries={"max_attempts": n}`, AWS .NET `MaxErrorRetry`, Azure .NET `Retry.MaxRetries`, Azure JS core `retryOptions.maxRetries`, httpx `HTTPTransport(retries=n)` and reqwest `max_retries_per_request`.
  - **Some timeouts bound the whole call, retries included.** These are AWS Rust `operation_timeout`, AWS Java v2 `apiCallTimeout`, Go `http.Client.Timeout`, `fetch(u, {signal: AbortSignal.timeout(ms)})` and reqwest `timeout`.
  - **Other timeouts bound one attempt.** These are AWS Java v2 `apiCallAttemptTimeout`, AWS Rust `operation_attempt_timeout`, Azure JS Storage `tryTimeoutInMs` and Azure .NET `Retry.NetworkTimeout`.
  - **Standard HTTP clients retry nothing by default.** This covers requests (`HTTPAdapter` `max_retries` defaults to 0), axios, fetch, Go `net/http`, `java.net.http` and `System.Net.Http`.
    - httpx retries only connect errors, and only when asked.
    - reqwest retries protocol NACKs by default, 2 times.
  - **Some bounds do not bind.**
    - AWS JS v3 `requestTimeout` only warns unless `throwOnRequestTimeout: true` is set (since 3.910.0).
    - AWS .NET `Timeout` does not apply to async calls; a `CancellationToken` does.
    - requests has no Session-level timeout: `timeout=(connect, read)` is set per call.
    - Google Cloud clients are bounded per call (Python `timeout=`/`retry=`, Node gax `CallOptions`).
  - **Defaults.**
    - botocore: 60 s + 60 s; legacy mode, 5 attempts.
    - AWS Rust: connect 3.1 s, read none, 3 attempts.
    - AWS JS v3: timeouts 0 (off).
    - AWS Java v2: timeouts off; 3 attempts (legacy 4, DynamoDB 8).
    - AWS .NET: `Timeout` 100 s; `MaxErrorRetry` 2 (DynamoDB 10).
    - azure-core Python: 300 s + 300 s; `retry_total` 10.
    - Azure Java: connect 10 s; read and response 60 s.
    - undici: connect 10 s; headers and body 300 s.
    - .NET: `HttpClient.Timeout` 100 s; `SocketsHttpHandler.ConnectTimeout` infinite.
  - **Known-cold** (not sourced, so no pack rule covers them):
    - boto3 `Session.client` and `boto3.resource` with `config=`;
    - first-try semantics of urllib3 `Retry.total`, azure-core Python `retry_total`, Azure Java `setMaxRetries` and Go `retry.StandardOptions.MaxAttempts`;
    - whether AWS JS v3 `requestTimeout` bounds one attempt or the whole operation;
    - the scope of Go `BuildableClient.WithTimeout`;
    - AWS Java `RetryPolicy.numRetries` and the `UrlConnectionHttpClient` timeouts;
    - .NET `IHttpClientFactory` configuration;
    - Azure Service Bus retry fields;
    - Google Java per-client `setRetrySettings` and Google .NET `CallSettings`.

## Decision

**RDR-1 (2026-11-09), the end-to-end tool.** Options: (1) `playwright | none`, extensible later; (2) Playwright and Cypress; (3) Playwright, Cypress, WebdriverIO and Selenium. The owner asked: «Y porque no mteriliza esa nueva opcion en lugar de preconstruir? repito el framework esta pensado para ser dinamico y construir el scafolding yy heramientas necesarias en materializacion, no prefijar».

The owner's verbatim choice: «seria 1 y si elige otro se construye lo necesario en la fase de materializacion».

The same principle holds for the bounds packs (§5). The owner asked the same for IaC («asi deberia ser tambien con IaC»), which is outside this issue, so it is registered as its own issue.

### 1. A case is proven by its run — `scripts/gates/proof.py`, `gate.py proof` (G)
- **Clauses — one reader, `proof.clauses(repo, feature)`.**
  - A row with a `Gherkin Ref` takes the steps of the `spec.feature` scenario it names: the Background, then the scenario. Each line is kept verbatim. `And`/`But` take the keyword before them, and a Scenario Outline `<x>` matches any text.
  - Any other row has one `Then` clause: its first column whose header starts with `Expected`.
  - Every case therefore has at least one `Then`.
- **End-to-end layer, selected by an answer (RDR-1).**
  - **The question.** Q23.8 `testing.e2e_tool` fills `E2E_TOOL` and `E2E_TESTING`.
    - It is asked when `frontend.framework` exists, since 10.2.0.
    - Its options are `playwright` and `none`, and it takes any other tool as free text.
  - **`playwright`** lands the shipped adapter below. Its JSON reporter is the only Playwright report that carries steps.
  - **Another tool.** The materialisation builds its adapter against the same contract, as the authored pipeline does (EVOL-081, RDR 9).
    - It writes, in that tool's idiom: the clause helper, the spec template and page object, the runner config, and the adapter canary.
    - It also writes a converter from the tool's native report to the proof shape, declared as `config/quality.json → proof.convert`.
    - The tool's facts come from the docs reader at Beat 0 and are sourced in `MATERIALIZATION_REPORT.md`.
  - **`none`**: no end-to-end layer. Every case is proven by the seal or by hand.
  - **One proof shape.** `proof.py` judges `{tests: [{title, status, steps: [{title, error}], annotations: [{type, description}]}]}`. The built-in Playwright reader maps the JSON reporter onto it; another tool's converter writes it.
  - **Adapter canary.** Every suite carries three planted cases titled `[CANARY/…]`, served by interception with no deployed app:
    - one that must judge green;
    - one whose steps are out of order;
    - one with a Then that asserts nothing.
    
    A run whose canary verdicts differ from the expected ones, in either run, is refused as «the adapter is broken», not as a case failure. A built adapter is therefore proven by its first run, and a converter that marks every Then asserted is caught.
  - **Invariant at materialisation.** `gate.py proof --check` must be green on the materialised tree, else BLOCK.
    - Any answered tool other than `none` needs its helper and its canary spec.
    - A tool other than Playwright also needs an executable `proof.convert`.
  - The shipped Playwright helper `e2e/support/clauses.ts` exports `given`, `when`, `then` and `control`:
    - `given`, `when` and `then` wrap `test.step`.
    - `then` counts the assertions made through the helper's `expect` and annotates `{type: "asserted", description: <title>}`. A Then step that asserts nothing throws.
    - `control(page, glob, mutate)` is active only under `CASE_CONTROL=1`. It corrupts the decisive response (fetch → mutate → fulfil) and annotates `{type: "control"}`.
  - The suite runs twice against the deployed build. The green run has no flag; the control run sets `CASE_CONTROL=1`.
- **`gate.py proof --record --green R --control C --env E`** reads both JSON reports and writes `docs/spec/{F}/qa/proof.json` per feature (`sha`, `env`, `at`, `cases`). History lives in git (EVOL-118). The record is refused when `qa --ready --env E` is red.
  - For each test titled `[F/C]`, these are red:
    - the steps are not the case's clauses in order: one step per clause, the exact title after whitespace and markdown are normalised;
    - a Then step has no `asserted` annotation;
    - the test did not pass;
    - in the control run, the test has no `control` annotation, passed, or failed first on a step that is not a Then.
  - `gate.py proof --report R` runs the same judgment and writes nothing. It is the end-to-end worker's local check.
- **Unit and integration evidence is the loop's seal.** `gate.py seal --check` is valid at the proof's SHA: every member ran green on those bytes, and LAW-05's `red` member proved that each changed test file ran and failed at the base. No second, per-test report reader is added (one evidence home per layer).
- **Trace — `gate.py proof --trace F [--json]`.** It walks scenario → AC row → test → evidence. These are red:
  - a scenario with no AC row;
  - a `Gherkin Ref` that names no scenario;
  - a case with no linking test, including a baselined one;
  - a test with no evidence: absent from `proof.json` or red there (end-to-end), or the seal not valid (unit and integration).
  
  A manual case reads `manual`: QA's own evidence, unchanged.
- **Retired cases.** A test plan's `## Retired cases` holds `| Retired ID | Reason |`. A retired id is not declared, its reason is non-empty, and an id that is both retired and declared is red. A retired id leaves the baseline through `--refresh`, which already removes ids that are no longer declared.

### 2. Certification reads the proof — inside `qa.verdict` (G)
- A report with `id: F` gains a `proof` row.
  - A ticked `[QA-TC-X]` whose trace entry has no evidence is red: the mark was not read from the run.
  - An aggregate report (`report_kind: qa_report_final`) needs the whole trace of F green. Every declared case is present and proven, so a baselined case of F is red.
  - The baseline stays a shrink-only debt list; it no longer reaches certification.
- QAV generates the `[QA-TC-*]` items from `gate.py proof --trace --json` and ticks them from it. Step 4 «Evidence Request» goes.

### 3. Readiness on the pre-production stage at the close — `qa --ready --env <stage> --feature F` (G)
- **The stage is one key.** `delivery.preproduction` defaults to `staging`, the stage the shipped pipelines deploy before production; #147's environment answers replace that default. It is the target of the close deploy and of QA Gate 0. The `dev` literal in IMPLEMENT and QAV is aligned (LAW-17): the shipped pipelines offer only `staging` and `production`.
- **Populated data.** `delivery.populated` is a read-only command that prints an integer. `delivery --run` runs it before migrate on every environment and records the result as `populated`.
  - Row `upgraded`: for every migration the feature adds, the first record on the stage that traced it has `populated > 0`. While the feature adds a migration, a null command is red, and the message names `DEVOPS --configure`.
  - Data-upgrade steps are migrations of the answered tool (`rules/database.md` § Data upgrades — #125's one rule). They run through the one executor with the same command in every environment, so production's order and flags hold by construction. Every registry tool applies every pending migration or exits non-zero, so exit 0 is the zero.
  - Seeding and reseeding stay after the deploy (DEVOPS Phase 5).
- **Performance.** Row `lkg`: the stage's record is good, with an `lkg/` tag on its SHA. This reads #127's verdict and does not restate it.
- **Production values.** Row `production`: every adapter command and the URL template fill for `production` (`delivery.fill`), so nothing is left unfilled. In `delivery --check` (light), a non-production value of a per-environment adapter param is red when it appears as a token in a file under the source roots whose path does not name that environment.
- **Rollback.** Row `rollback`: `devops_plan.md` carries `## Rollback` with non-empty `- **Restores:**` and `- **Cannot restore:**` lines. Every `contract` migration of the feature (`data.migrations`) is named under Cannot restore.

### 4. The plan states where the upgrade meets data — `train.py` clause (j) (G)
- Every INC that is neither BUILDING nor MERGED carries `**Upgrade over data:** <stage> | none`. Any other value is red, so «never» is not a stage.
- A push from an increment branch whose diff adds a migration while its INC says `none` is red.

### 5. Every external client in a time-limited function is bounded — `scripts/gates/bounds.py`, `gate.py bounds` (T)
- **Selection.** The check applies when `hosting.type == function`. One pack, `security/bounds/<lang>.yml`, ships per `backend.runtime` that has a SAST pack (Python, Node.js, Java, Go, .NET, Rust), marked `stack_conditional`. Each pack holds the hosting provider's SDK client construction and the language's standard HTTP clients.
  - **Outside the shipped packs.** For another `backend.runtime` or provider SDK, the materialisation builds the pack from Beat 0 facts (RDR-1's principle). The invariant is `semgrep --test` green, with each rule kind (unbounded, extraction) carrying a `ruleid:` case and an `ok:` case. Else BLOCK.
- **Rules.**
  - **Unbounded.** An *unbounded* rule finds a construction that has no whole-call deadline and lacks a connect bound, a per-attempt read bound or an attempt count.
    - A client with no built-in retry counts as 1 attempt by construction.
    - A bound that does not bind counts as absent: JS v3 `requestTimeout` without `throwOnRequestTimeout: true`, or .NET `Timeout` on an async call.
  - **Extraction.** An *extraction* rule emits its values through message interpolation, as `bound <unit> <count> <connect> <read> <attempts>` or `deadline <unit> <value>`. The `unit` (s/ms) and the `count` (`total`/`retries`) are fixed per rule.
  - **Normalisation.** `bounds.py` converts to seconds and to attempts that include the first try: a retries-only count adds one. Semgrep does no arithmetic.
  - **Coverage.** A known-cold form is in no pack.
- **The design does the arithmetic.**
  - The function resource in `design.md` carries `clients: [{name, calls, connect_s, read_s, attempts} | {name, calls, deadline_s}]`.
  - The sum over its clients of calls × (deadline_s, or attempts × (connect_s + read_s)) must be ≤ `timeout_seconds`.
  - A literal bound in code that no function declares is red: it was chosen without the arithmetic.
- **Ratchet.** `docs/project_log/bounds_baseline.json` (`unbounded: {"path#rule": count}`) only shrinks. `SETUP --upgrade` records it once (`--baseline --init`).
- **Delivery.** It is a verification-loop member; it needs semgrep, not a build.

### 6. Declared statuses ⊆ contract responses — inside `contracts.check` (G)
- A new rule, `statuses`. Each TC-API row's leading Expected Status code or codes must be among the responses of its `Operation` (`default` and `4XX` cover). The test plan's one row per declared status (EVOL-070) is the blueprint's declaration; `design.md` gets no second home for it.
- **Code.** Status literals in source files are read across stacks: a number in a status position, or a named constant mapped through the stdlib `http.HTTPStatus` phrases. They are scoped to the operations whose `operationId` the file names, and each must be among their responses. Older findings enter the existing contracts baseline as `status:<path>#<code>` and only shrink.
- **Emitted.** A status that code annotations declare is already compared by `parity()` `_emitted` (the declared responses); a red test pins it.

### 7. Alignment (LAW-17)
- **End-to-end template and policy.** `e2e_spec_template.md` and `policies/e2e_testing.md` § 4 adopt the `[F/C]` title-tag and the clause helper, replacing `test('should …')`.
  - The policy states the contract every tool meets.
  - `MATERIALIZATION_REPORT_TEMPLATE.md:202` names the answered tool and its sourced facts.
- **SETUP.**
  - `Factory-setup-discovery` gets the Q23.8 block.
  - `Factory-setup-materialization` gets the built-adapter clause and the built-pack clause, each with its invariant.
  - `Factory-setup-upgrade` asks Q23.8 through `since`.
- **Templates.**
  - The test plan template gets `## Retired cases`.
  - The design template gets the function `clients:` block.
  - `devops_plan.md` gets `## Rollback`.
  - The increment plan template gets `**Upgrade over data:**`.
- **Instructions:** QAV, IMPLEMENT (the close target), DEVOPS configure/deploy (`populated`, `## Rollback`), BLUEPRINT (`clients`, `Upgrade over data`) and SETUP upgrade (the baselines).
- **Manifest:** a minor bump, framework 10.1.0 → 10.2.0.

## Verification
Every test is written red first, against fixtures and synthetic Playwright JSON reports. Each DoD row maps to one of the groups below.

- **Clauses (DoD 2).** Each of these is red:
  - a test `[F/AC-01]` whose report lacks the step for one clause;
  - steps out of order;
  - a Then with no `asserted` annotation.
  
  These are green:
  - an Outline step with its `<x>` filled;
  - an `And` that inherits its keyword.
- **Control and marks (DoD 3).** Each of these is red:
  - a control run with no `control` annotation;
  - a control test that passed;
  - a control that fails first on a Given;
  - a ticked `[QA-TC-X]` with no evidence (`qa --verdict`).
- **Adapter (RDR-1).**
  - A test-only fixture converter proves the shape contract.
  - Each of these is red:
    - a canary verdict that differs from the expected one, including a converter that marks every Then asserted;
    - `proof --check` with a tool answered but no `proof.convert`.
  - A synthetic materialisation with `testing.e2e_tool: playwright` lands the helper and the canary; with `none` it lands neither.
- **Certification (DoD 4).** An aggregate report of F is red while F has a baselined case, and green once that case is linked and proven or retired with a reason. A retired id that is still declared is red.
- **Trace (DoD 5).** Each of these is red:
  - a scenario with no AC row;
  - a `Gherkin Ref` naming no scenario;
  - an unlinked AC;
  - an end-to-end case absent from `proof.json`;
  - a unit-level case whose seal is not valid.
- **Readiness and plan (DoD 6).** Each of these is red:
  - a feature migration first traced at a record with `populated: 0`;
  - `delivery.populated` null while the feature adds a migration;
  - `**Upgrade over data:** never`;
  - `none` on a push that adds a migration.
  
  `delivery --run` records `populated` before migrate (a fake runner, call order asserted).
- **Rollback (DoD 7).** Each of these is red:
  - `devops_plan.md` with no `## Rollback`;
  - an empty `Cannot restore`;
  - a contract migration of the feature that is not named.
- **Production values.** These are red:
  - `qa --ready` when a production param is missing;
  - `delivery --check` when a staging param value appears in a source file;
  - that same value inside `envs/staging.tfvars`.
- **Client bounds (DoD 8, per template).**
  - Each pack is proven by `semgrep --test` on semgrep 1.182.0, each rule with a positive and a negative fixture.
  - `bounds` is red on an unbounded client outside the baseline.
  - It is also red on a worst path over `timeout_seconds` (3 × 1 × (20 + 20) > 30) and on a literal tuple no function declares.
  - It is green at 3 × 1 × (1 + 6) = 21 ≤ 30.
  - The baseline only shrinks.
  - A synthetic materialisation with `hosting.type: function` lands the pack and the member; `container` lands neither.
- **Statuses (DoD 9).** Each of these is red:
  - a TC-API Expected Status that is not in the operation's responses;
  - a `409` raised in a file naming the operation, where the contract lacks it;
  - an emitted spec carrying an extra response (pins `_emitted`).
- **Delivery.**
  - mutation sweep in a scratch copy with `.context/templates/setup`;
  - full suite, `test-hooks.sh`, and 9/9 synthetic materialisations with `--answers`;
  - two critic rounds × four lenses;
  - manifest-parity after the bump (DoD 10).
