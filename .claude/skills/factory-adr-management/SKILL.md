---
name: factory-adr-management
description: "Factory ADR Management Skill — canonical algorithm for proposing, ratifying, and querying Architectural Decision Records and Feature Decision Records. Mechanically writes the ADR's Operational Rule into the constitution INDEX (one `[PLAW-NN]` sentence + body pointer + records) and its body into the pointed rule file at status flip; FDRs stay feature-local. Use when: any agent or free-form turn proposes an architectural decision (BLUEPRINT design, AUDIT mitigation, IMPLEMENT discovery, CODESIGN vision deviation, DEVOPS infra choice, BACKLOG retrospective DC promotion, ad-hoc 'this deserves an ADR'); when ratifying a proposed ADR/FDR after RDR with the user; when downstream consumers (BLUEPRINT § 7.8, IMPLEMENT Review Check #14) need a list of active records."
applicable_when:
  always: true
---

# FACTORY ADR MANAGEMENT (FAM)

> **Shared Protocol** — Referenced by: BLUEPRINT (`--start`, `--refine`), AUDIT (`--audit`), IMPLEMENT (`--build` discovery, `--fix` classification), CODESIGN (`--vision-deviation`), DEVOPS (`--configure`), BACKLOG (RETROSPECTIVE), and any free-form turn that needs to formalise an architectural decision.
> Single source of truth for ADR/FDR lifecycle, file format, amendment ceremony, and downstream query API. Every inline reference to ADR/FDR creation or acceptance across commands / instructions / templates must conform to this protocol.

**Core Principle:** Active operational law is INDEXED in `docs/constitution.md` — per project law one `## [PLAW-NN] Title`, one `> sentence`, one `Body:` pointer into `.claude/rules/`, its `Records:` — and detailed in exactly ONE body (EVOL-043). ADRs are historical records of why a sentence changed. The Accept Procedure mechanically writes the ADR's `## Operational Rule` sentence into the index and its `### Body` into the pointed rule file — no agent judgement, no manual editing, no second source of truth. A body-only change needs no ADR (rule-file edit + manifest bump). FDRs are feature-local binding records that never escalate to constitution.

---

## Three record types

| Type | Path | Amends constitution? | Lifecycle | Loaded into governance snapshot? |
|---|---|---|---|---|
| **ADR** (Architectural Decision Record) | `docs/project_log/adr/ADR-{N}-{slug}.md` | YES (mandatory at accept) | proposed → accepted | NO (the resulting `[PLAW-NN]` index entry is loaded; the ADR itself is historical) |
| **FDR** (Feature Decision Record) | `docs/spec/{FEAT-ID}/fdr/FDR-{N}-{slug}.md` | NO (feature-local only) | proposed → accepted | NO (read directly by BLUEPRINT § 7.8 when working the owning feature) |
| **DIVERGENCE** (Divergence Record) | `docs/project_log/adr/ADR-{N}-{slug}.md` | NO (records intent, no index entry added or modified) | accepted (single state — divergences are declarative) | NO (the ADR is the historical record; future readers consult it before "fixing" the documented divergence) |

Choosing between record types is the agent's first responsibility when invoking this skill — see § Decision: record_type. **DIVERGENCE records use the ADR file path and numbering** (they are a sub-flavour of ADR with `record_type: DIVERGENCE` in the call) but skip Accept Procedure (no constitution amendment). They satisfy `operational_rule` with a single explanatory line ("DIVERGENCE record — see § Decision body") and `target_section: none`, `amendment_kind: none`. The validator skips the constitution-section verification when `record_type == DIVERGENCE`.

---

## Procedures

### Propose Procedure

Creates a new record in `status: proposed`. Triggered by any agent or free-form turn that has a decision to formalise.

**Inputs:**

