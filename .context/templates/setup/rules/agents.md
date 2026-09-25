---
description: "Role agents and read-only critics — the class policy (tools per class, prompt budgets, model families as aliases, per-spawn resolution, fallback ladder, round caps) and the roster on two axes; the severity bar; the return contracts; no agent ratifies."
applicable_when:
  always: true
version: 1.2.0
date: 2026-09-25
changelog:
  - "1.2.0: feat(EVOL-056) — class `reader` (read-only, family critic, the harness matrix + the read operations of the [LAW-10] documentation servers: allow_mcp: docs_mcp_allowlist); roster entry factory-docs-reader; § Beat 0 — external facts before the design, the plan and the infrastructure; three spawn sites."
  - "1.1.0: fix(EVOL-049) — review pass: dead critic rows dropped; phase spawn sites (the five commands); worktree guard; who spawns (the main session); allowlist matrix; vendored lenses; effort precedence; separation lost on the fallback; return contract shape."
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
    reader:
      family: critic
      effort: high
      budget_bytes: 6000
      tools:
        must: [Read, Grep, Glob, WebFetch, WebSearch, ToolSearch]
        allow_mcp: docs_mcp_allowlist
        never: [Edit, Write, NotebookEdit, Bash, Agent]
  tiers:
    small: {files: 5, lines: 150}
    large: {files: 30, lines: 800}
  resolve:
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
    - {name: factory-docs-reader, class: reader, surface: ["package.json", "pyproject.toml", "uv.lock", "requirements*.txt", "go.mod", "Cargo.toml", "pom.xml", "build.gradle*", "infra/**"]}
  spawn_sites:
    - {path: ".claude/commands/codesign.md", policy: phase}
    - {path: ".claude/commands/blueprint.md", policy: phase}
    - {path: ".claude/commands/implement.md", policy: phase}
    - {path: ".claude/commands/qa.md", policy: phase}
    - {path: ".claude/commands/devops.md", policy: phase}
    - {path: ".claude/instructions/Factory-implement-build.instructions.md", policy: worker}
    - {path: ".claude/instructions/Factory-implement-review-checks.instructions.md", policy: work-critic}
    - {path: ".claude/instructions/Factory-blueprint-design.instructions.md", policy: plan-critic}
    - {path: ".claude/skills/factory-code-review/SKILL.md", policy: work-critic}
    - {path: ".claude/skills/factory-preventive-sweep/SKILL.md", policy: work-critic}
    - {path: ".claude/instructions/Factory-blueprint-design.instructions.md", policy: reader}
    - {path: ".claude/instructions/Factory-implement-plan.instructions.md", policy: reader}
    - {path: ".claude/instructions/Factory-devops-configure.instructions.md", policy: reader}
---

# Role Agents & Read-Only Critics

> The frontmatter above is the ONE data home of the policy (classes, tiers, per-spawn resolution, ladder, round caps, roster, spawn sites); the two family **aliases** are the project's SETUP decision (Q34) and live in `config/quality.json → agents.families` (`writer`, `critic` — harness aliases, never pinned ids, never a placeholder, never `inherit`). `python3 scripts/gate.py agents` reads both: bare, it validates (a member of the gate profile, and CI); `--resolve`, `--fallback`, `--digest`, `--spawn`, `--check-return` at every spawn. Changing the model table is an edit here plus a manifest bump — never a code change — and the change carries its measurement window (`subproducts/measure`, before/after per `measurement.report_interval_days`).

## Classes and the harness matrix

Each framework phase runs in an agent with its own context and its own surface; development work runs in workers per surface; the work is reviewed by **read-only critics that did not write it**. Read-only is the harness's tool matrix, not a sentence: a critic definition lists **only** `Read`, `Grep`, `Glob` (an allowlist — no write tool, no `mcp__*` mutator, no permission-pattern spelling of one) and a reader definition only the read tools plus the read operations of the allowlisted documentation servers (§ Beat 0), so an attempted write cannot happen; the roster's class is the class (a definition that says otherwise is red); the spawning session hashes the working tree before and after a critic run (`gate.py certify --subject worktree --paths <scope>` — on-disk bytes, tracked and untracked; the index hash would not see an unstaged edit) and refuses a run around which it moved. **Who spawns:** the main session — no agent carries `Agent` (classes `phase` and `worker` never do; a subagent does not nest). A command delegates its phase to the phase agent by name; the IMPLEMENT build loop, the plan gate and the review passes are run by the main session, which spawns workers and critics by name and hands the phase agent the results. Delegation is by name (`.claude/agents/<name>.md`); agents carry no self-discovery of applicability — the spawning session hands each one its **corpus digest** (`gate.py agents --digest --agent <name>`: the slice of law governing its surface — the roster globs over the tracked tree, always-on rules included — within its class `budget_bytes`) instead of the corpus. The six vendored lenses of the code-review engine (`.claude/skills/factory-code-review/agents/*.md`) are prompts the rostered critic `factory-critic-correctness` runs, never agent types of their own; the validator holds their frontmatter to the critic allowlist and budget.

