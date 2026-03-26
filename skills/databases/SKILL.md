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
source: custom
date_added: "2026-03-24"
effort: high
---

# Databases: Production Configuration & Operations

Configure, tune, design schemas, migrate, back up, and review database engines -- from single-node dev setups to PCI-compliant production clusters. The goal is correct, performant, durable databases that survive failures, pass audits, and don't wake you up at 3am.

**Target versions** (March 2026):
- PostgreSQL **18.3** (EOL 2030-11), previous LTS: 17.9, 16.13
- MongoDB **8.0.20** (GA), 8.2.6 (rapid release, EOL 2026-07)
- MariaDB **11.8.6** (LTS, EOL 2028-06), 12.2.2 (innovation, EOL 2026-05)
- MySQL **8.4.8** (LTS), 9.6.0 (innovation)
- SQL Server **2025 RTM + CU2** (GA 2025-11-18)
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

## PostgreSQL

### Configuration essentials

Read `references/config-templates.md` for copy-pasteable `postgresql.conf` and `pg_hba.conf` templates (dev, prod, PCI-CDE variants).

**PG 18 notable changes:**
- **OAuth 2.0 authentication** -- integrate with Keycloak, Entra ID, etc. natively
- **MD5 password auth deprecated** -- SCRAM-SHA-256 is the only acceptable option
- **Async I/O subsystem** -- up to 3x read performance improvement
- **`uuidv7()` built-in** -- timestamp-ordered UUIDs without extensions
- **`pg_upgrade` preserves optimizer statistics** -- no more post-upgrade `ANALYZE` marathons
- **Auto-drop idle replication slots** -- prevents WAL bloat from dead subscribers

**Critical `pg_hba.conf` rules:**
- `hostssl` only for remote connections (never `host` without SSL)
- `scram-sha-256` only (never `trust`, never `md5`)
- CIDR-restrict connections to known subnets
- Separate entries for app role (DML), migration role (DDL), admin (superuser)

**Key tuning parameters:**

| Parameter | Starting point | Notes |
|-----------|---------------|-------|
| `shared_buffers` | 25% of RAM | Never more than 40% |
| `effective_cache_size` | 75% of RAM | Tells planner about OS cache |
| `work_mem` | 64MB (OLTP), 256MB+ (OLAP) | Per-operation, not global. Set lower for OLTP (many concurrent queries) |
| `maintenance_work_mem` | 512MB-1GB | For VACUUM, CREATE INDEX |
| `max_connections` | 100-200 (with pooler) | Each connection costs ~10MB. Use PgBouncer for >200 clients |
| `random_page_cost` | 1.1 (SSD), 4.0 (HDD) | Default 4.0 assumes HDD -- wrong for modern deployments |
| `wal_level` | `replica` | Required for streaming replication; `logical` for logical replication |
| `statement_timeout` | 30s (web apps) | Prevents runaway queries. Set per-role, not globally for migrations |
| `idle_in_transaction_session_timeout` | 60s | Kills sessions holding locks without doing anything |
| `ssl_min_protocol_version` | `TLSv1.3` | `TLSv1.2` minimum for PCI |

### Replication

**Streaming replication** (physical, byte-for-byte copy):
- Primary sends WAL to standby(s) continuously
- Standby is read-only (hot standby) or offline (warm standby)
- Synchronous mode: `synchronous_commit = on` + `synchronous_standby_names` for zero data loss (at latency cost)
- Failover: use **Patroni** (etcd-backed, production standard) or **pg_auto_failover** (simpler, single-node HA)

**Logical replication** (PG 10+, table-level, cross-version):
- Subscribe to specific tables, not the whole cluster
- Supports different PG versions on publisher/subscriber (use for zero-downtime upgrades)
- PG 18: parallel streaming default, conflict monitoring via `pg_stat_subscription_stats`
- PG 18: `pg_createsubscriber --all` creates logical replicas for all DBs in one command
- Gotcha: DDL changes are NOT replicated -- you must apply schema changes on both sides

### Extensions (essential)

| Extension | Purpose | Built-in? |
|-----------|---------|-----------|
| `pgcrypto` | Column-level encryption (AES-256) | Yes (contrib) |
| `pgAudit` | Detailed audit logging (PCI Req 10) | Install separately |
| `pg_stat_statements` | Query performance statistics | Yes (contrib) |
| `pg_trgm` | Trigram matching for `LIKE`/`ILIKE` indexes | Yes (contrib) |
| `uuid-ossp` / built-in `uuidv7()` | UUID generation | `uuidv7()` in PG 18+, extension for older |
| `pgvector` | Vector similarity search (AI/ML) | Install separately |
| `pg_repack` | Online table/index reorganization (no locks) | Install separately |
| `PostGIS` | Geospatial data | Install separately |

