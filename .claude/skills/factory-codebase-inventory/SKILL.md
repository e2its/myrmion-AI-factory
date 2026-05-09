---
name: factory-codebase-inventory
description: "Factory Codebase Inventory Protocol (CIP) — DRY enforcement via codebase_inventory.json, CIP Canary gate, component reuse check. Use when: creating code artifacts, checking for existing components, or enforcing DRY across agents."
applicable_when:
  command: [implement, blueprint]
---

# CODEBASE INVENTORY PROTOCOL (CIP v1.2.0) — CROSS-AGENT DRY ENFORCEMENT

> **Shared Protocol** — Referenced by: CODESIGN, BLUEPRINT, IMPLEMENT, SETUP agents.
> Before ANY agent proposes creating a new service, entity, utility, component, or significant code artifact, it MUST consult the Codebase Inventory to detect existing artifacts with overlapping responsibility.
> **Memory Cache (MCP v1.0.0):** Uses `/memories/repo/codebase-inventory-cache.md` for fast domain-group lookups. See `Factory-memory-cache/SKILL.md`.

**Applies to:** `CODESIGN` (domain concepts), `BLUEPRINT` (technical artifacts), `IMPLEMENT` (code creation), `SETUP` (brownfield bootstrap)

### CIP Consultation Gate (BLOCKING — runs BEFORE any artifact creation)

```yaml
FUNCTION cip_consultation_gate(agent, proposed_artifacts):
  # This gate MUST execute before ANY agent creates a new service, entity,
  # utility, component, or significant code artifact. No exceptions.

  inventory_path = "config/codebase_inventory.json"
  IF NOT FILE_EXISTS(inventory_path):
    ⚠️ WARN: "Codebase inventory not found. DRY Gate degraded."
    LOG: "CIP_SKIPPED — inventory missing, proceed with caution"
    RETURN  # Proceed but REVIEW hat will catch duplicates post-build

  # Step 0: Cache Fast Path (MCP)
  # Try memory cache for fast domain-group lookups before full JSON parse.
  cache = MEMORY_READ("/memories/repo/codebase-inventory-cache.md")
  inventory_raw = READ(inventory_path)
  inventory_hash = MD5(inventory_raw)
  
  IF cache IS NOT NULL AND cache.frontmatter.source_hash == inventory_hash:
    LOG: "CIP inventory loaded from cache"
    inventory = PARSE_CACHED_INVENTORY(cache)  # Compact index + domain groups
  ELSE:
    LOG: "CIP cache miss or stale — loading full inventory"
    inventory = JSON_PARSE(inventory_raw)
    # Write-through: update cache with current inventory state
    write_inventory_cache(inventory, inventory_hash)

  FOR EACH artifact IN proposed_artifacts:
    # 4-Criteria Matching (name, type, module, responsibility)
    matches = find_inventory_matches(inventory, artifact)

    IF matches.EXACT_MATCH.length > 0:
      ❌ BLOCK: "EXACT MATCH found: '{matches[0].name}' at '{matches[0].path}'"
      SHOW: "Existing artifact has same name + type + module"
      RDR: Ask user → REUSE / EXTEND / CREATE_NEW (justification required for CREATE_NEW)
      IF choice == CREATE_NEW AND justification IS EMPTY:
        ❌ BLOCK: "CREATE_NEW requires justification to proceed"
        STOP

    IF matches.SAME_DOMAIN.length > 0:
      ⚠️ WARN: "Similar artifact '{matches[0].name}' in same domain — verify not duplicate"
      RDR: REUSE / EXTEND / CREATE_NEW

    LOG: "CIP Gate: '{artifact.name}' checked — {matches.length} potential matches"

  ✅ PROCEED — all proposed artifacts cleared
```

---

## Registry: `config/codebase_inventory.json`

```json
{
  "version": "1.0.0",
  "last_updated": "ISO_8601_TIMESTAMP",
  "bootstrap_mode": "greenfield|brownfield",
  "artifacts": [
    {
      "name": "UserService",
      "type": "service|domain_entity|repository|controller|adapter|ui_component|utility|middleware|hook|guard|pipe|module",
      "module": "auth",
      "path": "src/modules/auth/services/user.service.ts",
      "feature_ids": ["USR-001"],
      "responsibility": "Handles user CRUD, password hashing, profile management",
      "interfaces": ["IUserService"],
      "status": "PLANNED|IMPLEMENTED",
      "registered_by": "BLUEPRINT|IMPLEMENT",
      "registered_at": "ISO_8601_TIMESTAMP"
    }
  ]
}
```