## Beat 0 — external facts before the design, the plan and the infrastructure (EVOL-056)

A design, an implementation plan and an infrastructure configuration rest on external facts — a library API or version, a service behaviour or limit, an IaC resource shape. Before any of the three is written, the **main session** spawns the **reader** (`factory-docs-reader`, class `reader`) by name with the libraries and services in scope, their pinned versions and the questions the work rests on. The reader is read-only on the critic family; its matrix is the read tools plus the **read operations of the documentation servers `[LAW-10]` allowlists** (`allow_mcp: docs_mcp_allowlist` — one list, the banner's and the reader's, `.claude/skills/factory-mcp-docs-scan/SKILL.md`; a server outside it is red, a mutator on a server inside it is red — the validator admits an `mcp__<server>__<operation>` tool only when the server is listed and the operation carries a read verb: read, get, list, search, query, resolve, retrieve, fetch, describe, lookup, find, show, view). It receives no corpus digest — it reads documentation, not the corpus. Its return — `## Sources` (`mcp|doc · server · query · ref · digest`, or exactly `no sources`), `## Answer` (the source index beside each claim), `## Unknowns` (`question · searched: what`, or exactly `none`), `## Governance` — is held to the contract (`gate.py agents --check-return --class reader`); the sources go into the phase agent's spawn prompt; every external claim in the artefact cites its source index, a premise without one is written `known-cold`, and the sources land under `## External sources` at the end of the artefact. No documentation MCP and no web: the unknowns are named, nothing is guessed. Sites: the three instructions declaring `spawn-policy: reader` (BLUEPRINT design, IMPLEMENT plan, DEVOPS configure).

## Model policy — aliases, families, per spawn

Writers and critics live on **different model families by construction** (`agents.families.writer` ≠ `agents.families.critic` in `config/quality.json`, harness aliases chosen at SETUP — the separation is the invariant, the aliases are the project's); the model is passed at the spawn from the resolver (`gate.py agents --resolve`), never written into an agent definition; the validator refuses families where the critic alias equals the writer alias, and the PreToolUse hook on `Agent` (`check-agent-spawn.sh` → `gate.py agents --spawn`) refuses a roster agent spawned without its family's alias — the mechanical hold. Two aliases the account maps to one model are invisible to both; the separation is then the project's to keep. Model and effort are computed **per spawn** by the resolver (`gate.py agents`) from the class, the surface, the size tier of the work and the review round (`resolve` rows, first match wins; a row's `round` matches its round and every later one; the class defaults otherwise; a row that restates a default is refused as dead data) — strongest where the risk is highest, stepping down where the diff is small — never chosen at the call site. A size nobody measured (0 files, 0 lines) is tier `unknown` and matches no tier row. `effort:` in a definition is the harness default the file registers; the resolver's effort is passed at the call where the harness accepts one and otherwise written as the first line of the spawn prompt (`effort: <level>`). A round over the class cap (`rounds`) is refused by the resolver. A spawn the harness ends on a provider error falls down the **ladder** keyed by the resolved family: critics fall to another family — and when that rung is the writer's family the resolver says so (`separation: false`): the round's findings go to the user's adjudication and the review marker records `degraded`; **agents that write never degrade** (an empty rung — the spawn is retried or surfaced). Every site that spawns declares which policy it follows (`spawn_sites`), checked both directions — the five commands for the phase class, the build loop for workers, the plan gate for the plan critic, the review passes and the preventive sweep for work critics, the three Beat 0 sites for the reader.

## The bounded loop

One worker↔critic round on a completed diff (`rounds.work`), two at the plan gate (`rounds.plan_gate`) — the measured point of diminishing return. A cure that seeds the next round's findings is the loop's own defect. The loop ends in a **user adjudication**, never in the agent's own judgement.

## Severity bar — two limbs

A finding rises above informational only by naming a concrete path (a) to the **deployed product** — including any exposure of a credential or a personal datum, whatever the path — or (b) to the **machinery that produces or polices the work**. On a governance surface the burden inverts: informational is the default and escalation is what must be justified. Every critic cites the limb it stands on.

## Return contracts

A **worker** returns what it did plus which rules it read, which laws it applied, which defect classes it adjudicated, and its sources — under a `## Governance` heading with `Rules read:`, `Laws applied:`, `Defect classes:`, `Sources:` lines. A **reader** returns `## Sources`, `## Answer`, `## Unknowns` and the governance block (§ Beat 0). A **critic** returns findings, each on one line with a file, a line, a severity, a confidence and an executed probe (`file:line · 🔴|🟡|🟢|❓ · confidence N% · probe: <command or reasoning that was run>`), or a line reading exactly `no findings`. A return missing its governance block, a line carrying a severity outside that shape, or a probe that names nothing (`n/a`, `none`, `—`) is refused by the spawning session (`gate.py agents --check-return --class <class>`).

## No agent ratifies

RDR, user questions and version-control operations stay in the main session (LAW-06 / agent authority). No subagent commits, no subagent decides; a subagent that reaches a decision returns it as an open RDR to the main session.
