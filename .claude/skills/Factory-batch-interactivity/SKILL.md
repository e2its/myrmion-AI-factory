---
name: Factory-batch-interactivity
description: "Factory Batch Interactivity Protocol (BIP) — replaces one-at-a-time Q&A with tiered proposal→review→converge cycles. Factory acts as Business Analyst mediating between specialist agents and the user. Use when: any command requires prolonged user interactivity (multiple decision rounds)."
applicable_when:
  always: true
---

# BATCH INTERACTIVITY PROTOCOL (BIP v1.2.0)

> **Shared Protocol** — Referenced by: Factory (BA Mediation), SETUP (--init), CODESIGN (--start, --vision), AUDIT (--audit when NEEDS_INFO).
> Eliminates one-question-at-a-time inefficiency. Batches decisions by dependency tier and uses proposal-based iteration.

**Problem:** Sequential Q&A (one question → one answer → repeat 26+ times) wastes **agent handoff round trips** (each question = 1 agent invocation). A 26-question SETUP takes 26+ agent handoffs, fragmenting context and wasting tokens.

**Solution:** Two-layer communication model:
- **Agent ↔ Factory (BATCH):** Agents generate complete recommendation batches per dependency tier in a single invocation. Reduces 26+ agent handoffs to 3-4.
- **Factory ↔ User (RDR):** Factory presents each question one-by-one using the standard RDR protocol (Recommendation + Justification + Alternatives → User Decision). User experience is preserved.
- **Intra-tier navigation:** Agent pre-computes a **Conditional Navigation Matrix** — simple IF/THEN rules (show/skip/unlock) that Factory evaluates mechanically. No governance knowledge required.
- **Disruption-Triggered Re-Harvest:** Agent marks certain questions as **pivotal** (answers that change downstream recommendations). When a user overrides a pivotal question, Factory pauses the RDR walk and invokes a **partial re-harvest** — the agent regenerates only the remaining questions with updated context. Most overrides are non-pivotal and cost nothing extra.
- **Inter-tier dependencies:** Full agent re-evaluation at tier boundaries — agent gets all prior answers before generating the next tier's batch.

---

## 1. Scope: BIP vs Punctual Interactivity

### BIP Commands (Prolonged — BATCH mode)

| Command | Old agent handoffs | BIP agent handoffs | Tier structure |
|---------|-------------------|-------------------|----------------|
| SETUP --init | 26+ | 3-4 | Foundational → Stack → Infrastructure → Finalize |
| CODESIGN --start | 10-20+ | 2-3 | Complete ES Proposal → Tripartite Artifacts → Converge |
| CODESIGN --vision | 5-8 | 1-2 | Visual DNA Batch → Generate → Converge |
| AUDIT --audit | variable | 1-2 | NEEDS_INFO batch → Resolve |

> **Key distinction:** BIP reduces **agent invocations** (batch between agents), NOT user interactions. Factory still presents each decision to the user via RDR (one at a time).

### Punctual Commands (NOT BIP — single-decision)

These commands involve at most 1-2 isolated decisions, not prolonged Q&A:
- Individual RDR decisions during autonomous phases
- BLUEPRINT --approve (single checkpoint)
- IMPLEMENT --build/--fix (autonomous with review)
- DEVOPS --configure (autonomous with 7/7 check)
- QA --verify (autonomous with checklist)

### Classification Rule
```yaml
FUNCTION is_bip_command(command):
  BIP_COMMANDS = [
    "SETUP --init",
    "CODESIGN --start",
    "CODESIGN --vision",
    "AUDIT --audit"     # Only when sections have status: NEEDS_INFO
  ]
  RETURN command IN BIP_COMMANDS
```

---

## 2. Core Cycle: Harvest → Mediate → Resolve → Converge

```
┌─────────┐     ┌───────────────────────┐     ┌─────────┐     ┌──────────┐
│ HARVEST  │────▶│       MEDIATE          │────▶│ RESOLVE │────▶│ CONVERGE │
│ (Agent)  │     │     (Factory+User)     │     │ (Agent) │     │ (Factory)│
│  BATCH   │     │  RDR one-by-one +      │     │  BATCH  │     │          │
│ generates│     │  conditional nav +     │     │processes│     │          │
│ all Qs   │     │  disruption re-harvest │     │all As   │     │          │
└─────────┘     └───────────────────────┘     └─────────┘     └──────────┘
     ▲                    │                                         │
     │    pivotal override│                                         │
     │    ──────────────▶ │ partial re-harvest                      │
     │    ◀────────────── │ (agent regenerates remaining Qs)        │
     │                                                              │
     └──── DELTA (if user requests changes) ◀───────────────────────┘
```

