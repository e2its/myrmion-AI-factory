---
id: ADR-EVOL-085
title: "Team mode: one person, a coordinator session and parallel squad sessions — ownership by feature through the tracker, relayed decisions verbatim, ids no other branch can take"
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

**Field evidence — the team a downstream project actually runs (read 2026-11-19).**
- **Who the team is.** One person, a coordinator session (the project manager), and two permanent squad sessions. Each squad works its own clone and its own train. The sessions talk through the harness's cross-session messages.
  - The coordinator received about 330 messages from the squads in one session and sent 380.
  - The person speaks to the coordinator; decisions and notices travel through it.
- **What each squad owns is a feature, not a code surface.** The person and the coordinator assign the order once, in one tracker item:
  - squad 1: features 002, 004, 005, 012;
  - squad 2: features 003, 011, 020.
  - Each squad's train touches every surface of its feature: backend, frontend, infrastructure, tests.
- **Who decides.** The project made it its own law by ADR (accepted 2026-11-18), after two months of a delegation exception kept outside its corpus. It has three deciders:
  - the session decides up to and including the merge, and records each rejected option with an anchored reason;
  - the coordinator decides a technical RDR that is lawful, not visible to users, involves no money, and follows a cited best practice;
  - the person keeps a closed reserved list.
  - About 25 sentences in 11 framework-shipped files said the opposite («zero authority», «always RDR to the user»), and the project aligned them in its own copy.
