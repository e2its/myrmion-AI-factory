# Upgrade Safety Protocol v3.0.0

> **Notation convention.** This file describes an algorithm using pseudo-code and log format strings. Tokens like `{{target_path}}`, `{{feature_id}}`, `{{template_path}}`, `{{error}}` appearing in lowercase inside `LOG:` statements or pseudo-code blocks are **runtime interpolation variables** — they are filled in by the agent at log-write time with the value from its current execution context. They are NOT `SETUP --generate` materialization placeholders and they do NOT need a producer in `Factory-setup-discovery.instructions.md` or `Factory-setup-materialization.instructions.md`. The repo-wide `{{SCREAMING_SNAKE}}` convention applies ONLY to top-level materialization placeholders (e.g. `{{PROJECT_NAME}}`, `{{BACKEND_RUNTIME}}`). Loop iteration variables in Handlebars-style `{{#each ...}}` blocks and log/pseudo-code locals are correctly lowercase.

## 1. Core Principles

- **Zero-TODO Policy:** Every placeholder, decision, and value MUST be resolved inline during upgrade. No TODOs, no FIXMEs, no "TBD" markers left in output files. If a value cannot be discovered or decided, the upgrade for that file BLOCKS until resolved.
- **Smart Discovery First:** When a new placeholder `{{VAR}}` is found, the agent MUST exhaust ALL existing documentation sources before asking the user. Never invent, assume, or generate default values.
- **RDR Protocol for Unknowns:** When Smart Discovery fails, use Recommendation → Decision → Registration (one question at a time, with justified recommendation and alternatives).
- **Pre-Flight Validation:** Extensive checks BEFORE any upgrade executes
- **Atomic Operations:** All-or-nothing per file to prevent partial upgrades
- **Rollback Tracking:** Track all file states to enable safe rollbacks
- **ADR Respect:** Architecture decisions documented in ADRs protect files from blind overwrites
- **On-Demand Sync Only:** Synchronization happens ONLY when `/SETUP --upgrade` is explicitly invoked. No continuous sync, no pre-commit hooks for metadata.

---

## 2. Pre-Upgrade Inventory Audit Protocol

**Executed by `/SETUP --upgrade` BEFORE any modification starts.**

### Phase 1: Registry Integrity Check

```yaml
Validate: docs/project_log/governance_versions.json EXISTS
  IF NOT: Construct legacy snapshot + rebuild registry

Validate: .context/templates/setup/governance_versions.json EXISTS
  IF NOT: 🛑 BLOCK "🛑 Framework manifest missing. git pull to update mi-AI-Factory."
  STOP

Load: Both manifests
Parse: template registry with checksums
```

### Phase 2: Phantom File Detection

Detect files in `.claude/rules/` that are NOT in the framework manifest:

```yaml
FOR EACH file IN .claude/rules/:
  IF file NOT IN governance_versions.json.templates:
    ⚠️ WARN: "Phantom file detected: {{file}}"
    
    ACTION: Check git history
      git log --oneline -- .claude/rules/{{file}} | head -5
    
    IF file created by user (NOT in template ancestry):
      PROMPT: "Keep custom file? (Y/N)"
      IF Y: Mark in upgrade_plan.custom_files
      IF N: Mark for cleanup
    
    IF file was in old template version:
      PROMPT: "File removed in upgrade. Keep backup? (Y/N)"
      IF Y: File → .claude/rules/DEPRECATED/{{file}}
      IF N: Schedule deletion
```

### Phase 3: Template Checksum Validation

Detect if framework templates were modified externally (not via upgrade):

