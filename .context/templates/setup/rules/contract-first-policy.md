---
description: "Contract-first policy — API contracts before implementation, schema validation, backward compatibility rules."
---
# Contract-First Development Policy

> **Mandate:** All API boundaries MUST have contracts defined BEFORE implementation begins.  
> **Philosophy:** Design the interface, then code to the contract.

---

## 🎯 Core Principle

**Contract-First** means:
1. **Design Phase:** Architect creates machine-readable contracts
2. **Review Phase:** Frontend/Backend teams review contracts together
3. **Parallel Development:** Frontend consumes mocks, Backend implements against contract
4. **Validation:** CI/CD ensures implementation matches contract

**Rationale:**
- **Early Validation:** Catch API design issues before writing code
- **Parallel Development:** Frontend and Backend teams work simultaneously
- **Living Documentation:** Contracts serve as always-up-to-date API docs
- **Breaking Change Prevention:** Contract versioning prevents accidental breaking changes

---

## 📁 Contract Storage & Organization

### Centralized Structure (Domain-Name Traceability)
Contracts are stored centrally with **semantic domain-name directories + inline `x-feature-id` metadata** for traceability:

```
contracts/
├── openapi/              # REST API contracts — IF communication_style == REST (default)
│   ├── auth-oauth-login/ # {domain}-{capability} in kebab-case
│   │   ├── v1.yaml       # Version 1 contract
│   │   └── v2.yaml       # Version 2 (breaking changes)
│   └── payment-checkout/
│       └── v1.yaml
├── graphql/              # GraphQL contracts — IF communication_style == GraphQL
│   ├── user-profile/
│   │   └── schema.graphql
│   └── catalog-search/
│       └── schema.graphql
├── asyncapi/             # Event-Driven contracts — IF topology IN [B3, B6, B7, B11]
│   ├── order-events/
│   │   └── asyncapi.yaml
│   └── inventory-stock-events/
│       └── asyncapi.yaml
├── grpc/                 # gRPC contracts — IF communication_style == gRPC
│   └── inventory-stock/
│       └── service.proto
├── webhooks/             # Webhook contracts — IF backend.webhooks != None
│   ├── inbound/          # Third-party → Our system (payment gateways, CI/CD, SaaS)
│   │   └── stripe-payment-events/
│   │       └── v1.yaml   # OpenAPI 3.1 paths defining webhook receiver endpoints
│   └── outbound/         # Our system → External consumers
│       └── order-status-notifications/
│           └── v1.yaml   # OpenAPI 3.1 with `webhooks:` section
└── feature_map.md        # Cross-reference: CONTRACT_SLUG → Feature ID → spec
```

> **SETUP Scaffolding Rule:** Only create subdirectories that match the project's `communication_style` and `topology`. Additional contract types can be enabled later via ADR (e.g., adding AsyncAPI to a REST project that adopts event sourcing).

### Traceability Mechanism (Hybrid Approach)

#### 1. Directory Namespacing (CONTRACT_SLUG Convention)
- Contract directories MUST use **`{CONTRACT_SLUG}`** = `{domain}-{capability}` in kebab-case: `contracts/{type}/{CONTRACT_SLUG}/`
- Example: Feature `AUTH-001` (domain: auth, capability: oauth-login) → `contracts/openapi/auth-oauth-login/v1.yaml`
- The `{CONTRACT_SLUG}` is derived by `/BLUEPRINT --start` from `user_journey.md` bounded context + `spec.feature` title
- ⚠️ **PROHIBIDO** usar Feature IDs como nombre de directorio (e.g., `AUTH-001/`) — el Feature ID se almacena como metadata `x-feature-id` dentro del contrato y en `feature_map.md`

#### 2. Inline Metadata (OpenAPI Example)
```yaml
openapi: 3.1.0
info:
  title: Authentication API
  version: 1.0.0
  x-feature-id: AUTH-001                    # Links to docs/spec/AUTH-001/
  x-owner: backend-team
  x-consumers: ["web-app", "mobile-app"]
  x-design-doc: docs/spec/AUTH-001/design.md
```

#### 2b. Serverless Extensions (Mandatory for B9/Serverless)

When the project architecture's primary mode is Serverless (B9), OpenAPI operations MUST include the relevant `x-serverless-*` extensions to bridge the **contract→infrastructure** gap. DEVOPS reads these to auto-generate function resources in IaC (SAM `template.yaml`, CDK constructs, etc.). For non-B9 architectures, these extensions are not used and MAY be omitted.

```yaml
paths:
  /api/v1/auth/login:
    post:
      operationId: authLogin
      x-serverless-handler: src/handlers/auth.login   # Entry point (file.export)
      x-serverless-memory: 256                         # Memory MB (default: 128)
      x-serverless-timeout: 30                         # Timeout seconds (default: 30)
      x-serverless-runtime: nodejs20.x                 # Override project default runtime
      # ... normal OpenAPI spec (requestBody, responses, etc.)
```

**Extension Reference:**

| Extension | Scope | Required | Description |
|-----------|-------|----------|-------------|
| `x-serverless-handler` | operation | YES (B9) | Handler entry point (`file.exportedFunction`) |
| `x-serverless-memory` | operation | YES (B9) | Memory allocation in MB (sized per feature workload by BLUEPRINT) |
| `x-serverless-timeout` | operation | No | Execution timeout in seconds (default: 30) |
| `x-serverless-runtime` | operation | No | Runtime override (default from `backend.runtime`) |
| `x-serverless-layers` | operation | No | Lambda layer ARNs / shared dependencies |
| `x-serverless-env` | operation | No | Extra env vars beyond global config |

**Who writes these:** BLUEPRINT (🏗️ ARCH hat) during `--start` Phase 2, when constitution.md `architecture.primary == B9`. BLUEPRINT determines `x-serverless-memory` based on feature workload analysis (I/O-bound vs CPU-bound, payload size, crypto needs). Runtime is **inherited from `constitution.md → backend.runtime`** — the `x-serverless-runtime` extension is only used when a specific function needs a different runtime than the project stack.
**Who reads these:** DEVOPS during `--provision` / `--deploy` to derive function declarations.
**Validation:** Spectral custom rule enforces `x-serverless-handler` and `x-serverless-memory` presence on all operations when `architecture == B9`.

#### 3. Cross-Reference File (`contracts/feature_map.md`)
```markdown
# Contract → Feature Mapping

| Contract Slug | Contract Path | Feature ID | Spec Location | Status | Role | Notes | Superseded By | Superseded At |
|---------------|---------------|------------|---------------|--------|------|-------|---------------|---------------|
| auth-oauth-login | `openapi/auth-oauth-login/v1.yaml` | AUTH-001 | `docs/spec/AUTH-001/` | ACTIVE | OWNER | | | |
| user-profile | `graphql/user-profile/schema.graphql` | USER-003 | `docs/spec/USER-003/` | ACTIVE | OWNER | | | |
| payment-checkout | `openapi/payment-checkout/v2.yaml` | PAY-005 | `docs/spec/PAY-005/` | ACTIVE | OWNER | | | |
| auth-oauth-login | `openapi/auth-oauth-login/v1.yaml` | AUTH-001 | `docs/spec/AUTH-001/` | SUPERSEDED | OWNER | | AUTH-002 | 2026-02-20 |
```

> **Status Values:** `ACTIVE` (authoritative), `SUPERSEDED` (replaced by another feature — kept for audit trail, excluded from collision detection and runtime routing), `DEPRECATED` (sunset in progress).

#### 4. Cross-Feature Endpoint Collision Detection (MANDATORY)

When `/BLUEPRINT --start` generates a new contract, it MUST scan **all existing ACTIVE contracts** for endpoint path collisions before approval. Two features defining the same `{METHOD} {path}` is a **BLOCKING** error that must be resolved via:
- **SUPERSEDE:** New feature takes ownership, old entry marked SUPERSEDED
- **MERGE:** Consolidate into one shared contract directory
- **RENAME:** Change the endpoint path to avoid collision

