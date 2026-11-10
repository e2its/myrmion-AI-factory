---
id: ADR-EVOL-080
title: "Deliverable homes — one source of truth per deliverable category; an external home pinned by id and version, read live, written at approval"
date: 2026-11-09
status: accepted
---

# ADR-EVOL-080: Deliverable homes

## Context

This ADR implements issue #134 (epic #112, Wave 4, G+T; depends on #159). It was verified on `main` at framework 10.3.0 (39dcbcb). The owner's RDR-1a (#153, 2026-10-09, «2») is applied as ratified: one source of truth per deliverable category, an external home read live at the pinned version, no copy in the repo, the seal binds the pin. The build-at-materialisation rule (owner, 2026-11-09) is applied to the store answer: Confluence is shipped, and any other store is built at materialisation against the same contract and gate.

### Deliverables today
- **Every deliverable lives in the repo, and no store is named anywhere.** The registry has no `documents`, `deliverables` or store key (`.context/templates/setup/setup/discovery_registry.json`, 70 questions).
- **Gates read the artefacts straight from disk by fixed globs.** The globs are `docs/spec/*/design.md` (`scripts/gates/bounds.py:37`, `digests.py:98`, `freeze.py:211`, `seal.py:207`), `docs/spec/*/test_plan.md` (`contracts.py:390,622`, `traceability.py:98`, `qa.py:173`, `proof.py:416`), `docs/spec/*/user_journey.md` (`contracts.py:687`) and the certifying reports (`coherence.py:33`, `qa.py:53`).
  - Diff-based gates read the merge-base version with `git show` (`qa.py:354`).
- **The increment plan and the dev plan carry delivery state.** Increments become `MERGED` (`qa.py:28`) and dev_plan tasks are ticked. Hooks read the increment plan on every write, to classify a train (`branch.py:83`).
- **Approval is a frontmatter state.** `status`, `verdict` or `overall_verdict` says `APPROVED` (`qa.py:68`). The cascade flips a downstream `APPROVED` artefact (`factory-iteration-model/SKILL.md:243,337`).
- **Seal read-sets** are root-anchored globs over files on disk, by git blob id (`seal.py:7-15`).
- **The discovery grammar** tests a list answer only with `exists` (`discovery.py:24`). A derived `matches` maps a free answer to a value with a WARN (EVOL-079).
- **The Jira REST transport** lives in `scripts/gates/tracker.py:558-600`: no redirect followed, 429 retried once, faults named, no token in a message.
- **A profile member exiting 2 is FAULT.** It warns and the push proceeds (`profile.py:166-178`, `test-hooks.sh:632`). In CI, exit 2 fails the step.
- **Build at materialisation precedent:** `config/quality.json → proof.convert` (EVOL-106) is a command, with no shell, that prints a declared JSON shape.

## External facts (Beat 0)

`factory-docs-reader`, 2026-11-09. These are the facts the design rests on, with sources as listed in the reader's return:

1. **Cloud v2 page read.** `GET /wiki/api/v2/pages/{id}?body-format=storage` returns `version.number` (included by default) and `body.storage.value`. `?version=N` exists ("retrieves a previously published version by its number"). That it returns version N's body is **not confirmed**, and community reports say a historical body comes back empty. [openapi-v2, community]
2. **Cloud publish and create.**
   - Update: `PUT /wiki/api/v2/pages/{id}` with `{id, status: current, title, body: {representation: storage, value}, version: {number: current+1, message}}` → `PageSingle.version.number`.
   - Create: `POST /wiki/api/v2/pages` needs `spaceId`.
   - A stale version number: the official docs are silent; community reports say 409. [openapi-v2, CONFCLOUD-76640]
3. **Versions are not immutable.**
   - A historical body cannot be edited (409, CONFCLOUD-73670).
   - v1 `DELETE /wiki/rest/api/content/{id}/version/{n}` exists. Deleting a version folds its changes into the next one, so **the content at a version number can change**.
   - A restore creates a new version. [v1 reference]
4. **Auth.**
   - Cloud: `Authorization: Basic base64(email:token)` on `https://<site>.atlassian.net/wiki`.
   - Data Center (DC): a personal access token as `Authorization: Bearer` (7.9+).
   - 429 carries `Retry-After`. [basic-auth, DC PAT, rate-limiting]
