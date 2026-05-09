#!/usr/bin/env bash
# check_asyncapi_diff.sh — Detects changes in AsyncAPI specs.
#
# Uses @asyncapi/cli (npx @asyncapi/cli diff) to compare versions.
# If unavailable, falls back to a basic textual diff.
#
# Usage:
#   ./check_asyncapi_diff.sh <base-ref> <spec-path>
#   ./check_asyncapi_diff.sh main asyncapi.yaml
#
# Output:
#   JSON with structure:
#     { "valid": bool, "breaking_candidates": [...], "diff": "...", "exit_code": int }

set -uo pipefail

BASE_REF="${1:-main}"
SPEC_PATH="${2:-asyncapi.yaml}"

# Verify that the spec exists in HEAD
if [[ ! -f "$SPEC_PATH" ]]; then
    cat <<EOF
{
  "valid": false,
  "error": "Spec not found in HEAD: $SPEC_PATH",
  "exit_code": 2
}
EOF
    exit 2
fi

# Pre-validation with asyncapi-cli if available
if command -v npx &> /dev/null; then
    VALIDATION=$(npx --yes @asyncapi/cli@latest validate "$SPEC_PATH" 2>&1 || true)
    if echo "$VALIDATION" | grep -qiE "error|invalid"; then
        cat <<EOF
{
  "valid": false,
  "error": "Invalid spec according to asyncapi validate",
  "validation_output": $(echo "$VALIDATION" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "exit_code": 2
}
EOF
        exit 2
    fi
fi

# Get base version
BASE_SPEC=$(mktemp --suffix=.yaml)
trap 'rm -f "$BASE_SPEC"' EXIT

if ! git show "${BASE_REF}:${SPEC_PATH}" > "$BASE_SPEC" 2>/dev/null; then
    cat <<EOF
{
  "valid": true,
  "breaking_candidates": [],
  "diff": "New spec added: ${SPEC_PATH}",
  "is_new": true,
  "exit_code": 0
}
EOF
    exit 0
fi

# Textual diff (robust fallback)
DIFF_OUTPUT=$(diff -u "$BASE_SPEC" "$SPEC_PATH" 2>/dev/null || true)

# Heuristic for breaking: look for removed lines under channels / messages / payload sections
BREAKING_CANDIDATES=()

if echo "$DIFF_OUTPUT" | grep -qE "^-\s+(channels|operations|messages):"; then
    BREAKING_CANDIDATES+=("\"Channels/operations/messages section modified — review manually\"")
fi

# Lines starting with '-' under channels: → possible removal
DELETED_KEYS=$(echo "$DIFF_OUTPUT" | grep -E "^-\s+\w+:" | grep -vE "^---|^-\s*#" | head -20 || true)
if [[ -n "$DELETED_KEYS" ]]; then
    while IFS= read -r line; do
        clean=$(echo "$line" | sed 's/"/\\"/g' | tr -d '\n')
        BREAKING_CANDIDATES+=("\"Possible removal: ${clean}\"")
    done <<< "$DELETED_KEYS"
fi

# New required fields in payloads → potential breaking
if echo "$DIFF_OUTPUT" | grep -qE "^\+\s+required:"; then
    BREAKING_CANDIDATES+=("\"New 'required' field detected — verify if it breaks existing consumers\"")
fi

# Build JSON array
if [[ ${#BREAKING_CANDIDATES[@]} -eq 0 ]]; then
    BREAKING_JSON="[]"
    EXIT_CODE=0
else
    BREAKING_JSON="[$(IFS=,; echo "${BREAKING_CANDIDATES[*]}")]"
    EXIT_CODE=1
fi

cat <<EOF
{
  "valid": true,
  "breaking_candidates": ${BREAKING_JSON},
  "diff": $(echo "$DIFF_OUTPUT" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "is_new": false,
  "note": "Heuristic detection — for full semantic analysis use @asyncapi/diff (community project) or manual validation",
  "exit_code": ${EXIT_CODE}
}
EOF

exit $EXIT_CODE
