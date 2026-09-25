#!/usr/bin/env bash
# ============================================================================
# scripts/test-templates-static.sh — L1 static template validation
# ============================================================================
# Validates that the templates shipped to materialised projects are well-formed
# under the single-source-of-truth model:
#
#   1. constitution_template.md is the INDEX: ≥ N `## [PLAW-NN]` entries in the expected
#      operational sections (whitelist).
#   2. every entry = heading + `> sentence` + Body/Records line; every pointer resolves and quotes the sentence
#      (informational, would pollute the snapshot if embedded).
#   3. adr_template.md frontmatter requires target_section + amendment_kind.
#   4. adr_template.md has the mandatory `## Operational Rule` section.
#   5. adr_template.md has the auto-managed `## Constitution Amendment` section.
#   6. fdr_template.md exists, has feature_id frontmatter and `## Binding Rule`
#      section, and does NOT have a Constitution Amendment section.
#   7. the GitHub Projects backlog adapter links the board it creates to the
#      repository.
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

# ─── constitution_template.md — the INDEX of project law (EVOL-043) ──────────
echo "constitution_template.md"
if [ ! -f "$CONSTITUTION_TPL" ]; then
  fail "missing $CONSTITUTION_TPL"
else
  law_count=$(grep -cE '^## \[PLAW-[0-9]{2}\] ' "$CONSTITUTION_TPL" || echo 0)
  assert "[ '$law_count' -ge 8 ]" "has at least 8 [PLAW-NN] index entries (found $law_count)"
  # shape: heading → `> sentence` → `Body: \`pointer\` · Records: \`ids\``
  shape_bad=$(awk '
    /^## \[PLAW-[0-9][0-9]\] / { id=$2; getline s; getline b;
      if (s !~ /^> ./) print id " sentence line missing";
      if (b !~ /^Body: `(rules\/[A-Za-z0-9_.-]+\.md|\.claude\/(skills|instructions)\/[^`]+\.md|inline)` · Records: `[A-Z0-9-]+`(, `[A-Z0-9-]+`)*$/) print id " body/records line malformed: " b }
  ' "$CONSTITUTION_TPL")
  assert "[ -z '$shape_bad' ]" "every entry is heading + sentence + Body/Records line${shape_bad:+ — $shape_bad}"
  # every Body: pointer resolves to a file that carries the identical sentence under the same id
  ptr_bad=$(python3 - "$CONSTITUTION_TPL" <<'PY'
import sys, re, pathlib
text = pathlib.Path(sys.argv[1]).read_text()
lines = text.splitlines(); bad = []
for i, ln in enumerate(lines):
    m = re.match(r"^## \[(PLAW-\d\d)\] (.+)$", ln)
    if not m: continue
    sent = lines[i+1][2:].strip(); ptr = re.search(r"Body: `([^`]+)`", lines[i+2]).group(1)
    if ptr == "inline": continue
    f = pathlib.Path(".context/templates/setup/" + ptr if ptr.startswith("rules/") else ptr)
    if not f.is_file(): bad.append(f"{m.group(1)} → {ptr} missing"); continue
    body = f.read_text().splitlines()
    hit = [j for j, l in enumerate(body) if re.match(r"^#{2,4} \[" + m.group(1) + r"\]", l)]
    if not hit: bad.append(f"{m.group(1)} heading absent in {ptr}"); continue
    quoted = next((l[2:].strip() for l in body[hit[0]+1:hit[0]+4] if l.startswith("> ")), None)
    if quoted != sent: bad.append(f"{m.group(1)} sentence differs in {ptr}")
    if len(sent) > 240: bad.append(f"{m.group(1)} sentence over 240 chars")
print("; ".join(bad))
PY
)
  assert "[ -z '$ptr_bad' ]" "every Body: pointer resolves and quotes the identical sentence${ptr_bad:+ — $ptr_bad}"
  for topic in "KISS" "Stateless" "Security" "Privacy" "Branching" "Deployment" "QA Per-Increment" "Configuration"; do
    if grep -qE "^## \[PLAW-[0-9]{2}\] .*${topic}" "$CONSTITUTION_TPL"; then
      printf '  \033[32m✓\033[0m law "%s" indexed\n' "$topic"
    else
      printf '  \033[31m✗\033[0m law "%s" missing from the index\n' "$topic" >&2; failures=$((failures + 1))
    fi
  done
  # retired shapes never come back
  if grep -qE '^## \[LAW\] |Governance Index \(Auto' "$CONSTITUTION_TPL"; then
    printf '  \033[31m✗\033[0m retired shape present (`## [LAW]` bodies or the auto-generated index)\n' >&2; failures=$((failures + 1))
  else
    printf '  \033[32m✓\033[0m no retired shape (bodies live in rules/, the constitution is the index)\n'
  fi
  # placeholders only inside frontmatter / template blocks
  if awk 'NR>1 && /^---$/ && !d {d=1; next} d && /\{\{[A-Z_]+\}\}/ {bad=1} END {exit bad}' "$CONSTITUTION_TPL"; then
    printf '  \033[32m✓\033[0m no placeholder token outside the frontmatter\n'
  else
    printf '  \033[31m✗\033[0m placeholder token in the index body\n' >&2; failures=$((failures + 1))
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

  # The new ADR template must reference factory-adr-management Accept Procedure.
  if grep -qE "factory-adr-management" "$ADR_TPL"; then
    printf '  \033[32m✓\033[0m references factory-adr-management Accept Procedure\n'
  else
    printf '  \033[31m✗\033[0m does not reference factory-adr-management — likely stale template\n' >&2
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

# ─── backlog adapter: GitHub Projects board linked to its repository ───────
echo "backlog-tool-adapters/github-project.md"
GH_ADAPTER=".context/templates/setup/backlog-tool-adapters/github-project.md"
assert "[ -f '$GH_ADAPTER' ]" "file exists"
if [ -f "$GH_ADAPTER" ]; then
  gh_create=$(awk '/^#### `create_project`/{f=1; next} f && /^#### /{exit} f' "$GH_ADAPTER")
  assert "printf '%s' \"\$gh_create\" | grep -qxE 'gh project link \\{\\{PROJECT_NUMBER\\}\\} --owner \\{\\{ORG_OR_USER\\}\\} --repo \\{\\{REPO_SLUG\\}\\}'" \
    "create_project links the new board to the repository (a board created alone is missing from the repo's Projects tab)"
  assert "printf '%s' \"\$gh_create\" | grep -qF 'repositories(first:50){ nodes { nameWithOwner } }' && printf '%s' \"\$gh_create\" | grep -qF 'never re-run'" \
    "create_project verifies the link from the project side and never recovers by creating a second board"
fi
echo

# ─── Every workflow file parses (EVOL-046: an unquoted step name with a colon failed a CI run at 0 s) ───
YAML_RC=$(python3 - <<'PY'
import glob, sys
try:
    import yaml
except ImportError:
    print("skip"); sys.exit(0)
bad = []
for f in glob.glob(".github/workflows/*.yml") + glob.glob(".context/templates/setup/workflows/*.yml") + glob.glob(".context/templates/setup/workflows/*.yaml"):
    try:
        yaml.safe_load(open(f, encoding="utf-8"))
    except Exception as e:
        bad.append(f"{f}: {str(e).splitlines()[0][:100]}")
print("\n".join(bad) if bad else "ok")
PY
)
if [ "$YAML_RC" = "ok" ]; then
  printf '  \033[32m✓\033[0m every workflow file (meta + every platform template) parses as YAML\n'
elif [ "$YAML_RC" = "skip" ]; then
  printf '  \033[33m·\033[0m PyYAML absent — workflow YAML parse check skipped\n'
else
  printf '  \033[31m✗\033[0m a workflow file does not parse:\n%s\n' "$YAML_RC" >&2; failures=$((failures + 1))
fi
echo

# ─── EVOL-054: the profile step exports the Actions token (meta workflow AND the shipped template) — scm-protection reads the rulesets at ci; a step without the token is n/a forever ───
for wf in .github/workflows/governance-check.yml .context/templates/setup/workflows/governance-check.github-actions.yml; do
  if python3 - "$wf" <<'PYEOF'
import sys
try:
    import yaml
except ImportError:
    sys.exit(0)
d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
steps = d["jobs"]["governance-check"]["steps"]
ok = any("profile --run" in (s.get("run") or "") and (s.get("env") or {}).get("GH_TOKEN") == "${{ github.token }}" for s in steps)
sys.exit(0 if ok else 1)
PYEOF
  then printf '  \033[32m✓\033[0m %s exports GH_TOKEN on the profile step\n' "$wf"
  else printf '  \033[31m✗\033[0m %s does not export GH_TOKEN on the profile step (scm-protection n/a forever at ci)\n' "$wf" >&2; failures=$((failures + 1)); fi
done
# the five runbooks use only the placeholders the materialisation resolves (a misspelled token would land verbatim)
BAD_TOKENS=$(grep -ohE '\{\{[A-Za-z_]+\}\}' .context/templates/setup/scm/protection.*.md | sort -u | grep -vE '^\{\{(SCM_PLATFORM|SCM_REQUIRED_CHECKS|SCM_APPROVALS)\}\}$' || true)
if [ -z "$BAD_TOKENS" ]; then printf '  \033[32m✓\033[0m the SCM runbooks carry only the three SCM placeholders\n'
else printf '  \033[31m✗\033[0m unknown placeholder(s) in the SCM runbooks: %s\n' "$(echo "$BAD_TOKENS" | tr '\n' ' ')" >&2; failures=$((failures + 1)); fi
echo

# ─── dev_plan carries the governance digest key IMPLEMENT --plan writes (EVOL-051: one source for the key, judged by gate.py digests when listed) ───
if grep -q '^governance_digest_version:' .context/templates/develop/dev_plan_template.md; then
  printf '  \033[32m✓\033[0m dev_plan_template.md frontmatter carries governance_digest_version\n'
else
  printf '  \033[31m✗\033[0m dev_plan_template.md frontmatter lacks governance_digest_version (Factory-implement-plan writes it; two sources)\n' >&2; failures=$((failures + 1))
fi
echo

# ─── Every tree/worktree certification in the governed prose carries its paths (EVOL-049: `certify --subject tree` alone faults — a guard that faults never refuses) ───
BARE=$(grep -rnE 'certify --subject (tree|worktree)' .claude .context/templates/setup --include=*.md --include=*.sh 2>/dev/null | grep -vE 'certify --subject (tree|worktree) --paths' | grep -vE 'certify --subject (tree|worktree)[ |]*\[--' || true)
if [ -z "$BARE" ]; then
  printf '  \033[32m✓\033[0m every `certify --subject tree|worktree` call in .claude/** and the template tree names its --paths\n'
else
  printf '  \033[31m✗\033[0m a tree/worktree certification without --paths (it faults at runtime, the guard never refuses):\n%s\n' "$BARE" >&2; failures=$((failures + 1))
fi
echo

# ─── The runtime-surface gate line of every deploying template really skips (EVOL-047: `$?` inside `if ! cmd` is 0 — the first cut never did) ───
STUBDIR=$(mktemp -d); printf '#!/usr/bin/env bash\nexit "${STUB_RC:-0}"\n' > "$STUBDIR/python3"; chmod +x "$STUBDIR/python3"
for wf in .context/templates/setup/workflows/auto-tag.gitlab-ci.yml .context/templates/setup/workflows/auto-tag.azure-devops.yml .context/templates/setup/workflows/auto-tag.bitbucket.yml .context/templates/setup/workflows/auto-tag.gcp-cloudbuild.yaml .context/templates/setup/workflows/auto-tag.aws-codebuild.yml .context/templates/setup/workflows/auto-tag.jenkins.groovy; do
  LINE=$(grep -m1 'runtime-surface --changed.*|| rc=' "$wf" | sed -E "s/^[[:space:]]*(- )?'?//; s/'$//; s/\\\$\\\$/\$/g")
  OUT=$(cd "$STUBDIR" && PATH="$STUBDIR:$PATH" STUB_RC=1 bash -c "$LINE; echo REACHED-THE-TAG" 2>&1); RC=$?
  if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'outside the runtime surface' && ! printf '%s' "$OUT" | grep -q 'REACHED-THE-TAG'; then
    printf '  \033[32m✓\033[0m %s: untouched (exit 1) skips the tag script\n' "$(basename "$wf")"
  else printf '  \033[31m✗\033[0m %s: untouched did not skip (rc=%s): %s\n' "$(basename "$wf")" "$RC" "$OUT" >&2; failures=$((failures + 1)); fi
  OUT=$(cd "$STUBDIR" && PATH="$STUBDIR:$PATH" STUB_RC=2 bash -c "$LINE; echo REACHED-THE-TAG" 2>&1); RC=$?
  if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'could not judge (exit 2)' && printf '%s' "$OUT" | grep -q 'REACHED-THE-TAG'; then
    printf '  \033[32m✓\033[0m %s: a fault (exit 2) says so and tags to be safe\n' "$(basename "$wf")"
  else printf '  \033[31m✗\033[0m %s: fault lane wrong (rc=%s): %s\n' "$(basename "$wf")" "$RC" "$OUT" >&2; failures=$((failures + 1)); fi
  OUT=$(cd "$STUBDIR" && PATH="$STUBDIR:$PATH" STUB_RC=0 bash -c "$LINE; echo REACHED-THE-TAG" 2>&1); RC=$?
  if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'REACHED-THE-TAG' && ! printf '%s' "$OUT" | grep -qE 'outside|could not'; then
    printf '  \033[32m✓\033[0m %s: touched (exit 0) proceeds silently\n' "$(basename "$wf")"
  else printf '  \033[31m✗\033[0m %s: touched lane wrong (rc=%s): %s\n' "$(basename "$wf")" "$RC" "$OUT" >&2; failures=$((failures + 1)); fi
done
for wf in .github/workflows/auto-tag.yml .context/templates/setup/workflows/auto-tag.github-actions.yml; do
  BLOCK=$(awk '/set \+e; python3 scripts\/gate.py runtime-surface/{p=1} p{print} /esac/{if(p){exit}}' "$wf")
  OUTF=$(mktemp); OUT=$(cd "$STUBDIR" && PATH="$STUBDIR:$PATH" STUB_RC=1 GITHUB_OUTPUT="$OUTF" BASE=HEAD^1 bash -c "$BLOCK" 2>&1); RC=$?
  if [ "$RC" -eq 0 ] && grep -q 'touched=false' "$OUTF"; then printf '  \033[32m✓\033[0m %s: untouched → touched=false (the machinery steps are skipped by if:)\n' "$(basename "$wf")"
  else printf '  \033[31m✗\033[0m %s: GitHub gate step wrong (rc=%s): %s\n' "$(basename "$wf")" "$RC" "$OUT $(cat "$OUTF")" >&2; failures=$((failures + 1)); fi
  : > "$OUTF"; OUT=$(cd "$STUBDIR" && PATH="$STUBDIR:$PATH" STUB_RC=2 GITHUB_OUTPUT="$OUTF" BASE=HEAD^1 bash -c "$BLOCK" 2>&1); RC=$?
  if [ "$RC" -eq 0 ] && grep -q 'touched=true' "$OUTF"; then printf '  \033[32m✓\033[0m %s: a fault → touched=true (tag to be safe)\n' "$(basename "$wf")"
  else printf '  \033[31m✗\033[0m %s: GitHub fault lane wrong (rc=%s)\n' "$(basename "$wf")" "$RC" >&2; failures=$((failures + 1)); fi
  rm -f "$OUTF"
done
rm -rf "$STUBDIR"
echo

# ─── Summary ────────────────────────────────────────────────────────────────
if [ "$failures" -eq 0 ]; then
  echo "L1: ok — all template assertions passed."
  exit 0
else
  echo "L1: FAIL — $failures assertion(s) failed." >&2
  exit 1
fi
