---
description: "Defect Prevention Cases — origin, story and detection narrative per DC id. Annex to defect-prevention.md; read on demand by id, never at session start."
version: 1.6.1
date: 2026-09-25
applicable_when:
  path_glob:
    - "docs/project_log/**"
---

# Defect Prevention Cases

One case per row of `defect-prevention.md § Defect Classes`. Read a case by id when a row matches and the invariant alone is not enough. SETUP appends one case per materialised row; the Discovery Protocol appends one per new DC.

### DC-18 — SSR/CSR hydration mismatch from window reads in initial render

**Origin:** Server-rendered route whose component read `window` during its first render — React error #418 in the browser console after deploy.

**Story:** A component reads browser-only state (`window`, `document`, `localStorage`, `navigator`, `matchMedia`) inside its initial render and the route is server-rendered. The common attempt `useState(() => typeof window !== "undefined" ? readWindow() : default)` is insufficient — server returns one render, first client render returns another, hydration check throws React error #418. Fix pattern: `useState(<serverValue>)` + `useEffect(() => setX(readWindow()), [])`.

**Detection:** Static `grep -rn 'useState(() => .*window\.' <frontend-app-root>/` MUST return zero matches; Chrome DevTools MCP smoke during the SMOKE-E2E gate asserts zero `#418` errors in the browser console across every SSR-rendered page.

### DC-27 — Synthetic test data shape doesn't match production schema

**Origin:** Test suites green on synthetic values that the production parser rejects — tests passing for the wrong reason.

**Story:** Test factories or module-level constants synthesise values that satisfy `dict[str, Any]` but not the production parser. Patterns: single-char-repeating UUIDs, sequential zero-padded numerics for backup codes / external IDs, non-RFC-2606 fake emails (`test@test.com`), naive datetimes for `TIMESTAMPTZ` columns, plain strings for JSON-in-`TEXT` columns, plain strings for PHC-format columns. Production parsers reject; tests pass for the wrong reason. Fix (prevention, not detection): the same Pydantic semantic type production uses MUST be the constraint test factories build against.

**Detection:** Pydantic row model bound to factory via `_row_model` ClassVar (auto-validation hook); module-level realistic deterministic constants (`ANY_USER_ID`, `ANY_TENANT_ID`, etc.) for placeholders; lint script flags fake-pattern literals at module scope (single-char-repeating UUIDs, sequential zero-padded numerics, non-RFC-2606 emails).

### DC-28 — Cyclomatic complexity exceeds project threshold

**Origin:** A quantitative complexity budget replacing ad-hoc reviewer judgment (LAW-11). High CCN correlates with bug density, regression risk, and review fatigue.

**Story:** A source file under the project's code root contains a function whose cyclomatic complexity exceeds `config/quality.json.complexity.thresholds.hard` or `.thresholds.soft`. The check is MCP-driven: the project picks a complexity scanner (Semgrep or compatible) at SETUP and the scanner returns `{ file, function, ccn }` violations, which are classified `hard` (> hard threshold) or `soft` (> soft threshold). The skill itself is tool-agnostic; the MCP is chosen via RDR at SETUP.

**Detection:** BVL `full_verification_gate` invokes `factory-complexity-check` on `git diff --name-only $BASE..HEAD` after tests pass; factory-pr-review axis 6 invokes the same on the cumulative branch diff. `hard` violations block when `config/quality.json.complexity.bvl_gate==true` (BVL) or `.pr_blocker==true` (PR-review); `soft` always advisory. Fail-open when MCP unavailable or config absent.

### DC-29 — Over-engineering — code that exceeds task need (YAGNI / minimalism)

**Origin:** The "ponytail" discipline — the LLM tends to over-build: speculative abstractions, wrappers, config flags, dependencies, and boilerplate the task never asked for.

**Story:** Any code-bearing change in any phase. DC-28 caps *complexity* of code that exists; DC-29 questions whether the code should exist at all. The discipline is prevention-first: walk a decision ladder and stop at the first viable rung BEFORE writing code. Complementary, not redundant — DC-28 is quantitative on written code, DC-29 is qualitative on the build/no-build decision.

**Detection:** YAGNI ladder, stop at first viable rung: (1) does it need to exist? (2) stdlib? (3) native platform feature? (4) already-installed dependency? (5) one-liner? (6) only then minimal code. Four over-engineering categories flagged: **reinvented stdlib**, **unneeded dependency**, **single-implementation abstraction**, **dead flexibility** (config/flags/params with no caller). **Guardrail — how, not what:** the discipline argues a simpler *implementation*, NEVER cuts *specified scope* — a scope reduction is an RDR decision routed to CODESIGN, never a silent omission. NEVER simplifies input validation, error handling, security, or accessibility. Deliberate shortcuts marked with a `ponytail:` comment naming the ceiling + upgrade path. Consumed at decision-time by `factory-adversarial-reasoning` (do-less AGAINST lens, all phases) and at build-time by BVL `full_verification_gate` step 8 (advisory self-scan, fail-open, never blocks).

