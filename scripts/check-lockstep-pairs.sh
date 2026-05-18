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
#   - universal_clause_mirror  : DEFERRED — clause extraction not yet
#                                 implemented. INFO log, SKIPPED.
#   - meta_to_downstream_via_sync : informational only. INFO log, SKIPPED.
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
      echo "[INFO] skipping universal_clause_mirror (clause extraction not yet implemented): $LEFT <> $RIGHT" >&2
      SKIPPED=$((SKIPPED + 1))
      ;;
    meta_to_downstream_via_sync)
      echo "[INFO] skipping meta_to_downstream_via_sync (informational, no parity to enforce): $LEFT <> $RIGHT" >&2
      SKIPPED=$((SKIPPED + 1))
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
