# EVOL-039 — Agentic Code Review as a Push-Gate Precondition

Branch: `feature/EVOL-039-agentic-code-review`. Status: **DRAFT — decisions in progress**.

Behavioral-contract files (skills/hooks/scripts/instructions) are hard exclusions from the docs fast-lane (Generation Standards §3) → full PR + CI + governance bump. ADR-EVOL-039 is the local ceremony.

---

## 1. Problem

TBD.

## 2. Prior art surveyed

TBD.

## 3. Design — standalone executor + marker gate

TBD.

## 4. Decision log (RDR)

### RDR-1 — Marker key

**Ratified: Option A — content hash of code files in the diff.**

Verbatim user choice: `A`.

Options presented:
- **A (recommended, chosen)** — `code-review-${sha256(code content in diff)}.marker`. A commit touching only docs/manifest does not invalidate; a content-preserving rebase does not invalidate. Tradeoff: avoids the bulk of useless re-runs, at the cost of diverging from Phase 0's `${branch_sha}` keying — two marker conventions coexist in `.claude/state/`.
- **B** — `${branch_sha}`, identical to Phase 0. Tradeoff: one convention, minimal implementation, but pays the full fan-out on every commit of the branch.
- **C** — extend the existing Phase 0 marker with a `code_review` field. Tradeoff: smallest new surface, but couples two audits with different triggers (governance-sensitive vs code-sensitive).

Rationale: the AGAINST pass identified marker-invalidation cost as the factor determining whether the gate gets used or bypassed with `--no-verify`. A is the only option that addresses it.

### RDR-2 — Override policy

**Ratified: Option D — fail-open on infra (noisy advisory) + fail-closed with audited override on findings.**

Verbatim user choice: `para rdr-2. tu recomendacion` (recommendation was D).

Options presented:
- **A** — pure fail-closed, no override. Max integrity; infra failure kills the branch and pushes the user to a terminal outside Claude Code, where the gate sees nothing.
- **B** — audited override with mandatory justification (review-policy.md pattern) for everything.
- **C** — fail-open on infra, fail-closed on findings (LAW 11 / complexity-gate pattern). "Executor absent" silently makes the gate optional.
- **D (recommended, chosen)** — C for infra + B for findings.

Semantics:
- Executor not installed / not synced → **noisy warning, push passes**. Detectable state, no signal value: punishes not having run `factory-sync.sh`, not bad code.
- Executor ran, findings with blockers → **push blocked**. Override ONLY via explicit RDR with the user; recorded in the marker (`"override":{"reason","at"}`) + worklog entry.

Precedents: LAW 11 fail-open-on-infra (ratified); `review-policy.md` override-with-justification (shipped).

### RDR-3 — Relationship with the IMPLEMENT 🔍 REVIEW hat

**Ratified: Option C — single engine, two invocations.**

Verbatim user choice: `rdr-3 c`.

Options presented:
- **A** — independent: hat unchanged, push gate does its own full pass. Zero coupling; two divergent code checklists over time.
- **B** — peer_reviews satisfy the marker by file-coverage union. Discarded: false green — file touched by INC-1 then INC-3 accumulates partial reviews, none over the final state.
- **C (recommended, chosen)** — new skill `factory-code-review` is the SINGLE review engine. IMPLEMENT 🔍 REVIEW hat reimplements over it (scope = increment; output = `peer_review_{INC-N}_{ts}.md` per review-policy.md). Push-gate pass: scope = full branch diff `origin/{base}..HEAD`; ONLY this pass writes the marker (RDR-1 content-hash key). Sees final file state + cross-increment integration; one checklist framework-wide (CIP/DRY).
- **D** — gate reviews only files not covered by peer_reviews. Discarded: collapses to zero review when process ran clean; same final-state blind spot as B; needs a coverage ledger (new fragile machinery).

Cost note: with RDR-1 content-hash keying, the branch pass runs once per code state, not per commit. Total = N increment reviews + 1 final-state review.

## 5. Scope — files touched

TBD.

## 6. Governance — manifest, ADR, sync, validators

TBD.

## 7. Vertical-slice breakdown

TBD.
