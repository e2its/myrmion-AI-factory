---
id: ADR-EVOL-135
title: "Relayed ratification — a relay keeps the person's verbatim words and names itself, approvals never relay, a project's delegation law read from its accepted ADR"
date: 2026-11-20
status: accepted
---

# ADR-EVOL-135: Relayed ratification

## Context

This ADR plans issue #243 (epic #112, wave 5, destination S). It is follow-up C of spike #139 (ADR-EVOL-085). It was checked on `origin/main` at framework 10.12.0 (ffae566).

- **A coordinator session relays choices.** One person, a coordinator session and squad sessions work in parallel. The person answers in the coordinator's window, and the coordinator carries the answer to a squad session. Today no record tells a relayed answer from a typed one, and nothing refuses a relay that carries a summary instead of the person's words.
- **One reader judges ratification.** `scripts/gates/aligned.py` `ratification()` reads each `accepted-change` entry the change adds to `docs/project_log/features/{FEAT}.log.jsonl`. The entry carries exactly one of `rdr` (the verbatim choice) or `delegation` ({quote, date}). The RDR skill writes `_progress.decisions[]` with `user_choice`, and no gate reads it.
- **Approvals.**
  - The plan approval is written only by the harness (`record-plan-approval.sh` → `planning.record()`), which refuses a non-interactive mode and a transcript without the tool use. A peer session cannot produce it.
  - BLUEPRINT `--approve` writes `action: "--approve {FEAT}"` to the decision log. Nothing says who typed it.
  - Harness prompts and permission denials are answered in the harness's own window. The framework ships no hook on them.
- **Delegation.** A project may grant a standing delegation as its own law. The mirrored «RDR Universal» clause of both `CLAUDE.md` files says "No exceptions", so a project that delegates edits a framework-shipped file. The owner's scope ruling (RDR-4 «2», 2026-11-18) keeps delegation each project's own law. The framework ships none.
- **The one reader of a project ADR's acceptance** is `data._accepted()` (`scripts/gates/data.py`), already reused by `performance.py`.

## Decision

1. **A relay names itself and keeps the words.**
   - The RDR record (one that carries `user_choice`: a `_progress.decisions[]` entry, or an RDR line of the decision log such as `BLUEPRINT.increment_plan.rdr_ratified`) and the `accepted-change` entry may carry `relay: "<session that carried the words>"`, next to `user_choice` / `rdr`.
   - A relay copies the person's words between «», never a summary. A bare option id is verbatim (RDR Beat 2), a number included.
   - `relay` is a free session name with no registry.
   - A record without `relay` is a direct answer, so every existing record stays valid.
2. **A relay without verbatim words authorises nothing.**
   - `gate.py aligned` is red when an `accepted-change` entry carries `relay` with no `rdr`. It is red even when the entry carries a `delegation`: a delegation is the project's own act, and it is never relayed.
   - It is red on the same condition for an RDR record (a changed artefact's `_progress.decisions[]` entry, or a decision-log line the change adds) that carries `relay` and has no `user_choice`, and for one that carries both `relay` and `delegation`.
   - It is red when `relay` is empty or not a string.
3. **Approvals are typed in the deciding session's own window and are never relayed.**
   - Plan, BLUEPRINT, any plan exception a project reserves, every harness approval and every permission denial.
   - `relay` and `delegation` are valid only on the records of item 1. Any other decision-log line the change adds that carries either is red, and so is a line that carries either and is not JSON. This positive list names no project concept in code (LAW-07).
   - The plan approval is the harness's own marker (`record-plan-approval.sh`): it never reaches a decision log, and a peer cannot write it. The gate covers what reaches a log.
   - A peer session's message never answers an RDR, an approval or a permission prompt (`rules/agents.md` § No agent ratifies).
   - A delegation never covers an approval: BLUEPRINT `--approve` is the mandatory manual checkpoint.
4. **A project's delegation law is read, never shipped.**
   - `delegation` may name the accepted project ADR that grants it: `delegation: {quote, date, adr}`, on an accepted change (in place of `rdr`) or on an RDR record (beside the option taken, `user_choice`).
   - `gate.py aligned` reads that ADR through `data._accepted()` when the record is added. It is red when the ADR is missing or not accepted, and red when `adr` is not a project ADR id (a feature's FDR), because delegation is project law.
   - A record an earlier change added was judged at its own push: `_backed()`, the tracker's `--aligns` and an unchanged `_progress.decisions[]` entry already at the base re-read its `adr` for its shape only. A delegation ADR superseded later never un-ratifies the decisions taken under it.
   - A `delegation` with no `adr` stays valid as before.
   - The mirrored «RDR Universal» clause of both `CLAUDE.md` files gains one sentence: a relayed answer counts only with the person's verbatim words and the relay named; a project's accepted delegation ADR is honoured; approvals are never relayed. So no project edits a framework-shipped file to delegate.
5. **No new command, flag, member or permission hook.** The checks live in the existing `aligned` member. The harness keeps its prompts in its own window, and the text states that limit.

## Consequences

- The RDR skill gains § «Relay and delegation (EVOL-135)», the record fields, the inline-comment form and two anti-patterns. `rules/branching.md` [LAW-17], `factory-worklog`, `Factory-implement-build`, `Factory-blueprint-validation` and `rules/agents.md` state the same rules.
- **Honest limits.**
  - The gate cannot tell a paraphrase from verbatim words.
  - It trusts the session to declare a relay under the exact key `relay`, and an RDR record by its `user_choice`. A transcript check (`notebook.author()`) would be stronger, but CI cannot see another clone's transcript.
  - It reads that the named ADR is an accepted project ADR, not that it grants this class of decision.
  - The plan-approval marker's own guard is unchanged.
  - `data._accepted()` now reads only regular files, so a record named after a device is never opened.
- **Upgrade.** `SETUP --upgrade` and `factory-sync.sh` deliver it. No record is migrated.

## Verification

- **Unit tests (red first):**
  - a relay without words;
  - a relay with a delegation and no words;
  - an empty relay;
  - a relayed approval line (`--approve` and a project's plan exception), a delegated approval line, a non-JSON relayed line;
  - a relayed RDR record, in `_progress.decisions[]` and on a decision-log line, a bare numeric option id included;
  - `delegation.adr`: missing, proposed, accepted, FDR, absent; on an RDR decision too;
  - an earlier delegated entry keeps backing its claims once its ADR is superseded, and an earlier delegated decision is not re-judged when its artefact changes; the tracker's `--aligns` judges the `adr` shape;
  - a record named after a device (a FIFO) is never opened.
- **Synthetic materialisation with `--answers`:**
  - a relayed record without words is red;
  - a relayed approval is red;
  - a project ADR granting delegation is read (green when accepted, red when proposed);
  - the shipped framework files stay byte-identical.
- **Gates:** lock-step twins identical, manifest bumped.
