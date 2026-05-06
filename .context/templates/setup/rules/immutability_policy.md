---
description: "Immutability policy — approved artifact versioning, change tracking requirements, audit trail enforcement."
applicable_when:
  always: true
---
# Specification Immutability Policy

## Purpose

This policy guarantees the **traceability integrity** between specifications and implemented code through a **cascade immutability** system with **automatic versioning**.

### Problem It Solves

Without immutability, critical situations can occur:
- `/CODESIGN --reset USR-001` is executed **after** the code is in production
- Specifications disappear while the code remains active
- Compliance violations (GDPR, SOX, HIPAA) due to audit trail loss
- Inability to trace features back to their original requirements

### Solution: Immutability with Versioning

Instead of allowing destructive modifications, the system **blocks** dangerous operations and **forces the creation of new versions** (`USR-001-v2`).

---

## Immutability Rules by Phase

### Lock Table

| SDLC Phase | Lock Trigger | Immutable Artifact | Blocked Commands | Allowed Command |
|------------|--------------|--------------------|-----------------|-----------------|
| **CODESIGN Approved** | `/CODESIGN --start` / `--refine` (auto-approval) | `spec.feature` | `/CODESIGN --reset` (with downstream), `/CODESIGN --refine` (if downstream APPROVED) | `/CODESIGN --revise` |
| **BLUEPRINT Approved** | `/BLUEPRINT --approve` | `spec.feature` + `test_plan.md` + `design.md` + `increment_plan.md` (plan-level frontmatter; per-increment § 1 sections follow the Per-Increment Immutability table below) | `/CODESIGN --reset`, `/CODESIGN --refine`, `/BLUEPRINT --refine` (except on increments in DRAFT/READY/INVALIDATED status) | `/CODESIGN --revise` |
| **IMPLEMENT Plan Approved** | `/IMPLEMENT --plan` | All previous + `dev_plan.md` | All previous + `/BLUEPRINT --refine` (except per-increment allowance) | `/CODESIGN --revise` or `/BLUEPRINT --refine` (scoped to editable increments) |
| **IMPLEMENT Approved** | `/IMPLEMENT --build` (all 3 hats pass) | All previous + source code | All previous + `/IMPLEMENT --fix` (without versioning) | `/CODESIGN --revise` (new version) or `/IMPLEMENT --override` (emergencies) |
| **QA Verify+DAST Approved** | `/QA --verify` (post-staging auto-approval, includes DAST 🛡️ SEC hat) | Entire chain | All previous + `/IMPLEMENT --override` | Only `/CODESIGN --revise` (creates new feature) |
| **Merged to main** | Git merge | **FULLY IMMUTABLE** | All commands except hotfix | `/IMPLEMENT --fix` (emergencies) |

### Phase Descriptions

#### Phase 0: DRAFT (No Restrictions)
- **State:** `status: DRAFT`, `status: NEEDS_INFO`
- **Allowed:** Any modification via `--refine`, `--reset`
- **Immutability:** None

#### Phase 1: PO APPROVED (Soft Lock)
- **Trigger:** `/CODESIGN --start` or `--refine` auto-approval USR-001
- **Lock:** `spec.feature` blocked for `/CODESIGN --reset` **IF** downstream work exists (`test_plan.md`, `design.md`, `dev_plan.md`)
- **Exception:** Typographic corrections via `/CODESIGN --refine` allowed (maximum 3, recorded in history)
- **Versioning:** Not required if no downstream work

#### Phase 2: BLUEPRINT APPROVED (Hard Lock - Start)
- **Trigger:** `/BLUEPRINT --approve USR-001` (mandatory manual checkpoint)
- **Lock Cascade:**
  - `spec.feature` → **BLOCKED** for PO (no more `--reset`, no more `--refine`)
  - `test_plan.md` → **BLOCKED** for BLUEPRINT (no more `--refine` without versioning)
  - `design.md` → **BLOCKED** for BLUEPRINT (no more `--refine` without versioning)
  - `increment_plan.md` → **PARTIALLY BLOCKED** — plan-level frontmatter and § 0 Slicing Rationale frozen; § 1 per-increment sections follow Per-Increment Immutability below
