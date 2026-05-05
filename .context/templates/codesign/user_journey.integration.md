---
status: DRAFT
feature_id: "{{FEATURE_ID}}"
scope: backend-only  # must be backend-only or integration; full-stack / frontend-only use user_journey_template.md instead
co_creation_round: 0
po_sign_off: false
ux_sign_off: N/A  # scope excludes UX
schemas_version: 1
iteration: 1
iteration_history: []
last_iteration_scope: "Initial co-creation"
created_at: "{{TIMESTAMP}}"
updated_at: "{{TIMESTAMP}}"
based_on_iteration: 1
---

# Integration Journey: {{FEATURE_ID}} — {{FEATURE_NAME}}

> **Method:** Simplified Event Storming (Brandolini) — integration variant (no UI, no Read Models for display).
> **Generado por:** CODESIGN Agent | Feature: {{FEATURE_ID}} | Scope: backend-only / integration
> **Source of Truth for Data Schemas** — ARCH formalizes in contracts (OpenAPI / AsyncAPI / gRPC / Protobuf), DOES NOT invent business fields.
> **Incremental-slicing note.** Under `slicing_strategy: incremental` (the default), BLUEPRINT distributes the scenarios and caller actors across vertical increments declared in `increment_plan.md § 1` — each increment ships as an independent PR that leaves the integration surface 100% callable. Each increment's `contract_surface` lists the exact operations it delivers; consumers binding via `consumes_contract` see cumulative endpoints as increments merge.

---

## Section 0: Decision History

<!-- Chronological record of RDR decisions made during co-creation. UX hat is inactive for this scope — all decisions carry 🎩 PO. -->

| # | Date | Hat | Question | Options | Decision | Rationale |
|---|------|-----|----------|---------|----------|-----------|
| 1 | {{DATE}} | 🎩 PO | — | — | — | — |

---

## Section 1: Integration Overview

### Actors (caller-side + system-side)

| Actor | Type | Description |
|-------|------|-------------|
| {{CALLER_NAME}} | External caller / Upstream service / Cron / Webhook emitter | {{DESCRIPTION}} |
| {{SYSTEM_NAME}} | Our service | Processes the request |
| {{DOWNSTREAM_NAME}} | Downstream service / DB / Queue / External API | {{DESCRIPTION}} |

### Sequence Diagram (caller → system → downstream)

```mermaid
sequenceDiagram
    participant C as {{CALLER}}
    participant API as Our Service (API / Worker / Consumer)
    participant DB as Persistent Store
    participant EXT as {{DOWNSTREAM_SYSTEM}}

    C->>API: {{Command}} ({{SchemaRef}})
    API->>DB: Persist / read ({{SchemaRef}})
    API->>EXT: {{DownstreamCall}} ({{SchemaRef}})
    EXT-->>API: {{DownstreamResponse}} ({{SchemaRef}})
    API-->>C: {{ResponseOrAck}} ({{SchemaRef}})
```

For async integrations, replace the final `-->>C` with an event publication (`API->>BROKER: publish EventX`) and document the consumer contract separately.

---

## Section 2: Integration Steps

<!-- Per-step blocks (parser-canonical format).
     Each step is delimited by a `### Paso N` heading followed by labeled fields.
     Downstream parsers (CODESIGN consumers, contract generators, test scaffolders)
     extract by anchoring on `^### Paso N$` and reading the labeled fields below.
     `DataIn:` / `DataOut:` reference schemas from Section 3 by name.
     `Trigger` identifies what initiates the step (HTTP request, event, cron, webhook).
     `Effect` is the persisted or observable outcome.
     Integration-specific fields (Idempotency Key, Retry Policy) are mandatory for
     this scope and never elided. -->

### Paso 1

- **Actor:** {{CALLER}}
- **Trigger:** {{TRIGGER}}
- **Action (Command):** {{ACTION}}
- **Effect (Event / Side-effect):** {{EFFECT}}
- **External System:** —
- **DataIn:** {{SchemaRef}}
- **DataOut:** {{SchemaRef}}
- **Idempotency Key:** {{IDEMP_KEY_FIELD}}
- **Retry Policy:** none / exponential / dead-letter

#### Schema:

> Optional inline schema reference. Most steps reuse a schema defined in Section 3 — leave this block empty or remove it when not needed.

```yaml
# Inline schema for this step only (rare). Use sparingly — Section 3 is the canonical schema source.
```

---

### Paso 2

