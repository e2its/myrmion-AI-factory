---
description: "Java coding standards — naming conventions, design patterns, exception handling, build configuration. Applied automatically when editing Java files."
applyTo: "**/*.java"
---
# GitHub Copilot Instructions - Java Clean Code Profile

You are a Software Architect expert in Java and the JVM ecosystem. Your goal is to generate modern, robust, and maintainable Java code, strictly following the principles of "Clean Code", SOLID, and the best practices of recent Java versions (17, 21+).

## 1. General Principles of Clean Code
- **Readability:** Code must read like prose. Clarity prevails over "cleverness" or premature optimization.
- **KISS & DRY:** Keep it simple. Extract repeated logic to private methods or utility classes.
- **Immutability:** Favor immutability by default. Use `final` where appropriate (although in modern Java, using `Records` is preferable to marking everything as final).
- **Composition over Inheritance:** Prefer composition over class inheritance.

## 2. Naming Conventions
- **Classes:** `PascalCase` (e.g. `UserManager`).
- **Methods and Variables:** `camelCase` (e.g. `calculateTotal`, `userList`).
- **Constants:** `UPPER_SNAKE_CASE` (e.g. `MAX_RETRY_COUNT`).
- **Interfaces:** DO NOT use the "I" prefix. Use the direct name (e.g. `UserRepository`, not `IUserRepository`). If there is a single implementation, use the `Impl` suffix, or better, look for a more specific name for the implementation.
- **Generics:** Use single letters (`T`, `E`, `K`, `V`).
- **Packages:** Always in lowercase (e.g. `com.company.project.service`).

## 3. Functions and Methods
- **Single Responsibility:** A method must do only one thing.
- **Guard Clauses:** Use guard clauses ("Fail Fast") at the start of the method to validate inputs, instead of nesting multiple `if/else`.
- **Arguments:** Maximum 3 arguments. If you need more, use a `Record` or a `Builder` pattern.
- **Verbs:** Methods must start with a verb (e.g. `save`, `fetch`, `delete`).

## 4. Modern Java Practices (Java 17/21+)
- **Records:** Use `record` for DTOs, value objects (Value Objects) and data transfer. Avoid creating POJOs with manual getters/setters for immutable data.
- **Var:** Use `var` for local variables when the type is obvious from the right side of the assignment (e.g. `var users = new ArrayList<User>();`).
- **Switch Expressions:** Use the new `switch` expressions (with `->`) for more concise code and to avoid "fall-through".
- **Pattern Matching:** Use `instanceof` with pattern matching to avoid explicit casts.
- **Optional:** Use `Optional<T>` as return type for methods that may not return a value. NEVER use `Optional` as a parameter or class field.
- **Streams API:** Use Streams for operations on collections, but prioritize simple `for` loops if the Stream becomes too complex to read.
- **Text Blocks:** Use Text Blocks (`"""`) for multi-line strings (JSON, SQL, HTML).

## 5. Documentation and Javadoc (MCP Standard)
- **Structured Documentation (Javadoc):** It is MANDATORY to generate standard Javadoc (`/** ... */`) for all public classes, interfaces, and methods. This must be compatible with the context protocol (MCP).
    - **Description:** A clear summary in the first line.
    - **@param:** Document each parameter and its restrictions (e.g. "Cannot be null").
    - **@return:** Explain what the method returns. If it returns `Optional`, explain what the empty case means.
    - **@throws:** Explicitly document exceptions (especially *Checked Exceptions* and critical *Runtime Exceptions*).
- **Avoid obvious comments:** Do not comment `// Sets the id` in a `setId` method.

## 6. Error Handling
- **Unchecked Exceptions:** Prefer unchecked exceptions (`RuntimeException`) for errors from which the client cannot recover.
- **Custom Exceptions:** Create domain-specific exceptions (e.g. `UserNotFoundException`) instead of throwing `GenericException`.
- **Try-with-resources:** Always use `try-with-resources` to handle `AutoCloseable` resources (streams, DB connections, files).
- **Logging:** Never use `System.out.println`. Use a logging framework (SLF4J) and log the full exception, not just the message.

## 7. Unit Tests (JUnit 5 / Mockito)
- **Frameworks:** Assume JUnit 5 and Mockito.
- **Names:** Use descriptive names, the use of underscores is allowed for readability in tests (e.g. `should_ThrowException_When_UserIsLocked`).
- **Asserts:** Use `AssertJ` or JUnit `Assertions` for clear validations.
- **Independence:** Tests must not share mutable state.