See `BLUEPRINT.AGENT.MD` Phase 3 Step 1b for the full algorithm.

#### 5. Existing Contract Reuse Policy (MANDATORY — BEFORE Creating New Endpoints)

> **Mandate:** Before generating ANY new endpoint, BLUEPRINT MUST scan **100% of existing HTTP contracts** across all contract types (`openapi/`, `graphql/`, `grpc/`, `asyncapi/`) to build a complete **Existing Endpoint Inventory**. This prevents creating redundant endpoints that duplicate functionality already available in other feature contracts.

**Applies to:** `/BLUEPRINT --start` (Phase 2 Step -1) and `/BLUEPRINT --refine` (when feedback introduces new endpoints).

**Why this exists:**
- As a project grows, different features may need similar API capabilities (e.g., "get user by ID" used by Auth, Profile, Admin).
- Without a full scan, each feature creates its own endpoint, leading to: API surface bloat, inconsistent schemas for the same resource, duplicated server logic, and routing conflicts.
- A **full inventory scan** ensures ARCH makes informed decisions: REUSE existing endpoints, EXTEND existing contracts, or CREATE new ones with documented justification.

**Scan Protocol:**
1. **Full Inventory Build:** Scan ALL `contracts/{type}/{slug}/` directories (excluding SUPERSEDED entries in `feature_map.md`). Extract every `{METHOD} {path}` pair (OpenAPI), every Query/Mutation (GraphQL), every RPC (gRPC), and every channel (AsyncAPI).
2. **Semantic Matching:** Compare each *needed* capability (derived from `spec.feature` + `user_journey.md`) against the inventory using:
   - **Exact match:** Same `{METHOD} {path}` → Full reuse candidate.
   - **Partial match:** Same resource prefix + compatible method → Potential reuse after evaluation.
   - **Same domain:** Different capability within same domain slug → Extend existing contract.
   - **Schema overlap (>60%):** Different path but overlapping request/response fields → Near-duplicate alert.
3. **Decision per Candidate (RDR):**
   - **REUSE ✅ (recommended):** Do NOT create a new endpoint. Reference existing contract in `design.md`. Add consumer entry in `feature_map.md`.
   - **EXTEND:** Add new operation to existing contract slug. Update co-ownership in `feature_map.md`.
   - **NEW ENDPOINT (requires justification):** Create new endpoint only when existing one cannot serve the need (different auth context, different SLA, incompatible schema shape). Justification recorded in `design.md` Section 0.
4. **Output:** Summary logged in `design.md` Section 0 ("Existing Contract Analysis") with total endpoints scanned, reused, extended, and newly created.

**Consumer Tracking in `feature_map.md`:**
When a feature REUSES an endpoint from another feature's contract, a **consumer entry** is appended:

```markdown
| Contract Slug | Contract Path | Feature ID | Spec Location | Status | Role | Notes | Superseded By | Superseded At |
|---|---|---|---|---|---|---|---|---|
| auth-oauth-login | `openapi/auth-oauth-login/v1.yaml` | AUTH-001 | `docs/spec/AUTH-001/` | ACTIVE | OWNER | | | |
| auth-oauth-login | `openapi/auth-oauth-login/v1.yaml` | ADMIN-003 | `docs/spec/ADMIN-003/` | ACTIVE | CONSUMER | Reuses GET /api/v1/auth/users/{id} | | |
```

> **Role Values:** `OWNER` (feature that created the contract), `CONSUMER` (feature that reuses endpoints without modifying the contract), `CO-OWNER` (feature that extended the contract with new operations).

**Enforcement:**
- `/BLUEPRINT --start`: Scan is MANDATORY in Phase 2 Step -1. Cannot proceed to contract generation without completing the scan.
- `/BLUEPRINT --refine`: Scan is triggered ONLY when feedback introduces new endpoints (new paths, not schema modifications to existing paths).
- `/BLUEPRINT --approve`: Pre-check validates that `design.md` Section 0 contains the "Existing Contract Analysis" block. BLOCK if missing.

#### 6. Inter-Domain Communication Enforcement (MANDATORY — ALL Architectures)

> **Mandate:** ALL communication between domains, modules, features, or bounded contexts MUST go through formally defined HTTP contracts (synchronous or asynchronous). **No direct cross-domain imports, function calls, or implicit coupling** is permitted — regardless of whether modules run in the same process (monolith) or separate processes (microservices).

**Philosophy:**
- **Domain boundaries are API boundaries.** Even within a monolith, Module A MUST call Module B through an HTTP endpoint (or event channel) that has a contract in `contracts/`.
- **No backdoors.** A domain NEVER directly imports another domain's internal services, repositories, entities, or utilities. The only legal dependency path is: Caller → HTTP Client → Contract-defined endpoint → Target module's public API layer.
- **Architecture portability.** When ALL inter-domain calls go through contracts, extracting a module from a monolith into a microservice requires ZERO business logic changes — only the transport layer changes (localhost → network).

**Communication Mode Rules (Architecture-Driven):**

```yaml
# Mode selection is DERIVED from constitution.md, NOT hardcoded by developers.
# BLUEPRINT reads these fields and enforces the correct contract type per dependency.

Synchronous (Request-Response):
  contract_type: Determined by backend.communication_style
    REST (default) → OpenAPI 3.1 (contracts/openapi/)
    GraphQL → SDL (contracts/graphql/)
    gRPC → Proto3 (contracts/grpc/)
  applies_to: ALL architectures (B1-B12)
  use_when:
    - Caller needs an immediate response
    - Data query (read models)
    - Command that must confirm success before proceeding
    - Default for ALL inter-domain calls unless explicitly async

Asynchronous (Event/Message-Based):
  contract_type: AsyncAPI 2.6+ (contracts/asyncapi/)
  applies_to: Event-based topologies (B3, B6, B7, B11) OR when backend.communication_style == Event-Driven
  use_when:
    - Fire-and-forget commands (e.g., send email, log audit)
    - Domain events that multiple consumers may react to
    - Long-running processes where caller cannot wait
    - Eventual consistency is acceptable
  ALSO requires: Sync contract for the originating API endpoint (HTTP triggers the command that emits the event)
```

**Prohibited Patterns (BLOCKING violations):**

```yaml
# These patterns are detected by IMPLEMENT (🔍 REVIEW hat) and BLOCK the build.

Pattern 1 — Direct Cross-Domain Import:
  violation: Module A imports Module B's internal service/repository/entity directly
  examples:
    # ❌ PROHIBITED — direct import from another domain's internals
    import { UserService } from '../user-profile/services/user.service'
    import { OrderRepository } from '../../orders/repositories/order.repository'
    from modules.payments.services.payment_service import PaymentService
    use App\Modules\Inventory\Services\StockService;
  fix: Use HTTP client to call the contract-defined endpoint instead
  
Pattern 2 — Shared Database Access:
  violation: Module A queries Module B's database tables directly (bypassing B's API)
  examples:
    # ❌ PROHIBITED — querying another domain's tables
    SELECT * FROM user_profiles WHERE id = ?  -- called from Orders module
    UserProfile.objects.filter(id=customer_id)  -- called from Orders module
  fix: Call Module B's API endpoint that exposes the data through its contract
  exception: Read replicas or materialized views explicitly declared in design.md as "shared read model" with ADR justification

Pattern 3 — Implicit Service Locator / Global Registry:
  violation: Using a service locator or global container to resolve another domain's service at runtime
  examples:
    # ❌ PROHIBITED — resolving cross-domain service via container
    const userService = container.resolve('UserProfileService')  // from Orders module
    app.make(UserService::class)  // from Payments module
  fix: Inject an HTTP client configured for the target domain's contract

Pattern 4 — Event Without Contract:
  violation: Publishing or consuming domain events without an AsyncAPI contract defining the channel/message schema
  examples:
    # ❌ PROHIBITED — emitting events without contract
    eventBus.emit('user.created', payload)  // No asyncapi contract for this channel
  fix: Define AsyncAPI contract in contracts/asyncapi/{domain}-events/asyncapi.yaml FIRST, then implement
  applies_to: ONLY for event-based topologies (B3, B6, B7, B11) or when communication_style == Event-Driven
```

