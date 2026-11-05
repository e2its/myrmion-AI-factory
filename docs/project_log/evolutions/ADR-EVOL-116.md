---
id: ADR-EVOL-116
title: "A test runs as one file on every stack"
date: 2026-11-05
status: accepted
---

# ADR-EVOL-116: A test runs as one file on every stack

## Context

This ADR implements issue #188 (epic #112, train row 5f). It was verified on `main` at framework 8.20.0, and probed in pinned containers: `golang:1.23`, `rust:1.83`, `maven:3.9-eclipse-temurin-21` (Surefire 3.5.2, JUnit 5.11.4), `mcr.microsoft.com/dotnet/sdk:8.0` (VSTest, xUnit) and `node:22` (vitest 3, Jest 29, mocha 10, Angular CLI 22 with its vitest unit-test builder).

- **Four rows select by name, not by file** (`discovery_registry.json`):
  - .NET `--filter {paths}` and Rust `cargo test {paths}` exit 0 with no test run (`No test matches the given testcase filter`, `running 0 tests`).
  - Java `-Dtest=src/test/java/…` fails with `No tests matching pattern`.
  - Go `go test <file>` fails to compile without the package's other files.
  
  These four rows carry `red: false`.
- **A run that ran nothing often exits 0.** Go (`[no tests to run]`), Rust (`running 0 tests`), Maven (`Tests run: 0`), VSTest and mocha (`0 passing`) all exit 0 on a file with no test.
  - pytest (exit 5), vitest (`No test suite found`), Jest (`No tests found`) and Angular exit non-zero.
  - A worker's red-first run on the first group shows a green that tested nothing.
  - `seal.red_proof` runs only at the base (`scripts/gates/seal.py:705-762`). A file that selects no test at the base exits 0 there and reads «could not fail». On pytest or vitest the same file exits non-zero and reads «proven red».
- **The red member reads the `tests` gate only** (`seal.vcfg`, `out_gates.get("tests")`). As a result:
  - A frontend-only project gets «red not proven: no `tests` gate» on every run.
  - In a full-stack project, a frontend test file is run with the backend's scoped command.
- **The red member reads `traceability.test_roots`.** Python's `tests/**` covers `conftest.py`, and Rust's `src/**` covers the production code.
- **Rust's unit tests live in the file they test.** Copying the changed file over the base also brings the change, so the test always passes.
  
  A graft probe split each file at its first `#[cfg(test)]` line: the base file's body, followed by the head file's lines from that line on. All three cases came out right:
  - a new function's test does not compile at the base: red;
  - a bugfix test fails at the base: red;
  - a test that asserts nothing new passes at the base: could not fail.
- **Angular's row is broken today.** On Angular 22 (the vitest unit-test builder), `--browsers=ChromeHeadless` fails, because the option needs a `@vitest/browser-*` package. `npx ng test --no-watch` runs. The row has no `scoped`.

## Decision

1. **A scoped run that ran no test is red, in the run itself.**
   - Where the runner exits 0 when nothing ran (Java, Go, .NET, Rust, mocha), the registry row's `scoped` wraps the runner in a POSIX check:
     ```
     out=$(<runner> 2>&1); rc=$?; printf '%s\n' "$out"; [ "$rc" -eq 0 ] || exit "$rc"; printf '%s\n' "$out" | grep -qE '<a test ran>' || { echo 'scoped run: no test ran'; exit 1; }
     ```
     The «a test ran» patterns:
     - Maven: `Tests run: [1-9]`;
     - Go: `^=== RUN`;
     - Rust: `running [1-9][0-9]* tests?`;
     - VSTest: `[Tt]otal: *[1-9]`;
     - mocha: `[1-9][0-9]* (passing|failing)`.
   - pytest, vitest, Jest and Angular already exit non-zero, so their rows stay plain.
   - Every consumer gets the same verdict from the exit code: the worker's red-first run, the BVL phase run, the review checks and the seal. No consumer parses runner output, and the stack names stay in the registry rows (#121).
