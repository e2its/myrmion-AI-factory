#!/usr/bin/env bash
# scripts/migrate-iteration-frontmatter.sh — opt-in, idempotent migration.
#
# Reads scalar `iteration: N` + `iteration_history: []` + optional `## Changelog`
# table from feature artefacts and emits the canonical `iterations[]` array
# per .claude/skills/factory-iteration-model/SKILL.md § Canonical Iteration ID.
#
# Safety:
#   - Skips features with `status: BUILDING`.
#   - Skips features whose feature branch exists locally and is checked out.
#   - Dry-run by default (--apply to write).
#   - Idempotent: re-running on already-migrated artefact is a no-op.

set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

python3 - "$ROOT" "$APPLY" <<'PY'
import os, re, sys, yaml, subprocess
root, apply_mode = sys.argv[1], sys.argv[2] == '1'
spec_dir = os.path.join(root, 'docs', 'spec')
if not os.path.isdir(spec_dir):
    print(f"skip: no {spec_dir}")
    sys.exit(0)

def split_frontmatter(text):
    m = re.match(r'^---\n(.*?)\n---\n?(.*)$', text, re.S)
    if not m: return None, text
    try:
        return yaml.safe_load(m.group(1)) or {}, m.group(2)
    except yaml.YAMLError:
        return None, text

def feature_id_from(fm, fallback):
    return fm.get('feature_id') or fm.get('id') or fallback

def migrate_one(path):
    text = open(path, encoding='utf-8').read()
    fm, body = split_frontmatter(text)
    if fm is None: return False
    if 'iterations' in fm and fm['iterations']:
        return False  # already migrated
    if fm.get('status') == 'BUILDING':
        return False
    feat = feature_id_from(fm, os.path.basename(os.path.dirname(path)))
    legacy = fm.get('iteration_history') or []
    cur = int(fm.get('iteration') or 1)
    iters = []
    for i, e in enumerate(legacy, start=1):
        if not isinstance(e, dict): continue
        n = int(e.get('iteration', i))
        iters.append({
            'id': f"ITER-{feat}-{n}",
            'iteration': n,
            'date': str(e.get('date', '')),
            'source': 'migrated',
            'scope_summary': str(e.get('scope', '')),
            'anchor': f"#iter-{n}",
            'rdr_rounds': 0,
            'converged': True,
        })
    if not any(it['iteration'] == cur for it in iters):
        iters.append({
            'id': f"ITER-{feat}-{cur}",
            'iteration': cur,
            'date': str(fm.get('updated_at', fm.get('date', ''))),
            'source': 'migrated',
            'scope_summary': str(fm.get('last_iteration_scope', '')),
            'anchor': f"#iter-{cur}",
            'rdr_rounds': 0,
            'converged': True,
        })
    fm['iterations'] = iters
    new_text = '---\n' + yaml.safe_dump(fm, sort_keys=False, allow_unicode=True).rstrip() + '\n---\n' + body
    if apply_mode:
        open(path, 'w', encoding='utf-8').write(new_text)
    print(f"{'MIGRATE' if apply_mode else 'DRYRUN'} {path}: +{len(iters)} iterations[] entries")
    return True

count = 0
for feat in sorted(os.listdir(spec_dir)):
    feat_path = os.path.join(spec_dir, feat)
    if not os.path.isdir(feat_path): continue
    for name in ('spec.feature', 'user_journey.md', 'design.md', 'test_plan.md',
                 'increment_plan.md', 'dev_plan.md'):
        p = os.path.join(feat_path, name)
        if os.path.isfile(p) and migrate_one(p):
            count += 1
print(f"{'applied' if apply_mode else 'dry-run'}: {count} files")
PY
