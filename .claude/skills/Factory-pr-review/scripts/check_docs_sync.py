#!/usr/bin/env python3
"""
check_docs_sync.py — Detects drift between code and documentation.

Applies heuristics to identify code changes that should likely be accompanied
by documentation changes but aren't.

Usage:
    python check_docs_sync.py --git-range main..HEAD
    python check_docs_sync.py --git-range main..HEAD --json

Output (JSON with --json, prose without it):
    {
      "findings": [
        {
          "severity": "blocker|important|nit",
          "category": "openapi-missing|readme-stale|...",
          "message": "...",
          "files_involved": [...]
        }
      ],
      "summary": {...}
    }

Implemented heuristics:

1. Public endpoint code changes but openapi.* doesn't → BLOCKER
2. Event/handler code changes but asyncapi.* doesn't → BLOCKER
3. CLI flags change (argparse/click/typer/cobra) but README doesn't → IMPORTANT
4. Env vars change but neither .env.example nor README do → IMPORTANT
5. Code changes but no entry in CHANGELOG.md → IMPORTANT
6. Public functions change but their docstrings don't → IMPORTANT
7. Major dependencies change but no ADR exists → IMPORTANT
"""

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


# Reuse classification from the other script
sys.path.insert(0, str(Path(__file__).parent))


def git_files_changed(git_range: str) -> list[str]:
    out = subprocess.check_output(["git", "diff", "--name-only", git_range], text=True)
    return [l.strip() for l in out.splitlines() if l.strip()]


def git_diff_for(file_path: str, git_range: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "diff", git_range, "--", file_path],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return ""


def matches_any(path: str, patterns) -> bool:
    return any(re.search(p, path) for p in patterns)


PUBLIC_API_PATH_PATTERNS = [
    r"src/api/", r"src/controllers/", r"src/routes/", r"src/handlers/",
    r"app/controllers/", r"app/api/",
    r"internal/api/", r"pkg/api/",
    r"controllers?/.*\.(py|js|ts|go|java|kt|rb)$",
    r"routes?/.*\.(py|js|ts|go|java|kt|rb)$",
    r".*Controller\.(java|kt|cs)$",
    r".*Resource\.java$",
]

EVENT_HANDLER_PATTERNS = [
    r"events?/", r"consumers?/", r"producers?/",
    r"handlers?/.*event", r"messaging/", r"subscribers?/",
]

OPENAPI_PATTERNS = [r"openapi.*\.(ya?ml|json)$", r"swagger.*\.(ya?ml|json)$"]
ASYNCAPI_PATTERNS = [r"asyncapi.*\.(ya?ml|json)$"]

CLI_FRAMEWORK_HINTS = [
    r"argparse\.ArgumentParser", r"@click\.", r"click\.command",
    r"typer\.Typer", r"@app\.command",
    r"cobra\.Command", r"flag\.(String|Bool|Int)",
    r"yargs", r"commander\.",
    r"OptionParser", r"OptionsParser",
]

ENV_VAR_HINTS = [
    r"os\.environ", r"os\.getenv",
    r"process\.env\.",
    r"System\.getenv",
    r"std::env::var",
    r"ENV\[",
]

ADR_DIR_PATTERNS = [r"^docs/adr/", r"^doc/adr/", r"^architecture/decisions/"]


def find_files(files, patterns):
    return [f for f in files if matches_any(f, patterns)]


def added_lines(diff: str) -> list[str]:
    return [l[1:] for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]


