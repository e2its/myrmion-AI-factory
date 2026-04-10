---
description: "Defect Prevention Catalog (DPC) — living catalog of runtime defect patterns invisible to static gates. Managed by discover-catalog-prevent loop across DEV/REVIEW/BVL agents."
version: 1.0.0
date: {{TIMESTAMP}}
changelog:
  - "1.0.0: Initial — starter defect classes materialized from SETUP stack detection. Process integration: DEV pre-write check, REVIEW Check #2d, Discovery Protocol."
---

# Defect Prevention Catalog (DPC)

> **Version:** 1.0.0
> **Created:** {{TIMESTAMP}}
> **Scope:** ALL modules, ALL features, ALL agents
> **Enforcement:** IMPLEMENT (DEV hat pre-write, REVIEW hat post-write)

## Purpose

Static gates (lint, typecheck, SAST, unit tests) form a strong Build Verification Loop but **cannot catch defects that only appear under real infrastructure execution** — real auth providers, real databases, real CDNs, real browsers. This rule maintains a living catalog of empirically-discovered defect patterns and mandates that every agent consults it before generating or reviewing code.

The goal is **continuous process improvement**: every runtime defect discovered during development, fix, or evolution feeds back into this catalog, making future development cycles progressively cleaner.

---

## The Defect Prevention Catalog

Each entry includes: **Name, Applicable When** (scope condition), **Review Severity** (BLOCKER or WARNING for REVIEW hat Check #2d), and **Prevention Check** (what DEV hat verifies before writing code). The authoritative detailed search methodology lives in `.claude/skills/Factory-preventive-sweep/SKILL.md`.

> **SETUP materialization note:** The starter DCs below were selected based on the project's stack configuration. Extend this catalog with project-specific discoveries using the Discovery Protocol (Section 3).

| DC | Name | Applicable When | Review Severity | Prevention Check (DEV Hat) |
|----|------|-----------------|-----------------|---------------------------|
{{DC_ENTRIES}}

---

## Mandatory Process Integration

### 1. DEV Hat — Pre-Write Check (BLOCKING)

**When:** Before writing or modifying any source file (backend or frontend).

```yaml
BEFORE writing code:
  READ docs/rules/defect-prevention.md → DC catalog
  FOR EACH DC in catalog:
    IF current_task intersects DC.applicable_scope:
      VERIFY the code about to be written does NOT introduce the DC pattern
      IF pattern detected in planned code:
        REWRITE to use the documented prevention approach
        LOG: "DC-{N} prevented: {description}"
```

### 2. REVIEW Hat — Post-Write Verification (BLOCKING)

**When:** During REVIEW hat check cycle, after DEV hat completes each phase.

```yaml
Check #2d: [GOV-DEFECT-PREVENTION] Known Defect Pattern Scan

FOR EACH modified_file in phase:
  FOR EACH DC in defect_prevention_catalog:
    IF DC.pattern detected in modified_file:
      severity = DC.review_severity  # BLOCKER or WARNING per DC definition
      IF severity == BLOCKER:
        FAIL [GOV-DC-{N}]:
          "Known defect pattern DC-{N} ({DC.name}) detected in {file}:{line}.
           Prevention: {DC.prevention_check}.
           Reference: docs/rules/defect-prevention.md"
      ELSE:
        WARN [GOV-DC-{N}]:
          "Potential defect pattern DC-{N} ({DC.name}) in {file}:{line}. Verify."
```

### 3. Discovery Protocol — Adding New Entries

**When:** Any agent discovers a runtime defect that is NOT already in the catalog.

```yaml
WHEN a runtime defect is discovered during any phase (build, fix, deploy, visual test):
  1. DETERMINE if the defect pattern is novel (not covered by existing DC-1..DC-N)
  2. IF novel:
     a. Assign next DC number (DC-{last+1})
     b. ADD entry to this file (docs/rules/defect-prevention.md) with:
        - Name, Applicable When, Prevention Check, Review Severity
     c. ADD detailed search methodology to Factory-preventive-sweep/SKILL.md with:
        - Search command, scope, severity
     d. BUMP version of this rule in governance_versions.json
     e. SAVE feedback memory for cross-session awareness
     f. LOG: "New defect class DC-{N} cataloged: {name}"
  3. IF existing DC but new variant:
     a. UPDATE the existing DC entry with the new variant
     b. BUMP version of this rule
```

---

## Relationship to Other Governance Artifacts

| Artifact | Role |
|----------|------|
| This rule (`defect-prevention.md`) | **What** to check — the catalog + mandatory process hooks |
| `Factory-preventive-sweep/SKILL.md` | **How** to search — detailed patterns, 4-agent strategy, report template |
| `Factory-build-verification/SKILL.md` | **When** to run static gates — BVL is complementary, not overlapping |
| `Factory-implement-build.instructions.md` | **Where** DEV hat consults the catalog (pre-write checklist) |
| `Factory-implement-review-checks.instructions.md` | **Where** REVIEW hat enforces the catalog (Check #2d) |

---

## Project Discoveries

> This section is populated during development as new defect patterns are discovered via the Discovery Protocol (Section 3). Each entry follows the same format as the starter DCs above.

<!-- New DC entries discovered during development go here -->
