---
name: factory-adversarial-reasoning
description: "Factory Adversarial Reasoning — mandatory FOR/AGAINST double pass on any proposed or selected alternative, weighed against SDLC governance (constitution, rules, defect-prevention DCs, knowledge MCPs) and the product + its objectives, before presenting via the normal flow. Use when: any agent or free-form turn proposes, selects, or recommends an option — user-facing decision (feeds RDR) or agent-internal choice."
applicable_when:
  always: true
---

# ADVERSARIAL REASONING

> **Shared Protocol** — applies to ALL turns and agents. Pairs with [factory-rdr](../factory-rdr/SKILL.md) (user-facing decisions) and ADP Roll-Call (always-on surfacing).

**Core Principle:** No alternative is proposed or picked until it survives its own counter-case. Argue FOR. Then argue AGAINST. Only then present.

## The Double Pass

Run before every proposal or selection — user-facing (RDR) or agent-internal (silent pick).

### Pass 1 — FOR

Why this option fits. Ground in: project context, product goal, prior decisions, industry default.

### Pass 2 — AGAINST

Why this option could be wrong. Test across TWO axes:

1. **SDLC governance** — constitution / `[LAW]`, `.claude/rules/`, defect-prevention DCs, knowledge MCPs (context7, aws-knowledge, …). Does it break a law, a protected path, DRY, security, a DC?
2. **Product + objectives** — the feature's user value, scope, roadmap, NFRs. Does it miss the goal, add scope, hurt UX, raise cost or risk?

A recommendation that does not survive its own AGAINST is not the recommendation. Switch it, or state why the FOR wins despite the AGAINST.

## Output

- **User-facing decision** → feed both passes into [factory-rdr](../factory-rdr/SKILL.md): each option carries its FOR (when preferred) AND its AGAINST (main tradeoff vs governance + product). The recommendation names why it wins despite its own AGAINST.
- **Agent-internal choice (no user question)** → state the pick in one line with the surviving risk named ("chose X; risk Y accepted because Z"). No silent picks on non-trivial choices.

## Scope

| Choice | Adversarial pass |
|---|---|
| Trivial / mechanical (one correct answer, typo, format) | skip — no alternatives, no pass |
| Non-trivial (≥2 viable options: design, scope, naming, approach) | mandatory |

## Anti-Patterns (VIOLATIONS)

| Anti-pattern | Correct |
|---|---|
| Options framed only positively (no AGAINST) | Every option carries its counter-case |
| AGAINST ignores governance OR product axis | Test both axes |
| Recommendation fails its own AGAINST, presented anyway | Switch, or justify why FOR wins |
| Silent agent-internal pick on a non-trivial choice | State pick + surviving risk |

## Relationship to Other Protocols

| Protocol | Relationship |
|---|---|
| **RDR** ([factory-rdr](../factory-rdr/SKILL.md)) | Adversarial pass FEEDS RDR Beat 1: options, recommendation, and tradeoffs are its output. RDR ratifies; this skill reasons. |
| **ADP** ([factory-applicability-discovery](../factory-applicability-discovery/SKILL.md)) | `always: true` → surfaced in every command Roll-Call. |
| **Defect Prevention (DCs)** | The AGAINST governance axis scans active DCs as counter-evidence. |
