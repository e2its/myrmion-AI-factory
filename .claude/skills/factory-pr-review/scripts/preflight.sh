#!/usr/bin/env bash
# preflight.sh — Factory PR Review push-gate orchestrator (v1.1.3)
#
# Runs the local quality gate before `git push`. Aggregates findings from:
#   - detect_change_type.py     (classification + secrets heuristic)
#   - check_docs_sync.py        (code ↔ docs drift)
#   - check_openapi_diff.sh     (when has_openapi)
#   - check_asyncapi_diff.sh    (when has_asyncapi)
#   - framework-aware checks    (governance bump, branch protection, protected paths)
#
# Usage:
#   preflight.sh [--base origin/main] [--json] [--quiet]
#
# Exit codes:
#   0 — no blockers, push proceeds
#   1 — blockers found, push blocked
#   2 — tooling/environment failure (NOT a blocker; calling hook should warn, not block)
#
# Invoked by: .claude/hooks/check-push-preflight.sh (auto on `git push`)
# Also runnable manually for debugging.

set -uo pipefail

# ── Paths ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Args ──
BASE_REF=""
OUTPUT_JSON=false
QUIET=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)   BASE_REF="$2"; shift 2 ;;
    --json)   OUTPUT_JSON=true; shift ;;
    --quiet)  QUIET=true; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "preflight: unknown arg $1" >&2; exit 2 ;;
  esac
done

log() { [[ "$QUIET" == "true" ]] || echo "$@" >&2; }

# ── Repo root ──
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
if [[ -z "$REPO_ROOT" ]]; then
  log "preflight: not in a git repository"
  exit 2
fi
cd "$REPO_ROOT"

