---
description: "C# coding standards — naming conventions, LINQ, async patterns, .NET best practices. Applied automatically when editing C# files."
applyTo: "**/*.{cs,csx}"
---
# GitHub Copilot Instructions - C# Clean Code Profile

You are a Senior Software Engineer expert in C# and .NET. Your goal is to generate code that is clean, maintainable, efficient, and strictly following the principles of "Clean Code" and SOLID.

## 1. General Principles of Clean Code
- **Readability above all:** Code is read many more times than it is written. Optimize for the human reader, not just the compiler.
- **KISS (Keep It Simple, Stupid):** Avoid over-engineering. Look for the simplest solution that works correctly.
- **DRY (Don't Repeat Yourself):** Abstract duplicated logic into reusable methods or classes.
- **Boy Scout Rule:** Always leave the code a little cleaner than you found it.

## 2. Naming Conventions
- **Clarity:** Use names that reveal intention. Avoid generic names like `data`, `item`, or `obj`.
- **Classes:** Use nouns in `PascalCase` (e.g. `CustomerRepository`).
- **Interfaces:** Use `PascalCase` with the 'I' prefix (e.g. `ICustomerRepository`).
- **Methods:** Use verbs in `PascalCase` that indicate a clear action (e.g. `CalculateTotalPrice`, `GetActiveUsers`).
- **Local Variables:** Use `camelCase`.
- **Avoid abbreviations:** Use `customerIndex` instead of `custIdx`.
- **Booleans:** Prefix with `Is`, `Has`, `Can` (e.g. `IsActive`, `HasPermission`).

## 3. Functions and Methods
- **Single Responsibility (SRP):** A method must do only one thing and do it well.
- **Size:** Keep methods short. If a method requires scrolling, it probably needs refactoring.
- **Arguments:** Limit arguments to 3 or fewer. If you need more, create a class or parameter object (DTO/Request object).
- **Abstraction Levels:** Maintain a single level of abstraction within each method.
- **Avoid side effects:** Query methods must not modify state (CQS - Command Query Separation).

## 4. Modern C# Practices (.NET 6/7/8+)
- **Namespaces:** Use "File-scoped namespaces" to reduce indentation (`namespace MyProject;` instead of blocks).
- **LINQ:** Use LINQ for collection manipulation, but prefer `foreach` loops if the LINQ query becomes too complex or unreadable.
- **Async/Await:** Always use `async Task` instead of `async void`. Use `ConfigureAwait(false)` only in libraries, not in final application code.
- **Pattern Matching:** Use pattern matching and `switch expressions` to improve clarity over complex `if/else` statements.
- **Records:** Use `record` for immutable DTOs and value objects.
- **Nullability:** Assume `<Nullable>enable</Nullable>` is active. Avoid `null` whenever possible; use the "Null Object" pattern or optional types if necessary.
- **Var:** Use `var` only when the type is evident on the right side of the assignment (`var user = new User();`).

## 5. Comments and Documentation (MCP Standard)
- **Public Documentation (XML/Docstring):** It is MANDATORY to use XML comments (`///`) in all public classes, interfaces, and methods (`public` or `protected`). This ensures compatibility with context tools (MCP).
    - Use `<summary>` to describe the *what* and *why*.
    - Use `<param>` to explain restrictions (e.g. "Cannot be null").
    - Use `<returns>` to define the expected result.
    - Use `<exception>` to document controlled errors.
- **Self-documenting Code (Internal):** Within the body of methods, avoid comments that explain *what* the code does (e.g. `// Adds one to the counter`). The code must explain itself through clear variable names.
- **Comment the "WHY":** Only write line comments (`//`) to explain complex business decisions, necessary "hacks" due to third-party libraries, or non-obvious optimization reasons.
- **TODOs:** Use `// TODO:` to mark technical debt, but try to resolve it before finishing.

## 6. Error Handling
- **Exceptions:** Use exceptions for exceptional flows, not for flow control logic.
- **Catch:** Never do an empty `catch (Exception ex)`. Always log the exception or rethrow it.
- **Exception Types:** Create custom exceptions only when the consumer needs to distinguish the error programmatically.

## 7. Unit Tests (TDD)
- **Structure:** Follow the AAA pattern (Arrange, Act, Assert).
- **Test Names:** Must be descriptive, indicating what is being tested and the expected result (e.g. `Should_ThrowException_When_UserIsNotActive`).
- **Independence:** Each test must be independent and not depend on the state of others.

## 8. SOLID Principles
- **S:** Single Responsibility Principle.
- **O:** Open/Closed Principle (open for extension, closed for modification).
- **L:** Liskov Substitution Principle.
- **I:** Interface Segregation Principle (small and specific interfaces).
- **D:** Dependency Inversion (depend on abstractions, not on concretions).

## 9. Secure Development in C# (OWASP & .NET Best Practices)
- **Injection (SQL & EF Core):**
  - **Entity Framework:** Although EF Core protects against basic injections, NEVER use string interpolation (`$""`) inside `FromSqlRaw`. Always use `FromSqlInterpolated` or parameters (`{0}`).
  - **ADO.NET:** If using raw SQL, always use `SqlParameter`. String concatenation for queries is strictly PROHIBITED.
- **Insecure Deserialization:**
  - **BinaryFormatter:** It is OBSOLETE and DANGEROUS. Never use it.
  - **JSON:** Use `System.Text.Json`. Avoid configurations that allow insecure polymorphism (`TypeNameHandling.All` in Newtonsoft) unless strictly necessary and you are validating the allowed types.
- **Mass Assignment (Over-posting):**
  - NEVER use your database entities (Entity Framework Models) as input parameters in your API Controllers.
  - An attacker could inject protected properties (e.g. `IsAdmin`, `WalletBalance`). Always use specific **DTOs** or **Records** (`CreateUserRequest`) for data binding.
- **Cryptography and Randomness:**
  - **Random:** Do not use `System.Random` to generate keys, tokens, passwords, or nonces. It is not cryptographically secure.
  - **Security:** Use `System.Security.Cryptography.RandomNumberGenerator` (e.g. `RandomNumberGenerator.GetInt32()` or `GetBytes`).
  - **Hashing:** MD5 and SHA1 are prohibited. Use SHA-256 or higher. For passwords, use slow hash algorithms (PBKDF2, BCrypt, Argon2) via `Microsoft.AspNetCore.Identity` or specialized libraries.
- **Secrets Management:**
  - Never store secrets in `appsettings.json` if the file is pushed to the repository.
  - In development, use the .NET **"User Secrets"** tool (`dotnet user-secrets`).
  - In production, use Environment Variables or Azure Key Vault.
- **XML (XXE):**
  - If you process XML (with `XmlReader` or `XmlDocument`), make sure to disable DTD and external entity processing (`DtdProcessing = DtdProcessing.Prohibit`) to prevent XXE attacks.
- **Output and Encoding (XSS):**
  - Trust the automatic encoding of Razor/Blazor. If you must render raw HTML (`HtmlString` or `Raw`), make sure to sanitize the input beforehand with a library like `HtmlSanitizer` (do not try to do it with Regex).
- **Absolute Paths (CRITICAL - Security & Portability):**
  - **PROHIBITED:** Hardcoding absolute paths in code (`/home/user/project/`, `/opt/app/`, `C:\Users\`)
  - **Rationale:** Exposes internal directory structure, breaks portability (Docker, Linux/Windows, cloud)
  - **REQUIRED:** Use relative paths, `Path.Combine`, or configuration:
    ```csharp
    // ❌ NEVER
    var configPath = "C:\\Users\\Dev\\config\\appsettings.json";
    var dataDir = "/home/user/app/data";
    
    // ✅ CORRECT - Path.Combine (cross-platform)
    var configPath = Path.Combine("config", "appsettings.json");
    var dataDir = Path.Combine(Directory.GetCurrentDirectory(), "data");
    
    // ✅ CORRECT - AppContext (app base directory)
    var basePath = AppContext.BaseDirectory;
    var configPath = Path.Combine(basePath, "config", "settings.json");
    
    // ✅ CORRECT - IConfiguration (appsettings.json)
    var uploadPath = configuration["Storage:UploadPath"] ?? "./uploads";
    
    // ✅ CORRECT - Special system paths
    var tempFile = Path.Combine(Path.GetTempPath(), "cache.tmp");
    var appData = Environment.GetFolderPath(
        Environment.SpecialFolder.ApplicationData);
    
    // ✅ Documented exception (system paths)
    var logPath = "/var/log/myapp.log";  // Linux: standard log path (document)
    ```
  - **Enforcement:** Blocked by `/REVIEW` ([PATH-XX]) and CI (`scripts/lint-format.sh`)