- **Actor:** {{SYSTEM}}
- **Trigger:** {{TRIGGER}}
- **Action (Command):** {{ACTION}}
- **Effect (Event / Side-effect):** {{EFFECT}}
- **External System:** {{DownstreamSystem}}
- **DataIn:** {{SchemaRef}}
- **DataOut:** {{SchemaRef}}
- **Idempotency Key:** {{IDEMP_KEY_FIELD}}
- **Retry Policy:** exponential(max=5, base=2s)

#### Schema:

```yaml
# Inline schema (optional, see note above).
```

---

## Section 3: Data Schemas

<!-- SOURCE OF TRUTH for data. ARCH formalizes in OpenAPI/AsyncAPI/gRPC/Protobuf.
     Primitive types: string, number, boolean, date, uuid, enum[...], array[...], object
     Technical fields (id, created_at, updated_at, correlation_id, trace_id) are freely added by ARCH.
     Business fields are ONLY defined here. -->

### {{SchemaName}}
```yaml
# {{Description}}
field_name: type        # constraint or format hint
field_name: type        # constraint or format hint
```

<!-- Example (integration flavour):
### ProcessPaymentCommand
```yaml
# Inbound payment instruction
idempotency_key: string     # UUID, required, unique per logical operation
amount: number              # required, >0, decimal(18,2)
currency: string            # required, ISO 4217 (USD, EUR, ...)
customer_id: string         # required, references Customer aggregate
payment_method_token: string # required, tokenised — never raw card
metadata: object            # optional, free-form key/value, max 32 keys
```

### PaymentProcessedEvent
```yaml
# Outbound event after successful processing
idempotency_key: string
transaction_id: string      # issued by payment gateway
status: enum[SETTLED, DECLINED, PENDING]
settled_at: datetime        # ISO 8601, null when status != SETTLED
gateway_response_code: string
```
-->

---

## Section 4: Business Rules (Policies)

<!-- Business rules that condition behavior.
     Format: Condition → Action.
     Each rule is referenced in spec.feature as Given/When/Then. -->

| # | Rule ID | Condition | Action | Scenario Ref |
|---|---------|-----------|--------|--------------|
| P1 | {{RULE_ID}} | {{CONDITION}} | {{ACTION}} | {{SCENARIO_NAME}} |

---

## Section 5: External Systems (Integration Contracts)

<!-- External systems this feature integrates with. Every entry is consumed by BLUEPRINT --start to decide
     which contracts to freeze (OpenAPI / AsyncAPI / gRPC / Webhook contract). The contract_slug is assigned
     at BLUEPRINT --start and backfilled here. -->

| System | Direction | Protocol | Contract Type | Data Exchange (Schema Ref) | Auth Method | Contract Slug (backfilled) | Notes |
|--------|-----------|----------|---------------|----------------------------|-------------|----------------------------|-------|
| {{SYSTEM_NAME}} | Inbound / Outbound / Bidirectional | REST / GraphQL / gRPC / Event / Webhook | OpenAPI 3.1 / AsyncAPI 2.6 / Proto3 | {{SchemaRef}} | API Key / OAuth / mTLS / HMAC signature | {{CONTRACT_SLUG}} | {{NOTES}} |

---

## Section 6: Reliability Contract (integration-specific)

<!-- Explicit reliability guarantees for this flow. BLUEPRINT test_plan.md § Reliability Testing is generated from this section. -->

- **Idempotency:** {{keys + deduplication window + storage strategy}}
- **Retry policy (per downstream):** {{exponential / linear / none; max attempts; base delay; jitter}}
- **Circuit breaker:** {{enabled/disabled; threshold; half-open probe interval}}
- **Dead-letter handling:** {{destination; replay tooling; ownership}}
- **Timeouts:** {{per-hop timeout in ms}}
- **Graceful shutdown:** {{in-flight request drain window; signal handling: SIGTERM/SIGINT}}
- **Observability:** {{structured log fields, trace propagation header, critical metrics: latency_p95, error_rate, retry_count}}

---

## Traceability Matrix

<!-- Automatic mapping: Integration Step # → Gherkin Scenario → QA Test Case → Schema → Contract -->

| Step # | Gherkin Scenario | Schema In | Schema Out | Business Rules | Contract Slug |
|--------|------------------|-----------|-----------|----------------|---------------|
| #1 | {{SCENARIO_NAME}} | {{SchemaRef}} | {{SchemaRef}} | P1, P2 | {{CONTRACT_SLUG}} |
