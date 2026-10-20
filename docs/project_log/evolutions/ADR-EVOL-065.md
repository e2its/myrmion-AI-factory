---
id: ADR-EVOL-065
title: "Write-target guard — a file written through the shell meets the same branch and plan gates as Edit or Write; a path outside the project is never gated"
date: 2026-10-20
status: accepted
---

# ADR-EVOL-065: Write-target guard

## Context

This ADR implements issue #119 (epic #112, train row 5a, with EVOL-069). It was verified on `main` at framework 8.15.0.

- **The shell is not gated.**
  - `settings.json` runs `check-branch-protection.sh`, `check-plan-approval.sh` and `check-concurrency-lock.sh` on `Edit|Write` only. The `Bash` matcher runs `check-push-preflight.sh` alone.
  - So `sed -i`, `>`, `>>`, `tee`, `cp`, `mv` and `python -c "open(…,'w')"` write a governed file with no branch check and no plan check. The first backstop is the git `pre-commit` hook, after the bytes changed.
  - The hooks' own resolution text says «the shell is not gated».
- **The path filter exists for Edit and Write only.** #169 taught `check-branch-protection.sh` to let a path outside the repository through. `planning.governed` already returns «outside the repository — not a governed write». Neither reads a shell command.
- **The harness and user configuration are not guarded.** `~/.claude/settings.json` is outside the project, so the filter lets it through on every branch.
- **A merge commit skips `pre-commit`.** Git runs `pre-merge-commit` for a merge that completes without conflict. `scripts/hooks/` ships no such hook.
- **One diff-base consumer falls back.** `validate-governance.sh` compares against `main` when `gate.py diff-base` fails. When `main` is absent, the drift checks run on an empty range.

## Decision

1. **One answer to «where does this write land».**
   - `scripts/gates/writes.py` (lock-step twin) resolves a PreToolUse payload to its write targets, for every tool.
   - Edit and Write give `tool_input.file_path`.
   - Bash gives the targets of the recognised writers in `tool_input.command`:
     - redirections (`>`, `>>`, `>|`, `&>`, `N>`);
     - `tee`;
     - `sed -i` / `--in-place`;
     - `cp` (the destination);
     - `mv` (the sources and the destination);
     - `python`/`python3 -c` (parsed with `ast`: `open(<literal>, <write mode>)`, `Path(<literal>).write_text|write_bytes`).
   - Any other command is not a writer. That includes `bash -c` bodies, a script fed on stdin, `xargs` and `find -exec`, build scripts and `git apply`; the git `pre-commit` hook stays their backstop. A wrapper or a reserved word before the command (`sudo`, `do`, `then`, `else`, `{`, `!`) never hides it. A wrapper's own value option (`sudo -u root`, `env -C dir`) is a declared gap: the reader skips the wrapper word only, and the `pre-commit` hook is the backstop.
   - **How the command is read:**
     - heredoc bodies are dropped before lexing;
     - quoting is kept: a quoted or escaped `#` or operator character is part of the word, an unquoted `#` at a word start opens a comment to the end of the line, and a backslash-newline joins the lines;
     - `shlex` splits words and operators, and simple commands split on `;`, `&&`, `||`, `|`, `&`, parentheses and newlines;
     - leading `env`/`command`/`exec`/`nohup`/`time` words are skipped;
     - a literal `cd` moves the working directory for the commands after it, and a `cd` inside `( … )` stays in the subshell;
     - relative paths resolve against the payload's `cwd`, else the project root;
     - `~`, `$NAME` and `${NAME}` expand from literal assignments earlier in the same command, then from `HOME`, `CLAUDE_PROJECT_DIR` and `TMPDIR`.
   - **Unresolved targets:** command substitution, globs, brace expansion, any other variable and a non-literal `open` target leave the target unresolved. A `cp` of a source the reader cannot name into a named directory judges the directory's content (`dir/*`), so a governed directory meets its own pattern.
2. **The verdict, in order.**
   1. **Guarded on every branch:** the harness and user configuration. That is `~/.claude/settings.json`, `~/.claude/settings.local.json`, `~/.claude/hooks/**`, `~/.gitconfig`, `~/.config/git/**`, the project's `.claude/settings.local.json`, the git directory, and `core.hooksPath` when it lies outside the work tree. A guarded target is blocked.
   2. **Unresolved:** a recognised writer with an unresolved target is blocked. The reason names Edit or Write as the route (LAW-08).
   3. **Outside the project root** (the scratchpad, the user memory, `/dev/null`): never judged.
   4. **Inside the project root:** judged by the branch rule (`gate.py branch-class --protected`) and the planning stage (`gate.py plan --path`), as an Edit or a Write is today.
