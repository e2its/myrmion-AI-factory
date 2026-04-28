#!/usr/bin/env bash
# check-push-preflight.sh — PreToolUse Bash hook: Factory PR Review push gate (v1.0.0)
# ============================================================================
# Reads stdin JSON from Claude Code hook protocol.
# When the Bash command contains `git push`, runs the Factory-pr-review
# preflight script. Hard-blocker findings exit 1 (block); other outcomes
# pass through. Tool-call failures (preflight exit 2) are treated as
# warnings, NOT blocks (defence-in-depth must not break legitimate pushes).
# ============================================================================

set -u

# Read stdin JSON (Claude Code passes the tool call here)
INPUT="$(cat)"

# Best-effort parse: extract tool_input.command
CMD=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    pass
' 2>/dev/null)

# If no command parsed, pass through silently
if [ -z "$CMD" ]; then
  exit 0
fi

# Match `git push` as a token (start, after ;, &&, ||, or whitespace) — not `git pushblahblah`
# Also match piped/subshell forms (`(git push …)`, `bash -c 'git push …'` is best-effort).
if ! echo "$CMD" | grep -qE '(^|[[:space:]]|;|&&|\|\||\()git[[:space:]]+push([[:space:]]|$)'; then
  exit 0
fi

# Skip dry-run pushes (--dry-run is harmless and may be used for diagnostics)
if echo "$CMD" | grep -qE 'git[[:space:]]+push[[:space:]].*--dry-run'; then
  exit 0
fi

# Locate preflight script
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
if [ -z "$REPO_ROOT" ]; then
  exit 0
fi
PREFLIGHT="$REPO_ROOT/.claude/skills/Factory-pr-review/scripts/preflight.sh"
if [ ! -x "$PREFLIGHT" ]; then
  # Skill not installed in this project — pass through silently.
  exit 0
fi

# Run preflight quietly; capture output and exit code
OUTPUT="$("$PREFLIGHT" 2>&1)"
RC=$?

case $RC in
  0)
    # No blockers — push proceeds. Stay silent unless verbose.
    exit 0
    ;;
  2)
    # Tooling/environment failure (detached HEAD, no python, etc.) — warn, don't block.
    echo "Factory PR Review preflight: skipped (environment) — push proceeds."
    exit 0
    ;;
  1)
    # Blockers found — block the push with humanised message.
    cat <<EOF
🛑 Push blocked by Factory PR Review (preflight).

Hard-blocker findings on this branch must be fixed locally before pushing.
This is a quality gate — it runs against \`origin/main..HEAD\` and catches
issues that would otherwise hit the PR review.

$OUTPUT

Resolution path:
  1. Read the findings above. Each blocker cites a category (e.g. governance-bump-miss,
     openapi-missing, secrets, protected-path) and a concrete fix direction.
  2. Apply the fix locally and commit.
  3. Re-run the push. The gate runs fresh on each attempt.

To inspect findings without pushing:
  bash .claude/skills/Factory-pr-review/scripts/preflight.sh --json

To bypass intentionally (rare — for hotfix or recovery):
  git -c core.hooksPath=/dev/null push …
  (this DOES NOT bypass the harness PreToolUse hook; the user must approve.)
EOF
    exit 1
    ;;
  *)
    # Unknown exit — fail open (don't block on unexpected behaviour).
    exit 0
    ;;
esac
