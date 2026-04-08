---
description: "API standards — contract-first design, OpenAPI/GraphQL/gRPC/AsyncAPI conventions, versioning, error responses. Applied when editing API contracts."
applyTo: "**/contracts/**,**/*.{openapi,graphql,proto,asyncapi}.*"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Contract-First Development & API Governance

> **Auto-generated from** `docs/setup.md` decisions  
> **Scope:** REST, GraphQL, gRPC  
> **Contract Source of Truth:** `contracts/` directory

## REST Standards
- Resource naming: nouns, plural (`/users`, `/users/{id}`)
- HTTP verbs: GET (read), POST (create), PUT (replace), PATCH (partial), DELETE (remove)
- Status codes: 2xx success, 4xx client errors, 5xx server errors; use 422 for validation
- Pagination: `limit`, `offset` or `cursor` with `next`/`prev` tokens
- Sorting & filtering: explicit query params; no implicit ordering
- Errors: machine-readable structure `{ code, message, details, trace_id }`

## GraphQL Standards
- Schema-first; no implicit any/JSON scalar usage
- Avoid N+1 via dataloaders/resolvers batching
- Depth limiting and query cost analysis enabled
- Versioning via deprecation directives and `@inaccessible` for breaking changes

## API Versioning
- REST: URL versioning (`/v1/`) default; avoid breaking changes inside version
- GraphQL: schema deprecation and additive changes; breaking changes require new major version
- gRPC: package versioning and backwards-compatible field evolution (no field re-use)

## Documentation & Contracts
- OpenAPI/Swagger required for REST; GraphQL schema SDL committed
- Contract validation in CI (`spectral`, `graphql-schema-linter`)
- Mock servers: `contracts/mocks` driven by contracts for consumer testing

## Security & Auth
- Auth patterns: JWT/OAuth2 preferred; mTLS for service-to-service in production
- Rate limiting required for public/external APIs; include 429 handling contractually
- Input validation at boundary (zod/pydantic/schema validation)
- Logging: include `trace_id`, `feature_id`, `user_id` (masked where required)

## Internationalization & Content Negotiation

> **Scope:** {{I18N_SCOPE}} <!-- None | Basic | Full | Enterprise -->

{{#if I18N_SCOPE != "None"}}
### Request Headers
- `Accept-Language`: Client preferred locales (e.g., `es-ES, es;q=0.9, en;q=0.8`)
- `X-Timezone`: Client timezone for date/time formatting (e.g., `Europe/Madrid`)
- `X-Currency`: Preferred currency code (e.g., `EUR`, `USD`) - if {{I18N_CURRENCY_STRATEGY}} != "Locale-bound"

### Response Headers
- `Content-Language`: Actual response language (e.g., `es-ES`)
- Include in error responses for consistent UX

### Locale Resolution Order
1. Explicit `Accept-Language` header
2. User profile preference (if authenticated)
3. Geo-IP detection (optional, for anonymous users)
4. Default: `{{I18N_DEFAULT_LOCALE}}`

### Response Formatting
- **Dates:** ISO 8601 format in responses (`2026-02-04T15:30:00Z`)
- **Numbers:** Unformatted (client-side formatting responsibility)
- **Currency amounts:** Store and return in smallest unit (cents) with currency code
  ```json
  { "amount": 2999, "currency": "EUR" }  // €29.99
  ```

### Localized Error Messages
- Error `message` field should be localized based on `Accept-Language`
- Error `code` field remains constant (machine-readable)
  ```json
  {
    "code": "VALIDATION_REQUIRED",
    "message": "El campo email es obligatorio",  // Localized
    "field": "email"
  }
  ```

### OpenAPI/Contract Specification
- Document supported locales in API spec
- Include `Accept-Language` in request headers schema
- Document currency/timezone handling in endpoints that use them
{{else}}
- **Not applicable:** Project configured without internationalization support.
{{/if}}

## Further Reading
- RESTful API Best Practices
- GraphQL Best Practices
- `.context/rules/contract-first-policy.md`
