---
name: factory-rdr
description: "Factory Recommendation → Decision → Ratification Protocol (RDR) — canonical algorithm for agent-posed decisions requiring user ratification. Enforces minimum 3 options, justified recommendation, verbatim user choice, and immediate persistence via IPP. Use when: any agent asks the user to choose between alternatives (SETUP discovery, CODESIGN feature/vision, BLUEPRINT design, AUDIT low-confidence calls, DEVOPS configure, SETUP --generate ambiguous conventions)."
applicable_when:
  always: true
---

# RECOMMENDATION → DECISION → RATIFICATION PROTOCOL (RDR)

> **Shared Protocol** — Referenced by: ALL agents that pose decisions to the user.
> Canonical source of truth for RDR semantics, format, and persistence contract. Every inline reference to "RDR" across commands / instructions / templates must conform to this protocol.

**Core Principle:** A decision is not taken until it is (a) posed with a justified recommendation + alternatives, (b) chosen verbatim by the user, and (c) **ratified** — persisted to the artifact in the same turn it is made. Anything short of those three steps is a violation.

---

## The Three Beats

### Beat 1 — Recommendation

The agent presents the decision with:

1. **Question** — unambiguous, single-topic. "What testing framework?" not "How do we handle tests?".
2. **Recommended option** — ONE option marked as the recommendation, with a one-line justification grounded in: project context (from `setup.md`), governance rules (from `constitution.md` / `.claude/rules/`), prior RDR decisions, or well-established industry defaults.
3. **Alternatives** — at least **two** additional options (total ≥ 3 options). Each alternative carries a one-line rationale describing when it would be preferred over the recommendation.
4. **Impact** — which downstream sections / artifacts this decision affects, so the user can gauge cost of override.

> **Adversarial pass (MANDATORY).** Options, recommendation, and tradeoffs are the OUTPUT of the [factory-adversarial-reasoning](../factory-adversarial-reasoning/SKILL.md) FOR/AGAINST double pass. Each option carries its FOR (when preferred) AND its AGAINST (main tradeoff vs SDLC governance + product). The recommendation names why it wins despite its own AGAINST.

**MUST NOT:**
- Present a single option phrased as a question ("shall we use X?") — that is coercion, not RDR.
- Omit the recommendation to appear neutral — the user expects agent judgement.
- Mix multiple topics in one question — split into sequential RDRs.
- Invent alternatives for form's sake — if only two serious options exist, explicitly label the third as "status quo / do nothing" with its real cost.

### Beat 2 — Decision

The user chooses ONE option. The agent captures the choice **verbatim** — the exact string the user typed or the option ID they picked. No paraphrasing, no assumed intent.

**Special cases:**
- **User proposes a fourth option**: accept it, register it inline as `user_choice` with its own rationale. Do NOT re-offer the original three.
- **User defers**: mark the decision as `DEFERRED`, do not invent an answer, do not proceed to dependent sections until resolved.
- **User rejects all options**: treat as defer — ask what they want to see offered, then re-pose a new RDR.

### Beat 3 — Ratification

The decision is **persisted immediately** to the artifact, in the same agent turn. Ratification has TWO locations (per IPP Decision Persistence):

1. **`_progress.decisions[]` entry** in the artifact frontmatter (machine-readable, fast recovery):
   ```yaml
   - id: "RDR-{N}"                  # sequential per artifact
     question: "{verbatim question}"
     options: ["{A}", "{B}", "{C}", ...]
     recommendation: "{A}"
     user_choice: "{B}"             # verbatim
     rationale: "{why user chose}"  # if user volunteered one
     timestamp: "{ISO_8601}"
     impact: ["{section_id_1}", "{section_id_2}"]
   ```

2. **Inline comment** in the artifact body at the point the decision applies (human-readable, visible to downstream agents):
   ```markdown
   <!-- RDR-{N}: {question} → {user_choice} -->
   ```

**The file write happens in the same turn as the decision.** Not at "the end of the section". Not "after the next few questions". Immediately. See [factory-incremental-persistence/SKILL.md § Decision Persistence](../factory-incremental-persistence/SKILL.md) for the persistence contract.

---

## Sequential vs Batch RDR

Two execution modes depending on decision topology:

### Sequential RDR (default, L-03 compliant)

One question at a time, each ratified before the next is posed. Use when:
- Decisions are dependent (answer to Q1 determines the options for Q2).
- The decision is strategic / pivotal (impacts multiple downstream sections).
- `/audit --audit` low-confidence calls, `/blueprint --start` design decisions, `/devops --configure` environment choices.

**Flow:**
```
POSE Q1 → WAIT user → RATIFY Q1 → POSE Q2 → WAIT user → RATIFY Q2 → ...
```

### Batch RDR (BIP — Batch Interactivity Protocol)

A cluster of independent decisions in the same dependency tier, resolved through an interleaved sequential dialogue but saved atomically per tier. Use when:
- `/setup --init` gathering project configuration (tier = dependency group).
- Decisions within the tier do not affect each other's option sets.

**Flow:**
```
GENERATE complete batch {Q1, Q2, ..., QN} for tier T with RDR recommendations + Conditional Navigation Matrix
POSE Q1 → WAIT user → CAPTURE → POSE Q2 → WAIT user → CAPTURE → ... → POSE QN → WAIT user → CAPTURE
RATIFY tier-atomic: save ALL tier decisions to artifact in one write
ADVANCE to next tier (re-harvest if any pivotal Q was overridden)
```

