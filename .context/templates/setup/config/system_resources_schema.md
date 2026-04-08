---
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial schema version"
---

# System Resources Configuration Schema

## Purpose
This document defines the **canonical schema** for `/config/system_resources.json`, the single source of truth for all external integrations, internal endpoints, and infrastructure resources.

## Usage Instructions

### When to Use This Template
- **During `/SETUP --generate`**: Create `/config/system_resources.json` with this schema structure (start empty or with base structure only)
- **During `/BLUEPRINT --start`**: Add resource definitions following this schema when designing integrations
- **During `/IMPLEMENT --build`**: Add resource definitions when implementing endpoints or connecting to infrastructure

### Adaptation Rules
> **IMPORTANT:** Follow the canonical structure but adapt the `config` object based on your specific context.

**Adaptation Criteria:**
1. **Resource Type**: Different types (database, queue, API) require different config fields
2. **Architecture Pattern**: Monolith vs microservices vs serverless may need different metadata
3. **Technology Stack**: Specific frameworks/tools may require additional config fields
4. **Setup Decisions**: Use decisions documented in `docs/setup.md` to inform config structure

**Examples:**
- **REST API**: `config` includes `baseUrl`, `timeout`, `retries`, `endpoints`
- **GraphQL API**: `config` includes `baseUrl`, `timeout`, `introspectionUrl`, `subscriptionsUrl`
- **Database**: `config` includes `host`, `port`, `poolSize`, `sslMode`, `replicationLag`
- **Message Queue**: `config` includes `host`, `port`, `exchanges`, `queues`, `prefetchCount`

---

## Root Schema

```json
{
  "version": "string (semver format, e.g., '1.0.0')",
  "lastUpdated": "string (ISO date format YYYY-MM-DD)",
  "resources": [
    {
      "id": "unique-resource-id",
      "type": "integration|internal_endpoint|database|queue|storage|cache|cdn|other",
      "name": "Human-readable name",
      "purpose": "Brief description of why this resource exists",
      "protocol": "http|https|grpc|amqp|kafka|postgres|redis|s3|other",
      "authentication": "oauth2|api-key|jwt|basic|none|mTLS|other",
      "documentationUrl": "https://example.com/docs or path/to/internal/spec.md",
      "envVars": ["ENV_VAR_NAME_1", "ENV_VAR_NAME_2"],
      "owner": "team-name or email",
      "version": "1.0.0",
      "lastReviewed": "YYYY-MM-DD",
      "status": "active|deprecated|planned",
      "config": {
        "_note": "Flexible object - adapt based on resource type and architecture"
      }
    }
  ]
}
```

---

## Field Definitions

### Root Level Fields

#### `version` (string, required)
Semantic version of the configuration file schema itself (not resource versions).
- **Format:** `MAJOR.MINOR.PATCH` (e.g., `"1.0.0"`)
- **Usage:** Increment when schema structure changes

#### `lastUpdated` (string, required)
Date of last modification to this configuration file.
- **Format:** ISO date `YYYY-MM-DD` (e.g., `"2026-01-22"`)
- **Usage:** Updated automatically by agents `/ARCH` and `/DEV`

#### `resources` (array, required)
Array of resource objects. Each resource represents an external integration, internal endpoint, or infrastructure component.

---

### Resource Object Fields

#### `id` (string, required)
Unique identifier for this resource across the entire configuration.
- **Format:** `kebab-case` (e.g., `"stripe-payment-api"`, `"user-service-internal"`, `"pg-primary-db"`)
- **Uniqueness:** MUST be unique across all resources
- **Validation:** Enforced by `scripts/check-integrations.sh`

#### `type` (string, required)
Category of the resource.
- **Allowed Values:**
  - `integration`: External API or SaaS service
  - `internal_endpoint`: Internal microservice, API, or service
  - `database`: SQL/NoSQL database
  - `queue`: Message queue (RabbitMQ, Kafka, SQS, etc.)
  - `storage`: Object storage (S3, Azure Blob, GCS, etc.)
  - `cache`: In-memory cache (Redis, Memcached, etc.)
  - `cdn`: Content Delivery Network
  - `other`: Custom resource type (specify details in `config`)

#### `name` (string, required)
Human-readable name for this resource.
- **Format:** Plain text (e.g., `"Stripe Payment Gateway"`, `"User Service API"`)
- **Purpose:** Used in documentation and logging

#### `purpose` (string, required)
Brief explanation of why this resource exists and what it's used for.
- **Format:** 1-3 sentences
- **Example:** `"Process credit card payments and manage subscriptions"`

#### `protocol` (string, required)
Communication protocol used to interact with this resource.
- **Common Values:** `http`, `https`, `grpc`, `amqp`, `kafka`, `postgres`, `mysql`, `redis`, `mongodb`, `s3`
- **Custom Values:** Allowed (e.g., `"custom-rpc"`)