### Vacuum & maintenance

- **Autovacuum**: leave it ON. Tune `autovacuum_vacuum_scale_factor` (default 0.2 = vacuum when 20% of rows are dead). For large tables, lower to 0.01-0.05.
- **Bloat detection**: `SELECT relname, n_dead_tup, n_live_tup, n_dead_tup::float / GREATEST(n_live_tup, 1) AS dead_ratio FROM pg_stat_user_tables WHERE n_dead_tup > 1000 ORDER BY dead_ratio DESC;`
- **Index bloat**: `REINDEX CONCURRENTLY` (PG 12+) to rebuild without locking. Don't use plain `REINDEX` on production.
- **pg_repack**: alternative to `VACUUM FULL` that doesn't hold an exclusive lock. Use for large table compaction.
- **Unused indexes**: `SELECT indexrelname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0 AND idx_tup_read = 0 ORDER BY pg_relation_size(indexrelid) DESC;`

### CVEs to know (2025-2026)

- **CVE-2025-8714/8715** (pg_dump code injection): newline injection in object names allows code execution during `psql` restore. Fixed in 17.6, 16.10, 15.14, 14.19, 13.22.
- **CVE-2025-1094** (libpq SQL injection): `PQescapeLiteral()` etc. miss neutralizing quoting syntax. Fixed in 17.3, 16.7.
- **pgAdmin CVE-2025-13780**: security filter bypass in plain-text restore -> shell command execution on host.
- **PgBouncer CVE-2025-12819**: unauthenticated SQL execution via malicious `search_path` in StartupMessage. Fixed in 1.25.1. **Upgrade immediately if running PgBouncer < 1.25.1.**

---

## MongoDB

### Configuration essentials

Read `references/config-templates.md` for copy-pasteable `mongod.conf` templates.

**MongoDB 8.0 highlights:**
- 25% better throughput/latency across the board, 54% faster bulk inserts
- **Queryable Encryption with range queries** -- `>`, `<`, `>=`, `<=` on encrypted fields
- 50x faster resharding, ability to unshard collections
- Config shard: config server can store app data alongside cluster metadata

**Critical config:**
- `security.authorization: enabled` -- NEVER run without auth, even in dev (default is disabled)
- `net.tls.mode: requireTLS` for production
- `security.keyFile` for replica set authentication (minimum)
- `storage.wiredTiger.engineConfig.cacheSizeGB` -- default is `(RAM - 1GB) / 2` or 256MB, whichever is larger. Good default, but for shared hosts set explicitly.

### Replica sets

