#!/usr/bin/env bash
# ============================================================================
# scripts/governance-onedit.sh — PostToolUse hook (governance source detector)
# ============================================================================
# Detects Edit/Write on docs/constitution.md or docs/setup.md and writes a
# session-scoped marker so governance-onprompt.sh, on the NEXT prompt, can
# emit a `<governance-source-edited>` block with cause attribution + explicit
# regen instruction (Factory-governance-loading/SKILL.md § Step 1 POST-LOAD).
# When the marker is present the freshness gate's `<governance-warning>` block
# is suppressed for that prompt — the agent already knows why.
#
# Scope is intentionally narrow: only the two files whose hashes the freshness
# gate compares (`constitution_hash`, `setup_hash`). Edits to .claude/rules/**
# also invalidate the snapshot body but are not hashed, so the freshness gate
# does not flag them; surfacing them here would emit a marker without a
# corresponding warning and confuse the agent.
#
# Exit policy: always exit 0. Hook is observational, never blocks.
#
# Marker file: .claude/state/governance-source-edited-${session_id}.marker
# Body:        one path per line, sorted-unique (multiple edits to the same
#              file collapse to one entry).
# ============================================================================
set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

STATE_DIR=".claude/state"

PAYLOAD=""
if [ ! -t 0 ]; then
  PAYLOAD=$(cat || true)
fi
[ -n "$PAYLOAD" ] || exit 0

# Extract a JSON field by dotted path. jq → python3 cascade. Awk has no clean
# dotted-path support so we degrade silently when neither jq nor python3 is
# available — the result is that the marker is not written and the next
# prompt falls through to the plain `<governance-warning>` path.
json_path() {
  local path="$1"
  local result=""

  if command -v jq >/dev/null 2>&1; then
    result=$(printf '%s' "$PAYLOAD" | jq -r "${path} // empty" 2>/dev/null || true)
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
    keys = [k for k in sys.argv[1].lstrip(".").split(".") if k]
    cur = data
    for k in keys:
        if isinstance(cur, dict):
            cur = cur.get(k, "")
        else:
            cur = ""
            break
    if cur is None:
        cur = ""
    print(cur, end="")
except Exception:
    pass
' "$path" 2>/dev/null || true)
    if [ -n "$result" ]; then
      printf '%s' "$result"
      return 0
    fi
  fi

  printf ''
}

SESSION_ID=$(json_path '.session_id')
FILE_PATH=$(json_path '.tool_input.file_path')

[ -n "$FILE_PATH" ] || exit 0

# Match suffix — Claude Code may pass absolute or repo-relative paths.
case "$FILE_PATH" in
  */docs/constitution.md|docs/constitution.md|*/docs/setup.md|docs/setup.md) ;;
  *) exit 0 ;;
esac

mkdir -p "$STATE_DIR"

SESSION_ID_SAFE=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')
if [ -n "$SESSION_ID_SAFE" ]; then
  MARKER="${STATE_DIR}/governance-source-edited-${SESSION_ID_SAFE}.marker"
else
  MARKER="${STATE_DIR}/governance-source-edited.marker"
fi

# Normalise: strip leading ./ and any prefix outside the repo so the marker
# carries repo-relative paths. The freshness gate's diagnostic uses the same
# bare names ("constitution.md", "setup.md") — keep marker entries comparable.
NORM_PATH="$FILE_PATH"
case "$NORM_PATH" in
  */docs/constitution.md) NORM_PATH="docs/constitution.md" ;;
  */docs/setup.md)        NORM_PATH="docs/setup.md" ;;
esac

{
  if [ -f "$MARKER" ]; then
    cat "$MARKER"
  fi
  printf '%s\n' "$NORM_PATH"
} | sort -u > "${MARKER}.tmp"
mv "${MARKER}.tmp" "$MARKER"

exit 0
