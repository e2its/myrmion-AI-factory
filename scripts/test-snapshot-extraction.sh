#!/usr/bin/env bash
# ============================================================================
# scripts/test-snapshot-extraction.sh — L2 snapshot generator test (EVOL-043)
# ============================================================================
# Runs the REAL generator (scripts/generate-governance-snapshot.sh, the SETUP
# --generate Checkpoint 3.1 contract) against a synthetic project and asserts
# what a session receives:
#
#   1. frontmatter carries constitution_hash / setup_hash / dcs_hash / profile
#   2. LITE profile: the law INDEX (one `### [PLAW-NN]`, its `> sentence`, its
#      `Body:` pointer per law) — never a law body
#   3. LITE profile: the defect FAMILIES table — never the defect-class rows
#   4. the rules manifest is resolved by the one frontmatter parser (nested
#      applicable_when rendered, not `always` by default)
#   5. setup.md frontmatter verbatim (Setup Configuration)
#   6. FULL profile adds the law bodies and the defect-class table
#   7. RED: a lite snapshot over budgets.snapshot exits 3 and says so
#   8. idempotent: two runs differ only by generated_at
#   9. missing inputs → exit 1, plain language
#
# Exit codes: 0 ok · 1 assertion failed · 2 infrastructure
# ============================================================================
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$ROOT/.context/templates/setup/scripts/generate-governance-snapshot.sh"
[ -f "$GEN" ] || { echo "L2: generator template missing at $GEN" >&2; exit 2; }
cmp -s "$GEN" "$ROOT/scripts/generate-governance-snapshot.sh" || { echo "L2: generator twins drifted (lock-step)" >&2; exit 2; }
command -v python3 >/dev/null || { echo "L2: python3 required" >&2; exit 2; }
export PYTHONDONTWRITEBYTECODE=1

failures=0
fail() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; failures=$((failures + 1)); }
pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
SANDBOX=$(mktemp -d) || exit 2
trap 'rm -rf "$SANDBOX"' EXIT
P="$SANDBOX/proj"
mkdir -p "$P/docs" "$P/.claude/rules" "$P/config" "$P/scripts" "$P/.context"
cp -R "$ROOT/scripts/gates" "$P/scripts/gates"; cp "$ROOT/scripts/gate.py" "$P/scripts/gate.py"; cp "$GEN" "$P/scripts/"
cat > "$P/config/coherence-context.json" <<'EOF'
{"context": "downstream"}
EOF
cat > "$P/config/quality.json" <<'EOF'
{"budgets": {"session_start": 2000, "prompt_submit": 16000, "pre_edit": 6000, "snapshot": 16000, "law_sentence_max_chars": 240, "dc_invariant_max_chars": 160}}
EOF
cat > "$P/docs/constitution.md" <<'EOF'
---
version: 4.0.0
project_scope: full-stack
backend:
  runtime: Python
  framework: FastAPI
---
# Constitution — Fixture

> Index of operational law.

## [PLAW-01] KISS & DRY
> Every solution is the simplest one that satisfies the specification, written once.
Body: `rules/architecture.md` · Records: `ADR-0000`

## [PLAW-02] Stateless
> Services keep no request state between calls.
Body: `rules/stateless.md` · Records: `ADR-0000`
EOF
cat > "$P/docs/setup.md" <<'EOF'
---
project_scope: full-stack
codesign:
  authoring: internal
---
# Setup
EOF
cat > "$P/.claude/rules/defect-prevention.md" <<'EOF'
---
description: "catalog"
applicable_when:
  always: true
---
# Defect Prevention Catalog

## Families
| Family | Surface (globs) | Invariant |
|---|---|---|
| `runtime` | `src/**` | Every runtime path fails loudly. |
| `data` | `**/migrations/**` | Every migration is reversible. |

