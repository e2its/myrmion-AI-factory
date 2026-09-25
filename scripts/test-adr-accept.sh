#!/usr/bin/env bash
# ============================================================================
# scripts/test-adr-accept.sh — L4 Accept Procedure test (EVOL-043 index form)
# ============================================================================
# The factory-adr-management Accept Procedure is executed by an LLM. This test
# pins its mechanical contract with a shell reference implementation over a
# synthetic project whose constitution is the INDEX of project law:
#
#   ## [PLAW-NN] Title
#   > sentence
#   Body: `rules/x.md` · Records: `ADR-0000`
#
#   1. ADD     — mints the next PLAW id, appends the three-line entry, writes the
#                body section (`## [PLAW-NN]` + `> sentence` + body) in body_home.
#   2. REPLACE — swaps the `> sentence` in the index AND in the body home, appends
#                the record id; the parity between both is preserved.
#   3. RED     — an empty sentence fails before any write; a sentence over
#                budgets.law_sentence_max_chars fails before any write.
#   4. The framework's own parity gate (scripts/gate.py laws --parity) is green
#                after every accept.
#
# Exit codes: 0 ok · 1 assertion failed · 2 infrastructure
# ============================================================================
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v python3 >/dev/null || { echo "L4: python3 required" >&2; exit 2; }
export PYTHONDONTWRITEBYTECODE=1
failures=0
fail() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; failures=$((failures + 1)); }
pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
W=$(mktemp -d) || exit 2
trap 'rm -rf "$W"' EXIT
P="$W/proj"; mkdir -p "$P/docs/project_log/adr" "$P/.claude/rules" "$P/config" "$P/scripts"
cp -R "$ROOT/scripts/gates" "$P/scripts/gates"; cp "$ROOT/scripts/gate.py" "$P/scripts/gate.py"
printf '{"context": "downstream"}\n' > "$P/config/coherence-context.json"
printf '{"budgets": {"law_sentence_max_chars": 240}}\n' > "$P/config/quality.json"
cat > "$P/docs/constitution.md" <<'EOF'
---
version: 4.0.0
---
# Constitution

## [PLAW-01] Fundamental Principles (KISS & DRY)
> Every technical decision is the simplest one that meets the current requirement.
Body: `rules/architecture.md` · Records: `ADR-0000`

## [PLAW-02] Stateless Design Policy
> Every service scales horizontally without session affinity.
Body: `rules/stateless.md` · Records: `ADR-0000`
EOF
cat > "$P/.claude/rules/architecture.md" <<'EOF'
---
description: "arch"
applicable_when:
  always: true
---
# Architecture

## [PLAW-01] Fundamental Principles (KISS & DRY)
> Every technical decision is the simplest one that meets the current requirement.

Prefer composition. Delete before adding.
EOF
cat > "$P/.claude/rules/stateless.md" <<'EOF'
---
description: "stateless"
applicable_when:
  always: true
---
## [PLAW-02] Stateless Design Policy
> Every service scales horizontally without session affinity.

No instance-local state.
EOF

