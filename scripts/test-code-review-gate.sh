#!/usr/bin/env bash
# ============================================================================
# scripts/test-code-review-gate.sh — L6 Block 20 gate test (EVOL-039)
# ============================================================================
# Validates the factory-code-review hash helper + preflight.sh Step 0-bis
# against synthetic git repos. Each scenario constructs an ephemeral repo
# with a base branch (origin/main simulated via a local clone) and a feature
# branch carrying the scenario's diff + marker state, then invokes the
# helper / preflight and asserts the expected outcome.
#
# Scenarios:
#   1.  Hash determinism — two pipeline runs produce the identical 64-hex digest.
#   2.  RDR-1 invariance — docs-only commit does not change the hash; code
#       commit does.
#   3.  EMPTY sentinel — diff with zero is_code∪is_test files → helper prints
#       EMPTY rc 0; Step 0-bis skips with a log line, no finding.
#   4.  Git unavailable — helper with PATH stripped of git → rc 2, stderr
#       message, NEVER prints EMPTY (CRITICAL-1 regression guard).
#   5.  Bad stdin / missing files key → rc 2 (never 1, never EMPTY).
#   6.  Marker missing → blocker code-review-missing, preflight exit 1.
#   7.  Marker with blockers, no override → blocker code-review-blockers.
#   8.  Marker with blockers + override → important code-review-overridden,
#       no Block 20 blocker.
#   9.  Corrupt marker (garbage / non-int blocker) → blocker
#       code-review-marker-corrupt (CRITICAL-2 regression guard).
#   10. Clean marker → no Block 20 finding.
#   11. code_review.enabled=false → gate skipped, no finding.
#   12. code_review.pr_blocker=false → marker-missing degrades to Important.
#   13. Executor missing → important code-review-executor-missing, no blocker.
#   14. Tests-only diff → gate STILL fires (has_tests guard regression).
#
# Exit codes: 0 = ok, 1 = at least one scenario failed.
# ============================================================================

set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

FRAMEWORK_ROOT=$(pwd)
DETECT="$FRAMEWORK_ROOT/.claude/skills/factory-pr-review/scripts/detect_change_type.py"
HELPER="$FRAMEWORK_ROOT/.claude/skills/factory-code-review/scripts/code_review_hash.py"
PREFLIGHT_SRC="$FRAMEWORK_ROOT/.claude/skills/factory-pr-review/scripts"
CR_SKILL_SRC="$FRAMEWORK_ROOT/.claude/skills/factory-code-review"

PY=python3
FAILURES=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

pass() { echo "  ok  — $1"; }
fail() { echo "  FAIL — $1"; FAILURES=$((FAILURES + 1)); }

# ── fixture: repo with a base commit + feature branch, skill installed ──
make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -q -b main
    git config user.email t@t && git config user.name t
    mkdir -p src tests .claude/skills/factory-pr-review/scripts .claude/skills/factory-code-review/scripts config
    cp "$PREFLIGHT_SRC/preflight.sh" "$PREFLIGHT_SRC/detect_change_type.py" .claude/skills/factory-pr-review/scripts/
    cp "$HELPER" .claude/skills/factory-code-review/scripts/
    echo 'def base(): return 1' > src/base.py
    git add -A && git commit -qm base
    git checkout -qb feature/T-test
    echo 'def feat(): return 2' > src/feat.py
    git add -A && git commit -qm "feat: code"
    # simulate origin/main
    git update-ref refs/remotes/origin/main main
  )
}

