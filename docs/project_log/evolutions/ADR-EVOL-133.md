---
id: ADR-EVOL-133
title: "Session notebook — a long-lived session keeps its working state across a compaction: a standing part and an append-only log, re-injected on the governance path under their own budget"
date: 2026-11-19
status: accepted
---

# ADR-EVOL-133: Session notebook

## Context

This ADR plans issue #235 (epic #112, wave 5, destination G). Base model #97 (EVOL-062); related #106 (EVOL-063) and #142 (spike). It was checked on `origin/main` at framework 10.9.2 (9eb0469), after #240.

### State today
- **One compaction path exists, and it carries governance only.**
  - `PreCompact` runs `scripts/governance-oncompact.sh` (`.claude/settings.json:24-33`). The script writes `.claude/state/governance-reload-{sid}.marker` (`scripts/governance-oncompact.sh:85-93`) and prints nothing.
  - On the next prompt, `scripts/governance-onprompt.sh:119-142` prints the snapshot inside `<governance-reload>` and deletes the marker.
  - The template twins are byte-identical (checked with `diff`). The lock-step pair is `config/coherence-context.json:53`.
- **The script is not fail-open.** `governance-oncompact.sh:19` uses `set -euo pipefail`. If `mkdir` or the marker write fails, the script exits non-zero.
- **#97's hand-off records git state, not working state.**
  - `.claude/hooks/session-handoff.sh:28-34` writes `.claude/state/handoff.json` with `{branch, train, head, clean, pushed, closed, at}`.
  - It writes only on a sub-increment branch (`:21`).
  - It saves no decisions, no queue and no unsaved user words.
- **Budgets live in one home, measured in bytes.**
  - The home is `config/quality.json:43-52`, read by `scripts/gates/budget.py`.
  - Each producer runs at its worst case and is measured with `len(…encode())` (`budget.py:121`).
  - A missing key is a red row (`:111`). An empty emission from a `MUST_EMIT` producer is red (`:29`, `:113`).
  - `prompt_submit` is 10000 bytes (`config/quality.json:46`), measured on `governance-onprompt.sh` with the reload forced.
  - Since #240, `hook_output_cap: 10000` (`:51`) bounds every `MUST_EMIT` key (`budget.py:116-122`). A reload that does not fit goes out as a file pointer.
- **The harness caps each hook's output** (official hooks documentation, verified for #240).
  - Plain stdout is capped at 10,000 characters per hook. Output over the cap is saved to a file, and only a 2,000-character preview reaches the model.
  - PreCompact stdout on exit 0 becomes "instructions for the compaction summary", under the same cap.
  - Exit 2 from PreCompact blocks the compaction. Exit 2 from UserPromptSubmit blocks the prompt.
