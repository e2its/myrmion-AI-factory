---
description: "Factory AUDIT checklist — phases A-D, risk assessment, due diligence master checklist, governance scan. Use when: AUDIT --audit or AUDIT --software command execution."
---

# AUDIT Agent — Execution & Master Checklist (Phases A-D)

## Purpose
This instruction file defines the execution protocols for the AUDIT agent in two scopes:

1. **`--audit`** — full Technical Due Diligence. Senior Technical Auditor performing M&A due diligence, modernization assessment, or Brownfield evaluation of a complete target (team + infrastructure + code + compliance).
2. **`--software`** — narrow software-only audit of the repository/codebase. Rapid repository health check without organizational access (no team sizing, no billing, no cloud topology). Same evaluation rigour, reduced surface.

**Philosophy:** "Everything without evidence does not exist." Evidence-based, data-driven, scan-first — identical across both modes.

**Independence:** AUDIT operates OUTSIDE the main SDLC workflow in both modes. It does NOT require or apply governance (constitution, rules). It can run at ANY time — before `SETUP`, during the project, or as ad-hoc analysis.

---

## Main Artifacts

| Command | Artifact | Scope |
|---------|----------|-------|
| `--audit` | `docs/technical_due.md` | Full due diligence (P0 + A + B + C + D + COMP1) |
| `--software` | `docs/software_audit.md` | Software-only (P0 + B + selected D sections + COMP1) |

Both artifacts follow the frontmatter schema below. They can coexist — a project can run both modes independently; each command auto-detects its own artifact.

### Frontmatter Structure
```yaml
status: DRAFT | NEEDS_INFO | APPROVED | CANCELLED
risk_score: 0-100           # Calculated on --approve
complexity_score: 0.0-3.0   # From COMP1 analysis
complexity_assessment_level: 0-3  # LOW/MEDIUM/HIGH/CRITICAL
verdict: GO | NO_GO | GO_WITH_CONDITIONS
last_completed_phase: null | A | B | C | D | E
last_completed_section: null | P0 | G1..G3 | S1..S4 | I1..I4 | SEC1..SEC5 | COMP1
setup_mapping:               # Field mapping for SETUP consumption
  project_mode: null
  backend_runtime: null
  frontend_framework: null
  architecture_topology: null
  # ... (10 fields total)
complexity_details:           # Per-category scores (21 fields)
  approach: null
  development_expertise: null
  # ... all 21 COMP1 categories
```

### Content Structure
```markdown
# Technical Due Diligence Report

## 1. Executive Summary
Brief assessment + verdict + key findings

## 2. Audit Details
### [Section ID]: [Section Name]
- **Requirement**: What was evaluated
- **Conclusion**: Findings summary
- **Evidence**: Sources (files, configs, interviews)
- **Findings**: Detailed observations (positives + concerns)
- **Risk**: none | low | medium | high | critical
- **Metadata**: agent, scan_confidence, rdr_applied

## 3. COMP1: Complexity Analysis
(See audit-complexity.md for full protocol)

## 4. Setup Mapping
Field-by-field mapping for SETUP consumption

## 5. Recommendations
### Short Term (0-3 months)
### Long Term (3-12 months)

## 6. Investment Decision
Verdict + conditions + risk summary
```

---

## Execution Guardrails

### CANCELLED Verification
- If `technical_due.md` has `status: CANCELLED` → HARD BLOCK. No modifications allowed.

### Concurrency Prevention
- Uses **global** lock: `.context/locks/audit.lock` (NOT per-feature)
- Only one AUDIT can run at a time across the entire project

### Required Branching
- `--audit` CREATES branch: `feature/AUDIT-XXX-due-diligence`
- `--software` CREATES branch: `feature/AUDIT-XXX-software`
- Other AUDIT commands consume the existing branch

### Does NOT Apply Governance
- AUDIT reads @workspace reality, NOT .claude/rules/
- AUDIT never validates against constitution.md
- AUDIT output may FEED `SETUP --init` but is never fed BY setup

### Artifact Selection (mode disambiguation)
- `--audit` / `--refine` / `--approve` default to `docs/technical_due.md` when only that artifact exists.
- `--software` / `--refine` / `--approve` default to `docs/software_audit.md` when only that artifact exists.
- When BOTH artifacts exist in DRAFT/NEEDS_INFO state, `--refine` and `--approve` require an explicit `--scope {audit|software}` flag; otherwise BLOCK with the message: `"Both audit artifacts are open. Re-run with --scope audit or --scope software."`. This keeps the command tool-agnostic and prevents silent cross-contamination.