```yaml
FOR EACH template_entry IN governance_versions.json.templates:
  template_path = .context/templates/setup/ + template_entry.key
  registered_checksum = template_entry.registered_checksum  # NEW FIELD
  
  IF file EXISTS:
    current_checksum = MD5(template_path)
    
    IF current_checksum != registered_checksum:
      🚨 CRITICAL: "Template externally modified (drift detected)"
      
      # Log the modification
      LOG: "[TS] | Materialization | SETUP | Detect template drift {{template_path}} | BLOCKED | {{feature_id}} | Checksum mismatch: {{registered}} → {{current}}"
      
      PROMPT:
        """
        🚨 **TEMPLATE DRIFT DETECTED:** {{template_path}}
        
        Expected checksum: {{registered_checksum}}
        Current checksum: {{current_checksum}}
        
        This template was modified outside the upgrade process.
        
        Options:
        1. RESTORE — Restore from git (git checkout -- {{template_path}})
        2. REREGISTER — Accept changes, update checksum
        3. ABORT — Stop upgrade, investigate manually
        """
      
      IF RESTORE:
        Execute: git checkout -- {{template_path}}
        Update: governance_versions.json[template].registered_checksum = MD5(restored)
        LOG: "[TS] | Materialization | SETUP | Restore template {{template_path}} | COMPLETED | {{feature_id}} | Recovered from git"
      
      IF REREGISTER:
        Update: governance_versions.json[template].registered_checksum = current_checksum
        PROMPT: "Update version? Current: {{version}}, Proposed: {{version}}-MODIFIED"
        IF Y: Bump version automatically
      
      IF ABORT:
        STOP: 🛑 Upgrade blocked pending manual resolution
```

### Phase 4: Target File State Inventory

Verify that all target files exist and haven't been orphaned:

```yaml
FOR EACH file_entry IN project_snapshot.files:
  target_path = file_entry.target
  expected_version = file_entry.template_version
  
  IF file NOT EXISTS:
    IF file_entry.status != "NOT_FOUND":
      ⚠️ WARN: "Target file missing: {{target_path}}"
      ACTION: Check git status
        git status -- {{target_path}}
      
      PROMPT: "File was generated but is now missing. Options:
        1. REGENERATE — Create from template
        2. SKIP — Mark as deleted, don't regenerate
        3. INVESTIGATE — Abort, check manually"
      
      IF REGENERATE:
        Mark in upgrade_plan for regeneration
        LOG: "[TS] | Materialization | SETUP | Regenerate missing {{target_path}} | QUEUED | {{feature_id}} | File recreated"
  
  ELSE:
    current_checksum = MD5(target_path)
    registered_checksum = file_entry.materialized_checksum
    
    IF current_checksum != registered_checksum:
      ℹ️ NOTE: "{{target_path}} was customized since last upgrade"
      # Will trigger customization handling in actual upgrade
    ELSE:
      ✅ File matches registered version (not customized)
```

### Phase 5: Dependency Graph Check

Verify that dependent rules aren't broken:

```yaml
FOR EACH file_entry IN project_snapshot.files:
  target_path = file_entry.target
  
  # Check for broken references within rule files
  IF target_path contains "rules/":
    content = READ(target_path)
    
    # Scan for references to other rules
    referenced_rules = GREP(content, /\[.*\]\(.*\.md\)|«.*»|Rule: .*/)
    
    FOR EACH ref IN referenced_rules:
      referenced_file = EXTRACT_PATH(ref)
      
      IF referenced_file NOT IN project_snapshot.files:
        🟡 WARN: "Broken reference in {{target_path}}"
        ACTION: Schedule for manual review
        LOG: "[TS] | Materialization | SETUP | Detect broken reference {{target_path}} | WARNING | {{feature_id}} | Ref: {{referenced_file}} not found"
```

### Phase 6: ADR Customization Protection Check (CRITICAL - NEW v2.0.0)

**Purpose:** Respect architecture decisions documented in ADRs. Prevent blind overwrites of customized files.

