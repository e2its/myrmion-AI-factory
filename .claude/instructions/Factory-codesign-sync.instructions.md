---
description: "Factory CODESIGN sync — adopts a ratified Product Owner return (vision or one feature) verbatim and adds only what the factory owns: gates, frontmatter, iteration ledger, change classification, cascade, approval checks as validation. Never generates, never edits PO content. Use when: CODESIGN --sync execution, or when an authoring sub-command is blocked by the external-authoring guard."
applicable_when:
  phase: [CODESIGN]
  command: [codesign]
---

# CODESIGN — `--sync {VISION|FEATURE_ID}`

Entry point for CODESIGN work authored OUTSIDE the repo (PO package, Claude Desktop). One target per invocation. Operator steps: `subproducts/po-package/RUNBOOK.md`. Upstream skill: `factory-po-intake`.

**Law of this command:** adopt, never author. The PO's bytes land as ONE intact, contiguous block between two factory-owned parts: the header the factory prepends and the iteration appendix the factory appends. Nothing in between is touched. A finding goes BACK to the PO — it is never repaired here. ONE declared exception: slicing (§ Slicing).

## Authoring mode

```yaml
authoring = READ("docs/setup.md").codesign.authoring OR "internal"     # absent key ⇒ internal (back-compat)
package_mode = READ("docs/setup.md").po_package.mode OR "off"
```

| `authoring` | `--sync` | `--start` / `--refine` | `--vision` / `--vision-refine` |
|---|---|---|---|
| `internal` | BLOCK | unchanged | unchanged |
| `external` | this file | guarded | guarded only when `package_mode == "full"` |

State sub-commands (`--vision-approve`, `--vision-propagate`, `--revise`, `--cancel`, `--deprecate`, `--reset`) are never guarded.

### External-authoring guard (IDENTICAL text at the 4 authoring entry points)

```yaml
# EXTERNAL-AUTHORING GUARD (EVOL-052) — runs after Step 0 Roll-Call, BEFORE Step -1 (no branch switch, no lock, no write)
IF READ("docs/setup.md").codesign.authoring == "external":   # vision sub-commands: AND po_package.mode == "full"
  ❌ BLOCK (humanised, LAW-08): "CODESIGN authoring for this project lives in the Product Owner package, not in this command. Send the change to the PO, validate the return, then run `/codesign --sync {target}`. Steps: subproducts/po-package/RUNBOOK.md."
  STOP
```

## Drop zone (written by `factory-po-intake`, transient, UNCOMMITTED until sync)

```
docs/ux/po-return/INTAKE.md          frontmatter: verdict, ratified: [targets], rejected: {target: [change ids]}, synced: [] ; body: one RDR row per change
docs/ux/po-return/VISION/            ERQ.md + the 6 vision artefacts
docs/ux/po-return/{FEATURE_ID}/      ERQ.md, user_journey.md, spec.feature, mock.html (UI scope), slice_map.md (optional)
```

## Factory-owned parts (exact, per artefact)

| Artefact | Header carrier | Header source — VALUES ONLY, drop every template comment | Iteration appendix starts at the first line… |
|---|---|---|---|
| `user_journey.md`, `slice_map.md` | leading `---` YAML block | same-name template under `.context/templates/codesign/` | `## Iteration ITER-` |
| `spec.feature` | leading `---` YAML block | `gherkin_master_template.feature` frontmatter keys | `## Iteration ITER-` |
| `mock.html` | leading `<!-- CO-DESIGN FRONTMATTER … -->` comment, before `<!doctype>` | that comment of `mock-template.html`, plus `scope:`; OMIT any template line that itself contains `<!--` | `<!-- iter:ITER-` |
| `vision.md` | leading `---` YAML block | `{status, version, input_mode: PO_PACKAGE, source_erq}` | — (no ledger) ; the 5 other vision files carry NO header |

Set on every feature header: `feature_id`, `scope ← ERQ.scope`, `status: DRAFT`, `po_sign_off: true`, timestamps. `spec.feature` also: `slicing_strategy ← ERQ.slicing_strategy OR "incremental"`. A header the PO returned is discarded. **PO block** = everything after the header carrier and before the appendix start; the byte-identity guarantee applies to it. Auto-approval CHECK 1 (Gherkin) judges the PO block, not the header.

Iteration entry (canonical schema, factory-iteration-model): `{id, iteration, date, source: rdr-ratification, erq_id: ERQ.erq_id, scope_summary: ERQ.feature_name, changes: ERQ.changes[].id, anchor}` — `source` stays inside its closed enum; the ERQ id rides in `erq_id`. Appendix text is factory prose: keep it free of technical type tokens (the journey gate scans Section 5 → EOF).

## Algorithm

