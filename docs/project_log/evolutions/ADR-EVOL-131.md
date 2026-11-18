---
id: ADR-EVOL-131
title: "Any answer — a tool the registry does not list is accepted, asked as free text where its list has a hole, and built to the same contract before anything lands"
date: 2026-11-18
status: accepted
---

# ADR-EVOL-131: Any answer

## Context

This ADR implements issue #228 (epic #151, P0). It was verified on `main` at framework 10.5.0 (6c23d8b).

### State today
- **The discovery instruction promises «Other (describe)» on every question.** See `Factory-setup-discovery.instructions.md` § Universal Option Protocol (4.1.1).
- **The resolver refuses every answer outside a closed list.**
  - `_check_answers` (`scripts/gates/discovery.py:425`) raises GateFault, so `gate.py discovery --resolve` exits 2 on any literal not in `options` / `options_by`.
  - The promise holds only where a list carries an `Other` literal: Q20 and Q21.2.
- **Dependent lists have holes.**
  - Q6 has no row for `.NET`, `Ruby`, `PHP`, `Rust` or `Elixir`.
  - Q10 and Q12 have no row for `Solid`.
  - `_offered_for` returns None there, so any answer is accepted, but nothing tells the agent to ask the question as free text.
- **The registry does not say which lists are market lists and which are framework vocabulary.**
  - Market lists name a tool or platform a team already uses: a runtime, a database or a CI.
  - Framework vocabulary is a closed set the gates read: a topology, a tier, a mode or a severity.
  - Today both are closed the same way.
- **One precedent already builds what is not modelled.** A stack with no `verification.gates` rows declares them at discovery. `--resolve` stops until they exist (`LOOP_PARTS` / `STOP`, `discovery.py:99`).
  - Other precedents warn without stopping: a tracker without a pack (`project_tracking.adapter`), a documents store (`documents.adapter = built`) and the end-to-end tool's adapter.

## Decision

1. **Every list declares its kind: `open: true | false`, mandatory on every `options` / `options_by` key spec.**
   - V1 is red when the field is missing or not a boolean, and when it sits on a `free` key.
   - **19 market lists are open:**
     - `backend.runtime`, `backend.framework`;
     - `frontend.framework`, `frontend.meta_framework`, `frontend.state_management`;
     - `database.primary.engine`, `database.secondary.engine`, `database.migrations_tool`, `database.cache.engine`;
     - `hosting.provider`, `hosting.deploy_tool`, `hosting.secrets_manager`;
     - `ci_cd.platform`, `scm.platform`;
     - `qa.browser_mcp`, `qa.dast_tool`;
     - `observability.monitoring`, `observability.error_tracking`, `observability.tracing`.
   - Every other list is vocabulary, which includes auth strategies, compliance and the security standard: none of them is a tool or platform.
   - The literals stay and act as suggestions, until #144 owns the recommendation.
2. **An open key admits a tool the registry does not know.**
   - `_check_answers` refuses a name only on a vocabulary key.
   - On an open key it refuses a literal the registry knows but pairs with another parent (Django under Node.js), so a mis-paired answer is still caught.
   - A name the registry does not know is accepted and persisted.
3. **`--resolve` reports what the answer owes, with no new flag:**
   - `unmodelled: [{key, answer, owes, templates}]`. An entry is listed for every answered open key whose value is no literal of the key. **owes** is the union of config pointers the key's shipped rows set. **templates** is the manifest entries whose `stack_conditional` names the key.
   - `free_text: [key]`: every owed `options_by` question whose parent's answer has no row. The agent asks it as free text. A key an earlier answer decides (`decided_by`) is never listed.
   - **A condition the unmodelled answer cannot judge is asked.** A question whose `when` names an unmodelled key is owed when some listed literal of that key would make it hold. Example: Q15.1 (migrations tool) is asked for CockroachDB, because its `when` lists the SQL engines.
4. **Same contract, same gate, nothing half-built.** This generalises the `verification.gates` precedent.
   - Each owed pointer is declared in `docs/setup.md` under the pointer itself, in a shipped row's shape.
   - `--resolve` stops while an owed pointer is undeclared or does not hold to the row shape V12 checks: gate rows, `mcp.servers` pinned and isolated, `defect_prevention.classes` ids. The materialisation does not run past a stop.
   - A declared value must also be of the kind the shipped rows carry: a list where they carry a list.
   - A declared pointer is merged into `configures` as the option's row would be. The same config keys are filled, and the same gates read them.
   - A pointer owed by two unmodelled answers (a runtime and a frontend both owe `verification.gates`) is declared once and merged once.
   - Covered literals are unchanged.
