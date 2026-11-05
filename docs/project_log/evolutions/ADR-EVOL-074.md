---
id: ADR-EVOL-074
title: "A pinned SAST base pack for each language a project uses"
date: 2026-11-05
status: accepted
---

# ADR-EVOL-074: A pinned SAST base pack for each language a project uses

## Context

This ADR implements issue #128 (epic #112, train row 6a). It was verified on `main` at framework 8.21.1 and probed in `semgrep/semgrep:1.182.0`.

- **No rules ship.** `rules/security_policy.md` names Semgrep as the code scanner, but no rule pack ships.
- **The slot is empty.** `scripts/gates/seal.py` counts `sast` among the security members, which are never skipped. Yet no registry row configures a `sast` gate, so no project runs one.
- **One gate, one source.** `discovery._merge` refuses a gate configured by two answered sources. A `sast` row on the Node.js backend row and on the React frontend row would collide in a full-stack project.
- **The engine.** Semgrep CE 1.182.0 was released 2026-10-20; its engine is LGPL 2.1. Facts from the probe:
  - `semgrep scan --config <dir> --error` loads every `.yml`/`.yaml` in the directory. It exits 1 on a finding and 0 when clean.
  - `semgrep --test --config <rules> <targets>` pairs a rule file with the target files that share its basename. It exits 1 on a missed or an extra line.
  - CE has no parser for `.vue` or `.svelte`, but a `generic` rule matches them, with HTML comments as annotations.
  - A `generic` rule in the same file as a language rule broke the language rule's test.
- **Licence.** The Semgrep registry rules are licensed for internal use only, with no redistribution. Every rule here is our own text, written from each API's documentation. A pattern that names an API (`tempfile.mktemp(...)`, `InsecureSkipVerify`) is that API's own name, not a copied rule.
- **More probe facts:**
  - `--strict` does not fail on a parse error. A file the engine cannot parse is skipped, and the scan exits 0. With `--quiet` the output does not name it.
  - With no `.semgrepignore`, the engine skips `tests/`, `build/`, `dist/`, `vendor/` and `node_modules/`. A project's `.semgrepignore` replaces that list.
  - A bare `nosem` or `nosemgrep` comment silences every rule on its line.
  - In `paths.exclude`, `/dev/` matches only the root's `dev/`; `dev/` matches a `dev/` directory at any depth.
  - CE does not scan the `<script>` block of a `.vue` or `.svelte` file, nor Razor (`.cshtml`, `.razor`).
  - The named import `import { exec } from 'node:child_process'` is not resolved to `child_process.exec`; the rule names the `node:` forms itself.

## Decision

1. **Packs.** Seven template files, `security/sast/<pack>.yml`. Each lands only when the stack answers select it (`stack_conditional` on the registry literals):

   | Pack | Selected by |
   |---|---|
   | `python.yml` | `backend.runtime` Python |
   | `javascript.yml` (JS and TS) | `backend.runtime` Node.js, or `frontend.framework` React, Vue.js, Angular, Svelte, Solid |
   | `ui-templates.yml` (generic) | `frontend.framework` Vue.js, Svelte |
   | `java.yml` | `backend.runtime` Java |
   | `go.yml` | `backend.runtime` Go |
   | `csharp.yml` | `backend.runtime` .NET |
   | `rust.yml` | `backend.runtime` Rust |

   - **Rule ids** follow `<pack>-<class>`, and every rule is `severity: ERROR`.
   - **Classes:**
     - debug mode outside development;
     - an insecure temporary file;
     - autoescape disabled or raw HTML;
     - a shell running non-literal input;
     - TLS verification disabled.
   - **Coverage:** each rule covers the common forms it names, not every form. The security lens reads the rest.
   - **Gaps:** a class with no idiom in a language has no rule there. Each pack's header names its gaps: Java raw HTML, Rust debug mode, C# Razor files, the script blocks of `.vue`/`.svelte` files.
   - **Angular:** no rule. Angular sanitises `[innerHTML]`; its bypass (`bypassSecurityTrustHtml`) is a `javascript.yml` rule.
   - **Development-only paths** are excluded from the debug rules by anchored globs: the root's `/dev/`, `/local/`, `/development/`; `tests/` and `test/`; file names such as `settings.dev.py`, `local_settings.py` or `config_local.go`. A substring glob such as `*dev*` would also exclude `src/devices/`, and an unanchored `local/` would exclude `src/auth/local/`, so neither is used.
   - **Pin:** each pack names the engine it is proven on, `semgrep 1.182.0`.
2. **One `sast` member.** A derived registry entry configures `verification.gates.sast` under a new `when` condition, which is the union of the pack conditions. The entry is the gate's one source, so a Node.js + React project gets one row.
   - `discovery.configures` evaluates a derived `when`.
   - Validator V5 checks a derived `when` like any other condition.
   - The command is `semgrep scan --config security/sast --error --metrics=off --disable-version-check --quiet .`.
   - The target `.` is explicit. Probed: in the semgrep image with no target, the engine resolves a relative `--config` against `/src`, and exits 7 when the project is anywhere else.
   - The derived key `quality.sast` gets a slot in the setup frontmatter. It records the packs that landed.
   - **Governed path.** `security/sast/**` is a gate input. In a project it is a governed path, planned like `config/**`.
   - **Suppression.** A finding is suppressed only by `nosemgrep: <rule-id> — <reason>` on its line. The security loop blocks a bare `nosem`/`nosemgrep` added in the diff (`[SEC-SAST-005]`) and a changed `.semgrepignore` (`[SEC-SAST-006]`, a governed path). The security lens reviews every new suppression. The framework's own scripts carry five, each with its reason: the configured gate commands run with `shell=True` in `seal.py`, and the registry rows under test in `test_gates.py`.
