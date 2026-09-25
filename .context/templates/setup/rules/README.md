# Template Rules Reference

**Version:** 1.1.0  
**Date:** 2026-09-25  
**Purpose:** Canonical templates for project governance rules

---

## Available Templates

### Core Rules
1. **[architecture.md](architecture.md)** - Architecture patterns & layer separation — hosts `[PLAW-01]` KISS & DRY, `[PLAW-04]` Readability
2. **[branching.md](branching.md)** - Git branching strategy & version control — hosts `[PLAW-11]`
3. **[ci-cd.md](ci-cd.md)** - CI/CD pipeline configuration — hosts `[PLAW-12]` Deployment & Environment
4. **[configuration.md](configuration.md)** - Configuration hardcoding prohibition, tiered secrets — hosts `[PLAW-05]`
5. **[database.md](database.md)** - Database & persistence standards
6. **[dependencies.md](dependencies.md)** - Dependency allowlist & licenses — hosts `[PLAW-10]`
7. **[documentation.md](documentation.md)** - Docstrings, architecture docs, comment policy — hosts `[PLAW-09]`
8. **[i18n.md](i18n.md)** - Internationalization strategy — hosts `[PLAW-08]`
9. **[observability.md](observability.md)** - Monitoring & logging rules
10. **[performance.md](performance.md)** - Performance budgets & optimization
11. **[privacy.md](privacy.md)** - GDPR compliance & data privacy — hosts `[PLAW-07]`
12. **[project-mode.md](project-mode.md)** - Greenfield / Brownfield extension strategy — hosts `[PLAW-03]`
13. **[protected-code.md](protected-code.md)** - Anti-drift enforcement (red zones)
14. **[security_policy.md](security_policy.md)** - OWASP Top 10 & security standards — hosts `[PLAW-06]`
15. **[stateless.md](stateless.md)** - Stateless design principles — hosts `[PLAW-02]`
16. **[testing.md](testing.md)** - Test coverage & TDD standards — hosts `[PLAW-13]` QA Per-Increment

### Law body homes
`docs/constitution.md` (from `../constitution/constitution_template.md`) is an INDEX: one `## [PLAW-NN]` entry per project law — `> sentence` + `Body:` pointer + `Records:`. The body lives ONLY in the pointed rule file, under `## [PLAW-NN] Title` followed by the byte-identical `> sentence` line. One body per law; a rule file may host several laws plus its own content.

---

## Usage

### During `/SETUP --generate`
Templates are materialized into `.claude/rules/*.md` with variable substitution:

**Variables Format:** `{{VAR_NAME}}`

**Example:**
```markdown
# Template: branching.md
**Strategy Selected:** {{BRANCHING_STRATEGY}}

# Materialized: .claude/rules/branching.md
**Strategy Selected:** GitHub Flow
```

### Variable Sources
All variables come from `docs/setup.md` frontmatter:
- `{{BRANCHING_STRATEGY}}` → `branching_strategy: GitHub Flow`
- `{{SEMVER_ENABLED}}` → `semver_enabled: true`
- `{{BACKEND_TOPOLOGY}}` → `backend_topology: Modular Monolith (Hexagonal)`

---

## Modification Policy

**RESTRICTION:** Template structure CANNOT be modified except via `/BLUEPRINT --refine` with justified ADR.

**Allowed:**
- Add new templates for new technologies (ej. Ruby, Go)
- Update variable substitution logic
- Add new variables from setup.md

**Forbidden:**
- Change canonical phrasing without ADR
- Remove mandatory sections
- Break variable substitution syntax

---

## Template Structure

Each template MUST include:

```markdown
---
version: 1.0.0
date: YYYY-MM-DD
changelog:
  - "1.0.0: Initial template version"
---

# [Template Name]

> **Auto-generated from:** `docs/setup.md` decisions  
> **[Variable Name]:** {{VARIABLE}}

[Content with {{VARIABLE}} placeholders]
```

---

## Adding New Templates

1. Create template file in `.context/templates/setup/rules/new_rule.md`
2. Add version header (YAML frontmatter)
3. Define variables with `{{VAR_NAME}}` syntax
4. Update this README with template description
5. Add its entry to `governance_versions.json` (`templates` section, `1.0.0`)
6. Test materialization: `/SETUP --generate` (dry-run)

---

## Related Documentation

- **Policies:** [.context/templates/setup/policies/](../policies/README.md)
- **Snippets:** [.context/templates/setup/snippets/](../snippets/README.md) (example code for agents, not project templates)
- **Scripts:** [.context/templates/setup/scripts/](../scripts/README.md)
- **Security:** [.context/templates/setup/security/](../security/README.md)

---

**Maintained by:** SETUP Agent  
**Last Updated:** 2026-01-26