- **3-member minimum** for production. 2 data-bearing + 1 arbiter for homelab (but arbiter can't participate in elections if a data member goes down -- prefer 3 data-bearing).
- `rs.initiate()` with explicit member config. Set `priority: 0` on members that should never become primary (analytics replicas, DR site).
- **Write concern**: `w: "majority"` for durability (default in 8.0+). `w: 1` sacrifices durability for speed.
- **Read preference**: `primaryPreferred` for reads that can tolerate stale data. `primary` for consistency-critical reads.
- **Oplog sizing**: default 5% of disk. Increase for write-heavy workloads to give more time for maintenance windows.
- Monitor replication lag: `rs.printReplicationInfo()`, `rs.printSecondaryReplicationInfo()`.

### Schema design patterns

MongoDB is schemaless but not designless:
- **Embed** when: 1:1 or 1:few relationships, data is read together, updates are atomic per document
- **Reference** when: 1:many or many:many, documents would exceed 16MB, independent lifecycle
- **Avoid unbounded arrays** -- the "fan-out" anti-pattern. Arrays that grow without limit cause document migration (expensive), eventual 16MB limit hit
- **Schema validation**: use `$jsonSchema` validator on collections. Catch bad data at insert, not at query time
- **Compound indexes**: field order matters more than in SQL. Equality fields first, sort fields next, range fields last (ESR rule)

### CVEs to know (2025-2026)

- **MongoBleed (CVE-2025-14847)**: **CRITICAL**. Unauthenticated heap memory disclosure via malformed zlib-compressed packets. CVSS 8.7. 87,000+ exposed servers. Actively exploited. Affects every version from 3.6 through 8.2.2. **Patch to: 8.0.17+, 7.0.28+, 6.0.27+, 5.0.32+, 4.4.30+** (depending on your branch). Atlas customers auto-patched. CISA KEV deadline: Jan 19, 2026.

---

## MySQL / MariaDB

### Configuration essentials

Read `references/config-templates.md` for copy-pasteable `my.cnf` templates.

**MySQL 8.4 LTS** is what you run in production. 9.x is innovation/quarterly -- fine for dev, not for stability.

**MariaDB 11.8 LTS** (EOL 2028-06) is the production choice. 12.x is innovation.

**Critical settings:**

```ini
# MANDATORY: prevents silent data truncation, the biggest MySQL correctness trap
sql_mode = STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION

# Character set: utf8mb4, NOT utf8 (which is 3-byte only, can't store emoji)
character-set-server = utf8mb4
collation-server = utf8mb4_0900_ai_ci    # MySQL 8.0+
# MariaDB: utf8mb4_uca1400_ai_ci (14.0.0 UCA)

# InnoDB
innodb_buffer_pool_size = 70%_of_RAM     # the single most important tuning parameter
innodb_redo_log_capacity = 2G            # MySQL 8.0.30+. Replaces innodb_log_file_size (deprecated, ignored in 8.4)
innodb_flush_log_at_trx_commit = 1       # durability (2 = faster but risks 1s of data loss)
innodb_file_per_table = ON               # always

# Encryption (all replication connections encrypted by default in 9.x)
require_secure_transport = ON
tls_version = TLSv1.2,TLSv1.3
```

**MySQL vs MariaDB divergence (2026):**
- MariaDB has native temporal tables, Oracle compat mode, ColumnStore engine
- MySQL has Group Replication / InnoDB Cluster, HeatWave (ML), JSON Duality Views
- They share InnoDB but the implementations have diverged. Don't assume compatibility.
- MariaDB dropped the "drop-in replacement" positioning in 2024.

### Replication

**MySQL**: GTID-based replication is the standard. `gtid_mode = ON`, `enforce_gtid_consistency = ON`. Group Replication for multi-primary (but single-primary mode is safer).

**MariaDB**: GTID is also domain-based but incompatible with MySQL GTID. Galera Cluster for synchronous multi-primary.

**ProxySQL** (3.0.6): transparent read/write splitting, query routing, connection pooling. Sits between app and MySQL/MariaDB.

### CVEs to know (2025-2026)

- **MariaDB CVE-2026-32710**: `JSON_SCHEMA_VALID()` crash, potential RCE. CVSS 8.5. Affects 11.4 < 11.4.10 and 11.8 < 11.8.6. Published March 20, 2026. **Patch immediately.**

---

## MSSQL

### Configuration essentials

**SQL Server 2025** (GA Nov 2025) -- the first version with built-in AI features. Web edition dropped.

**Key settings:**
- `MAXDOP` -- set to CPU core count (per NUMA node), not left at 0 (unlimited)
- `Cost Threshold for Parallelism` -- raise from default 5 to 25-50 for OLTP
- `Max Server Memory` -- set explicitly, leave 4-8GB for OS. Never leave at default (unlimited).
- `TempDB files` -- one data file per CPU core (up to 8), equal size, same growth rate
- `Query Store` -- enable for all production databases (auto-plan regression detection)

**Critical:**
- `SCOPE_IDENTITY()`, NOT `@@IDENTITY` (the latter returns identity from trigger scope too)
- `NVARCHAR` for Unicode text, NOT `VARCHAR` (VARCHAR can't store international characters)
- `DATETIME2` over `DATETIME` (100ns precision vs 3ms, larger date range)
- `SET NOCOUNT ON` in all stored procedures (row count messages interfere with some drivers)
- `TOP` without `ORDER BY` returns arbitrary rows -- not the same ones each time

### Backup strategy

Read `references/backup-patterns.md` for the full backup strategy per engine.

**MSSQL quick reference:**
- Recovery model: `FULL` for production (enables PITR), `SIMPLE` for dev/test
- Schedule: Full weekly + Differential daily + TLog every 15 min
- `BACKUP DATABASE ... WITH COMPRESSION, CHECKSUM, INIT`
- Verify: `RESTORE VERIFYONLY` after every backup. Periodic full test restores.
- **Ola Hallengren's maintenance scripts** are the standard for backup + integrity + index maintenance. Use them.

### CVEs to know (2025-2026)

- **CVE-2025-59499**: malicious database names with SQL control characters -> arbitrary T-SQL as elevated user. CVSS 8.8. Affects 2016-2022.
- **CVE-2026-21262**: zero-day (March 10, 2026). Privilege escalation to sysadmin. CVSS 8.8. Affects 2016-2025 including Azure IaaS.
- **CVE-2025-47954, CVE-2025-53727**: cross-tenant privilege escalation on DBaaS platforms (AWS RDS, GCP CloudSQL, Alibaba ApsaraDB). Users could decrypt vendor-protected procedures. **Verify your managed provider has patched.**

---

## Schema Design

### Index strategy (cross-engine)

**Composite index column order** (ESR rule -- applies to all engines):
1. **E**quality columns first (WHERE col = value)
2. **S**ort columns next (ORDER BY col)
3. **R**ange columns last (WHERE col > value)

**PostgreSQL-specific:**
- PG does NOT auto-create indexes on FK columns -- you must add them manually
- Partial indexes: `CREATE INDEX ... WHERE status = 'active'` -- smaller, faster, targeted
- Covering indexes: `CREATE INDEX ... INCLUDE (col)` (PG 11+) -- enables index-only scans
- Expression indexes: `CREATE INDEX ... ON lower(email)` for case-insensitive lookups
- GIN indexes for JSONB, array, and full-text search
- `text` vs `varchar(n)`: no performance difference in PG. `varchar(n)` just adds a length check.

**MySQL/MariaDB-specific:**
- InnoDB clusters on PK by default -- PK choice directly impacts write performance and index size
- Secondary indexes implicitly include PK columns (affects size)
- Prefix indexes for long text: `CREATE INDEX ... ON col(255)` -- but they can't be covering

**MongoDB-specific:**
- Compound index order is critical -- MongoDB can only use the index for queries that match a prefix of the key pattern
- Covered queries: if projection matches the index fields exactly, MongoDB skips document fetch
- Text indexes for full-text search, `2dsphere` for geospatial

### Partitioning

**When to partition:**
- Tables > 100M rows with time-based queries
- Data retention policies (drop old partitions instead of DELETE)
- Tenant isolation in multi-tenant apps

**PostgreSQL**: declarative partitioning (PG 10+). Range (time-series), List (tenant), Hash (even distribution). Create partitions ahead of time or use `pg_partman`.

**MySQL/MariaDB**: range, list, hash, key partitioning. Partition pruning requires the partition key in the WHERE clause.

**MongoDB**: sharding is the partitioning equivalent. Shard key selection is permanent (pre-8.0) and critical. Hash shard key for even distribution, range for time-series.

### Multi-tenant patterns

| Pattern | Pros | Cons | Best for |
|---------|------|------|----------|
| **Shared schema** (tenant_id column) | Simple, cheap, easy joins | Noisy neighbor, no isolation | Small tenants, SaaS startups |
| **Schema-per-tenant** (PG schemas) | Good isolation, shared server | Connection overhead, migration complexity | Medium tenants, moderate isolation needs |
| **DB-per-tenant** | Full isolation, independent backup/restore | Expensive, hard to aggregate | PCI CDE, enterprise, large tenants |

For PCI-DSS CDE data: **DB-per-tenant or schema-per-tenant with Row-Level Security (RLS)**. Shared schema without RLS is a finding.

### Type selection gotchas

- **PG**: `timestamptz` always (never bare `timestamp`). `text` over `varchar`. `bigint` for IDs (32-bit `integer` exhausts faster than you think). `GENERATED ALWAYS AS IDENTITY` over `SERIAL`.
- **MySQL**: `utf8mb4` always. `DATETIME` over `TIMESTAMP` (TIMESTAMP has 2038 problem, implicit timezone conversion). `BIGINT` for IDs. Avoid `ENUM` (adding values requires ALTER TABLE).
- **MongoDB**: `ObjectId` is fine for most IDs. `Decimal128` for money (not `Double`). `Date` stores milliseconds since epoch -- don't store date strings.
- **MSSQL**: `NVARCHAR` for text. `DATETIME2` over `DATETIME`. `BIGINT` for IDs. `DECIMAL` for money (not `MONEY` type -- it has rounding issues).

---

## Migration

Read `references/migration-patterns.md` for complete cross-engine type mapping tables, zero-downtime patterns, and tooling comparison.

### Zero-downtime schema changes (expand-contract)

1. **Expand**: add new column/table (nullable, with default). Deploy app code that writes to both old and new.
2. **Migrate**: backfill data in batches. Verify integrity.
3. **Contract**: deploy app code that reads from new only. Drop old column/table in a later release.

This is the only safe pattern for production schema changes under continuous deployment.

### Tooling landscape (2026)

| Tool | Type | Engines | Notes |
|------|------|---------|-------|
| **Drizzle Kit** | Declarative (schema-as-code) | PG, MySQL, SQLite | TypeScript. Generates SQL migrations from schema diff. Review generated DDL -- add `IF NOT EXISTS` guards. |
| **Prisma Migrate** | Declarative | PG, MySQL, SQLite, MSSQL, MongoDB | TypeScript. Shadow database for diff. Heavy. |
| **Atlas** (Ariga) | Declarative (schema-as-code) | PG, MySQL, MariaDB, SQLite, MSSQL, CockroachDB | "Terraform for databases." HCL or SQL schema. Best CI/CD integration. |
| **Flyway** | Versioned (SQL files) | All major engines | Java CLI. Simple, proven, enterprise-standard. |
| **Liquibase** | Versioned (XML/YAML/SQL) | All major engines | Java CLI. Rollback support, change tracking. |
| **Alembic** | Versioned (Python) | PG, MySQL, SQLite, MSSQL | Python (SQLAlchemy). Auto-generates from model diff. |
| **pgloader** | Data migration | MySQL/MSSQL -> PG | Best tool for cross-engine data migration to PostgreSQL. |
| **pg_dump/pg_restore** | Backup/restore | PG | Schema + data. Use `--format=custom` for selective restore. |

### Cross-engine migration gotchas

The full type mapping table is in `references/migration-patterns.md`. Key traps:

**MySQL -> PostgreSQL:**
- `TINYINT(1)` -> `boolean` (not `smallint`)
- `DATETIME` -> `timestamptz` (not `timestamp`)
- `AUTO_INCREMENT` -> `GENERATED ALWAYS AS IDENTITY`
- `ENUM('a','b')` -> `CHECK` constraint or PG enum type
- `utf8` (3-byte) -> PG `UTF8` handles everything
- `UNSIGNED` integers -> no equivalent; use `CHECK (col >= 0)` or wider type
- `ON UPDATE CURRENT_TIMESTAMP` -> needs a trigger in PG
- `REPLACE INTO` -> `INSERT ... ON CONFLICT`
- `GROUP BY` partial column list -> PG enforces SQL standard (list all non-aggregated columns)
- `LIMIT x, y` -> `LIMIT y OFFSET x`
- Backtick quoting -> double-quote quoting

---

## Connection Pooling

### PostgreSQL pooling (non-negotiable)

PostgreSQL uses a process-per-connection model (~10MB per connection). Without a pooler, you run out of connections or RAM. MySQL uses threads (~256KB each) -- pooling helps but is less critical.

**PgBouncer** (recommended for most workloads):

| Mode | Description | Use when |
|------|-------------|----------|
| `transaction` | Connection returned after each transaction | Default for web apps. Most apps should use this. |
| `session` | Connection held for entire client session | Need: prepared statements, advisory locks, LISTEN/NOTIFY, SET commands |
| `statement` | Connection returned after each statement | Rare. Breaks multi-statement transactions. |

**Key settings:**
```ini
[pgbouncer]
pool_mode = transaction
max_client_conn = 1000           # max app connections to PgBouncer
default_pool_size = 20           # backend connections per user/db pair
reserve_pool_size = 5            # extra connections for burst
server_idle_timeout = 300        # reclaim idle backend connections
query_wait_timeout = 120         # fail fast instead of queueing forever
max_prepared_statements = 100    # PgBouncer 1.21+ -- fixes prepared stmt + transaction mode
```

**Sizing formula:**
```
pool_per_instance = (db_max_connections * 0.8) / app_instance_count
optimal_db_max = CPU_cores * 2 + disk_count
```

**Prepared statement gotcha**: PgBouncer in transaction mode breaks named prepared statements (they're connection-scoped). Fix: use PgBouncer 1.21+ `max_prepared_statements` setting, or use `DEALLOCATE ALL` at transaction end, or switch to extended query protocol.

**CVE-2025-12819 reminder**: PgBouncer < 1.25.1 allows unauthenticated SQL execution. Upgrade.

### MySQL/MariaDB pooling

**ProxySQL** (3.0.6) is the standard middleware pooler for MySQL/MariaDB:
- Transparent read/write splitting
- Query routing rules (regex-based)
- Connection multiplexing
- Query caching
- Built-in monitoring

### Application-side pooling

Most ORMs/drivers have built-in connection pools. Key settings:
- **Pool size**: match the PgBouncer `default_pool_size` or database `max_connections / app_instances`
- **Idle timeout**: release connections after 30-60s idle
- **Connection lifetime**: rotate connections every 30-60 min (catches stale DNS, failover)
- **Acquire timeout**: fail fast (5-10s) rather than queue indefinitely

---

## Backup & Recovery

Read `references/backup-patterns.md` for complete per-engine backup scripts and schedules.

### Strategy matrix

| Engine | Logical backup | Physical backup | PITR | Streaming |
|--------|---------------|-----------------|------|-----------|
| **PostgreSQL** | `pg_dump` / `pg_dumpall` | `pg_basebackup` | WAL archiving + `restore_command` | pgBackRest, Barman |
| **MongoDB** | `mongodump` | Filesystem snapshots | Oplog replay | Ops Manager, Percona Backup |
| **MySQL** | `mysqldump` / `mysqlpump` | Percona XtraBackup, MySQL Enterprise Backup | Binary log replay | `--source-data` flag |
| **MSSQL** | BCP, `BACKUP DATABASE` | VDI snapshots | Transaction log restore with `STOPAT` | Log shipping, Always On AG |

### Non-negotiable rules

1. **Test restores regularly.** A backup you've never restored is not a backup. Monthly minimum.
2. **3-2-1 rule**: 3 copies, 2 different media, 1 offsite.
3. **Encrypt backups** -- `pg_dump` output is plaintext SQL with data. Pipe through `gpg` or use pgBackRest encryption.
4. **Monitor backup freshness.** Alert if the last successful backup is >24h old.
5. **Document the restore procedure.** When you need it, you'll be stressed and sleep-deprived. Write it down now.
6. **PCI Req 3.1**: define data retention limits. Don't keep backups of cardholder data beyond the retention period.

---

## Performance

### Query plan analysis

**PostgreSQL** `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`:
- `Seq Scan` on a large table = missing index (or index not selective enough)
- `Bitmap Heap Scan` = good, using index but fetching many rows
- `Index Only Scan` = best, all data from index
- `Nested Loop` with high row count on inner = consider hash/merge join (may need `work_mem` increase)
- `Buffers: shared hit` = cached. `shared read` = disk I/O. High read count = need more `shared_buffers` or better index.
- **Use `pg_stat_statements`** to find the most time-consuming queries (sorted by `total_exec_time`).

**MySQL** `EXPLAIN FORMAT=TREE` (8.0+):
- `type: ALL` = full table scan. Need index.
- `type: index` = full index scan. Better but still scanning everything.
- `type: range` = index range scan. Good.
- `type: ref` = index lookup. Good.
- `type: const` = single row by PK/unique. Best.
- Check `rows` estimate vs actual (use `EXPLAIN ANALYZE` in 8.0.18+).

**MongoDB** `explain("executionStats")`:
- `COLLSCAN` = collection scan (no index). Bad.
- `IXSCAN` = index scan. Good.
- `totalDocsExamined` >> `nReturned` = index not selective enough
- `executionTimeMillis` > threshold = needs optimization

### Monitoring essentials

**PostgreSQL:**
- `pg_stat_user_tables`: sequential vs index scan ratio, dead tuples, last vacuum/analyze
- `pg_stat_user_indexes`: unused indexes (`idx_scan = 0`)
- `pg_stat_activity`: active queries, idle-in-transaction, waiting on locks
- `pg_stat_statements`: top queries by time, calls, rows
- Cache hit ratio: `SELECT sum(blks_hit) / sum(blks_hit + blks_read) FROM pg_stat_database;` -- should be >99%

**MySQL:**
- `SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool%'` -- hit ratio, free pages
- `SHOW PROCESSLIST` -- active connections, long-running queries
- `performance_schema.events_statements_summary_by_digest` -- top queries
- `SHOW ENGINE INNODB STATUS` -- deadlocks, lock waits

**MongoDB:**
- `db.serverStatus()` -- connections, opcounters, lock percentage
- `db.currentOp()` -- running operations
- `mongotop` -- time spent reading/writing per collection
- `mongostat` -- server-level metrics at intervals

---

## Compliance (PCI-DSS 4.0)

PCI-DSS 4.0 is the only active version (3.2.1 retired March 2024). All future-dated requirements became mandatory March 31, 2025.

### Encryption at rest (Req 3.5)

**PCI-DSS 4.0 change: disk-level encryption alone no longer satisfies Req 3.5.1.2** (except for removable media). You need TDE, column-level, or application-layer encryption.

| Engine | TDE | Column-level | Application-layer |
|--------|-----|-------------|-------------------|
| **PostgreSQL** | pg_tde (EDB), filesystem-level | `pgcrypto` (AES-256) | App-managed encryption before insert |
| **MySQL** | InnoDB tablespace encryption | `AES_ENCRYPT()`/`AES_DECRYPT()` | App-managed |
| **MariaDB** | InnoDB + Aria encryption | Same as MySQL | App-managed |
| **MongoDB** | WiredTiger encrypted storage engine | CSFLE (Client-Side Field Level Encryption), Queryable Encryption (8.0) | App-managed |
| **MSSQL** | TDE (whole DB), Always Encrypted (column) | `ENCRYPTBYKEY()`/`DECRYPTBYKEY()` | App-managed |

**Key management (Req 3.6, 3.7):**
- Store encryption keys in HSM or KMS (AWS KMS, Azure Key Vault, HashiCorp Vault) -- never alongside the data
- Key hierarchy: master key (in HSM) -> data encryption key (in database)
- Rotate DEKs every 90 days, master keys annually
- Split knowledge / dual control for master key access
- Document key custodians and rotation procedures

### Encryption in transit (Req 4)

- **PostgreSQL**: `ssl = on`, `ssl_min_protocol_version = TLSv1.2` (TLSv1.3 preferred), `pg_hba.conf` with `hostssl` entries only
- **MySQL/MariaDB**: `require_secure_transport = ON`, `tls_version = TLSv1.2,TLSv1.3`
- **MongoDB**: `net.tls.mode: requireTLS`
- **MSSQL**: `Force Encryption = Yes` in SQL Server Configuration Manager

### Audit logging (Req 10)

| Engine | Tool | What it captures |
|--------|------|-----------------|
| **PostgreSQL** | pgAudit extension | SELECT, DML, DDL, role, function calls. `pgaudit.log = 'all'` for CDE. |
| **MySQL** | Audit Log plugin (Enterprise), MariaDB Audit Plugin | Connections, queries, errors. |
| **MongoDB** | `--auditDestination file` + `auditFilter` | Auth events, CRUD, admin ops. |
| **MSSQL** | SQL Server Audit + C2 Audit Mode | Server-level and database-level events. |

Ship audit logs to an immutable SIEM (Req 10.4.1.1). The database server must not be able to modify or delete its own audit trail.

### Access control (Req 7, 8)

- **Separate roles**: app (DML only), migration (DDL), admin (superuser, restricted), read-only (analytics, support)
- **No shared accounts** (Req 8.5.1): every DBA gets their own credentials
- **MFA for all CDE database access** (Req 8.4.2): use certificate auth, LDAP/OIDC integration, or jump host with MFA
- **Row-Level Security (PG)**: `CREATE POLICY` to restrict row access by tenant/role. Enforced at engine level, can't be bypassed by application bugs.
- **Review access quarterly** (Req 7.2.5): who has access, do they still need it?

### Data masking (Req 3.3, 3.4)

- Display only last 4 digits of PAN: `SELECT '****-****-****-' || RIGHT(pan, 4)`
- **Dynamic data masking**: MSSQL has built-in. PG: use views with masking functions. MySQL: ProxySQL can mask in-flight.
- **Static data masking**: for non-prod environments. Copy prod data, replace PAN/PII with realistic fakes. Never use real cardholder data in dev/test.

---

## AI-Age Considerations

### LLM SQL injection

Attackers craft natural language prompts to trick LLMs into generating `DROP TABLE`, data exfiltration queries, or privilege escalation SQL. **ToxicSQL** (2025) demonstrated backdoor attacks that poison Text-to-SQL fine-tuning datasets.

**Rules:**
- Never execute LLM-generated SQL without validation
- All database operations from AI agents MUST use parameterized queries
- AI agents should have read-only database access unless explicitly authorized for writes
- Log all AI-generated queries separately for audit

### AI-generated schema/migration quality

AI-generated PRs have **1.7x more issues** than human code (CodeRabbit 2025). SQL injection is the #1 AI codegen flaw -- models default to string concatenation from old training data.

**Common AI mistakes in database code:**
- String concatenation instead of parameterized queries (training data bias)
- Missing `CONCURRENTLY` on PG index creation (locks table)
- Bare `ALTER TABLE ADD COLUMN NOT NULL` without DEFAULT (fails on non-empty tables)
- `utf8` instead of `utf8mb4` for MySQL (old training data)
- `timestamp` instead of `timestamptz` for PG (the classic)
- Missing `IF NOT EXISTS` guards on migrations (not idempotent)
- Suggesting `VACUUM FULL` casually (holds exclusive lock -- use `pg_repack` instead)
- Recommending PgBouncer session mode when transaction mode is correct

### Vector databases (pgvector, MongoDB Atlas Search)

Embeddings are NOT anonymous -- **embedding inversion attacks recover original inputs in 92% of cases** (including PII). Treat vector data with the same security controls as the source data. Encrypt at rest, control access, audit queries.

---

## Managed vs Self-Hosted Decision

| Factor | Managed (RDS, Cloud SQL, Atlas) | Self-hosted (VM, K8s, bare metal) |
|--------|--------------------------------|-----------------------------------|
| **Ops overhead** | Low (patches, backups, HA handled) | High (you own everything) |
| **Cost** | Higher at scale, predictable | Lower at scale, variable |
| **Customization** | Limited (no custom extensions, restricted superuser) | Full control |
| **Performance** | Good, but can't tune kernel/storage | Tunable to the metal |
| **Compliance** | Shared responsibility -- verify what the provider covers | You own all controls |
| **Extensions** | Limited catalog (varies by provider) | Install anything |
| **HA** | Built-in (multi-AZ, automatic failover) | DIY (Patroni, Galera, replica sets) |

**Recommendation**: start managed, move to self-hosted when you need custom extensions, cost optimization at scale, or full compliance control. For PCI CDE: managed is fine IF you verify the provider's attestation covers your requirements. Most do, but read the shared responsibility matrix.

For self-hosted on K8s: use an operator (CloudNativePG for PG, Percona for MySQL/MongoDB, CrunchyData for PG). Don't raw-dog StatefulSets for databases.

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
- [ ] `random_page_cost = 1.1` for SSD storage
- [ ] `statement_timeout` set per-role (not globally -- migrations need longer)
- [ ] `idle_in_transaction_session_timeout` set (60s default)
- [ ] `pg_stat_statements` enabled
- [ ] Autovacuum tuned for large tables (`autovacuum_vacuum_scale_factor`)
- [ ] Foreign key columns have indexes
- [ ] pgAudit installed and configured (if PCI scope)

### MySQL/MariaDB-Specific

- [ ] `sql_mode` includes `STRICT_TRANS_TABLES` (prevents silent data truncation)
- [ ] `innodb_buffer_pool_size` = 70% RAM
- [ ] `innodb_flush_log_at_trx_commit = 1` for durability
- [ ] `require_secure_transport = ON`
- [ ] `character-set-server = utf8mb4`
- [ ] Binary log enabled for PITR (`log_bin = ON`)
- [ ] `innodb_file_per_table = ON`

### MongoDB-Specific

- [ ] `security.authorization: enabled` (never run without auth)
- [ ] Replica set with 3+ members (not standalone in production)
- [ ] Write concern `w: "majority"` (default in 8.0+)
- [ ] Schema validation (`$jsonSchema`) on critical collections
- [ ] Patched against MongoBleed (CVE-2025-14847) -- 8.0.17+
- [ ] TLS enabled (`net.tls.mode: requireTLS`)

### MSSQL-Specific

- [ ] `Max Server Memory` set explicitly (not unlimited)
- [ ] `MAXDOP` set to core count per NUMA node
- [ ] `Cost Threshold for Parallelism` raised from default 5
- [ ] TempDB files = min(CPU cores, 8), equal size
- [ ] Query Store enabled
- [ ] Recovery model = FULL for production databases
- [ ] TDE enabled for CDE databases

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

## Critical Rules

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
12. **Patch PgBouncer (CVE-2025-12819).** PgBouncer < 1.25.1 allows unauthenticated SQL execution. Upgrade.
13. **Run the AI self-check.** Every generated migration, schema, or config gets verified against the checklist above before returning.

---

## Related Skills

- **code-review** -- has `references/databases.md` for application-level database **bug patterns** (transaction misuse, NULL handling, ORM N+1, type coercion). This skill covers engine configuration and operations; code-review covers how the application uses the database.
- **security-audit** -- for SQL injection detection and credential scanning in application code
- **kubernetes** -- for deploying databases on K8s (StatefulSets, operators, PVCs)
- **terraform** -- for provisioning managed databases (RDS, Cloud SQL, Atlas)
- **docker** -- for database containers in Docker Compose
- **ansible** -- for database server configuration management