---

## Command: `--audit`

### State Machine Logic
```yaml
IF technical_due.md NOT EXISTS:
  CREATE with status: DRAFT, start from P0
ELIF status == NEEDS_INFO AND last_completed_section != null:
  RESUME from last_completed_section + 1
ELIF status == APPROVED:
  BLOCK: "Audit already completed. Use --refine to update sections."
ELIF status == CANCELLED:
  BLOCK: "Audit cancelled. Cannot resume."
```

### Scan-First Protocol (5 Steps — MANDATORY per section)

```yaml
BEFORE asking ANY question about a section:

Step 1: SILENT SCAN
  Use @workspace tools (grep_search, file_search, semantic_search, read_file)
  to gather evidence about the section topic. Never ask what you can discover.

Step 2: EVALUATE & PRESENT
  Present findings to user:
  "Based on my scan, I found: [evidence]. Here's my assessment: [conclusion]."
  "Do you confirm, or should I adjust? [RDR options]"

Step 3: HANDLE UPLOADS
  If user provides additional files/screenshots/documentation:
  Analyze and incorporate into section findings.

Step 4: PERSIST IMMEDIATELY
  Save section to technical_due.md BEFORE proceeding to next section.
  Update last_completed_section in frontmatter.

Step 5: NEXT
  Move to next section in the checklist order.
```

### Persistence Protocol
- **ONE question per turn** — FORBIDDEN to batch multiple questions
- Each section saved atomically after completion
- If interrupted, resumes from `last_completed_section + 1`

### Defect Prevention Catalog Signal

When auditing a codebase that ALREADY has `.claude/rules/defect-prevention.md` materialised (i.e. the target project went through Factory SETUP previously), AUDIT adds a dedicated evidence signal to its findings.

```yaml
# Runs once, after all sections are scanned, as part of the final maturity synthesis.
IF FILE_EXISTS(".claude/rules/defect-prevention.md"):
  # AUDIT runs at project level (no single feature_id); fall back to project_scope
  # from the governance snapshot so DPC Filter 2 only considers DCs compatible with the project's scope.
  # A backend-only project won't get frontend-specific DCs flagged as audit evidence.
  # Read from setup_configuration section (matches codebase convention; snapshot writes project_scope
  # into both setup_configuration and stack_configuration — see Factory-setup-materialization § Checkpoint 3.1).
  project_scope = READ(".context/governance_snapshot.md").setup_configuration.project_scope OR READ(".context/governance_snapshot.md").stack_configuration.project_scope OR "full-stack"
  applicable_dcs = consult_defect_catalog("AUDIT", {project: project_context, feature_scope: project_scope})
  IF applicable_dcs is not empty:
    dc_signals = []
    FOR EACH dc IN applicable_dcs:
      # Search the codebase for evidence of the DC pattern.
      # Positive evidence = the pattern is present = governance debt.
      occurrences = grep_search(dc.pattern_signature, scope=code_search_roots)
      dc_signals.push({
        dc_number: dc.number,
        name: dc.name,
        severity: dc.severity,
        occurrences: occurrences.length,
        sample_locations: occurrences[:3]  # first 3 for the audit narrative
      })

    # Add the evidence to the audit report under a dedicated dimension
    ADD to technical_due.md § Defect Prevention Maturity (new sub-section):
      - Catalog size: {applicable_dcs.length} entries applicable to AUDIT
      - Total pattern occurrences in current codebase: {sum(dc_signals.occurrences)}
      - Per-DC breakdown with sample locations
    CONTRIBUTE score: inverse_of(total_occurrences) → feeds into overall maturity_score
  ELSE:
    NOTE: "Defect Prevention Catalog exists but no AUDIT-applicable entries. Not a signal."
ELSE:
  NOTE: "Project has no Defect Prevention Catalog. Signal absent (project predates SETUP or never materialised the catalog)."
```

See `.claude/rules/defect-prevention.md` § Mandatory Process Integration § 7 for the canonical consultation protocol. This signal is **advisory** — a high occurrence count does not automatically fail the audit; it feeds the maturity score and informs the `Short Term` / `Long Term` recommendations in § 5.

---

## Command: `--software`

### Scope

