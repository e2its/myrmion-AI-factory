# pr-review skill

Pull Request review orchestrator skill with five axes: code, code↔docs sync, API contracts (OpenAPI/AsyncAPI), architectural decisions (ADR), and traceability (CHANGELOG, migrations, runbooks).

## Features

- **Conditional activation** based on the type of change: doesn't over-review trivial PRs and goes deep on PRs that touch API or architecture.
- **Breaking change detection** in OpenAPI via `oasdiff` and heuristic for AsyncAPI.
- **Automatic documentary verification**: README, CHANGELOG, env vars, docstrings, ADR.
- **Clear severity rubric**: blocker / important / nit / suggestion / question / praise.
- **Structured output** (JSON) for integration with dashboards and metrics, plus Markdown for publishing.
- **Multi-platform**: GitHub (gh CLI), GitLab (glab), Azure DevOps (partial).
- **Compatible** with the standard SKILL.md format (Anthropic Claude, Factory.ai droids, OpenAI Codex CLI, OpenCode, Cursor).

## Structure

```
pr-review/
├── SKILL.md                          ← orchestrator (always loaded)
├── README.md
├── references/                       ← loaded on demand (progressive disclosure)
│   ├── severity-rubric.md
│   ├── code-review-criteria.md
│   ├── docs-sync-checklist.md
│   ├── api-contract-rules.md
│   ├── adr-policy.md
│   └── changelog-policy.md
├── scripts/
│   ├── detect_change_type.py
│   ├── check_openapi_diff.sh
│   ├── check_asyncapi_diff.sh
│   ├── check_docs_sync.py
│   └── post_review.py
└── assets/
    └── review_template.md
```

## Installation

### In your "myai factory" framework

Copy the `pr-review/` directory to the location your framework uses for skills. The most common locations per ecosystem:

```bash
# Anthropic Claude Code (project)
cp -r pr-review .claude/skills/pr-review

# Anthropic Claude Code (personal)
cp -r pr-review ~/.claude/skills/pr-review

# Factory.ai droids
cp -r pr-review .factory/skills/pr-review

# OpenAI Codex CLI
cp -r pr-review ~/.codex/skills/pr-review

# OpenCode
cp -r pr-review .opencode/skills/pr-review
```

If your framework uses a different location, check its docs. The `SKILL.md` format is the same across all of them.

### Dependencies

The skill works "dry" with any model, but some checks require external tools:

| Tool | What for | How to install |
|---|---|---|
| `git` | Diff between versions (required) | Pre-installed in most environments |
| `gh` | Interact with GitHub (publish reviews) | `brew install gh` or https://cli.github.com |
| `oasdiff` | Detect breaking changes in OpenAPI | `brew install oasdiff` or `go install github.com/oasdiff/oasdiff@latest` |
| `npx` + `@asyncapi/cli` | Validate AsyncAPI | Comes with Node.js |
| `glab` | Interact with GitLab | `brew install glab` |
| Python 3.10+ | Run the scripts | Pre-installed |

Without the optional tools the skill works but degrades those checks to text heuristics or skips them with a clear message.

## Usage

### Natural invocation (from the agent)

> "Review this PR for me: https://github.com/owner/repo/pull/123"

> "Do a code review of this GitLab MR: ..."

> "Audit the changes between main and my branch before merging"

The skill activates automatically.

### Explicit invocation (slash command)

```
/pr-review https://github.com/owner/repo/pull/123
```

### Running scripts manually

```bash
# Classify the PR
gh pr diff 123 --name-only | python pr-review/scripts/detect_change_type.py --stdin

# Detect breaking changes in OpenAPI
./pr-review/scripts/check_openapi_diff.sh main openapi.yaml

# Check drift between code and docs
python pr-review/scripts/check_docs_sync.py --git-range main..HEAD --json

# Render review (dry-run is the default — nothing is published)
python pr-review/scripts/post_review.py \
    --review review.json \
    --pr-url https://github.com/owner/repo/pull/123 \
    --decision comment \
    --publish    # required to actually publish; omit to just print
```

## Customization

This skill is framework-owned: sync replaces it whole, so an edit here is lost (EVOL-138). A project tunes the review in its own homes:

- **Project policy** (naming, libraries, logging, testing, PII/PCI/health rules) — a rule under `.claude/rules/`, applied by the precedence `factory-code-review/SKILL.md` states (law > ADR/FDR > rule file > agent defaults).
- **Severity and blocking** — `config/quality.json → code_review`, or an ADR's `pr_review_overrides` (see `SKILL.md`).
- **A language or a check the framework lacks** — proposed upstream.

## CI integration

You can run the scripts in CI as a gate before merge:

```yaml
# .github/workflows/pr-quality-gate.yml
name: PR Quality Gate

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  docs-sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Check docs sync
        run: |
          python .claude/skills/pr-review/scripts/check_docs_sync.py \
            --git-range origin/${{ github.base_ref }}..HEAD \
            --json > docs-findings.json
      - name: Check OpenAPI breaking changes
        if: hashFiles('openapi.yaml') != ''
        run: |
          .claude/skills/pr-review/scripts/check_openapi_diff.sh \
            origin/${{ github.base_ref }} openapi.yaml
```

This turns the skill into a guardian that blocks PRs with documentary drift even if no one explicitly asks for review.

## Philosophy

1. **Documentation as contract**: if code changes public behavior, docs must change. No "I'll fix it in the next PR" exceptions.
2. **Severity over volume**: 3 real blockers are worth more than 30 nits.
3. **Verification over assertion**: every finding cites file, line, and why it's a problem in THIS codebase.
4. **Progressive disclosure**: the base skill is light (~200 lines), references load only when applicable.
5. **Don't reinvent the wheel**: integrates with standard tooling (oasdiff, asyncapi-cli, gh, glab).

## License

MIT — adapt it to your organization.

## Credits

Inspired by patterns from:
- `awesome-skills/code-review-skill` (progressive disclosure, severity)
- `addyosmani/agent-skills` (multi-axis review)
- `Factory-AI/skills` (skill structure)
- `SpillwaveSolutions/pr-reviewer-skill` (gh CLI integration)
- OpenAI Agents SDK (`docs-sync` pattern)
- MADR for ADRs, Keep a Changelog, Conventional Commits, SemVer
