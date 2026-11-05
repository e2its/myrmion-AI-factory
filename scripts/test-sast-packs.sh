#!/usr/bin/env bash
# META-ONLY — proof of the SAST base packs (EVOL-074). Runs where semgrep is the pinned engine (meta CI: the image
# semgrep/semgrep:1.182.0). Six proofs, each red on its own:
#   (a) both ways — every rule of every pack carries a `ruleid:` and an `ok:` annotation in its pack's fixtures;
#   (b) the rule tests — `semgrep --test` over the packs and scripts/fixtures/sast passes;
#   (d) never vacuous — semgrep's `N/N: ✓ All tests passed` with N = the rules the packs declare (a pack with no paired
#       fixture, or a run that tested nothing, is red);
#   (c) per answer set (every scripts/fixtures/synthetic-answers/*.json, plus a stack with no pack): a scratch project holds
#       the tree the framework delivers to that stack (the templates whose stack_conditional holds, the synced framework
#       files) and the resolved `sast` command; the planted defects (the pack fixtures) → exit 1, the same fixtures with
#       every `ruleid:` line removed → exit 0 (the delivered tree itself is clean); no pack lands → no `sast` row;
#   (e) one condition: over every backend.runtime × frontend.framework option, the registry's derived `when` holds exactly
#       when some pack's stack_conditional holds;
#   (f) the debug rules' exclusions are anchored: a debug switch under src/devices/ or src/auth/local/ is red; under the
#       root's dev/, in settings.dev.py or local_settings.py green.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKS="$ROOT/.context/templates/setup/security/sast"
FIX="$ROOT/scripts/fixtures/sast"
FAIL=0
fail() { echo "FAIL: $*"; FAIL=1; }
ok() { echo "ok: $*"; }

command -v semgrep >/dev/null 2>&1 || { echo "FAIL: semgrep is absent — run this in semgrep/semgrep:1.182.0"; exit 1; }
SG=(--metrics=off --disable-version-check)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# (a) both ways, and the rule count for (d)
N=$(python3 -I - "$PACKS" "$FIX" <<'PY'
import re, sys
from pathlib import Path
packs, fix = Path(sys.argv[1]), Path(sys.argv[2])
n, bad = 0, []
for p in sorted(packs.glob("*.yml")):
    ids = re.findall(r"^  - id: (\S+)\s*$", p.read_text(encoding="utf-8"), re.M)
    if not ids:
        bad.append(f"{p.name} declares no rule")
    text = "\n".join(f.read_text(encoding="utf-8") for f in sorted(fix.glob(p.stem + ".*")))
    for i in ids:
        if not i.startswith(p.stem + "-"):
            bad.append(f"{p.name}: rule `{i}` is not named <pack>-<class>")
        for kind in ("ruleid", "ok"):
            if not re.search(rf"\b{kind}: (\S+, )*{re.escape(i)}(?![\w-])", text):
                bad.append(f"{p.name}: rule `{i}` has no `{kind}:` annotation in scripts/fixtures/sast/{p.stem}.*")
    n += len(ids)
for b in bad:
    print("FAIL: " + b, file=sys.stderr)
print(n if not bad else 0)
PY
)
if [ "${N:-0}" -gt 0 ]; then ok "(a) every one of the $N rules fires on a ruleid line and has an ok line"; else fail "(a) a rule is not proven both ways"; fi

# (b) + (d)
semgrep --test "${SG[@]}" --config "$PACKS" "$FIX" >"$WORK/test.out" 2>&1; r=$?
if [ "$r" -ne 0 ]; then
  cat "$WORK/test.out"; fail "(b) semgrep --test exited $r"
elif grep -q "^$N/$N: ✓ All tests passed" "$WORK/test.out"; then
  ok "(b)(d) semgrep --test: $N/$N rule tests passed"
else
  grep "tests passed\|All tests" "$WORK/test.out"; fail "(d) semgrep --test did not test all $N rules"
fi

