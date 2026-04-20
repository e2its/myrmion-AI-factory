---
name: Factory-build-verification
description: "Factory Build Verification Loop (BVL) — automated test execution, error parsing, auto-fix cycle, and full verification gate. Use when: IMPLEMENT --build executes tasks with TDD cycle requiring real test execution."
---

# BUILD VERIFICATION LOOP (BVL v1.4.0)

> **Shared Protocol** — Referenced by: IMPLEMENT agent (--build, --fix commands), REVIEW hat (coverage + lint verification), SEC hat (dependency audit + secret scan).
> Closes the TDD feedback loop by executing tests in the terminal, parsing errors, and auto-fixing.
> **Prerequisite:** The IMPLEMENT agent has `execute/runInTerminal` and `execute/getTerminalOutput` tools.

**Core Principle:** Code that isn't executed isn't verified. Writing tests is necessary but insufficient — they must be run, results parsed, and failures fixed in a closed loop before marking a task complete.

## v1.4.0 — Defect Discovery Hook

> When BVL detects a test failure caused by a **recurring pattern** (not a one-off bug), the agent MUST check `.claude/rules/defect-prevention.md` and propose cataloging if the pattern is novel. This closes the improvement loop: discover→catalog→prevent→never again.

```yaml
FUNCTION defect_discovery_hook(errors, task, attempt):
  # Triggered when task_verification_loop returns FLAGGED (max attempts exhausted)
  # or when a fix reveals a systemic pattern (same error class in 2+ files)

  IF errors.recurrence_count >= 2 OR attempt == MAX_ATTEMPTS:
    # Check if this pattern is already cataloged
    catalog = READ(".claude/rules/defect-prevention.md")

    IF catalog EXISTS:
      existing_dcs = PARSE_DC_TABLE(catalog)
      pattern_signature = CLASSIFY_ERROR_PATTERN(errors)

      FOR EACH dc IN existing_dcs:
        IF pattern_signature SEMANTICALLY_MATCHES dc.applicable_when AND dc.prevention_check:
          LOG: "Known DC-{dc.number} ({dc.name}) — already cataloged"
          RETURN  # Already known, no action needed

      # Novel pattern — propose cataloging
      PROPOSE_TO_USER:
        "Recurring defect pattern detected: {errors.summary}
         This pattern is NOT in the Defect Prevention Catalog.
         Propose cataloging as DC-{next_dc_number}?
         Pattern: {pattern_signature}
         Prevention: {suggested_prevention}"
      # If user approves → Discovery Protocol in defect-prevention.md Section 3
```

## v1.3.0 — Seed/Synthetic Data Alignment Gate

> When a feature touches seed/synthetic data scripts OR migration/schema files, `full_verification_gate()` MUST run the project's seed alignment test suite. This catches schema drift between migration definitions and seed data generators.

**Rule:** When `IMPLEMENT --build` runs `full_verification_gate(FEATURE_ID)` AND the feature touches files matching the project's seed script pattern OR schema/migration files, the gate MUST run the **Seed Alignment Tests** (resolved via `resolve_verification_commands()`).

The test suite verifies:
- Every column written by seed scripts exists in the target schema
- Every NOT NULL column is provided by the seed generator
- UNIQUE constraints are not violated by the generated row set
- CHECK constraints (enum-like) are honored
- INSERT statements use schema-qualified table names

**Also runs Seed Deployment Isolation verification:**
- Seed scripts are physically excluded from the production deployment artifact
- Every seed script calls a fail-secure environment guard
- Guard uses an allowlist pattern (refuses to run when environment is unset/ambiguous)

**Failure is BLOCKING for `IMPLEMENTED_AND_VERIFIED` status.**

**Cross-feature applicability:** This gate applies to ALL modules. When a new module introduces its own seed file, the test discovers it automatically.

## v1.2.0 — Full Feature Scope Mandate (MANDATORY)

> When a feature is in `delta_mode: true` OR has a `cascade_source` annotation in `dev_plan.md` frontmatter, the gate MUST run the **full module scope**, not just changed files.

