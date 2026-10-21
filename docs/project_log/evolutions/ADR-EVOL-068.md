---
id: ADR-EVOL-068
title: "Honest tests — a green is worth what its red was worth"
date: 2026-10-21
status: accepted
---

# ADR-EVOL-068: Honest tests

## Context

This ADR implements issue #122 (epic #112, train row 5b, after EVOL-067). It was verified on `main` at framework 8.16.0.

- **The red is ordered, never proven.** LAW-05 says "written red first". The workers are told red-first. The TDD gate checks only that the test file exists (`Factory-implement-build.instructions.md:1660-1675`). Nothing runs a test without its change, so a test that cannot fail is counted.
- **No lens owns scope or deferral.** The review checks have no "nothing missing, nothing extra" item. "No TODO/FIXME" is one unenforced line (`Factory-implement-review-checks.instructions.md:1303`). Deferral language such as «next slice» is not a finding.
- **Coverage is an aggregate in prose.** The 80 % threshold lives in `rules/testing.md`. No gate produces a per-file table, no lens reads coverage, and files a tool omits are omitted silently.
- **The canary has no planted always-green test and no deferral.** It also asserts exactly two defects per lens.

## Decision

1. **LAW-05 states the red proven.** The sentence becomes: "Every unit of logic has its unit test, proven red without its change: red, green, refactor, verify." Both `CLAUDE.md` files mirror it. The body (`rules/testing.md`) states «a green is worth what its red was worth». A fix's regression test follows DC-30 (#118), which the body cites and never restates.
2. **The red is proven by the loop — the `red` member.**
   - `seal.py` runs it in the full loop. Its read-set is the test roots, so its seal caches the result by the test files' bytes.
   - It checks out the diff base (`gate.py diff-base`) as a `git worktree` in a temporary directory outside the tree.
   - It overlays the test files the diff adds or changes, and links the row's `red_link` paths (for example `node_modules`) from the working tree.
   - It runs `tests.scoped` on those files. Each file must fail.
   - A file that passes at the base is red, with the reason «could not fail».
   - A worktree that cannot be built is red, and its reason names the repair.
   - **Who wrote the test does not matter.** A worker's red-first test and a person's test written after the code (#175) are proven the same way.
   - **CI cost:** one scoped run at the base per loop when test files changed, plus a build for compiled stacks; zero otherwise.
   - **Stacks whose runner cannot run one file** (owner RDR «1», 2026-10-21):
     - The proof runs only where the scoped run executes exactly the file it names: Python and Node/React/Vue/Svelte.
     - The Java, Go, .NET and Rust `tests` rows carry `red: false`. The loop then owes no `red` gate and lists «red not proven for this stack» with its repair, on every run.
     - Their per-file runs are #188 (epic #112), which also states the intermediate state.
     - A frontend-only project has no `tests` gate (its member is `frontend-tests`), so the loop lists «red not proven: no `tests` gate» on every run. Its proof is #188 too.
     - Python's scoped run puts the worktree's `src` first on `PYTHONPATH`, so an editable install of the working tree cannot answer for the base.
     - Rejected:
       - per-file commands for the four stacks now — no toolchain to prove them, and Rust's in-source tests stay unprovable;
       - shipping as delivered — a false block on Rust and false proofs on Java and Go.
   - **Declared limit:**
     - the proof is per file;
     - a new file that fails only because its module does not exist at the base counts as red;
     - whether the assertion itself can fail is the correctness lens's judgement;
     - a moved base alone does not re-run the proof (the seal keys it on the test files);
     - in a mixed stack, a frontend test file under shared roots runs through the backend's scoped command; a runner that collects nothing exits non-zero, so the file counts as red (lenient, never a false block).
3. **Lens checklists** (in `Factory-implement-review-checks`, until #177 moves them to the question catalog):
   - **Correctness:** a test that cannot fail, every edge case of the test plan with its test, one regression test per fix.
   - **Fidelity:** exact scope against the task (nothing missing, nothing extra), and deferral language in code or plan as 🔴.
4. **Coverage per file.**
   - The `coverage` member declares `report:`, an LCOV file of the combined suites.
   - `seal --run` writes `coverage-table.md` into `verification.logs`, one row per file: lines, covered, percentage.
   - A runtime-surface file absent from the report and not declared in `verification.coverage.omit` is listed «not measured».
   - The omit list is materialised empty, and the project declares its entries.
   - The correctness lens receives the table of the last loop run. The loop runs after the critics (EVOL-051), so an increment's first round reads «not measured yet»; the push-gate review reads the table.
5. **The canary** gains correctness `c3` (an always-green test) and fidelity `f3` (a deferral comment). Each lens has at least two planted defects.

## Consequences

- A test that passes without its change stops counting. A fix whose regression test does not reproduce the defect is caught.
- Compiled stacks pay a base build when tests change. The cost is stated here and bounded by the seal's cache.
- A hole hidden behind an aggregate shows as a row.

## Alternatives considered

- **The worker records its red output.** Rejected: that takes the red on the author's word, which the issue forbids, and it cannot cover a test written after the code.
- **Reverting the production files in place.** Rejected: a crash mid-run leaves the working tree corrupted.
- **Mutation testing.** Rejected for now: it is per-stack tooling at a far higher CI cost. The rules keep it optional.
- **Cobertura XML for coverage.** Rejected: LCOV is plain text that every covered stack can emit, and it needs no XML parser.

## Operational Rule

A new or changed test is proven red at the diff base, without its change, by the verification loop. Scope and deferral are judged by the fidelity lens. Coverage reaches the correctness lens as a per-file table with every omission declared.

## Verification record

Delivered on `feature/EVOL-067-verification-loop`, commit 3 of train row 5b (2026-10-21, framework 8.17.0).

- **Red first** (`scripts/gates/test_gates.py`, class `HonestTests` plus the canary and V12 cases):
  - the LAW-05 sentence pinned;
  - the `red` member is built in, reads the test roots, and is refused as a project row;
  - a test that passes at the base is red «could not fail»; one that fails at the base is green;
  - no test change costs nothing (no worktree created);
  - a runner or worktree fault is red with its repair, and leaves no worktree;
  - `red_link` paths are linked from the working tree;
  - `red: false` creates no `red` gate, the loop lists the notice, and a `--full` seal is green without it; a non-bool `red` is refused;
  - a missing `tests.scoped`, missing test roots or a map without `tests` is listed «red not proven», never silent;
  - the registry's Java, Go, .NET and Rust rows carry `red: false`, and Python's scoped run carries the `src` prefix;
  - the coverage table from a planted LCOV: per-file rows, «not measured», an omitted file, «no report declared»;
  - the canary holds with c3 and f3, and a return that misses them reports them.
- **Synthetic materialisations:**
  - default: the red member, the LCOV report, `red_link` and the empty omit list, as the fixture's `expect` states;
  - dotnet: no red member (`expect.red: false`);
  - upgrade-8.12: green.
- **Battery:** every `scripts/test-*.sh`, lock-step pairs, `validate-governance.sh`, `check-adr-constitution-sync.sh`, three synthetic materialisations, `gate.py discovery`, `manifest-parity` and `gate.py profile --run` — green.