3. **No pack, no member.** A stack the packs do not cover (Ruby, PHP, Elixir, or no code language) gets no `sast` row. Its setup report states that it has no SAST pack.
4. **The security loop runs the member.**
   - The exit code is the verdict: a finding is a blocker, and an engine fault is a blocker.
   - An engine that is not installed is a blocker, because a security member is never skipped (LAW-04).
   - A framework pack present with no `sast` row is a blocker (`[SEC-SAST-004]`): the member never vanishes. A project's own rule file on a stack with no pack needs the row the project adds itself.
   - An engine other than 1.182.0 still runs the packs, with a warning: the packs are proven on 1.182.0.
   - The security lens reads the member's result. It does not re-derive the patterns the packs cover.
5. **Upgrade.** `SETUP --upgrade` Step 8b already lands the templates a project lacks (`templates_to_add`). It also adds a derived gate the project does not have (`gates_upgrade` → `added`). One line is new: the upgrade reports `added`, so the project learns to install semgrep, and `planning.governed_paths` gains `security/sast/**` and `.semgrepignore` when absent.
6. **Proof in meta CI.** A job `sast-packs` in `semgrep/semgrep:1.182.0` runs `scripts/test-sast-packs.sh`. The script checks:
   - every rule has at least one `ruleid:` fixture and at least one `ok:` fixture;
   - `semgrep --test` passes, with as many tests as there are rules;
   - for each synthetic answer set, a scratch project holds the tree the framework delivers to that stack plus the selected packs. The resolved `sast` command is red on a planted defect and green without it, so the delivered tree itself scans clean;
   - over every `backend.runtime` × `frontend.framework` option, the derived `when` holds exactly when some pack lands;
   - the debug exclusions are anchored: a debug switch under `src/devices/` or `src/auth/local/` is red; under the root's `dev/`, in `settings.dev.py` or `local_settings.py` green.

## Consequences

- Every project whose languages have a pack scans them on every full loop, and a finding blocks the seal.
- A project must install Semgrep (`pipx install semgrep==1.182.0`, or the pinned image). Until it does, the `sast` member is red.
- CE analysis is single-file: cross-file taint is out of reach. The security lens keeps its pattern library for what no pack covers.
- A file the engine cannot parse is skipped silently. The packs do not see it; the security lens does.
- Code under the engine's default ignore list (`build/`, `dist/`, `vendor/`) is not scanned. That list holds generated and vendored code.
- Moving the engine pin means re-running the proof job. The packs and the job move together.
- PHP (#129) and the BaaS client rules (#149) add their packs on this mechanism, as one more template with a `stack_conditional` and a literal in the derived `when`.

## Alternatives considered

- **A `sast` row on each Q5 and Q9 option.** A full-stack project's two rows collide in `_merge`. Rejected.
- **One gate per language (`sast-python`, …).** These are not in `seal.SECURITY`, so they could be skipped. Rejected.
- **A discovery question for the SAST tool.** The stack answers already decide it (#128 «we do not want»). Rejected.
- **The Semgrep registry rulesets (`p/python`, …).** Their licence forbids redistribution, and fetching them needs the network and is not pinned. Rejected.

## Operational Rule

No new law. The `[LAW-04]` sentence is unchanged; its records add `ADR-EVOL-074`. `rules/security_policy.md` § Static Analysis names the packs, the member, the pinned engine and the covered classes. The change is a rule-file edit plus a manifest bump.

## Verification record

Each case was proven red at the base, then green:
- `test_gates.py`: a derived `when` landing and not landing; Node.js + React gives one row with no collision; V5 on a derived `when`.
- `scripts/test-sast-packs.sh` in `semgrep/semgrep:1.182.0`: 30/30 rule tests (after the round-2 cure: the shell and TLS forms the critics named — Python `args=` and `sh -c` lists, the JS `spawn` family through every import form, OkHttp, Apache's socket factory, a held or anonymous `HostnameVerifier`), both-ways coverage, the planted defect per answer set on the delivered tree, the one condition, the anchored exclusions. Each new proof was red on a mutated copy: a `nosemgrep` removed from the delivered `seal.py`, a `*dev*` exclusion, an unanchored `local/` exclusion, a `when` naming Ruby.
- A synthetic materialisation per answer set.
- Critics, two rounds on four lenses (fidelity, correctness, security, governance). Round 1: one 🔴 (the delivered tree unscanned) and the 🟡 above, cured. Round 2 on the cure diff: no 🔴; its 🟡 cured in session (the shell and TLS forms, root-anchored exclusions, the suppression checks, the `[SEC-SAST-004]` guard, this record). Accepted by the adjudication default after round 2: the declared gaps (the silent parse skip, the engine's default ignore list, the forms a header does not name).
