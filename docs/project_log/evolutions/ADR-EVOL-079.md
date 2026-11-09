---
id: ADR-EVOL-079
title: "Backlog lifecycle — the board tells the truth about the work on every adapter, Jira complete"
date: 2026-11-09
status: accepted
---

# ADR-EVOL-079: Backlog lifecycle

## Context

This ADR implements issue #133 (epic #112, Wave 4). It was verified on `main` at framework 10.2.0 (3d6a182). BOPS means `.claude/instructions/Factory-backlog-operations.instructions.md`. Each fact below cites its source.

### The lifecycle today
- **Nothing moves an item to In Progress.** No phase command touches the board (`.claude/commands/{codesign,blueprint,implement,devops,qa}.md`). Moves exist only to the first column at creation (BOPS § 6.1 step 5) and back to `Todo` on a cascade (`factory-iteration-model/SKILL.md:347,367,563,700`).
- **Column names are hard-coded.** The cascade writes `column="Todo"`; the adapters key their runtime config by `Todo / In Progress / Review / Done` (`backlog-tool-adapters/github-project.md:66-72`, `jira.md:65-70`); Q27.1 defaults to `[Todo, In Progress, Review, Done]` (`Factory-setup-discovery:454`).
- **Creation is not idempotent.** `--plan-feature` creates every phase on every run (BOPS § 6.2); a failure closes what it created (Rollback Protocol, `commands/backlog.md:144`). Nothing looks for an existing item first. Sub-increment items (BOPS:104) have no creation step at all.
- **No realignment carve-out.** A pre-approved realignment (`rules/branching.md` § [LAW-17], `kind: accepted_change`) works on a phase whose item is Done; nothing says whether that item moves.
- **Each operation is an agent reading a markdown catalogue.** BOPS § 6.0: the agent substitutes placeholders into tool commands and parses their output. No script reads or moves the board.

### The adapters today
- **Jira is a stub.** `jira.md` carries `stub: true`, 8 of its 13 required operations `TODO`, CLI only (`jira.md:5-6,213-230`).
- **Linear is a stub** (`linear.md`, MCP). RDR G (2026-10-09, owner «1») takes it out of the offered tools.
- **Q27 offers trackers with no adapter.** Suggestions `Linear | Azure Boards | Shortcut | Notion` (`discovery_registry.json` Q27) fall back to `none.md` with a WARN (`Factory-setup-materialization:763-773`). The selection is a regex the agent applies — no script computes it.
- **The fallback lands half the local set.** `backlog/state.md` lands on `project_tracking.tool == "None"` and `backlog/project-config.json` on `!= "None"` (manifest `templates`). A `Linear` answer renders `none.md` but gets `project-config.json` and no `state.md`.
- **`none.md` columns are unsourced for `None`.** It renders `{{BOARD_COLUMNS}}`, which Q27.1 asks only when `tool != None`.

### MCP today
- **V12** holds every `mcp.servers` row to `npx` of one pinned package with `--isolated`, no `env`, no `url` (`scripts/gates/discovery.py:1281-1302`, EVOL-077). Its first consumer is the browser MCP (Q23.5).
- **#159 phase 3** ("an MCP entry with a vault-name credential") ships with its first consumer that needs one (#159 comment, 2026-11-08).

### Overlap
- **#216 (EVOL-126)** wants the sub-increment item moved by events (branch cut → in progress, merge into the train → done) and a config key mapping the lifecycle states to option names. That key is this issue's `project_tracking.flow`. Boundary below (§ 9).

## External facts (Beat 0)

`factory-docs-reader`, 2026-11-09. Sources by index in the reader's return; the ones this design rests on:

1. **Jira Cloud search** is `POST /rest/api/3/search/jql` (`GET /rest/api/3/search` is being removed, CHANGE-2046). Token pagination: `nextPageToken`, `isLast`; no `startAt`, no `total`. `fields` defaults to `id` — the reader names `summary,status,parent,labels,issuetype`. The JQL must be bounded (`project = KEY …`). [S1]
2. **Create** `POST /rest/api/3/issue` → 201 `{id, key, self}`. `description` is ADF on v3. A sub-task: an issue type with `subtask: true` and `fields.parent.key`, same project as the parent. No idempotency key is documented — idempotency is the reader's job. [S1]
3. **Transitions** are per issue: `GET …/issue/{key}/transitions` → `transitions[].id, .to.id, .to.name`; `POST {"transition":{"id"}}` → 204. No transition to the target → an empty list, never an error. [S1]
4. **Board columns** `GET /rest/agile/1.0/board/{id}/configuration` → `columnConfig.columns[].name`, `.statuses[].id`, in board order. Board lookup `GET /rest/agile/1.0/board?projectKeyOrId=`. [S2, S4]
5. **Auth** Cloud: `Authorization: Basic base64(email:api_token)`. 429 carries `Retry-After`; API-token traffic is outside the points quota. [S3, S5]
6. **Atlassian Rovo MCP Server** is GA, remote `https://mcp.atlassian.com/v2/mcp`, OAuth 2.1 (or an admin-enabled API token in `headers`). Project `.mcp.json`: `{"type": "http", "url"}`. Jira tools: `createJiraIssue`, `editJiraIssue`, `transitionJiraIssue`, `searchJiraIssuesUsingJql`, `getJiraIssue`, `listJiraIssueTransitions`, `listJiraBoards`, `getJiraBoardConfig`; each call needs a `cloudId` (`getAccessibleAtlassianResources`). [S6, S7, S8]
7. **`mcp-atlassian` (community)** v0.24.1 (2026-11-08), `uvx`, env `JIRA_URL`, `JIRA_USERNAME`, `JIRA_API_TOKEN`. [S10–S12]
8. **Claude Code `.mcp.json`** expands `${VAR}` in `command`, `args`, `env`, `url`, `headers`. [S9]
9. **jira-cli** v1.7.0 (2025-08-31): `JIRA_API_TOKEN`, `jira init`; Cloud and on-premises (`JIRA_AUTH_TYPE=bearer` for a PAT). `issue create … --no-input`, `issue move KEY "Status"`, `issue edit KEY -l x --no-input` (appends), `issue list -q JQL --plain`; `--raw` prints jira-cli structs, not the REST body. [S13–S15]
10. **Jira Data Center** speaks `api` v2 and `agile` v1 only. Search is `GET|POST /rest/api/2/search` with `startAt` and `maxResults`; whether the body carries `total` is not shown, and `/search/jql` is not documented on DC. Create is `POST /rest/api/2/issue` → 201 `{id, key, self}` with `description` a plain string. Transitions take the same `{transition: {id}}` → 204, each with `to {id, name}`. The board configuration has the same shape as Cloud. [D1, D2]
11. **DC auth** is a personal access token sent as `Authorization: Bearer` (Jira 8.14+). [D3]
12. **DC end of life**: no new-customer sales after 30 March 2026, no existing-customer sales after 30 March 2028, read-only on 28 March 2029. [D4]
13. **GitHub sub-issues**: `Issue.parent`, `Issue.subIssues`, and `addSubIssue(issueId, subIssueId, replaceParent)`. Re-adding a linked child is undocumented. The limit is 100 children and 8 levels. [G1, G6]
14. **GitHub Projects v2**:
    - `ProjectV2Item.fieldValueByName("Status")` returns `{name, optionId}`.
    - `ProjectV2.field(name)` with the single-select fragment returns `options {id, name}`.
    - `updateProjectV2ItemFieldValue(projectId, itemId, fieldId, value: {singleSelectOptionId})` sets one value per call.
    - `addProjectV2ItemById` returns the existing item when the content is already on the project.
    - `items(first ≤ 100, after)` excludes archived items.
    - The owner is `organization(login)` or `user(login)`, then `.projectV2(number)`. [G2, G3, G5]
15. **Cloud search is eventually consistent**; `reconcileIssues` (a list of issue ids, at most 50, POST body) makes a search read its own writes. The project resource `GET /rest/api/{2|3}/project/{key}` lists `issueTypes[] {id, name, subtask}` and `versions[] {id, name}`; `fixVersions` takes a version by id. (Second reader pass, 2026-11-09: Jira Cloud REST v3 reference — issue search, projects, issues.)
16. **Unknown, so not relied on:**
    - whether a transition to the current status errors;
    - whether `update.labels.add` of an existing label duplicates;
    - whether `addSubIssue` on a linked child errors;
    - whether DC search returns `total`.

    The reader never needs any of them. It moves only an item outside the target column. It adds labels only at creation. It links only a child whose parent differs. It pages DC search until a page comes back short.

## Decision

The issue states the what; everything below is the how, resolved from the SDLC (owner rule: issues state the WHAT). RDR G «1» is applied as ratified.

