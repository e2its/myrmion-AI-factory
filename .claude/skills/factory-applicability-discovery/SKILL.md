---
name: factory-applicability-discovery
description: "Factory Applicability Discovery Protocol (ADP) — live scan of governance trees (snapshot, instructions, structural skills, DCs) filtered by applicable_when frontmatter, emits canonical Roll-Call block on-screen as first user-facing message of every command. Use when: any command/skill enters Step 0 — produces the salience-anchor commitment before acting."
applicable_when:
  always: true
---

# APPLICABILITY DISCOVERY PROTOCOL

> **Shared Protocol** — Step 0 of every `.claude/commands/*.md`. Live discovery (no precomputed lists). Frontmatter-driven. Output is **on-screen, user-facing**, not internal reasoning.

**Purpose.** Force the agent to enumerate, in writing and visible to the user, which governance entries (laws, defect classes, rules, instructions, skills) apply to the current task — before any action is taken. This commits the agent's attention and gives the user a veto window. The framework remains **alive**: a new DC added today appears in tomorrow's roll-call automatically; no manual table to maintain — and no hand-written list: one resolver (`scripts/gate.py applicable`) computes it.

---

## When to invoke

- **Always at Step 0** of every command in `.claude/commands/*.md`. Section name in command file: `## Step 0 — Applicability Roll-Call`.
- **Re-invoke** when context changes mid-command (scope flip, phase transition, new sub-feature). Discovery hash drift is the trigger.
- **NOT invoked on free-form chat turns** — only when a slash command or structural skill executes.

---

## Inputs (filter context)

Derived from the runtime, never from a static config:

| Variable | Source |
|---|---|
| `command` | The slash command being executed (`/implement --build` → `command: implement`) |
| `phase` | Mapped from command (setup → SETUP, codesign → CODESIGN, blueprint → BLUEPRINT, implement → IMPLEMENT, qa → QA, devops → DEVOPS, backlog → BACKLOG, audit → AUDIT) |
| `scope` | `_progress.scope` of the feature spec frontmatter, else `project_scope` in `docs/setup.md` frontmatter |
| `change_type` | From the branch name: `fix/*` `bugfix/*` `hotfix/*` → `fix`; `feature/*` → `feature`; `docs/*` → `docs`; `chore/*` → `chore`; `refactor/*` → `refactor` |
| `framework` | `backend.framework` / `frontend.framework` of `docs/setup.md` (frontmatter), lower-cased |
| `paths` | Optional: the files the command will touch (a pre-flight over a known diff passes them; command start leaves them empty) |

---

## Discovery — ONE resolver (EVOL-043)

Hand-written rule lists are forbidden. Every pre-flight asks the same reader:

```bash
python3 scripts/gate.py applicable --phase {phase} --command {command} --change-type {change_type} \
        [--scope {scope}] [--framework {f1} {f2}] [--paths {p1} {p2}] [--feature {ID}] --format rollcall
```

`--format json` returns the same result as data (`active.laws / families / dcs / rules / instructions / skills`, `excluded[] {name, reason}`, `discovery_hash`, `scanned`). The block it prints IS the roll-call: paste it on-screen verbatim as the first user-facing message.

