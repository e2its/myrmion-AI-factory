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

# ── law_corpus_mirror cases (EVOL-040) ──────────────────────────────────────

write_law_pair() { # $1 dir ; $2 left-laws-body ; $3 right-laws-body ; $4 extra pair fields (JSON, no braces)
  local dir="$1"
  mkdir -p "$dir/config" "$dir/.context/templates/setup" "$dir/L" "$dir/R"
  printf '# Doc\n\n## Governance Rules\n\n%s\n## Next\n\ntail.\n' "$2" > "$dir/L/F.md"
  printf '# Doc\n\n## Governance Rules\n\n%s\n## Next\n\ntail.\n' "$3" > "$dir/R/F.md"
  cat > "$dir/config/coherence-context.json" <<JSON
{ "audit": { "lock_step_pairs": [
  { "type": "law_corpus_mirror", "left": "L/F.md", "right": "R/F.md",
    "law_section": "## Governance Rules"${4:+, $4} } ] } }
JSON
}

UNI=$'1. **[LAW-01] Alpha**: body alpha.\n2. **[LAW-02] Beta**: body beta.'

# Case 4 — identical corpus → pass
d=$(mktemp -d); write_law_pair "$d" "$UNI" "$UNI" ""
assert_exit "law corpus identical" 0 "$(run_gate "$d")"; rm -rf "$d"

# Case 5 — drifted universal body (ordinal differs too — must be stripped) → fail
d=$(mktemp -d); write_law_pair "$d" "$UNI" $'1. **[LAW-01] Alpha**: body alpha.\n7. **[LAW-02] Beta**: body DRIFTED.' ""
assert_exit "law universal body drift detected" 1 "$(run_gate "$d")"; rm -rf "$d"

# Case 5b — same bodies under different ordinals → pass (ordinal is cosmetic)
d=$(mktemp -d); write_law_pair "$d" "$UNI" $'3. **[LAW-01] Alpha**: body alpha.\n9. **[LAW-02] Beta**: body beta.' ""
assert_exit "ordinal-only difference tolerated" 0 "$(run_gate "$d")"; rm -rf "$d"

# Case 6 — undeclared ID missing on right → fail
d=$(mktemp -d); write_law_pair "$d" "$UNI" $'1. **[LAW-01] Alpha**: body alpha.' ""
assert_exit "undeclared missing law detected" 1 "$(run_gate "$d")"; rm -rf "$d"

# Case 7 — declared meta_only absent right → pass; present right → fail
d=$(mktemp -d); write_law_pair "$d" "$UNI" $'1. **[LAW-01] Alpha**: body alpha.' '"meta_only": ["LAW-02"]'
assert_exit "declared meta-only law tolerated" 0 "$(run_gate "$d")"; rm -rf "$d"
d=$(mktemp -d); write_law_pair "$d" "$UNI" "$UNI" '"meta_only": ["LAW-02"]'
assert_exit "meta-only law present on right detected" 1 "$(run_gate "$d")"; rm -rf "$d"

# Case 8 — duplicate ID within one side → fail
d=$(mktemp -d); write_law_pair "$d" $'1. **[LAW-01] Alpha**: a.\n2. **[LAW-01] Alpha**: a.' $'1. **[LAW-01] Alpha**: a.' ""
assert_exit "duplicate law ID detected" 1 "$(run_gate "$d")"; rm -rf "$d"

# Case 9 — divergence BELOW the addendum marker of a declared addendum ID → pass
AL=$'1. **[LAW-01] Alpha**: body alpha.\n\n   *Meta application:* meta-specific tail.'
AR=$'1. **[LAW-01] Alpha**: body alpha.\n\n   *Project application:* project-specific tail.'
d=$(mktemp -d); write_law_pair "$d" "$AL" "$AR" '"addendum_ids": ["LAW-01"]'
assert_exit "declared addendum divergence tolerated" 0 "$(run_gate "$d")"; rm -rf "$d"

echo ""
echo "test-check-lockstep-pairs: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