5. **DC.**
   - Read: `GET /rest/api/content/{id}?expand=body.storage,version`. A historical read is `?status=historical&version=N` (a KB article; the expand is unconfirmed).
   - Update: `PUT /rest/api/content/{id}` with an incremented `version.number`, `title`, `type` and `body.storage`.
   - Create: `POST /rest/api/content` with `space.key`. [DC KB, DC 6.6 REST]
6. **No source says storage XHTML is byte-stable across reads.** Macro ids can change. The reader recommends hashing what the writer wrote, never the raw storage. [macro docs, community]
7. **Unknown, so not relied on:**
   - the historical body on Cloud;
   - the DC historical expand;
   - page id stability on move;
   - redirect behaviour;
   - acli Confluence commands;
   - whether Rovo MCP returns a version's body.

   Section 3 below needs none of them: the reader asks for a historical version only when the store has moved past the pin, and it verifies whatever comes back.

## Decision

The issue states the what; everything below is the how, resolved from the SDLC.

### 1. The categories — a closed list
`scripts/gates/documents.py → CATEGORIES` holds each category's paths, writer and kind. The registry asks the home of each asked category through its `deliverables.<category>.home` key. `gate.py discovery` holds those keys to the asked categories (V14): a missing one, or one for a category that only lives in the repo, is red.
- **Asked** (an external home is admissible). Each is approved at a phase checkpoint and nothing moves its bytes without approval:
  - `business`: `docs/spec/*/user_journey.md`, `docs/spec/*/slice_map.md`, `docs/ux/vision/vision.md`, `docs/ux/vision/navigation_map.md`. CODESIGN; agent-written.
  - `design`: `docs/spec/*/design.md`, `docs/spec/*/test_plan.md`, `docs/spec/*/devops_plan.md`, `docs/spec/*/fdr/*.md`. BLUEPRINT and DEVOPS; agent-written.
  - `report`: `docs/spec/*/qa/qa_report*.md`, `docs/spec/*/review/*.md`, `docs/spec/*/smoke_e2e_report*.md`, `docs/technical_due.md`, `docs/software_audit.md`. QA, review and AUDIT; agent-written.
- **Derived to the repo, never asked:**
  - `scenario` (Gherkin), `contract`, `test`, `config` (config, setup, constitution, rules, ADRs that feed the constitution index) and `mock` (HTML the browser renders): the code compiles, runs or machine-reads them.
  - `plan` (increment plan, dev plan, backlog): delivery state moves its bytes without an approval, so no pin could hold it.
  - `record` (worklogs, proof, baselines).
- **The writer field.** Every category above is agent-written. A category people write is the seam for #154 and #175: a read-only store may be its home.

### 2. The pin
- **Shape.** `<artefact path>.pin.json` = `{source, id, version, approved_at, sha256}`.
- **The hash.** `sha256` is over the artefact bytes approved at that version. It is not a copy. It is what lets the reader prove the store returned exactly the approved bytes. A deleted version can change the content at a number (fact 3), so the hash is necessary.
- **The pin is the artefact in the tree.** The seal binds it: a read glob `G` also matches `G.pin.json` (`seal.py` read-set expansion). Diff-based gates see a changed pin as a changed artefact.
- **Precedence.** A file at the path wins over its pin: it is the draft of a refine. With no file and no pin, the artefact is absent.

