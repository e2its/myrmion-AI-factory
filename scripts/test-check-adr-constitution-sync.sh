#!/usr/bin/env bash
# ============================================================================
# scripts/test-check-adr-constitution-sync.sh — L5 CI gate test (EVOL-026)
# ============================================================================
# Validates scripts/check-adr-constitution-sync.sh against synthetic git
# histories. Each scenario constructs an ephemeral repo with a base commit
# (representing main) and a feature branch with the scenario's diff, then
# invokes the gate and asserts the expected outcome.
#
# Scenarios:
#   1. ADR transitions to accepted, NO constitution change → expect FAIL.
#   2. ADR transitions to accepted, constitution.md changed → expect PASS.
#   3. ADR transitions to accepted, NO constitution change, but a commit
#      message contains [adr-backfill] → expect PASS (bypass).
#   4. No ADR changes at all (other unrelated changes) → expect PASS.
#   5. ADR file edited but status stays proposed → expect PASS.
#   6. New ADR file lands already-accepted, no constitution change → expect FAIL.
#   7. FDR file (under docs/spec/{ID}/fdr/) transitions to accepted, no
#      constitution change → expect PASS (FDRs are not subject to the gate).
#
# Exit codes:
#   0 = ok
#   1 = at least one scenario produced unexpected outcome
# ============================================================================

set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

GATE_SCRIPT="$(pwd)/scripts/check-adr-constitution-sync.sh"
if [ ! -x "$GATE_SCRIPT" ]; then
  echo "L5: gate script not found or not executable at $GATE_SCRIPT" >&2
  exit 2
fi

failures=0
fail() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; failures=$((failures + 1)); }
pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }

echo "L5 CI gate test (EVOL-026)"
echo

# ─── Scenario harness ───────────────────────────────────────────────────────
run_scenario() {
  local name="$1" expect_exit="$2"
  shift 2
  local repo
  repo=$(mktemp -d -t evol026-l5-XXXXXX)

  (
    cd "$repo"
    git init -q -b main
    git config user.email "test@evol026.local"
    git config user.name "EVOL-026 L5 test"

    # Base commit: representative project layout.
    mkdir -p docs/project_log/adr docs/spec/FEAT-001/fdr
    echo "# Initial constitution" > docs/constitution.md
    echo "placeholder" > README.md
    git add -A && git commit -q -m "init"
    git tag base

    # Scenario-specific work (the rest of the args are the work command).
    "$@"
  )

  # Run gate against base. Use --git-dir/--work-tree so we can call from any cwd.
  set +e
  ( cd "$repo" && bash "$GATE_SCRIPT" base ) >"$repo/gate.stdout" 2>"$repo/gate.stderr"
  local actual=$?
  set -e
  if [ "$actual" -eq "$expect_exit" ]; then
    pass "$name (expected exit $expect_exit, got $actual)"
  else
    fail "$name (expected exit $expect_exit, got $actual)"
    echo "    stdout: $(head -3 "$repo/gate.stdout" | tr '\n' '|')" >&2
    echo "    stderr: $(head -3 "$repo/gate.stderr" | tr '\n' '|')" >&2
  fi

  rm -rf "$repo"
}

write_adr_proposed() {
  local n="$1" path="docs/project_log/adr/ADR-${n}-test.md"
  cat > "$path" <<EOF
---
adr_number: "${n}"
title: "Test ADR ${n}"
date: "2026-05-05"
status: proposed
target_section: "NEW: Test"
amendment_kind: ADD
---

# ADR-${n}: Test

## Operational Rule
Some rule.
EOF
}

flip_adr_to_accepted() {
  local n="$1" path="docs/project_log/adr/ADR-${n}-test.md"
  sed -i.bak -E 's/^status:[[:space:]]*proposed/status: accepted/' "$path"
  rm -f "$path.bak"
}

write_fdr_proposed() {
  local n="$1" feat="$2" path="docs/spec/${feat}/fdr/FDR-${n}-test.md"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
---
feature_id: "${feat}"
fdr_number: "${n}"
title: "Test FDR ${n}"
date: "2026-05-05"
status: proposed
---

# FDR-${n}: Test

## Binding Rule
Some feature-local rule.
EOF
}