---

## Bootstrap Strategy

```yaml
GREENFIELD (project_mode: Greenfield in setup.md):
  # Registry starts EMPTY. Grows organically:
  #   BLUEPRINT --approve → registers PLANNED artifacts from design.md
  #   IMPLEMENT --build  → transitions PLANNED→IMPLEMENTED, registers TDD-discovered artifacts
  
  ON SETUP --generate:
    IF NOT FILE_EXISTS("config/codebase_inventory.json"):
      CREATE with: { "version": "1.0.0", "last_updated": NOW, "bootstrap_mode": "greenfield", "artifacts": [] }

BROWNFIELD (project_mode: Brownfield in setup.md):
  # Registry bootstrapped with existing codebase artifacts during SETUP.
  
  ON SETUP --generate (brownfield):
    Execute BOOTSTRAP_CODEBASE_INVENTORY():
      Step 1: Detect stack from constitution.md
      Step 2: Use file_search with framework-specific glob patterns
      Step 3: Extract name + type + module from path convention
      Step 4: Use grep_search for class/function/export declarations
      Step 5: Populate config/codebase_inventory.json with status: IMPLEMENTED
```

---

## Lifecycle: PLANNED → IMPLEMENTED

```yaml
ARTIFACT LIFECYCLE:
  1. BLUEPRINT --approve: Registers artifacts from design.md → status: PLANNED
  2. IMPLEMENT --build: Transitions PLANNED→IMPLEMENTED + registers TDD-discovered artifacts
  3. Multi-feature evolution: REUSE/EXTEND decision via RDR for existing artifacts
```

---

## Domain-Aware Artifact Classification (MANDATORY)

```yaml
FUNCTION classify_artifact_reuse_category(artifact_type, artifact_module, topology):
  DOMAIN_MODEL_TOPOLOGIES = [B2, B3, B4, B5, B6, B7, B8, B10, B11]
  FLAT_TOPOLOGIES = [B1, B9, B12]
  
  is_domain_model = topology IN DOMAIN_MODEL_TOPOLOGIES
  
  SHARED_TYPES = [ui_component, utility, middleware, guard, pipe, hook, interceptor]
  DOMAIN_INTERNAL_TYPES = [service, domain_entity, repository, adapter, aggregate, value_object, domain_event]
  MODULE_TYPES = [controller, module]
  
  IF artifact_type IN SHARED_TYPES:
    RETURN "SHARED"
  IF artifact_type IN DOMAIN_INTERNAL_TYPES:
    RETURN "DOMAIN_INTERNAL" IF is_domain_model ELSE "SHARED"
  IF artifact_type IN MODULE_TYPES:
    RETURN "DOMAIN_INTERNAL" IF is_domain_model ELSE "SHARED"
  RETURN "SHARED"  # Default
```

---

## 4-Criteria Matching Algorithm (Used by BLUEPRINT & IMPLEMENT)

