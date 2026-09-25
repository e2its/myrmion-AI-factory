---
id: ADR-EVOL-050
title: RDR in two registers — a plain-language explanation first, then the technical decision
date: 2026-09-25
status: accepted
---

# ADR-EVOL-050: RDR in two registers

## Context

Issue #59, axis I of the 2026-09 evolution (#50). In the reference implementation the person deciding product, scope and process asked more than once to "explain it first for non-technical people, then the technical options"; decisions posed only in the technical register had to be posed again, and one recommendation built on a technically correct but misleading aggregate was caught only once a plain-language framing made the trade-off visible. Decision authority delegated by the user on 2026-09-25 ("las rdrs son tuyas hasta el final").

## Decision

Agent-internal choices (pick + surviving risk):

- **Protocol text only, no gate.** The RDR skill gains § Two Registers (order, content of each register, agreement rule, scope) and two anti-patterns; both `CLAUDE.md` sides gain one mirrored paragraph in § RDR Universal. Rejected: a deterministic validator over `_progress.decisions[]` — the plain section is prose; a gate would check its presence, not its quality, and the issue scopes "no new gate".
- **Language rule.** The plain section follows the project language of the person deciding; technical identifiers stay as they are. Risk: a bilingual RDR in mixed-language projects; accepted, the skill already binds the project language.
- **Budget line updated** (≈ +100 tokens per RDR). One extra paragraph per decision costs less than one extra round.

## Consequences

- Every RDR posed anywhere (commands, plan-mode queues, free-form turns, sub-agents returning open decisions) opens in plain language. Malformed = registers disagree.
- `framework_version` 6.2.1 → **6.3.0** (MINOR — additive; branch `feature/EVOL-050-rdr-two-registers`).
- No new LAW; § RDR Universal is amended on both lock-step sides (universal_clause_mirror verified).

## Alternatives considered

Plain section optional, at the agent's judgement — rejected: the measured cost is the re-posed decision, and judgement is what failed. Plain section after the technical one — rejected: the reader who needs it stops reading before it. A separate "explain" sub-command — rejected: one more round by construction.

## Operational Rule

Amendment shipped in this PR to `CLAUDE.md` § RDR Universal (meta) and its byte-identical mirror in the project `CLAUDE.md` template: two registers in this order, agreement rule, scope.

## Verification record

`scripts/check-lockstep-pairs.sh` (universal_clause_mirror: § RDR Universal identical on both sides), `scripts/check-applicability-frontmatter.sh`, `scripts/validate-governance.sh --base main`, full T2 suite. Prompt-level protocol; no runtime test applies.
