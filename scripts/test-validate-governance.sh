#!/usr/bin/env bash
# ============================================================================
# scripts/test-validate-governance.sh — manifest-gate self-test (EVOL-040)
# ============================================================================
# META-ONLY. Exercises scripts/validate-governance.sh (default CI mode) in
# disposable git sandboxes with a minimal manifest. CI live-fire only covers
# the happy path — clean real data never plants an orphan or a duplicate, so
# every fail-direction here would otherwise run zero times per year (the
# pre-EVOL-040 CHECK 2 rotted exactly this way: 27 orphans, green for months).
#
# Scenarios:
#   1. Clean sandbox (all files tracked) → exit 0.
#   2. Planted orphan in a governed tree → exit 1 (full-tree CHECK 2).
#   3. Duplicate source path across manifest keys → exit 1 (CHECK 1c DUP-PATH).
#   4. templates entry without target key → exit 1 (CHECK 1c NO-TARGET).
#   5. Duplicate target WITH target_mode: merge on all → tolerated (exit 0).
#   6. Stale manifest entry (missing file) → WARNING only, exit 0 (CHECK 3
#      contract pin: stale is advisory).
#   7. Malformed manifest JSON → nonzero exit, NEVER a green pass (CHECK 1c
#      crash guard: broken inspector must not read as "no issues").
#
# Exit codes: 0 = ok, 1 = at least one scenario failed.
# ============================================================================

set -uo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

GATE="$(pwd)/scripts/validate-governance.sh"
PASS=0
FAIL=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

assert() { # $1 label ; $2 expected-exit ; $3 actual-exit
  if [ "$2" = "$3" ]; then
    echo "  ok: $1 (exit $3)"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $1 — expected exit $2, got $3"; FAIL=$((FAIL + 1))
  fi
}

# Minimal sandbox: git repo, one governed tree (.claude/commands), manifest
# tracking its files. validate-governance's TRACKED_DIRS also names trees that
# simply don't exist here — the gate warns and skips those (pinned by S1=0
# only if absent trees are non-fatal, which is itself part of the contract).
make_sandbox() { # $1 dir
  local dir="$1"
  mkdir -p "$dir/.claude/commands" "$dir/.context/templates/setup"
  ( cd "$dir" && git init -q -b main && git config user.email t@t && git config user.name t )
  echo cmd > "$dir/.claude/commands/x.md"
  cat > "$dir/.context/templates/setup/governance_versions.json" <<'JSON'
{ "$schema": "governance_versions_v2", "manifest_version": "2.0.0",
  "framework_version": "0.1.0", "last_updated": "2026-01-01",
  "framework_core": {
    "commands/x.md": { "version": "1.0.0", "type": "command", "role": "t",
      "path": ".claude/commands/x.md", "changelog": ["1.0.0: init"] }
  },
  "templates": {}, "agent_templates": {} }
JSON
  ( cd "$dir" && git add -A && git commit -qm base )
}

run_gate() { # $1 dir — echoes exit code
  ( cd "$1" && CLAUDE_PROJECT_DIR="$1" bash "$GATE" --base main >/dev/null 2>&1 )
  echo $?
}

manifest_edit() { # $1 dir ; $2 python body operating on dict `m`
  python3 - "$1/.context/templates/setup/governance_versions.json" "$2" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p))
exec(sys.argv[2])
json.dump(m, open(p, 'w'), indent=2)
PY
}

echo "test-validate-governance — manifest gate"

# 1. clean
d="$TMP_ROOT/s1"; make_sandbox "$d"
assert "clean sandbox passes" 0 "$(run_gate "$d")"

# 2. planted orphan (full-tree CHECK 2 — file is committed but untracked in manifest)
d="$TMP_ROOT/s2"; make_sandbox "$d"
echo orphan > "$d/.claude/commands/orphan.md"
( cd "$d" && git add -A && git commit -qm orphan )
assert "planted orphan detected" 1 "$(run_gate "$d")"

# 3. duplicate source path (CHECK 1c)
d="$TMP_ROOT/s3"; make_sandbox "$d"
manifest_edit "$d" "m['framework_core']['dup-key'] = dict(m['framework_core']['commands/x.md'])"
assert "duplicate source path detected" 1 "$(run_gate "$d")"

