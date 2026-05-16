---
name: factory-complexity-check
description: "Factory Complexity Check — invokes a project-configured complexity MCP (Semgrep or compatible) on changed files, normalises violations against soft/hard thresholds. Use when: BVL runs full_verification_gate, factory-pr-review axis 6 executes, or a user explicitly requests complexity analysis."
applicable_when:
  phase: [IMPLEMENT, QA]
  change_type: [feature, refactor]
mcp_contract:
  expected_response:
    - { file: "string", function: "string", ccn: "int" }
  invocation: "mcp__<server>__<tool>(files: list[str])"
  config_source: "config/quality.json"
---

# COMPLEXITY CHECK

> **Shared Protocol** — Referenced by: BVL `full_verification_gate` (post-test step), factory-pr-review (axis 6), user-invoked `/complexity` if materialised.
> Framework defines the process; the project chooses the MCP. Defaults are opinionated; tool is not.

**Core Principle:** A function's cyclomatic complexity beyond a calibrated threshold is a defect indicator (DC-28). Detection is delegated to a multi-language MCP server selected at SETUP time and recorded in `config/quality.json`. The skill itself is tool-agnostic.

## Configuration source

The skill reads `config/quality.json` at the project root. Required fields:

```json
{
  "$schema": "quality_v1",
  "complexity": {
    "enabled": true,
    "mcp_server": "semgrep",
    "mcp_tool_name": "scan_complexity",
    "thresholds": { "soft": 10, "hard": 15 },
    "bvl_gate": true,
    "pr_blocker": false
  }
}
```

- `enabled: false` OR `mcp_server: null` → skill no-ops, returns `{ ok: true, reason: "disabled" }`.
- `mcp_server` not present in the agent's tool registry at runtime → returns `{ ok: true, reason: "mcp-unavailable", advisory: true }`. NEVER blocks.
- `bvl_gate: false` → BVL consumer logs findings as advisory; never fails.
- `pr_blocker: true` → factory-pr-review escalates `hard` violations to blocker; otherwise advisory.

## Algorithm

```yaml
FUNCTION analyze_complexity(files: list[str]) -> Report:
  # 1. Load config + short-circuit if disabled.
  cfg = read_json("config/quality.json").complexity
  IF cfg == null OR cfg.enabled == false OR cfg.mcp_server == null:
    RETURN { ok: true, reason: "disabled", violations: [], thresholds_used: null, mcp_consulted: null }

  # 2. Resolve MCP tool. Tool name format: mcp__<server>__<tool_name>.
  tool_id = "mcp__" + cfg.mcp_server + "__" + cfg.mcp_tool_name
  IF tool_id NOT IN agent.available_tools:
    EMIT advisory: "complexity-mcp-unavailable: {tool_id} not in tool registry"
    RETURN { ok: true, reason: "mcp-unavailable", advisory: true, violations: [], thresholds_used: cfg.thresholds, mcp_consulted: null }

  # 3. Filter input file list to source files (drop docs/binaries via simple extension allowlist OR delegate to MCP).
  scanned = [f for f IN files IF is_source_file(f)]
  IF scanned == []:
    RETURN { ok: true, reason: "no-source-files", violations: [], thresholds_used: cfg.thresholds, mcp_consulted: cfg.mcp_server }

  # 4. Invoke MCP. Expected response shape: list of {file, function, ccn}.
  raw = INVOKE_TOOL(tool_id, { files: scanned })
  parsed = normalise_response(raw)   # see § Response normalisation

  # 5. Classify against thresholds.
  violations = []
  FOR EACH entry IN parsed:
    IF entry.ccn > cfg.thresholds.hard:
      violations.append({ ...entry, severity: "hard" })
    ELSE IF entry.ccn > cfg.thresholds.soft:
      violations.append({ ...entry, severity: "soft" })

  # 6. Return normalised report.
  RETURN {
    ok: true,
    reason: (violations == [] ? "ok" : "violations"),
    violations: violations,
    thresholds_used: cfg.thresholds,
    mcp_consulted: cfg.mcp_server
  }
```

## Response normalisation

The skill expects MCP responses to map cleanly to `{ file, function, ccn }`. Adapters MAY vary; the skill normalises common shapes:

| MCP shape | Mapping |
|-----------|---------|
| `{ findings: [{ path, name, complexity }] }` | `{ file: path, function: name, ccn: complexity }` |
| `{ results: [{ file, fn, ccn }] }` | passthrough |
| Flat list of `{ file, function, ccn }` | passthrough |
| Anything else | `{ ok: false, reason: "mcp-shape-unknown" }` — consumer treats as advisory, logs raw |

## Output Banner

When invoked, emit a single-line banner BEFORE returning (mirrors `factory-mcp-docs-scan` style):

```
🧮 Complexity Check — {mcp_server} ✓ | scanned {N} files | {H} hard / {S} soft / {O} ok
🧮 Complexity Check — disabled | (config/quality.json complexity.enabled=false)
🧮 Complexity Check — {mcp_server} ✗ unavailable | proceeding advisory
```

## Consumer integration

### BVL — factory-build-verification

After tests pass, BVL calls `analyze_complexity(changed_files_in_branch)` where `changed_files_in_branch = git diff --name-only $BASE..HEAD`. Treatment:
- `cfg.bvl_gate == true` AND `violations[*].severity == "hard"` present → BVL fails; humanised block names file + function + CCN + threshold.
- `cfg.bvl_gate == false` OR only `soft` violations → log under advisory; BVL passes.
- `reason in ("disabled", "mcp-unavailable", "no-source-files")` → silent pass (banner only).

### factory-pr-review — axis 6 (complexity)

Push-gate preflight calls the skill on the cumulative branch diff. Treatment:
- `cfg.pr_blocker == true` AND any `hard` violation → adds to `blockers[]` with category `complexity`.
- Otherwise → `important[]` (soft) / `nits[]` (informational) — advisory only.
- Output finding shape: `{ category: "complexity", file, function, ccn, threshold, severity, mcp: cfg.mcp_server }`.

## Rules

- **No tool hardcoding** — the skill MUST NOT reference Semgrep / radon / lizard / gocyclo by name in code paths. Tool selection is `config/quality.json`-driven.
- **Fail-open on infra issues** — missing MCP, malformed response, or absent config never blocks. Blocking is reserved for confirmed `hard` violations against present, parseable findings.
- **Per-invocation call** — no caching across BVL runs; complexity changes with every commit.
- **Source files only** — skip docs, binaries, generated artefacts. `is_source_file()` uses an extension allowlist documented in `config/quality.json.complexity.source_extensions` (default: `[".py", ".js", ".ts", ".tsx", ".jsx", ".go", ".java", ".rb", ".php", ".c", ".cpp", ".cs", ".swift", ".kt", ".rs"]`).
- **Banner emission** — mandatory before returning. Missing banner = `mal-iniciado`.

## Extending to a new MCP

A project may swap MCP servers without touching the skill. Steps:
1. Install the MCP and register it in the project's `mcp.json`.
2. Verify the response shape matches one of the rows in § Response normalisation; if not, ship a thin adapter or open an issue for skill-side normalisation.
3. Update `config/quality.json.complexity.mcp_server` + `.mcp_tool_name`.

The skill makes no opinion about which MCP is correct; that choice is RDR-ratified at SETUP (`Factory-setup-discovery` complexity discovery question).