- **Where an agent can write.**
  - **`.claude/**` needs an approved plan.** It is a gate input in the meta repo (`config/quality.json:376`) and in a project (template `config/quality.json` `planning.gate_inputs`).
  - **The auto-mode classifier refuses agent writes there.** Agent-written state moved to `.context/state/` for that reason (#165, v8.12.3).
  - **`.context/state/` is runtime state.** It is gitignored (`.gitignore:67`; in a project, `setup/gitignore.hbs:28` ignores all of `.context/`). It is not RED (`rules/protected-code.md:25`).
  - **The write guard still applies.** Every in-project write is judged by branch (`scripts/gates/writes.py:10-11`, `.claude/hooks/check-branch-protection.sh:47-74`). A protected branch blocks it.
- **A hook already passes its payload to the one reader.** `gate.py deliver --hook-json` (`scripts/gate.py:147-182`, `:862`) does this. `scripts/gates/planning.py:114` dispatches on `hook_event_name`.
- **Evidence from an adopting project (#235):**
  - the governance re-injection used 9,533 of its 10,000 characters, so a shared budget overflows;
  - 9,000 characters for the notebook and 1,000 at pre-compact were enough;
  - four defects were found: queued messages judged at enqueue, hard links passing a symlink guard, `/compact` counting itself, and a shared index for claims.
- **Field use, read 2026-11-19** (the same project; three long-lived sessions: one coordinator and two squads):
  - **754 notebook writes, 0 refused by the branch guard.** The sessions sit on working branches (sub-increment branches). A train or `main` is checked out only between steps.
  - **Most writes go through the shell.** The coordinator appended 368 times, almost all with `cat >> … <<'EOF'`. Write and Edit are rare.
  - **Notebooks grow:** 13 KB to 90 KB after two days. That is far over any hook budget, so the cut and its pointer are the common path, not an edge case.
  - **The coordinator receives about 330 peer messages per session** (`<cross-session-message from-name=…>`). Its unsaved words are as often a peer's as the user's.

## Decision

1. **The notebook is a file the main session writes.**
   - Path: `.context/state/notebook/<name>.md`. It has two sections:
     - `## Standing`: the decisions in force, the queue, and the user's words not yet acted on. These are copied verbatim, under the payload-verbatim invariant (`rules/agents.md:133`).
     - `## Log`: append-only, one entry per line, `- <UTC ISO> <text>`. Continuation lines are indented.
   - The session writes it with Edit, Write or a shell append (§2). Subagents never write it.
   - *Rationale:* an agent write under `.claude/**` would need a plan and would hit the classifier. `.context/state/` is the place #165 already chose for agent-written state. Hooks keep their state in #97's home.
2. **Claiming a notebook writes one state file per session, `.claude/state/notebook-{sid}.json`.**
   - Content: `{path, claimed_at, reload, unsaved, authors, lower_bound}`. A claim on the same notebook keeps all but `claimed_at`: a write after the compaction does not prove the missed messages were written (a duplicate entry is cheaper than a lost count). On read, `unsaved` is kept only as an int, `authors` only as kinds of the closed vocabulary, `lower_bound` only as `true`: what reaches the model from the state file is a count and known kinds.
   - It is written on PostToolUse of a write to a path directly under `.context/state/notebook/`, by a new block in `scripts/governance-onedit.sh` that calls the reader. That includes Edit and Write, and a shell write resolved by the one write-target resolver (`gate.py write-target`, EVOL-065; `scripts/gates/writes.py`).
   - The PostToolUse matcher widens from `Edit|Write` to `Edit|Write|Bash`. For a Bash payload the script exits at once unless the payload names `.context/state/notebook/`, a shell `case`, so the cost of an unrelated command is one shell start.
   - *Field:* most notebook writes are shell appends. A claim on Edit/Write only would miss them.
   - The write is atomic: `mkstemp` in the same directory, then `os.replace`. There is no shared index and no lock. When two claims race, the last one wins.
   - A payload that carries `agent_id` is ignored, so a subagent's write never claims.
   - *Rationale:* the session does not know its own id; the hook does. Riding the one PostToolUse Edit|Write entry (`.claude/settings.json:123-132`) adds no hook.
3. **One reader: `python3 scripts/gate.py notebook --hook-json`, with logic in `scripts/gates/notebook.py`.**
   - It dispatches on the payload's `hook_event_name`: `PostToolUse` claims, `PreCompact` advises, `UserPromptSubmit` re-injects.
   - It reuses the existing flag name `--hook-json`, so no new flag.
   - It has one guard, `open_single(path)`. The guard opens with `O_RDONLY|O_NOFOLLOW|O_NONBLOCK` and refuses the file unless `fstat` shows `S_ISREG` and `st_nlink == 1`.
   - The guard also checks that the parent's realpath is the repository's realpath joined with the expected directory, so a symlink higher in the path does not slip through. An Edit/Write target is resolved with `realpath` before the name check, so a symlinked notebook is never claimed.
   - The guard applies to the notebook, the state file and the transcript. The `path` inside a state file is re-checked against `.context/state/notebook/*.md`.
   - Every path through the reader exits 0, including an exception or a missing key.
   - *§4 test (CLAUDE.md:104):*
     - the SDLC needs it: three hooks share one guard and one budgeted cut, and inline copies would repeat the guard three times (LAW-03);
     - the problem is real: it was measured downstream;
     - the benefit is clear: the logic gets unit tests red-first and a budget measured on the real producer.
   - It is not a user command. `deliver --hook-json` is the precedent.
4. **PreCompact keeps one path.**
   - `governance-oncompact.sh` gains `trap 'exit 0' EXIT`. Its new last step is `printf '%s' "$PAYLOAD" | python3 scripts/gate.py notebook --hook-json 2>/dev/null || true`.
   - The governance marker is unchanged.
   - When a notebook is claimed, the reader does three things:
     - it sets `reload: true`;
     - it counts the user-authored transcript entries delivered after the notebook's `st_mtime`;
     - it writes only the count and the authors into the state file.
   - The count rules close two of the known defects:
     - a queued message is judged by where it sits in the transcript, not by its enqueue time. The attachment entry carries the enqueue time as its own `timestamp` (verified on real transcripts at review); it is delivered at its position, so it takes the timestamp of the next newer entry, and is counted when none follows (the compaction fired right after its delivery);
     - an interruption marker (`[Request interrupted by user]`) is not someone's words;
     - with `trigger == "manual"`, the newest entry that is the `/compact` invocation is dropped.
   - The transcript is read backwards from its end and stops at the first entry older than the notebook.
   - When the count is above 0, stdout names the notebook path, the count and the authors, and asks the summary to keep those requests and decisions. It never contains their words. Its size is at most `budgets.notebook_precompact`.
   - Authors use a closed vocabulary: `user`, `queued`, `peer` (a prompt that opens with the `<cross-session-message>` envelope), `other`. A peer's name is never printed.
   - *Rationale:* the only documented channel to the summariser is PreCompact stdout, and it already belongs to this script, which prints nothing today.
5. **The re-injection rides the same pair, in its own hook command.**
   - `UserPromptSubmit` gains a second entry: `cd "${CLAUDE_PROJECT_DIR:-.}" && python3 scripts/gate.py notebook --hook-json || true`.
   - When `reload` is true, it prints one `<session-notebook path=… updated=…>` block, then clears `reload` atomically, so the block is consumed once. The block holds, in order:
     - `## Standing`, whole;
     - the newest `## Log` entries that fit, in chronological order;
     - `[N older entries cut — read <path>]`;
     - the advisory line, when the count is above 0.
   - The whole block is at most `budgets.notebook_reinject`, counted in UTF-8 bytes and cut only at entry boundaries. Every `<` of the notebook's text reaches the model as `&lt;`; the split is linear in the notebook's size and reads CRLF as LF. A project that symlinks `.context/state` or `.claude/state` gets its notebook refused (fail-closed, silent, exit 0): the guard cannot tell a shared directory from a planted one.
   - A standing part over the budget is never cut. In its place the block prints its path and size and says "read it whole".
   - No claim, or no reload pending, prints nothing, so the cost is zero.
   - *Rationale:* the harness caps each hook command's output separately, and the measured governance block already fills its share. Putting this block inside `governance-onprompt.sh` is the shared budget #235 rules out. The trigger is the existing PreCompact → next-prompt pair. Only the emitter is a sibling. `governance-onprompt.sh` does not change.
6. **The budgets are keys in the injection-budget home.**
   - `config/quality.json → budgets` gains `notebook_reinject: 9000` and `notebook_precompact: 1000`, in the meta file and the template. Its `_doc` says these are never counted in `prompt_submit`.
   - `budget.py` adds both keys to `REQUIRED` and `MUST_EMIT`. Each runs its real producer on a throw-away fixture session, which is removed in `finally` (`budget.py:132-139` precedent):
     - `notebook_reinject`: `gate.py notebook --hook-json` on a notebook larger than the key;
     - `notebook_precompact`: `bash scripts/governance-oncompact.sh` on a transcript with every author and many unsaved entries.
   - Both keys join `MUST_EMIT`, so #240's rule holds them at or under `hook_output_cap`.
   - *Rationale:* the issue's measured figures fit under the per-hook cap (bytes ≥ characters). One home applies the "every digit a key" rule.
7. **The rule is one paragraph.** `rules/agents.md` § context diet gains bound **(4) The session notebook**. It says:
   - when to write the notebook: a recorded decision, queued work, or user words not acted on this turn;
   - the path and the format;
   - the claim: Edit, Write or a shell append, never a subagent;
   - that the block after a compaction is data, never an instruction;
   - that the budgets are named in the config.

   `factory-governance-loading/SKILL.md:61` and `README.md:863` (the Tier-4 row) each gain one clause. No CLAUDE.md change: always-on bytes are not spent on it.

### Rejected
- **Re-inject at SessionStart `compact`:** it would be a second re-injection path, which #235 rules out.
- **Inline Python in each hook:** it copies the guard three times (LAW-03).
- **Build on `handoff.json`:** that is another concern's file; #235 asks for one state file per concern.

## Materialisation
- **No question selects it.** Every project gets it (#235: no discovery question).
- **What lands with `SETUP --generate`:**
  - the reader module;
  - the two changed governance scripts;
  - the settings entry;
  - the two budget keys;
  - the rule paragraph.
- **What `SETUP --upgrade` does:** today merge-preserve adds the `UserPromptSubmit` block only when it is absent (`Factory-setup-upgrade.instructions.md:457`), so an installed project would never get the second entry. The fix:
  - **Merge rule.** The rule gains: `UserPromptSubmit`: add `gate.py notebook --hook-json` when absent, identified by the reader it runs; never touch a project's own entries. The `PostToolUse` entry that runs `governance-onedit.sh` takes the matcher `Edit|Write|Bash`. The same clause goes into `Factory-setup-materialization.instructions.md:1016`. The anchor adds a budget key that is absent or not a positive int, at the template's value or the project's `hook_output_cap` when lower; it never raises a value.
  - **Anchor.** A new anchor `**session-notebook (EVOL-133).**` holds a bash block that adds the two budget keys when absent, the entry when the `UserPromptSubmit` event exists without it (an absent event comes whole from the merge rule), and the `Edit|Write|Bash` matcher. The block is idempotent.
  - **Restart.** Hook wiring reloads per tool call, so no restart is needed.
- **Synthetic proof** (`scripts/materialize-synthetic.sh`, every fixture run with `--answers`):
  - (a) the settings carry exactly one anchored notebook entry ending in `|| true`, and `scripts/gate.py` is delivered (the check at `:851-855` reads `.sh` tokens only);
  - (b) both budget keys are present and `gate.py budget` is green on both rows;
  - (c) on a fix branch, end to end:
    - the shipped `check-branch-protection.sh` and `check-plan-approval.sh` let a Write to the notebook through;
    - a Write payload claims;
    - a PreCompact payload over a fixture transcript prints at most 1000 bytes with the count and authors and without the fixture's sentinel word;
    - the next UserPromptSubmit prints the block at most 9000 bytes with the standing part whole;
    - a second prompt prints nothing;
  - (d) `gate.py plan --path .context/state/notebook/x.md` reports the path as not governed;
  - (e) the upgrade anchor runs twice on a 10.9-shaped tree that has the project's own `UserPromptSubmit` hook: the entry, the keys and the `Edit|Write|Bash` matcher land, the project's hook is kept, and the second run leaves the same sha.

## Build

| File (meta ↔ template twin) | Change | Manifest bump |
|---|---|---|
| `scripts/gates/notebook.py` ↔ `.context/templates/setup/scripts/gates/notebook.py` | new reader (covered by the `scripts/gates/*.py` pair, `coherence-context.json:66-67`) | new `1.0.0`, both sections |
| `scripts/gate.py` ↔ twin | `notebook` subparser, `--hook-json` | MINOR 2.8.0→2.9.0 |
| `scripts/gates/budget.py` ↔ twin | two rows in `REQUIRED` and `MUST_EMIT` | MINOR 1.1.2→1.2.0 |
| `scripts/gates/test_gates.py` ↔ twin | class `Notebook` | MINOR 1.46.2→1.47.0 |
| `scripts/governance-oncompact.sh` ↔ twin | `trap 'exit 0' EXIT`, the reader call | MINOR (fc 1.0.0, tpl 1.1.0: a pre-existing skew, see limits) |
| `scripts/governance-onedit.sh` ↔ twin | Block 3: the claim | MINOR 1.2.0→1.3.0 |
| `.claude/settings.json` ↔ `claude/settings.json` | second `UserPromptSubmit` entry; PostToolUse matcher `Edit|Write|Bash` | MINOR |
| `config/quality.json` (fc) · template `config/quality.json` | two budget keys plus `_doc` | MINOR 1.19.2→1.20.0 · 2.5.1→2.6.0 |
| template `rules/agents.md` | bound (4) | MINOR 1.11.1→1.12.0 |
| `Factory-setup-upgrade.instructions.md` | merge rule plus anchor | MINOR 3.5.1→3.6.0 |
| `Factory-setup-materialization.instructions.md` | merge-preserve clause | PATCH 4.6.0→4.6.1 |
| `factory-governance-loading/SKILL.md`, `README.md`, template `scripts/README.md:242` | one clause each | PATCH |
| `scripts/test-hooks.sh`, `scripts/materialize-synthetic.sh` (meta-only) | hook and synthetic assertions; the anchoring check accepts `cd "${CLAUDE_PROJECT_DIR:-.}" && python3 scripts/` | MINOR |
| template `setup/discovery_registry.json` | migration row `session-notebook (EVOL-133)`, since 10.10.0 | MINOR 2.8.1→2.9.0 |
| `scripts/fixtures/synthetic-answers/upgrade-8.12{,-api}.json` | the migration expected | MINOR |
| `governance_versions.json` | `framework_version` 10.9.2→10.10.0 | MINOR |

### Red first

Each test below is proven red against `origin/main` before its code lands.

`test_gates.py::Notebook`:
1. The standing part is whole, the newest log entries are kept chronologically, the cut pointer is present, the total is at most the key, and every kept entry carries its multibyte run whole.
2. A standing part over the key gives the pointer only, with no partial standing.
3. No claim, or no reload, prints nothing. The reload is consumed once.
4. The count follows the notebook's mtime. A queued entry in the real shape (its own stamp the enqueue time) enqueued before the update but delivered after it is counted; one delivered before it is not; an interruption marker is not counted.
5. The output, the state file and the block carry the count and the authors, and never the fixture's sentinel word.
6. With `trigger: manual`, the `/compact` entry alone gives a count of 0. The same entry with `trigger: auto` counts.
7. A symlinked notebook, a hard-linked notebook (`st_nlink == 2`), a FIFO (no hang), a hard-linked state file, a state `path` outside the directory, a symlinked notebook directory and a symlinked state directory are each refused; a forged state `authors` never closes the block.
8. A claim leaves no temp file and the last claim wins. A payload with `agent_id` does not claim. A Bash `cat >> .context/state/notebook/x.md` claims; a Bash command that names no notebook does not.
9. Garbage stdin, an unwritable state directory or a missing budget key exits 0.
10. In `budget`, a missing key is red, a dead producer is red, and a key above `hook_output_cap` is red.
11. The notebook's text cannot close the block or forge a tag: `<` reaches the model as `&lt;`, and only the reader writes `</session-notebook>`.

`test-hooks.sh`:
- `governance-oncompact.sh` exits 0 when `gate.py` is absent, when `.claude/state` is a file, and when the reader raises.
- Both settings files wire the notebook entry once, anchored, and fail-open. The existing Stop-wiring check (`test-hooks.sh:710-716`) is the precedent.

## Consequences
- **A coordinating session survives a compaction.** After a compaction it gets its decisions, its queue and its pending user words back verbatim, under its own budget, and is told how many user messages the notebook missed.
- **The cost is zero for a session without a notebook.** One extra process per prompt checks for a state file.
- **A notebook hook fault can never block a compaction or a prompt.**

## Honest limits
- **Mid-turn auto-compaction.** After an auto-compaction in the middle of a turn, the notebook (like governance Tier 4, `factory-governance-loading/SKILL.md:61`) comes back only at the next user prompt. Moving both re-injections to SessionStart `compact` together would be a separate evolution, so there would still be one path.
- **The transcript format is not a public contract.** An entry the reader cannot classify counts as `other`. A shape it cannot read gives no advisory, which is fail-open, so the advisory can be silent.
- **Append-only is not enforced.** The rule asks for it, and the reader takes the last entries in file order.
- **A shell write the resolver cannot read** (a variable target) is not claimed. The branch guard already refuses such a write in a project.
- **A resumed session with a new id** claims again on its first notebook write.
- **Pre-existing, outside this change:**
  - The manifest versions of `governance-oncompact.sh` are skewed (fc 1.0.0, tpl 1.1.0) while the twins are byte-identical.

## Decided from field evidence

**RDR-1 — may the notebook be written on a protected branch? → option 1, no guard change.**
- **The premise of the draft RDR is refuted by the field.** It assumed coordinating sessions often sit on `main` or a train. In 754 notebook writes across three long-lived sessions, the branch guard refused none.
- **Options weighed:**
  1. leave the guard as it is;
  2. a narrow exception for the notebook directory in `writes.py`;
  3. hooks writing the notebook from a tagged block.
- Option 2 widens a guard for a case the field never hit. Option 3 costs output tokens.
- **Decided:** the owner ruled the field evidence sufficient (2026-11-19: «Con eso debes tener informacion mas que de sobra»), and the evidence gives a clear winner. If a write is ever refused on a protected branch, the session cuts a working branch, as for any write.
- **Surviving risk:** a coordinator that works from `main` in a future project. The refusal is loud and humanised (LAW-08), so nothing is lost silently.

## Premises not verified at a readable source
- **Hook facts, from the official hooks page:**
  - the 10,000-character cap per hook is read in the general section; its application to UserPromptSubmit is not stated explicitly;
  - PreCompact stdout goes to the summary instructions;
  - PreCompact input carries `trigger` and `custom_instructions`.

  The docs reader should confirm these at Beat 0.
- **`session_id` is the same before and after a compaction.** The existing governance reload assumes it too (`governance-onprompt.sh:122`).
- **Transcript JSONL shape is undocumented:**
  - the queued-message attachment type and its timestamp (the enqueue time, verified on real transcripts; delivery is its position);
  - how a manual `/compact` appears;
  - the `isMeta` and tool-result entries to exclude.
- **PostToolUse carries `agent_id` for a subagent's tool call.**
- **A project's `planning.governed_paths` placeholder** (Q33 runtime surface) never covers `.context/state/**`. Synthetic assertion (d) proves this for the fixtures only.