```yaml
Step 6.1: Load all ADRs from project
  adr_directory = "docs/project_log/adr/"
  
  IF directory NOT EXISTS OR no ADR-*.md files found:
    ℹ️ LOG: "No ADRs found - skipping customization protections"
    SKIP to Phase 7

Step 6.2: Parse ADRs for governance file references
  protected_files = {}  # { file_path: [adr_references] }
  
  FOR EACH adr_file IN docs/project_log/adr/ADR-*.md:
    adr_title = READ header
    adr_content = READ full content
    
    # Find references to .claude/rules/ files
    referenced_files = GREP(adr_content, ".claude/rules/[a-z-]+\.instructions\.md")
    
    # Check if ADR documents a CUSTOMIZATION
    IF adr_content CONTAINS:
      "customize", "custom requirement", "compliance", "regulatory",
      "specific to {{project}}", "do not update", "override", "modifications"
    THEN:
      FOR EACH ref_file IN referenced_files:
        protected_files[ref_file] = {
          adr: adr_file,
          title: adr_title,
          reason: EXTRACT_KEY_JUSTIFICATION(adr_content)
        }
        
        LOG: "[TS] | Materialization | SETUP | Protected by ADR {{adr_file}} | NOTED | {{feature_id}} | {{ref_file}} customized per {{adr_title}}"

Step 6.3: Display protected files to user
  IF protected_files.length > 0:
    DISPLAY:
        """
        🛡️  FILES PROTECTED BY ADR
        
        The following files are customized based on architectural decisions:
        
        {{FOR EACH file, refs IN protected_files:}}
          - {{file}}
            {{FOR EACH ref IN refs:}}
             ← {{ref.adr}}: {{ref.title}}
            {{END FOR}}
        {{END FOR}}
        """

Step 6.4: User decides on ADR-protected files
  PROMPT:
    """
    Upgrade strategy for ADR-protected files:
    
      a) SKIP - No actualizar archivos protegidos (mantener customizaciones)
      b) SMART_MERGE - Actualizar estructura, preservar customizaciones
      c) OVERRIDE - Actualizar todo (⚠️  sobrescribir decisiones ADR)
    
    Your choice? (a-c)
    """
  
  IF choice == a:
    protected_skip = protected_files.keys()
    LOG: "Protected files will be SKIPPED in upgrade"
  
  IF choice == b:
    protected_merge_strategy = "smart_merge"
    LOG: "Protected files will use 3-way merge (preserve customizations)"
  
  IF choice == c:
    CONFIRM: "Type 'ENTENDIDO' to confirm overwrite of {{protected_files.length}} ADR decisions"
    IF confirmed:
      protected_override = true
      LOG: "User confirmed ADR override - proceeding with full replacement"
    ELSE:
      RETURN to Step 6.4 (re-ask)
```

---

## 3. Smart Placeholder Discovery & RDR Resolution Protocol

**Applies to:** ALL governance files during `/SETUP --upgrade` — both existing file upgrades (Smart Additive Merge) and new file handling.

**CRITICAL:** This protocol replaces the old "mini-discovery" approach. No TODOs, no defaults invented by the agent, no assumptions.

### 3.1 Smart Discovery Cascade (MANDATORY before asking user)

When a new placeholder `{{PLACEHOLDER_NAME}}` is found in an upgraded template:

```yaml
Step 1: NORMALIZE placeholder name
  # Convert to searchable variants
  # {{BACKEND_RUNTIME}} → "backend_runtime", "backend.runtime", "Backend Runtime"
  search_keys = GENERATE_SEARCH_VARIANTS(placeholder_name)

Step 2: SEARCH docs/setup.md (PRIMARY SOURCE)
  FOR EACH key IN search_keys:
    value = SEARCH_FRONTMATTER(docs/setup.md, key)
    IF value != NULL:
      RETURN { source: "setup.md", value: value, confidence: "HIGH" }
    
    value = SEARCH_BODY(docs/setup.md, key)
    IF value != NULL:
      RETURN { source: "setup.md (body)", value: value, confidence: "MEDIUM" }

Step 3: SEARCH docs/constitution.md (SECONDARY SOURCE)
  FOR EACH key IN search_keys:
    value = SEARCH_YAML_SECTIONS(docs/constitution.md, key)
    IF value != NULL:
      RETURN { source: "constitution.md", value: value, confidence: "HIGH" }
    
    value = SEARCH_BODY(docs/constitution.md, key)
    IF value != NULL:
      RETURN { source: "constitution.md (body)", value: value, confidence: "MEDIUM" }

Step 4: SEARCH ADRs (TERTIARY SOURCE)
  FOR EACH adr IN docs/project_log/adr/ADR-*.md:
    value = SEARCH_CONTENT(adr, search_keys)
    IF value != NULL:
      RETURN { source: adr, value: value, confidence: "MEDIUM" }

Step 5: SEARCH existing materialized rules (QUATERNARY SOURCE)
  FOR EACH rule IN .claude/rules/*.instructions.md:
    value = SEARCH_CONTENT(rule, search_keys)
    IF value != NULL:
      RETURN { source: rule, value: value, confidence: "LOW" }

Step 6: SEARCH project config files (LAST RESORT)
  config_files = ["package.json", "pyproject.toml", "Cargo.toml", "pom.xml",
                  "tsconfig.json", "docker-compose.yml", ".env.example"]
  FOR EACH config IN config_files:
    IF EXISTS(config):
      value = SEARCH_CONFIG(config, search_keys)
      IF value != NULL:
        RETURN { source: config, value: value, confidence: "LOW" }

Step 7: DISCOVERY FAILED
  RETURN { source: NULL, value: NULL, confidence: "NONE" }
  → TRIGGER RDR Protocol (Section 3.2)
```

### 3.2 RDR Protocol (Recommendation → Decision → Registration)

**Triggered ONLY when Smart Discovery finds NO value for a placeholder.**

**RULES:**
- ONE question at a time (never batch multiple placeholders)
- ALWAYS provide a justified recommendation with alternatives
- NEVER invent values or use generic defaults like "TODO", "TBD", "CHANGE_ME"
- NEVER skip — the upgrade BLOCKS until every placeholder is resolved

```yaml
FOR EACH unresolved_placeholder:

  # ═══ RECOMMENDATION ═══
  # Agent analyzes the template context to formulate a recommendation
  
  template_context = EXTRACT_SURROUNDING_CONTEXT(placeholder, template_content)
  # Read 10-20 lines around the placeholder to understand its purpose
  
  recommendation = ANALYZE_CONTEXT_FOR_RECOMMENDATION({
    placeholder_name: placeholder,
    template_file: template_path,
    surrounding_context: template_context,
    project_stack: READ(docs/setup.md, "stack"),
    project_type: READ(docs/setup.md, "project_type")
  })
  
  DISPLAY:
  """
  🔍 **NUEVO CAMPO REQUERIDO:** `{{placeholder}}`
  
  📄 **Archivo:** {{target_path}} (v{{new_version}})
  📋 **Contexto:** {{template_context_summary}}
  
  💡 **Recommendation:** {{recommendation.value}}
     **Justification:** {{recommendation.reason}}
  
  🔀 **Alternatives:**
  {{FOR idx, alt IN recommendation.alternatives:}}
     {{idx+1}}. {{alt.value}} — {{alt.reason}}
  {{END}}
  
  What value to use?
    R) Accept recommendation: "{{recommendation.value}}"
  {{FOR idx, alt IN recommendation.alternatives:}}
    {{idx+1}}) {{alt.value}}
  {{END}}
    C) Enter custom value
  """
  
  WAIT_FOR_USER_INPUT(choice)
  
  # ═══ DECISION ═══
  IF choice == "R":
    decided_value = recommendation.value
  ELIF choice IN [1, 2, ...]:
    decided_value = recommendation.alternatives[choice - 1].value
  ELIF choice == "C":
    PROMPT: "Ingresa el valor para `{{placeholder}}`:"
    decided_value = USER_INPUT
  
  # ═══ REGISTRATION ═══
  # MANDATORY: Persist decision so it's never asked again
  
  # 1. Save to docs/setup.md (canonical source)
  APPEND_TO_SETUP_MD(placeholder, decided_value, section="upgrade_discoveries")
  
  # 2. Log the decision
  LOG: "[TS] | Materialization | SETUP | RDR: {{placeholder}} = {{decided_value}} | COMPLETED | {{feature_id}} | Source: user decision via RDR"
  
  # 3. Return resolved value
  RETURN { value: decided_value, source: "RDR", registered: true }
```

