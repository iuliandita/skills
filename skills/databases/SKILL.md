---
name: databases
description: >
  Design schemas, tune queries, migrate, and administer PostgreSQL, MySQL/MariaDB, MongoDB, MSSQL, Redis, and Valkey.
license: MIT
compatibility: "Use the relevant engine client: psql, mongosh, mysql, sqlcmd, redis-cli, or valkey-cli"
metadata:
  source: iuliandita/skills
  date_added: "2026-03-24"
  effort: high
  argument_hint: "[engine-or-task-or-query]"
---

# Databases: Production Configuration & Operations

Configure, tune, design schemas, migrate, back up, and review database engines - from single-node dev setups to PCI-compliant production clusters. The goal is correct, performant, durable databases that survive failures and pass audits.

**Target versions** (October 2026):
- PostgreSQL **18.6** (EOL 2030-11; August 13, 2026 release), back-branches: 17.11, 16.15, 15.19, 14.24 (EOL 2026-11-12 - plan the upgrade off 14 now); PostgreSQL 19 RC 1 (2026-10-15) is for testing only
- MongoDB **9.0.2** (new major, GA 2026-09-28, EOL 2031-10); 8.0 lane **8.0.34** (EOL 2029-10); 8.0.32 fixes CVE-2026-89099 and is the security floor for the 8.0 lane. The rapid lane is Atlas-only with a short window - verify live before pinning
- MariaDB **11.8.9** (LTS, EOL 2028-06), **12.3.3** (LTS, EOL 2029-06); 13.x rolling GA is quarterly and EOLs at each successor - verify live
- MySQL **8.4.12** (LTS; August 18, 2026 release), **9.7.3** (9.7 LTS lane; August 18, 2026 release); the innovation lane has a short support window - verify live
- Redis **8.10.2**; Valkey **9.1.2** (9.0.6 on the 9.0 lane) - verify live before pinning
- SQL Server **2025 RTM + CU9** (released 2026-09-15)
- PgBouncer **1.26.0** (fixes CVE-2026-19888/6668/6669), Pgpool-II **4.7.3**, ProxySQL **3.0.11** (3.0.9+ fixes CVE-2026-48772/48773; CVE-2026-48774 affects the 4.0 lane, fixed in 4.0.9)

This skill covers these domains depending on context:
- **Configuration** - engine settings, authentication, TLS, tuning parameters
- **Schema design** - indexing strategy, partitioning, normalization, type selection
- **Migration** - cross-engine migration, zero-downtime DDL, ORM migration tooling
- **Operations** - backup/restore, replication, connection pooling, monitoring
- **Performance** - query plan analysis, index optimization, vacuum/maintenance
- **Compliance** - PCI-DSS 4.0 encryption, audit logging, key management, data masking
- **Redis/Valkey operations** - cache or durable-data classification, memory/eviction, persistence,
  replication, ACL/TLS, and stream recovery

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
- Exposing engine-native metrics and diagnosing database-specific health or query signals
- Operating Redis or Valkey as a cache, data store, session store, or stream

## When NOT to use

- Deploying databases on Kubernetes (StatefulSets, PVCs, operators) - use **kubernetes**
- Provisioning managed databases (RDS, Cloud SQL, Atlas) via IaC - use **terraform**
- Docker Compose for database containers - use **docker**
- Database-related Ansible playbooks and roles - use **ansible**
- Application-level database bugs (N+1, transaction misuse, ORM pitfalls) - use **code-review**
- SQL injection detection, connection string secrets in code - use **security-audit**
- CI/CD pipelines that run migrations - use **ci-cd**
- Cross-service telemetry pipelines, dashboards, alert routing, or SLOs - use **observability**
- Other non-relational engines (Cassandra, DynamoDB, ClickHouse, etc.) - use the relevant platform skill or general guidance

---

## AI Self-Check

AI tools consistently produce the same database mistakes. **Before returning any generated SQL, schema, migration, or config, verify against this list:**

### Migrations

- [ ] Versioned migrations detect unexpected schema drift; use guards only for intentionally rerunnable operations
- [ ] Adding `NOT NULL` column includes a `DEFAULT` value (or two-step: add nullable, backfill, alter NOT NULL)
- [ ] Live-write PostgreSQL index builds use CONCURRENTLY only where supported, outside transaction blocks; check for invalid indexes after failure
- [ ] Large table changes run in batches, not a single transaction (lock escalation, OOM risk)
- [ ] Migration is backward-compatible (old app version can still run against new schema)
- [ ] No `DROP TABLE` or `DROP DATABASE` without explicit user confirmation
- [ ] Migration runner records applied versions; rerunnable operational scripts converge and validate existing objects
- [ ] Recovery is tested: down migration when safe, or documented roll-forward/restore when reversal loses data
- [ ] PG enum changes use `ALTER TYPE ... ADD VALUE` outside a transaction (PG 12+ allows it inside a transaction, but the new value cannot be used until that transaction commits - run it standalone to use the value immediately)

