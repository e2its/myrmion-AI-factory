---
applyTo: "backlog"
description: "Factory BACKLOG next-task guidance — determines the next executable step from execution plan and returns agent + command + evidence. Use when: user asks what to do next in the project."
---

# Backlog Next Task Guidance (v1.2.0)

> Loaded by the `backlog` mode to answer sequencing questions with a deterministic protocol.
> Goal: always return the next executable task, with exact agent and command.

---

## 0. Source Of Truth (Strict Order)

1. `/memories/repo/execution-plan-cache.md` (fast path — cache, checked first)
2. `docs/backlog/execution-plan.md` (primary source of truth for ordering/dependencies)
3. Configured tracking issue body (`project_tracking.tool`) (authoritative source for task details/command)
4. `/memories/repo/*` (other caches — never override source files)

If sources disagree:
- ordering/dependencies precedence: `execution-plan.md`
- task details/command precedence: issue body from configured tracking tool
- always report mismatch explicitly.

---

## 1. Detection Protocol

### Step 0: Cache Fast Path

```yaml
READ /memories/repo/execution-plan-cache.md
IF cache exists AND cache.last_synced is recent:
  IF cache.next_step exists AND cache.next_step.blocked_by == "none":
    # Cache can skip plan parsing, but MUST NOT bypass issue fetch when issue reference exists.
    CONTINUE using cache.next_step candidate
  ELIF cache.next_step.blocked_by != "none":
    RETURN blocker from cache
# Cache miss or stale: fall through to standard protocol
```

### Step 1.1: Parse execution order

Read `docs/backlog/execution-plan.md` top-to-bottom and identify checklist items:
- Completed: `- [x]`
- Pending: `- [ ]`

### Step 1.2: Select candidate

Select the first pending item in natural plan order.

### Step 1.3: Prerequisite gate

Confirm upstream required steps in the same dependency chain are complete.
If not complete, return blocker instead of skipping ahead.

### Step 1.4: Extract execution tuple

From the selected line, extract:
- `agent` (CODESIGN, BLUEPRINT, IMPLEMENT, DEVOPS, QA, BACKLOG)
- `command` (exact runnable command)
- `issue` (if present, e.g., `#13`, `PROJ-42`)
- `epic`, `slice`, and phase context

### Step 1.4.5: Fetch issue content from configured tool (MANDATORY when issue reference exists)

> **Why:** The execution-plan holds only a summary. The actual issue body may contain more specific acceptance criteria, updated constraints, or a different "Comando Factory" field. The issue is the authoritative spec.

```yaml
IF issue reference is null → SKIP this step

READ governance snapshot (.context/governance_snapshot.md) → project_tracking.tool

IF project_tracking.tool is undefined:
  WARN: "Issue reference exists ({issue_reference}) but project tracking configuration is missing. Continuing with execution-plan data only."
  PROCEED with execution-plan data

IF project_tracking.tool == "None"  (local mode):
  NORMALIZE issue reference to local_id
    → supports "#13" and "L-001"
  READ docs/backlog/state.md
  FIND entry for local_id and EXTRACT stored body_path
  READ local file from body_path

IF project_tracking.tool != "None"  (external mode):
  READ docs/backlog/project-config.json → integration, cli_command, tool_adapter_id
  READ docs/backlog/tool-adapter.md
  IF integration == "cli":
    RESOLVE abstract operation ISSUE_READ(issue_reference)
      using tool_adapter_id mappings from tool-adapter.md
    RUN: {resolved_cli_command}
    # Never hardcode CLI subcommands here; adapter resolves them.
  IF integration == "mcp":
    CALL adapter-defined MCP operation ISSUE_READ(issue_reference)

PARSE fetched content:
  - issue description / body
  - acceptance criteria / Definition of Done
  - "Comando Factory" field (if present)

IF "Comando Factory" in issue body differs from execution-plan command:
  SURFACE discrepancy:
    "⚠️ Mismatch: plan says '{plan_command}', issue says '{issue_command}'.
    The issue is the SSOT — using the issue command."
  SET command = issue_command

IF fetch fails (network / auth error):
  WARN: "Could not read issue {issue_reference} from {tool}. Continuing with execution-plan summary."
  PROCEED with execution-plan data
```

### Step 1.5: Update cache

After resolving the next task from disk, refresh `/memories/repo/execution-plan-cache.md` with the computed result.

---

## 2. Required Response Contract

Always return this structure:

- `next_task`: human readable task
- `agent`: exact agent name
- `command`: exact command string — from issue body "Comando Factory" when available; from execution-plan otherwise
- `issue`: issue reference if present
- `evidence`: source file path + issue URL/path when fetched
- `why_now`: one-line sequencing reason
- `if_blocked`: unblock command if prerequisites are missing
- `issue_context`: key acceptance criteria / DoD excerpt from issue body; `null` if not fetched
- `discrepancy`: description if plan command ≠ issue command; `none` otherwise

---

## 3. Blocking Rules

- Never invent issue IDs or statuses.
- Never skip pending prerequisites unless user explicitly requests reprioritization.
- If plan file is missing: block with clear action to restore it.
- If ambiguity exists: report assumptions explicitly.
- Cache fast path must still execute Step 1.4.5 when issue reference exists.
- **NEVER use hardcoded CLI subcommands** when reading issue content. Always resolve `ISSUE_READ` via `docs/backlog/tool-adapter.md`.
- **Issue body is authoritative** over the execution-plan summary. If they conflict, the issue wins and the discrepancy must be surfaced.
- If `project_tracking` is not configured (no governance snapshot and no setup.md), skip issue fetch and warn.

---

## 4. Minimal Answer Template

```text
Next task: {next_task}
Agent: {agent}
Command: {command}
Issue: {issue_or_n/a}
Evidence: docs/backlog/execution-plan.md{issue_url_if_fetched}
Reason: {why_now}
Blocker: {if_blocked_or_none}
Issue context: {acceptance_criteria_excerpt_or_n/a}
Plan↔issue mismatch: {discrepancy_or_none}
```


> **Note:** Always include `Issue context` and `Plan↔issue mismatch` fields. If issue content is not available, use `N/A` for context and `none` for mismatch.