---
id: ADR-EVOL-113
title: "A delivery costs what its change warrants — the spawn re-measures a work critic's scope, a second round reads the cure only, and measure reports spend by phase and role"
date: 2026-10-20
status: accepted
---

# ADR-EVOL-113: A delivery costs what its change warrants

## Context

This ADR implements issue #180 (epic #112, train row 4c). It was verified on `main` at framework 8.14.0. Owner RDR «1» (2026-10-19) set the scope: one issue for the whole delivery's cost, not the critics alone.

- **The evidence.**
  - One framework session of four fix PRs (2026-10-19) cost about $72 at list price. 82 % of that was the orchestrating session and 18 % the critics.
  - #168 round 1: five critics reached the 60-turn ceiling on a 46-line diff, about 1.4 M tokens. Scoped to the cure diff with a stated tool cap, each critic spent about 43 k.
- **The budget is a key, but nothing ties it to the change.**
  - `rules/agents.md` declares `turn_budget` and `probe_budget` per size tier (EVOL-058).
  - The spawn prompt is told to open with `effort:`, `turn budget:` and `probe budget:`.
  - The PreToolUse hook on `Agent` (`check-agent-spawn.sh` → `gate.py agents --spawn --hook-json`) checks the model alias only (`agents.py` `spawn_check`).
  - So a critic spawned without its budget lines, or with the large tier's on a small diff, passes. The harness then stops it at `maxTurns`, the large tier's 60.
- **The second round re-reads the whole diff.**
  - `rules/agents.md` § The bounded loop says that "the second pass's tier is the diff's (the whole scope), not the cure's".
  - `factory-code-review` hands round 2 the same scope as round 1.
- **Large reads are already rare in the orchestrator's context; the cost is accumulation.**
  - This repo's transcripts (read as evidence, no baseline claimed) hold 615 main-session requests on 2026-10-20: context p50 181 k, p90 249 k, max 266 k, under the 300 k compaction window (EVOL-063).
  - Tool results above `context_result_max_kb` (20 KB): one on 2026-10-20 and five in 1783 requests on 2026-10-19.
  - The bound is the compaction window. The diet (EVOL-062) keeps large reads out, and the harness caps a whole-file read.
- **What the instrument does not report.** `subproducts/measure` reports the median context per session, the cache per spawn by class and turn bucket, and critics inside their budget. It has no context distribution per request, no split by phase or role, and no money.

## Decision

1. **The spawn re-measures a work critic's scope.**
   - A `work-critic` spawn prompt opens with five lines: `effort:`, `turn budget:`, `probe budget:`, `round: N` and `scope:`.
   - `scope:` takes one of two forms:
     - `diff <path>`: a unified diff file the critic reads. Its size is its `diff --git` headers (files) and its `+`/`-` lines (lines), the same count as `git diff --numstat`.
     - `files <glob>…`: the tracked files the globs match, with lines 0. The preventive sweep uses this form.
   - The existing hook path re-measures the scope and asks `resolve()` for the class, the size and the round.
   - It refuses the spawn when:
     - a line is missing;
     - the scope cannot be read;
     - a stated budget or effort differs from the resolver's (the harness `effort` input too, when given);
     - the round is over `rounds.work`.
   - The refusal names the lines the spawn owes.
   - There is no new mode or flag: `gate.py agents --spawn --hook-json` reads the prompt it already receives.
   - The plan critic and the reader are not held this way. Their size is never measured, so their budget is the large tier, which equals the ceiling the harness already stops at; stating it changes no outcome.
2. **A second round reads the cure only.**
   - A round-1 work-critic spawn that is admitted records its scope in `.context/state/critic-round.json`, per branch. The record holds each file's worktree hash and the scope's changed lines.
   - A round-≥2 spawn is refused when:
     - no round 1 is recorded on the branch;
     - its scope names a file whose bytes did not change since round 1;
     - its scope is not smaller than round 1's.
     A cure as large as the diff is a rewrite: round 1 starts again on the new bytes.
   - The canary fixture is recognised by its content (`canary.fixture()`). It is never recorded and is round 1 by definition.
   - **The round-2 tier is the cure's.** The rule's sentence is reversed, so the round-2 effort rows step by the cure's size.
   - A finding on a line the round's scope did not add, change or remove is informational: in round 1 that scope is the branch diff, in round 2 the cure diff.
