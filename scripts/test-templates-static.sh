#!/usr/bin/env bash
# ============================================================================
# scripts/test-templates-static.sh — L1 static template validation
# ============================================================================
# Validates that the templates shipped to materialised projects are well-formed
# under the single-source-of-truth model:
#
#   1. constitution_template.md has at least N `## [LAW]` markers in expected
#      operational sections (whitelist).
#   2. constitution_template.md does NOT mark Governance Index as `[LAW]`
#      (informational, would pollute the snapshot if embedded).
#   3. adr_template.md frontmatter requires target_section + amendment_kind.
#   4. adr_template.md has the mandatory `## Operational Rule` section.
#   5. adr_template.md has the auto-managed `## Constitution Amendment` section.
#   6. fdr_template.md exists, has feature_id frontmatter and `## Binding Rule`
#      section, and does NOT have a Constitution Amendment section.
#
# Designed to run in CI (cheap, deterministic, no fixtures beyond the templates
# themselves) and locally via `bash scripts/test-templates-static.sh`.
#
# Exit codes:
#   0 = ok
#   1 = at least one assertion failed
# ============================================================================

set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

CONSTITUTION_TPL=".context/templates/setup/constitution/constitution_template.md"
ADR_TPL=".context/templates/architect/adr_template.md"
FDR_TPL=".context/templates/architect/fdr_template.md"

failures=0
assert() {
  local condition="$1"
  local message="$2"
  if eval "$condition"; then
    printf '  \033[32m✓\033[0m %s\n' "$message"
  else
    printf '  \033[31m✗\033[0m %s\n' "$message" >&2
    failures=$((failures + 1))
  fi
}

echo "L1 static template validation"
echo

# ─── constitution_template.md ───────────────────────────────────────────────
echo "constitution_template.md"
assert "[ -f '$CONSTITUTION_TPL' ]" "file exists"

if [ -f "$CONSTITUTION_TPL" ]; then
  law_count=$(grep -c '^## \[LAW\] ' "$CONSTITUTION_TPL" || echo 0)
  assert "[ '$law_count' -ge 8 ]" "has at least 8 [LAW] sections (operational law sections — found $law_count)"

  # Whitelist of operational sections that MUST be marked [LAW]. Each entry is a
  # substring that should appear inside a `## [LAW] {something} {topic}` heading.
  for topic in "Fundamental Principles" "Stateless Design" "Project Mode" "Code Readability" "Configuration Hardcoding" "Security by Design" "Privacy" "Documentation Standards" "Dependency Management" "Branching Strategy" "Deployment"; do
    if grep -qE "^## \[LAW\] .*${topic}" "$CONSTITUTION_TPL"; then
      printf '  \033[32m✓\033[0m operational section "%s" is marked [LAW]\n' "$topic"
    else
      printf '  \033[31m✗\033[0m operational section "%s" missing [LAW] marker\n' "$topic" >&2
      failures=$((failures + 1))
    fi
  done

  # Negative: Governance Index must NOT be marked [LAW] (it's an inventory).
  if grep -qE "^## \[LAW\] .*Governance Index" "$CONSTITUTION_TPL"; then
    printf '  \033[31m✗\033[0m "Governance Index" is incorrectly marked [LAW] (must stay informational)\n' >&2
    failures=$((failures + 1))
  else
    printf '  \033[32m✓\033[0m "Governance Index" stays informational (no [LAW] marker)\n'
  fi
fi
echo

# ─── adr_template.md ────────────────────────────────────────────────────────
echo "adr_template.md"
assert "[ -f '$ADR_TPL' ]" "file exists"

if [ -f "$ADR_TPL" ]; then
  for fm_field in target_section amendment_kind status; do
    if grep -qE "^${fm_field}:" "$ADR_TPL"; then
      printf '  \033[32m✓\033[0m frontmatter field %s present\n' "$fm_field"
    else
      printf '  \033[31m✗\033[0m frontmatter field %s missing\n' "$fm_field" >&2
      failures=$((failures + 1))
    fi
  done

  for section in "## Operational Rule" "## Constitution Amendment" "## Context" "## Decision" "## Consequences"; do
    if grep -qF "$section" "$ADR_TPL"; then
      printf '  \033[32m✓\033[0m section "%s" present\n' "$section"
    else
      printf '  \033[31m✗\033[0m section "%s" missing\n' "$section" >&2
      failures=$((failures + 1))
    fi
  done

  # The new ADR template must reference Factory-adr-management Accept Procedure.
  if grep -qE "Factory-adr-management" "$ADR_TPL"; then
    printf '  \033[32m✓\033[0m references Factory-adr-management Accept Procedure\n'
  else
    printf '  \033[31m✗\033[0m does not reference Factory-adr-management — likely stale template\n' >&2
    failures=$((failures + 1))
  fi
