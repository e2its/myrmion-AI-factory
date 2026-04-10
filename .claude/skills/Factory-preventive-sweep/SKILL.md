---
name: Factory-preventive-sweep
description: "Preventive Defect Sweep — post-deployment runtime validation that catches defects invisible to static gates. Searches all cataloged defect classes using 4 parallel agents. Use when: first deploy of a feature, after major architectural changes, or on user request."
---

# PREVENTIVE DEFECT SWEEP (v1.0.0)

> **Shared Protocol** — Referenced by: QA agent (--verify post-deploy), IMPLEMENT agent (build completion gate for first-deploy features).
> Catches runtime defects that static gates cannot detect by searching for empirically-discovered defect patterns across backend, frontend, and infrastructure.
> **Prerequisite:** Feature must have passed BVL (all static gates GREEN) before running a sweep.

**Core Principle:** Static gates (lint + typecheck + SAST + unit tests) form a strong build verification loop, but they **cannot catch defects that only appear under real infrastructure execution** — real auth providers, real databases, real CDNs, real browsers. This sweep closes that gap.

**Governance integration:** The Defect Prevention Catalog at `docs/rules/defect-prevention.md` is the authoritative list of known defect patterns. This skill provides the search methodology; the rule provides the mandatory process hooks (DEV pre-write check, REVIEW Check #2d). When this sweep discovers a new DC, it MUST be added to BOTH the governance rule AND this skill's search table.

---

## WHEN TO TRIGGER

| Trigger | Who invokes | Condition |
|---------|-------------|-----------|
| First deploy | QA agent | Feature has never been deployed to a real environment before |
| Post-architectural change | IMPLEMENT agent | ADR touches providers, middleware, auth, IaC, or runtime packaging |
| On demand | User | User requests a sweep against a feature |
| Post-major fix batch | IMPLEMENT agent | 3+ fixes applied in a single session that touch both backend and frontend |

**NOT triggered for:** pure doc changes, test-only changes, seed data changes (covered by BVL Seed Schema Alignment Gate).

---

## DEFECT CLASSES — SEARCH METHODOLOGY

> **Source of truth:** `docs/rules/defect-prevention.md` — the authoritative catalog of all DC patterns, prevention checks, and the mandatory Discovery Protocol.
> This skill defines HOW to search for each DC during a sweep. The rule defines WHAT each DC is and WHEN to check.

Every sweep MUST search for ALL DCs listed in `docs/rules/defect-prevention.md`. Never skip a class — even if a previous sweep marked it CLEAN.

### Search Strategy per DC

```yaml
FUNCTION build_search_plan(dc_catalog):
  # Read the materialized DC catalog — contents vary per project (SETUP-generated)
  READ docs/rules/defect-prevention.md → dc_entries[]

  FOR EACH dc IN dc_entries:
    # Derive search command from the DC's applicable_when and prevention_check fields
    # The search is a VERIFICATION that the prevention check was followed
    search = {
      dc_id: dc.number,
      dc_name: dc.name,
      scope: DERIVE_SCOPE(dc.applicable_when),  # backend | frontend | infra | cross-cutting
      search_type: DERIVE_SEARCH_TYPE(dc.prevention_check),  # grep | ast_walk | cross_reference
      verification: dc.prevention_check  # What to verify is NOT violated
    }
    APPEND search to search_plan

  RETURN search_plan
```

**Scope derivation from DC's `applicable_when` field:**
- Mentions "handler", "backend", "service", "use case" → **backend** scope
- Mentions "component", "hook", "form", "layout", "frontend" → **frontend** scope
- Mentions "env var", "IaC", "deployment", "provider" → **infra** scope
- Mentions "API call", "contract", "fetch URL" → **cross-cutting** scope (both backend + frontend)

---

## 4-AGENT PARALLEL STRATEGY

Spawn 4 Explore agents in parallel with non-overlapping scopes. Each agent searches ALL DCs within its scope.

### Agent 1: Backend Modules

**Scope:** Backend source code (all modules/bounded contexts for the feature)
**Primary DCs:** Those with backend scope (handlers, services, use cases, data access)
**Searches:**
- Every entry point handler for runtime contract compliance
- Every service/use case for identity field confusion
- Every data access layer for cross-module boundary violations
- Every route definition against contract specifications

### Agent 2: Frontend Feature

**Scope:** Frontend source code (feature components, pages, hooks)
**Primary DCs:** Those with frontend scope (providers, hooks, forms, layouts)
**Searches:**
- Every hook import → verify Provider in component tree
- Every form handler → verify post-action navigation
- Auth/session state initialization patterns
- Hook ordering relative to conditional returns
- Mobile responsiveness in page layouts

### Agent 3: Infrastructure Wiring

**Scope:** IaC config, root layouts, provider chains, deployment config
**Primary DCs:** Those with infra scope (env vars, providers, deployment)
**Searches:**
- All frontend env var reads vs IaC/deployment injection
- Provider chain completeness in root layout
- Auth/session configuration call locations
- Error boundary existence

### Agent 4: Contract Alignment

**Scope:** Cross-cutting — contract files, frontend API clients, backend route definitions
**Primary DCs:** Those with cross-cutting scope (contract mismatches)
**Searches:**
- Every frontend fetch URL vs backend route path
- Every frontend request interface vs backend request model
- Every frontend response type vs backend response shape
- Identity field naming consistency across layers

---

## OUTPUT FORMAT

Each agent reports findings in this format:

```
[DC-N] SEVERITY | file:line | Description
  Expected: ...
  Actual: ...
  Fix suggestion: ...
```

**Severity levels:**
- **BLOCKER** — Crash or complete functional failure at runtime
- **HIGH** — UX broken but doesn't crash
- **MEDIUM** — Degraded experience, not blocking
- **LOW** — Improvement opportunity, no user impact

---

## CONSOLIDATION PROTOCOL

After all 4 agents complete:

1. **Merge** all findings into a single severity-ordered table
2. **Deduplicate** — if Agent 2 and Agent 4 both report the same DC finding, keep only one
3. **Group by defect class** — show DC-N header with finding count
4. **Mark CLEAN** — for each DC with zero findings, explicitly mark `DC-N: CLEAN`
5. **Present to user BEFORE touching code** — the user approves the fix plan
6. **Save report artifact** at `docs/spec/{{FEATURE_ID}}/review/preventive_sweep_{{YYYYMMDD}}.md`
7. **On user approval:**
   - Apply fixes in priority batches: P0 (BLOCKER) → P1 (HIGH) → P2 (MEDIUM)
   - One commit per priority group
   - Run BVL after all fixes
   - One CI redeploy at the end (not N redeploys)

---

## REPORT ARTIFACT TEMPLATE

```markdown
---
status: COMPLETED | IN_PROGRESS
feature_ids: ["{{FEATURE_ID}}"]
title: "Preventive Defect Sweep — {{Feature Name}}"
sweep_date: "YYYY-MM-DD"
trigger: "{{why the sweep was triggered}}"
methodology: "4 parallel Explore agents searching N defect classes"
analyst: "IMPLEMENT (REVIEW hat + SEC hat)"
total_findings: N
critical: N
high: N
medium: N
low: N
all_resolved_in_commit: true | false
---

# Preventive Defect Sweep — {{FEATURE_ID}}

> Generated by Agent: IMPLEMENT (REVIEW hat) | Feature: {{FEATURE_ID}}

## Methodology
{{Brief description of scope and trigger}}

## Findings — Ordered by Severity

### BLOCKER (N)
| # | DC | File(s) | Description | Fix |
|---|----|---------|----|-----|

### HIGH (N)
| # | DC | File(s) | Description | Fix |
|---|----|---------|----|-----|

### MEDIUM (N)
| # | DC | File(s) | Description | Fix |
|---|----|---------|----|-----|

## Clean Areas
| DC | Area | Notes |
|----|------|-------|

## Framework Observations
{{Any patterns that suggest a new DC or a gate improvement}}
```

---

## EVOLUTION

When a sweep discovers a new defect pattern that doesn't fit existing DCs:
1. Assign it the next DC number (DC-{last+1})
2. Document it in `docs/rules/defect-prevention.md` with: Name, Applicable When, Prevention Check, Review Severity
3. Add its search methodology to this skill's search strategy
4. Bump the rule version in `governance_versions.json`
5. Save a feedback memory so future sessions are aware