### 3.3 Semantic Coherence Check (POST-MERGE, PRE-CONFIRMATION)

**After building merged content but BEFORE showing diff to user, detect contradictions between new additions and existing content.**

**Why this matters:** Smart Additive Merge is *structurally* safe (never overwrites, never deletes) but NOT *semantically* safe. Adding new content that contradicts existing content produces incoherent governance files.

**Categories of Incoherence Detected:**

| Category | File Type | Example | Severity |
|----------|-----------|---------|----------|
| OPPOSING_LIST_CONFLICT | JSON | Same package in `prohibited` AND `exceptions` | HIGH |
| NUMERIC_BOUND_CONFLICT | JSON | `min_connections: 150` but `max_connections: 100` | HIGH |
| TOOL_CONFLICT | Markdown | Existing uses Prometheus, new recommends Datadog for same domain | MEDIUM |
| NUMERIC_CONFLICT | Markdown | Existing says "minimum 8 chars", new says "minimum 12 chars" | HIGH |
| POLICY_CONTRADICTION | Markdown | Existing: "MUST use sessions", new: "MUST NOT use sessions" | CRITICAL |

**Resolution Protocol (per issue):**
- **H (HARMONIZE):** User provides unified value/text replacing both conflicting elements
- **E (KEEP EXISTING):** Don't add the conflicting new content
- **N (KEEP NEW):** Replace existing with new (⚠️ breaks additive-only for this conflict — logged as exception)
- **B (KEEP BOTH):** Accept contradiction with inline warning comment (user harmonizes later)

**Severity Handling:**
- **CRITICAL/HIGH:** Must resolve individually before proceeding
- **MEDIUM:** Can batch-accept with warnings, or resolve individually

**Implementation:** See `SETUP.AGENT.md` Section 4.4.2, Step 5a.

---

### 3.4 Zero-TODO Enforcement (POST-TEMPLATE-APPLICATION)

**After applying ALL placeholders to a template, validate NO residual markers remain:**

```yaml
Step 1: Scan output content for unresolved markers
  patterns_to_detect = [
    /\{\{[A-Z_]+\}\}/,      # {{PLACEHOLDER}}
    /TODO[:\s]/i,            # TODO: something
    /FIXME[:\s]/i,           # FIXME: something  
    /TBD/,                   # TBD
    /CHANGE_ME/,             # CHANGE_ME
    /XXX/,                   # XXX
    /___+/,                  # _____ (blank to fill)
    /\[PENDIENTE\]/i,       # [PENDIENTE]
    /\[REPLACE\]/i          # [REPLACE]
  ]
  
  violations = []
  FOR EACH pattern IN patterns_to_detect:
    matches = GREP(output_content, pattern)
    IF matches.length > 0:
      violations.push({ pattern: pattern, matches: matches })

Step 2: If violations found, BLOCK and resolve
  IF violations.length > 0:
    ❌ BLOCK: "Output file contains {{violations.length}} unresolved marker(s)"
    
    FOR EACH violation IN violations:
      DISPLAY: "  ❌ Line {{violation.line}}: {{violation.match}}"
    
    # Force resolution via RDR for each violation
    FOR EACH violation IN violations:
      TRIGGER: RDR Protocol (Section 3.2) for each unresolved marker
    
    # Re-scan after resolution
    GOTO Step 1
  
  ELSE:
    ✅ "Output clean: no unresolved markers"
```

---

## 4. Atomic Upgrade Operations Protocol

**Ensures EACH file upgrade is all-or-nothing**