### 1. One tracker reader and mover — `scripts/gates/tracker.py`, `gate.py tracker` (G)
- **One shape** for every adapter: `{columns: [name], items: [{key, title, column, parent, labels, closed}]}` — `key` is the issue number (GitHub), the issue key (Jira) or the local id (`none`); `parent` is the parent's key.
- **Pure planner** over that shape: `plan_move(board, ident, column)` and `plan_ensure(board, wanted, column)` return a request list — `move`, `create`, `link`. A board already in the wanted state plans nothing: that is the idempotency, proven on recorded responses.
- **Executor per adapter**, one transport each, injectable for tests:
  - `github` — `gh api graphql` (the pre-authenticated CLI). The Status field and its options are resolved **by name** at run time; no option id is stored. The board is the project's items plus the repository's open issues that are not on the project yet (column none). An item created but never added is found on the re-run and added, not created twice; `addProjectV2ItemById` returns the existing item.
  - `jira` — REST over `urllib` (the `scm.py` pattern). The site decides the API: a host under `atlassian.net` is Cloud (`api/3`, `search/jql` with token paging, Basic `email:token`, ADF description); any other host is Data Center (`api/2`, `search` with `startAt` paging, Bearer personal token, plain description). Token `JIRA_API_TOKEN` and, on Cloud, `JIRA_USER_EMAIL` from the environment — the variable jira-cli reads; never a file, never an answer. A column is the set of status ids the board configuration lists; a move takes the one transition whose `to.id` is in the target column's statuses. A 429 waits its `Retry-After` once, then faults.
  - `none` — `docs/backlog/state.md`: the Status, Parent and Labels cells, the next local id, the body file.
- **Every request is followed by a re-read**: the command is green only when the fresh board shows the wanted state. A transport or auth failure is a fault with its cure, never a stack trace (LAW-08).
- **Item identity is the title head.** `ident` = the title up to and including the phase token's colon (`[FEAT-001] IMPLEMENT:`, `[FEAT-001] INC-1 / SUB-1-2:`), or the full title for a catalog component. A title matches when it equals the ident or continues it after a blank. Two items matching one ident: red — a duplicate is reported, never closed by the reader.
- **Config:** `config/quality.json → tracker {adapter, flow}`; the tracker ids stay in `docs/backlog/project-config.json → project_ids` (`--init-board` captures them: GitHub `owner`, `repo`, `project_number`; Jira `site`, `project_key`, `board_id`).

### 2. The flow — `tracker.flow` (G)
- Four lifecycle states, in order: **backlog** (the business opened it), **ready** (designed, the technical team moved it), **in progress**, **done**. `tracker.flow` is the project's column for each, as a list in that order.
- Default columns and flow: `[Backlog, Ready, In Progress, Done]`. A board `[Todo, In Progress, Review, Done]` answers `[Todo, Todo, In Progress, Done]`.
- `gate.py tracker --move IDENT --to backlog|ready|in-progress|done` is the one move. The cascade reopens a gate to **ready**; `--update-execution` closes to **done**. No instruction, skill or adapter names a column any more.
- A flow column the board lacks is a fault naming the column and the board's columns.

### 3. In Progress before the work — `gate.py tracker --start` (G)
- Each phase command opens with `gate.py tracker --start --feature {ID} --phase <phase>` (or `--item IDENT` for a sub-increment or a refinement item). Not in progress → the reader moves it there, re-reads, and is green; anything it cannot do → red, the command BLOCKS.
- The phase → item map is code (`tracker.ident`), from `project_tracking.feature_phases`: `full-sdlc` one item per phase (the smoke item matches any `SMOKE-E2E (…)` variant); `simplified` codesign/blueprint → `SPEC`, devops/implement → `IMPLEMENT`, qa/smoke → `QA`; `single` → the feature's one item.
- On every adapter, `none` included: the gate reads whichever board the adapter has.

### 4. Idempotent items — `gate.py tracker --ensure` (G)
- `--ensure FILE`: wanted rows `{title, body?, labels?, parent?, milestone?, state?}` (body: a file). Missing items are created in their state's column (default backlog), an existing child without its parent is linked (GitHub, `none`), nothing else is touched. `--dry-run` prints the planned requests.
- `--ensure --sub-increments FEATURE`: the rows are computed from `increment_plan.md § 1` (`train.parse`), parent `[{ID}] IMPLEMENT:`.
- `--plan-feature`, the sub-increment items and the catalog component items (`factory-po-intake`) all go through `--ensure`. The Rollback Protocol retires: a failed run is finished by running it again.
- An item found under another parent is red with the item named, on every adapter — the gate never re-parents (Jira cannot move a sub-task; GitHub `replaceParent` would silently rewrite the tree).
- **Jira search lag.** The gate reconciles its own creations (`reconcileIssues` of the ids it made, then `GET` by key). A creation by another tool within the last minutes may not be searchable yet: a re-run in that window can create a duplicate, and the next run reports it red (two items on one ident) — never closes it. Residual risk, stated in `jira.md` § Troubleshooting.
- **Body files.** A row's `body` is a markdown path. `none`: a body already under `docs/backlog/issue-bodies/` is pointed at; any other is copied there as `L-NNN.md`.