# ─── Reference Accept Procedure (python; ADD / REPLACE) ──────────────────────
accept_adr() { # accept_adr <adr> <project>  → exit 0 accepted · 1 refused before any write
  python3 - "$1" "$2" <<'PY'
import re, sys, json, pathlib, subprocess
adr, proj = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
text = adr.read_text()
fm = dict(re.findall(r"^([a-z_]+):\s*\"?([^\"\n]*)\"?$", text.split("---")[1], re.M))
if fm.get("status") != "proposed":
    print("accept: status is not proposed", file=sys.stderr); sys.exit(1)
rule = re.search(r"^## Operational Rule\n(.*?)(?=^## |\Z)", text, re.M | re.S).group(1)
body_m = re.search(r"^### Body\n(.*)", rule, re.M | re.S)
sentence_block = rule[:body_m.start()] if body_m else rule
sentence = next((l.strip() for l in sentence_block.splitlines() if l.strip() and not l.startswith(">")), "")
body = (body_m.group(1).strip() if body_m else "")
budget = json.loads((proj / "config/quality.json").read_text())["budgets"]["law_sentence_max_chars"]
if not sentence:
    print("accept: Operational Rule sentence is empty — refused before any write", file=sys.stderr); sys.exit(1)
if len(sentence) > budget:
    print(f"accept: sentence is {len(sentence)} chars, over budgets.law_sentence_max_chars={budget} — refused before any write", file=sys.stderr); sys.exit(1)
const = proj / "docs/constitution.md"; ctext = const.read_text()
kind, target, home, title, n = fm["amendment_kind"], fm["target_section"], fm.get("body_home", ""), fm["title"], fm["adr_number"]
if kind == "ADD":
    ids = [int(x) for x in re.findall(r"^## \[PLAW-(\d+)\]", ctext, re.M)]
    lid = f"PLAW-{max(ids, default=0) + 1:02d}"
    ctext = ctext.rstrip("\n") + f"\n\n## [{lid}] {title}\n> {sentence}\nBody: `{home}` · Records: `ADR-{n}`\n"
    hp = proj / ".claude/rules" / home[len("rules/"):]
    if not hp.is_file():
        hp.write_text(f'---\ndescription: "{title}"\napplicable_when:\n  always: true\n---\n')
    hp.write_text(hp.read_text().rstrip("\n") + f"\n\n## [{lid}] {title}\n> {sentence}\n\n{body}\n")
elif kind == "REPLACE":
    lid = target.strip("[]")
    m = re.search(r"^## \[" + re.escape(lid) + r"\] (.+)\n> (.+)\nBody: `([^`]+)` · Records: (.+)$", ctext, re.M)
    if not m:
        print(f"accept: {lid} not in the index", file=sys.stderr); sys.exit(1)
    old_sentence, old_home = m.group(2), m.group(3)
    home = home or old_home
    new_entry = f"## [{lid}] {m.group(1)}\n> {sentence}\nBody: `{home}` · Records: {m.group(4)}, `ADR-{n}`"
    ctext = ctext[:m.start()] + new_entry + ctext[m.end():]
    hp = proj / ".claude/rules" / home[len("rules/"):]
    htext = hp.read_text()
    sec = re.search(r"(^## \[" + re.escape(lid) + r"\][^\n]*\n)> [^\n]*\n(.*?)(?=^## |\Z)", htext, re.M | re.S)
    if not sec:
        print(f"accept: body section {lid} not in {home}", file=sys.stderr); sys.exit(1)
    new_body = ("\n" + body + "\n") if body else sec.group(2)
    htext = htext[:sec.start()] + sec.group(1) + f"> {sentence}\n" + new_body + htext[sec.end():]
    hp.write_text(htext)
else:
    print(f"accept: {kind} not covered by this reference", file=sys.stderr); sys.exit(1)
const.write_text(ctext)
text = re.sub(r"^status:\s*proposed", "status: accepted", text, flags=re.M)
adr.write_text(text)
PY
}

parity() { # parity <project> → the framework's own gate (gate.py laws --parity); prints its report
  (cd "$1" && python3 scripts/gate.py laws --parity 2>&1)
}

echo "L4 Accept Procedure test (index form)"; echo
echo "Test 1 — ADD"
cat > "$P/docs/project_log/adr/ADR-003-tracing.md" <<'EOF'
---
adr_number: "003"
title: "Mandatory request tracing"
date: "2026-09-25"
status: proposed
target_section: "NEW: Mandatory request tracing"
body_home: "rules/observability.md"
amendment_kind: ADD
---
# ADR-003

## Operational Rule
> guidance line, ignored
Every inbound request carries a correlation id that every log line and outbound call propagates.

### Body
Header `X-Request-Id`, generated at the edge when absent. Logged as `request_id`.
EOF
if accept_adr "$P/docs/project_log/adr/ADR-003-tracing.md" "$P"; then pass "ADD accepted"; else fail "ADD refused"; fi
grep -q '^## \[PLAW-03\] Mandatory request tracing$' "$P/docs/constitution.md" && pass "next id minted (PLAW-03) in the index" || fail "id not minted"
grep -q '^Body: `rules/observability.md` · Records: `ADR-003`$' "$P/docs/constitution.md" && pass "pointer + record written" || fail "pointer/record line wrong"
grep -q '^## \[PLAW-03\] Mandatory request tracing$' "$P/.claude/rules/observability.md" && grep -q 'X-Request-Id' "$P/.claude/rules/observability.md" && pass "body section written in body_home (file created with frontmatter)" || fail "body section missing"
grep -q '^status: accepted$' "$P/docs/project_log/adr/ADR-003-tracing.md" && pass "status flipped" || fail "status not flipped"
[ "$(grep -c 'correlation id' "$P/docs/constitution.md")" = "1" ] && pass "the index carries the sentence once, never the body" || fail "body leaked into the index"
if out=$(parity "$P"); then pass "gate.py laws --parity: every index sentence equals its body quote"; else fail "parity red: $out"; fi