- **Versioning:** **MANDATORY** for any change (except per-increment allowances)
- **Command:** `/CODESIGN --revise USR-001 "Reason for change"`
- **Note:** QA verification happens AFTER implementation (Phase 4), not at this phase.

##### Per-Increment Immutability (`slicing_strategy: incremental`)

`increment_plan.md` § 1 is addressable per-increment. Each `### INC-N` section carries a `**Status:**` field (`DRAFT | READY | BUILDING | MERGED | INVALIDATED`) that scopes the lock below the plan level. This lets the pipeline mutate still-DRAFT increments without re-versioning the feature while preserving audit integrity for increments already in production.

**Per-Increment Lock Table:**

| Increment Status | Transition trigger | Fields editable via `BLUEPRINT --refine` | Fields editable via `IMPLEMENT --refine` | Resulting version bump |
|---|---|---|---|---|
| `DRAFT` | Initial (emitted by `BLUEPRINT --start`) | scope, scenarios_covered, contract_surface, depends_on, deployable, functional_definition, acceptance checklist | N/A (IMPLEMENT has not started) | None |
| `READY` | `BLUEPRINT --approve` sets increment_plan.md `status: APPROVED`; no per-increment branch yet | scope/scenarios/contract_surface/depends_on FROZEN. Acceptance checklist may be refined. | Layer tasks `[INC-N.A.M]`, `[INC-N.B.M]`, `[INC-N.C.M]` editable (task decomposition) | None |
| `BUILDING` | `IMPLEMENT --plan` opens the increment branch `feature/{ID}-inc-N-{slug}` (first task checked) | **BLOCKED** — use `IMPLEMENT --pause INC-N` or complete | **BLOCKED** — same | None (must pause) |
| `MERGED` | Increment PR merged to `main` (git merge hook updates `Merged at:` timestamp) | **BLOCKED** — increment is in production. Changes require `CODESIGN --revise` (new feature version) OR a new follow-up increment (see below). | **BLOCKED** — same | MANDATORY if change alters scope of merged increment |
| `INVALIDATED` | Iteration cascade `CASCADE_INCREMENT_INTERNAL` set by upstream `--refine` (only valid on increments in `DRAFT` or `READY` at cascade time; MERGED increments are NEVER invalidated — they cascade to a new follow-up increment instead) | Full resync — scope/scenarios/contracts/tasks all editable until status returns to DRAFT/READY | Same | Delta iteration bump (spec.feature.iteration + increment_plan.based_on_iteration) |

**Follow-up Increment Rule (additive, non-breaking):**

After one or more increments reach `MERGED`, a NEW increment MAY be appended to `increment_plan.md § 1` without bumping the feature version when all of the following hold:
- New increment is additive: its scenarios_covered and contract_surface do NOT overlap with any merged increment's coverage.
- New increment's `depends_on` references only existing increments (no cycles).
- Iteration Model classifies the change as DELTA (see `Factory-iteration-model/SKILL.md`).
- CVP `increment_deployability` + `increment_to_scenario_coverage` + `increment_to_contract_coverage` PASS under the updated plan.
- **The feature has NOT yet reached Phase 4 (QA Verify+DAST Approved).** Once QA --verify has certified the chain, the feature enters the Phase-4 Hard Lock (ENTIRE CHAIN BLOCKED) — new increments are no longer appendable; any scope extension requires `CODESIGN --revise` (new feature version).

Common case: retrofitting a flag-guarded rollout as an explicit new increment, rather than pretending the original increment was only "partially deployable". Window: between the first increment merge and `QA --verify` certification.

**Interaction with Phase 3 (IMPLEMENT Plan Approved) lock.** Phase 3's "dev_plan.md BLOCKED" lock refers to the **artefact structure** — the plan's overall shape and the per-increment assignment are frozen at `IMPLEMENT --plan`. Per-increment DRAFT sections remain editable via `BLUEPRINT --refine` per the Per-Increment Lock Table above: their scope/scenarios/contracts/depends_on can still change as long as the increment is DRAFT, and BLUEPRINT --refine then re-triggers `IMPLEMENT --plan` for that increment. The two layers are complementary — artefact-level lock prevents whole-plan churn, per-increment lock grants surgical latitude on work not yet started.

**Enforcement invariant — status monotonicity:**