### Schema

- [ ] New timestamp columns use `timestamptz` (PG), `DATETIME2` (MSSQL), `DATETIME` (MySQL - `TIMESTAMP` has the 2038 problem)
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

### Bulk Operations

- [ ] Bulk inserts are chunked - never pass an unbounded array into a single `INSERT ... VALUES` statement
- [ ] Chunk size computed as `floor(max_host_parameters / columns_per_row)`, where host-parameter limits are: PostgreSQL 65,535, MySQL 65,535, SQLite 32,766 (default `SQLITE_MAX_VARIABLE_NUMBER`), MSSQL 2,100
- [ ] When the app targets multiple backends, chunk size uses the lowest limit across all supported engines
- [ ] Chunked writes stay inside one transaction when atomicity matters (always for replace-all DELETE + INSERT); otherwise make each chunk idempotent so a failed run can resume.
- [ ] Tests assert that multiple insert calls fire when row count crosses the safe chunk threshold

### General

- [ ] All SQL uses parameterized queries / prepared statements (never string concatenation)
- [ ] Connection pool settings don't exceed `max_connections` across all app instances
- [ ] Backup strategy tested by actually restoring (backup without restore test = hope, not a strategy)
- [ ] Secrets (passwords, connection strings) injected via env vars or secret managers, not config files
- [ ] **Engine/version checked**: SQL syntax, index options, and replication advice match the named engine and major version
- [ ] **Data-loss path gated**: migrations, deletes, reindexes, and failovers include backup, dry-run, rollback, or maintenance-window guidance
- [ ] Cross-cutting agent hygiene applied - see `references/agent-hygiene.md`

---

## Best Practices

- Run restore drills in an isolated destination; verify application reads/writes, consistency,
  encryption-key access, and PITR boundary. Measure elapsed recovery and data loss against
  RTO/RPO, then record the source backup, checks, and cleanup without overwriting live data.
- Separate online, background, and analytical workloads where query shape or latency differs.

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

Before writing SQL or config, determine these. If the user doesn't specify, use the sensible defaults shown:
- **Engine and version** - behavior differs significantly across versions. Default: latest stable (see target versions above).
- **Deployment model** - self-hosted (bare metal, VM, container, K8s) vs managed (RDS, Cloud SQL, Atlas). Default: assume self-hosted unless context says otherwise.
- **Workload type** - OLTP (many small transactions) vs OLAP (few large queries) vs mixed. Default: OLTP.
- **Data volume** - row counts, table sizes, growth rate. Default: medium (1-100GB). If unknown, optimize for growth.
- **Compliance** - PCI-DSS CDE? HIPAA? What data classification? Default: no compliance scope (but still apply security baseline).
- **HA requirements** - RTO/RPO targets, multi-AZ, read replicas. Default: single-node with PITR.
- **Existing infrastructure** - what's already running, what ORMs/drivers are in use. Inspect the codebase if accessible.

### Step 3: Build

Follow the domain-specific section below. Always apply the production checklist and AI self-check before finishing.

Read `references/build-patterns.md` before building: it has the quick-start patterns for query
optimization (PostgreSQL, MySQL, MongoDB plans), lock and deadlock diagnosis, PgBouncer sizing, and
migration safety, plus the required checklist before any destructive or production-changing operation.

### Step 4: Validate

Detect the client first (`command -v psql mongosh mysql sqlcmd`); a missing client is a gap to
report, not a passed check. If a check fails, fix the config, query, or migration and return to
Step 3. After a failed destructive operation, stop and re-plan; never improvise a second one.

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
- **Redis/Valkey**: cache-versus-durable-data classification, memory/eviction safety, persistence,
  replication, ACL/TLS, and stream consumer recovery. Read `references/redis-valkey.md`.

---

## Schema, Migration, and Performance

- Favor expand-contract for zero-downtime schema changes.
- Composite index order still follows equality, sort, then range.
- Choose tenant isolation deliberately; PCI-sensitive shared-schema designs need extra scrutiny.
- Treat query-plan review and monitoring as normal operations, not emergency-only work.
- Watch for `WHERE` clauses that nullify `LEFT JOIN` semantics (filtering the outer table converts it to `INNER JOIN` - move the filter into the `ON` clause or use a subquery).

### Major version upgrades

Before any PostgreSQL major version upgrade, read `references/version-upgrades.md` for the method
choice (`pg_upgrade`, logical replication, dump/restore), the zero-downtime runbook, rollback, and pitfalls.

Read `references/migration-patterns.md` for cross-engine type mapping, ORM migration tooling, and detailed migration patterns.

---