**Rule:** `full_verification_gate(FEATURE_ID)` runs against:
- **Backend:** every source file under each module the feature touches PLUS the matching test trees
- **Frontend:** every source file under the feature's frontend slice plus shared components if touched PLUS matching test files
- **All gates:** lint, format, typecheck, tests, SAST — for BOTH layers — even if only one layer was edited in the delta

The `COLLECT_ALL_SOURCE_FILES(FEATURE_ID)` resolver MUST consult `design.md` Section 1 (module/bounded context) and `dev_plan.md` frontmatter to compute scope, NOT a git diff.

**REVIEW hat compliance:** REVIEW hat MUST NOT issue `verdict: APPROVED` until `full_verification_gate(FEATURE_ID)` returns PASSED.

**SEC hat compliance:** SEC hat MUST NOT issue `verdict: PASS` until SAST tools run against the FULL module scope.

---

## WHY THIS PROTOCOL EXISTS

The TDD cycle in IMPLEMENT --build previously followed: RED (write test) → GREEN (write code) → REFACTOR → **assume** tests pass. This leaves a critical gap — the agent never validates that the code actually compiles or that tests actually pass. BVL closes this gap by adding real execution after each task.

---

## TEST COMMAND RESOLUTION (Automatic — No User Input Required)

Test commands are derived from the governance snapshot's Stack Configuration. No SETUP question needed.
Uses `/memories/repo/bvl-commands-cache.md` as acceleration layer (see `Factory-memory-cache/SKILL.md`).

