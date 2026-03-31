---
name: databases
description: >
  Use when configuring, tuning, designing schemas, migrating, backing up,
  or reviewing database engines. Covers PostgreSQL, MongoDB, MySQL/MariaDB,
  and MSSQL. Also use for connection pooling, replication, PCI-DSS database
  compliance, migration planning, database performance tuning, or schema
  design review. Triggers: 'database', 'db', 'postgres', 'postgresql', 'pg_',
  'mysql', 'mariadb', 'mongodb', 'mongo', 'mssql', 'sql server', 'schema',
  'migration', 'index', 'backup', 'restore', 'replication', 'replica',
  'connection pool', 'pgbouncer', 'proxysql', 'pgaudit', 'TDE',
  'encryption at rest', 'drizzle-kit', 'prisma migrate', 'typeorm',
  'sequelize', 'knex', 'alembic', 'flyway', 'liquibase', 'mongod',
  'pg_dump', 'mysqldump', 'EXPLAIN', 'query plan', 'slow query',
  'vacuum', 'autovacuum', 'reindex', 'partitioning'.
license: MIT
compatibility: "Requires one or more of: psql, mongosh, mysql, or sqlcmd"
metadata:
  source: custom
  date_added: "2026-03-24"
  effort: high
---

# Databases: Production Configuration & Operations

Configure, tune, design schemas, migrate, back up, and review database engines -- from single-node dev setups to PCI-compliant production clusters. The goal is correct, performant, durable databases that survive failures, pass audits, and don't wake you up at 3am.

**Target versions** (March 2026):
- PostgreSQL **18.3** (EOL 2030-11), previous: 17.9, 16.13
- MongoDB **8.0.20** (GA), 8.2.6 (rapid release, EOL 2026-07)
- MariaDB **11.8.6** (LTS, EOL 2028-06), 12.2.2 (rolling GA, EOL 2026-05)
- MySQL **8.4.8** (LTS), 9.6.0 (innovation)
- SQL Server **2025 RTM + CU3** (GA 2025-11-18)
- PgBouncer **1.25.1**, Pgpool-II **4.7.1**, ProxySQL **3.0.6**

This skill covers six domains depending on context:
- **Configuration** -- engine settings, authentication, TLS, tuning parameters
- **Schema design** -- indexing strategy, partitioning, normalization, type selection
- **Migration** -- cross-engine migration, zero-downtime DDL, ORM migration tooling
- **Operations** -- backup/restore, replication, connection pooling, monitoring
- **Performance** -- query plan analysis, index optimization, vacuum/maintenance
- **Compliance** -- PCI-DSS 4.0 encryption, audit logging, key management, data masking

## When to use

- Configuring database engines (postgresql.conf, mongod.conf, my.cnf, MSSQL settings)
- Designing or reviewing database schemas (indexes, partitioning, types, constraints)
- Planning or executing cross-engine migrations (MySQL -> PostgreSQL, etc.)
- Setting up backup/restore strategies and PITR
- Configuring replication (streaming, logical, replica sets, GTID)
- Tuning connection pooling (PgBouncer, ProxySQL, application-side pools)
- Analyzing query performance (EXPLAIN, slow query logs, index usage)
- Database-level PCI-DSS 4.0 compliance (encryption, audit logging, access control)
- Evaluating managed vs self-hosted database decisions
- Setting up database monitoring and alerting

## When NOT to use

- Deploying databases on Kubernetes (StatefulSets, PVCs, operators) -- use kubernetes
- Provisioning managed databases (RDS, Cloud SQL, Atlas) via IaC -- use terraform
- Docker Compose for database containers -- use docker
- Database-related Ansible playbooks and roles -- use ansible
- Application-level database bugs (N+1, transaction misuse, ORM pitfalls) -- use code-review
- SQL injection detection, connection string secrets in code -- use security-audit
- CI/CD pipelines that run migrations -- use ci-cd

---

## AI Self-Check

AI tools consistently produce the same database mistakes. **Before returning any generated SQL, schema, migration, or config, verify against this list:**

### Migrations

- [ ] `IF NOT EXISTS` / `IF EXISTS` guards on `ADD COLUMN` / `DROP COLUMN` (bare DDL crashes on re-run)
- [ ] Adding `NOT NULL` column includes a `DEFAULT` value (or two-step: add nullable, backfill, alter NOT NULL)
- [ ] Index creation uses `CONCURRENTLY` on PostgreSQL (prevents full table lock)
- [ ] Large table changes run in batches, not a single transaction (lock escalation, OOM risk)
- [ ] Migration is backward-compatible (old app version can still run against new schema)
- [ ] No `DROP TABLE` or `DROP DATABASE` without explicit user confirmation
- [ ] Migration is idempotent -- can be run twice without error
- [ ] Rollback/down migration exists and is tested