### DC-30 — Verifying a fix by re-running everything

**Origin:** A generic class from a downstream instantiation (#120): each fix task re-ran every test and every gate to prove one change.

**Story:** Any fix, in any phase. The cost grows with the codebase, the one test that names the bug drowns in the noise, and the loop's seal — which already knows which gates a delta touches — is bypassed. One full loop per change (EVOL-051): after a green seal, a delta re-runs only the gates whose read-set it touched.

**Detection:** The fix's red test fails before the fix and passes after it, in the scoped suite. Then `python3 scripts/gate.py seal --plan` names the stale gates and `--run` re-runs only those. Framework text that prescribes otherwise is a retired pattern, red in meta CI (#118).

### DC-31 — Secret committed to the diff

**Origin:** A generic class from a downstream instantiation (#120): provider keys, personal access tokens and private-key blocks reached a branch as literals, and the diff check that should have stopped them was the only one in place.

**Story:** Any file, any phase — source, configuration, a test fixture, a script, a document. A credential that reaches any branch is compromised the moment it is pushed, whatever happens to the commit afterwards. A scanner that is installed but cannot detect (wrong rules, wrong range, an error exit read as clean) gives the same green as one that found nothing.

**Detection:** The loop's `secrets` member runs the project's scanner, and `gate.py seal --run` first proves it detects: a clean commit must pass and a planted provider-shaped credential must fail, in a temporary repository outside the tree. The pre-push hook scans every pushed ref. A hit is removed from the diff and the credential is rotated at once — removal alone is not a cure. LAW-04 is the law; this class is its runtime prevention.

### DC-32 — A deploying job blind to one of its sources

**Origin:** A generic class from a downstream instantiation (#120): a job's trigger filter routed by directory while the job read sources outside its filter, so a change to such a source skipped the job and CI stayed green — a declared gate that never executed.

**Story:** Pipelines that decide by path what to run — deploy and release jobs, and the scripts they call. A path the job reads but the trigger does not name changes what ships without the machinery firing. The same defect one layer down is a hook whose matcher omits a tool that writes.

**Detection:** `python3 scripts/gate.py runtime-surface` (a profile member): every path literal in the deploying jobs, and transitively in the scripts they run, matches `surface.runtime_surface`, a hard exclusion or a declared read with its reason; a declared read nothing reads any more is a finding. A non-deploying job's filter against what its compiler resolves (path aliases, generated clients) is toolchain-specific: it stays a project class (`PDC`), searched by the sweep where the toolchain is known.

### DC-33 — Phantom coverage

**Origin:** A generic class from a downstream instantiation (#120): a coverage run lost the data of a worker killed for memory; the run exited green and the threshold held on the files that remained.

**Story:** Any coverage run that aggregates per-process data, or whose configuration excludes paths. A file dropped from the report raises the percentage instead of lowering it, so the figure claims more than it measured. A coverage number that moves without a code change is the symptom.

**Detection:** `gate.py seal --run` writes `coverage-table.md` from this run's LCOV report only: one row per measured file, and every runtime-surface file absent from the report listed «not measured» unless `verification.coverage.omit` declares it. A stale report or a failed run is said, never tabled. The correctness lens reads the table; an undeclared «not measured» file is its finding. Cap the runner's workers to its memory before chasing a number.

### DC-34 — Implementation drifts from the journey and the mock

**Origin:** A generic class from a downstream instantiation (#120): the built product diverged from what co-design defined, visually and in its journeys; the fidelity checks existed as prose in the author's own context and none of the review records adjudicated them.

**Story:** Any feature with a spec, a journey and a mock. Scenarios ship untraced, journey steps exist but cannot be reached, mock states, copy or accessible names are left out, or scope grows beyond the task — and nobody with fresh context compares the build with what was agreed before the deploy.

**Detection:** The `traceability` member: every test case the plan declares is linked to its test at its one home, and the baseline only shrinks. The fidelity lens (`factory-critic-fidelity`) reads the diff against spec, journey, mock and plan with fresh context; a step that cannot be reached or a state not built is its finding. Reachability through the project's navigation model is project-specific (`PDC`).

### DC-35 — A stub outlives its producer

**Origin:** A generic class from a downstream instantiation (#184): a sub-increment shipped a placeholder for a dependency built by a later sub; the later sub merged, and the placeholder kept answering.

**Story:** Any train that splits a use case from what it consumes. The first sub stubs the producer so its tests run; nothing records the stub's end, so the real producer lands beside it, both pass their own tests, and the product answers from the stub.

**Detection:** The increment plan's `## Seam map` names each stub with `stub until SUB-…`; the `train` member is red while that row still says it and the named sub is MERGED. Finding the stub in code (a fake client, a fixture wired at runtime) is stack-specific (`PDC`).

### DC-36 — One error code, two meanings

**Origin:** A generic class proven in a downstream instantiation (#126).

**Story:** Any API with more than one contract. A new endpoint needs an error, its author coins a code instead of finding the existing one, or reuses a familiar code for a different failure. Every contract reads well alone; the catalog nobody keeps tells two stories.

**Detection:** The `contracts` member reads `contracts/errors.yaml` and every contract: a code listed twice, two codes with one meaning, an entry without a meaning, or a contract code the catalog lacks is red. Whether two differently worded meanings are the same failure stays a review question.

### DC-37 — An undeclared departure from CRUD-First, single or batch

**Origin:** A generic class proven in a downstream instantiation (#126).

**Story:** Any REST contract. A route like `GET /users/me` or `DELETE /orders` is convenient for one screen; a resource ships without its delete or its batch update because no screen needed it yet. Nobody records why, so the next author copies the shape and the client discovers the gap at runtime.

**Detection:** The `contracts` member reads every contract: an operation outside the CRUD table and its four extension patterns, or a resource missing one of its eight operations (single and batch), with no non-empty `x-crud-exception`, is red. Findings older than the law sit in a baseline that only shrinks. Whether the stated reason is sound stays a review question.

### DC-38 — A delivered artefact deleted

**Origin:** A generic class proven in a downstream instantiation (#126).

**Story:** Any feature past approval. Cancelling or replacing it feels like deleting its files; the next reader of the code, the audit or the measurement finds a feature id that points nowhere.

**Detection:** The `frontmatter-lock` member: a markdown or `.feature` file whose base `status` is delivered or terminal is red when deleted, replaced by a link, or moved to a name that is no artefact. A move to another artefact name is not a deletion.

### DC-39 — Request validation that does not mirror the contract

**Origin:** A generic class proven in a downstream instantiation (#124).

**Story:** Any API whose handlers validate their own input. The contract caps a name at 80 characters; the DTO caps it at 255, or not at all. The contract makes a field optional; the handler refuses a request without it. Each reads well alone; the client built from the contract meets a different API.

**Detection:** The loop member `contract-parity`: the code's emitted OpenAPI is compared with the authored contract by `oasdiff diff`, so a constraint, a required field, a security requirement or a response on one side only is red; the contract tests record every answer, so a status or an error code the contract does not declare is red. A constraint enforced outside the emitted schema (a hand-written check in the handler) stays a review question.

### DC-40 — A shipped migration edited

**Origin:** A generic class proven in a downstream instantiation (#125).

**Story:** A migration already merged has a typo, or misses a column. Editing it in place looks cleaner than a new one. Every database that already ran it keeps the old shape; every fresh database gets the new one. The environments drift with no trace. Two branches that each add migration 0042 do the same at merge time: one of them never runs.

**Detection:** The `data` member: a migration present at the merge-base that differs, or is gone, at HEAD is red. Two migrations of one directory with one version, or two Alembic heads, are red.

### DC-41 — A destructive schema step with no decision behind it

**Origin:** A generic class proven in a downstream instantiation (#125).

**Story:** A column retires with `DROP COLUMN` in the same increment that stops using it. The step reads like cleanup. A failed deploy then triggers the automatic rollback, which runs the down: the column comes back empty, and the rollback looks like a success. A plain `CREATE INDEX` on a large live table locks its writes for minutes.

**Detection:** The `data` member: a destructive or table-locking step in the up part of a new migration with no decision tag (`FDR: <feature>/FDR-NNNN` or `ADR: ADR-NNN`) naming an accepted record is red. The member lists the migration's class (`expand` or `contract`); the DEVOPS rollback never runs a contract step backwards.

### DC-42 — Data reached around its owner

**Origin:** A generic class proven in a downstream instantiation (#125).

**Story:** A repository class owns the database access. A handler opens its own connection for one quick query; a seed script inserts rows straight into the tables. Each skips the owner's validation and invariants. A baseline of those shortcuts, deleted and seeded again, quietly grows.

**Detection:** The `data` member: a connection built outside `data.connection_factory` (the migrations and the test roots aside) is red; older ones sit in a baseline compared with its merge-base copy, so it only shrinks. Each seeded entity names its owner's create and delete, and a seeder or fixture that writes a table is red.

### DC-43 — One site's figure scores another

**Origin:** A generic class proven in a downstream instantiation (#127).

**Story:** A latency reference was measured once, on one environment, and became the threshold for every environment. A slower environment looked like a regression on each deploy, and a real regression hid behind a faster one. Nobody could tell which figure belonged to which build.

**Detection:** The `performance` member: every baseline line names its site, its measured commit and its date. The deployed measurement compares a figure only with the last line of the same site; a site with no line yet is advisory and writes its first line. The light member refuses a line with no site and an edited or removed line.

