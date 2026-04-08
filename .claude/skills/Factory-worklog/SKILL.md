---
name: Factory-worklog
description: "Factory Worklog Enforcement — per-feature JSONL audit trail, action registration, phase mapping. Use when: any agent registers actions for traceability."
---

# WORKLOG ENFORCEMENT (v2.0.0)

> **Shared Protocol** — Referenced by: ALL agents + Factory (dispatcher enforcement).
> Ensures every agent action is recorded in a per-feature JSONL audit trail.

ALL agents MUST register their actions in the worklog for audit trail and traceability.

---

## Architecture: Per-Feature Segregation (v2.0.0)

```yaml
STRUCTURE:
  docs/project_log/
    workflow_log.json              # GLOBAL INDEX (metadata + counters only)
    features/
      {FEATURE_ID}.log.jsonl       # Per-feature log (JSONL: 1 JSON object per line)
      _global.log.jsonl            # Project-level (SETUP, AUDIT — no feature_id)

WRITE RULES:
  - Feature commands → APPEND to features/{FEATURE_ID}.log.jsonl
  - Global commands → APPEND to features/_global.log.jsonl
  - NEVER write entries to workflow_log.json (index only)

MIGRATION: If workflow_log.json contains entries[] → split by feature_id into .jsonl files
```

## APPEND_TO_WORKLOG Function

```yaml
FUNCTION APPEND_TO_WORKLOG(entry):
  # Determine target file
  target = entry.feature_id ? "docs/project_log/features/{feature_id}.log.jsonl" : "docs/project_log/features/_global.log.jsonl"
  # Append single JSON line (no pretty-print)
  APPEND_LINE(target, JSON_STRINGIFY_SINGLE_LINE(entry))
  # Update global index counters
  UPDATE workflow_log.json: last_updated, total_entries++, entries_by_agent[agent]++, entries_by_result[result]++
```

## Entry Format
```json
{"timestamp":"YYYY-MM-DD","phase":"Phase","user_agent":"AGENT","action":"description","result":"STATUS","feature_id":"ID","observations":"details"}
```

**`user_agent` Attribution Rule (MANDATORY):** The `user_agent` field MUST reflect the **actual agent that performed the work**, NOT a default or assumed agent.
- If IMPLEMENT executed the command → `"user_agent": "IMPLEMENT"`
- If Factory handled it directly (SCM, read-only) → `"user_agent": "FACTORY"`
- If Factory performed sub-agent work (dispatcher violation) → `"user_agent": "FACTORY"` with observation noting the violation
- **NEVER** set `user_agent` to a default mapping if that agent didn't actually execute

## Valid Statuses
`COMPLETED` | `IN_PROGRESS` | `FAILED` | `BLOCKED` | `APPROVED` | `REJECTED` | `FIXED` | `CORRECTED` | `ROLLBACK` | `SKIPPED` | `UPDATED`

## Phase Mapping
```yaml
AUDIT: → AUDIT (Due Diligence)
SETUP --init: → Discovery | --generate: → Materialization | --upgrade: → Materialization
CODESIGN: → Co-Creation
BLUEPRINT: → Blueprint
IMPLEMENT --plan: → Dev (Planning) | --build: → Dev (Implementation) | --fix: → Dev (Bugfix)
QA: → QA
DEVOPS: → DevOps
```

## Enforcement in Dispatcher
```yaml
BEFORE ANY agent: Verify docs/project_log/workflow_log.json + docs/project_log/features/ directory exist
  IF NOT: BLOCK with "Run SETUP --generate first" (except for SETUP/AUDIT themselves)

ON_COMMAND_START: APPEND_TO_WORKLOG with result: IN_PROGRESS
ON_COMMAND_SUCCESS: APPEND_TO_WORKLOG with result: COMPLETED
ON_COMMAND_ERROR: APPEND_TO_WORKLOG with result: FAILED/BLOCKED
ON_COMMAND_FIX: APPEND_TO_WORKLOG with result: FIXED

INTERNAL SUB-ACTIONS: Use parent command context (agent, feature_id, phase)
```
