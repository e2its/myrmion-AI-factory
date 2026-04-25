---
description: "Factory SETUP upgrade — framework version upgrade, rollback, legacy migration, Smart Additive Merge. Use when: SETUP --upgrade, --rollback-upgrade, --migrate-legacy-setup."
---

# SETUP Agent — Upgrade, Migration & Rollback (`/setup --upgrade`, `--rollback-upgrade`, `--migrate-legacy-setup`)

> Instruction file for the SETUP worker agent — Governance upgrade, legacy migration, and rollback capabilities.
> Loaded when SETUP handles `--upgrade`, `--rollback-upgrade`, or `--migrate-legacy-setup`.

---

## Migration Path Mapping

### v9.0.0 — filename rename

| Pre-9.0.0 Path | Post-9.0.0 Path |
|---|---|
| .claude/instructions/agents/*.md | .claude/instructions/Factory-*.instructions.md |
| .claude/instructions/protocols/*.md | .claude/instructions/Factory-protocol-*.instructions.md |
| .claude/instructions/protocols/{5 cross-cutting}.md | .claude/skills/Factory-{name}/SKILL.md |
| docs/rules/*.md | docs/rules/*.instructions.md |

### Rules / config split (NOT auto-applied)

| Pre-EVOL-016 | Post-EVOL-016 |
|---|---|
| docs/rules/*.instructions.md | .claude/rules/*.instructions.md |
| docs/rules/defect-prevention.md | .claude/rules/defect-prevention.md |
| docs/rules/protected-paths.json | config/protected-paths.json |
| docs/rules/allowlist.json | config/allowlist.json |

Manual migration (run once, gated by `test -d docs/rules && ! test -d .claude/rules`):

```bash
git mv docs/rules .claude/rules
[ -f .claude/rules/protected-paths.json ] && git mv .claude/rules/protected-paths.json config/protected-paths.json
[ -f .claude/rules/allowlist.json ] && git mv .claude/rules/allowlist.json config/allowlist.json
```

Then regenerate governance snapshot and re-run `--upgrade`.

---

## Command: `--upgrade` (v3.0.0)

Upgrades project governance artifacts to match the latest framework templates. Uses Smart Additive Merge to preserve user customizations while adding new framework capabilities.

**Key features:** Pre-Upgrade Audit, Smart Discovery Cascade, RDR Protocol, Zero-TODO Enforcement, Atomic Operations, Rollback, On-Demand Sync.

### Prerequisites (BLOCKING)
- `docs/setup.md` with `materialization_complete: true`
- `.context/templates/setup/governance_versions.json` (framework manifest)
- If `docs/project_log/governance_versions.json` missing → treat as legacy project, construct snapshot with forced `"0.0.0"` versioning to ensure full scan

---

### Step -1: Pre-Upgrade Inventory Audit Protocol

6-phase comprehensive audit before any modifications:

**Phase 1 — Registry Integrity Check:**
Verify `governance_versions.json` structure, all referenced files exist on disk, no orphan entries.

**Phase 2 — Phantom File Detection:**
Scan `.claude/rules/`, `config/`, `scripts/` for files not tracked in registry. For each phantom:
- (a) Register in snapshot (was created manually)
- (b) Delete (accidental/obsolete)
- (c) Skip (handle later)

**Phase 3 — Template Checksum Validation:**
Compare current framework template checksums against stored checksums. Detect drift (file was modified in framework since last upgrade). Flag templates that changed.

**Phase 4 — Target File State Inventory:**
For each file that will be touched by upgrade, record: current checksum, last modified date, size. Used for rollback.

**Phase 5 — Dependency Graph Validation:**
Check cross-references between governance files. Detect broken links (e.g., constitution.md references a rule that doesn't exist). List broken dependencies.

**Phase 6 — ADR Customization Protection Check (v2):**
For each ADR in `docs/project_log/adr/`:
- **VALUE_PROTECTED (default):** Structural updates allowed, but user-defined values preserved during merge. Smart Merge auto-assigned.
- **FULL_LOCK:** No modifications at all. Only when ADR explicitly states `lock: full`.
- Classify each ADR, report protection scope.

---

### Step 0: Prerequisite Validation (4.4.0)
1. Verify `materialization_complete: true`
2. Load framework manifest from `.context/templates/setup/governance_versions.json`
3. Load project snapshot from `docs/project_log/governance_versions.json`
4. If project snapshot missing: construct from current files with forced `"0.0.0"` version

### Step 1: Version Comparison & Change Detection (4.4.1)
1. Compare framework versions vs project versions (SemVer)
2. Evaluate `stack_conditional` filters (skip files that don't apply to current stack)
3. Detect user customizations (project checksum ≠ previous framework checksum → user modified file)
4. Present upgrade summary with options: **ALL** (upgrade everything) | **SELECT** (choose files) | **ABORT**

### Step 1b: Centralized Backup Creation (MANDATORY)
**Before ANY file modification:**
1. Create `BACKUP_MANIFEST.json` with per-file tracking
2. Copy every file that will be modified to backup location
3. Record original checksums for rollback verification
4. Backup is ATOMIC — all or nothing

---

### Step 2: Unified Smart Additive Merge (4.4.2)

ALL files use the same merge strategy (replaces old Category A/B/C system):

**Gate 0 — ADR Lock Check:**
If file is FULL_LOCK → SKIP (no modifications). If VALUE_PROTECTED → proceed with value preservation.

**Step 1 — Read Source & Target:**
Read framework template (new) and current project file.

**Step 1b — Script Semantic Merge (special case for `.sh`/`.py` scripts):**
Block-based parsing strategy:
1. Parse both files into semantic blocks (functions, sections, headers)
2. Match blocks between old and new by name/signature
3. For each block: compute diff
4. Per-block conflict resolution options:
   - **KEEP:** Retain project version (user customization)
   - **TAKE:** Accept framework version (new capability)
   - **MERGE:** Combine both (add new code while preserving customizations)
   - **APPEND:** Add framework block at end (new function)
5. Post-merge validation: syntax check, duplicate symbol detection

**Step 2 — Structural Diff (format-aware):**
- **JSON:** Key-by-key comparison, detect added/removed/modified keys
- **Markdown:** Section-by-section comparison using headers as anchors
- **YAML:** Key-path comparison, detect structural changes
- **Text/Other:** Line-by-line diff

**Step 3 — Check Additions:**
Identify new sections/keys/content in framework template that don't exist in project file.

**Step 4 — Resolve Placeholders (Smart Discovery Cascade):**
For any `{{PLACEHOLDER}}` in new content, resolve from 5 sources in order:
1. `docs/setup.md` body fields
2. `docs/constitution.md` values
3. ADR decisions
4. Existing rules files
5. Config files (`config/*.json`)

If unresolved after all 5 sources → **RDR Protocol**: Present recommendation with justification + alternatives → User decides → Ratify immediately.

**Step 5 — Build Merged Content:**
Format-specific merge functions:
- `JSON_ADDITIVE_MERGE`: Add new keys, preserve existing values, deep merge nested objects
- `MARKDOWN_ADDITIVE_MERGE`: Add new sections at appropriate position, preserve existing content
- `YAML_ADDITIVE_MERGE`: Add new keys, preserve existing values, handle nested structures

**Step 5a — Semantic Coherence Check:**
Post-merge validation to detect configuration conflicts:

*JSON conflicts:*
- Opposing-list conflicts (e.g., `allow: ["X"]` and `deny: ["X"]` for same item) using OPPOSING_PAIRS table
- Numeric bound conflicts (e.g., `min > max`, `timeout < 0`)

*Markdown conflicts:*
- Overlapping domain detection using DOMAIN_KEYWORDS
- Tool conflicts (two rules recommending different tools for same purpose)
- Numeric conflicts (contradictory thresholds)
- Policy contradictions

*YAML conflicts:* Same as JSON checks.

**Coherence Resolution Protocol:**
- **CRITICAL/HIGH issues:** Resolve 1-by-1 with options: HARMONIZE | KEEP EXISTING | KEEP NEW | KEEP BOTH
- **MEDIUM issues:** Batch resolution

**Step 5b — Zero-TODO Enforcement:**
Scan merged content for unresolved placeholders (`TODO`, `FIXME`, `XXX`, `{{...}}`).
- **Exception:** `REPLACE_ME_*` patterns in `.env.example` files are EXEMPT (Secret Placeholder Convention v11.0.0)
- If unresolved TODOs found → resolve via Smart Discovery Cascade or RDR before proceeding

**Step 6 — Show Diff:** Display unified diff for user confirmation.
**Step 7 — Write:** Save merged content to file.
**Step 8 — Update Snapshot:** Record new checksum in project `governance_versions.json`.

---

### Step 3: New File Handling (4.4.3)
Files that exist in framework but not in project:
1. Apply same Smart Discovery Cascade for placeholder resolution
2. Apply RDR for unresolvable placeholders
3. Apply Zero-TODO Enforcement
4. Write new file
5. Register in `governance_versions.json`

**Special case — `claude/CLAUDE.md` and `claude/settings.json`:**

- `.context/templates/setup/claude/CLAUDE.md` → target `CLAUDE.md` (project root). Uses `smart-additive-merge`. On first upgrade after EVOL-018, the project's existing `CLAUDE.md` is expected to be the old framework-shared variant; the merge keeps all existing sections, adds any new universal sections from the template, and leaves user-added sections untouched. Framework-repo-specific sections in the old file (e.g. "Meta-Framework Triage", paths to `.context/templates/setup/governance_versions.json`) become stale — the upgrade surfaces them as diff candidates for user review. Explicit user confirmation is required before the merge replaces framework-specific guidance with project-specific guidance.
- `.context/templates/setup/claude/settings.json` → target `.claude/settings.json`. Uses `merge-preserve` (more conservative than smart-additive-merge):
  - Add the `hooks.SessionStart`, `hooks.UserPromptSubmit`, `hooks.PreCompact` blocks from the template if absent in target.
  - For `hooks.PreToolUse`, if target has any entry at all, leave it untouched (never overwrite user-configured pre-tool-use hooks).
  - NEVER touch `permissions`, `model`, `env`, or any other top-level keys.
  - Idempotent: re-running `--upgrade` after the first run is a no-op.

### Step 3b: Post-Merge Script Validation (4.4.3b)
After ALL script files are merged, run 6 validation checks:

1. **Syntax Check:** `bash -n` for `.sh`, `py_compile` for `.py`
2. **Shebang Integrity:** Verify `#!/bin/bash` or `#!/usr/bin/env python3` present
3. **Permission Check:** Verify `+x` permission on all `.sh` files
4. **Duplicate Symbol Detection:** Scan for duplicate function names within same file
5. **Merge Artifact Detection:** Scan for `<<<<<<<`, `=======`, `>>>>>>>` markers
6. **Smoke Test:** Run `script --help` or equivalent (if supported)

**Decision Gate (if any check fails):**
- **ROLLBACK SCRIPTS:** Restore all scripts from backup, re-run merge with different options
- **ROLLBACK ALL:** Full upgrade rollback (→ `--rollback-upgrade`)
- **FIX NOW:** Manually fix issues before continuing
- **CONTINUE:** Accept issues (with logged warnings)

---

### Step 4: Finalization (4.4.4)
1. Update project snapshot (`governance_versions.json`) with all new checksums
2. Finalize backup manifest: `status: COMPLETED`
3. **Regenerate governance snapshot** (`.context/governance_snapshot.md`):
   - Constitution may have changed during upgrade → snapshot must reflect new state
   - Call `generate_governance_snapshot()` from setup-materialization.md Checkpoint 3.1
   - This ensures post-upgrade agent commands use fresh governance context
4. Generate `UPGRADE_REPORT_{timestamp}.md` with:
   - Files modified (with before/after versions)
   - New files added
   - Coherence issues resolved (and how)
   - Script validation results
   - Skipped files (with reason)
5. `APPEND_TO_WORKLOG` × 3 (start, execution, completion)

### Developer Workflow for Template Authors (4.4.5)
When updating framework templates:
- Follow SemVer bump rules (MAJOR: breaking, MINOR: additive, PATCH: fix)
- Update changelog
- Update `governance_versions.json` with new version + checksum
- Document new placeholders in placeholder registry

---

## Command: `--rollback-upgrade` (4.5)

Reverts a failed or unwanted upgrade to a previous state.

### Prerequisite Validation
- `BACKUP_MANIFEST.json` must exist with `status: COMPLETED`
- List available rollback points (from backup history) for user selection

### Atomic Rollback Execution
1. **Pre-rollback checkpoint:** Save current state as emergency recovery point
2. **Checksum verification:** For each file to restore, verify backup file integrity
3. **Atomic copy:** Restore all files from backup (all or nothing)
4. **Update snapshot:** Revert `governance_versions.json` to pre-upgrade state
5. **Validate restoration:** Verify all restored files match expected checksums

### Emergency Rollback
If atomic rollback fails:
- Provide manual intervention protocol with step-by-step commands
- List files that need manual restoration
- Point to backup location

### Post-Rollback Report
- Files restored (with checksums)
- Post-rollback validation results
- `APPEND_TO_WORKLOG` with rollback details

### Post-Upgrade Validation Script
`validate-upgrade-integrity.sh` performs 6 checks:
1. All files in snapshot exist on disk
2. All checksums match recorded values
3. No orphan governance files
4. No broken cross-references between rules
5. Constitution.md has no unresolved placeholders
6. All scripts pass syntax check

---

## Command: `--migrate-legacy-setup` (4.3) — EXPERIMENTAL

**⚠️ Status: EXPERIMENTAL** — Behavior, scoring, and thresholds may change.

**Prerequisites:**
- `project_mode: Brownfield` in `docs/setup.md`
- **Strategy Gate:** If `extension.strategy: E0` (Native Extension) → SKIP migration strategy entirely (E0 does not involve migration). Only E1/E2/E3 proceed.

### NO-FORCE Policy
There is NO `--force` option. If viability score is too low, the command ABORTS. No override exists.

### Step 1: Automatic Viability Analysis (4.3.2)
**BLOCKING** — runs before any user interaction.

6-phase scoring with weighted criteria (total: 100 points):

| Phase | Weight | What it measures |
|-------|--------|-----------------|
| Stack Detection | 25% | Can we identify the technology stack? |
| Test Coverage | 20% | Does the project have meaningful tests? |
| Documentation | 15% | Is existing documentation usable? |
| Architectural Complexity | 20% | How complex is the current architecture? |
| Dependencies State | 10% | Are dependencies healthy and current? |
| External Integrations | 10% | How many external systems are coupled? |

**Threshold: 85%**
- **Score > 85% (VIABLE):** Continue to guided analysis
- **Score ≤ 85% (NOT_VIABLE):** **ABORT** with blockers list. No override exists.

Generates viability report with per-phase scores and overall verdict.

### Step 2: Legacy Analysis Guided (4.3.3)
4 interactive questions (conditional on viability phase scores):
- Questions about codebase age, team familiarity, technical debt areas, migration urgency
- Skip questions where viability scan already provided high-confidence answers

### Step 3: Migration Strategy Generation (4.3.4)

**Strategy-specific phase templates by extension strategy:**

| Strategy | Approach | Key Phases |
|----------|----------|------------|
| E1 (Preserve+Wrapper) | Build adapters around existing code | Adapter layer → New modules → Integration testing → Gradual adoption |
| E2 (Strangler Fig) | Build new around old, replace incrementally | Proxy layer → Module-by-module replacement → Data migration → Legacy decommission |
| E3 (Full Rewrite) | Freeze legacy, build fresh | Specification capture → New build → Data migration → Cut-over |

**Generates:**
- `docs/migration_strategy.md` with strategy-specific content
- 5 actionable Epics (MIGR-001 through MIGR-005)
- Estimated roadmap (up to 12 months)
- Risk assessment table

---

## Architecture Reference

### Backend Topologies (B1-B12)

| ID | Name | Tier | Cost/mo |
|----|------|------|---------|
| B1 | Traditional Monolith | Starter | $150 |
| B2 | Modular by Bounded Contexts | Professional | $300 |
| B3 | DDD + Event Sourcing | Professional | $450 |
| B4 | Microkernel + Plugins | Professional | $480 |
| B5 | Microservices REST | Professional | $800 |
| B6 | Microservices Event-Driven | Enterprise | $1,100 |
| B7 | Microservices CQRS+ES | Enterprise | $1,300 |
| B8 | SOA + ESB | Enterprise | $700 |
| B9 | Serverless | Professional | $400 |
| B10 | Peer-to-Peer | Enterprise | $900 |
| B11 | Broker/Pipeline | Enterprise | $650 |
| B12 | MVC Monolith | Starter | $150 |

### Frontend Patterns (F1-F10)

| ID | Name | Tier | Cost/mo |
|----|------|------|---------|
| F1 | SPA | Starter | $100 |
| F2 | SSR + Hydration | Professional | $150 |
| F3 | SSR Pure | Starter | $120 |
| F4 | ISR | Professional | $180 |
| F5 | MFE Module Federation | Enterprise | $400 |
| F6 | MFE iFrames | Enterprise | $400 |
| F7 | MFE Web Components | Enterprise | $400 |
| F8 | Islands Architecture | Professional | $200 |
| F9 | PWA | Starter | $120 |
| F10 | Component-Driven | Starter | $100 |

### Integration Layer
- **ACL Global:** Anti-Corruption Layer between backend and frontend
- **Backend Aggregator Pattern:** For distributed topologies (B5-B11), aggregate cross-service data at the API gateway level

---

## Logging Standards

All SETUP commands use `APPEND_TO_WORKLOG` with phase mapping:

| Command | Phase |
|---------|-------|
| --init | Discovery |
| --generate | Materialization |
| --generate --resume | Materialization |
| --migrate-legacy-setup | Materialization |
| --upgrade | Materialization |
| --rollback-upgrade | Correction |

---

## Responsibilities Summary

| Command | Input | Output | Final State |
|---------|-------|--------|-------------|
| --init | User answers | docs/setup.md + ADR-0000 | phase: COMPLETED |
| --generate | setup.md (COMPLETED) | All governance + scaffolding | materialization_complete: true |
| --generate --resume | MATERIALIZATION_REPORT (IN_PROGRESS) | Remaining tasks | status: COMPLETED |
| --migrate-legacy-setup | Brownfield project | migration_strategy.md + 5 Epics | Strategy generated |
| --upgrade | Framework templates | Merged governance files + UPGRADE_REPORT | Snapshot updated |
| --rollback-upgrade | BACKUP_MANIFEST | Restored files | Pre-upgrade state |

**SETUP is responsible for:** Project structure, governance, scaffolding, configuration, budget.
**SETUP is NOT responsible for:** Source code, tests, deployment, feature implementation — those belong to IMPLEMENTDEVOPSQA.
