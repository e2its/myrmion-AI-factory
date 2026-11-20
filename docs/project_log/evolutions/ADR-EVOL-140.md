---
id: ADR-EVOL-140
title: "The measure instrument counts calls to a context-compression tool — calls, retrieve ratio, bytes in and out, and a payload audit traced to each call's source"
date: 2026-11-20
status: accepted
---

# ADR-EVOL-140: Compression calls in the measure instrument

## Context

This ADR plans issue #253 (epic #112, wave 5, destination S). It is follow-up A of spike #142 (ADR-EVOL-088), whose measured run needs it. It was checked on `origin/main` at framework 10.10.1 (8dcab6d).

- **No MCP counter today.** `subproducts/measure/measure.py` classifies tool uses by name only for Read, Bash, Agent and the edit tools (`Session._classify_use`, `Session._tool_result`). A window cannot tell «the tool was never offered» from «the tool was offered and not used». #91's «0 calls» stayed ambiguous for that reason.
- **The tool's real contract.** `headroom_compress` takes one argument, `content` (a string), and returns compressed text plus a hash. `headroom_retrieve` takes that `hash`. The call does not say where its content came from, so the source has to be traced.
- **The rule to audit** (ADR-EVOL-088 Q1, `rules/agents.md` payload-verbatim invariant): only evidence of a state may be compressed. Evidence means a log the executor already wrote to a file; `gate.py seal --run` writes `<seal dir>/loop-*.log`. Code, paths, identifiers, errors to fix, hand-offs, the notebook, artefacts and a user's words are work input and stay verbatim. Anything ambiguous counts as work input.

## Decision

1. **One config key, in the universal part of `measure.config.json`:**
   `"compression": {"compress": [], "retrieve": [], "evidence": ["(^|[/\\s])loop-[^/\\s]*\\.log\\b"]}`.
   - `compress` and `retrieve` hold exact MCP tool names. Both are empty by default: the framework names no vendor, and the project that wires a tool lists it.
   - `evidence` holds regexes matched against the source tool's target: a Read's `file_path`, or a Bash `command`. The default names the executor's `loop-*.log` only: a user's or a CI log may hold the error being fixed, which is work input (ADR-EVOL-088 Q1).
   - If the key is absent or `compress` is empty, the section reads `unavailable: no compression tool configured`. It is never a silent 0.
2. **Source trace, mechanical.**
   - A compress call's sources are the earlier tool results, in the same transcript, whose text contains the call's `content` (stripped).
   - The call is `evidence` when every source came from a Read or Bash whose target matches an `evidence` regex.
   - It is `work-input:<tool>` when any source came from another tool or target; the newest such source names it.
   - It is `work-input:authored` when the content copies no earlier result. An unproven source is work input.
   - A Read result is also matched without the `N<tab>` line prefix the harness writes on every line.
   - A compression tool's own result is never a source: content recompressed after a retrieve traces back to the original read.
   - Every earlier result that contains the content counts: the call is evidence only when each of them is. A text held by a source file and by a loop log is ambiguous, so it is work input (Context, last line).
   - With no retrieve tool listed, retrieve per compress is None: unmeasured, never 0.
   - ADR-EVOL-088's size floor (`context_result_max_kb`) is not applied. It decides whether a compress is worth its cost, which the bytes-in median shows; the audit asks only whether the payload is evidence.
   - Earlier results are kept only while a compress tool is configured, in memory, at most the size of the transcript the instrument already reads. A project without one pays nothing.
3. **Report section `compression`.**
   - Each main session counts with its subagents' transcripts.
   - Per session it gives compress calls, retrieve calls, bytes in, bytes out, and work-input calls.
   - Overall it gives sessions, sessions with a compress call and their share (ADR-EVOL-088 Q3 criterion 3), calls, compress calls per session, retrieve per compress (None with no compress call), bytes in and out with per-call medians, and the payload audit (`work_input_calls`, by source; the target is 0).
   - Bytes are characters of the transcript text, like every other byte figure of the instrument.
4. **`--compare`** gains six scalars:
   - compress calls per session;
   - retrieve per compress;
   - bytes in and bytes out;
   - share of sessions with a compress call;
   - work-input calls.
5. **Runbook.** One Signals row and one Config row. Upgrade note: `measure.config.json` is the project's own file and is never overwritten. A project adds the key when it wires a tool, and the section stays `unavailable` until then.

Nothing else ships: no command, no flag, no SETUP question, no registry row, no gate reading the subproduct. No baseline is claimed from this repository.

## Consequences

- #142's run can prove that a window wired the tool. It reads criterion 3 and the payload audit, criterion 4, straight from the report, and no agent computes them.
- The audit is a signal people read, never a gate: a command that only names a loop log reads as evidence.
- The audit is strict by design. A compress call on content the agent paraphrased counts as work input, even if its origin was a log. The policy wants exactly that: what is compressed must be the original evidence.
- Matching by containment costs a linear scan of the earlier results per compress call. It only runs when a tool is configured, and compress calls are few per session.

## Verification

- `measure.py --selftest` uses a new fixture: two main sessions and one subagent.
  - Session A has an evidence log with repeated blocks, a source file, an authored text and one retrieve, then a CI log read through Bash, a search result, a text read from a note and from a loop log, and the evidence log compressed again after the retrieve. Read results carry line-number prefixes.
  - The subagent tails a log through Bash.
  - Session B makes no call.
  - Expected:
    - 8 compress and 1 retrieve;
    - ratio 0.125;
    - share 0.5;
    - 5 work-input calls (`work-input:Read` 2, `work-input:Bash`, `work-input:Grep`, `work-input:authored`) and 3 evidence;
    - exact bytes;
    - `unavailable` without the key;
    - the compare rows present.
- `scripts/test-measure.sh` reads calls, the ratio, the share, bytes and the audit by source through the synthetic materialisation, with the shipped evidence default, plus the documented-key list. Both are red on origin/main.
- A mutation sweep in scratch copies must kill each of these mutants: no trace, no evidence match, subagents not counted, unavailable collapsed to 0, only the newest source read, a retrieve result kept as a source, the line prefix not stripped, and every Bash source taken as evidence.
