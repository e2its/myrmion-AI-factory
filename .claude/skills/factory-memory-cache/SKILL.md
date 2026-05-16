---
name: factory-memory-cache
description: "Factory Memory Cache Protocol (FMCP) — unified /memories/repo/ caching layer for cross-command performance optimization. Use when: any agent reads frequently-accessed data (feature state, BVL commands, CIP inventory, execution plan)."
applicable_when:
  always: true
---

# FACTORY MEMORY CACHE PROTOCOL (FMCP) — UNIFIED /memories/repo/ CACHING LAYER

> Naming note: `FMCP` refers to this internal Factory caching protocol.
> `MCP` without the `F` prefix refers to the external Model Context Protocol ecosystem.

> **Shared Protocol** — Referenced by: Factory, CODESIGN, BLUEPRINT, IMPLEMENT, DEVOPS, QA, BACKLOG agents.
> Defines a unified caching architecture using VS Code Copilot's `/memories/repo/` system to eliminate redundant file reads across agent commands.
> **Complements** the Governance Snapshot (`.context/governance_snapshot.md`) — does NOT replace it.
> **Write-through** — disk artifacts remain SSOT; memory caches are acceleration layers.

---

## WHY THIS PROTOCOL EXISTS

Agent commands in mi-AI-Factory repeatedly read the same files:
- **Smart Redirect** reads 9-15 artifact frontmatters after every command
- **BVL** derives test commands from stack config on every `--build`
- **CIP** parses the full `codebase_inventory.json` and runs 4-Criteria matching 3-5 times per build
- **Next-Task Resolver** reads the execution plan on every "what's next?" query

The `/memories/repo/` system provides repository-scoped, conversation-persistent storage that:
1. Is **listed in agent context** at conversation start (discoverability)
2. **Survives conversation boundaries** (unlike session memory)
3. **Scoped to the workspace** (no cross-repo contamination)
4. Accessible via the `memory` tool (read/write without file system calls)

---

## CACHE ARCHITECTURE

### Design Principles

1. **SSOT on Disk** — The authoritative source is ALWAYS the on-disk artifact. Memory caches are acceleration layers, never primary sources.
2. **Write-Through** — When an agent modifies a source artifact, it MUST update the corresponding cache immediately.
3. **Hash Validation** — Every cache entry stores a hash of its source. On read, validate hash; if stale → regenerate from source.
4. **Graceful Degradation** — If cache is missing, stale, or corrupted → fall back to direct file reads. NEVER block a command because of cache failure.
5. **Bounded Size** — Each cache file SHOULD be < 500 lines. Prefer compact tabular formats.

### Cache Registry

| Cache File | Source(s) | Updated By | Read By | Invalidation Trigger |
|-----------|-----------|------------|---------|---------------------|
| `/memories/repo/feature-state-cache.md` | `docs/spec/*/` frontmatters | Smart Redirect (post-command) | Smart Redirect, Factory, any agent | Any artifact status change |
| `/memories/repo/bvl-commands-cache.md` | `.context/governance_snapshot.md` § Verification Commands + project config files | BVL `resolve_verification_commands()` | IMPLEMENT `--build`, `--fix` | Stack config change, governance snapshot regeneration |
| `/memories/repo/codebase-inventory-cache.md` | `config/codebase_inventory.json` | CIP `cip_consultation_gate()`, IMPLEMENT `--build` (post-task registration) | BLUEPRINT, IMPLEMENT, CODESIGN | Any inventory modification |
| `/memories/repo/execution-plan-cache.md` | `docs/backlog/execution-plan.md` | BACKLOG `--plan-execution`, `--update-execution`, `--sync-execution` | Next-Task Resolver, Factory | Execution plan modification |

### Naming Convention

```
/memories/repo/{component}-cache.md
```

Examples:
- `/memories/repo/feature-state-cache.md`
- `/memories/repo/bvl-commands-cache.md`
- `/memories/repo/codebase-inventory-cache.md`
- `/memories/repo/execution-plan-cache.md`

---

## UNIVERSAL CACHE LIFECYCLE

Every cache follows this standardized lifecycle:

```yaml
# PHASE 1: READ (Fast Path)
FUNCTION cache_read(cache_path, source_hash_function):
  cache = MEMORY_READ(cache_path)
  
  IF cache IS NULL:
    LOG: "Cache miss: {cache_path} — not found"
    RETURN NULL  # Caller regenerates from source
  
  cached_hash = cache.frontmatter.source_hash
  current_hash = source_hash_function()
  
  IF cached_hash != current_hash:
    LOG: "Cache stale: {cache_path} — hash mismatch ({cached_hash} != {current_hash})"
    RETURN NULL  # Caller regenerates from source
  
  LOG: "Cache hit: {cache_path}"
  RETURN cache.content

# PHASE 2: WRITE (Write-Through)
FUNCTION cache_write(cache_path, content, source_hash):
  payload = FORMAT_CACHE(content, source_hash)
  
  # /memories/repo/ supports: create, delete, view
  # To update: delete + create (atomic replacement)
  MEMORY_DELETE(cache_path)  # Ignore if not exists
  MEMORY_CREATE(cache_path, payload)
  
  LOG: "Cache written: {cache_path} (hash: {source_hash})"

# PHASE 3: INVALIDATE
FUNCTION cache_invalidate(cache_path):
  MEMORY_DELETE(cache_path)
  LOG: "Cache invalidated: {cache_path}"

# PHASE 4: GRACEFUL DEGRADATION
# If any cache operation fails:
#   - Log warning
#   - Fall back to direct source file reads
#   - NEVER block the command
#   - NEVER retry more than once
```

### Standard Cache Format

```markdown
---
source_hash: "{MD5 or content hash of source file(s)}"
generated_at: "{ISO_8601}"
generated_by: "{AGENT} --{COMMAND}"
cache_version: "1.0"
---

# {Cache Name} (Auto-Generated — DO NOT EDIT)

> Regenerated automatically when source changes.
> Source: {path to authoritative file(s)}

## {Section 1}
{Compact data in table or YAML-under-heading format}

## {Section 2}
{...}
```

---

## CACHE TYPE 1: FEATURE STATE CACHE

**Purpose:** Cached artifact frontmatter statuses for all active features. Eliminates 9-15 file reads per Smart Redirect computation.

**Source:** Artifact frontmatters in `docs/spec/{FEATURE_ID}/`

**Cache Location:** `/memories/repo/feature-state-cache.md`

```yaml
FUNCTION write_feature_state_cache(feature_id, state):
  # Called by Smart Redirect AFTER computing feature state from disk
  existing = MEMORY_READ("/memories/repo/feature-state-cache.md")
  
  IF existing IS NOT NULL:
    # Update only the changed feature's entry
    updated = REPLACE_FEATURE_ENTRY(existing, feature_id, state)
  ELSE:
    updated = CREATE_NEW_CACHE(feature_id, state)
  
  # Since /memories/repo/ only supports create, use delete+create
  MEMORY_DELETE("/memories/repo/feature-state-cache.md")
  MEMORY_CREATE("/memories/repo/feature-state-cache.md", updated)

FUNCTION read_feature_state_cache(feature_id):
  cache = MEMORY_READ("/memories/repo/feature-state-cache.md")
  IF cache IS NULL: RETURN NULL
  
  entry = FIND_FEATURE_ENTRY(cache, feature_id)
  IF entry IS NULL: RETURN NULL
  
  # Validate: check if any artifact has been modified since cache time
  # Quick check: compare spec.feature mtime (most frequently changed)
  spec_path = "docs/spec/{feature_id}/spec.feature"
  IF FILE_EXISTS(spec_path):
    spec_iteration = READ_FRONTMATTER(spec_path, "iteration")
    IF spec_iteration != entry.spec_iteration:
      RETURN NULL  # Stale — spec changed since cache
  
  RETURN entry
```

**Cache Format:**