### Two Communication Layers

| Layer | Direction | Mode | Rationale |
|-------|-----------|------|-----------|
| **Batch** | Agent → Factory | All decisions for a tier in one invocation | Minimizes agent handoffs (token/context savings) |
| **RDR** | Factory → User | One question at a time with Recommendation | Preserves decision quality, allows conditional navigation |
| **Conditional Nav** | Agent → Factory (pre-computed) | IF/THEN rules for navigation (show/skip/unlock) | Factory handles intra-tier navigation without governance knowledge |
| **Disruption Re-Harvest** | Factory → Agent (on pivotal override) | Partial re-harvest of remaining questions | Agent recalculates recommendations with governance context |

### Phase 1: HARVEST (Agent generates Decision Batch)

Factory invokes agent in **harvest mode**. Agent:
1. Analyzes available context (workspace, audit results, user prose, templates)
2. Generates a **Decision Batch** for the current dependency tier
3. Each decision point includes an RDR recommendation (Recommendation + Justification + Alternatives)
4. Returns Decision Batch to Factory via handoff

```yaml
FUNCTION agent_harvest(tier, context):
  # Agent reads governance, scans workspace, loads templates
  # Generates recommendations for ALL questions in this tier
  
  decision_batch = {
    tier_id: N,
    tier_name: "Foundational | Stack | Infrastructure | ...",
    decisions: [
      {
        id: "Q1",
        question: "Project Name",
        type: "free_text | single_choice | multi_choice | boolean",
        pivotal: false,              # If true, override triggers partial re-harvest
        recommendation: "my-fintech-app",
        justification: "Derived from repository name and business goal",
        simplified: "El nombre con el que identificarás tu proyecto",  # Plain-language explanation for non-technical users
        alternatives: [],           # For free_text: empty
        options: [],                 # For single_choice: list of options
        depends_on: [],              # Other Q IDs this depends on
        tier_filter: null,           # Budget tier filter if applicable
        persist_key: "project_name"
      },
      # ... all questions in this tier
    ],
    conditional_navigation: [
      # Pre-computed IF/THEN rules for Factory to evaluate during RDR walk
      # NAVIGATION rules: show/skip/unlock questions based on prior answers
      { trigger: "Q3 == 'Brownfield'", action: "unlock", targets: ["Q3.1", "Q3.2", "Q3.3"] },
      { trigger: "Q5 == 'None'",       action: "skip",   targets: ["Q6", "Q7", "Q8"] },
      { trigger: "Q7 in [B5..B11]",    action: "unlock", targets: ["Q8"] }
    ]
  }
  
  # Persist to file for Factory to read
  WRITE decision_batch → docs/.bip/{feature_id}_tier_{N}.md
  RETURN_TO_FACTORY: "Decision Batch Tier {N} ready. {count} decisions."
```

### Phase 2: MEDIATE (Factory presents RDR to user, one question at a time)

Factory reads the Decision Batch and walks through each question **sequentially** using the standard RDR protocol. Factory evaluates the agent's **Conditional Navigation Matrix** locally for show/skip/unlock rules.

**Disruption-Triggered Re-Harvest:** When the user overrides a **pivotal** question (one whose answer changes downstream recommendations), Factory pauses the RDR walk and invokes a **partial re-harvest**. The agent regenerates only the remaining questions with the updated context. Non-pivotal overrides proceed normally with no extra cost.