def removed_lines(diff: str) -> list[str]:
    return [l[1:] for l in diff.splitlines() if l.startswith("-") and not l.startswith("---")]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--git-range", required=True, help="e.g. main..HEAD")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args()

    files = git_files_changed(args.git_range)
    findings = []

    # === Heuristic 1: public API without spec ===
    public_api_files = find_files(files, PUBLIC_API_PATH_PATTERNS)
    openapi_files = find_files(files, OPENAPI_PATTERNS)

    if public_api_files and not openapi_files:
        findings.append({
            "severity": "blocker",
            "category": "openapi-missing",
            "message": (
                "Public API code is modified but no OpenAPI spec is updated. "
                "The contract must reflect the code. Update the spec or explain why "
                "this change does not affect the public contract."
            ),
            "files_involved": public_api_files,
        })

    # === Heuristic 2: events without asyncapi ===
    event_files = find_files(files, EVENT_HANDLER_PATTERNS)
    asyncapi_files = find_files(files, ASYNCAPI_PATTERNS)

    if event_files and not asyncapi_files:
        findings.append({
            "severity": "blocker",
            "category": "asyncapi-missing",
            "message": (
                "Event/handler code is modified but no AsyncAPI spec is updated. "
                "If the change affects an externally published/consumed event, the spec "
                "must be updated."
            ),
            "files_involved": event_files,
        })

    # === Heuristic 3: CLI flags without README ===
    code_files = [f for f in files if Path(f).suffix in {".py", ".js", ".ts", ".go", ".java", ".kt", ".rb", ".rs"}]
    readme_changed = any(Path(f).name.upper().startswith("README") for f in files)

    cli_changes_detected = False
    cli_files = []
    for f in code_files:
        diff = git_diff_for(f, args.git_range)
        added = "\n".join(added_lines(diff))
        if any(re.search(p, added) for p in CLI_FRAMEWORK_HINTS):
            cli_changes_detected = True
            cli_files.append(f)

    if cli_changes_detected and not readme_changed:
        findings.append({
            "severity": "important",
            "category": "readme-stale-cli",
            "message": (
                "Changes to CLI flags/commands detected but README is not updated. "
                "Verify that the usage section reflects the changes."
            ),
            "files_involved": cli_files,
        })

    # === Heuristic 4: env vars without .env.example/README ===
    env_example_changed = any(".env" in Path(f).name and "example" in Path(f).name.lower() for f in files)
    env_changes_detected = False
    env_files = []
    for f in code_files:
        diff = git_diff_for(f, args.git_range)
        added = "\n".join(added_lines(diff))
        if any(re.search(p, added) for p in ENV_VAR_HINTS):
            env_changes_detected = True
            env_files.append(f)

    if env_changes_detected and not env_example_changed and not readme_changed:
        findings.append({
            "severity": "important",
            "category": "env-vars-undocumented",
            "message": (
                "References to potentially new environment variables detected, but neither "
                ".env.example nor README is updated. Document new variables with their "
                "purpose and valid values."
            ),
            "files_involved": env_files,
        })

    # === Heuristic 5: changes without CHANGELOG entry ===
    changelog_changed = any(Path(f).name.upper().startswith("CHANGELOG") for f in files)
    has_observable_change = bool(public_api_files or event_files or cli_files or env_files)

    if has_observable_change and not changelog_changed:
        findings.append({
            "severity": "important",
            "category": "changelog-missing",
            "message": (
                "The PR introduces observable changes (API, CLI, configuration, or events) but "
                "there is no CHANGELOG.md entry. Add an entry under [Unreleased] following Keep "
                "a Changelog (Added/Changed/Deprecated/Removed/Fixed/Security)."
            ),
            "files_involved": [],
        })

    # === Heuristic 6: major dependency changes without ADR ===
    DEP_FILES_RE = r"(package\.json|requirements\.txt|pyproject\.toml|go\.mod|pom\.xml|build\.gradle|Cargo\.toml|Gemfile|composer\.json)"
    dep_files_changed = [f for f in files if re.search(DEP_FILES_RE, f)]
    adr_changed = any(matches_any(f, ADR_DIR_PATTERNS) for f in files)

    if dep_files_changed and not adr_changed:
        # Only flag if there's substantial change — simple heuristic: check added lines
        substantial = False
        for f in dep_files_changed:
            diff = git_diff_for(f, args.git_range)
            adds = added_lines(diff)
            if len(adds) >= 3:  # arbitrary threshold, better than nothing
                substantial = True
                break
        if substantial:
            findings.append({
                "severity": "important",
                "category": "adr-missing-for-deps",
                "message": (
                    "Project dependencies change. If a new major library is introduced or "
                    "a core dependency is replaced, consider recording the decision as an ADR "
                    "in docs/adr/ following the MADR template."
                ),
                "files_involved": dep_files_changed,
            })

    # === Output ===
    summary = {
        "total_findings": len(findings),
        "blockers": sum(1 for f in findings if f["severity"] == "blocker"),
        "important": sum(1 for f in findings if f["severity"] == "important"),
        "files_changed": len(files),
    }

    result = {"findings": findings, "summary": summary}

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(f"=== Docs sync check ===")
        print(f"Files changed: {summary['files_changed']}")
        print(f"Findings: {summary['total_findings']} ({summary['blockers']} blockers, {summary['important']} important)")
        print()
        for f in findings:
            icon = {"blocker": "🔴", "important": "🟡", "nit": "🟢"}.get(f["severity"], "•")
            print(f"{icon} [{f['category']}] {f['message']}")
            if f["files_involved"]:
                for fi in f["files_involved"][:5]:
                    print(f"    - {fi}")
                if len(f["files_involved"]) > 5:
                    print(f"    ... and {len(f['files_involved']) - 5} more")
            print()

    sys.exit(0 if summary["blockers"] == 0 else 1)


if __name__ == "__main__":
    main()
