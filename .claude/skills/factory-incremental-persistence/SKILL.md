---
name: factory-incremental-persistence
description: "Factory Incremental Persistence Protocol (IPP) — skeleton-first write, section-atomic saves, resume-on-entry, Context Canary gate. Use when: any agent writes artifacts incrementally to survive context summarization."
applicable_when:
  always: true
---

# INCREMENTAL PERSISTENCE PROTOCOL (IPP v1.0.1)

> **Shared Protocol** — Referenced by: ALL agents (SETUP, AUDIT, CODESIGN, BLUEPRINT, IMPLEMENT, DEVOPS, QA).
> Ensures every reasoning cycle is persisted to files so that context loss (summarization, session change, interruption) never causes loss of progress or decisions.

**Core Principle:** The artifact IS the memory. If conversation context disappears, the agent reads the artifact and knows exactly where to continue.

---

## Why This Protocol Exists

LLM conversation context is ephemeral:
- **Summarization** compresses or drops mid-task state
- **Session changes** lose all in-memory reasoning
- **Token limits** force context eviction of earlier decisions

Without file persistence, an agent mid-way through generating `design.md` cannot recover:
- Which phase it was in
- What decisions were already made with the user
- Which sections are complete vs pending

**Solution:** Persist ALL reasoning state to the artifact itself. The file is the single source of truth — not conversation memory.

---

## Three Pillars

### Pillar 1: Skeleton-First Write

**BEFORE any content generation**, create the artifact file with its complete structure:

```yaml
FUNCTION skeleton_first_write(artifact_path, artifact_type):
  # Step 1: Write frontmatter with ALL fields (including _progress)
  # Step 2: Write ALL section headers (empty bodies)
  # Step 3: SAVE to disk IMMEDIATELY
  
  frontmatter = BUILD_FRONTMATTER(artifact_type):
    status: DRAFT
    feature_id: "{FEATURE_ID}"
    created_at: "{ISO_8601}"
    updated_at: "{ISO_8601}"
    _progress:
      current_phase: "skeleton"        # Updated as agent advances
      completed_sections: []           # Section IDs already written
      pending_sections: [ALL_SECTIONS] # Section IDs not yet written
      decisions: []                    # RDR decisions made (persisted inline)
      last_agent: "{AGENT_NAME}"       # Which agent last wrote
      last_command: "{COMMAND}"        # Which command was executing
      resumable: true                  # Can another session continue?
    # ... artifact-specific fields ...

  body = BUILD_SECTION_SKELETON(artifact_type):
    # Write ALL expected section headers with empty placeholder bodies
    # Example for design.md:
    #   ## Section 0: Reuse Analysis
    #   <!-- PENDING -->
    #   ## Section 1: Architecture Overview
    #   <!-- PENDING -->
    #   ... etc.

  WRITE(artifact_path, frontmatter + body)
  LOG: "Skeleton created: {artifact_path} ({pending_sections.length} sections pending)"
```

**Key rule:** The skeleton is written in ONE atomic operation. After this, the file EXISTS on disk with valid frontmatter. Any interruption after skeleton → artifact is recoverable.

### Pillar 2: Section-Atomic Saves

**After EACH logical section is completed**, save to disk immediately:

```yaml
FUNCTION save_section(artifact_path, section_id, content):
  # Step 1: Replace section placeholder with actual content
  REPLACE_SECTION(artifact_path, section_id, content)
  
  # Step 2: Update _progress in frontmatter
  UPDATE_FRONTMATTER(artifact_path):
    _progress.completed_sections: APPEND(section_id)
    _progress.pending_sections: REMOVE(section_id)
    _progress.current_phase: NEXT_PHASE_OR_SECTION
    updated_at: "{ISO_8601}"
  
  # Step 3: SAVE to disk — IMMEDIATE, NO BATCHING
  SAVE(artifact_path)
  
  LOG: "Section saved: {section_id} in {artifact_path}"
  # Rule: NEVER hold multiple completed sections in memory without saving
  # Rule: NEVER continue to next section until current section is on disk
```

**Granularity by agent:**