```yaml
FUNCTION find_inventory_matches(planned_artifact, topology):
  candidates = []
  reuse_category = classify_artifact_reuse_category(planned_artifact.type, planned_artifact.module, topology)
  
  FOR EACH existing IN codebase_inventory.artifacts:
    existing_category = classify_artifact_reuse_category(existing.type, existing.module, topology)
    same_module = (existing.module == planned_artifact.module)
    
    # DOMAIN ISOLATION GATE
    IF reuse_category == "DOMAIN_INTERNAL" AND existing_category == "DOMAIN_INTERNAL":
      IF NOT same_module:
        IF existing.name == planned_artifact.name AND existing.type == planned_artifact.type:
          candidates.push({existing, match_type: "CROSS_DOMAIN_COLLISION", confidence: 0.3})
        CONTINUE
    
    # STANDARD 4-CRITERIA MATCHING
    
    # Criterion 1: EXACT_MATCH
    IF existing.name == planned_artifact.name AND existing.type == planned_artifact.type:
      candidates.push({existing, match_type: "EXACT_MATCH", confidence: 1.0, reuse_category})
      CONTINUE
    
    # Criterion 2: SAME_DOMAIN
    IF same_module AND existing.type == planned_artifact.type:
      candidates.push({existing, match_type: "SAME_DOMAIN", confidence: 0.8, reuse_category})
      CONTINUE
    
    # Criterion 3: NEAR_DUPLICATE (>60% responsibility overlap)
    overlap = SEMANTIC_SIMILARITY(existing.responsibility, planned_artifact.responsibility)
    IF overlap > 0.6 AND existing.type == planned_artifact.type:
      candidates.push({existing, match_type: "NEAR_DUPLICATE", confidence: overlap, reuse_category})
      CONTINUE
    
    # Criterion 4: NAME_SIMILAR (Levenshtein distance <3)
    IF LEVENSHTEIN(existing.name, planned_artifact.name) < 3 AND existing.type == planned_artifact.type:
      candidates.push({existing, match_type: "NAME_SIMILAR", confidence: 0.5, reuse_category})
  
  RETURN candidates SORTED BY confidence DESC
```

---

## RDR Decision Protocol (Per Candidate — NEVER Batch)

```yaml
# BLUEPRINT RDR OPTIONS (during --start, Step -2):
# For SHARED or same-domain DOMAIN_INTERNAL matches:
REUSE:       "Use existing artifact as-is. Add current feature_id to feature_ids[]."
EXTEND:      "Extend existing artifact with new capabilities."
CREATE_NEW:  "Create new despite overlap. MANDATORY: ADR + log in design.md Section 0."

# For CROSS_DOMAIN_COLLISION (different domains, same name):
RENAME:          "Rename planned artifact to avoid confusion."
SHARED_KERNEL:   "Extract to Shared Kernel. MANDATORY: ADR."
KEEP_BOTH:       "Both intentionally distinct. MANDATORY: ADR."

# IMPLEMENT DRY GATE (during --build):
IF design.md Section 0 exists:
  TRUST BLUEPRINT decisions (already RDR'd)
ELSE:
  Lightweight check → Apply Domain Isolation Gate → RDR if overlap

# CODESIGN RDR OPTIONS (during --start, Phase 0.5):
REUSE_EXISTING: "Domain concept already exists. Reference it."
RENAME_NEW:     "Keep new concept but rename."
MERGE:          "Merge overlapping concepts."
KEEP_BOTH:      "Both distinct despite similar naming. Log in user_journey.md."
ACKNOWLEDGE_CROSS_DOMAIN: "Expected in DDD. Document boundary."
SHARED_KERNEL:  "Shared business concept. Flag for ADR by BLUEPRINT."
```

---

## Cross-Agent Responsibilities

```yaml
AGENT RESPONSIBILITIES:
  
  SETUP --generate:
    - CREATE config/codebase_inventory.json (empty for greenfield, bootstrapped for brownfield)
    - Add to protected-paths.json (config/ directory)
  
  SETUP --reconcile-inventory:
    - RECONCILE registry with actual codebase (5-phase protocol)
    - Re-bootstrap if file missing, validate integrity, clean orphans, discover untracked
  
  CODESIGN --start:
    - Phase 0.5: load_inventory_or_fallback() → cross-reference domain concepts
    - If missing → SKIP with CIP_SKIPPED log, proceed to Event Storming
    - RDR per overlap: REUSE_EXISTING / RENAME_NEW / MERGE / KEEP_BOTH
  
  BLUEPRINT --start:
    - Step -2: load_inventory_or_fallback() → 4-criteria matching → RDR per candidate (1-to-1)
    - If missing → SKIP with CIP_SKIPPED log, proceed to artifact generation
    - If stale (>30 days) → emit advisory for SETUP --reconcile-inventory
    - Log decisions in design.md Section 0: "Reuse Analysis"
  
  BLUEPRINT --approve:
    - Register PLANNED artifacts in registry
    - Update last_updated timestamp
  
  IMPLEMENT --plan:
    - Cross-reference dev_plan tasks against registry
    - If missing → WARN, continue with limited DRY checks
    - Annotate tasks with REUSE/EXTEND context from design.md Section 0
  
  IMPLEMENT --build:
    - DRY Gate: Load design.md Section 0; fallback to registry check
    - Auto-fix PLANNED→IMPLEMENTED if file already exists at artifact.path
    - REVIEW hat [DRY-XX] checks
    - Post-build: Update registry (PLANNED→IMPLEMENTED + new TDD artifacts)
  
  DEVOPS & QA:
    - No direct interaction with codebase_inventory.json
```

