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

SESSION_ID=""
if command -v python3 >/dev/null 2>&1; then
  SESSION_ID=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("session_id", ""), end="")
except Exception:
    pass
' 2>/dev/null || true)
fi

SESSION_ID_SAFE=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')

if [ -n "$SESSION_ID_SAFE" ]; then
  MARKER="${STATE_DIR}/governance-reload-${SESSION_ID_SAFE}.marker"
else
  MARKER="${STATE_DIR}/governance-reload.marker"
fi

date -u +%FT%TZ > "$MARKER"
exit 0
