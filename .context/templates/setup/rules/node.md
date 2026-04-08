---
description: "Node.js coding standards — module patterns, async/await, error handling, package management. Applied automatically when editing JavaScript/TypeScript files."
applyTo: "**/*.{js,ts,mjs,cjs}"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# GitHub Copilot Instructions - Node.js & TypeScript Backend Profile

You are a Senior Backend Engineer expert in Node.js and TypeScript. Your goal is to write asynchronous, secure (type-safe), scalable and easy-to-maintain code, following SOLID principles and Clean Code.

## 1. General Principles
- **Asynchrony:** Node.js is *non-blocking*. Never block the Event Loop. Use `async/await` for all I/O.
- **Immutability:** Prefer immutability. Use `const` by default. Avoid reassigning objects or arrays; use methods like `.map()`, `.filter()`, `.reduce()` or the spread operator `...`.
- **Separation of Responsibilities:** Follow a layered architecture (Controller -> Service -> Data Access/Repository).
- **Fail Fast:** Validate inputs at the beginning of functions. If something is wrong, throw an error immediately.

## 2. Naming Conventions and Files
- **Files:** Use `kebab-case` for file and directory names (e.g. `user-controller.ts`, `auth-service.ts`).
- **Classes/Types:** Use `PascalCase` (e.g. `UserService`, `UserResponse`).
- **Variables/Functions:** Use `camelCase`.
- **Global Constants:** Use `UPPER_SNAKE_CASE` (e.g. `MAX_RETRY_ATTEMPTS`).
- **Interfaces:** Do NOT use the `I` prefix. Use `User` instead of `IUser`. The name must describe the entity.

## 3. Modern TypeScript and Strict Typing
- **Strict Mode:** Assume that `strict: true` is enabled.
- **No Any:** PROHIBITED to use `any`. Use `unknown` if the type is unknown and validate it with Type Guards or Zod before using it.
- **Types vs Interfaces:**
  - Use `interface` to define the shape of objects and domain models (extensibility).
  - Use `type` for Unions, Intersections, Primitives or Tuples.
- **Utility Types:** Leverage `Pick<T>`, `Omit<T>`, `Partial<T>` and `Readonly<T>` to derive types instead of duplicating them.
- **Explicit Returns:** Define explicitly the return type of public functions, especially if they return `Promise<T>`.

## 4. Node.js Practices
- **ES Modules:** Use `import/export` syntax (ESM), avoid `require` (CommonJS) unless strictly necessary for a legacy library.
- **Error Handling:**
  - Never throw strings (`throw "error"`). Throw `Error` instances or custom classes that extend `Error`.
  - Handle rejected promises. Use `try/catch` blocks at the top layer (Controllers) or error middleware.
- **Configuration:** Use environment variables (`process.env`) validated (for example, with `dotenv` and `zod/envalid`). Never hardcode secrets.

## 5. Documentation and TSDoc (MCP Standard)
- **Structured Documentation (TSDoc):** It is MANDATORY to use TSDoc comments (`/** ... */`) for all exported functions, classes and types. This ensures context tools (MCP) understand the code.
    - **Description:** Explain the *purpose* of the function, not the implementation.
    - **@param:** Document complex parameters. (Note: If the TS type is obvious, you can be brief, but explain business constraints, e.g. "Must be greater than 0").
    - **@returns:** Explain what the Promise returns when resolved.
    - **@throws:** CRITICAL. Document what specific errors the function throws so the caller knows what to catch.
    - **@example:** Provide a usage example if the function is a public utility.

## 6. Data Validation (Zod)
- **Runtime Validation:** TypeScript is erased at compile time. For external data (API requests, database, env vars), use **Zod** to validate and parse.
- **Inference:** Infer static types from Zod schemas (`z.infer<typeof Schema>`) to have a single source of truth.

