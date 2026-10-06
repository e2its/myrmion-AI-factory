---
id: ADR-EVOL-060
title: "Informational findings stay off the return — the orchestrator adjudicates critical and warning, the rest lives in the round artefact"
date: 2026-10-06
status: accepted
---

# ADR-EVOL-060: Informational findings stay off the return

## Context

Issue #95, axis N of the 2026-10 evolution (#91). Downstream, over 118 branches with a critic round: 39 critical · 462 warning · 893 informational — 64 % of every finding informational. The severity bar (EVOL-049, `rules/agents.md § Severity bar`) already says what they are: a finding rises above informational only by naming a concrete path to the product or to the machinery; what names no path is, by law, never cured. Yet they travel: the return contract sends every finding to the orchestrator, which reads, classifies and summarises each one — returns of 4–10 KB per lens, four lenses per round — and output tokens per product line rose 2.5× between the two measured windows.

A critic is read-only by construction (`Read, Grep, Glob`: it cannot write an artefact). The orchestrator must not read what it will never adjudicate. The channel changes, not the definition.

Execution delegated by the user (2026-10-06); agent-internal choices under the rules of transfer of #91.

## Decision

- **The return has two parts.** The **contract part** — the findings above informational (`🔴`, `🟡`, and `❓` for an unverified one) in the one line shape, then `## Governance` with its lines and a new line `Informational: N` — is what the orchestrator reads, holds to the contract and adjudicates. The **appendix** — a trailing `## Informational` section after the governance block, every informational finding in full in the same line shape (file, line, the rule id or defect class it rests on) — is what the orchestrator **never parses**: it is copied verbatim into the round artefact. Nothing is deleted; nothing informational is adjudicated.
- **The return check refuses an informational finding inside the contract part** (`gate.py agents --check-return --class work-critic` / `plan-critic`): a `🟢` line before `## Governance` is refused ("informational inside findings — it belongs under `## Informational`"); the `Informational: N` line is required for a critic and `N` must equal the count of `🟢` lines in the appendix (a count that does not match is a refusal — a critic that hides or inflates). An appendix line outside the shape is refused like any finding. A return with no finding above informational still says `no findings` in its contract part.
- **The round artefact keeps everything.** Branch mode (the push gate's Block 20): every delivered return is appended verbatim to `.claude/state/code-review-<content_hash>.returns.md`, beside the marker and with its lifecycle. Increment mode (IMPLEMENT): the peer review artefact (`peer_review_*.md`, Template B) gains § Critic returns with the same verbatim copies. The marker's `counts.nit` is the sum of the `Informational: N` lines — the orchestrator counts, never reads. The canary's judge reads the whole return (it looks for planted defects above informational; an appendix line never credits one).
- **The five critic definitions** (the four work critics and the plan critic, both lock-step sides) state the two-part shape; the rule's § Return contracts carries it; the engine's `normalise` reads the contract part only.
- **The measurement subproduct keeps counting from the artefact — no figure changes** and the protocol's signal list gains two: `return_bytes_adjudicated` (the contract part's bytes, what the orchestrator read) beside `return_bytes` (the whole return), and `informational_count` (the sum of the `Informational:` lines); `orchestrator_tokens_out_per_round` is the output of every session that spawned a critic over its distinct (session, round) pairs — the whole session's output, a coarse figure comparable before and after on the same project (the round-bounded figure is a later refinement of the instrument). Before/after is the adopting project's window, as every evolution of this train.
- **Scope boundaries.** The severity bar does not move: no operational sentence changes. A critical or warning misfiled as informational was already a critic defect; the canary (EVOL-059) measures it — the canary's expected findings are all above informational, so a lens that files a planted defect under `## Informational` is red.

Risk: a critic that pads the appendix costs bytes nobody reads; the count line and the measurement make it visible, the severity bar makes it a defect. Risk: a harness that truncates a long return cuts the appendix first (it trails) — the contract part survives, the count still says how many were owed.

## Consequences

- Upgrade (`Factory-setup-upgrade.instructions.md` Step 8): the five critic definitions and `scripts/gates/agents.py` arrive with the gates refresh; a project whose critics still return the one-part shape sees its returns refused with the reason — the next spawn carries the new definitions. The measurement subproduct reads old and new returns alike.
- `framework_version` 8.7.0 → 8.8.0 (MINOR: a new contract part, new signals).

## Alternatives considered

- **Drop informational findings entirely** — rejected: the issue says nothing is deleted; the measurement (EVOL-042) and the severity bar's calibration need them.
- **Give critics a write tool for the artefact** — rejected: a critic cannot write by construction (EVOL-049; the harness matrix is the guarantee); the orchestrator copies without reading instead.
- **A separate artefact per critic written by the engine from a structured return (JSON)** — rejected (DC-29): the line shape is the one contract every reader and the measurement already parse; a second format is a second reader.

## Operational Rule

No universal sentence changes. The body of the agents policy (`rules/agents.md § Return contracts`) gains the two-part shape and the `Informational:` line; the engine and the IMPLEMENT review carry the artefact; the severity bar is untouched.

## Verification record

`scripts/test-gates.sh` (63 — `Agents`: an informational finding before the governance block refused; the two-part shape passes; the count held to the appendix's length, never less, never more; a warning hidden in the appendix refused; the `Informational:` line owed by every critic; `no findings` with an appendix; `split_return` on both shapes and on a phrase that only looks like the heading; every critic fixture carries the count line). `scripts/materialize-synthetic.sh` (103 — the red and the green on the materialised tree). `scripts/test-measure.sh` (25 — the contract part against the whole return, the count from the governance line, the signals in the before/after table, the orchestrator's output per critic round). `test-hooks` 107, `test-code-review-gate` 17, lock-step 74 / 16, validate-governance, manifest-parity, templates-static, ADR sync, applicability, one-definition, budget, retired-terms, runtime-surface — green.

**Round 1 (sonnet, `max`, tier medium — the first round under the two-part contract this change ships; every return in the new shape).** Above informational, cured: the `Model:` line was read from the tail of the whole text — an appendix line mentioning the governance heading moved the split and a well-formed return was refused (`governance_block()` reads the contract part, the heading is a line of its own); the engine's artefact path used a hash it had not bound (bound once at the top in branch mode; the artefact appended under a timestamp, its lifecycle said: local, gitignored, one file per hash, never rotated); a legacy one-part return read as zero informational findings in the before window (the inline `🟢` lines are counted where they are); the orchestrator's output per critic round defined as implemented (the spawning sessions' whole output over their rounds — a coarse figure, comparable on the same project) and pinned to its number; the `split_return` pins that did not discriminate their guards (the heading as a line of its own; `## Informational` before the governance block refused as inside the findings; a `🟢` after the block under no heading said as such); an appendix line outside the shape pinned; an appendix line held to the probe like any finding; the spawn directive names the two-part shape; the plan gate's appendix has a home (`plan_critic_{timestamp}.md`), the sweep reads the contract part and keeps the returns under § Critic returns, the peer review template carries § 2b; `nit` counts the appendix plus this engine's demotions; the judge reads the contract part. Informational and left: the orchestrator's verbatim copy regenerates the return as output tokens (the saving is in what it adjudicates, not in what it writes — the signal will say); the IMPLEMENT per-phase returns are copied at the peer review's creation, not per phase; `nit` counts per return, not per deduplicated defect.

**Round 2** — recorded below.
