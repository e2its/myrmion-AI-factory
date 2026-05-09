# Code review criteria

Load this file only if the PR contains code changes (`has_code: true`). The five dimensions to review are **correctness, readability, architecture, security, and performance**. Approval is granted when the change improves codebase health, not when it's perfect.

## 1. Correctness

- Does the code do what the PR description says?
- Does it handle edge cases? (empty input, null/undefined, large lists, concurrency, timeouts)
- Are errors propagated correctly? Or silently swallowed with `except: pass` / `catch {}`?
- Are there race conditions in concurrent code?
- Do `if` conditions cover all paths? Watch for off-by-one errors.
- Do external dependencies (HTTP, DB, queues) have timeout and retry with backoff?
- Tests: do they cover non-trivial paths? Is there a test for the bug if this is a fix?

## 2. Readability

- Are names descriptive? No `temp`, `data`, `result`, `x` outside of minimal scope.
- Does the function do ONE thing? Functions over 50 lines usually do several.
- Is control flow flat? More than 3 levels of nesting is a smell.
- Do comments explain the **why**, not the **what**? The what is read from the code.
- Are there magic numbers/strings? Extract them to named constants.
- Is there dead code, unused imports, unused variables?

## 3. Architecture

- Does the change respect the dependency direction of the codebase? (clean architecture, layers, modules)
- Does it put business logic where it shouldn't be? (fat controllers, anemic models, logic in templates)
- **DRY / CIP**: does it reuse existing utilities, or reinvent the wheel? In materialised Factory projects, every new component must be checked against `config/codebase_inventory.json` — see `Factory-codebase-inventory/SKILL.md`. A new artefact without a CIP consultation is Hard Block 7.
- Does it introduce unnecessary coupling between modules?
- Is the public interface (function signatures, exported classes) the minimum necessary?
- If it introduces a new pattern in the codebase: should there be an ADR? See `adr-policy.md`.

## 4. Security

Universal checklist (always applies):

- **Untrusted inputs**: anything coming from outside (HTTP, DB, files, env) is validated and sanitized.
- **Injection**: parameterized queries, no string concatenation for SQL/LDAP/shell commands/HTML.
- **Secrets**: not in code, not in logs, not in error messages. Use a secrets manager.
- **AuthN/AuthZ**: every new endpoint has explicit authentication and authorization. Default deny.
- **Logging**: no logging of sensitive data (PII, tokens, passwords, card numbers, credentials).
- **Error handling**: error messages to the user don't expose stack traces or internal paths.
- **New dependencies**: are they maintained? Do they have known vulnerabilities? (npm audit / pip-audit / govulncheck)
- **Cryptography**: never implement primitives by hand. Use standard libraries and secure modes (AES-GCM, not ECB; bcrypt/argon2 for passwords).
- **CORS**: explicit configuration, no `*` on authenticated endpoints.
- **Deserialization**: insecure by default (pickle, eval, yaml.load without SafeLoader). Avoid with untrusted data.

## 5. Performance

Only applies if the change is on a critical path or has scaling potential:

- **N+1 queries**: loop that runs one query per iteration. Use batch / eager loading.
- **Indexes**: new queries are backed by an index.
- **Memory**: loading everything into memory vs. streaming. Be careful with `SELECT *` on large tables.
- **Algorithms**: O(n²) on collections that can grow.
- **Cache**: when applicable, is there invalidation? A cache without invalidation is an eventual data bug.
- **External calls in loops**: the worst latency pattern.
- **Lazy vs eager**: load only what's needed.

## Per-language notes

### Python
- Type hints on public functions.
- `dataclass` or pydantic for data objects.
- Context managers (`with`) for resources.
- Avoid `except Exception` without re-raise or log.
- f-strings, not `%` or `.format()`.

### TypeScript
- `strict: true` in tsconfig. No `any` without justification.
- `unknown` over `any` for external inputs.
- Discriminated unions instead of multiple boolean flags.
- `readonly` by default on immutable properties.
- Don't mutate arrays with in-place methods if semantics expect immutability.

### Java / Kotlin
- Immutability by default (`final` / `val`).
- Optional/nullable explicit, don't return null silently.
- Try-with-resources for closeable resources.
- Don't swallow InterruptedException without restoring the flag.

### Go
- Errors wrapped with `%w` and context.
- `context.Context` propagated in calls that may block.
- Goroutines with clear cancellation, no leaks.
- Don't silence errors with `_` except in justified cases.

### SQL
- No `SELECT *` in production.
- Migrations with both up AND down scripts.
- Indexes declared with the migration that creates the query that needs them.
- Transactions where multiple writes must be atomic.

## What does NOT belong in review

- Style: handled by the formatter (Prettier, Black, gofmt, rustfmt).
- Linting: handled by the linter (ESLint, Ruff, golangci-lint, Checkstyle).
- If the formatter/linter wasn't run, the blocker is "run the formatter", not commenting each case.
- Personal preferences without measurable technical impact.