---

## REVIEW Hat DRY Check Categories (Enforced in IMPLEMENT --build)

```yaml
# Domain-Aware Severity (reads topology from constitution.md)

[DRY-SVC]:    Service duplication
  SHARED: BLOCKER if >80% overlap with REUSE-flagged existing
  DOMAIN_INTERNAL same_module: BLOCKER
  DOMAIN_INTERNAL different_module: SKIP (DDD isolation)
  EXCEPTION: SHARED_KERNEL decision → enforce shared service

[DRY-UTIL]:   Utility/helper duplication — WARNING (always SHARED category)

[DRY-ENTITY]: Domain entity duplication
  DOMAIN_INTERNAL different_module: INFO (correct DDD isolation)
  DOMAIN_INTERNAL same_module: BLOCKER
  SHARED (flat arch): BLOCKER if name+type matches

[DRY-LOGIC]:  Cross-module logic — ADVISORY (>60% similar business logic)
  Domain-model: advisory only | Flat: WARNING (extract to shared module)

[DRY-COMP]:   UI Component duplication — BLOCKER if exists in vision library or inventory
```

---

## Inventory Resilience Protocol

### Missing Inventory Fallback (ALL consuming agents)

```yaml
FUNCTION load_inventory_or_fallback():
  IF NOT FILE_EXISTS("config/codebase_inventory.json"):
    ⚠️ WARN: "Codebase inventory missing. DRY checks limited."
    LOG in worklog: { action: "CIP_INVENTORY_MISSING", result: "SKIPPED" }
    IF SETUP was completed (docs/setup.md exists with materialization_complete: true):
      ⚠️ ADVISORY: "Inventory should exist. Consider: SETUP --reconcile-inventory"
    RETURN null  # Agent continues with degraded DRY capability
  
  inventory = READ("config/codebase_inventory.json")
  RETURN inventory
```

**Per-agent fallback:**
- **CODESIGN** Phase 0.5: SKIP CIP check, proceed with Event Storming. Log `CIP_SKIPPED`.
- **BLUEPRINT** Step -2: SKIP reuse analysis, proceed with design. Log `CIP_SKIPPED`.
- **IMPLEMENT** --plan/--build: Emit `⚠️ WARN`, continue with limited DRY checks (code-level grep only).

### Orphaned PLANNED Cleanup

```yaml
FUNCTION cleanup_orphaned_planned(inventory):
  # Runs during RECONCILE and optionally during BLUEPRINT/IMPLEMENT reads
  FOR EACH artifact IN inventory.artifacts WHERE status == "PLANNED":
    feature_branch = git branch --list "*{artifact.feature_ids[0]}*"
    feature_spec = FILE_EXISTS("docs/spec/{artifact.feature_ids[0]}/design.md")
    
    IF NOT feature_branch AND NOT feature_spec:
      MARK artifact.status = "ORPHANED"
      LOG: "⚠️ PLANNED artifact '{artifact.name}' has no active feature. Marked ORPHANED."
  
  # ORPHANED artifacts are excluded from matching but preserved for audit trail
  # They can be manually removed or auto-purged after configurable retention (default: 90 days)
```

### Integrity Validation

