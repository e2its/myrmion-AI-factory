---
description: "Defect Prevention Catalog (DPC) — living catalog of runtime defect patterns invisible to static gates. Consulted by every SDLC agent filtered by each entry's applicable_to + feature_scope fields. Managed by the discover-catalog-prevent loop across all agents."
version: 2.2.0
date: {{TIMESTAMP}}
changelog:
  - "1.0.0: Initial — starter defect classes materialized from SETUP stack detection. Process integration: DEV pre-write check, REVIEW Check #2d, Discovery Protocol."
  - "2.0.0: Universal consumption — every SDLC agent consults the catalog filtered by applicable_to. Added applicable_to schema field, 8 consumer sections, expanded relationship table."
  - "2.1.0: feat(EVOL-016): rules relocated to .claude/rules/; protected-paths.json + allowlist.json relocated to config/."
  - "2.2.0: feat(EVOL-019): feature_scope schema field added — entries can restrict to scope IN [full-stack, backend-only, frontend-only, integration]. consult_defect_catalog() gains a feature_context.feature_scope filter. Enables the 7 starter integration DCs shipped by EVOL-019 Phase 2."
---

# Defect Prevention Catalog (DPC)

> **Version:** 2.0.0
> **Created:** {{TIMESTAMP}}
> **Scope:** ALL modules, ALL features, ALL agents
> **Enforcement:** Universal — every SDLC agent consults the catalog filtered by the `applicable_to` field of each entry.

## Purpose

Static gates (lint, typecheck, SAST, unit tests) form a strong Build Verification Loop but **cannot catch defects that only appear under real infrastructure execution** — real auth providers, real databases, real CDNs, real browsers. This rule maintains a living catalog of empirically-discovered defect patterns and mandates that every agent consults it at the points in the lifecycle where it can actually prevent or detect the defect.

The goal is **continuous process improvement**: every runtime defect discovered during development, fix, or evolution feeds back into this catalog, making future development cycles progressively cleaner.

---

## The Defect Prevention Catalog

Each entry has the following schema:

| Field | Meaning |
| --- | --- |
| **DC** | Unique sequential id (DC-1, DC-2, …) |
| **Name** | Short descriptive title |
| **Applicable When** | Scope condition (which stacks, topologies, or feature types this pattern applies to). Uses free-form prose for human readability; the canonical filter is `Applicable To` + `Feature Scope` + per-entry stack conditionals evaluated at materialisation time. |
| **Applicable To** | **[v2.0.0]** Enum list of SDLC agents that MUST consult this entry. Values: `CODESIGN`, `BLUEPRINT`, `IMPLEMENT`, `REVIEW`, `DEVOPS`, `QA`, `AUDIT`. (SETUP is never a consumer — it materializes the catalog, does not consume it.) An entry can list multiple agents. |
| **Feature Scope** | **[NEW in v2.2.0 — EVOL-019]** Optional enum list from `[full-stack, backend-only, frontend-only, integration]`. When omitted OR empty → entry applies to ALL scopes (backward-compatible). When present → entry is consulted ONLY when the feature's `scope` is in the list. Enables scope-aware DCs: integration patterns (idempotency, retry, DLQ, graceful shutdown) filter to `[backend-only, integration]`; UI patterns (WCAG, hook ordering, responsive gaps) filter to `[full-stack, frontend-only]`; universal patterns (mutation semantics, CORS, pipeline short-circuit) omit the field. |
| **Severity** | `BLOCKER` or `WARNING` when the entry is violated by a consumer |
| **Check (per consumer)** | What each listed consumer verifies. May be a single check when one agent owns it, or a table mapping agent→check when multiple consume |

The authoritative detailed search methodology for the runtime sweep lives in `.claude/skills/Factory-preventive-sweep/SKILL.md`.

> **SETUP materialization note:** The starter DCs below were selected based on the project's stack configuration. Extend this catalog with project-specific discoveries using the Discovery Protocol (§ 8).

| DC | Name | Applicable When | Applicable To | Feature Scope | Severity | Check |
|----|------|-----------------|---------------|---------------|----------|-------|
{{DC_ENTRIES}}

