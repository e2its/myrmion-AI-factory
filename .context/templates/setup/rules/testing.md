---
description: "Testing standards — unit/integration/E2E patterns, coverage targets, test naming, mocking strategies. Applied automatically when editing test files."
applicable_when:
  path_glob:
    - "**/test/**"
    - "**/tests/**"
    - "**/*.test.*"
    - "**/*.spec.*"
version: 1.7.0
date: 2026-09-25
changelog:
  - "1.5.1: feat(EVOL-044) — frontmatter `version` realigned to this manifest entry (manifest-parity gate); YAML made parseable where needed."
  - "1.1.0: feat(EVOL-043) — hosts [PLAW-13] body (merged from the constitution template)"
  - "1.0.0: Initial template version"
---

# Testing Standards & TDD Enforcement

> **Auto-generated from** `docs/setup.md` decisions  
> **Scope:** Unit, Integration, E2E, Security, Performance  
> **Mode:** {{GREENFIELD|BROWNFIELD}}

## [PLAW-13] QA Per-Increment Alignment
> Under incremental slicing, verification is per slice: each increment is closed by its own triple gate and QA report, and the plan-level status is derived, never written by hand.

> **Mandate:** Under `slicing_strategy: incremental`, the implementation lifecycle is per-slice. The QA verification command MUST mirror that granularity. The plan-level `dev_plan.status` value is **derived** from the per-slice mirror; never written manually.

### Rules

- ✅ **Per-slice transition path:** When `slicing_strategy: incremental`, `IMPLEMENT --build {ID} {INC-N}` flips ONLY `dev_plan.frontmatter.increments[INC-N].status` to `IMPLEMENTED_AND_VERIFIED`. The global `dev_plan.status` field MUST NOT be written manually under this strategy.
- ✅ **Per-slice triple gate:** A slice transitions to `IMPLEMENTED_AND_VERIFIED` ONLY when (1) every `[INC-N.A.M]/[INC-N.B.M]/[INC-N.C.M]/[INC-N.ACC.k]` task is `[x]`, (2) the latest `peer_review_{INC-N}_*.md` has `status: APPROVED`, and (3) `BVL full_verification_gate(FEATURE_ID, "INC-N")` returns `PASSED`.
- ✅ **QA slice mode REQUIRED:** Each slice that has reached per-entry `IMPLEMENTED_AND_VERIFIED` REQUIRES `/qa --verify {FEATURE_ID} {INC-N}` before the aggregate may run. The slice report path is `docs/spec/{FEATURE_ID}/qa/qa_report_{INC-N}_{ts}.md` with checklist filtered to the scenarios assigned to that increment in `increment_plan.md § 1`.
- ✅ **Aggregate gate:** `/qa --verify {FEATURE_ID}` (no `INC-N`) is BLOCKED until every per-slice `qa_report_{INC-N}_*.md` exists with `status: APPROVED`. The aggregate report (`qa_report_final_{ts}.md`) cross-references every slice report via the `aggregates: [...]` frontmatter field.
- ✅ **Plan-level derivation:** `dev_plan.status` flips to `IMPLEMENTED_AND_VERIFIED` ONLY when (a) every entry in `dev_plan.frontmatter.increments[]` has `status: IMPLEMENTED_AND_VERIFIED` AND (b) the plan-level aggregate `BVL full_verification_gate(FEATURE_ID, null)` passes — run automatically on the last slice closure.
- ✅ **Monolithic compatibility:** When `slicing_strategy: monolithic`, the gate is single-level: all `[ ]` → `[x]`, then `dev_plan.status` flips (the last tracked write), then the one full loop seals the bytes (EVOL-051). `/qa --verify {ID}` without `INC-N` reads global status — exactly as before.

### Anti-Patterns (PROHIBITED)

- ❌ **Manual global flip under incremental:** Writing `dev_plan.status: IMPLEMENTED_AND_VERIFIED` directly when `slicing_strategy: incremental` and any `increments[].status != IMPLEMENTED_AND_VERIFIED` remains.
- ❌ **Skipping per-slice QA:** Running `/qa --verify {FEATURE_ID}` (aggregate) on an incremental feature with pending `qa_report_{INC-N}_*.md` items.
- ❌ **Cross-slice peer_review reuse:** Pointing the slice closure to a `peer_review_{ts}.md` that does not match the `peer_review_{INC-N}_{ts}.md` naming for the slice being closed.
- ❌ **Aggregate before plan-level BVL:** Marking `dev_plan.status` global as `IMPLEMENTED_AND_VERIFIED` before the last-slice plan-level BVL aggregate has run.

### Validation in Code Review

- ✅ Does the slice's `peer_review_{INC-N}_*.md` exist and is `APPROVED` before the slice transition?
- ✅ Does `qa_report_{INC-N}_*.md` exist with `status: APPROVED` before the aggregate run?
- ✅ Is the `aggregates: [...]` frontmatter field of `qa_report_final_*.md` populated with the consumed slice reports?
- ✅ Does `dev_plan.frontmatter.increments[]` agree with the latest IMPLEMENT closure (no stale `BUILDING` entries for slices that have moved)?