Even in Batch mode, the user sees **one question at a time** — the batching is internal to the agent (it pre-computes the whole tier so Conditional Navigation can short-circuit dependent questions). Ratification is tier-atomic, not per-question.

Canonical Batch implementation: [Factory-setup-discovery.instructions.md](../../instructions/Factory-setup-discovery.instructions.md).

---

## When to Trigger RDR

| Trigger | Agent | Mode | Artifact |
|---------|-------|------|----------|
| Project configuration discovery | SETUP `--init` | Batch (tier-atomic) | `docs/setup.md` |
| Ambiguous placeholder during materialization | SETUP `--generate` | Sequential | materialization report |
| Framework convention ambiguity (e.g. `src/` vs `app/`) | SETUP `--generate` | Sequential | materialization report |
| Feature scope / vision decisions | CODESIGN `--start`, `--vision` | Sequential | `spec.feature`, `user_journey.md` |
| Design alternatives with ≥2 viable paths | BLUEPRINT `--start` | Sequential | `design.md` |
| Analysis confidence < 80% | AUDIT `--audit` | Sequential | `technical_due.md` |
| Environment / infra choices | DEVOPS `--configure` | Sequential | `devops_plan.md` |
| Peer review decisions | REVIEW | Sequential | `review_*.md` |

If the trigger you face is not listed but meets the core principle (agent needs user judgement between alternatives), use RDR. If the decision is purely mechanical (one correct answer derivable from existing artifacts), do NOT use RDR — just proceed and state the derivation.

---

## Anti-Patterns (VIOLATIONS)

| Anti-pattern | Why it's a violation | Correct behaviour |
|--------------|---------------------|-------------------|
| Single-option question ("Shall we use PostgreSQL?") | Coercion, not choice | Offer ≥3 options with recommendation |
| Recommendation without justification | User cannot evaluate agent's reasoning | Ground recommendation in setup.md / rules / industry default |
| Paraphrased `user_choice` | Loses verbatim intent | Capture exact string |
| Ratification deferred to "end of section" | Violates IPP — summarization loses decision | Persist in the same turn |
| Decision recorded only in conversation | Not recoverable after summarization | Persist to `_progress.decisions[]` AND inline comment |
| Multiple decisions in one question | User cannot ratify them independently | Split into sequential RDRs |
| Skipped RDR because "obvious" | Bypasses user agency | If ≥2 viable options exist, RDR is mandatory |
| Options framed only positively (no AGAINST) | User cannot weigh the real tradeoff | Run the [adversarial double pass](../factory-adversarial-reasoning/SKILL.md); each option carries its counter-case |
| "Registration" used as the third R | Terminology drift | Canonical third beat is **Ratification** (persistence + artifact commit) |

---

## Relationship to Other Protocols

| Protocol | Relationship |
|----------|--------------|
| **IPP (factory-incremental-persistence)** | RDR Beat 3 (Ratification) IS an invocation of IPP Decision Persistence. Every RDR decision triggers an immediate section-atomic save. |
| **L-03 One Question at a Time Gate** | Sequential RDR satisfies L-03. Batch RDR satisfies L-03 at the user-facing layer (one question per turn) while pre-computing the tier internally. |
| **GCRP (factory-governance-loading)** | Recommendation justifications cite governance context loaded by GCRP. Ratified decisions become inputs to future governance snapshots. |
| **CVP (factory-coherence-validation)** | Ratified decisions persisted via RDR are the ground truth CVP checks across artifacts. Missing RDR trail = lower coherence confidence. |
| **ACP (factory-agent-communication)** | ACP structures HOW the agent speaks to the user during RDR; RDR structures WHAT is being asked / chosen / persisted. Orthogonal. |
| **Adversarial Reasoning (factory-adversarial-reasoning)** | Feeds RDR Beat 1: options, recommendation, and tradeoffs are the output of the FOR/AGAINST double pass. RDR ratifies; adversarial reasons. |

---

## Context Budget

```yaml
CONTEXT BUDGET:
  Per RDR entry in _progress.decisions[]: ~80-150 tokens
  Per inline RDR comment: ~20 tokens
  Per RDR recommendation block presented to user: ~120-200 tokens (question + 3 options + justifications)
  Total overhead per decision: <400 tokens
  # Long-term cost is minimal: _progress.decisions[] persists but inline comments are the primary trail.
  # On finalization (status → APPROVED), _progress is cleared; inline comments remain for traceability.
```

---

## Enforcement

This protocol is **MANDATORY** for ALL agents posing decisions to the user. Violations:
- Presenting a decision with fewer than 3 options without justifying the degenerate case → **VIOLATION**
- Omitting the recommendation to appear neutral → **VIOLATION**
- Failing to persist a ratified decision in the same turn → **VIOLATION**
- Paraphrasing `user_choice` instead of capturing verbatim → **VIOLATION**
- Using "Registration" as the third R in agent-facing prose → **VIOLATION** (terminology drift)
- Bypassing RDR because "the answer is obvious" when ≥2 viable options exist → **VIOLATION**

Enforcement is currently **prompt-level** (agents self-comply by reading this skill). A future deterministic gate may inspect `_progress.decisions[]` for malformed entries post-command.