### Centralized Backup (MANDATORY — Before any file modification)

**Ref: ADR-0001 Decision D5**

```yaml
# This runs ONCE before all per-file transactions.
# Provides the single source of truth for --rollback-upgrade.

TIMESTAMP = NOW_ISO8601()
BACKUP_DIR = "docs/project_log/.governance_upgrades/upgrade_{{TIMESTAMP}}"

mkdir -p {{BACKUP_DIR}}/files

# Copy ALL files that will be modified
FOR EACH file_to_upgrade IN upgrade_plan.upgrades + upgrade_plan.new_files:
  IF file_exists(file_to_upgrade.target):
    mkdir -p {{BACKUP_DIR}}/files/$(dirname {{file_to_upgrade.target}})
    COPY: {{file_to_upgrade.target}} → {{BACKUP_DIR}}/files/{{file_to_upgrade.target}}

# Snapshot governance metadata
COPY: docs/project_log/governance_versions.json → {{BACKUP_DIR}}/governance_versions.json.bak

# Generate manifest
WRITE: {{BACKUP_DIR}}/BACKUP_MANIFEST.json with:
  {
    "timestamp": "{{TIMESTAMP}}",
    "framework_version": { "from": "{{current}}", "to": "{{target}}" },
    "status": "IN_PROGRESS",
    "file_count": N,
    "files": [ { "path", "from_version", "to_version", "checksum_at_backup", "content_type", "strategy" } ]
  }

# After ALL upgrades succeed → update manifest.status = "COMPLETED"
# If upgrade fails → manifest.status remains "IN_PROGRESS" (signals rollback eligibility)
```

### Per-File Transaction Pattern

```yaml
FOR EACH file_to_upgrade IN upgrade_plan.upgrades:
  
  # Phase 1: Create temp working directory (NOT the backup — that's centralized above)
  temp_dir = /tmp/upgrade_{{TIMESTAMP}}_{{file_hash}}/
  mkdir -p {{temp_dir}}
  
  # NOTE: Backup already exists in {{BACKUP_DIR}}/files/ — no per-file backup needed
  
  Checkpoint A: Generate new version
    content_new = RENDER_TEMPLATE({{template}}, {{values}})
    WRITE: {{temp_dir}}/new.version
  
  Checkpoint B: Validation
    - WCAG check (if CSS/HTML rules file)
    - JSON validation (if JSON)
    - Markdown lint (if Markdown)
    - Syntax check with language-specific linter
    
    IF validation fails:
      ❌ ROLLBACK: Delete {{temp_dir}}, abort this file
      LOG: "[TS] | Materialization | SETUP | Validation failed {{target_path}} | FAILED | {{feature_id}} | {{error}}"
      CONTINUE to next file
  
  # Phase 2: User approval
  Show diff: current {{target_path}} → {{temp_dir}}/new.version
  PROMPT: "Apply upgrade? (Y/N/E[dit])"
  
  IF N:
    ❌ ROLLBACK: Delete {{temp_dir}}, skip this file
    CONTINUE
  
  IF E:
    Allows user to edit {{temp_dir}}/new.version
  
  # Phase 3: Atomic write
  IF Y:
    COPY: {{temp_dir}}/new.version → {{target_path}}.tmp
    
    Verify: {{target_path}}.tmp matches expected output
    Verify: {{target_path}}.tmp is not empty
    
    IF verification fails:
      ❌ ROLLBACK: Delete {{target_path}}.tmp, abort this file
      CONTINUE
    
    ATOMIC: mv {{target_path}}.tmp {{target_path}}
  
  # Phase 4: Update metadata
  project_snapshot.files[{{target_path}}] = {
    "template_source": {{template_key}},
    "template_version": {{new_version}},
    "content_type": {{content_type}},
    "materialized_checksum": MD5({{target_path}}),
    "materialized_at": NOW,
    "backup_location": "{{BACKUP_DIR}}/files/{{target_path}}",
    "user_customized": {{boolean}},
    "upgrade_strategy": {{strategy_used}},
    "validation_passed": true
  }
  
  # Phase 5: Cleanup
  rm -rf {{temp_dir}}
  
  LOG: "[TS] | Materialization | SETUP | Upgrade {{target_path}} | COMPLETED | {{feature_id}} | Atomic write successful"
```