---

## Canonical Consultation Protocol

Every consumer (CODESIGN, BLUEPRINT, IMPLEMENT, REVIEW, DEVOPS, QA, AUDIT) implements the same read pattern:

```yaml
FUNCTION consult_defect_catalog(current_agent, feature_context):
  IF NOT FILE_EXISTS(".claude/rules/defect-prevention.md"):
    ⚠️ WARN: "Defect Prevention Catalog not found — SETUP may not have materialised it."
    RETURN []  # Non-blocking: missing catalog is a SETUP problem, not a feature problem

  catalog = READ ".claude/rules/defect-prevention.md" → parse DC entries
  applicable = []
  FOR EACH dc IN catalog:
    # Filter 1: Is this agent in the DC's applicable_to list?
    IF current_agent NOT IN dc.applicable_to:
      CONTINUE
    # Filter 2 (EVOL-019 — v2.2.0): Feature scope match?
    # When dc.feature_scope is omitted or empty → entry applies to ALL scopes (backward-compatible).
    # When present → entry is consulted ONLY when feature_context.feature_scope is in the list.
    IF dc.feature_scope IS NOT NULL AND dc.feature_scope IS NOT EMPTY:
      IF feature_context.feature_scope NOT IN dc.feature_scope:
        CONTINUE
    # Filter 3: Does the feature's context match "Applicable When"? (free-form — stack conditions)
    IF evaluate_scope_condition(dc.applicable_when, feature_context) == false:
      CONTINUE
    applicable.append(dc)

  RETURN applicable
```

**Caller contract (EVOL-019).** Every consumer MUST pass `feature_context.feature_scope` read from `docs/spec/{ID}/spec.feature` frontmatter — OR fall back to `project_scope` from the governance snapshot when invoked pre-feature (e.g. AUDIT at project level). Consumers that pre-date EVOL-019 (no feature_scope in feature_context) degrade gracefully: Filter 2 skips when `feature_scope` is undefined, matching the pre-EVOL-019 behaviour.

**Outputs** (what the agent does with the filtered list) are agent-specific and documented in the per-agent sections below.

---

## Mandatory Process Integration (by agent)

### 1. CODESIGN — Pre-Spec Advisory (NON-BLOCKING)

**When:** `CODESIGN --start {ID}` and `CODESIGN --refine {ID}`, after loading the UX Vision and BEFORE drafting Gherkin scenarios.

**What:** Consult the catalog, project applicable DCs into the spec as acceptance hints.

```yaml
applicable_dcs = consult_defect_catalog("CODESIGN", feature_context)
FOR EACH dc IN applicable_dcs:
  IF dc.type == "ux_pattern" OR dc.type == "accessibility" OR dc.type == "business_rule":
    ADD to spec.feature § Notes:
      "⚠️ DC-{N} ({dc.name}): acceptance criteria should cover this scenario.
       Prevention: {dc.check}"
```

**Output artefact:** `docs/spec/{ID}/spec.feature` gains a `## Defect-Prevention Notes` section (when non-empty) listing applicable DCs as drafting hints. Advisory only — the CODESIGN agent does NOT block on this. Ignoring a hint is tracked as a risk in the next REVIEW cycle, not as a spec violation.

### 2. BLUEPRINT — Pre-Design Advisory + Design Gate (BLOCKING at `--approve`)

**When:** `BLUEPRINT --start {ID}` and `BLUEPRINT --refine {ID}` read the catalog during design. `BLUEPRINT --approve {ID}` blocks if applicable architectural DCs are not explicitly addressed in `design.md`.

**What:**

```yaml
applicable_dcs = consult_defect_catalog("BLUEPRINT", feature_context)
FOR EACH dc IN applicable_dcs:
  ADD to design.md § Constraints:
    "DC-{N} ({dc.name}) — {dc.check}"
  ADD to test_plan.md § Edge Cases:
    "Verify DC-{N} is not introduced: {dc.check}"

# At --approve time:
FOR EACH dc IN applicable_dcs WHERE dc.severity == "BLOCKER":
  IF "DC-{N}" NOT present in design.md § Constraints:
    ❌ BLOCK: "Blueprint missing required DC-{N} constraint. Run --refine to add."
    STOP
```

