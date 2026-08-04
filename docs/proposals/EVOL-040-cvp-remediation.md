# EVOL-040 — Global CVP Remediation (validator + delivery channel + CLAUDE.md pair)

Branch: `feature/EVOL-040-cvp-remediation`. Status: **FINAL — implemented**.

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

## 3. Design (as shipped — 6 commits)

- **K1 weld** — `validate-governance.sh` 2.0.0: TRACKED_DIRS ×10, full-tree CHECK 2 via `git ls-files` (extension + diff-scoping blind spots die), 3-section TRACKED_PATHS/vmap, NEW CHECK 1c (dup paths/targets, missing target keys). 26 new manifest entries in the SAME commit (the weld). Duplicate workflow keys merged, Bitbucket `target_mode: merge`, `delivery` field introduced, changelog hygiene, `$schema` v2. governance-check.yml paths filter deleted.
- **K2 delivery channel** — factory-sync 1.9.0: hardcoded list → manifest query over `delivery`; `__pycache__` prune. 3 CI-invoked scripts template-ized + lockstep pairs. Materialization: constitution path fix, `coherence-context.json` materialised, delivery-closure Invariant. Phantom refs removed; downstream coherence-context globs fixed.
- **K3 LAW-NN corpus** — both CLAUDE.md re-rendered `N. **[LAW-NN] Title**`; LAW-07 meta / LAW-14 project (ordinal-7 collision dies); LAW-13 both (EVOL-039 offset dies); LAW-08 template-wins; LAW-15 = ADP. NEW `law_corpus_mirror` pair type + 8 self-test cases. § What Lives Where rewritten; declared-divergence doctrine; PLAW-NN project namespace. ADR-EVOL-040 accepted (constitutional amendment = the restructure).
- **K4 dispatcher (RDR-2)** — template security-scan.sh 3.0.0 (tool flags die; `--secrets` config-driven lane; 🔒 fail-open-noisy / findings fail-closed / `--require-scanner`); meta 0-byte dies; Q23.2 discovery + TIER_2 backfill; quality.json ×2 (template placeholders + meta concrete gitleaks); pre-push delegates (inline gitleaks removed).
- **K5 T3** — `test-materialization-surface.sh` (5 assertion groups over the agnostic delivery surface), negative-tested, in the T2 CI loop.
- **K6 close** — this doc, framework_version 5.9.0.

## 4. Disposition table (40 findings)

Carried in full in `docs/project_log/evolutions/ADR-EVOL-040.md` (40 rows): **37 FIXED** (K1 ×15, K2 ×9, K3 ×11, K4 ×1, K6 ×1) · **3 DISCARDED with reason** (immutable historical ADR mention; algorithm-local rule numbering; intentional schematic notation).

## 5. Verification (executed)

Full local CI parity green at every commit (validate-governance hardened, lockstep 10 pairs incl. law corpus, ADR-sync, applicability, T2+L6+T3 suites). Dispatcher matrix 6/6 (clean/not-installed/require-scanner/disabled/unconfigured/planted-secret). factory-sync synthetic run: emitted list == old ∪ nothing-lost, 0 `.pyc`. law_corpus_mirror negative-tested live (planted LAW-05 drift caught with diff). T3 negative-tested (detects pre-K2 state). CHECK 1b caught its own author's bump error during K4 (constitution_template 3.1.0 under a 3.2.0 base) — the weld working. Block 20 dogfood + /pr-review loop to 0/0/0 before push.
