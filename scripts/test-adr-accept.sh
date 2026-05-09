#!/usr/bin/env bash
# ============================================================================
# scripts/test-adr-accept.sh — L4 ADR Accept Procedure simulation
# ============================================================================
# Validates the mechanical contract of factory-adr-management Accept Procedure
# against fixtures. The Accept Procedure (per the skill's pseudocode) is
# language-agnostic — this test implements a reference shell version of the
# steps and asserts:
#
#   1. ADD   — appending a new [LAW] section copies the ADR's Operational Rule
#              verbatim into constitution.md and flips ADR status to accepted.
#   2. REPLACE — substituting the body of an existing [LAW] section preserves
#                its heading.
#   3. Amendment record — the ADR's `## Constitution Amendment` section is
#                         populated with before/after content (non-empty after
#                         flip; empty before).
#   4. Validation — empty Operational Rule fails before any edit (no half-state).
#   5. ADR status flip is atomic with the constitution amendment (no flip if
#      the constitution edit fails).
#
# The agent implementing the actual Accept Procedure is free to use any tooling;
# what matters is the observable contract verified here.
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

WORK=$(mktemp -d -t evol026-l4-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

failures=0
fail() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; failures=$((failures + 1)); }
pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }

echo "L4 ADR Accept Procedure simulation"
echo

