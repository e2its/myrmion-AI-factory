---
id: ADR-EVOL-085
title: "Team mode: one standing owner per surface in the SCM platform's own code-owners file, ids no other branch can take, version counters re-derived by the second to land"
date: 2026-11-19
status: proposed
---

# ADR-EVOL-085: Team mode — multi-author state, ownership by surface

## Context

This spike answers issue #139 (epic #112, wave 5). It was checked against branch `feature/EVOL-084-design-system-catalog`, at framework 10.9.0. It is read-only: no framework change.

**Today: single author.**
- **Locks are local to one clone.**
  - The skill describes locks keyed by feature, epic, environment or audit, with a 24-hour auto-removal (`.claude/skills/factory-branching-strategy/SKILL.md:15-50`).
  - The hook that actually runs keys the lock by **branch**, holds the PID of one machine and checks it with `kill -0` (`.claude/hooks/check-concurrency-lock.sh:6-8,46-60`).
  - The lock directory is gitignored (`.gitignore:63`), so a second person on another clone never sees the lock.
  - Nothing deletes a lock. The framework repo's own `.context/locks/` holds about 100 files from branches merged long ago.
  - The rule "one increment branch per feature at a time" rests on that lock (`rules/branching.md:64`, under `.context/templates/setup/`). Between people it has no reach.
- **Sequential ids collide across branches.**
  - ADR: `N = max(existing)+1`; a collision is retried once with N+1 (`.claude/skills/factory-adr-management/SKILL.md:51,67`). That retry only sees the local tree.
  - The same pattern holds for PDC, "highest PDC + 1" (`rules/defect-prevention.md:82`; `Factory-backlog-operations.instructions.md:245`), and for `FEAT-NNN` (Q27.4, `Factory-backlog-operations.instructions.md:45`).
  - An ADR is one file per number. Two branches therefore write `ADR-0030-a.md` and `ADR-0030-b.md` with **no textual conflict**.
  - The PR needs no up-to-date base: "require branches to be up to date: off" (`scm/protection.github.md:15`). Both PRs go green, and the duplicate reaches main.
  - No gate checks ADR uniqueness. `freeze.py:51` only parses `ADR-\d+`.
- **Where duplicates are already red:**
  - PDC (`scripts/gates/corpus.py:289`);
  - test-case ids (`scripts/gates/traceability.py:185`);
  - tracker items (`scripts/gates/tracker.py:175-181`).
- **Ids already qualified by their scope, so collision-free by construction:**
  - an accepted change is `AC-{FEAT}-{N}`, logged in the feature's own worklog (`rules/branching.md:181`);
  - worklogs are one file per feature (`.claude/skills/factory-worklog/SKILL.md:24-29`);
  - the data gate already accepts alphanumeric record ids (`scripts/gates/data.py:61`).
