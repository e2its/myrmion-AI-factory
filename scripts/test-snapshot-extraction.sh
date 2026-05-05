#!/usr/bin/env bash
# ============================================================================
# scripts/test-snapshot-extraction.sh — L2 extraction unit test
# ============================================================================
# Validates the deterministic extraction contract that SETUP --generate's
# `generate_governance_snapshot()` (Factory-setup-materialization Checkpoint 3.1)
# must follow when populating the snapshot's:
#
#   - "## Active Constitution (Operational [LAW] sections — verbatim)"
#   - "## Defect Prevention Catalog (Universal entries — applicable_when: always)"
#
# The agent implementing the snapshot generator is free to use any tooling
# (sed/awk/python/native) but MUST produce output equivalent to the regex
# contract this test verifies on canonical fixtures.
#
# Test cases:
#   1. EXTRACT_LAW_SECTIONS isolates `^## \[LAW\] .+` blocks up to next `^## `.
#   2. Subsections (###, ####) inside a [LAW] block are preserved verbatim.
#   3. Sections without [LAW] marker are NOT extracted (preamble, references).
#   4. EXTRACT_UNIVERSAL_DCS keeps entries with applicable_when: always.
#   5. Scope-conditional DCs (applicable_when: scope:*) are excluded.
#   6. Idempotency: extracting the same fixture twice produces identical output.
#
# Exit codes:
#   0 = ok
#   1 = at least one assertion failed
# ============================================================================

set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

# Workspace under repo's .gitignored area.
WORK=$(mktemp -d -t evol026-l2-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

failures=0
fail() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; failures=$((failures + 1)); }
pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }

echo "L2 snapshot extraction unit test"
echo

# ─── Reference implementation: EXTRACT_LAW_SECTIONS ─────────────────────────
# Awk one-liner that implements the regex contract from Checkpoint 3.1.
# Reads from stdin, writes extracted [LAW] blocks to stdout. Each block starts
# with the heading line and includes everything up to (but not including) the
# next `^## ` boundary or EOF.
extract_law_sections() {
  awk '
    BEGIN { in_block = 0 }
    /^## \[LAW\] / { in_block = 1; print; next }
    /^## / { in_block = 0 }
    in_block { print }
  '
}

