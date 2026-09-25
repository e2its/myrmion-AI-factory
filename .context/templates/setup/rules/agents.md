---
description: "Role agents and read-only critics — the class policy (tools per class, prompt budgets, model families as aliases, per-spawn resolution, fallback ladder, round caps) and the roster on two axes; the severity bar; the return contracts; no agent ratifies."
applicable_when:
  always: true
version: 1.0.0
date: 2026-09-25
changelog:
  - "1.0.0: feat(EVOL-049)! — initial: the one data home of the agent class policy and the roster (read by python3 scripts/gate.py agents)."
agents:
  classes:
    phase:
      family: writer
      effort: medium
      budget_bytes: 8000
      tools:
        must: [Read, Grep, Glob, Edit, Write, Bash]
        never: [Agent]
    worker:
      family: writer
      effort: medium
      budget_bytes: 6000
      tools:
        must: [Read, Grep, Glob, Edit, Write, Bash]
        never: [Agent]
    plan-critic:
      family: critic
      effort: high
      budget_bytes: 8000
      tools:
        must: [Read, Grep, Glob]
        never: [Edit, Write, NotebookEdit, Bash, Agent]
    work-critic:
      family: critic
      effort: high
      budget_bytes: 8000
      tools:
        must: [Read, Grep, Glob]
        never: [Edit, Write, NotebookEdit, Bash, Agent]
  tiers:
    small: {files: 5, lines: 150}
    large: {files: 30, lines: 800}
  resolve:
    - {class: work-critic, surface: security, effort: high}
    - {class: work-critic, surface: governance, effort: high}
    - {class: plan-critic, round: 2, effort: high}
    - {class: worker, tier: small, effort: low}
    - {class: worker, tier: large, effort: high}
  ladder:
    critic: [writer]
    writer: []
  rounds:
    plan_gate: 2
    work: 1
  roster:
    - {name: factory-codesign, class: phase, phase: CODESIGN, surface: ["docs/spec/**"]}
    - {name: factory-blueprint, class: phase, phase: BLUEPRINT, surface: ["docs/spec/**", "contracts/**"]}
    - {name: factory-implement, class: phase, phase: IMPLEMENT, surface: ["docs/spec/**"]}
    - {name: factory-qa, class: phase, phase: QA, surface: ["docs/spec/**", "tests/**"]}
    - {name: factory-devops, class: phase, phase: DEVOPS, surface: ["infra/**", ".github/workflows/**"]}
    - {name: factory-dev-backend, class: worker, surface: ["src/**", "app/**", "lib/**"]}
    - {name: factory-dev-frontend, class: worker, surface: ["src/**/frontend/**", "web/**", "ui/**"]}
    - {name: factory-dev-platform, class: worker, surface: ["scripts/**", "infra/**", ".github/workflows/**", "config/**"]}
    - {name: factory-dev-e2e, class: worker, surface: ["tests/**", "e2e/**"]}
    - {name: factory-plan-critic, class: plan-critic, surface: ["docs/spec/**"]}
    - {name: factory-critic-security, class: work-critic, lens: security, surface: ["**"]}
    - {name: factory-critic-correctness, class: work-critic, lens: correctness, surface: ["**"]}
    - {name: factory-critic-governance, class: work-critic, lens: governance, surface: [".claude/**", "config/**", "docs/**"]}
    - {name: factory-critic-fidelity, class: work-critic, lens: fidelity, surface: ["docs/spec/**", "src/**"]}
  spawn_sites:
    - {path: ".claude/instructions/Factory-implement-build.instructions.md", policy: worker}
    - {path: ".claude/instructions/Factory-implement-review-checks.instructions.md", policy: work-critic}
    - {path: ".claude/instructions/Factory-blueprint-design.instructions.md", policy: plan-critic}
    - {path: ".claude/skills/factory-code-review/SKILL.md", policy: work-critic}
    - {path: ".claude/skills/factory-preventive-sweep/SKILL.md", policy: work-critic}
---

# Role Agents & Read-Only Critics

> The frontmatter above is the ONE data home of the policy (classes, tiers, per-spawn resolution, ladder, round caps, roster, spawn sites); the two family **aliases** are the project's SETUP decision (Q34) and live in `config/quality.json → agents.families` (`writer`, `critic` — harness aliases, never pinned ids). `python3 scripts/gate.py agents` reads both: `python3 scripts/gate.py agents` reads it (`--validate` in the gate profile and CI; `--resolve`, `--fallback`, `--digest`, `--check-return` at every spawn). Changing the model table is an edit here plus a manifest bump — never a code change — and the change carries its measurement window (`subproducts/measure`, before/after per `measurement.report_interval_days`).

## Classes and the harness matrix

Each framework phase runs in an agent with its own context and its own surface; development work runs in workers per surface; the work is reviewed by **read-only critics that did not write it**. Read-only is the harness's tool matrix, not a sentence: a critic definition lists no `Edit`, `Write`, `NotebookEdit`, `Bash` or `Agent`, so an attempted write cannot happen; the orchestrator hashes the tree before and after a critic run (`gate.py certify --subject tree`) and refuses a run around which the tree moved. Delegation is by name (`.claude/agents/<name>.md`); agents carry no self-discovery of applicability — the orchestrator hands each one its **corpus digest** (`gate.py agents --digest --agent <name>`: the slice of law governing its surface, within its class `budget_bytes`) instead of the corpus.

## Model policy — aliases, families, per spawn

Writers and critics live on **different model families by construction** (`agents.families.writer` ≠ `agents.families.critic` in `config/quality.json`, harness aliases chosen at SETUP — the separation is the invariant, the aliases are the project's); the model is passed at the spawn from the reader's resolution, never written into an agent definition; the validator refuses a roster where a critic and the writer of the surface it reviews resolve to the same family. Model and effort are computed **per spawn** by the reader from the class, the surface, the size tier of the work and the review round (`resolve` rows, first match wins; the class defaults otherwise) — strongest where the risk is highest, stepping down where the diff is small — never chosen at the call site. A spawn the harness ends on a provider error falls down the **ladder** keyed by the resolved family: readers and critics fall to another family; **agents that write never degrade** (an empty rung — the spawn is retried or surfaced). Every site that spawns declares which policy it follows (`spawn_sites`), checked both directions.

## The bounded loop

One worker↔critic round on a completed diff (`rounds.work`), two at the plan gate (`rounds.plan_gate`) — the measured point of diminishing return. A cure that seeds the next round's findings is the loop's own defect. The loop ends in a **user adjudication**, never in the agent's own judgement.

## Severity bar — two limbs

A finding rises above informational only by naming a concrete path (a) to the **deployed product** — including any exposure of a credential or a personal datum, whatever the path — or (b) to the **machinery that produces or polices the work**. On a governance surface the burden inverts: informational is the default and escalation is what must be justified. Every critic cites the limb it stands on.

## Return contracts

A **worker** returns what it did plus which rules it read, which laws it applied, which defect classes it adjudicated, and its sources — under a `## Governance` heading with `Rules read:`, `Laws applied:`, `Defect classes:`, `Sources:` lines. A **critic** returns findings, each with a file, a line, a severity, a confidence and an executed probe (`file:line · 🔴|🟡|🟢|❓ · confidence N% · probe: <command or reasoning that was run>`). A return missing its governance block or a finding missing its probe is refused by the orchestrator (`gate.py agents --check-return --class <class>`).

## No agent ratifies

RDR, user questions and version-control operations stay in the main session (LAW-06 / agent authority). No subagent commits, no subagent decides; a subagent that reaches a decision returns it as an open RDR to the main session.
