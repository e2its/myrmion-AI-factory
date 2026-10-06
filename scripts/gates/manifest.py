"""The manifest bump as a tool, not a ritual (EVOL-061).

One helper behind `python3 scripts/gate.py manifest`:

bump    `--bump --entry <path> [--entry …] --level patch|minor|major --note "<what and why>" [--framework LEVEL] [--base REF | --no-base]`
        moves each entry's version by the level, prepends the changelog line in the entry's shape (`"<version>: <note>"`), moves
        the file's frontmatter `version:` when it carries one, and — with --framework — framework_version, last_updated and the
        description prefix. Idempotent over an entry already moved on the branch (against the base manifest): the version stays,
        the top changelog note is replaced only when it differs. Nothing is written until every entry resolved; the manifest is
        written before the frontmatters, so a fault never leaves a file ahead of the manifest. The note is mandatory.
new     `--new <path> [--target T]` adds an entry at 1.0.0 in the section the path belongs to (the framework repo only; the file
        must exist); a template's target and delivery follow its nearest sibling's convention, or --target names it.
check   `--check --entry <path> …`: verifies without writing — advanced against the base, the top line starts with the version,
        the frontmatter in parity, framework_version advanced when entries moved; every reason listed; a base that cannot be read
        is a fault, never a green over nothing compared.

The governance check (validate-governance.sh CHECK 1b, gate.py manifest-parity) does not change: it verifies the same line
whoever wrote it. The helper touches the manifest and the files' frontmatter `version:` lines, nothing else.
"""
from __future__ import annotations

import datetime as dt
import json
import re
import subprocess
from pathlib import Path

from . import coherence
from .common import GateFault

LEVELS = ("patch", "minor", "major")
SECTIONS = ("framework_core", "templates", "agent_templates")
VERSION_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
FM_VERSION_RE = re.compile(r'^(version:[ \t]*)(["\']?)(\d+\.\d+\.\d+)(\2)[ \t]*$', re.M)
META_ROOTS = (".claude/", "scripts/", ".github/workflows/", "config/")   # where a framework_core file lives (and CLAUDE.md itself)
COPIED_FROM_SIBLING = ("delivery", "type", "content_type")   # a sibling's channel and kind — never its prose (role) nor its stack condition (a new file ships everywhere until it says otherwise)


def _rel(path: str) -> str:
    """A repo-relative path: a leading `./` dropped, nothing else (never a character strip — `.context/…` keeps its dot)."""
    p = path.strip()
    return p[2:] if p.startswith("./") else p


def _semver(v: str) -> tuple[int, int, int]:
    m = VERSION_RE.match(str(v).strip())
    if not m:
        raise GateFault(f"`{v}` is not a version (MAJOR.MINOR.PATCH)")
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def bump_version(v: str, level: str) -> str:
    if level not in LEVELS:
        raise GateFault(f"--level must be one of {', '.join(LEVELS)}, not `{level}`")
    a, b, c = _semver(v)
    return {"patch": f"{a}.{b}.{c + 1}", "minor": f"{a}.{b + 1}.0", "major": f"{a + 1}.0.0"}[level]


