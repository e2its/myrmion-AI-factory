---
description: "Architecture standards — layered architecture, dependency rules, module boundaries, domain-driven design patterns."
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Architecture Patterns & Layer Separation

> **Auto-generated from** `docs/setup.md` decisions  
> **Reference:** Template C

## Selected Pattern
- Pattern: {{ARCHITECTURE_PATTERN}} (Hexagonal/Clean/Onion/Feature-based)
- Base path: {{BASE_PATH}} (e.g., `src` or `internal`)
- Language/Framework: {{PRIMARY_LANGUAGE}} + {{PRIMARY_FRAMEWORK}}

## Layer Separation
- Domain/Core: pure business logic; no framework imports
- Application/Use Cases: orchestrate workflows; no IO specifics
- Infrastructure: adapters (DB, HTTP, messaging, file systems)
- Interface/Delivery: controllers, handlers, UI
- Rule: Inner layers cannot depend on outer layers; enforce via imports

## Portability & Environment Independence

**MANDATORY:** All file path references MUST be environment-agnostic.

**Rule:** Use relative paths, module aliases, or environment variables. NEVER hardcode absolute paths.

**Rationale (Architectural):**
- **Cloud-Native Compatibility:** Deployments in Docker/K8s/serverless have dynamic paths
- **Multi-Environment Support:** Dev/staging/prod have different directory structures
- **Build System Compatibility:** CI/CD, bundlers, and compilers expect workspace-relative paths
- **Team Collaboration:** Different OS (Linux/Mac/Windows) and directory layouts

**Example Violations (BLOCKER):**
```typescript
// ❌ Breaks in Docker, cloud, other developer machines
import { UserService } from '/home/dev/project/src/services/UserService';
const templatePath = 'C:\\Users\\Dev\\templates\\email.html';
```

**Correct Patterns:**
```typescript
// ✅ Workspace-relative (with tsconfig paths)
import { UserService } from '@/services/UserService';
import { UserService } from '../../../services/UserService';

// ✅ Runtime-resolved paths
const templatePath = path.join(__dirname, '../templates/email.html');
const configPath = process.env.CONFIG_PATH || './config/default.json';
```

**Cross-Reference:** See `security_policy.instructions.md` Section 3.1 for security implications.

## DDD Guidelines (if applicable)
- Aggregates with clear invariants; Repositories per aggregate
- Domain events for side effects; avoid anemic models
- Anti-Corruption Layer for third-party systems

## CQRS (optional)
- Split read/write models when complexity or performance requires
- Commands validated; queries read-only and cache-friendly

## ADR Requirements
- Record architecture choices in `docs/adr/` with rationale
- Brownfield: add migration strategy (e.g., Strangler Fig) if patterns change

## Further Reading
- Clean Architecture
- DDD Reference
- Hexagonal Architecture
