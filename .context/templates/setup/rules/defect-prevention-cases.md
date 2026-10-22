---
description: "Defect Prevention Cases — origin, story and detection narrative per DC id. Annex to defect-prevention.md; read on demand by id, never at session start."
version: 1.1.0
date: 2026-09-25
changelog:
  - "1.0.0: feat(EVOL-043) — annex created; narratives moved out of the catalog prose columns into one case per DC"
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