| Agent | Artifact | Section = Save Unit |
|-------|----------|-------------------|
| SETUP | setup.md | Each answered question (Q1, Q2, ...) |
| SETUP | constitution.md | Each resolved config block |
| CODESIGN | spec.feature | Each completed scenario |
| CODESIGN | mock.html | Each page/view completed |
| CODESIGN | user_journey.md | Each discovery phase (actors, commands, events, schemas) |
| BLUEPRINT | design.md | Each design section (0-6) |
| BLUEPRINT | test_plan.md | Each test category |
| BLUEPRINT | increment_plan.md | Frontmatter + § 0 Slicing Rationale frozen at RDR ratification; each § 1 increment (INC-N) as its own atomic section; § 2 DAG on completion; § 3 Monolithic Escape Declaration on completion (when applicable) |
| IMPLEMENT | dev_plan.md | Each phase task group (A, B, C) under monolithic; each `## Increment INC-N` section under incremental (section per increment, tasks per phase within) |
| IMPLEMENT | source code | Each task [x] completion (already exists) |
| DEVOPS | devops_plan.md | Each environment config block |
| QA | qa_report.md | Each verification category |

### Pillar 3: Resume-on-Entry

**Every agent command MUST check for in-progress artifacts before starting:**

```yaml
FUNCTION resume_or_start(artifact_path, FEATURE_ID, command):
  IF FILE_EXISTS(artifact_path):
    fm = READ_FRONTMATTER(artifact_path)
    progress = fm._progress
    
    IF progress IS NOT NULL AND progress.pending_sections.length > 0:
      # RESUME MODE
      LOG: "Resuming {artifact_path}: {progress.completed_sections.length} sections done, {progress.pending_sections.length} pending"
      LOG: "Last agent: {progress.last_agent}, Last command: {progress.last_command}"
      
      # Recover decisions from artifact (NOT from conversation memory)
      decisions = progress.decisions
      LOG: "Recovered {decisions.length} previous decisions from artifact"
      
      # Continue from first pending section
      RESUME_FROM(progress.pending_sections[0])
      RETURN "RESUMED"
    
    ELIF fm.status IN [APPROVED, IMPLEMENTED_AND_VERIFIED, CANCELLED, DEPRECATED]:
      # TERMINAL STATE — do not overwrite
      LOG: "Artifact in terminal state: {fm.status}"
      RETURN "TERMINAL"
    
    ELSE:
      # Artifact exists but progress is complete or missing
      # Treat as fresh generation (may be legacy artifact without _progress)
      RETURN "FRESH"
  
  ELSE:
    # No artifact — start from scratch
    skeleton_first_write(artifact_path, artifact_type)
    RETURN "FRESH"
```

---

## Decision Persistence (RDR Journal)

Every decision made during RDR (Recommendation → Decision → Ratification) MUST be persisted to the artifact immediately:

```yaml
FUNCTION persist_decision(artifact_path, decision):
  # Decision structure:
  decision_entry = {
    id: "RDR-{sequential}",
    question: "{what was asked}",
    recommendation: "{agent recommendation}",
    user_choice: "{what user decided}",
    rationale: "{why}",
    timestamp: "{ISO_8601}",
    impact: "{which sections affected}"
  }
  
  # Persist in TWO locations:
  # 1. _progress.decisions[] in frontmatter (for quick recovery)
  UPDATE_FRONTMATTER(artifact_path):
    _progress.decisions: APPEND(decision_entry)
  
  # 2. Inline in the artifact body where the decision applies
  #    (for human readability and downstream agent reference)
  #    Format: <!-- RDR-{N}: {question} → {choice} -->
  
  SAVE(artifact_path)  # IMMEDIATE
  LOG: "Decision persisted: {decision_entry.id} → {decision_entry.user_choice}"
```

**Why two locations?**
- `_progress.decisions[]`: Machine-readable, fast recovery for resume-on-entry
- Inline comments: Human-readable, visible to downstream agents reading the artifact

---

## Multi-Artifact Coordination (Ordered Saves)

When a command produces MULTIPLE artifacts (e.g., CODESIGN produces 3 files), persist in dependency order:

```yaml
FUNCTION multi_artifact_persistence(artifacts_in_order):
  # Write skeletons for ALL artifacts FIRST (parallel-safe)
  FOR EACH artifact IN artifacts_in_order:
    skeleton_first_write(artifact.path, artifact.type)
  
  # Then fill content ONE artifact at a time, section by section
  # Order matters: upstream artifacts first
  # Example for CODESIGN:
  #   1. user_journey.md (data schemas = source of truth)
  #   2. spec.feature (references schemas)
  #   3. mock.html (visualizes spec + schemas)
  
  FOR EACH artifact IN artifacts_in_order:
    FOR EACH section IN artifact.sections:
      content = GENERATE(section)
      save_section(artifact.path, section.id, content)
    
    # Mark artifact complete
    UPDATE_FRONTMATTER(artifact.path):
      _progress.current_phase: "complete"
      _progress.pending_sections: []

  LOG: "All {artifacts_in_order.length} artifacts persisted"
```

