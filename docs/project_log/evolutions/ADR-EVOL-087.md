---
id: ADR-EVOL-087
title: "Remote codebase inventory: sibling repositories' inventories read at their main-branch commit through the SCM the project already uses — no server, off by default"
date: 2026-11-19
status: proposed
---

# ADR-EVOL-087: Remote codebase inventory

## Context

Spike #141 (epic #112, wave 5). Verified on `feature/EVOL-084-design-system-catalog` at framework 10.9.0. Boundary (issue, 2026-10-09): transport, storage, indexing only.

**Today.**
- The inventory is one JSON file per repository, `config/codebase_inventory.json`. Agents read it from disk; missing → warn and proceed (`factory-codebase-inventory/SKILL.md:23-27`).
- It is already shared by the team **inside one repository**: it is tracked, written on the working branch at `IMPLEMENT --build` (`Factory-implement-review-checks.instructions.md:1361-1380`) and is a train close ledger (`.context/templates/setup/config/quality.json:235-240`; meta `config/quality.json:458-461`). The issue's «local copy on one disk» holds only for **other repositories**: no reader looks past the clone.
- Schema: `name, type, module, path, feature_ids, responsibility, interfaces, status PLANNED|IMPLEMENTED` (`SKILL.md:67-88`). No `id` (#153 Beat 0 Q4). PLANNED entries exist before any code (`SKILL.md:119-125`).
- Matching: criteria 1, 2, 4 are mechanical; criterion 3 is an LLM similarity (`SKILL.md:184-188`). Budget: one 2-10 KB read, no workspace scan (`SKILL.md:654-665`).
- Probes: Python only — `check-inventory-freshness.py:125-128`, `reconcile_inventory.py:308`. Drift check runs only in a GitHub Actions template (`governance_versions.json:665-670`).
- Gate readers of the inventory: `scripts/gates/catalog.py:41,258-267` (ui_component paths, local file); `scripts/gates/coherence.py:225` (no history key).
- SCM: `scripts/gates/scm.py` already speaks the APIs of GitHub, GitLab, Bitbucket, Azure DevOps (`:40` tokens from env, `:42` known hosts, `:327` adapters, `:457` injectable `fetch`). `scripts/gates/rest.py:1-10`: no redirect followed, credential never in a message.
- Credentials: a credential-named key must be `free: vault_name` (`scripts/gates/discovery.py:1112-1113`, V3); precedents Q27.9 `project_tracking.token` (`discovery_registry.json:2026-2036`), Q38.3 `documents.token` (`:2409-2418`). Q20.2 `hosting.secrets_manager` names the vault (`:1355-1371`).
- MCP entries: V12 admits a remote server only on an allowlisted vendor host, no `headers`, no `env` (`discovery.py:96`, `:1583-1590`); ADR-EVOL-079:108-109 keeps «the vault-name line of #159 for a consumer that needs a credential in the entry».

**Owned elsewhere — not re-decided here.**
- Language probes: each stack pack (#129 ships PHP: «PHP classes, interfaces, traits and enums in the codebase inventory, before #154 reuses it»).
- Element ids and file → element map: #154 (EVOL-097), designed by #153 (EVOL-096, not accepted yet).
- External source of truth read live at a pin, never copied: #153 RDR-1a, built by #134 (pin `{source, id, version, approved_at, sha256}`, `scripts/gates/documents.py:7,76`).
- Cross-branch visibility of in-flight work: #156's channel (#139 reuses it). Multi-author collisions on one file: #139.
- Registry, `--upgrade` asking new questions, MCP target: #159 (phase 2 shipped v8.17.0; MCP target shipped with #131).

## Questions

1. **HTTP transport with a token gateway.** Transport = the HTTPS API of the SCM each sibling repository lives on (already authenticated, already modelled in `scm.py`). No gateway: the SCM is the gateway; the token is read-only on repository contents. A Streamable HTTP MCP endpoint (MCP spec 2025-11-25, OAuth 2.1, RFC 9728 / 8707 [S1, S2]) is only needed if a server is built or adopted (options 3, 4).
2. **Storage.** None new. Each repository's own inventory file is the source of truth; the reader caches by commit SHA (immutable, so never stale).
3. **Index keyed by repo/branch/SHA fed by CI.** Key = (repository, default branch, commit SHA resolved at read). Git is the index; the merge to main is the feed — no CI job. In-flight branches are not read: their visibility is #156's channel.
4. **Annotations in code.** No. An annotation would be a second definition of an element (#154 owns ids and the file → element map); entries keep being written by agents and probes as today.
5. **How SETUP configures it.** One registry question (#159): the sibling repositories to read; recommended answer empty = off. A token key `free: vault_name` in the vault Q20.2 names. Asked always (#159 RDR C: a default is a recommendation, never a skip).
6. **Build vs adopt.** Desk bake-off below. Decisive criterion: the inventory holds PLANNED entries and SDLC fields (`feature_ids`, `responsibility`, `status`) that no code graph holds; every candidate indexes code only.
7. **Languages.** The inventory is language-neutral JSON. A sibling's entries are as complete as its own probes (#129 and later packs); the reader adds no probe.

### Bake-off (desk, 2026-11-19; licence and release via the GitHub API)

| Candidate | Licence | Latest release | Shared multi-repo | Remote + auth | Holds PLANNED / SDLC fields | Notes |
|---|---|---|---|---|---|---|
| Sourcebot | MIT | v6.1.1, 2026-11-18 | yes (GitHub, GitLab, Bitbucket, Azure DevOps) | Streamable HTTP `/api/mcp`, OAuth or API key bearer [S4] | no — code search, symbols | self-hosted server; daily request limit per tool call ❓ unverified — external (plan-dependent?) |
| GitHub MCP server | MIT | v2.2.0, 2026-11-16 | GitHub only | remote, OAuth or PAT; no GHES remote [S5] | no — files, tree; no symbols | one SCM |
| Serena | GPL-3.0+ app, MIT SolidLSP | v2.1.0, 2026-10-19 | per project, LSP | «HTTP mode», auth not documented [S6] | no | an editing tool, not a shared index |
| CodeGraphContext | MIT | v0.5.7, 2026-08-08 | yes, local graph DB | transport, auth not documented [S7] | no | needs a graph DB to run |
| code-graph-rag | MIT | v0.7.1, 2026-11-17 | yes, shared graph | not documented; NL queries need an LLM [S8] | no | |
| Joern | Apache-2.0 | v4.0.686, 2026-11-18 | per project CPG | no official MCP ❓ unverified — external | no | data flow, not reuse |
| Sourcegraph | proprietary ❓ unverified — external | public snapshot archived 2024 | — | — | no | excluded: licence |

Result: no candidate replaces the inventory; Sourcebot is the only one that would add shared, authenticated, multi-SCM code search (option 4). A measured run was not done (Honest limits).

## Decision to take (RDR)

### In plain words

**Qué se decide.** Cuando un producto vive en varios repositorios, cómo ve cada agente lo que ya existe en los demás antes de crear algo nuevo. Dentro de un mismo repositorio el equipo ya comparte el inventario: viaja con el código. El hueco son los otros repositorios.

**Por qué ahora.** El epic de equipos lo pide y la pieza de lenguajes y la de identificadores de elementos se están construyendo; conviene fijar cómo se lee de fuera antes de que cada una invente su camino.

**Caminos.**
1. **No hacer nada más.** Cada repositorio sigue con su inventario. Coste: cero. Riesgo: un equipo con varios repositorios duplica piezas sin enterarse.
2. **Leer el inventario de los repositorios hermanos donde ya están guardados (recomendado).** En la instalación se indica qué repositorios hermanos mirar (por defecto, ninguno: apagado). Una herramienta automática lee el inventario de cada uno tal como está en su versión principal, con una clave de solo lectura guardada en la caja fuerte de secretos, y devuelve al agente solo las coincidencias. Coste: una pieza pequeña y una pregunta más en la instalación. Límites: no busca dentro del código de los otros, solo en su inventario; un repositorio sin inventario no se ve; si el servicio de repositorios no responde, el agente sigue avisando de que no ha podido mirar.
3. **Construir un servicio propio de inventario compartido.** Un servidor que recibe el inventario de cada repositorio y lo sirve con autenticación. Coste: un producto nuevo que construir, alojar, asegurar y mantener; más superficie de ataque.
4. **Adoptar un buscador de código existente** (el mejor candidato es libre y autoalojado) junto al inventario actual. Coste: un servidor que alojar, abrir la puerta a credenciales en la configuración de los agentes, y agentes leyendo resultados de búsqueda (más consumo y más juicio, menos automatismo). No sustituye al inventario: no conoce lo que está solo planificado.

**Recomendación: 2.** Es lo que menos construye y aprovecha lo que ya existe. Se renuncia a buscar dentro del código de los otros repositorios; si más adelante una medición demuestra que hace falta, el camino 4 sigue disponible sin deshacer nada.

### Technical

**Evidence.** Inventory is tracked and shared within a repo (Context). No reader crosses repositories. `scm.py` already authenticates per platform with env tokens and an injectable fetch; `rest.py` holds the credential discipline; V3 forces `vault_name`; #153 RDR-1a forbids a copy of an external source of truth and wants a live read at a pin.

**Adversarial pass on option 2.**
- FOR, governance: no second definition (reads the sibling's own file, #154/#129 untouched); RDR-1a pattern (live read at a pin, no copy); one reader in `gate.py`; credential by vault name (V3); deterministic criteria by script, LLM only on the returned slice (agentic-philosophy line of #141); V12 untouched.
- FOR, product: zero infrastructure for the client team; works on every SCM `scm.py` models; off costs nothing.
- AGAINST, governance: a network read inside CIP consultation makes an agent step depend on availability → bounded: fail-open with a stated warning (LAW-08), never a push or CI gate member, as `documents` treats a store down. Cross-repo hits need a reuse RDR whose option set differs (reuse as a dependency vs copy) → the existing REUSE / EXTEND / CREATE_NEW set applies; the pin recorded in design § Reuse Analysis.
- AGAINST, product: no full-text or symbol search across repos; siblings outside the framework have no inventory and are invisible; a sibling's PLANNED entries on unmerged branches are not seen (#156 owns that).
- Do-less lens: could option 1 suffice? Only for single-repo products; #141 names multi-repo as the goal, so 1 leaves the stated scope unmet. Within 2, build less: no MCP server, no cache service, no CI job, no new storage, no annotation — one reader function per SCM adapter already present, one question, one token key.

**Options, per axis.**

| # | Option | SDLC governance | Product | Cost |
|---|---|---|---|---|
| 1 | Nothing more | + nothing to govern · − LAW-03 blind across repos | − duplicates across repos unseen | none |
| 2 | Federated read at the sibling's main SHA via the SCM API | + one reader, RDR-1a pin, V3, script-first · − network in an agent step (fail-open) | + no infrastructure · − inventory only, siblings must be materialised | one reader + one question + one token key |
| 3 | Own index service (Streamable HTTP MCP + REST, OAuth 2.1, DB keyed repo/branch/SHA, CI push) | − a second copy of each inventory (against RDR-1a), a server's whole security surface, V12 widening for headers · + one endpoint for all | + fast queries · − a product to host and operate | high: build, host, secure, run |
| 4 | Adopt Sourcebot beside the local inventory (remote MCP) | − V12 widening (self-hosted host, bearer header from a vault variable), LLM reading search results · + no build | + cross-repo code and symbol search · − a server to host; no PLANNED entries | medium: host + configure; tokens per query |

**Recommendation: option 2.** Main tradeoff: inventory-level reuse only, no cross-repo code search. Surviving risk: a sibling repository not run by the framework (no inventory) is invisible; the reader says so per source rather than staying silent.

## Consequences

- **What lands (answer non-empty):** the inventory reader gains a cross-repository read; the CIP skill's consultation step calls it and receives only matching entries tagged `{source, sha}`; the reuse RDR records that pin in design § Reuse Analysis. Answer empty (default): nothing lands, the reader reports n/a.
- **Selected by:** a new registry question (#159) listing sibling repositories, recommended empty; plus a token key `free: vault_name` asked only when the list is non-empty; the vault is Q20.2's.
- **Not changed:** the inventory schema, the probes, element ids, V12, `.mcp.json`, the gate profile.
- **Upgrade path:** the question carries its `since`; `SETUP --upgrade` Step 8b asks it generically (`Factory-setup-upgrade.instructions.md:212-215`); no hand-written clause.
- **Synthetic proof:** an answers fixture with an empty list lands nothing; one with two siblings resolves the token key; red tests through the injectable fetch (one sibling unreachable → warning, one with no inventory → named, a redirect not followed, a credential absent from every message).

## Follow-up issues

**Title:** Cross-repository inventory reuse — agents check sibling repositories' inventories at their main commit before creating a component, off by default
- **Goal:** In a product spread over several repositories, reuse is checked against every sibling's inventory, not only the local one.
- **We want:**
  - The sibling repositories named once, at SETUP, by a registry question (#159); none by default, and then nothing changes.
  - Each sibling's inventory read as it stands on its main branch, at a commit recorded with every match; never a copy kept in the repository.
  - A read-only token named from the vault (Q20.2), never a value.
  - The mechanical matching criteria computed by the script; the agent receives only the matching entries.
  - A sibling unreachable or without an inventory reported by name, in plain language (LAW-08); the agent goes on, warned.
  - Every SCM the project's platform answer already supports.
  - Every phase, reader, template and upgrade step that touches reuse consultation agreeing in the same change.
- **We do not want:**
  - A server, a database, a CI job or a copy of another repository's inventory.
  - A second definition of language probes, element ids or the file → element map (#129, #154).
  - In-flight branches of a sibling read (#156's channel).
  - The read becoming a push or CI gate member.
  - A credential in an MCP entry or in any answer.
  - An agent reading a whole sibling inventory or doing what the script can compute.
- **How it reaches a project:** selected by the new question (empty → nothing lands); lands the reader change, the CIP skill lines, the token key; `SETUP --upgrade` asks the question generically; proof: answers fixtures plus red tests through an injected fetch in meta CI.
- **Depends on:** #159 (registry, phase 2 shipped). Phases with #154: before it, matches carry today's fields; after it, the element id rides along unchanged — no change owed here.

## Honest limits

- The bake-off is a desk review (README, docs, GitHub API metadata); no candidate was run against a synthetic multi-repo fixture. If the owner picks option 4, a measured run (recall on a planted duplicate, tokens per consultation) is owed before build.
- ❓ unverified — external: Sourcebot's request limits and whether any MCP feature needs a paid key; Serena's HTTP transport and auth; CodeGraphContext and code-graph-rag transports; Joern MCP availability; current Sourcegraph licence.
- Rate limits of each SCM API for N siblings per consultation are not measured; caching by SHA bounds repeat reads but not the first.
- Option 2 assumes siblings are materialised by the framework (they carry an inventory); a mixed estate sees only part.
- Claude Code's `headersHelper` and `${VAR}` expansion in `headers` [S3] would make option 4 possible without a literal credential, but V12 forbids `headers` today; widening it is out of scope here.

**Sources.** [S1] https://modelcontextprotocol.io/specification/2025-11-25/basic/transports · [S2] https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization · [S3] https://code.claude.com/docs/en/mcp · [S4] https://docs.sourcebot.dev/docs/features/mcp-server , https://github.com/sourcebot-dev/sourcebot · [S5] https://github.com/github/github-mcp-server · [S6] https://github.com/oraios/serena · [S7] https://github.com/CodeGraphContext/CodeGraphContext · [S8] https://github.com/vitali87/code-graph-rag · Joern https://github.com/joernio/joern