## Defect Classes
| DC | Family | Invariant | Gate | Paths | Applicable To | Severity |
|---|---|---|---|---|---|---|
| DC-18 | `runtime` | Unused imports are removed before commit. | `—` | `src/**` | DEV | WARNING |
| DC-27 | `data` | A migration ships with its down step. | `scripts/validate-migrations.sh` | `**/migrations/**` | DEV | CRITICAL |
EOF
cat > "$P/.claude/rules/architecture.md" <<'EOF'
---
description: "arch"
applicable_when:
  always: true
---
## [PLAW-01] KISS & DRY
> Every solution is the simplest one that satisfies the specification, written once.

THE-KISS-BODY-TEXT. Prefer composition.
EOF
cat > "$P/.claude/rules/stateless.md" <<'EOF'
---
description: "stateless"
applicable_when:
  always: true
---
## [PLAW-02] Stateless
> Services keep no request state between calls.

THE-STATELESS-BODY-TEXT.
EOF
cat > "$P/.claude/rules/python.md" <<'EOF'
---
description: "py"
applicable_when:
  path_glob: ["**/*.py"]
  framework: [fastapi]
---
EOF
printf '{"paths": ["src/core/"], "yellow_zones": ["src/shared/"]}\n' > "$P/config/protected-paths.json"

echo "L2 snapshot generator test"; echo
run_gen() { (cd "$P" && bash scripts/generate-governance-snapshot.sh "$@" 2>&1); }
OUT=$(run_gen --quiet); RC=$?
S="$P/.context/governance_snapshot.md"
[ "$RC" -eq 0 ] && [ -f "$S" ] && pass "lite snapshot written (exit 0)" || fail "generator failed (rc=$RC): $OUT"
grep -qE '^constitution_hash: "[0-9a-f]{32}"$' "$S" && grep -qE '^dcs_hash: "[0-9a-f]{32}"$' "$S" && grep -q '^profile: "lite"$' "$S" \
  && pass "frontmatter: constitution/setup/dcs hashes + profile" || fail "frontmatter hashes/profile missing"
grep -q '^### \[PLAW-01\] KISS & DRY$' "$S" && grep -q '^> Every solution is the simplest one that satisfies the specification, written once.$' "$S" \
  && grep -q 'Body: `rules/architecture.md` · Records: `ADR-0000`' "$S" && pass "law index: id, sentence, body pointer, records" || fail "law index entry missing"
[ "$(grep -cE '^### \[PLAW-[0-9]+\]' "$S")" = "2" ] && pass "every project law indexed (2)" || fail "law count"
! grep -q 'THE-KISS-BODY-TEXT' "$S" && ! grep -q 'THE-STATELESS-BODY-TEXT' "$S" && pass "lite: no law body injected" || fail "lite snapshot carries a body"
grep -q '^| `runtime` | `src/\*\*` | Every runtime path fails loudly. |$' "$S" && pass "defect families table present" || fail "families missing"
! grep -q 'DC-18' "$S" && pass "lite: defect-class rows not injected (delivered at the point of edit)" || fail "lite carries DC rows"
grep -q '| python.md | {"path_glob": \["\*\*/\*.py"\], "framework": \["fastapi"\]} |' "$S" && pass "rules manifest: nested applicable_when rendered by the one parser" || fail "rules manifest applicability wrong: $(grep 'python.md' "$S")"
grep -q '^  authoring: internal$' "$S" && pass "setup.md frontmatter verbatim (codesign.authoring reaches the snapshot)" || fail "setup frontmatter missing"
grep -q '^- src/core/$' "$S" && pass "protected paths rendered" || fail "protected paths missing"
grep -q 'runtime: Python' "$S" && pass "stack configuration from the constitution frontmatter" || fail "stack config missing"
BYTES=$(wc -c < "$S"); [ "$BYTES" -le 16000 ] && pass "lite snapshot within budgets.snapshot ($BYTES B)" || fail "over budget"