```yaml
FUNCTION codesign_sync(TARGET):
  # 0. Preconditions — BLOCK (humanised) on any miss; never fall through to generation
  REQUIRE authoring == "external"                         ELSE "authoring is internal in this project — use --start / --refine"
  REQUIRE FILE_EXISTS("docs/ux/po-return/INTAKE.md")      ELSE "run factory-po-intake first"
  REQUIRE INTAKE.verdict == "GREEN" AND TARGET IN INTAKE.ratified
          AND (TARGET NOT IN INTAKE.rejected OR INTAKE.rejected[TARGET] == [])
                                                          ELSE "target not fully ratified — see RUNBOOK § 5"
  Step -1 branch protocol (factory-branching-strategy — `CODESIGN --sync` is a CREATION command):
          VISION → feature/UX-VISION-global-app-design ; ID → feature/{ID}-{slug} (slug ← ERQ.feature_name) ; existing branch ⇒ reuse

  IF TARGET == "VISION":
    RUN Scope Guard                                       # Factory-codesign-vision § Scope Guard
    COPY the 6 artefacts docs/ux/po-return/VISION/ → docs/ux/vision/   # IPP: one artefact = one save ; HTML byte-identical, no provenance comment
    PREPEND vision.md header (table above)
    REFRESH docs/ux/component-registry.json               # Factory-codesign-vision § Component Registry — writer rules
    VALIDATE Phase V.7 WCAG + --vision-approve Blocking Validations   # validation ONLY — no Auto-Repair
    never_approved ⇒ status DRAFT ; else tell the user: --vision-approve, then --vision-propagate

  ELSE:
    first_adoption = NOT DIR_EXISTS("docs/spec/{TARGET}/")
    never_approved = first_adoption OR (no artefact of TARGET ever reached APPROVED AND NOT FILE_EXISTS("docs/spec/{TARGET}/design.md"))

    IF first_adoption:                                     # what --start guards, minus generation
      CALL scope_compatibility_gate(TARGET, ERQ.scope)     # Factory-codesign-feature
      RUN Vision Gate — its BLOCK half only (vision APPROVED for UI scopes). Shell composition is authoring: skipped.
    RUN CIP concept check (Phase 0.5 / cip_refine_recheck matching rules) with
        concepts ← ERQ.new_names[kind == concept] + journey § 6 `###` headings
        overlap ⇒ RDR: REUSE_EXISTING / KEEP_BOTH / RETURN_TO_PO        # RENAME_NEW and MERGE would edit PO content ⇒ they are RETURN_TO_PO here
    IF NOT never_approved:                                 # what --refine guards, minus generation
      RUN Iteration Execution 1.1 (implementation-state probe)
      level1 = Change Classification Protocol Level 1 on the PO-block diff        # DELTA | BREAKING_CANDIDATE | BREAKING
      IF level1 == BREAKING_CANDIDATE: level1 = Level 2 (Cross-Reference Downstream)
      IF lower(level1) != ERQ.classification: RDR (≥3 options) — the structural result is the default recommendation

    WRITE each artefact = header + PO block (verbatim from the drop zone) + existing appendix (if any)
    CALL append_iteration_entry(artefact, entry)  per artefact, ONE shared id ITER-{TARGET}-{N+1} (first adoption ⇒ N+1 = 1)
    § Slicing
    IF NOT never_approved:
      IF slice_map.md changed: CALL check_slice_immutability(TARGET, proposed) PRE-persist      # factory-iteration-model
      CALL CASCADE_PENDING_ITERATION(...) ; CALL CASCADE_SLICE_INTERNAL(...) when re-sliced

    # Validation — same bar as internal authoring, zero generation
    RUN Tripartite Alignment Protocol ; CALL codesign_auto_approve(TARGET)      # CHECK 0–14 ; all green ⇒ it sets APPROVED
    # Reused functions speak of re-running --start / --refine: under --sync read that as "return to the PO, then --sync again"

  # Records — always, whatever the outcome
  MOVE ERQ.md → docs/spec/{TARGET}/erq/{erq_id}.md  (VISION: docs/ux/vision/erq/)      # the WHY survives the drop zone
  WRITE {erq_id}.intake.md next to it ← TARGET's RDR rows from INTAKE.md (verbatim user choices)
  IF any finding:
    status ← NEEDS_INFO on every adopted artefact of TARGET
    WRITE {erq_id}.findings.md next to it — plain language, per artefact, each finding tagged `for: PO` or `for: factory`
    NEVER edit the PO block. The next return re-enters through never_approved ⇒ no classification, no cascade.
  REMOVE docs/ux/po-return/{TARGET}/ ; INTAKE.synced += TARGET ; remove INTAKE.md when every ratified target is synced
  STAGE adoption + records + removal together ⇒ ONE commit (factory-commit-prompt)
  APPEND_TO_WORKLOG {action: "--sync", target, erq_id, ratified_changes, result}
```

## Slicing — the one declared exception to "never author"

`slice_map.md` returned ⇒ adopt like any artefact. Absent AND `slicing_strategy == incremental` ⇒ RUN "Slice Map Generation" (Factory-codesign-feature Execution Flow step 9.5) with ITS RDR: the factory proposes, the user ratifies, `rdr_*` fields record it. Absent AND `monolithic` ⇒ nothing (the Trivial-Heuristic is enforced later by BLUEPRINT). Never silently skipped, never generated without the RDR.

## Forbidden

- Generating or rewording any journey step, scenario, mock markup, token or component.
- WCAG Auto-Repair, Tripartite auto-fix, placeholder filling, shell composition — every one is authoring.
- Syncing a target with a rejected change. The skill returns or splits it first.
- Deciding board eligibility. `factory-po-intake` Beat 4 settles it BEFORE a target reaches `INTAKE.ratified`; sync trusts that list.
- Writing design-system card markers. Cards are the package builder's output.
