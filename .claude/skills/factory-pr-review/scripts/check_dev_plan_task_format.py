#!/usr/bin/env python3
"""
check_dev_plan_task_format.py — Validates that `dev_plan.md` tasks use the
IMPLEMENT-canonical `- [ ] [X.N]` markdown-checkbox form.

Why this matters: `IMPLEMENT --build` reads task progress directly from
the `- [ ]` / `- [x]` markdown checkboxes — checkbox is the single
source of truth for completion tracking. Tasks written as `### X.N — title`
h3 headers (without a matching checkbox) are operationally inert: the plan
looks structured but `--build` has nothing to advance.

Background — Why this script exists (MASS PR #331 retrospective):
The iter-7 `IMPLEMENT --plan` re-authoring of FEAT-002 Phase H wrote 10
tasks as `### H.0 — title` through `### H.9 — title` h3 headers. ALL
existing review gates passed green because none validated dev_plan task
format. The plan was operationally unusable. The fix shipped as MASS
capability 29; this file is the meta-framework adaptation following the
existing `check_*.py` script convention (skill-bundled, no orchestrator
needed).

Usage:
    python check_dev_plan_task_format.py --git-range main..HEAD
    python check_dev_plan_task_format.py --git-range main..HEAD --json

Output (JSON with --json, prose without it):
    {
      "findings": [
        {
          "severity": "blocker|important|nit",
          "category": "dev-plan-task-format-orphan-h3|dev-plan-ready-without-tasks",
          "message": "...",
          "files_involved": [...]
        }
      ],
      "summary": {
        "files_changed": <int>,
        "total_findings": <int>,
        "blockers": <int>,
        "important": <int>
      }
    }

Severity mapping (meta convention ↔ MASS):
    blocker   ↔ CRITICAL (push-blocking)
    important ↔ WARNING
    nit       ↔ INFO

This check is inert in the meta-framework repo itself (no `docs/spec/{ID}/`
tree exists in the framework — only in materialised projects), but it
ships with the skill so every downstream project that consumes
`factory-pr-review` gets the gate without further work.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

# Match dev_plan.md under any feature spec dir. Matches both:
#   docs/spec/FEAT-002/dev_plan.md
#   docs/spec/CLUSTER-001/dev_plan.md
DEV_PLAN_PATTERN = re.compile(r"^docs/spec/[^/]+/dev_plan\.md$")

# Phase 2-level heading: `## Phase X — title` or `## Phase X: title`. Loose
# matching tolerates typography variants.
PHASE_HEADING_RE = re.compile(r"^##\s+Phase\s+", re.MULTILINE)

# `### X.N` task-shaped h3 inside a phase block. Examples we want to flag:
#   ### H.0 — CIP Pre-Implementation Survey
#   ### A.1: Contract Verification Gate
#   ### FIX-7 — Step 7 Plant Assignment
H3_TASK_RE = re.compile(
    r"^###\s+\[?(?P<id>[A-Z][A-Z0-9-]*\.\d+|FIX-\d+|ADJ-\d+|INC-\d+)\]?\b",
    re.MULTILINE,
)

# Checkbox-form task: list form `- [ ] [X.N]` / `- [x] [X.N]` OR
# table-cell form `| [ ] [X.N]` / `| [x] [X.N]` (MASS Phase D UI mock
# alignment uses the table form). Both shapes are valid completion
# markers for `IMPLEMENT --build`.
CHECKBOX_TASK_RE = re.compile(
    r"(?:^- \[[ x]\]|\|\s*\[[ x]\])\s+(?:\*\*)?\[?(?P<id>[A-Z][A-Z0-9-]*\.\d+|FIX-\d+|ADJ-\d+|INC-\d+)\]?",
    re.MULTILINE,
)


def git_files_changed(git_range: str) -> list[str]:
    """List files changed in the git range, relative to repo root."""
    out = subprocess.check_output(
        ["git", "diff", "--name-only", git_range], text=True
    )
    return [line.strip() for line in out.splitlines() if line.strip()]


def parse_frontmatter_status(text: str) -> str | None:
    """Extract `status:` field from dev_plan.md YAML frontmatter."""
    fm_match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not fm_match:
        return None
    m = re.search(
        r"^status:\s*['\"]?([A-Z_]+)['\"]?", fm_match.group(1), re.MULTILINE
    )
    return m.group(1) if m else None


def split_phase_blocks(text: str) -> list[tuple[str, str]]:
    """Split the doc body into `(heading, body)` tuples per `## Phase X`
    block. Returns empty list for stub plans with no Phase blocks."""
    matches = list(PHASE_HEADING_RE.finditer(text))
    if not matches:
        return []
    blocks: list[tuple[str, str]] = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block = text[start:end]
        nl = block.find("\n")
        heading = block[:nl].strip() if nl >= 0 else block.strip()
        body = block[nl + 1 :] if nl >= 0 else ""
        blocks.append((heading, body))
    return blocks


def check_dev_plan(path: Path) -> list[dict[str, Any]]:
    """Run both checks (orphan h3 + READY-with-zero-unchecked) against
    one dev_plan.md. Returns a list of findings (dicts)."""
    findings: list[dict[str, Any]] = []
    if not path.exists():
        return findings
    text = path.read_text(encoding="utf-8")
    status = parse_frontmatter_status(text)
    rel = str(path).replace(str(Path.cwd()) + "/", "")

    phase_blocks = split_phase_blocks(text)
    all_checkboxes = {m.group("id") for m in CHECKBOX_TASK_RE.finditer(text)}

    # Check #1 — per-phase: any `### X.N` h3 must have a matching
    # `- [ ] [X.N]` or `- [x] [X.N]` checkbox somewhere in the doc.
    for _heading, body in phase_blocks:
        for h3 in H3_TASK_RE.finditer(body):
            task_id = h3.group("id")
            if task_id not in all_checkboxes:
                findings.append(
                    {
                        "severity": "blocker",
                        "category": "dev-plan-task-format-orphan-h3",
                        "message": (
                            f"Task `{task_id}` in {rel} appears as a `### h3` "
                            f"header but NOT as a `- [ ] [{task_id}]` "
                            f"checkbox. IMPLEMENT --build cannot track this "
                            f"task — checkbox is the only source of truth for "
                            f"completion. Convert to "
                            f"`- [ ] [{task_id}] **title**` per "
                            f"Factory-implement-plan §Task Format."
                        ),
                        "files_involved": [rel],
                    }
                )

    # Check #2 — `status: READY` plans must have ≥1 unchecked `- [ ]`.
    # Otherwise IMPLEMENT --build has nothing to execute.
    if status == "READY" and phase_blocks:
        unchecked = re.search(r"^- \[ \]|\|\s*\[ \]", text, re.MULTILINE)
        if not unchecked:
            findings.append(
                {
                    "severity": "blocker",
                    "category": "dev-plan-ready-without-tasks",
                    "message": (
                        f"{rel} declares `status: READY` but no unchecked "
                        f"`- [ ]` tasks exist. IMPLEMENT --build has "
                        f"nothing to execute. Either lower the status to "
                        f"`IMPLEMENTED_AND_VERIFIED` (if all `[x]`) or add "
                        f"`- [ ] [X.N] **title**` rows per the Task Format spec."
                    ),
                    "files_involved": [rel],
                }
            )

    return findings


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate dev_plan.md task format (checkbox vs orphan h3)"
    )
    parser.add_argument(
        "--git-range",
        required=True,
        help="Git range to inspect (e.g. main..HEAD)",
    )
    parser.add_argument(
        "--json", action="store_true", help="Emit JSON instead of prose"
    )
    args = parser.parse_args()

    changed = git_files_changed(args.git_range)
    relevant = [f for f in changed if DEV_PLAN_PATTERN.match(f)]

    findings: list[dict[str, Any]] = []
    for rel_path in relevant:
        findings.extend(check_dev_plan(Path(rel_path)))

    blockers = sum(1 for f in findings if f["severity"] == "blocker")
    important = sum(1 for f in findings if f["severity"] == "important")
    summary = {
        "files_changed": len(relevant),
        "total_findings": len(findings),
        "blockers": blockers,
        "important": important,
    }

    if args.json:
        print(json.dumps({"findings": findings, "summary": summary}, indent=2))
    else:
        print(f"Files inspected: {summary['files_changed']}")
        print(
            f"Findings: {summary['total_findings']} "
            f"({summary['blockers']} blockers, {summary['important']} important)"
        )
        print()
        for f in findings:
            icon = {"blocker": "🔴", "important": "🟡", "nit": "🟢"}.get(
                f["severity"], "•"
            )
            print(f"{icon} [{f['category']}] {f['message']}")
            for fi in f["files_involved"][:5]:
                print(f"    - {fi}")
            print()

    sys.exit(0 if summary["blockers"] == 0 else 1)


if __name__ == "__main__":
    main()