### Schema

- [ ] New timestamp columns use `timestamptz` (PG), `DATETIME2` (MSSQL), `DATETIME` (MySQL -- `TIMESTAMP` has the 2038 problem)
- [ ] Character set is `utf8mb4` for MySQL (not `utf8` which is 3-byte only), `UTF8` for PG
- [ ] Identity columns use `GENERATED ALWAYS AS IDENTITY` over `SERIAL` in PG 10+ (non-bypassable)
- [ ] Foreign keys have explicit `ON DELETE` behavior (don't rely on engine defaults)
- [ ] Indexes exist on all foreign key columns (PG does NOT auto-create these, unlike MySQL InnoDB)
- [ ] Composite index column order follows: equality columns first, range column last, selectivity-ordered

### Configuration

- [ ] No `trust` or `md5` authentication in `pg_hba.conf` (use `scram-sha-256`)
- [ ] MySQL `sql_mode` includes `STRICT_TRANS_TABLES` (prevents silent data truncation)
- [ ] TLS enforced for all connections (not just "available")
- [ ] `max_connections` is sized for the actual workload, not left at default
- [ ] Password authentication uses modern hashing (SCRAM-SHA-256 for PG, `caching_sha2_password` for MySQL)
- [ ] No default/example passwords in config files

### General

- [ ] All SQL uses parameterized queries / prepared statements (never string concatenation)
- [ ] Connection pool settings don't exceed `max_connections` across all app instances
- [ ] Backup strategy tested by actually restoring (backup without restore test = hope, not a strategy)
- [ ] Secrets (passwords, connection strings) injected via env vars or secret managers, not config files

---

## Workflow

### Step 1: Determine the domain

Based on the request:
- **"Configure PostgreSQL / tune settings"** -> Configuration
- **"Design a schema / review indexes"** -> Schema design
- **"Migrate from X to Y / add a column"** -> Migration
- **"Set up backups / replication / pooling"** -> Operations
- **"This query is slow / optimize"** -> Performance
- **"PCI audit / encrypt database"** -> Compliance
- **"Review this schema/config"** -> Apply production checklist + AI self-check

### Step 2: Gather requirements

Before writing SQL or config:
- **Engine and version** -- behavior differs significantly across versions
- **Deployment model** -- self-hosted (bare metal, VM, container, K8s) vs managed (RDS, Cloud SQL, Atlas)
- **Workload type** -- OLTP (many small transactions) vs OLAP (few large queries) vs mixed
- **Data volume** -- row counts, table sizes, growth rate
- **Compliance** -- PCI-DSS CDE? HIPAA? What data classification?
- **HA requirements** -- RTO/RPO targets, multi-AZ, read replicas
- **Existing infrastructure** -- what's already running, what ORMs/drivers are in use

### Step 3: Build

Follow the domain-specific section below. Always apply the production checklist and AI self-check before finishing.

### Step 4: Validate

```bash
# PostgreSQL
psql -c "SHOW config_file;"                    # verify config location
pg_isready -h localhost                         # connection check
psql -c "SELECT * FROM pg_hba_file_rules;"     # verify pg_hba.conf
psql -c "EXPLAIN (ANALYZE, BUFFERS) <query>;"  # query plan analysis

# MongoDB
mongosh --eval "db.adminCommand({getCmdLineOpts: 1})"  # verify config
mongosh --eval "rs.status()"                            # replica set health
mongosh --eval "db.collection.explain('executionStats').find({})"

# MySQL / MariaDB
mysql -e "SELECT @@sql_mode;"                  # verify strict mode
mysql -e "SHOW VARIABLES LIKE 'innodb%';"      # InnoDB settings
mysql -e "EXPLAIN FORMAT=TREE <query>;"        # query plan (MySQL 8.0+)

# MSSQL
sqlcmd -Q "SELECT @@VERSION;"
sqlcmd -Q "DBCC CHECKDB ('dbname') WITH NO_INFOMSGS;"  # integrity check
```

---

## Engine Routing

- **PostgreSQL**: SCRAM, poolers, WAL or logical replication, `pg_stat_statements`, and careful vacuum strategy
- **MongoDB**: replica-set health, schema validation, oplog sizing, and avoiding fan-out document patterns
- **MySQL/MariaDB**: strict mode, `utf8mb4`, GTID or Galera choices, and understanding the MySQL/MariaDB divergence
- **MSSQL**: memory limits, TempDB layout, Query Store, and backup or restore discipline

Read `references/config-templates.md` for copy-pasteable engine configs and `references/backup-patterns.md`
for recovery specifics.

---

## Schema, Migration, and Performance

- Favor expand-contract for zero-downtime schema changes.
- Composite index order still follows equality, sort, then range.
- Choose tenant isolation deliberately; PCI-sensitive shared-schema designs need extra scrutiny.
- Treat query-plan review and monitoring as normal operations, not emergency-only work.

Read `references/migration-patterns.md` for migration tooling, type mapping, and cross-engine move details.

---

## Pooling, Backup, and Platform Choice

- PostgreSQL pooling is usually non-negotiable; use PgBouncer unless a concrete reason says otherwise.
- Backup discipline means restore testing, encryption, retention limits, and monitoring backup freshness.
- Managed databases reduce toil but do not remove shared-responsibility or compliance review.
- Self-hosted databases buy control at the cost of HA, patching, and operational burden.

---

## Production Checklist

### All Engines

- [ ] Authentication uses modern hashing (SCRAM-SHA-256, caching_sha2_password, certificate auth)
- [ ] TLS enforced for all connections (not just "available")
- [ ] No default passwords, no `trust` auth, no passwordless access
- [ ] Connection pool in front of the database (PgBouncer, ProxySQL, or application-side)
- [ ] `max_connections` sized for actual workload, not default
- [ ] Backup strategy implemented, tested, and monitored
- [ ] Restore procedure documented and tested (at least monthly)
- [ ] Monitoring in place (connections, query performance, replication lag, disk usage)
- [ ] Slow query logging enabled with appropriate threshold
- [ ] Dead/unused indexes identified and removed
- [ ] Character encoding correct (`utf8mb4` for MySQL, `UTF8` for PG)

### PostgreSQL-Specific

- [ ] `pg_hba.conf`: `hostssl` only, `scram-sha-256` only, CIDR-restricted
- [ ] `shared_buffers` = 25% RAM, `effective_cache_size` = 75% RAM
- [ ] `work_mem` sized for concurrency (default 64MB is high for OLTP with many connections -- per-sort, not per-connection)
- [ ] `random_page_cost = 1.1` for SSD storage
- [ ] `statement_timeout` set per-role (not globally -- migrations need longer)
- [ ] `idle_in_transaction_session_timeout` set (60s default)
- [ ] `pg_stat_statements` enabled
- [ ] Autovacuum tuned for large tables (`autovacuum_vacuum_scale_factor`)
- [ ] WAL archiving enabled for PITR (`archive_mode = on` + pgBackRest/Barman, or managed backup)
- [ ] Foreign key columns have indexes
- [ ] pgAudit installed and configured (if PCI scope)
- [ ] Patched against CVE-2026-2005 (pgcrypto heap buffer overflow, RCE) -- 18.2+ / 17.8+ / 16.12+

### MySQL/MariaDB-Specific

- [ ] `sql_mode` includes `STRICT_TRANS_TABLES` (prevents silent data truncation)
- [ ] `innodb_buffer_pool_size` = 70% RAM
- [ ] `innodb_flush_log_at_trx_commit = 1` for durability
- [ ] `require_secure_transport = ON`
- [ ] `character-set-server = utf8mb4`
- [ ] Binary log enabled for PITR (`log_bin = ON`)
- [ ] `innodb_file_per_table = ON`
- [ ] MariaDB patched against CVE-2026-32710 (JSON_SCHEMA_VALID crash/RCE) -- 11.8.6+ / 11.4.10+

### MongoDB-Specific

- [ ] `security.authorization: enabled` (never run without auth)
- [ ] Replica set with 3+ members (not standalone in production)
- [ ] Write concern `w: "majority"` (default in 8.0+)
- [ ] Schema validation (`$jsonSchema`) on critical collections
- [ ] Patched against MongoBleed (CVE-2025-14847) -- 8.0.17+
- [ ] Patched against CVE-2026-25611 (pre-auth DoS via compression) -- 8.0.18+ / 8.2.4+
- [ ] TLS enabled (`net.tls.mode: requireTLS`)

### MSSQL-Specific

- [ ] `Max Server Memory` set explicitly (not unlimited)
- [ ] `MAXDOP` set to core count per NUMA node
- [ ] `Cost Threshold for Parallelism` raised from default 5
- [ ] TempDB files = min(CPU cores, 8), equal size
- [ ] Query Store enabled
- [ ] Recovery model = FULL for production databases
- [ ] TDE enabled for CDE databases
- [ ] Patched against CVE-2026-21262 (privilege escalation) -- March 2026 CU+

### Compliance (PCI-DSS 4.0)

- [ ] Encryption at rest: TDE or column-level (disk-level alone insufficient per Req 3.5.1.2)
- [ ] Encryption in transit: TLS 1.2+ enforced on all connections (Req 4)
- [ ] Audit logging: pgAudit/audit plugin, shipped to immutable SIEM (Req 10)
- [ ] Key management: keys in HSM/KMS, not alongside data (Req 3.6)
- [ ] Key rotation: DEKs every 90 days, master keys annually (Req 3.7)
- [ ] Access control: separate roles, no shared accounts, MFA for CDE access (Req 7, 8)
- [ ] Data masking: PAN display limited to last 4 digits (Req 3.3)
- [ ] No cardholder data in non-prod environments (Req 6.5.4)
- [ ] Quarterly access review documented (Req 7.2.5)
- [ ] Vulnerability scanning includes database engine, not just containers (Req 11.3)

---

## Reference Files

- `references/config-templates.md` -- engine configuration templates
- `references/backup-patterns.md` -- backup, restore, and PITR patterns
- `references/migration-patterns.md` -- cross-engine migration patterns and type-mapping guidance

---

## Rules

These are non-negotiable. Violating any of these is a bug.

1. **Backups without restore tests are not backups.** Test restores monthly. Document the procedure.
2. **No `trust` auth in `pg_hba.conf`.** Not in dev, not in Docker, not anywhere. Use `scram-sha-256`.
3. **MySQL strict mode ON.** `STRICT_TRANS_TABLES` prevents silent data truncation. Without it, MySQL silently corrupts your data.
4. **TLS enforced, not just available.** `require_secure_transport`, `hostssl`, `requireTLS`. Connections without TLS are a finding.
5. **Connection pooler for PostgreSQL.** PG's process-per-connection model doesn't scale without one. Use PgBouncer.
6. **Indexes on foreign keys in PostgreSQL.** PG doesn't auto-create them. Missing FK indexes cause sequential scans on JOINs and cascading DELETEs.
7. **`utf8mb4` for MySQL, always.** `utf8` is a lie -- it's 3-byte only, can't store emoji or many CJK characters.
8. **`timestamptz` for PostgreSQL, always.** Bare `timestamp` stores no timezone, breaks when server timezone changes.
9. **Parameterized queries everywhere.** String concatenation for SQL is a bug, not a shortcut. Doubly true for AI-generated code.
10. **Disk-level encryption is insufficient for PCI-DSS 4.0.** Req 3.5.1.2 requires TDE, column-level, or application-layer encryption.
11. **Patch MongoBleed (CVE-2025-14847).** Self-hosted MongoDB < 8.0.17 / 7.0.28 / 6.0.27 is actively exploitable with no authentication required.
12. **Patch MongoDB compression DoS (CVE-2026-25611).** Pre-auth DoS via crafted OP_COMPRESSED messages. Default config affected (compression enabled since 3.6). Fixed in 8.0.18+ / 8.2.4+ / 7.0.29+.
13. **Patch PgBouncer (CVE-2025-12819).** PgBouncer < 1.25.1 can allow unauthenticated SQL execution when `track_extra_parameters` includes `search_path` AND `auth_user` is set (both non-default). Upgrade regardless -- the fix is low-risk.
14. **Run the AI self-check.** Every generated migration, schema, or config gets verified against the checklist above before returning.

---

## Related Skills

- **code-review** -- has `references/databases.md` for application-level database **bug patterns** (transaction misuse, NULL handling, ORM N+1, type coercion). This skill covers engine configuration and operations; code-review covers how the application uses the database.
- **security-audit** -- for SQL injection detection and credential scanning in application code
- **kubernetes** -- for deploying databases on K8s (StatefulSets, operators, PVCs)
- **terraform** -- for provisioning managed databases (RDS, Cloud SQL, Atlas)
- **docker** -- for database containers in Docker Compose
- **ansible** -- for database server configuration management