**Output artefact:** `design.md § Constraints` and `test_plan.md § Edge Cases` are populated with DC references. `--approve` is blocking.

### 3. IMPLEMENT — Plan Compliance + Pre-Write Check + Fix Classification

**When:**

- `IMPLEMENT --plan {ID}`: read catalog, project into `dev_plan.md § DC Compliance` section as mandatory tasks.
- `IMPLEMENT --build {ID}`: DEV hat pre-write check (existing since v1.0.0).
- `IMPLEMENT --fix {ID}`: classify each FIX-N task against the catalog — is this fix addressing a known DC, or is it a Discovery Protocol candidate (new DC)?

**What:**

```yaml
# --plan
applicable_dcs = consult_defect_catalog("IMPLEMENT", feature_context)
dev_plan.md § DC Compliance:
  FOR EACH dc IN applicable_dcs:
    ADD task:
      "[DC-{N}] Verify {dc.name}: {dc.check}"
      # Every DC becomes an explicit dev_plan task tracked in the BVL loop

# --build (unchanged — pre-write check)
BEFORE writing code:
  applicable_dcs = consult_defect_catalog("IMPLEMENT", file_context)
  FOR EACH dc IN applicable_dcs:
    VERIFY the code about to be written does NOT introduce the DC pattern
    IF pattern detected in planned code:
      REWRITE to use the documented prevention approach
      LOG: "DC-{N} prevented: {description}"

# --fix
FOR EACH fix_task:
  IF fix addresses an existing DC:
    LABEL fix_task with "dc-compliance: DC-{N}"
  ELSE IF fix pattern is novel and recurring:
    TRIGGER Discovery Protocol (§ 8) — propose new DC entry
```

**Output artefact:** `dev_plan.md § DC Compliance` is populated. BVL tracks each DC task as a mandatory item.

### 4. REVIEW — Post-Write Verification (BLOCKING)

**When:** During REVIEW hat check cycle, after DEV hat completes each phase. Existing Check #2d, filter expanded.

**What:**

```yaml
applicable_dcs = consult_defect_catalog("REVIEW", file_context)
FOR EACH modified_file in phase:
  FOR EACH dc IN applicable_dcs:
    IF dc.pattern detected in modified_file:
      severity = dc.severity  # BLOCKER or WARNING
      IF severity == BLOCKER:
        FAIL [GOV-DC-{N}]:
          "Known defect pattern DC-{N} ({dc.name}) detected in {file}:{line}.
           Prevention: {dc.check}.
           Reference: .claude/rules/defect-prevention.md"
      ELSE:
        WARN [GOV-DC-{N}]:
          "Potential defect pattern DC-{N} ({dc.name}) in {file}:{line}. Verify."
```

**Output artefact:** `peer_review_*.md § Check #2d` lists DC findings.

### 5. DEVOPS — Pre-Configure Advisory (NON-BLOCKING)

**When:** `DEVOPS --configure {ID}` reads the catalog and pre-populates `devops_plan.md` with equivalent deploy/infra checks.

**What:**

```yaml
applicable_dcs = consult_defect_catalog("DEVOPS", feature_context)
FOR EACH dc IN applicable_dcs:
  # Typical DCs applicable to DEVOPS: missing health checks, wrong probe timing,
  # env-var drift, missing SIGTERM handling, observability gaps
  ADD to devops_plan.md § Reliability Checks:
    "DC-{N} ({dc.name}) — {dc.check}"
  ADD to devops_plan.md § Verification Script:
    # Shell snippet that exercises the check at deploy time
```

**Output artefact:** `devops_plan.md § Reliability Checks` populated. Advisory, but once materialised into the plan it becomes part of the plan's auto-approval criteria.

### 6. QA — Verify Checklist Expansion (BLOCKING)

**When:** `QA --verify {ID}` generates its checkbox-driven checklist. For every applicable DC, a `[QA-DC-{N}]` line is appended.

**What:**