OUT=$(run_gen --quiet --profile full); RC=$?
[ "$RC" -eq 0 ] && grep -q 'THE-KISS-BODY-TEXT' "$S" && grep -q 'THE-STATELESS-BODY-TEXT' "$S" && grep -q '| DC-27 |' "$S" && grep -q '^profile: "full"$' "$S" \
  && pass "full profile: law bodies + defect-class table (review only)" || fail "full profile incomplete (rc=$RC)"

# RED: budget overflow
sed -i 's/"snapshot": 16000/"snapshot": 300/' "$P/config/quality.json"
OUT=$(run_gen --quiet); RC=$?
[ "$RC" -eq 3 ] && printf '%s' "$OUT" | grep -q 'over budgets.snapshot' && pass "RED: lite snapshot over budgets.snapshot → exit 3, plain language" || fail "budget overflow not caught (rc=$RC): $OUT"
sed -i 's/"snapshot": 300/"snapshot": 16000/' "$P/config/quality.json"

# RED: budget key missing → exit 2, nothing claimed
python3 - "$P/config/quality.json" <<'PY'
import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["budgets"].pop("snapshot"); json.dump(d, open(p,"w"))
PY
OUT=$(run_gen --quiet); RC=$?
[ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'budgets.snapshot' && pass "RED: missing budgets.snapshot key → exit 2 in plain language (fail-closed)" || fail "missing budget key not refused (rc=$RC): $OUT"
python3 - "$P/config/quality.json" <<'PY'
import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["budgets"]["snapshot"]=16000; json.dump(d, open(p,"w"))
PY
# RED: a corpus fault surfaces MID-WRITE (the header was already emitted) → no partial snapshot with fresh
# hashes is left behind (atomic). The fault: a law without its Body: pointer, refused by the one reader.
run_gen --quiet >/dev/null; BEFORE=$(md5sum "$S" | cut -d' ' -f1)
cp "$P/docs/constitution.md" "$SANDBOX/const.bak"; sed -i '/^Body: `rules\/stateless.md`/d' "$P/docs/constitution.md"
OUT=$(run_gen --quiet); RC=$?
[ "$RC" -eq 2 ] && [ "$(md5sum "$S" | cut -d' ' -f1)" = "$BEFORE" ] && [ -z "$(ls "$P/.context"/governance_snapshot.md.tmp.* 2>/dev/null)" ] \
  && pass "RED: corpus fault mid-write → exit 2, previous snapshot untouched, no temp file left (atomic)" || fail "partial snapshot or temp file left after a mid-write failure (rc=$RC): $OUT"
cp "$SANDBOX/const.bak" "$P/docs/constitution.md"
# RED: corrupt protected-paths.json → exit 2 (protected paths would be silently absent otherwise)
cp "$P/config/protected-paths.json" "$SANDBOX/pp.bak"; printf '{not json' > "$P/config/protected-paths.json"
OUT=$(run_gen --quiet); RC=$?
[ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'not readable JSON' && pass "RED: corrupt protected-paths.json → exit 2 in plain language" || fail "corrupt protected paths not refused (rc=$RC): $OUT"
cp "$SANDBOX/pp.bak" "$P/config/protected-paths.json"

# idempotency
run_gen --quiet >/dev/null; A=$(grep -v '^generated_at' "$S")
run_gen --quiet >/dev/null; B=$(grep -v '^generated_at' "$S")
[ "$A" = "$B" ] && pass "idempotent (only generated_at differs)" || fail "non-deterministic output"

# missing input
mv "$P/docs/setup.md" "$P/docs/setup.bak"
OUT=$(run_gen --quiet); RC=$?
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'docs/setup.md not found' && pass "missing setup.md → exit 1 in plain language" || fail "missing input not reported (rc=$RC)"
mv "$P/docs/setup.bak" "$P/docs/setup.md"
OUT=$(run_gen --check); [ $? -eq 0 ] && pass "--check validates inputs only" || fail "--check failed: $OUT"

echo
if [ "$failures" -eq 0 ]; then echo "L2: ok — snapshot generator contract verified."; exit 0; else echo "L2: FAIL — $failures assertion(s)." >&2; exit 1; fi