5. **Templates are owed by the materialisation, not judged by the resolver.** For each `templates` slot the agent builds the tool's equivalent in its idiom, from docs-reader facts, and records each built item with its source in `MATERIALIZATION_REPORT.md`.
   - The resolver cannot judge a CI pipeline for a platform it has never seen. The pointers carry the contract the gates read, and those are held mechanically.
   - A derived pack keyed on a listed stack (SAST, client bounds) behaves as it does for a listed stack without a pack today: the setup report says so.
6. **The UOP text and the registry agree, mechanically.**
   - 4.1.1 reads the registry's `open` field: an open list offers «Other — name the one you use», and a vocabulary list offers its literals only.
   - V6 is red when the instruction offers `Other` on a vocabulary key.
   - «Help me decide» stays on every question.

## Consequences

- An answer to a tool question is never refused because the registry does not list it. The project is built to the same contract as a covered tool, or `--resolve` says what is still owed.
- Vocabulary lists stay closed, and the validator holds every list to its declared kind.
- **Upgrade.**
  - The `open` field is registry-internal. No answer changes, and `SETUP --upgrade` reads the same answers.
  - The `Other` literals of Q20 and Q21.2 stay, so installed answers stay valid.
  - A project that picked a stand-in may re-answer through #159.
- **One home per concern.**
  - Admissibility lives in the registry `open` field.
  - #144 owns recommendations.
  - #219, #222 and #210 keep their families, whose keys are already `free` + `suggestions`.

## Alternatives considered

- **Refuse less: drop `_check_answers` for every list.** A vocabulary typo would pass silently, and the issue asks for vocabulary lists to stay closed.
- **Add `Other` to every market list as a literal.** It would carry no name, so the tool would be lost. The issue asks for the name the user gives.
- **A new `--unmodelled` flag or gate.** It would be a second reader of the same answers. Rejected under DC-29 and Generation Standards §4.
- **Hold the built templates mechanically.** No reader can judge a pipeline file for an unknown platform. Holding the pointers is what keeps the gates honest.

## Operational Rule

No new law. The discovery and materialisation instructions name the open lists and the build owed by an unmodelled answer.

## Verification record

Red first, then green. `test_gates.py::Discovery`, 80 tests:
- `test_open_key_admits_an_unmodelled_tool`: an outside answer on an open key is accepted and reported as unmodelled, with what it owes and the templates it skips. A manifest entry that names the key but lands anyway is no debt.
- `test_open_key_still_holds_a_known_literal_to_its_parent`: a mis-paired known literal still exits 2, with "belongs to another".
- `test_vocabulary_key_stays_closed`: a vocabulary key still exits 2. V1 is red on a missing, a non-boolean and a misplaced `open`, and on `Other` in a vocabulary list.
- `test_v6_the_option_protocol_reads_the_registry`: V6 is red when 4.1.1 does not read `open: true`.
- `test_free_text_dependents`: an unlisted parent and a row-less parent both put the dependent in `free_text`. A decided key is never listed.
- `test_unmodelled_owes_stop_until_declared`: an undeclared, a malformed and a wrong-kind pointer each stop, and a malformed row never lands. A declared pointer clears the stop and lands in `configures`.
- `test_a_condition_an_unmodelled_answer_cannot_judge_is_asked`: Q15.1 is pending for an unmodelled SQL engine.
- `test_one_declared_pointer_owed_twice_lands_once`.

Other checks:
- `gate.py discovery` is green on the shipped registry.
- Synthetic materialisation is green on 11 of 11 fixtures. `unmodelled.json` carries one unmodelled tool per family, built, and is green. `unmodelled-unbuilt.json` stops as expected.
- Mutation sweep of the new branches in a scratch copy: 28 of 28 mutants killed.

Honest limits:
- The templates an unmodelled tool owes are listed for the agent and recorded in the report. They are not judged mechanically.
- A pointer a shipped row sets to `null` cannot be told apart from one left unanswered.