### 5. The realignment carve-out — `--start … --aligns AC-…` (G)
- A pre-approved realignment (LAW-17) works on a phase whose item is Done. With `--aligns AC-{FEAT}-{N}` the gate checks the entry in `docs/project_log/features/{FEAT}.log.jsonl` is ratified (`aligned.ratification`) and is green **without moving** the item.
- A Done item without `--aligns` is red: new work on a Done phase opens a refinement item (`[{ID}] {PHASE}-R{k}:`).

### 6. Jira complete (T)
- `jira.md` loses `stub: true`. Every operation has its command for both transports — **cli** (jira-cli 1.7.0) and **mcp** (the Rovo tools) — and the lifecycle operations (`move_to_column`, `add_sub_issue`, sub-item creation, the In Progress gate) point to `gate.py tracker`, as on GitHub and `none`.
- **The MCP server is Atlassian's own** (`type: http`, `url: https://mcp.atlassian.com/v2/mcp`, OAuth): no credential sits in `.mcp.json`. A community server would run third-party code holding the token. The reader does not depend on the transport — it speaks REST either way.
- **V12** admits a second row shape, `{type: "http", url}`: `https`, a host on the registry's allowlist (`mcp.atlassian.com`), no `headers`, no `env`. The no-credential rule holds; the vault-name line of #159 stays for a consumer that needs a credential in the entry.