# preflight exits 1 on blockers by design — always capture, never abort the suite
run_preflight() { (cd "$1" && bash .claude/skills/factory-pr-review/scripts/preflight.sh --json 2>/dev/null) || true; }
compute_hash()  { (cd "$1" && "$PY" .claude/skills/factory-pr-review/scripts/detect_change_type.py --git-range origin/main..HEAD 2>/dev/null | "$PY" .claude/skills/factory-code-review/scripts/code_review_hash.py 2>/dev/null); }
find_cat() { echo "$1" | "$PY" -c 'import json,sys
d=json.load(sys.stdin)
cats=[f["category"] for f in d.get("blockers",[])+d.get("important",[])+d.get("nits",[])]
print(" ".join(cats))'; }
sev_of() { echo "$1" | "$PY" -c 'import json,sys
d=json.load(sys.stdin); cat=sys.argv[1]
for sev in ("blockers","important","nits"):
    if any(f["category"]==cat for f in d.get(sev,[])): print(sev); break
else: print("absent")' "$2"; }

R="$TMP_ROOT/repo"; make_repo "$R"

echo "Scenario 1/2 — determinism + RDR-1 invariance"
H1=$(compute_hash "$R"); H2=$(compute_hash "$R")
[[ "$H1" =~ ^[0-9a-f]{64}$ && "$H1" == "$H2" ]] && pass "deterministic 64-hex" || fail "determinism (H1=$H1 H2=$H2)"
(cd "$R" && echo doc > note.md && git add -A && git commit -qm docs)
H3=$(compute_hash "$R")
[[ "$H3" == "$H1" ]] && pass "docs commit → hash unchanged" || fail "docs commit changed hash"
(cd "$R" && echo 'def x(): return 3' >> src/feat.py && git add -A && git commit -qm code2)
H4=$(compute_hash "$R")
[[ "$H4" != "$H1" ]] && pass "code commit → hash changed" || fail "code commit did not change hash"

echo "Scenario 3 — EMPTY sentinel"
E=$(echo '{"files":{"README.md":{"is_code":false,"is_test":false}}}' | "$PY" "$HELPER"; echo "rc=$?")
[[ "$E" == "EMPTY"$'\n'"rc=0" ]] && pass "no reviewable files → EMPTY rc0" || fail "EMPTY sentinel ($E)"

echo "Scenario 4 — git unavailable → rc 2, never EMPTY"
GITLESS="$TMP_ROOT/gitless"; mkdir -p "$GITLESS"
for tool in python3 head cat mktemp tr grep sed awk cut wc; do
  p=$(command -v "$tool" 2>/dev/null) && ln -sf "$p" "$GITLESS/$tool" || true
done
OUT=$( (cd "$R" && echo '{"files":{"src/feat.py":{"is_code":true,"is_test":false}}}' | PATH="$GITLESS" "$GITLESS/python3" "$HELPER" 2>/dev/null); echo "rc=$?" )
[[ "$OUT" == "rc=2" ]] && pass "git missing → rc2, no stdout" || fail "git-missing path ($OUT)"

echo "Scenario 5 — bad stdin / missing files key → rc 2"
O1=$(echo 'garbage' | "$PY" "$HELPER" 2>/dev/null; echo "rc=$?")
O2=$(echo '{}' | "$PY" "$HELPER" 2>/dev/null; echo "rc=$?")
[[ "$O1" == "rc=2" && "$O2" == "rc=2" ]] && pass "bad stdin + missing key → rc2" || fail "stdin guards ($O1|$O2)"

echo "Scenario 6 — marker missing → blocker"
J=$(run_preflight "$R")
[[ "$(sev_of "$J" code-review-missing)" == "blockers" ]] && pass "code-review-missing blocker" || fail "marker-missing ($(find_cat "$J"))"

HASH=$(compute_hash "$R"); MARKER="$R/.claude/state/code-review-${HASH}.marker"
mkdir -p "$R/.claude/state"

echo "Scenario 7 — blockers, no override → blocker"
echo '{"findings":{"blocker":2},"override":null}' > "$MARKER"
J=$(run_preflight "$R")
[[ "$(sev_of "$J" code-review-blockers)" == "blockers" ]] && pass "code-review-blockers blocker" || fail "blockers path ($(find_cat "$J"))"

echo "Scenario 8 — blockers + override → important only"
echo '{"findings":{"blocker":2},"override":{"reason":"rdr","at":"2026-08-04T00:00:00Z"}}' > "$MARKER"
J=$(run_preflight "$R")
[[ "$(sev_of "$J" code-review-overridden)" == "important" && "$(sev_of "$J" code-review-blockers)" == "absent" ]] \
  && pass "override → important, no blocker" || fail "override path ($(find_cat "$J"))"

echo "Scenario 9 — corrupt marker → blocker (regression: CRITICAL-2)"
echo 'garbage-not-json' > "$MARKER"
J=$(run_preflight "$R")
[[ "$(sev_of "$J" code-review-marker-corrupt)" == "blockers" ]] && pass "corrupt marker → blocker" || fail "corrupt marker ($(find_cat "$J"))"
echo '{"findings":{"blocker":"corrupt"}}' > "$MARKER"
J=$(run_preflight "$R")
[[ "$(sev_of "$J" code-review-marker-corrupt)" == "blockers" ]] && pass "non-int blocker count → blocker" || fail "non-int corrupt ($(find_cat "$J"))"

echo "Scenario 10 — clean marker → no Block 20 finding"
echo '{"findings":{"blocker":0,"important":1},"override":null}' > "$MARKER"
J=$(run_preflight "$R")
CATS=$(find_cat "$J")
[[ "$CATS" != *code-review* ]] && pass "clean marker silent" || fail "clean marker emitted ($CATS)"

echo "Scenario 11 — enabled=false → gate skipped"
rm -f "$MARKER"
echo '{"code_review":{"enabled":false}}' > "$R/config/quality.json"
J=$(run_preflight "$R")
[[ "$(find_cat "$J")" != *code-review* ]] && pass "disabled via config" || fail "disabled still fired ($(find_cat "$J"))"

echo "Scenario 12 — pr_blocker=false → marker-missing degrades to Important"
echo '{"code_review":{"pr_blocker":false}}' > "$R/config/quality.json"
J=$(run_preflight "$R")
[[ "$(sev_of "$J" code-review-missing)" == "important" ]] && pass "pr_blocker=false → important" || fail "pr_blocker routing ($(find_cat "$J"))"
rm -f "$R/config/quality.json"

echo "Scenario 13 — executor missing → important, no blocker"
mv "$R/.claude/skills/factory-code-review" "$TMP_ROOT/parked"
J=$(run_preflight "$R")
[[ "$(sev_of "$J" code-review-executor-missing)" == "important" && "$(sev_of "$J" code-review-missing)" == "absent" ]] \
  && pass "executor-missing important" || fail "executor-missing ($(find_cat "$J"))"
mv "$TMP_ROOT/parked" "$R/.claude/skills/factory-code-review"

echo "Scenario 14 — tests-only diff → gate still fires (has_tests guard)"
R2="$TMP_ROOT/repo2"; make_repo "$R2"
(cd "$R2" && git checkout -q main && git checkout -qb feature/T-tests-only \
  && echo 'def test_x(): assert True' > tests/test_x.py && git add -A && git commit -qm "test: only tests" \
  && git update-ref refs/remotes/origin/main main)
J=$(run_preflight "$R2")
[[ "$(sev_of "$J" code-review-missing)" == "blockers" ]] && pass "tests-only diff gated" || fail "tests-only bypass ($(find_cat "$J"))"

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "L6: ok — Block 20 gate behaviour verified across 14 scenarios."
  exit 0
else
  echo "L6: FAIL — $FAILURES scenario assertion(s) failed."
  exit 1
fi
