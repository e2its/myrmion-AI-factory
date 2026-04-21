#!/usr/bin/env bash
# ============================================================================
# scripts/governance-onprompt.sh — UserPromptSubmit hook (governance always-on)
# ============================================================================
# Two jobs per prompt:
#   1. Post-compact re-inject: if the sibling PreCompact hook left a session-
#      scoped marker, emit the governance snapshot wrapped in
#      <governance-reload>...</governance-reload> so Claude Code appends it to
#      the next turn as additional context. Then consume the marker.
#   2. Freshness gate: delegate to validate-governance.sh --snapshot-freshness.
#      Exit 2 on stale — blocks the prompt.
#
# Carve-outs (freshness gate only — marker replay always runs):
#   - Prompt starts with /setup → bypass (avoid livelock on recovery path)
#
# Marker lives in .claude/state/ (Claude Code hook namespace, gitignored) and
# is session-scoped (suffixed with session_id) to avoid collisions when
# multiple Claude sessions run against the same repo.
#
# JSON field extraction uses a jq → python3 → awk cascade so session-scoping
# and the /setup livelock carve-out stay reliable even in minimal environments
# that lack python3.
# ============================================================================
set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

SNAPSHOT=".context/governance_snapshot.md"
STATE_DIR=".claude/state"

# Claude Code passes hook payload as JSON on stdin: { session_id, prompt, ... }
PAYLOAD=""
if [ ! -t 0 ]; then
  PAYLOAD=$(cat || true)
fi

# Extract a string-valued JSON field from the payload. Tries jq → python3 →
# awk (simple-JSON regex) in that order. Awk fallback assumes the value does
# not contain an unescaped closing quote; this holds for session_id (UUID) and
# for the leading bytes of `prompt` that we need for `/setup*` detection.
json_field() {
  local field="$1"
  local result=""
  [ -n "$PAYLOAD" ] || { echo ""; return 0; }

  if command -v jq >/dev/null 2>&1; then
    result=$(printf '%s' "$PAYLOAD" | jq -r ".${field} // empty" 2>/dev/null || true)
    if [ -n "$result" ]; then
      printf '%s' "$result"
      return 0
    fi
  fi

  if command -v python3 >/dev/null 2>&1; then
    result=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    value = data.get(sys.argv[1], "")
    if value is None:
        value = ""
    print(value, end="")
except Exception:
    pass
' "$field" 2>/dev/null || true)
    if [ -n "$result" ]; then
      printf '%s' "$result"
      return 0
    fi
  fi

  # Awk fallback — collapses newlines, regex-matches `"field":"..."`. Returns
  # empty when the payload is not valid simple JSON or when the value contains
  # an unescaped quote (acceptable degradation for UUID-like session_id and
  # the leading bytes of a `/setup*` prompt).
  printf '%s' "$PAYLOAD" | tr '\n' ' ' | awk -v f="$field" '
    {
      pat = "\"" f "\"[[:space:]]*:[[:space:]]*\"[^\"]*\""
      if (match($0, pat)) {
        v = substr($0, RSTART, RLENGTH)
        sub("\"" f "\"[[:space:]]*:[[:space:]]*\"", "", v)
        sub("\"$", "", v)
        print v
      }
    }
  '
}

SESSION_ID=$(json_field session_id)
PROMPT_TEXT=$(json_field prompt)

if [ -n "$PAYLOAD" ] && [ -z "$SESSION_ID" ] && ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "governance-onprompt: neither jq nor python3 available and awk fallback could not parse the hook payload; session-scoped marker replay degraded, /setup livelock carve-out may not trigger. Install jq or python3." >&2
fi

SESSION_ID_SAFE=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')

# ── 1) Post-compact re-inject ───────────────────────────────────────────────
# Prefer session-scoped marker; fall back to legacy unscoped marker if present.
MARKER_SCOPED=""
[ -n "$SESSION_ID_SAFE" ] && MARKER_SCOPED="${STATE_DIR}/governance-reload-${SESSION_ID_SAFE}.marker"
MARKER_LEGACY="${STATE_DIR}/governance-reload.marker"

MARKER=""
if [ -n "$MARKER_SCOPED" ] && [ -f "$MARKER_SCOPED" ]; then
  MARKER="$MARKER_SCOPED"
elif [ -f "$MARKER_LEGACY" ]; then
  MARKER="$MARKER_LEGACY"
fi

if [ -n "$MARKER" ] && [ -f "$SNAPSHOT" ]; then
  echo "<governance-reload>"
  cat "$SNAPSHOT"
  echo "</governance-reload>"
  rm -f "$MARKER"
fi

# ── 2) Livelock carve-out ───────────────────────────────────────────────────
trimmed=$(printf '%s' "$PROMPT_TEXT" | sed -E 's/^[[:space:]]+//')
case "$trimmed" in
  /setup*|/loop\ /setup*|/loop\ \"/setup*)
    exit 0
    ;;
esac

# ── 3) Freshness gate ───────────────────────────────────────────────────────
exec bash scripts/validate-governance.sh --snapshot-freshness