```yaml
FUNCTION resolve_verification_commands():
  # Step 0: Cache Fast Path (MCP)
  # Check memory cache before reading governance snapshot + detecting frameworks.
  cache = MEMORY_READ("/memories/repo/bvl-commands-cache.md")
  IF cache IS NOT NULL:
    snapshot_hash = MD5(READ(".context/governance_snapshot.md"))
    IF cache.frontmatter.source_hash == snapshot_hash:
      LOG: "BVL commands loaded from cache"
      RETURN PARSE_COMMANDS(cache)  # Cache hit — skip derivation
    ELSE:
      LOG: "BVL commands cache stale — snapshot changed"
  
  # Step 1: Read from governance snapshot (summarization-safe — INVARIANT 5)
  snapshot = READ(".context/governance_snapshot.md")
  
  # Parse ## Verification Commands section (key: value lines)
  verification = PARSE_SECTION(snapshot, "## Verification Commands")
  
  IF verification IS NOT NULL AND verification.test_single IS NOT NULL:
    commands = verification  # Pre-computed commands from snapshot
  ELSE:
    # Fallback: derive from stack config (first run, or pre-BVL projects)
    stack = PARSE_SECTION(snapshot, "## Stack Configuration")
    commands = derive_commands_from_stack(stack)
  
  # Step 2: Write-Through Cache
  snapshot_hash = MD5(READ(".context/governance_snapshot.md"))
  write_bvl_commands_cache(commands, snapshot_hash)
  
  RETURN commands

FUNCTION derive_commands_from_stack(stack):
  # Derives verification commands from the ## Stack Configuration section of the
  # governance snapshot. Uses backend.runtime and frontend.framework fields.
  # Testing framework is inferred from config files when not explicitly set.
  commands = {}
  
  # Infer testing framework from project files
  testing_framework = DETECT_TESTING_FRAMEWORK(stack.backend.runtime):
    "Node.js"  → IF FILE_EXISTS("vitest.config.ts") OR FILE_EXISTS("vitest.config.js"): "vitest"
                  ELIF FILE_EXISTS("jest.config.ts") OR FILE_EXISTS("jest.config.js") OR FILE_EXISTS("jest.config.mjs"): "jest"
                  ELIF FILE_EXISTS(".mocharc.yml") OR FILE_EXISTS(".mocharc.json"): "mocha"
                  ELSE: "jest"  # Default for Node.js
    "Python"   → IF FILE_EXISTS("pytest.ini") OR FILE_EXISTS("pyproject.toml"): "pytest" ELSE: "pytest"
    DEFAULT    → NULL  # Built-in test runners for Java/Go/C#/Rust
  
  # Test runner
  commands.test_single = MATCH stack.backend.runtime:
    "Node.js"  → MATCH testing_framework:
                    "jest"    → "npx jest {test_file} --no-coverage --verbose"
                    "vitest"  → "npx vitest run {test_file}"
                    "mocha"   → "npx mocha {test_file}"
                    DEFAULT   → "npx jest {test_file} --no-coverage --verbose"
    "Python"   → MATCH testing_framework:
                    "pytest"  → "python -m pytest {test_file} -x --tb=short -q"
                    "unittest"→ "python -m pytest {test_file} -x --tb=short -q"
                    DEFAULT   → "python -m pytest {test_file} -x --tb=short -q"
    "Java"     → "mvn test -pl {module} -Dtest={test_class} -q"
    "Go"       → "go test {test_package} -run {test_name} -v"
    "C#"       → "dotnet test --filter {test_class} --verbosity minimal"
    "Rust"     → "cargo test {test_name} -- --nocapture"
    DEFAULT    → NULL  # Unknown stack — skip BVL with warning
  
  commands.test_suite = MATCH stack.backend.runtime:
    "Node.js"  → "npx jest --no-coverage"
    "Python"   → "python -m pytest -x --tb=short -q"
    "Java"     → "mvn test -q"
    "Go"       → "go test ./... -v"
    "C#"       → "dotnet test --verbosity minimal"
    "Rust"     → "cargo test"
    DEFAULT    → NULL
  
  # Lint runner
  commands.lint = MATCH stack.backend.runtime:
    "Node.js"  → "npx eslint {files} --max-warnings 0"
    "Python"   → "ruff check {files}"
    "Java"     → NULL  # IDE-based
    "Go"       → "golangci-lint run {files}"
    "C#"       → "dotnet format --verify-no-changes"
    "Rust"     → "cargo clippy -- -D warnings"
    DEFAULT    → NULL
  
  # Type check
  commands.typecheck = MATCH stack.backend.runtime:
    "Node.js"  → IF FILE_EXISTS("tsconfig.json"): "npx tsc --noEmit" ELSE: NULL
    "Python"   → IF FILE_EXISTS("mypy.ini") OR (FILE_EXISTS("pyproject.toml") AND TOML_HAS_SECTION("pyproject.toml", "tool.mypy")): "mypy {files}" ELSE: NULL
    DEFAULT    → NULL  # Statically typed languages don't need separate type check
  
  # Build check
  commands.build = MATCH stack.backend.runtime:
    "Node.js"  → IF FILE_EXISTS("package.json") AND JSON_HAS_KEY("package.json", "scripts.build"): "npm run build" ELSE: NULL
    "Python"   → NULL  # Interpreted
    "Java"     → "mvn compile -q"
    "Go"       → "go build ./..."
    "C#"       → "dotnet build --no-restore"
    "Rust"     → "cargo build"
    DEFAULT    → NULL
  
  # Frontend test runner (if frontend exists)
  IF stack.frontend IS NOT NULL AND stack.frontend.framework != "None":
    commands.frontend_test = MATCH stack.frontend.framework:
      "React" | "Next.js" → "npx jest --config jest.config.ts {test_file} --no-coverage"
      "Vue"               → "npx vitest run {test_file}"
      "Angular"           → "npx ng test --no-watch --browsers=ChromeHeadless"
      "Svelte"            → "npx vitest run {test_file}"
      DEFAULT             → commands.test_single  # Same as backend
  
  # Coverage report (used by REVIEW hat — Check #2 GOV-TEST threshold verification)
  commands.coverage = MATCH stack.backend.runtime:
    "Node.js"  → MATCH testing_framework:
                    "jest"    → "npx jest --coverage --coverageReporters=text-summary --no-cache"
                    "vitest"  → "npx vitest run --coverage --reporter=text"
                    DEFAULT   → "npx jest --coverage --coverageReporters=text-summary --no-cache"
    "Python"   → "python -m pytest --cov --cov-report=term-missing -q"
    "Java"     → "mvn verify -Djacoco.skip=false -q"
    "Go"       → "go test ./... -coverprofile=coverage.out && go tool cover -func=coverage.out"
    "C#"       → "dotnet test --collect:'XPlat Code Coverage' --results-directory ./coverage"
    "Rust"     → NULL  # Requires cargo-tarpaulin, optional
    DEFAULT    → NULL
  
  # Dependency vulnerability audit (used by SEC hat — CVE detection)
  commands.dependency_audit = MATCH stack.backend.runtime:
    "Node.js"  → "npm audit --omit=dev --audit-level=high 2>&1 || true"
    "Python"   → IF COMMAND_EXISTS("pip-audit"): "pip-audit --strict --desc 2>&1 || true"
                  ELIF COMMAND_EXISTS("safety"): "safety check 2>&1 || true"
                  ELSE: NULL
    "Java"     → IF FILE_EXISTS("pom.xml") AND COMMAND_EXISTS("grep") AND SHELL("grep -Eq '<groupId>org\\.owasp</groupId>|<artifactId>dependency-check-maven</artifactId>' pom.xml"): "mvn dependency-check:check -q" ELSE: NULL
    "Go"       → IF COMMAND_EXISTS("govulncheck"): "govulncheck ./... 2>&1 || true" ELSE: NULL
    "C#"       → "dotnet list package --vulnerable 2>&1 || true"
    "Rust"     → IF COMMAND_EXISTS("cargo-audit"): "cargo audit 2>&1 || true" ELSE: NULL
    DEFAULT    → NULL
  
  # Secret scanning (used by SEC hat — hardcoded credential detection)
  # Prioritizes dedicated tools; falls back to regex-based grep scan.
  commands.secret_scan = DETECT_SECRET_SCANNER():
    IF COMMAND_EXISTS("gitleaks"):  "gitleaks detect --source=. --no-git --redact -v 2>&1 || true"
    ELIF COMMAND_EXISTS("trufflehog"): "trufflehog filesystem --directory=. --no-update 2>&1 || true"
    ELSE: NULL  # Fallback: SEC hat uses regex-based scan (see implement-review-checks.md)
  
  RETURN commands
```