#### `authentication` (string, required)
Authentication method required to access this resource.
- **Common Values:**
  - `oauth2`: OAuth 2.0 flow
  - `api-key`: API key in header or query param
  - `jwt`: JSON Web Token
  - `basic`: HTTP Basic Authentication
  - `mTLS`: Mutual TLS (certificate-based)
  - `none`: No authentication required
  - `other`: Custom authentication (describe in `config`)

#### `documentationUrl` (string, required)
URL or file path to the resource's specification, API documentation, or internal spec.
- **External APIs:** Full URL (e.g., `"https://stripe.com/docs/api"`)
- **Internal Services:** Relative path (e.g., `"docs/services/user-service/api-spec.md"`)
- **Infrastructure:** Link to runbook or architecture doc

#### `envVars` (array of strings, required)
List of environment variable names required for this resource.
- **Purpose:** Documents which env vars are needed (values must be in `.env` or secrets manager, NOT in this file)
- **Format:** Array of uppercase strings with underscores (e.g., `["STRIPE_API_KEY", "STRIPE_WEBHOOK_SECRET"]`)
- **Validation:** `scripts/check-integrations.sh` verifies these vars exist in `.env` or secrets documentation

#### `owner` (string, required)
Responsible team or maintainer for this resource.
- **Format:** Team name or email (e.g., `"payments-team@example.com"`, `"infra-team"`)
- **Purpose:** Contact point for issues, changes, or deprecation

#### `version` (string, required)
Version of the resource itself (API version, database version, service version).
- **Format:** Semantic versioning recommended (e.g., `"1.2.0"`, `"2023-10-16"`)
- **Purpose:** Track resource version changes, migrations, deprecations

#### `lastReviewed` (string, required)
Date when this resource configuration was last reviewed for accuracy.
- **Format:** ISO date `YYYY-MM-DD`
- **Purpose:** Identify stale configurations that need audit

#### `status` (string, required)
Lifecycle status of this resource.
- **Allowed Values:**
  - `active`: Currently in use in production
  - `deprecated`: Scheduled for removal (include deprecation date in `config`)
  - `planned`: Not yet implemented, planned for future
- **Validation:** Enforced by `scripts/check-integrations.sh`
- **Connectivity Tests:** Only run for `status: active` resources

#### `config` (object, required)
Flexible object for resource-specific configuration.
- **Structure:** Varies by `type` and architecture (see examples below)
- **Rule:** NO credentials allowed (e.g., no passwords, API keys, tokens)
- **Purpose:** Store non-sensitive configuration that varies by resource type

---

## Config Object Patterns by Resource Type

### Integration (External API)
```json
{
  "config": {
    "baseUrl": "https://api.stripe.com",
    "apiVersion": "2023-10-16",
    "timeout": 30000,
    "retries": 3,
    "rateLimitPerMinute": 100,
    "webhookPath": "/webhooks/stripe",
    "endpoints": {
      "createPayment": "POST /v1/payment_intents",
      "refund": "POST /v1/refunds"
    }
  }
}
```

### Internal Endpoint (Microservice API)
```json
{
  "config": {
    "baseUrl": "https://user-service.internal",
    "healthCheckPath": "/health",
    "timeout": 5000,
    "retries": 2,
    "circuitBreaker": {
      "enabled": true,
      "threshold": 5,
      "timeout": 60000
    },
    "endpoints": {
      "createUser": "POST /api/v1/users",
      "getUser": "GET /api/v1/users/:id",
      "updateUser": "PUT /api/v1/users/:id",
      "deleteUser": "DELETE /api/v1/users/:id"
    }
  }
}
```

### Database (PostgreSQL, MySQL, MongoDB, etc.)
```json
{
  "config": {
    "host": "db.primary.internal",
    "port": 5432,
    "database": "app_production",
    "poolSize": 20,
    "sslMode": "require",
    "connectionTimeout": 10000,
    "maxRetries": 3,
    "replicationLag": {
      "enabled": true,
      "maxLagMs": 1000
    }
  }
}
```

### Queue (RabbitMQ, Kafka, SQS, etc.)
```json
{
  "config": {
    "host": "rabbitmq.internal",
    "port": 5672,
    "vhost": "/production",
    "prefetchCount": 10,
    "reconnectDelay": 5000,
    "exchanges": {
      "events": {
        "type": "topic",
        "durable": true
      }
    },
    "queues": {
      "user-events": {
        "durable": true,
        "routingKey": "user.*",
        "deadLetterExchange": "dlx"
      }
    }
  }
}
```

### Storage (S3, Azure Blob, GCS, etc.)
```json
{
  "config": {
    "bucket": "app-user-uploads-prod",
    "region": "us-east-1",
    "storageClass": "STANDARD",
    "publicRead": false,
    "maxFileSize": 10485760,
    "allowedMimeTypes": ["image/jpeg", "image/png", "application/pdf"],
    "versioning": true,
    "lifecycle": {
      "deleteAfterDays": 365
    }
  }
}
```

