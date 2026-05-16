#!/usr/bin/env bash
# scripts/check-iteration-id-format.sh — CI gate for ITER-{FEAT}-{N} schema.
#
# Rules (per .claude/skills/factory-iteration-model/SKILL.md § Canonical Iteration ID):
#   1. Every `iterations[].id` matches ^ITER-[A-Z0-9]+(-[A-Z0-9]+)*-[0-9]+$.
#   2. `iterations[].iteration` integer equals the trailing -N of `id`.
#   3. Body contains matching anchor: `## Iteration {id} {#iter-N}` for .md / .feature,
#      `<!-- iter:{id} ` for .html.
#   4. `_progress.iteration_in_flight` (when present) is null at command exit.
#
# Scans both framework templates (.context/templates/) and any docs/spec/ trees
# the script is invoked on. Exits 0 on clean, 1 on first violation reported.

set -euo pipefail

ROOT="${1:-$(pwd)}"
RC=0

scan_iterations_block() {
  local file="$1"
  python3 - "$file" <<'PY'
import re, sys, yaml
fp = sys.argv[1]
text = open(fp, encoding='utf-8', errors='replace').read()

# For .md / .feature: real YAML frontmatter between --- markers.
# For .html: pseudo-frontmatter inside <!-- ... -->; not strict YAML.
# Strategy: extract the `iterations:` block by regex, parse only that.
fm_block = None
m = re.match(r'^---\n(.*?)\n---', text, re.S)
if m:
    fm_block = m.group(1)
else:
    m = re.match(r'^<!--\s*(.*?)\s*-->', text, re.S)
    if m:
        fm_block = m.group(1)
if not fm_block:
    sys.exit(0)

# Extract only `iterations:` mapping using indentation-aware regex.
iter_m = re.search(r'^\s*iterations:\s*(\[\])?\s*$((?:\n\s+-.*)*)', fm_block, re.M)
if not iter_m:
    sys.exit(0)
iters_yaml = 'iterations: ' + (iter_m.group(1) or '') + (iter_m.group(2) or '')
try:
    iters = (yaml.safe_load(iters_yaml) or {}).get('iterations') or []
except yaml.YAMLError as e:
    print(f"FAIL {fp}: iterations block parse error: {e}")
    sys.exit(2)
# Stale in-flight marker check (best-effort scan).
flight_m = re.search(r'iteration_in_flight:\s*([^\s#]+)', fm_block)
if flight_m and flight_m.group(1).lower() not in ('null', '~', ''):
    print(f"FAIL {fp}: stale iteration_in_flight={flight_m.group(1)}")
    sys.exit(2)
if not isinstance(iters, list):
    print(f"FAIL {fp}: iterations is not a list")
    sys.exit(2)
id_re = re.compile(r'^ITER-[A-Z0-9]+(-[A-Z0-9]+)*-(\d+)$')
for e in iters:
    if not isinstance(e, dict) or 'id' not in e:
        print(f"FAIL {fp}: iterations entry missing id: {e}")
        sys.exit(2)
    m = id_re.match(e['id'])
    if not m:
        print(f"FAIL {fp}: id violates schema: {e['id']}")
        sys.exit(2)
    n_from_id = int(m.group(2))
    if 'iteration' in e and int(e['iteration']) != n_from_id:
        print(f"FAIL {fp}: iteration {e['iteration']} != id suffix {n_from_id} ({e['id']})")
        sys.exit(2)
    if fp.endswith('.html'):
        token = f"<!-- iter:{e['id']}"
        if token not in text:
            print(f"FAIL {fp}: missing body anchor {token}")
            sys.exit(2)
    else:
        anchor = f"## Iteration {e['id']}"
        if anchor not in text:
            print(f"FAIL {fp}: missing body anchor '{anchor}'")
            sys.exit(2)
sys.exit(0)
PY
}

while IFS= read -r f; do
  scan_iterations_block "$f" || RC=1
done < <(find "$ROOT" \( -name "*.feature" -o -name "*.md" -o -name "*.html" \) \
                      -not -path "*/node_modules/*" -not -path "*/.git/*" \
                      -not -path "*/dist/*" -not -path "*/build/*" 2>/dev/null)

if [[ $RC -eq 0 ]]; then
  echo "OK: iteration-id schema + anchor + in-flight marker"
fi
exit $RC
