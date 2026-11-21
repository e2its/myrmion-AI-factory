---
id: ADR-EVOL-138
title: "Project extension points — a project's additions live in project-owned homes the framework reads"
date: 2026-11-21
status: accepted
---

# ADR-EVOL-138: Project extension points

## Context

This ADR plans issue #249 (epic #112, wave 5). It was checked on `origin/main` at framework 10.16.0 (02bccff).

Since EVOL-136, sync replaces a framework-owned file whole. Every instruction that tells a project to add something to a framework-owned file therefore loses the addition on the next sync. Issue #249 asks for four things:

- a project-owned home for gate members that the profile reads;
- the CI template comment re-pointed;
- a sweep of «edit this framework file» instructions, each given a project-owned home;
- a migration that moves the members found in an installed `profile.py`.

It does not want a member lost on sync, and it does not want a second member list.

Evidence:

- **Gate members.**
  - `scripts/gates/profile.py:34-82` holds `MEMBERS`, a tuple list owned by the framework (`delivery: both`).
  - Its readers are `owed()`, `_members()`, `freeze._gates()` (`freeze.py:161`) and `gate.py` `cmd_profile`.
  - The GitHub CI template says «Add project-specific gates as further members in scripts/gates/profile.py» (`workflows/governance-check.github-actions.yml:13`).
- **Documentation servers.**
  - [LAW-10]'s allowlist is read only from the framework-owned `factory-mcp-docs-scan/SKILL.md` frontmatter (`agents.py:133`).
  - The reader `factory-docs-reader.md` is framework-owned and spawned by name in eight places.
  - Claude Code uses the highest-precedence same-name definition whole, never merged, and no settings key widens a subagent's `tools:` (code.claude.com/docs/en/sub-agents).
- **Turn caps.**
  - `worker_turn_cap` and the tier budgets live in the project-owned `rules/agents.md`.
  - The validator wants every framework-owned definition's `maxTurns` equal to them (`agents.py:265-273`). So a project that changes a key turns red, and the only cure is an edit that sync reverts.
- **DAST false positives.**
  - `policies/dast.md:35` sends them to `zap-config.yaml`. That file is framework-owned and read by nothing: `security-scan.sh` runs the packaged ZAP scans with `-g gen.conf`.
  - The packaged scans take exclusions from a `-c` rules file: tab-separated `ID<TAB>IGNORE|INFO|WARN|FAIL<TAB>name`, or `ID<TAB>OUTOFSCOPE<TAB>regex`, the path relative to `/zap/wrk` (zaproxy.org docker baseline, full and API scan pages; `zap_common.py` `load_config`).
  - An Automation Framework YAML is run only by `zap.sh -cmd -autorun`.
- **Prose that sends a project into a framework file:**
  - `claude/framework.md:149`, which also says framework files are not in the project manifest, contrary to EVOL-136;
  - the `factory-pr-review` README § Customization and `SKILL.md` § Customisation;
  - `severity-mapping.md:5`;
  - `rules/contract-first-policy.md` § Integration;
  - `Factory-setup-upgrade` (the EVOL-058 step adds `maxTurns` by hand);
  - `backlog-tool-adapters/README.md` § Authoring;
  - `rules/README.md` § Adding New Templates;
  - `rules/frontend_architecture_compatibility.md` (a checklist path that does not exist in a project).

## Decision

1. **One member list, two homes.**
   - The project's rows live in `config/quality.json → profile.members`, a seam merged add-only by key. The default is `[]`. Each row is `{name, runner, needs_build, needs_database, owner}`; `runner` is a non-empty list of strings, or `null` for an agent-run member.
   - `profile.members(repo)` returns `MEMBERS` followed by the project's rows, never `meta_only`. It is the one list every reader takes.
   - A malformed key raises `GateFault`. Any of these makes it malformed:
     - it is not a list;
     - a row lacks a key;
     - a name collides with a framework member or repeats;
     - a runner is not a list of strings.
   - `run` reports the fault as one RED row, `profile.members`, while the framework members still run: all-report, never a silent drop.
2. **The migration (EVOL-136 registry path).**
   - Registry row `profile members (EVOL-138)`: since 10.17.0, detected by `governance_features.project_members_v1`, with its anchor in `Factory-setup-upgrade`.
   - Sync overwrites `profile.py` before any migration, so the anchor reads the committed one (`git show HEAD:scripts/gates/profile.py`).
   - The pure function `profile.installed_members(text, known)` parses its `MEMBERS` with `ast` and returns each literal row whose name the delivered list lacks. A non-literal element is refused.
   - The anchor merges the rows into `profile.members` by name, add-only, and stamps the feature.
     - It refuses, humanised, on a git failure or a non-literal row, and nothing is stamped then.
     - A second run changes nothing.
   - Materialisation stamps the feature from the start.
