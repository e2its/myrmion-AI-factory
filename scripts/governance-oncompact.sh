#!/usr/bin/env bash
# ============================================================================
# scripts/governance-oncompact.sh — PreCompact hook (governance always-on)
# ============================================================================
# Writes a session-scoped marker file that the next UserPromptSubmit hook
# reads to trigger re-injection of the governance snapshot as additional
# context. Pairs with scripts/governance-onprompt.sh.
#
# Marker: .claude/state/governance-reload-{session_id}.marker
#   - Gitignored (.claude/state/ is ignored entirely)
#   - Session-scoped so parallel Claude sessions on the same repo don't
#     collide on each other's post-compact replays.
#
# JSON field extraction uses a jq → python3 → awk cascade so session-scoping
# stays reliable even in minimal environments that lack python3. When all
# three parsers fail, the script emits a warning to stderr and falls back to
# an unscoped marker (best-effort Tier-3) rather than failing the hook.
# ============================================================================
set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

STATE_DIR=".claude/state"
mkdir -p "$STATE_DIR"

PAYLOAD=""
if [ ! -t 0 ]; then
  PAYLOAD=$(cat || true)
fi

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

if [ -n "$PAYLOAD" ] && [ -z "$SESSION_ID" ] && ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "governance-oncompact: neither jq nor python3 available and awk fallback could not extract session_id; falling back to unscoped marker (Tier-3 session isolation degraded). Install jq or python3." >&2
fi

SESSION_ID_SAFE=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')

if [ -n "$SESSION_ID_SAFE" ]; then
  MARKER="${STATE_DIR}/governance-reload-${SESSION_ID_SAFE}.marker"
else
  MARKER="${STATE_DIR}/governance-reload.marker"
fi

date -u +%FT%TZ > "$MARKER"
exit 0