## Testing Pyramid
- Unit coverage target: **≥80%** of business-critical code
- Integration coverage target: **≥60%** of service boundaries
- API integration tests: **mandatory** for features with HTTP endpoints (supertest/httpx/httptest per stack)
- E2E: critical paths only; flaky tests are blockers
- Contract tests: enforce contract-first workflow (OpenAPI/GraphQL/gRPC)

## API Integration Testing
- Every HTTP endpoint in `contracts/` MUST have a corresponding test in `tests/api/`
- Template: `.context/templates/develop/api_test_template.md`
- Test data derived from `user_journey.md § 6 Business Fields` (existence) + `design.md § 7.4 Schema Constraints` (types/formats) or `contracts/` request/response schemas
- Must cover: happy path (200/201), validation errors (400/422), not found (404), unauthorized (401), server errors (500/503)
- Runner: `./scripts/test.sh api --apply` or direct stack runner
- Contract validation (optional): validate response bodies against OpenAPI schema (ajv, jsonschema)
- Generated during `/DEV --plan` Phase A, executed during `/IMPLEMENT --build` Phase A TDD cycle

## TDD & Workflow
- Red-Green-Refactor is mandatory for new logic
- Every bug fix starts with a failing test reproducing the defect
- CI blocks merges if any test fails or coverage < threshold

## Coverage & Quality Gates
- Coverage gate: **80%** minimum, measured in CI
- Mutation testing (optional): enable if mutation score <90%
- Block merge on failing tests or coverage regression

## Test-case traceability (EVOL-053)
- **One home.** A test states the case it proves in ONE machine-readable place — `config/quality.json → traceability.home`: the `case` marker for pytest (`@pytest.mark.case("FEAT-001/TC-01")` on the test, its class or the module's `pytestmark`, read from the syntax tree), the title tag for runners without markers (a literal `[FEAT-001/TC-01]` opening the title of `test(` / `it(` / `t.Run(`; one id per title), `@DisplayName("[FEAT-001/TC-01] …")` for JUnit, or a custom pattern. A comment, a docstring, a bare name, a `describe` title, a skipped / todo / xfail test link nothing — a suite title or a skipped test proves no case.
- **Strict ids.** A link is `FEATURE/CASE` — the plan folder under `docs/spec/` and the id its `test_plan.md` declares (`traceability.id_pattern`; the first cell of a row in a table whose header starts with `ID`, outside code fences; a row twice is red). A malformed id or one that names no declared case is red — at collection for pytest (`tests/conftest_traceability.py`, `--strict-markers` required), and at the gate for every stack. A case whose `Tool` column begins with `Manual` is a MANUAL case: never owed a test, reported as such, never a baseline entry.
- **Case → test, never test → case.** Every declared case has at least one linking test; a helper's test with no link is never a finding.
- **The baseline only shrinks.** `docs/project_log/traceability_baseline.json` records the cases unlinked at adoption (`python3 scripts/gate.py traceability --baseline --init`, once — refused when nothing links at all, and the file must be committed: CI reads the commit); a new case must link; an entry now linked is removed (`--refresh`), never added; after a merge that touched it, re-run `--refresh`. The baseline is a gate input (`planning.gate_inputs`): a hand edit is planned like code. The number is on the board.
- **One gate, two control points.** `python3 scripts/gate.py traceability` is a light member of the gate profile (the static round, the push, CI); QA builds its `[QA-TC-*]` checklist from `--json` and never re-derives the linkage.

## Security Testing
- Include OWASP Top 10 test cases (injection, authz, XSS/CSRF, SSRF)
- Secret detection in tests: no secrets in fixtures or snapshots
- Negative tests: authz failure, rate limiting, input validation
- **Path References (CRITICAL):** All file paths MUST be relative - NEVER use absolute paths (`/home/`, `/Users/`, `C:\`)
  - **Full details:** See `security_policy.md` Section 3.1 & `architecture.md` (Portability)
  - **Language examples:** See `python.md`, `node.md`, `React.md` for concrete patterns
  - **Enforcement:** Blocked by `/REVIEW` ([PATH-XX]) and CI (`scripts/lint-format.sh`)

## Performance & Reliability
- Define p95 latency targets per service; add load tests when breached
- Add resiliency tests (timeouts, retries, circuit breakers) for integrations
- Run smoke tests post-deploy in each environment

## Framework References
- Language-specific standards live in `.claude/rules/{language}.md`
- Contract validation referenced by `.claude/rules/contract-first-policy.md`

## Further Reading
- TDD by Example (Kent Beck)
- Testing Trophy & Pyramid models
- OWASP ASVS testing guidance

## [LAW-05] Testing
> Every unit of logic has its unit test, written red first: red, green, refactor, verify.

Every declared test case has a linking test at the ONE home (§ Test-case traceability). 1 Logic = 1 Unit Test. TDD cycle per task: Red (a failing test names the behaviour) → Green (the least code that passes) → Refactor (under the tests) → Verify (the scoped suite, then the one full verification loop per change). A unit of logic without its test does not reach review. **One full loop per change (EVOL-051):** the static round (no build, no database) and the workers' scoped runs before the critics; the artefacts written; then the full loop once, on the bytes the commit carries, each suite executed once (the suite that feeds coverage feeds both), its green sealed (`python3 scripts/gate.py seal`) and honoured at the push; after a green seal a delta re-runs only the gates whose read-set it touched, a documentation-only delta none, an unmapped path the whole loop.
