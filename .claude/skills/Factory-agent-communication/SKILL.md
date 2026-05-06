---
name: Factory-agent-communication
description: "Factory Agent Communication Protocol (ACP) — entry announcement, phase milestones, completion summary, Factory return briefing. Use when: controlling sub-agent output verbosity and structuring inter-agent communication."
applicable_when:
  always: true
---

# AGENT COMMUNICATION PROTOCOL (ACP v1.0.0)

> **Shared Protocol** — Referenced by: ALL sub-agents (audit, setup, codesign, blueprint, implement, devops, qa) + Factory (return briefing).
> Ensures the user always knows which agent is active, what it's doing, and what it produced.

**Problem:** Slash commands execute complex multi-phase operations. Without explicit communication, the user has no visibility into progress or results.

---

## 1. Entry Announcement (MANDATORY — First message when command starts)

Every sub-agent MUST announce itself immediately upon receiving control:

```markdown
🔧 **{AGENT_NAME}** executing `--{command} {FEATURE_ID}`

**Objective:** {one-line description of what this command will produce}
```

### Examples:
```markdown
🔧 **IMPLEMENT** executing `--build USR-001`

**Objective:** Generate source code, tests, peer review, and security audit for user authentication.
```

```markdown
🔧 **BLUEPRINT** executing `--start USR-001`

**Objective:** Design architecture, API contracts, and test strategy for user authentication.
```

### Entry Announcement Gate (BLOCKING — M-02):
```yaml
FUNCTION enforce_entry_announcement(agent_name, command, FEATURE_ID):
  # This gate MUST be the ABSOLUTE FIRST action of any sub-agent.
  # No tool call, file read, or governance loading may precede it.
  # The user must see which agent is active BEFORE any work begins.

  IF NOT first_message_is_announcement:
    ❌ BLOCK: "Entry announcement missing — user has no visibility into agent transition"
    EMIT announcement BEFORE any other action

  EMIT:
    "🔧 **{agent_name}** executing `--{command} {FEATURE_ID}`"
    "**Objective:** {derived_from_spec_title_NOT_invented}"

  # Only AFTER this announcement: proceed with governance loading, file reads, etc.
  ✅ Announcement emitted — proceed with command execution
```

### Rules:
- ALWAYS emit before any tool call or file read
- Keep to 2 lines maximum (agent+command, objective)
- Objective is derived from the feature spec title/description, NOT invented
- For multi-hat agents, do NOT announce hat switches (those are internal)

---

## 2. Phase Milestones (MANDATORY for multi-phase commands)

For commands with distinct execution phases, emit a milestone marker at the **start** of each phase:

```markdown
📋 **Phase {N}/{total}: {phase_name}**
```

### Phase Maps per Agent:

```yaml
AUDIT --audit:
  1/4: Governance Scan (Phase A)
  2/4: Architecture Analysis (Phase B)
  3/4: Infrastructure Review (Phase C)
  4/4: Security Assessment (Phase D)

SETUP --init:
  1/2: Requirements Discovery
  2/2: ADR-0000 Generation

SETUP --generate:
  1/4: Governance Checkpoints
  2/4: Constitution & Rules
  3/4: Scaffolding & CI/CD
  4/4: CIP & Validation Templates

CODESIGN --start:
  1/4: CIP Domain Concept Check
  2/4: Event Storming Discovery
  3/4: Spec & Mock Co-Creation
  4/4: Validation & Summary

CODESIGN --vision:
  1/3: Vision Discovery
  2/3: Artifact Generation
  3/3: Validation & Summary

BLUEPRINT --start:
  1/4: CIP Reuse Analysis
  2/4: Architecture Design
  3/4: Test Plan Co-Design
  4/4: Contract Generation & Validation

IMPLEMENT --plan:
  1/2: Codebase Survey & Task Decomposition
  2/2: Dev Plan Generation

IMPLEMENT --build:
  1/5: Prerequisites & DRY Gate
  2/5: TDD Implementation
  3/5: Peer Review (REVIEW hat)
  4/5: Security Audit (SEC hat)
  5/5: Completion Verification

DEVOPS --configure:
  1/2: Infrastructure Analysis
  2/2: DevOps Plan Generation

DEVOPS --deploy:
  1/3: Pre-deployment Checks
  2/3: Deployment Execution
  3/3: Smoke Test Verification

QA --verify:
  1/3: Test Execution
  2/3: DAST Scan & Analysis
  3/3: Report Generation
```

### Rules:
- ONLY emit at phase transitions, NOT for every sub-step
- Keep to 1 line — do NOT add descriptions
- For single-phase commands (`--approve`, `--refine` quick changes), milestones are OPTIONAL
- Do NOT emit milestones for file reads or governance loading (those are infrastructure)

