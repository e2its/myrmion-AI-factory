---
id: ADR-EVOL-058
title: A critic's turn budget is enforced, not requested — the orchestrator owns the hand-back, the correctness critic probes only what its finding names
date: 2026-10-06
status: accepted
---

# ADR-EVOL-058: A critic's turn budget is enforced, not requested

## Context

Issue #93, axis L of the 2026-10 evolution (#91). Downstream, with the per-spawn policy of EVOL-049, the correctness critic exhausted its turn budget without a report in every sub-PR of one train and the security critic in a third of them; the budget travelled as a sentence of the spawn prompt, an agent does not count its turns, and recovery was a manual message to the same agent. In this framework the policy (`rules/agents.md`) carries no turn budget at all: a size tier is files and lines, nothing bounds how long a critic may probe, and nothing says what happens when it does not deliver. Verified before design (the harness's own documentation, read by the reader agent): a subagent definition may declare `maxTurns` — when reached, the harness stops the agent, marks its result partial and lets the parent resume it with a message; the Agent tool itself takes no turn or token bound; a running agent can be messaged (`SendMessage`), a message is read between its tool calls and enforced by the agent's reasoning, never a hard stop. Critics in this framework are read-only by tool matrix — a "probe" is an execution the main session runs on a finding's behalf, never the critic's own.

Execution delegated by the user (2026-10-06); agent-internal choices under the rules of transfer of #91.

## Decision

- **Two keys per size tier, in the one policy home.** `agents.tiers.<small|medium|large>` gains `turn_budget` (the turns a critic may spend per round) and `probe_budget` (the executions the main session may run on that critic's behalf per round); `medium` becomes an explicit tier (its files and lines are the bounds of the other two). The resolver (`gate.py agents --resolve`) returns both with the model and the effort; an unmeasured size (tier `unknown`) is held to the large tier's budgets — never starved, never unbounded. The validator (`gate.py agents`) refuses a tier without either key or with a value that is not a positive integer. No digit lives in prose: the template rule carries the defaults, a project edits its keys.
- **The hard stop is the harness's.** Every read-only roster definition (`plan-critic`, `work-critic`, `reader`) declares `maxTurns` equal to the large tier's `turn_budget` — the ceiling the harness enforces by stopping the agent and marking its return partial; the validator refuses a read-only definition without it or with another value (a definition that writes declares none: the writer cap is axis P's). The resolved per-tier budget is the contract below the ceiling, stated on the first lines of the spawn prompt (`effort:`, `turn budget:`, `probe budget:`).
- **The orchestrator owns the hand-back.** At every critic spawn site the main session, on a partial return (the ceiling reached) or on a return that is not a report, sends **one** hand-back request to the same agent — write the report now with what is verified, the rest as unverified — and resumes it; a critic that still does not deliver counts as **fully unverified** (every finding `❓`, the round recorded as not delivered), never as silence and never as clean. The text lives once in the policy (`rules/agents.md § The bounded loop`) and is pointed at from the four spawn sites.
- **The correctness critic probes, it does not re-verify.** The whole suite is green from the loop that precedes the round (EVOL-051); a probe is bounded to the test a finding names, at most `probe_budget` executions per critic per round, run by the main session; re-running the suite for a critic is forbidden in the critic's definition and in the engine's spawn contract.
- **The report.** The measurement subproduct's agents table gains `turns` (the assistant entries of the sub-agent's own transcript) and the ceiling it was held to; critics delivered inside the ceiling per round are counted; the before/after protocol gains the signal.

Risk: `maxTurns` is a harness feature of a given version; a harness without it falls back to the orchestrator's message alone — the validator still requires the key (the contract is declared), and the policy says the ceiling is advisory there.

## Consequences

- `rules/agents.md` 1.2.0 → 1.3.0 (keys, the hand-back, the probe rule); the five read-only definitions (`maxTurns`, the probe rule in the correctness critic) on both lock-step sides; `scripts/gates/agents.py` (budgets, validator, resolver) both sides; `scripts/gates/test_gates.py` both sides; the four spawn sites (`Factory-implement-review-checks`, `factory-code-review`, `factory-preventive-sweep`, `Factory-blueprint-design`); `measure.py` + `RUNBOOK.md`; `scripts/materialize-synthetic.sh`; both `CLAUDE.md` (the agents row); `framework_version` 8.5.0 → **8.6.0**.

## Alternatives considered

- **A wall-clock timer in the orchestrator** — rejected: a critic's turns are not time; the harness counts turns and stops at the ceiling, the orchestrator only has to answer the partial.
- **A second round for an exhausted critic** — rejected: `rounds.work` is one; an exhausted critic is adjudicated as unverified, the loop still ends in the user.
- **Pinning the budget in each definition** — rejected: one key per tier in the policy; the definition carries only the ceiling the harness needs.

## Operational Rule

No universal sentence changes. The body of the agents policy (`rules/agents.md`) gains the tier budgets, the hand-back and the probe rule; both `CLAUDE.md` sides name the enforced budgets in the agents row. Recorded on the class policy's rule.

## Verification record

Filled at the close of the branch.
