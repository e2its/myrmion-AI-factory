# API contracts — OpenAPI and AsyncAPI

Load this file if the PR touches API contracts (`has_openapi: true` or `has_asyncapi: true`), or if it touches endpoint/handler/event code without updating the spec (BLOCKER case).

## Master rule

**The contract is the source of truth**. If the code changes a public endpoint or a published event but the spec doesn't change, that's a blocker — the spec stops reflecting reality and consumers break without warning.

## OpenAPI 3.x — synchronous

### Required validation

Before any semantic analysis, validate that the spec is valid:

```bash
# using spectral (recommended)
npx @stoplight/spectral-cli lint openapi.yaml

# or redocly
npx @redocly/cli lint openapi.yaml
```

If validation fails → BLOCKER. An invalid spec cannot be merged.

### Breaking change detection with `oasdiff`

```bash
# Compare PR version against main
git show main:openapi.yaml > /tmp/openapi.base.yaml
oasdiff breaking /tmp/openapi.base.yaml openapi.yaml
oasdiff changelog /tmp/openapi.base.yaml openapi.yaml
```

Cases classified as breaking by `oasdiff` → skill analysis:

| Change | Default severity |
|---|---|
| Endpoint removed | Blocker (unless prior documented deprecation) |
| New required parameter in request | Blocker |
| Field removed from response | Blocker |
| Field type changed incompatibly (string→int) | Blocker |
| Success status code changed | Blocker |
| Auth scheme changed (none to required, or bearer to oauth2) | Blocker |
| New enum value in request (may break client validation) | Important |
| Header removed | Important |
| Description / summary improved | Nit (positive) |

When breaking changes exist, **require**:

1. Major version bump in `info.version` (semver) or new versioned URL (`/v2/...`).
2. Note in CHANGELOG under "Breaking" or "Changed".
3. Migration guide in `docs/migrations/` with examples.
4. Deprecation policy if the old endpoint stays temporarily (`Sunset`, `Deprecation` headers).

### Spec quality (not breaking but important)

- Every operation has a unique `operationId`.
- Every operation has `summary` and `description`.
- Every response has a `description`.
- Standardized errors (RFC 7807 Problem Details is recommended).
- Reusable schemas via `$ref`, not duplicated.
- Examples (`examples`) on operations and critical schemas.
- `tags` consistent with API organization.
- Auth declared at operation or global level.

## AsyncAPI 3.x — asynchronous

### Required validation

```bash
npx @asyncapi/cli validate asyncapi.yaml
```

If it fails → BLOCKER.

### Change detection

AsyncAPI doesn't have tooling as mature as `oasdiff`, but there are options:

```bash
# basic diff
git diff main -- asyncapi.yaml

# semantic comparison (community project)
npx @asyncapi/diff main:asyncapi.yaml asyncapi.yaml
```

### Event-specific rules

| Change | Severity |
|---|---|
| Channel/topic removed | Blocker |
| Message in channel changes its schema incompatibly | Blocker |
| New required field in payload | Blocker |
| Field removed from payload (consumers read it) | Blocker |
| Type change in payload field | Blocker |
| Event type versioning (`com.company.domain.entity.action.v1` → `v2`) | OK if both versions coexist during the grace period |
| New optional field in payload | Not breaking |
| Description improved | Nit |

### CloudEvents envelope

If the team uses CloudEvents 1.0 as envelope:

- `id`, `source`, `specversion`, `type` are required.
- `type` must follow the convention `<reverse-dns>.<domain>.<entity>.<action>.<version>`.
- `subject` recommended to identify the affected resource.
- `datacontenttype` must be declared if not JSON.
- `time` in RFC 3339.

### Payload schema

Regardless of the envelope, the event `data` must have a versioned schema:

- JSON Schema, Avro, or Protobuf.
- Registered in a Schema Registry (Confluent, Apicurio) if Kafka is used.
- Compatibility policy declared (BACKWARD is the most common).
- Any change that breaks the compatibility policy → BLOCKER.

## Special case: code without spec

If the diff touches code that clearly exposes a public API (files under `src/api/`, `controllers/`, decorators like `@app.route`, `@RestController`, `@Controller`, `@MessageHandler`, etc.) but does NOT touch any `openapi.*` or `asyncapi.*`:

→ **Automatic BLOCKER** with message:
> "A public endpoint is modified in `<file>` but the corresponding spec is not updated. The spec must be the source of truth — update it or explain why this change does not affect the public contract."

Exception: if the PR description explicitly declares "internal-only" or the endpoint is marked as internal by project convention.

## Recommended deprecation policy

When an endpoint or event is to be removed:

1. **Version N**: mark as `deprecated: true` in the spec, add `x-sunset-date` to the operation.
2. **Version N+1**: include `Deprecation: true` and `Sunset: <date>` headers in responses.
3. **Grace period**: minimum 1 minor release, ideally 2 (3-6 months).
4. **Communication**: changelog + email to known consumers + banner in docs.
5. **Version N+M**: effective removal.

Skipping any of these steps without justification → IMPORTANT minimum, BLOCKER if it's an external public API.