### 3. One reader — `gate.py documents` (`scripts/gates/documents.py`)
- **`text(repo, rel, ref=None)`** is the Python API every gate uses. Plain-call verbs:
  - `--read PATH [--ref R]` prints the same bytes, for agents and CI. It is one reader, so the verdict on the commit (#176) judges what the session read.
  - `--approve PATH` publishes the file's bytes as a new version when they differ from the store's current bytes. It writes the pin at that version with `approved_at` set to now, and removes the file.
  - `--pull PATH` writes the pinned bytes back to the path as the draft of a refine or a cascade.
  - `--probe` runs the store contract live (§ 5).
- **The read.**
  1. Read the page's current version and body in one call.
  2. If the current version equals the pin, that body is the pinned version. A historical read is needed only after drift.
  3. Otherwise read version N. Either way, the returned `version.number` must equal the pin and the sha256 of the extracted artefact must equal the pin's, else red.
  - The gate never reads the latest in place of the pinned version.
  - A run-scoped memo is a temporary folder that `profile --run` sets and removes. Members read it by content hash, so one run fetches each pin once. Nothing survives the run, so an outage is never masked.
- **Fault classes.**
  - Store down: unreachable, 5xx, a repeated 429, 401 or 403. This is `StoreDown` (a `GateFault`; the message starts `the source of truth is down`).
    - `profile --run` reports a member that exits 2 with that line as n/a with a WARN, which is shown on the board and in the CI log. It is the LAW-11/LAW-13 noisy warning, never a pass in silence.
    - A direct call (an approval, a read) exits 2: nothing approves on an unread source of truth.
    - The one exception: at the `ci` control point, a missing or refused credential (`NoCredential`) is a red wiring finding under `documents.verify: ci` (§ Owner decisions). The bare check takes `--control-point push|ci|static`, as `qa`, `digests` and `scm-protection` do, and the profile hands it; no new channel.
  - Under the profile (`GATE_DOCUMENTS_BASE`, set by `profile --run`), the credential goes only to the store the base names. A pull request that adds the store or changes where it points (Confluence's site, space, deployment; a built store's commands and credentials) is the store down until it merges.
  - Red, never infra: a missing page or version, a version or hash mismatch, and a page that no longer carries the artefact.
- **Sharing the transport.** The REST transport moves out of `tracker.py` into `scripts/gates/rest.py`, which Jira and Confluence share (LAW-03). It follows no redirect, retries a 429 once, never puts a token in a message, and raises `Unreachable` for the transport class.

### 4. The gate — profile member `documents` (light and full)
- **(a) Shape and admissibility.** Every pin must:
  - be well formed;
  - name the configured source;
  - sit under an asked category whose home is that source.

  A pin anywhere else is red. This covers a pin under a code-run path: the DoD's «external home for a code-run category».
- **(b) Re-approval.** A pin that changed against the merge-base, whose version or hash moved while `approved_at` did not advance, is red.
- **(c) Drift.** The store's current version must equal the pin. Anything else is red («moved without re-approval»): re-approve through the owner phase's refine (`--pull`, refine, `--approve`), or restore the pinned version in the store. When the base's tip pins that current version, the base re-approved it after the fork: the red says «rebase onto the base».
- **(d) Pinned read.** Each pin read verifies version and hash.
- **(e) No copy.** A file under a category homed externally whose frontmatter says approved (`status`, `verdict` or `overall_verdict` carrying `APPROVED`, `ACCEPTED` or `PASS` — one set for every key, `common.approved`) is red. Its remedy is `--approve`. A draft, a rejected report or an in-progress report is work in the repo.
- **Scope.** With no external home configured, the member is n/a with its reason, and the gate costs nothing.

### 5. Stores
- **repo.** The default. No pin; the file is the source of truth.
- **Confluence (shipped).**
  - REST through `rest.py`. A site under `atlassian.net` is Cloud (v2); any other site is Data Center (v1 `/rest/api`, with the context path inside the site URL).
  - Auth:
    - Cloud: Basic, `CONFLUENCE_USER_EMAIL:CONFLUENCE_API_TOKEN`.
    - DC: Bearer, `CONFLUENCE_API_TOKEN`.
    - Both come from the vault entries the answers name, never from a file.
  - The page holds the artefact as one code macro (title = the artefact path) whose CDATA body is the artefact's bytes, with `]]>` split. The reader extracts and hashes that, never the storage XHTML (fact 6). The team reads the source in the page.
  - The title is `{PROJECT_NAME} · {path}`, in the configured space.
  - First publish: when there is no pin, the page is found by title, else created. This makes it idempotent like `tracker --ensure`.
- **Any other answer (built at materialisation).**
  - `config/quality.json → documents.commands {read, publish}` are commands with no shell, as with `proof.convert`.
    - `read` takes `{id} {version}` and prints `{version, body}`.
    - `publish` takes `{id} {title} {file}` and prints `{id, version}`.
  - The reader applies the same verification to them.
  - `gate.py documents --probe` is the canary. It publishes twice to a probe page; the version must rise; current must read the second body; the first version must read the first. Materialisation blocks without a green probe.
  - A built store with no `publish` is read-only, so it is admissible only for a category people write. There is none today, so every category derives the repo, with a WARN.

### 6. Discovery and materialisation (T)
- **New questions** (Tier 2; registry order after Q37.1):
  - Q38 `documents.source`: free text; suggestions `Confluence | None`.
    - Derived `documents.adapter` `matches`: `confluence` → `confluence`, `none` → `none`, any other answer → `built`, with a WARN naming the answer («built at materialisation, proven by `gate.py documents --probe`»).
  - Q38.1 `documents.site`, asked when the adapter is `confluence`. Derived `documents.deployment` `matches`: `atlassian.net` → `cloud`, else `dc`.
  - Q38.2 `documents.space`.
  - Q38.3 `documents.token`: `vault_name`.
  - Q38.4 `documents.user`: `vault_name`, asked when the deployment is `cloud`. This is the account email, a personal datum, so it is kept as a vault name too.
  - Q38.5–Q38.7 `deliverables.{business,design,report}.home`, options `Repo | External`, asked when `documents.adapter IN [confluence, built]` (a condition on an unanswered key never holds). Recommendation: External for a category the team reads outside the code.
  - Q38.8 `documents.verify`, options `ci | local`, with the same condition (owner RDR, § Owner decisions). Recommendation: `ci`, a read-only service-account credential exported by the governance-check workflow. A missing or refused credential at the `ci` control point is red; `local` gives n/a + WARN, a declared risk. Under the profile, the credential goes only to the store the base names (§ 3).
- **Source and home count.** One declared source per project: the grammar tests a list only with `exists`, and three asked categories need no second store. `External` is that source.
- **A code-run category home in an answer** is an unknown key, so discovery rejects it (V-unknown).
- **Config.** `config/quality.json → documents {adapter, site, space, deployment, verify, title_prefix, homes {business, design, report}, commands, credentials}` is rendered from the answers (`DOCUMENTS_*` placeholders). Materialisation asks for `--probe` on a built adapter. `none` adds nothing.

### 7. Writers and readers (LAW-17)
- **Approval.** Each approval checkpoint of an asked category runs `gate.py documents --approve <path>` when its home is external:
  - CODESIGN `--approve` (business);
  - BLUEPRINT `--approve` and DEVOPS plan approval (design);
  - QA, review and AUDIT reports when written approved (report).
- **Pull.** A refine, and the iteration-model cascade, on a pinned artefact first runs `--pull`.
- **Agents.** Agents read a pinned artefact with `gate.py documents --read`. This is one line in the project CLAUDE.md template, and `rules/documentation.md` holds the body.
- **Gates.** The readers that move to `documents.text` / the pin-aware listing are bounds, digests, freeze, seal, frontmatter-lock, contracts, data, qa, delivery, proof, traceability and coherence. Frontmatter-lock reads an approved artefact moved home through its pin, so `--approve` deleting the file is no deletion; a re-pin, a draft over a pin and a deleted pin are judged like the file.
- **The PO package (owner RDR-2, § Owner decisions).** External CODESIGN authoring reads the business it ships and judges a return against through the same reader. The builder (journeys, slice maps, the navigation map, the glossary, the feature list) and the return validator (the scope fallback, the last synced copy of the diff-only judgement) take a pinned artefact's approved bytes with `gate.py --repo <repo> documents --read`, as a subprocess: the subproduct imports nothing. The reader is told the repository (never the caller's `CLAUDE_PROJECT_DIR`), writes no bytecode into it, and is called once per artefact and run. A copy into the package keeps the approved bytes exactly (CRLF kept, strict UTF-8); a parse reads line ends as it reads a file, so one artefact parses alike from either home. A store that does not answer, or a reader that is missing, stops either tool with exit 2 and a plain line — never a package without the approved business, never a verdict. The adoption side already reads the pin (`Factory-codesign-sync` § never_approved).