**Legal Cross-Domain Communication Patterns:**

```yaml
# ✅ LEGAL — HTTP client call to contract-defined endpoint
Pattern A — Synchronous HTTP call (ALL architectures):
  # Module Orders calls Module UserProfile via REST contract
  # Contract: contracts/openapi/user-profile/v1.yaml
  const response = await httpClient.get('/api/internal/users/{id}')
  # Or via framework HTTP module (NestJS HttpService, Django requests, Laravel Http)

Pattern B — Event publish/subscribe (Event-based topologies):
  # Module Orders publishes event per AsyncAPI contract
  # Contract: contracts/asyncapi/order-events/asyncapi.yaml  
  await eventBus.publish('order.created', { orderId, customerId, total })
  # Consumer Module Notifications subscribes per same contract

Pattern C — Shared Kernel (EXCEPTIONAL — requires ADR):
  # Shared value objects, DTOs, or constants across domains
  # MUST be in a dedicated shared/ or kernel/ directory
  # MUST have ADR justifying the shared coupling
  # MUST NOT contain business logic — only data structures
  import { Money } from '@shared/value-objects/money'  // ✅ OK with ADR
```

**Monolith-Specific Enforcement:**

For modular monolith architectures (B1-B4), inter-module communication follows the SAME contract-first rules as microservices. The transport is internal HTTP (localhost or in-process HTTP) rather than network HTTP, but the **contract MUST exist**.

```yaml
Monolith inter-module call chain:
  1. Module A needs data from Module B
  2. Check: Does a contract exist in contracts/ for Module B's capability? 
     - YES → Use HTTP client to call Module B's endpoint (internal routing)
     - NO  → ❌ BLOCK — BLUEPRINT must create the contract FIRST
  3. Module A's code uses HttpClient/HttpService to call the contract-defined path
  4. Framework routes internally (no network hop, but contract enforced)

Why this matters for monoliths:
  - Prepares codebase for future microservice extraction (zero code changes)
  - Prevents "big ball of mud" — modules cannot reach into each other's internals
  - Contract serves as documentation of module API surface
  - Type safety: Contract-generated types enforce compile-time compatibility
```

**BLUEPRINT Enforcement (Design-Time):**
- `/BLUEPRINT --start` Phase 2 Step -0.5: Inter-Domain Dependency Analysis — for EACH cross-domain call identified in `spec.feature` and `user_journey.md`, verify a contract exists or mandate its creation. Classify as sync/async per constitution.md rules.
- `/BLUEPRINT --approve` Phase 3: Validate that `design.md` "Cross-Domain Dependencies" section lists ALL inter-domain calls with their contract references. BLOCK if any dependency lacks a contract.

**IMPLEMENT Enforcement (Build-Time):**
- `🔍 REVIEW hat` Step R.1 Check #10 `[CFP-XX]`: Scans implemented code for prohibited cross-domain import patterns (Patterns 1-4 above). Uses architecture layer paths from `constitution.md` to identify module boundaries. BLOCKER if direct cross-domain import detected without corresponding HTTP contract.
- `💻 DEV hat` Phase A: CONTRACT VERIFICATION GATE verifies that ALL contracts referenced in `design.md` cross-domain dependencies exist in `contracts/`.

---

## 📊 Contract Format Selection Matrix (HTTP API EVERYWHERE)

> **CRITICAL:** ALL architectures use HTTP API communication (REST by default). Event-based topologies ALSO get AsyncAPI contracts for asynchronous messaging.

### Primary Selection (based on `backend.communication_style`)

| `constitution.md` Setting | Contract Format | Path |
|---------------------------|-----------------|------|
| `backend.communication_style: REST` (DEFAULT) | OpenAPI 3.1 | `contracts/openapi/{SLUG}/v1.yaml` |
| `backend.communication_style: GraphQL` | GraphQL SDL | `contracts/graphql/{SLUG}/schema.graphql` |
| `backend.communication_style: gRPC` | Protocol Buffers | `contracts/grpc/{SLUG}/service.proto` |
| `backend.communication_style: Event-Driven` | OpenAPI 3.1 (REST default) + AsyncAPI 2.6+ | `contracts/openapi/` + `contracts/asyncapi/` |

### Secondary Selection (Event-Based Topologies ONLY)

| Topology | Additional Contract | Purpose | Path |
|----------|---------------------|---------|------|
| B3 (DDD + Event Sourcing) | AsyncAPI 2.6+ | Domain events | `contracts/asyncapi/{SLUG}/asyncapi.yaml` |
| B6, B7, B11 (Event-Driven) | AsyncAPI 2.6+ | Inter-service events | `contracts/asyncapi/{SLUG}/asyncapi.yaml` |

### Webhook Selection (based on `backend.webhooks`)

> **Complementary to communication_style.** Webhooks do NOT replace REST/GraphQL/gRPC — they add webhook-specific contracts alongside the primary format.

| `backend.webhooks` Setting | Contract Type | Format | Path |
|---------------------------|---------------|--------|------|
| `Inbound only` | Receiver endpoints | OpenAPI 3.1 (paths) | `contracts/webhooks/inbound/{SLUG}/v1.yaml` |
| `Outbound only` | Publisher definitions | OpenAPI 3.1 (`webhooks:` section) | `contracts/webhooks/outbound/{SLUG}/v1.yaml` |
| `Both` | Receiver + Publisher | OpenAPI 3.1 (both patterns) | `contracts/webhooks/inbound/` + `contracts/webhooks/outbound/` |
| `None` | — | — | No webhook contracts generated |

**Inbound webhooks** = Our system receives events from third parties (e.g., Stripe payment events, GitHub push events). Defined as standard OpenAPI `paths:` with payload schemas for validation.

**Outbound webhooks** = Our system notifies external consumers when events occur. Uses OpenAPI 3.1 native `webhooks:` section — NOT AsyncAPI (webhooks are HTTP callbacks, not message broker events).

### Examples

```yaml
# B1-B4 Monolith variants with REST API (DEFAULT)
topology: B1  # or B2, B3, B4
backend.communication_style: REST
→ Generates:
  1. contracts/openapi/auth-oauth-login/v1.yaml    # HTTP API

# B3 DDD + Event Sourcing (REST + Events)
topology: B3
backend.communication_style: REST
→ Generates:
  1. contracts/openapi/auth-oauth-login/v1.yaml    # HTTP API
  2. contracts/asyncapi/auth-oauth-login/asyncapi.yaml  # Domain events

# B5 Microservices with REST
topology: B5
backend.communication_style: REST
→ Generates:
  1. contracts/openapi/auth-oauth-login/v1.yaml    # HTTP API

# B6 Event-Driven Microservices
topology: B6
backend.communication_style: Event-Driven
→ Generates:
  1. contracts/openapi/auth-oauth-login/v1.yaml    # HTTP API
  2. contracts/asyncapi/auth-oauth-login/asyncapi.yaml  # Inter-service events

# B5 Microservices with GraphQL
topology: B5
backend.communication_style: GraphQL
→ Generates:
  1. contracts/graphql/auth-oauth-login/schema.graphql  # GraphQL API

# gRPC communication
communication_style: gRPC
→ Generates:
  1. contracts/grpc/auth-oauth-login/service.proto  # gRPC service

# Webhook examples (complementary — added on top of primary format)

# REST + Inbound webhooks
backend.communication_style: REST
backend.webhooks: Inbound only
→ Generates:
  1. contracts/openapi/auth-oauth-login/v1.yaml              # HTTP API
  2. contracts/webhooks/inbound/stripe-payment-events/v1.yaml # Webhook receiver

# REST + Outbound webhooks
backend.communication_style: REST
backend.webhooks: Outbound only
→ Generates:
  1. contracts/openapi/order-management/v1.yaml                        # HTTP API
  2. contracts/webhooks/outbound/order-status-notifications/v1.yaml    # Webhook publisher (OpenAPI 3.1 webhooks: section)

# REST + Both webhooks
backend.communication_style: REST
backend.webhooks: Both
→ Generates:
  1. contracts/openapi/auth-oauth-login/v1.yaml              # HTTP API
  2. contracts/webhooks/inbound/stripe-payment-events/v1.yaml # Webhook receiver
  3. contracts/webhooks/outbound/order-status-notifications/v1.yaml  # Webhook publisher
```

