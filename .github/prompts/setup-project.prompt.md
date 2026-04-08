---
description: "Set up a new project — runs SETUP --init and --generate to scaffold governance and configuration."
mode: agent
agent: Factory
tools: [vscode/memory, vscode/askQuestions, execute/runInTerminal, read/readFile, edit/createFile, edit/editFiles, search/codebase, search/textSearch, search/listDirectory, agent/runSubagent]
---

# Setup Project Workflow

You are initializing a new project with the AI Factory governance framework.

## Instructions

### Phase 1: Discovery (SETUP --init)
Run `SETUP --init` to start the interactive discovery process:
- Answer questions Q1-Q26 about the project (tech stack, architecture, team size, etc.)
- Use Smart Discovery to infer answers when possible
- Produce `docs/setup.md` with all configuration captured

### Phase 2: Materialization (SETUP --generate)
After discovery completes, run `SETUP --generate` to scaffold:
- `docs/constitution.md` — project constitution (immutable without ADR)
- `docs/rules/*.instructions.md` — technology and domain-specific rules
- `ADR-0000` — initial architecture decision record
- Project directory structure with `.gitkeep` files
- Script configuration (linting, testing, security)

### Phase 3: Verification
After materialization:
- Run `bash scripts/validate-governance.sh` to verify integrity
- Confirm all files generated match the setup configuration
- Present the materialization report to the user

## Context
- This is typically the FIRST command run on a new project
- The user may have existing code — detect and adapt
- If `docs/constitution.md` already exists, warn about re-initialization
