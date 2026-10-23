---
id: ADR-EVOL-115
title: "Reliability is planned up front"
date: 2026-10-23
status: accepted
---

# ADR-EVOL-115: Reliability is planned up front

## Context

This ADR implements issue #184 (epic #112, train row 5e, after #162 / ADR-EVOL-104). It was verified on `main` at framework 8.19.0.

- **Premises.** The plan critic (`factory-plan-critic`) asks a source for every written premise. A premise that nobody wrote is never asked. The design template's `## Reliability Contract` lists mechanisms (idempotency, retry, breaker, timeouts), not the questions whose answers reopen design.
- **Security level.** No SETUP answer names a security standard or level. The discovery registry has only the scanner and its threshold.
- **Contracts.** No script reads a contract at the freeze. Comparing raised statuses with declared ones is #124's parity reader (owner RDR «1», 2026-10-23, recorded on #124 and #184).
- **Seams.** The increment plan has no seam map. A split can separate a use case from its handler and its integration test.
- **Routing.** Work routed into a sub does not re-measure the sub's estimate. That estimate is written only at Step B.4.
- **Sub count.** Nothing records the sub count ratified at the split. A train can open more subs than it ratified, with no decision.
- **Defect class.** The class «a stub outlives its producer» has no row.

## Decision

1. **A closed reliability question set.** It lives in the design template, `## Reliability Questions`: one row per capability with a security or availability weight, and one column per question.
   - **RQ-1:** what each credential or factor change does to live sessions and tokens.
   - **RQ-2:** the provider's lockout and rate-limit semantics.
   - **RQ-3:** token lifetime and revocation.
   - **RQ-4:** the recovery flows.
   - **RQ-5:** what each operation returns when a dependency is down.

   Each cell holds an answer and its cited source. The template maps every question to the requirement of the declared standard and level. A project adds questions only through the discovery registry, never in prose.
2. **The standard and level are a registry question.** A new question sets `security.standard` (`asvs-5.0` | `none`) and `security.level` (`L1` | `L2` | `L3`, asked only when a standard is set). It goes through the registry parity of `gate.py discovery` (EVOL-102). An upgrade asks it as a pending question.
3. **One reader: `scripts/gates/freeze.py`.** It is lock-step with its template, runs as `gate.py freeze`, and is a light and full profile member. It judges the `design.md` and `contracts/openapi/**` files the diff changes. It reports red when:
   - (a) a weighted capability's question has no answer or no source;
   - (b) an OpenAPI operation does not declare the outage response (`config/quality.json → contracts.outage_status`);
   - (c) a property marked `x-sensitive` (any value but false) carries no constraint (`maxLength`, `pattern`, `enum`, `format`, `minimum` or `maximum`).

   The weight vocabulary is closed: `security`, `availability`, `both`, `none`; any other word is red. A design without `## Reliability Questions`, or with a header the reader does not recognise, reports `n/a` with its reason, never an ok note (owner RDR «1», 2026-10-23, after the round-1 correctness and security critics: «1»).

   The plan critic reports an unanswered question as CRITICAL. Its freeze checklist asks «every raised status declared» until #124's reader lands. A contract bump inside a train is a plan finding in the measure.
4. **Risk-first order.** The split puts first the subs that carry the integrations whose premises can fail: an external provider, permissions, contracts, data migrations. Presentation work follows. Step B.4 orders this, and the plan critic checks it.
5. **A seam map in the plan.** The increment-plan template gains `## Seam map`, one row per use case: handler, permission grant and route, integration test, client, end-to-end case, and its `sub`. A row may name `closes: SUB-…` for the client and end-to-end columns, and `stub until SUB-…`. `gate.py train` (ADR-EVOL-104) gains these red clauses:
   - (d) a row's use case, handler or integration test is not covered by its `sub`'s `paths`;
   - (e) a row still says `stub until SUB-x` once SUB-x is `MERGED`;
   - (f) a sub's `tasks` differ from the task set its estimate `measured` (a routing that did not re-measure);
   - (g) the subs outnumber the INC's `Ratified sub-increments` (a re-plan by file, through the split's RDR, raises it).

   The routing notice to the person carries the new figure, the delta, and the train total with its unique paths, all from `gate.py train --figures`.
6. **The defect class enters the catalog.** DC-35 «a stub outlives its producer» (family `process`) is gated by `gate.py train` (e). It passes the promotion procedure of `rules/defect-prevention.md`: row and case in one change.
7. **Measured.** Per train, `measure` reports:
   - the subs at ratification against the subs delivered;
   - the paths in more than one sub (ADR-EVOL-104);
   - the routings and their re-estimates (worklog `IMPLEMENT.train.routed`);
   - the premises found by critics against those found at design (worklog `premise_found`, `origin`);
   - the contract bumps inside the train.

## Consequences

- The questions that reopen design are answered before the first sub. The plan critic sees a blank answer, not a missing one.
- Raised ⊆ declared stays a checklist item until #124. This intermediate state is stated on both issues.
- One more SETUP question, asked as a pending question on upgrade.

## Alternatives considered

- **A free-prose premise list per project.** It grows unchecked, and the issue forbids it. Rejected.
- **The contract parity reader here.** It is #124's (owner RDR «1»). Rejected.
- **A separate seam checker.** The seam map lives in the increment plan, so the one reader of that plan checks it. Rejected (DC-29).

## Operational Rule

No new law. The bodies of `rules/vertical-slicing.md` and `rules/defect-prevention.md` are edited (rule-file edits plus a manifest bump).

## Verification record

Red first, then green.
- `test_gates.py::Freeze`:
  - (a) a blank answer and a blank source;
  - (b) an operation without the outage response;
  - (c) a sensitive field without a constraint;
  - n/a without a changed design or contract.
- `test_gates.py::Train`:
  - (d) a use case split from its handler;
  - (e) a stub past its merged sub;
  - (f) a routed task whose estimate did not re-measure;
  - (g) more subs than ratified.
- `gate.py discovery` is green with the new question.
- The measure selftest is red first on the five train figures.