---

## 🔧 Contract Formats by Architecture Mode

### 1. REST APIs → OpenAPI 3.1+ Specification

**Use Case:** Microservices, Public APIs, Multi-consumer systems

**Storage:** `contracts/openapi/{CONTRACT_SLUG}/v{N}.yaml`

**Example:**
```yaml
openapi: 3.1.0
info:
  title: User Management API
  version: 1.0.0
  x-feature-id: USER-001
paths:
  /api/v1/users:
    get:
      summary: List all users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 50
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserListResponse'
    post:
      summary: Create new user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UserCreateRequest'
      responses:
        '201':
          description: User created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserResponse'
components:
  schemas:
    UserCreateRequest:
      type: object
      required: [email, name]
      properties:
        email:
          type: string
          format: email
        name:
          type: string
          minLength: 2
        password:
          type: string
          minLength: 8
    UserResponse:
      type: object
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
        name:
          type: string
        createdAt:
          type: string
          format: date-time
```

---

### 2. GraphQL APIs → GraphQL Schema Definition Language (SDL)

**Use Case:** Complex data fetching, Frontend-driven data requirements

**Storage:** `contracts/graphql/{CONTRACT_SLUG}/schema.graphql`

**Example:**
```graphql
# x-feature-id: USER-003
# x-owner: backend-team
# x-design-doc: docs/spec/USER-003/design.md

"""
User profile with personal information and preferences
"""
type User {
  id: ID!
  email: String!
  name: String!
  avatar: String
  createdAt: DateTime!
  posts(first: Int = 10, after: String): PostConnection!
}

"""
Paginated list of users
"""
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  node: User!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  endCursor: String
}

input CreateUserInput {
  email: String!
  name: String!
  password: String!
}

type Mutation {
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, name: String): User!
  deleteUser(id: ID!): Boolean!
}

type Query {
  user(id: ID!): User
  users(first: Int = 10, after: String): UserConnection!
}

scalar DateTime
```

---

### 3. Modular Monolith → REST API Contracts

**Use Case:** Monolith architectures (B1-B4) where modules communicate via internal REST APIs

**Storage:** `contracts/openapi/{CONTRACT_SLUG}/v{N}.yaml` (same as microservices)

**Rationale:** 
- Uniform contract model across all architectures
- Modules expose REST APIs even within a monolith
- Facilitates future extraction to microservices
- No special TypeScript contracts — APIs are the contract

**When Generated:**
- All topologies (B1-B12) that use REST as backend.communication_style

> **Note:** Monoliths use the SAME OpenAPI contract format as microservices. See Section 1 (REST APIs) for the full example. The only difference is that in a monolith, modules call each other's REST endpoints internally rather than over the network.

**Internal Module Communication (Monolith):**
```typescript
// Module A calls Module B's internal REST endpoint
// contracts/openapi/user-profile/v1.yaml defines the contract

// src/modules/orders/services/order.service.ts
import { HttpService } from '@nestjs/axios';

export class OrderService {
  constructor(private readonly http: HttpService) {}

  async getCustomerProfile(customerId: string) {
    // Internal REST call to user-profile module
    // Contract: contracts/openapi/user-profile/v1.yaml
    return this.http.get(`/api/internal/users/${customerId}`).toPromise();
  }
}
```

---

### 4. Event-Driven → AsyncAPI 2.6+ Specification

**Use Case:** Event-Driven Microservices (B6), CQRS + Event Sourcing (B7), Broker/Pipeline (B11)

**Storage:** `contracts/asyncapi/{CONTRACT_SLUG}/asyncapi.yaml`

**Rationale:** AsyncAPI is the industry standard for documenting event-driven APIs (Kafka, RabbitMQ, NATS, etc.). It provides the same contract-first benefits as OpenAPI but for asynchronous messaging.

**Example:**
```yaml
asyncapi: 2.6.0
info:
  title: Order Events API
  version: 1.0.0
  x-feature-id: ORDER-001
  x-owner: backend-team
  x-design-doc: docs/spec/ORDER-001/design.md
  description: |
    Event-driven API for order lifecycle management.
    Publishes events when orders are created, updated, shipped, or cancelled.

servers:
  production:
    url: kafka://kafka.example.com:9092
    protocol: kafka
    description: Production Kafka cluster
  development:
    url: localhost:9092
    protocol: kafka
    description: Local Kafka (Docker Compose)

channels:
  orders.created:
    description: Emitted when a new order is placed
    publish:
      operationId: onOrderCreated
      message:
        $ref: '#/components/messages/OrderCreatedEvent'

  orders.shipped:
    description: Emitted when an order is shipped
    publish:
      operationId: onOrderShipped
      message:
        $ref: '#/components/messages/OrderShippedEvent'

  orders.cancelled:
    description: Emitted when an order is cancelled
    publish:
      operationId: onOrderCancelled
      message:
        $ref: '#/components/messages/OrderCancelledEvent'

components:
  messages:
    OrderCreatedEvent:
      name: OrderCreatedEvent
      title: Order Created
      contentType: application/json
      payload:
        $ref: '#/components/schemas/OrderCreatedPayload'
      headers:
        $ref: '#/components/schemas/CloudEventHeaders'

    OrderShippedEvent:
      name: OrderShippedEvent
      title: Order Shipped
      contentType: application/json
      payload:
        $ref: '#/components/schemas/OrderShippedPayload'

    OrderCancelledEvent:
      name: OrderCancelledEvent
      title: Order Cancelled
      contentType: application/json
      payload:
        $ref: '#/components/schemas/OrderCancelledPayload'

  schemas:
    CloudEventHeaders:
      type: object
      required: [ce_id, ce_type, ce_source, ce_time]
      properties:
        ce_id:
          type: string
          format: uuid
          description: CloudEvents ID
        ce_type:
          type: string
          description: CloudEvents type (e.g., "com.example.order.created")
        ce_source:
          type: string
          format: uri
          description: CloudEvents source
        ce_time:
          type: string
          format: date-time
          description: CloudEvents timestamp
        ce_specversion:
          type: string
          default: "1.0"

    OrderCreatedPayload:
      type: object
      required: [orderId, customerId, items, totalAmount, createdAt]
      properties:
        orderId:
          type: string
          format: uuid
        customerId:
          type: string
          format: uuid
        items:
          type: array
          items:
            $ref: '#/components/schemas/OrderItem'
        totalAmount:
          type: number
          format: decimal
        currency:
          type: string
          default: USD
        createdAt:
          type: string
          format: date-time

    OrderShippedPayload:
      type: object
      required: [orderId, trackingNumber, carrier, shippedAt]
      properties:
        orderId:
          type: string
          format: uuid
        trackingNumber:
          type: string
        carrier:
          type: string
          enum: [UPS, FedEx, DHL, USPS]
        shippedAt:
          type: string
          format: date-time

    OrderCancelledPayload:
      type: object
      required: [orderId, reason, cancelledAt]
      properties:
        orderId:
          type: string
          format: uuid
        reason:
          type: string
        refundAmount:
          type: number
          format: decimal
        cancelledAt:
          type: string
          format: date-time

    OrderItem:
      type: object
      required: [productId, quantity, unitPrice]
      properties:
        productId:
          type: string
        productName:
          type: string
        quantity:
          type: integer
          minimum: 1
        unitPrice:
          type: number
          format: decimal
```