```yaml
FUNCTION validate_inventory_integrity(inventory):
  issues = []
  
  FOR EACH artifact IN inventory.artifacts WHERE status == "IMPLEMENTED":
    IF NOT FILE_EXISTS(artifact.path):
      issues.push({ artifact: artifact.name, issue: "PATH_NOT_FOUND", path: artifact.path })
  
  FOR EACH artifact IN inventory.artifacts:
    IF NOT artifact.name OR NOT artifact.type OR NOT artifact.module:
      issues.push({ artifact: artifact.name, issue: "INCOMPLETE_ENTRY" })
  
  # Check for duplicates (same name + type + module)
  seen = {}
  FOR EACH artifact IN inventory.artifacts:
    key = "{artifact.name}:{artifact.type}:{artifact.module}"
    IF key IN seen:
      issues.push({ artifact: artifact.name, issue: "DUPLICATE_ENTRY", duplicate_of: seen[key] })
    seen[key] = artifact.name
  
  RETURN issues
```

---

## Reconciliation Protocol (SETUP --reconcile-inventory)

```yaml
FUNCTION RECONCILE_INVENTORY():
  # Phase 1: Load current state
  IF NOT FILE_EXISTS("config/codebase_inventory.json"):
    # Full re-bootstrap (reuse brownfield strategy)
    Execute BOOTSTRAP_CODEBASE_INVENTORY()
    RETURN
  
  inventory = READ("config/codebase_inventory.json")
  constitution = READ("docs/constitution.md")
  topology = EXTRACT(constitution, "architecture.topology")
  
  # Phase 2: Integrity validation
  issues = validate_inventory_integrity(inventory)
  
  FOR EACH issue IN issues:
    IF issue.type == "PATH_NOT_FOUND":
      # File was deleted/moved — try to locate by name pattern
      relocated = file_search("**/{artifact_filename}")
      IF relocated.length == 1:
        UPDATE artifact.path = relocated[0]
        LOG: "✅ Relocated '{artifact.name}' → {relocated[0]}"
      ELIF relocated.length == 0:
        MARK artifact.status = "REMOVED"
        LOG: "🗑️ '{artifact.name}' no longer exists. Marked REMOVED."
      ELSE:
        RDR: "Multiple candidates for '{artifact.name}'. Select correct path or mark REMOVED."
    
    IF issue.type == "DUPLICATE_ENTRY":
      RDR: "Duplicate entries for '{artifact.name}'. Merge or remove?"
    
    IF issue.type == "INCOMPLETE_ENTRY":
      # Attempt auto-fill from file analysis
      TRY infer_artifact_metadata(artifact)
  
  # Phase 3: Orphaned PLANNED cleanup
  cleanup_orphaned_planned(inventory)
  
  # Phase 4: Discover untracked artifacts
  # Scan source code for artifacts NOT in inventory
  stack = EXTRACT(constitution, "stack")
  source_patterns = GET_FRAMEWORK_PATTERNS(stack)  # Same patterns as brownfield bootstrap
  
  found_files = file_search(source_patterns)
  FOR EACH file IN found_files:
    artifact_meta = EXTRACT_ARTIFACT_METADATA(file)  # name, type, module from path + declarations
    existing = FIND_IN_INVENTORY(inventory, artifact_meta.name, artifact_meta.type, artifact_meta.module)
    
    IF NOT existing:
      RDR per untracked artifact:
        REGISTER: "Add to inventory as IMPLEMENTED."
        SKIP:     "Intentionally untracked (test helper, generated file, etc.)."
        DEFER:    "Decide later — add to review backlog."
  
  # Phase 5: Persist & Report
  inventory.last_updated = NOW()
  inventory.last_reconciled = NOW()
  SAVE("config/codebase_inventory.json", inventory)
  
  REPORT:
    - Relocated: N artifacts
    - Removed: N artifacts  
    - Orphaned: N PLANNED artifacts marked
    - Discovered: N new artifacts registered
    - Issues resolved: N / Issues remaining: N
```

### Auto-Reconciliation Triggers

```yaml
AUTO_RECONCILE_ADVISORY:
  # These agents emit an advisory (NOT a blocker) when drift is suspected:
  
  BLUEPRINT --start (Step -2):
    IF inventory.last_updated older than 30 days:
      ⚠️ ADVISORY: "Inventory may be stale (last updated {date}). Consider SETUP --reconcile-inventory."
  
  IMPLEMENT --build (DRY Gate):
    IF artifact.status == "PLANNED" AND file already exists at artifact.path:
      ⚠️ ADVISORY: "'{artifact.name}' is PLANNED but file exists. Inventory may be outdated."
      AUTO-FIX: Transition to IMPLEMENTED (no RDR needed — evidence is file existence)
  
  IMPLEMENT --build (Post-build):
    IF created files not matching any PLANNED artifact AND no design.md Section 0:
      ⚠️ ADVISORY: "New artifacts created without CIP tracking. Register manually or run SETUP --reconcile-inventory."

# NEVER auto-reconcile silently. Always log advisories in worklog.
```

