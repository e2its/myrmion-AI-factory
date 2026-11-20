---
description: "Factory SETUP upgrade — framework version upgrade, rollback, legacy migration, apply by owner (EVOL-136). Use when: SETUP --upgrade, --rollback-upgrade, --migrate-legacy-setup."
applicable_when:
  phase: [SETUP]
  command: [setup]
---

# SETUP Agent — Upgrade, Migration & Rollback (`/setup --upgrade`, `--rollback-upgrade`, `--migrate-legacy-setup`)

> Instruction file for the SETUP worker agent — Governance upgrade, legacy migration, and rollback capabilities.
> Loaded when SETUP handles `--upgrade`, `--rollback-upgrade`, or `--migrate-legacy-setup`.

---

## Migration Path Mapping

### filename rename

| Pre-9.0.0 Path | Post-9.0.0 Path |
|---|---|
| .claude/instructions/agents/*.md | .claude/instructions/Factory-*.instructions.md |
| .claude/instructions/protocols/*.md | .claude/instructions/Factory-protocol-*.instructions.md |
| .claude/instructions/protocols/{5 cross-cutting}.md | .claude/skills/Factory-{name}/SKILL.md |

### Rules / config split (NOT auto-applied)

Projects still on the retired pre-`.claude/rules` layout (rules directory under `docs/`, JSON config beside the rules): one-time manual `git mv` of that directory to `.claude/rules/` and of `protected-paths.json` / `allowlist.json` into `config/`, then regenerate the governance snapshot and re-run `--upgrade`.

### rules-naming convention unification (drop `.instructions.md` suffix)

Materialised projects on framework < 4.0.0 carry rules as `.claude/rules/foo.instructions.md`. Convention is unified to `.claude/rules/foo.md` everywhere — source, target, manifest, instruction refs.

**Auto-applied during `--upgrade` (Step 2 prologue):**

```bash
# Detect legacy state and rename in lock-step. Idempotent + collision-safe.
# Degrades to plain `mv` when not inside a git work tree (sandbox / non-git
# materialisation) — `git mv` would otherwise fail with "fatal: not a git
# repository" and abort the entire upgrade.
shopt -s nullglob
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  rename_cmd=(git mv)
else
  rename_cmd=(mv)
fi
for f in .claude/rules/*.instructions.md; do
  base="${f##*/}"; new="${base%.instructions.md}.md"
  # Skip if target already exists (current materialisation already correct).
  [ -e ".claude/rules/$new" ] && continue
  "${rename_cmd[@]}" "$f" ".claude/rules/$new"
