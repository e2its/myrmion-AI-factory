---
description: "Defect Prevention Cases — origin, story and detection narrative per DC id. Annex to defect-prevention.md; read on demand by id, never at session start."
version: 1.0.0
date: 2026-09-25
changelog:
  - "1.0.0: feat(EVOL-043) — annex created; narratives moved out of the catalog prose columns into one case per DC"
applicable_when:
  path_glob:
    - "docs/project_log/**"
---

# Defect Prevention Cases

One case per row of `defect-prevention.md § Defect Classes`. Read a case by id when a row matches and the invariant alone is not enough. SETUP appends one case per materialised row; the Discovery Protocol appends one per new DC.

### DC-18 — SSR/CSR hydration mismatch from window reads in initial render

**Origin:** Server-rendered route whose component read `window` during its first render — React error #418 in the browser console after deploy.

**Story:** A component reads browser-only state (`window`, `document`, `localStorage`, `navigator`, `matchMedia`) inside its initial render and the route is server-rendered. The common attempt `useState(() => typeof window !== "undefined" ? readWindow() : default)` is insufficient — server returns one render, first client render returns another, hydration check throws React error #418. Fix pattern: `useState(<serverValue>)` + `useEffect(() => setX(readWindow()), [])`.

**Detection:** Static `grep -rn 'useState(() => .*window\.' <frontend-app-root>/` MUST return zero matches; Chrome DevTools MCP smoke during the SMOKE-E2E gate asserts zero `#418` errors in the browser console across every SSR-rendered page.

### DC-27 — Synthetic test data shape doesn't match production schema

**Origin:** Test suites green on synthetic values that the production parser rejects — tests passing for the wrong reason.

**Story:** Test factories or module-level constants synthesise values that satisfy `dict[str, Any]` but not the production parser. Patterns: single-char-repeating UUIDs, sequential zero-padded numerics for backup codes / external IDs, non-RFC-2606 fake emails (`test@test.com`), naive datetimes for `TIMESTAMPTZ` columns, plain strings for JSON-in-`TEXT` columns, plain strings for PHC-format columns. Production parsers reject; tests pass for the wrong reason. Fix (prevention, not detection): the same Pydantic semantic type production uses MUST be the constraint test factories build against.

**Detection:** Pydantic row model bound to factory via `_row_model` ClassVar (auto-validation hook); module-level realistic deterministic constants (`ANY_USER_ID`, `ANY_TENANT_ID`, etc.) for placeholders; lint script flags fake-pattern literals at module scope (single-char-repeating UUIDs, sequential zero-padded numerics, non-RFC-2606 emails).

### DC-28 — Cyclomatic complexity exceeds project threshold

**Origin:** A quantitative complexity budget replacing ad-hoc reviewer judgment (LAW-11). High CCN correlates with bug density, regression risk, and review fatigue.

**Story:** A source file under the project's code root contains a function whose cyclomatic complexity exceeds `config/quality.json.complexity.thresholds.hard` or `.thresholds.soft`. The check is MCP-driven: the project picks a complexity scanner (Semgrep or compatible) at SETUP and the scanner returns `{ file, function, ccn }` violations, which are classified `hard` (> hard threshold) or `soft` (> soft threshold). The skill itself is tool-agnostic; the MCP is chosen via RDR at SETUP.

**Detection:** BVL `full_verification_gate` invokes `factory-complexity-check` on `git diff --name-only $BASE..HEAD` after tests pass; factory-pr-review axis 6 invokes the same on the cumulative branch diff. `hard` violations block when `config/quality.json.complexity.bvl_gate==true` (BVL) or `.pr_blocker==true` (PR-review); `soft` always advisory. Fail-open when MCP unavailable or config absent.

### DC-29 — Over-engineering — code that exceeds task need (YAGNI / minimalism)

**Origin:** The "ponytail" discipline — the LLM tends to over-build: speculative abstractions, wrappers, config flags, dependencies, and boilerplate the task never asked for.

**Story:** Any code-bearing change in any phase. DC-28 caps *complexity* of code that exists; DC-29 questions whether the code should exist at all. The discipline is prevention-first: walk a decision ladder and stop at the first viable rung BEFORE writing code. Complementary, not redundant — DC-28 is quantitative on written code, DC-29 is qualitative on the build/no-build decision.

**Detection:** YAGNI ladder, stop at first viable rung: (1) does it need to exist? (2) stdlib? (3) native platform feature? (4) already-installed dependency? (5) one-liner? (6) only then minimal code. Four over-engineering categories flagged: **reinvented stdlib**, **unneeded dependency**, **single-implementation abstraction**, **dead flexibility** (config/flags/params with no caller). **Guardrail — how, not what:** the discipline argues a simpler *implementation*, NEVER cuts *specified scope* — a scope reduction is an RDR decision routed to CODESIGN, never a silent omission. NEVER simplifies input validation, error handling, security, or accessibility. Deliberate shortcuts marked with a `ponytail:` comment naming the ceiling + upgrade path. Consumed at decision-time by `factory-adversarial-reasoning` (do-less AGAINST lens, all phases) and at build-time by BVL `full_verification_gate` step 8 (advisory self-scan, fail-open, never blocks).