## Pooling, Backup, and Platform Choice

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
- [ ] `work_mem` sized for concurrency (PG default is 4MB; allocated per sort/hash operation, not per connection - multiply by concurrent queries x operations to estimate peak memory)
- [ ] `random_page_cost = 1.1` for SSD storage
- [ ] `statement_timeout` set per-role (not globally - migrations need longer)
- [ ] `idle_in_transaction_session_timeout` assessed per role/workload; default 0 disables it
- [ ] `pg_stat_statements` enabled
- [ ] Autovacuum tuned for large tables (`autovacuum_vacuum_scale_factor`)
- [ ] WAL archiving enabled for PITR (`archive_mode = on` + pgBackRest/Barman, or managed backup)
- [ ] Foreign key columns have indexes
- [ ] pgAudit installed and configured (if PCI scope)
- [ ] Patched against CVE-2026-2005 (pgcrypto heap buffer overflow, RCE) - 18.2+ / 17.8+ / 16.12+ / 15.16+ / 14.21+
- [ ] On the [August 13 PostgreSQL security update](https://www.postgresql.org/support/security/): 18.6 / 17.11 / 16.15 / 15.19 / 14.24 or later in the chosen supported lane. Earlier minors are affected by high-impact server and client issues including CVE-2026-16239 (cursor type confusion), CVE-2026-19385 (pg_dump overflow), and CVE-2026-18408 (psql execution via untrusted dump origin). Update backup/restore clients too. CVE-2026-16238 specifically affects PostgreSQL 18 before 18.6.
- [ ] On the May 14, 2026 PostgreSQL update (CVE-2026-6473/6475/6476/6477/6478: integer-wraparound under-sized allocation, intarray/ltree field overflow, pg_createsubscriber SQL injection, libpq lo_*/path traversal, MD5 password timing leak) - 18.4+ / 17.10+ / 16.14+ / 15.18+ / 14.23+

### MySQL/MariaDB-Specific

- [ ] `sql_mode` includes `STRICT_TRANS_TABLES` (prevents silent data truncation)
- [ ] `innodb_buffer_pool_size` = 70% RAM
- [ ] `innodb_flush_log_at_trx_commit = 1` for durability
- [ ] `require_secure_transport = ON`
- [ ] `character-set-server = utf8mb4`
- [ ] Binary log enabled for PITR (`log_bin = ON`)
- [ ] `innodb_file_per_table = ON`
- [ ] MariaDB patched against CVE-2026-32710 (JSON_SCHEMA_VALID crash/RCE) - 11.8.6+ / 11.4.10+

### MongoDB-Specific

- [ ] `security.authorization: enabled` (never run without auth)
- [ ] Replica set with 3+ members (not standalone in production)
- [ ] Write concern `w: "majority"` (implicit default since 5.0; arbiter topologies can fall back to `w: 1`, so set it explicitly)
- [ ] Schema validation (`$jsonSchema`) on critical collections
- [ ] Patched against MongoBleed (CVE-2025-14847) - 8.0.17+ / 7.0.28+ / 6.0.27+
- [ ] Patched against CVE-2026-89099 - 8.0.32+ ([release notes](https://www.mongodb.com/docs/v8.0/release-notes/8.0/))
- [ ] Patched against CVE-2026-25611 (pre-auth DoS via compression) - 8.0.18+ / 8.2.4+ / 7.0.29+
- [ ] On the June 11, 2026 MongoDB security release (CVE-2026-11933) - 8.0.26+
- [ ] TLS enabled (`net.tls.mode: requireTLS`)

### MSSQL-Specific

- [ ] `Max Server Memory` set explicitly (not unlimited)
- [ ] `MAXDOP` per Microsoft guidance: <= logical processors per (soft-)NUMA node, capped at 8 on single-NUMA servers; multi-NUMA with >16 LPs/node uses half the LPs per node, max 16
- [ ] `Cost Threshold for Parallelism` raised from default 5
- [ ] TempDB files = min(CPU cores, 8), equal size
- [ ] Query Store enabled
- [ ] Recovery model = FULL for production databases
- [ ] TDE enabled for CDE databases
- [ ] Patched against CVE-2026-21262 (privilege escalation) - March 2026 CU+

### Compliance (PCI-DSS 4.0)

- [ ] Encryption at rest: TDE or column-level (disk-level alone insufficient per Req 3.5.1.2)
- [ ] Encryption in transit: TLS 1.2+ enforced on all connections (Req 4)
- [ ] Audit logging: pgAudit/audit plugin, shipped to immutable SIEM (Req 10)
- [ ] Key management: keys in HSM/KMS, not alongside data (Req 3.6)
- [ ] Key rotation follows each key owner/vendor-defined cryptoperiod and compromise response; do not invent universal numeric PCI intervals
- [ ] Access control: separate roles, no shared accounts, MFA for CDE access (Req 7, 8)
- [ ] Data masking: PAN display limited to last 4 digits (Req 3.3)
- [ ] No cardholder data in non-prod environments (Req 6.5.4)
- [ ] Quarterly access review documented (Req 7.2.5)
- [ ] Vulnerability scanning includes database engine, not just containers (Req 11.3)

---

## Reference Files

- `references/config-templates.md` - read when writing engine, pg_hba, role, or PgBouncer config
- `references/backup-patterns.md` - read before any backup, restore, PITR, or retention change
- `references/migration-patterns.md` - read for cross-engine moves, type mapping, ORM tooling, or large-table DDL
- `references/redis-valkey.md` - read whenever Redis or Valkey holds data, sessions, or streams
- `references/version-upgrades.md` - read before any PostgreSQL major version upgrade
- `references/build-patterns.md` - read in Step 3 for query, lock, pooler, and migration-safety patterns, and before any destructive operation

---

## Output Contract

See `references/output-contract.md` for the full contract.

- **Skill name:** DATABASES
- **Deliverable bucket:** `audits`
- **Mode:** conditional. When invoked to **analyze, review, audit, or improve** existing repo content, apply the reporting size and evidence rules in `references/output-contract.md` and write the deliverable to `docs/local/audits/databases/<YYYY-MM-DD>-<slug>.md`. When invoked to **answer a question, teach a concept, build a new artifact, or generate content**, respond freely without the contract.
- **Severity scale:** `P0 | P1 | P2 | P3 | info` (see shared contract; only used in audit/review mode).

## Related Skills

- **code-review** - has a `databases.md` reference for application-level database **bug patterns** (transaction misuse, NULL handling, ORM N+1, type coercion). This skill covers engine configuration and operations; code-review covers how the application uses the database.
- **security-audit** - for SQL injection detection and credential scanning in application code
- **kubernetes** - for deploying databases on K8s (StatefulSets, operators, PVCs)
- **terraform** - for provisioning managed databases (RDS, Cloud SQL, Atlas)
- **docker** - for database containers in Docker Compose
- **ansible** - for database server configuration management
- **ci-cd** - for CI/CD pipelines that run migrations (schema execution in CI, migration gating, rollback automation)
- **observability** - for cross-service telemetry pipelines, dashboards, alert routing, and SLOs.
  This skill owns database-native metrics, engine health, and query diagnosis.
- **message-queues** - broker delivery contracts, retries, dead letters, ordering, and replay. This
  skill owns Redis/Valkey engine configuration and stream data safety.

---

## Rules

1. **Backups without restore tests are not backups.** Test restores monthly. Document the procedure.
2. **No `trust` auth in `pg_hba.conf`.** Not in dev, not in Docker, not anywhere. Use `scram-sha-256`.
3. **Connection pooler for PostgreSQL.** PG's process-per-connection model doesn't scale without one. Use PgBouncer unless a concrete reason says otherwise.
4. **Indexes on foreign keys in PostgreSQL.** PG doesn't auto-create them. Missing FK indexes cause sequential scans on JOINs and cascading DELETEs.
5. **`utf8mb4` for MySQL, always.** `utf8` is a lie - it's 3-byte only, can't store emoji or many CJK characters.
6. **`timestamptz` for PostgreSQL, always.** Bare `timestamp` stores no timezone, breaks when server timezone changes.
7. **Disk-level encryption is insufficient for PCI-DSS 4.0.** Req 3.5.1.2 requires TDE, column-level, or application-layer encryption.
8. **Patch MongoBleed (CVE-2025-14847).** Self-hosted MongoDB < 8.0.17 / 7.0.28 / 6.0.27 is actively exploitable with no authentication required.
9. **Patch MongoDB compression DoS (CVE-2026-25611).** Pre-auth DoS via crafted OP_COMPRESSED messages. Default config affected (compression enabled since 3.6). Fixed in 8.0.18+ / 8.2.4+ / 7.0.29+.
10. **Patch PgBouncer.** PgBouncer < 1.25.1 (CVE-2025-12819) can allow unauthenticated SQL execution when `track_extra_parameters` includes `search_path` AND `auth_user` is set (both non-default). The May 2026 1.25.2 release adds further fixes (CVE-2026-6664/6665/6666/6667: integer overflow, SCRAM, null-deref, KILL_CLIENT authz). The September 2026 1.26.0 release fixes CVE-2026-19888 (unauthenticated crash via a SCRAM client-final-message without a nonce), CVE-2026-6668 (pre-auth hang from packet buffer overflow at default `max_packet_size`), and CVE-2026-6669 (unbounded server SCRAM iterations). Upgrade to 1.26.0+ - the fixes are low-risk.
11. **No destructive command without an approved exact command.** Drops, destructive restores, failovers, and backend terminations run only as the approved text against the confirmed target.
