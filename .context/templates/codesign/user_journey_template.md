---
status: DRAFT
feature_id: "{{FEATURE_ID}}"
scope: full-stack  # dual-axis — must match scope in spec.feature; when in [backend-only, integration], use user_journey.integration.md variant
co_creation_round: 0
po_sign_off: false
ux_sign_off: false  # N/A when scope in [backend-only, integration]
schemas_version: 1
iteration: 1
iteration_history: []
last_iteration_scope: "Initial co-creation"
created_at: "{{TIMESTAMP}}"
updated_at: "{{TIMESTAMP}}"
based_on_iteration: 1
---

# User Journey: {{FEATURE_ID}} — {{FEATURE_NAME}}

> **Method:** Simplified Event Storming (Brandolini)
> **Generado por:** CODESIGN Agent | Feature: {{FEATURE_ID}}
> **Source of Truth for Data Schemas** — ARCH formalizes in contracts, DOES NOT invent business fields.
> **Incremental-slicing note.** Under `slicing_strategy: incremental` (the default), BLUEPRINT distributes the scenarios in `spec.feature` across vertical increments declared in `increment_plan.md § 1` — each increment ships as an independent PR that leaves the product 100% functional. This journey describes the COMPLETE end-state; per-increment UI/flow deltas are documented in `increment_plan.md` and in Section 0 below when they diverge significantly.

---

## Section 0: Decision History

<!-- Chronological record of RDR decisions made during co-creation -->

| # | Date | Hat | Question | Options | Decision | Rationale |
|---|-------|----------|----------|----------|----------|-----------|
| 1 | {{DATE}} | 🎩 PO | — | — | — | — |

---

## Section 1: Journey Overview

### Actors
<!-- Lista de actores que participan en esta feature -->

| Actor | Type | Description |
|-------|------|-------------|
| {{ACTOR_NAME}} | Usuario / Sistema / Externo | {{DESCRIPTION}} |

### Sequence Diagram

```mermaid
sequenceDiagram
    participant U as {{ACTOR}}
    participant FE as Frontend
    participant BE as Backend
    participant EXT as External System

    U->>FE: {{Command}} ({{SchemaRef}})
    FE->>BE: {{APICall}} ({{SchemaRef}})
    BE-->>FE: {{Response}} ({{SchemaRef}})
    FE-->>U: {{ReadModel}} ({{SchemaRef}})
```

---

## Section 2: Journey Steps

<!-- Master table: each row is a step in the journey.
     Data In/Out reference schemas from Section 3 by name.
     Screen/View links to mock.html.
     # correlates with QA test cases. -->

| # | Actor | Action (Command) | System Response (Event) | Data In | Data Out | External System | Screen/View |
|---|-------|-------------------|-------------------------|---------|----------|-----------------|-------------|
| 1 | {{ACTOR}} | {{ACTION}} | {{EVENT}} | {{SchemaRef}} | {{SchemaRef}} | — | {{SCREEN}} |
| 2 | {{ACTOR}} | {{ACTION}} | {{EVENT}} | {{SchemaRef}} | {{SchemaRef}} | — | {{SCREEN}} |

---

## Section 3: Data Schemas

<!-- SOURCE OF TRUTH for data. ARCH formalizes in OpenAPI/TypeScript/GraphQL.
     Primitive types: string, number, boolean, date, uuid, enum[...], array[...], object
     Technical fields (id, created_at, updated_at) are freely added by ARCH.
     Business fields are ONLY defined here. -->

### {{SchemaName}}
```yaml
# {{Description}}
field_name: type        # constraint or format hint
field_name: type        # constraint or format hint
```

<!-- Ejemplo:
### LoginRequest
```yaml
# Data sent by the user to authenticate
email: string           # format: email, required
password: string        # minLength: 8, required
remember_me: boolean    # default: false
```

### LoginResponse
```yaml
# System response upon successful authentication
token: string           # JWT token
user_name: string       # display name
role: enum[admin, user, guest]
```

### LoginError
```yaml
# System response in case of authentication error
error_code: enum[INVALID_CREDENTIALS, ACCOUNT_LOCKED, ACCOUNT_NOT_VERIFIED]
message: string
remaining_attempts: number  # 0-5
```
-->

---

## Section 4: Business Rules (Policies)

<!-- Business rules that condition behavior.
     Format: Condition → Action.
     Each rule is referenced in spec.feature as Given/When/Then. -->

| # | Rule ID | Condition | Action | Scenario Ref |
|---|---------|-----------|--------|-------------|
| P1 | {{RULE_ID}} | {{CONDITION}} | {{ACTION}} | {{SCENARIO_NAME}} |

---

## Section 5: External Systems

<!-- External systems this feature interacts with.
     Each integration must be documented in config/system_resources.json -->

| System | Protocol | Data Exchange (Schema Ref) | Auth Method | Notes |
|--------|----------|---------------------------|-------------|-------|
| {{SYSTEM_NAME}} | REST / GraphQL / gRPC / Event | {{SchemaRef}} | API Key / OAuth / mTLS | {{NOTES}} |

---

## Traceability Matrix

<!-- Automatic mapping: Journey Step # → Gherkin Scenario → QA Test Case → Schema -->

| Journey Step | Gherkin Scenario | Schema In | Schema Out | Business Rules |
|-------------|-----------------|-----------|-----------|----------------|
| #1 | {{SCENARIO_NAME}} | {{SchemaRef}} | {{SchemaRef}} | P1, P2 |