### 8. Upgrade
Migration row `documents (EVOL-080)`, since 10.4.0, detect `config/quality.json#/documents`. It asks Q38 and its follow-ups, then writes the block. A project that answers `None` gets `{adapter: none}`, and nothing else moves.

### 9. Boundaries
- **#154** consumes the mechanism: its architecture plan is a category it adds, people-written where its owner writes it.
- **#175** (any-author, on hold) is the people-written path.
- **#176** reads the same reader.

## Verification
- **Red first**, in `scripts/gates/test_gates.py`, against a fake store and recorded Confluence responses under `scripts/fixtures/documents/` (Cloud v2 and DC). The DoD cases:
  - drift: current v4, pin v3 → red;
  - store down: the member is n/a with a WARN under `profile --run`, and a direct read exits 2;
  - the reader returns v3's bytes while v4 is current;
  - a pin under `spec.feature`, or a code-run home in an answer → red;
  - `--approve` publishes v+1 and moves the pin; a version published outside approval moves no pin and is drift;
  - two independent reads of one pin (fresh memo) return the same bytes, equal to the pin's hash.
- **Other cases:**
  - the precedence of file over pin;
  - a page that no longer carries the macro;
  - `]]>` round-trip;
  - Cloud/DC routing;
  - `rest.py` no-redirect, 429 and fault classes;
  - the built-adapter `--probe` (a faking adapter fails);
  - V14 parity;
  - each threaded gate reading a pinned artefact;
  - the PO package (RDR-2), in `scripts/test-po-package.sh` Part 2c, through the delivered reader and a built store ahead of the pin that needs its declared credential, with `CLAUDE_PROJECT_DIR` pointing elsewhere and bytecode writes allowed:
    - the package carries the approved journey, slice map (CRLF, byte for byte) and navigation map, never the latest; each approved version is read once per build;
    - a journey and a navigation map approved with CRLF parse as their files would: the scope reads the journey's frontmatter, the route map carries no frontmatter;
    - the glossary, catalogue and scope read the pinned journey; the golden return is judged against it; the diff-only judgement reads the pinned synced copy;
    - the repository is untouched, bytecode included; the credential's canary is absent from the package, the zip's members, the output and the error lines (the fake store echoes it when it refuses);
    - the store down stops the builder (no zip) and the validator with exit 2 and a plain line; one unreadable synced journey stops the validator, naming it; a missing reader names `SETUP --upgrade`; a reader that times out, cannot start or answers bytes that are not UTF-8 is named in plain words.