---

## 5. Rollback Capability Protocol

**Enable safe recovery from failed upgrades**

### Rollback Command

```yaml
/SETUP --rollback-upgrade {{TIMESTAMP}}

Steps:
  1. Locate: docs/project_log/UPGRADE_REPORT_{{TIMESTAMP}}.md
  2. Read: backup locations from report
  3. FOR EACH backup:
       Verify: Backup file exists
       Restore: backup → original location
       Update: project_snapshot with pre-upgrade versions
  4. Revert: docs/project_log/governance_versions.json to pre-upgrade state
  5. Generate: ROLLBACK_REPORT_{{TIMESTAMP}}.md with details
```

### Post-Upgrade State Snapshot

```yaml
Save after EVERY upgrade: docs/project_log/UPGRADE_STATE_{{TIMESTAMP}}.json

Contains:
  - Before/after checksums for all modified files
  - Backup locations
  - User decisions log
  - Exact upgrade command parameters
  - Step-by-step operation log for debugging

Enables: /SETUP --analyze-upgrade {{TIMESTAMP}} for post-mortem
```

---

## 6. Enhanced Project Snapshot Structure

**New fields for governance_versions.json in projects**

```json
{
  "schema_version": "2.0.0",
  "framework_version": "5.0.0",
  "project_initialized": "2026-02-01",
  "last_upgraded": "2026-02-10",
  "last_successful_upgrade": "2026-02-10",
  "last_failed_upgrade": null,
  "setup_md_checksum": "abc123...",
  "constitution_md_checksum": "def456...",
  "files": {
    ".claude/rules/architecture.instructions.md": {
      "template_source": "rules/architecture.md",
      "template_version": "1.2.3",
      "content_type": "stack_configured",
      "registered_checksum": "SHA256_OF_TEMPLATE",
      "materialized_checksum": "SHA256_OF_CURRENT_FILE",
      "materialized_at": "2026-02-01T14:30:00Z",
      "user_customized": false,
      "user_customized_since": null,
      "backup_location": "docs/project_log/.governance_upgrades/upgrade_{{TIMESTAMP}}/files/...",
      "upgrade_history": [
        {
          "from_version": "1.0.0",
          "to_version": "1.2.3",
          "date": "2026-02-10",
          "strategy": "Smart Additive Merge",
          "status": "COMPLETED",
          "customization_detected": false
        }
      ],
      "validation_status": "PASSED",
      "validation_timestamp": "2026-02-10T15:00:00Z",
      "deprecation_notes": null
    }
  },
  "dependencies": {
    ".claude/rules/architecture.instructions.md": [
      ".claude/rules/api-standards.instructions.md",
      "docs/constitution.md"
    ]
  },
  "sync_status": "IN_SYNC",
  "last_audit": "2026-02-10T15:00:00Z"
}
```

---

## 7. Pre-Upgrade Checklist

**Interactive checklist executed before upgrade starts**

```yaml
Interactive Pre-Flight:

☐ Git repository clean?
  IF NOT: "⚠️  Uncommitted changes detected. Commit before upgrade (prevents merge conflicts)"
  PROMPT: Continue anyway? (Y/N)

☐ docs/setup.md unchanged?
  IF NOT: "⚠️  setup.md has drifted. Update governance_versions.json checksum?"

☐ All registered files exist?
  IF NOT: "⚠️  {{N}} registered files missing. Regenerate? (Auto-fix)"

☐ No phantom files?
  IF NOT: "⚠️  {{N}} unregistered files in .claude/rules/. Ignore or remove?"

☐ Templates have correct checksums?
  IF NOT: "🚨 Template drift detected. Run 'git restore' or 'reregister'?"

☐ Ready to upgrade?
  CONFIRM: "Upgrade will modify {{N}} files. Continue? (Y/N)"
```