```yaml
FUNCTION factory_mediate(decision_batch):
  # Factory reads the tier's Decision Batch document
  # This is a BA mediation artifact — Factory MAY read its full content
  # (Exception to frontmatter-only rule for BIP Decision Documents)
  
  nav = decision_batch.conditional_navigation  # Pre-computed by agent
  questions = decision_batch.decisions
  answers = []
  cursor = 0  # Current position in questions list
  
  PRINT: "📋 **Tier {tier_id}: {tier_name}** — {count} decisions"
  
  WHILE cursor < questions.LENGTH:
    question = questions[cursor]
    
    # 1. Evaluate NAVIGATION rules
    IF nav.should_skip(question.id, answers):
      cursor += 1
      CONTINUE
    IF NOT nav.is_unlocked(question.id, answers):
      cursor += 1
      CONTINUE
    
    # 2. Present single question via RDR (adapts to explanation_level + language)
    level = session.explanation_level OR "SIMPLIFIED"
    lang = session.language OR "en"
    IF level == "SIMPLIFIED" AND Q.simplified:
      PRESENT TO USER:
        """
        **{Q.id}: {Q.question}**
        💡 _{Q.simplified}_
        🔹 {t(lang, 'recommendation')}: {Q.recommendation}
           _{Q.justification}_
           {t(lang, 'alternatives')}: {Q.alternatives}
        ▸ {t(lang, 'your_decision')}: [{t(lang, 'accept')} / {t(lang, 'change')}]  — {t(lang, 'type_help')}
        """
        # recommendation: es="Recomendación" en="Recommendation"
        # alternatives: es="Alternativas" en="Alternatives"
        # your_decision: es="Tu decisión" en="Your decision"
        # accept: es="aceptar" en="accept"
        # change: es="cambiar" en="change"
        # type_help: es="escribe 'ayuda' para más detalle" en="type 'help' for more detail"
    ELSE:
      PRESENT TO USER:
        """
        **{Q.id}: {Q.question}**
        🔹 {t(lang, 'recommendation')}: {Q.recommendation}
           _{Q.justification}_
           {t(lang, 'alternatives')}: {Q.alternatives}
        ▸ {t(lang, 'your_decision')}: [{t(lang, 'accept')} / {t(lang, 'override')}]
        """
        # override: es="cambiar" en="override"
    
    COLLECT user_answer
    overrode = (user_answer != Q.recommendation)
    answers.APPEND({ id: Q.id, value: user_answer, overrode: overrode })
    
    # 3. Evaluate navigation triggers
    nav.evaluate_triggers(Q.id, user_answer)
    
    # 4. DISRUPTION CHECK — pivotal override triggers partial re-harvest
    IF overrode AND question.pivotal:
      PRINT: "🔄 Recalculating recommendations based on your choice..."
      # Invoke agent to regenerate remaining questions with updated context
      remaining_ids = [q.id FOR q IN questions[cursor+1:] IF NOT already_answered(q.id)]
      INVOKE agent "{command} --harvest --tier {tier} --partial --from {next_question_id} --answers {answers}"
      # Agent writes updated Decision Batch with regenerated remaining questions
      updated_batch = READ("docs/.bip/{slug}_tier_{tier}.md")
      questions = updated_batch.decisions  # Replace remaining questions with fresh ones
      nav = updated_batch.conditional_navigation  # Refresh navigation rules
      cursor = find_index(questions, next_question_id)  # Resume from where we left off
      CONTINUE
    
    cursor += 1
  
  # Compile AnswerSet from all collected answers
  answer_set = {
    tier_id: N,
    answers: answers
  }
  
  # Persist for agent to read
  WRITE answer_set → docs/.bip/{feature_id}_answers_tier_{N}.md
```

#### Why this works without Factory having governance knowledge

- **Navigation rules** (`skip`/`unlock`): Factory evaluates simple IF/THEN conditions — pure routing logic.
- **Non-pivotal overrides**: Factory continues the RDR walk unchanged — the override doesn't affect downstream recommendations.
- **Pivotal overrides**: Factory delegates back to the agent, who has full governance knowledge to regenerate accurate recommendations. The user sees a brief "Recalculating..." message and the RDR walk resumes with updated recommendations.
- **Cost model**: Most overrides are non-pivotal (zero extra cost). Pivotal overrides add 1 agent call each, but pivotal questions are rare (typically 3-5 per tier: platform, architecture style, budget tier).

### Phase 3: RESOLVE (Agent processes answers, generates next tier or proposal)

Factory invokes agent in **resolve mode** with the AnswerSet. Agent:
1. Processes all answers (persists to setup.md / spec artifacts)
2. Evaluates conditional unlocks → generates next tier's Decision Batch
3. OR if all tiers complete → generates complete proposal

