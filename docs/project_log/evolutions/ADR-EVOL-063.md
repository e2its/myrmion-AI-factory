---
id: ADR-EVOL-063
title: "Compact at 300k — a project ships autoCompactWindow so a long session stops re-reading up to a million tokens per turn"
date: 2026-10-07
status: accepted
---

# ADR-EVOL-063: Compact at 300k

## Context

Issue #106. Every turn re-sends the whole context; a native 1M-window model compacts by default at about 967 k tokens (<https://code.claude.com/docs/en/model-config#default-auto-compact-thresholds>). Measured downstream (104 main sessions, 38.5 k assistant turns, usage de-duplicated per message id): context re-read 17.97 G tokens (cache-read 17.82 G), cache-creation 152 M, output 42.7 M; session floor (first-turn context) p50 69 k; context per turn p50 454 k, p75 636 k, p95 860 k, 87 % of turns above 200 k; 28 compactions, median pre-compaction size 967 k. A replay of the measured per-turn growth under a lower window (reset to ~95 k after each compaction: floor + summary): 200 k −68 % re-read, 704 compactions; **300 k −58 %, 346**; 400 k −49 %, 220; 500 k −40 %, 152. Those sessions predate EVOL-062 (a fresh session per sub-increment), so the saving on a current project is smaller; the phase sessions and the orchestrating main session stay long and keep most of it.

EVOL-062 bounded a writer's turns, a session's span and a tool result's size; nothing bounds the main conversation's context, and the framework ships no compaction window.

## Decision

RDR 2026-10-07 — options 300 k / 400 k / 200 k / no default; the user's verbatim choice: **"A. 300k (Recommended)"**.

- **The key** — `"autoCompactWindow": 300000` in the project template `.context/templates/setup/claude/settings.json` and in this repository's `.claude/settings.json`. The harness setting (tokens, 100 000–1 000 000, accepted in any settings file, capped at the model's window). Project scope outranks user scope, so a developer's `~/.claude/settings.json` value and a `/autocompact` value (saved to user settings) do not override it; `.claude/settings.local.json`, `--autocompact` and `CLAUDE_CODE_AUTO_COMPACT_WINDOW` do — the project ships a default, the developer keeps a local way out. On a 200 k-window model the cap makes it a no-op.
- **One home** — `settings.json` is the key's only home: the harness reads it there. No copy in `config/quality.json` or in the spawn policy (a copy would owe a parity check for a digit the harness already reads).
- **Upgrade** — `merge-preserve` (`Factory-setup-upgrade.instructions.md`, `Factory-setup-materialization.instructions.md`) gains one rule: add `autoCompactWindow` from the template when absent; never overwrite a value the project set. Every other top-level key stays untouched.
- **Proof** — the synthetic materialisation asserts the key lands at 300 000.

Risk: more compactions per session lose detail mid-work — covered by what already survives a compaction: the PreCompact → UserPromptSubmit governance re-injection, IPP resume-on-entry, RDR's immediate persistence; an RDR still awaiting its answer is what a compaction can cost. Risk: the window may not apply to subagents (the documentation names `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` for both, the window key for neither) — subagents rarely reach 300 k (EVOL-058/062 bound their turns).

## Consequences

- A fresh `SETUP --generate` lands the key; `SETUP --upgrade` adds it to an existing project's settings and keeps a value the project set.
- Before/after is the adopting project's act (the `measure` subproduct: median context per session, cache-read per session); this repository claims no baseline.
- `framework_version` MINOR (a new shipped default).

## Alternatives considered

- **The `env` block** (`CLAUDE_CODE_AUTO_COMPACT_WINDOW` / `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` in `settings.json`) — rejected: an `env` value in `settings.json` is reported ignored by the auto-compact logic (anthropics/claude-code#63186, closed not planned); the setting key is the documented path for a settings file.
- **400 k / 200 k / no default** — the RDR's other options: 400 k saves less (−49 %); 200 k compacts about every 55 turns and cuts long work; no default saves nothing for whoever does not read the documentation.
- **The digit as a spawn-policy key with a parity check** — rejected (DC-29): the harness's own key is the data home; a second home owes a check and saves nothing.
- **A "Compact Instructions" section in CLAUDE.md** — rejected: no official backing; the governance re-injection already restores the law after a compaction.

## Operational Rule

No universal sentence changes. The Core Protocols row on the agent policy names the compaction window beside the context diet (both `CLAUDE.md`); the upgrade's `merge-preserve` gains the one-key rule.

## Verification record

Red-first: `materialize-synthetic.sh` against the template without the key — 108 passed, 1 failed (`autoCompactWindow not shipped`); with the key — 109 passed. Suites on the delivered bytes: test-hooks 121, test-gates OK, lock-step 76 / 16, validate-governance, check-adr-constitution-sync, manifest-parity (35 compared), the static round (15 members) — green. The manifest's seven entries and `framework_version` 8.10.0 → 8.11.0 written by `gate.py manifest --bump` (EVOL-061). The `merge-preserve` rule is an instruction the upgrade agent executes — no code path to test; its proof is the adopting project's first `--upgrade`.

**Round 1 (sonnet, `max`, tier medium — 9 files, ~85 lines).** Correctness, fidelity, governance, security: no findings. Informational cured in the act (mechanical, the written default of `rules/agents.md § The bounded loop`): the precedence statement — project scope outranks user scope, so a `~/.claude/settings.json` or `/autocompact` value does not override the key, `.claude/settings.local.json`, `--autocompact` and the variable do; the upgrade's "NEVER touch … any other top-level key" names its one exception; the materialisation's idempotency line names the key; the synthetic assertion pins the type (`int 300000`). Left informational: the seven changelog lines carry the feature sentence (the `gate.py manifest --bump` shape); the external and downstream figures are cited, not re-measured here; the `merge-preserve` rule has no code path to test.
