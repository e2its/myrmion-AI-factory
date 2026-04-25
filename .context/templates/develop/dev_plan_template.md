# Template B: Master Implementation Plan (`dev_plan.md`)

> **Body structure depends on `slicing_strategy`:**
> - `monolithic` — flat `## Phase A / B / C` sections with tags `[A.M] / [B.M] / [C.M]`. Body below reflects this case.
> - `incremental` — one `## Increment INC-N: {title}` section per increment (topologically ordered by `depends_on` from increment_plan.md). Each increment contains `### Phase A / B / C` sub-sections with tags `[INC-N.A.M] / [INC-N.B.M] / [INC-N.C.M]` plus an `### Increment INC-N Acceptance Gate` with `[INC-N.ACC.k]` items. Full generation rules: `.claude/instructions/Factory-implement-plan.instructions.md § Strategy Branch`.

```markdown
---
id: {{FEATURE_ID}}
status: DRAFT   # DRAFT | READY | NEEDS_INFO | BUILDING | IMPLEMENTED_AND_VERIFIED | BLOCKED | REJECTED | INVALIDATED
scope: full-stack  # inherited from spec.feature.scope
slicing_strategy: incremental   # incremental | monolithic — inherited from increment_plan.md; drives body layout
last_update: [DATE]
e2e_required: [true | false]             # recommended false when scope in [backend-only, integration]
api_test_required: [true | false]
reliability_test_required: [true | false]  # auto-true when scope in [backend-only, integration]

# Iteration model tracking
based_on_iteration: 1
based_on_schemas_version: 1

# Push-based cascade fields — set by upstream --refine, cleared by IMPLEMENT --refine (delta) sync
pending_iteration: null
pending_schemas_version: null
invalidated_sections: []          # section-level invalidation (legacy, monolithic plans)
invalidated_increments: []        # increment-level invalidation (incremental plans) — list of INC-N ids flagged by CASCADE_INCREMENT_INTERNAL
invalidated_by_iteration: null
invalidated_reason: null
cascade_source: null
cascade_timestamp: null
cascade_scope: []

# Per-increment status mirror (populated when slicing_strategy == incremental; empty list otherwise)
# Mirrors increment_plan.md § 1 status for increments that have reached READY-or-later.
# DRAFT increments stay only in increment_plan.md until IMPLEMENT --plan is run against them.
increments: []
  # - id: "INC-1"
  #   status: "READY"                   # READY | BUILDING | IMPLEMENTED_AND_VERIFIED | INVALIDATED
  #   tasks: { A: N, B: N, C: N, ACC: N }
  # - id: "INC-2"
  #   status: "READY"
  #   tasks: { A: N, B: N, C: N, ACC: N }
---

# Implementation Plan: {{FEATURE_ID}}
**Base Architecture:** `design.md`  
**Test Plan:** `test_plan.md`  
**API Contracts:** `contracts/{{CONTRACT_TYPE}}/{{CONTRACT_SLUG}}/` (if applicable)

## 0. Blockers and Decisions Log (Issue Log)
> 📝 **Flight Log:** Here I record if I get stuck so you can help me.

- **[DATE] Blocker B-01:** Compilation error in `AuthService`.
  - **Cause:** The `IUser` interface changed in the design.
  - **Resolution:** (Pending / Fixed by updating import).

## 1. Task List (Checklist)

### Scaffolding (Design Artifacts - First iteration)
- [ ] Generate Domain Entities: `{{DOMAIN_PATH}}/entities/user.ts`
    - *Ref: design.md → C4 Component Diagram → Entity "User"*
    - *Attributes: id, email, passwordHash, createdAt*
- [ ] Generate Domain Ports: `{{DOMAIN_PATH}}/ports/user-repository.ts`
    - *Ref: design.md → Interface "IUserRepository"*
    - *Methods: findByEmail(), create(), update()*
- [ ] Generate Application DTOs: `{{APPLICATION_PATH}}/dtos/login.dto.ts`
    - *Ref: design.md → Use Case "Login" Input/Output*
- [ ] Generate Application Use Cases (Skeleton): `{{APPLICATION_PATH}}/use-cases/login.usecase.ts`
    - *Ref: design.md → Use Case "Login"*
    - *Inject: IUserRepository, IAuthService*
- [ ] Generate Infrastructure Adapters (Empty): `{{INFRASTRUCTURE_PATH}}/adapters/user-sql.repository.ts`
    - *Implements: IUserRepository*
    - *Methods: Empty stubs (to implement in GREEN phase)*

### E2E Tests (TDD First - If e2e_required: true)
- [ ] Create Page Object: `tests/e2e/pages/login.page.ts`
    - *Map: Email input, Password input, Submit button, Error message*
- [ ] Create E2E Spec (RED): `tests/e2e/specs/auth.spec.ts`
    - *Ref: test_plan.md → TC-UX-01, TC-UX-02*
    - *Scenarios: Login success, Login failure with invalid credentials*

### Unit/Integration Tests
- [x] Create Test `LoginUseCase.test.ts` (RED)
- [ ] Create Test `UserRepository.test.ts` (RED)

### API Integration Tests (If api_test_required: true)
> **Ref:** `contracts/` + `test_plan.md` Section 2.1 (API Integration Test Cases)
> **Template:** `.context/templates/develop/api_test_template.md`
- [ ] [A.N] Create API Test: `tests/api/auth.api.test.ts` (RED)
    - *Ref: contracts/openapi/{{CONTRACT_SLUG}}/v1.yaml → POST /api/v1/auth/login*
    - *Happy path: valid credentials → 200 + token*
    - *Ref: test_plan.md → TC-API-01, TC-API-02*
- [ ] [A.N] Create API Test: `tests/api/users.api.test.ts` (RED)
    - *Ref: contracts/openapi/{{CONTRACT_SLUG}}/v1.yaml → GET /api/v1/users/:id*
    - *Happy path: existing user → 200, non-existent → 404*
    - *Edge cases: malformed ID → 400, unauthorized → 401*
- [ ] [A.N] Execute API tests: `./scripts/test.sh api --apply`
- [ ] [A.N] Verify all API tests PASS (GREEN)

### Reliability Tests (applicable_when scope in [backend-only, integration], reliability_test_required: true)
<!-- applicable_when: scope in [backend-only, integration] -->
> **Ref:** `test_plan.md § 2.2 Reliability Testing` + `user_journey.integration.md § 6 Reliability Contract`
> **Template:** `.context/templates/develop/api_test_template.md` (reuse the harness — reliability tests are API-level with fault injection)
> **Skipping rule:** When scope in [full-stack, frontend-only], replace this block with `N/A (scope={value})`. When scope in [backend-only, integration], every item below is MANDATORY.
- [ ] [A.N] Create idempotency replay test (RED): `tests/reliability/idempotency.test.ts`
    - *Ref: test_plan.md → REL-IDEMP-01, REL-IDEMP-02*
    - *Given: same idempotency_key sent twice; Then: second call is a cached no-op side-effect-wise*
- [ ] [A.N] Create retry/backoff test (RED): `tests/reliability/retry.test.ts`
    - *Ref: test_plan.md → REL-RETRY-01, REL-RETRY-02*
    - *Given: downstream returns 503 for N attempts; Then: exponential backoff honoured; retry_exhausted emits after max*
- [ ] [A.N] Create circuit breaker test (RED): `tests/reliability/circuit-breaker.test.ts`
    - *Ref: test_plan.md → REL-CB-01, REL-CB-02*
    - *Given: threshold failures within window; Then: breaker opens, fails fast; half-open probe closes on success*
- [ ] [A.N] Create DLQ + replay test (RED): `tests/reliability/dlq.test.ts`
    - *Ref: test_plan.md → REL-DLQ-01, REL-DLQ-02*
    - *Given: message exceeds max_retries; Then: lands in DLQ with context; replay succeeds or loops back*
- [ ] [A.N] Create timeout test (RED): `tests/reliability/timeout.test.ts`
    - *Ref: test_plan.md → REL-TIMEOUT-01*
- [ ] [A.N] Create graceful shutdown test (RED): `tests/reliability/shutdown.test.ts`
    - *Ref: test_plan.md → REL-SHUTDOWN-01, REL-SHUTDOWN-02*
    - *Given: SIGTERM during in-flight request; Then: drain completes, process exits 0*
- [ ] [A.N] Create observability contract test (RED): `tests/reliability/observability.test.ts`
    - *Ref: test_plan.md → REL-OBS-01, REL-OBS-02*
    - *Given: request traverses N hops; Then: same trace_id propagated; structured log fields present*
- [ ] [A.N] Execute reliability tests: `./scripts/test.sh reliability --apply`
- [ ] [A.N] Verify all reliability tests PASS (GREEN)

### Domain Layer
- [x] Create Entity `User`
- [ ] Define Port `IUserRepository`

### Application Layer
- [!] **(BLOCKED)** Implement `LoginUseCase`
    - *See Blocker B-01 in log.*

### Infrastructure Layer
- [ ] Implement `UserSqlRepository`

### E2E Validation (Final Check)
- [ ] Execute E2E tests locally: `./scripts/test.sh e2e --apply`
- [ ] Verify all E2E tests PASS (GREEN)

### API Validation (Final Check — If api_test_required: true)
- [ ] Execute API integration tests: `./scripts/test.sh api --apply`
- [ ] Verify all API tests PASS (GREEN)
- [ ] Verify responses match contracts/ schemas (if contract-first-policy.instructions.md applies)

### Reliability Validation (Final Check — applicable_when scope in [backend-only, integration])
<!-- applicable_when: scope in [backend-only, integration] -->
- [ ] Execute reliability suite: `./scripts/test.sh reliability --apply`
- [ ] Verify all reliability tests PASS (GREEN)
- [ ] Verify observability contract: `trace_id` propagated end-to-end, structured log fields per test_plan § REL-OBS-01/02
- [ ] Verify graceful shutdown on staging: `kill -TERM <pid>` mid-request drains within configured window
```