# ─── Reference implementation: EXTRACT_UNIVERSAL_DCS ────────────────────────
# DC entries follow `### DC-N — {title}` headings each with a small YAML-like
# metadata block immediately after. We keep entries where `applicable_when:`
# value is `always` (after stripping quotes/whitespace).
extract_universal_dcs() {
  awk '
    BEGIN { in_entry = 0; keep = 0; meta_done = 0; buf = "" }
    /^### DC-/ {
      if (in_entry && keep) print buf
      in_entry = 1; keep = 0; meta_done = 0; buf = $0 "\n"
      next
    }
    in_entry {
      buf = buf $0 "\n"
      if (!meta_done && $0 ~ /^applicable_when:[[:space:]]*/) {
        v = $0
        sub(/^applicable_when:[[:space:]]*/, "", v)
        gsub(/[[:space:]"\x27]/, "", v)
        if (v == "always") keep = 1
        meta_done = 1
      }
    }
    END { if (in_entry && keep) print buf }
  '
}

# ─── Fixture: constitution_fixture.md ────────────────────────────────────────
cat > "$WORK/constitution_fixture.md" <<'EOF'
---
version: 3.0.0
---

# Project Constitution - Fundamental Laws

> Preamble that should NEVER be extracted.

## [LAW] 🎯 Fundamental Principles
> Mandate text.

### KISS
- Simple beats clever.
### DRY
- One source of truth.

## [LAW] 🛡️ Security by Design

OWASP enforcement.

### OWASP Top 10
- Injection prevention.
- AuthN/AuthZ baselines.

## Governance Index

> This section MUST NOT be extracted (informational).

### Inventory
- file1.md
- file2.md

## [LAW] 🌳 Branching Strategy

### Branch Naming
feature/{slug}, fix/{slug}.

## References

> Also informational. Not extracted.
EOF

# ─── Fixture: defect_prevention_fixture.md ──────────────────────────────────
cat > "$WORK/defect_prevention_fixture.md" <<'EOF'
# Defect Prevention Catalog (fixture)

### DC-001 — Always-applicable rule
applicable_to: [BLUEPRINT, IMPLEMENT, REVIEW]
applicable_when: always
severity: high

Body of DC-001 — universal.

### DC-002 — Stack-conditional rule
applicable_to: [IMPLEMENT]
applicable_when: stack:nodejs
severity: medium

Body of DC-002 — only for Node.js.

### DC-003 — Another universal rule
applicable_to: [REVIEW]
applicable_when: always
severity: low

Body of DC-003 — universal.

### DC-004 — Scope-conditional rule
applicable_to: [BLUEPRINT]
applicable_when: scope:full-stack
severity: high

Body of DC-004 — only for full-stack features.
EOF

# ─── Run extractions ────────────────────────────────────────────────────────
extract_law_sections < "$WORK/constitution_fixture.md" > "$WORK/law_extract.md"
extract_universal_dcs < "$WORK/defect_prevention_fixture.md" > "$WORK/dc_extract.md"

# ─── Assertions on EXTRACT_LAW_SECTIONS ─────────────────────────────────────
echo "EXTRACT_LAW_SECTIONS"
expected_law_headings=("Fundamental Principles" "Security by Design" "Branching Strategy")
unexpected_law_text=("Preamble that should NEVER be extracted" "Governance Index" "Inventory" "References" "Also informational")

for h in "${expected_law_headings[@]}"; do
  if grep -qF "$h" "$WORK/law_extract.md"; then
    pass "extracts [LAW] heading containing \"$h\""
  else
    fail "missing [LAW] heading containing \"$h\""
  fi
done

# Subsection preservation
for sub in "### KISS" "### DRY" "### OWASP Top 10" "### Branch Naming"; do
  if grep -qF "$sub" "$WORK/law_extract.md"; then
    pass "preserves subsection \"$sub\""
  else
    fail "missing subsection \"$sub\""
  fi
done

# Negative: non-[LAW] content excluded
for text in "${unexpected_law_text[@]}"; do
  if grep -qF "$text" "$WORK/law_extract.md"; then
    fail "non-[LAW] content leaked into extract: \"$text\""
  else
    pass "excludes non-[LAW] content: \"$text\""
  fi
done

echo

# ─── Assertions on EXTRACT_UNIVERSAL_DCS ────────────────────────────────────
echo "EXTRACT_UNIVERSAL_DCS"
for dc in "DC-001" "DC-003"; do
  if grep -qF "$dc" "$WORK/dc_extract.md"; then
    pass "keeps universal DC \"$dc\""
  else
    fail "missing universal DC \"$dc\""
  fi
done

for dc in "DC-002" "DC-004"; do
  if grep -qF "$dc" "$WORK/dc_extract.md"; then
    fail "scope/stack-conditional DC \"$dc\" leaked into universal extract"
  else
    pass "excludes scope/stack-conditional DC \"$dc\""
  fi
done

echo

# ─── Idempotency ────────────────────────────────────────────────────────────
echo "Idempotency"
extract_law_sections < "$WORK/constitution_fixture.md" > "$WORK/law_extract2.md"
extract_universal_dcs < "$WORK/defect_prevention_fixture.md" > "$WORK/dc_extract2.md"

if diff -q "$WORK/law_extract.md" "$WORK/law_extract2.md" >/dev/null 2>&1; then
  pass "EXTRACT_LAW_SECTIONS is idempotent"
else
  fail "EXTRACT_LAW_SECTIONS produced different output on second run"
fi

if diff -q "$WORK/dc_extract.md" "$WORK/dc_extract2.md" >/dev/null 2>&1; then
  pass "EXTRACT_UNIVERSAL_DCS is idempotent"
else
  fail "EXTRACT_UNIVERSAL_DCS produced different output on second run"
fi

echo

# ─── Summary ────────────────────────────────────────────────────────────────
if [ "$failures" -eq 0 ]; then
  echo "L2: ok — extraction contract verified on fixtures."
  exit 0
else
  echo "L2: FAIL — $failures assertion(s) failed." >&2
  exit 1
fi