2. **Per-file selection lives in the row's own command, over any number of paths.**
   - Java: `-Dsurefire.failIfNoSpecifiedTests=false -Dtest=<class names from basename, comma-joined>`. The flag lets a multi-module build skip the modules without the class.
   - Go: `go test <unique package dirs> -run '^(<the files' Test names from sed>)$' -v`.
   - .NET: `--filter "<FullyQualifiedName~.Class. per class in the files, from awk>|FullyQualifiedName=_"`. The last alternative is a sentinel that matches nothing, so the filter is never empty.
   - Rust: `--test <stem>` per `tests/*.rs` file.
   - Jest: `--runTestsByPath {paths}`.
   - Angular: `--include=<path>` per file.
   - vitest and mocha: the paths themselves.
   
   The rows add no new token: workers, BVL, the review checks and the seal interpolate `{paths}` as before, with one or many files. The seal runs one file per run, so each file gets its own verdict.
3. **The red proof runs each changed test file at the head first.** It runs in the working tree, with the row's `scoped`.
   - A non-zero exit at the head is red: «fails at the head or runs no test — <the run's last line>».
   - Then it runs at the base, and the exit code decides:
     - 0 → could not fail;
     - 126 or 127 → could not run;
     - any other code → proven red. A compile or import failure counts, because the test cannot exist without its change.
4. **Every gate row with `scoped` is a red source.** No gate name is special.
   - A row declares `red_reads`: the globs of the test files it proves. They default to `traceability.test_roots`.
   - The template rows follow each runner's naming:
     - Python `tests/**/{test_*,*_test}.py`;
     - Node and the frontends `{tests,src}/**/*.{test,spec}.*`;
     - Java `**/src/test/**/*{Test,Tests,TestCase}.java`;
     - Go `**/*_test.go`;
     - .NET `**/*{Test,Tests}.cs`;
     - Rust `tests/*.rs`.
     
     A helper (`conftest.py`, `tests/common/mod.rs`) is not a test file.
   - A changed file is proven by the first row, in declared order, whose `red_reads` hold it. The red member reads the union of those reads.
   - A frontend-only project proves its red through `frontend-tests`. A full-stack project proves each file with its own runner where the rows' reads differ; where they overlap, the next point applies.
   - The notice names what is missing, per row: no `scoped`, no reads, or a project's own `red: false`. `red: false` stays valid only as that opt-out; no template row carries it.
   - A glob two rows both read goes to the first row, and the notice says so. The JavaScript backend and frontend rows read the same globs, so a Node.js plus JavaScript-frontend project is told to give the frontend row its own `red_reads` — on the seal's plan and run, and on every `seal --scoped` call the worker's red-first run makes (BVL `SCOPED_RUNS` shows it). The registry cannot know where a project keeps its frontend, so the default never guesses a directory.
5. **Rust's in-source unit tests are proven by a graft** (owner RDR «2», 2026-11-05: they are proven, not a declared limit).
   - A row may declare `inline: {start, reads, scoped}`:
     - `start` is the regex of a test block's first line; for Rust, `^#\[cfg\(test\)\]\s*$`;
     - `reads` are the files that hold code and tests together; for Rust, `src/**/*.rs`;
     - `scoped` runs the test functions named in the files: `cargo test -- __none__ <the #[test] fn names>`. `__none__` keeps the filter from ever being empty.
   - A changed file under `inline.reads` is a test file when it matches `start` exactly once at the head, and its tail from `start` differs from the base's tail.
   - The red proof writes into the base worktree the base file's lines before its own `start`, followed by the head file's lines from `start` on. With no `start` at the base, the whole base file comes first; when the file is new, nothing does.
   - A file that matches `start` more than once, at the head or at the base, is declared «not proven: more than one test block». It is never guessed.
   - The rule is data, not stack code.
