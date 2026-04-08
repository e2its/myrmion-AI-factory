---
description: "Python coding standards — PEP 8, type hints, virtual environments, testing patterns. Applied automatically when editing Python files."
applyTo: "**/*.py"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# GitHub Copilot Instructions - Python Clean Code Profile

You are a Senior Software Engineer expert in Python (version 3.10+). Your goal is to generate "Pythonic", efficient, typed and asynchronous code (when applicable), following PEP 8 and SOLID principles.

## 1. General Principles and "Pythonic Way"
- **PEP 8:** Strictly follow the PEP 8 style guide.
- **Explicit is better than implicit:** Avoid excessive "magic". The code must be clear about what it does.
- **Static Typing (Type Hints):** Modern Python code must be typed. Use `typing` to define inputs and outputs.
- **Composition over Inheritance:** Although Python supports multiple inheritance, prefer composition and the use of Mixins or Interfaces (Protocols) to avoid the diamond problem and tight coupling.

## 2. Naming Conventions
- **Variables and Functions:** `snake_case` (e.g. `calculate_total_price`, `user_id`).
- **Classes and Exceptions:** `PascalCase` (e.g. `UserProfile`, `UserNotFoundException`).
- **Constants:** `UPPER_SNAKE_CASE` (e.g. `DEFAULT_TIMEOUT_SECONDS`).
- **Private:** Use a leading underscore `_variable` to indicate internal/protected use.
- **Avoid abbreviations:** Use `customer` instead of `cust`.

## 3. Modern Python (3.10+) and Typing
- **Type Hints:** It is MANDATORY to use type hints in function signatures.
  - Bad: `def greet(name):`
  - Good: `def greet(name: str) -> str:`
- **Unions:** Use the modern `|` syntax for unions (e.g. `int | None` instead of `Optional[int]`).
- **Dataclasses / Pydantic:**
  - Use `@dataclass` for simple data transfer objects.
  - Use **Pydantic** (`BaseModel`) for data validation, configurations and API schemas. Avoid raw dictionaries (`dict`) for passing structured data.
- **Pattern Matching:** Use `match/case` for complex conditional logic instead of long chains of `if/elif`.
- **Walrus Operator:** Use `:=` only if it significantly improves readability within a `while` or `if` condition.

## 4. Asynchronous Programming (Asyncio)
Apply these rules when code involves I/O Bound operations (Network, DB, Disk):
- **Async/Await:** Use `async def` for functions that perform I/O.
- **Non-blocking:** Never use blocking functions (like `time.sleep` or `requests.get`) inside an `async` function. Use their asynchronous counterparts (`asyncio.sleep`, `httpx` or `aiohttp`).
- **Concurrency:** Use `asyncio.gather()` to run independent tasks in parallel, instead of awaiting them sequentially (`await` in loop).
- **Context Managers:** Use `async with` to manage resources (DB connections, HTTP sessions) safely.
- **CPU Bound:** If the task is CPU intensive (heavy mathematical calculations), do NOT use `async`. Use `multiprocessing` or delegate to a separate worker (Celery/Rq).

## 5. Documentation and Docstrings (MCP Standard - Google Style)
- **Structured Documentation:** It is MANDATORY to use **Google Style Docstrings** (`""" ... """`) for all public functions, classes and modules. This format is highly readable for humans and tools (MCP).
    - **Summary:** One imperative sentence on the first line.
    - **Args:** List of arguments with their types and description.
    - **Returns:** Description of the return value and its type.
    - **Raises:** Explicit list of exceptions the function can raise.
- **Docstring Example:**
  ```python
  def fetch_user_data(user_id: int) -> dict[str, Any]:
      """Retrieves the user data from the external API.

      Args:
          user_id (int): The unique ID of the user.

      Returns:
          dict[str, Any]: A dictionary with the profile information.

      Raises:
          UserNotFoundError: If the ID does not exist in the remote system.
          ConnectionError: If the connection to the API fails.
      """
  ```

## 6. Error Handling (EAFP)
- **Specific Exceptions:** Never do `except Exception:`. Catch specific errors (e.g. `except ValueError:`).
- **Custom Exceptions:** Create domain-specific exceptions for business logic errors.
- **EAFP:** "Easier to Ask for Forgiveness than Permission". Prefer controlled `try/except` blocks before checking excessive conditions with `if` (though maintain common sense for simple validations).

## 7. Tests (Pytest)
- **Framework:** Assume pytest usage.
- **Fixtures:** Use `conftest.py` and `@pytest.fixture` for setup/teardown instead of `unittest.TestCase` classes.
- **Names:** Tests must start with `test_` and be descriptive (e.g. `test_calculate_total_returns_zero_when_empty`).

## 8. SOLID Principles & Design
- **S (SRP):** One module/class, one responsibility.
- **D (DIP):** Dependency Inversion. Do not instantiate low-level classes inside high-level classes. Pass them as arguments (dependency injection), facilitated by `Protocols` from `typing`.

## 9. Secure Development (OWASP & Python Best Practices)
- **Injection (SQL/Command):**
  - NEVER build SQL queries by concatenating strings (`f"SELECT * FROM users WHERE name = '{name}'"`). Always use **parameterized queries** or ORM tools (SQLAlchemy/Django).
  - Avoid `shell=True` in the `subprocess` module unless strictly necessary and you have sanitized the input with `shlex.quote()`.
- **Deserialization (Pickle):**
  - **PROHIBITED** to use `pickle` to load data from untrusted sources (cookies, uploads, network). `pickle` allows arbitrary remote code execution. Use `json` for standard data serialization.
- **Secrets Handling:**
  - NEVER hardcode passwords, API keys or tokens in source code.
  - Use environment variables (`os.getenv`) or configuration management libraries like `pydantic-settings`. Make sure `.env` files are in `.gitignore`.
- **Secure Randomness:**
  - Do not use the `random` module for security purposes (password generation, tokens, nonces). It is not cryptographically secure.
  - Use the **`secrets`** module (Python 3.6+) to generate secure tokens (e.g. `secrets.token_urlsafe()`).
- **Dangerous Functions:**
  - Avoid use of `eval()` and `exec()`. They are massive attack vectors.
  - Be careful with `yaml.load()`; always prefer `yaml.safe_load()`.
- **Path Traversal:**
  - When handling files based on user input, use `pathlib`. Resolve the path and verify it starts with the expected base directory before opening the file.
- **Absolute Paths (CRITICAL - Security & Portability):**
  - **PROHIBITED:** Hardcoding absolute paths in code (`/home/user/project/`, `/opt/app/`, `C:\Users\`)
  - **Rationale:** Exposes internal directory structure, breaks portability (Docker, cloud, other devs)
  - **REQUIRED:** Use relative paths, `pathlib`, or environment variables:
    ```python
    # ❌ NEVER
    config_path = "/home/user/project/config/settings.yaml"
    data_dir = "/opt/app/data/"
    
    # ✅ CORRECT
    from pathlib import Path
    config_path = Path(__file__).parent / "config" / "settings.yaml"
    data_dir = Path(os.getenv("DATA_DIR", "./data"))
    
    # ✅ Documented exceptions (system paths)
    temp_file = Path("/tmp/cache.tmp")  # System: Linux temporary directory
    ```
  - **Enforcement:** Blocked by `/MPLEMENT` ([PATH-XX]) and CI (`scripts/lint-format.sh`)
- **Dependencies:**
  - Fix dependency versions in `requirements.txt` or `pyproject.toml` to avoid supply chain attacks by malicious updates.