- **What is never relayed.** Plan, BLUEPRINT and `plan_exception` approvals are typed by the person in the squad's own window. Every other reserved act is posed by the coordinator and relayed with the person's verbatim words. A relay without verbatim words authorises nothing.
- **What the sessions needed and built themselves:**
  - a per-session notebook that survives compaction (#235 owns it here);
  - a goal reset for the squad at each new train;
  - the second-to-land rule for counters (comment on #139).
- **Locks.** Each squad is on its own clone, so the per-clone lock (`check-concurrency-lock.sh:46-60`) never sees the other squad. That is the same gap as two persons.
- **Persons.** No downstream project has more than one person deciding. The second downstream project's multi-author need is who builds each task (#172 RDR-1 «1», on hold), not code-surface review.

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
   | Who works a feature, across people or squad sessions | a local lock that cannot reach (`check-concurrency-lock.sh:46-60`) | the tracker's In Progress state, already written by `gate.py tracker --start` (`tracker.py` docstring), carried by #156's channel. The lock stays a same-clone session guard, and its description says so. → follow-up D |
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
4. **Standing ownership, people included.** Decided from the field evidence below (§ Decision); no RDR.
5. **How team mode reaches a project.**
   - No mode key (#172 RDR-1).
   - Team is what earlier answers already say: `scm.approvals` ≠ 0.
   - No new registry question: the team the field runs needs none.
   - Everything is framework core: ids, the second-lands rule, relayed ratification, the lock's stated reach.
6. **Not here:** proof on the commit (#176); where cross-branch state lives (#153); per-epic element claims (#156); `--reconfigure` (#159).

## Decision (field evidence)

**Ratification.** The owner, 2026-11-19, while the RDR for code-surface owners was pending: «en ⟨a downstream project⟩ estamos utilizando una sesion que hace de pm» and «Con eso debes tener informacion mas que de sobra». The draft RDR (platform code-owners file, map in config, owners in the agent roster, nothing) is withdrawn. The evidence answers the question it asked.

1. **Ownership is by feature, held by a session, recorded in the tracker.**
   - The owner of a feature in flight is the session that holds its train. The tracker's In Progress state, written by `gate.py tracker --start`, is the record, carried by #156's channel (route D).
   - Assigning features to sessions is the person's scope and calendar decision. A coordinator session may relay it, never take it.
   - The roster's surfaces stay what they are: which agent class writes where (`rules/agents.md:66-80`).
2. **No code-owners file, no new question, for now.** The field shows one person and no reviewer per surface.
   - The platform's code-owners mechanism stays the right home when a project has several persons who review by surface. The evidence for it is kept below.
   - It enters through #172, the any-author epic, as the person-side of a team, never as a second map. Until then, `scm.approvals` stays the count it is.
3. **Delegated decision authority stays project law.** A project may give a session or a coordinator authority by its own accepted ADR, as the field did.
   - The framework does not ship a delegation law. The owner's scope ruling of 2026-11-18 (RDR-4 «2») keeps autonomy rules out of framework content.
   - What the framework owes every project is that a relay never forges a decision (follow-up C).
4. **Relayed ratification is framework core** (follow-up C), shaped by the field:
   - a relay carries the person's verbatim words and names the relay;
   - plan, BLUEPRINT and `plan_exception` approvals, and every harness approval, are typed in the deciding session's own window and never relayed.
5. **Ids and counters** are unchanged from Questions 1 and 3 (follow-up B). Two parallel trains are exactly the case they cure.

**Adversarial pass.**
- **FOR — governance:**
  - one home per concern: the tracker for ownership, project law for delegation, the RDR skill for relays;
  - nothing new for a solo project;
  - no new command, flag or question.
- **FOR — product:** it builds for the team that exists. The field paid for every piece in its own copy, so each follow-up removes a fork point.
- **AGAINST — governance:** a project with several persons gets no surface review from the framework. Mitigation: the evidence and the home (#172) are written here; nothing blocks a team from adding the platform file by hand.
- **AGAINST — product:** n = 1 field team. Mitigation: each follow-up is small and stands on the existing tracker, RDR skill and gates. None assumes squads; one session is the degenerate case.
- **Do-less lens:** dropping the code-owners file, its templates, its runbook rows and its check is the smallest change the evidence allows. The recommendation survives.

**External evidence kept for #172 (code-owners per platform).**
- **GitHub:** `CODEOWNERS` in `.github/`, the root or `docs/`. The base branch's file applies, and owners need write access. "Require review from Code Owners" is a protection or ruleset setting. https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
- **GitLab:** `CODEOWNERS`, `docs/` or `.gitlab/`, Premium or Ultimate only. https://docs.gitlab.com/user/project/codeowners/
- **Bitbucket Cloud:** `.bitbucket/CODEOWNERS`, suggested reviewers. https://support.atlassian.com/bitbucket-cloud/docs/set-up-and-use-code-owners/
- **Azure DevOps:** branch policy "Automatically include reviewers" per path, with no file. https://learn.microsoft.com/en-us/azure/devops/repos/git/branch-policies

## Consequences

- **What lands in a materialised project:** framework core only, through follow-ups B, C and D. There is no question and no template.
- **Upgrade path:** existing ADR numbers stay valid, and readers accept both id shapes. The RDR skill and the lock's text arrive with the core.
- **Synthetic proof:**
  - a red fixture where two branches add the same ordinal id;
  - a fixture where two branch-born ADRs never collide;
  - a lint fixture where a relayed record without verbatim words is red;
  - a hook test where a dead PID's lock is reclaimed.

## Follow-up issues

**B — Ids no other branch can take; counters re-derived by the second to land** → #242 (EVOL-134)
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

**C — Relayed ratification across sessions** → #243 (EVOL-135)
- **Goal:** When a coordinator session and squad sessions work in parallel, a person's decision reaches the deciding session intact, and approvals that only a person can give stay in that person's own window.
- **We want:**
  - a relayed choice keeps the verbatim words and names the relay;
  - a relay without verbatim words authorises nothing;
  - plan, BLUEPRINT and `plan_exception` approvals, harness approvals and permission denials are never relayed;
  - a project's own delegation law (an accepted project ADR) is honoured by the skill without editing framework files.
- **We do not want:**
  - an agent ratifying;
  - a peer session answering a permission prompt;
  - a delegation law shipped by the framework (RDR-4 «2»).
- **How it reaches a project:**
  - Framework core (RDR skill), no question.
  - Proof: a lint fixture where a relayed record without its verbatim words is red.
- **Depends on:** none.

**D — fix: the session lock says what it guards** (`fix/` branch, no EVOL) → #244
- **Goal:** The lock's description matches the hook, a branch on one clone. Exclusivity across clones, whether between persons or squad sessions, points to the tracker's In Progress state.
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

- **One field team.** The design rests on one downstream project: one person, a coordinator and two squads. The second downstream project has not run a team yet.
- **#153 RDR-3 is not yet ratified.** Decision 1 and D's pointer depend on its answer. If #153 chooses a different home than the tracker, both move with it.
- **Code-owners premises are unverified** and now wait for #172:
  - GitHub CODEOWNERS on private repositories needs a paid plan;
  - Bitbucket Cloud cannot require code-owner approval in a merge check;
  - the exact GitLab Free behaviour.
- **Not measured:** how often branch-born ADR collisions occur. The evidence is structural, plus one downstream report of counter collisions.
- **Qualified ADR ids change a visible convention.** The owner may prefer sequential ids with a duplicate gate. That choice is queued as an RDR if contested.