done
```

The rename runs BEFORE the owner step (Step 2) so that subsequent file-by-file comparisons use the new path. Manifest `target` fields for `templates.rules/*` already point to the new convention; the rename brings the project filesystem into alignment.

If the migration finds collisions (both `foo.instructions.md` and `foo.md` exist), it skips the rename and surfaces a manual-resolution warning — typical cause is a half-applied prior upgrade that the user must reconcile.

`factory-sync.sh` accepts both forms during the transition window (1 minor version) and prefers the new form when both exist on the framework side. It replaces every framework-owned file wholesale (EVOL-136); a project keeps its own change in a project-owned file — `--preserve-local` is retired.

---

## Command: `--upgrade`

Upgrades project governance artifacts to match the latest framework templates. Each delivered file is applied by its declared owner (EVOL-136): the framework's are replaced, the project's are written only by an answer or a migration row, the seams are merged by key — a project never loses its work to an upgrade.

**Key features:** Pre-Upgrade Audit, Smart Discovery Cascade, RDR Protocol, Zero-TODO Enforcement, Atomic Operations, Rollback, On-Demand Sync.

### Prerequisites (BLOCKING)
- `docs/setup.md` with `materialization_complete: true`
- `.context/templates/setup/governance_versions.json` (framework manifest)
- If `docs/project_log/governance_versions.json` missing → treat as legacy project, construct snapshot with forced `"0.0.0"` versioning to ensure full scan

---

### Step -1: Pre-Upgrade Inventory Audit Protocol

6-phase comprehensive audit before any modifications:

**Phase 1 — Registry Integrity Check:**
Verify `governance_versions.json` structure, all referenced files exist on disk, no orphan entries.

**Phase 2 — Phantom File Detection:**
Scan `.claude/rules/`, `config/`, `scripts/` for files not tracked in registry. For each phantom:
- (a) Register in snapshot (was created manually)
- (b) Delete (accidental/obsolete)
- (c) Skip (handle later)

**Phase 3 — Template Checksum Validation:**
Compare current framework template checksums against stored checksums. Detect drift (file was modified in framework since last upgrade). Flag templates that changed.

**Phase 4 — Target File State Inventory:**
For each file that will be touched by upgrade, record: current checksum, last modified date, size. Used for rollback.

**Phase 5 — Dependency Graph Validation:**
Check cross-references between governance files. Detect broken links (e.g., constitution.md references a rule that doesn't exist). List broken dependencies.

**Phase 6 — ADR Customization Protection Check (v2):**
For each ADR in `docs/project_log/adr/`:
- **VALUE_PROTECTED (default):** Structural updates allowed, but user-defined values preserved.
- **FULL_LOCK:** No modifications at all. Only when ADR explicitly states `lock: full`.
- Classify each ADR, report protection scope.

---

### Step 0: Prerequisite Validation (4.4.0)
1. Verify `materialization_complete: true`
2. Load framework manifest from `.context/templates/setup/governance_versions.json`
3. Load project snapshot from `docs/project_log/governance_versions.json`
4. If project snapshot missing: construct from current files with forced `"0.0.0"` version

### Step 1: Version Comparison & Change Detection (4.4.1)

**Owners (EVOL-136).** Every delivered manifest entry declares `owner`; the owner decides how the upgrade touches the landed file — never the format, never a merge by judgement:

| Owner | Landed files | Upgrade |
|-------|--------------|---------|
| `framework` | `.claude/{commands,instructions,skills,hooks,agents}/**`, the framework scripts, `.context/templates/**`, the universal templates the framework alone writes | Replaced wholesale: `factory-sync.sh` (sync channel); `templates_to_refresh` copied by script (Step 2). An edit in the project is red in `gate.py manifest-parity`. |
| `project` | `.claude/rules/**`, the CI workflows, root `CLAUDE.md`, `docs/**`, every `stack_configured` / `project_data` template | Written only by an answer (Step 8b.3), a migration row (Step 8b.4) or as a new file (Step 3). `templates_moved` is listed, never written. |
| `seam` | `.claude/settings.json`, `config/quality.json` | Merged by key, add-only, by script (Step 8b.7). |

A `framework_core` entry without `delivery` is a file of the framework repo itself — never delivered.

1. Compare framework versions vs project versions (SemVer)
2. Select templates through `python3 scripts/gate.py discovery --resolve` against the project — never read a `stack_conditional` as prose. A project materialised before 8.13.0 is back-filled first (Step 8b.1). Before resolving: a `ci_cd.platform` of `CircleCI` is no longer offered (#143) — ask Q21 again; a frontmatter `mode:` is renamed `project_mode:` with Q3's literal (`Greenfield` | `Brownfield`).
3. Drift: `python3 scripts/gate.py manifest-parity` names each framework-owned file the project edited — say it is replaced; the change belongs in a project-owned file.
4. Present upgrade summary with options: **ALL** (upgrade everything) | **SELECT** (choose files) | **ABORT**

### Step 1b: Centralized Backup Creation (MANDATORY)
**Before ANY file modification:**
1. Create `BACKUP_MANIFEST.json` with per-file tracking
2. Copy every file that will be modified to backup location
3. Record original checksums for rollback verification
4. Backup is ATOMIC — all or nothing

---

### Step 2: Apply by owner (EVOL-136)

**Gate 0 — ADR Lock Check:** a FULL_LOCK file → SKIP (no modifications).

1. **framework.** `factory-sync.sh` already replaced the sync channel. From `gate.py discovery --resolve --json`, list `templates_to_refresh` (a framework-owned landed file whose bytes differ from its delivered template), then copy each `.context/templates/setup/<key>` over its `target` with the script below (idempotent; the target keeps its mode). No diff review, no merge.
2. **project.** No write here. List each `templates_moved` entry in the upgrade report as «moved {from}→{to}, not written — a migration row carries what a project needs». `claude/CLAUDE.md` moves are owed to EVOL-137.
3. **seam.** Step 8b.7.

```bash
python3 -I - <<'PY'
import json, pathlib, shutil, subprocess, sys
sys.path.insert(0, "scripts")
from gates import discovery
r = json.loads(subprocess.run([sys.executable, "scripts/gate.py", "discovery", "--resolve", "--json"], capture_output=True, text=True, check=True).stdout)
m = json.loads(pathlib.Path(discovery.MANIFEST).read_text(encoding="utf-8"))["templates"]
for k in r.get("templates_to_refresh") or []:
    shutil.copyfile(discovery.TEMPLATE_ROOT + k, m[k]["target"])
    print(f"refreshed: {m[k]['target']}")
PY
```

**Placeholder resolution (Smart Discovery Cascade)** — for a new file (Step 3) and a seam's `unresolved` key. Resolve each `{{PLACEHOLDER}}` from, in order:
1. `docs/setup.md` frontmatter — `gate.py discovery --resolve --json → placeholders`, then the registry's derived `fills` and `constants`
2. `docs/constitution.md` values
3. ADR decisions
4. Existing rules files
5. Config files (`config/*.json`)

Unresolved after all 5 → **RDR Protocol**: recommendation with justification + alternatives → user decides → ratify immediately.

**Zero-TODO Enforcement** — a written file carries no `TODO`, `FIXME`, `XXX` or `{{...}}` (`REPLACE_ME_*` in `.env.example` is exempt — Secret Placeholder Convention); resolve by the cascade or RDR before writing.

**Update Snapshot** — record each written entry's version and `owner` in the project `governance_versions.json`.

**Step 8b — What the project lacks (EVOL-102).** One call: `python3 scripts/gate.py discovery --resolve --json` against the project (no `--answers`). Exit 2 names what to fix: an answer outside a vocabulary list or under another parent (ask that question again), a catalog row the parser refuses (repair that row) or a missing template catalog (run `factory-sync.sh`); then run the call again. Then, in order:
1. **Back-fill.** A project materialised before 8.13.0 holds its answers as `docs/setup.md` body bullets (`- **Backend Runtime:** Python`). Each `pending` question whose key the body states unambiguously, with a value inside its options → write it to the frontmatter; list each in the upgrade report. Anything else → RDR, never a guess.
2. **Carry (EVOL-132).** Each `carried` row `{key, from, entries}`: write `entries` to the frontmatter under `key`, verbatim (each keeps `carried_from`), and remove the `from` key — one home. Its question stays pending: ask it with the carried entries shown; the person keeps, splits or replaces them. Write the confirmed answer without `carried_from` — that confirmation ends the question; an entry left with it is asked again.
3. **Ask** the remaining `pending` questions in tier order (`pending_since` says why each is new), RDR with the recommendation shown; write each answer to the frontmatter. Q21.2 (`scm`), Q32 (`delivery_mode`) and Q34 (`agents.families`) arrive this way; their migration below writes the block the answer configures. Then run the call again: steps 4–6 read the output of the answered set.
4. **Migrate.** Run `migrations_owed` in order, each by its anchor below.
5. **Templates.** Offer `templates_to_add` (Step 3). Offer `templates_to_remove` by RDR — never remove silently.
6. **Defect catalog (EVOL-066).** From `defect_classes`: land each `to_add` universal row in `.claude/rules/defect-prevention.md § Defect Classes` and its case in the annex; offer `to_remove` (a tool-bound row whose tool the answers do not name) by RDR. Each `collisions` entry — a universal id the project already uses for its own class — is one RDR: renumber the project's class to its next `PDC-NN` (row, case and every reference; recommended — then run the call again and land the universal row, now in `to_add`), retire it into the universal row when it is the same class, or defer the universal row (listed again next upgrade). A row whose id the template does not hold is the project's — never touched. Then `python3 scripts/gate.py budget` (the parser refuses a duplicate or malformed row).
7. **Seams (EVOL-136), every upgrade.** `seams_upgrade` lists, per seam, the keys it adds, the framework hook commands it replaces and the keys no answer fills. Show the listing; then run it as written (idempotent — a second run adds nothing). Each `unresolved` key is one RDR through the cascade (Step 2); write the answer to that key, then run it again:

```bash
python3 -I - <<'PY'
import json, os, pathlib, shutil, subprocess, sys, tempfile
sys.path.insert(0, "scripts")
from gates import discovery
fills = json.loads(subprocess.run([sys.executable, "scripts/gate.py", "discovery", "--resolve", "--json"], capture_output=True, text=True, check=True).stdout)["placeholders"]
for target, r in discovery.seams_upgrade(pathlib.Path("."), fills).items():
    for k in ("added", "replaced", "unresolved"):
        for x in r[k]:
            print(f"{target} {k}: {x}")
    if r["added"] or r["replaced"]:
        os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(target) or ".")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(json.dumps(r["merged"], indent=2, ensure_ascii=False) + "\n")
            if os.path.exists(target):
                shutil.copymode(target, tmp)
            os.replace(tmp, target)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
PY
```

Migration anchors (registry `migrations`; a row is owed when the project is older than its `since` and its `detect` pointer is missing; a `detect: always` row on every upgrade):

**iterations array (EVOL-032).** Run `bash scripts/migrate-iteration-frontmatter.sh` (idempotent), then set `governance_features.iterations_array_v1` in the project manifest.

**delivery_mode (EVOL-046).** Write Q32's answer as top-level `delivery_mode` in the project manifest. Absent, it resolves to `production` — say so.

**agents.families (EVOL-049).** Write Q34's two aliases to `config/quality.json → agents.families`; materialise `.claude/rules/agents.md` and `.claude/agents/*.md` from the template tree.

**documentation + verification (EVOL-051).** Move `planning.docs_exempt` to `documentation.paths`; add `documentation.exclusions` (template defaults) and the `verification` block (`seal.required: true`, `gates` derived as materialisation resolves `{{VERIFICATION_GATES}}`, `digest_artefacts: ["design.md"]`) — same step as the `scripts/gates/` refresh. Until then the planning gate refuses the retired key.

**traceability (EVOL-053).** Add the block (home derived as materialisation resolves `{{TRACEABILITY_HOME}}`; template grammar, plans, roots, baseline path); deliver `tests/conftest_traceability.py` for Python; then `python3 scripts/gate.py traceability --baseline --init` once.

**contracts (EVOL-072).** After the `scripts/gates/` refresh, with the contracts unchanged: run `python3 scripts/gate.py contracts --json` — exit 1 is expected here, the findings are what it seeds. `n/a` (no contract, no catalog) → nothing to write. Otherwise write its `undeclared` list verbatim to `docs/project_log/crud_baseline.json` as `{"_doc": "CRUD-First findings older than the law (EVOL-072); the list only shrinks", "undeclared": [...]}` (`[]` when empty — the row is then done) and commit it in the upgrade commit: the base's contracts carry those findings, so the gate accepts them; nothing new enters later. Report the count. A catalog finding is no CRUD debt: fix it.

**contracts.emit (EVOL-070).** Add the template's contract-parity keys to `config/quality.json → contracts` (`emit: null`, `tests_root`, `timeout_s`, `_doc_parity`). An API scope (Q4.5 full-stack, backend-only, integration) also gets the loop row `verification.gates.contract-parity` through the derived rows. Say that its next full loop is red until the backend's emit command is written (`rules/contract-first-policy.md` § Contract parity), or a dated skip names why.

**feature_map Version (EVOL-070).** `contracts/feature_map.md` absent → nothing to do. Otherwise add a `Version` column after `Contract Path` to each registry table, and fill each row with its contract's `info.version` (`—` where the contract has none). Run `python3 scripts/gate.py contracts`: its `contracts/feature_map.md` row is green. A row naming no file is fixed or marked SUPERSEDED, never dropped.

**data (EVOL-071).** Add the template's `data` block to `config/quality.json` (`connection_factory`, `baseline`, `migrations_paths`, `_doc`). Then, in this order:

1. **The answer.** `database.migrations_tool` empty while the engine is SQL and a backend exists → Q15.1 is owed through `pending_since`. A Django backend decides it (`derived_answers`); write that value beside the answers.
2. **The old validator.** Delete `scripts/validate-migrations.sh` and every call to it. `gate.py data` replaces it.
3. **The factory.** Name the one module that builds connections in `data.connection_factory`, or leave it `null` when no backend code exists yet.
4. **The baseline.** Run `python3 scripts/gate.py data --json`. Write the `owed` list of its `connection factory` entry verbatim into `docs/project_log/data_baseline.json` (`{"undeclared": [...]}`, each `<path>#<driver>`). The list only shrinks from here. An entry with no `owed` key is red for another reason (a malformed `data.connection_factory`): fix that, then run it again.
5. **The seed registry.** `config/seed_registry.json` absent → nothing to do. Otherwise move it to `seed_registry_v2`: name the `seeder`, and give each entity its `owner` (`{module, create, delete}` or the API's `{create, delete}` operationIds), read from its `owner_domain` module. An owner that cannot be read from the code is one RDR per entity, never a guess.

Run `python3 scripts/gate.py data`: green, or each finding named.

**performance (EVOL-073).** Add the template's `performance` block to `config/quality.json` (`thresholds`, `margin_pct`, `bundles: null`, `endpoints: null`, `warmup`, `samples`, `timeout_s`, `_doc`). Then, in this order:

1. **The answers.** `hosting.type` (Q20.3, unless `hosting.provider` decides it — write the `derived_answers` value), `performance.api_p95` (Q37, a backend exists) and `performance.web` (Q37.1, a frontend exists) unanswered → owed through `pending_since`. Each answer lands its thresholds in `performance.thresholds` (`--resolve` → `configures["performance.thresholds"]`); a frontend answer also adds the loop row `verification.gates.performance` (`gates_upgrade.added`).
2. **The old numbers.** The refreshed rules carry none; a project rule or script that repeats a performance threshold now points to `performance.thresholds` instead.
3. **No baseline.** Nothing writes a deploy record here: the first deployed measurement writes it (EVOL-081). Until then the deployed measurement is advisory on the ratchet and blocking on the thresholds.

Run `python3 scripts/gate.py performance`: green, or each finding named.

**history-in-vcs (EVOL-118).** The operational files carry current state only; the history stays in version control. It drops every `changelog` key of the manifest and the inventory, and the frontmatter `changelog:` of every delivered Markdown target and every `.claude/rules/*.md`; a path outside the project, a symlink or a non-UTF-8 file is skipped; a Markdown file keeps its line endings, a rewritten JSON file is written with indent 2. Idempotent — a clean project changes nothing. Run:

```bash
python3 - <<'PY'
import json, pathlib, re
root = pathlib.Path.cwd().resolve()
def strip(o):
    if isinstance(o, dict): return {k: strip(v) for k, v in o.items() if k != "changelog"}
    if isinstance(o, list): return [strip(x) for x in o]
    return o
def inside(f): return f.is_file() and not f.is_symlink() and f.resolve().is_relative_to(root)
def read(f): return f.read_bytes().decode("utf-8")
man = root / "docs/project_log/governance_versions.json"
tpl = json.loads(read(man)).get("templates") if inside(man) else None
targets = {e["target"] for e in (tpl.values() if isinstance(tpl, dict) else []) if isinstance(e, dict) and isinstance(e.get("target"), str)}
for f in (man, root / "config/codebase_inventory.json"):
    if inside(f):
        d = json.loads(read(f)); c = strip(d)
        if c != d: f.write_bytes((json.dumps(c, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
for f in sorted({root / t for t in targets if t.endswith(".md")} | set((root / ".claude/rules").glob("*.md"))):
    if not inside(f): continue
    try: s = read(f)
    except UnicodeDecodeError: print(f"skipped, not UTF-8: {f.relative_to(root)}"); continue
    m = re.match(r"---\r?\n(.*?\r?\n)---\r?\n", s, re.S)
    if m and re.search(r"^changelog:", m.group(1), re.M):
        fm = re.sub(r"^changelog:[^\r\n]*\r?\n(?:(?:[ \t]+\S|-[ \t])[^\r\n]*\r?\n|[ \t]*\r?\n(?=[ \t]+\S|-[ \t]))*", "", m.group(1), flags=re.M)
        f.write_bytes((s[:m.start(1)] + fm + s[m.end(1):]).encode("utf-8"))
PY
```

Then regenerate the snapshot (`docs/constitution.md` may have moved) and run `python3 scripts/gate.py manifest-parity`: green, or each finding named. Bumps from now on: `gate.py manifest --bump` writes the version only; the why goes in the commit.

**browser-mcp (EVOL-077).** Q23.5's answer (`qa.browser_mcp`, asked when a frontend exists) lands its server in `.mcp.json` → `mcpServers`: the registry row `configures → mcp.servers`, pinned and `--isolated`. The merge keeps every server the project already has. A same-name server with other content is kept and printed: pose it as an RDR (keep it, or take the registry's). `none` or no frontend writes nothing. Idempotent — a second run changes nothing. Materialisation runs this same block. Run:

```bash
python3 - "$@" <<'PY'
import json, os, pathlib, subprocess, sys, tempfile
root = pathlib.Path.cwd().resolve()
cmd = [sys.executable, "scripts/gate.py", "discovery", "--resolve", "--json"] + (["--answers", sys.argv[1]] if len(sys.argv) > 1 else [])
r = subprocess.run(cmd, capture_output=True, text=True)
if r.returncode != 0: sys.exit(f"discovery --resolve failed: {(r.stdout or r.stderr).strip()}")
want = json.loads(r.stdout).get("configures", {}).get("mcp.servers") or {}
f = root / ".mcp.json"
if not want: print("no browser MCP answered: .mcp.json untouched"); sys.exit(0)
if f.is_symlink(): sys.exit(".mcp.json is a symlink: merge the servers by hand")
try: doc = json.loads(f.read_text(encoding="utf-8")) if f.is_file() else {}
except json.JSONDecodeError as e: sys.exit(f".mcp.json is not valid JSON ({e.msg}, line {e.lineno}): fix it, then re-run")
except UnicodeDecodeError: sys.exit(".mcp.json is not UTF-8 text: fix it, then re-run")
if not isinstance(doc, dict) or not isinstance(doc.setdefault("mcpServers", {}), dict): sys.exit(".mcp.json is not {\"mcpServers\": {...}}: merge the servers by hand")
added = []
for name, row in want.items():
    have = doc["mcpServers"].get(name)
    if have is None: doc["mcpServers"][name] = row; added.append(name)
    elif have != row: print(f"kept {name}: it differs from the registry's {row} — RDR: keep it, or take the registry's")
if added:
    fd, tmp = tempfile.mkstemp(dir=root, prefix=".mcp.json.")   # an unpredictable name, created exclusively: no symlink is followed
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out: out.write(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
        if f.is_file(): os.chmod(tmp, f.stat().st_mode & 0o777)   # the project's own mode survives the replace
        os.replace(tmp, f)
    except BaseException:
        os.unlink(tmp); raise
    print("added: " + ", ".join(added))
PY
```

Interactive sessions ask once to approve a project server; the `factory-qa` agent carries the walk's tools of that server by name (`mcp__<server>__<tool>`).

**deploy-tool (EVOL-081).** `hosting.iac_tool` becomes `hosting.deploy_tool` in `docs/setup.md`: a tool answer carries over as is; `None` or no answer on a served host → ask Q20.1 again (Vercel, Railway, Fly.io, Other: decided by the provider, never asked). Then the tool's row from `gate.py discovery --resolve --json → configures.delivery.adapter` lands in `config/quality.json → delivery.adapter` (Other: the finalisation's RDR, Factory-setup-discovery § 4.1.3 step 2a). Idempotent.

**delivery-execution (EVOL-081).** Add the template's `delivery` block to `config/quality.json`: `execution` and `migrate` from `--resolve` (`configures.delivery.execution`, `configures.delivery.migrate`), `adapter` from deploy-tool, `secrets: []`, `probe` as the template. When `coherence.certifying_artefacts` is present, append `docs/spec/*/smoke_e2e_report*.md` and `docs/spec/*/review/preventive_sweep_*.md` where missing (the PR's verdicts are certifying: `gate.py currency` judges their freshness). Write `delivery.execution` beside `delivery.mode` in `docs/setup.md`. `ci` with a hosting provider answered → the deploy pipeline lands — GitHub `.github/workflows/deploy.yml` (`templates_to_add`); Bitbucket merges into the existing `bitbucket-pipelines.yml` (`target_mode: merge`, Factory-setup-materialization) — and a local apply is denied from then. `ci` on GitHub Actions with a hosting provider answered → append `pr-verify` (the Deploy workflow's verdict job) to `scm.required_checks` in `docs/setup.md` and `config/quality.json` where missing, and re-render `docs/scm/protection.md` from its template (it gains the production environment section). `ci` with a hosting provider answered, on any other platform (no deploy template yet, epic #210) → the agent authors the deploy pipeline as materialisation does (Factory-setup-materialization § Delivery, RDR 9), and `gate.py delivery --check` is green before the upgrade closes. A project that already authored one keeps it: the check holds it, nothing is overwritten. No hosting provider answered → no pipeline, no `pr-verify`, `delivery --check` n/a (RDR 7).

**deploy-records (EVOL-081).** Each line of `docs/project_log/performance_baseline.jsonl` becomes a `deploy/{env}/{ts}` record tag on its commit — the line's `site` is the `env`, `at` → `ts`; message JSON `{env, sha, at, hosting, metrics[, rebaseline]}`, written by the executor's own `write_record` (no lkg: a legacy line names no probe). The tags are pushed to `origin` and read back there; only then the file is removed and `performance.baseline` leaves `config/quality.json`. A line whose commit is not in the clone stops it, nothing removed. No file → nothing. Idempotent: a record that exists is skipped. Run it at the project root:

```bash
set -euo pipefail
F=docs/project_log/performance_baseline.jsonl
[ -f "$F" ] || { echo "deploy-records: no baseline file — nothing to convert"; exit 0; }
python3 - "$F" <<'PY'
import datetime as dt, json, subprocess, sys
from pathlib import Path
sys.path.insert(0, "scripts")
from gates import delivery
repo = Path(".")
have = {(r["env"], r["sha"], r.get("at")) for r in delivery.records(repo)}
for n, raw in enumerate(Path(sys.argv[1]).read_text(encoding="utf-8").splitlines(), 1):
    if not raw.strip():
        continue
    e = json.loads(raw)
    r = subprocess.run(["git", "rev-parse", "-q", "--verify", f"{e['sha']}^{{commit}}"], capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"deploy-records: line {n} names {e['sha']}, not a commit of this clone — fetch it, run again; nothing removed")
    env, sha = delivery._env_name(e["site"]), r.stdout.strip()
    if (env, sha, e["at"]) not in have:
        at = dt.datetime.strptime(e["at"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)
        delivery.write_record(repo, env, sha, {k: e[k] for k in ("hosting", "metrics", "rebaseline") if k in e}, good=False, now=at)
        have.add((env, sha, e["at"]))
PY
git push origin 'refs/tags/deploy/*:refs/tags/deploy/*'
python3 - "$F" <<'PY'
import json, subprocess, sys
from pathlib import Path
sys.path.insert(0, "scripts")
from gates import delivery
remote = set(subprocess.run(["git", "ls-remote", "--tags", "origin", "deploy/*"], capture_output=True, text=True, check=True).stdout.split())
recs = delivery.records(Path("."))
for n, raw in enumerate(Path(sys.argv[1]).read_text(encoding="utf-8").splitlines(), 1):
    if raw.strip():
        e = json.loads(raw)
        tag = next((r["tag"] for r in recs if r["env"] == e["site"] and r["sha"].startswith(e["sha"]) and r["at"] == e["at"]), None)
        if not tag or f"refs/tags/{tag}" not in remote:
            sys.exit(f"deploy-records: line {n} is not a record on origin yet — nothing removed")
q = json.loads(Path("config/quality.json").read_text(encoding="utf-8"))
(q.get("performance") or {}).pop("baseline", None)
Path("config/quality.json").write_text(json.dumps(q, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
Path(sys.argv[1]).unlink()
print("deploy-records: every line is a record tag on origin; the baseline file is removed")
PY
```

**proof-at-the-close (EVOL-106).** One row, five writes:

1. **The answer.** `--resolve` lists Q23.8 `testing.e2e_tool` as pending where a frontend exists; ask it (RDR). Not asked → `none`. Write it to `docs/setup.md → testing.e2e_tool`.
2. **The proof block.** Add the template's `proof` block to `config/quality.json`, `tool` ← the answer. `playwright` → `tests/e2e/support/clauses.ts` and `tests/e2e/specs/canary.spec.ts` land (`templates_to_add`). Existing specs keep running; each gains its `[F/C]` title and its clause steps when its feature next moves. Another tool → its helper, canary and converter are built as materialisation builds them (Factory-setup-materialization § End-to-end adapter), and `gate.py proof --check` is green before the upgrade closes.
3. **Delivery.** Add `delivery.preproduction` (the environment the close deploys to before production; the template's `staging`, or the project's name for it) and `delivery.populated: null` — `DEVOPS --configure` writes the row-count command. Each feature still open gets its `devops_plan.md` `## Rollback` section at its next `DEVOPS --configure`. Each open increment plan gains `**Upgrade over data:**` — the pre-production name where its diff carries a migration, `none` otherwise.
4. **Client bounds.** `hosting.type == function` → the pack for `backend.runtime` lands (`templates_to_add`); another runtime gets its pack built as materialisation builds it, held by `semgrep --test`. Write `quality.bounds` (the pack's name, `[]` when none). Then run `python3 scripts/gate.py bounds --baseline --init` once and commit the baseline: today's unbounded clients are the debt; it only shrinks.
5. **Statuses.** Re-run the contracts seed above (`gate.py contracts --json` → `undeclared` → `docs/project_log/crud_baseline.json`): the `status:<path>#<code>` entries the code already carries enter once; nothing new enters later.

**tracker (EVOL-079).** One row, four writes:

1. **The answers.** `--resolve` derives `project_tracking.adapter` (and prints its WARN for a tracker with no adapter) and lists the pending Q27.1 (a `None` project never answered it), Q27.7 and, for Jira, Q27.8–Q27.9; ask them (RDR). Q27.7's recommendation maps the board's existing columns to backlog, ready, in progress, done — no column is renamed.
2. **The tracker block.** Add the template's `tracker` block to `config/quality.json`: `adapter` ← the derived adapter, `flow` ← Q27.7. Check: `python3 scripts/gate.py tracker --ensure <a one-row file naming an existing item> --dry-run` plans nothing — every flow column exists on the board.
3. **The adapter.** Re-render `docs/backlog/tool-adapter.md` from the derived adapter's template (Jira loses its stub banner). A tracker with no adapter (Linear and any other): the derived adapter is `none` — `state.md` lands (`templates_to_add`); copy the open items into it with one `gate.py tracker --ensure` (one row per item, its state), then remove `project-config.json` (`templates_to_remove`). The old stub files under `docs/backlog-tool-adapters/` stay; the team's own board is no longer driven. Jira with Q27.8 `mcp`: run the browser-mcp block above — it merges every `configures → mcp.servers` row, the `atlassian` row included, by the same rule.
4. **Nothing moves at upgrade.** The next phase command's `tracker --start` moves its item; an item in a column outside the flow stays where it is.

**documents (EVOL-080).** One row, three writes:

1. **The answers.** `--resolve` lists the pending Q38 (`documents.source`) and, by its derived `documents.adapter`, Q38.1–Q38.8; ask them (RDR). The recommendation is `None` unless the team already reads its documents in a wiki.
2. **The documents block.** Add the template's `documents` block to `config/quality.json`: `adapter` ← the derived adapter, `site` / `space` / `deployment` / `verify` ← Q38.1 / Q38.2 / the derived deployment / Q38.8, `title_prefix` ← the project name, `homes` ← Q38.5–Q38.7 (`Repo` for an unasked category). A project answering `None` gets `{adapter: none}` and nothing else moves. A store with no shipped adapter (`built`): build `documents.commands` (Factory-setup-materialization § Deliverable homes) and run `python3 scripts/gate.py documents --probe` — no category is homed `External` before it is green. With `verify: ci`, wire the CI's read-only credential (Factory-setup-materialization § Deliverable homes; a built store's `documents.credentials` go into the workflow's env block); with `local`, record the accepted risk in the upgrade report.
3. **No document moves at upgrade.** An approved artefact of a category homed `External` stays a file until its owner phase approves it again; `python3 scripts/gate.py documents` names each one (`--approve` publishes it and writes its pin).

**catalog (EVOL-084).** Q14.1 is pending for a project with a frontend (`since` 10.9.0) — ask it first.

1. **The block.** Add the template's `catalog` block to `config/quality.json`, `packages` / `prefixes` from Q14.1 (`[]` without a frontend — the block stays inert, like `performance`); `local` names the project's own import aliases. Where `bitbucket-pipelines.yml` carries the design-system rebuild step, `surface.declared_reads` gains the entry Factory-setup-materialization § Quality Configuration names.
2. **The registry.** Run it as written (idempotent; no registry, nothing written):

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path("docs/ux/component-registry.json")
if p.is_file():
    r = json.loads(p.read_text(encoding="utf-8"))
    if "design_system_version" not in r:
        r["design_system_version"] = "1.0.0"
        for c in r.get("components") or []:
            if isinstance(c, dict):
                c.setdefault("since", "1.0.0")
        p.write_text(json.dumps(r, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
```

Run `python3 scripts/gate.py catalog`: green, n/a with its reason, or each finding named. Only the UI files a change touches are judged, so the upgrade itself stops nothing.

**scm (EVOL-054).** Add the `scm` block from Q21.2's answer; deliver `docs/scm/protection.md` from the platform's template. Administrators apply it; CI verifies it.

**verification.logs (EVOL-057).** Add the template's `verification.logs` block (`push`, `timings`, `max_kb`).

**turn and probe budgets (EVOL-058).** Add `turn_budget` and `probe_budget` to every size tier of `.claude/rules/agents.md` (template values, the `medium` row) and `maxTurns` (= the large tier's `turn_budget`) to every read-only definition under `.claude/agents/` — same step as the `scripts/gates/` refresh.

**canary (EVOL-059).** Add `agents.canary.line_tolerance` with the template's value; the critics' `Model:` line arrives with the gates refresh.

**critic return shape (EVOL-060).** Refresh the five critic definitions and `scripts/gates/agents.py`; the next spawn carries the two-part return.

**manifest --bump (EVOL-061).** Nothing to write: `gate.py manifest --bump` arrives with the gates refresh.

**context diet (EVOL-062).** Refresh `rules/agents.md` (`worker_turn_cap`, `context_result_max_kb`), the four worker definitions (`maxTurns`), the `Stop` hook `session-handoff.sh` and its `settings.json` wiring.

**verification.gates (EVOL-067).** Write `--resolve --json → gates_upgrade.gates` into `verification.gates` — the merge is the script's, field by field: a derived field the project lacks is added, a value equal to a superseded template value (the registry's `was`) is replaced, a value the project changed is kept (EVOL-068, EVOL-116); report its `added`, `replaced` and `kept` lists (an added `sast` row, EVOL-074: the project installs semgrep 1.182.0, or the member is red; `planning.governed_paths` gains `security/sast/**` and `.semgrepignore` when absent). A `docs/setup.md → verification.commands` key moves into its `verification.gates` row (`test_suite` → `tests`, `test_single` → `tests.scoped` with `{paths}`, `lint`, `typecheck`, `build`, `coverage`, `dependency_audit` → `sca`), then the frontmatter key goes. Nothing dropped. Add `verification.skips: []` when absent.

**verification.gates per-file (EVOL-116).** The same write: the Java, Go, .NET, Rust, Node and frontend rows move to their per-file `scoped` (red when no test ran), gain `red_reads` (and Rust `inline`), and lose the template's `red: false`; a row the project edited is kept and named in `kept`.

**security_scan.secrets_command trufflehog (#189).** When `config/quality.json → security_scan.secrets_command` is byte for byte `trufflehog git file://. --since-commit {{RANGE_BASE}} --fail` (the former template), replace it with `trufflehog git file://. --since-commit={{RANGE_BASE}} --branch={{RANGE_HEAD}} --fail --fail-on-scan-errors --no-update`; any other value is the project's — keep it and name it in the report; a kept value with a bare placeholder after a flag (`--since-commit {{RANGE_BASE}}`) is named with its `--flag={{X}}` form, since the dispatcher refuses it on a scan with no range. Nothing to write on a later upgrade.

**train.close_ledgers (EVOL-104).** Add the template's `train` block (`close_ledgers`: the paths written once per train — the manifest, the inventory) to `config/quality.json`; `gate.py train` reads it.

**contracts.outage_status (EVOL-115).** Add the template's `contracts` block (`outage_status`, default `503`) to `config/quality.json`; `gate.py freeze` is red on the first changed contract without it.

**budgets.hook_output_cap (#240).** The harness swaps a hook's text over its cap for a file path. Run it as written (idempotent): it adds the key when absent or invalid and lowers an injection key above it — never raises one; name each line it prints in the upgrade report:

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path("config/quality.json")
q = json.loads(p.read_text(encoding="utf-8"))
b = q.setdefault("budgets", {})
was = b.get("hook_output_cap")
added = type(was) is not int or was < 1
if added:
    b["hook_output_cap"] = 10000   # the template's value at 10.9.2 (the harness cap per hook text); a project's own positive int is kept
    if was is not None:
        print(f"budgets.hook_output_cap: {was!r} -> 10000 (not a positive integer)")
cap = b["hook_output_cap"]
lowered = [(k, b[k]) for k in ("session_start", "prompt_submit", "pre_edit") if type(b.get(k)) is int and b[k] > cap]
for k, _ in lowered:
    b[k] = cap
if added or lowered:
    p.write_text(json.dumps(q, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
for k, old in lowered:
    print(f"budgets.{k}: {old} -> {cap} (budgets.hook_output_cap)")
PY
```

**session-notebook (EVOL-133).** The session notebook's two budget keys and its two hook wirings. Run it as written (idempotent): it adds `budgets.notebook_reinject` and `budgets.notebook_precompact` when absent or invalid (at the template's value, or the project's `budgets.hook_output_cap` when lower; a valid value is never touched), adds the `UserPromptSubmit` entry that runs `scripts/gate.py notebook --hook-json` when the event exists and no entry runs it (an absent event is added whole by the seams step, 8b.7), and widens the `PostToolUse` entry that runs `scripts/governance-onedit.sh` to `Edit|Write|Bash`; a project's own entries and values are kept. Name each line it prints in the upgrade report:

```bash
python3 - <<'PY'
import json, pathlib
def load(p):
    return json.loads(p.read_text(encoding="utf-8"))
q_path, s_path = pathlib.Path("config/quality.json"), pathlib.Path(".claude/settings.json")
q = load(q_path)
b = q.setdefault("budgets", {})
changed_q = False
cap = b.get("hook_output_cap")
for k, v in (("notebook_reinject", 9000), ("notebook_precompact", 1000)):   # the template's values at 10.10.0
    if type(cap) is int and cap > 0:
        v = min(v, cap)
    if type(b.get(k)) is not int or b[k] < 1:
        print(f"budgets.{k}: {b.get(k)!r} -> {v}")
        b[k] = v
        changed_q = True
if changed_q:
    q_path.write_text(json.dumps(q, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
s = load(s_path) if s_path.exists() else {}
h = s.get("hooks") if isinstance(s.get("hooks"), dict) else {}
changed_s = False
ups = h.get("UserPromptSubmit")
if isinstance(ups, list) and not any("scripts/gate.py notebook --hook-json" in (x.get("command") or "") for e in ups for x in e.get("hooks", [])):
    ups.append({"hooks": [{"type": "command", "command": 'cd "${CLAUDE_PROJECT_DIR:-.}" && python3 scripts/gate.py notebook --hook-json || true'}]})
    print("hooks.UserPromptSubmit: + scripts/gate.py notebook --hook-json")
    changed_s = True
for e in h.get("PostToolUse", []):
    if e.get("matcher") == "Edit|Write" and any("scripts/governance-onedit.sh" in (x.get("command") or "") for x in e.get("hooks", [])):
        e["matcher"] = "Edit|Write|Bash"
        print("hooks.PostToolUse: governance-onedit.sh matcher Edit|Write -> Edit|Write|Bash")
        changed_s = True
if changed_s:
    s_path.write_text(json.dumps(s, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
```

**owners (EVOL-136).** Stamps on each project snapshot entry the `owner` the delivered manifest declares, where the entry has none, and sets `governance_features.owners_v1`. Run it as written (idempotent); name the count it prints in the upgrade report:

```bash
python3 -I - <<'PY'
import json, pathlib
snap_p = pathlib.Path("docs/project_log/governance_versions.json")
d = json.loads(pathlib.Path(".context/templates/setup/governance_versions.json").read_text(encoding="utf-8"))
snap = json.loads(snap_p.read_text(encoding="utf-8"))
n = 0
for sec in ("templates", "agent_templates", "framework_core"):
    for k, e in (snap.get(sec) or {}).items():
        src = (d.get(sec) or {}).get(k)
        if isinstance(e, dict) and isinstance(src, dict) and src.get("owner") and "owner" not in e:
            e["owner"] = src["owner"]; n += 1
feats = snap.setdefault("governance_features", {})
if n or not feats.get("owners_v1"):
    feats["owners_v1"] = True
    snap_p.write_text(json.dumps(snap, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"owners stamped: {n}")
PY
```

---

### Step 3: New File Handling (4.4.3)
Files that exist in framework but not in project:
1. Apply the Smart Discovery Cascade (Step 2) for placeholder resolution
2. Apply RDR for unresolvable placeholders
3. Apply Zero-TODO Enforcement
4. Write new file
5. Register in `governance_versions.json`

**Special case — `claude/CLAUDE.md`, `claude/settings.json`, `config/quality.json`:** root `CLAUDE.md` is project-owned — present, it is never written here (its template moves are owed to EVOL-137); absent, it lands as a new file. `.claude/settings.json` and `config/quality.json` are seams (Step 8b.7): a missing one lands from its template, the rest is keyed add-only. The `planning` block of `config/quality.json` and the framework hook entries land in the **same** run — a wired gate with no `planning` key blocks every write except the one that adds the key.

**Git hooks:** installed hooks are copies. After `scripts/hooks/**` is refreshed, run `bash scripts/install-hooks.sh --force` — a hook added since the last install (`pre-merge-commit`, EVOL-065) lands only this way.

### Step 4: Finalization (4.4.4)
1. Update project snapshot (`governance_versions.json`): each written entry's version and `owner`
2. Finalize backup manifest: `status: COMPLETED`
2b. **Seed the dependency allowlist (#114):** `python3 scripts/gate.py dependencies --seed` — Q26's answers (`docs/setup.md → dependencies.backend / frontend / denied`) merge into `config/allowlist.json`; an entry already listed is kept as written. Step 2 replaced the `dependency-allowlist.sh` stub with the real check where the stub was delivered.
3. **Regenerate governance snapshot** (`.context/governance_snapshot.md`):
   - Constitution / defect-prevention.md / setup.md may have changed during upgrade → snapshot must reflect new state
   - Call `generate_governance_snapshot()` from setup-materialization.md Checkpoint 3.1
   - The current format embeds the law INDEX: `## [PLAW-NN]` entries of the constitution (sentence + `Body:` pointer + `Records:`) + the defect families table (classes are delivered at the point of edit). If the upgraded constitution still carries the pre-4.0.0 `## [LAW] {title}` section form, the upgrade MUST convert it to the index form per the materialization template (bodies to their `.claude/rules/` homes, `> sentence` byte-identical on both sides) before regen, otherwise the snapshot's `## Law Index` section will be empty and CI will fail
   - Frontmatter freshness fields are: `constitution_hash`, `setup_hash`, `dcs_hash` — all three are recomputed
   - This ensures post-upgrade agent commands use fresh governance context
4. Generate `UPGRADE_REPORT_{timestamp}.md` with:
   - Files replaced (framework-owned, with before/after versions) and the drift `manifest-parity` named
   - New files added
   - Seam keys added, replaced and unresolved (Step 8b.7)
   - Templates moved and not written (`templates_moved`)
   - Skipped files (with reason)
5. `APPEND_TO_WORKLOG` × 3 (start, execution, completion)

### Developer Workflow for Template Authors (4.4.5)
When updating framework templates:
- Follow SemVer bump rules (MAJOR: breaking, MINOR: additive, PATCH: fix)
- Update `governance_versions.json` with the new version (state only — the why in the commit, EVOL-118)
- Give every new `{{TOKEN}}` one source in `discovery_registry.json` (a key's `fills`, a derived `fills`, `constants`) — `gate.py discovery` V10 holds it

---

## Command: `--rollback-upgrade` (4.5)

Reverts a failed or unwanted upgrade to a previous state.

### Prerequisite Validation
- `BACKUP_MANIFEST.json` must exist with `status: COMPLETED`
- List available rollback points (from backup history) for user selection

### Atomic Rollback Execution
1. **Pre-rollback checkpoint:** Save current state as emergency recovery point
2. **Checksum verification:** For each file to restore, verify backup file integrity
3. **Atomic copy:** Restore all files from backup (all or nothing)
4. **Update snapshot:** Revert `governance_versions.json` to pre-upgrade state
5. **Validate restoration:** Verify all restored files match expected checksums

### Emergency Rollback
If atomic rollback fails:
- Provide manual intervention protocol with step-by-step commands
- List files that need manual restoration
- Point to backup location

### Post-Rollback Report
- Files restored (with checksums)
- Post-rollback validation results
- `APPEND_TO_WORKLOG` with rollback details

### Post-Upgrade Validation Script
`validate-upgrade-integrity.sh` performs 6 checks:
1. All files in snapshot exist on disk
2. All checksums match recorded values
3. No orphan governance files
4. No broken cross-references between rules
5. Constitution.md has no unresolved placeholders
6. All scripts pass syntax check

---

## Command: `--migrate-legacy-setup` (4.3) — EXPERIMENTAL

**⚠️ Status: EXPERIMENTAL** — Behavior, scoring, and thresholds may change.

**Prerequisites:**
- `project_mode: Brownfield` in `docs/setup.md`
- **Strategy Gate:** If `extension.strategy: E0` (Native Extension) → SKIP migration strategy entirely (E0 does not involve migration). Only E1/E2/E3 proceed.

### NO-FORCE Policy
There is NO `--force` option. If viability score is too low, the command ABORTS. No override exists.

### Step 1: Automatic Viability Analysis (4.3.2)
**BLOCKING** — runs before any user interaction.

6-phase scoring with weighted criteria (total: 100 points):

| Phase | Weight | What it measures |
|-------|--------|-----------------|
| Stack Detection | 25% | Can we identify the technology stack? |
| Test Coverage | 20% | Does the project have meaningful tests? |
| Documentation | 15% | Is existing documentation usable? |
| Architectural Complexity | 20% | How complex is the current architecture? |
| Dependencies State | 10% | Are dependencies healthy and current? |
| External Integrations | 10% | How many external systems are coupled? |

**Threshold: 85%**
- **Score > 85% (VIABLE):** Continue to guided analysis
- **Score ≤ 85% (NOT_VIABLE):** **ABORT** with blockers list. No override exists.

Generates viability report with per-phase scores and overall verdict.

### Step 2: Legacy Analysis Guided (4.3.3)
4 interactive questions (conditional on viability phase scores):
- Questions about codebase age, team familiarity, technical debt areas, migration urgency
- Skip questions where viability scan already provided high-confidence answers

### Step 3: Migration Strategy Generation (4.3.4)

**Strategy-specific phase templates by extension strategy:**

| Strategy | Approach | Key Phases |
|----------|----------|------------|
| E1 (Preserve+Wrapper) | Build adapters around existing code | Adapter layer → New modules → Integration testing → Gradual adoption |
| E2 (Strangler Fig) | Build new around old, replace incrementally | Proxy layer → Module-by-module replacement → Data migration → Legacy decommission |
| E3 (Full Rewrite) | Freeze legacy, build fresh | Specification capture → New build → Data migration → Cut-over |

**Generates:**
- `docs/migration_strategy.md` with strategy-specific content
- 5 actionable Epics (MIGR-001 through MIGR-005)
- Estimated roadmap (up to 12 months)
- Risk assessment table

---

## Architecture Reference

### Backend Topologies (B1-B12)

| ID | Name | Tier | Cost/mo |
|----|------|------|---------|
| B1 | Traditional Monolith | Starter | $150 |
| B2 | Modular by Bounded Contexts | Professional | $300 |
| B3 | DDD + Event Sourcing | Professional | $450 |
| B4 | Microkernel + Plugins | Professional | $480 |
| B5 | Microservices REST | Professional | $800 |
| B6 | Microservices Event-Driven | Enterprise | $1,100 |
| B7 | Microservices CQRS+ES | Enterprise | $1,300 |
| B8 | SOA + ESB | Enterprise | $700 |
| B9 | Serverless | Professional | $400 |
| B10 | Peer-to-Peer | Enterprise | $900 |
| B11 | Broker/Pipeline | Enterprise | $650 |
| B12 | MVC Monolith | Starter | $150 |

### Frontend Patterns (F1-F10)

| ID | Name | Tier | Cost/mo |
|----|------|------|---------|
| F1 | SPA | Starter | $100 |
| F2 | SSR + Hydration | Professional | $150 |
| F3 | SSR Pure | Starter | $120 |
| F4 | ISR | Professional | $180 |
| F5 | MFE Module Federation | Enterprise | $400 |
| F6 | MFE iFrames | Enterprise | $400 |
| F7 | MFE Web Components | Enterprise | $400 |
| F8 | Islands Architecture | Professional | $200 |
| F9 | PWA | Starter | $120 |
| F10 | Component-Driven | Starter | $100 |

### Integration Layer
- **ACL Global:** Anti-Corruption Layer between backend and frontend
- **Backend Aggregator Pattern:** For distributed topologies (B5-B11), aggregate cross-service data at the API gateway level

---

## Logging Standards

All SETUP commands use `APPEND_TO_WORKLOG` with phase mapping:

| Command | Phase |
|---------|-------|
| --init | Discovery |
| --generate | Materialization |
| --generate --resume | Materialization |
| --migrate-legacy-setup | Materialization |
| --upgrade | Materialization |
| --rollback-upgrade | Correction |

---

## Responsibilities Summary

| Command | Input | Output | Final State |
|---------|-------|--------|-------------|
| --init | User answers | docs/setup.md + ADR-0000 | phase: COMPLETED |
| --generate | setup.md (COMPLETED) | All governance + scaffolding | materialization_complete: true |
| --generate --resume | MATERIALIZATION_REPORT (IN_PROGRESS) | Remaining tasks | status: COMPLETED |
| --migrate-legacy-setup | Brownfield project | migration_strategy.md + 5 Epics | Strategy generated |
| --upgrade | Framework templates | Framework-owned files replaced, seams merged by key, project files untouched + UPGRADE_REPORT | Snapshot updated |
| --rollback-upgrade | BACKUP_MANIFEST | Restored files | Pre-upgrade state |

**SETUP is responsible for:** Project structure, governance, scaffolding, configuration, budget.
**SETUP is NOT responsible for:** Source code, tests, deployment, feature implementation — those belong to IMPLEMENTDEVOPSQA.