# (c) per answer set
printf '{"answers": {"backend.runtime": "Ruby", "frontend.framework": "None", "surface.runtime_surface": ["src/**"]}}\n' >"$WORK/no-pack.json"
for ans in "$ROOT"/scripts/fixtures/synthetic-answers/*.json "$WORK/no-pack.json"; do
  name=$(basename "$ans" .json)
  P="$WORK/$name"; mkdir -p "$P/security/sast" "$P/src"
  plan=$(python3 -I - "$ROOT" "$ans" "$P" <<'PY'
import json, shutil, sys
from pathlib import Path
root, out = Path(sys.argv[1]), Path(sys.argv[3]); sys.path.insert(0, str(root / "scripts"))
from gates import discovery
a = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))["answers"]
m = json.loads((root / ".context/templates/setup/governance_versions.json").read_text(encoding="utf-8"))
holds = lambda e: e.get("stack_conditional") is None or discovery.evaluate(discovery.parse(e["stack_conditional"]), a)
packs = [k for k, e in m["templates"].items() if k.startswith("security/sast/") and holds(e)]
for k, e in m["templates"].items():   # the delivered tree: every landing template at its target (packs: by the caller)
    src = root / ".context/templates/setup" / k
    if e.get("target") and src.is_file() and not k.startswith("security/sast/") and holds(e):
        (out / e["target"]).parent.mkdir(parents=True, exist_ok=True); shutil.copy(src, out / e["target"])
for e in [*m["framework_core"].values(), *(m.get("agent_templates") or {}).values()]:   # and every file factory-sync delivers
    t = isinstance(e, dict) and e.get("delivery") in ("sync", "both") and (e.get("path") or e.get("target"))
    if t and (root / t).is_file() and not t.startswith("scripts/fixtures/"):
        (out / t).parent.mkdir(parents=True, exist_ok=True); shutil.copy(root / t, out / t)
row = discovery.resolve(root, a)["configures"].get("verification.gates", {}).get("sast")
print((row or {}).get("command", ""))
print(" ".join(Path(p).stem for p in packs))
PY
) || { fail "(c) $name: the answers do not resolve"; continue; }
  cmd=$(sed -n 1p <<<"$plan"); landed=$(sed -n 2p <<<"$plan")
  if [ -z "$landed" ]; then
    if [ -z "$cmd" ]; then ok "(c) $name: no pack lands, no sast member"; else fail "(c) $name: no pack lands but a sast member is configured"; fi
    continue
  fi
  [ -n "$cmd" ] || { fail "(c) $name: packs land ($landed) but no sast member is configured"; continue; }
  for k in $landed; do
    cp "$PACKS/$k.yml" "$P/security/sast/"
    cp "$FIX/$k".* "$P/src/"
  done
  (cd "$P" && eval "$cmd") >"$WORK/$name.red" 2>&1; r=$?
  [ "$r" -eq 1 ] || { cat "$WORK/$name.red"; fail "(c) $name: the planted defects exit $r, not 1"; continue; }
  python3 -I - "$P/src" <<'PY'
import re, sys
from pathlib import Path
for f in Path(sys.argv[1]).iterdir():
    out, skip = [], False
    for line in f.read_text(encoding="utf-8").splitlines():
        if re.search(r"\bruleid: ", line):
            skip = True; continue
        if skip:
            skip = False; continue
        out.append(line)
    f.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
  (cd "$P" && eval "$cmd") >"$WORK/$name.green" 2>&1; r=$?
  if [ "$r" -eq 0 ]; then ok "(c) $name: packs [$landed] on the delivered tree — planted defects red, their absence green"
  else cat "$WORK/$name.green"; fail "(c) $name: the clean fixtures exit $r, not 0"; fi
done

# (e) one condition
python3 -I - "$ROOT" <<'PY' && ok "(e) the derived when holds exactly when a pack lands, on every backend × frontend option" || fail "(e) the derived when and the packs' stack_conditional disagree"
import json, sys
from pathlib import Path
root = Path(sys.argv[1]); sys.path.insert(0, str(root / "scripts"))
from gates import discovery
reg = discovery.load_registry(root); specs = discovery._specs(reg)
when = discovery.parse(reg["derived"]["quality.sast"]["when"])
m = json.loads((root / ".context/templates/setup/governance_versions.json").read_text(encoding="utf-8"))
conds = [discovery.parse(e["stack_conditional"]) for k, e in m["templates"].items() if k.startswith("security/sast/")]
bad = [(be, fe) for be in specs["backend.runtime"]["options"] for fe in specs["frontend.framework"]["options"]
       if discovery.evaluate(when, a := {"backend.runtime": be, "frontend.framework": fe}) != any(discovery.evaluate(c, a) for c in conds)]
for b in bad:
    print(f"FAIL: (e) backend {b[0]} + frontend {b[1]}", file=sys.stderr)
sys.exit(1 if bad or not conds else 0)
PY

# (f) anchored exclusions
X="$WORK/excl"; mkdir -p "$X/security/sast" "$X/src/devices" "$X/src/auth/local" "$X/dev" "$X/config"
cp "$PACKS/python.yml" "$X/security/sast/"
red=0
for f in src/devices/settings.py src/auth/local/settings.py; do
  printf 'DEBUG = True\n' >"$X/$f"
  (cd "$X" && semgrep scan --config security/sast --error "${SG[@]}" --quiet .) >"$WORK/excl.red" 2>&1; r=$?
  [ "$r" -eq 1 ] || { cat "$WORK/excl.red"; fail "(f) a debug switch in $f exits $r, not 1"; red=1; }
  rm "$X/$f"
done
printf 'DEBUG = True\n' >"$X/dev/settings.py"; printf 'DEBUG = True\n' >"$X/config/settings.dev.py"; printf 'DEBUG = True\n' >"$X/config/local_settings.py"
(cd "$X" && semgrep scan --config security/sast --error "${SG[@]}" --quiet .) >"$WORK/excl.green" 2>&1; g=$?
if [ "$red" -eq 0 ] && [ "$g" -eq 0 ]; then ok "(f) a debug switch under src/devices/ or src/auth/local/ is red; under dev/, in settings.dev.py or local_settings.py green"
elif [ "$g" -ne 0 ]; then cat "$WORK/excl.green"; fail "(f) dev/ + settings.dev.py + local_settings.py exit $g, not 0"; fi

[ "$FAIL" -eq 0 ] && echo "test-sast-packs: OK" || echo "test-sast-packs: FAILED"
exit "$FAIL"
