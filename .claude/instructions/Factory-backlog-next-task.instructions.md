---
applyTo: "backlog"
description: "Factory BACKLOG next-task guidance — determines the next executable step from execution plan and returns agent + command + evidence. Use when: user asks what to do next in the project."
---

# Backlog Next Task Guidance (v1.2.0)

> Loaded by the `backlog` mode to answer sequencing questions with a deterministic protocol.
> Goal: always return the next executable task, with exact agent and command.

---

## 0. Source Of Truth (Dual-Mode — EVOL-014)

> The resolver branches on `project_tracking.tool` (from Q27). Both modes are parallel — the resolver itself is mode-agnostic in its code path and always delegates to the tool-adapter. See [Factory-backlog-execution-plan.instructions.md § 0.3](Factory-backlog-execution-plan.instructions.md) for the full dual-mode contract.

### File mode (`project_tracking.tool == "None"`)

1. `/memories/repo/execution-plan-cache.md` (fast path — cache, checked first)
2. `docs/backlog/execution-plan.md` (primary source of truth for ordering/dependencies)
3. `docs/backlog/state.md` (authoritative for issue metadata and body refs — resolved via tool-adapter rendered from `none.md`)
4. `/memories/repo/*` (other caches — never override source files)

If sources disagree in file mode:
- ordering/dependencies precedence: `execution-plan.md`
- task details/command precedence: body file at `docs/backlog/issue-bodies/{local_id}.md`
- always report mismatch explicitly.

### Board mode (`project_tracking.tool != "None"`)

1. `/memories/repo/project-board-cache.md` (fast path — cache, checked first)
2. The configured external board, read via tool-adapter `query_board` (primary source of truth for ordering/dependencies AND issue metadata in board mode — the board IS the plan; `execution-plan.md` does NOT exist on disk in this mode)
3. Issue body fetched via tool-adapter `read_issue` (authoritative source for task details / "Factory command" field)
4. `/memories/repo/*` (other caches — never override the board)

If sources disagree in board mode:
- the board (via `query_board`) is ALWAYS authoritative; cache mismatches trigger a refresh, never a fallback
- always report drift explicitly.

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

### Step 1.3.5: Hard-gate enforcement (v14.0.0 — EVOL-014, full-sdlc preset only)

> Applies only when `project_tracking.feature_phases == "full-sdlc"`. `simplified` and `single` presets skip this step.

Before returning the candidate step, check whether the candidate command is one of the four downstream commands that an EVOL-014 hard gate blocks:

| Candidate command | Blocking gate issue | Resolver action if gate not Done |
| --- | --- | --- |
| `IMPLEMENT --plan {ID}` | `[{ID}] CONTRACT-FREEZE: …` (phase label `phase:contract-freeze`) | Return CONTRACT-FREEZE as the next task instead |
| `DEVOPS --deploy --env dev {ID}` | `[{ID}] PREVENTIVE-SWEEP: …` (phase label `phase:preventive-sweep`) | Return PREVENTIVE-SWEEP as the next task instead |
| `QA --verify {ID}` | `[{ID}] SMOKE-E2E: …` (phase label `phase:smoke-e2e`) | Return SMOKE-E2E as the next task instead |
| First `CODESIGN --start` of slice `{N}.{M+1}` within epic `{N}` | `[SLICE-{N}.{M}] INTEGRATION-TEST: …` (phase label `phase:integration-test`) | Return INTEGRATION-TEST as the next task instead |
| First `CODESIGN --start` of epic `{N+1}` | `[EPIC-{N}] RETROSPECTIVE: …` (phase label `phase:retrospective`) | Return RETROSPECTIVE as the next task instead |

```yaml
# Tool-agnostic gate lookup via the adapter — NEVER hardcode CLI queries here.
ADAPTER = READ docs/backlog/tool-adapter.md  # or in local mode the state.md-backed equivalent

FUNCTION find_gate_issue(phase_label, scope_token):
  # scope_token is the feature ID, slice ref (SLICE-1.2) or epic ref (EPIC-1) found in title
  items = ADAPTER.query_board()
  RETURN first item WHERE labels CONTAINS phase_label AND title CONTAINS scope_token

# 1. Per-feature gates
IF candidate.command matches "IMPLEMENT --plan {ID}":
  gate = find_gate_issue("phase:contract-freeze", candidate.feature_id)
  IF gate IS NULL OR gate.status != "Done":
    RETURN blocker = {
      next_task: gate.title if gate else "CONTRACT-FREEZE issue missing",
      agent: "BACKLOG",
      command: gate ? "Complete contract freeze for {candidate.feature_id}" : "BACKLOG --plan-feature {candidate.feature_id}",
      why_now: "CONTRACT-FREEZE gate must be Done before IMPLEMENT --plan can start (full-sdlc preset)",
      if_blocked: "none — gate is the work itself"
    }

IF candidate.command matches "DEVOPS --deploy --env dev {ID}":
  gate = find_gate_issue("phase:preventive-sweep", candidate.feature_id)
  IF gate IS NULL OR gate.status != "Done":
    RETURN blocker = { ...same shape, pointing to PREVENTIVE-SWEEP... }

IF candidate.command matches "QA --verify {ID}":
  gate = find_gate_issue("phase:smoke-e2e", candidate.feature_id)
  IF gate IS NULL OR gate.status != "Done":
    RETURN blocker = { ...same shape, pointing to SMOKE-E2E... }

# 2. Slice integration-test gate
IF candidate is the first phase issue of a feature in slice {N}.{M+1}:
  prev_slice_ref = "SLICE-{N}.{M}"
  gate = find_gate_issue("phase:integration-test", prev_slice_ref)
  IF gate AND gate.status != "Done":
    RETURN blocker pointing to the SLICE integration-test issue

# 3. Epic retrospective gate
IF candidate is the first phase issue of a feature in epic {N+1}:
  prev_epic_ref = "EPIC-{N}"
  gate = find_gate_issue("phase:retrospective", prev_epic_ref)
  IF gate AND gate.status != "Done":
    RETURN blocker pointing to the EPIC retrospective issue
```

> **Tool-agnostic invariant.** The resolver NEVER runs `gh` / `jira` / `linear` / `state.md` queries directly. All board reads go through `query_board` on the tool-adapter, which materialisation picks per project per Q27 answer (see `Factory-setup-materialization.instructions.md` § 6.1).

> **Stale-after-cascade tag handling.** When a gate issue carries the label `stale-after-cascade` or `stale-after-slice-peer-iterated` (placed by the iteration model — see `Factory-iteration-model/SKILL.md` § CASCADE_PENDING_ITERATION), the resolver treats the gate as NOT Done regardless of the board's status field. The label takes precedence until the gate is re-run and the label removed.

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