---

## 3. Completion Summary (MANDATORY — Last message before command completes)

Before returning control to Factory, every sub-agent MUST emit a structured summary:

```markdown
✅ **{AGENT_NAME}** `--{command} {FEATURE_ID}` — completed

| Artifact | Status | Path |
|----------|--------|------|
| {artifact_name} | {Created/Updated/Unchanged} | `{path}` |
| ... | ... | ... |

**Checklist:**
- [x] Artifacts created/updated
- [x] Frontmatter status correct
- [x] Worklog entry written (APPEND_TO_WORKLOG)
- [x] Cascade executed (if applicable)
- [x] Smart Redirect computed

**Next steps:** {computed from Smart Redirect or agent knowledge}
```

### Completion Checklist (MANDATORY — Self-Verification Gate)

Before emitting the Completion Summary, every sub-agent MUST internally verify:

```text
CHECKLIST = [
  "artifacts_exist":     All expected output artifacts exist on disk,
  "frontmatter_valid":   Status field updated to correct value per lifecycle,
  "worklog_written":     APPEND_TO_WORKLOG executed with structured JSON entry,
  "cascade_executed":    CASCADE_PENDING_ITERATION run (if --refine with iteration bump),
  "changelog_appended":  Iteration changelog entry added (if --refine),
  "smart_redirect":      Next steps computed from artifact state (not hardcoded)
]

FOR EACH item IN CHECKLIST:
  IF item.applicable AND NOT item.done:
    ⚠️ SELF-CORRECT: Execute missing step BEFORE returning
    LOG: "ACP self-correction: {item} was missing, executed now"
```

**Rules:** The rendered checklist in the Completion Summary makes progress visible to the user and Factory's PMO Validation. Items not applicable to the command (e.g., cascade for `--approve`) should be omitted from the rendered output.

### Rules:
- Table includes ONLY artifacts relevant to the command (not all feature files)
- Status values: `Created` (new file), `Updated` (modified), `Unchanged` (verified but not changed)
- Next steps: 1-2 lines maximum, referencing the specific command the user should consider
- For `--approve` commands, emphasize what is now UNLOCKED (e.g., "IMPLEMENT now available")
- For `--build` commands, include file counts: "12 source files, 8 test files created"

### Failure Summary:
If command could not complete:

```markdown
⚠️ **{AGENT_NAME}** `--{command} {FEATURE_ID}` — blocked

**Reason:** {specific blocker}
**Resolution:** {what the user needs to do}
```

---

## 4. Factory Return Briefing (Executed by Factory after PMO Validation)

When Factory regains control after PMO Validation, it presents a **concise briefing** to the user:

```markdown
**{AGENT_NAME}** completed `--{command} {FEATURE_ID}` — {pass/issues detected}

{If issues: list each issue as bullet point}

### What's next?
{Smart Redirect computed actions — numbered list with commands}
```

### Factory Return Briefing Gate (BLOCKING — L-01):
```yaml
FUNCTION verify_briefing_not_redundant(briefing_content, agent_completion_summary):
  # Factory MUST NOT repeat the sub-agent's completion summary.
  # The user already saw the completion summary inline.
  # Factory's briefing adds VALUE via: PMO validation result + Smart Redirect.

  IF briefing_content CONTAINS agent_completion_summary.artifact_table:
    ❌ STRIP: Remove duplicated artifact table from briefing
    LOG: "Briefing de-duplicated: removed agent's artifact table"

  IF briefing_content.line_count > 5 (excluding next steps):
    ⚠️ TRIM: "Briefing too long ({line_count} lines). Keep to 3-5 lines max."

  # Briefing MUST contain:
  REQUIRED_ELEMENTS = ["pass/issues verdict", "next steps from Smart Redirect"]
  FOR EACH element IN REQUIRED_ELEMENTS:
    IF element NOT IN briefing_content:
      ❌ BLOCK: "Factory briefing missing: {element}"
      ADD element to briefing

  ✅ Briefing validated — concise, non-redundant, actionable
```

### Rules:
- If PMO Validation passes cleanly: single line + next steps
- If PMO Validation detects issues: list issues, then next steps
- ALWAYS include next steps (this is the key user value of the briefing)
- NEVER repeat the full completion summary (the sub-agent already showed it)

---

## Context Budget

```yaml
CONTEXT BUDGET:
  - Entry announcement: ~30 tokens
  - Phase milestone: ~10 tokens each
  - Completion summary: ~100-200 tokens
  - Total overhead per command: <500 tokens (~1% of typical agent context)
```
