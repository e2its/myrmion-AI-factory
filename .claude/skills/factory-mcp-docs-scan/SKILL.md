---
name: factory-mcp-docs-scan
description: "Factory MCP Docs Scan — agent self-introspects its tool registry, filters by explicit allowlist, emits a single-line banner naming consulted MCP docs sources. Use when: BLUEPRINT --start, BLUEPRINT --refine, IMPLEMENT --build, IMPLEMENT --refine."
applicable_when:
  command: [blueprint, implement]
docs_mcp_allowlist:
  - context7
  - aws-knowledge
  - pulumi
  - claude_ai_Google_Drive
  - claude_ai_Microsoft_365
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

  # 2. Filter by explicit allowlist (frontmatter `docs_mcp_allowlist`). NO heuristics.
  allowlist = THIS_SKILL.frontmatter.docs_mcp_allowlist
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
- **Allowlist-based filtering** — adding a new docs MCP requires editing this skill's frontmatter `docs_mcp_allowlist`. No regex / heuristic detection.
- **`none detected` is a warning, not a block** — greenfield / offline use must not break.
- **Scope value** is `design` for BLUEPRINT (`--start`, `--refine`) and `implementation` for IMPLEMENT (`--build`, `--refine`).
- **Citation contract** — when `docs_mcps NOT EMPTY`, the consumer (BLUEPRINT step 2.6 / IMPLEMENT step 3.4) MUST cite each docs MCP it queried in the iteration body and populate `iterations[-1].mcp_consulted: [names]` (factory-iteration-model § Canonical Iteration ID).

## Extending the allowlist

Add a server name to `docs_mcp_allowlist` in this file's frontmatter when:
- A new docs-focused MCP server is integrated (e.g. official docs MCP for a framework).
- An existing MCP that primarily provides documentation lookup is connected (e.g. a new vendor docs MCP).

Do NOT add general-purpose MCPs (chrome-devtools, pulumi for resource ops, etc.) — those are not docs sources.