---

## Context Recovery After Summarization

When an agent starts and detects it may have lost context (new session, summarization occurred):

```yaml
FUNCTION recover_context(FEATURE_ID, command):
  base_path = "docs/spec/{FEATURE_ID}"
  
  # Step 1: Read ALL feature artifacts for state recovery
  recovery_context = {}
  FOR EACH artifact IN expected_artifacts_for(command):
    path = RESOLVE_PATH(artifact, FEATURE_ID)
    IF FILE_EXISTS(path):
      fm = READ_FRONTMATTER(path)
      recovery_context[artifact] = {
        status: fm.status,
        progress: fm._progress OR NULL,
        decisions: fm._progress.decisions OR [],
        iteration: fm.iteration OR 1
      }
  
  # Step 2: Determine continuation point
  in_progress = FILTER(recovery_context, r => r.progress != NULL AND r.progress.pending_sections.length > 0)
  
  IF in_progress.length > 0:
    LOG: "Context recovery: {in_progress.length} artifact(s) with pending work"
    FOR EACH artifact IN in_progress:
      LOG: "  {artifact}: {artifact.progress.completed_sections.length} done, {artifact.progress.pending_sections.length} pending"
    RETURN { mode: "RESUME", artifacts: in_progress }
  
  ELSE:
    LOG: "Context recovery: all artifacts complete or not started"
    RETURN { mode: "FRESH_OR_COMPLETE", artifacts: recovery_context }
```

---

## _progress Cleanup

When an artifact reaches a terminal status (APPROVED, IMPLEMENTED_AND_VERIFIED, etc.), the `_progress` field is cleaned:

```yaml
FUNCTION finalize_artifact(artifact_path, final_status):
  UPDATE_FRONTMATTER(artifact_path):
    status: {final_status}
    updated_at: "{ISO_8601}"
    _progress: null  # REMOVE — artifact is complete, no resume needed
  
  # Decisions remain in inline comments (<!-- RDR-N: ... -->) for traceability
  # but are removed from frontmatter to reduce clutter
  
  SAVE(artifact_path)
  LOG: "Artifact finalized: {artifact_path} → {final_status} (_progress cleared)"
```

---

## Relationship to Existing Gates

| Existing Mechanism | Relationship | Change |
|-------------------|-------------|--------|
| Atomic Persistence Gate (M-07, codesign-feature.md) | **EVOLVED INTO** Pillar 2 (Section-Atomic Saves) | M-07 is now a specific application of IPP Pillar 2. M-07 remains as the CODESIGN-specific enforcement; IPP generalizes it to ALL agents. |
| SETUP Checkpoint 2 (Per-Task Logging) | **ALIGNED WITH** Pillar 2 | Already follows the pattern. Now formalized as IPP compliance. |
| IMPLEMENT `MARK task [x] (atomic save)` | **ALIGNED WITH** Pillar 2 | Already saves per-task. Now gains Pillar 1 (skeleton) and Pillar 3 (resume). |
| One Question at a Time Gate (L-03) | **COMPLEMENTED BY** Decision Persistence | L-03 enforces sequential questions. IPP adds: persist each answer immediately to artifact. |
| Agent Communication Protocol Milestones | **ORTHOGONAL** | ACP milestones are for user visibility. IPP is for file-level state persistence. Both coexist. |

---

## Per-Agent Application Summary

### AUDIT
| Command | Key Persistence Points |
|---------|----------------------|
| `--audit` | Skeleton technical_due.md → save per analysis section (A/B/C/D) → persist risk scores |
| `--refine {SECTION}` | Resume from section → save refined section immediately → update _progress |
| `--approve` | Finalize: status → APPROVED, _progress → null |

### SETUP
| Command | Key Persistence Points |
|---------|----------------------|
| `--init` | Skeleton setup.md → save each Q&A answer immediately → persist ADR-0000 decisions |
| `--generate` | Skeleton constitution.md → save per config block → MATERIALIZATION_REPORT checkboxes [✓] |
| `--generate --resume` | Resume-on-entry from MATERIALIZATION_REPORT → continue from last [✓] checkpoint |
| `--upgrade` | Save per upgraded file → track in upgrade report |