- **Process:**
  - a mutation sweep in a scratch copy;
  - the full suite, `test-hooks.sh`, and 9/9 synthetic materialisations, one fixture answering Confluence;
  - lock-step, manifest parity, discovery, budgets, ADR sync, retired terms, `validate-governance` and `gate.py profile --run`;
  - two critic rounds × four lenses;
  - manifest bump, MINOR (framework 10.4.0).

## Critic rounds

### Round 1 (four lenses) — cured
- **The store down never drops a red.** A gate that meets an outage leaves that artefact unjudged and goes on. The reds it found stand, with the outage as a WARN line. With no red, the outage is the verdict: n/a + WARN under the profile, exit 2 on a direct call (`documents.Outage`). This applies to bounds, coherence, data, digests, freeze, frontmatter-lock and traceability. The `contracts`, `data` and `delivery` verbs exit 2, never 1.
- **A pin stands only when it can.** A pin is admitted as an artefact's home only when it is well formed, comes from the project's store, and sits under a category homed there. A forged pin, or a pin from another store, leaves a deletion red. A re-pin, a draft over a pin, and a deleted pin are judged like the file.
- **Re-approval on the base.** When the base re-approved after the fork, the red says to rebase onto the base. An edit made in the store is drift; the red names both cures (restore the version, or `--pull`, refine, `--approve`).
- **One approval predicate** (`common.approved`, read by qa and documents). Decoration is ignored, a REJECTED or INVALIDATED verdict denies, and a non-string value approves nothing.
- **Nothing leaves the repo without the secrets floor.**
  - `--approve` runs the secrets floor (`SECRET_PATTERNS`, DC-31 layer 1) on the bytes. A hit refuses the publish and names the file, never the match. If the floor is not delivered, the publish is refused too.
  - A credential that is not ASCII, printable and trimmed is refused by name, never shown.
  - Neither a header refused by the transport nor a built adapter's stderr ever reaches a message.
- **Store bytes never backtrack.** A page is unwrapped by a linear scan: exactly one code macro, and a body made of CDATA only. Text inside a CDATA is never read as structure, so an artefact that quotes Confluence storage round-trips. A page over 8 MB and an answer over 16 MB are refused.
- **Paths and shapes.** An artefact path stays inside the repo. The memo never writes through a link. Two pages with one title, or an update answered by another page, is a fault. `approved_at` is ASCII digits only. A pin nested too deep is a fault.
- **Transport classes.** 401, 403, a second 429, any 5xx, a cut response and an answer that is not JSON are outages. Any other 4xx is red.
- **No `{{…}}` in shipped code.** The git commit check is written `ref + "^{commit}"`. The synthetic materialisation resolved the f-string's `{{commit}}` as a placeholder, which broke every read at a ref (`documents._at`, `common.py`).
- **Text aligned (LAW-17).** Every existence or frontmatter check counts the pin and reads through `--read`. The `documents` member is named in the light profile. The peer-review approval is an executed step.

