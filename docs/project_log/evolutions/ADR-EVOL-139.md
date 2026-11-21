---
id: ADR-EVOL-139
title: "Cross-repository inventory reuse — agents check sibling repositories' inventories at their main commit before creating a component, off by default"
date: 2026-11-21
status: accepted
---

# ADR-EVOL-139: Cross-repository inventory reuse

## Context

This ADR plans issue #251 (epic #112, wave 5), the follow-up of spike #141 (ADR-EVOL-087, option 2, decided on evidence). It was checked on `origin/main` at framework 10.17.0 (9afd19c).

In a product spread over several repositories, the reuse check ([LAW-03], CIP) reads only the local `config/codebase_inventory.json`. A component that already exists in a sibling repository is created again. #251 asks for the following:

- the siblings named once at SETUP by a registry question (none by default, and then nothing changes);
- each sibling's inventory read at its main-branch commit, with that commit on every match, never copied into the repository;
- a read-only token named from the vault, never a value;
- the mechanical criteria computed by a script, so that the agent receives only the matches;
- an unreachable sibling, or one without an inventory, named in plain language while the agent goes on, warned;
- every SCM the platform answer supports;
- every phase, reader, template and upgrade step that touches the consultation agreeing in the same change.

It does not want:

- a server, a database, a CI job or a copy of a sibling's inventory;
- a second definition of probes, element ids or the file → element map (#129, #154);
- in-flight branches read;
- a push or CI gate member;
- a credential in an MCP entry or an answer;
- an agent reading a whole sibling inventory.

Evidence (repository):

- **The registry** (`.context/templates/setup/setup/discovery_registry.json`):
  - A question is `{id, tier, since, when?, keys}`.
  - A list answer is `free: list` (Q21.2 `scm.required_checks`).
  - A credential key must be `free: vault_name` (V3, `discovery.py` `_v3`), as with Q27.9 `project_tracking.token` and Q38.3 `documents.token`.
  - `when: "<key> exists"` holds only for a non-empty list (`discovery.py` grammar).
  - `SETUP --upgrade` Step 8b.3 asks each pending question generically (`Factory-setup-upgrade.instructions.md:185`).
  - V4 wants a reader for every persisted key. V6 wants a `#### Qn` heading with a `**Persist:**` line in the discovery instruction. V7 wants a slot in the `setup_master_template.md` frontmatter.
- **The transport:**
  - `scripts/gates/rest.py` `call(service, site_hint, auth_hint, method, url, headers, body=None)` answers a redirect and never follows it, caps the body at 16 MB, and keeps every query and header value out of its messages. `Unreachable` / `Refused` are its transport faults.
  - `scripts/gates/scm.py`:
    - `remote(repo, url)` parses any clone URL (ssh, scp-like, https; Azure org/project/repo);
    - `KNOWN_HOSTS` maps a host to its platform;
    - `PLATFORMS` / `ADAPTERS` are GitHub, GitLab, Bitbucket and Azure DevOps.
  - No adapter reads a file's content.
- **The consultation:**
  - `factory-codebase-inventory/SKILL.md:16-62` `cip_consultation_gate` and `:154-197` hold the four criteria:
    - EXACT_MATCH: name and type;
    - SAME_DOMAIN: module and type;
    - NEAR_DUPLICATE: semantic, judged by an LLM;
    - NAME_SIMILAR: Levenshtein < 3, same type.
  - These criteria are pseudo-code: no script computes them.
  - An inventory entry is `{name, type, module, path, feature_ids, responsibility, interfaces, status, registered_by, registered_at}`.
- **Probes, element ids, file → element map:** defined nowhere in this tree. #129 and #154 own them, and this change defines none.

Evidence (external, beat 0, the docs reader):

- **GitHub** (docs.github.com/en/rest):
  - `GET /repos/{o}/{r}` → `default_branch`;
  - `GET /repos/{o}/{r}/branches/{b}` → `commit.sha`;
  - `GET /repos/{o}/{r}/contents/{path}?ref={sha}` with `Accept: application/vnd.github.raw+json` → the raw bytes (raw-only up to 100 MB);
  - a 302 is listed without a trigger;
  - a private repository without access answers 404, not 403.
  - Base `https://api.github.com`, or `https://{host}/api/v3` (GHES).
- **GitLab** (docs.gitlab.com/ee/api):
  - `GET /projects/{url-encoded path}` → `id`, `default_branch`;
  - `GET /projects/{id}/repository/branches/{b}` → `commit.id`;
  - `GET /projects/{id}/repository/files/{url-encoded path}/raw?ref={sha}` → raw;
  - auth with `PRIVATE-TOKEN`;
  - 404 means both missing and unauthorised.
- **Bitbucket Cloud** (api.bitbucket.org/swagger.json):
  - `GET /repositories/{ws}/{slug}` → `mainbranch.name`;
  - `…/refs/branches/{name}` → `target.hash`;
  - `…/src/{sha}/{path}` → raw contents (only LFS files redirect);
  - 403 means no access and 404 means missing;
  - scope `read:repository:bitbucket`.
- **Azure DevOps** (learn.microsoft.com, api-version 7.1):
  - repository → `defaultBranch` (`refs/heads/…`);
  - `refs?filter=heads/{b}` → `objectId` (a starts-with filter: match the name exactly);
  - Items - Get with `versionDescriptor.versionType=commit&includeContent=true` → JSON `content`;
  - auth Basic `:{PAT}`; scope Code (read).

## Decision

1. **The question.**
   - One registry question asks for `inventory.siblings`, `free: list` of clone URLs. It is asked always, and its recommendation is the empty list.
   - A second key, `inventory.siblings_token` (`free: vault_name`), asks for the vault entry's name. It is owed only `when: "inventory.siblings exists"`.
   - Both carry `since: 10.18.0`. `SETUP --upgrade` asks them through Step 8b with no clause of their own.
   - The answers live where every answer lives, the `docs/setup.md` frontmatter. No config key repeats them.
2. **The reader — `python3 scripts/gate.py inventory --siblings`.** Owner RDR, 2026-11-21, on how the agent calls it (CLAUDE.md Generation Standards §4). Three options were posed: a dedicated subcommand, a flag on an existing reader, or a snippet in the CIP skill. The owner's choice, verbatim: **«1»**. The do-less pass (DC-29) weighed the flag and the snippet: the subcommand builds no more than either, and only a script keeps the token out of the agent's context and the matching testable.
   - The candidates `[{name, type, module}]` come on stdin. It prints JSON `{matches: [{source, sha, criterion, entry}], warnings: [...]}`. It exits 0 whatever a sibling answers, and 2 on a bad call (no `--siblings`, candidates not JSON or malformed).
   - It reads `inventory.siblings` from `docs/setup.md`. With none declared, it reads nothing and says so.
   - Each sibling is parsed by `scm.remote(repo, url)`. Its platform comes from `scm.KNOWN_HOSTS`, or else from the project's `scm.platform` answer (a self-hosted host).
   - **One token, one platform.** Owner RDR, 2026-11-21, on where the token may go. Three options were posed: the project's own SCM only, one token per platform, or one token to every sibling with the risk documented. The owner's choice, verbatim: **«1»**. The token is sent only to the project's origin host, or, when that host is SaaS, to the same platform's SaaS host. A self-managed server's token never leaves it, not even for the platform's SaaS host. Bitbucket and Azure DevOps are read on their SaaS API only. Any other sibling is one named warning, unread. A platform issues its own tokens, so a second platform could not be read with this token anyway.
   - The calls go through `rest.call`, which a test can replace. Per sibling, in order:
     1. the default branch;
     2. its head commit;
     3. the raw `config/codebase_inventory.json` at that commit.
     Nothing is cached and nothing is written.
   - The token is read from the environment variable `INVENTORY_SIBLINGS_TOKEN`. Its absence is a warning that names `docs/setup.md → inventory.siblings_token`.
   - Criteria 1, 2 and 4 are computed against each sibling's entries. Only the matching entries return, whole, so an element id #154 adds later rides along. Every string in them is cleaned (no control or bidi character) and capped: another repository's data, never an instruction.
   - Every value that lands in a URL is encoded; a commit id must be hex and a GitLab project id digits.
   - Criterion 3 (semantic) stays local: it would need the whole sibling inventory in the agent's context.
3. **Fail-open, named (LAW-08).** No token: one warning, nothing read. Otherwise each sibling that yields nothing returns one plain warning naming its URL, and the remaining siblings are still read:
   - a URL carrying a credential (refused unread; the warning shows the URL without it);
   - an unsupported platform;
   - refused (401/403);
   - unreachable (network, 5xx, a redirect never followed);
   - no inventory at the main commit or no access (404 — GitHub and GitLab do not tell the two apart);
   - not an inventory (not JSON, not an object, no `artifacts` list).
   No message carries the token.
4. **The consultation.**
   - `cip_consultation_gate` gains one step, always run: it pipes the artefacts it is about to create into the reader; none declared → a note. Each match is decided the same way as a local one, tagged `{source}@{sha}`: REUSE (consume it, record the pin, never write a foreign entry) or CREATE_NEW; a sibling is never extended from here.
   - **The architect decides reuse.** Owner direction, 2026-11-21, verbatim: «no me vale, es algo que el sistema debería poder decidir sin intervención humana» · «debería poder decidir si un módulo existe y es reutilizable» · «el arquitecto debería revisar qué hay construido antes de proponer construir nada nuevo si ya existe un componente para eso. Eso es lo que hace un arquitecto y para eso gestionamos un code_inventory». The CIP's one decision home (factory-codebase-inventory § Reuse Decision) changes from a user RDR per candidate to the agent's decision from the evidence, local and sibling alike. Each decision lands in § Reuse Analysis with one line of rationale and is reviewed at BLUEPRINT --approve. The user is asked only when the choice changes what the product does for the business (LAW-16). Aligned in the same pull request (LAW-17): blueprint-design −2d and −1c, the blueprint-validation refine re-check, implement-build 0d, the canary and design_template § Reuse Analysis. CODESIGN's domain-concept overlap stays the user's: it is a business decision.
   - The design's § Reuse Analysis records that pin.
   - BLUEPRINT (−2c, the refine re-check) and IMPLEMENT (plan S.2, build 0d) consult siblings. CODESIGN 0.5 stays local: its domain check is business-only (LAW-16).
5. **Not a gate.** The reader is no profile member, no CI step and no workflow.

## Rejected

- **A config key mirroring the answer** (`config/quality.json → inventory.siblings` through a fill). It would create a second home and a seam to merge on upgrade. The answer is read where it lives.
- **A cache by commit SHA** (ADR-EVOL-087 sketch). A file holding a sibling's entries is a copy, which #251 does not want. Three calls per sibling per consultation cost little.
- **Reusing the CI token names** (`scm.TOKENS`, `GITHUB_TOKEN`). The CI token's rights are broader and its scope is one repository. A dedicated read-only variable keeps the sibling read least-privileged.

## Consequences

- With no siblings declared, nothing changes: the token question is not owed, and the reader reads nothing.
- With siblings declared, a component that already exists next door surfaces before it is created. The agent receives only the matches, each pinned to the sibling's main commit.
- Honest limits:
  - Semantic near-duplicates across repositories are not detected.
  - On GitHub and GitLab, a missing inventory and a token that cannot see the repository give the same 404, so the warning names both.
  - Rate limits were not measured (ADR-EVOL-087).
  - A sibling that was never materialised has no inventory and is named as such.
  - An entry's strings are capped at 300 characters; a longer description is cut.
  - A sibling on another platform or another server is not read: one token reaches one SCM.

## Verification

- **Unit tests, red first, through the injected call:**
  - the four platforms' three calls (URLs, auth headers, the exact-name ref match on Azure);
  - criteria 1, 2 and 4, plus no match;
  - none declared → nothing read;
  - an unreachable sibling → a warning, and the other sibling still read;
  - no inventory → named;
  - a redirect → not followed, named;
  - no token → named;
  - the token in no message (the warnings and the output scanned for the token's value).
- **Registry:** V3, V4, V6 and V7 green. The token key is owed only with siblings declared.
- **Synthetic with `--answers`:**
  - `default` (empty list) lands nothing, and the token question is not owed;
  - a two-sibling fixture resolves the token key.
- **Gates:** lock-step, `manifest --check`, `manifest-parity`, `discovery`, `laws --parity`, `budget`, `profile --run`; the whole CI T2 list and synthetic matrix before the push.
- **A mutation sweep** in a scratch copy.