---

## TASK-LEVEL VERIFICATION LOOP (Per TDD Task)

Runs after each task's GREEN phase (code written to pass the test).

```yaml
FUNCTION task_verification_loop(task, test_files, source_files):
  # Gate: Check if BVL is available for this stack
  commands = resolve_verification_commands()
  IF commands.test_single IS NULL:
    ⚠️ WARN: "BVL: No test command for stack '{stack.backend.runtime}'. Skipping execution."
    LOG: "BVL_SKIPPED: {task.id} — unknown test runner"
    RETURN SKIPPED  # Graceful degradation — task still completes without execution
  
  MAX_ATTEMPTS = 3
  attempt = 0
  previous_errors = NULL
  
  WHILE attempt < MAX_ATTEMPTS:
    attempt += 1
    
    # Execute test
    test_cmd = INTERPOLATE(commands.test_single, {test_file: test_files[0]})
    result = RUN_IN_TERMINAL(test_cmd, timeout: 60000)
    
    IF result.exit_code == 0:
      LOG: "✅ BVL: {task.id} GREEN (attempt {attempt})"
      RETURN GREEN
    
    # Parse errors
    errors = parse_test_output(result.output, commands)
    
    # Detect fix loop (same error after fix → stop)
    IF attempt > 1 AND errors.signature == previous_errors.signature:
      LOG: "⚠️ BVL: {task.id} — same error after fix attempt {attempt}. Escalating."
      RETURN FLAGGED(errors)
    
    previous_errors = errors
    
    # Apply fix
    LOG: "🔧 BVL: {task.id} — attempt {attempt}/{MAX_ATTEMPTS}, fixing: {errors.summary}"
    apply_targeted_fix(source_files, test_files, errors, attempt)
  
  # Max attempts exhausted
  LOG: "⚠️ BVL: {task.id} — {MAX_ATTEMPTS} attempts exhausted. Manual intervention needed."
  RETURN FLAGGED(errors)
```

---

## ERROR PARSER (Token-Efficient Output Processing)

