#!/usr/bin/env bash
# ============================================================================
# scripts/test-materialization-surface.sh — T3 delivery-surface test (EVOL-040)
# ============================================================================
# SETUP --generate is LLM-driven and cannot run in CI. This test statically
# verifies the DELIVERY SURFACE instead: everything a materialised project's
# artifacts reference must be deliverable by SETUP's auto-scan or by
# factory-sync — the north-star check ("SETUP instantiation perfect, reliable,
# secure"). Validates the AGNOSTIC surface only — placeholders must have
# resolution rules; resolved values are never asserted.
#
# Assertions:
#   1. Workflow→script closure: every scripts/* a template workflow invokes
#      has a source under .context/templates/setup/scripts/ (CVP CRITICAL-10
#      class: fresh SETUP materialises CI that invokes undelivered scripts).
#   2. Template CLAUDE.md ref resolution via the delivery map: rules/config/
#      scripts refs → template sources exist; skills/instructions refs → meta
#      tree exists (factory-sync channel).
#   3. Placeholder resolvability: every {{TOKEN}} in template config JSONs has
#      a resolution rule in Factory-setup-materialization.instructions.md.
#   4. Hooks invariant, template side: every hook wired in the template
#      settings.json exists under the template hooks dir.
#   5. Delivery-field closure: every manifest scripts entry with delivery
#      setup|both resolves to an existing template source (the factory-sync
#      query and the SETUP auto-scan both depend on it).
#
# Exit codes: 0 = ok, 1 = at least one assertion failed.
# ============================================================================

set -uo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

TPL_ROOT=".context/templates/setup"
MATERIALIZATION=".claude/instructions/Factory-setup-materialization.instructions.md"
MANIFEST=".context/templates/setup/governance_versions.json"

failures=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1" >&2; failures=$((failures + 1)); }

echo "T3 — materialization surface"
echo ""

echo "1. workflow→script closure"
MISSING=$(python3 - <<'PY'
import glob, os, re
missing = set()
for wf in glob.glob('.context/templates/setup/workflows/*'):
    txt = open(wf, errors='replace').read()
    for ref in re.findall(r'scripts/[A-Za-z0-9_./-]+\.(?:sh|py)', txt):
        name = ref[len('scripts/'):]
        if not os.path.exists(f'.context/templates/setup/scripts/{name}'):
            missing.add(f'{ref} (invoked by {os.path.basename(wf)})')
for m in sorted(missing):
    print(m)
PY
) || MISSING="probe failed — python error above must be fixed, not ignored (a broken probe is not a pass)"
if [ -z "$MISSING" ]; then
  ok "every workflow-invoked script has a template source"
else
  while IFS= read -r m; do [ -n "$m" ] && bad "workflow-invoked script without template source: $m"; done <<< "$MISSING"
fi
echo ""

echo "2. template CLAUDE.md ref resolution (delivery map)"
MISSING=$(python3 - <<'PY'
import json, os, re
txt = open('.context/templates/setup/claude/CLAUDE.md', errors='replace').read()
manifest = json.load(open('.context/templates/setup/governance_versions.json'))
# runtime-synthesised artefacts + the manifest itself are exempt from the
# template-source requirement (loop invariants — computed once)
runtime = {k.split('/')[-1] for k in manifest.get('runtime_artefacts', {}) if not k.startswith('_')}
project_local = {'governance_versions.json'}
missing = set()
# rules / config refs → template sources (SETUP channel)
for ref in set(re.findall(r'\.claude/rules/[A-Za-z0-9_.-]+\.md', txt)):
    name = ref.split('/')[-1]
    if not os.path.exists(f'.context/templates/setup/rules/{name}'):
        missing.add(f'{ref} -> no template under rules/')
for ref in set(re.findall(r'config/[A-Za-z0-9_-]+\.json', txt)):
    name = ref.split('/')[-1]
    if name in runtime or name in project_local:
        continue
    candidates = [f'.context/templates/setup/config/{name}', f'.context/templates/setup/rules/{name}']
    if not any(os.path.exists(c) for c in candidates):
        missing.add(f'{ref} -> no template under config/ or rules/')
# skills / instructions → meta tree (factory-sync channel)
for ref in set(re.findall(r'\.claude/skills/[a-z-]+/SKILL\.md', txt)):
    if not os.path.exists(ref):
        missing.add(f'{ref} -> no meta skill (sync channel)')
for ref in set(re.findall(r'\.claude/instructions/[A-Za-z0-9-]+\.instructions\.md', txt)):
    if not os.path.exists(ref):
        missing.add(f'{ref} -> no meta instruction (sync channel)')
for m in sorted(missing):
    print(m)
PY
) || MISSING="probe failed — python error above must be fixed, not ignored (a broken probe is not a pass)"
if [ -z "$MISSING" ]; then
  ok "every template-CLAUDE.md governance ref resolves through its delivery channel"
