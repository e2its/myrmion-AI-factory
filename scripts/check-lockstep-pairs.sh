#!/usr/bin/env bash
# ============================================================================
# check-lockstep-pairs.sh — Lock-step Pair Integrity Gate
# ============================================================================
# META-ONLY: do not ship to downstream materialised projects.
# Lock-step pairs are a meta-framework concept (a script lives twice —
# once at meta scripts/X.sh, once at .context/templates/setup/scripts/X.sh
# as the template shipped to downstream via factory-sync.sh). The
# distinction collapses post-materialisation. If you find this file in
# a downstream project, it was copied by mistake — delete it.
#
# Reads config/coherence-context.json § audit.lock_step_pairs and
# verifies parity per pair `type`:
#   - meta_template_mirror     : byte-identical diff between left/right.
#                                 If left/right contain glob chars (*),
#                                 expand and pair files by basename.
#   - universal_clause_mirror  : extracts each H2 section listed in the
#                                 pair's universal_sections array (content
#                                 between the heading and the next H2 or
#                                 EOF) from left and right, diffs them.
#                                 Drift in any listed section fails.
#   - other types              : WARN and SKIPPED.
#
# Exits:
#   0 — all checked pairs pass (or list empty / all skipped)
#   1 — at least one pair has drifted
#   2 — config file missing or unreadable
#
# Self-guard: if .context/templates/setup/ is absent (not in meta repo),
# exits 0 silently. Belt-and-braces against future copy-paste leaks.
# ============================================================================

set -euo pipefail

# ── Self-guard: silent no-op if not in meta repo ──
if [[ ! -d .context/templates/setup ]]; then
  echo "[INFO] check-lockstep-pairs: not in meta repo (.context/templates/setup absent) — no-op" >&2
  exit 0
fi

CONTEXT_FILE="config/coherence-context.json"

if [[ ! -f "$CONTEXT_FILE" ]]; then
  echo "[ERROR] check-lockstep-pairs: $CONTEXT_FILE not found" >&2
  exit 2
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "[ERROR] check-lockstep-pairs: jq not installed" >&2
  exit 2
fi

PAIRS=$(jq -c '.audit.lock_step_pairs // [] | .[]' "$CONTEXT_FILE" 2>/dev/null || true)
if [[ -z "$PAIRS" ]]; then
  echo "[INFO] check-lockstep-pairs: no pairs declared in $CONTEXT_FILE.audit.lock_step_pairs — nothing to check"
  exit 0
fi

DRIFT_COUNT=0
TOTAL=0
SKIPPED=0
CHECKED=0

check_byte_identical() {
  local left="$1"
  local right="$2"
  if [[ ! -f "$left" ]]; then
    echo "[FAIL] $left missing (declared as left side of lock-step pair)" >&2
    return 1
  fi
  if [[ ! -f "$right" ]]; then
    echo "[FAIL] $right missing (declared as right side of lock-step pair)" >&2
    return 1
  fi
  if ! diff -q "$left" "$right" > /dev/null 2>&1; then
    echo "[FAIL] lock-step drift: $left <> $right" >&2
    diff -u "$left" "$right" 2>&1 | sed 's/^/   /' >&2 || true
    return 1
  fi
  return 0
}