- **Version counters are already computed against the base.**
  - `gate.py manifest --bump` is idempotent against the base manifest (`scripts/gates/manifest.py:8`).
  - It refuses a bump that would not pass the base's version — "rebase first" (`:268`).
  - A downstream measurement (comment on #139) confirms the field rule *second-lands-absorbs*: the train that reaches main second absorbs main, re-bumps against it, and takes main's number for a contract semver both trains used.
- **Ownership by surface covers agents only.**
  - The roster maps surfaces to agents (`rules/agents.md:66-80`).
  - For people there is only a count, `scm.approvals`: Q21.2, registry `discovery_registry.json:1464-1469`, "0 for a single author" (`config/quality.json:229` in the template; `scripts/gates/scm.py:7`).
  - No template, runbook or gate mentions a code-owners file (grep over `.claude`, `.context/templates`, `scripts`: none).
  - `scm.py:365` already treats self-review as a note: "a solo maintainer needs it, a team sets prevent_self_review".
- **One answer home.** Every answer lives in `docs/setup.md` frontmatter (ADR-EVOL-102 §3, #159).

**Owned elsewhere — not re-decided here:**
- **#153 (EVOL-096): where cross-branch state lives** (the tracker, main, the `none` fallback). Its design question 2 is still open: the issue body ratifies only RDR-1a/1b/1c, and no `ADR-EVOL-096` exists in `docs/project_log/evolutions/`.
- **#156 (EVOL-099): the one cross-branch channel**, with element reservations as its first user.
- **#159 (EVOL-102):** SETUP by modules (`--reconfigure`, phase 3) and `docs/setup.md` frontmatter as the only answer home.
- **#176 (EVOL-110):** proof on the commit.
- **#154 (EVOL-097):** element ids.
- **#141 (EVOL-087):** the shared inventory.
- **#172 / #173:** who builds each task. **#172 RDR-1 «1»:** no project mode key.

## Questions

1. **Derive state instead of editing it.** Settled by the SDLC; no RDR. Each kind of shared state a project edits today has one route:

   | State | Today | Route |
   |---|---|---|
   | Version counters (governance manifest, contract semver) | computed against the base (`manifest.py:8,268`) | already derived. Second-lands-absorbs becomes the written rule: re-run the bump against main after the rebase, never hand-merge a version. → follow-up B |
   | Board state with the `none` adapter (`docs/backlog/state.md`) | one shared file | **#153 RDR-3 / #156** — not here |
   | Who works a feature, across people | a local lock that cannot reach (`check-concurrency-lock.sh:46-60`) | the tracker's In Progress state, already written by `gate.py tracker --start` (`tracker.py` docstring), carried by #156's channel. The lock stays a same-clone session guard, and its description says so. → follow-up D |
   | Increment status, increment plan | feature-scoped, one branch at a time (`branching.md:64`) | single writer per feature; no change |
   | Code inventory, element ids | one JSON file per project | **#154 / #141** — not here |

2. **Fragments instead of one shared file.** Settled; no RDR.
   - `docs/setup.md` stays the one answer home. #159 has precedence, and an answer changes only through `--reconfigure`, one writer at a time.
   - Worklogs are already fragmented per feature.
   - No new fragmentation. The do-less lens finds no remaining shared file whose collision fragments would cure better than routes 1 and 3.
   - `.gitattributes merge=union` was considered and rejected. Git warns that it "tends to leave the added lines … in random order and the user should verify the result" (https://git-scm.com/docs/gitattributes). That makes it unreliable for any ordered file.
3. **Ids without collision.** Settled from precedent (`AC-{FEAT}-{N}`, qualified test-case ids); no RDR.
   - **A record born on a branch takes an id qualified by its owning scope**, so no other branch can take it: `ADR-{FEAT}-{N}`, and `FEAT` ids from the tracker key when a tracker exists.
   - **Ordinal indexes stay sequential:** `PLAW-NN`, `PDC-NN`, and `FEAT-NNN` with `none`.
     - Each lives in one shared file, so two branches adding one collide textually at the rebase.
     - A duplicate is red in the one reader, against the tree it is given (PDC already is).
   - **Existing ids are never renamed.** Readers accept both shapes (`freeze.py:51` must widen).
   - **Element ids are #154's.**
   - → follow-up B. If the owner contests the qualified ADR id, this becomes a queued RDR (one per turn).
4. **Standing ownership by surface, people included.** The open product choice → the RDR below.
5. **How team mode reaches a project.**
   - No mode key (#172 RDR-1).
   - Team is what earlier answers already say: `scm.approvals` ≠ 0.
   - One registry question, unlocked by `scm.approvals != 0`, asks for standing owners by surface. In the closed grammar, `!=` holds only for a key that holds an answer (ADR-EVOL-102 §2).
   - Everything else is framework core: ids, the second-lands rule, relayed ratification, the lock's stated reach.
6. **Not here:** proof on the commit (#176); where cross-branch state lives (#153); per-epic element claims (#156); `--reconfigure` (#159).

## Decision to take (RDR)

### In plain words

Cuando varias personas trabajan en el mismo proyecto, cada parte del producto (la parte de servidor, la de pantallas, la infraestructura, las pruebas…) necesita a alguien que responda por ella de forma estable. Esa persona o equipo revisa los cambios que tocan su parte y decide cuando hay que elegir algo de esa parte. Hoy el sistema solo sabe qué agente escribe en cada parte; de las personas solo sabe cuántas aprobaciones pide un cambio, no quién debe darlas. Lo decidimos ahora porque el trabajo en equipo es el siguiente paso, y las piezas que lo construyen necesitan saber dónde vive este dato.

1. **El fichero de responsables que ya usa la plataforma de código.** Se guarda en el propio repositorio, y la plataforma lo aplica sola: pide la revisión del responsable antes de aceptar un cambio. Coste: una plantilla por plataforma, una pregunta nueva en la configuración inicial (solo para equipos) y una comprobación automática. En una plataforma que no tiene ese fichero, el reparto se configura a mano siguiendo una guía. En planes gratuitos de algunas plataformas, la exigencia no se puede imponer y solo queda como aviso.
2. **Una lista propia en la configuración del proyecto, desde la que se genera el fichero de la plataforma.** Coste: lo mismo que la opción 1, más un generador. Además, la gente acaba editando el fichero de la plataforma a mano y la lista se queda atrás, con lo que habría dos sitios para el mismo dato.
3. **Añadir las personas a la lista que ya reparte el trabajo entre agentes.** Coste: mezcla dos cosas distintas, quién puede escribir y quién debe aprobar. Esa lista tiene partes compartidas por todos los revisores automáticos, y la plataforma no la entiende, así que nada la haría cumplir en el servidor.
4. **No construir nada más:** seguir contando aprobaciones y que cada equipo configure a mano su plataforma. Coste: cero de construcción. Pero no cubre lo que pide el encargo (responsables por parte), nadie comprueba que el reparto exista ni que siga siendo cierto, y el sistema no sabe a quién preguntar cuando hay que decidir.

Recomiendo la **1**: es lo que menos se construye sin dejar el encargo sin cumplir, y la propia plataforma hace cumplir la regla. El coste que asumimos es que en algunas plataformas o planes la regla solo puede verificarse como aviso, no imponerse.

### Technical

**Evidence (external).**
- **GitHub:** `CODEOWNERS` in `.github/`, the repository root or `docs/`, first found wins. The file of the PR's **base** branch applies. Owners need write access. "Require review from Code Owners" is a branch-protection and ruleset setting. Invalid lines are skipped, and the API lists the errors. https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
  - Private repositories need Pro, Team or Enterprise. `❓ unverified — external`: only an older Enterprise Server page states it.
- **GitLab:** `CODEOWNERS`, `docs/CODEOWNERS` or `.gitlab/CODEOWNERS`, first found wins. Premium or Ultimate only. https://docs.gitlab.com/user/project/codeowners/
- **Bitbucket Cloud:** `.bitbucket/CODEOWNERS`, read from the destination branch. It adds suggested reviewers automatically. https://support.atlassian.com/bitbucket-cloud/docs/set-up-and-use-code-owners/
  - A merge check that *requires* code-owner approval: `❓ unverified — external`.
- **Azure DevOps:** no file. The branch policy "Automatically include reviewers" takes a path filter, Required or Optional. https://learn.microsoft.com/en-us/azure/devops/repos/git/branch-policies
- **Other:** checklist only, as `protection.other.md` does today.

**Evidence (repo).**
- Approvals are already a Q21.2 answer, verified by `gate.py scm-protection` at `ci` (`scm.py:7,351-356`).
- A setting the platform does not expose is listed as `unverifiable`, never red (`scm.py:237-244`). That pattern fits GitLab Free.
- The runbooks are per platform (`.context/templates/setup/scm/protection.*.md`).

**Adversarial pass on option 1.**
- **FOR — governance:**
  - One home per concern (the platform file is the ownership home, and `docs/setup.md` holds only the answer that unlocks it).
  - The check is mechanical and server-side, through the existing `scm-protection` control point.
  - No mode key, no change to any gate's strength (#172 RDR-1).
  - No new command or flag (§4).
- **FOR — product:** teams already know the format, and the platform requests reviews natively. The main session can compute the owning role of a decision's surface with a script, so the RDR names who ratifies.
- **AGAINST — governance:**
  - (a) Azure DevOps has no file. Its policy lives in the server, so the runbook is the record and a reader there needs the API.
  - (b) A file of `@handles` can name persons. #159's premise is "a role, never a person, where an owner is asked", so owners must be teams or groups. A personal handle cannot be told from a group by syntax on every platform, so that is a recommendation, not a red check; an e-mail address, a personal datum, is red.
  - (c) The ownership file is a governed file, edited by PR like any other, so it needs its own planning carve-out or none. None is needed: it is a project artefact, not a gate input.
- **AGAINST — product:** on GitLab Free and Bitbucket the requirement may not be enforceable, so ownership degrades to suggested reviewers.
- **AGAINST — do-less lens:** option 4 builds nothing, but it fails the issue's WHAT ("ownership by surface that covers people").
  - Option 1 is the smallest that meets it: per platform, one template plus one runbook row; one registry entry; one check folded into the existing reader. No generator, no second map.
  - The recommendation survives.

| Option | Governance — pro | Governance — con | Product — pro | Product — con |
|---|---|---|---|---|
| 1 · platform code-owners file | one home; server-enforced; no mode key | Azure is policy, not file; persons vs roles | native reviews; RDR names owner role | GitLab Free / Bitbucket enforcement weak |
| 2 · map in config, file generated | config is gate-readable | two homes in practice; generator to keep | same as 1 | hand edits drift from the map |
| 3 · owners in the agent roster | one roster | mixes write policy with approval; `**` critic surfaces; not server-enforced | — | platform ignores it |
| 4 · nothing more | zero build | no check that ownership exists or holds | — | issue WHAT unmet; nobody to route a decision to |

**Recommendation: 1.**
- **Main tradeoff:** native server enforcement and no second map, in exchange for platform-dependent strength (enforced on GitHub and Azure; `unverifiable` where the tier does not expose it).
- **Surviving risk:** a team that names persons rather than groups. The runbook recommends groups, and only an e-mail address is red.

## Consequences (option 1 plus the settled answers)

- **What lands in a materialised project when `scm.approvals != 0`:**
  - the platform's code-owners file at its native path, seeded with one line per surface the roster already declares (`rules/agents.md:66-80`, writer surfaces), each owned by a role the team names;
  - for Azure DevOps, the runbook row "Automatically include reviewers" per surface;
  - the protection runbook row "require review from code owners".
- **Selected by:** Q21.2 `scm.platform`, which picks the template, and a new registry question unlocked by `scm.approvals != 0`. That question records only that standing owners exist; the owner list lives in the file.
- **Framework core, every project:**
  - branch-born ids qualified by scope, plus a duplicate check for the ordinal indexes;
  - the second-lands-absorbs rule for version counters;
  - relayed ratification across sessions;
  - the lock's stated reach.
- **Upgrade path:** `SETUP --upgrade` asks the new question (#159's generic upgrade, which reads `since`). Existing ADR numbers stay valid; readers accept both id shapes.
- **Synthetic proof:**
  - one fixture per `scm.platform` with `approvals: 2`, and one with `approvals: 0` where nothing lands;
  - a red fixture where an owner glob matches no tracked path;
  - a red fixture where two branches add the same ordinal id;
  - a fixture where two branch-born ADRs never collide.

## Follow-up issues

**A — Standing owners by surface, for people**
- **Goal:** Every surface of a team project has a standing owner the SCM platform knows, and the decisions on that surface are routed to that owner.
- **We want:**
  - the platform's own code-owners mechanism as the one home;
  - each owned pattern matching something tracked, and every writer surface owned;
  - the server requiring owner review where the platform can, and `unverifiable` where it cannot;
  - an RDR naming the owning role of the surface it decides, computed by a script.
- **We do not want:**
  - a second ownership map;
  - persons where a role will do, or an e-mail address in the file;
  - a mode key, or a gate softened for a solo project.
- **How it reaches a project:**
  - Selected by Q21.2 platform plus a new registry question when `scm.approvals != 0`.
  - What lands: the file at the platform path, or the Azure runbook row, plus the protection runbook row.
  - Upgrade: `--upgrade` asks it.
  - Proof: a fixture per platform, and a red unmatched glob.
- **Depends on:** #159 phase 1 (shipped, ADR-EVOL-102); #176 for the server verdict (phased: until #176 ships, the owner-review requirement is read by `scm-protection` only).

**B — Ids no other branch can take; counters re-derived by the second to land**
- **Goal:** Two branches never ship the same record id, and never hand-merge a version.
- **We want:**
  - records born on a branch take a scope-qualified id;
  - a duplicate ordinal id is red before merge;
  - the second branch to land re-derives every version counter (manifest, contract semver) against main;
  - existing ids kept.
- **We do not want:**
  - renaming shipped ids;
  - a reservation mechanism of our own (if one is ever needed, it is #156's channel);
  - element ids (#154).
- **How it reaches a project:**
  - Framework core; no question.
  - Upgrade: readers accept both shapes.
  - Proof: two-branch fixtures, one duplicate red and one ADR pair green.
- **Depends on:** none. Phase with #154: element ids stay #154's.

**C — Relayed ratification across sessions**
- **Goal:** When several sessions work in parallel, a person's decision reaches the deciding session intact, and approvals that only a person can give stay in that person's own window.
- **We want:**
  - a relayed choice keeps the verbatim words and names the relay;
  - harness approvals and permission denials are never relayed.
- **We do not want:**
  - an agent ratifying;
  - a peer session answering a permission prompt.
- **How it reaches a project:**
  - Framework core (RDR skill), no question.
  - Proof: a lint fixture where a relayed record without its verbatim words is red.
- **Depends on:** none.

**D — fix: the session lock says what it guards** (`fix/` branch, no EVOL)
- **Goal:** The lock's description matches the hook, a branch on one clone, and cross-person exclusivity points to the tracker's In Progress state.
- **We want:**
  - the skill aligned to `check-concurrency-lock.sh`;
  - an orphan lock of a merged branch removed.
- **We do not want:**
  - a cross-machine lock (that is #156's channel).
- **How it reaches a project:**
  - Framework core via `factory-sync.sh`.
  - Proof: a hook test that a dead PID's lock is reclaimed.
- **Depends on:** none.

## Honest limits

- **#153 RDR-3 is not yet ratified.** Route 1's board row and D's pointer depend on its answer. If #153 chooses a different home than the tracker, D's pointer moves with it.
- **Three external premises are unverified:**
  - GitHub CODEOWNERS on private repositories needs a paid plan;
  - Bitbucket Cloud cannot require code-owner approval in a merge check;
  - the exact GitLab Free behaviour beyond "Premium/Ultimate only".
- **Not measured:** how often branch-born ADR collisions occur in a downstream project. The evidence is structural, plus one downstream report of counter collisions.
- **Qualified ADR ids change a visible convention.** The owner may prefer sequential ids with a duplicate gate. That choice is queued as an RDR if contested.
