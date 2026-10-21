---
name: factory-build-verification
description: "Factory Build Verification Loop (BVL) — automated test execution, error parsing, auto-fix cycle, and full verification gate. Use when: IMPLEMENT --build executes tasks with TDD cycle requiring real test execution."
applicable_when:
  phase: [IMPLEMENT]
  command: [implement]
---

# BUILD VERIFICATION LOOP (BVL)

> **Shared Protocol** — Referenced by: IMPLEMENT agent (--build, --fix commands), the critics' verification loop (coverage + lint — run by the orchestrator, read by the governance lens), the security lens's loop (dependency audit + secret scan).
> Closes the TDD feedback loop by executing tests in the terminal, parsing errors, and auto-fixing.
> **Prerequisite:** The IMPLEMENT agent has `execute/runInTerminal` and `execute/getTerminalOutput` tools.

**Core Principle:** Code that isn't executed isn't verified. Writing tests is necessary but insufficient — they must be run, results parsed, and failures fixed in a closed loop before marking a task complete.

## Per-Increment Verification Scope

> When `IMPLEMENT --build` runs under `slicing_strategy: incremental` and a single increment is in BUILDING, `full_verification_gate(FEATURE_ID, increment_id)` MUST restrict its scope to the increment's source/test files. The aggregate (feature-level) gate runs only when every increment has closed.

**Rule:** `full_verification_gate(FEATURE_ID, increment_id=null)` accepts an optional `increment_id`:

- `increment_id == null` (default — monolithic features and the final aggregate run on the last incremental closure): unchanged behaviour. `COLLECT_ALL_SOURCE_FILES(FEATURE_ID)` returns every source/test file under each module the feature touches.
- `increment_id == "INC-N"`: scope is filtered to the source/test files mapped from the increment's tasks (`[INC-N.A.M]`, `[INC-N.B.M]`, `[INC-N.C.M]`) and contract surface (read from `increment_plan.md § 1`). **Tests** are selected by intersection (tests whose target files lie inside the increment scope, plus any test file explicitly created in the increment's Phase C tasks) and **lint** runs against the same scope set. **Typecheck, build, format, and SAST run repo-wide** even in slice mode — those tools need the full module graph (or the slice's branch state IS the repo, so a slice that breaks compilation breaks the whole repo). Slice-mode reduces test/lint runtime; it does not weaken the global compilation/security gates.

**Resolver contract:** `COLLECT_ALL_SOURCE_FILES(FEATURE_ID, increment_id=null)` reads `dev_plan.md` Section "## Increment {increment_id}" (when `increment_id` provided) to extract layer-tagged file paths; falls back to feature-level scope when null. Under `incremental`, `phase_verification(phase, files)` is already per-phase scoped — when called inside a slice build the caller MUST pre-filter `files` to the increment's set.

**Aggregate gate semantics:** The plan-level Completion Gate (Factory-implement-build.instructions.md § Completion Verification Gate) calls this function with `increment_id=null` ONLY when every entry in `dev_plan.frontmatter.increments[]` has `status: IMPLEMENTED_AND_VERIFIED`. Any earlier per-slice closure passes the slice id.

**No regression for monolithic features:** `slicing_strategy: monolithic` always calls with `increment_id=null` — exactly the v1.4.0 behaviour.

---

## Defect Discovery Hook

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
        IF pattern_signature SEMANTICALLY_MATCHES dc.invariant:
          LOG: "Known {dc.id} ({dc.name}) — already cataloged"
          RETURN  # Already known, no action needed

      # Novel pattern — propose cataloging
      PROPOSE_TO_USER:
        "Recurring defect pattern detected: {errors.summary}
         This pattern is NOT in the Defect Prevention Catalog.
         Propose cataloging as PDC-{next_pdc}? (the project's next own id)
         Pattern: {pattern_signature}
         Prevention: {suggested_prevention}"
      # If user approves → the Discovery Protocol of .claude/rules/defect-prevention.md
```

## Seed/Synthetic Data Alignment Gate

> When a feature touches seed/synthetic data scripts OR migration/schema files, `full_verification_gate()` MUST run the project's seed alignment test suite. This catches schema drift between migration definitions and seed data generators.

**Rule:** When `IMPLEMENT --build` runs `full_verification_gate(FEATURE_ID)` AND the feature touches files matching the project's seed script pattern OR schema/migration files, the gate MUST run the **Seed Alignment Tests** (the `seed-alignment` gate of `verification.gates`, or the `tests` gate's `scoped` command on the seed test files).

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

## Full Feature Scope Mandate (MANDATORY)

> When a feature is in `delta_mode: true` OR has a `cascade_source` annotation in `dev_plan.md` frontmatter, the gate MUST run the **full module scope**, not just changed files.

**Rule:** `full_verification_gate(FEATURE_ID)` runs against:
- **Backend:** every source file under each module the feature touches PLUS the matching test trees
- **Frontend:** every source file under the feature's frontend slice plus shared components if touched PLUS matching test files
- **All gates:** lint, format, typecheck, tests, SAST — for BOTH layers — even if only one layer was edited in the delta

The `COLLECT_ALL_SOURCE_FILES(FEATURE_ID)` resolver MUST consult `design.md` § Implementation Inventory (module/bounded context) and `dev_plan.md` frontmatter to compute scope, NOT a git diff.

**Order compliance (EVOL-051):** the critics' verdict precedes the loop — it is written as an artefact BEFORE `full_verification_gate` runs; the **commit** MUST NOT follow until the loop's seal is green (`python3 scripts/gate.py seal --check`). Never run the loop to earn a verdict and again after it.

**Security lens compliance:** the security lens MUST NOT issue `verdict: PASS` until SAST tools run against the FULL module scope.

---

## WHY THIS PROTOCOL EXISTS

The TDD cycle in IMPLEMENT --build previously followed: RED (write test) → GREEN (write code) → REFACTOR → **assume** tests pass. This leaves a critical gap — the agent never validates that the code actually compiles or that tests actually pass. BVL closes this gap by adding real execution after each task.

---

## THE LOOP'S MEMBERS — `verification.gates` (EVOL-067)

The loop names no stack. Its members are `config/quality.json → verification.gates`: `{<gate>: {reads, command, scoped?, red_link?, report?, red?}}`. SETUP derives them from the registry's `configures` rows (`gate.py discovery --resolve`); the project edits them like any config. `scoped` is the single-test form, `{paths}` the test files. EVOL-068: `red_link` — paths linked into the diff base for the built-in `red` member; `report` — the `coverage` row's LCOV file; `red: false` — red not proven for this stack: its scoped run selects tests by name, not by file — give `tests.scoped` a per-file command and drop `red: false` to enable the proof.

```yaml
FUNCTION gates():
  RETURN READ_JSON("config/quality.json").verification.gates   # the one source; no stack match, no override
```

Skips: `verification.skips [{gate, reason, at, until}]` — dated, expires; a security gate (`secrets`, `sast`, `sca`) is never skipped. `gate.py seal --plan` lists an active skip with its reason; an expired one is owed again.

---

## TASK-LEVEL VERIFICATION LOOP (Per TDD Task)

Runs after each task's GREEN phase (code written to pass the test).

```yaml
FUNCTION task_verification_loop(task, test_files, source_files):
  # Gate: Check if BVL is available for this stack
  g = gates()
  IF g.tests.scoped IS NULL:
    RETURN BLOCK(UNDECLARED_STACK)   # § GRACEFUL DEGRADATION — the task is not marked [x]
  
  MAX_ATTEMPTS = 3
  attempt = 0
  previous_errors = NULL
  
  WHILE attempt < MAX_ATTEMPTS:
    attempt += 1
    
    # Execute test
    test_cmd = INTERPOLATE(g.tests.scoped, {paths: test_files[0]})
    result = RUN_IN_TERMINAL(test_cmd, timeout: 60000)
    
    IF result.exit_code == 0:
      LOG: "✅ BVL: {task.id} GREEN (attempt {attempt})"
      RETURN GREEN
    
    # Parse errors
    errors = parse_test_output(result.output)
    
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
FUNCTION parse_test_output(raw_output):
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

## PHASE VERIFICATION (Post-Phase — Before the work critics)

Runs after all tasks in a phase are complete, before the work critics are spawned. **Scoped, never the full suite (EVOL-051):** the phase's own test files (the workers' red-first evidence, re-run together) plus lint and format on the phase's files — no build, no typecheck, no coverage run. The full suite runs once, in `full_verification_gate`, after the artefacts.

```yaml
FUNCTION phase_verification(phase, all_test_files):
  g = gates()
  IF g.tests.scoped IS NULL OR all_test_files IS EMPTY:
    RETURN SKIPPED

  # The phase's scoped tests — the files its tasks wrote or touched (the same selection task_verification_loop used)
  result = RUN_IN_TERMINAL(INTERPOLATE(g.tests.scoped, {paths: JOIN(all_test_files, " ")}), timeout: 120000)

  IF result.exit_code != 0:
    errors = parse_test_output(result.output)
    LOG: "❌ BVL Phase {phase}: scoped regression detected — {errors.summary}"
    RETURN REGRESSION(errors)
    # Caller (Phase Loop) handles regression fix loop

  # Lint and format, when declared — their own command; a red one: fix with the tool, run again
  FOR gate IN ["lint", "format"] WHERE g[gate] IS NOT NULL:
    r = RUN_IN_TERMINAL(g[gate].command, timeout: 30000)
    IF r.exit_code != 0: RETURN ISSUES(gate, r.output)

  LOG: "BVL Phase {phase}: scoped tests GREEN + Lint clean + Format clean"
  RETURN GREEN
```

---

## FULL VERIFICATION GATE (Pre-IMPLEMENTED_AND_VERIFIED)

**One full loop per change (EVOL-051).** The order per completed diff is: the **static round** (`python3 scripts/gate.py profile --run --control-point static` — every member that needs no build and no database, `digests` included — plus the workers' red-first scoped runs as the test evidence) → the **critics** (one round) → the **artefacts** (the review and security reports, the plan's ticks and its status: every tracked write) → **this loop, once**, on those bytes → the **commit** on its green. Cures found by the critics are re-checked by their scoped gate (`python3 scripts/gate.py seal --plan` names the gates the tree on disk owes), never by a full loop per cure. Each suite runs **once** per loop: the plan groups the gates by command — the suite that feeds coverage is one execution whose result feeds both `tests` and `coverage`. The gates the map names run through **the loop's executor** — `python3 scripts/gate.py seal --run [--full]` (EVOL-057): one call runs every execution the plan names, times each, streams its output to `<seal.dir>/loop-<gates>.log` with the tail on screen, appends one timing line per gate to the timings log (`verification.logs`, what the measurement subproduct reads) and records the **seal** right after each execution, before anything else can touch the tree; a gate the map names is the runner's and is NOT run again by the steps below (they keep the gates the map does not name and the advisory scans); a gate the map gives no command is recorded by its owner with `python3 scripts/gate.py seal --write --gates … --ok|--red`. The seal is an untracked state file the push honours through `gate.py seal --check`: nothing tracked is written after the green — a tracked write would move the tree the commit carries. After a green seal, a delta whose paths only documentation covers owes nothing; a delta that touches a gate's read-set owes that gate (`verification.gates` in `config/quality.json`); a changed path no gate reads owes the full loop (fail closed: declare its reader).

Runs after all phases complete, after the completion gate wrote the plan's status (§ Completion Gate, Factory-implement-build), before the commit. Accepts an optional `increment_id` to restrict scope to a single slice (see § v1.5.0 — Per-Increment Verification Scope).

```yaml
FUNCTION full_verification_gate(FEATURE_ID, increment_id=null):
  results = {}
  scope_label = increment_id IS NOT NULL ? "increment {increment_id}" : "feature aggregate"

  # EVOL-051 — the loop runs what the seal reader says the tree on disk owes: every gate after a change the seal
  # never covered (the full loop), only the gates whose read-set moved after a green seal (the incremental seal),
  # nothing after a documentation-only delta. One execution per distinct command; a red execution is recorded red.
  plan = RUN("python3 scripts/gate.py seal --plan --json")
  IF NOT plan.required: LOG "seal: n/a — {plan.reason}"          # a repo whose loop runs elsewhere (config says so)
  IF NOT plan.ok: RETURN BLOCKED(plan.reason)                       # no map, no config: nothing can run — never "nothing owed"
  owed = SET(plan.owed)                                              # empty AND plan.ok ⇒ the seal already covers this tree: RETURN PASSED(sealed)
  # EVOL-057 — the executions the plan names run through the loop's executor, which times each one, keeps its output
  # in <seal.dir>/loop-<gates>.log (the tail on screen — read the log, never paste it), appends the per-gate timing and
  # records the seal RIGHT AFTER the execution, before any auto-fix touches the tree:
  run = RUN("python3 scripts/gate.py seal --run --summary '{scope_label}'")      # exit 1 = a red execution; its log names the cause
  IF run.exit_code != 0: ❌ BLOCK: "{run.reason}" ; RETURN BLOCKED                 # cure, then `seal --plan` names what is owed; `seal --run` again
  mapped = KEYS(READ_JSON("config/quality.json").verification.gates)              # the runner's gates — every step below is guarded by it
  FOR g IN mapped: results[g] = {status: "GREEN (seal --run)"}
  # Every member is the runner's: the steps below keep the advisory scans. A red lint / format: fix with the tool,
  # then `seal --run` again — the gates whose read-set moved are owed again (`seal --write --full` refuses a stale one).
  #   A gate the map gives no command (an MCP-driven check) is recorded by its owner:
  #   RUN("python3 scripts/gate.py seal --write --gates <gate> --ok|--red --summary '<one line>'")
  # When every gate of the map holds a green record on the tree as it stands: `seal --run --full` (the tree is sealed).

  # Resolve scope-filtered file set ONCE — reused by every gate that takes `files`.
  # When increment_id is null this returns the feature-level set (legacy behaviour).
  scope_files = COLLECT_ALL_SOURCE_FILES(FEATURE_ID, increment_id)

  # 6. Seed alignment check (conditional)
  # Seed alignment tests run through the `tests` gate's `scoped` command (when no `seed-alignment` gate is declared).
  # The resolver scans for test files matching the seed alignment naming convention
  # (e.g., test_seed_schema_alignment, test_seed_deployment_isolation) under the project's
  # integration test directory. Stack-agnostic: the project's declared runner.
  IF scope_files MATCHES seed_script_pattern OR scope_files MATCHES migration_pattern:
    seed_test_files = GLOB("tests/**/test_seed_*" OR "tests/**/*seed*alignment*")
    seed_test_cmd = INTERPOLATE(gates().tests.scoped, {paths: seed_test_files})
    IF seed_test_cmd IS NOT NULL AND seed_test_files.length > 0 AND "seed-alignment" NOT IN mapped:
      result = RUN_IN_TERMINAL(seed_test_cmd, timeout: 60000)
      results.seed_alignment = {status: result.exit_code == 0 ? "ALIGNED" : "DRIFT"}
      IF result.exit_code != 0:
        BLOCK: "Seed schema alignment failed. Seed data drifted from migration schemas."
        RETURN BLOCKED

  # 7. Complexity check (DC-28 — cyclomatic complexity gate, MCP-driven)
  # Project-configured via config/quality.json. Tool-agnostic: skill picks the MCP at runtime
  # (default Semgrep, RDR-ratified at SETUP Q23.1). Fail-open: missing config, disabled gate,
  # unavailable MCP, or unparseable response → advisory only, never blocks.
  # Scope_files (already computed above) IS the changed-file set for the increment / feature.
  IF FILE_EXISTS("config/quality.json"):
    complexity_report = INVOKE_SKILL("factory-complexity-check", { files: scope_files })
    results.complexity = {
      status: complexity_report.reason,                  # disabled | mcp-unavailable | no-source-files | ok | violations
      mcp: complexity_report.mcp_consulted,
      violations: complexity_report.violations,          # [{file, function, ccn, severity}]
      thresholds: complexity_report.thresholds_used
    }
    quality_cfg = READ_JSON("config/quality.json").complexity
    hard_violations = [v FOR v IN complexity_report.violations IF v.severity == "hard"]
    IF quality_cfg.bvl_gate == true AND hard_violations.length > 0:
      ❌ BLOCK: "Complexity exceeded hard threshold ({quality_cfg.thresholds.hard}) on {hard_violations.length} function(s)."
      SHOW: humanise_complexity_violations(hard_violations)
      RETURN BLOCKED
    # Soft violations OR bvl_gate=false → advisory log only.

  # 8. Minimalism advisory (DC-29 — over-engineering self-scan, NON-BLOCKING)
  # No MCP: the agent (LLM) scans scope_files for the four DC-29 categories — reinvented stdlib,
  # unneeded dependency, single-implementation abstraction, dead flexibility. Advisory by design
  # (minimalism is subjective; the cost-saving lives in prevention at decision-time via
  # factory-adversarial-reasoning, NOT in post-hoc blocking). NEVER blocks IMPLEMENTED_AND_VERIFIED.
  # Fail-open: skip silently when the catalog is absent.
  # how-not-what guardrail: findings are logged for the author; a scope cut is NEVER auto-applied —
  # a real scope reduction routes to CODESIGN via RDR, not to this gate.
  IF FILE_EXISTS(".claude/rules/defect-prevention.md"):
    minimalism_findings = SCAN_DC29(scope_files)   # [{file, line, category, suggestion, net_lines}]
    results.minimalism = {
      status: minimalism_findings.length == 0 ? "lean" : "advisory",
      findings: minimalism_findings
    }
    IF minimalism_findings.length > 0:
      LOG: "ℹ️ BVL Minimalism (DC-29, advisory): {minimalism_findings.length} simplification(s) possible, net -{SUM(net_lines)} lines. Author decides — no block."
    # No RETURN BLOCKED from this step — ever.

  # All checks passed — seal the tree (untracked); the commit follows; nothing tracked is written after this line
  run = RUN("python3 scripts/gate.py seal --run --full --summary '{scope_label}: green'")   # the owed executions (none when every record is green), then the tree sealed
  IF run.exit_code != 0: ❌ BLOCK: "{run.reason}" ; RETURN BLOCKED                       # not sealed is not green: a gate without its record, a read-set that moved after its run
  LOG: "BVL Full Gate ({scope_label}): {FOR g IN mapped: g=results[g].status}, complexity={results.complexity.status}, minimalism={results.minimalism.status}"

  RETURN PASSED(results)
```

### `RESOLVE_INCREMENT_TEST_CMD` helper

```yaml
FUNCTION RESOLVE_INCREMENT_TEST_CMD(scope_files, increment_id):
  # Map scope_files to their test files: tests under the same module path, plus tests created in the increment.
  test_targets = DEDUPE(GLOB(test_pattern_for_module(f)) FOR f IN scope_files) + scope_files WHERE matches_test_naming_convention(file)
  IF test_targets IS EMPTY:
    RETURN gates().tests.command          # the suite
  RETURN INTERPOLATE(gates().tests.scoped, {paths: JOIN(test_targets, " ")})
```

---

## SAST OUTPUT PARSER

```yaml
FUNCTION parse_sast_results(raw_output):
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
  # Coverage runs ONLY in the critics' verification loop, not per-task
  STRIP_FLAGS: ["--coverage", "--cov"]
```

---

## GRACEFUL DEGRADATION

A missing declaration blocks; an infrastructure fault (a tool not installed, a crash, a timeout) degrades and is logged (#116).

```yaml
DEGRADATION_SCENARIOS:
  
  # No `tests` gate (or no `scoped` form) declared
  UNDECLARED_STACK:
    ACTION: BLOCK
    MESSAGE: "No test command is declared for this project, so the build cannot be checked."
    RESOLUTION: "Declare the gate rows in config/quality.json → verification.gates (SETUP discovery § verification coverage)."
  
  # Tool missing (the declared command's tool is not installed)
  TOOL_MISSING:
    ACTION: WARN + SKIP BVL
    LOG: "BVL degraded: {tool} not found — install with {install_cmd}"
    FALLBACK: Continue without execution
  
  # All 3 fix attempts failed
  MAX_ATTEMPTS_EXHAUSTED:
    ACTION: FLAG task in dev_plan.md with ⚠️ + continue to next task
    ANNOTATION: "⚠️ BVL: Tests failed after 3 attempts. Manual review required."
    NOTE: "- [ ] [FIX-BVL-{N}]: Manual fix needed — {error.summary}"
    FALLBACK: Task remains [x] but with BVL flag. The correctness lens MUST inspect.
  
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
| **TDD Cycle (per task)** | After GREEN phase → `task_verification_loop()` → marks [x] only if GREEN (SKIPPED = infrastructure fault, logged) |
| **Phase Loop (per phase)** | After all task [x] → `phase_verification()` (the phase's scoped tests + lint + format; no build) → before the work critics |
| **Work critics (per phase)** | `review_verification_loop()` (run by the main session) → the static round (`gate.py profile --run --control-point static`, digests included) + scoped lint → blockers feed the critics' verdict; coverage, typecheck and the full suite are deferred to the one loop |
| **Security lens (per phase)** | `sec_verification_loop()` (run by the main session) → the `sca` gate + the secrets dispatcher → blockers feed the security verdict |
| **Completion Gate** | After the artefacts (reports, ticks, the plan's status — the last tracked writes) → `full_verification_gate()` ONCE → the seal → the commit on its green (EVOL-051) |
| **--fix execution** | Same loop: write regression test → fix → `task_verification_loop()` |
| **Escalation** | FLAGGED tasks → Resilience Protocol (user choice: retry/modify/escalate/skip) |

---

## DECLARED GATE ROWS

A stack with no registry `configures` rows, or non-standard tooling, declares its rows at SETUP discovery (§ verification coverage) into `verification.gates`; a new stack's rows ship with its platform pack. `tests` and `coverage` may share one command (one execution feeds both).

```yaml
# config/quality.json
"verification": {"gates": {"tests": {"reads": ["src/**", "tests/**"], "command": "<suite>", "scoped": "<one test: {paths}>"}},
                 "skips": []}
```