```markdown
---
source_hash: "composite"
generated_at: "2026-03-25T10:00:00Z"
generated_by: "Factory Smart Redirect"
cache_version: "1.0"
features_count: 3
---

# Feature State Cache (Auto-Generated — DO NOT EDIT)

> Source: docs/spec/*/frontmatter

## USR-001
spec_feature: APPROVED (iteration: 2, slicing_strategy: incremental)
mock_html: APPROVED
user_journey: APPROVED
design_md: APPROVED (based_on: 2)
test_plan: APPROVED (based_on: 2)
increment_plan: APPROVED (3 increments, 3 MERGED)
dev_plan: IMPLEMENTED_AND_VERIFIED
increments: [INC-1=MERGED, INC-2=MERGED, INC-3=MERGED]
devops_plan: APPROVED (envs: dev=active, staging=active)
qa_report: APPROVED
pr_state: MERGED
next_action: DEVOPS --deploy USR-001 --env prod

## USR-002
spec_feature: APPROVED (iteration: 1, slicing_strategy: incremental)
mock_html: APPROVED
user_journey: APPROVED
design_md: DRAFT (based_on: 1)
test_plan: NULL
increment_plan: NULL
dev_plan: NULL
increments: []
devops_plan: NULL
qa_report: NULL
pr_state: NULL
next_action: BLUEPRINT --start USR-002
```

---

## CACHE TYPE 2: BVL COMMANDS CACHE

**Purpose:** Cached verification commands (test_single, lint, typecheck, build) derived from stack config. Eliminates framework detection file searches on every `--build`.

**Source:** `.context/governance_snapshot.md` § Verification Commands + project config files

**Cache Location:** `/memories/repo/bvl-commands-cache.md`

```yaml
FUNCTION write_bvl_commands_cache(commands, snapshot_hash):
  payload = """
---
source_hash: "{snapshot_hash}"
generated_at: "{ISO_8601}"
generated_by: "IMPLEMENT --build (BVL)"
cache_version: "1.0"
---

# BVL Commands Cache (Auto-Generated — DO NOT EDIT)

> Source: .context/governance_snapshot.md § Verification Commands + config file detection

## Verification Commands
test_single: {commands.test_single}
test_suite: {commands.test_suite}
lint: {commands.lint}
typecheck: {commands.typecheck}
build: {commands.build}
frontend_test: {commands.frontend_test OR "NULL"}

## Detection Metadata
backend_runtime: {commands.backend_runtime}
testing_framework: {commands.testing_framework}
frontend_framework: {commands.frontend_framework OR "None"}
"""
  MEMORY_DELETE("/memories/repo/bvl-commands-cache.md")
  MEMORY_CREATE("/memories/repo/bvl-commands-cache.md", payload)

FUNCTION read_bvl_commands_cache():
  cache = MEMORY_READ("/memories/repo/bvl-commands-cache.md")
  IF cache IS NULL: RETURN NULL
  
  # Validate against current governance snapshot hash
  snapshot_hash = MD5(READ(".context/governance_snapshot.md"))
  IF cache.frontmatter.source_hash != snapshot_hash:
    RETURN NULL  # Stale — governance changed
  
  RETURN PARSE_COMMANDS(cache)
```

---

## CACHE TYPE 3: CODEBASE INVENTORY CACHE

**Purpose:** Cached compact index of `config/codebase_inventory.json` with pre-computed domain groupings. Eliminates full JSON parse + 4-Criteria matching on repeated CIP consultations.

**Source:** `config/codebase_inventory.json`

**Cache Location:** `/memories/repo/codebase-inventory-cache.md`

```yaml
FUNCTION write_inventory_cache(inventory, inventory_hash):
  # Build compact index: name → type → module → path (one line per artifact)
  index_lines = []
  FOR EACH artifact IN inventory.artifacts:
    index_lines.append("| {artifact.name} | {artifact.type} | {artifact.module} | {artifact.path} | {artifact.status} |")
  
  # Build domain groups for fast same-domain lookups
  domain_groups = GROUP_BY(inventory.artifacts, "module")
  
  payload = FORMAT_WITH_FRONTMATTER(inventory_hash, index_lines, domain_groups)
  MEMORY_DELETE("/memories/repo/codebase-inventory-cache.md")
  MEMORY_CREATE("/memories/repo/codebase-inventory-cache.md", payload)

FUNCTION read_inventory_cache():
  cache = MEMORY_READ("/memories/repo/codebase-inventory-cache.md")
  IF cache IS NULL: RETURN NULL
  
  inventory_hash = MD5(READ("config/codebase_inventory.json"))
  IF cache.frontmatter.source_hash != inventory_hash:
    RETURN NULL  # Stale
  
  RETURN cache  # Caller uses compact index for fast lookups
```

