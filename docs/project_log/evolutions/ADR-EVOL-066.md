---
id: ADR-EVOL-066
title: "Defect-class intake — generic lessons enter the universal catalog, each with its gate"
date: 2026-10-21
status: accepted
---

# ADR-EVOL-066: Defect-class intake

## Context

This ADR implements issue #120 (epic #112, train row 5c). It was verified on `main` at framework 8.17.0.

- **The universal catalog holds five rows**: DC-18, DC-27, DC-28, DC-29 and DC-30 (`rules/defect-prevention.md`). A downstream instantiation catalogued about 31 more classes, and nine of them name no stack.
- **Ids collide.** A project numbers its own classes in the framework's sequence, at five sites with three formulas:
  - the rule body's Discovery Protocol and the preventive sweep use `DC-{last+1}`;
  - the retrospective uses `max+1`;
  - the build loop uses `existing_dcs.length+1`;
  - the seed numbers from 1 and skips a reserved list, which omits DC-30.

  So a project's next class takes the number of the framework's next universal row. The upgrade has no collision handling.
- **The parser is lax.** `corpus.catalog()` checks the column count, the family and the paths. It does not reject:
  - a duplicate id;
  - a severity or an agent outside the template's vocabulary;
  - a row without its case.

  A row whose id is mistyped is skipped silently.
- **A tool-bound row lands everywhere.** DC-18 (server-rendered hydration) lands in every project, server rendering or not.
- **The sweep text is stale.** The Discovery Protocol asks for a per-class search in the preventive-sweep skill. The skill derives every search from the row and its case.

## Decision

1. **Two namespaces.**
   - A universal class is `DC-NN` and takes the framework's own next number.
   - A project's own class is `PDC-NN`, as project law is `PLAW-NN`. This covers the starter seed at `--generate`, the Discovery Protocol, the retrospective and the build loop's proposal.
   - A fork's number is never an alias: a fork's numbering is not a compatibility contract.
   - Every minting site cites the Discovery Protocol and mints `PDC`.
   - Every reader names a class by its id as the catalog writes it, never by a `DC-` prefix on its number. An output format's `DC-{N}` stands for that id.
2. **A promotion procedure in the rule body.** A class becomes universal only when it is:
   - generic: it names no stack or cloud (checked against the discovery registry's vocabulary) and no domain (judged at review);
   - gated: its gate exists or is built in the same change. A class with no gate yet waits in the issue that builds its gate; that issue names the class and adds the row in its DoD;
   - novel: not a variant of an existing row;
   - numbered by the framework;
   - tool-bound only through the tool's registry option; a tool no registry question names waits for its question;
   - complete: its row and its case land in one change.
3. **The nine classes.**

   | Class | Outcome | Gate |
   |---|---|---|
   | Secret in the diff | **DC-31** | the `secrets` verification member, proven by its canary; the pre-push secret scan |
   | A deploying job blind to a source | **DC-32** | the `runtime-surface` parity member |
   | Phantom coverage | **DC-33** | the loop's per-file coverage table, which lists every runtime-surface file absent from the report |
   | Drift from the journey | **DC-34** | test-case traceability, plus the fidelity lens |
   | Verifying a fix by re-running everything | DC-30, unchanged (#118) | — |
   | Request validation not mirroring the contract | enters with #124 | — |
   | A stub that outlives its producer | enters with #184 (the seam map) | — |
   | A reference measured on one site, scored on several | enters with #127 | — |
   | A deploy reports success while the service does not start | enters with #135 (it owns the liveness probe) | — |

   - **DC-32 covers the deploying half.** The toolchain half (a non-deploying job's filter against what its compiler resolves) has no generic gate. It stays a project class, where the toolchain is known.
4. **Tool-bound rows are selected by the registry's `configures`**, the mechanism of EVOL-067, never by a field on the row.
   - The `frontend.pattern` options that render on the server (F2, F3, F4, F8) configure `defect_prevention.classes: ["DC-18"]`.
   - `gate.py discovery --resolve` returns `defect_classes`:
     - `drop`: the tool-bound ids the answers rule out; an id whose key is unanswered while questions are still pending is undecided and stays;
     - against a project, also `to_add`: the template rows it lacks;
     - `to_remove`: dropped rows it holds;
     - `collisions`: a template id it holds as another class, meaning neither the invariant nor the case title matches; a dropped id is the project's, never a collision.
   - In a project, a missing template catalog is a fault (deliver the templates first), never an empty delta.
5. **Checks.**
   - `corpus.catalog()` refuses, in every context:
     - an id that is neither `DC-NN` nor `PDC-NN`;
     - a duplicate id;
     - a severity outside BLOCKER and WARNING;
     - an empty agent list, or an agent outside the seven;
     - an empty invariant.
   - `gate.py discovery` V13 checks the template catalog in the framework repo:
     - every row is `DC-NN`, has a gate and has its case;
     - every case has its row;
     - every configured id exists;
     - a row no option configures names no registry stack or cloud label.
6. **Materialisation and upgrade.**
   - **`--generate`** numbers the seed `PDC-1…` and drops `defect_classes.drop` with its cases.
   - **`--upgrade`**:
     - lands `to_add`;
     - offers `to_remove` by RDR;
     - poses one RDR per collision: renumber the project's class to its next `PDC`, retire it into the universal row, or defer the universal row;
     - never touches a row outside the template.

## Consequences

- **Every future class enters without a collision.** A project materialised before keeps its `DC-NN` rows, and a collision with one of them reaches the person as an RDR.
- **The catalog parser blocks a malformed row.** This also applies in projects. A project row that was already malformed turns red with its repair named.
- **Out of scope:**
  - **The seed's 22 prose entries**, most with no gate, land as the project's own `PDC` rows. A follow-up evolution makes every framework-authored class either universal with its gate, tool-bound, or gone.
  - **A universal row a project already holds** keeps the additive merge, so a project's own gate is never overwritten.
- **The vocabulary check misses domain words.** Review judges them.

## Verification

- **Red first:**
  - **Parser:** a duplicate id, a bad severity, a bad agent and a mistyped id each block; a `PDC` row parses.
  - **V13:** fails for a missing case, a missing gate, a stack label on a universal row and an unknown configured id.
  - **`defect_classes`:** proves drop, to_add, to_remove and a collision.
- **Synthetic materialisations:**
  - with server rendering (default, `F2`), DC-18 lands;
  - without it (dotnet, `F1`), no DC-18 row and no DC-18 case land;
  - the upgrade fixture lacks DC-32 to DC-34 and holds its own `DC-31`, and `--resolve` lists `to_add` and the collision.
