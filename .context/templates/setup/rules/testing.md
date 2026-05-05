---
description: "Testing standards — unit/integration/E2E patterns, coverage targets, test naming, mocking strategies. Applied automatically when editing test files."
applyTo: "**/*.{test,spec}.{js,ts,jsx,tsx,py,java,cs}"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Testing Standards & TDD Enforcement

> **Auto-generated from** `docs/setup.md` decisions  
> **Scope:** Unit, Integration, E2E, Security, Performance  
> **Mode:** {{GREENFIELD|BROWNFIELD}}

## Testing Pyramid
- Unit coverage target: **≥80%** of business-critical code
- Integration coverage target: **≥60%** of service boundaries
- API integration tests: **mandatory** for features with HTTP endpoints (supertest/httpx/httptest per stack)
- E2E: critical paths only; flaky tests are blockers
- Contract tests: enforce contract-first workflow (OpenAPI/GraphQL/gRPC)

## API Integration Testing
- Every HTTP endpoint in `contracts/` MUST have a corresponding test in `tests/api/`
- Template: `.context/templates/develop/api_test_template.md`
- Test data derived from `user_journey.md` DataIn/DataOut schemas or `contracts/` request/response schemas
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

## Security Testing
- Include OWASP Top 10 test cases (injection, authz, XSS/CSRF, SSRF)
- Secret detection in tests: no secrets in fixtures or snapshots
- Negative tests: authz failure, rate limiting, input validation
- **Path References (CRITICAL):** All file paths MUST be relative - NEVER use absolute paths (`/home/`, `/Users/`, `C:\`)
  - **Full details:** See `security_policy.instructions.md` Section 3.1 & `architecture.instructions.md` (Portability)
  - **Language examples:** See `python.instructions.md`, `node.instructions.md`, `React.instructions.md` for concrete patterns
  - **Enforcement:** Blocked by `/REVIEW` ([PATH-XX]) and CI (`scripts/lint-format.sh`)

## Performance & Reliability
- Define p95 latency targets per service; add load tests when breached
- Add resiliency tests (timeouts, retries, circuit breakers) for integrations
- Run smoke tests post-deploy in each environment

## Framework References
- Language-specific standards live in `.claude/rules/{language}.instructions.md`
- Contract validation referenced by `.claude/rules/contract-first-policy.md`

## Further Reading
- TDD by Example (Kent Beck)
- Testing Trophy & Pyramid models
- OWASP ASVS testing guidance