### CODESIGN
| Command | Key Persistence Points |
|---------|----------------------|
| `--start {ID}` | Skeleton 3 artifacts → save per ES phase → save per scenario → save per alignment check |
| `--refine {ID}` | Resume existing artifacts → save per modified scenario → persist changelog entry → persist CASCADE to downstream frontmatters → save alignment re-check results |
| `--vision` | Skeleton 6 vision artifacts → save per artifact completion → save decisions |
| `--vision-refine` | Resume vision artifacts → save per modified artifact → persist changelog |
| `--cancel/--deprecate` | Terminal state write → status update → _progress → null |

### BLUEPRINT
| Command | Key Persistence Points |
|---------|----------------------|
| `--start {ID}` | Skeleton design.md + test_plan.md + increment_plan.md → save per design section (0-6) → save per test category → save contract files → save increment_plan frontmatter + § 0 at RDR ratification → save each § 1 INC-N → save § 2 DAG |
| `--refine {ID}` | Resume from existing artifacts → save per modified section → persist changelog → CASCADE to downstream (includes per-increment invalidation via CASCADE_INCREMENT_INTERNAL) |
| `--approve {ID}` | Finalize: status → APPROVED, _progress → null (design.md + test_plan.md + increment_plan.md) |
| `--adr {ID}` | Skeleton ADR file → save decision content immediately |

### IMPLEMENT
| Command | Key Persistence Points |
|---------|----------------------|
| `--plan {ID}` | Skeleton dev_plan.md → save per phase task group (A, B, C) → save CIP annotations |
| `--build {ID}` | Save per task `[x]` completion (atomic) → resume from first unchecked `[ ]` task → save per phase review/SEC result |
| `--refine {ID}` | Resume dev_plan.md → save per generated delta `[D.N]` or adjustment `[ADJ-N]` task → persist changelog entry → resume unchecked tasks if auto-continues to --build |
| `--fix {ID}` | Append `[FIX-N]` tasks to dev_plan.md (save immediately) → save per fix task `[x]` completion → resume from first unchecked `[FIX-N]` |

### DEVOPS
| Command | Key Persistence Points |
|---------|----------------------|
| `--configure {ID}` | Skeleton devops_plan.md → save per environment block → save per RDR decision → resume from `questions.next_question` |
| `--refine {ID}` | Resume devops_plan.md → save per modified section → recalculate costs → persist cascade |
| `--provision {ID}` | Save IaC files per resource → update infra registry → save provisioning status per environment |
| `--deploy {ID}` | Skeleton deployment_report → save per deployment step → save smoke test results |
| `--rollback {ID}` | Save rollback report → update environment status immediately |

### QA
| Command | Key Persistence Points |
|---------|----------------------|
| `--verify {ID}` | Skeleton qa_report.md with `[ ]` checklist → save per check `[x]` completion → save DAST report → persist verdict |
| `--reject {ID}` | Update qa_report status → persist `[FIX-N]` remediation items → save immediately |
| `--e2e {ID}` | Skeleton e2e_report → save per test suite result → persist verdict |

---

## Context Budget

```yaml
CONTEXT BUDGET:
  _progress frontmatter field: ~50-200 tokens per artifact (depends on decisions count)
  Inline RDR comments: ~20 tokens each
  Section placeholders (<!-- PENDING -->): ~5 tokens each
  Resume-on-entry check: ~30 tokens (frontmatter read only)
  Context Canary gate per section: ~80-110 tokens (frontmatter re-read + validation)
  Total overhead per artifact lifecycle: <800 tokens (including canary checkpoints)
  
  # _progress is REMOVED on finalization → zero long-term cost
  # Inline RDR comments persist but are minimal and serve as traceability
  # Canary gates cost ~0.8s each — negligible vs section generation time
```

---

## Mid-Command Summarization Resilience (Context Canary)

**Problem:** LLM summarization can occur MID-COMMAND — while an agent is generating sections of an artifact. When this happens:
- The agent loses track of which section it was writing
- It may re-generate an already completed section (wasted tokens, potential inconsistency)
- It may skip a pending section (incomplete artifact)
- Previous decisions made during the same command are forgotten

**Solution — Context Canary Gate:** Before EVERY write operation to an artifact, re-read the `_progress` frontmatter (first ~20 lines) from the file itself. The file is the single source of truth — if summarization destroyed conversation memory, the file still reflects actual state.

