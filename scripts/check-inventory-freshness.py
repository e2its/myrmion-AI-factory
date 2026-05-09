#!/usr/bin/env python3
"""
check-inventory-freshness.py — Inventory drift detector

Compares `config/codebase_inventory.json` against the actual codebase to detect drift:

  - Pass A (dead paths):     inventory entries whose `path` no longer exists on disk.
                              Status filter: PLANNED / DESIGNED / DEPRECATED / REMOVED
                              entries are exempt (forward-looking or retired).
  - Pass B (orphan entities): code under `src/backend/**/domain/entities/`,
                              `src/backend/**/domain/value_objects/`, and
                              `src/backend/**/application/use_cases/` that has no
                              inventory entry pointing to it.
  - Pass C (CIP-lint):        opt-in via --strict. Flags inventory entries whose
                              `name` does not match any `^class ` in the source
                              file, whose `feature_ids`/`feature_id` is empty,
                              whose ID prefix doesn't match the BC alias map, or
                              whose `description` is the path-echo boilerplate
                              fallback. These are quality issues that don't break
                              CI today but rot the inventory's usefulness.

Both passes emit advisory output. Exit codes:
  0 = clean
  1 = drift found (CI fails)

Usage:
  python3 scripts/check-inventory-freshness.py                  # human report + exit code
  python3 scripts/check-inventory-freshness.py --json           # machine-readable
  python3 scripts/check-inventory-freshness.py --orphan-allowlist FILE
                                                                # skip orphans matching glob lines
  python3 scripts/check-inventory-freshness.py --strict         # enable Pass C CIP-lint

Why this exists:
  Caught on FEAT-020 CODESIGN (2026-05-05): inventory missed `tax_id` and
  `contact_email` fields on `Organization` even though they exist live. The audit
  classified the corpus item as GAP based on stale inventory data, requiring manual
  override. CIP gate already enforces inventory presence (BLOCK on missing) but
  doesn't enforce freshness (no diff against actual code). This script closes that.

  Pass C added 2026-05-05 (PR #297 self-review): the original gate verified
  presence but not quality. A bulk-register run produced 43 entries that satisfied
  Pass A + Pass B while having fabricated names, missing feature_ids, and
  boilerplate descriptions. --strict catches that semantic rot.

Authored 2026-05-05 as part of governance pre-flight + template hygiene PR.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
INVENTORY = REPO_ROOT / "config" / "codebase_inventory.json"
INVENTORY_ALIASES = REPO_ROOT / "config" / "inventory_aliases.json"


def _load_aliases_config() -> dict:
    if not INVENTORY_ALIASES.exists():
        return {}
    return json.loads(INVENTORY_ALIASES.read_text(encoding="utf-8"))


_ALIASES_CONFIG = _load_aliases_config()

# Globs scanned for orphan detection — loaded from config/inventory_aliases.json
# under "canonical_path_globs". Each match is expected to have an inventory entry.
ORPHAN_SCAN_GLOBS: list[str] = _ALIASES_CONFIG.get("canonical_path_globs", [])

# Filenames that are infrastructure (not business artifacts) — never expected in inventory.
ORPHAN_IGNORE_BASENAMES = {"__init__.py", "base.py", "exceptions.py"}


def load_inventory() -> dict:
    if not INVENTORY.exists():
        print(f"ERROR: {INVENTORY} not found — run SETUP --reconcile-inventory")
        sys.exit(2)
    return json.loads(INVENTORY.read_text(encoding="utf-8"))


def scan_orphans(inventory_paths: set[str]) -> list[str]:
    orphans: list[str] = []
    for glob in ORPHAN_SCAN_GLOBS:
        for path in REPO_ROOT.glob(glob):
            if path.name in ORPHAN_IGNORE_BASENAMES:
                continue
            rel = str(path.relative_to(REPO_ROOT))
            if rel not in inventory_paths:
                orphans.append(rel)
    return sorted(orphans)


def scan_dead_paths(inventory: dict) -> list[dict]:
    dead: list[dict] = []
    for entry in inventory.get("artifacts", []):
        status = (entry.get("status") or "").upper()
        if status in {"PLANNED", "DESIGNED", "DEPRECATED", "REMOVED"}:
            continue
        path = entry.get("path")
        if not path:
            continue
        if not (REPO_ROOT / path).exists():
            dead.append({"id": entry.get("id"), "name": entry.get("name"), "path": path})
    return dead


# ---------------------------------------------------------------------------
# Pass C — CIP-lint (opt-in via --strict)
#
# Catches inventory entries that satisfy presence gates (path exists, no
# orphans) but fail quality gates: name doesn't match real class, feature_ids
# empty, id-prefix doesn't match BC, description is path-echo boilerplate.
# ---------------------------------------------------------------------------

# BC → ID alias map — loaded from config/inventory_aliases.json (shared with
# scripts/reconcile_inventory.py). Empty dict when the file is missing.
BC_ID_ALIAS: dict[str, str] = _ALIASES_CONFIG.get("bc_alias", {})

_CLASS_DECLARATION = re.compile(r"^class\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
_BOILERPLATE_DESC = re.compile(
    r"^bc_\w+ (use case|value object|domain entity)\s*[—-]\s*[\w\s]+\.\s*$"
)


def _classes_in_file(path: Path) -> list[str]:
    if not path.exists() or path.suffix != ".py":
        return []
    return _CLASS_DECLARATION.findall(path.read_text(encoding="utf-8"))


def _entry_bc(path: str | None) -> str | None:
    if not path:
        return None
    m = re.search(r"src/backend/(bc_[a-z]+)/", path)
    return m.group(1) if m else None


def scan_cip_lint(inventory: dict) -> list[dict]:
    """Pass C — quality lint over inventory entries.

    Returns a list of {entry_id, kind, message} issues. Empty list = clean.
    Skips entries with status PLANNED / DESIGNED / DEPRECATED / REMOVED
    (forward-looking or retired entries are exempt by construction).
    """
    issues: list[dict] = []
    for entry in inventory.get("artifacts", []):
        status = (entry.get("status") or "").upper()
        if status in {"PLANNED", "DESIGNED", "DEPRECATED", "REMOVED"}:
            continue
        entry_id = entry.get("id", "?")
        path = entry.get("path")

        # C1: feature_ids non-empty (or feature_id legacy field).
        if not entry.get("feature_ids") and not entry.get("feature_id"):
            issues.append(
                {
                    "entry_id": entry_id,
                    "kind": "missing_feature",
                    "message": (
                        f"Entry `{entry_id}` has no feature_ids/feature_id — "
                        "tools that filter by feature will skip it."
                    ),
                }
            )

        # C2: id prefix matches BC alias map (only enforced for entries clearly
        # under src/backend/<bc>/; shared/* and frontend entries skipped).
        bc = _entry_bc(path)
        if bc and bc in BC_ID_ALIAS:
            expected_prefix = BC_ID_ALIAS[bc]
            if not entry_id.startswith(f"{expected_prefix}-"):
                issues.append(
                    {
                        "entry_id": entry_id,
                        "kind": "id_prefix_mismatch",
                        "message": (
                            f"Entry `{entry_id}` lives under {bc} but ID prefix "
                            f"is not `{expected_prefix}-*`. Update to match the "
                            "BC alias map (single source of truth for inventory IDs)."
                        ),
                    }
                )

        # C3: name matches the source file's `^class ` declarations.
        # SCOPE: only canonical DDD paths (use_cases / value_objects / entities
        # under src/backend/<bc>/). Test helpers, factories, frontend, infra
        # and shared/* use looser conventions (function-only utilities,
        # mock helper classes, etc.) that don't fit a class-coverage rule.
        # The orphan-scan globs in ORPHAN_SCAN_GLOBS are the same scope.
        in_canonical_scope = path and any(
            re.search(g.replace("*", "[^/]+"), path) for g in ORPHAN_SCAN_GLOBS
        )
        if path and path.endswith(".py") and in_canonical_scope:
            classes = _classes_in_file(REPO_ROOT / path)
            if classes:
                registered = entry.get("name", "")
                registered_parts = {
                    p.strip() for p in registered.split("/") if p.strip()
                }
                # Multi-class coverage: every real class must appear in the
                # registered slash-list (no fabrication, no truncation).
                missing = [c for c in classes if c not in registered_parts]
                if missing:
                    issues.append(
                        {
                            "entry_id": entry_id,
                            "kind": "name_class_mismatch",
                            "message": (
                                f"Entry `{entry_id}` name={registered!r} but "
                                f"file has classes {classes}; missing: {missing}. "
                                "CIP search-by-name will miss the unlisted classes "
                                "(use slash-joined name for multi-class files; "
                                "exact match for single-class files)."
                            ),
                        }
                    )

        # C4: description is not the path-echo boilerplate.
        desc = entry.get("description", "")
        if _BOILERPLATE_DESC.match(desc):
            issues.append(
                {
                    "entry_id": entry_id,
                    "kind": "boilerplate_description",
                    "message": (
                        f"Entry `{entry_id}` description echoes path slug "
                        "(`{bc} use case — slug.`). Run "
                        "`scripts/reconcile_inventory.py --enrich-descriptions` "
                        "or hand-craft a meaningful description."
                    ),
                }
            )
    return issues


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit JSON instead of human-readable report",
    )
    parser.add_argument(
        "--orphan-allowlist",
        default=None,
        help="Path to a file with one path per line; orphans matching are skipped",
    )
    parser.add_argument(
        "--no-orphan-check",
        action="store_true",
        help="Skip orphan detection (Pass B); only check dead paths (Pass A)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help=(
            "Enable Pass C (CIP-lint): name-class mismatch, missing feature_ids, "
            "id-prefix drift, boilerplate descriptions. Opt-in for gradual rollout."
        ),
    )
    args = parser.parse_args(argv)

    inventory = load_inventory()
    inventory_paths = {entry.get("path") for entry in inventory.get("artifacts", []) if entry.get("path")}

    dead = scan_dead_paths(inventory)
    orphans: list[str] = []
    if not args.no_orphan_check:
        orphans = scan_orphans(inventory_paths)
        if args.orphan_allowlist:
            allow = set()
            allow_path = Path(args.orphan_allowlist)
            if allow_path.exists():
                allow = {
                    line.strip()
                    for line in allow_path.read_text().splitlines()
                    if line.strip() and not line.startswith("#")
                }
            orphans = [o for o in orphans if o not in allow]

    cip_issues: list[dict] = []
    if args.strict:
        cip_issues = scan_cip_lint(inventory)

    summary = {
        "dead_path_count": len(dead),
        "orphan_count": len(orphans),
        "cip_lint_count": len(cip_issues),
        "drift_detected": bool(dead or orphans or cip_issues),
    }
    payload = {
        "summary": summary,
        "dead_paths": dead,
        "orphans": orphans,
        "cip_lint_issues": cip_issues,
    }

    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print("=== Inventory freshness check ===")
        print(f"Inventory: {INVENTORY.relative_to(REPO_ROOT)}")
        print(f"Artifact entries: {len(inventory.get('artifacts', []))}")
        if args.strict:
            print("Strict mode: ON (Pass C CIP-lint enabled)")
        print()
        if dead:
            print(f"❌ {len(dead)} dead path(s) — inventory points to files that don't exist:")
            for d in dead:
                print(f"   - {d['path']}  (id={d['id']}, name={d['name']})")
            print()
        if orphans:
            print(f"⚠️  {len(orphans)} orphan artifact(s) — code without inventory entry:")
            for o in orphans:
                print(f"   - {o}")
            print()
            print("   To resolve: run SETUP --reconcile-inventory, or add the entries manually,")
            print("   or whitelist the path in the orphan allowlist file.")
            print()
        if cip_issues:
            print(f"⚠️  {len(cip_issues)} CIP-lint issue(s) — entries fail the quality gate:")
            for issue in cip_issues:
                print(f"   - [{issue['kind']}] {issue['message']}")
            print()
            print("   To resolve: run SETUP --reconcile-inventory or hand-edit the entries.")
            print()
        if not dead and not orphans and not cip_issues:
            print("✅ Inventory clean — no dead paths, no orphan artifacts" + (
                ", no CIP-lint issues." if args.strict else "."
            ))

    return 1 if summary["drift_detected"] else 0


if __name__ == "__main__":
    sys.exit(main())
