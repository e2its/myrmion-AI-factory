---
description: "Architecture standards — layered architecture, dependency rules, module boundaries, domain-driven design patterns."
applicable_when:
  always: true
version: 1.1.0
date: 2026-09-25
changelog:
  - "1.1.0: feat(EVOL-043) — hosts [PLAW-01] and [PLAW-04] bodies (merged from the constitution template)"
  - "1.0.0: Initial template version"
---

# Architecture Patterns & Layer Separation

> **Auto-generated from** `docs/setup.md` decisions  
> **Reference:** Template C

## [PLAW-01] Fundamental Principles (KISS & DRY)
> Every technical decision is the simplest one that meets the current requirement, and every piece of knowledge has one authoritative representation in the system.

> **Mandate:** THESE ARE THE NON-NEGOTIABLE ARCHITECTURAL PRINCIPLES. EVERY technical decision must be validated against these principles.

### KISS (Keep It Simple, Stupid)
> **Mandate:** Simplicity is the ultimate sophistication. NEVER over-engineer a solution.

**KISS Rules:**
- ✅ **Minimum Viable Solution:** Implement ONLY what is necessary to meet the current requirement. Do not anticipate future needs.
- ✅ **Clarity over Complexity:** If a solution requires more than 5 minutes to explain, it is probably too complex.
- ✅ **Avoid Premature Patterns:** DO NOT implement complex architectural patterns (CQRS, Event Sourcing, Microservices) unless a DEMONSTRATED need exists.
- ✅ **Refactor when it Scales:** Start simple (modular monolith), refactor to complexity when scale justifies it.
- ✅ **Less Code = Fewer Bugs:** The best line of code is the one that is NOT written.

**KISS Anti-Patterns (PROHIBITED):**
- ❌ **Gold Plating:** Adding features "just in case" without an explicit requirement.
- ❌ **Framework Stacking:** Using 3 frameworks when 1 is sufficient.
- ❌ **Excessive Abstraction Layering:** More than 3 layers of abstraction without clear technical justification.

**KISS Validation in Code Review:**
- ✅ Can this be implemented in a SIMPLER way?
- ✅ Are we solving a REAL problem or anticipating a hypothetical one?
- ✅ Can a junior developer understand this solution in <10 minutes?

---

### DRY (Don't Repeat Yourself)
> **Mandate:** Every piece of knowledge must have ONE unique, authoritative and unambiguous representation in the system.

**DRY Rules:**
- ✅ **Single Source of Truth:** For each business concept, there must be ONE SINGLE reusable implementation.
- ✅ **Abstract Repeated Patterns:** If you copy code 2 times, refactor on the 3rd repetition.
- ✅ **Configure, Don't Duplicate:** Use external configuration (`/config`, `.env`) instead of duplicating values.
- ✅ **Reuse Business Logic:** Domain Services, Value Objects and Entities must be shared, NOT duplicated per layer.
- ✅ **Reusable UI Components:** Atomic Design ensures shared components (Atoms, Molecules).

**DRY Anti-Patterns (PROHIBITED):**
- ❌ **Copy-Paste Programming:** Duplicating code blocks instead of extracting functions/classes.
- ❌ **Duplicated Business Logic:** Implementing the same validation in frontend AND backend without shared validation logic.
- ❌ **Hardcoded Configuration:** Duplicating URLs, API keys, timeouts in multiple files (see `[PLAW-05]` in `configuration.md`).
- ❌ **Duplicate Schemas:** Having different entity definitions in backend, frontend and database (use Shared Types / Contracts).

**DRY Validation in Code Review:**
- ✅ Does this code already exist somewhere else in the project?
- ✅ Can we extract this logic into a shared module?
- ✅ Is the configuration externalized in `/config` or `.env`?
- ✅ Are API contracts defined in `/contracts` and shared between consumers?

---

### KISS ↔ DRY Relationship (Balance)

**CAUTION:** These principles may conflict. Use this tiebreaker criterion:

| Scenario | Decision |
|-----------|----------|
| Small duplication (<10 lines) vs Complex abstraction | **KISS wins:** Tolerate duplication if abstraction adds unnecessary complexity |
| Repeated business logic (>20 lines) vs Simple abstraction | **DRY wins:** Refactor to shared function/class |
| Duplicated configuration (URLs, secrets) | **DRY ALWAYS wins:** Use `/config/system_resources.json` and `.env` |
| Duplicated API contracts (frontend/backend) | **DRY ALWAYS wins:** Use `/contracts` with OpenAPI/TypeScript |

## [PLAW-04] Code Readability & Maintainability
> Code readability for humans is always prioritised over brevity or optimisation tricks: a function does one thing and a reader grasps its purpose without decoding.

> **Mandate:** Code readability for humans is ALWAYS prioritized over brevity or optimization tricks.

### Readability Principles
- **Clarity over Cleverness:** Code must be self-explanatory. Avoid complex "one-liners" that require mental decoding.
- **Explicit over Implicit:** Dependencies, data transformations and control flows must be visible and traceable.
- **Naming Conventions:** Variable, function and class names must describe their purpose without the need for additional documentation.
- **Function Length:** Functions must do ONE thing well. If it exceeds ~20 logical lines, consider refactoring.
- **Cognitive Load:** Code must minimize cognitive load. A developer must understand the purpose in <2 minutes of reading.

### Prohibited Patterns (Anti-Readability)
- ❌ **Magic Numbers:** Use constants with descriptive names (e.g., `MAX_RETRY_ATTEMPTS = 3` instead of `3`).
- ❌ **Nested Ternaries:** Maximum one level of ternary. Beyond that, use explicit `if/else`.
- ❌ **Deep Nesting:** Maximum 3 levels of indentation. Use "early returns" or extract functions.
- ❌ **Cryptic Abbreviations:** `usr` ≠ `user`, `calc` ≠ `calculate`. Use full names except universal conventions (e.g., `id`, `url`, `http`).

### Code Review Criteria
- ✅ **Could a junior developer understand this without additional context?**
- ✅ **Do variable/function names explain the "what" and the "why"?**
- ✅ **Is the logical flow linear and predictable?**

### Further Reading
- [Clean Code by Robert C. Martin](https://www.oreilly.com/library/view/clean-code-a/9780136083238/)
- [Code Simplicity by Max Kanat-Alexander](https://www.codesimplicity.com/)

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

**Cross-Reference:** See `security_policy.md` Section 3.1 for security implications.

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