Transitions go `DRAFT → READY → BUILDING → MERGED`, with `→ INVALIDATED` permitted from DRAFT/READY only. Regression transitions (`MERGED → BUILDING`, `BUILDING → DRAFT`, etc.) are BLOCKED. Any attempt to edit a status field in violation raises `ImmutabilityViolationError`.

**Enforcement invariant — scope exclusivity on append:**

When `BLUEPRINT --refine` appends a new `### INC-N+1` to a plan with at least one MERGED increment, the refiner MUST validate that no scenario or contract operation from a merged increment is re-assigned. CVP `increment_to_scenario_coverage` + `increment_to_contract_coverage` enforce this automatically at `--approve`.

**Slicing-Strategy Flip:**

- `incremental → monolithic` is permitted ONLY when no increment has reached `BUILDING` (all still `DRAFT`/`READY`) AND the trivial-heuristic passes (`≤2 scenarios AND ≤3 contract operations AND scope ≠ full-stack`). Requires `BLUEPRINT --refine`; no version bump.
- `monolithic → incremental` is permitted ONLY when no increment has reached `BUILDING`. Requires re-running the Increment Slicing RDR. If the monolithic INC-1 already merged, a version bump (`USR-001 → USR-001-v2`) is MANDATORY — the original monolithic form is preserved as v1's audit record.

#### Phase 3: IMPLEMENT APPROVED (Hard Lock - Code Implemented + Reviewed + SAST)
- **Trigger:** `/IMPLEMENT --build USR-001` completes all phases (💻 DEV ↔ 🔍 REVIEW ↔ 🛡️ SEC per phase)
- **Lock Cascade:**
  - All previous + `dev_plan.md` + source code → **BLOCKED**
  - BLUEPRINT cannot `/BLUEPRINT --refine` without creating `USR-001-v2`
  - Generates `peer_review_{timestamp}.md` + `sec_audit.md` inline
- **Risk:** Implemented and certified code. Architectural changes require a new version.
- **Versioning:** **MANDATORY** for any upstream or downstream change
- **Next Phase:** DEVOPS deploy to staging → QA verification → SEC DAST

#### Fase 3.5: ~~REVIEW APPROVED~~ (DEPRECATED — Absorbed into IMPLEMENT --build)
> Review is now inline within `/IMPLEMENT --build` (🔍 REVIEW hat per phase). No separate review phase exists.

#### Phase 4: QA VERIFY+DAST APPROVED (Hard Lock - Post-Staging Certified)
- **Trigger:** `/QA --verify USR-001` (post-staging auto-approval including DAST 🛡️ SEC hat, v8.0.0)
- **Lock Cascade:**
  - **ENTIRE CHAIN BLOCKED** (SAST already passed in IMPLEMENT)
  - Nobody can modify code without re-certification
  - Only exception: Security hotfixes
- **QA Rejection Cycle:** If QA rejects → `/IMPLEMENT --fix` generates [FIX-N] tasks → sets `qa_report.status: INVALIDATED` → `/QA --verify` re-runs (standard flow, NOT emergency)
- **Versioning:** **MANDATORY** for any change
- **Ready for Merge:** Feature ready for production

#### Phase 5: MERGED (Fully Immutable)
- **Trigger:** Git merge to `main` or `release/*`
- **Lock:** **ABSOLUTE** - No agent can modify artifacts
- **Exception:** `/IMPLEMENT --fix USR-001 "CVE-XXX"` (emergency bypass)
- **Versioning:** Required for any functional change

---

## Versioning Convention

### ID Format

```
Original Feature:     USR-001
First Revision:       USR-001-v2
Second Revision:      USR-001-v3
Hotfix (Optional):    USR-001-v2.1
```

**Rules:**
- Base ID remains constant (`USR-001`)
- Suffix `-v{N}` indicates sequential version
- Hotfix uses `.{N}` (patch) only for security emergencies

### Extended Frontmatter

All artifacts (spec.feature, design.md, test_plan.md, dev_plan.md, etc.) must include:

```yaml
---
status: DRAFT
feature_id: USR-001-v2
original_feature_id: USR-001
version: 2
supersedes: USR-001
  superseded_by: null  # Filled when v3 is created
  parent_spec: docs/spec/USR-001/spec.feature
  revision_reason: "Add multi-currency support based on production feedback"
locked_at: 2026-01-15T14:30:00Z  # Timestamp when v1 was locked
created_at: 2026-01-20T09:00:00Z
---
```

**Key Fields:**
- `parent_spec`: Path to the parent artifact (enables inheritance)
- `supersedes`: ID of the version this one replaces
- `superseded_by`: ID of the version that replaces this one (filled when a new version is created)
- `revision_reason`: Justification for the change (required)

### Directory Structure

```
docs/spec/
├── USR-001/                      # Original version (SUPERSEDED)
│   ├── spec.feature              # status: APPROVED (SUPERSEDED)
│   ├── test_plan.md
│   ├── design.md
│   └── dev_plan.md
└── USR-001-v2/                   # Active version
    ├── spec.feature              # status: DRAFT (con parent_spec)
    ├── test_plan.md              # (puede heredarse de v1)
    └── design.md                 # (puede heredarse de v1)
```

**Separation:** Each version has its own directory to avoid conflicts.

---

## Artifact Inheritance (Avoid Rework)

### Principle

When `USR-001-v2` is created, downstream artifacts (`test_plan.md`, `design.md`) **can be inherited** from `USR-001` if the changes are minimal.

### Inheritance Options per Agent

#### BLUEPRINT Agent (`/BLUEPRINT --start USR-001-v2` — Test Plan)
**Detection:** Reads `parent_spec` in `spec.feature`
**Opciones:**
1. **INHERIT:** Copia `USR-001/test_plan.md` → marca casos como `[INHERITED]`
2. **REFERENCE:** Enlaza a `USR-001/test_plan.md` pero crea plan nuevo
3. **SKIP:** Ignora herencia (no recomendado)

**Frontmatter Resultante:**
```yaml
parent_test_plan: docs/spec/USR-001/test_plan.md
inherited_from: USR-001
delta_tests_only: true  # Solo nuevos test cases agregados
```

> **Note:** `test_plan.md` is a BLUEPRINT artifact (generated alongside `design.md`). QA Agent (`/QA --verify`) validates post-staging — it does not create test plans.

#### BLUEPRINT Agent (`/BLUEPRINT --start USR-001-v2`)
**Detection:** Reads `parent_spec` in `spec.feature`
**Options:**
1. **INHERIT:** Copies `USR-001/design.md` + ADR history
2. **REFERENCE:** Only ADR Section 4, regenerates diagrams
3. **SKIP:** Design from scratch

**Resulting Frontmatter:**
```yaml
parent_design: docs/spec/USR-001/design.md
inherited_from: USR-001
```

#### IMPLEMENT Agent (`/IMPLEMENT --plan USR-001-v2`)
**Detection:** Reads `parent_design` in `design.md`
**Options:**
1. **DELTA MODE:** Only plans tasks for NEW artifacts (compares inventories)
2. **FULL RE-IMPLEMENTATION:** All tasks from scratch

**Resulting Frontmatter:**
```yaml
parent_dev_plan: docs/spec/USR-001/dev_plan.md
delta_mode: true
reused_artifacts: ["src/domain/User.ts", "src/domain/Auth.ts"]  # Do not re-implement
```

#### SEC SAST (within `/IMPLEMENT --build USR-001-v2`)
**Detection:** Reads `parent_dev_plan` in `dev_plan.md`
**Inheritance:** **NONE** - Always full audit (🛡️ SEC hat per phase)
**Validation:** Checks whether vulnerabilities from `USR-001` were corrected (regression check)

---

## Parallel Version Limit

### Rule: Maximum 1 Active Version

**Active = `status` in:** `DRAFT`, `IN_PROGRESS`, `APPROVED`, `READY`, `IMPLEMENTED` (but not merged, superseded, cancelled, or on_hold)

**Example:**
```
USR-001: status=APPROVED (SUPERSEDED) → ✅ Doesn't count (superseded)
USR-001-v2: status=IMPLEMENTED → ✅ Counts (active)
USR-001-v3: ❌ BLOCKED - Max 1 active version reached
```

**Reason:** **Forced linearity** - Prevents merge chaos, resource splitting, and team ambiguity. Forces completing a feature before starting another.

