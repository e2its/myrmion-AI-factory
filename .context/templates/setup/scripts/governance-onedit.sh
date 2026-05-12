#!/usr/bin/env bash
# ============================================================================
# scripts/governance-onedit.sh — PostToolUse hook (governance source detector)
# ============================================================================
# Detects Edit/Write on docs/constitution.md, docs/setup.md, or
# .claude/rules/defect-prevention.md and writes a session-scoped marker so
# governance-onprompt.sh, on the NEXT prompt, can emit a
# `<governance-source-edited>` block with cause attribution + explicit regen
# instruction (Factory-governance-loading/SKILL.md § Step 1 POST-LOAD).
# When the marker is present the freshness gate's `<governance-warning>` block
# is suppressed for that prompt — the agent already knows why.
#
# Scope is intentionally narrow: only the three files whose hashes the
# freshness gate compares (`constitution_hash`, `setup_hash`, `dcs_hash`).
# Edits to other .claude/rules/** files also invalidate the snapshot body but
# are not hashed, so the freshness gate does not flag them; surfacing them
# here would emit a marker without a corresponding warning and confuse the
# agent.
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
else
  # No reliable project root → bail rather than littering the caller's CWD.
  exit 0
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

SESSION_ID_SAFE=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')

# ── Block 1 — Governance source detector (existing) ─────────────────────────
IS_GOV_SOURCE=false
case "$FILE_PATH" in
  */docs/constitution.md|docs/constitution.md|*/docs/setup.md|docs/setup.md|*/.claude/rules/defect-prevention.md|.claude/rules/defect-prevention.md)
    IS_GOV_SOURCE=true
    ;;
esac

if $IS_GOV_SOURCE; then
  mkdir -p "$STATE_DIR"

  if [ -n "$SESSION_ID_SAFE" ]; then
    MARKER="${STATE_DIR}/governance-source-edited-${SESSION_ID_SAFE}.marker"
  else
    MARKER="${STATE_DIR}/governance-source-edited.marker"
  fi

  # Normalise: strip leading ./ and any prefix outside the repo so the marker
  # carries repo-relative paths. The freshness gate's diagnostic uses the same
  # bare names ("constitution.md", "setup.md", "defect-prevention.md") — keep
  # marker entries comparable.
  NORM_PATH="$FILE_PATH"
  case "$NORM_PATH" in
    */docs/constitution.md)              NORM_PATH="docs/constitution.md" ;;
    */docs/setup.md)                     NORM_PATH="docs/setup.md" ;;
    */.claude/rules/defect-prevention.md) NORM_PATH=".claude/rules/defect-prevention.md" ;;
  esac

  {
    if [ -f "$MARKER" ]; then
      cat "$MARKER"
    fi
    printf '%s\n' "$NORM_PATH"
  } | sort -u > "${MARKER}.tmp"
  mv "${MARKER}.tmp" "$MARKER"
fi

# ── Block 2 — IPP Pillar 2 detector ─────────────────────────────────────────
# Detects subsequent writes to governance artefacts that fill sections but
# fail to advance `_progress.completed_sections`. The hook reads the file
# from disk (PostToolUse runs after the write applied) and compares filled
# H2 count against the tracker. Egregious mismatch → drop marker so the
# next UserPromptSubmit emits a corrective <ipp-warning> block.
#
# Heuristic, intentionally conservative — fires only on clear violations to
# avoid noise. False negatives acceptable (the LLM still sees the first-write
# reminder); false positives are not.
IS_IPP_ARTEFACT=false
case "$FILE_PATH" in
  */docs/spec/*/design.md|*/docs/spec/*/test_plan.md|*/docs/spec/*/dev_plan.md|\
  */docs/spec/*/increment_plan.md|*/docs/spec/*/spec.feature|\
  */docs/spec/*/user_journey.md|*/docs/spec/*/user_journey.integration.md|\
  */docs/spec/*/devops_plan.md|*/docs/spec/*/technical_due.md|\
  */docs/spec/*/qa_report*.md|*/docs/setup.md)
    IS_IPP_ARTEFACT=true
    ;;
esac

if $IS_IPP_ARTEFACT && [ -f "$FILE_PATH" ] && command -v python3 >/dev/null 2>&1; then
  VIOLATION_KIND=$(python3 - "$FILE_PATH" <<'PY' 2>/dev/null || echo ''
import re, sys
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        content = f.read()
except Exception:
    sys.exit(0)

# Extract YAML frontmatter (best-effort, no PyYAML dependency).
fm_match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if not fm_match:
    sys.exit(0)
fm = fm_match.group(1)
body = content[fm_match.end():]

# completed_sections may be inline `[]`, inline `[a, b]`, or block list.
completed_count = 0
in_progress_block = False
in_completed_list = False
for line in fm.split('\n'):
    stripped = line.strip()
    if stripped.startswith('_progress:'):
        in_progress_block = True
        continue
    if in_progress_block and line and not line.startswith(' ') and not line.startswith('\t'):
        in_progress_block = False
        in_completed_list = False
    if in_progress_block and 'completed_sections' in stripped:
        after = stripped.split(':', 1)[1].strip()
        if after.startswith('['):
            inner = after.strip('[]').strip()
            if inner:
                completed_count = len([x for x in inner.split(',') if x.strip()])
            in_completed_list = False
        else:
            in_completed_list = True
        continue
    if in_completed_list:
        if stripped.startswith('- '):
            completed_count += 1
        elif stripped and not stripped.startswith('#'):
            in_completed_list = False

# Count H2 section headers in body and PENDING markers.
h2_count = len(re.findall(r'(?m)^##[^#]', body))
pending_count = body.count('<!-- PENDING -->')
filled = h2_count - pending_count

# Violation kinds (conservative):
#  - "tracker-empty": filled >= 3 sections but completed_sections has 0 entries
#  - "tracker-lagging": filled exceeds completed by 3+ (suggests batched section writes)
if filled >= 3 and completed_count == 0:
    print('tracker-empty')
elif filled - completed_count >= 3 and filled >= 4:
    print('tracker-lagging')
PY
)

  if [ -n "$VIOLATION_KIND" ]; then
    mkdir -p "$STATE_DIR"

    if [ -n "$SESSION_ID_SAFE" ]; then
      IPP_MARKER="${STATE_DIR}/ipp-pillar2-${SESSION_ID_SAFE}.marker"
    else
      IPP_MARKER="${STATE_DIR}/ipp-pillar2.marker"
    fi

    # Repo-relative path.
    NORM_PATH="$FILE_PATH"
    REPO_ROOT=$(pwd 2>/dev/null || echo '')
    if [ -n "$REPO_ROOT" ]; then
      case "$NORM_PATH" in
        "$REPO_ROOT/"*) NORM_PATH="${NORM_PATH#$REPO_ROOT/}" ;;
      esac
    fi

    {
      if [ -f "$IPP_MARKER" ]; then cat "$IPP_MARKER"; fi
      printf '%s\t%s\n' "$NORM_PATH" "$VIOLATION_KIND"
    } | sort -u > "${IPP_MARKER}.tmp"
    mv "${IPP_MARKER}.tmp" "$IPP_MARKER"
  fi
fi

exit 0