6. **The worker's run goes through the same dispatch** (owner RDR «1», 2026-11-05).
   - `gate.py seal --scoped PATH[,PATH…] [--json]` is the one reader. For each red-source row that holds some of the paths, it returns `{gate, files, command}`, with `command` interpolated. It also lists the paths no row reads.
   - BVL (the task loop, the phase run, `RESOLVE_INCREMENT_TEST_CMD`, the seed checks) and the review checks call it instead of interpolating `tests.scoped`. Its dispatch is the seal's own, by construction.
   - A test file no row reads blocks the loop (`UNDECLARED_STACK`), alone or beside routed files. A file that runs nowhere never passes.
   - Each path is one shell word: quoted, and `./`-prefixed when it starts with `-`.
   - It passes the CLAUDE.md § Generation Standards 4 bar:
     - Without it, a frontend-only project cannot run red-first: BVL blocks on `UNDECLARED_STACK`.
     - A full-stack project runs its frontend tests with the backend runner.
     - The benefit is one definition of the dispatch, with no hand-written glob.
7. **Upgrade, computed by a script.** `gate.py discovery --resolve` (project mode) reads the project's `verification.gates` against the derived rows and returns the merged rows with three lists:
   - `added`: a derived field the project lacks;
   - `replaced`: a project value equal to a value the registry row lists in `was`, that is, a superseded template value;
   - `kept`: a project value that differs from both the derived value and every `was` value.
   
   `SETUP --upgrade` writes the merged rows and names the `replaced` and `kept` lists. `was` is registry data only and never lands in the project.
8. **Angular.** `command` drops `--browsers=ChromeHeadless`, which the current builder refuses, and `scoped` is added. The old `command` is a `was` value.
9. **Proof in meta CI.**
   - A synthetic materialisation per stack (Java, Go, .NET, Rust, frontend-only) produces the new rows.
   - `scripts/test-red-stacks.sh <stack>` runs in that stack's pinned container, in a CI matrix job. On a fixture git repository with a passing file, a failing file and a file with no test, the red proof gives proven, could not fail and fails-at-the-head. The Rust job adds the in-source graft.

## Consequences

- A new test is proven red on every stack the templates offer, and a run that ran nothing is red everywhere, in every consumer.
- Each changed test file costs one more scoped run, at the head.
- The rows carry POSIX shell that is less readable than a token. The container job is what keeps each of them true.
- A file named like a test that holds no test (a Go `export_test.go`, an abstract `BaseTest.java`) is refused until the project narrows `red_reads`.
- JavaScript runners fail a multi-file run when one named file holds no test. The other runners pass it when one file ran a test.
- A file with more than one inline test block is declared unproven, and the loop's green says so.
- The Rust inline row names `#[test]` functions only. A source file with only `#[tokio::test]` or `#[rstest]` tests is red at the head (no test ran). Beside `#[test]` functions, those tests run nowhere until the project edits the row.
- A test of a brand-new function is red at the base because it does not compile. That is true on every stack: it proves the test is new, not that it is strong. Mutation testing would prove its strength, which is a separate issue.

## Alternatives considered

- **A `ran` regex per row, read by the seal.** It would protect the seal only: a worker's run would still read a run that ran nothing as green. Rejected.
- **New tokens (`{stem}`, `{names}`) resolved by the seal.** Every consumer, workers included, would need the resolver. Rejected (DC-29, CLAUDE.md § Generation Standards 4).
- **Exit-code semantics per row (pytest 5, the Microsoft Testing Platform's 8).** Maven, Go, Rust, VSTest and mocha exit 0. Rejected: not enough.
- **Rust's in-source tests as a declared limit, or a convention requiring `tests/`.** Owner RDR «2».
- **Mutation of the change (`cargo-mutants --in-diff`).** Probe: 7 of 7 mutants caught with a strong test, 2 missed with a weak one (exit 2). It is better designed once for every stack. Rejected here.

## Operational Rule

No new law. `rules/testing.md` § the red proven (LAW-05) is edited: a run that ran no test is red, and the red proof runs the file at the head before the base. That is a rule-file edit plus a manifest bump.

## Verification record

Red first, then green:
- `test_gates.py::HonestTests`:
  - a head failure is red;
  - a non-`tests` row is a red source;
  - per-row dispatch in a full-stack project;
  - `red_reads` leaves a helper out;
  - the inline graft: one block, a new file, an unchanged tail skipped, two blocks declared;
  - the upgrade merge (added, replaced, kept).
- `scripts/test-red-stacks.sh <stack>` in its pinned container: proven, could not fail, fails at the head. The Rust job adds in-source.
- A synthetic materialisation per stack.