---

## Drift Detection Gate (`scripts/check-inventory-drift.sh`)

The inventory's `path` fields can silently rot when files are deleted, renamed, or moved without updating the inventory entry. CIP Consultation does not catch this — it checks presence in inventory and cache freshness, not whether the inventory tells the truth about disk. The drift detector is a complementary gate that closes the asymmetry.

### What it detects

| Class | Definition | Action |
|-------|-----------|--------|
| `STALE` | Artifact has `status: IMPLEMENTED` but `path` does not exist on disk | Investigate: file deleted/moved → update or remove the inventory entry |
| `PROMOTE` | Artifact has `status: PLANNED` but `path` exists on disk | Promote to `IMPLEMENTED` (transition is mechanical when path matches) |
| `INVALID` | Entry missing required `path` or `status` fields | Repair or remove the entry |

### Invocation

```bash
# Human report; exit 1 on drift, 0 if clean
bash scripts/check-inventory-drift.sh

# JSON output for CI / orchestration; same exit codes
bash scripts/check-inventory-drift.sh --json

# Report drift but never fail (advisory mode for soft CI gates)
bash scripts/check-inventory-drift.sh --warn-only
```

Exit codes: `0` = no drift (or `--warn-only`), `1` = drift detected, `2` = tooling/file missing (no `python3`, etc.). When `config/codebase_inventory.json` is absent (CIP not bootstrapped — typical for greenfield projects pre-BLUEPRINT) the script exits 0 with an informational message.

### When to invoke

- **CI** — wired into `.github/workflows/governance-check.yml` as an advisory step (`--warn-only`). Drift surfaces as a workflow log line; does not block PR merge in advisory mode. Materialised projects whose CI must enforce drift can flip the flag in their workflow YAML.
- **`SETUP --reconcile-inventory`** — runs the drift check after Phase 5 (Persist & Report) to surface any residual drift the heuristic reconciliation missed.
- **Pre-merge audit (manual)** — invoke before approving a PR that touches `config/codebase_inventory.json` to verify the new entries are coherent.

The detector is intentionally narrow: it does NOT scan the filesystem for orphan code files outside the inventory (that would require stack-specific globs that the script cannot derive deterministically). Filesystem-side orphan detection is the job of `SETUP --reconcile-inventory` Phase 4 (heuristic-driven, agent-mediated).

### Propagation behaviour (`factory-sync.sh --preserve-local`)

`scripts/check-inventory-drift.sh` ships meta-direct via `factory-sync.sh` (base-scripts whitelist). Default propagation overwrites the materialised project's copy with the framework version. When `factory-sync.sh --preserve-local` is set, materialised projects with legitimate local modifications keep their version (the sync reports it under the `PRESERVED` counter). The same flag covers the other framework-shipped scripts (`generate-governance-snapshot.sh`, governance-on{prompt,edit,compact}, validate-governance, etc.) — single global flag, not per-script. Use it when a project needs to lock specific framework scripts to a non-canonical version while still receiving updates to everything else.

---

## Post-Summarization DRY Recovery (CIP Canary)

**Problem:** LLM summarization can destroy in-memory CIP consultation results. An agent that already ran `cip_consultation_gate()` at phase start may lose awareness of existing artifacts and silently create duplicates — the worst DRY violation.

**Vulnerability window:** Between `load_inventory_or_fallback()` (phase start) and the actual `CREATE_NEW` / `EXTEND` file write (possibly many sections later). If summarization occurs in this window, the agent acts as if no matches exist.

**Solution — CIP Canary:** Before ANY artifact creation decision is materialized (file created, code written), re-read a **filtered slice** of the inventory — only entries matching the proposed artifact's `type` + `module`. This costs ~50-150 tokens (1 JSON filter) vs. ~2-10KB for the full inventory.