3. **The spawn sites write the scope.**
   - `factory-code-review` (branch and increment mode):
     - Round 1 hands a diff file of the scope's files and resolves on its numstat.
     - Round 2 hands the cure: the diff of the scope's files against their round-1 bytes. That is `git diff <round-1 HEAD> -- <files>` when round 1 reviewed committed bytes. Otherwise it is a diff against the copy the main session kept at round 1.
   - `factory-preventive-sweep` uses `scope: files …` for the sweep and `scope: diff <fixture file>` for the canary.
   - `Factory-implement-review-checks` names the five lines.
4. **The plan gate's second pass still reads the whole plan.** The plan critic judges coverage of every scenario and contract, which is a property of the whole plan, so `rules/agents.md` says so on the bounded loop.
5. **The orchestrator's bound stays where it is; the instrument measures it.**
   - The compaction window (`autoCompactWindow`, EVOL-063) is the hard bound. The context diet (EVOL-062) keeps large reads out.
   - No new hook is added: the evidence shows a whole-read bound would change almost no request.
   - `measure` reports the main session's context per request as p50, p90 and max, overall and per phase. Lowering the window is the adopting project's decision, read from its before/after window.
6. **`measure` reports spend by phase and role.**
   - **Phase:** the last slash command the main session ran before the request (`/implement`, `/qa`, …), or `none`. A subagent request inherits the parent session's phase at the subagent's first request.
   - **Role:** `main`, or the subagent's roster class (`agent_class`).
   - **Per phase × role:** requests and tokens by category (input, cache write 5 m, cache write 1 h, cache read, output).
   - **Money:**
     - Dollars appear when `measure.config.json → prices` prices the model: per family, a model-id substring, with an `as_of` date.
     - A model with no price is counted in tokens and named as unpriced.
     - `--compare` carries the totals into the before/after table.
7. **Governance source.** The `CLAUDE.md` Core Protocols row for role agents gains the spawn re-measure and the cure-only second round.

## Consequences

- A critic on a small diff is told the small tier's budget (20 turns, 2 probes) and is refused at the spawn otherwise. A second round reads only the cure. That is the #168 saving, held by a gate instead of by the orchestrator's memory.
- The hook gains one state file under `.context/state/`, which is already gitignored, as the seal and the markers are.
- No new command, flag, hook or gate mode. `gate.py agents --spawn --hook-json` reads one more field of the payload it already receives.
- **Upgrade path:**
  - `factory-sync.sh` delivers the skills, the instruction, the gate (`scripts/gates/agents.py`, a lock-step twin) and `CLAUDE.md`.
  - `SETUP --upgrade` delivers `rules/agents.md` and the `measure` subproduct.
  - Until a project's spawn sites are upgraded, a work-critic spawn without the five lines is refused, and the refusal names them. Upgrade both together.
- The lens canary is unchanged. It still reviews the fixture at round 1, under the budget its own size earns (9 files, 153 lines, tier medium).
- **The DoD's before/after window** needs a project that adopts this change through `factory-sync.sh` / `SETUP --upgrade`. None is adopting now, so the PR carries `Refs #180` and the issue stays open for that item. This repo claims no baseline (CLAUDE.md § Templates, `measure`).

## Alternatives considered

- **Declare the scope as a git range only.** Rejected:
  - The canary fixture and the increment review are not committed bytes.
  - The sweep's scope is a file set.
  - A diff file covers the first two, and the `files` form covers the sweep.
- **Record the round-1 HEAD and require round 2 to start there.** Rejected: an increment review reads worktree bytes, so HEAD does not move between rounds. Per-file hashes hold in both modes.
- **A PreToolUse hook bounding whole-file reads in the main session.** Rejected by the do-less lens: the evidence shows almost no read above the key, so the hook would change no outcome. The cost is accumulation under the window.
- **Lower `autoCompactWindow` here.** Rejected: it is data set by EVOL-063 against its own measurement. The per-request distribution this change adds is what an adopting project reads before it moves the window.
- **Prices left empty in the template.** Rejected: a before/after window in money needs them on both sides. A stale price moves both sides alike, and `as_of` says when they were read.

## Operational Rule

- A work critic's spawn prompt opens with `effort:`, `turn budget:`, `probe budget:`, `round: N` and `scope: diff <path>` or `scope: files <glob>…`. The spawn hook re-measures the scope and refuses a budget that is not the resolver's for that size and round.
- A second round's scope is the cure: the diff against the round-1 bytes. It is refused when it repeats a file the cure did not change, or when it is not smaller than round 1.
- `measure` reports spend by phase and role, and the main session's context per request.