What the resolver reads: the law index (`CLAUDE.md § Governance Rules` universal `[LAW-NN]` entries + the constitution's `[PLAW-NN]` entries — always active); the defect catalog (`.claude/rules/defect-prevention.md`: families by surface glob, defect classes by `Paths`; a class with `Paths: *` is universal; `Applicable To` filters by agent when `--agent` is passed); every `.claude/rules/*.md`, `.claude/instructions/*.instructions.md` and `.claude/skills/factory-*/SKILL.md` frontmatter `applicable_when:`.

### Match semantics

- `always: true` → matches. Missing `applicable_when:` → `always: true` (back-compat).
- Several axes in one entry → AND. Several values in one axis → OR.
- `phase`, `scope`, `change_type` → the current value must be in the list.
- `command` → matches the command name or the full sub-command string.
- `path_glob` → against `--paths` when given, else against the tracked tree (any tracked file matching counts).
- `framework` → any project framework in the list.
- A frontmatter that does not parse, or an unknown axis → EXCLUDED with reason (`frontmatter-parse-error` / `applicable-when-invalid`); `scripts/check-applicability-frontmatter.sh` blocks it in CI before it ships.

The same resolver narrows the law at the point of edit (`.claude/hooks/deliver-governance.sh` → `gate.py deliver`) and builds the digest an agent receives at spawn (`gate.py digest`). One parser, no second definition.

---

## Output — canonical Roll-Call block

**MUST be the first user-facing output of every command.** Format is fixed, NOT subject to caveman tone rules. Target: ≤25 lines.

```
📋 Applicability Roll-Call — {command} · {feature_id} · phase={phase} scope={scope} change_type={change_type}

  ACTIVE LAWS (n)
    • {source} — {title} ({axis}={value})
  ACTIVE DCs (n)
    • {id} {title} ({axis}={value})
  ACTIVE RULES (n)
    • {name} ({axis}={value})            ← .claude/rules/*.md (technical + cross-cutting)
  ACTIVE INSTRUCTIONS (n)
    • {name}, {name}, {name}
  ACTIVE SKILLS (n)
    • {name}, {name}
  EXCLUDED (n)
    • {name} — {axis}={value} ≠ {current_value}
  Discovery hash: {hash8} · {total} frontmatters scanned · {active_count} active · {excluded_count} excluded
```

### Rules for the block

1. **Always emitted, even in plan/read-only mode.** Discovery is always safe. The block is the resolver's output, never re-typed.
2. **Never abbreviated, never collapsed into prose.** Format is fixed for parseability.
3. **EXCLUDED section caps at 6 entries.** If more excluded, show first 6 + `… and N more (see hash)`.
4. **discovery_hash is mandatory.** Used by tests and by mid-session re-discovery to detect drift.
5. **Empty sections render with `(0)` and no bullet** — never omit a section.

---

## Failure modes

| Condition | Behavior |
|---|---|
| Law index unreadable (no `CLAUDE.md` corpus and no constitution) | Roll-call prints `ACTIVE LAWS (0)`; the agent halts before Step 1 and regenerates governance (`scripts/generate-governance-snapshot.sh`). |
| `scripts/gate.py` missing | The resolver is a framework-shipped script (factory-sync / SETUP); halt and re-deliver — never fall back to a hand-written list. |
| Frontmatter parse error in any scanned file | The file is reported as EXCLUDED with reason `frontmatter-parse-error: <file>`. Agent continues but flags the broken file in a follow-up note. |
| `applicable_when:` syntax invalid (unknown axis) | Same as parse error — entry EXCLUDED with reason `applicable-when-invalid: <axis>`. CI gate `scripts/check-applicability-frontmatter.sh` should have caught it pre-merge; runtime treats as soft-fail. |
| Discovery hash drift mid-command (frontmatter edited mid-session) | Re-emit roll-call before next destructive action (Edit/Write). |

---

## Integration points

- **Step 0 of every `.claude/commands/*.md`** — wires this skill via the section "## Step 0 — Applicability Roll-Call".
- **factory-governance-loading SKILL** — runs BEFORE this skill (snapshot must be loaded first). This skill does not read the snapshot; it asks the resolver, which reads the corpus on disk.
- **factory-rdr SKILL** — independent. RDR can be triggered from inside any command; the roll-call block is emitted once at command start, not per RDR.

---

## [LAW-15] Applicability Discovery vocabulary
> Every governance entry declares where it applies through the closed applicable_when vocabulary, and one resolver decides what applies.

Every entry in `.claude/instructions/`, `.claude/skills/factory-*/`, and `.claude/rules/*.md` MAY declare a frontmatter `applicable_when:` block using a **closed vocabulary**. Missing block ⇒ `always: true` (back-compat). The closed axes are:

| Axis | Values | Use |
|------|--------|-----|
| `phase` | `[CODESIGN, BLUEPRINT, IMPLEMENT, QA, DEVOPS, SETUP, BACKLOG, AUDIT]` | SDLC phase |
| `scope` | `[frontend-only, backend-only, full-stack, infra]` | Feature scope |
| `change_type` | `[feature, fix, docs, chore, refactor]` | Branch-derived |
| `command` | free list (`[implement, /implement --build]`) | Specific command/sub-command |
| `path_glob` | list of globs (`["**/*.py"]`) | Technical rules tied to file patterns |
| `framework` | free list (`[django, react, fastapi]`) | Stack-conditional rules |
| `always` | `true` | Always applies (mutually exclusive with all other axes) |

Semantics: AND across axes, OR within values of one axis. Defect classes declare applicability per row (`Paths` globs, `Applicable To` agents) in `defect-prevention.md`. The resolver (`scripts/gate.py applicable`) consumes these at command Step 0 and emits the Roll-Call block on-screen, user-facing, as the first message of every command. Validator: `scripts/check-applicability-frontmatter.sh` (CI hard gate).

## Validation contract (for `scripts/check-applicability-frontmatter.sh`)

The validator MUST verify, for every file under `.claude/instructions/**`, `.claude/skills/factory-*/SKILL.md` and `.claude/rules/*.md` (technical + cross-cutting governance; the defect catalog carries applicability per row in its `Paths` column, not in frontmatter blocks):

1. Frontmatter `applicable_when:` block parses as valid YAML.
2. All keys belong to the closed vocabulary: `phase, scope, change_type, command, path_glob, framework, always`.
3. `always: true` is mutually exclusive with any other axis in the same entry.
4. Values for `phase` are subset of `[CODESIGN, BLUEPRINT, IMPLEMENT, QA, DEVOPS, SETUP, BACKLOG, AUDIT]`.
5. Values for `scope` are subset of `[frontend-only, backend-only, full-stack, infra]`.
6. Values for `change_type` are subset of `[feature, fix, docs, chore, refactor]`.
7. `path_glob` values are valid glob syntax.

A missing `applicable_when:` block is **valid** (interpreted as `always: true`) — back-compat during migration. After full backfill (Fase 2 complete), a separate gate may require explicit declaration.
