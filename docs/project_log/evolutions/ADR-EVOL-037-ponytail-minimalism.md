---
id: ADR-EVOL-037
title: Ponytail minimalism — do-less discipline as DC-29 + adversarial lens + BVL advisory
date: 2026-06-22
status: accepted
---

# ADR-EVOL-037: Ponytail minimalism discipline

## Context

The framework prevents defects, enforces DRY (CIP), and caps cyclomatic complexity (DC-28), but had **no first-class minimalism discipline**. CIP says "reuse what exists"; DC-28 caps the complexity of code that exists. Neither asks the prior question: *should this code exist at all?* The LLM reflexively over-builds — speculative abstractions, wrappers, config flags, unneeded dependencies, boilerplate the task never requested.

The user surfaced the open-source skill **ponytail** (`DietrichGebert/ponytail`, MIT) — a "laziest senior dev" discipline that forces the simplest solution via a YAGNI decision ladder (necessity → stdlib → native → installed dep → one-liner → minimal code) plus a 4-category over-engineering review (reinvented stdlib, unneeded dependency, single-implementation abstraction, dead flexibility). Headline metrics: ~54% less code, ~20% cheaper, ~27% faster, safety maintained.

The integration question: **where** does this belong in a governed pipeline, and **how much** of ponytail to absorb?

## Decision

Absorb the *idea*, not the *code*. The value is the discipline; importing 6 ponytail commands would duplicate logic, bloat downstream agent context, and clash with the framework's hard-law culture. Encode it **once** as a DC and reference it from the layers where it applies — DRY single-source.

- **DC-29** (NEW) in `defect-prevention.md` — single source of truth: the YAGNI ladder + 4 over-engineering categories + the **how-not-what scope guardrail**. Severity WARNING (advisory). `applicable_to: CODESIGN, BLUEPRINT, IMPLEMENT, REVIEW, AUDIT`, all feature scopes. Complements DC-28: DC-28 is quantitative on written code, DC-29 questions build-vs-no-build before the code exists.
- **factory-adversarial-reasoning** — NEW always-on **do-less lens** on every AGAINST pass (decision-time, all phases). This is the cost-saver: the token never spent is the code never generated. Cites DC-29; mechanics not duplicated.
- **factory-build-verification** — NEW `full_verification_gate` Step 8 minimalism advisory (build-time, IMPLEMENT). LLM self-scan of `scope_files` for the 4 categories. Advisory fail-open, **never blocks**, skips silently when the catalog is absent. The late quality net for reflexive line-level bloat the adversarial lens cannot perceive as a decision.

**Scope guardrail (how, not what):** the discipline argues a simpler *implementation*; it NEVER cuts *specified scope*. A scope reduction is an RDR decision routed to CODESIGN, never a silent omission. Validation, error handling, security, accessibility are never simplified. This neutralises the only governance conflict — spec-as-contract supremacy.

**Lifecycle tiling:** adversarial (prevention, all phases, saves tokens) + BVL (detection, IMPLEMENT, recovers LOC). They overlap little and cover the lifecycle.

## Alternatives considered

