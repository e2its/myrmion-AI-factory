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

parse_json_field() {
  local field="$1"
  printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
field = sys.argv[1]
try:
    data = json.load(sys.stdin)
    print(data.get(field, ""), end="")
except Exception:
    pass
' "$field" 2>/dev/null || true
}

SESSION_ID=""
PROMPT_TEXT=""
if command -v python3 >/dev/null 2>&1; then
  SESSION_ID=$(parse_json_field session_id)
  PROMPT_TEXT=$(parse_json_field prompt)
fi

# Sanitize session_id for filename use (alnum + dash + underscore only).
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
