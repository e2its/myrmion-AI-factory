#!/usr/bin/env python3
"""META-ONLY — the tree the framework delivers to one answer set, built in a scratch project (#261; first written
inline in test-sast-packs.sh, EVOL-074). It holds every template whose stack_conditional holds, at its target, and
every file factory-sync delivers (manifest.delivered, EVOL-136), shipped fixtures included. With --tree it also
holds the template copies a project receives at their source paths (the `tree` channel SETUP --upgrade reads).

Usage: delivered-tree.py ROOT ANSWERS OUT [--tree] [--skip PREFIX]...
Prints one JSON line: {"gates": <the resolved verification.gates>, "was": <their superseded values>, "held": [<template keys whose
condition holds>]}.
"""
import json
import shutil
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    root, answers, out = Path(argv[0]), Path(argv[1]), Path(argv[2])
    tree, skip, rest = False, [], argv[3:]
    while rest:
        a = rest.pop(0)
        if a == "--tree":
            tree = True
        elif a == "--skip" and rest:
            skip.append(rest.pop(0))
        else:
            print(f"delivered-tree: unknown argument {a}", file=sys.stderr)
            return 2
    sys.path.insert(0, str(root / "scripts"))
    from gates import discovery, manifest
    a = json.loads(answers.read_text(encoding="utf-8"))["answers"]
    m = json.loads((root / discovery.MANIFEST).read_text(encoding="utf-8"))
    holds = lambda e: e.get("stack_conditional") is None or discovery.evaluate(discovery.parse(e["stack_conditional"]), a)

    def put(src: Path, rel: str) -> None:
        if src.is_file() and not any(rel.startswith(s) for s in skip):
            (out / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(src, out / rel)

    held = [k for k, e in m["templates"].items() if holds(e)]
    for k in held:
        e = m["templates"][k]
        if e.get("target") and not any(k.startswith(s) for s in skip):
            put(root / discovery.TEMPLATE_ROOT / k, e["target"])
    for t, r in manifest.delivered(m).items():
        if r["channel"] == "sync" or tree:
            put(root / r["source"], t)
    gates = discovery.resolve(root, a)["configures"].get("verification.gates", {})
    was = {}   # the registry rows that resolved to these gates carry their superseded values (resolve never returns them)
    for s in discovery._specs(discovery.load_registry(root)).values():
        for r in (s.get("configures") or {}).values() if isinstance(s.get("configures"), dict) else []:
            for g, row in ((r or {}).get("verification.gates") or {}).items() if isinstance(r, dict) else []:
                if isinstance(row, dict) and row.get("was") and (gates.get(g) or {}).get("command") == row.get("command"):
                    was[g] = row["was"]
    print(json.dumps({"gates": gates, "was": was, "held": held}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