**Enforcement:**
- Command `/CODESIGN --revise` checks count before creating a new version
- If >=1 active version → BLOCKS with message:
  ```
  ❌ MAX ACTIVE VERSION EXCEEDED
  Active version for USR-001: [v2 (status: DEV IN_PROGRESS)]
  
  Options:
  1. PAUSE v2: /CODESIGN --pause USR-001-v2 "Reason" → Allows creating v3
  2. CANCEL v2: /CODESIGN --cancel USR-001-v2 → Allows creating v3
  3. COMPLETE v2: Finish full SDLC pipeline first
  
  Why 1 version only?
  - Prevents merge conflicts
  - Avoids team resource splitting
  - Eliminates "which version to work on?" confusion
  - Forces architectural decisions before coding
  ```

**Exception: ON_HOLD State**
- Versions with `status: ON_HOLD` do NOT count as active
- Allows temporarily pausing v2 to create v3
- Command: `/CODESIGN --pause {{FEATURE_ID}} "reason"`

---

## Versioning Commands

### `/CODESIGN --revise {{FEATURE_ID}} "[REASON]"`

**Purpose:** Create a new version of a feature whose spec is locked by downstream work

**Prerequisites:**
- `spec.feature` exists with `status: APPROVED`
- Downstream work exists (test_plan.md, design.md, or dev_plan.md with `status: APPROVED`)

**Workflow:**
1. **Validation:** Verifies that no more than 1 active version exists
2. **Version Calculation:** Increments number (`USR-001` → `USR-001-v2`)
3. **Directory Creation:** `docs/spec/USR-001-v2/`
4. **Artifact Copy:**
   - Copies `initial.md` + adds `revision_reason` section
   - Copies `spec.feature` + updates frontmatter
5. **Marks Parent as SUPERSEDED:**
   ```yaml
   status: APPROVED (SUPERSEDED)
   superseded_by: USR-001-v2
   ```
6. **Inheritance Prompt:** Asks whether to copy downstream artifacts (test_plan, design)
7. **Log:** `| PO | REVISION_CREATED | USR-001-v2 from USR-001 | Reason: [REASON] |`

**Output:**
```
✅ Revision created: USR-001-v2

New spec initialized at: docs/spec/USR-001-v2/spec.feature
Parent spec marked as SUPERSEDED.

  Reason: "Add OAuth authentication"

Next steps:
1. Review and refine: /CODESIGN --refine USR-001-v2 "[changes]"
2. Approve when ready: Auto-approval via /CODESIGN --start or --refine USR-001-v2

Inherited context from USR-001:
- Business requirements (initial.md)
- Gherkin scenarios (spec.feature - edit as needed)

Downstream agents will detect parent version and offer inheritance options.
```

---

### `/CODESIGN --deprecate {{FEATURE_ID}} "[REASON]"`

**Purpose:** Soft-cancel for approved features (marks as obsolete without breaking traceability)

**Difference vs `/CODESIGN --cancel`:**
- **`--cancel`:** Hard block, used for early-stage failures (DRAFT, NEEDS_INFO)
- **`--deprecate`:** Soft archive, used for completed features that are no longer maintained

**Workflow:**
1. **Validation:** Feature must exist with `status: APPROVED` or higher
2. **Mark as DEPRECATED:**
   ```yaml
   status: DEPRECATED
   deprecated_at: 2026-01-22T12:00:00Z
   deprecation_reason: "Business requirements changed"
   ```
3. **Does not delete artifacts** — Only marks as inactive
4. **Log:** `| PO | DEPRECATED | USR-001 | Reason: [REASON] |`

---

### `/IMPLEMENT --fix {{FEATURE_ID}} "[CVE or QA_REJECTION]"`

**Purpose:** Two use cases:
1. **QA Rejection (standard flow):** Fix issues identified by `/QA --verify` → generates [FIX-N] tasks → sets `qa_report.status: INVALIDATED` → re-triggers `/QA --verify`
2. **Security Hotfix (emergency):** Immutability bypass for critical production vulnerabilities (post-merge)