fi
echo

# ─── fdr_template.md ────────────────────────────────────────────────────────
echo "fdr_template.md"
assert "[ -f '$FDR_TPL' ]" "file exists"

if [ -f "$FDR_TPL" ]; then
  for fm_field in feature_id fdr_number status; do
    if grep -qE "^${fm_field}:" "$FDR_TPL"; then
      printf '  \033[32m✓\033[0m frontmatter field %s present\n' "$fm_field"
    else
      printf '  \033[31m✗\033[0m frontmatter field %s missing\n' "$fm_field" >&2
      failures=$((failures + 1))
    fi
  done

  if grep -qF "## Binding Rule" "$FDR_TPL"; then
    printf '  \033[32m✓\033[0m section "## Binding Rule" present\n'
  else
    printf '  \033[31m✗\033[0m section "## Binding Rule" missing\n' >&2
    failures=$((failures + 1))
  fi

  # Negative: FDR must NOT have a Constitution Amendment section (FDRs don't
  # amend constitution — only ADRs do).
  if grep -qF "## Constitution Amendment" "$FDR_TPL"; then
    printf '  \033[31m✗\033[0m FDR template incorrectly has "## Constitution Amendment" — that section is ADR-only\n' >&2
    failures=$((failures + 1))
  else
    printf '  \033[32m✓\033[0m no "## Constitution Amendment" section (correct — FDRs do not amend constitution)\n'
  fi
fi
echo

# ─── agent_templates manifest ↔ disk coherence ──────────────────────────────
echo "agent_templates manifest ↔ disk coherence"

MANIFEST=".context/templates/setup/governance_versions.json"
if [ ! -f "$MANIFEST" ]; then
  printf '  \033[31m✗\033[0m %s missing\n' "$MANIFEST" >&2
  failures=$((failures + 1))
else
  missing=$(python3 - <<'PY'
import json, os
data = json.load(open(".context/templates/setup/governance_versions.json"))
at = data.get("agent_templates", {}) or {}
missing = []
for key in at:
  if key.startswith("_"):
    continue
  src = f".context/templates/{key}"
  if not os.path.exists(src):
    missing.append(f"{key} -> {src}")
print("\n".join(missing))
PY
  )
  if [ -z "$missing" ]; then
    count=$(python3 -c "
import json
data = json.load(open('.context/templates/setup/governance_versions.json'))
at = data.get('agent_templates', {}) or {}
print(sum(1 for k in at if not k.startswith('_')))
")
    printf '  \033[32m✓\033[0m all %s agent_templates entries have source files\n' "$count"
  else
    printf '  \033[31m✗\033[0m agent_templates entries with missing source files:\n' >&2
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      printf '      \033[31m→\033[0m %s\n' "$line" >&2
      failures=$((failures + 1))
    done <<EOF
$missing
EOF
  fi
fi
echo

# ─── runtime_artefacts manifest design coherence ────────────────────────────
echo "runtime_artefacts manifest design coherence"

if [ -f "$MANIFEST" ]; then
  bad=$(python3 - <<'PY'
import json
data = json.load(open(".context/templates/setup/governance_versions.json"))
ra = data.get("runtime_artefacts", {}) or {}
bad = []
for key, entry in ra.items():
  if key.startswith("_"):
    continue
  if not isinstance(entry, dict):
    continue
  if entry.get("bootstrap_synthesised") is not True:
    bad.append(key)
print("\n".join(bad))
PY
  )
  if [ -z "$bad" ]; then
    printf '  \033[32m✓\033[0m all runtime_artefacts entries flagged bootstrap_synthesised: true\n'
  else
    printf '  \033[31m✗\033[0m runtime_artefacts entries missing bootstrap_synthesised: true flag:\n' >&2
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      printf '      \033[31m→\033[0m %s\n' "$line" >&2
      failures=$((failures + 1))
    done <<EOF
$bad
EOF
  fi
fi
echo

# ─── Summary ────────────────────────────────────────────────────────────────
if [ "$failures" -eq 0 ]; then
  echo "L1: ok — all template assertions passed."
  exit 0
else
  echo "L1: FAIL — $failures assertion(s) failed." >&2
  exit 1
fi
