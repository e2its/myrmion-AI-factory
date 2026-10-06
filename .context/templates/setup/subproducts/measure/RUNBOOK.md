# measure — operator runbook

What this project's SDLC costs, read from local data only: Claude Code session transcripts, the git log and the per-feature worklog. Nothing leaves the machine. This file is self-sufficient.

## Requirements

- Python 3.10 or later. No packages.
- Check the setup: `python3 subproducts/measure/measure.py --selftest` — `0 failure(s)` means ready.
- Transcripts are read from `~/.claude/projects/<repo-slug>/` (the folder Claude Code writes for this repository). Their format is internal to Claude Code and may change: the reader degrades a section to `unavailable: <reason>` rather than failing.

## What it reports

| Section | Signal | Definition |
|---|---|---|
| Gates | share of active agent clock spent under gates | active clock = gaps between consecutive transcript entries, each capped at `idle_cap_s`; under gates = wall-clock of Bash calls matching a gate pattern (`gates` in `measure.config.json`: verification · push · deploy · e2e) |
| Branches | commits and review rounds per branch | one branch = one pull request; commits = `git commit` tool calls; review rounds = review invocations (`review_patterns`, `review_agent_patterns`) |
| Rework | share of rework | commits typed `fix`/`revert` over all commits in the window (git); edits that hit a file already edited on the same branch over all edits (transcripts) |
| Governance bytes | injected vs delivered vs read | emitted = hook stdout; delivered = what reached the model's context; **undelivered** = fired with stdout, nothing delivered (wrong channel); truncated = delivered shorter than emitted; read = bytes of Read (or `cat`/`sed`/`head` through Bash) on `governance_paths` |
| Agents | per agent: model, tokens, bytes read, seconds, citations | main session plus every subagent transcript |
| Citations | citations per law / defect-class id | ids defined in `corpus_files` and never cited in the window are **pruning candidates** — decided by the user through RDR with the originating record in view, never deleted by a script |
| Returns | every spawn's return, three channels (EVOL-057) | a spawn = an `Agent` tool use; collected when any channel appeared — **direct** (a foreground spawn's tool result), **hand-back** (an `<agent-message>` from the agent the launch stub named), **notification** (a `<task-notification>` naming the spawn's tool-use id); **uncollected** = none; a roster agent's return (the notification's result, else the direct result, else the last hand-back) is **parsed** or **refused** by the project's return reader (the return check of `python3 scripts/gate.py agents`); an agent outside the roster is unchecked |
| Pushes | pushes by gate profile | from the push log the pre-push hook writes (`gate.py push-log`: profile, base, mode, class, start, end, exit — `config/quality.json → verification.logs.push` inside `verification.seal.dir`); without the log, the trace: `git push` tool calls, the profile from the banner in a foreground result, else **unknown** |
| Loop | the verification loop per gate and per profile | from the timings log the loop's executor writes (`gate.py seal --run`: gate, command, branch, profile, start, end, exit — `verification.logs.timings`); runs, reds, seconds per gate and per profile, hours total |

Every number is per window. Absolute values are this project's own; compare shapes across projects, not digits.

## Before / after — the standard shape of a framework evolution

The obligation of an adopting project, not of the framework repository (which delivers no product and has no feature clock).

```bash
# 1. before the change: take the baseline and attach it to the tracking item
python3 subproducts/measure/measure.py --json --out ../measure-before.json

# 2. adopt the change; let it run for report_interval_days (measure.config.json)

# 3. after the interval: the same report with the before/after table
python3 subproducts/measure/measure.py --compare ../measure-before.json
```

Write both reports outside the repository (they contain session detail). Paste the `Before → after` table on the tracking item. A change whose "after" does not move the signal it targeted is reverted or re-planned — the numbers decide.

The table carries the share of active clock under gates, commits and review rounds per branch, the two rework shares, the governance bytes, and (EVOL-057) the share of spawns whose return was never collected, the share of pushes with an unknown profile, the hours under the verification loop.

## Options

```
--window-days N     window length (default report_interval_days; never above retention_days)
--until ISO         window end (default now)
--transcripts DIR   override the transcripts folder
--repo PATH         repository root (default: git root of the current folder)
--json / --out F    JSON instead of markdown / write to a file
--compare before.json
--selftest
```

Exit codes: `0` report written (partial reports included) · `2` the tool could not do its job (unresolved placeholders, bad config, unreadable repository) — the message says what to do.

## Configuration (`measure.config.json`)

| Key | Set at | Meaning |
|---|---|---|
| `retention_days` | SETUP Q30 | the longest window the reader accepts |
| `report_interval_days` | SETUP Q30 | default window; the interval of the before/after protocol |

Branches: one row per branch (one branch = one pull request); sub-increment branches of a train (`…-inc-{N}-{slug}-sub-{M}`, EVOL-045) also roll up into a per-train table (commits, review rounds, sub-increment branches seen).
| `idle_cap_s` | edit | cap on one gap when summing active clock |
| `gates.*` | edit | regex lists naming the gate commands of this project (verification, push, deploy, e2e) |
| `review_patterns`, `review_agent_patterns` | edit | what counts as a review round |
| `governance_paths`, `corpus_files` | edit | where governance lives and where law / defect-class ids are defined |
| `rework_commit_types` | edit | commit types counted as rework |

The reader names no tool and no stack: adapt the regex lists to the commands this project really runs.

The push log and the gate timings are not configured here: the reader takes their place from `config/quality.json → verification.seal.dir` and `verification.logs` (the loop's own configuration) and reads the project's return reader (`scripts/gate.py`) as a subprocess — it imports nothing from the project.
