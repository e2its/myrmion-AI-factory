---
description: "Protected code policy — PROTECTED-CODE block enforcement, immutable sections, code review gates for protected regions. Applied when editing source code files."
applicable_when:
  path_glob:
    - "**/*.js"
    - "**/*.ts"
    - "**/*.jsx"
    - "**/*.tsx"
    - "**/*.py"
    - "**/*.java"
    - "**/*.cs"
    - "**/*.go"
    - "**/*.rs"
    - "**/*.rb"
version: 1.4.1
date: 2026-01-26
changelog:
  - "1.4.1: feat(EVOL-044) — frontmatter `version` realigned to this manifest entry (manifest-parity gate); YAML made parseable where needed."
  - "1.4.0: chore(EVOL-044) — frontmatter version realigned to the governance manifest (the manifest is the source of truth; gate: gate.py manifest-parity)"
  - "1.0.0: Initial template version"
---

# Protected Code (Anti-Drift)

> **Purpose:** Declare RED/YELLOW/GREEN zones and required extension patterns.  
> **Source:** `docs/setup.md` scan results (Brownfield adds legacy paths).

## Zones
- **RED:** Framework/vendor code (`node_modules/`, `venv/`, `vendor/`), governance (`.context/**`), legacy paths detected in Brownfield, any block marked `PROTECTED-CODE START/END`.
- **YELLOW:** Extension points (wrappers/decorators/adapters) touching RED code indirectly.
- **GREEN:** Application code you own; free to change with tests.

## Rules
- Never edit RED directly; use GREEN adapters/wrappers/DI/middleware.
- Before editing, check `.claude/rules/protected-code.md` and `config/protected-paths.json`.
- CI drift check blocks merges on RED modifications.

## Extension Patterns (Allowed)
1. **Wrapper**: encapsulate legacy/third-party services in `src/adapters/`.
2. **Decorator**: add behavior without touching parent classes.
3. **Dependency Injection**: swap implementations via interfaces.
4. **Hooks/Middleware**: use framework extension points instead of patching core.

## Maintenance
- Update legacy RED paths after refactors (with ADR). 
- Re-run `/SETUP --init` to refresh detected RED zones.
- Commit updates; review in PRs.

## See Also
- `.claude/rules/protected-code.md`
- `.claude/rules/architecture.md`
- `.claude/rules/security_policy.md`

## [LAW-02] Protected Code
> Protected code blocks and protected paths are never modified.

NEVER modify code between `PROTECTED-CODE START` / `PROTECTED-CODE END` markers, nor any path listed in `config/protected-paths.json` (`paths[]` blocking — an ADR is required to touch them; `yellow_zones[]` warn). Pre-flight and push gates (factory-pr-review Block 12) fail closed on a protected path in the diff.