## Verification record

- **Red first.**
  - `scripts/gates/test_gates.py`:
    - `Agents.test_spawn_hold_budget_round_and_cure` errored before the code (`TypeError` on `prompt=`).
    - `Agents.test_spawn_hook_json_passes_prompt_and_effort` failed (`0 != 1 : agents: spawn ok`).
    - `Cli.test_cli_exit_codes` went red on the new contract and now expects a work-critic payload without the five lines to be refused.
    - The cases cover:
      - a small diff with the large budget, a missing line and a harness effort mismatch → refused;
      - the proportional header → admitted and recorded;
      - round 2 on the whole re-diff and round 2 without a record → refused;
      - round 2 on the cure → admitted;
      - round 3 → refused;
      - the canary fixture at round 1 → admitted and not recorded;
      - the `files` form counts tracked files;
      - a worker and a non-roster agent → unaffected.
  - `measure --selftest`:
    - Eleven new expectations failed before the code (ten failures, then exit 2 on the missing `price_of`).
    - After the phase cure, seven failed while a built-in `/model` still set the phase.
    - It now reports `0 failure(s)`.
  - `scripts/materialize-synthetic.sh` plants a 1-file, 3-line diff in the materialised project and pipes hook payloads into `gate.py agents --spawn --hook-json`:
    - the large-tier budget → red;
    - the resolver's lines → green, with round 1 recorded;
    - round 2 on the same whole diff → red ("did not change").
- **Green:**
  - `test-gates.sh`, `test-measure.sh` (25 passed), `check-lockstep-pairs.sh` (79 files);
  - `gate.py agents`, `retired-terms`, `check-command-flags.py`, `check-applicability-frontmatter.sh`;
  - both synthetic materialisations;
  - `manifest-parity`, `gate.py profile --run --base origin/main`.
- **Live proof on this branch's own review.**
  - Round 1: three correctness lenses on the 8-file, 538-line scope diff were admitted at tier medium (effort max, 40 turns, 4 probes), and the record was written.
  - The cure: 5 files, 72 lines, tier small.
  - A round-2 spawn handed the whole round-1 diff was refused by the hook. The refusal named the three files the cure did not change.
  - The three round-2 spawns on the cure were admitted at effort medium, 20 turns and 2 probes.
  - Round 1's own findings were cured before round 2:
    - the `test-hooks.sh` admitted case was vacuous (an f-string escape made the payload empty); it now asserts the round-1 record;
    - a diff scope naming no file is refused;
    - a header without `a/`/`b/` prefixes is refused, naming `--src-prefix=a/ --dst-prefix=b/`;
    - a non-UTF-8 byte is counted;
    - a NUL path is refused, with no traceback;
    - git's line split is used.
  - Round 2 (cure only) raised one question, shared by two lenses: a path git quotes (`core.quotePath`, a non-ASCII name) was refused as a missing prefix. It is cured unreviewed under the adjudication default: the quoted header is unquoted, with a red-first pin.
- **Smoke on this repo's own transcripts** (evidence only, no baseline claimed, two-day window):
  - 2,081 requests, $121.64 at the declared list prices:
    - main $92.62;
    - work critics $14.83;
    - workers $7.58;
    - unclassed $6.61.
  - Main-session context per request: p50 176 k, p90 246 k, max 267 k.
  - Every request is in phase `none`: framework work runs no project command.
- **Deviations:**
  - **The round-1 record is keyed by branch and then by scope form** (`diff` | `files`). Otherwise a preventive sweep's round 1 would overwrite the code review's record on the same branch, and the review's round 2 would be refused for the wrong reason. A test pins it.
  - **The phase is the last command that names a file in the project's `.claude/commands/`.** Built-in and plugin commands (`/model`, `/clear`) never set it: the commands folder is the definition, with no list and no key.
  - **The worker aligned more texts to the cure-only round 2 than the plan listed:**
    - `rules/review-policy.md`;
    - `Factory-implement-build`;
    - `factory-code-review/references/severity-mapping.md`;
    - both copies of `check-agent-spawn.sh` (comment and refusal text).
  - **Sizes are counted from the diff file's `@@` hunk counts**, so a removed line that starts with `--` is counted correctly. On the last three commits the count matches `git diff --numstat` exactly (53 files, 6,044 lines).