```yaml
FUNCTION agent_resolve(answer_set, tier_id):
  # Process all answers
  FOR EACH answer IN answer_set.answers:
    PERSIST answer.value TO target artifact (setup.md, etc.)
  
  # Check conditional unlocks
  next_tier = evaluate_conditionals(answer_set)
  
  IF next_tier EXISTS:
    # Generate next Decision Batch
    RETURN agent_harvest(next_tier, updated_context)
  ELSE:
    # All tiers complete → generate final proposal
    RETURN agent_propose_final()
```

### Phase 4: CONVERGE (User reviews complete proposal)

After all tiers are resolved, Factory presents the complete proposal summary (this IS shown as a single document — it's a review of already-made decisions, not new decisions):

```yaml
FUNCTION factory_converge(proposal):
  PRESENT TO USER:
    """
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ✅ **Complete Proposal Summary**
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    {proposal_summary — table of all decisions made across all tiers}
    
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Accept this configuration? (yes / request changes)
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """
  
  IF user_accepts:
    INVOKE agent --finalize
  ELSE:
    # Delta round — user specifies which decisions to change
    # Agent re-harvests ONLY the affected tier(s) with updated context
    INVOKE agent --harvest-delta with change_requests
```

---

## 3. Dependency Tier Definitions

### SETUP --init Tiers

```yaml
TIER_0_FOUNDATIONAL:
  name: "Project Foundation"
  questions: [Q1, Q2, Q3, Q4]
  dependencies: none
  description: "Project identity, business goal, mode, and budget. Everything else depends on these."
  conditional_unlocks:
    - { trigger: "Q3 == 'Brownfield'", unlocks: [Q3.1, Q3.2, Q3.3] }

TIER_1_STACK:
  name: "Technology Stack"
  questions: [Q5, Q6, Q7, Q8, Q9, Q10, Q11, Q12, Q13, Q14]
  dependencies: [TIER_0]
  description: "Backend/frontend stack. Filtered by budget tier (Q4) and project mode (Q3)."
  conditional_unlocks:
    - { trigger: "Q5 == 'None'", skips: [Q6, Q7, Q8] }
    - { trigger: "Q9 == 'None'", skips: [Q10, Q11, Q12, Q13, Q14] }
    - { trigger: "Q7 in [B5..B11]", unlocks: [Q8] }

TIER_2_INFRASTRUCTURE:
  name: "Infrastructure & Tooling"
  questions: [Q15, Q16, Q17, Q18, Q19, Q20, Q20.1, Q20.2, Q21, Q21.1, Q22, Q22.1, Q23, Q24, Q25, Q26]
  dependencies: [TIER_0, TIER_1]
  description: "Databases, auth, hosting, CI/CD, observability, dependencies."
  conditional_unlocks:
    - { trigger: "Q18 == 'OAuth2'", unlocks: [Q18.1_provider] }
    - { trigger: "Q24a == true", unlocks: [Q24a_details] }
    - { trigger: "Q24b == true", unlocks: [Q24b_details] }
    - { trigger: "Q24c == true", unlocks: [Q24c_details] }

TIER_FINAL:
  name: "Finalization"
  questions: []
  dependencies: [TIER_0, TIER_1, TIER_2]
  description: "Budget validation, complete summary, ADR-0000 generation."
```

### CODESIGN --start Tiers

```yaml
TIER_PROPOSAL:
  name: "Complete Event Storming Proposal"
  dependencies: [feature_description, constitution, CIP_inventory]
  description: >
    Agent generates complete Event Storming (all 7 phases) as a proposal
    based on feature description. Actors, Commands, Events, Read Models,
    Schemas, Policies, External Systems — all proposed in one batch.
    Factory presents key decision points to user via RDR.

TIER_ARTIFACTS:
  name: "Tripartite Artifact Generation"
  dependencies: [TIER_PROPOSAL approved]
  description: >
    Agent generates all 3 artifacts (spec.feature, mock.html, user_journey.md)
    from approved Event Storming. Presented together for review.

TIER_ALIGNMENT:
  name: "Tripartite Alignment Verification"
  dependencies: [TIER_ARTIFACTS reviewed]
  description: >
    12-point alignment check. Gaps presented to user via RDR for resolution.
```

### CODESIGN --vision Tiers

```yaml
TIER_VISUAL_DNA:
  name: "Visual DNA & Input Mode"
  dependencies: [setup.md, ux-constitution]
  description: >
    Agent generates all foundational visual decisions in one batch:
    input mode detection, color mood, density, spacing, any FROM_SCRATCH
    RDR questions. Factory presents each to the user via RDR one-by-one.

TIER_GENERATION:
  name: "Vision Artifact Generation"
  dependencies: [TIER_VISUAL_DNA approved]
  description: >
    Agent generates all 6 vision artifacts in one pass.
    User reviews complete visual system.
```

---

## 4. Decision Batch Document Format

Decision Batches are persisted as markdown files in `docs/.bip/` for cross-invocation state:

```markdown
---
type: bip_decision_batch
command: "SETUP --init"
tier_id: 0
tier_name: "Project Foundation"
created_at: ISO_8601
status: PENDING | ANSWERED | PROCESSED
answers_file: null | "docs/.bip/SETUP_answers_tier_0.md"
conditional_navigation:
  - { trigger: "Q3 == 'Brownfield'", action: unlock, targets: [Q3.1, Q3.2, Q3.3] }
  - { trigger: "Q3 == 'Greenfield'", action: skip, targets: [Q3.1, Q3.2, Q3.3] }
---

# Decision Batch — Tier 0: Project Foundation

## Q1: Project Name
- **Type:** free_text
- **Recommendation:** `my-fintech-app`
- **Justification:** Derived from repository name and business goal keywords
- **Persist key:** `project_name`

## Q2: Business Goal
- **Type:** free_text
- **Recommendation:** _(no recommendation — user must describe)_
- **Persist key:** `business_goal`

## Q3: Project Mode
- **Type:** single_choice
- **Options:** Greenfield (new project) | Brownfield (existing codebase)
- **Pivotal:** yes
- **Recommendation:** `Greenfield`
- **Justification:** No existing codebase detected in workspace
- **Persist key:** `project_mode`
- **Navigates:** Q3.1, Q3.2, Q3.3 (unlock if Brownfield)

## Q4: AI Budget Tier
- **Type:** single_choice
- **Options:** Starter ($0-50) | Professional ($200-500) | Enterprise ($1,000-3,000) | Unlimited ($5,000+)
- **Pivotal:** yes
- **Recommendation:** `Professional`
- **Justification:** Balanced cost/capability for typical web application
- **Persist key:** `ai_budget.tier`
```

### Conditional Navigation Matrix Format

The `conditional_navigation` array in frontmatter defines rules that Factory evaluates during the RDR walk:

```yaml
# Each rule has:
#   trigger: Simple condition on a question's answer (equality, membership, boolean)
#   action:  What Factory does when trigger is true
#   targets: Which question IDs are affected

# Supported actions:
actions:
  skip:      "Hide question(s) from RDR walk — answer set to null/default"
  unlock:    "Show question(s) that are hidden by default"

# Examples:
- { trigger: "Q3 == 'Brownfield'", action: unlock, targets: [Q3.1, Q3.2, Q3.3] }
- { trigger: "Q5 == 'None'",       action: skip,   targets: [Q6, Q7, Q8] }
- { trigger: "Q7 in [B5..B11]",    action: unlock, targets: [Q8] }

# KEY PRINCIPLES:
# - Navigation rules are pure routing logic — Factory needs NO governance knowledge.
# - Recommendation accuracy is handled by Disruption-Triggered Re-Harvest (see Phase 2).
# - Agent marks pivotal questions in the decisions array (pivotal: true).
```

### Pivotal Questions & Disruption-Triggered Re-Harvest

Questions marked `pivotal: true` in the Decision Batch are those whose user override invalidates downstream recommendations. Examples:
- **Q4 (Budget Tier):** Changes which tools/services are cost-appropriate
- **Q5 (Backend Runtime):** Changes framework, ORM, testing tool recommendations
- **Q19 (Cloud Platform):** Changes queue, storage, hosting recommendations

```yaml
# In the decisions array, pivotal questions are marked:
decisions:
  - id: "Q19"
    question: "Cloud Platform"
    pivotal: true     # ← Override triggers partial re-harvest of Q20+
    recommendation: "AWS"
    justification: "..."
  - id: "Q20"
    question: "Message Queue"
    pivotal: false
    recommendation: "SQS"       # ← This recommendation assumes Q19=AWS
    justification: "Native AWS message queue"

# When user overrides Q19 from AWS → Azure:
# Factory invokes: --harvest --tier 2 --partial --from Q20 --answers [Q15=..., ..., Q19=Azure]
# Agent regenerates Q20+ with governance context → Q20.recommendation becomes "Azure Service Bus"
```

---

## 5. Answer Set Document Format

```markdown
---
type: bip_answer_set
command: "SETUP --init"
tier_id: 0
answered_at: ISO_8601
---

# Answers — Tier 0: Project Foundation

| Question | Recommendation | User Decision | Overrode? |
|----------|---------------|--------------|-----------|
| Q1: Project Name | my-fintech-app | payflow | yes |
| Q2: Business Goal | — | "Digital payment platform for SMBs" | n/a |
| Q3: Project Mode | Greenfield | Greenfield | no |
| Q4: AI Budget Tier | Professional | Enterprise | yes |
```

---

## 6. Factory BA Mediation Protocol

### Role Extension
Factory gains a **Business Analyst (BA)** capability EXCLUSIVELY for BIP-tagged commands. This does NOT violate Strict Dispatcher Discipline because:
1. BA mediation is PROJECT MANAGEMENT, not technical work
2. Decision Documents are structured Q&A, not technical specifications
3. Factory manages the **process** (which question to show next), not the **content** (what to recommend)
4. Recommendations come from the specialist agent, not from Factory

### Context Depth Exception for BIP Documents
```yaml
# Factory MAY read full content of files in docs/.bip/
# These are BA mediation artifacts — Factory's own domain.
# Similar to workflow_log.json (Factory's own domain).
BIP_READABLE_PATHS = ["docs/.bip/*"]
```

### BA Mediation Flow (Factory-side)
```yaml
FUNCTION factory_bip_mediate(command, feature_id, user_context):
  # Step 0: Detect BIP command
  IF NOT is_bip_command(command):
    # Standard single-handoff delegation
    RETURN standard_delegate(command, feature_id, user_context)
  
  # Step 1: Announce BIP mode to user
  PRINT:
    """
    📊 **Guided Decision Mode** — {command}
    I'll walk you through each decision one by one, with the specialist's
    recommendation for each. Decisions are organized by dependency tier.
    """
  
  # Step 2: HARVEST — invoke agent for first tier (BATCH: agent generates all questions at once)
  tier = 0
  LOOP:
    INVOKE agent "{command} --harvest --tier {tier}" WITH user_context
    # Agent returns, Decision Batch + Conditional Nav Matrix written to docs/.bip/
    
    # Step 3: MEDIATE — present questions to user ONE BY ONE via RDR
    batch = READ("docs/.bip/{command_slug}_tier_{tier}.md")  # BIP exception: Factory MAY read
    factory_rdr_walk(batch)  # ← Sequential RDR with disruption detection
    # All answers collected, AnswerSet written to docs/.bip/
    
    # Step 4: RESOLVE — invoke agent to process all tier answers (BATCH: agent gets all answers at once)
    INVOKE agent "{command} --resolve --tier {tier}"
    # Agent processes answers, checks for next tier
    
    result = READ_FRONTMATTER("docs/.bip/{command_slug}_tier_{tier}.md")
    IF result.next_tier EXISTS:
      tier = result.next_tier
      CONTINUE
    ELSE:
      BREAK
  
  # Step 5: CONVERGE — present final summary for approval
  INVOKE agent "{command} --propose-final"
  present_final_proposal_to_user()
  
  IF user_accepts:
    INVOKE agent "{command} --finalize"
  ELSE:
    # Delta iteration — user specifies changes, agent re-harvests affected tiers
    INVOKE agent "{command} --harvest-delta" WITH change_requests
    CONTINUE mediation loop

# RDR walk: Factory iterates through questions, detects pivotal overrides
FUNCTION factory_rdr_walk(batch):
  nav = batch.conditional_navigation
  questions = batch.decisions
  answers = []
  cursor = 0
  WHILE cursor < questions.LENGTH:
    question = questions[cursor]
    IF nav.should_skip(question.id, answers): cursor += 1; CONTINUE
    IF NOT nav.is_unlocked(question.id, answers): cursor += 1; CONTINUE
    PRESENT_RDR(question)  # One question, one recommendation, wait for answer
    answer = COLLECT_USER_ANSWER()
    
    # GO-BACK DETECTION — user wants to revisit a prior question
    IF answer MATCHES /^(back|volver|← ?volver|change Q\d+)/i:
      target_id = EXTRACT_QUESTION_ID(answer) OR answers.LAST().id
      target_idx = find_index(questions, target_id)
      IF target_idx >= 0 AND target_idx < cursor:
        PRINT: t(lang, "go_back", {target_id})
        # es: "↩️ Volviendo a **{target_id}**..."
        # en: "↩️ Going back to **{target_id}**..."
        # Remove all answers from target_id onward (they'll be re-collected)
        answers = answers.FILTER(a => find_index(questions, a.id) < target_idx)
        # Check if any removed answer was pivotal-override → re-harvest needed
        removed_pivotals = [a FOR a IN removed_answers IF a.overrode AND questions[a.id].pivotal]
        IF removed_pivotals.LENGTH > 0:
          PRINT: t(lang, "recalculating")
          # es: "🔄 Recalculando recomendaciones..."
          # en: "🔄 Recalculating recommendations..."
          INVOKE agent "--harvest --tier {tier} --partial --from {target_id} --answers {answers}"
          updated = READ("docs/.bip/{slug}_tier_{tier}.md")
          questions = updated.decisions
          nav = updated.conditional_navigation
        cursor = target_idx
        CONTINUE
      ELSE:
        PRINT: t(lang, "go_back_not_found", {target_id})
        # es: "⚠️ No se encontró {target_id} en preguntas anteriores."
        # en: "⚠️ {target_id} not found in previous questions."
        CONTINUE  # Re-present current question
    
    overrode = (answer != question.recommendation)
    answers.APPEND({ id: question.id, value: answer, overrode: overrode })
    nav.evaluate_triggers(question.id, answer)
    # DISRUPTION CHECK — pivotal override triggers partial re-harvest
    IF overrode AND question.pivotal:
      PRINT: "🔄 Recalculating recommendations based on your choice..."
      INVOKE agent "--harvest --tier {tier} --partial --from {next_q_id} --answers {answers}"
      updated = READ("docs/.bip/{slug}_tier_{tier}.md")
      questions = updated.decisions
      nav = updated.conditional_navigation
      cursor = find_index(questions, next_q_id)
      CONTINUE
    cursor += 1
  WRITE answers → docs/.bip/{slug}_answers_tier_{tier}.md
```

### Separation of Concerns

```
┌───────────────────────────────────────────────────────────────┐
│  AGENT (knows governance)                                     │
│  ─ Generates default recommendations (RDR content)             │
│  ─ Pre-computes conditional navigation rules (skip/unlock)     │
│  ─ Marks pivotal questions (override → downstream impact)      │
│  ─ Handles partial re-harvest on pivotal override              │
│  ─ Evaluates inter-tier dependencies (full re-harvest)          │
│  ─ Validates final proposal against governance                  │
└───────────────────────────────────────────────────────────────┘
        │ Decision Batch + Conditional Nav Matrix (BATCH)
        ▼
┌───────────────────────────────────────────────────────────────┐
│  FACTORY (no governance knowledge — process navigator)         │
│  ─ Presents agent's recommendations via RDR (one-by-one)       │
│  ─ Evaluates nav rules (show/skip/unlock)                       │
│  ─ Detects pivotal overrides → triggers partial re-harvest     │
│  ─ Collects user answers into AnswerSet                         │
│  ─ Routes AnswerSet back to agent (BATCH)                       │
└───────────────────────────────────────────────────────────────┘
        │ RDR (one question at a time)
        │ Pivotal override? → partial re-harvest → resume
        ▼
┌───────────────────────────────────────────────────────────────┐
│  USER                                                         │
│  ─ Sees one question + recommendation at a time               │
│  ─ Accepts or overrides each decision                           │
│  ─ Pivotal overrides trigger brief recalculation, then resume  │
│  ─ Never aware of batching layer (transparent)                  │
└───────────────────────────────────────────────────────────────┘
```

---

## 7. Agent BIP Modes (New Sub-Commands)

Each BIP-tagged agent command gains three operational modes:

### `--harvest --tier {N}` (Generate Decision Batch)
- Analyze context (workspace, templates, audit results, prior tier answers)
- Generate complete Decision Batch for tier N with RDR recommendations
- Mark pivotal questions (`pivotal: true`) — those whose override invalidates downstream recommendations
- Generate Conditional Navigation Matrix (skip/unlock rules)
- Persist to `docs/.bip/`
- Return to Factory

### `--harvest --tier {N} --partial --from {QID} --answers {answers}` (Partial Re-Harvest)
- Triggered by Factory when user overrides a pivotal question
- Receive collected answers so far (including the overridden value)
- Regenerate ONLY questions from {QID} onward with governance-aware context
- Update Decision Batch in `docs/.bip/` (replace remaining questions + nav rules)
- Return to Factory (Factory resumes RDR walk from {QID})

### `--resolve --tier {N}` (Process User Answers)
- Read AnswerSet from `docs/.bip/`
- Persist answers to target artifact (setup.md, spec.feature, etc.)
- Evaluate conditional unlocks
- If next tier exists: write `next_tier` to batch frontmatter
- Return to Factory

### `--propose-final` (Generate Complete Proposal)
- Generate final artifact(s) with all answered decisions
- Present summary for convergence review
- Return to Factory

### `--finalize` (Persist Approved Proposal)
- Finalize artifacts (set status: COMPLETED/APPROVED)
- Generate derived artifacts (ADR-0000 for SETUP, etc.)
- Clean up `docs/.bip/` temporary files
- Return to Factory

---

## 8. Resumability (BIP-aware)

BIP state is persisted in `docs/.bip/` files. If interrupted:

```yaml
FUNCTION bip_resume(command):
  bip_files = SCAN("docs/.bip/{command_slug}_*")
  
  IF bip_files IS EMPTY:
    # Fresh start
    RETURN start_from_tier_0
  
  # Find last completed tier
  FOR EACH tier_file IN bip_files SORTED_BY tier_id DESC:
    IF tier_file.status == "PROCESSED":
      RETURN start_from_tier(tier_file.tier_id + 1)
    ELIF tier_file.status == "ANSWERED":
      RETURN resolve_tier(tier_file.tier_id)  # Answers exist, need processing
    ELIF tier_file.status == "PENDING":
      RETURN mediate_tier(tier_file.tier_id)   # Questions exist, need user input
```

---

## 9. BIP Cleanup

After successful finalization, temporary BIP files are removed:

```yaml
FUNCTION bip_cleanup(command_slug):
  DELETE docs/.bip/{command_slug}_*
  # If docs/.bip/ is empty, remove directory
  IF DIRECTORY_EMPTY("docs/.bip/"):
    DELETE "docs/.bip/"
```

---

## 10. Integration with Existing Protocols

| Protocol | BIP Integration |
|----------|----------------|
| **RDR** | Factory presents each question to the user one-by-one using RDR format (Recommendation + Justification + Alternatives). The **batch** is between agents; the user sees standard RDR. |
| **IPP** | Decision Batches and Answer Sets follow IPP skeleton-first write. Resumable on interruption. |
| **ACP** | Agent entry announcements include BIP mode indicator. Phase milestones map to tier transitions. |
| **Smart Redirect** | After BIP finalization, normal Smart Redirect computes next steps. |
| **Worklog** | BIP tier transitions logged as worklog entries with `bip_tier` field. |
| **Governance Loading** | Each agent invocation (harvest/resolve) loads governance per standard protocol. Agent knows governance; Factory does not need it. |

---

## 11. User Interaction Shortcuts

Factory recognizes these shorthand responses during the RDR walk:

| Input | Meaning |
|-------|---------|
| `ok` / `accept` / `acepto` / `de acuerdo` / `👍` / `yes` / `sí` | Accept this recommendation |
| `help` / `help me decide` / `ayuda` / `explícame` | Show detailed pros/cons in session.language for current question |
| `skip` / `saltar` | Skip optional question (mark as default/auto) |
| `back` / `volver` / `← volver` / `change Q3` | Re-open a previously answered question in this tier. Removes answers from that point forward. If a pivotal override is undone, triggers partial re-harvest. |
| `show summary` / `resumen` | Display all decisions made so far in this tier |