### Cache (Redis, Memcached, etc.)
```json
{
  "config": {
    "host": "redis.internal",
    "port": 6379,
    "db": 0,
    "ttl": 3600,
    "maxConnections": 50,
    "keyPrefix": "session:",
    "evictionPolicy": "allkeys-lru",
    "persistence": {
      "enabled": true,
      "strategy": "rdb"
    }
  }
}
```

### CDN (Cloudflare, CloudFront, etc.)
```json
{
  "config": {
    "zone": "example.com",
    "cacheTtl": 86400,
    "purgeOnDeploy": true,
    "assetPaths": ["/assets/*", "/images/*", "/css/*", "/js/*"],
    "compression": {
      "enabled": true,
      "level": 6
    },
    "securityHeaders": {
      "hsts": true,
      "csp": "default-src 'self'"
    }
  }
}
```

---

## Validation Rules

The `scripts/check-integrations.sh` script enforces these rules:

### 1. Schema Compliance
- All required root fields (`version`, `lastUpdated`, `resources`) must be present
- All required resource fields must be present for each resource
- Field types must match expected types (string, array, object)

### 2. Unique Resource IDs
- No two resources can have the same `id` value
- IDs must be in kebab-case format

### 3. Valid Status Values
- `status` must be one of: `active`, `deprecated`, `planned`
- Invalid values will cause validation failure

### 4. No Credentials in Config
- The script scans for patterns matching secrets:
  - `api_key`, `api-key`, `apikey`
  - `password`, `passwd`, `pwd`
  - `secret`, `token`, `credential`
  - `auth_key`, `bearer`, `private_key`
- If detected in `config` object values, validation fails with exit code 2

### 5. Environment Variables Exist
- All variables listed in `envVars` must be defined in `.env` or secrets documentation
- Missing env vars trigger warnings (errors in `--strict` mode)

### 6. Connectivity Tests (Active Resources Only)
- For resources with `status: active`, the script attempts connection:
  - **APIs**: HTTP request to `baseUrl + healthCheckPath`
  - **Databases/Caches/Queues**: TCP connection to `host:port`
- Failed connectivity tests cause validation failure with exit code 3

---

## Adaptation Guidelines

### For Different Architecture Patterns

#### Monolithic Application
- **Fewer Resources**: Likely only external integrations, single database, single cache
- **Simpler Config**: Less emphasis on service discovery, no inter-service auth

#### Microservices Architecture
- **Many Internal Endpoints**: Each service is a separate resource with `type: internal_endpoint`
- **Service Mesh Considerations**: Add `config.serviceMesh` with mesh-specific settings
- **API Gateway**: Add resource for API gateway with routing config

#### Serverless Architecture
- **Event-Driven Resources**: Emphasize queues, topics, event buses
- **Stateless Functions**: Focus on external storage, databases, no local cache
- **Cold Start Config**: Add `config.coldStartOptimization` settings

### For Different Technology Stacks

#### Node.js/Express
```json
{
  "config": {
    "baseUrl": "...",
    "middleware": ["cors", "helmet", "compression"],
    "rateLimiting": {
      "windowMs": 900000,
      "max": 100
    }
  }
}
```

#### Python/FastAPI
```json
{
  "config": {
    "baseUrl": "...",
    "workers": 4,
    "timeout": 30,
    "keepAlive": 5
  }
}
```

#### Java/Spring Boot
```json
{
  "config": {
    "baseUrl": "...",
    "threadPool": {
      "coreSize": 10,
      "maxSize": 50
    },
    "actuatorEndpoints": ["/actuator/health", "/actuator/metrics"]
  }
}
```

---

## Maintenance Workflow

### Adding a New Resource
1. **Blueprint** (`/BLUEPRINT --start`): Design integration, define required fields
2. **Add Entry**: Append resource object to `resources` array in `/config/system_resources.json`
3. **Document Env Vars**: Add required env vars to `.env.example`
4. **Validate**: Run `scripts/check-integrations.sh --strict`
5. **Commit**: Include in feature branch PR

### Updating an Existing Resource
1. **Developer** (`/IMPLEMENT --build`): Modify resource `config` as needed
2. **Update `lastReviewed`**: Set to current date
3. **Increment `version`**: If breaking changes, increment version
4. **Validate**: Run `scripts/check-integrations.sh --strict`
5. **Document**: Update ADR if architectural change

### Deprecating a Resource
1. **Change Status**: Set `status: "deprecated"`
2. **Add Deprecation Info**: In `config`, add:
   ```json
   {
     "deprecationDate": "2026-06-01",
     "replacedBy": "new-resource-id",
     "migrationGuide": "docs/migrations/resource-migration.md"
   }
   ```
3. **Update Documentation**: Add migration guide
4. **Monitor Usage**: Track deprecation warnings in logs
5. **Remove**: After deprecation date + grace period, delete entry

---

## Examples Reference

See `.context/templates/setup/config/system_resources.template.json` for complete working examples of all resource types.

---

## Further Reading
- [12-Factor App - Config](https://12factor.net/config)
- [OWASP Configuration Management](https://owasp.org/www-project-proactive-controls/)
- [JSON Schema Specification](https://json-schema.org/)