```yaml
FUNCTION parse_test_output(raw_output, commands):
  # Step 1: Truncate if too large
  # Test output can be 500+ lines. Only extract what's actionable.
  IF raw_output.lines > 100:
    # Keep only FAIL-relevant lines
    raw_output = FILTER_LINES(raw_output, KEEP: [
      "FAIL", "Error", "error", "Expected", "Received",
      "AssertionError", "TypeError", "ReferenceError",
      "at ", "✕", "✗", "FAILED", "not found", "Cannot find",
      "undefined", "null", "import", "require"
    ])
  
  # Step 2: Extract structured error info
  errors = {
    type: CLASSIFY(raw_output),  # assertion | compile | import | runtime | timeout
    summary: EXTRACT_FIRST_ERROR_LINE(raw_output),
    file: EXTRACT_FILE_PATH(raw_output),
    line: EXTRACT_LINE_NUMBER(raw_output),
    expected: EXTRACT_EXPECTED_VALUE(raw_output),
    received: EXTRACT_RECEIVED_VALUE(raw_output),
    stack: EXTRACT_STACK_TRACE(raw_output, max_lines: 5),
    signature: MD5(type + summary + file + line)  # For loop detection
  }
  
  RETURN errors
```

---

## TARGETED FIX STRATEGY (Per Attempt)

```yaml
FUNCTION apply_targeted_fix(source_files, test_files, errors, attempt):
  # Strategy escalates with each attempt
  
  IF attempt == 1:
    # Direct fix: address the specific error
    MATCH errors.type:
      "assertion":
        # Expected vs Received mismatch — fix logic in source
        READ source_files → find function producing wrong result
        FIX the logic to produce expected result
      
      "compile" | "import":
        # Missing import, wrong path, type error
        FIX imports, paths, type annotations in source
      
      "runtime":
        # Null reference, undefined property, etc.
        ADD defensive check or fix initialization
  
  ELIF attempt == 2:
    # Broader analysis: check dependencies and context
    READ related files (imports, shared modules, config)
    CHECK: Are all dependencies installed?
    CHECK: Are environment variables set in .env.example?
    CHECK: Do mock/stub files exist and export correctly?
    FIX based on broader context analysis
  
  ELIF attempt == 3:
    # Refactor approach: different implementation strategy
    ANALYZE: Is the current approach fundamentally wrong?
    CONSIDER: Alternative algorithm, different data structure, simpler logic
    REWRITE the failing function with a different strategy
    UPDATE test expectations ONLY if test was incorrectly derived from spec
```

---

## PHASE VERIFICATION (Post-Phase — Before REVIEW Hat)

Runs after all tasks in a phase are complete, before the REVIEW hat.

```yaml
FUNCTION phase_verification(phase, all_test_files):
  commands = resolve_verification_commands()
  IF commands.test_suite IS NULL:
    RETURN SKIPPED
  
  # Run full test suite for this phase
  result = RUN_IN_TERMINAL(commands.test_suite, timeout: 120000)
  
  IF result.exit_code != 0:
    errors = parse_test_output(result.output, commands)
    LOG: "❌ BVL Phase {phase}: Suite regression detected — {errors.summary}"
    RETURN REGRESSION(errors)
    # Caller (Phase Loop) handles regression fix loop
  
  # Lint check (if available)
  IF commands.lint IS NOT NULL:
    phase_files = COLLECT_SOURCE_FILES(phase)
    lint_cmd = INTERPOLATE(commands.lint, {files: phase_files})
    lint_result = RUN_IN_TERMINAL(lint_cmd, timeout: 30000)
    
    IF lint_result.exit_code != 0:
      LOG: "BVL Phase {phase}: Lint issues — auto-fixing"
      autofix_cmd = derive_autofix_command(commands.lint)
      
      IF autofix_cmd IS NOT NULL:
        RUN_IN_TERMINAL(autofix_cmd, timeout: 30000)
        recheck = RUN_IN_TERMINAL(lint_cmd, timeout: 30000)
        IF recheck.exit_code != 0:
          RETURN LINT_ISSUES(recheck.output)
      ELSE:
        RETURN LINT_ISSUES(lint_result.output)
  
  # Format check (v1.1.0 — between lint and typecheck)
  IF commands.format IS NOT NULL:
    format_result = RUN_IN_TERMINAL(commands.format, timeout: 30000)
    IF format_result.exit_code != 0:
      LOG: "BVL Phase {phase}: Format issues — auto-fixing"
      # Derive format-fix command from format-check command
      format_fix_cmd = derive_format_fix_command(commands.format)
      IF format_fix_cmd IS NOT NULL:
        RUN_IN_TERMINAL(format_fix_cmd, timeout: 30000)
        recheck = RUN_IN_TERMINAL(commands.format, timeout: 30000)
        IF recheck.exit_code != 0:
          RETURN FORMAT_ISSUES(recheck.output)
      ELSE:
        RETURN FORMAT_ISSUES(format_result.output)
  
  LOG: "BVL Phase {phase}: Suite GREEN + Lint clean + Format clean"
  RETURN GREEN
```