flip_fdr_to_accepted() {
  local n="$1" feat="$2" path="docs/spec/${feat}/fdr/FDR-${n}-test.md"
  sed -i.bak -E 's/^status:[[:space:]]*proposed/status: accepted/' "$path"
  rm -f "$path.bak"
}

# ─── Scenario 1: ADR accepted, NO constitution change → FAIL ────────────────
run_scenario "scenario 1: ADR accepted without constitution diff" 1 bash -c '
  write_adr_proposed() { :; }
  '"$(declare -f write_adr_proposed flip_adr_to_accepted)"'
  write_adr_proposed 001
  git add -A && git commit -q -m "propose ADR-001"
  flip_adr_to_accepted 001
  git add -A && git commit -q -m "accept ADR-001 (forgot constitution amendment)"
'

# ─── Scenario 2: ADR accepted + constitution change → PASS ──────────────────
run_scenario "scenario 2: ADR accepted with constitution diff" 0 bash -c '
  '"$(declare -f write_adr_proposed flip_adr_to_accepted)"'
  write_adr_proposed 002
  git add -A && git commit -q -m "propose ADR-002"
  flip_adr_to_accepted 002
  echo "## [LAW] Test rule" >> docs/constitution.md
  git add -A && git commit -q -m "accept ADR-002 + amend constitution"
'

# ─── Scenario 3: bypass via [adr-backfill] marker → PASS ────────────────────
run_scenario "scenario 3: [adr-backfill] bypass" 0 bash -c '
  '"$(declare -f write_adr_proposed flip_adr_to_accepted)"'
  write_adr_proposed 003
  git add -A && git commit -q -m "propose ADR-003"
  flip_adr_to_accepted 003
  git add -A && git commit -q -m "accept ADR-003 historical [adr-backfill]"
'

# ─── Scenario 4: no ADR changes → PASS ──────────────────────────────────────
run_scenario "scenario 4: no ADR touched" 0 bash -c '
  echo "unrelated change" > some_file.txt
  git add -A && git commit -q -m "unrelated work"
'

# ─── Scenario 5: ADR edited but status stays proposed → PASS ────────────────
run_scenario "scenario 5: ADR edited, status stays proposed" 0 bash -c '
  '"$(declare -f write_adr_proposed)"'
  write_adr_proposed 005
  git add -A && git commit -q -m "propose ADR-005"
  echo "additional context" >> docs/project_log/adr/ADR-005-test.md
  git add -A && git commit -q -m "refine ADR-005"
'

# ─── Scenario 6: new ADR landing already-accepted, no constitution → FAIL ──
run_scenario "scenario 6: new ADR landing accepted without constitution" 1 bash -c '
  cat > docs/project_log/adr/ADR-006-test.md <<"EOF"
---
adr_number: "006"
title: "Direct landing accepted"
date: "2026-05-05"
status: accepted
target_section: "NEW: X"
amendment_kind: ADD
---
# ADR-006

## Operational Rule
something
EOF
  git add -A && git commit -q -m "land ADR-006 already accepted (skipping ceremony)"
'

# ─── Scenario 7: FDR transitions to accepted, NO constitution diff → PASS ───
run_scenario "scenario 7: FDR transitions to accepted (not subject to gate)" 0 bash -c '
  '"$(declare -f write_fdr_proposed flip_fdr_to_accepted)"'
  write_fdr_proposed 001 FEAT-001
  git add -A && git commit -q -m "propose FDR-001"
  flip_fdr_to_accepted 001 FEAT-001
  git add -A && git commit -q -m "accept FDR-001"
'

echo

# ─── Summary ────────────────────────────────────────────────────────────────
if [ "$failures" -eq 0 ]; then
  echo "L5: ok — gate behaviour verified across 7 scenarios."
  exit 0
else
  echo "L5: FAIL — $failures scenario(s) produced unexpected outcome." >&2
  exit 1
fi