else
  while IFS= read -r m; do [ -n "$m" ] && bad "unresolvable ref: $m"; done <<< "$MISSING"
fi
echo ""

echo "3. placeholder resolvability"
MISSING=$(python3 - <<'PY'
import glob, re
rules = open('.claude/instructions/Factory-setup-materialization.instructions.md', errors='replace').read()
missing = set()
for cfg in glob.glob('.context/templates/setup/config/*.json'):
    txt = open(cfg, errors='replace').read()
    for token in set(re.findall(r'\{\{([A-Z0-9_]+)\}\}', txt)):
        if token not in rules:
            missing.add(f'{{{{{token}}}}} in {cfg}')
for m in sorted(missing):
    print(m)
PY
) || MISSING="probe failed — python error above must be fixed, not ignored (a broken probe is not a pass)"
if [ -z "$MISSING" ]; then
  ok "every {{TOKEN}} in template configs has a materialization resolution rule"
else
  while IFS= read -r m; do [ -n "$m" ] && bad "placeholder without resolution rule: $m"; done <<< "$MISSING"
fi
echo ""

echo "4. hooks invariant (template side)"
MISSING=$(python3 - <<'PY'
import json, os, re
try:
    s = open('.context/templates/setup/claude/settings.json').read()
except FileNotFoundError:
    print('template settings.json missing'); raise SystemExit
for hook in set(re.findall(r'\.claude/hooks/([A-Za-z0-9_-]+\.sh)', s)):
    if not os.path.exists(f'.context/templates/setup/claude/hooks/{hook}'):
        print(f'.claude/hooks/{hook} wired in template settings.json but no template hook file')
PY
) || MISSING="probe failed — python error above must be fixed, not ignored (a broken probe is not a pass)"
if [ -z "$MISSING" ]; then
  ok "every hook wired in template settings.json ships as a template hook"
else
  while IFS= read -r m; do [ -n "$m" ] && bad "$m"; done <<< "$MISSING"
fi
echo ""

echo "5. delivery-field closure"
MISSING=$(python3 - <<'PY'
import json, os
m = json.load(open('.context/templates/setup/governance_versions.json'))
for k, v in m.get('templates', {}).items():
    if k.startswith('_') or not isinstance(v, dict):
        continue
    if k.startswith('scripts/') and v.get('delivery') in ('setup', 'both'):
        if not os.path.exists(f'.context/templates/setup/{k}'):
            print(f'templates::{k} (delivery={v["delivery"]}) -> template source missing')
# framework_core sync|both scripts must resolve template-or-meta (the
# factory-sync query ships them; a dangling entry ships nothing silently)
for k, v in m.get('framework_core', {}).items():
    if k.startswith('_') or not isinstance(v, dict):
        continue
    if k.startswith('scripts/') and v.get('delivery') in ('sync', 'both'):
        if not (os.path.exists(f'.context/templates/setup/{k}') or os.path.exists(k)):
            print(f'framework_core::{k} (delivery={v["delivery"]}) -> no template or meta source')
PY
) || MISSING="probe failed — python error above must be fixed, not ignored (a broken probe is not a pass)"
if [ -z "$MISSING" ]; then
  ok "every delivery setup|both scripts entry resolves to a template source"
else
  while IFS= read -r m; do [ -n "$m" ] && bad "$m"; done <<< "$MISSING"
fi
echo ""

if [ "$failures" -eq 0 ]; then
  echo "T3: ok — materialization surface closed (5 assertion groups)."
  exit 0
else
  echo "T3: FAIL — $failures assertion(s) failed." >&2
  exit 1
fi