```yaml
applicable_dcs = consult_defect_catalog("QA", feature_context)
FOR EACH dc IN applicable_dcs:
  APPEND checklist item:
    "- [ ] [QA-DC-{N}] {dc.name}: {dc.check}"
  # Must be marked [x] before QA can auto-approve
```

**Output artefact:** `qa_report_final_*.md` includes `[QA-DC-N]` lines. Verdict `APPROVED` requires all `[QA-DC-N]` items checked.

### 7. AUDIT — Evidence Signal (ADVISORY)

**When:** `AUDIT --audit` scans the codebase for evidence of existing governance maturity.

**What:**

```yaml
applicable_dcs = consult_defect_catalog("AUDIT", project_context)
FOR EACH dc IN applicable_dcs:
  evidence = SEARCH codebase for the DC pattern
  audit_report.add_signal({
    dimension: "Defect Prevention",
    evidence: evidence,
    score: inverse_of(pattern_density)  # fewer occurrences = higher score
  })
```

**Output artefact:** Audit report gains a "Defect Prevention" dimension contributing to the overall maturity score.

### 8. Discovery Protocol — Adding New Entries

**When:** Any agent discovers a runtime defect that is NOT already in the catalog.

```yaml
WHEN a runtime defect is discovered during any phase:
  1. DETERMINE if the defect pattern is novel (not covered by existing DC-1..DC-N)
  2. IF novel:
     a. Assign next DC number (DC-{last+1})
     b. ADD entry to this file with:
        - Name, Applicable When, Applicable To (enum list), Severity, Check
     c. ADD detailed search methodology to Factory-preventive-sweep/SKILL.md
     d. BUMP version of this rule in governance_versions.json
     e. SAVE feedback memory for cross-session awareness
     f. LOG: "New defect class DC-{N} cataloged: {name}"
  3. IF existing DC but new variant:
     a. UPDATE the existing DC entry with the new variant
     b. BUMP version of this rule
```

**Who triggers Discovery:** Any agent can propose a new DC, but the write happens through the RETROSPECTIVE gate (`[EPIC-{N}] RETROSPECTIVE` issue) or an emergency hotfix commit if the defect is critical and recurrent. The issue body on the retrospective ticket documents the rationale; the DC entry in this file captures the actionable prevention.

---

## Relationship to Other Governance Artifacts

| Artifact | Role |
|----------|------|
| This rule (`defect-prevention.md`) | **What** to check + **when** each agent checks it (canonical consultation protocol, per-consumer integration) |
| `Factory-preventive-sweep/SKILL.md` | **How** to search — detailed patterns, parallel scope strategy (one sub-agent per non-overlapping scope derived from this catalog), report template |
| `Factory-build-verification/SKILL.md` | **Pre-test** and **BVL fail-recurrence** consumer — reads catalog when a test failure pattern recurs |
| `Factory-codesign-feature.instructions.md` | CODESIGN consumer — advisory hints projected into `spec.feature § Defect-Prevention Notes` |
| `Factory-blueprint-design.instructions.md` | BLUEPRINT consumer — constraint population in `design.md` + `--approve` blocker for BLOCKER-severity DCs |
| `Factory-implement-plan.instructions.md` | IMPLEMENT --plan consumer — `dev_plan.md § DC Compliance` task generation |
| `Factory-implement-build.instructions.md` | IMPLEMENT --build / --fix consumer — DEV hat pre-write check + fix classification |
| `Factory-implement-review-checks.instructions.md` | REVIEW hat enforcer — Check #2d (existing) |
| `Factory-devops-configure.instructions.md` | DEVOPS --configure consumer — `devops_plan.md § Reliability Checks` population |
| `Factory-qa-verify.instructions.md` | QA --verify consumer — `[QA-DC-N]` checklist expansion |
| `Factory-audit-checklist.instructions.md` | AUDIT consumer — "Defect Prevention" maturity signal |
| `Factory-backlog-operations.instructions.md` | RETROSPECTIVE gate writes new entries back into this file (Discovery Protocol) |

---

## Project Discoveries

> This section is populated during development as new defect patterns are discovered via the Discovery Protocol (§ 8). Each entry follows the same schema as the starter DCs above.

<!-- New DC entries discovered during development go here -->