**Cache Format:**

```markdown
---
source_hash: "{MD5 of codebase_inventory.json}"
generated_at: "2026-03-25T10:00:00Z"
generated_by: "IMPLEMENT --build (CIP)"
cache_version: "1.0"
total_artifacts: 12
---

# Codebase Inventory Cache (Auto-Generated — DO NOT EDIT)

> Source: config/codebase_inventory.json

## Artifact Index
| Name | Type | Module | Path | Status |
|------|------|--------|------|--------|
| UserService | service | auth | src/modules/auth/services/user.service.ts | IMPLEMENTED |
| AuthController | controller | auth | src/modules/auth/controllers/auth.controller.ts | IMPLEMENTED |
| OrderService | service | orders | src/modules/orders/services/order.service.ts | PLANNED |

## Domain Groups
### auth
- UserService (service) — src/modules/auth/services/user.service.ts
- AuthController (controller) — src/modules/auth/controllers/auth.controller.ts

### orders
- OrderService (service) — src/modules/orders/services/order.service.ts
```

---

## CACHE TYPE 4: EXECUTION PLAN CACHE

**Purpose:** Already implemented. See `Factory-backlog-execution-plan.instructions.md` § Memory Cache Protocol.

**Cache Location:** `/memories/repo/execution-plan-cache.md`

**Reference:** The execution plan cache follows the same FMCP architecture defined here. It was the first implementation of this pattern and serves as the template.

---

## INTEGRATION POINTS

### Per-Agent Integration

| Agent | Command | Cache Read | Cache Write | Fallback |
|-------|---------|------------|-------------|----------|
| **Factory** | Every routing | Feature State | — | Full artifact scan |
| **Smart Redirect** | Post-command | Feature State | Feature State | Full artifact scan |
| **IMPLEMENT** | `--build` | BVL Commands, CIP Inventory | BVL Commands, CIP Inventory | derive_commands_from_stack(), full JSON parse |
| **IMPLEMENT** | `--fix` | BVL Commands | — | derive_commands_from_stack() |
| **BLUEPRINT** | `--start`, `--refine` | CIP Inventory | CIP Inventory | Full JSON parse |
| **CODESIGN** | `--start` | CIP Inventory | — | Full JSON parse |
| **BACKLOG** | `--plan-execution` | — | Execution Plan | — |
| **BACKLOG** | Next-Task query | Execution Plan | — | Full plan read |

### When to Invalidate

| Event | Caches to Invalidate |
|-------|---------------------|
| Artifact status change (any agent modifies frontmatter) | Feature State |
| `SETUP --generate` or `SETUP --upgrade` (governance changes) | BVL Commands |
| Governance snapshot regenerated | BVL Commands |
| `config/codebase_inventory.json` modified | CIP Inventory |
| `IMPLEMENT --build` registers new artifact | CIP Inventory |
| `BACKLOG --plan-execution` | Execution Plan |
| `BACKLOG --update-execution` | Execution Plan |
| `CODESIGN --refine` (iteration bump) | Feature State |

### Relationship to Governance Snapshot

The **Governance Snapshot** (`.context/governance_snapshot.md`) remains the PRIMARY mechanism for governance context recovery. It is:
- **In-repo** (trackable, inspectable by humans, survives git operations)
- **Dual-hash validated** (constitution + setup)
- **The foundation** for BVL Commands Cache (snapshot hash is the BVL cache's validation key)

The FMCP caches in `/memories/repo/` are **complementary acceleration layers**:
- They cache DERIVED or COMPUTED data (artifact states, resolved commands, domain groupings)
- They do NOT cache governance rules themselves (the snapshot handles that)
- They reduce I/O for frequently-accessed, rarely-changed data

---

## GUARDRAILS

1. **Never block on cache failure** — If memory tool fails, fall back to direct reads.
2. **Never trust cache without validation** — Always check source hash before using cached data.
3. **Never cache secrets or sensitive data** — `/memories/repo/` is workspace-scoped but readable. No tokens, credentials, or PII.
4. **Bound cache size** — Each cache < 500 lines. If a project has 50+ features, the feature state cache uses compact format (one line per artifact, not per field).
5. **No cascading cache dependencies** — Caches read from sources, NEVER from other caches. This prevents stale-chain propagation.