3. **Documentation servers — the owner's RDR «1+» (2026-11-21).**
   - **Option 1 was chosen:** the project declares its servers and sync completes the reader. It was preferred over a project-owned second reader (a copy that drifts, eight spawn sites) and over a banner-only key (a source nobody reads).
   - **The "+":** the framework's own list widens with the vendor-official, documentation-only servers verified at source:
     - `microsoft-learn` (learn.microsoft.com/api/mcp);
     - `cloudflare-docs` (docs.mcp.cloudflare.com/mcp);
     - `google-developer-knowledge` (developerknowledge.googleapis.com/mcp);
     - `terraform`, the HashiCorp registry toolset's read operations only.
   - **Left out:** servers whose documentation tool sits beside write tools (Stripe, Vercel, Supabase, MongoDB, GitHub). A project adds those through its key.
   - **The key** is `config/quality.json → agents.docs_servers: {server: [read operations]}`, a seam, default `{}`.
   - **The allowlist:** `agents.docs_servers(repo)` is the skill's list plus the key's servers.
   - **Sync** writes the reader through `agents.reader_tools(text, extra)`, which appends `mcp__<server>__<op>` per declared operation to its `tools:` line.
   - **The drift check** compares the landed reader after `agents.reader_unrender`, which strips exactly that suffix. So the render is not drift, and a hand edit still is.
   - **Unchanged:** `gate.py agents` still holds each operation to a read verb, an allowlisted server and no personal-data connector.
   - **[LAW-10]:** the sentence is unchanged; its body and the skill name the key.
4. **Turn caps.**
   - A definition's `maxTurns` is the framework's ceiling: the harness's stop. The project's key is the cap the agent is told.
   - The validator holds `worker_turn_cap ≤` each worker's `maxTurns`, and the large tier's `turn_budget ≤` each read-only `maxTurns`.
   - Above the ceiling stays red, because the harness would stop first.
5. **DAST.**
   - `security-scan.sh` passes `-c security/dast/rules.tsv` to all three packaged scans when that file exists.
   - The project-owned template `security/dast/rules.tsv` lands holding the format and an example, as comments only.
   - `dast.md` sends false positives there, and states that `zap-config.yaml` is an Automation Framework plan the scan does not run.
6. **The prose sweep.** Each hit names its project-owned home:
   - `config/quality.json` (`profile.members`, `verification.gates`, `agents.docs_servers`, `code_review`);
   - the project's rules;
   - an ADR (`pr_review_overrides`).
   A change wanted in a framework-owned file goes upstream. The deprecated `local-policy.md` path of `factory-pr-review` is dropped.

## Consequences

- A project adds a gate, a docs server, a turn cap or a DAST exclusion without touching a framework file, and sync keeps it.
- `factory-docs-reader.md` is no longer byte-identical to its source once a project declares a server. The drift check knows the one suffix that is allowed.
- Honest limits:
  - A server registered in Claude Code under another name than the canonical one is reached through the project's key, not the base list.
  - `zap-config.yaml` stays delivered and unread by the scan. Retiring it is not in this issue.
  - A member an installed `profile.py` built with a non-literal expression, or added to `MEMBERS` outside its list, is refused, so the agent moves it by hand.
  - The anchor reads the installed `profile.py` from HEAD. When HEAD already holds the delivered file (the sync result was committed first), it refuses and writes nothing; the agent moves the rows from the earlier commit by hand.
  - The project's servers are self-declared. The validator refuses a write verb, a name outside the tool-id characters and a `claude_ai_*` connector; it cannot tell a data read from a documentation read, so the skill names the servers that are never documentation servers.
  - The reader sync renders is compared as delivered by every reader of «landed differs from delivered» — the drift check and the upgrade's refresh — through one function, `agents.landed_as_delivered`.

## Verification

- **Unit tests, red first:**
  - the member list: merged, colliding, repeated, non-list, bad runner, and the RED row with the framework members still run;
  - a project member run by `profile --run`;
  - `owed` and `freeze._gates` naming it;
  - `installed_members`: added, none, non-literal;
  - `reader_tools` and `reader_unrender`: round trip, idempotent; drift green on a rendered reader and red on a hand edit;
  - the validator: a project server's read operation ok, a write operation red, a personal connector red, caps `≤` ok and `>` red;
  - the registry row owed before the stamp and not after;
  - the DAST lane passing `-c` only when the rules file exists.
- **Synthetic h138 on the default fixture:**
  - a committed `profile.py` with a member `ours`, then sync, then the anchor;
  - the config gains `ours`, `profile --run` names it, and a second run changes nothing;
  - with `agents.docs_servers` set, sync renders the reader, `gate.py agents` is green and the drift check is green.
- **Fixtures** `default`, `bitbucket`, `upgrade-8.12` and `upgrade-8.12-api` with `--answers`.
- **Gates:** lock-step, `manifest --check`, `manifest-parity`, `discovery`, `laws --parity`, `budget`, `profile --run`.
- **A mutation sweep** in a scratch copy.