- `record_type: ADR | FDR | DIVERGENCE`
- `feature_id: string | null` — required for FDR; null for project-wide ADR / DIVERGENCE.
- `title: string` — operational title, will become heading + slug.
- `context: string` — what problem motivated this decision.
- `decision: string` — what was decided, with rationale.
- `alternatives: list of {name, rationale}` — minimum 2 (required by RDR).
- `consequences: {positives: list, negatives: list}`.
- `operational_rule: string` — for ADR: the normative SENTENCE (one line, within `budgets.law_sentence_max_chars`, no file paths, no threshold digits) that becomes the `> sentence` of the index entry at accept; the ADR's `### Body` (optional, under `## Operational Rule`) is the detail written to the body home. For FDR: the binding rule that applies within the feature scope. For DIVERGENCE: a single explanatory line stating that the ADR is a divergence record and points to its `## Decision` body. **MUST NOT be empty.** Plain operational text only — no rationale, no alternatives, no commentary.
- `target_section: string` — ADR only (mandatory). `[PLAW-NN]` to amend an existing law, or `NEW: {Title}` to mint the next `PLAW-NN`. For DIVERGENCE: `none`. Never mint a `LAW-NN` id in a project (reserved framework corpus).
- `body_home: string` — ADR `ADD` (mandatory) / `REPLACE` (optional, defaults to the entry's current pointer): the rule file that hosts the body, as `rules/{file}.md` (resolved against `.claude/rules/`). Created with sibling frontmatter when absent.
- `amendment_kind: ADD | REPLACE | REMOVE | NONE` — ADR. `NONE` is reserved for `record_type: DIVERGENCE`.

**Steps:**

1. **Resolve number.** `N = max(existing_numbers) + 1` per scope (ADR + DIVERGENCE scope = `docs/project_log/adr/`; FDR scope = `docs/spec/{FEAT-ID}/fdr/`). Format as zero-padded — width matches local convention (detect max width of existing files in scope; fallback 4-digit if scope is empty): e.g. `ADR-0030`, `FDR-014`.
2. **Validate inputs.**
   - `operational_rule` non-empty (whitespace-only fails).
   - For ADR: `target_section` non-empty AND `amendment_kind` ∈ {ADD, REPLACE, REMOVE}.
   - For ADR with `amendment_kind: REPLACE | REMOVE`: `target_section` is an existing `[PLAW-NN]` of `docs/constitution.md` (verified by `python3 scripts/gate.py laws --json`).
   - For ADR with `amendment_kind: ADD`: `target_section` is `NEW: {Title}`, no existing entry carries that title, `body_home` names a rule file.
   - For FDR: `feature_id` matches an existing feature directory.
   - For DIVERGENCE: `target_section == "none"` AND `amendment_kind == "NONE"`. Constitution section verification SKIPPED.
   - Fail with humanised message if any check fails — never write the record on validation error.
3. **Resolve template.** Read `.context/templates/architect/adr_template.md` (for ADR) or `fdr_template.md` (for FDR). Substitute placeholders with provided inputs.
4. **Write file.** Atomic write to the resolved path. `## Constitution Amendment` section stays empty (placeholder text untouched) for ADRs; FDRs do not have this section.
5. **Append worklog entry.** Worklog event: `record_proposed` with `{record_type, number, feature_id, target_section}`.
6. **Return.** `{path, number, status: proposed}` to the caller.

**Failure modes:**

- Number collision (concurrent proposal in same scope) → retry with `N+1` once, then fail.
- Target section verification fails → return error `target_section_not_found` with the section the caller named; caller must escalate to user (typically via RDR with corrected sections).
- Template missing → fatal; SETUP --upgrade required.

### Accept Procedure

Flips a proposed record to `accepted`. For ADRs, mechanically amends `docs/constitution.md` in the same atomic step. For FDRs, just flips the status.

**Inputs:**

- `path: string` — path to the proposed ADR or FDR file.

**Preconditions:**

- File exists and parses as a valid record (frontmatter present, all required fields populated).
- `status: proposed` — accepting a record already in `accepted` is a no-op with a warning.
- For ADR: a Recommendation → Decision → Ratification ceremony with the user must have completed for THIS ADR's content (the caller is responsible for running RDR before invoking Accept; the skill verifies traceability via the ADR's `## Decision` section narrative but does not re-run RDR).

**Steps (ADR):**

1. **Read frontmatter.** `target_section`, `amendment_kind`, `title`, `adr_number`, `body_home`.
2. **Read `## Operational Rule`.** The first non-empty paragraph is the SENTENCE (one line; re-validate non-empty and within `budgets.law_sentence_max_chars`). The `### Body` sub-section, when present, is the body text (verbatim, placeholders allowed).
3. **Capture `before`.** From `python3 scripts/gate.py laws --json` (`.project[]`): the target entry (`sentence`, `body`, `records`) and, when the body changes, the current body section of the pointed file (`## [PLAW-NN] …` heading + `> sentence` + text up to the next `## `).
4. **Apply edit — index (`docs/constitution.md`):**
   - `ADD` → `id = PLAW-{max+1:02d}`; append `\n## [{id}] {title}\n> {sentence}\nBody: \`{body_home}\` · Records: \`ADR-{N}\`\n`.
   - `REPLACE` → replace the `> sentence` line of the target entry; append `ADR-{N}` to its `Records:`; when `body_home` is given, replace the `Body:` pointer.
   - `REMOVE` → delete the three-line entry.
