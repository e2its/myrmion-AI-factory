#!/usr/bin/env python3
"""META-ONLY (EVOL-137): the known parts of every CLAUDE.md monolith the framework ever shipped, for the upgrade's split row.

Walks every commit up to REV that touched the project CLAUDE.md template (renames followed), cuts each version with
`discovery.claude_parts` — the one splitter the upgrade runs — and prints the JSON of
`.context/templates/setup/claude/sections.json`: the sha256 of every part and every H2 heading. Frozen at the split: after
it no monolith exists, so the file is generated once (REV = the split's base) and never again.

    python3 scripts/claude-md-sections.py 525b902 > .context/templates/setup/claude/sections.json
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gates.discovery import claude_parts, part_hash  # noqa: E402

PATH = ".context/templates/setup/claude/CLAUDE.md"


def git(*a: str) -> str:
    return subprocess.run(["git", *a], capture_output=True, text=True, check=True).stdout


def main(rev: str) -> int:
    log = git("log", "--follow", "--name-only", "--format=%x00%H", rev, "--", PATH)
    versions, sections, headings = 0, set(), set()
    for block in log.split("\0")[1:]:
        lines = [x for x in block.splitlines() if x.strip()]
        sha, path = lines[0], lines[-1]
        try:
            text = git("show", f"{sha}:{path}")
        except subprocess.CalledProcessError:
            continue   # the commit deleted or renamed the file away: no version here
        versions += 1
        for h, t in claude_parts(text):
            sections.add(part_hash(t))
            if h is not None:
                headings.add(h)
    if not versions:
        print(f"claude-md-sections: no version of {PATH} up to {rev}", file=sys.stderr)
        return 1
    print(json.dumps({"_doc": "EVOL-137: the sha256 of every part (preamble and H2 section, normalised by discovery.claude_parts) "
                              "and every H2 heading of the CLAUDE.md monolith the framework shipped, all versions up to the split. "
                              "Read by the upgrade's split row; generated once by scripts/claude-md-sections.py, never edited.",
                      "from": rev, "versions": versions, "sections": sorted(sections), "headings": sorted(headings)},
                     indent=1, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: claude-md-sections.py <rev>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