def load(repo: Path) -> tuple[Path, dict]:
    p = coherence.manifest_path(repo)
    try:
        return p, json.loads(p.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise GateFault(f"the manifest {p.relative_to(repo)} is not readable JSON: {e}") from e


def _entries(m: dict, sec: str):
    for k, e in (m.get(sec) or {}).items():
        if isinstance(e, dict) and "version" in e:
            yield k, e


def core_file(key: str, e: dict) -> str:
    """The file a framework_core entry names — its `path`, else the key under `.claude/` (the rule CHECK 1b reads by)."""
    return e.get("path") or (key if key.startswith(".") else ".claude/" + key)


def resolve(repo: Path, m: dict, path: str) -> tuple[str, str]:
    """A repo-relative file path → (section, key). The framework repo: framework_core by the entry's file (path or `.claude/` + key),
    templates and agent_templates by the key under their root. A project: by the entry's materialisation `target` — one match, never
    an arbitrary one. `section:key` names an entry directly."""
    rel = _rel(path)
    if ":" in rel and rel.split(":", 1)[0] in SECTIONS:
        sec, key = rel.split(":", 1)
        if key in (m.get(sec) or {}):
            return sec, key
        raise GateFault(f"`{rel}`: no entry `{key}` in {sec}")
    for k, e in _entries(m, "framework_core"):
        if core_file(k, e) == rel or k == rel:
            return "framework_core", k
    for sec in ("templates", "agent_templates"):
        root = coherence.ROOTS[sec]
        if root and rel.startswith(root) and rel[len(root):] in (m.get(sec) or {}):
            return sec, rel[len(root):]
    hits = [(sec, k) for sec in SECTIONS for k, e in _entries(m, sec) if e.get("target") == rel]
    if len(hits) == 1:
        return hits[0]
    if len(hits) > 1:
        raise GateFault(f"`{rel}` is the target of {len(hits)} entries ({', '.join(f'{s}:{k}' for s, k in hits)}) — name one as section:key")
    raise GateFault(f"`{rel}` matches no manifest entry (framework_core by its file, templates under {coherence.ROOTS['templates']}, "
                    f"agent_templates under {coherence.ROOTS['agent_templates']}, a project's by target) — a new file is added with --new, never silently")


def file_of(repo: Path, m: dict, sec: str, key: str) -> Path | None:
    """The file an entry names, when it is in this tree: the meta path, else the project's target."""
    e = m[sec][key]
    cands = [core_file(key, e)] if sec == "framework_core" else [coherence.ROOTS[sec] + key, e.get("target")]
    for cand in cands:
        if cand and (repo / cand).is_file():
            return repo / cand
    return None


def base_manifest(repo: Path, p: Path, base: str | None, no_base: bool = False) -> dict | None:
    """The manifest at the base ref: `--base REF`, else the branching grammar's one diff base. A ref that cannot be read is a fault —
    never a silent `every entry moves`; `--no-base` is the one way to say so on purpose."""
    if no_base:
        return None
    ref = base
    if not ref:
        from . import branch as branch_mod
        try:
            ref = branch_mod.diff_base(repo)
        except Exception as e:   # noqa: BLE001 — the grammar's own fault, humanised with the way out: a base nobody can read is never silent
            raise GateFault(f"{e} — pass --base REF, or --no-base to move every entry on purpose") from e
    rel = p.relative_to(repo).as_posix()
    try:
        r = subprocess.run(["git", "-C", str(repo), "show", f"{ref}:{rel}"], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise GateFault(f"the base manifest `{ref}:{rel}` cannot be read ({e}) — fetch the base, pass --base REF, or --no-base on purpose") from e
    if r.returncode != 0:
        raise GateFault(f"the base manifest `{ref}:{rel}` cannot be read ({(r.stderr or '').strip()[:120]}) — fetch the base, pass --base REF, or --no-base on purpose")
    try:
        return json.loads(r.stdout)
    except ValueError as e:
        raise GateFault(f"the base manifest `{ref}:{rel}` is not JSON: {e}") from e


def _branch(repo: Path) -> str:
    try:
        r = subprocess.run(["git", "-C", str(repo), "branch", "--show-current"], capture_output=True, text=True, timeout=10)
        return r.stdout.strip() or "HEAD"
    except (OSError, subprocess.TimeoutExpired):
        return "HEAD"


def _frontmatter(s: str) -> tuple[str, str] | None:
    if not s.startswith("---"):
        return None
    end = s.find("\n---", 3)
    return None if end < 0 else (s[:end], s[end:])


def frontmatter_version(f: Path) -> tuple[str, str | None]:
    """(status, version): `none` (no frontmatter version), `unreadable`, `unmatched` (a version: line the shape does not read), or `ok`."""
    try:
        s = f.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return "unreadable", None
    fm = _frontmatter(s)
    if fm is None:
        return "none", None
    m = FM_VERSION_RE.search(fm[0])
    if m:
        return "ok", m.group(3)
    return ("unmatched", None) if re.search(r"^version:", fm[0], re.M) else ("none", None)


def _frontmatter_bump(f: Path, new: str) -> str:
    """Move a file's frontmatter `version:` line to `new`: `moved`, or why not (`none`, `unreadable`, `unmatched`)."""
    status, _ = frontmatter_version(f)
    if status != "ok":
        return status
    s = f.read_text(encoding="utf-8")
    head, tail = _frontmatter(s)
    m = FM_VERSION_RE.search(head)
    try:
        f.write_text(head[:m.start()] + f"{m.group(1)}{m.group(2)}{new}{m.group(4)}" + head[m.end():] + tail, encoding="utf-8")
    except OSError:
        return "unwritable"   # the manifest is on disk already: said in the result, manifest-parity holds it, a re-run heals it
    return "moved"


def _shared_dirs(a: str, b: str) -> int:
    ap, bp = a.split("/"), b.split("/")
    n = 0
    while n < min(len(ap), len(bp)) - 1 and ap[n] == bp[n]:
        n += 1
    return n


def _sibling(m: dict, sec: str, key: str, with_target: bool = False) -> dict | None:
    """The nearest sibling of a key in a section: the entry sharing the longest key directory (one at least)."""
    best = None
    for k, e in _entries(m, sec):
        if k == key or (with_target and not e.get("target")):
            continue
        n = _shared_dirs(k, key)
        if n and (best is None or n > best[0]):
            best = (n, k, e)
    return {"key": best[1], "entry": best[2]} if best else None


def _sibling_target(m: dict, sec: str, key: str) -> str | None:
    """A new template's target by its nearest sibling's convention; None when no sibling tells."""
    sib = _sibling(m, sec, key, with_target=True)
    if not sib:
        return None
    k, t = sib["key"], sib["entry"]["target"]
    if t == k:
        return key
    if t == "." + k:
        return "." + key
    if t == ".claude/" + k:
        return ".claude/" + key
    return None   # any other convention (claude/CLAUDE.md → CLAUDE.md, docs/…, workflows/…) is named with --target


def _sibling_fields(m: dict, sec: str, key: str) -> dict:
    sib = _sibling(m, sec, key)
    return {f: sib["entry"][f] for f in COPIED_FROM_SIBLING if sib and f in sib["entry"]}


def plan_new(repo: Path, m: dict, path: str, target: str | None) -> tuple[str, str, dict]:
    """The section, key and entry of a new tracked file (the framework repo only: the manifest carries framework_core)."""
    if "framework_core" not in m:
        raise GateFault("--new is the framework repo's act: a project's manifest has no framework_core — a project's files arrive by SETUP, never by hand")
    rel = _rel(path)
    if not (repo / rel).is_file():
        raise GateFault(f"--new `{rel}`: no such file in this tree — an entry names a file that exists")
    if rel.startswith(coherence.ROOTS["templates"]):
        sec, key = "templates", rel[len(coherence.ROOTS["templates"]):]
        t = target or _sibling_target(m, sec, key)
        if not t:
            raise GateFault(f"--new `{rel}`: no sibling under `{key.split('/')[0]}/` tells where it materialises — pass --target <project path>")
        extra = {"content_type": "universal", **_sibling_fields(m, sec, key), "target": t}
    elif rel.startswith(coherence.ROOTS["agent_templates"]):
        sec, key = "agent_templates", rel[len(coherence.ROOTS["agent_templates"]):]
        extra = {"content_type": "universal", **_sibling_fields(m, sec, key), "target": target or rel}
    elif rel.startswith(META_ROOTS) or rel == "CLAUDE.md":
        sec = "framework_core"; key = rel[len(".claude/"):] if rel.startswith(".claude/") else rel
        extra = {**_sibling_fields(m, sec, key), "path": rel}
    else:
        raise GateFault(f"--new `{rel}`: outside every tracked tree ({', '.join(META_ROOTS)}, {coherence.ROOTS['templates']}, {coherence.ROOTS['agent_templates']}) — not a tracked file")
    if key in (m.get(sec) or {}):
        raise GateFault(f"--new `{rel}`: the entry `{key}` already exists in {sec} — bump it with --entry")
    return sec, key, extra


def bump(repo: Path, entries: list[str], level: str | None, note: str, framework: str | None = None, base: str | None = None,
         new: list[str] | None = None, write: bool = True, no_base: bool = False, target: str | None = None) -> dict:
    note = (note or "").strip()
    if not note:
        raise GateFault("--note is mandatory and never empty: the changelog keeps its why (what changed and why)")
    if entries and level not in LEVELS:
        raise GateFault(f"--level must be one of {', '.join(LEVELS)}, not `{level}`")
    if framework and framework not in LEVELS:
        raise GateFault(f"--framework must be one of {', '.join(LEVELS)}, not `{framework}`")
    if not entries and not new:
        raise GateFault("nothing to bump: name at least one --entry <path> or --new <path>")
    if base and no_base:
        raise GateFault("--base and --no-base together say two things — pass one")
    p, m = load(repo)
    if framework and "framework_core" not in m:
        raise GateFault("--framework is the framework repo's act: a project's framework_version is the framework it materialised")
    basem = base_manifest(repo, p, base, no_base)
    # plan everything first: nothing is written until every path resolved and every version computed
    plan_added = [plan_new(repo, m, path, target) for path in new or []]
    plan_entries = []; seen: set[tuple[str, str]] = set()
    for path in entries:
        sec, key = resolve(repo, m, path)
        if (sec, key) in seen:   # one plan per entry, however many ways it was named
            continue
        seen.add((sec, key))
        e = m[sec][key]; cur = str(e["version"]); _semver(cur)
        base_v = ((basem or {}).get(sec) or {}).get(key, {}).get("version") if basem else None
        already = basem is not None and (base_v is None or _semver(cur) > _semver(str(base_v)))   # added or moved on this branch already
        newv = cur if already else bump_version(cur, level)
        if base_v is not None and not already and not _semver(newv) > _semver(str(base_v)):
            raise GateFault(f"{sec}:{key}: {cur} → {newv} would not pass the base's {base_v} — the branch is behind its base: rebase first")
        plan_entries.append((sec, key, cur, newv, already, base_v))
    fw = None
    if framework:
        cur = str(m.get("framework_version", "0.0.0")); _semver(cur)
        base_v = (basem or {}).get("framework_version") if basem else None
        fw_already = base_v is not None and _semver(cur) > _semver(str(base_v))
        fw = {"version": cur, "kept": True} if fw_already else {"from": cur, "to": bump_version(cur, framework)}
    # apply: the manifest in memory, the manifest on disk, then the frontmatters
    moved, kept, added, frontmatter, skipped = [], [], [], [], []
    for sec, key, extra in plan_added:
        m.setdefault(sec, {})[key] = {"version": "1.0.0", **extra, "changelog": [f"1.0.0: {note}"]}
        added.append({"entry": f"{sec}:{key}", "target": extra.get("target") or extra.get("path")})
    for sec, key, cur, newv, already, base_v in plan_entries:
        e = m[sec][key]; cl = e.setdefault("changelog", [])
        if already:
            top = cl[0] if cl else ""; wanted = f"{cur}: {note}"; line = None
            if top.startswith(cur + ":"):
                if top != wanted:
                    cl[0] = wanted; line = wanted
            else:
                cl.insert(0, wanted); line = wanted
            kept.append({"entry": f"{sec}:{key}", "version": cur, "base": base_v, "line": line})
        else:
            e["version"] = newv; cl.insert(0, f"{newv}: {note}")
            moved.append({"entry": f"{sec}:{key}", "from": cur, "to": newv})
    if fw and not fw.get("kept"):
        m["framework_version"] = fw["to"]; m["last_updated"] = dt.date.today().isoformat()
        m["description"] = f"v{fw['to']} ({_branch(repo)}): {note}. " + str(m.get("description", ""))
    if write:
        p.write_text(json.dumps(m, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for sec, key, cur, newv, already, base_v in plan_entries:
        f = file_of(repo, m, sec, key)
        if f is None:
            continue
        status = _frontmatter_bump(f, newv) if write else frontmatter_version(f)[0]
        if status in ("moved", "ok"):
            frontmatter.append(str(f.relative_to(repo)))
        elif status in ("unreadable", "unmatched", "unwritable"):
            skipped.append({"file": str(f.relative_to(repo)), "reason": status})
    return {"ok": True, "manifest": str(p.relative_to(repo)), "base": "none (every entry moves — --no-base)" if basem is None else (base or "diff base"),
            "moved": moved, "kept": kept, "added": added, "framework": fw, "frontmatter": frontmatter, "frontmatter_skipped": skipped, "written": write}


def check(repo: Path, entries: list[str], base: str | None = None, framework: bool = False, no_base: bool = False) -> list[str]:
    if not entries:
        raise GateFault("nothing to check: name at least one --entry <path>")
    if base and no_base:
        raise GateFault("--base and --no-base together say two things — pass one")
    p, m = load(repo)
    basem = base_manifest(repo, p, base, no_base)
    problems: list[str] = []
    any_moved = False
    for path in entries:
        try:
            sec, key = resolve(repo, m, path)
        except GateFault as e:
            problems.append(str(e)); continue
        e = m[sec][key]; cur = str(e["version"])
        top = (e.get("changelog") or [""])[0]
        if not top.startswith(cur + ":"):
            problems.append(f"{sec}:{key}: the top changelog line does not start with `{cur}:` — the line names the version it describes")
        elif not top[len(cur) + 1:].strip():
            problems.append(f"{sec}:{key}: the changelog line carries no note")
        if basem is not None:
            base_v = ((basem.get(sec) or {}).get(key) or {}).get("version")
            if base_v is not None and not _semver(cur) > _semver(str(base_v)):
                problems.append(f"{sec}:{key}: version {cur} did not advance against the base ({base_v}) — gate.py manifest --bump --entry {path} --level … --note …")
            else:
                any_moved = True
        f = file_of(repo, m, sec, key)
        if f is not None:
            status, v = frontmatter_version(f)
            if status == "ok" and v != cur:
                problems.append(f"{sec}:{key}: frontmatter version {v} ≠ manifest {cur} (manifest-parity)")
            elif status in ("unreadable", "unmatched"):
                problems.append(f"{sec}:{key}: the file's frontmatter version line cannot be read ({status}) — parity cannot be verified")
    if framework and basem is not None and any_moved:
        cur, base_v = str(m.get("framework_version")), str(basem.get("framework_version"))
        if not _semver(cur) > _semver(base_v):
            problems.append(f"framework_version {cur} did not advance against the base ({base_v}) while entries moved — gate.py manifest --bump … --framework patch|minor|major")
    return problems


def render(r: dict) -> str:
    lines = [f"manifest: {r['manifest']} · base {r['base']}" + ("" if r["written"] else " · dry run")]
    for x in r["moved"]:
        lines.append(f"  ↑ {x['entry']}: {x['from']} → {x['to']}")
    for x in r["kept"]:
        lines.append(f"  = {x['entry']}: {x['version']} already moved on this branch (base {x['base'] or 'absent'})" + (" — the line written" if x["line"] else ""))
    for x in r["added"]:
        lines.append(f"  + {x['entry']}: 1.0.0 → {x['target']}")
    if r["framework"]:
        fw = r["framework"]
        lines.append(f"  framework_version: {fw['version']} already moved on this branch" if fw.get("kept") else f"  framework_version: {fw['from']} → {fw['to']}")
    for f in r["frontmatter"]:
        lines.append(f"  frontmatter version {'moved' if r['written'] else 'would move'}: {f}")
    for x in r.get("frontmatter_skipped", []):
        lines.append(f"  ! frontmatter NOT moved ({x['reason']}): {x['file']} — move it by hand, manifest-parity holds it")
    return "\n".join(lines)