---

## FULL VERIFICATION GATE (Pre-IMPLEMENTED_AND_VERIFIED)

Runs after all phases complete, before status → IMPLEMENTED_AND_VERIFIED.

```yaml
FUNCTION full_verification_gate(FEATURE_ID):
  commands = resolve_verification_commands()
  results = {}
  
  # 1. Full test suite
  IF commands.test_suite IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.test_suite, timeout: 180000)
    results.tests = {
      status: result.exit_code == 0 ? "GREEN" : "RED",
      output: parse_test_output(result.output, commands) IF result.exit_code != 0 ELSE NULL
    }
    IF result.exit_code != 0:
      ❌ BLOCK: "Full test suite failed. Fix before marking IMPLEMENTED_AND_VERIFIED."
      SHOW: results.tests.output.summary
      RETURN BLOCKED
  
  # 2. Lint check
  IF commands.lint IS NOT NULL:
    all_source_files = COLLECT_ALL_SOURCE_FILES(FEATURE_ID)
    lint_cmd = INTERPOLATE(commands.lint, {files: all_source_files})
    result = RUN_IN_TERMINAL(lint_cmd, timeout: 30000)
    results.lint = {status: result.exit_code == 0 ? "CLEAN" : "ISSUES"}
    IF result.exit_code != 0:
      # Attempt auto-fix before blocking
      autofix_cmd = derive_autofix_command(commands.lint)
      IF autofix_cmd:
        RUN_IN_TERMINAL(autofix_cmd, timeout: 30000)
        recheck = RUN_IN_TERMINAL(lint_cmd, timeout: 30000)
        IF recheck.exit_code != 0:
          ❌ BLOCK: "Lint issues remain after auto-fix."
          RETURN BLOCKED
        results.lint.status = "CLEAN (auto-fixed)"
      ELSE:
        ❌ BLOCK: "Lint issues detected. Fix manually."
        RETURN BLOCKED
  
  # 3. Type check
  IF commands.typecheck IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.typecheck, timeout: 60000)
    results.typecheck = {status: result.exit_code == 0 ? "CLEAN" : "ERRORS"}
    IF result.exit_code != 0:
      ❌ BLOCK: "Type errors detected."
      SHOW: parse_test_output(result.output, commands).summary
      RETURN BLOCKED
  
  # 4. Build check
  IF commands.build IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.build, timeout: 120000)
    results.build = {status: result.exit_code == 0 ? "SUCCESS" : "FAILED"}
    IF result.exit_code != 0:
      ❌ BLOCK: "Build failed."
      SHOW: parse_test_output(result.output, commands).summary
      RETURN BLOCKED
  
  # 4a. Format check (v1.1.0)
  IF commands.format IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.format, timeout: 30000)
    results.format = {status: result.exit_code == 0 ? "CLEAN" : "ISSUES"}
    IF result.exit_code != 0:
      format_fix_cmd = derive_format_fix_command(commands.format)
      IF format_fix_cmd:
        RUN_IN_TERMINAL(format_fix_cmd, timeout: 30000)
        recheck = RUN_IN_TERMINAL(commands.format, timeout: 30000)
        IF recheck.exit_code != 0:
          BLOCK: "Format issues remain after auto-fix."
          RETURN BLOCKED
        results.format.status = "CLEAN (auto-fixed)"
      ELSE:
        BLOCK: "Format issues detected. Fix manually."
        RETURN BLOCKED

  # 5. SAST check (v1.1.0)
  IF commands.sast IS NOT NULL:
    result = RUN_IN_TERMINAL(commands.sast, timeout: 120000)
    sast_findings = parse_sast_results(result.output, commands)
    results.sast = {
      status: sast_findings.critical == 0 AND sast_findings.high == 0 ? "CLEAN" : "FINDINGS",
      summary: sast_findings.summary
    }
    IF sast_findings.critical > 0 OR sast_findings.high > 0:
      BLOCK: "SAST found {sast_findings.critical} CRITICAL + {sast_findings.high} HIGH"
      RETURN BLOCKED

  # 6. Seed alignment check (v1.3.0 — conditional)
  # Seed alignment tests are resolved from the project's test suite via commands.test_single.
  # The resolver scans for test files matching the seed alignment naming convention
  # (e.g., test_seed_schema_alignment, test_seed_deployment_isolation) under the project's
  # integration test directory. Stack-agnostic: uses BVL's test runner (pytest, jest, go test, etc.)
  feature_files = COLLECT_ALL_SOURCE_FILES(FEATURE_ID)
  IF feature_files MATCHES seed_script_pattern OR feature_files MATCHES migration_pattern:
    seed_test_files = GLOB("tests/**/test_seed_*" OR "tests/**/*seed*alignment*")
    seed_test_cmd = INTERPOLATE(commands.test_single, {test_file: seed_test_files})
    IF seed_test_cmd IS NOT NULL AND seed_test_files.length > 0:
      result = RUN_IN_TERMINAL(seed_test_cmd, timeout: 60000)
      results.seed_alignment = {status: result.exit_code == 0 ? "ALIGNED" : "DRIFT"}
      IF result.exit_code != 0:
        BLOCK: "Seed schema alignment failed. Seed data drifted from migration schemas."
        RETURN BLOCKED

  # All checks passed
  LOG: "BVL Full Gate: tests={results.tests.status}, lint={results.lint.status}, format={results.format.status}, types={results.typecheck.status}, build={results.build.status}, sast={results.sast.status}"
  
  RETURN PASSED(results)
```