### 7. Discovery and materialisation (T)
- Q27 suggestions: `GitHub Projects | Jira | None` — every other offered tracker landed `none`, which is what RDR G removes for Linear; free text still accepts any name.
- **`project_tracking.adapter` is derived**, never asked: a new derived-entry field `matches {key, values: {<substring>: value}, else, warn}` (case-insensitive, first substring wins) — `github → github`, `jira → jira`, `none → none`, else `none` with the WARN. `--resolve` reports it in `derived_answers` and `warnings`; conditions read it.
- The manifest lands `backlog/state.md` on `project_tracking.adapter == none` and `project-config.json` on `!= none` — a Linear answer gets the whole `none` set. `linear.md` and its manifest entry are removed.
- Q27.1 is asked on every adapter, default `[Backlog, Ready, In Progress, Done]`; Q27.2–Q27.6 keep their condition (the gate reads `feature_phases` with `full-sdlc` as the default when absent). New: Q27.7 `project_tracking.flow` (list, every adapter), Q27.8 `project_tracking.transport` (`cli | mcp`, Jira only; `mcp` configures the Rovo row), Q27.9 `project_tracking.token` (`free: vault_name`, Jira only: the vault entry's name; the vault exports it as `JIRA_API_TOKEN`).
- A derived value's `fills` reach `--resolve → placeholders` (`TRACKER_ADAPTER`), as a question's do.
- The Linear-only constants (`LINEAR_*`, `STATE_ID_*`) and the column-id constants no adapter carries any more leave the registry (V10).
- `config/quality.json` gains `tracker {adapter, flow}` from the answers.

### 8. Upgrade
- Migration row `tracker (EVOL-079)`, detect `config/quality.json#/tracker`: write `tracker` from the answers (asking Q27.1, Q27.7–Q27.9 where pending), re-render `docs/backlog/tool-adapter.md` from the derived adapter (the Jira stub is replaced), merge the `atlassian` row where Q27.8 is `mcp` (the browser-mcp merge block: every `configures → mcp.servers` row, same rule).
- A project on the Linear stub (or any tracker with no adapter) derives `none`: `docs/backlog/tool-adapter.md` is re-rendered from `none.md`, `state.md` lands, the open items are copied into it with one `gate.py tracker --ensure`, and `project-config.json` is removed (`templates_to_remove`). The old stub files under `docs/backlog-tool-adapters/` stay — project layer, never removed. The team's own board is no longer driven.

### 9. Boundaries
- **#216** builds on this: its lifecycle map is `tracker.flow`, its mover is `gate.py tracker --move`; it adds the event-driven workflow and the git reconciler. Its issue body says so.
- **#156** (reservations) adds its operations to the adapters later; nothing here reserves.

### 10. Alignment (LAW-17)
Every reader of the board lifecycle moves in this change: BOPS (§ 1, § 6, § 7.2, a new § 6.5), `commands/backlog.md`, the five phase commands, `factory-iteration-model` (the cascade moves), `factory-po-intake` (component items), `Factory-backlog-next-task` (no column literal), the adapters and their README, SETUP discovery / materialisation / upgrade, the registry, the setup template, `config/quality.json`, README.

## Verification
- **Red first**, a test class per decision in `scripts/gates/test_gates.py`:
  - parsing: recorded GitHub (`gh api graphql`) and Jira (search, board configuration, transitions, create) responses under `scripts/fixtures/tracker/` → the one shape; `none` from a `state.md` fixture;
  - idempotency: the board before → its request sequence; the recorded board after → no request;
  - flow: a flow whose «ready» is another column name moves the item to that column (DoD);
  - start: moved and green; a Done item red; `--aligns` with a ratified entry green and unmoved, with an unratified one red;
  - ensure: re-running creates nothing (DoD); a duplicate ident red; Jira re-parent red;
  - discovery: a `Linear` answer → adapter `none`, its WARN, `state.md` landing, `project-config.json` skipped, no `linear.md` entry (DoD); `matches` V1 shape; V12 `http` row (allowed host green, other host / `headers` / `env` / `http:` red).
- Mutation sweep in a scratch copy. Full suite, `test-hooks.sh`, 9/9 synthetic materialisations with `--answers`, lock-step, manifest parity, discovery, budgets, ADR sync, retired terms, `validate-governance`, `gate.py profile --run`.
- No live tracker in meta CI: every adapter test replays recorded responses.
- Two critic rounds × four lenses; manifest bump (MINOR).
- **Round 1 (four lenses).** Cured, each with its regression test:
  - an ident that is a whole title matches only that title; two rows naming one item are red (one row per item);
  - what the replan still finds after a write is red (a Jira parent the server dropped), never green;
  - a flow column off the board is a fault on every read (`--start`, `--move`, `--ensure`), not only on a row's own state;
  - `--aligns` names an accepted change of the item's own feature;
  - a body is a `.md` file, checked before any write; an unreadable or non-UTF-8 body is a fault; a short `state.md` row reads its missing cells empty;
  - every page is read (GitHub cursors, Jira Cloud `nextPageToken` until `isLast`);
  - Jira HTTP: no redirect is followed (the token is never sent on), 429 retried once then a fault with its remedy, 401/5xx/HTML/closed port mapped to a fault, no token in any message; a `site` with a user or password, a GitHub owner/repo outside `[A-Za-z0-9._-]` and a path segment that is not quoted whole (`safe=""`) are refused before any request;
  - `--dry-run` plans an `--ensure` only; `--feature`, `--phase`, `--item`, `--aligns` go with `--start` only, `--to` with `--move` only;
  - discovery: the unmatched-tracker WARN prints the answer cleaned; a `$` in an `http` row's url is red (the harness expands it); every synthetic fixture checks the resolver's warnings exactly; the upgrade fixture simulates a config with no `tracker` block;
  - LAW-17: BOPS (sub-issue nesting through the `--ensure` row's `parent`, sub-increment items, the retrospective close, § 7.1 project ids, § 7.2 report, § 10.1), `Factory-implement-plan` (the cascade move), `Factory-backlog-next-task` and the IOP map (no column literal), README (the `--move` row; Phase 0.1 is required, not optional — each phase command's `--start` blocks without its item), § 8 here (a Linear project derives `none`, its items copied with `--ensure`), the upgrade's MCP merge.
  Accepted with reason: a closed GitHub issue that left the project is not read (the project read covers every item the project holds; archiving is the team's choice); no page cap (a board is bounded by the team); `*.jira.com` read as Data Center (Atlassian's Cloud hosts are `*.atlassian.net`); the body path is not confined to the repository (the external-mode scratch body lives outside it, BOPS § 5); `tracker.py` complexity (one adapter per class, below the hard threshold).
- **Round 2 (four lenses, the cure only).** No finding. Informational cured, each with its regression test:
  - every body is read (a readable UTF-8 `.md`) before the first write, so a bad second body leaves the first row unwritten;
  - a number from the config or the server (`project_number`, `board_id`, `Retry-After`, a created id) is an ASCII decimal — `²` is a fault or the default wait, never a traceback;
  - a Jira search page token returned twice is a fault, never an endless loop;
  - the local HTTP test bypasses any CI proxy; the module docstring states the whole-title rule;
  - LAW-17: BOPS external mode (the body reaches the tool as a scratch `.md` the gate reads), the adapters README (every shipped adapter nests).
  Accepted with reason: a body path outside the repository and a `site` edited in a pull request (both are the team's own reviewed configuration; the round-1 reasons hold); `.` and `..` as GitHub names (they reach only `--repo` and GraphQL values, nothing breaks out).