5. **Apply edit — body home (`.claude/rules/{file}.md`):**
   - `ADD` → append `\n## [{id}] {title}\n> {sentence}\n\n{body}\n` (create the file with sibling frontmatter when absent).
   - `REPLACE` → replace the `> sentence` line under the `## [{id}]` heading (the quote must equal the index sentence — the parity gate reads both); replace the section text when a `### Body` was given.
   - `REMOVE` → delete the `## [{id}]` section.
6. **Write `## Constitution Amendment` section** in the ADR with the before/after of the entry (and of the body when it changed).
7. **Flip frontmatter** `status: proposed` → `accepted`. Set `accepted_at: ISO_8601`.
8. **Bump the governance manifest** entries: `docs/constitution.md` (MINOR, or MAJOR when the caller signals a breaking flip), the body home rule file (MINOR), the ADR at `1.0.0`; changelog line `"{new_version}: ADR-{N} {amendment_kind} {target_section} — {title}"`.
9. **Regenerate the snapshot:** `bash scripts/generate-governance-snapshot.sh` (the index changed).
10. **Append worklog entry.** `adr_accepted` with `{number, target_section, amendment_kind, body_home}`.
11. **Emit commit-message suggestion** at `.claude/state/commit-message-suggestion.md`:
    ```
    feat(governance): ADR-{N} {amendment_kind} {target_section} — {title}

    Index entry in docs/constitution.md and body in {body_home} per ADR-{N} Operational Rule.
    ```
    `scripts/check-adr-constitution-sync.sh` passes in both directions: the ADR flips to accepted with the constitution in the diff, and the sentence change carries its accepted ADR.
12. **Return.** `{path, status: accepted, constitution_diff: {target_section, amendment_kind, before, after}, body_home, version_bumps: {...}}` to the caller.

**Steps (FDR):**

1. Read frontmatter; validate `status: proposed`, `feature_id` matches owning directory.
2. Flip `status: proposed → accepted`. Set `accepted_at: ISO_8601`.
3. Append worklog entry: `fdr_accepted` with `{number, feature_id}`.
4. Bump `governance_versions.json` entry for the FDR file (`1.0.0`).
5. Return `{path, status: accepted}`.

**Failure modes:**

- ADR with `target_section` no longer present in the index (e.g., another ADR removed it concurrently) → fail; caller must re-propose with updated target.
- ADR amendment produces malformed constitution (e.g., regex extraction would no longer return a contiguous block) → fail; rollback constitution edit; do NOT flip status.
- Constitution write fails mid-edit → rollback via the `before` snapshot; do NOT flip status; surface error to caller.

### List Active ADRs API

Read-only query consumed by BLUEPRINT § 7.8, IMPLEMENT Review Check #14, AUDIT cross-reference, and any agent that needs historical traceability.

**Inputs:**

- `feature_id: string | null` — null returns project-wide ADRs only; non-null returns FDRs of that feature plus all project-wide ADRs.
- `since_date: ISO_8601 | null` — optional filter; returns records accepted on or after this date.
- `target_section: string | null` — optional filter; returns ADRs whose frontmatter `target_section` matches.

**Output:**

List of records, each with:

```yaml
- record_type: ADR | FDR
  number: 003
  title: "Use BaseRepository pattern for all data access"
  path: "docs/project_log/adr/ADR-003-baserepository.md"
  status: accepted
  accepted_at: "2026-04-15T10:30:00Z"
  feature_id: null  # or FEAT-024
  target_section: "[PLAW-04]"  # ADR only — an existing law id, or "NEW: {Title}" at propose time
  amendment_kind: ADD  # ADR only
  operational_rule_summary: "{first 200 chars of Operational Rule, single line}"
```

The API is deterministic (sorted by accepted_at descending) and idempotent. Consumers must NOT use this API as a source of operational law — that lives in constitution. Use it only for traceability ("why is this `[PLAW-NN]` sentence worded this way?") and historical queries.

---

## Decision: ADR vs FDR

The first responsibility when invoking this skill is to decide the record type. Use this matrix:

| Trigger | Likely type | Why |
|---|---|---|
| Architectural pattern that applies project-wide (e.g., "all data access via BaseRepository") | ADR | Universal law; belongs in constitution. |
| Cross-cutting infra decision (e.g., "use Postgres connection pooling everywhere") | ADR | Universal. |
| Security baseline addition (e.g., "all endpoints require JWT validation") | ADR | Universal. |
| Feature-local invariant (e.g., "FEAT-024 uses event sourcing for audit log") | FDR | Local to feature; would pollute constitution if globalised. |
| Feature-local pattern overriding default (e.g., "FEAT-024 uses Redis instead of project default cache") | FDR | Local. If the override should apply everywhere, escalate to ADR. |
| Audit mitigation that codifies a project-wide rule | ADR | Universal. |
| Audit finding scoped to a feature implementation | FDR | Local. |
| Retrospective promotion of a recurring DC to architectural rule | ADR | Promoting to law is a project-wide act. |
| Deviation from product vision affecting product strategy | ADR | Universal product law. |
| Feature-specific UX or behaviour decision | FDR | Local. |

When ambiguous, default to FDR. Promotion FDR → ADR is an additive operation (a new ADR amends constitution, the FDR stays as historical feature record); promotion ADR → FDR is rare and treated as constitutional removal + new FDR.

---

## Invocation patterns

### From BLUEPRINT --start (architectural decision during design)

```yaml
WHEN BLUEPRINT detects a design decision needing formalisation:
  → run RDR with user (factory-rdr/SKILL.md) → user picks decision
  → invoke factory-adr-management Propose Procedure with operational_rule = decision text
  → continue design with new ADR/FDR as feature-relevant context
  → at BLUEPRINT --approve, invoke Accept Procedure on the proposed record
```

### From AUDIT --audit (mitigation that should become law)

```yaml
WHEN AUDIT identifies a mitigation that codifies a missing project-wide rule:
  → record finding in audit report
  → run RDR with user on whether to formalise as ADR
  → if yes: invoke Propose Procedure with target_section = constitution section the rule belongs to
  → defer Accept Procedure until user explicitly ratifies (typically a follow-up PR)
```

### From IMPLEMENT --build (TDD-time discovery)

```yaml
WHEN DEV hat discovers an invariant during TDD that should be codified:
  → block the build with a [DC-DISCOVERY] entry per factory-build-verification
  → run RDR with user on (a) treat as DC for catalog promotion, (b) escalate to FDR for this feature, (c) escalate to ADR for project-wide
  → invoke Propose Procedure with the chosen scope
```

### From BACKLOG RETROSPECTIVE (DC promotion)

```yaml
WHEN [EPIC-N] RETROSPECTIVE closes and a DC has been triggered N≥3 times across features:
  → run RDR with user on whether to promote DC to ADR (constitution amendment)
  → if yes: invoke Propose Procedure with operational_rule = the prevention rule, target_section = the `[PLAW-NN]` it sharpens (or `NEW: …`)
```

### From free-form turn

```yaml
USER: "esto merece un ADR — todos los servicios deben emitir trace IDs en cada request"
AGENT:
  → confirm scope with one-line reflection ("project-wide → ADR amending [PLAW-06] Security by Design")
  → run RDR with user on the exact operational rule wording
  → invoke Propose Procedure
  → ask user when to invoke Accept Procedure (now or after PR review)
```

---

## CI integration

The CI gate `scripts/check-adr-constitution-sync.sh` runs at PR-time and enforces:

- Any commit in the PR diff that flips an ADR file's `status` from `proposed` to `accepted` MUST also include changes to `docs/constitution.md` in the same diff.
- Bypass: commit message containing `[adr-backfill]` (one-shot historical migration of pre-existing ADRs).
- FDRs are not subject to this gate (they do not amend constitution).

The Accept Procedure produces a single coherent commit (constitution amendment + ADR status flip + governance_versions.json bump + ADR Constitution Amendment section), so PRs that use the procedure pass the gate by construction. Manual ADR edits that try to flip status without using the procedure will fail the gate.

---

## What the skill does NOT do

- Run RDR with the user. RDR is a separate protocol (`factory-rdr/SKILL.md`) and is the caller's responsibility. This skill assumes the decision is already user-ratified before Accept is invoked.
- Validate the operational text quality. Whether the rule is well-worded, complete, or actionable is the author's responsibility (or the caller's RDR ceremony).
- Resolve conflicts between concurrent ADRs targeting the same section. If two ADRs are proposed simultaneously for the same `target_section`, the second Accept will fail with `target_section_already_modified` and the caller must escalate to user.
- Migrate legacy feature-scoped ADRs at `docs/spec/{ID}/adr/` to `docs/spec/{ID}/fdr/`. That is a one-shot SETUP --upgrade concern, not a runtime concern.

---

## Versioning of this skill

- `1.0.0` — Initial release.

Future evolutions of FAM extend the procedures or add new ones (e.g., `Supersede Procedure` to handle ADR → ADR replacement chains). All breaking changes to procedure signatures or output schemas require MAJOR bump.