**Conditions (QA Rejection — pre-merge):**
- `qa_report` exists with `status: REJECTED`
- `dev_plan.md` with `status: IMPLEMENTED_AND_VERIFIED`
- Generates [FIX-N] checkbox tasks from QA rejection items
- After completion gate: sets `qa_report.status: INVALIDATED`, keeps `dev_plan.status: IMPLEMENTED_AND_VERIFIED`

**Conditions (Security Hotfix — post-merge):**
- Feature must be merged to `main`
- `sec_audit.md` with `status: APPROVED`
- Active security vulnerability (CVE, high-risk finding)

**Workflow:**
1. **Immutability Bypass:** Does not require QA approval
2. **Limited Scope:** Only dependency patches or config fixes
3. **Prohibited:** Functional changes (require full new version)
4. **Artifact:** Creates `sec_audit_hotfix_{timestamp}.md`
5. **Escalation:** IMPLEMENT executes `/IMPLEMENT --fix USR-001 "patch command"`
6. **Re-Audit:** Mandatory via `/QA --verify USR-001`

**Frontmatter:**
```yaml
status: HOTFIX
hotfix_for: CVE-2026-1234
security_approved_by: SEC Agent
hotfix_applied_at: 2026-01-22T15:00:00Z
```

**Constraints:**
- No ADR required (documented in `sec_audit_hotfix.md`)
- Commit tag: `// Ref: USR-001, HOTFIX: CVE-2026-1234`

---

## Usage Scenarios

### Case 1: Spec Change During Development

**Situation:** USR-001 in DEV phase (50% tasks completed), PO needs to add OAuth

**Flow:**
1. CODESIGN attempts `/CODESIGN --refine USR-001`:
   ```
   ❌ BLOCKED: spec.feature is APPROVED with downstream work (DEV in progress).
   Use `/CODESIGN --revise USR-001 "reason"` to create USR-001-v2.
   ```
2. CODESIGN executes `/CODESIGN --revise USR-001 "Add OAuth login"`:
   - Creates `USR-001-v2/`
   - Marks `USR-001` as `SUPERSEDED`
   - Notifies ARCH/QA/DEV
3. **Decision:** Continue USR-001 as-is, or pause and work on v2?
4. If paused: IMPLEMENT can `/IMPLEMENT --plan USR-001-v2` with delta mode (only new tasks)

---

### Case 2: Vulnerability in Production

**Situation:** USR-001 in production for 6 months, critical CVE in dependency

**Flow:**
1. QA executes `/IMPLEMENT --fix USR-001 "CVE-2026-1234"`:
   - Immutability bypass
   - Creates `sec_audit_hotfix_{timestamp}.md`
2. IMPLEMENT executes `/IMPLEMENT --fix USR-001 "npm update express@5.0.1"`:
   - Commit: `// Ref: USR-001, HOTFIX: CVE-2026-1234`
   - **Does not version USR-001** (remains v1)
3. QA executes `/QA --verify USR-001`:
   - Re-scans
   - If it passes: Updates `sec_audit.md` Section 0 (Remediation Log)

---

### Case 3: Pivot During Development (Max 1 Version)

**Situation:** USR-001-v2 in DEV (50% complete), user discovers approach doesn't scale, needs to create v3 with new architecture

**Flow:**
1. User attempts `/CODESIGN --revise USR-001-v2 "Switch to microservices"`:
   ```
   ❌ MAX ACTIVE VERSION EXCEEDED
   Active version for USR-001: [USR-001-v2 (status: IN_PROGRESS)]
   
   Options:
   1. PAUSE v2: /CODESIGN --pause USR-001-v2 "Escalabilidad insuficiente" → Allows creating v3
   2. CANCEL v2: /CODESIGN --cancel USR-001-v2 → Permanently removes v2
   3. COMPLETE v2: Finish SDLC pipeline first, then revise
   
   Recommendation: Use PAUSE if you might return to v2 approach later.
   ```

2. User chooses PAUSE:
   ```
   /CODESIGN --pause USR-001-v2 "Approach doesn't scale to 10M users. Exploring microservices."
   ```
   - Output:
     ```
     ⏸️ Feature USR-001-v2 paused (status: ON_HOLD).
     Previous status: IN_PROGRESS
     
     You can now create USR-001-v3.
     To resume v2 later: /CODESIGN --resume USR-001-v2
     ```

