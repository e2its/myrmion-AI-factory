#!/usr/bin/env bash
# check_openapi_diff.sh — Detects breaking changes in OpenAPI using oasdiff.
#
# Requires oasdiff installed: https://github.com/oasdiff/oasdiff
#   brew install oasdiff
#   or: go install github.com/oasdiff/oasdiff@latest
#
# Usage:
#   ./check_openapi_diff.sh <base-ref> <spec-path>
#   ./check_openapi_diff.sh main openapi.yaml
#   ./check_openapi_diff.sh origin/main api/openapi.yaml
#
# Output:
#   Prints JSON to stdout with the structure:
#     { "valid": bool, "breaking": [...], "changelog": "...", "exit_code": int }
#
# Exit codes:
#   0 — no changes or only non-breaking changes
#   1 — breaking changes detected
#   2 — validation or tooling error

set -uo pipefail

BASE_REF="${1:-main}"
SPEC_PATH="${2:-openapi.yaml}"

# Verify that oasdiff is installed
if ! command -v oasdiff &> /dev/null; then
    cat <<EOF
{
  "valid": false,
  "error": "oasdiff is not installed. Install it with: brew install oasdiff",
  "exit_code": 2
}
EOF
    exit 2
fi

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

# Get the base version
BASE_SPEC=$(mktemp --suffix=.yaml)
trap 'rm -f "$BASE_SPEC"' EXIT

if ! git show "${BASE_REF}:${SPEC_PATH}" > "$BASE_SPEC" 2>/dev/null; then
    # The spec doesn't exist at base — it's new, no breaking changes
    cat <<EOF
{
  "valid": true,
  "breaking": [],
  "changelog": "New spec added: ${SPEC_PATH}",
  "is_new": true,
  "exit_code": 0
}
EOF
    exit 0
fi

# Validation: that both specs are valid OpenAPI
# (oasdiff does an implicit validation when parsing)

# Detect breaking changes
BREAKING_OUTPUT=$(oasdiff breaking "$BASE_SPEC" "$SPEC_PATH" --format json 2>&1)
BREAKING_EXIT=$?

# Generate full changelog (all changes, not just breaking)
CHANGELOG_OUTPUT=$(oasdiff changelog "$BASE_SPEC" "$SPEC_PATH" --format text 2>&1)

# Build JSON response
if [[ $BREAKING_EXIT -eq 0 ]] || [[ -z "$BREAKING_OUTPUT" ]] || [[ "$BREAKING_OUTPUT" == "[]" ]]; then
    cat <<EOF
{
  "valid": true,
  "breaking": [],
  "changelog": $(echo "$CHANGELOG_OUTPUT" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "is_new": false,
  "exit_code": 0
}
EOF
    exit 0
else
    # There are breaking changes — return JSON as-is + the changelog
    cat <<EOF
{
  "valid": true,
  "breaking": ${BREAKING_OUTPUT},
  "changelog": $(echo "$CHANGELOG_OUTPUT" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
  "is_new": false,
  "exit_code": 1
}
EOF
    exit 1
fi
