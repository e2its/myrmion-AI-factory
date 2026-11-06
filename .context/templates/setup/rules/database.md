---
description: "Database standards — migrations (expand and contract), destructive steps, rollback, one connection factory, seeds through the owner, query hygiene. Lands where database.migrations_tool holds an answer."
applicable_when:
  path_glob:
    - "**/migrations/**"
    - "**/Migrations/**"
    - "**/*.sql"
    - "**/models/**"
    - "config/seed_registry.json"
version: 1.4.0
date: 2026-11-06
changelog:
  - "1.4.0: feat(EVOL-071) — the data pack: expand and contract, an ADR tag per destructive step, no automatic rollback of a contract step, one connection factory, seeds through the owner; enforced by gate.py data."
  - "1.3.0: feat(EVOL-049)! — the review-time hats retire; the lenses named."
  - "1.2.1: feat(EVOL-044) — frontmatter `version` realigned to this manifest entry (manifest-parity gate); YAML made parseable where needed."
  - "1.0.0: Initial template version"
---

# Database Governance & Migration Strategy

> **Lands when:** `database.migrations_tool` holds an answer in `docs/setup.md` (asked at SETUP, or decided by the backend framework).
> **Tool:** {{DB_MIGRATION_TOOL}}
> **Enforcement:** `python3 scripts/gate.py data` — a light profile member: every push and CI, no build, no database. QA --verify reads its verdict. Defect classes DC-40, DC-41, DC-42.

## Migration Policy

- Every schema change is a migration. Never a manual database edit.
- **A shipped migration never changes.** A migration on the base branch is applied somewhere. To change its effect, write a new migration. The gate compares every migration of the merge-base with HEAD: an edit or a deletion is red.
- **One version, one migration.** Two migrations of one directory never claim one version (an up/down pair excepted). Alembic keeps one head: a second head needs a merge revision.
- The PR states the migration's rationale and its impact.

## Expand and contract

A schema change ships in two kinds of step:

| Step | What it does | Down | Ships |
|------|--------------|------|-------|
| **expand** | Adds: a table, a nullable column, an index, a new name beside the old one. | Carries its down. The down drops only what the step added. | With the code that starts using the new shape. |
| **contract** | Removes or renames: a drop, a rename, a truncate, an unbounded delete. | None. It declares itself irreversible. | In a later increment, after no deployed code reads the old shape. |

BLUEPRINT plans a contract step as its own task in a later increment, with its ADR.

## Destructive steps

Destructive steps are: `DROP TABLE | COLUMN | SCHEMA | DATABASE | INDEX`, `TRUNCATE`, `DELETE` with no `WHERE` (or `WHERE 1=1`), `RENAME` of a table or a column, and the tool's DSL twins (`op.drop_column`, `migrations.RemoveField`, `dropTable`, `remove_column`, …).

- Every destructive step in the up part carries `ADR: ADR-NNN` on its line or in the comment block right above it, in the file's comment syntax (`-- ADR: ADR-012 …`, `# ADR: ADR-012 …`).
- The tag names an ADR at `docs/project_log/adr/ADR-NNN-*.md` with `status: accepted`. Propose it through `/blueprint --adr`. A proposed ADR is not enough.
- The ADR names the backup taken before the step and who decides a restore.
- The down part is never judged: an expand's down drops what the expand added.

## Index discipline (PostgreSQL)

- An index on a table the same migration did not create is built `CONCURRENTLY` (SQL), with `AddIndexConcurrently` (Django) or with `postgresql_concurrently=True` (Alembic). A plain `CREATE INDEX` locks writes on a live table.
- A small table that tolerates the lock: tag the step with its ADR.

## Rollback

- **An automatic rollback undoes code, traffic and the expand downs of the deployed range.** Nothing else.
- **A contract step is never rolled back by a machine.** When `gate.py data --base <previous deploy ref> --json` lists a `contract` migration in the range, the data stays: fix forward, or the owner decides a restore from backup (an RDR).
- The agent never decides a destructive data operation.

## One connection factory

- One module builds every database connection: `config/quality.json → data.connection_factory`. The first increment that builds the backend writes its path.
- Code outside the factory, the migrations and the test roots never opens a connection itself. It asks the factory.
- Older direct connections sit in `data.baseline` (`docs/project_log/data_baseline.json`). The list only shrinks: the gate compares it with its merge-base copy, so a re-seed never raises it.

## Seeds through the owner

`config/seed_registry.json`, schema `seed_registry_v2`:

```json
{
  "$schema": "seed_registry_v2",
  "seeder": "scripts/seed.py",
  "shared_entities": {
    "orders": {
      "owner": {"module": "src/orders/service.py", "create": "create_order", "delete": "delete_order"},
      "fixture_path": "config/seed_fixtures/orders.json",
      "table_or_collection": "orders",
      "count": 3
    }
  }
}
```

- `owner` is a module function (`{module, create, delete}`) or the API's operationIds (`{create, delete}`).
- The `seeder` calls the owner's create per record. It never writes a table and never opens a connection.
- A fixture is `.json`: data the owner receives, never SQL.
- A re-seed deletes only the seeded ids, through the owner's delete. A full reset (`FORCE_RESEED`) is the owner's RDR at deploy time, never the agent's. No `TRUNCATE`.
- `table_or_collection` is read only, for the integrity counts.

## Performance & Query Hygiene

- Use `EXPLAIN ANALYZE` for slow queries; add indexes for hotspots.
- Prevent N+1 via joins or batching; enforce query timeouts.
- Connection pooling lives in the factory; configure max connections per environment.

## Data Retention & Privacy

- Define TTL per PII tier; document in `docs/privacy/`.
- Implement erasure workflows (GDPR Art. 17) and audit logs.
- Mask PII in logs and exports.

## Backup & DR

- Automated backups with retention (e.g., 30 days) and integrity checks.
- Restore drills at least quarterly; document RTO/RPO per tier.
