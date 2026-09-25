---
id: ADR-EVOL-044
title: Coherence gates — body vs sentence, artefact currency, manifest vs frontmatter
date: 2026-09-25
status: accepted
---

# ADR-EVOL-044: Coherence gates

## Context

Issue #53, axis H of the 2026-09 evolution (#50). Layering the corpus (EVOL-043) created two new ways to lie: a rule body that contradicts its own normative sentence, and a verdict artefact that still certifies a build that moved under it. A third, cheaper one was measured on this repository before design: 20 governed files carried a frontmatter `version` different from their manifest entry, and two frontmatters were not even valid YAML (a duplicate `date` key, an unquoted description) — so the manifest had stopped being the source of truth for what changed. Decision authority delegated by the user on 2026-09-25.

## Decision

Agent-internal choices (pick + surviving risk):

- **Body ↔ sentence parity is the one reader's `parity()`** (shipped in EVOL-043 as `gate.py laws --parity`): every law's pointer resolves, the body heading exists, the quoted sentence is byte-identical, exactly one body per law, no orphan body. This axis wires it where the work happens (pre-push step 4) and in every CI (meta + template workflow) and the synthetic smoke. Rejected: a semantic "does the body contradict the sentence" judgement — not deterministic; the byte-identical quote is the mechanical proxy the issue asked for.
- **Artefact currency by declaration.** A verdict artefact (QA report, peer review, security audit, smoke report) declares in frontmatter what it certified — `certifies: {subject: diff|tree, base|paths, hash}` — and the gate recomputes the hash **with the function the writer used** (`gate.py certify`): `diff` = the factory-code-review content hash over `base..HEAD` (docs-only commits keep a review valid — RDR-1 invariance); `tree` = sha256 over the tracked blobs under the declared paths. A terminal verdict without `certifies`, or with a hash that no longer matches, is red: re-take, never re-bless. Frontmatter is read by the one parser (`read_frontmatter`) so a parser difference cannot produce a false green. Risk: the writers are instructions executed by an LLM; the smoke cannot prove they stamp the block — the gate's `certifies-missing` finding is the backstop, and it fires on the first terminal verdict that forgets.
- **Manifest ↔ frontmatter parity with the manifest as truth.** Every manifest entry whose file carries `version:` must equal it; unreadable frontmatter is red. The 20 drifts were realigned in this PR (file frontmatter set to the manifest version with a changelog line), the two YAML faults fixed at the root, and the template `coherence-context.json` now names the manifest path the materialisation instruction actually writes (`docs/project_log/governance_versions.json`; the old value never existed).
- **Same definition everywhere.** One CLI subcommand per gate; pre-push, meta CI, the template CI workflow and `materialize-synthetic.sh` (which now writes the project manifest the way SETUP does) call the same three commands. No YAML-side copy of any rule.

## Consequences

- New module `scripts/gates/coherence.py` (lock-step pair, delivered to projects); `gate.py certify | currency | manifest-parity`.
- The four verdict templates carry the `certifies:` block; QA `--verify`, the review checks and the security audit stamp it before a terminal verdict.
- `framework_version` 7.0.0 → **7.1.0** (MINOR — additive gates; branch `feature/EVOL-044-coherence-gates`).
- No new LAW. Both `CLAUDE.md` sides carry one paragraph (project § Artifact States: Currency; meta § Generation Standards §2: parity gate).

## Alternatives considered

Timestamps instead of hashes — rejected: a later edit that changes nothing would invalidate, a same-second edit would not. Storing the certified hash in a state marker instead of the artefact — rejected: markers are gitignored; the certification must travel with the verdict. Making every commit re-take every verdict — rejected: the content hash already ignores documentation-only commits; EVOL-051's incremental seal builds on the same idea.

## Operational Rule

No LAW added. Project `CLAUDE.md` § Artifact States gains the Currency paragraph; meta `CLAUDE.md` § Generation Standards §2 names the manifest-parity gate. Both lock-step sides updated; universal sections and the LAW corpus untouched.

## Verification record

`scripts/test-gates.sh` (23 unit tests; new: certify tree moves only with its subject, currency fresh / stale / missing / unreadable and the draft exemption, manifest parity drift / unreadable / missing manifest, CLI exit codes). `gate.py manifest-parity` went red on the real repository first (20 findings) and is green after the realignment. `scripts/materialize-synthetic.sh` (20 checks; it caught the missing manifest entry of the new module before any human would). `check-lockstep-pairs` 44 files / 14 pairs, `validate-governance --base main`, full T2 suite — green locally and in CI.