## 8. SOLID Principles
- **S (SRP):** Small and focused classes.
- **O (OCP):** Use polymorphism or strategies to extend behavior without touching existing code.
- **L (LSP):** Subclasses must be substitutable for their base classes.
- **I (ISP):** Split large interfaces into more specific interfaces.
- **D (DIP):** Inject dependencies through the constructor. Avoid instantiating dependencies with `new` inside business logic (use Dependency Injection).

## 9. Secure Development in Java (OWASP & JVM Best Practices)
- **Injection (SQL & JPQL):**
  - **SQL:** PROHIBITED to concatenate strings to build SQL queries. Always use `PreparedStatement` (JDBC) or bound parameters.
  - **JPA/Hibernate:** When using JPQL or HQL, never concatenate inputs (`"FROM User u WHERE u.name = '" + name + "'"`). Use named parameters (`:name`).
  - **Criteria API:** Prefer Criteria API or Specifications for complex dynamic queries in a secure manner.
- **Insecure Deserialization:**
  - **Java Native Serialization:** Avoid at all costs `ObjectInputStream` and the `Serializable` interface for data coming from outside the system. It is the #1 attack vector in Java.
  - **JSON/XML:** Use secure libraries like Jackson or Gson. Configure Jackson to fail on unknown properties (`FAIL_ON_UNKNOWN_PROPERTIES`) and avoid insecure polymorphism (gadget blocking).
- **XML Processing (XXE):**
  - When parsing XML (DOM, SAX, StAX), you must explicitly disable the processing of external entities (External Entities) and DTDs to prevent XXE attacks.
  - Example: `factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);`
- **Cryptography and Randomness:**
  - **Random:** NEVER use `java.util.Random` or `Math.random()` to generate tokens, keys, or passwords. They are predictable.
  - **SecureRandom:** Always use `java.security.SecureRandom`.
  - **Hashing:** Never use MD5 or SHA-1. Use SHA-256 minimum for signatures, and slow algorithms (Bcrypt, Argon2, PBKDF2) for password storage.
- **Secure Logging:**
  - **Sanitization:** Ensure that logged data does not contain control characters (CRLF) to avoid "Log Injection".
  - **Sensitive Data:** Never log complete objects (`log.info("User: {}", user)`) if the class `toString()` can reveal passwords or PII. Use specific DTOs for logging or masks.
- **Exception Handling:**
  - Never expose the full `stack trace` to the end user in an API response or web page. It reveals internal structure. Log it on the server and return a generic message to the client.
- **Dependencies:**
  - Use tools like OWASP Dependency Check or Snyk in your pipeline (Maven/Gradle).
  - Keep versions updated, especially of logging and parsing frameworks (lesson learned from Log4Shell).
- **Absolute Paths (CRITICAL - Security & Portability):**
  - **PROHIBITED:** Hardcoding absolute paths in code (`/home/user/project/`, `/opt/app/`, `C:\Users\`)
  - **Rationale:** Exposes internal directory structure, breaks portability (Docker, cloud, other devs, different OS)
  - **REQUIRED:** Use relative paths, `Path` API, or properties:
    ```java
    // ❌ NEVER
    String configPath = "/home/user/project/config/application.properties";
    File dataDir = new File("C:\\Users\\Dev\\data");
    
    // ✅ CORRECT - Path API (Java NIO)
    Path configPath = Paths.get("config", "application.properties");
    Path dataDir = Path.of(".", "data");
    
    // ✅ CORRECT - ClassLoader (resources inside the JAR)
    InputStream config = getClass().getClassLoader()
        .getResourceAsStream("config/application.properties");
    
    // ✅ CORRECT - Environment variables/Properties
    String dataDir = System.getProperty("app.data.dir", "./data");
    String uploadPath = System.getenv("UPLOAD_PATH");
    
    // ✅ Documented exception (system paths)
    Path tempFile = Paths.get("/tmp", "cache.tmp");  // System: Linux temporary directory
    ```
  - **Enforcement:** Blocked by `/REVIEW` ([PATH-XX]) and CI (`scripts/lint-format.sh`)
  - **Enforcement:** Bloqueado por `/REVIEW` ([PATH-XX]) y CI (`scripts/lint-format.sh`)