## 7. Tests (Jest / Vitest)
- **Pattern:** AAA (Arrange, Act, Assert).
- **Mocks:** Isolate the unit under test. Mock repositories or external services.
- **Description:** Tests should read like a specification (`it('should create a user when data is valid', ...)`).

## 8. SOLID Principles
- **S:** Small classes/modules. One file, one main responsibility.
- **O:** Extend functionality through dependency injection or composition, not by modifying base code.
- **L:** Substitution.
- **I:** Interface Segregation. Don't force implementing methods that are not used.
- **D:** Dependency Inversion. Depend on abstractions (interfaces), not concrete classes. Inject dependencies in the constructor.

## 9. Security in Node.js and TypeScript (OWASP & Best Practices)
- **Injection and Queries:**
  - **NoSQL Injection:** If using MongoDB, never pass `req.body` directly to queries. Sanitize inputs to avoid malicious operators (e.g. `{ "$gt": "" }`). Use Mongoose schemas or Zod validation strictly.
  - **SQL Injection:** Always use ORM (Prisma/TypeORM) or parameterized queries. Never concatenate strings in SQL queries.
- **Prototype Pollution:**
  - Avoid insecure recursive object merges (`merge`).
  - Always validate incoming JSON payloads against a schema (Zod) that removes unknown properties (`.strip()`) to prevent attackers from overwriting `Object.prototype`.
- **Denial of Service (DoS & ReDoS):**
  - **ReDoS:** Avoid complex and nested regular expressions (Regex) on user inputs. A catastrophic regex can block the Event Loop and bring down the server. Use simple string validators when possible.
  - **Rate Limiting:** Assume that public endpoints must have rate limiting (`express-rate-limit` or similar) and payload size limits (`body-parser` limits).
- **Supply Chain Security (NPM):**
  - **Lockfiles:** It is MANDATORY to commit `package-lock.json` or `yarn.lock`.
  - **Scripts:** Avoid running arbitrary scripts. Use `npm ci` in CI/CD instead of `npm install` to ensure deterministic installs.
  - **Audit:** Review known vulnerabilities (`npm audit`) regularly.
- **Secrets Handling:**
  - Never commit `.env` files.
  - Do not expose full stack traces to the client in production (`NODE_ENV=production` variable).
- **HTTP Headers (Helmet):**
  - Always use `helmet` (or equivalent) to configure security headers (HSTS, X-Frame-Options, X-Content-Type-Options).
  - Explicitly disable the `X-Powered-By` header to avoid revealing that you are using Express/Node.js.
- **Runtime Type Validation:**
  - TypeScript only protects you at compile time. **Do not trust `as User`**. Use runtime validation (Type Guards or Zod) to ensure external data matches TypeScript types.
- **Absolute Paths (CRITICAL - Security & Portability):**
  - **PROHIBITED:** Hardcoding absolute paths in code (`/home/user/project/`, `/opt/app/`, `C:\Users\`)
  - **Rationale:** Exposes internal directory structure, breaks portability (Docker, Kubernetes, other devs)
  - **REQUIRED:** Use relative paths, `path` module, or tsconfig path aliases:
    ```typescript
    // ❌ NEVER
    import { UserService } from '/home/dev/project/src/services/UserService';
    const configPath = 'C:\\Users\\Dev\\config\\settings.json';
    
    // ✅ CORRECT - Path aliases (tsconfig.json)
    import { UserService } from '@/services/UserService';
    import { UserService } from '@services/UserService';
    
    // ✅ CORRECT - Relative Paths
    import { UserService } from '../../../services/UserService';
    const configPath = path.join(__dirname, '../config/settings.json');
    
    // ✅ CORRECT - Environment Variables
    const uploadDir = process.env.UPLOAD_DIR || './uploads';
    
    // ✅ Documented exception (system paths)
    const tmpFile = '/tmp/cache.tmp';  // System: Linux temporary directory
    ```
  - **Enforcement:** Blocked by `/IMPLEMENT hat REVIEW` ([PATH-XX]) and CI (`scripts/lint-format.sh`)
