---
description: "Factory SETUP — codebase inventory reconciliation. Use when: SETUP --reconcile-inventory."
applicable_when:
  phase: [SETUP]
  command: [setup]
---

# SETUP Agent — Codebase Inventory Reconciliation (`/setup --reconcile-inventory`)

## Role

Governance Guardian. Bring `config/codebase_inventory.json` back into agreement with the actual codebase: relocate stale paths, register orphan artifacts, retire removed code. Operates per the protocol declared in `.claude/skills/Factory-codebase-inventory/SKILL.md` § Reconciliation Protocol.

This subcommand is the canonical entry point for the inventory reconciliation flow. The same protocol may run automatically (after merges, on demand from BLUEPRINT/IMPLEMENT canaries) but `SETUP --reconcile-inventory` is the human-driven invocation that closes drift before flipping the inventory-drift CI gate to blocking, before opening a feature PR that touches new BC surface, or whenever `python3 scripts/check-inventory-freshness.py` reports drift the agent cannot resolve in-flight.

## Pre-flight (Step 0)

Read these files before doing anything else:

1. `.claude/skills/Factory-codebase-inventory/SKILL.md` — full reconciliation protocol (Phases 1–5).
2. `config/codebase_inventory.json` — current state (especially `version` + `changelog` for context on the last reconcile).
3. `docs/constitution.md` § Architecture Stack Definition — for the BC list (which BCs the orphan scan covers).
4. `scripts/reconcile_inventory.py` — the reusable Python helper this command orchestrates.

## Pre-conditions (BLOCKING)

- `config/codebase_inventory.json` exists. If absent, the project has never been bootstrapped — run `SETUP --generate` first (the protocol's "full re-bootstrap" branch is reserved for fresh projects, not for sessions where the inventory was deleted by mistake).
- Working tree clean OR the only modified files are inventory-relevant (`config/codebase_inventory.json`, governance manifests). Reconciliation produces a focused commit; mixing it with unrelated edits dilutes the audit trail.
- If on `main`, refuse and create a `fix/inventory-reconcile-{date}` branch first (Pre-Action Protocol still applies).

## Execution

### Step 1 — Detect drift

```bash
python3 scripts/check-inventory-freshness.py --json > /tmp/inventory-drift.json
```

Parse:
- `summary.dead_path_count` — entries pointing to files that no longer exist.
- `summary.orphan_count` — code under canonical paths (`src/backend/*/{domain/entities,domain/value_objects,application/use_cases}/*.py`) without an inventory entry.

If both are zero → emit `✅ Inventory clean — no reconciliation needed.` and exit. Idempotency.

### Step 2 — Resolve dead paths (Phase 2 of the protocol)

For each entry in `dead_paths`:

- **Try to relocate**: `find src -name "$(basename "$path")" -type f 2>/dev/null`. If exactly one match, propose RELOCATE; if zero, propose MARK REMOVED; if multiple, RDR with the candidate list.
- **Status-aware**: entries with `status: PLANNED | DESIGNED` whose path doesn't exist yet are NOT dead — they are forward-looking. The freshness script (≥1.1.0) already filters these; this step is a fallback for inventory schemas that predate the filter.

Bulk-action shortcut: if every dead-path resolution is unambiguous (single relocate target), present them as a single approval gate with the proposed renames listed; one user "go" applies all.

### Step 3 — Register orphans (Phase 4 of the protocol)

For each path in `orphans`, build the inventory entry via the reconciler helper. The helper handles BC alias mapping, class-name probing (multi-class files get slash-joined names), docstring-aware description extraction, feature_ids per BC (with cross-BC overrides), and the `reusable` flag per kind.

```bash
# Auto mode — bulk-register every canonical orphan with the helper's defaults.
# Idempotent: re-running on a clean inventory is a no-op.
python3 scripts/reconcile_inventory.py
```

For non-canonical orphan paths the helper skips (returns None), surface them via RDR per artifact:

- **REGISTER**: hand-craft an entry (the helper's path-derivation doesn't fit). Use a sibling entry as a template.
- **SKIP**: add to `--orphan-allowlist` if the path is intentionally untracked (test helper, generated file, fixture).
- **DEFER**: leave the gate failing until a follow-up PR resolves it. Surface as a tracking note in the reconcile commit body.

### Step 4 — Enrich descriptions (optional but recommended)

When the helper falls back to a boilerplate template (file has no docstring, or a regex bug missed it on a previous run), re-run with the docstring extractor to pick up content that has since become readable:

```bash
python3 scripts/reconcile_inventory.py --enrich-descriptions
```

Idempotent. Only touches entries whose description matches the boilerplate fallback regex.

### Step 5 — Persist + verify

1. Bump `config/codebase_inventory.json` `version` (PATCH for additions, MINOR for renames/relocations, MAJOR for breaking schema changes — schema is governed by the inventory's own `$schema` field).
2. Append a `changelog` entry naming the reconcile trigger + counts (e.g. "Reconciliation triggered by inventory-drift CI gate flip — registered N orphans, relocated M dead paths").
3. Bump `last_updated` to today.
4. Re-run `python3 scripts/check-inventory-freshness.py` → must report `✅ Inventory clean`.
5. Update `docs/project_log/governance_versions.json`:
   - `config/codebase_inventory.json` entry — bump `version` + add changelog line.
   - If the freshness script or reconciler script changed, bump those manifest entries too.
   - `framework_version` — PATCH bump if this is a content-only reconcile; MINOR if reconciler logic changed.

## Post-execution

1. Commit suggestion: `fix(governance): reconcile inventory — register {N} orphans, relocate {M} dead paths` (or `chore(governance): inventory reconcile baseline` if the trigger was an upcoming gate flip).
2. Smart Redirect: if the reconcile was driven by a feature about to enter IMPLEMENT, suggest `IMPLEMENT --plan {FEAT-XXX}` next; otherwise return to `BACKLOG --status`.

## Failure modes + recovery

- **Helper script returns None for >50% of orphans**: the orphan paths are non-canonical (likely outside the standard DDD layout). Stop the auto-register and walk RDR-by-RDR; the file structure may need an architecture review before mass-registration.
- **Class-name probe returns empty for a file that should have classes**: the file uses a non-standard declaration (functional code, dataclass-only, dynamic classes via `type()`). Hand-craft the entry with a sensible name.
- **Docstring extractor returns None on a file that visibly has one**: the docstring uses a non-standard form (single-quote strings, raw strings, prefix-modifier strings). The probe regex covers `"""` / `'''` only; expand the regex if this becomes recurrent.

## Why this command is separate from `SETUP --upgrade`

`--upgrade` migrates governance scaffolding (constitution, rules, instructions) across framework versions. `--reconcile-inventory` operates on the project's own artifact catalogue. They sometimes run together (a framework upgrade may add new BCs that trigger orphan detection) but their concerns are distinct; bundling them would couple the framework's release cadence to the project's BC growth.

## Audit trail

Every reconcile produces:
- One `changelog` line in `config/codebase_inventory.json`.
- One commit message with the canonical pattern above.
- One `governance_versions.json` entry recording the framework_version bump.

The full reconciliation history is reproducible by walking `git log --follow config/codebase_inventory.json` + diffing the inventory's `changelog` array.

---

## See also

- `.claude/skills/Factory-codebase-inventory/SKILL.md` — the underlying protocol.
- `scripts/reconcile_inventory.py` — the Python helper this command orchestrates.
- `scripts/check-inventory-freshness.py` — the drift detector (CI gate).
- `.github/workflows/inventory-drift.yml` — blocking CI gate that requires reconciled state.
