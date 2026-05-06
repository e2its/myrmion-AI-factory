---
name: Factory-backlog-next-task
description: "Factory Next Task Resolver — computes the next executable backlog step and returns exact agent + command + evidence. Use when: asking what should be executed next in project sequence."
applicable_when:
  phase: [BACKLOG]
  command: [backlog]
---

# NEXT TASK RESOLVER (v1.2.0)

> **Shared operational skill** for sequencing decisions in backlog mode.
> Uses memory cache (fast path) and deterministic parsing of `docs/backlog/execution-plan.md` (authoritative).

---

## Input

Optional parameters inferred from user prompt:
- `feature_id` (e.g., FEAT-002)

Issue content fetch behavior:
- If issue reference exists, issue content is ALWAYS fetched from the configured tracking source (see STEP 5).

---

## Procedure

```yaml
STEP 0 (CACHE FAST PATH):
  READ /memories/repo/execution-plan-cache.md
  IF cache exists AND cache.next_step exists AND cache.last_synced recent:
    candidate = cache.next_step
    # Never bypass STEP 5. Cache fast path can skip plan parsing,
    # but issue fetch/discrepancy validation still runs when issue exists.
    FALL THROUGH to STEP 4.5 with candidate (skip STEPS 1-4)
  ELSE:
    FALL THROUGH to STEP 1

STEP 1:
  READ docs/backlog/execution-plan.md

STEP 2:
  PARSE checklist lines preserving file order

STEP 3:
  FIND first pending item (- [ ])

STEP 4:
  VALIDATE dependencies from preceding mandatory tasks
  IF blocked:
    RETURN blocker + unblock command

STEP 4.5:
  EXTRACT:
    - agent
    - command
    - issue      # e.g. "#13" or "PROJ-42" or null
    - cluster
    # NOTE: "cluster" field retained as alias for backward compatibility.
    # Semantically this is the epic (EPIC-{N}) the feature belongs to.
    # New consumers should prefer reading "epic" if present.
    - slice      # e.g. "EPIC-1.2" — the slice within the epic this step belongs to

STEP 5 (MANDATORY when issue reference is found):
  # Tool-agnostic: reads from the project_tracking tool configured in SETUP, not hardcoded to GitHub.
  READ governance snapshot (.context/governance_snapshot.md) → project_tracking.tool

  IF issue == null:
    SKIP — no issue reference available, proceed to STEP 6

  IF project_tracking.tool is undefined:
    WARN: "Issue reference exists ({issue_reference}) but project tracking configuration is missing. Continuing with execution-plan data only."
    PROCEED to STEP 6

  DETERMINE read strategy:
    CASE project_tracking.tool == "None"  (local mode):
      NORMALIZE issue reference to local_id
        → supports "#13" and "L-001" styles
      READ docs/backlog/state.md
      FIND entry for local_id and EXTRACT stored body_path
      READ local body file

    CASE project_tracking.tool != "None"  (external mode):
      READ docs/backlog/project-config.json → integration, cli_command, tool_adapter_id
      # External mode MUST go through tool-adapter abstraction
      # (docs/backlog/tool-adapter.md), not hardcoded subcommands.
      IF integration == "cli":
        RESOLVE adapter operation ISSUE_READ(issue_reference)
          using docs/backlog/tool-adapter.md + tool_adapter_id
        RUN: {resolved_cli_command}
        # Examples (resolved by adapter):
        # "gh issue view 13", "jira issue get PROJ-42", "linear issue ISSUE-7"
      IF integration == "mcp":
        CALL adapter-defined MCP operation ISSUE_READ(issue_reference)

  PARSE fetched content:
    - issue_title
    - issue_body (full description)
    - acceptance_criteria / Definition of Done
    - "Comando Factory" field (if present in body template)
    - any discrepancy fields

  COMPARE issue body "Comando Factory" vs execution-plan command:
    IF they differ:
      SURFACE discrepancy to user:
        "⚠️ Mismatch detected:
          execution-plan says: {plan_command}
          issue {issue_reference} says:  {issue_command}
        The issue is the authoritative source (SSOT = tracking tool).
        Using the issue command."
      SET command = issue_command  (issue body wins over plan summary)

  OUTPUT: enriched context from issue body for downstream agent execution

STEP 6:
  UPDATE /memories/repo/execution-plan-cache.md with resolved next step
  RETURN normalized action card (enriched with issue content when available)
```

---

## Output Contract

Return exactly:

- `next_task`
- `agent`
- `command` — sourced from issue body "Comando Factory" when available; falls back to execution-plan
- `issue`
- `cluster`
- `epic` — same as `cluster` (Agile-standard alias; preferred for new consumers)
- `slice` — the slice within the epic (e.g., `EPIC-1.2`); `null` if epic has a single slice
- `why_now`
- `source_refs` — includes issue URL/path when fetched
- `if_blocked`
- `issue_context` — full issue body excerpt (acceptance criteria, DoD) when fetched; `null` otherwise
- `discrepancy` — if plan command ≠ issue command, describes the conflict; `none` otherwise

---

## Example

- `next_task`: CODESIGN FEAT-002 (Organization & AuthZ multi-tenant RBAC)
- `agent`: CODESIGN
- `command`: `CODESIGN --start FEAT-002`
- `issue`: `#13`
- `cluster`: `Epic 1 - Foundation`
- `epic`: `EPIC-1`
- `slice`: `EPIC-1.1`
- `why_now`: FEAT-001 CODESIGN is completed and FEAT-002 is the next unchecked item in slice EPIC-1.1.
- `source_refs`: `docs/backlog/execution-plan.md`
- `if_blocked`: `none`

---

## Guardrails

- Source of truth is repository artifacts, not memory cache.
- Do not invent workflow progress.
- Cache fast path never skips STEP 5 when issue reference exists.
- **Issue body beats execution-plan summary.** When the tool-fetched issue body contains a "Comando Factory" field, that command is authoritative. The execution-plan only holds a summary.
- **Tool-agnostic:** NEVER hardcode CLI subcommands. Resolve `ISSUE_READ` via `docs/backlog/tool-adapter.md` and `tool_adapter_id`.
- **Local mode:** When `project_tracking.tool == "None"`, do NOT make CLI/API calls — resolve `body_path` from `docs/backlog/state.md` and read that file.
- If the plan is inconsistent with board state, report both and surface the discrepancy clearly before proceeding.
- If issue content cannot be fetched (network error, missing credentials), proceed with execution-plan data but warn the user explicitly.