A narrow, software-only variant of `--audit` focused exclusively on the repository and its code. Produces `docs/software_audit.md` with the same schema as `docs/technical_due.md` but with HR / organizational / infrastructure sections **excluded by design**.

### Included sections

| Section ID | Name | Rationale for inclusion |
|------------|------|------------------------|
| **P0** | Report Language | Required to render the report in the user's language. One question only. |
| **S1** | Architecture Diagrams (HLD) | Code-level — existence and freshness of HLD artefacts in the repo. |
| **S2** | Design Patterns & Topology | Code-level — module boundaries, patterns, coupling. |
| **S3** | Stack & Obsolescence | Code-level — manifest files, version lag, EOL signals. |
| **S4** | IP & Licenses | Code-level — LICENSE, dependency license compatibility. |
| **SEC1** | Identity & Access Management | Scoped to **code-level auth patterns** — how auth is implemented in the codebase (JWT handling, password storage, session code). Out of scope: organizational RBAC, SSO provider, MFA at the org level. |
| **SEC3** | Data Protection | Scoped to **code-level data handling** — encryption libraries used, PII processing code, key management code, hardcoded secrets. Out of scope: key-rotation policies, data-retention SLAs. |
| **SEC4** | Vulnerability Management | Code-level — SAST results, dependency vulnerabilities, CVE exposure in manifests. Out of scope: organizational patch cadence SLA. |
| **COMP1** | Complexity Analysis | Software complexity applies directly to code (optional). |

### Explicitly excluded sections

| Section ID | Name | Why excluded |
|------------|------|-------------|
| **G1** | Technical Organization | Requires team interviews. |
| **G2** | Strategy & Roadmap | Requires business context. |
| **G3** | Budget | Requires billing access. |
| **I1** | Hosting & Cloud | Requires cloud access. |
| **I2** | CI/CD & Release | Skipped in software-only scope (pipeline files exist in the repo but their operational status requires organizational access). |
| **I3** | Observability | Primarily infrastructure/operational. |
| **I4** | Business Continuity (BCP/DRP) | Organizational / policy scope. |
| **SEC2** | Network Security | Primarily infrastructure (WAF, firewalls). Code-level HTTPS enforcement is folded into SEC3's data-protection scan when relevant. |
| **SEC5** | Compliance (GDPR/PII) | Policy / legal scope. |

### Execution order

```
P0 → S1 → S2 → S3 → S4 → SEC1 (code-level) → SEC3 (code-level) → SEC4 → COMP1 → --approve
```

Same Scan-First Protocol, same one-section-per-turn persistence, same RDR protocol as `--audit`. Resume logic reads `last_completed_section` from `docs/software_audit.md`; valid values are `P0, S1–S4, SEC1, SEC3, SEC4, COMP1`.

### State machine logic

```yaml
IF software_audit.md NOT EXISTS:
  CREATE with status: DRAFT, start from P0
ELIF status == NEEDS_INFO AND last_completed_section != null:
  RESUME from the next section in the included list (skip excluded IDs)
ELIF status == APPROVED:
  BLOCK: "Software audit already completed. Use --refine --scope software to update sections."
ELIF status == CANCELLED:
  BLOCK: "Software audit cancelled. Cannot resume."
```

### Risk score adjustment

Per-section risk weights remain identical to `--audit`. The cap at 100 also remains. Because the section count is smaller (9 sections vs 18 in full audit), the same absolute risk_score indicates a **higher density** of findings — adjust verdict thresholds accordingly:

```yaml
NO_GO (software):
  - >1 Critical SEC finding (SEC1/SEC3/SEC4)
  - Serious license violation (GPL in proprietary, no license at all)
  - complexity_score ≥ 2.5 AND risk_score ≥ 50

GO_WITH_CONDITIONS (software):
  - risk_score 25–49
  - complexity_score ≥ 2.0
  - Obsolete but stable stack

GO (software):
  - risk_score < 25
  - complexity_score < 2.0
  - Scalable + mature architecture
```

### Setup mapping

`--software` populates only the software-relevant keys in `setup_mapping`:

- `backend_runtime`, `frontend_framework`, `architecture_topology`, `stack_versions`, `license_model` — populated.
- `project_mode`, `team_size`, `budget_tier`, `hosting_provider`, `ci_cd_platform`, `compliance_frameworks` — left `null` (require full `--audit`).

Downstream `SETUP --init` consumes whichever keys are non-null and asks the user interactively for the rest.

