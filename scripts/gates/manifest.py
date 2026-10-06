"""The manifest bump as a tool, not a ritual (EVOL-061).

One helper behind `python3 scripts/gate.py manifest`:

bump    `--bump --entry <path> [--entry …] --level patch|minor|major --note "<what and why>" [--framework LEVEL] [--base REF]`
        moves each entry's version by the level, prepends the changelog line in the entry's shape (`"<version>: <note>"`), moves
        the file's frontmatter `version:` when it carries one, and — with --framework — framework_version, last_updated and the
        description prefix. Idempotent over an entry already moved on the branch (against the base manifest): the version stays,
        the top changelog note is replaced only when it differs. The note is mandatory.
new     `--new <path>` adds an entry at 1.0.0 in the section the path belongs to (the framework repo), the note its first line.
check   `--check --entry <path> …`: verifies without writing — advanced against the base, the top line starts with the version,
        the frontmatter in parity, framework_version advanced when entries moved; every reason listed.

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
FM_VERSION_RE = re.compile(r'^(version:\s*)(["\']?)(\d+\.\d+\.\d+)(\2)\s*$', re.M)


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


def resolve(repo: Path, m: dict, path: str) -> tuple[str, str]:
    """A repo-relative file path → (section, key). The framework repo: framework_core by the entry's `path`, templates and
    agent_templates by the key under their root. A project: by the entry's materialisation `target`. `section:key` is accepted."""
    rel = _rel(path)
    if ":" in rel and rel.split(":", 1)[0] in SECTIONS:
        sec, key = rel.split(":", 1)
        if key in (m.get(sec) or {}):
            return sec, key
        raise GateFault(f"`{rel}`: no entry `{key}` in {sec}")
    for k, e in _entries(m, "framework_core"):
        if e.get("path") == rel or k == rel:
            return "framework_core", k
    for sec in ("templates", "agent_templates"):
        root = coherence.ROOTS[sec]
        if root and rel.startswith(root) and rel[len(root):] in (m.get(sec) or {}):
            return sec, rel[len(root):]
    for sec in SECTIONS:
        for k, e in _entries(m, sec):
            if e.get("target") == rel:
                return sec, k
    raise GateFault(f"`{rel}` matches no manifest entry (framework_core by path, templates under {coherence.ROOTS['templates']}, "
                    f"agent_templates under {coherence.ROOTS['agent_templates']}, a project's by target) — a new file is added with --new, never silently")


def file_of(repo: Path, m: dict, sec: str, key: str) -> Path | None:
    """The file an entry names, when it is in this tree: the meta path, else the project's target."""
    e = m[sec][key]
    for cand in ([e.get("path")] if sec == "framework_core" else [coherence.ROOTS[sec] + key, e.get("target")]):
        if cand and (repo / cand).is_file():
            return repo / cand
    return None