echo "Test 2 — REPLACE"
cat > "$P/docs/project_log/adr/ADR-004-kiss.md" <<'EOF'
---
adr_number: "004"
title: "Sharpen KISS"
date: "2026-09-25"
status: proposed
target_section: "[PLAW-01]"
amendment_kind: REPLACE
---
# ADR-004

## Operational Rule
Every technical decision is the simplest one that meets the current requirement, and nothing more.

### Body
Prefer composition. Delete before adding. Three similar lines are not yet an abstraction.
EOF
if accept_adr "$P/docs/project_log/adr/ADR-004-kiss.md" "$P"; then pass "REPLACE accepted"; else fail "REPLACE refused"; fi
grep -q '^> Every technical decision is the simplest one that meets the current requirement, and nothing more.$' "$P/docs/constitution.md" && pass "index sentence replaced" || fail "index sentence not replaced"
grep -q 'Records: `ADR-0000`, `ADR-004`$' "$P/docs/constitution.md" && pass "record appended, earlier record kept" || fail "records wrong"
grep -q '^> Every technical decision is the simplest one that meets the current requirement, and nothing more.$' "$P/.claude/rules/architecture.md" && grep -q 'Three similar lines' "$P/.claude/rules/architecture.md" && pass "body home quote + body replaced" || fail "body home not updated"
if grep -q 'Delete before adding\.$' "$P/.claude/rules/architecture.md"; then fail "old body text remains"; else pass "old body text gone"; fi
[ "$(grep -c '^## \[PLAW-01\]' "$P/.claude/rules/architecture.md")" = "1" ] && pass "one body section per law" || fail "duplicate body section"
if out=$(parity "$P"); then pass "gate.py laws --parity holds after REPLACE"; else fail "parity red: $out"; fi
grep -q '^> Every service scales horizontally without session affinity.$' "$P/docs/constitution.md" && pass "untouched law unchanged" || fail "collateral edit"

echo "Test 3 — RED: refused before any write"
cp "$P/docs/constitution.md" "$W/const.before"
cat > "$P/docs/project_log/adr/ADR-005-empty.md" <<'EOF'
---
adr_number: "005"
title: "Empty"
date: "2026-09-25"
status: proposed
target_section: "NEW: Empty"
body_home: "rules/x.md"
amendment_kind: ADD
---
## Operational Rule
> only guidance, no sentence
EOF
if accept_adr "$P/docs/project_log/adr/ADR-005-empty.md" "$P" 2>"$W/err"; then fail "empty sentence accepted"; else grep -q 'empty' "$W/err" && pass "empty sentence refused in plain language" || fail "refusal message unclear"; fi
cmp -s "$P/docs/constitution.md" "$W/const.before" && pass "no write happened on refusal" || fail "index modified on refusal"
LONG=$(python3 -c 'print("Every " + "very " * 60 + "long sentence.")')
cat > "$P/docs/project_log/adr/ADR-006-long.md" <<EOF
---
adr_number: "006"
title: "Long"
date: "2026-09-25"
status: proposed
target_section: "NEW: Long"
body_home: "rules/x.md"
amendment_kind: ADD
---
## Operational Rule
$LONG
EOF
if accept_adr "$P/docs/project_log/adr/ADR-006-long.md" "$P" 2>"$W/err"; then fail "over-budget sentence accepted"; else grep -q 'law_sentence_max_chars' "$W/err" && pass "sentence over budgets.law_sentence_max_chars refused" || fail "budget refusal message unclear"; fi
cmp -s "$P/docs/constitution.md" "$W/const.before" && pass "no write on the budget refusal" || fail "index modified on budget refusal"
grep -q '^status: proposed$' "$P/docs/project_log/adr/ADR-006-long.md" && pass "ADR status untouched on refusal" || fail "status flipped on refusal"

echo
if [ "$failures" -eq 0 ]; then echo "L4: ok — Accept Procedure contract verified (index form)."; exit 0; else echo "L4: FAIL — $failures assertion(s)." >&2; exit 1; fi