3. **One reader, three hooks.**
   - `gate.py write-target --hook-json` exits:
     - 0 and prints the in-project targets;
     - 4 when there is nothing to judge (not a writer, or every target outside). Never 3: that is `gate.py`'s import guard (the package missing or broken), which the hooks read as a fault;
     - 1 with the reason (guarded or unresolved);
     - 2 on a fault.
   - `check-branch-protection.sh` and `check-plan-approval.sh` block on 1 and judge each printed target.
   - `check-concurrency-lock.sh` judges only when a write lands inside.
   - All three join the `Bash` PreToolUse group in `settings.json` (lock-step twin).
   - **On a reader fault:** an Edit or a Write stays fail-closed, as today. A Bash call passes with a notice, delivered through the PreToolUse envelope (`additionalContext`), the only channel an exit-0 hook has to the model. The shell is the repair route: `git checkout origin/main -- scripts/gates` and `factory-sync.sh` are not recognised writers. The git `pre-commit` hook classifies the branch before any commit. The resolution text says so and no longer says «the shell is not gated».
4. **A merge commit is a commit.** `scripts/hooks/pre-merge-commit` (lock-step twin, a manifest template entry at 1.0.0) runs the `pre-commit` hook. `install-hooks.sh` already installs every file of `scripts/hooks/`.
5. **An unresolvable diff base blocks.** `validate-governance.sh` exits with the reason when the reader is present and `gate.py diff-base` fails. It never falls back to `main` in that case. `--banner` never blocks, and an absent reader keeps the legacy `main`.
6. **The governance sentence.** The Pre-Action Gate line of both `CLAUDE.md` files («blocks Edit/Write on protected branches») names shell writes. `rules/branching.md` and `factory-branching-strategy` say the same.

## Consequences

- **What it costs:** every Bash call runs three more hooks, each one `gate.py write-target` process. A command that is not a writer exits at the reader.
- **Unresolved targets are blocked.** A write to `"$X"` that the reader cannot expand is blocked; the route is Edit or Write, or a literal path.
- **Upgrade path:**
  - `factory-sync.sh` delivers the gate, the hooks and the skill.
  - `SETUP --upgrade` merges the `Bash` matcher into an installed `settings.json` and installs `pre-merge-commit` through `install-hooks.sh`.
- **The surviving risk is the fail-open shell on a reader fault.** It is the repair route, and `pre-commit` stands behind it.

## Alternatives considered

- **A Bash allow-list (every command not on it blocked).** Rejected: it blocks read-only commands, which the issue forbids.
- **A regex prefilter in the hooks before the reader.** Rejected: it is a second parser that would drift from the first.
- **A fail-closed shell on a reader fault.** Rejected: one broken gate script would lock the agent out of its own repair.

## Operational Rule

A project file meets the branch rule and the planning stage whatever tool writes it. One reader resolves the write target, and a write outside the project is never judged by the project's rules. The harness and user configuration are guarded on every branch. A merge commit is refused where a commit is.

## Verification record

- **Red first:**
  - `test-gates.sh -k Writes` → `ImportError: cannot import name 'writes'` (8 errors).
  - `test-hooks.sh` → 182 passed, 15 failed:
    - scratch and read-only Bash were blocked on main;
    - an unplanned `sed -i` was not blocked, nor were a temp-HOME `~/.claude/settings.json` write and an unresolved target;
    - Bash was blocked under a reader fault;
    - the text «the shell is not gated» was present;
    - the Bash wiring was missing;
    - a merge commit on main went through.
  - `test-validate-governance.sh` → «unresolvable diff base did not block (exit 0)».
- **Green:**
  - `test-gates.sh`: 135 tests OK;
  - `test-hooks.sh`: 197/0;
  - `test-validate-governance.sh`: 15/0;
  - lock-step: 81 files, 17 pairs;
  - `materialize-synthetic.sh` with a Bash `sed -i` payload through the materialised hooks: red on main, green on a planned branch.
- **Live proof, this session's own hook:**
  - `echo probe > "$NOPE_EVOL065"` was refused by `check-plan-approval.sh` with «a target the guard cannot name … make the write with Edit or Write»;
  - `S=/tmp/…; git diff > $S/r.diff` → nothing to judge;
  - `cp … ~/.claude/settings.json` → guarded.
- **Deviations from the Decision:**
  - An Edit or a Write without `file_path` gives exit 0 with no target, and the branch decides, as before.
  - The hooks recognise a Bash payload by its text, so the shell's fault pass works without python3.
  - A single-quoted `$` or glob in a target counts as unresolved, the cautious side.
  - An unbalanced quote is unresolved only when the command names a writer.
  - `validate-governance.sh` `--base` parsing was fixed (`shift` inside a `for`).
- **Review round 1 (three correctness lenses), cured red-first:**
  - «nothing to judge» moved from exit 3 to 4, because a broken package (the import guard's 3) let an Edit through;
  - the lexer keeps quoting (`echo '# t' > f` was missed, `grep ">" f` was blocked) and joins backslash-newlines;
  - reserved words and `sudo` are skipped, a subshell's `cd` is scoped, and a brace word is unresolved;
  - `cp <glob> dir/` judges the directory's content;
  - the fault notice goes through the envelope;
  - `pre-merge-commit` carries the header `install-hooks.sh` recognises, and the merge test has its positive control.
- **Review round 2 (the cure only), cured red-first:**
  - `cp /tmp/*.sh scripts/` named `scripts`, which `scripts/**` does not match: the target is now `scripts/*`;
  - an escaped pair before `#` (`a\ #x`) is a word, never a comment;
  - tests pin `$#`, a quoted escape and a brace on a redirection.