---

## SAST OUTPUT PARSER (v1.1.0)

```yaml
FUNCTION parse_sast_results(raw_output, commands):
  # Parses SAST tool output into structured findings.
  # Supports JSON output format (preferred) and plain text fallback.

  findings = []

  # Step 1: Detect output format
  IF raw_output STARTS_WITH "{" OR raw_output STARTS_WITH "[":
    # JSON format (common for bandit -f json, gosec -fmt json, etc.)
    parsed = JSON_PARSE(raw_output)

    # Normalize from tool-specific JSON format:
    IF parsed.results IS NOT NULL:  # bandit-style
      FOR EACH result IN parsed.results:
        findings.push({
          test_id: result.test_id,
          file: result.filename,
          line: result.line_number,
          description: result.issue_text,
          severity: result.issue_severity,
          confidence: result.issue_confidence,
          cwe: result.issue_cwe.id OR NULL,
          code: result.code
        })
    ELIF parsed IS ARRAY:  # gosec/generic array style
      FOR EACH item IN parsed:
        findings.push(NORMALIZE_FINDING(item))
  ELSE:
    # Plain text fallback: grep for severity markers
    FOR EACH line IN raw_output.lines:
      IF line MATCHES severity pattern (HIGH, MEDIUM, LOW, CRITICAL):
        findings.push(EXTRACT_FINDING_FROM_LINE(line))

  # Step 2: Classify
  critical = findings.filter(f => f.severity == "CRITICAL").length
  high = findings.filter(f => f.severity == "HIGH").length
  medium = findings.filter(f => f.severity == "MEDIUM").length
  low = findings.filter(f => f.severity == "LOW").length

  summary = "{critical} critical, {high} high, {medium} medium, {low} low"

  RETURN { findings, critical, high, medium, low, summary }
```

---

## TOKEN BUDGET GUARD

Terminal output from test runners can be very large. These guards prevent context window overflow.

