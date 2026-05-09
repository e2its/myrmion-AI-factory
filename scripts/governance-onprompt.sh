#!/usr/bin/env bash
# ============================================================================
# scripts/governance-onprompt.sh — UserPromptSubmit hook (governance always-on)
# ============================================================================
# Three jobs per prompt:
#   1. Post-compact re-inject: if the sibling PreCompact hook left a session-
#      scoped marker, emit the governance snapshot wrapped in
#      <governance-reload>...</governance-reload> so Claude Code appends it to
#      the next turn as additional context. Then consume the marker.
#   2. Source-edit attribution: if the sibling PostToolUse hook
#      (governance-onedit.sh) left a session-scoped marker, emit a
#      <governance-source-edited paths="..."> block naming the governance
#      source files (docs/constitution.md / docs/setup.md) edited in this
#      session and instructing the agent to regenerate the snapshot inline
#      via Factory-governance-loading/SKILL.md § Step 1 POST-LOAD. When this
#      block fires the freshness gate (job 3) is suppressed for this prompt:
#      the agent already knows why the snapshot is stale.
#   3. Freshness gate (advisory): delegate to validate-governance.sh
#      --snapshot-freshness. Stale snapshots are surfaced as a
#      <governance-warning reason="snapshot-stale"> block on stdout. Never
#      blocks — the hook always exits 0. Rationale: when an EVOL/ADR
#      legitimately edits governance source, a blocking gate would
#      auto-livelock the very session trying to resolve the staleness.
#
# Carve-outs (freshness gate only — marker replays always run):
#   - Prompt starts with /setup → bypass (avoid emitting the warning during
#     the recovery path that would regenerate the snapshot anyway)
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
else
  # No reliable project root → bail rather than reading/writing relative
  # paths against the caller's CWD (markers, snapshot, validate-governance).
  exit 0
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

# ── 2) Source-edit attribution (PostToolUse → onprompt) ─────────────────────
# governance-onedit.sh writes this marker when Edit/Write touched
# docs/constitution.md or docs/setup.md. Surface cause + explicit regen
# instruction so the agent connects the dots; suppresses the freshness gate
# below for this one prompt (the agent already has the information it needs).
EDIT_MARKER_SCOPED=""
[ -n "$SESSION_ID_SAFE" ] && EDIT_MARKER_SCOPED="${STATE_DIR}/governance-source-edited-${SESSION_ID_SAFE}.marker"
EDIT_MARKER_LEGACY="${STATE_DIR}/governance-source-edited.marker"

EDIT_MARKER=""
if [ -n "$EDIT_MARKER_SCOPED" ] && [ -f "$EDIT_MARKER_SCOPED" ]; then
  EDIT_MARKER="$EDIT_MARKER_SCOPED"
elif [ -f "$EDIT_MARKER_LEGACY" ]; then
  EDIT_MARKER="$EDIT_MARKER_LEGACY"
fi

EDIT_PATHS_CSV=""
if [ -n "$EDIT_MARKER" ] && [ -f "$EDIT_MARKER" ]; then
  # Allowlist filter — `.claude/state/` is user-writable, so a tampered or
  # legacy marker could carry arbitrary lines (quotes, `>`, newlines) that
  # would break the `<governance-source-edited paths="...">` tag or inject
  # content into the model-facing block. Only known governance source paths
  # are accepted; everything else is dropped silently.
  EDIT_PATHS_FILTERED=$(awk '$0 == "docs/constitution.md" || $0 == "docs/setup.md"' "$EDIT_MARKER" | sort -u)
  if [ -n "$EDIT_PATHS_FILTERED" ]; then
    EDIT_PATHS_CSV=$(printf '%s' "$EDIT_PATHS_FILTERED" | tr '\n' ',' | sed 's/,$//; s/,/, /g')
    echo "<governance-source-edited paths=\"${EDIT_PATHS_CSV}\">"
    echo "Governance source was edited in this session. The snapshot is now stale by definition."
    echo "Regenerate inline before continuing — factory-governance-loading SKILL § Step 1 POST-LOAD"
    echo "(generate_governance_snapshot()). This does NOT require running /setup --upgrade."
    echo "</governance-source-edited>"
  fi
  rm -f "$EDIT_MARKER"
fi

# ── 3) Livelock carve-out ───────────────────────────────────────────────────
trimmed=$(printf '%s' "$PROMPT_TEXT" | sed -E 's/^[[:space:]]+//')
case "$trimmed" in
  /setup*|/loop\ /setup*|/loop\ \"/setup*)
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Freshness gate — advisory only, never blocks the turn. Runs by default,
# suppressed when the source-edit marker already attributed the cause for
# this prompt. Stale snapshots are surfaced to the model as a tagged warning
# block via stdout so Claude can react (inform the user, regenerate when
# appropriate, avoid stale assumptions about governance).
# ---------------------------------------------------------------------------
if [ -z "$EDIT_PATHS_CSV" ]; then
  set +e
  FRESHNESS_OUTPUT="$(bash scripts/validate-governance.sh --snapshot-freshness 2>&1)"
  FRESHNESS_EXIT=$?
  set -e

  if [ "$FRESHNESS_EXIT" -ne 0 ]; then
    echo "<governance-warning reason=\"snapshot-stale\">"
    echo "$FRESHNESS_OUTPUT"
    echo "</governance-warning>"
  else
    # Positive confirmation tag — emitted to the model as additional context so
    # the agent knows governance is fresh in this turn (counterpart to the
    # warning block above; same observational discipline, opposite signal).
    # Counts mirror the SessionStart banner so the agent sees the same digest
    # mid-session as the user sees on screen.
    if [ -f "$SNAPSHOT" ]; then
      law_count=$(grep -cE '^## \[LAW\] ' "$SNAPSHOT" 2>/dev/null || printf '0')
      dcs_count=$(awk '/^## Defect Prevention Catalog/{f=1; next} f && /^## /{f=0} f && /^### DC-/{c++} END{print c+0}' "$SNAPSHOT" 2>/dev/null || printf '0')
      echo "<governance-loaded snapshot=\"fresh\" law-sections=\"${law_count}\" universal-dcs=\"${dcs_count}\" />"
    elif [ -f "CLAUDE.md" ] && [ ! -f "docs/constitution.md" ]; then
      # Meta context — no snapshot by design, root CLAUDE.md is the source.
      echo "<governance-loaded context=\"meta\" />"
    fi
  fi
fi

exit 0