# 4. templates entry without target (CHECK 1c)
d="$TMP_ROOT/s4"; make_sandbox "$d"
mkdir -p "$d/.context/templates/setup/rules"; echo r > "$d/.context/templates/setup/rules/r.md"
manifest_edit "$d" "m['templates']['rules/r.md'] = {'version':'1.0.0','content_type':'universal','role':'t','changelog':['1.0.0: init']}"
( cd "$d" && git add -A && git commit -qm t )
assert "target-less templates entry detected" 1 "$(run_gate "$d")"

# 5. duplicate target with declared merge → tolerated
d="$TMP_ROOT/s5"; make_sandbox "$d"
mkdir -p "$d/.context/templates/setup/workflows"
echo a > "$d/.context/templates/setup/workflows/a.yml"; echo b > "$d/.context/templates/setup/workflows/b.yml"
manifest_edit "$d" "m['templates']['workflows/a.yml'] = {'version':'1.0.0','content_type':'universal','target':'pipe.yml','target_mode':'merge','role':'t','changelog':['1.0.0: init']}; m['templates']['workflows/b.yml'] = {'version':'1.0.0','content_type':'universal','target':'pipe.yml','target_mode':'merge','role':'t','changelog':['1.0.0: init']}"
( cd "$d" && git add -A && git commit -qm t )
assert "declared merge target collision tolerated" 0 "$(run_gate "$d")"

# 5b. duplicate target with DISTINCT stack_conditional on every collider → tolerated (exactly one lands — EVOL-054 runbooks)
d="$TMP_ROOT/s5b"; make_sandbox "$d"
mkdir -p "$d/.context/templates/setup/scm"
echo a > "$d/.context/templates/setup/scm/p.github.md"; echo b > "$d/.context/templates/setup/scm/p.gitlab.md"
manifest_edit "$d" "m['templates']['scm/p.github.md'] = {'version':'1.0.0','content_type':'universal','stack_conditional':'scm.platform == GitHub','target':'docs/scm/p.md','role':'t','changelog':['1.0.0: init']}; m['templates']['scm/p.gitlab.md'] = {'version':'1.0.0','content_type':'universal','stack_conditional':'scm.platform == GitLab','target':'docs/scm/p.md','role':'t','changelog':['1.0.0: init']}"
( cd "$d" && git add -A && git commit -qm t )
assert "exclusive stack-conditional target collision tolerated" 0 "$(run_gate "$d")"

# 5c. duplicate target where two colliders share the SAME stack_conditional → both would land: violation
d="$TMP_ROOT/s5c"; make_sandbox "$d"
mkdir -p "$d/.context/templates/setup/scm"
echo a > "$d/.context/templates/setup/scm/p.github.md"; echo b > "$d/.context/templates/setup/scm/p.other.md"
manifest_edit "$d" "m['templates']['scm/p.github.md'] = {'version':'1.0.0','content_type':'universal','stack_conditional':'scm.platform == GitHub','target':'docs/scm/p.md','role':'t','changelog':['1.0.0: init']}; m['templates']['scm/p.other.md'] = {'version':'1.0.0','content_type':'universal','stack_conditional':'scm.platform == GitHub','target':'docs/scm/p.md','role':'t','changelog':['1.0.0: init']}"
( cd "$d" && git add -A && git commit -qm t )
assert "same stack_conditional on two colliders is a violation" 1 "$(run_gate "$d")"

# 6. stale entry → warning only (contract pin)
d="$TMP_ROOT/s6"; make_sandbox "$d"
manifest_edit "$d" "m['framework_core']['commands/ghost.md'] = {'version':'1.0.0','type':'command','role':'t','path':'.claude/commands/ghost.md','changelog':['1.0.0: init']}"
assert "stale entry is advisory (exit 0)" 0 "$(run_gate "$d")"

# 7. malformed manifest → nonzero, never green
d="$TMP_ROOT/s7"; make_sandbox "$d"
echo 'broken{' > "$d/.context/templates/setup/governance_versions.json"
rc=$(run_gate "$d")
if [ "$rc" != "0" ]; then
  echo "  ok: malformed manifest never passes (exit $rc)"; PASS=$((PASS + 1))
else
  echo "  FAIL: malformed manifest passed green"; FAIL=$((FAIL + 1))
fi

echo ""
echo "test-validate-governance: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