- **Import the ponytail repo wholesale (6 commands + skills)** — Discarded. Two instruction philosophies (soft persona vs hard law) confuse the agent; duplicates logic across 3 places (drift); bloats downstream context (violates the lean-artefact principle); each skill would still need `applicable_when` + manifest entries + ADR. Copy-paste is not integration.
- **Add a minimalism axis to factory-pr-review (the user's initial "que también")** — Discarded after adversarial review. The pr-review SKILL explicitly declares `defect-prevention.md` as **NOT consumed** ("defect prevention is a design-and-build-time concern, not a push-time one") and defends a one-rule-file-one-primary-consumer invariant. A DC-29 push-time axis breaks that boundary and is redundant with DC-28 + the BVL step that already ran at IMPLEMENT. Push-time minimalism is also too late — the value was prevention. Risk accepted: no push-time minimalism net; mitigated because adversarial (prevention) + BVL (build) tile before push.
- **BVL minimalism step as blocking / soft-block** — Discarded via RDR. Minimalism is subjective; blocking a build on "you could shrink this" is a costly false-positive and breaks "BVL enhances, not blocks". User ratified advisory fail-open.
- **A standalone Governance LAW for minimalism (DC-28/LAW-11 precedent)** — Discarded. DC-28 earned a LAW because it is a hard quantitative gate; DC-29 is advisory. A standalone LAW over-weights an advisory discipline and bloats the constitution. The do-less lens is genuinely a *facet of the existing adversarial mandate*, so the constitution amendment extends that section (one sentence) rather than minting a new LAW — the leanest honest amendment (do-less applied to its own rollout; EVOL-036 precedent: no new LAW, extend an existing section).

## RDR Decisions Ratified (2026-06-22)

| # | Question | Choice |
|---|----------|--------|
| A | BVL minimalism step force | **Advisory fail-open** (never blocks; mirrors DC-28 fail-open) |
| B | Adversarial do-less lens scope | **Always-on, how-not-what** (all phases; argues implementation, never cuts specified scope) |

## Consequences

**Positives:**
- Fills a genuine gap (anti-over-engineering as a first-class discipline) without new external dependencies.
- Single source (DC-29); three reference points (adversarial, BVL, snapshot embed) — DRY, no drift.
- Cost-saving lands at decision-time (prevention) where tokens are actually saved, not just post-hoc LOC recovery.
- Defense-in-depth: prevention (adversarial, all phases) + detection (BVL, IMPLEMENT).
- Spec-as-contract preserved by the how-not-what guardrail; the lens can never silently cut scope.
- Lean: one DC, one lens sentence, one BVL step, one constitution sentence. No command bloat downstream.

**Negatives / Trade-offs:**
- No push-time (pr-review) minimalism net by deliberate choice — relies on the upstream layers having run.
- BVL Step 8 is an LLM self-scan (no MCP), so quality is judgment-bound and non-deterministic; advisory status contains the blast radius.
- DC-29 only embeds in the governance snapshot for projects whose snapshot regenerates after `SETUP --upgrade`; until then the catalog entry is present but not snapshot-cached.

## Compliance

- ✅ Generation Standards #2: every framework-core / template file touched bumped + changelog in the same commit. `framework_version` 5.5.0 → 5.6.0 (`feat:`, MINOR — additive).
- ✅ Pre-Action Gate: shipped on `feature/EVOL-037-ponytail-minimalism` off `origin/main`.
- ✅ RDR Universal: 2 decisions ratified by the user verbatim (table above); persistence = this ADR + commit + manifest.
- ✅ Adversarial Reasoning: FOR/AGAINST run on placement (pr-review dropped after its own AGAINST), on blocking force, and on LAW-vs-no-LAW. The recommendation survived its AGAINST.
- ✅ Constitutional Supremacy: this ADR's amendment extends § Adversarial Reasoning — MANDATORY in both CLAUDE.md files (byte-identical universal_section, gated by check-lockstep-pairs.sh). No new LAW.
- ✅ Communication Style: framework artefact bodies stay caveman + free of version/EVOL refs; the why-of-change lives in this ADR + commit + manifest changelog.

## Operational Rule

```
Over-engineering is a cataloged defect class (DC-29, WARNING). Before writing code,
walk the YAGNI ladder and stop at the first viable rung: need-to-exist → stdlib →
native platform → installed dependency → one-liner → minimal code. Flag the four
over-engineering categories: reinvented stdlib, unneeded dependency, single-
implementation abstraction, dead flexibility.

The discipline argues a simpler implementation (the HOW), NEVER cuts specified scope
(the WHAT) — a scope reduction is an RDR decision routed to CODESIGN, never a silent
omission. Input validation, error handling, security, accessibility are never
simplified. Deliberate shortcuts are marked with a `ponytail:` comment naming the
ceiling + upgrade path.

factory-adversarial-reasoning runs the always-on do-less lens on every AGAINST pass
(decision-time, all phases). BVL full_verification_gate Step 8 runs the minimalism
advisory self-scan on changed source files (build-time, IMPLEMENT) — advisory
fail-open, never blocks. No push-time (pr-review) consumer by design.
```

## Constitution Amendment

> **MANDATORY when this ADR transitions to `status: accepted`** (Governance Rule 1 — CLAUDE.md).
> The same PR that flips `status:` to `accepted` applies the edit below to the governance source. CI gate `scripts/check-adr-constitution-sync.sh` blocks the PR if no governance source is in the diff alongside the status flip.

- **Section affected:** `## Adversarial Reasoning — MANDATORY` in `CLAUDE.md` (root meta) and `.context/templates/setup/claude/CLAUDE.md` (template). One sentence appended to the AGAINST-pass description introducing the always-on do-less lens (DC-29).
- **Before:** the AGAINST pass tested two axes (governance, product) only.
- **After:** the AGAINST pass also runs the always-on do-less lens — argue simpler implementation (how), never cut specified scope (what; scope cut routes to CODESIGN via RDR).
- **No new LAW.** The do-less lens is a facet of the existing adversarial mandate (EVOL-036 precedent: extend an existing section rather than mint a LAW).
- **Lock-step:** this is a `universal_clause_mirror` section — both files edited byte-identical, verified by `scripts/check-lockstep-pairs.sh`.
- **Constitution version bump:** none (meta repo has no `docs/constitution.md`; universal law lives in `CLAUDE.md`). `framework_version` 5.5.0 → 5.6.0 carries the cross-reference.