### Use cases

1. **M&A of a single codebase** without access to the selling org's team / billing / infra (seller provides repo only).
2. **OSS project evaluation** before adopting as a dependency or forking.
3. **Contributor-level read** of an unknown repo (new hire onboarding, third-party review).
4. **Pre-flight check** before committing to a full `--audit` — `--software` surfaces the red flags that are cheap to find in code.

---

## Command: `--refine {{SECTION_ID}}`

- Reopens a specific section for correction
- Valid IDs: P0, G1-G3, S1-S4, I1-I4, SEC1-SEC5, COMP1
- If audit was APPROVED: reverts to `status: DRAFT`
- Re-runs Scan-First Protocol for that section only
- Saves updated section, preserving all other sections

---

## Command: `--approve`

### Risk Score Calculation
```yaml
risk_score = 0
FOR EACH section IN audit_sections:
  IF section.risk == "critical": risk_score += 25
  IF section.risk == "high":     risk_score += 15
  IF section.risk == "medium":   risk_score += 8
  IF section.risk == "low":      risk_score += 2
  IF section.risk == "none":     risk_score += 0

risk_score = MIN(risk_score, 100)  # Capped at 100
```

### Recommendations Generation
- **Short Term (0-3 months):** Critical fixes, security patches, quick wins
- **Long Term (3-12 months):** Architecture improvements, tech debt reduction, modernization

### Verdict Decision Matrix
```yaml
NO_GO:
  - >2 Critical SEC findings (SEC1-SEC5)
  - Serious license violation (GPL in proprietary, no license at all)
  - No backups AND no DRP (Disaster Recovery Plan)
  - complexity_score ≥ 2.5 AND risk_score ≥ 70

GO_WITH_CONDITIONS:
  - Obsolete but stable stack (can modernize incrementally)
  - High technical debt but solid team (team can fix it)
  - risk_score 40-69
  - complexity_score ≥ 2.0

GO:
  - Scalable + mature architecture
  - risk_score < 40
  - complexity_score < 2.0
```

### Setup Mapping Consolidation
- Consolidates all setup-relevant findings into `setup_mapping` block
- Maps architecture patterns, stack, topology, team info to SETUP fields
- Generates migration strategy recommendation (E0/E1/E2/E3 based on risk+complexity)

---

## Master Checklist

### Phase 0: Report Language
**P0**: Ask user preferred language for the report (English, Spanish, etc.)
- Applies to all section narratives, findings, recommendations

### Phase A: Governance & HR

**G1: Technical Organization**
- Scan for: README, CONTRIBUTING, team docs, org charts
- Assess: Team size, seniority distribution, bus factor
- Key question: "How many developers? What seniority mix?"
- Risk indicators: bus factor ≤ 1, all juniors, no documentation

**G2: Strategy & Roadmap**
- Scan for: roadmap docs, project boards, release notes, changelog
- Assess: Vision clarity, alignment with business goals, documented roadmap
- Key question: "Is there a documented technology roadmap?"
- Risk indicators: no roadmap, conflicting priorities, no release cadence

**G3: Budget**
- Scan for: cloud billing configs, CI/CD costs, license costs
- Assess: Infrastructure spend, tool licensing, team costs
- Key question: "What is the monthly infrastructure cost?"
- Risk indicators: unknown costs, no monitoring of spend, vendor lock-in

### Phase B: Architecture & Software

**S1: Architecture Diagrams (HLD)** — ⚠️ CRITICAL
- Scan for: diagram files (*.drawio, *.puml, *.mmd), architecture docs, README with diagrams
- Assess: System boundaries, data flows, integration points, deployment topology
- If no diagrams: construct from code analysis + interview
- Risk indicators: no documentation, tribal knowledge only, inconsistent views

**S2: Design Patterns & Topology**
- Scan for: folder structure, module boundaries, dependency injection, patterns
- Map to topology catalog: B1 (Monolith) through B12 (Workers/Queues)
- Assess: Pattern consistency, anti-patterns, coupling level
- Risk indicators: Big Ball of Mud, no separation of concerns, circular deps

**S3: Stack & Obsolescence**
- Scan for: package.json, requirements.txt, pom.xml, Gemfile, go.mod, *.csproj
- Detect: language versions, framework versions, EOL (End of Life) flags
- Assess: maintenance status, community support, upgrade path
- Risk indicators: EOL runtime, unsupported framework, >2 years behind latest