**CloudEvents Integration:**
All events SHOULD follow the [CloudEvents](https://cloudevents.io/) specification for interoperability. The `CloudEventHeaders` schema above demonstrates the required headers.

**Protocol Support:**
- **Kafka:** `protocol: kafka` — Most common for B6, B7, B11
- **RabbitMQ:** `protocol: amqp`
- **NATS:** `protocol: nats`
- **AWS SNS/SQS:** `protocol: sns` / `protocol: sqs`

---

### 5. gRPC → Protocol Buffers (Proto3)

**Use Case:** High-performance internal service communication, cross-language microservices

**Storage:** `contracts/grpc/{CONTRACT_SLUG}/service.proto`

**Rationale:** gRPC provides strongly-typed, high-performance RPC with automatic code generation. Ideal for internal service-to-service communication where REST overhead is unacceptable.

**Example:**
```protobuf
// contracts/grpc/inventory-stock/service.proto
syntax = "proto3";

package inventory.stock.v1;

option go_package = "github.com/example/inventory/stock/v1;stockv1";
option java_package = "com.example.inventory.stock.v1";
option java_multiple_files = true;

// Feature metadata (comments parsed by tooling)
// x-feature-id: INV-001
// x-owner: inventory-team
// x-design-doc: docs/spec/INV-001/design.md

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

// ============================================================================
// Service Definition
// ============================================================================

service InventoryService {
  // Check stock availability for a product
  rpc CheckStock(CheckStockRequest) returns (CheckStockResponse);
  
  // Reserve stock for an order (idempotent with reservation_id)
  rpc ReserveStock(ReserveStockRequest) returns (ReserveStockResponse);
  
  // Release previously reserved stock
  rpc ReleaseStock(ReleaseStockRequest) returns (google.protobuf.Empty);
  
  // Stream real-time stock updates for a list of products
  rpc WatchStock(WatchStockRequest) returns (stream StockUpdate);
  
  // Bulk update stock levels (admin operation)
  rpc BulkUpdateStock(stream StockAdjustment) returns (BulkUpdateResponse);
}

// ============================================================================
// Request/Response Messages
// ============================================================================

message CheckStockRequest {
  string product_id = 1;
  string warehouse_id = 2; // Optional: specific warehouse
}

message CheckStockResponse {
  string product_id = 1;
  int32 available_quantity = 2;
  int32 reserved_quantity = 3;
  int32 total_quantity = 4;
  repeated WarehouseStock warehouse_breakdown = 5;
  google.protobuf.Timestamp last_updated = 6;
}

message WarehouseStock {
  string warehouse_id = 1;
  string warehouse_name = 2;
  int32 quantity = 3;
}

message ReserveStockRequest {
  string reservation_id = 1; // Idempotency key
  string product_id = 2;
  int32 quantity = 3;
  string order_id = 4;
  int32 ttl_seconds = 5; // Reservation expiry (default: 900)
}

message ReserveStockResponse {
  string reservation_id = 1;
  ReservationStatus status = 2;
  int32 reserved_quantity = 3;
  google.protobuf.Timestamp expires_at = 4;
}

enum ReservationStatus {
  RESERVATION_STATUS_UNSPECIFIED = 0;
  RESERVATION_STATUS_CONFIRMED = 1;
  RESERVATION_STATUS_PARTIAL = 2;
  RESERVATION_STATUS_INSUFFICIENT_STOCK = 3;
  RESERVATION_STATUS_ALREADY_EXISTS = 4;
}

message ReleaseStockRequest {
  string reservation_id = 1;
}

message WatchStockRequest {
  repeated string product_ids = 1;
}

message StockUpdate {
  string product_id = 1;
  int32 available_quantity = 2;
  StockChangeReason reason = 3;
  google.protobuf.Timestamp timestamp = 4;
}

enum StockChangeReason {
  STOCK_CHANGE_REASON_UNSPECIFIED = 0;
  STOCK_CHANGE_REASON_SALE = 1;
  STOCK_CHANGE_REASON_RESTOCK = 2;
  STOCK_CHANGE_REASON_RESERVATION = 3;
  STOCK_CHANGE_REASON_RELEASE = 4;
  STOCK_CHANGE_REASON_ADJUSTMENT = 5;
}

message StockAdjustment {
  string product_id = 1;
  string warehouse_id = 2;
  int32 quantity_delta = 3; // Positive = add, Negative = remove
  string reason = 4;
}

message BulkUpdateResponse {
  int32 successful_updates = 1;
  int32 failed_updates = 2;
  repeated FailedUpdate failures = 3;
}

message FailedUpdate {
  string product_id = 1;
  string error_message = 2;
}
```

**Proto Best Practices:**
- **Versioning:** Use package versioning (`v1`, `v2`) for breaking changes
- **Field Numbers:** Never reuse deleted field numbers (reserve them)
- **Enums:** Always include `_UNSPECIFIED = 0` as first value
- **Streaming:** Use server/client/bidirectional streaming for real-time data

**Code Generation:**
```bash
# Generate code from proto (add to Makefile or scripts/)
protoc --go_out=. --go-grpc_out=. contracts/grpc/*/service.proto
protoc --python_out=. --grpc_python_out=. contracts/grpc/*/service.proto
protoc --ts_out=. contracts/grpc/*/service.proto
```

---

### 6. Webhooks → OpenAPI 3.1 (Inbound & Outbound)

**Use Case:** Third-party integrations (inbound), platform notifications (outbound)

**Prerequisite:** `backend.webhooks != None` (configured via Q8.1 in Smart Discovery)

#### Inbound Webhooks (Receiver Endpoints)

**Storage:** `contracts/webhooks/inbound/{CONTRACT_SLUG}/v{N}.yaml`

Inbound webhooks are standard REST endpoints that receive HTTP callbacks from external systems. Defined as regular OpenAPI `paths:` with payload schemas for input validation.

**Example:**
```yaml
openapi: 3.1.0
info:
  title: Stripe Payment Events Webhook Receiver
  version: 1.0.0
  x-feature-id: FEAT-042
paths:
  /webhooks/stripe:
    post:
      operationId: receiveStripeEvent
      summary: Receive Stripe payment webhook events
      security:
        - webhookSignature: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/StripeEvent'
      responses:
        '200':
          description: Webhook received successfully
        '401':
          description: Invalid webhook signature
components:
  schemas:
    StripeEvent:
      type: object
      required: [id, type, data]
      properties:
        id:
          type: string
        type:
          type: string
          enum: [payment_intent.succeeded, payment_intent.failed, charge.refunded]
        data:
          type: object
  securitySchemes:
    webhookSignature:
      type: apiKey
      in: header
      name: Stripe-Signature
```

#### Outbound Webhooks (Publisher Definitions)

**Storage:** `contracts/webhooks/outbound/{CONTRACT_SLUG}/v{N}.yaml`

Outbound webhooks use the OpenAPI 3.1 native `webhooks:` section to define what our system sends to external subscribers. This is NOT AsyncAPI — webhooks are HTTP callbacks, not message broker events.

**Example:**
```yaml
openapi: 3.1.0
info:
  title: Order Status Notifications
  version: 1.0.0
  x-feature-id: FEAT-055
webhooks:
  orderStatusChanged:
    post:
      operationId: notifyOrderStatusChange
      summary: Notify subscriber when order status changes
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/OrderStatusEvent'
      responses:
        '200':
          description: Webhook delivered successfully
components:
  schemas:
    OrderStatusEvent:
      type: object
      required: [event_id, order_id, status, timestamp]
      properties:
        event_id:
          type: string
          format: uuid
        order_id:
          type: string
        status:
          type: string
          enum: [created, confirmed, shipped, delivered, cancelled]
        timestamp:
          type: string
          format: date-time
```

**Webhook vs AsyncAPI — When to use which:**
| Pattern | Use | Format | Transport |
|---------|-----|--------|-----------|
| **Inbound webhook** | Receive HTTP callbacks from third parties | OpenAPI `paths:` | HTTP POST |
| **Outbound webhook** | Send HTTP callbacks to external subscribers | OpenAPI 3.1 `webhooks:` | HTTP POST |
| **AsyncAPI events** | Internal async messaging between services | AsyncAPI 2.6+ | Message broker (Kafka, RabbitMQ, SQS) |

---

## 🌐 SSR Architecture Pattern (Internal HTTP)

### Principle: Frontend Always Calls Backend via HTTP

**Mandate:** Even in Server-Side Rendering (Next.js, SvelteKit, etc.), frontend MUST call backend via HTTP. **NO direct server-side imports** of backend services.

**Rationale:**
- **True Separation:** Enables independent scaling and deployment later
- **Contract Enforcement:** HTTP layer validates all API contracts
- **Observability:** All API calls are logged/traced (even internal ones)
- **Flexibility:** Migrate from Monolith to Microservices without refactoring

### Configuration: Internal API Port

**Environment Variables:**
```bash
# .env.example
# Internal API endpoint (used by SSR server-side calls)
INTERNAL_API_PORT=3001
INTERNAL_API_URL=http://localhost:${INTERNAL_API_PORT}

# Mock API endpoint (used during development with mock servers)
MOCK_API_PORT=4010
MOCK_API_URL=http://localhost:${MOCK_API_PORT}

# Public API endpoint (used by browser-side calls)
NEXT_PUBLIC_API_URL=https://api.example.com
```

### Example: Next.js App Router with Server Component

**❌ WRONG APPROACH (Direct Import):**
```typescript
// app/users/page.tsx (Server Component)
import { UserService } from '@/backend/services/users'; // ❌ Violates separation!

export default async function UsersPage() {
  const userService = new UserService();
  const users = await userService.listUsers(); // ❌ No HTTP contract validation
  return <UserList users={users} />;
}
```

**✅ CORRECT APPROACH (HTTP Call):**
```typescript
// app/users/page.tsx (Server Component)
// Types generated from OpenAPI spec via openapi-typescript
import type { components } from '@/generated/api-types';
type UserListResponse = components['schemas']['UserListResponse'];

async function fetchUsers(): Promise<UserListResponse> {
  const apiUrl = process.env.INTERNAL_API_URL || 'http://localhost:3001';
  const response = await fetch(`${apiUrl}/api/v1/users`, {
    cache: 'no-store', // or 'force-cache' depending on needs
  });
  if (!response.ok) throw new Error('Failed to fetch users');
  return response.json();
}

export default async function UsersPage() {
  const users = await fetchUsers(); // ✅ HTTP call, contract validated
  return <UserList users={users.data} />;
}
```

---

## 🔄 Contract Versioning Strategy

### Principle: Separate Files for Breaking Changes

**Why Separate Files:**
- **Clear History:** Easy to see what changed between versions
- **Parallel Support:** Old and new versions can coexist during migration
- **Safe Rollback:** If v2 fails, roll back to v1 without restoring from Git

### Naming Convention
```
contracts/openapi/{CONTRACT_SLUG}/v1.yaml     # Initial version
contracts/openapi/{CONTRACT_SLUG}/v2.yaml     # Breaking changes
contracts/openapi/{CONTRACT_SLUG}/v3.yaml     # More breaking changes
```

### Breaking vs. Non-Breaking Changes

#### Breaking Changes (Require New Version)
- ❌ Removing endpoints or fields
- ❌ Renaming endpoints or fields
- ❌ Changing field types (string → number)
- ❌ Making optional fields required
- ❌ Changing status codes for existing operations

#### Non-Breaking Changes (Update Same Version)
- ✅ Adding new optional fields
- ✅ Adding new endpoints
- ✅ Expanding enum values
- ✅ Making required fields optional
- ✅ Adding default values

### Deprecation Policy
1. **Announce:** Add `deprecated: true` to OpenAPI/GraphQL schema
2. **Warning Period:** Minimum 6 months notice before removal
3. **Monitor:** Track usage via API gateway/analytics
4. **Sunset:** Remove only when usage drops to <1% of requests

### Example (OpenAPI Deprecation)
```yaml
paths:
  /api/v1/users/{id}:
    get:
      deprecated: true
      summary: "[DEPRECATED] Use /api/v2/users/{id} instead"
      description: |
        This endpoint will be removed on 2026-12-31.
        Migrate to v2 for enhanced user profiles.
```

---

## 🐳 Mock Server Setup (Language-Agnostic)

### Architecture: Docker Compose

**Rationale:**
- **Language Independence:** Works with Python, Go, Java, Node.js, any backend
- **Isolation:** Mock servers run in containers, no npm/pip conflicts
- **Parallel Development:** Frontend team can start before backend is ready

### Auto-Generated Docker Compose

**File:** `docker-compose.mock.yml`

```yaml
version: '3.8'

services:
  # OpenAPI Mock Server (uses Prism)
  openapi-mock:
    image: stoplight/prism:latest
    container_name: api-mock-server
    command: mock -h 0.0.0.0 -p 4010 /contracts/combined-openapi.yaml
    ports:
      - "${MOCK_API_PORT:-4010}:4010"
    volumes:
      - ./contracts/openapi:/contracts:ro
    environment:
      - PRISM_LOG_LEVEL=info
    networks:
      - dev-network

  # GraphQL Mock Server (uses graphql-tools)
  graphql-mock:
    image: node:20-alpine
    container_name: graphql-mock-server
    working_dir: /app
    command: sh -c "npm install -g @graphql-tools/mock && node /app/mock-server.js"
    ports:
      - "4011:4011"
    volumes:
      - ./contracts/graphql:/app/schemas:ro
      - ./scripts/graphql-mock-server.js:/app/mock-server.js:ro
    networks:
      - dev-network

  # gRPC Mock Server (uses grpc-mock)
  grpc-mock:
    image: tkpd/gripmock:latest
    container_name: grpc-mock-server
    command: /proto/service.proto
    ports:
      - "4012:4770"  # gRPC
      - "4013:4771"  # Admin API
    volumes:
      - ./contracts/grpc:/proto:ro
    networks:
      - dev-network

networks:
  dev-network:
    driver: bridge
```

### Auto-Start Integration

**Add to `package.json` (Node.js projects):**
```json
{
  "scripts": {
    "dev": "concurrently \"npm run dev:app\" \"npm run dev:mocks\"",
    "dev:app": "next dev",
    "dev:mocks": "docker-compose -f docker-compose.mock.yml up",
    "dev:mocks:down": "docker-compose -f docker-compose.mock.yml down"
  }
}
```

**Or add to `Makefile` (language-agnostic):**
```makefile
.PHONY: dev
dev:
	@docker-compose -f docker-compose.mock.yml up -d
	@echo "Mock servers started. API: http://localhost:4010"
	@npm run dev  # or python -m uvicorn, go run, etc.

.PHONY: dev-down
dev-down:
	@docker-compose -f docker-compose.mock.yml down
```

---

## ✅ Contract Validation & Linting

### Pre-Commit Hooks (Immediate Feedback)

**File:** `.pre-commit-config.yaml`

```yaml
repos:
  # OpenAPI Linting (Spectral)
  - repo: https://github.com/stoplightio/spectral
    rev: v6.11.0
    hooks:
      - id: spectral
        name: Lint OpenAPI Contracts
        files: ^contracts/openapi/.*\.ya?ml$
        args: ['lint', '--ruleset', '.spectral.yaml']

  # GraphQL Schema Linting
  - repo: local
    hooks:
      - id: graphql-schema-linter
        name: Lint GraphQL Schemas
        entry: npx graphql-schema-linter
        language: node
        files: ^contracts/graphql/.*\.graphql$
        additional_dependencies: ['graphql-schema-linter']

  # gRPC Protocol Buffers Linting
  - repo: local
    hooks:
      - id: buf-lint
        name: Lint Protocol Buffers
        entry: buf lint
        language: system
        files: ^contracts/grpc/.*\.proto$

  # AsyncAPI Schema Validation
  - repo: local
    hooks:
      - id: asyncapi-validate
        name: Validate AsyncAPI Specs
        entry: npx @asyncapi/cli validate
        language: node
        files: ^contracts/asyncapi/.*\.ya?ml$
        additional_dependencies: ['@asyncapi/cli']
```

### Spectral Rules for OpenAPI

**File:** `.spectral.yaml`

```yaml
extends: [[spectral:oas, all]]

rules:
  # Enforce x-feature-id metadata
  info-x-feature-id:
    description: OpenAPI info must include x-feature-id
    given: $.info
    severity: error
    then:
      field: x-feature-id
      function: truthy

  # Enforce versioning in URL
  path-version:
    description: Paths must include /v{N}/ segment
    given: $.paths[*]~
    severity: error
    then:
      function: pattern
      functionOptions:
        match: ^/api/v\d+/

  # Require pagination for list endpoints
  pagination-required:
    description: GET endpoints returning arrays must support pagination
    given: $.paths[*].get.responses.200.content.application/json.schema
    severity: warn
    then:
      - field: properties.meta
        function: truthy
      - field: properties.data
        function: truthy
```

---

## 🔬 CI/CD Contract Validation

### Integration with Existing Scripts

**Add to:** `scripts/security-scan.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Existing flags
SEM_GREP=0
GITLEAKS=0
VALIDATE_CONTRACTS=0  # NEW FLAG
DRY_RUN=${DRY_RUN:-1}

while [ $# -gt 0 ]; do
  case "$1" in
    --semgrep) SEM_GREP=1 ;;
    --gitleaks) GITLEAKS=1 ;;
    --validate-contracts) VALIDATE_CONTRACTS=1 ;;  # NEW
    --apply) DRY_RUN=0 ;;
  esac
  shift
done

# NEW: Contract validation
if [ "$VALIDATE_CONTRACTS" -eq 1 ]; then
  echo "🔍 Validating contracts..."
  
  # OpenAPI validation
  if [ -d "contracts/openapi" ]; then
    echo "  ├─ OpenAPI specs..."
    npx @stoplight/spectral-cli lint "contracts/openapi/**/*.yaml" || exit 1
  fi
  
  # GraphQL validation
  if [ -d "contracts/graphql" ]; then
    echo "  ├─ GraphQL schemas..."
    npx graphql-schema-linter "contracts/graphql/**/*.graphql" || exit 1
  fi
  
  # gRPC validation (Protocol Buffers)
  if [ -d "contracts/grpc" ]; then
    echo "  ├─ gRPC Protocol Buffers..."
    buf lint contracts/grpc/ || exit 1
  fi
  
  # AsyncAPI validation (Event schemas)
  if [ -d "contracts/asyncapi" ]; then
    echo "  ├─ AsyncAPI specs..."
    npx @asyncapi/cli validate "contracts/asyncapi/**/*.yaml" || exit 1
  fi
  
  echo "✅ All contracts valid"
fi

# Existing semgrep/gitleaks logic...
```

### GitHub Actions Workflow

**File:** `.github/workflows/contract-validation.yml`

```yaml
name: Contract Validation

on:
  pull_request:
    paths:
      - 'contracts/**'
  push:
    branches: [main, develop]
    paths:
      - 'contracts/**'

jobs:
  validate-contracts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      
      - name: Install validators
        run: |
          npm install -g @stoplight/spectral-cli
          npm install -g graphql-schema-linter
      
      - name: Validate OpenAPI
        if: hashFiles('contracts/openapi/**/*.yaml') != ''
        run: spectral lint "contracts/openapi/**/*.yaml"
      
      - name: Validate GraphQL
        if: hashFiles('contracts/graphql/**/*.graphql') != ''
        run: graphql-schema-linter "contracts/graphql/**/*.graphql"
      
      - name: Validate gRPC
        if: hashFiles('contracts/grpc/**/*.proto') != ''
        run: buf lint contracts/grpc/

      - name: Validate AsyncAPI
        if: hashFiles('contracts/asyncapi/**/*.yaml') != ''
        run: npx @asyncapi/cli validate "contracts/asyncapi/**/*.yaml"
```

---

## 📋 CRUD-First API Design Pattern

### Principle: Start with CRUD, Extend as Needed

**Rationale:**
- **80/20 Rule:** Most features require basic CRUD operations
- **Predictability:** Consistent API patterns reduce cognitive load
- **Scaffolding:** Auto-generate CRUD contracts during materialization

### Standard CRUD Endpoints

For resource `{resource}` (e.g., `users`, `products`, `orders`):

| Operation | HTTP Method | Endpoint | Description |
|-----------|-------------|----------|-------------|
| **Create** | POST | `/api/v1/{resource}` | Create new resource |
| **Read (List)** | GET | `/api/v1/{resource}` | Get paginated list |
| **Read (Single)** | GET | `/api/v1/{resource}/{id}` | Get single resource by ID |
| **Update (Full)** | PUT | `/api/v1/{resource}/{id}` | Replace entire resource |
| **Update (Partial)** | PATCH | `/api/v1/{resource}/{id}` | Update specific fields |
| **Delete** | DELETE | `/api/v1/{resource}/{id}` | Soft/hard delete resource |

### Extension Patterns (Beyond CRUD)

**1. Custom Actions (RPC-style)**
```
POST /api/v1/users/{id}/verify-email
POST /api/v1/orders/{id}/cancel
POST /api/v1/payments/{id}/refund
```

**2. Nested Resources**
```
GET /api/v1/users/{userId}/orders
GET /api/v1/orders/{orderId}/line-items
```

**3. Bulk Operations**
```
POST /api/v1/users/bulk-create
PATCH /api/v1/products/bulk-update
DELETE /api/v1/orders/bulk-delete
```

**4. Search & Filtering**
```
GET /api/v1/users?search=john&status=active&role=admin
GET /api/v1/products?category=electronics&priceMin=100&priceMax=500
```

### Auto-Generated CRUD Contract Template

During `/BLUEPRINT --start`, the ARCH hat generates contracts using this base template:

**File:** `contracts/openapi/{CONTRACT_SLUG}/v1.yaml`

```yaml
openapi: 3.1.0
info:
  title: {{RESOURCE_NAME}} API
  version: 1.0.0
  x-feature-id: {{FEATURE_ID}}
  x-owner: backend-team

paths:
  /api/v1/{{resource_plural}}:
    get:
      operationId: list{{Resource}}s
      summary: List {{resource_plural}}
      # x-serverless-handler: src/handlers/{{resource_plural}}.list    # ← Include when architecture == B9
      # x-serverless-memory: 256                                        # ← Sized per feature (list = higher payload)
      parameters:
        - name: page
          in: query
          schema: { type: integer, default: 1 }
        - name: limit
          in: query
          schema: { type: integer, default: 50 }
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/{{Resource}}ListResponse'
    post:
      operationId: create{{Resource}}
      summary: Create {{resource_singular}}
      # x-serverless-handler: src/handlers/{{resource_plural}}.create  # ← Include when architecture == B9
      # x-serverless-memory: 128                                        # ← Sized per feature (create = standard)
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/{{Resource}}CreateRequest'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/{{Resource}}Response'

  /api/v1/{{resource_plural}}/{id}:
    get:
      operationId: get{{Resource}}
      summary: Get {{resource_singular}} by ID
      # x-serverless-handler: src/handlers/{{resource_plural}}.get     # ← Include when architecture == B9
      # x-serverless-memory: 128                                        # ← Sized per feature (get = lightweight)
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/{{Resource}}Response'
    put:
      operationId: replace{{Resource}}
      summary: Replace {{resource_singular}}
      # x-serverless-handler: src/handlers/{{resource_plural}}.replace # ← Include when architecture == B9
      # x-serverless-memory: 128                                        # ← Sized per feature
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/{{Resource}}UpdateRequest'
      responses:
        '200':
          description: Success
    patch:
      operationId: update{{Resource}}
      summary: Update {{resource_singular}} (partial)
      # x-serverless-handler: src/handlers/{{resource_plural}}.update  # ← Include when architecture == B9
      # x-serverless-memory: 128                                        # ← Sized per feature
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/{{Resource}}PatchRequest'
      responses:
        '200':
          description: Success
    delete:
      operationId: delete{{Resource}}
      summary: Delete {{resource_singular}}
      # x-serverless-handler: src/handlers/{{resource_plural}}.delete  # ← Include when architecture == B9
      # x-serverless-memory: 128                                        # ← Sized per feature
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
      responses:
        '204':
          description: Deleted

components:
  schemas:
    {{Resource}}CreateRequest:
      type: object
      required: []  # TODO: Add required fields
      properties: {}  # TODO: Add fields

    {{Resource}}UpdateRequest:
      type: object
      properties: {}  # TODO: Add fields

    {{Resource}}PatchRequest:
      type: object
      properties: {}  # TODO: Add optional fields

    {{Resource}}Response:
      type: object
      properties:
        id: { type: string, format: uuid }
        createdAt: { type: string, format: date-time }
        updatedAt: { type: string, format: date-time }
        # TODO: Add domain fields

    {{Resource}}ListResponse:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/{{Resource}}Response'
        meta:
          type: object
          properties:
            page: { type: integer }
            limit: { type: integer }
            total: { type: integer }
            totalPages: { type: integer }
```

---

## 🌉 Contract → Infrastructure Bridge (Serverless B9)

> **Applies to:** Projects with `architecture.primary == B9` (Serverless).
> **Purpose:** Define how OpenAPI contracts drive serverless function declarations in IaC, closing the gap between contract-first development and infrastructure-as-code.

### The Bridge Pattern

```
OpenAPI Contract                    design.md Section 5              IaC (SAM/CDK/Serverless)
─────────────────                   ─────────────────────            ───────────────────────
paths:                              resources:                       Resources:
  /api/v1/auth/login:     ──►        - id: auth-login-fn    ──►       AuthLoginFunction:
    post:                               type: function                   Type: AWS::Serverless::Function
      x-serverless-handler:             handler: src/handlers/           Properties:
        src/handlers/auth.login           auth.login                       Handler: src/handlers/auth.login
      x-serverless-memory: 512          memory_mb: 512                     MemorySize: 512
                                        trigger: api-gateway               Events:
                                        contract_slug: auth-oauth            PostLogin:
                                        endpoints:                             Type: Api
                                          - "POST /auth/login"                 Properties:
                                                                                 Path: /auth/login
                                                                                 Method: post
```

### Derivation Rules (BLUEPRINT → design.md Section 5)

When BLUEPRINT (🏗️ ARCH hat) generates `design.md` for a B9 project:

1. **Read** `contracts/openapi/{CONTRACT_SLUG}/v1.yaml`
2. **For EACH operation** in `paths`:
   - Extract `x-serverless-handler` → `handler`
   - Extract `x-serverless-memory` → `memory_mb` (REQUIRED — sized per feature workload by BLUEPRINT)
   - Extract `x-serverless-timeout` → `timeout_seconds` (default: 30)
   - Resolve `runtime`: IF `x-serverless-runtime` present → use it (function-specific override). ELSE → derive from `constitution.md → backend.runtime` (mapped to cloud-native format: Python 3.12 → `python3.12`, Node.js 20 → `nodejs20.x`, Go 1.x → `provided.al2023`)
3. **Group** handlers by file module:
   - If multiple operations share the same handler file (e.g., `src/handlers/auth.*`), generate ONE `type: function` resource with multiple `endpoints`
   - If handler files differ, generate separate function resources
4. **Emit** `type: function` entries in Section 5.1 with all serverless fields + `contract_slug` + `endpoints` list

### Derivation Rules (DEVOPS → IaC)

When DEVOPS reads `design.md Section 5` and encounters `type: function` resources:

1. **Map** each function resource to IaC construct using `iac_descriptor`:
   - SAM → `AWS::Serverless::Function` in `template.yaml`
   - CDK → `new lambda.Function()` construct
   - Serverless Framework → `functions:` in `serverless.yml`
2. **Generate** API Gateway integration from `trigger: api-gateway` + `endpoints` list
3. **Link** function permissions to other resources in Section 5 (databases, queues, etc.)
4. **Apply** environment-specific overrides from `devops_plan.md`

### Spectral Validation Rule (B9 Projects)

```yaml
# .spectral.yml — added when architecture == B9
rules:
  serverless-handler-required:
    description: All operations must have x-serverless-handler in B9 architecture
    severity: error
    given: "$.paths[*][get,post,put,patch,delete]"
    then:
      field: x-serverless-handler
      function: truthy
  serverless-memory-required:
    description: All operations must declare x-serverless-memory (sized per feature workload)
    severity: error
    given: "$.paths[*][get,post,put,patch,delete]"
    then:
      field: x-serverless-memory
      function: truthy
```

---

## 🔒 Enforcement & Escape Hatches

### Mandatory Checkpoints

1. **Blueprint Agent (`/BLUEPRINT --start`):**
   - MUST generate contract artifact before approval
   - Contract types: OpenAPI `.yaml`, GraphQL `.graphql`, gRPC `.proto`, or AsyncAPI `.yaml`
   - Approval blocked if contract missing

2. **Implementation Agent (`/IMPLEMENT --plan`):**
   - MUST verify contract exists before creating implementation plan
   - Can challenge via `/IMPLEMENT --refine` if contract blocks implementation

3. **QA Agent (`/QA --verify`):**
   - MUST validate implementation matches contract
   - Uses spectral/graphql-inspector/ts-morph for automated checks

### Escape Hatches (Require ADR)

Scenarios where Contract-First can be deferred:

1. **MVP/Prototypes:** Implementation-first allowed for rapid validation (max 2 weeks)
2. **Spike/Discovery Features:** Defer contract until domain model stabilizes
3. **GraphQL Projects:** Schema-first (not OpenAPI) is the contract

**Process:**
1. Architect proposes exception during `--design`
2. Logs ADR documenting rationale
3. Developer implements with understanding that contract is debt
4. Next refinement cycle MUST formalize contract

---

## 📚 See Also

- `.context/constitution.md` § Contract-First Development
- `.context/agents/BLUEPRINT.AGENT.MD` § Contract Generation
- `.context/agents/IMPLEMENT.AGENT.MD` § Contract Validation
- `.context/rules/api-standards.md` § REST/GraphQL conventions
- `.context/rules/protected-code.md` § Never modify framework contracts

---

## 🎯 Summary

**Contract-First is the default** for all API boundaries:
- **OpenAPI** for REST APIs (ALL architectures - default)
- **GraphQL Schema** for GraphQL projects
- **gRPC Protocol Buffers** for gRPC communication
- **AsyncAPI** for Event-Driven topologies (B3, B6, B7, B11)

**SSR always uses HTTP** (internal localhost calls, never direct imports)

**Traceability via hybrid approach** (namespace + metadata + feature_map.md)

**Validation at multiple layers:**
- Pre-commit hooks (spectral, graphql-schema-linter)
- CI/CD pipeline (automated contract checks)
- QA agent (implementation-contract alignment)

**Escape hatches exist** (ADR required for MVP/prototypes/spikes)