---

## 8. Recovery Procedures

### Scenario: Upgrade Fails Mid-Process

```yaml
Detection: Error thrown while processing file N of M

Immediate Actions:
  1. HALT: Stop processing remaining files
  2. ROLLBACK: Restore partial file to checkpoint
  3. SAVE: State snapshot to docs/project_log/UPGRADE_FAILURE_{{TIMESTAMP}}.json
  4. NOTIFY: Show error detail + recovery options

Recovery Options:
  A. RESUME — Continue from next file (skip failed file)
  B. RETRY — Retry failed file alone
  C. ROLLBACK — Undo all changes from this upgrade
  D. ABORT — Stop and leave in indeterminate state (manual recovery needed)
```

### Scenario: Checksum Mismatch After Upgrade

```yaml
Detection: Post-upgrade validation finds file checksum != expected

Steps:
  1. Check git diff: Did other process modify file during upgrade?
  2. Compare: against latest template version
  3. Decision:
     - If match: Cache was stale, update snapshot
     - If diverge: Conflict detected, manual review needed
```

---

## 9. Validation Scripts

### Script: `validate-upgrade-integrity.sh` (Post-upgrade)

```bash
#!/bin/bash
# Validates upgrade consistency — run after /SETUP --upgrade

PROJECT_SNAPSHOT="docs/project_log/governance_versions.json"

if [ ! -f "$PROJECT_SNAPSHOT" ]; then
  echo "❌ Project snapshot missing"
  exit 1
fi

# Verify all registered files exist
jq -r '.files | keys[]' "$PROJECT_SNAPSHOT" | while read -r file; do
  if [ ! -f "$file" ]; then
    echo "❌ Registered file missing: $file"
    exit 1
  fi
done

# Verify no phantom files
find .claude/rules -type f | while read -r file; do
  file_key=$(echo "$file" | sed 's|docs/||')
  if ! jq -e ".files | has(\"$file_key\")" "$PROJECT_SNAPSHOT" > /dev/null; then
    echo "⚠️  Phantom file detected: $file"
  fi
done

# Zero-TODO check: no unresolved markers in output files
echo "Checking for unresolved markers..."
find .claude/rules -name '*.md' -exec grep -Hn -E '\{\{[A-Z_]+\}\}|TODO:|FIXME:|TBD|CHANGE_ME|\[PENDIENTE\]' {} \;
if [ $? -eq 0 ]; then
  echo "❌ Unresolved markers found in governance files"
  exit 1
fi

echo "✅ Upgrade integrity check passed (zero unresolved markers)"
exit 0
```

---

## 10. Configuration Reference

### Enable Pre-Flight Checks

Add to `docs/constitution.md`:

```yaml
upgrade_settings:
  enforce_dual_write: true
  pre_flight_checks: true
  atomic_operations: true
  auto_rollback_on_error: true
  backup_retention_days: 30
  checksum_validation: strict
  conflict_resolution: manual  # or "auto_accept_framework"
```

---

## Glossary

| Term | Definition |
|------|-----------|
| **Dual-Write** | Template and metadata updated together atomically |
| **Phantom File** | File in .claude/rules/ not registered in governance_versions.json |
| **Template Drift** | Checksum mismatch in .context/templates/setup/ (external modification) |
| **Checkpoint** | Saved state at transaction boundary |
| **Smart Additive Merge** | Unified upgrade strategy for ALL files: structural diff → add new content → preserve existing → resolve placeholders |
| **Content Type: universal** | No placeholders. New sections/keys merged additively |
| **Content Type: stack_configured** | Contains {{PLACEHOLDER}} tokens. Additions resolved via Smart Discovery + RDR |
| **Content Type: project_data** | Project-specific values. Additions with defaults, existing values never modified |

