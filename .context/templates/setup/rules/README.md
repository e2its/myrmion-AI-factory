# Template Rules Reference

**Version:** 1.0.0  
**Date:** 2026-01-26  
**Purpose:** Canonical templates for project governance rules

---

## Available Templates

### Core Rules
1. **[architecture.instructions.md](architecture.instructions.md)** - Architecture patterns & layer separation
2. **[branching.instructions.md](branching.instructions.md)** - Git branching strategy & version control
3. **[ci-cd.instructions.md](ci-cd.instructions.md)** - CI/CD pipeline configuration
4. **[database.instructions.md](database.instructions.md)** - Database & persistence standards
5. **[observability.instructions.md](observability.instructions.md)** - Monitoring & logging rules
6. **[performance.instructions.md](performance.instructions.md)** - Performance budgets & optimization
7. **[privacy.instructions.md](privacy.instructions.md)** - GDPR compliance & data privacy
8. **[protected-code.instructions.md](protected-code.instructions.md)** - Anti-drift enforcement (red zones)
9. **[security_policy.instructions.md](security_policy.instructions.md)** - OWASP Top 10 & security standards
10. **[stateless.instructions.md](stateless.instructions.md)** - Stateless design principles
11. **[testing.instructions.md](testing.instructions.md)** - Test coverage & TDD standards

---

## Usage

### During `/SETUP --generate`
Templates are materialized into `.claude/rules/*.instructions.md` with variable substitution:

**Variables Format:** `{{VAR_NAME}}`

**Example:**
```markdown
# Template: branching.instructions.md
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
5. Update `scripts/validate-template-references.sh` to include new template
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
