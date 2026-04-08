# mi AI Factory for Claude

[![License: EULA](https://img.shields.io/badge/License-EULA-blue.svg)](./EULA.md)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai/claude-code)

> **Governed Agentic SDLC System**: A single Claude Code agent orchestrates the complete Software Development Life Cycle with built-in governance, security, and quality gates via slash commands.

---

## Overview

This system transforms Claude Code into a **governed SDLC orchestrator** using slash commands (`.claude/commands/`). A single agent assumes specialized roles — 6 covering the main SDLC phases plus 2 independent operational commands (AUDIT and BACKLOG) — supported by 12 cross-cutting skill protocols and 20 contextual instruction files.

### Key Features

- **Single Agent + Slash Commands**: 8 specialized commands invoked via `/command --args` — no multi-agent coordination overhead
- **Natural Language + Commands**: Say what you need or use explicit slash commands — Claude routes everything
- **Constitution-Driven**: All decisions validated against `docs/constitution.md` (generated during setup)
- **Contract-First Development**: API contracts (OpenAPI, GraphQL, gRPC, AsyncAPI, Webhooks) defined and linted before implementation
- **Build Verification Loop (BVL)**: Tests executed in terminal, errors parsed and auto-fixed (max 3 attempts). Full Verification Gate (tests + lint + typecheck + build) before completion
- **Security by Design**: OWASP Top 10 + SAST/DAST built into workflow (inline, not post-facto)
- **TDD Enforcement**: Red-Green-Refactor-**Verify** cycle mandatory for all code (BVL closes the loop)
- **Immutable Specifications**: Version-controlled requirements with full audit trail
- **Anti-Drift Protection**: RED ZONES prevent modification of framework/third-party code
- **Project Tracking**: Integrated backlog management with external tools or local files

---

## Prerequisites

- **Claude Code** — CLI, VS Code extension, JetBrains extension, or Desktop app
- **Model**: Claude Opus 4.6 (required for complex framework reasoning)
- **Git** repository (initialized)
- **Bash-compatible shell** (Linux / macOS / WSL on Windows)

---

## Quick Start

### 1. Install

```bash
git clone https://github.com/e2its/mi-AI-Factory-for-Claude.git
cd mi-AI-Factory-for-Claude

# CLI
claude

# Or open in VS Code / JetBrains with Claude Code extension installed
```

Claude Code auto-detects `CLAUDE.md` and registers slash commands from `.claude/commands/`.

### 2. Setup Project Governance

```bash
/setup --init
# Interactive: selects language, framework, architecture, CI/CD, security tools

/setup --generate
# Materializes: constitution, rules, scaffolding, CI/CD pipelines
```

### 3. (Optional) Technical Due Diligence

For **Brownfield projects** (existing codebases), run an audit at any time:

```bash
/audit --audit
/audit --approve
# Generates GO / GO_WITH_CONDITIONS / NO_GO verdict
```

AUDIT is fully independent — never blocks the main workflow.

### 4. Develop Features

```bash
# (Optional) Initialize project board and plan feature issues
/backlog --init-board
/backlog --plan-feature USR-001 "Users can reset password via email"

# Co-create spec + mockup + user journey (auto-approves when 12/12 validations pass)
/codesign --start USR-001 "Users can reset password via email"

# Co-design architecture + test strategy (only mandatory manual checkpoint)
/blueprint --start USR-001
/blueprint --approve USR-001

# Plan and implement with TDD + BVL (real test execution) + Review + SAST
/implement --plan USR-001
/implement --build USR-001

# Deploy, verify (auto-approves when verdict APPROVED), ship
/devops --deploy USR-001 --env staging
/qa --verify USR-001
# PR → merge to main → /devops --deploy USR-001 --env prod
```

> **Auto-Approval (v8.2.0):** CODESIGN, DEVOPS `--configure`, and QA `--verify` auto-approve when all checks pass. Only `BLUEPRINT --approve` requires explicit manual approval.

> **Build Verification Loop (BVL v1.0.0):** During `/implement --build`, tests are executed in the terminal after each task. If a test fails, the agent parses the error, applies a fix, and retries (max 3 attempts). Before marking a feature as complete, a Full Verification Gate runs the entire test suite + lint + typecheck + build. Supports Node.js, Python, Java, Go, C#, and Rust.

For complete command reference, state machines, and governance details, see **[instructions.md](instructions.md)**.

---

## Architecture

### Command Model

| Command | Role |
|---------|------|
| `/audit` | Technical Due Diligence (optional, independent) |
| `/setup` | Setup & Governance |
| `/codesign` | Co-Creation: PO ↔ UX (spec + mock + journey) |
| `/blueprint` | Co-Design: ARCH ↔ QA (design + test plan) |
| `/implement` | Implementation: DEV ↔ REVIEW ↔ SEC (TDD + BVL per phase) |
| `/devops` | Infrastructure & Deployment |
| `/qa` | Post-Staging Verification (includes DAST) |
| `/backlog` | Project Tracking & Issue Management |

### Workflow Sequence

```
SETUP (one-time) → CODESIGN → BLUEPRINT → IMPLEMENT → DEVOPS (pre-prod) → QA → MERGE → DEVOPS (prod)
                                            ↕
                              DEVOPS (configure/provision) — flexible after BLUEPRINT
```

**AUDIT** and **BACKLOG** run independently at any time (after SETUP for BACKLOG). Dynamic environments from `docs/rules/ci-cd.instructions.md`. MERGE always before production deployment.

> **Auto-Approval (v8.2.0):** CODESIGN, DEVOPS `--configure`, and QA `--verify` auto-approve when all validations pass. `BLUEPRINT --approve` is the only mandatory manual checkpoint.

### Cross-Cutting Skills (Protocols)

| Skill | Purpose |
|-------|---------|
| **Build Verification Loop (BVL)** | Real test execution in terminal, error parsing, auto-fix (max 3 attempts), Full Verification Gate |
| **Incremental Persistence (IPP)** | Skeleton-first write, section-atomic saves, survives context summarization |
| **Codebase Inventory (CIP)** | DRY enforcement via codebase_inventory.json + CIP Canary gate |
| **Governance Loading (GCRP)** | Zero Trust context recovery via file-based snapshot (summarization-safe) |
| **Iteration Model** | Domain-driven incremental dev, cascading invalidation on spec changes |
| **Branching Strategy (SCM)** | Branch enforcement, merge policy, concurrency locks |
| **Agent Communication (ACP)** | Controlled verbosity: entry → milestones → completion |
| **Commit Prompt** | Auto-generated conventional commit messages after file modifications |
| **Worklog** | Per-feature JSONL audit trail with action registration and phase mapping |
| **Memory Cache (MCP)** | Acceleration layer via /memories/repo/ for cross-command state |
| **Coherence Validation (CVP)** | Cross-artifact traceability and completeness validation |
| **Backlog Next-Task** | Determines next executable step from execution plan |

---

## Directory Structure

### Framework System

```
CLAUDE.md                               # Root governance (always loaded by Claude Code)
.claude/
├── commands/                           # 8 Slash Commands (one per SDLC phase)
│   ├── audit.md                        # /audit
│   ├── setup.md                        # /setup
│   ├── codesign.md                     # /codesign
│   ├── blueprint.md                    # /blueprint
│   ├── implement.md                    # /implement
│   ├── devops.md                       # /devops
│   ├── qa.md                           # /qa
│   └── backlog.md                      # /backlog
├── instructions/                       # 20 contextual instruction files
├── skills/                             # 12 cross-cutting skill protocols
│   ├── Factory-build-verification/     # BVL: test execution + auto-fix
│   ├── Factory-incremental-persistence/ # IPP: atomic saves
│   ├── Factory-codebase-inventory/     # CIP: DRY enforcement
│   ├── Factory-governance-loading/     # Zero Trust recovery
│   ├── Factory-iteration-model/        # Cascading invalidation
│   ├── Factory-branching-strategy/     # SCM enforcement
│   ├── Factory-agent-communication/    # ACP verbosity
│   ├── Factory-commit-prompt/          # Conventional commits
│   ├── Factory-worklog/                # JSONL audit trail
│   ├── Factory-memory-cache/           # MCP acceleration layer
│   ├── Factory-coherence-validation/   # CVP cross-artifact checks
│   └── Factory-backlog-next-task/      # Next-task resolver
└── settings.json                       # Permission configuration
.context/
└── templates/                          # Materialization templates (SETUP --generate)
```

### Project Structure (after `/setup --generate`)

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
├── backlog/                        # Project tracking (BACKLOG — SSOT mode-dependent)
│   ├── project-config.json         #   External mode: non-sensitive connection params
│   ├── state.md                    #   Local mode: Feature issue registry + Kanban
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

**What `/setup --generate` creates:** directory structure, configuration files (100% functional), type definitions, documentation, CI/CD pipelines, declarative schemas.

**What it does NOT create:** source code, components, test files, business logic, API routes — all generated by `/implement --build` during TDD cycle.

This ensures CI/CD pipelines pass from day 1 (no stub code = no lint/compile errors).

---

## Governance

All code must comply with `docs/constitution.md`:

- **Allowed/Blacklisted Technologies**: Whitelist of approved frameworks/libraries
- **Architecture Patterns**: Clean Architecture, Hexagonal, DDD, Layered, etc.
- **Security Policies**: OWASP Top 10, secret management, SAST/DAST
- **Protected Code Zones**: RED ZONES prevent modification of framework/legacy code (requires ADR)

Enforcement is **hybrid**: semantic validation (LLM-based pattern detection) + deterministic scripts (`dependency-allowlist.sh`, `security-scan.sh`, etc.). Mandatory checkpoints at `/blueprint --approve`, `/implement --build`, and `/qa --verify`.

See [instructions.md - Governance](instructions.md#10-sistema-de-gobernanza-dinámica) for the complete validation system.

---

## Security

| Control | Tool | When |
|---------|------|------|
| **SAST** | Semgrep, custom patterns | `/implement --build` (per phase, inline) |
| **Secret scanning** | Gitleaks, regex patterns | `/implement --build` + `/qa --verify` |
| **DAST** | OWASP ZAP | `/qa --verify` (post-staging) |
| **Dependency audit** | `dependency-allowlist.sh` | `/qa --verify` (BLOCKING) |
| **Secret management** | `.env` (local) + Vault/cloud (prod) | Always — hardcoded secrets = BLOCK |

---

## Documentation

| Document | Purpose |
|----------|---------|
| **[instructions.md](instructions.md)** | Complete reference: installation, commands, state machines, governance, workflows |
| **[CLAUDE.md](CLAUDE.md)** | Root governance rules (loaded by Claude Code in every conversation) |
| **[docs/constitution.md](docs/constitution.md)** | Project constitution (generated by SETUP) |
| **[EULA.md](EULA.md)** | License terms |

---

## Troubleshooting

**Slash commands not appearing?**
- Verify Claude Code is installed and active (CLI: `claude`, or IDE extension)
- Check `CLAUDE.md` exists in the repository root
- Check `.claude/commands/` contains the command `.md` files

**Command stuck in `NEEDS_INFO`?**
- Check the artifact frontmatter for pending questions
- Use `/command --refine {ID} "Your answer"` to unblock

**RED ZONE violation blocking build?**
- Create an ADR: `/blueprint --adr {ID} "Justification for protected code change"`

---

## License

e2its is an unregistered trademark used as a project and domain identifier. The holder of the domain e2its.com retains all rights over the software and the brand, without implying official registration.

This software is provided under a custom End User License Agreement (EULA). See [EULA.md](./EULA.md) for details.

---

## Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Documentation**: [instructions.md](instructions.md)
