# mi AI Factory

[![License: EULA](https://img.shields.io/badge/License-EULA-blue.svg)](./EULA.md)
[![GitHub Copilot](https://img.shields.io/badge/GitHub-Copilot-blue)](https://github.com/features/copilot)

> **Governed Agentic SDLC System**: Custom AI agents orchestrate the complete Software Development Life Cycle with built-in governance, security, and quality gates.

---

## Overview

This system transforms GitHub Copilot into a **multi-agent SDLC orchestrator** using VS Code Custom Agents (`.agent.md`). A single visible orchestrator (`@Factory`) routes user intent to 8 specialized invisible worker agents — 6 covering the main SDLC phases plus 2 independent operational agents (AUDIT and BACKLOG) — supported by 10 cross-agent skills, 18 contextual instructions, and 3 reusable prompt workflows.

### Key Features

- **Custom Agents Architecture**: Hub-and-spoke model — 1 visible orchestrator + 8 invisible workers + 10 cross-agent skills
- **Natural Language + Commands**: Say what you need or use explicit commands — Factory routes everything
- **Constitution-Driven**: All decisions validated against `docs/constitution.md` (generated during setup)
- **Contract-First Development**: API contracts (OpenAPI, GraphQL, gRPC, AsyncAPI, Webhooks) defined and linted before implementation
- **Build Verification Loop (BVL)**: Tests executed in terminal, errors parsed and auto-fixed (max 3 attempts). Full Verification Gate (tests + lint + typecheck + build) before completion
- **Security by Design**: OWASP Top 10 + SAST/DAST built into workflow (inline, not post-facto)
- **TDD Enforcement**: Red-Green-Refactor-**Verify** cycle mandatory for all code (BVL closes the loop)
- **Immutable Specifications**: Version-controlled requirements with full audit trail
- **Anti-Drift Protection**: RED ZONES prevent modification of framework/third-party code
- **Project Tracking**: Integrated backlog management with GitHub Projects

---

## Prerequisites

- **VS Code** 1.99+ with **GitHub Copilot** (Agent Mode enabled)
- **Model**: Claude Opus 4.5+ (configured automatically — see [instructions.md](instructions.md#configuración-del-modelo-llm))
- **Git** repository (initialized)
- **Bash-compatible shell** (Linux / macOS / WSL on Windows)

---

## Quick Start

### 1. Install

```bash
git clone https://github.com/e2its/mi-AI-Factory.git
cd mi-AI-Factory && code .
```

Agents are auto-detected by VS Code. Open Copilot Chat → type `@` → **Factory** should appear.

### 2. Setup Project Governance

```bash
# In Copilot Chat:
@Factory SETUP --init
# Interactive: selects language, framework, architecture, CI/CD, security tools

@Factory SETUP --generate
# Materializes: constitution, rules, scaffolding, CI/CD pipelines
```

### 3. (Optional) Technical Due Diligence

For **Brownfield projects** (existing codebases), run an audit at any time:

```bash
@Factory AUDIT --audit
@Factory AUDIT --approve
# Generates GO / GO_WITH_CONDITIONS / NO_GO verdict
```

AUDIT is fully independent — never blocks the main workflow.

### 4. Develop Features

```bash
# (Optional) Initialize project board and plan feature issues
@Factory BACKLOG --init-board
@Factory BACKLOG --plan-feature USR-001 "Users can reset password via email"

# Co-create spec + mockup + user journey (auto-approves when 12/12 validations pass)
@Factory CODESIGN --start USR-001 "Users can reset password via email"

# Co-design architecture + test strategy (only mandatory manual checkpoint)
@Factory BLUEPRINT --start USR-001
@Factory BLUEPRINT --approve USR-001

# Plan and implement with TDD + BVL (real test execution) + Review + SAST
@Factory IMPLEMENT --plan USR-001
@Factory IMPLEMENT --build USR-001

# Deploy, verify (auto-approves when verdict APPROVED), ship
@Factory DEVOPS --deploy USR-001 --env staging
@Factory QA --verify USR-001
# PR → merge to main → @Factory DEVOPS --deploy USR-001 --env prod
```

> **Auto-Approval (v8.2.0):** CODESIGN, DEVOPS `--configure`, and QA `--verify` auto-approve when all checks pass. Only `BLUEPRINT --approve` requires explicit manual approval.

> **Build Verification Loop (BVL v1.0.0):** During `IMPLEMENT --build`, tests are executed in the terminal after each task. If a test fails, the agent parses the error, applies a fix, and retries (max 3 attempts). Before marking a feature as complete, a Full Verification Gate runs the entire test suite + lint + typecheck + build. Supports Node.js, Python, Java, Go, C#, and Rust.

For complete command reference, state machines, and governance details, see **[instructions.md](instructions.md)**.

---

## Architecture

### Agent Model

| Agent | Role | Visibility |
|-------|------|-----------|
| **Factory** | Orchestrator — classifies intent, routes, enforces governance | Visible (`@Factory`) |
| **audit** | Technical Due Diligence (optional, independent) | Invisible (via handoff) |
| **setup** | Setup & Governance | Invisible (via handoff) |
| **codesign** | Co-Creation: PO ↔ UX (spec + mock + journey) | Invisible (via handoff) |
| **blueprint** | Co-Design: ARCH ↔ QA (design + test plan) | Invisible (via handoff) |
| **implement** | Implementation: DEV ↔ REVIEW ↔ SEC (TDD + BVL per phase) | Invisible (via handoff) |
| **devops** | Infrastructure & Deployment | Invisible (via handoff) |
| **qa** | Post-Staging Verification (includes DAST) | Invisible (via handoff) |
| **backlog** | Project Tracking & Issue Management | Invisible (via handoff) |

### Workflow Sequence

```
SETUP (one-time) → CODESIGN → BLUEPRINT → IMPLEMENT → DEVOPS (pre-prod) → QA → MERGE → DEVOPS (prod)
                                            ↕
                              DEVOPS (configure/provision) — flexible after BLUEPRINT
```

**AUDIT** and **BACKLOG** run independently at any time (after SETUP for BACKLOG). Dynamic environments from `docs/rules/ci-cd.instructions.md`. MERGE always before production deployment.

> **Auto-Approval (v8.2.0):** CODESIGN, DEVOPS `--configure`, and QA `--verify` auto-approve when all validations pass. `BLUEPRINT --approve` is the only mandatory manual checkpoint.

### Cross-Agent Skills (Protocols)

| Skill | Purpose |
|-------|---------|
| **Build Verification Loop (BVL)** | Real test execution in terminal, error parsing, auto-fix (max 3 attempts), Full Verification Gate |
| **Batch Interactivity (BIP)** | Tier-based batch decisions instead of one-question-at-a-time |
| **Incremental Persistence (IPP)** | Skeleton-first write, section-atomic saves, survives context summarization |
| **Codebase Inventory (CIP)** | DRY enforcement via codebase_inventory.json + CIP Canary gate |
| **Governance Loading (GCRP)** | Zero Trust context recovery via file-based snapshot (summarization-safe) |
| **Iteration Model** | Domain-driven incremental dev, cascading invalidation on spec changes |
| **Branching Strategy (SCM)** | Branch enforcement, merge policy, concurrency locks |
| **Agent Communication (ACP)** | Controlled verbosity: entry → milestones → completion → Factory return |
| **Commit Prompt** | Auto-generated conventional commit messages after file modifications |
| **Worklog** | Per-feature JSONL audit trail with action registration and phase mapping |

---

## Directory Structure

### Agent System (`.github/`)

```
.github/
├── copilot-instructions.md         # Cross-cutting governance (always loaded)
├── agents/                         # 9 Custom Agent definitions
│   ├── factory.agent.md            # Visible orchestrator
│   ├── audit.agent.md              # Worker agents
│   ├── setup.agent.md              #   (invisible —
│   ├── codesign.agent.md           #    invoked via
│   ├── blueprint.agent.md          #    Factory
│   ├── implement.agent.md          #    handoffs
│   ├── devops.agent.md             #    only)
│   ├── qa.agent.md
│   └── backlog.agent.md
├── instructions/                   # 18 contextual instruction files
├── skills/                         # 10 cross-agent skill protocols
│   ├── Factory-build-verification/  # BVL: test execution + auto-fix
│   ├── Factory-batch-interactivity/ # BIP: batch decisions
│   ├── Factory-incremental-persistence/ # IPP: atomic saves
│   ├── Factory-codebase-inventory/ # CIP: DRY enforcement
│   ├── Factory-governance-loading/ # Zero Trust recovery
│   ├── Factory-iteration-model/    # Cascading invalidation
│   ├── Factory-branching-strategy/ # SCM enforcement
│   ├── Factory-agent-communication/ # ACP verbosity
│   ├── Factory-commit-prompt/      # Conventional commits
│   └── Factory-worklog/            # JSONL audit trail
└── prompts/                        # 3 reusable prompt workflows
```

### Project Structure (after `SETUP --generate`)

```
docs/
├── technical_due.md                # (optional) AUDIT report
├── setup.md                        # Setup state tracker
├── constitution.md                 # Project constitution (tech stack, rules)
├── rules/                          # Technology-specific governance rules
├── spec/{FEATURE_ID}/              # Per-feature workspace
│   ├── spec.feature                #   Gherkin BDD (CODESIGN)
│   ├── mock.html                   #   Visual mockup (CODESIGN)
│   ├── user_journey.md             #   Event Storming + Data Schemas (CODESIGN)
│   ├── design.md                   #   Architecture (BLUEPRINT)
│   ├── test_plan.md                #   Test strategy (BLUEPRINT)
│   ├── dev_plan.md                 #   Implementation plan (IMPLEMENT)
│   ├── devops_plan.md              #   Infrastructure plan (DEVOPS)
│   ├── adr/                        #   Architecture Decision Records
│   └── qa/                         #   QA verification reports
├── backlog/                        # Project tracking (BACKLOG agent — SSOT mode-dependent)
│   ├── project-config.json         #   External mode: non-sensitive tool connection identifiers / field mappings (no tokens, no issue registry)
│   ├── state.md                    #   Local mode: Feature issue registry + Kanban board
│   └── issue-bodies/               #   Local mode: Issue body markdown files
├── ux/vision/                      # Global UX vision artifacts
└── project_log/                    # Worklog, migration reports
contracts/                          # API contracts (OpenAPI, GraphQL, gRPC, AsyncAPI)
config/                             # system_resources.json, infrastructure_registry.json
infra/                              # Infrastructure as Code (modules/ + features/)
scripts/                            # Automation & CI/CD scripts
src/ (or apps/)                     # Source code (created by IMPLEMENT, not scaffolding)
tests/                              # Test infrastructure (config only — tests created by IMPLEMENT)
```

### Scaffolding Philosophy

**What `SETUP --generate` creates:** directory structure, configuration files (100% functional), type definitions, documentation, CI/CD pipelines, declarative schemas.

**What it does NOT create:** source code, components, test files, business logic, API routes — all generated by `IMPLEMENT --build` during TDD cycle.

This ensures CI/CD pipelines pass from day 1 (no stub code = no lint/compile errors).

---

## Governance

All code must comply with `docs/constitution.md`:

- **Allowed/Blacklisted Technologies**: Whitelist of approved frameworks/libraries
- **Architecture Patterns**: Clean Architecture, Hexagonal, DDD, Layered, etc.
- **Security Policies**: OWASP Top 10, secret management, SAST/DAST
- **Protected Code Zones**: RED ZONES prevent modification of framework/legacy code (requires ADR)

Enforcement is **hybrid**: semantic validation (LLM-based pattern detection) + deterministic scripts (`dependency-allowlist.sh`, `security-scan.sh`, etc.). Mandatory checkpoints at `BLUEPRINT --approve`, `IMPLEMENT --build`, and `QA --verify`.

See [instructions.md - Governance](instructions.md#10-sistema-de-gobernanza-dinámica) for the complete validation system.

---

## Security

| Control | Tool | When |
|---------|------|------|
| **SAST** | Semgrep, custom patterns | `IMPLEMENT --build` (per phase, inline) |
| **Secret scanning** | Gitleaks, regex patterns | `IMPLEMENT --build` + `QA --verify` |
| **DAST** | OWASP ZAP | `QA --verify` (post-staging) |
| **Dependency audit** | `dependency-allowlist.sh` | `QA --verify` (BLOCKING) |
| **Secret management** | `.env` (local) + Vault/cloud (prod) | Always — hardcoded secrets = BLOCK |

---

## Documentation

| Document | Purpose |
|----------|---------|
| **[instructions.md](instructions.md)** | Complete reference: installation, commands, state machines, governance, workflows |
| **[.github/copilot-instructions.md](.github/copilot-instructions.md)** | Cross-cutting governance rules (loaded by all agents) |
| **[docs/constitution.md](docs/constitution.md)** | Project constitution (generated by SETUP) |
| **[EULA.md](EULA.md)** | License terms |

---

## Troubleshooting

**Agent not appearing in Copilot Chat?**
- Verify VS Code 1.99+ with Copilot extension active
- Check `.github/agents/factory.agent.md` exists
- Restart VS Code (Ctrl+Shift+P → "Reload Window")

**Agent stuck in `NEEDS_INFO`?**
- Check the artifact frontmatter for pending questions
- Use `@Factory [AGENT] --refine {ID} "Your answer"` to unblock

**RED ZONE violation blocking build?**
- Create an ADR: `@Factory BLUEPRINT --adr {ID} "Justification for protected code change"`

**Rate limiting on Claude Opus 4.6?**
- Automatic fallback to Claude Opus 4.5 (configured in agent model preferences)

---

## License

e2its is an unregistered trademark used as a project and domain identifier. The holder of the domain e2its.com retains all rights over the software and the brand, without implying official registration.

This software is provided under a custom End User License Agreement (EULA). See [EULA.md](./EULA.md) for details.

---

## Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Documentation**: [instructions.md](instructions.md)