def base_manifest(repo: Path, p: Path, base: str | None) -> dict | None:
    """The manifest at the base ref (the branching grammar's one diff base unless --base), or None when no base is readable."""
    ref = base
    if not ref:
        try:
            from . import branch as branch_mod
            ref = branch_mod.diff_base(repo)
        except Exception:   # noqa: BLE001 — no base: every entry moves (said in the result)
            return None
    try:
        r = subprocess.run(["git", "-C", str(repo), "show", f"{ref}:{p.relative_to(repo).as_posix()}"], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except ValueError:
        return None


def _branch(repo: Path) -> str:
    try:
        r = subprocess.run(["git", "-C", str(repo), "branch", "--show-current"], capture_output=True, text=True, timeout=10)
        return r.stdout.strip() or "HEAD"
    except (OSError, subprocess.TimeoutExpired):
        return "HEAD"


def _frontmatter_bump(f: Path, new: str) -> bool:
    """Move a file's frontmatter `version:` line to `new` when it carries one; True when written."""
    try:
        s = f.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False
    if not s.startswith("---"):
        return False
    end = s.find("\n---", 3)
    if end < 0:
        return False
    head, tail = s[:end], s[end:]
    m = FM_VERSION_RE.search(head)
    if not m:
        return False
    head2 = head[:m.start()] + f"{m.group(1)}{m.group(2)}{new}{m.group(4)}" + head[m.end():]
    f.write_text(head2 + tail, encoding="utf-8")
    return True


def _section_of_new(path: str) -> tuple[str, str, dict]:
    rel = _rel(path)
    if rel.startswith(coherence.ROOTS["templates"]):
        key = rel[len(coherence.ROOTS["templates"]):]
        return "templates", key, {"content_type": "universal", "target": key if not key.startswith("claude/") else "." + key}
    if rel.startswith(coherence.ROOTS["agent_templates"]):
        key = rel[len(coherence.ROOTS["agent_templates"]):]
        return "agent_templates", key, {"content_type": "universal", "target": rel}
    key = rel[len(".claude/"):] if rel.startswith(".claude/") else rel
    return "framework_core", key, {"path": rel}


def bump(repo: Path, entries: list[str], level: str, note: str, framework: str | None = None, base: str | None = None,
         new: list[str] | None = None, write: bool = True) -> dict:
    note = (note or "").strip()
    if not note:
        raise GateFault("--note is mandatory and never empty: the changelog keeps its why (what changed and why)")
    if level not in LEVELS:
        raise GateFault(f"--level must be one of {', '.join(LEVELS)}, not `{level}`")
    if framework and framework not in LEVELS:
        raise GateFault(f"--framework must be one of {', '.join(LEVELS)}, not `{framework}`")
    if not entries and not new:
        raise GateFault("nothing to bump: name at least one --entry <path> or --new <path>")
    p, m = load(repo)
    basem = base_manifest(repo, p, base)
    moved, kept, added, frontmatter = [], [], [], []
    for path in new or []:
        sec, key, extra = _section_of_new(path)
        if key in (m.get(sec) or {}):
            raise GateFault(f"--new `{path}`: the entry `{key}` already exists in {sec} — bump it with --entry")
        m.setdefault(sec, {})[key] = {"version": "1.0.0", **extra, "changelog": [f"1.0.0: {note}"]}
        added.append(f"{sec}:{key}")
    for path in entries:
        sec, key = resolve(repo, m, path)
        e = m[sec][key]
        cur = str(e["version"])
        base_v = ((basem or {}).get(sec) or {}).get(key, {}).get("version") if basem else None
        already = base_v is not None and _semver(cur) > _semver(str(base_v))
        line = None
        if already:   # moved on this branch already: the version stays; the line that names it is replaced when the note differs, added when absent
            cl = e.setdefault("changelog", [])
            top = cl[0] if cl else ""
            wanted = f"{cur}: {note}"
            if top.startswith(cur + ":"):
                if top != wanted:
                    cl[0] = wanted; line = wanted
            else:
                cl.insert(0, wanted); line = wanted
            kept.append({"entry": f"{sec}:{key}", "version": cur, "base": base_v, "line": line})
            newv = cur
        else:
            newv = bump_version(cur, level)
            e["version"] = newv
            e.setdefault("changelog", []).insert(0, f"{newv}: {note}")
            moved.append({"entry": f"{sec}:{key}", "from": cur, "to": newv})
        f = file_of(repo, m, sec, key)
        if f is not None and write and _frontmatter_bump(f, newv):
            frontmatter.append(str(f.relative_to(repo)))
    fw = None
    if framework:
        cur = str(m.get("framework_version", "0.0.0"))
        base_v = (basem or {}).get("framework_version") if basem else None
        if base_v is not None and _semver(cur) > _semver(str(base_v)):
            fw = {"version": cur, "kept": True}
        else:
            newv = bump_version(cur, framework)
            m["framework_version"] = newv
            m["last_updated"] = dt.date.today().isoformat()
            m["description"] = f"v{newv} ({_branch(repo)}): {note}. " + str(m.get("description", ""))
            fw = {"from": cur, "to": newv}
    if write:
        p.write_text(json.dumps(m, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return {"ok": True, "manifest": str(p.relative_to(repo)), "base": "none (every entry moves)" if basem is None else (base or "diff base"),
            "moved": moved, "kept": kept, "added": added, "framework": fw, "frontmatter": frontmatter, "written": write}


def check(repo: Path, entries: list[str], base: str | None = None, framework: bool = False) -> list[str]:
    p, m = load(repo)
    basem = base_manifest(repo, p, base)
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
            elif base_v is None or _semver(cur) > _semver(str(base_v)):
                any_moved = True
        f = file_of(repo, m, sec, key)
        if f is not None:
            try:
                s = f.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                s = ""
            fm = FM_VERSION_RE.search(s[:s.find("\n---", 3)] if s.startswith("---") and s.find("\n---", 3) > 0 else "")
            if fm and fm.group(3) != cur:
                problems.append(f"{sec}:{key}: frontmatter version {fm.group(3)} ≠ manifest {cur} (manifest-parity)")
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
        lines.append(f"  = {x['entry']}: {x['version']} already moved on this branch (base {x['base']})" + (f" — note replaced" if x["line"] else ""))
    for x in r["added"]:
        lines.append(f"  + {x}: 1.0.0")
    if r["framework"]:
        fw = r["framework"]
        lines.append(f"  framework_version: {fw['version']} already moved on this branch" if fw.get("kept") else f"  framework_version: {fw['from']} → {fw['to']}")
    for f in r["frontmatter"]:
        lines.append(f"  frontmatter version moved: {f}")
    return "\n".join(lines)
