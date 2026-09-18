---
name: factory-po-intake
description: "Factory PO Intake — receive, validate, ratify and hand over a return produced by a Product Owner who authors CODESIGN outside the repo (PO package, Claude Desktop). Runs the deterministic validator in subproducts/po-package/, drives ONE RDR per proposed change, writes the drop zone, calls /codesign --sync per ratified target, then plans component-catalog work through /backlog. Use when: a PO return zip arrives; when building or rebuilding the outbound package; when reconciling the component registry against the codebase inventory."
applicable_when:
  phase: [CODESIGN, BACKLOG]
  command: [codesign, backlog]
---

# Factory PO Intake

**Principle.** The validator decides whether a return is **reviewable**. Only the user decides whether a change is **accepted**. Never collapse the two. `/codesign --sync` then adopts what was accepted — as written.

Requires `docs/setup.md` `codesign.authoring: external`. Operator-readable twin of this skill: `subproducts/po-package/RUNBOOK.md` (reference it, never duplicate it). The subproduct sits OUTSIDE the governed surface — its only net is `--selftest`, which is why Beat 1 runs it every time.

## Beat 0 — Outbound (build the package)

1. Export the roadmap through `/backlog --status` (adapter; local mode: `docs/backlog/state.md`): features on the board with NO `docs/spec/{ID}/` → `roadmap.json` = `[{"id","name","summary"}]`, written OUTSIDE the repo.
2. `python3 subproducts/po-package/build_po_package.py --roadmap {path}` — cards from code (`design_system.code_cards.dir` set): with a `rebuild_command`, add `--rebuild` (fail-open: a failing tool warns and falls back to vision cards); without one, the tool is run by asking Claude — first ask the user to refresh the cards (or run their design-system-from-code skill into that folder when they ask you to), then build.
3. Read the output. STOP and fix before sending on: empty glossary (no journey could be read) · `WARNING` lines · card count ≠ component count · stale-runbook warning.
4. Optional, user-started, never a gate: `/design-sync` publishes `10-design-system/` to Claude Design (one-way mirror).

## Beat 1 — Validate

```
python3 subproducts/po-package/validate_po_return.py --selftest     # FIRST, ALWAYS
python3 subproducts/po-package/validate_po_return.py --zip {return.zip}
```

- Self-test not green ⇒ STOP. The tooling is broken; judge nothing with it.
- **Exit 2 ⇒ STOP. It is NOT a verdict**: the tool could not do its job (config, repository, its own fault). Fix that, run again. NOTHING goes to the PO.
- RED whose blocking finding is `journey-grammar-infra` (JSON: `returnable_to_po: false`) ⇒ the LOCAL gate is broken: restore `scripts/check-journey-grammar.sh`. Nothing goes to the PO.
- Any other RED ⇒ return the report to the PO **unedited**. NEVER fix the PO's documents to turn red into green: their errors are signal (a translated heading = the instructions did not land).
- GREEN ⇒ reviewable. Not accepted.

## Beat 2 — Read the evolution request BEFORE the artefacts

Per target (`VISION/ERQ.md`, `{ID}/ERQ.md`): `changes[]`, `new_names[]`, `new_components[]`, `open_questions[]`. A change whose `reuse_checked` is empty or generic is the likeliest duplicate — check it yourself against `00-core/domain-glossary.md`, `docs/ux/component-registry.json` and `config/codebase_inventory.json`. Open questions are settled with the user before Beat 3.

## Beat 3 — One RDR per change

- Announce the queue first (N changes across M targets).
- `factory-adversarial-reasoning` pass, then `factory-rdr`: ≥3 options — accept / accept with amendment (the amendment goes BACK to the PO; never edited here) / reject — recommendation + main trade-off, verbatim choice.
- A change a LAW forbids (LAW-16 technical content, scope decided outside the board) is shown as **discarded by rule**, not offered.
- NEVER batch ("all DELTA, applying").
- Classification heuristic: BREAKING = removes or renames a field, makes an optional field required, changes what an existing name means. Everything else is a candidate DELTA. `--sync` re-derives it structurally; a mismatch raises its own RDR.

