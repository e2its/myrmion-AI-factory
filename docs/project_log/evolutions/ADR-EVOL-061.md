---
id: ADR-EVOL-061
title: "The manifest bump as a tool, not a ritual — one helper moves the entry, the framework version and the changelog line in the checked shape"
date: 2026-10-06
status: accepted
---

# ADR-EVOL-061: The manifest bump as a tool, not a ritual

## Context

Issue #96, axis O of the 2026-10 evolution (#91). Downstream: 185 commits to the governance manifest in 35 days; 10.6 % of agent hours spent editing governance, up from 6.7 % in the baseline window. The changelog check (`scripts/validate-governance.sh` CHECK 1b: every tracked file changed on the branch has its entry's version advanced against the base manifest; `gate.py manifest-parity`: a file's frontmatter `version:` equals its entry) is right to exist — its own precedent is a version bumped with no line describing it — and every line is typed by hand: the entry's version, the changelog line in the entry's shape (`"<version>: <note>"`), the file's frontmatter when it carries one, `framework_version`, `last_updated`, the `description` prefix. The check refuses the first attempt often enough that the retry is a visible cost. No helper exists in the framework or in the template tree.

Execution delegated by the user (2026-10-06); agent-internal choices under the rules of transfer of #91.

## Decision

- **One helper, in the reader** — `scripts/gates/manifest.py` (a lock-step pair by the gates package) behind `python3 scripts/gate.py manifest`:
  - `--bump --entry <path> [--entry …] --level patch|minor|major --note "<what and why>" [--framework patch|minor|major] [--base <ref>]`: resolves each path to its entry (the meta repo: `framework_core` by the entry's `path`, `templates` under `.context/templates/setup/`, `agent_templates` under `.context/templates/`; a project: by the entry's `target`), moves the version by the level, prepends the changelog line in the entry's shape (`"<new version>: <note>"`), moves the file's frontmatter `version:` when it carries one (manifest-parity holds by construction), and — with `--framework` — moves `framework_version`, sets `last_updated` to today and prefixes `description` with `"v<version> (<branch>): <note>. "`. The note is mandatory and never empty.
  - **Idempotent over an entry already moved on the branch**: against the base manifest (`git show <base>:<manifest>`, the base from the branching grammar's one diff base or `--base`; no base → every entry moves), an entry whose version already advanced is not moved again — its top changelog line's note is replaced only when the note differs; the same call twice changes nothing.
  - `--new <path>` adds an entry at `1.0.0` in the section the path belongs to (the framework repo only: `framework_core` with its `path`, `templates`/`agent_templates` with `content_type: universal` and the materialisation `target` — the key under the section's root), with the note as its first changelog line.
  - `--check --entry <path> …`: verifies without writing — every entry advanced against the base, its top changelog line starts with its version, the frontmatter in parity, `framework_version` advanced when the entries moved; exit 1 with every reason.
- **The check does not change** (`validate-governance.sh`, `manifest-parity`): it verifies the same line whether a helper or a hand wrote it. The helper touches the manifest and the files' frontmatter `version:` lines, nothing else.
- **The sites that bump use the helper**: the governance write protocol (`factory-governance-loading/SKILL.md § GWP`) names the command as the procedure; the IMPLEMENT build's platform worker step and the discovery protocol's bump step call it; `CLAUDE.md` Generation Standards §2 names it on both lock-step sides.
- **The measurement subproduct** gains two signals in the before/after table: `governance.manifest_commits_per_week` (commits touching the manifest in the window, from `git log`, per seven days) and `governance.hours` (the sessions' active clock weighted by the share of their edits on governance paths — `config/quality.json → measurement.governance_paths`), beside `governance.edit_share`.
- **Dogfood**: this evolution's own bumps are written by the helper (`--entry` for every touched file, `--new` for the module, `--framework minor`).

Risk: a path that matches no entry is refused (never added silently — `--new` is the explicit act). Risk: the `description` prefix is prose the helper writes once per framework bump; a second `--framework` on the same branch moves the version again only when the base says it has not moved — the idempotency rule applies to it too.

## Consequences

- Upgrade (`Factory-setup-upgrade.instructions.md` Step 8): the helper arrives with the gates refresh (`gate.py` and `scripts/gates/**` are lock-step pairs); a project keeps typing lines by hand until then — the check is unchanged either way.
- `framework_version` 8.8.0 → 8.9.0 (MINOR: a new subcommand, new signals).

## Alternatives considered

- **A hook that bumps on commit** — rejected: a bump without its note is the drift the check exists for; the note is the decision, the hook cannot write it.
- **The changelog line derived from the commit message** — rejected: the line names what and why for one entry; a commit names a change across many; the GWP's `kind from commit prefix` stays a hint for the level, never the note.
- **A separate script outside the gates package** — rejected (DC-29, LAW-12): the reader already owns the manifest's shape (`coherence.manifest_path`, `ROOTS`, parity) and travels as a pair.

## Operational Rule

No universal sentence changes. The body of the governance write protocol names the helper as the procedure; Generation Standards §2 names the command.

## Verification record

Red-first on synthetic repositories (`scripts/gates/test_gates.py` class `Manifest`): a new entry; several entries in one call; the framework moved with them; an empty note refused; a path matching no entry refused; idempotence over an entry already moved on the branch (against a git base); the frontmatter moved with the entry; `--check` red on an entry not advanced and green after the bump; a project manifest resolved by `target`. `materialize-synthetic.sh`: the helper on the materialised tree. `test-measure.sh`: the two signals pinned. Suites on the delivered bytes: test-gates 66 (class `Manifest`: three tests, every case above), materialize-synthetic 105 (the empty note refused; a materialised rule bumped by target with parity holding), test-measure 25 (the governance signals pinned on the fixture: share 0, hours 0, the two keys in the before/after table, the section rendered), test-hooks 107, test-code-review-gate 17, lock-step 75 / 16 (the module is a pair), validate-governance, manifest-parity, templates-static, ADR sync, applicability, one-definition, budget, retired-terms, runtime-surface — green. **Dogfood**: this evolution's fourteen entries, the two new ones and `framework_version` were written by `gate.py manifest --bump … --new … --framework minor` in one call; `--check` green on the result.

The push gate's lenses under RDR-3 — recorded below as it happens.
