#!/usr/bin/env bash
# META-ONLY: proves the registry's per-file scoped rows; not shipped to materialised projects.
# test-red-stacks.sh — EVOL-116: the red proven on every stack the templates offer.
#
#   bash scripts/test-red-stacks.sh <stack>      stack ∈ scripts/fixtures/red-stacks/<stack>.json (java, go, dotnet, rust, node, angular)
#
# Runs inside that stack's pinned tool container (meta CI: governance-check.yml → red-stacks). It lays a two-commit
# repository from scripts/fixtures/red-stacks/<stack>.json — `base` (a bug) on `main`, `head` (the fix and three test files)
# on a feature branch — writes config/quality.json from the registry's row for the stack (the row byte for byte; reads
# `**`), then runs the seal's red proof (scripts/gates/seal.py red_proof) and asserts each file's verdict from
# the fixture's expect: `proven` (fails at the base), `could not fail` (passes at the base), `head` (runs no test at
# the head). Rust adds its in-source tests (the graft, owner RDR «2»).
#
# Exit codes: 0 every verdict as expected · 1 a verdict differs · 2 infrastructure (never a silent pass).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/git-test-env.sh"   # git isolated from the user's config: no gpg signing per commit

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="${1:-}"
FIX="$ROOT/scripts/fixtures/red-stacks/$STACK.json"
case "$STACK" in ''|*[!a-z0-9-]*) STACK="" ;; esac
[ -n "$STACK" ] && [ -f "$FIX" ] || { echo "test-red-stacks: unknown stack '${1:-}' — one of: $(cd "$ROOT/scripts/fixtures/red-stacks" && ls *.json | sed 's/\.json$//' | tr '\n' ' ')" >&2; exit 2; }
command -v python3 >/dev/null || { echo "test-red-stacks: python3 not available" >&2; exit 2; }
command -v git >/dev/null || { echo "test-red-stacks: git not available" >&2; exit 2; }
export PYTHONDONTWRITEBYTECODE=1

SANDBOX=$(mktemp -d) || { echo "test-red-stacks: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$SANDBOX"' EXIT

python3 - "$ROOT" "$FIX" "$SANDBOX/repo" <<'PYEOF'
import json, subprocess, sys
from pathlib import Path

root, fix, repo = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
sys.path.insert(0, str(root / "scripts"))
from gates import seal  # noqa: E402

spec = json.loads(fix.read_text())
reg = json.loads((root / ".context/templates/setup/setup/discovery_registry.json").read_text())
conf = next(s["configures"][spec["literal"]] for q in reg["questions"] for k, s in q["keys"].items() if k == spec["key"])
row = dict(conf["verification.gates"][spec["gate"]]); row.pop("was", None); row["reads"] = ["**"]

def sh(cmd, cwd=repo):
    r = subprocess.run(cmd, shell=True, cwd=str(cwd), capture_output=True, text=True)
    if r.returncode:
        print(f"test-red-stacks: `{cmd}` failed (exit {r.returncode}): {(r.stdout + r.stderr).strip()[-800:]}", file=sys.stderr); sys.exit(2)

def overlay(part):
    for rel, text in spec[part].items():
        dest = (repo / rel).resolve()
        if repo.resolve() not in dest.parents:
            print(f"test-red-stacks: fixture path `{rel}` leaves the sandbox", file=sys.stderr); sys.exit(2)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text)

repo.mkdir(parents=True)
if spec.get("scaffold"):
    sh(spec["scaffold"])
overlay("base")
(repo / "config").mkdir(exist_ok=True)
(repo / "config/quality.json").write_text(json.dumps({
    "documentation": {"paths": ["**/*.md"], "exclusions": []},
    "traceability": {"test_roots": conf.get("traceability.test_roots") or []},
    "verification": {"seal": {"required": True, "dir": ".claude/state"}, "gates": {spec["gate"]: row}, "digest_artefacts": ["design.md"]}}, indent=1))
(repo / ".gitignore").write_text(".claude/state/\nnode_modules/\ntarget/\nbin/\nobj/\n.angular/\n")
if spec.get("install"):
    sh(spec["install"])
git = "git -c user.name=t -c user.email=t@t -c init.defaultBranch=main"
sh(f"{git} init -q && {git} add -A && {git} commit -qm base && {git} checkout -qb feature/EVOL-116-red-stacks")
overlay("head")

r = seal.red_proof(repo, seal.vcfg(repo), "main")
detail = "\n".join(r["detail"])
want = {"proven": "at the base — proven red", "could not fail": "at the base — could not fail", "head": "at the head — fails with its change, or runs no test"}
bad = [f"{p}: expected «{v}»" for p, v in spec["expect"].items() if f"{p}: " not in detail or want[v] not in next((l for l in r["detail"] if l.startswith(f"{p}: ")), "")]
bad += [f"{p}: proven but not expected" for p in r["files"] if p not in spec["expect"]]
print(f"test-red-stacks [{spec['literal']} · {spec['gate']}]: {len(spec['expect']) - len(bad)}/{len(spec['expect'])} verdicts as expected")
print("  " + detail.replace("\n", "\n  "))
if bad:
    print("  ✗ " + "\n  ✗ ".join(bad)); sys.exit(1)
PYEOF