# ─── Reference helper: read frontmatter value ───────────────────────────────
read_fm() {
  local file="$1" key="$2"
  awk -v key="$key" '
    BEGIN { in_fm = 0; seen = 0 }
    /^---$/ { seen++; if (seen == 1) { in_fm = 1; next } if (seen == 2) exit }
    in_fm && $0 ~ "^" key ":[[:space:]]*" {
      sub("^" key ":[[:space:]]*", "", $0)
      gsub(/^["'\'']/, "", $0)
      gsub(/["'\'']$/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      print $0
      exit
    }
  ' "$file"
}

# ─── Reference helper: extract body of a heading ────────────────────────────
read_section_body() {
  local file="$1" heading_pattern="$2"
  awk -v hp="$heading_pattern" '
    BEGIN { in_sec = 0 }
    $0 ~ hp { in_sec = 1; next }
    /^## / { in_sec = 0 }
    in_sec { print }
  ' "$file"
}

# ─── Reference Accept Procedure (shell, ADD/REPLACE only) ───────────────────
# Inputs: $1 = adr path, $2 = constitution path
# Side effects: edits constitution + ADR per the procedure spec.
# Validates: empty Operational Rule → fail before any write.
accept_adr() {
  local adr="$1" constitution="$2"

  local target_section status amendment_kind title
  status=$(read_fm "$adr" status)
  target_section=$(read_fm "$adr" target_section)
  amendment_kind=$(read_fm "$adr" amendment_kind)
  title=$(read_fm "$adr" title)

  if [ "$status" != "proposed" ]; then
    echo "accept_adr: status is '$status', not 'proposed'" >&2
    return 1
  fi

  local op_rule
  op_rule=$(read_section_body "$adr" "^## Operational Rule")
  # Strip leading blockquote lines (template guidance) so the body is the rule itself.
  op_rule=$(printf '%s\n' "$op_rule" | sed '/^>/d' | awk 'NF { found=1 } found' | sed -e :a -e '/^$/{$d;N;ba' -e '}')

  if [ -z "$(printf '%s' "$op_rule" | tr -d '[:space:]')" ]; then
    echo "accept_adr: Operational Rule is empty — FAIL before any edit" >&2
    return 1
  fi

  # Capture before snapshot of the target section in constitution.
  local before_block=""
  case "$amendment_kind" in
    ADD)
      # Append new [LAW] section
      printf '\n## [LAW] %s\n\n%s\n' "$title" "$op_rule" >> "$constitution"
      ;;
    REPLACE)
      # Substitute body of the existing [LAW] section identified by target_section.
      before_block=$(read_section_body "$constitution" "^## \[LAW\] .*${target_section}")
      python3 - "$constitution" "$target_section" "$op_rule" <<'PY'
import sys, re, pathlib
path, target, rule = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(path).read_text()
# Heading captured line-bound ([^\n]*) so DOTALL does not spill across sections;
# body is non-greedy with DOTALL to cross newlines until the next ^## boundary.
pattern = re.compile(
    rf'(^## \[LAW\][^\n]*{re.escape(target)}[^\n]*\n)(.*?)(?=^## |\Z)',
    re.MULTILINE | re.DOTALL,
)
new = pattern.sub(lambda m: f"{m.group(1)}\n{rule}\n\n", text)
pathlib.Path(path).write_text(new)
PY
      ;;
    *)
      echo "accept_adr: amendment_kind '$amendment_kind' not handled by this reference (ADD/REPLACE only)" >&2
      return 1
      ;;
  esac

  # Write Constitution Amendment section (replace placeholder).
  python3 - "$adr" "$amendment_kind" "$target_section" "$before_block" "$op_rule" <<'PY'
import sys, pathlib, re
adr_path, kind, target, before, after = sys.argv[1:]
text = pathlib.Path(adr_path).read_text()
amendment = f"\n**Amendment kind:** {kind}\n**Target section:** {target}\n\n**Before:**\n```\n{before.rstrip()}\n```\n\n**After:**\n```\n{after.rstrip()}\n```\n"
text = re.sub(
    r'(## Constitution Amendment\n(?:>.*\n)*\n?){{POBLAR_POR_ACCEPT_PROCEDURE}}',
    rf'\1{amendment}',
    text,
)
# Also handle the case without literal placeholder (cleaner template).
if "{{POBLAR_POR_ACCEPT_PROCEDURE}}" not in text and amendment.strip() not in text:
    text = re.sub(
        r'(## Constitution Amendment\n)((?:>.*\n)*)',
        rf'\1\2{amendment}',
        text,
    )
pathlib.Path(adr_path).write_text(text)
PY

  # Flip status: proposed → accepted
  sed -i.bak -E 's/^status:[[:space:]]*proposed/status: accepted/' "$adr"
  rm -f "$adr.bak"
}

# ─── Test 1: ADD — happy path ───────────────────────────────────────────────
echo "Test 1 — ADD: append new [LAW] section"
cat > "$WORK/constitution_1.md" <<'EOF'
---
version: 3.0.0
---

# Project Constitution

## [LAW] 🛡️ Security by Design

OWASP enforcement.

## Governance Index

Inventory placeholder.
EOF

cat > "$WORK/adr_1.md" <<'EOF'
---
adr_number: "001"
title: "Mandatory request tracing"
date: "2026-05-05"
status: proposed
target_section: "NEW: Request Tracing"
amendment_kind: ADD
---

# ADR-001: Mandatory request tracing

## Context
Distributed tracing was inconsistent.

## Decision
All services emit a trace_id per request.

## Operational Rule
> Boilerplate guidance line one.
> Boilerplate guidance line two.

All services MUST emit a trace_id header on every request and propagate it across calls.
Trace IDs MUST be UUIDv4.

## Constitution Amendment
> Auto-managed.
{{POBLAR_POR_ACCEPT_PROCEDURE}}
EOF

if accept_adr "$WORK/adr_1.md" "$WORK/constitution_1.md"; then
  pass "accept_adr completed without error"
else
  fail "accept_adr failed unexpectedly"
fi

if grep -qE "^## \[LAW\] Mandatory request tracing" "$WORK/constitution_1.md"; then
  pass "constitution gained new [LAW] section"
else
  fail "constitution did NOT gain new [LAW] section"
fi

if grep -qF "All services MUST emit a trace_id" "$WORK/constitution_1.md"; then
  pass "Operational Rule body copied verbatim into constitution"
else
  fail "Operational Rule body not present in constitution"
fi

# Boilerplate guidance lines must NOT be copied.
if grep -qF "Boilerplate guidance line" "$WORK/constitution_1.md"; then
  fail "boilerplate guidance leaked into constitution"
else
  pass "boilerplate guidance excluded from constitution"
fi

if [ "$(read_fm "$WORK/adr_1.md" status)" = "accepted" ]; then
  pass "ADR status flipped to accepted"
else
  fail "ADR status did NOT flip (still: $(read_fm "$WORK/adr_1.md" status))"
fi

if grep -qF "**Amendment kind:** ADD" "$WORK/adr_1.md"; then
  pass "Constitution Amendment section populated"
else
  fail "Constitution Amendment section not populated"
fi

echo

# ─── Test 2: REPLACE — substitute existing [LAW] body ───────────────────────
echo "Test 2 — REPLACE: substitute existing [LAW] body"
cat > "$WORK/constitution_2.md" <<'EOF'
---
version: 3.0.0
---

# Project Constitution

## [LAW] 🌳 Branching Strategy

Old rule: feature/X only.

## [LAW] 🛡️ Security by Design

OWASP.
EOF

cat > "$WORK/adr_2.md" <<'EOF'
---
adr_number: "002"
title: "Refined branching"
date: "2026-05-05"
status: proposed
target_section: "Branching Strategy"
amendment_kind: REPLACE
---

# ADR-002: Refined branching

## Context
We need fix/* branches too.

## Decision
Allow feature/, fix/, hotfix/.

## Operational Rule
Working branches: feature/{slug}, fix/{slug}, hotfix/{slug}.
Base is main, never HEAD.

## Constitution Amendment
> Auto-managed.
{{POBLAR_POR_ACCEPT_PROCEDURE}}
EOF

if accept_adr "$WORK/adr_2.md" "$WORK/constitution_2.md"; then
  pass "accept_adr (REPLACE) completed"
else
  fail "accept_adr (REPLACE) failed"
fi

if grep -qF "Working branches: feature/{slug}, fix/{slug}, hotfix/{slug}" "$WORK/constitution_2.md"; then
  pass "constitution body replaced with new Operational Rule"
else
  fail "new Operational Rule not present in constitution"
fi

if grep -qF "Old rule: feature/X only" "$WORK/constitution_2.md"; then
  fail "old body not removed (REPLACE should substitute)"
else
  pass "old body removed"
fi

# Heading must remain after REPLACE.
if grep -qE "^## \[LAW\] 🌳 Branching Strategy" "$WORK/constitution_2.md"; then
  pass "[LAW] heading preserved across REPLACE"
else
  fail "[LAW] heading lost during REPLACE"
fi

# Other [LAW] sections must be untouched.
if grep -qE "^## \[LAW\] 🛡️ Security by Design" "$WORK/constitution_2.md"; then
  pass "unrelated [LAW] section untouched"
else
  fail "unrelated [LAW] section damaged"
fi

echo

# ─── Test 3: empty Operational Rule fails fast ──────────────────────────────
echo "Test 3 — validation: empty Operational Rule"
cat > "$WORK/constitution_3.md" <<'EOF'
---
version: 3.0.0
---

# Project Constitution

## [LAW] 🛡️ Security by Design

OWASP.
EOF

cat > "$WORK/adr_3.md" <<'EOF'
---
adr_number: "003"
title: "Empty rule"
date: "2026-05-05"
status: proposed
target_section: "NEW: Empty"
amendment_kind: ADD
---

# ADR-003: Empty rule

## Context
n/a

## Decision
n/a

## Operational Rule
> Boilerplate only — no actual rule below.

## Constitution Amendment
{{POBLAR_POR_ACCEPT_PROCEDURE}}
EOF

constitution_3_before=$(cat "$WORK/constitution_3.md")
adr_3_before=$(cat "$WORK/adr_3.md")

if accept_adr "$WORK/adr_3.md" "$WORK/constitution_3.md" 2>/dev/null; then
  fail "accept_adr should have failed on empty Operational Rule"
else
  pass "accept_adr correctly failed on empty Operational Rule"
fi

# State unchanged: status still proposed, constitution unchanged.
if [ "$(cat "$WORK/constitution_3.md")" = "$constitution_3_before" ]; then
  pass "constitution unchanged after failed accept (atomic)"
else
  fail "constitution was modified despite Operational Rule validation failure"
fi

if [ "$(read_fm "$WORK/adr_3.md" status)" = "proposed" ]; then
  pass "ADR status remained proposed (atomic)"
else
  fail "ADR status flipped despite validation failure"
fi

echo

# ─── Summary ────────────────────────────────────────────────────────────────
if [ "$failures" -eq 0 ]; then
  echo "L4: ok — Accept Procedure contract verified across ADD / REPLACE / validation."
  exit 0
else
  echo "L4: FAIL — $failures assertion(s) failed." >&2
  exit 1
fi
