# EVOL-040 — Global CVP Remediation (validator + delivery channel + CLAUDE.md pair)

Branch: `feature/EVOL-040-cvp-remediation`. Status: **DRAFT — design in plan mode**.

North star (user directive, persistent): every decision optimises for SETUP instantiation being perfect, reliable and secure. Definitive verification = synthetic materialization, not meta validators alone.

## 1. Origin

Global CVP analysis @ main ce4b818 (3 read-only sweeps: manifest↔disk full, reference integrity, meta↔product seam). Result: 11 CRITICAL + 15 WARNING + 14 note. CI-enforced surface 100% clean; ALL incoherence lives in the manually-disciplined surface. Three systemic root causes: (A) manifest validator sees 5/8 governed trees + extension filter blind spots + diff-scoped only; (B) two delivery channels with no shared manifest (factory-sync hardcoded list vs SETUP template auto-scan) — scripts invoked by materialized CI that SETUP never delivers; (C) CLAUDE.md meta↔template pair has only 3 H2 sections under mechanical verification — accumulated drift produced one ordinal (7) carrying two different laws.

Scope ratified by user: **one PR, everything** — 37 findings fixed, 3 discarded as non-defects (historical doc, intentional notation, runtime artifact) with justification in ADR-EVOL-040. Full disposition table to be carried in the ADR.

## 2. Decision log (RDR)

### RDR-1 — LAW identity scheme

**Ratified: Option A — stable non-ordinal LAW-NN IDs, single namespace across the pair.**

Verbatim user choice: `confirmado` (after scope clarification "¿framework o meta?" → both, single namespace; decisive argument: shipped skills are ONE artifact running in BOTH contexts — a shared artifact cannot reference context-dependent ordinals; today "LAW 12" = lock-step in meta, code-review in a project).

Semantics: LAW-NN assigned once, never renumbered, never reused. Universal law ⇒ same ID in both CLAUDE.md files; context-specific law ⇒ ID exists once, listed only where it applies. Markdown list ordinals become cosmetic; all references (skills, instructions, manifest) cite LAW-NN. Precedent: DC-28/DC-29 stable IDs solved the same problem. Out of scope: project-minted laws via their own ADR ceremony (project namespace; anti-collision convention fixed in design). Migration cost verified LOW: ordinal refs live in only 2 files.

Options presented: A stable IDs (chosen) / B shared renumbering with context blocks M*/P* / C per-context ordinals + mapping table (fragility remains, every future ref needs context qualifier).

### RDR-2 — security-scan.sh (0 bytes since initial commit, 4 real consumers)

**Ratified: Option A-refined — tool-agnostic dispatcher materialized from SETUP decisions.**

Verbatim user choice: `confirmado` (after user refinement: "tiene que materializarse en función de las decisiones del setup durante setup materialize").

Design (LAW 11 / EVOL-033 pattern — process in framework, tool in project): new SETUP discovery RDR (scanner: gitleaks default / trufflehog / custom / Skip) → `config/quality.json.security_scan` block with `{{SECURITY_SCANNER}}` placeholders resolved at materialization (Skip ⇒ enabled:false, file still materialized) → script = dispatcher only (reads config, resolves command, normalizes `{severity,file,line,rule}`, verdict per `fail_on`, exit 0/1/2), never names tools outside the resolution table → single source at `.context/templates/setup/scripts/security-scan.sh` (materialization auto-scan delivers it; meta copy aligned via unified channel) → **two-layer security**: always-on fail-closed floor (detect_change_type secrets regex, Block 3) + fail-open-NOISY scanner layer (mandatory 🔒 banner when scanner unavailable) → pre-push hook's inline gitleaks delegates to the dispatcher (one scanning path, DC-29).

Options presented: A implement minimal (chosen, then refined to materialization-driven) / B remove file + rewrite 4 refs (cuts specified capability) / C explicit stub (formalizes the smoke).

## 3. Design

TBD — plan mode.

## 4. Disposition table (40 findings)

TBD — carried in ADR-EVOL-040; summary here after design.

## 5. Verification

TBD — must include synthetic materialization test (T3 class): scratch `SETUP --generate`, assert materialized CI references only existing files, rules resolve, gates active.
