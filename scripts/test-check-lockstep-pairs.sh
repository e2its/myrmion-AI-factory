#!/usr/bin/env bash
# ============================================================================
# test-check-lockstep-pairs.sh — self-test for the lock-step gate
# ============================================================================
# META-ONLY: exercises scripts/check-lockstep-pairs.sh in a disposable sandbox.
# Regression guard for the universal_clause_mirror false-green (LS-01): a
# drifted universal section MUST make the gate exit 1, not 0.
# ============================================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO/scripts/check-lockstep-pairs.sh"
PASS=0
FAIL=0

run_gate() { # $1 = sandbox dir — echoes the gate's exit code
  ( cd "$1" && bash "$GATE" >/dev/null 2>&1 )
  echo $?
}

write_pair() { # $1 dir ; $2 left-section-body ; $3 right-section-body
  local dir="$1"
  mkdir -p "$dir/config" "$dir/.context/templates/setup" "$dir/L" "$dir/R"
  printf '# Doc\n\n## Shared — MANDATORY\n%s\n## Next\n\ntail.\n' "$2" > "$dir/L/F.md"
  printf '# Doc\n\n## Shared — MANDATORY\n%s\n## Next\n\ntail.\n' "$3" > "$dir/R/F.md"
  cat > "$dir/config/coherence-context.json" <<'JSON'
{ "audit": { "lock_step_pairs": [
  { "type": "universal_clause_mirror", "left": "L/F.md", "right": "R/F.md",
    "universal_sections": ["## Shared — MANDATORY"] } ] } }
JSON
}

assert_exit() { # $1 label ; $2 expected ; $3 actual
  if [ "$2" = "$3" ]; then
    echo "  ok: $1 (exit $3)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1 — expected exit $2, got $3"
    FAIL=$((FAIL + 1))
  fi
}

BODY=$'\nline one.\nline two.\n'

# Case 1 — identical universal section → pass (exit 0)
d=$(mktemp -d); write_pair "$d" "$BODY" "$BODY"
assert_exit "identical universal section" 0 "$(run_gate "$d")"; rm -rf "$d"

# Case 2 — drifted section → fail (exit 1). REGRESSION GUARD for LS-01.
d=$(mktemp -d); write_pair "$d" "$BODY" $'\nline one.\nDRIFTED.\n'
assert_exit "drifted universal section detected" 1 "$(run_gate "$d")"; rm -rf "$d"

# Case 3 — section absent on right → fail (exit 1)
d=$(mktemp -d)
mkdir -p "$d/config" "$d/.context/templates/setup" "$d/L" "$d/R"
printf '# Doc\n\n## Shared — MANDATORY\n\nbody.\n' > "$d/L/F.md"
printf '# Doc\n\n## Other\n\nbody.\n' > "$d/R/F.md"
cat > "$d/config/coherence-context.json" <<'JSON'
{ "audit": { "lock_step_pairs": [
  { "type": "universal_clause_mirror", "left": "L/F.md", "right": "R/F.md",
    "universal_sections": ["## Shared — MANDATORY"] } ] } }
JSON
assert_exit "missing section on right detected" 1 "$(run_gate "$d")"; rm -rf "$d"

echo ""
echo "test-check-lockstep-pairs: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