# Extract content between an H2 heading and the next H2 heading (or EOF).
# Output is the section body without the heading line itself.
extract_section() {
  local file="$1"
  local heading="$2"
  awk -v h="$heading" '
    BEGIN { p = 0 }
    {
      if (substr($0, 1, length(h)) == h && length($0) == length(h)) { p = 1; next }
      if (p && /^## /) { exit }
      if (p) print
    }
  ' "$file"
}

check_universal_clauses() {
  local left="$1"
  local right="$2"
  local sections_json="$3"
  local local_drift=0

  if [[ ! -f "$left" ]]; then
    echo "[FAIL] $left missing (declared as left side of universal_clause_mirror)" >&2
    return 1
  fi
  if [[ ! -f "$right" ]]; then
    echo "[FAIL] $right missing (declared as right side of universal_clause_mirror)" >&2
    return 1
  fi

  while IFS= read -r section; do
    [[ -z "$section" ]] && continue
    local left_body right_body
    left_body=$(extract_section "$left" "$section")
    right_body=$(extract_section "$right" "$section")
    if [[ -z "$left_body" ]]; then
      echo "[FAIL] universal_clause_mirror: section '$section' not found in $left" >&2
      local_drift=$((local_drift + 1))
      continue
    fi
    if [[ -z "$right_body" ]]; then
      echo "[FAIL] universal_clause_mirror: section '$section' not found in $right" >&2
      local_drift=$((local_drift + 1))
      continue
    fi
    if ! diff -q <(printf '%s' "$left_body") <(printf '%s' "$right_body") > /dev/null 2>&1; then
      echo "[FAIL] universal_clause_mirror drift in section '$section': $left <> $right" >&2
      diff -u <(printf '%s' "$left_body") <(printf '%s' "$right_body") 2>&1 | sed 's/^/   /' >&2 || true
      local_drift=$((local_drift + 1))
    fi
  done < <(jq -r '.[]' <<< "$sections_json")

  return $local_drift
}

while IFS= read -r pair; do
  TYPE=$(jq -r '.type // empty' <<< "$pair")
  LEFT=$(jq -r '.left // empty' <<< "$pair")
  RIGHT=$(jq -r '.right // empty' <<< "$pair")
  TOTAL=$((TOTAL + 1))

  case "$TYPE" in
    meta_template_mirror)
      if [[ "$LEFT" == *"*"* ]]; then
        # Glob — expand left, pair by basename to corresponding right path
        LEFT_DIR=$(dirname "$LEFT")
        RIGHT_DIR=$(dirname "$RIGHT")
        LEFT_GLOB=$(basename "$LEFT")
        shopt -s nullglob
        for left_file in "$LEFT_DIR"/$LEFT_GLOB; do
          base=$(basename "$left_file")
          right_file="$RIGHT_DIR/$base"
          CHECKED=$((CHECKED + 1))
          if ! check_byte_identical "$left_file" "$right_file"; then
            DRIFT_COUNT=$((DRIFT_COUNT + 1))
          fi
        done
        shopt -u nullglob
      else
        # Concrete paths
        CHECKED=$((CHECKED + 1))
        if ! check_byte_identical "$LEFT" "$RIGHT"; then
          DRIFT_COUNT=$((DRIFT_COUNT + 1))
        fi
      fi
      ;;
    universal_clause_mirror)
      SECTIONS_JSON=$(jq -c '.universal_sections // []' <<< "$pair")
      SECTION_COUNT=$(jq 'length' <<< "$SECTIONS_JSON")
      if [[ "$SECTION_COUNT" == "0" ]]; then
        echo "[FAIL] universal_clause_mirror declared without universal_sections list: $LEFT <> $RIGHT" >&2
        DRIFT_COUNT=$((DRIFT_COUNT + 1))
      else
        CHECKED=$((CHECKED + SECTION_COUNT))
        if ! check_universal_clauses "$LEFT" "$RIGHT" "$SECTIONS_JSON"; then
          rc=$?
          DRIFT_COUNT=$((DRIFT_COUNT + rc))
        fi
      fi
      ;;
    *)
      echo "[WARN] unknown pair type '$TYPE' — skipping: $LEFT <> $RIGHT" >&2
      SKIPPED=$((SKIPPED + 1))
      ;;
  esac
done <<< "$PAIRS"

if [[ $DRIFT_COUNT -gt 0 ]]; then
  echo "" >&2
  echo "[FAIL] check-lockstep-pairs: $DRIFT_COUNT file(s) out of sync ($CHECKED checked across $TOTAL pair declarations; $SKIPPED skipped)" >&2
  exit 1
fi

echo "[OK] check-lockstep-pairs: $CHECKED file(s) verified in lock-step ($TOTAL pair declarations; $SKIPPED skipped)"