```yaml
TOKEN_BUDGET_RULES:
  # 1. Timeout all executions (prevents hanging on interactive prompts)
  DEFAULT_TIMEOUT: 60000  # 60 seconds per task test
  SUITE_TIMEOUT: 180000   # 3 minutes for full suite
  COVERAGE_TIMEOUT: 120000  # 2 minutes for coverage report
  AUDIT_TIMEOUT: 60000    # 60 seconds for dependency audit
  SECRET_SCAN_TIMEOUT: 30000  # 30 seconds for secret scanning
  
  # 2. Output truncation
  MAX_OUTPUT_LINES: 80
  TRUNCATION_STRATEGY:
    KEEP: Lines containing FAIL, Error, Expected, Received, assertion, ✕,
          vulnerability, CRITICAL, HIGH, secret, password, api_key, coverage, %
    DISCARD: Lines containing PASS, ✓, timing info, coverage tables, blank lines
    ALWAYS_KEEP: First 5 lines (summary) + Last 10 lines (totals)
  
  # 3. Never run tests in watch mode
  PROHIBITED_FLAGS: ["--watch", "--watchAll", "-w"]
  
  # 4. Never run coverage during BVL task loop (saves time + output)
  # Coverage runs ONLY in REVIEW hat verification, not per-task
  STRIP_FLAGS: ["--coverage", "--cov"]
```

---

## GRACEFUL DEGRADATION

BVL is designed to enhance, not block. If execution is unavailable, the build continues with semantic verification only.

```yaml
DEGRADATION_SCENARIOS:
  
  # No test runner detected for stack
  UNKNOWN_STACK:
    ACTION: WARN + SKIP BVL
    LOG: "BVL degraded: unknown stack — semantic verification only"
    FALLBACK: REVIEW + SEC hats continue normally
  
  # Tool missing (e.g., npx not installed)
  TOOL_MISSING:
    ACTION: WARN + SKIP BVL
    LOG: "BVL degraded: {tool} not found — install with {install_cmd}"
    FALLBACK: Continue without execution
  
  # All 3 fix attempts failed
  MAX_ATTEMPTS_EXHAUSTED:
    ACTION: FLAG task in dev_plan.md with ⚠️ + continue to next task
    ANNOTATION: "⚠️ BVL: Tests failed after 3 attempts. Manual review required."
    NOTE: "- [ ] [FIX-BVL-{N}]: Manual fix needed — {error.summary}"
    FALLBACK: Task remains [x] but with BVL flag. REVIEW hat MUST inspect.
  
  # Timeout exceeded
  EXECUTION_TIMEOUT:
    ACTION: WARN + note in dev_plan.md
    LOG: "BVL timeout: {test_file} exceeded {timeout}ms"
    FALLBACK: Continue — might indicate infinite loop or missing mock
```

---

## INTEGRATION POINTS

| Where | How BVL Integrates |
|-------|-------------------|
| **TDD Cycle (per task)** | After GREEN phase → `task_verification_loop()` → marks [x] only if GREEN or SKIPPED |
| **Phase Loop (per phase)** | After all task [x] → `phase_verification()` → before REVIEW hat |
| **REVIEW Hat (per phase)** | `review_verification_loop()` → runs coverage + lint + typecheck → blockers feed REVIEW verdict |
| **SEC Hat (per phase)** | `sec_verification_loop()` → runs dependency_audit + secret_scan → blockers feed SEC verdict |
| **Completion Gate** | After all phases → `full_verification_gate()` → before IMPLEMENTED_AND_VERIFIED |
| **--fix execution** | Same loop: write regression test → fix → `task_verification_loop()` |
| **Escalation** | FLAGGED tasks → Resilience Protocol (user choice: retry/modify/escalate/skip) |

---

## VERIFICATION COMMANDS IN GOVERNANCE SNAPSHOT

The snapshot includes a `## Verification Commands` section auto-derived from Stack Configuration during SETUP --generate. This avoids re-computing commands on every build.

```yaml
# Section added to .context/governance_snapshot.md:
## Verification Commands
> Auto-derived from Stack Configuration. Used by BVL (Build Verification Loop).
> Override by editing this section manually if project uses non-standard tooling.
test_single: "{resolved_command}"
test_suite: "{resolved_command}"
lint: "{resolved_command}"
typecheck: "{resolved_command}"
build: "{resolved_command}"
frontend_test: "{resolved_command}"
coverage: "{resolved_command}"
dependency_audit: "{resolved_command}"
secret_scan: "{resolved_command}"
```
