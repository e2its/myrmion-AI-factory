---
id: ADR-EVOL-035
title: Adversarial Reasoning model — mandatory FOR/AGAINST double pass before any proposal
date: 2026-06-15
status: accepted
---

# ADR-EVOL-035: Adversarial Reasoning model — mandatory FOR/AGAINST double pass before any proposal

## Context

The framework mandates RDR for every user-facing decision (CLAUDE.md § RDR Universal) but RDR only ever frames options **positively** — Beat 1 alternatives carry a "when it would be preferred" rationale, never a "why this could be wrong". A repo-wide scan (`adversarial`, `steelman`, `devil`, `counter-argument`, `reasons against`) returned **zero** matches in `.claude/` and `docs/`. The "main tradeoff" mention in § RDR Universal is the only adversarial residue, and it is singular and optional.

The user asked for a thinking discipline broader than RDR: before selecting or proposing any alternative, weigh the reasons **for** it AND the reasons **against** it, tested against (a) the SDLC governance (constitution, rules, DCs, knowledge MCPs) and (b) the product being built and its objectives — then present via the usual flow. This applies to "cualquier cosa" — not just user questions, but agent-internal picks too.

## Decision

Ship a dedicated always-on skill plus a short constitutional anchor.

- **New skill `factory-adversarial-reasoning`** (`applicable_when: always`). Canonical mechanics of the FOR/AGAINST double pass: Pass 1 (FOR), Pass 2 (AGAINST across the governance axis and the product axis), output routing (feed RDR for user decisions; one-line stated rationale for agent-internal picks), scope gate (trivial/mechanical skip; non-trivial mandatory), anti-patterns, protocol relationships. Surfaced in every command Roll-Call via ADP because it is `always`.
- **New universal CLAUDE.md section `## Adversarial Reasoning — MANDATORY`** — ~4-line constitutional anchor pointing to the skill. **Universal** (applies downstream too): mirrored byte-identical into `.context/templates/setup/claude/CLAUDE.md` and registered in `config/coherence-context.json § lock_step_pairs` `universal_sections` so `check-lockstep-pairs.sh` enforces parity.
- **factory-rdr wiring** — Beat 1 gains a one-line note that options/recommendation/tradeoffs are the OUTPUT of the adversarial double pass; one anti-pattern row ("options framed only positively") and one relationship row added. No duplication of mechanics — the skill owns the reasoning, RDR owns ratification.

Risk: Low. Additive; no contract broken. Reversible.

## RDR Decisions Ratified (2026-06-15)

| # | Question | Choice | Rationale |
|---|---|---|---|
| 1 | Where does the adversarial model live? | New always-on skill `factory-adversarial-reasoning` + short universal anchor in CLAUDE.md (user 4th-option override of the original "detail in factory-rdr" recommendation) | Adversarial reasoning ≠ RDR-only; it applies to agent-internal choices too ("cualquier cosa"). A dedicated `always` skill is surfaced by ADP every command; the short anchor keeps it constitutional without bloating per-agent context (lean-file rule). |

## Alternatives Considered

- Alternative 1 — Detail inside `factory-rdr` only (original agent recommendation): rejected — scopes adversarial reasoning to user-facing decisions, missing agent-internal picks the user explicitly wants covered.
- Alternative 2 — Full adversarial spec inline in CLAUDE.md: rejected — bloats the file loaded into every agent context (violates lean-file discipline).
- Alternative 3 — Skill only, no universal clause: rejected — not constitutional; relies solely on ADP discovery, weaker anchor than a `[LAW]`-adjacent universal section.

## Consequences

**Positives:**
- Every proposal/selection now carries its own counter-case across two fixed axes (governance + product) — plausible-but-wrong recommendations are caught before they reach the user.
- Always-on via ADP Roll-Call; no per-command opt-in.
- Lean: bulk lives in an on-demand skill; CLAUDE.md grows by ~4 lines.
- Universal — ships to materialised projects via sync; SDLC governance + product objectives apply downstream identically.

**Negatives / Trade-offs:**
- One more universal lock-step section to keep byte-identical (meta ↔ template). Mitigated: enforced mechanically by `check-lockstep-pairs.sh`.
- Two artefacts touch decision-making (skill + RDR). Mitigated: strict ownership split — skill reasons, RDR ratifies; RDR references, never duplicates.

## Compliance

- Generation Standards §2: every framework-core file touched bumped + changelog line added in the same commit (CLAUDE.md, template claude/CLAUDE.md, factory-rdr SKILL, new factory-adversarial-reasoning SKILL, framework_version).
- Pre-Action Gate: shipped on `feature/EVOL-035-adversarial-reasoning` off `origin/main`.
- RDR Universal: decision ratified verbatim (user 4th-option override) and persisted here.
- Constitutional Supremacy: this ADR's acceptance adds the universal `## Adversarial Reasoning — MANDATORY` section to CLAUDE.md (and template mirror) in the same PR.
- Lock-step: new universal section registered in `coherence-context.json § universal_sections`; parity gated by `check-lockstep-pairs.sh`.

## Operational Rule

```
Before proposing or selecting any non-trivial alternative, every agent and
free-form turn MUST run a FOR/AGAINST double pass: argue why the option fits,
then argue why it could be wrong across two axes — (a) SDLC governance
(constitution / [LAW], .claude/rules/, defect-prevention DCs, knowledge MCPs)
and (b) the product and its objectives. A recommendation that does not survive
its own AGAINST is not the recommendation. Only after both passes is the choice
presented via the normal flow: RDR for a user decision, a one-line stated
rationale (pick + surviving risk) for an agent-internal choice. Trivial /
mechanical choices (one correct answer) skip the pass.

Canonical mechanics: .claude/skills/factory-adversarial-reasoning/SKILL.md
(applicable_when: always; surfaced in every command Roll-Call via ADP; feeds
factory-rdr Beat 1). This rule is UNIVERSAL — mirrored byte-identical in
.context/templates/setup/claude/CLAUDE.md and shipped to materialised projects.
```

## Constitution Amendment

> **MANDATORY when this ADR transitions to `status: accepted`** (Governance Rule 1 — CLAUDE.md). The same PR that flips `status:` to `accepted` MUST apply the edit below. CI gate `scripts/check-adr-constitution-sync.sh` blocks the PR if no governance source is in the diff alongside the status flip.

- **Section affected:** `CLAUDE.md` (meta) — new universal section `## Adversarial Reasoning — MANDATORY` inserted after `## RDR Universal — MANDATORY`, before `## Governance Scope — MANDATORY`.
- **Before:** § RDR Universal was followed directly by § Governance Scope.
- **After:** § Adversarial Reasoning — MANDATORY inserted between them.
- **Template mirror:** YES — `.context/templates/setup/claude/CLAUDE.md` receives the byte-identical section (universal branch of "What Lives Where"). Registered in `config/coherence-context.json § lock_step_pairs` `universal_sections`.
- **Constitution version bump:** none (this `meta` repo has no `docs/constitution.md`; universal/meta law lives in `CLAUDE.md`). The `framework_version` bump in `governance_versions.json` carries the cross-reference.
