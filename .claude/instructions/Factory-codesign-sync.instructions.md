---
description: "Factory CODESIGN sync — adopts a ratified Product Owner return (vision or one feature) verbatim and adds only what the factory owns: gates, frontmatter, iteration ledger, change classification, cascade, approval checks as validation. Never generates, never edits PO content. Use when: CODESIGN --sync execution, or when an authoring sub-command is blocked by the external-authoring guard."
applicable_when:
  phase: [CODESIGN]
  command: [codesign]
---

# CODESIGN — `--sync {VISION|FEATURE_ID}`

Entry point for CODESIGN work authored OUTSIDE the repo (PO package, Claude Desktop). One target per invocation. Operator steps: `subproducts/po-package/RUNBOOK.md`. Upstream skill: `factory-po-intake`.

**Law of this command:** adopt, never author. What the PO wrote lands byte-for-byte. The factory adds the parts the PO never writes. A finding goes BACK to the PO — it is never repaired here.

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
# EXTERNAL-AUTHORING GUARD (EVOL-052) — runs first, before any gate or generation
IF READ("docs/setup.md").codesign.authoring == "external":   # vision sub-commands: AND po_package.mode == "full"
  ❌ BLOCK (humanised, LAW-08): "CODESIGN authoring for this project lives in the Product Owner package, not in this command. Send the change to the PO, validate the return, then run `/codesign --sync {target}`. Steps: subproducts/po-package/RUNBOOK.md."
  STOP
```

## Drop zone (written by `factory-po-intake`, transient)

```
docs/ux/po-return/INTAKE.md          verdict, ratified targets, rejected changes, one RDR per change
docs/ux/po-return/VISION/            ERQ.md + the 6 vision artefacts
docs/ux/po-return/{FEATURE_ID}/      ERQ.md, user_journey.md, spec.feature, mock.html (UI scope), slice_map.md (optional)
```

## Algorithm

```yaml
FUNCTION codesign_sync(TARGET):
  # 0. Preconditions — BLOCK (humanised) on any miss; never fall through to generation
  REQUIRE authoring == "external"                         ELSE "authoring is internal in this project — use --start / --refine"
  REQUIRE FILE_EXISTS("docs/ux/po-return/INTAKE.md")      ELSE "run factory-po-intake first"
  REQUIRE INTAKE.verdict == "GREEN" AND TARGET IN INTAKE.ratified AND INTAKE.rejected[TARGET] == []
                                                          ELSE "target not fully ratified — see RUNBOOK § 5"
  Step -1 branch protocol (factory-branching-strategy): VISION → feature/UX-VISION-global-app-design ; ID → feature/{ID}-{slug}

  IF TARGET == "VISION":
    RUN Scope Guard                         # Factory-codesign-vision § Scope Guard
    FOR f IN the 6 vision artefacts:        # IPP: one artefact = one save
      COPY docs/ux/po-return/VISION/{f} → docs/ux/vision/{f}      # verbatim
    vision.md frontmatter ← {status: DRAFT, input_mode: PO_PACKAGE, source_erq: ERQ.erq_id}   # PREPEND only
    HTML artefacts stay byte-identical — provenance lives in vision.md frontmatter + worklog, never in a comment
    REFRESH docs/ux/component-registry.json # Factory-codesign-vision § Component Registry — writer rules apply
    VALIDATE Phase V.7 WCAG                 # validation ONLY — no Auto-Repair
    IF vision was APPROVED before: tell the user to run --vision-approve then --vision-propagate

  ELIF NOT DIR_EXISTS("docs/spec/{TARGET}/"):              # new feature — what --start guards, minus generation
    CALL scope_compatibility_gate(TARGET, ERQ.scope)       # Factory-codesign-feature
    RUN Vision Gate                                        # Factory-codesign-feature § Vision Gate
    RUN Phase 0.5: CIP Domain Concept Check                # RDR per overlap: REUSE_EXISTING / RENAME_NEW / MERGE / KEEP_BOTH
    COPY each returned artefact verbatim → docs/spec/{TARGET}/
    PREPEND frontmatter from .context/templates/codesign/* (scope ← ERQ.scope, status: DRAFT)
    CALL append_iteration_entry(artifact, {id: "ITER-{TARGET}-1", source: ERQ.erq_id})       # factory-incremental-persistence
    slice_map.md: returned ⇒ adopt ; absent AND slicing_strategy == incremental ⇒ RUN "Slice Map Generation" (Execution Flow step 9.5, its RDR)

  ELSE:                                                    # existing feature — what --refine guards, minus generation
    RUN Iteration Execution 1.1 (implementation-state probe)
    CALL cip_refine_recheck(TARGET, diff)                  # only when new concepts appear
    RUN Change Classification Protocol Level 1 (structural, deterministic) on the diff
      IF result != ERQ.classification: RDR (≥3 options) — the structural result is the default recommendation
    REPLACE body of each artefact ; PRESERVE factory frontmatter + iteration appendix
    IF slice_map.md changed: CALL check_slice_immutability(TARGET, proposed) PRE-persist      # factory-iteration-model
    CALL append_iteration_entry(...) with ONE shared id ITER-{TARGET}-{N+1}, source: ERQ.erq_id
    CALL CASCADE_PENDING_ITERATION(...) ; CALL CASCADE_SLICE_INTERNAL(...) when re-sliced     # factory-iteration-model

  # Validation — same bar as internal authoring, zero generation
  IF TARGET != "VISION":
    RUN Tripartite Alignment Protocol ; CALL codesign_auto_approve(TARGET)    # CHECK 0–14
  IF any finding:
    status ← NEEDS_INFO ; REPORT findings for the PO (plain language, per artefact) ; NEVER edit PO content
  DELETE docs/ux/po-return/{TARGET}/ in the SAME commit ; INTAKE.md: mark TARGET synced (delete INTAKE.md when no target is left)
  APPEND_TO_WORKLOG {action: "--sync", target, erq_id, ratified_changes, result}
```

## Forbidden

- Generating or rewording any journey step, scenario, mock markup, token or component.
- WCAG Auto-Repair, Tripartite auto-fix, placeholder filling — every one is authoring.
- Syncing a partially ratified target. The skill splits or returns it first.
- `--start` because material arrived. Board eligibility decides (BACKLOG); ineligible ⇒ park via `/backlog --create-issue`.
- Writing design-system card markers. Cards are the package builder's output.