## Beat 4 — Drop zone, then sync

1. **Eligibility first.** New feature whose CODESIGN item is not eligible on the board ⇒ RDR: park the material in a refinement issue via `/backlog --create-issue` (recommended) / sync now / reject. Arrival is not scheduling. Only an eligible (or explicitly "sync now") target may enter `ratified`.
2. A target with ANY rejected change is NOT syncable ⇒ it never enters `ratified`. RDR: return it to the PO (recommended) / ask the PO to split the ERQ and resubmit the ratified part / abandon the target.
3. Write the drop zone — the ONLY place this skill writes in the repo, left UNCOMMITTED (`--sync` adopts from it, commits the adoption, deletes it):
   - `docs/ux/po-return/VISION/` and/or `docs/ux/po-return/{ID}/` ← the returned files, verbatim.
   - `docs/ux/po-return/INTAKE.md` ← frontmatter `verdict: GREEN`, `based_on_package`, `ratified: [targets]`, `rejected: {target: [change ids]}` (omit a target with none), `synced: []` ; body: per target, one row per change — question, options, recommendation, VERBATIM user choice.
4. Per ratified target, one at a time: `/codesign --sync VISION` · `/codesign --sync {ID}` (it creates or reuses the branch — NEVER `--start` / `--refine`). `--sync` moves the ERQ and the target's RDR rows next to the artefacts (`erq/`), so the decisions outlive the drop zone.
5. `--sync` result `NEEDS_INFO` ⇒ send `{erq_id}.findings.md` (the `for: PO` items) to the PO unedited. The corrected return comes back through Beat 1.

## Beat 4C — Component catalog (after a VISION sync, or on request)

```yaml
reconcile registry ⋈ inventory (type: ui_component):
  registry.cip_name resolves to an IMPLEMENTED artifact  ⇒ status IMPLEMENTED
  inventory ui_component with no registry entry          ⇒ REPORT only (code without design) — never auto-add
  builder drift `candidate-implemented`                  ⇒ propose cip_name + IMPLEMENTED (RDR when the match is not exact)
missing = [c FOR c IN registry.components IF c.status == "DESIGNED" AND c.backlog_ref IS NULL]
IF missing AND registry.catalog_feature IS NULL:
  RDR: foundational Component Catalog feature (recommended) / refinement issues on the consuming features only / defer
  ON foundational: ratify {ID} per project naming → `/backlog --plan-feature {ID} "Component Catalog"` → registry.catalog_feature = {ID}
FOR c IN missing:
  first round  : `/backlog --create-issue "[{ID}] COMPONENT: {c.name}"` — labels phase:implement, scope:frontend-only, kind:component-catalog ; sub-issue of the IMPLEMENT issue (`add_sub_issue`; adapters without it ⇒ `> Parent: #{N}` line)
  later rounds : Refinement Issue `[{ID}] IMPLEMENT-R{k}: Extension — Component {c.name}` (+ enhancement)
  registry: c.backlog_ref = issue ref ; c.status = PLANNED
```

Everything through `/backlog` and the tool-adapter. NEVER call a tracker directly.

## Beat 5 — Close the loop

Rebuild the package (Beat 0) so the PO works on the new state. Give the user a short written account FOR the PO: what went in, what did not and why, what stays open. Carry unresolved `open_questions` forward.

## Boundaries

- Never edits `docs/spec/**` or `docs/ux/vision/**` — that is `--sync`. Never edits PO documents.
- Never decides scope or ordering: a PO recommendation to bring a roadmap feature forward is a board decision, surfaced to the user.
- Never treats `/design-sync` or the optional CI workflow as a gate.
- Registry writes limited to `cip_name`, `status`, `backlog_ref`, `catalog_feature` (writer table: `Factory-codesign-vision.instructions.md` § Component Registry).