3. User creates new version:
   ```
   /CODESIGN --revise USR-001 "Microservices architecture for scalability"
   ```
   - Creates `USR-001-v3/` (v2 in ON_HOLD doesn't count as active)

4. **Subsequent Decision:**
   - If v3 works → `/CODESIGN --cancel USR-001-v2` (discards v2)
   - If v3 fails → `/CODESIGN --resume USR-001-v2` (resumes v2)

---

## Compliance & Audit Trail

### Compliance Benefits

| Regulation | Immutability Benefit |
|------------|----------------------|
| **GDPR Art. 30** | Full traceability of features that process personal data |
| **SOX 404** | Immutable audit trail for internal controls |
| **HIPAA Security Rule** | Proof that PHI features were audited |
| **ISO 27001** | Documented change management |
| **PCI DSS 6.5** | Traceability of security controls to specs |

### Audit Trail Example

```
docs/project_log/workflow_log.json

| Timestamp | Feature_ID | Agent | Command | Status_Before | Status_After | Blocked | Reason |
|-----------|------------|-------|---------|---------------|--------------|---------|--------|
| 2026-01-15T10:00 | USR-001 | CODESIGN | --start (auto-approved) | DRAFT | APPROVED | No | 9/9 validations passed |
| 2026-01-15T10:05 | USR-001 | BLUEPRINT | --start | - | DRAFT | No | - |
| 2026-01-15T10:10 | USR-001 | BLUEPRINT | --approve | READY | APPROVED | No | - |
| 2026-01-20T09:00 | USR-001 | CODESIGN | --refine | APPROVED | APPROVED | Yes | Downstream work exists |
| 2026-01-20T09:05 | USR-001 | CODESIGN | --revise | APPROVED | APPROVED (SUPERSEDED) | No | Create v2 |
| 2026-01-20T09:05 | USR-001-v2 | CODESIGN | --revise | - | DRAFT | No | Created from USR-001 |
```

---

## Enforcement Mechanism

### Pre-Command Validation (All Agents)

Before executing any command, each agent **MUST** run:

```python
def check_immutability(agent, command, feature_id):
    """
    CRITICAL: Run BEFORE every command execution
    """
    artifact_path = get_artifact_path(agent, feature_id)
    
    if not os.path.exists(artifact_path):
        # New feature, no immutability check needed
        return True
    
    frontmatter = parse_frontmatter(artifact_path)
    
    # Check 1: CANCELLED state (universal block)
    if frontmatter.get("status") == "CANCELLED":
        raise BlockedError("Feature is CANCELLED. Cannot operate on cancelled features.")
    
    # Check 2: SUPERSEDED state
    if "SUPERSEDED" in frontmatter.get("status", ""):
        raise BlockedError(
            f"Feature {feature_id} has been superseded by {frontmatter.get('superseded_by')}. "
            f"Work on the new version instead."
        )
    
    # Check 3: Immutability lock (agent-specific)
    if frontmatter.get("status") == "APPROVED":
        if command in ["--refine", "--plan", "--reset"]:
            if has_downstream_work(agent, feature_id):
                raise BlockedError(
                    f"Artifact is APPROVED with downstream work. "
                    f"Use `/{agent} --revise {feature_id} 'reason'` to create new version."
                )
    
    return True


def check_increment_immutability(agent, command, feature_id, target_increment_ids):
    """
    Per-Increment lock — applies when agent/command targets specific increments
    inside increment_plan.md. Runs AFTER check_immutability() has accepted the
    artifact-level operation (increment_plan.md is in APPROVED status).

    target_increment_ids: list of increment IDs the command intends to mutate
    (e.g., ["INC-2"] for a --refine scoped to a single increment, or the full
    list of modified increments for a multi-touch --refine).
    """
    plan_path = f"docs/spec/{feature_id}/increment_plan.md"
    if not os.path.exists(plan_path):
        return True  # No plan → nothing to enforce

    increments = parse_section_1_increments(plan_path)   # yields {id, status, merged_at, ...}
    by_id = {inc["id"]: inc for inc in increments}

    for inc_id in target_increment_ids:
        inc = by_id.get(inc_id)
        if inc is None:
            raise BlockedError(f"Increment {inc_id} not found in {plan_path}")

        status = inc["status"]

        if status == "MERGED":
            raise BlockedError(
                f"Increment {inc_id} is MERGED (production). "
                f"Options: (a) `CODESIGN --revise {feature_id}` to create a new feature version, "
                f"(b) append a NEW follow-up increment via `BLUEPRINT --refine {feature_id}` "
                f"— additive-only, non-overlapping scenarios/contracts, see Follow-up Increment Rule."
            )

        if status == "BUILDING":
            raise BlockedError(
                f"Increment {inc_id} is BUILDING (branch open, tasks in progress). "
                f"Complete the increment or run `IMPLEMENT --pause {feature_id} {inc_id}` first."
            )

        # DRAFT / READY / INVALIDATED → allowed (subject to field-level rules in the
        # Per-Increment Lock Table — e.g., READY freezes scope/scenarios/contracts
        # while permitting layer-task edits).
        enforce_field_level_rules(inc, command, status)

    # Status-transition monotonicity (if command carries a status delta)
    for inc_id, (before, after) in status_transitions(command).items():
        if not is_valid_transition(before, after):
            raise BlockedError(
                f"Invalid status transition for {inc_id}: {before} → {after}. "
                f"Allowed: DRAFT → READY → BUILDING → MERGED; {{DRAFT,READY}} → INVALIDATED → DRAFT."
            )

    return True
```

### Workflow Log Integration

All blocks MUST be recorded:

```python
log_workflow(
    feature_id=feature_id,
    agent=agent,
    command=command,
    status_before=current_status,
    status_after=current_status,  # Did not change
    blocked=True,
    reason="Immutability violation - downstream work approved"
)
```

---

## Exceptions and Override

### Permitted Exceptions

1. **Typo Fixes:** Minor editorial corrections (grammar, spelling)
   - **Limit:** Maximum 3 per artifact
   - **Command:** `/CODESIGN --refine USR-001 "Fix typo: pasword → password"`
   - **Condition:** Only if no downstream `APPROVED` work exists
   - **Record:** Documented in Section 0 (Definition History)

2. **Security Hotfixes:** Critical vulnerabilities in production
   - **Command:** `/IMPLEMENT --fix USR-001 "CVE-XXX"`
   - **Scope:** Only dependency updates, config patches
   - **Prohibited:** Functional changes

### Manual Override (NOT IMPLEMENTED)

**Note:** In the future, a `--force-override` flag could be added with:
- Requires justification
- Requires approval from 2 people
- Special audit log (marks as immutability override)
- Only for extreme cases (do not use in normal operation)

---

## Migrating Existing Features

### Features Without `version` Field

**Treatment:** Considered `version: 1` (implicit)

**Automatic Conversion:** Not required - backward compatibility guaranteed

**First Revision:** When executing `/CODESIGN --revise USR-001`, it is assumed that `USR-001` is `v1` and `USR-001-v2` is created.

### Features in DRAFT/NEEDS_INFO

**Immutability:** Does not apply — can be modified freely

---

## Frequently Asked Questions (FAQ)

### Can I edit a spec after approving it?

**If there is no downstream work:** Yes, via `/CODESIGN --refine` (limited to typos)
**If there is downstream work:** No, you must use `/CODESIGN --revise` to create a new version.

### What happens if I need to change the design after implementing?

You must create a new version:
1. `/CODESIGN --revise USR-001 "Architecture change"`
2. This creates `USR-001-v2`
3. BLUEPRINT/IMPLEMENT work on v2 while v1 remains untouched

### How do I handle a production bug?

**Functional bug:** Create a new feature (BUG-XXX) or version (USR-001-v2)
**Security vulnerability:** Use `/IMPLEMENT --fix USR-001 "CVE-XXX"`

### Can I have 5 parallel versions?

No, maximum 1 active version at a time. Complete or cancel one before creating another.

---

## References

- **Versioning Commands:** See the framework README § "Command Reference" for the full command catalogue — [github.com/e2its/mi-AI-Factory-for-Claude](https://github.com/e2its/mi-AI-Factory-for-Claude#command-reference)
- **Frontmatter Schema:** See templates in `.context/specs/`
- **Workflow Log:** See `docs/project_log/workflow_log.json`
- **Command Definitions:** See slash commands in `.claude/commands/`