> **Cost budget:** ~50-150 tokens + ~0.5s per creation decision. Only fires for CREATE_NEW/EXTEND, NOT for REUSE (which doesn't create files).

### CIP Canary Gate Function

```yaml
FUNCTION cip_canary_gate(proposed_artifact):
  # Runs IMMEDIATELY BEFORE any file creation for a new artifact.
  # This is NOT a replacement for cip_consultation_gate() — it's a SAFETY NET
  # that catches post-summarization DRY amnesia.

  inventory_path = "config/codebase_inventory.json"
  
  # Step 1: Re-read inventory (file-based, NOT from memory)
  IF NOT FILE_EXISTS(inventory_path):
    LOG: "CIP Canary: inventory missing — DRY degraded, proceed with caution"
    RETURN { action: "PROCEED_DEGRADED" }
  
  inventory = READ(inventory_path)
  
  # Step 2: Filter to relevant slice (minimal context load)
  relevant = FILTER(inventory.artifacts,
    a => a.type == proposed_artifact.type
      AND (a.module == proposed_artifact.module OR classify_artifact_reuse_category(a.type) == "SHARED")
      AND a.status != "ORPHANED"
      AND a.status != "REMOVED"
  )
  
  # Step 3: Quick match against filtered slice
  FOR EACH existing IN relevant:
    IF existing.name == proposed_artifact.name AND existing.type == proposed_artifact.type:
      ❌ CANARY BLOCK: "DRY VIOLATION — '{existing.name}' already exists at '{existing.path}'."
      LOG: "CIP Canary caught post-summarization duplicate: {proposed_artifact.name}"
      RETURN { action: "BLOCK_DUPLICATE", existing: existing }
    
    IF LEVENSHTEIN(existing.name, proposed_artifact.name) < 3 AND existing.type == proposed_artifact.type:
      ⚠️ CANARY WARN: "Near-duplicate: '{existing.name}' ↔ '{proposed_artifact.name}'"
      RETURN { action: "RDR_REQUIRED", existing: existing, match_type: "NAME_SIMILAR" }
    
    overlap = SEMANTIC_SIMILARITY(existing.responsibility, proposed_artifact.responsibility)
    IF overlap > 0.6:
      ⚠️ CANARY WARN: "Responsibility overlap ({overlap}): '{existing.name}'"
      RETURN { action: "RDR_REQUIRED", existing: existing, match_type: "NEAR_DUPLICATE" }
  
  # Step 4: No conflicts
  ✅ RETURN { action: "PROCEED" }
```

### Contract Canary Gate (BLUEPRINT-specific)

Contracts (`contracts/feature_map.md`) are NOT in `codebase_inventory.json` — they have their own registry. The same summarization gap applies: Step -1 (Endpoint Inventory Scan) loads all existing contracts, but summarization between Step -1 and Step 2a (contract creation) loses that awareness → duplicate SLUGs, conflicting endpoints.

```yaml
FUNCTION contract_canary_gate(proposed_slug, proposed_paths):
  # Runs BEFORE creating contract files (Step 2a) or updating feature_map.md (Step 2c).
  # Re-reads feature_map.md from disk — NOT from conversation memory.
  # Cost: ~100-300 tokens (feature_map.md is a small markdown table)

  feature_map_path = "contracts/feature_map.md"
  
  # Step 1: Re-read feature_map (file-based)
  IF NOT FILE_EXISTS(feature_map_path):
    LOG: "Contract Canary: feature_map.md missing — first contract, proceed"
    RETURN { action: "PROCEED" }
  
  feature_map = READ(feature_map_path)
  
  # Step 2: Check SLUG collision
  IF proposed_slug IN feature_map.slugs:
    existing_row = FIND_ROW(feature_map, slug == proposed_slug)
    ❌ CANARY BLOCK: "Contract SLUG '{proposed_slug}' already exists → Feature {existing_row.feature_id}"
    LOG: "Contract Canary caught duplicate SLUG after possible summarization"
    RETURN { action: "BLOCK_DUPLICATE", existing: existing_row }
  
  # Step 3: Check path collision (same contract file already exists)
  FOR EACH path IN proposed_paths:
    IF FILE_EXISTS(path):
      ⚠️ CANARY WARN: "Contract file already exists at '{path}'"
      RETURN { action: "RDR_REQUIRED", existing_path: path, match_type: "PATH_COLLISION" }
  
  # Step 4: Check endpoint/channel overlap with existing contracts
  # Quick scan: read only the paths/channels section of contracts in SAME domain
  domain = EXTRACT_DOMAIN(proposed_slug)  # e.g., "auth" from "auth-login"
  same_domain_contracts = FILTER(feature_map.rows, r => r.slug.startsWith(domain + "-"))
  
  IF same_domain_contracts.length > 0:
    ⚠️ CANARY ADVISORY: "{same_domain_contracts.length} contract(s) in domain '{domain}' — verify no endpoint overlap"
    # NOT a blocker — just ensures the architect is aware
  
  ✅ RETURN { action: "PROCEED" }
```

### When the CIP Canary Fires

```yaml
CIP_CANARY_TRIGGER_POINTS:
  # The canary fires DURING DESIGN to prevent rework, not at approval time.
  
  BLUEPRINT --start (Step -2, during artifact design):
    BEFORE writing each artifact entry to design.md Section 0:
      canary = cip_canary_gate(artifact)
      IF canary.action == "BLOCK_DUPLICATE": ❌ STOP — duplicate already exists, switch to REUSE
      IF canary.action == "RDR_REQUIRED": RDR → REUSE / EXTEND / CREATE_NEW (with justification)
      # This prevents designing artifacts that already exist → avoids full rework at --approve
  
  BLUEPRINT --start (Step 2a, during contract creation):
    BEFORE creating any contract file:
      canary = contract_canary_gate(CONTRACT_SLUG, [proposed_file_paths])
      IF canary.action == "BLOCK_DUPLICATE": ❌ STOP — SLUG already registered, REUSE or EXTEND existing
      IF canary.action == "RDR_REQUIRED": RDR → REUSE / EXTEND / CREATE_NEW
  
  IMPLEMENT --build:
    BEFORE creating any new source file:
      canary = cip_canary_gate({ name, type, module, responsibility })
      IF canary.action == "BLOCK_DUPLICATE": ❌ STOP — check design.md Section 0
      IF canary.action == "RDR_REQUIRED": Lightweight RDR → REUSE / EXTEND / CREATE_NEW
  
  CODESIGN --start:
    BEFORE persisting new domain concepts to user_journey.md:
      canary = cip_canary_gate({ name: concept_name, type: "domain_entity", module: inferred_module })
      IF canary.action != "PROCEED": RDR before persisting concept
  
  # DOES NOT fire for:
  # - REUSE decisions (no new file created)
  # - Inventory reads / queries
  # - DEVOPS / QA (no CIP interaction)
```

### Relationship to Existing Gates

```yaml
# The CIP Canary does NOT replace existing gates — it COMPLEMENTS them:
#
# ┌─────────────────────────┐     ┌──────────────────────────┐     ┌──────────────────┐
# │ cip_consultation_gate() │ ──→ │  Agent designs artifacts  │ ──→ │ cip_canary_gate()│
# │ (Phase start — full     │     │  (summarization may occur)│     │ (Before writing  │
# │  4-criteria matching)   │     │                           │     │  each artifact to │
# │  ~2-10KB loaded         │     │                           │     │  design.md/code)  │
# └─────────────────────────┘     └──────────────────────────┘     └──────────────────┘
#
# If NO summarization occurred → canary confirms what consultation already decided (fast pass)
# If summarization DID occur  → canary catches forgotten matches before rework happens
```

---

## Context Budget Guarantee

```yaml
CONTEXT BUDGET:
  - Registry read: 1 file, ~2-10KB
  - Bootstrap (brownfield): ~50-100 grep_search calls, <500 lines total
  - Reconciliation: ~20-50 file_search + grep_search calls
  - Per-feature lookup: O(1) — read JSON, filter by type/module
  - CIP Canary per creation decision: ~50-150 tokens (filtered inventory slice only)
  - Contract Canary per contract creation: ~100-300 tokens (feature_map.md read)
  - NO full workspace scans during BLUEPRINT or IMPLEMENT
```
