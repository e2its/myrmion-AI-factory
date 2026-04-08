---
description: "Database standards — migration patterns, query optimization, schema design, connection management. Applied when editing database-related files."
applyTo: "**/migrations/**,**/*.sql,**/models/**"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Database Governance & Migration Strategy

> **Auto-generated from** `docs/setup.md` decisions  
> **Scope:** Relational/NoSQL data stores  
> **Tools:** {{DB_MIGRATION_TOOL}} (Flyway/Alembic/Liquibase/Prisma)

## Migration Policy
- All schema changes via migrations; never manual DB edits
- Backwards-compatible migrations required; include down/rollback scripts
- PRs must include migration rationale and impact analysis

## Migration Safety Policy

> **Enforcement:** `scripts/validate-migrations.sh` — executed by IMPLEMENT (🔍 REVIEW hat), QA --verify, and CI pipeline.

### Forbidden Operations (ALWAYS BLOCKED)

| Operation | Pattern | Risk | Safe Alternative |
|-----------|---------|------|------------------|
| `DROP TABLE` | `DROP TABLE {name}` | Total data loss, breaks FK references | Rename to `_deprecated_{name}`, drop after 2 release cycles |
| `DROP DATABASE` | `DROP DATABASE {name}` | Catastrophic data loss | Never automated; manual DBA-only with backup verification |
| `DROP SCHEMA` | `DROP SCHEMA {name}` | Cascading data loss | Deprecate and archive, drop after data migration verified |
| `TRUNCATE TABLE` | `TRUNCATE TABLE {name}` | All rows removed irreversibly | Soft-delete with TTL policy, or archive to cold storage first |
| `DELETE ALL` (no WHERE) | `DELETE FROM {table};` | All rows removed | Add explicit WHERE clause with bounded scope |
| `DELETE ALL` (WHERE 1=1) | `DELETE FROM {t} WHERE 1=1` | Disguised mass delete | Add explicit business-logic WHERE clause |
| `DROP COLUMN` | `ALTER TABLE {t} DROP COLUMN {c}` | Data loss, breaks queries | Mark column deprecated, stop writing, drop after 2 cycles |

### Suspicious Operations (WARNING — review required)

| Operation | Pattern | Risk | Guidance |
|-----------|---------|------|----------|
| `RENAME TABLE` | `RENAME TABLE` / `ALTER TABLE RENAME TO` | Breaks app references | Dual-write migration: create new, copy, switch, drop old |
| `CHANGE column type` | `ALTER COLUMN SET TYPE` | Implicit data truncation/loss | Add new column, backfill, switch reads, drop old |
| `Raw SQL execute` | `execute("...")` in ORM | Bypasses ORM safety | Prefer ORM migration DSL; justify with comment |
| `Bulk UPDATE no LIMIT` | `UPDATE ... SET ... WHERE` (no LIMIT) | Table lock, long transaction | Batch updates with LIMIT and explicit transaction scope |

### Exception Process

Destructive operations are allowed ONLY with:
1. **ADR**: Filed via `/BLUEPRINT --adr {FEATURE_ID} "Migration: {OPERATION} on {TABLE}"`
2. **Pre-migration backup**: Verified snapshot before execution
3. **Rollback script**: Tested restore procedure included in the migration
4. **ADR tag in migration**: Comment `-- ADR: ADR-XXXX` referencing the approved exception

## Versioning & Rollback
- Tag releases with schema version; align with app semver
- Rollback playbooks for failed deploys; keep last 3 migrations reversible

## Performance & Query Hygiene
- Use `EXPLAIN ANALYZE` for slow queries; add indexes for hotspots
- Prevent N+1 via joins/batching; enforce query timeouts
- Connection pooling mandatory; configure max connections per environment

## Data Retention & Privacy
- Define TTL per PII tier; document in `docs/privacy/`
- Implement erasure workflows (GDPR Art. 17) and audit logs
- Mask PII in logs and exports

## Backup & DR
- Automated backups with retention (e.g., 30 days) and integrity checks
- Restore drills at least quarterly; document RTO/RPO per tier

## Further Reading
- Database Reliability Engineering
- PostgreSQL Performance Tuning