### Round 1 — accepted, not cured (informational)
- `approved_at` compares at one-second granularity. Two approvals within the same second are indistinguishable, and harmless.
- No dedicated exit code for the store down: exit 2 plus the fault line is the contract `profile.classify` reads.
- The `vault_name` answer shape and owner-typed placeholders (pre-existing, outside this change).
- `approved_at` / `approved_by` in the lock's permitted keys predate this change.

### Owner decisions
- **RDR CI verification of pins (2026-11-09).** Owner, verbatim: «1, y sino se provee 3 coo backup». CI carries a read-only credential: it goes only to the store the base names, a missing credential is a wiring finding, and an outage stays n/a + WARN. Without a credential, verification is local only (option 3), documented as a known risk. The backup's selection is the next decision.
- **RDR backup selection (2026-11-09).** Owner, verbatim: «1». It is declared at SETUP. `documents.verify: ci|local` is asked only when an external store is answered. With `ci`, a missing credential at the `ci` control point is a RED wiring finding. With `local`, the result is n/a + WARN «verified locally only (declared)», and the materialisation report records the accepted risk.
- **RDR-2 external CODESIGN authoring with business homed outside (2026-11-10).** Owner, verbatim: «Tecnicamente lo suyo seria integrarlo con tras opciones. confluence, github wiki y repo» · «ejemplo se construye en claude y se almacena en repo, confluence o Github wiki» · «estamos hablando solo de los documentos generados por ese subproducto, verdad, para el reto no hay problema». Read as option 1 (import through the one reader, § 7), store-agnostic: the repo, Confluence and any built store today. Scope: the four business artefacts the PO loop writes and reads back (`user_journey.md`, `slice_map.md`, `vision.md`, `navigation_map.md`). The PO package reads no design or report artefact; every other consumer of those reads through the reader (§ 4). Requirement: the package carries the approved business (the pinned version, never the store's latest); the validator judges a return against it; the store down stops the tool; nothing is copied into the repo; the credential never travels with the package. GitHub Wiki as a shipped store: RDR-3.
- **RDR-3 GitHub Wiki (2026-11-10).** Owner, verbatim: «2». This change closes with the repo, Confluence and the built adapter as the stores. GitHub Wiki gets its own shipped adapter in #224 (EVOL-129, epic #151), under the same contract and gate. Until then, a project that answers GitHub Wiki gets the built adapter at materialisation, with a WARN; the PO package reads it unchanged through the reader.

### Round 2 (four lenses, the cure diff) — cured
- **The credential goes only where the base points.** The round-1 overlay (the base's site and space under the tree's other keys) is replaced by a guard: a pull request that adds the store or changes any key that steers the credential is the store down until it merges. A built store is covered too (its commands and credentials), and an adapter switch is a new store.
- **A store move is one pull request.** `--pull` each pinned artefact at the old address, delete its pin, change the address, `--approve` at the new one. An approval whose pinned page cannot be read names this recovery.
- **A built command gets only its credentials.** It runs with PATH, HOME, the locale, the temp folder, the proxy and CA variables and the names in `documents.credentials` — no other variable of the CI reaches it. Its answer is capped at 16 MB; JSON nested past reading is red, in `rest.py` too. A text UTF-8 cannot encode is red at the hash.
- **The wiring is proven before the first pin.** At `ci` with `verify: ci` and a category homed outside, the store is opened even with no pin, so a missing credential is red on the first pull request. A refused one is red when a pin is read.
- **A weaker verification is named.** A pull request that moves `documents.verify` (e.g. `ci → local`) carries a WARN.
- **The gate warms the run's memo**, so the members after it read each pin without a call.
- **The email is checked only where it is sent** (Cloud).
- **The pin is written inside the repository**, checked before anything is published.
- **An unread plan leaves its cases unjudged.** Traceability takes the outage in `declared` and `retired`; the links, walks and baseline entries of a feature whose plan the store could not answer are never unknown or stale. Six gate-level tests prove a red stands beside an outage (bounds, coherence, data, digests, freeze, traceability).
- **Text aligned.** README (Q38.8), the rule's CI and address bullets, the materialisation and upgrade instructions (a built store's credentials in the workflow's env block; a fork's pull request gets no secrets), the report, the CI templates (GitHub's fork and Dependabot secrets; GitLab variables masked, not protected).

### Round 2 — accepted, not cured
- **The declared scanner does not read the draft before the publish.** `--approve` runs the secrets floor only. `security_scan.secrets_command` reads git history ranges, not a file: it reads the draft's bytes when its commits are pushed, after the publish. A file-mode scanner contract would be a new key per scanner (DC-29). Residual risk: a token the floor's patterns miss reaches the store before the push scan names it; the store is the team's own, behind its access control.
- Direct calls (`gate.py documents --read`, a gate run outside the profile) read the tree's address: the guard applies under the profile, where a pull request's tree is untrusted.
- A pin's id may name any page the credential can read; a read-only account limited to the one space bounds it.
- The secrets floor's patterns are not exhaustive (DC-31 says so); the declared scanner is the second layer.
- The other members run with the CI's full environment, as before this change.
- A credential with a line break or a non-ASCII character is a fault (exit 2) named by variable, not the wiring red.

### Round 3 (four lenses, the PO package import) — cured
- **The reader is told the repository.** `CLAUDE_PROJECT_DIR` set by a session in another project made the reader resolve the wrong tree; the call now passes `--repo`.
- **Nothing lands in the repository through the reader.** The child runs with `PYTHONDONTWRITEBYTECODE`, so an operator without it exported gets no `__pycache__` under `scripts/gates`; the snapshot is taken after the validator too.
- **Exact bytes.** The answer is read as bytes and decoded strictly; text is written with `newline=""`. A CRLF artefact reaches the package unchanged; bytes that are not UTF-8 stop the tool.
- **Plain failures.** A missing `scripts/gate.py` names `SETUP --upgrade`; a timeout says the store did not answer in 300 s; the reader's own line is passed through; the closing hint is «fix what it says, then run again».
- **One read per artefact and run** (a run-scoped memo), `stdin` closed.
- **Proof widened.** The declared credential reaches the store and nothing else (a canary); the golden return is judged against the approved journey; per-artefact outage; no zip with the store down; the test header names Part 2c.
- **Text aligned.** The runbooks name every business artefact, the intake skill's exit-2 meaning names the store, the subproduct's own docstring and the catalogue header no longer say "the repository".

### Round 3 — accepted, not cured (informational)
- The vision's synced copy is not observed on its own: it takes the same `_synced_copy` path as the journey, which is.
- The reader runs with the caller's full environment: it is the project's own trusted tree, and its built command gets only the declared credentials (Round 2).
- `extra_files`, the builder's symlink following and a partial staging tree on failure predate this change; the staging folder lives outside the repo.
- The subproduct's `--selftest` carries no pin case: meta CI covers the import (Part 2c), and the selftest stays hermetic.
- `.pin.json` and the "synced" predicate are spelled in the subproduct as well as in `documents.py`: the subproduct imports nothing by contract (EVOL-052); both sides fail closed.
- On Windows the reader's text-mode stdout would translate line ends; the framework's gates and hooks run under bash, and its CI on Linux runners.

### Round 4 (four lenses, the cure diff) — cured
- **One artefact parses alike from either home.** Exact bytes reached the frontmatter parse: a journey approved with CRLF lost its scope, and a navigation map kept its frontmatter in the route map (correctness and governance). `read_artefact` keeps the bytes only for a copy (`exact=True`); every parse reads line ends as `read_text` reads a file. Part 2c pins both with CRLF.
- **The leak proof reaches the zip and the errors.** The canary is searched inside each zip member, not the deflated archive, and in the store-down and missing-reader output; the fake store echoes the token when it refuses.
- **Every named failure is proven.** The timeout, a reader that cannot start and bytes that are not UTF-8 are asserted in-process; the missing-reader line is asserted with its `SETUP --upgrade` cure.

### Round 4 — accepted, not cured (informational)
- The memo is keyed by repository and path, not by the pin's hash: one CLI run cannot see a pin change, and no caller imports the subproduct.
- The reader's last stderr line passes through as it is (300 characters): the reader cleans its own messages, and a raw tail needs `GATE_DEBUG=1`, which the operator sets.
- The golden return asserts the verdict, not the read itself; the glossary mutant (read the file instead of the store) fails it.
- The validator's missing-reader case is not run on its own: the builder and the validator share `read_artefact`.
- The "GitHub Wiki gets a WARN" clause of RDR-3 is the discovery warning «`X` has no shipped store» (`test_q38_documents_source_is_derived`).

