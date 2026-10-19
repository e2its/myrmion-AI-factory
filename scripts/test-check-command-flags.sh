#!/usr/bin/env bash
# test-check-command-flags.sh — red-proving self-test for check-command-flags.py (#117). META-ONLY.
# A cited flag its command does not declare is red; a declared one, a non-command (`npm audit --omit`) and a
# command name used as another flag's value (`--phase SETUP --format`) are not. Then the real tree is green.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/check-command-flags.py"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0

expect() { # expect <exit> <label> [substring]
  local want=$1 label=$2 substr=${3:-} out got
  out=$(python3 "$CHECK" --root "$SANDBOX" 2>&1); got=$?
  if [ "$got" -ne "$want" ] || { [ -n "$substr" ] && ! printf '%s' "$out" | grep -qF -- "$substr"; }; then
    FAIL=$((FAIL+1)); echo "  ✗ $label (want exit $want, got $got)"; printf '%s\n' "$out" | sed 's/^/      /' | head -6; return
  fi
  PASS=$((PASS+1)); echo "  ✓ $label"
}

git -C "$SANDBOX" init -q
mkdir -p "$SANDBOX/.claude/commands" "$SANDBOX/.claude/rules" "$SANDBOX/.context/templates/setup"
printf '# IMPLEMENT\n### `--plan {ID}`\n### `--refine {ID}`\n' > "$SANDBOX/.claude/commands/implement.md"
printf '# SETUP\n### `--upgrade`\n' > "$SANDBOX/.claude/commands/setup.md"
printf 'Run `IMPLEMENT --plan X`, then `/implement --refine X`.\nnpm audit --omit=dev\n`gate.py applicable --phase SETUP --format rollcall`\n' > "$SANDBOX/.claude/rules/ok.md"
git -C "$SANDBOX" add -A
expect 0 "declared flags, a non-command and a flag value: green"

printf 'Blocked: use `IMPLEMENT --pause INC-1`.\n' > "$SANDBOX/.context/templates/setup/policy.md"; git -C "$SANDBOX" add -A
expect 1 "an undeclared flag cited in a template: red, file:line named" "policy.md:1: IMPLEMENT --pause"

printf 'Blocked: run `/setup --rollback-last`.\n' > "$SANDBOX/.context/templates/setup/policy.md"; git -C "$SANDBOX" add -A
expect 1 "the lowercase slash form is a citation too: red" "SETUP --rollback-last"

printf 'Blocked: complete the increment first.\n' > "$SANDBOX/.context/templates/setup/policy.md"
printf '{"changelog": ["1.0.0: IMPLEMENT --pause retired"]}\n' > "$SANDBOX/.context/templates/setup/governance_versions.json"; git -C "$SANDBOX" add -A
expect 0 "history (the manifest changelog) is not rewritten: green"

rm -rf "$SANDBOX/.claude/commands"/*
expect 2 "no command file: the check cannot judge (exit 2), never green"

out=$(python3 "$CHECK" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✓ the framework's own trees: zero ghost flags"; else FAIL=$((FAIL+1)); echo "  ✗ the framework's own trees carry ghost flags"; printf '%s\n' "$out" | head -8; fi

echo "test-check-command-flags: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