**S4: IP & Licenses**
- Scan for: LICENSE file, package licenses, NOTICE files
- Detect: GPL contamination in proprietary code, missing licenses, dual-licensing
- Assess: License compatibility with project's business model
- Risk indicators: GPL in commercial product, no LICENSE file, mixed incompatible licenses

### Phase C: Infrastructure & Operations

**I1: Hosting & Cloud**
- Scan for: cloud configs (terraform, cloudformation, docker-compose), deployment scripts
- Assess: Cloud provider, region, redundancy, scalability, vendor lock-in level
- Risk indicators: single region, no autoscaling, deep vendor lock-in

**I2: CI/CD & Release**
- Scan for: .github/workflows, .gitlab-ci.yml, Jenkinsfile, bitbucket-pipelines.yml
- Assess: Pipeline stages, test automation, deployment frequency, rollback capability
- Risk indicators: manual deployments, no CI pipeline, no staging environment

**I3: Observability**
- Scan for: logging configs, monitoring dashboards, APM integrations, alerts
- Assess: Logging strategy, metrics collection, tracing, alerting coverage
- Risk indicators: no structured logging, no APM, no alerts, blind spots

**I4: Business Continuity (BCP/DRP)**
- Scan for: backup configs, disaster recovery docs, RTO/RPO definitions
- Assess: Backup strategy, recovery procedures, tested recovery, documentation
- Risk indicators: no backups, untested recovery, no RTO/RPO defined, no DRP

### Phase D: Security

**SEC1: Identity & Access Management (IAM)**
- Scan for: auth configs, OAuth/OIDC setup, RBAC/ABAC policies, session management
- Assess: Authentication method, authorization granularity, session handling
- Risk indicators: plaintext passwords, no MFA, overly permissive roles

**SEC2: Network Security**
- Scan for: firewall configs, WAF, TLS certificates, network policies
- Assess: Perimeter security, internal segmentation, encryption in transit
- Risk indicators: HTTP (no TLS), open ports, no WAF, flat network

**SEC3: Data Protection**
- Scan for: encryption configs, PII handling, data classification, key management
- Assess: Encryption at rest, PII inventory, data retention, key rotation
- Risk indicators: unencrypted PII, no key rotation, no data classification

**SEC4: Vulnerability Management**
- Scan for: dependency audit results, CVE history, security scan configs, SAST/DAST
- Assess: Known vulnerabilities, patch cadence, security scanning coverage
- Risk indicators: critical CVEs unpatched, no security scanning, outdated deps

**SEC5: Compliance (GDPR/PII)**
- Scan for: privacy policies, consent mechanisms, data processing agreements
- Assess: GDPR/CCPA compliance, PII handling procedures, audit trail
- Risk indicators: no privacy policy, no consent mechanism, PII without protection

---

## Section Evaluation Format

For each section, produce:
```yaml
section_id: "G1"
section_name: "Technical Organization"
requirement: "Documented team structure with clear roles"
conclusion: "Team of 5 developers, senior-heavy, bus factor 2"
evidence:
  - "CONTRIBUTING.md lists 5 team members"
  - "Git log shows 3 active contributors in last 90 days"
findings:
  positives:
    - "Well-documented contribution guidelines"
    - "Established code review process"
  concerns:
    - "One developer handles 60% of critical modules"
risk: "medium"
metadata:
  agent: "AUDIT"
  scan_confidence: 0.85  # 0.0-1.0
  rdr_applied: false      # true if user RDR was needed
```

---

## RDR Protocol for Uncertain Values

When scan confidence < 80% for any finding:

```yaml
Step 1: RECOMMENDATION
  "Based on my scan, I estimate [finding]. Confidence: [X]%.
   I recommend scoring this as [value] because [reason]."

Step 2: DECISION
  Present options: [Option A with score], [Option B with score], [Option C with score]
  Wait for user decision.

Step 3: RATIFICATION
  Save user's decision immediately.
  Mark section with `rdr_applied: true` in metadata.
```

---

## Final Instructions

1. **Start from P0** (language), then proceed A→B→C→D→E sequentially
2. **One section per turn** — complete, save, then move to next
3. **Scan before asking** — never ask what you can discover
4. **Evidence is mandatory** — every finding must cite a source
5. **Risk is per-section** — not cumulative until --approve
6. **Interruption-safe** — always resumable from last_completed_section
