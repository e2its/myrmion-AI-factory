---
name: factory-mcp-docs-scan
description: "Factory MCP Docs Scan — agent self-introspects its tool registry, filters by explicit allowlist, emits a single-line banner naming consulted MCP docs sources. Use when: BLUEPRINT --start, BLUEPRINT --refine, IMPLEMENT --build, IMPLEMENT --refine."
applicable_when:
  command: [blueprint, implement]
docs_mcp_allowlist:
  - context7
  - aws-knowledge
  - pulumi
  - microsoft-learn
  - cloudflare-docs
  - google-developer-knowledge
  - terraform
---

# MCP DOCS SCAN

> **Shared Protocol** — Referenced by: BLUEPRINT `--start` / `--refine`, IMPLEMENT `--build` / `--refine`.
> Surfaces which documentation MCPs the agent can consult before generating design or implementation. Banner is mandatory and per-invocation (NOT cached across turns — MCP servers can crash mid-feature).

## Algorithm

```yaml
FUNCTION mcp_docs_scan(scope: "design" | "implementation"):
  # 1. Introspect own tool registry (function names visible at session start +
  #    surfaced via ToolSearch). NO bash way to enumerate MCPs — the agent reads
  #    its own tools list.
  available_mcp_tools = list_own_tools_matching(/^mcp__([^_]+)__/)
  available_mcp_servers = unique(extract_server_name(t) for t IN available_mcp_tools)

  # 2. Filter by explicit allowlist (frontmatter `docs_mcp_allowlist` + the project's
  #    config/quality.json → agents.docs_servers keys, EVOL-138). NO heuristics.
  allowlist = THIS_SKILL.frontmatter.docs_mcp_allowlist + keys(config.agents.docs_servers)
  docs_mcps = intersect(available_mcp_servers, allowlist)

  # 3. Emit banner (single line, mirrors Applicability Roll-Call style).
  IF docs_mcps NOT EMPTY:
    EMIT: "🔌 MCP Docs Scan — {' | '.join(name + ' ✓' for name in docs_mcps)} | (consulting before {scope})"
  ELSE:
    EMIT: "🔌 MCP Docs Scan — none detected | proceeding with training data"

  # 4. Return for downstream consumers (instruction Step 2.6 / 3.4 cite findings).
  RETURN { docs_mcps: docs_mcps, scope: scope, ts: NOW_ISO() }
```

## Output Banner Format

Examples:

```
🔌 MCP Docs Scan — context7 ✓ | aws-knowledge ✓ | (consulting before design)
🔌 MCP Docs Scan — context7 ✓ | (consulting before implementation)
🔌 MCP Docs Scan — none detected | proceeding with training data
```

## Rules

- **Mandatory emission** at the first user-facing turn of every command invocation listed in `applicable_when.command`. Missing banner = `mal-iniciado`, halt and re-emit (same severity as missing Applicability Roll-Call).
- **Per-invocation scan** — never cached across turns. If a different command fires later in the same session, the scan runs again.
- **Allowlist-based filtering** — the framework's servers in this skill's frontmatter `docs_mcp_allowlist`, the project's in `config/quality.json → agents.docs_servers` (EVOL-138). No regex / heuristic detection.
- **`none detected` is a warning, not a block** — greenfield / offline use must not break.
- **Scope value** is `design` for BLUEPRINT (`--start`, `--refine`) and `implementation` for IMPLEMENT (`--build`, `--refine`).
- **Citation contract** — when `docs_mcps NOT EMPTY`, the consumer (BLUEPRINT step 2.6 / IMPLEMENT step 3.4) MUST cite each docs MCP it queried in the iteration body and populate `iterations[-1].mcp_consulted: [names]` (factory-iteration-model § Canonical Iteration ID).

## Extending the allowlist

This skill and the reader are framework-owned: sync replaces both whole, so a project never edits them (EVOL-138).

**The framework's servers** — vendor-official, documentation only, verified at source; registered in Claude Code under the name shown (the tool ids carry it, names exact):

| Name | Source | Register |
|------|--------|----------|
| `context7` | Upstash Context7 | `claude mcp add --transport http context7 https://mcp.context7.com/mcp` |
| `aws-knowledge` | AWS Knowledge | `claude mcp add --transport http aws-knowledge https://knowledge-mcp.global.api.aws` |
| `pulumi` | Pulumi registry tools | Pulumi MCP server |
| `microsoft-learn` | Microsoft Learn | `claude mcp add --transport http microsoft-learn https://learn.microsoft.com/api/mcp` |
| `cloudflare-docs` | Cloudflare docs | `claude mcp add --transport http cloudflare-docs https://docs.mcp.cloudflare.com/mcp` |
| `google-developer-knowledge` | Google Developer Knowledge (auth) | `claude mcp add --transport http google-developer-knowledge https://developerknowledge.googleapis.com/mcp` |
| `terraform` | HashiCorp Terraform MCP, registry toolset | `hashicorp/terraform-mcp-server` |

A server whose documentation tool sits beside write tools (Stripe, Vercel, Supabase, MongoDB) is not in this list: the project adds its documentation read operation itself. A server that reads the project's or the user's own data — source hosting, a database, payments, mail, tickets — is never a documentation server: the validator cannot tell a data read from a docs read by its name, so this line is the guard. A server that needs a key reads it from the environment (`${VAR}` in the MCP config), never a literal in a committed file.

**The project's servers** — `config/quality.json → agents.docs_servers`, each server mapped to its read operations, e.g. `{"vendor-docs": ["search_vendor_docs"]}`. The banner lists them, and `factory-sync.sh` lands the reader with `mcp__<server>__<op>` appended to its `tools:`. A server registered under another name than the table's goes here too. A server the framework already lists stays the framework's.

Never a general-purpose MCP (chrome-devtools, a cloud's resource operations) and never a personal-data connector (`claude_ai_*`: mail, drive, docs, office): the validator refuses them for the reader whatever a list says, because a reader that also fetches the web must never hold the user's private files.

The reader (`factory-docs-reader`, class `reader`, `rules/agents.md` § Beat 0, EVOL-056) carries the **read operations** of these servers and no other — `python3 scripts/gate.py agents` holds every definition of the class to them, and the drift check reads the landed reader with exactly the project's tail removed.

## [LAW-10] MCP-Docs Scan Banner
> Design and build invocations open with the MCP docs scan banner, computed per invocation from an allowlist and never cached.

BLUEPRINT `--start` / `--refine` and IMPLEMENT `--build` / `--refine` MUST emit the banner (`🔌 MCP Docs Scan — ...`) as the first user-facing line of every invocation. Missing banner = `mal-iniciado`. Per-invocation scan, never cached across turns. Allowlist-based detection, no heuristics — the framework's servers in this skill's frontmatter `docs_mcp_allowlist`, a project's in `config/quality.json → agents.docs_servers` (EVOL-138).
