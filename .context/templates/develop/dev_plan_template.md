# Template B: Master Implementation Plan (`dev_plan.md`)

```markdown
---
id: {{FEATURE_ID}}
status: DRAFT   # DRAFT | READY | NEEDS_INFO | BUILDING | IMPLEMENTED_AND_VERIFIED | BLOCKED | REJECTED | INVALIDATED
last_update: [DATE]
e2e_required: [true | false]
api_test_required: [true | false]

# Iteration model tracking (EVOL-014)
based_on_iteration: 1
based_on_schemas_version: 1

# Push-based cascade fields — set by upstream --refine, cleared by IMPLEMENT --refine (delta) sync
pending_iteration: null
pending_schemas_version: null
invalidated_sections: []
invalidated_by_iteration: null
invalidated_reason: null
cascade_source: null
cascade_timestamp: null
cascade_scope: []
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
```