# ── Resolve base ──
if [[ -z "$BASE_REF" ]]; then
  if [[ -f ".claude/rules/branching.md" ]]; then
    cfg_base=$(grep -E '^default_base_branch:' .claude/rules/branching.md 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"' | tr -d "'")
    BASE_REF="origin/${cfg_base:-main}"
  else
    BASE_REF="origin/main"
  fi
fi

# ── Branch sanity ──
CURRENT=$(git branch --show-current 2>/dev/null || echo '')
if [[ -z "$CURRENT" ]]; then
  log "preflight: detached HEAD — skipping (not on a working branch)"
  exit 2
fi
if echo "$CURRENT" | grep -qE '^(main|master|develop|release(/.+)?|hotfix)$'; then
  log "preflight: on protected branch '$CURRENT' — skipping (branch-protection hook should have caught this)"
  exit 2
fi

# ── Fetch base quietly (best-effort) ──
git fetch origin "${BASE_REF#origin/}" --quiet 2>/dev/null || true

# ── Diff vs base ──
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  log "preflight: base ref '$BASE_REF' not resolvable — skipping"
  exit 2
fi

CHANGED_FILES=$(git diff --name-only "$BASE_REF"..HEAD 2>/dev/null || echo '')
if [[ -z "$CHANGED_FILES" ]]; then
  log "preflight: no diff vs $BASE_REF — nothing to review"
  exit 0
fi

# ── Docs-only fast-lane (matches CLAUDE.md Generation Standards §3) ──
# Allowlist: **/*.md, docs/**, .context/templates/**, .gitignore
# Hard exclusion: .github/workflows/**
fast_lane=true
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    .github/workflows/*)
      fast_lane=false; break ;;
    *.md|docs/*|.context/templates/*|.gitignore)
      ;;
    *)
      fast_lane=false; break ;;
  esac
done <<< "$CHANGED_FILES"

if [[ "$fast_lane" == "true" ]]; then
  log "preflight: docs-only fast-lane (every changed path matches the allowlist) — exit 0"
  if [[ "$OUTPUT_JSON" == "true" ]]; then
    echo '{"verdict":"pass","mode":"fast-lane","reason":"docs-only","blockers":[],"important":[]}'
  fi
  exit 0
fi

# ── Detect tools (early — needed by Step 0) ──
PYTHON=python3
command -v python3 >/dev/null 2>&1 || PYTHON=python
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  log "preflight: python not available — skipping (tooling failure)"
  exit 2
fi

# ── Step 0 — Coherence Audit marker check (Block 13-18 enforcement) ──
# Governance-sensitive diff requires Phase 0 of the SKILL to have run for this
# (session_id, branch_sha) tuple. Marker proves it. Missing marker → blocker.
# When invoked manually (no CLAUDE_SESSION_ID env var), the check degrades to
# advisory: log a note, do not block.
COHERENCE_CONFIG="$REPO_ROOT/config/coherence-context.json"
if [[ -f "$COHERENCE_CONFIG" ]]; then
  ROOT_SETS=$("$PYTHON" -c '
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
    for p in cfg.get("audit", {}).get("root_sets", []):
        print(p.rstrip("/"))
except Exception:
    pass
' "$COHERENCE_CONFIG" 2>/dev/null || echo '')

  EXCLUSIONS=$("$PYTHON" -c '
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
    for p in cfg.get("audit", {}).get("exclusions", []):
        print(p.rstrip("/"))
except Exception:
    pass
' "$COHERENCE_CONFIG" 2>/dev/null || echo '')

  GOVERNANCE_SENSITIVE=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    excluded=false
    while IFS= read -r ex; do
      [[ -z "$ex" ]] && continue
      case "$f" in
        "$ex"|"$ex"/*) excluded=true; break ;;
      esac
    done <<< "$EXCLUSIONS"
    [[ "$excluded" == "true" ]] && continue
    while IFS= read -r rs; do
      [[ -z "$rs" ]] && continue
      case "$f" in
        "$rs"|"$rs"/*) GOVERNANCE_SENSITIVE=true; break ;;
      esac
    done <<< "$ROOT_SETS"
    [[ "$GOVERNANCE_SENSITIVE" == "true" ]] && break
  done <<< "$CHANGED_FILES"

  if [[ "$GOVERNANCE_SENSITIVE" == "true" ]]; then
    BRANCH_SHA=$(git rev-parse HEAD 2>/dev/null || echo '')
    if [[ -z "$BRANCH_SHA" ]]; then
      log "preflight: cannot resolve HEAD — skipping coherence-audit marker check"
    else
      MARKER_FILE=".claude/state/coherence-audit-${BRANCH_SHA}.marker"
      if [[ ! -f "$MARKER_FILE" ]]; then
        # Defer add_finding (FINDINGS_FILE not yet created) — store and emit after.
        DEFERRED_COHERENCE_FINDING="blocker|coherence-audit-missing|Governance-sensitive diff requires factory-pr-review Phase 0 Coherence Audit. Marker file '$MARKER_FILE' not found. Run the SKILL Phase 0 (read SKILL.md § Phase 0 — Coherence Audit) before pushing — the audit writes the marker on completion."
      else
        # Marker exists — parse JSON, look at blocker count.
        MARKER_BLOCKERS=$("$PYTHON" -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(int(d.get("findings", {}).get("blocker", 0)))
except Exception:
    print(0)
' "$MARKER_FILE" 2>/dev/null || echo 0)
        if [[ "$MARKER_BLOCKERS" -gt 0 ]]; then
          DEFERRED_COHERENCE_FINDING="blocker|coherence-audit-blockers|Coherence Audit recorded $MARKER_BLOCKERS blocker(s) in '$MARKER_FILE'. Resolve and re-run Phase 0 to refresh the marker."
        fi
      fi
    fi
  fi
fi

# ── Run detect_change_type.py ──
CLASSIFICATION=$("$PYTHON" "$SKILL_ROOT/scripts/detect_change_type.py" \
  --git-range "$BASE_REF"..HEAD --check-secrets 2>/dev/null || echo '{}')

has_secrets=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("potential_secrets") else "false")' 2>/dev/null || echo 'false')
has_openapi=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("has_openapi") else "false")' 2>/dev/null || echo 'false')
has_asyncapi=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("has_asyncapi") else "false")' 2>/dev/null || echo 'false')
has_code=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("has_code") else "false")' 2>/dev/null || echo 'false')

# ── Aggregate findings (each line: SEVERITY|CATEGORY|message) ──
FINDINGS_FILE=$(mktemp)
trap 'rm -f "$FINDINGS_FILE"' EXIT

add_finding() {
  printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$FINDINGS_FILE"
}

# Emit deferred Step-0 finding (computed before FINDINGS_FILE existed)
if [[ -n "${DEFERRED_COHERENCE_FINDING:-}" ]]; then
  IFS='|' read -r _sev _cat _msg <<< "$DEFERRED_COHERENCE_FINDING"
  add_finding "$_sev" "$_cat" "$_msg"
fi

# Block 3: secrets in diff
if [[ "$has_secrets" == "true" ]]; then
  add_finding "blocker" "secrets" "Potential secret detected in diff (regex match). Review before pushing — secrets in git history are public forever even if rewritten."
fi

# Run check_docs_sync.py — captures Blocks 1, 2 (public API/event without spec) + several Important findings
DOCS_OUT=$("$PYTHON" "$SKILL_ROOT/scripts/check_docs_sync.py" \
  --git-range "$BASE_REF"..HEAD --json 2>/dev/null || echo '{"findings":[]}')

while IFS=$'\t' read -r sev cat msg; do
  [[ -z "$sev" ]] && continue
  add_finding "$sev" "$cat" "$msg"
done < <(echo "$DOCS_OUT" | "$PYTHON" -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for f in data.get("findings", []):
        print(f"{f.get(\"severity\",\"important\")}\t{f.get(\"category\",\"unknown\")}\t{f.get(\"message\",\"\")}")
except Exception:
    pass
' 2>/dev/null)

# OpenAPI breaking changes
if [[ "$has_openapi" == "true" ]]; then
  spec=$(echo "$CHANGED_FILES" | grep -E 'openapi.*\.(yaml|yml|json)$' | head -n1)
  if [[ -n "$spec" ]] && [[ -x "$SKILL_ROOT/scripts/check_openapi_diff.sh" ]]; then
    if ! "$SKILL_ROOT/scripts/check_openapi_diff.sh" "$BASE_REF" "$spec" >/dev/null 2>&1; then
      add_finding "blocker" "openapi-breaking" "Breaking change detected in $spec by oasdiff. Bump major version + add migration note (docs/migrations/) before pushing."
    fi
  fi
fi

# dev_plan task format — orphan `### X.N` h3 without matching `- [ ] [X.N]`
# checkbox, OR `status: READY` with zero unchecked tasks. Inert in the meta
# repo itself (no docs/spec/{ID}/) but live in every downstream project.
# Triggered on changes to any `docs/spec/{FEAT}/dev_plan.md`.
if echo "$CHANGED_FILES" | grep -qE '^docs/spec/[^/]+/dev_plan\.md$'; then
  DEVPLAN_OUT=$("$PYTHON" "$SKILL_ROOT/scripts/check_dev_plan_task_format.py" \
    --git-range "$BASE_REF"..HEAD --json 2>/dev/null || echo '{"findings":[]}')
  while IFS=$'\t' read -r sev cat msg; do
    [[ -z "$sev" ]] && continue
    add_finding "$sev" "$cat" "$msg"
  done < <(echo "$DEVPLAN_OUT" | "$PYTHON" -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for f in data.get("findings", []):
        print(f"{f.get(\"severity\",\"important\")}\t{f.get(\"category\",\"unknown\")}\t{f.get(\"message\",\"\")}")
except Exception:
    pass
' 2>/dev/null)
fi

# AsyncAPI breaking-candidate
if [[ "$has_asyncapi" == "true" ]]; then
  spec=$(echo "$CHANGED_FILES" | grep -E 'asyncapi.*\.(yaml|yml|json)$' | head -n1)
  if [[ -n "$spec" ]] && [[ -x "$SKILL_ROOT/scripts/check_asyncapi_diff.sh" ]]; then
    if ! "$SKILL_ROOT/scripts/check_asyncapi_diff.sh" "$BASE_REF" "$spec" >/dev/null 2>&1; then
      add_finding "important" "asyncapi-breaking-candidate" "Possible breaking change in $spec. Verify removed channels/messages or new required fields manually."
    fi
  fi
fi

# Block 11 — Governance-bump miss (framework meta only)
# Heuristic: file at ".context/templates/setup/governance_versions.json" exists AND is the meta repo.
# We detect "meta repo" by checking for the canonical CLAUDE.md framework header AND absence of docs/spec/.
GOV_MANIFEST=".context/templates/setup/governance_versions.json"
if [[ -f "$GOV_MANIFEST" ]] && [[ ! -d "docs/spec" ]] && grep -q "framework_version" "$GOV_MANIFEST" 2>/dev/null; then
  # Tracked-file patterns (subset of CLAUDE.md Generation Standards §2)
  TRACKED_HIT=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      CLAUDE.md|.claude/commands/*|.claude/instructions/*|.claude/skills/*|.claude/hooks/*)
        TRACKED_HIT=true; break ;;
      scripts/factory-*.sh|scripts/validate-governance.sh|scripts/governance-onprompt.sh|scripts/governance-onedit.sh|scripts/governance-oncompact.sh|scripts/auto-tag.sh)
        TRACKED_HIT=true; break ;;
      .github/workflows/governance-check.yml|.github/workflows/auto-tag.yml)
        TRACKED_HIT=true; break ;;
      .context/templates/*)
        TRACKED_HIT=true; break ;;
    esac
  done <<< "$CHANGED_FILES"

  if [[ "$TRACKED_HIT" == "true" ]]; then
    if ! echo "$CHANGED_FILES" | grep -qx "$GOV_MANIFEST"; then
      add_finding "blocker" "governance-bump-miss" "Framework-core file changed without a matching $GOV_MANIFEST update (CLAUDE.md Generation Standards §2). Bump the manifest entry + add a changelog line in the SAME commit."
    fi
  fi
fi

# Block 12 — Protected-code modified (downstream only)
if [[ -f "config/protected-paths.json" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if "$PYTHON" -c "
import json, sys, fnmatch
patterns = json.load(open('config/protected-paths.json')).get('paths', [])
sys.exit(0 if any(fnmatch.fnmatch('$f', p) for p in patterns) else 1)
" 2>/dev/null; then
      add_finding "blocker" "protected-path" "$f matches a pattern in config/protected-paths.json. Protected code MUST NOT be modified outside its dedicated maintenance flow."
    fi
  done <<< "$CHANGED_FILES"
fi

# ── Tally ──
# Use `grep | wc -l` instead of `grep -c || echo 0`: the latter concatenates
# grep's "0" output with echo's "0" when grep finds nothing (exit 1), producing
# a multi-line value that breaks the `[[ -gt ]]` arithmetic test below.
BLOCKER_COUNT=$(grep '^blocker|' "$FINDINGS_FILE" 2>/dev/null | wc -l | tr -d ' ')
IMPORTANT_COUNT=$(grep '^important|' "$FINDINGS_FILE" 2>/dev/null | wc -l | tr -d ' ')

# ── Output ──
if [[ "$OUTPUT_JSON" == "true" ]]; then
  # Pass FINDINGS_FILE via env (handles paths with spaces); keep heredoc
  # unquoted so $BASE_REF/$CURRENT/$CHANGED_FILES below are bash-expanded.
  PRE_FF="$FINDINGS_FILE" "$PYTHON" - <<PYEOF
import json, os
findings = []
with open(os.environ["PRE_FF"]) as fh:
    for line in fh:
        line=line.strip()
        if not line: continue
        parts=line.split("|",2)
        if len(parts)==3:
            findings.append({"severity":parts[0],"category":parts[1],"message":parts[2]})
blockers=[f for f in findings if f["severity"]=="blocker"]
print(json.dumps({
    "verdict": "block" if blockers else "pass",
    "mode": "preflight",
    "base": "$BASE_REF",
    "branch": "$CURRENT",
    "files_changed_count": sum(1 for _ in "$CHANGED_FILES".splitlines() if _.strip()),
    "blockers": blockers,
    "important": [f for f in findings if f["severity"]=="important"],
    "nits": [f for f in findings if f["severity"]=="nit"]
}, indent=2))
PYEOF
else
  log "═══ Factory PR Review — Preflight ═══"
  log "Branch: $CURRENT  →  Base: $BASE_REF"
  log "Files changed: $(echo "$CHANGED_FILES" | wc -l | tr -d ' ')"
  log "Findings: $BLOCKER_COUNT blocker(s), $IMPORTANT_COUNT important"
  log ""
  if [[ -s "$FINDINGS_FILE" ]]; then
    while IFS='|' read -r sev cat msg; do
      case "$sev" in
        blocker)   icon="🔴 BLOCKER  " ;;
        important) icon="🟡 Important" ;;
        nit)       icon="🟢 Nit      " ;;
        *)         icon="•  $sev   " ;;
      esac
      log "$icon [$cat] $msg"
    done < "$FINDINGS_FILE"
    log ""
  fi
fi

if [[ "$BLOCKER_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