> **Cost budget:** ~80-110 tokens + ~0.8s per checkpoint (reading frontmatter only, NOT the full file). This is <0.1% of a typical 128K context window per checkpoint.

### Gate Placement

```yaml
# The Context Canary runs at THREE points during artifact lifecycle:
#
# 1. BEFORE EACH SECTION WRITE   → ipp_canary_gate() — validates next section
# 2. BEFORE MULTI-ARTIFACT SAVE  → ipp_canary_gate() per artifact
# 3. BEFORE FINALIZATION          → ipp_canary_gate() — confirms all sections done
#
# It does NOT run:
# - During skeleton_first_write (file doesn't exist yet)
# - For governance snapshot reads (handled by INVARIANT 5 at command start only)
```

### Context Canary Gate Function

```yaml
FUNCTION ipp_canary_gate(artifact_path, intended_section):
  # Step 1: Verify artifact exists
  IF NOT FILE_EXISTS(artifact_path):
    ❌ BLOCK: "IPP Violation — artifact not yet created. Run skeleton_first_write."
    STOP
  
  # Step 2: Re-read _progress from file (MANDATORY — NOT from memory)
  fm = READ_FRONTMATTER(artifact_path)  # Only first ~20 lines, minimal token cost
  
  # Step 3: Handle legacy artifacts without _progress
  IF fm._progress IS NULL AND fm.status == "DRAFT":
    ⚠️ WARN: "Legacy artifact without _progress. Backfilling from file content."
    BACKFILL_PROGRESS(artifact_path)
    fm = READ_FRONTMATTER(artifact_path)  # Re-read after backfill
  
  # Step 4: DUPLICATE DETECTION — has this section already been written?
  IF intended_section IN fm._progress.completed_sections:
    ⚠️ CANARY ALERT: "Section '{intended_section}' already completed. SKIPPING re-generation."
    LOG: "Canary detected post-summarization duplicate write attempt."
    RETURN { action: "SKIP", reason: "already_completed" }
  
  # Step 5: SEQUENCE VALIDATION — is this the correct next section?
  next_pending = fm._progress.pending_sections[0]
  IF intended_section != next_pending:
    ⚠️ CANARY ALERT: "Section mismatch — intended: '{intended_section}', expected next: '{next_pending}'."
    # Auto-correct: write the ACTUAL next pending section instead
    LOG: "Canary correcting section sequence after possible summarization."
    RETURN { action: "REDIRECT", correct_section: next_pending }
  
  # Step 6: CONTENT DRIFT DETECTION — does section have unexpected content?
  IF SECTION_HAS_CONTENT(artifact_path, intended_section):
    IF intended_section NOT IN fm._progress.completed_sections:
      ⚠️ CANARY ALERT: "Section '{intended_section}' has content but not tracked. Auto-correcting _progress."
      UPDATE_FRONTMATTER(artifact_path):
        _progress.completed_sections APPEND intended_section
        _progress.pending_sections REMOVE intended_section
      SAVE(artifact_path)
      RETURN { action: "SKIP", reason: "content_exists_untracked" }
  
  # Step 7: All checks passed
  ✅ RETURN { action: "PROCEED" }
```

### Integration with save_section

The canary gate is integrated into the save_section flow:

```yaml
FUNCTION save_section_with_canary(artifact_path, section_id, content):
  # Canary Gate (MANDATORY — runs BEFORE write)
  canary = ipp_canary_gate(artifact_path, section_id)
  
  IF canary.action == "SKIP":
    LOG: "Canary: skipped section {section_id} — {canary.reason}"
    RETURN  # Do NOT write, move to next section
  
  IF canary.action == "REDIRECT":
    LOG: "Canary: redirecting from {section_id} to {canary.correct_section}"
    section_id = canary.correct_section
    content = GENERATE(section_id)  # Generate correct section content
  
  # Proceed with normal save_section
  save_section(artifact_path, section_id, content)
```

---

## Enforcement

This protocol is **MANDATORY** for ALL agents producing file artifacts. Violations:
- Generating full artifact content in memory then writing once at the end → **VIOLATION**
- Continuing to next section without saving current section → **VIOLATION**
- Starting a command without checking for resumable in-progress artifacts → **VIOLATION**
- Making RDR decisions without persisting them to the artifact → **VIOLATION**
- Writing a section WITHOUT running `ipp_canary_gate()` first → **VIOLATION**
- Assuming section completion state from conversation memory instead of reading `_progress` from file → **VIOLATION**
