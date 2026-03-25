# Database Migration Patterns

Cross-engine type mappings, zero-downtime schema changes, migration tooling, and SQL dialect differences. Opinionated toward safety -- if a pattern risks data loss, it's called out.

---

## Cross-Engine Type Mapping: MySQL -> PostgreSQL

The most common migration path. MySQL is loose by default; PG is strict. Expect surprises.

| MySQL | PostgreSQL | Notes |
|---|---|---|
| `TINYINT(1)` / `BOOLEAN` | `BOOLEAN` | MySQL BOOLEAN is just TINYINT(1). PG has real booleans. |
| `TINYINT` | `SMALLINT` | PG has no TINYINT. |
| `SMALLINT` | `SMALLINT` | Direct map. |
| `MEDIUMINT` | `INTEGER` | PG has no MEDIUMINT. |
| `INT` / `INTEGER` | `INTEGER` | Direct map. |
| `BIGINT` | `BIGINT` | Direct map. |
| `FLOAT` | `REAL` | IEEE 754 single precision. |
| `DOUBLE` | `DOUBLE PRECISION` | IEEE 754 double precision. |
| `DECIMAL(p,s)` | `NUMERIC(p,s)` | Exact. DECIMAL and NUMERIC are synonyms in both. |
| `INT AUTO_INCREMENT` | `INTEGER GENERATED ALWAYS AS IDENTITY` | Or `SERIAL` (legacy). IDENTITY is SQL-standard, preferred. |
| `BIGINT AUTO_INCREMENT` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Or `BIGSERIAL` (legacy). |
| `VARCHAR(n)` | `VARCHAR(n)` | Direct map. PG `VARCHAR` without length = unlimited. |
| `CHAR(n)` | `CHAR(n)` | Direct map. PG pads with spaces like MySQL. |
| `TINYTEXT` | `TEXT` | PG has no length-limited TEXT variants. |
| `TEXT` | `TEXT` | Direct map. |
| `MEDIUMTEXT` | `TEXT` | PG TEXT is unlimited. |
| `LONGTEXT` | `TEXT` | PG TEXT is unlimited. Use `TOAST` awareness for huge values. |
| `ENUM('a','b','c')` | `CREATE TYPE ... AS ENUM (...)` | PG enums are real types. Or use `VARCHAR` + `CHECK`. |
| `SET('a','b','c')` | `TEXT[]` + `CHECK` | No direct equivalent. Use arrays with constraints. |
| `JSON` | `JSON` | PG `JSON` stores raw text. Usually want `JSONB` instead. |
| `JSON` (with operators) | `JSONB` | Binary storage, indexable, operators work. **Prefer this.** |
| `DATE` | `DATE` | Direct map. |
| `DATETIME` | `TIMESTAMP` | No timezone. Consider `TIMESTAMPTZ` instead. |
| `TIMESTAMP` | `TIMESTAMPTZ` | MySQL TIMESTAMP auto-converts to UTC. PG TIMESTAMPTZ stores UTC. |
| `TIME` | `TIME` | Direct map. |
| `YEAR` | `SMALLINT` or `INTEGER` | No YEAR type in PG. |
| `BINARY(n)` | `BYTEA` | PG has no fixed-length binary. |
| `VARBINARY(n)` | `BYTEA` | PG BYTEA is variable-length, no max. |
| `BLOB` / `LONGBLOB` | `BYTEA` | Or `lo` (large objects) for truly huge data. |
| `BIT(n)` | `BIT(n)` | Direct map. |
| `GEOMETRY` | `geometry` (PostGIS) | Requires PostGIS extension. |
| `POINT` / `POLYGON` etc. | PostGIS types | `CREATE EXTENSION postgis;` required. |
| `ON UPDATE CURRENT_TIMESTAMP` | Trigger | PG has no auto-update timestamp. Write a trigger function. |

**Auto-update timestamp trigger (PG replacement for MySQL's ON UPDATE):**

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_updated_at
    BEFORE UPDATE ON my_table
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

---

## Cross-Engine Type Mapping: PostgreSQL -> MySQL

Rare but happens (usually when moving to managed MySQL or consolidating).

| PostgreSQL | MySQL | Notes |
|---|---|---|
| `BOOLEAN` | `TINYINT(1)` | Loses real boolean semantics. |
| `SMALLINT` | `SMALLINT` | Direct map. |
| `INTEGER` | `INT` | Direct map. |
| `BIGINT` | `BIGINT` | Direct map. |
| `NUMERIC(p,s)` | `DECIMAL(p,s)` | Direct map. |
| `REAL` | `FLOAT` | Direct map. |
| `DOUBLE PRECISION` | `DOUBLE` | Direct map. |
| `TEXT` | `LONGTEXT` | Use `LONGTEXT` to avoid MySQL's 65k limit on `TEXT`. |
| `VARCHAR` (no length) | `VARCHAR(16383)` | MySQL requires a length. 16383 is max for utf8mb4 in InnoDB. |
| `BYTEA` | `LONGBLOB` | Direct map for content. |
| `JSONB` | `JSON` | Loses binary storage and GIN indexing. MySQL JSON is text-parsed. |
| `UUID` | `CHAR(36)` or `BINARY(16)` | MySQL 8.0 has `UUID()` function but no native UUID type. `BINARY(16)` with `UUID_TO_BIN()` is faster. |
| `ARRAY` types | Junction table or `JSON` | MySQL has no native arrays. Normalize or use JSON. |
| `ENUM` type | `ENUM(...)` | MySQL ENUM is column-level, not a reusable type. |
| `TIMESTAMPTZ` | `TIMESTAMP` | MySQL TIMESTAMP is UTC-converting. Or use `DATETIME` + app-level TZ handling. |
| `INTERVAL` | No equivalent | Store as seconds (BIGINT) or use app logic. |
| `INET` / `CIDR` | `VARCHAR(45)` | No native IP type in MySQL. |
| `HSTORE` | `JSON` | Or a key-value table. |
| `TSQUERY` / `TSVECTOR` | `FULLTEXT INDEX` | Completely different full-text approach. |
| `SERIAL` / `IDENTITY` | `AUTO_INCREMENT` | Direct conceptual map. |
| PostGIS geometry | `GEOMETRY` (spatial) | MySQL has basic spatial support. Less capable than PostGIS. |

---

## Cross-Engine Type Mapping: MSSQL -> PostgreSQL

Common in enterprises moving off SQL Server licensing.

| MSSQL | PostgreSQL | Notes |
|---|---|---|
| `BIT` | `BOOLEAN` | MSSQL BIT is 0/1/NULL. PG BOOLEAN is true/false/NULL. |
| `TINYINT` | `SMALLINT` | PG has no TINYINT (0-255 unsigned). |
| `INT` | `INTEGER` | Direct map. |
| `BIGINT` | `BIGINT` | Direct map. |
| `MONEY` / `SMALLMONEY` | `NUMERIC(19,4)` / `NUMERIC(10,4)` | **Never use MONEY in MSSQL either.** Use NUMERIC. |
| `FLOAT(n)` | `DOUBLE PRECISION` or `REAL` | MSSQL FLOAT(1-24)=REAL, FLOAT(25-53)=DOUBLE. |
| `NVARCHAR(n)` | `VARCHAR(n)` | PG is always Unicode (UTF-8). No N-prefix needed. |
| `NVARCHAR(MAX)` | `TEXT` | Direct map. |
| `VARCHAR(MAX)` | `TEXT` | Direct map. |
| `NTEXT` | `TEXT` | NTEXT is deprecated in MSSQL anyway. |
| `IMAGE` | `BYTEA` | IMAGE is deprecated. |
| `VARBINARY(MAX)` | `BYTEA` | Direct map. |
| `UNIQUEIDENTIFIER` | `UUID` | PG has native UUID type. `CREATE EXTENSION "uuid-ossp"` for generation, or `gen_random_uuid()` (PG 13+). |
| `DATETIME` | `TIMESTAMP` | MSSQL DATETIME has 3.33ms precision. PG TIMESTAMP has microsecond. |
| `DATETIME2` | `TIMESTAMP` | PG TIMESTAMP has microsecond precision (6 digits). DATETIME2(7) has 100ns (7 digits) -- values truncated to microseconds on migration. |
| `DATETIMEOFFSET` | `TIMESTAMPTZ` | Direct map. |
| `SMALLDATETIME` | `TIMESTAMP(0)` | Minute precision -- use `TIMESTAMP(0)` to match. |
| `XML` | `XML` | PG has native XML type. Most projects should use JSONB instead. |
| `SQL_VARIANT` | No equivalent | Redesign the schema. `SQL_VARIANT` is a code smell. |
| `IDENTITY(1,1)` | `GENERATED ALWAYS AS IDENTITY` | Direct conceptual map. |
| `ROWVERSION` / `TIMESTAMP` | `xmin` or trigger-based | MSSQL auto-incrementing binary. PG `xmin` serves similar purpose for optimistic locking. |
| `GEOGRAPHY` / `GEOMETRY` | PostGIS types | Requires PostGIS extension. |
| `HIERARCHYID` | `LTREE` | `CREATE EXTENSION ltree;` for path-based hierarchy queries. |
| `COMPUTED COLUMN` | `GENERATED ALWAYS AS (...) STORED` | PG 12+ supports stored generated columns. No virtual (computed-on-read) columns yet. |

---

## Cross-Engine: Relational -> MongoDB

Not a type mapping -- it's a modeling paradigm shift.

| Relational Concept | MongoDB Approach | Guidance |
|---|---|---|
| Normalized tables + JOINs | Embedded documents | Embed data that's read together. Don't normalize by reflex. |
| Foreign keys | `$lookup` or app-level refs | No referential integrity enforcement. Your app owns consistency. |
| JOIN tables (M:N) | Arrays of references or embedded arrays | Small arrays: embed. Large/unbounded arrays: reference. |
| `VARCHAR(n)` | String (no max by default) | Use `$jsonSchema` validator if you need length constraints. |
| `DECIMAL` / `NUMERIC` | `Decimal128` | Use `NumberDecimal()` in shell. **Never store money as Double.** |
| `BOOLEAN` | Boolean | Native BSON type. |
| `TIMESTAMP` / `DATETIME` | `Date` (ISODate) | BSON Date is millisecond precision UTC. |
| `BLOB` | `Binary` or GridFS | GridFS for files > 16MB. Binary for smaller blobs. |
| `AUTO_INCREMENT` | `ObjectId` (default `_id`) | Or use UUID/ULID/nanoid. Sequential IDs leak information. |
| `ENUM` | String + validator | `$jsonSchema` with `enum` in the validator. |
| `NULL` columns | Field absence or explicit `null` | Decide on a convention and stick to it. Missing field != null field in queries. |
| Transactions | Multi-document transactions (4.0+) | Available but slower than single-doc writes. Design to minimize transactions. |
| Schema migrations | Schema versioning field + app-level migration | Add a `schemaVersion` field. Migrate on read or in batch jobs. |

**Schema design rules of thumb:**

- If you query it together, store it together (embed).
- If it grows without bound, reference it (separate collection).
- If it's shared across documents, reference it.
- If the embedded array will exceed ~100 items, reconsider.
- Denormalize for read performance, accept write complexity.

---

## Zero-Downtime Schema Changes

### The Expand-Contract Pattern

The gold standard for schema changes in production with zero downtime. Every change is split into phases that are individually backward-compatible.

**Phase 1: Expand** -- add the new structure alongside the old.

**Phase 2: Migrate** -- backfill data, deploy code that writes to both.

**Phase 3: Contract** -- remove the old structure once nothing reads it.

Never combine phases in one deployment. Each phase gets its own deploy cycle.

### Adding a Column Safely

This is the simplest case. Still has gotchas.

```sql
-- PostgreSQL: non-blocking (no default, nullable)
ALTER TABLE orders ADD COLUMN tracking_url TEXT;

-- PostgreSQL: non-blocking with default (PG 11+, metadata-only)
ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';
-- PG 11+ stores the default in catalog, doesn't rewrite the table.
-- Pre-PG 11: this rewrites every row. Use expand-contract instead.

-- MySQL 8.0+: INSTANT (metadata-only, limited to adding at end)
ALTER TABLE orders ADD COLUMN tracking_url TEXT, ALGORITHM=INSTANT;
-- Falls back to INPLACE if INSTANT isn't possible. Check: ALGORITHM=INSTANT, LOCK=NONE
-- MySQL < 8.0.29: INSTANT only works for adding columns at the end.

-- MSSQL: generally non-blocking for nullable columns
ALTER TABLE orders ADD tracking_url NVARCHAR(2048) NULL;
-- NOT NULL with default: takes a schema lock briefly but doesn't rewrite (2012+).
```

### Removing a Column Safely

**Never drop a column in one step.** The app is still reading it during deploy.

```
Step 1: Deploy code that stops reading the column.
Step 2: Deploy code that stops writing the column.
Step 3: Wait for all old instances to drain (at least one full deploy cycle).
Step 4: DROP the column.
```

```sql
-- PostgreSQL: DROP COLUMN is fast (marks as dropped, doesn't rewrite)
ALTER TABLE orders DROP COLUMN old_status;

-- MySQL: DROP COLUMN rewrites the table. Use pt-online-schema-change for large tables.
-- MySQL 8.0+:
ALTER TABLE orders DROP COLUMN old_status, ALGORITHM=INPLACE, LOCK=NONE;

-- MSSQL: drops column but doesn't reclaim space until DBCC CLEANTABLE or rebuild.
ALTER TABLE orders DROP COLUMN old_status;
```

### Renaming a Column (The Hard One)

You cannot atomically rename a column and update all application code. This is always a multi-step process.

```
Step 1: Add the new column.
Step 2: Deploy code that writes to BOTH old and new columns.
Step 3: Backfill: UPDATE table SET new_col = old_col WHERE new_col IS NULL;
         (batch this for large tables -- see "Large Table Migration Patterns")
Step 4: Deploy code that reads from new column (falls back to old).
Step 5: Deploy code that only reads/writes new column.
Step 6: Drop old column.
```

```sql
-- DO NOT use ALTER TABLE ... RENAME COLUMN in production deployments.
-- It's atomic at the DB level but breaks every query referencing the old name.
-- Only safe if you can deploy DB change + app change atomically (you can't).
```

**Shortcut for low-traffic/maintenance-window scenarios:**

```sql
-- PostgreSQL: metadata-only rename (fast, but breaks queries instantly)
ALTER TABLE orders RENAME COLUMN old_name TO new_name;

-- MySQL: ALGORITHM=INPLACE, LOCK=NONE (but still breaks queries)
ALTER TABLE orders CHANGE old_name new_name VARCHAR(255), ALGORITHM=INPLACE, LOCK=NONE;
```

### Changing a Column Type

Widening (INT -> BIGINT, VARCHAR(50) -> VARCHAR(255)) is usually safe. Narrowing or type-changing is dangerous.

```sql
-- PostgreSQL: widening VARCHAR is metadata-only
ALTER TABLE orders ALTER COLUMN name TYPE VARCHAR(500);
-- Narrowing or type change: rewrites table + takes ACCESS EXCLUSIVE lock.
-- Use expand-contract pattern for these.

-- PostgreSQL: INT -> BIGINT rewrites the table. Expand-contract approach:
ALTER TABLE orders ADD COLUMN id_new BIGINT;
-- backfill, switch reads, drop old, rename new

-- MySQL 8.0+: some type changes support ALGORITHM=INPLACE
ALTER TABLE orders MODIFY COLUMN name VARCHAR(500), ALGORITHM=INPLACE, LOCK=NONE;
-- Changing INT -> BIGINT: always a table rebuild in MySQL.
```

### Adding/Dropping Indexes Without Locking

```sql
-- PostgreSQL: CONCURRENTLY prevents table lock (but takes longer, can't run in transaction)
CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);
DROP INDEX CONCURRENTLY idx_orders_status;
-- If CONCURRENTLY fails partway, it leaves an INVALID index. Check and retry:
-- SELECT * FROM pg_indexes WHERE indexname = 'idx_orders_status';
-- DROP INDEX CONCURRENTLY idx_orders_status; CREATE INDEX CONCURRENTLY ...

-- MySQL 8.0+: online DDL (default for secondary indexes)
ALTER TABLE orders ADD INDEX idx_status (status), ALGORITHM=INPLACE, LOCK=NONE;
ALTER TABLE orders DROP INDEX idx_status, ALGORITHM=INPLACE, LOCK=NONE;

-- MSSQL: ONLINE = ON for Enterprise/Developer editions
CREATE INDEX idx_orders_status ON orders (status) WITH (ONLINE = ON);
DROP INDEX idx_orders_status ON orders WITH (ONLINE = ON);
-- Standard Edition: no ONLINE option. Plan for a maintenance window.
```

---

## Cross-Engine Migration Process

### Assessment Checklist

Before migrating a database engine, evaluate:

- [ ] **Schema complexity**: stored procedures, triggers, views, CTEs, custom functions
- [ ] **Data volume**: total size, largest tables, row counts
- [ ] **Data types**: identify all types that don't map 1:1 (see tables above)
- [ ] **Character encoding**: source charset vs target (MySQL latin1 -> PG UTF-8 is common pain)
- [ ] **Collation differences**: sort order may change (affects ORDER BY, indexes, UNIQUE constraints)
- [ ] **Auto-increment gaps**: sequences in PG don't guarantee gap-free. If the app relies on gap-free IDs, redesign.
- [ ] **Stored procedures/functions**: language differences (T-SQL vs PL/pgSQL vs MySQL proc syntax)
- [ ] **Triggers**: rewrite required (syntax is completely different per engine)
- [ ] **Views**: check for engine-specific functions
- [ ] **Implicit type coercion**: MySQL silently truncates, PG throws errors. Test all write paths.
- [ ] **NULL handling**: MySQL treats NULL differently in some comparisons
- [ ] **Query patterns**: LIMIT/OFFSET, GROUP BY rules, window functions, CTEs
- [ ] **Connection pooling**: PgBouncer (PG), ProxySQL (MySQL) -- different configs
- [ ] **ORM/driver compatibility**: check driver support for target engine
- [ ] **Backup/restore tooling**: different per engine
- [ ] **Replication topology**: may need redesign

### Data Migration Tooling

| Tool | Direction | Notes |
|---|---|---|
| `pgloader` | MySQL/MSSQL/SQLite -> PG | Best open-source option. Handles type mapping, encoding, indexes. Single command. |
| AWS DMS | Any -> Any (AWS) | Supports CDC (ongoing replication). Good for minimal-downtime migrations. |
| Azure DMS | Any -> Azure SQL/PG/MySQL | Microsoft's equivalent. |
| `mysqldump` + transform | MySQL -> anything | Export SQL, sed/awk the syntax. Crude but works for small DBs. |
| `pg_dump` / `pg_restore` | PG -> PG | For version upgrades or same-engine migrations. |
| `ora2pg` | Oracle -> PG | The Oracle escape hatch. Handles schema + data + PLSQL conversion. |
| Custom ETL scripts | Any -> Any | For complex transformations. Use batched reads/writes with checkpointing. |

**pgloader example (MySQL -> PostgreSQL):**

```lisp
LOAD DATABASE
    FROM mysql://user:pass@mysql-host/source_db
    INTO postgresql://user:pass@pg-host/target_db
WITH
    include no drop,
    create tables,
    create indexes,
    reset sequences,
    workers = 4,
    concurrency = 2,
    batch rows = 10000
SET
    PostgreSQL PARAMETERS
        maintenance_work_mem to '512MB'
CAST
    type tinyint to smallint using byte-to-smallint,
    type mediumint to integer,
    type int when (= precision 1) to boolean using tinyint-to-boolean
;
```

### Schema Conversion Approach

1. **Export source schema** (DDL only, no data).
2. **Automated conversion** with pgloader/ora2pg/AWS SCT for a first pass.
3. **Manual review** of every type mapping, constraint, and index.
4. **Stored procedures**: rewrite manually. Automated tools produce garbage for complex logic.
5. **Test schema** against target engine: create empty DB, load schema, fix errors iteratively.
6. **Diff tools**: compare source and target schemas side by side.

### Validation Checklist

Run after migration, before cutover:

- [ ] **Row counts**: every table, source vs target. Must match exactly.
- [ ] **Checksum/hash spot checks**: sample rows from large tables, compare field values.
- [ ] **NULL counts per column**: catch silent truncation or coercion.
- [ ] **Constraint verification**: all PKs, FKs, UNIQUEs, CHECKs exist and are enforced.
- [ ] **Index verification**: all indexes exist and are valid.
- [ ] **Sequence values**: current values match max(id) + 1 for each table.
- [ ] **Encoding verification**: special characters (emoji, CJK, diacritics) survived.
- [ ] **Date/time verification**: timezone-aware values didn't shift.
- [ ] **Application smoke tests**: run the full test suite against the new DB.
- [ ] **Query plan comparison**: run top-N slow queries on both, compare plans.
- [ ] **Performance baseline**: measure p50/p95/p99 latency on critical queries.

### Rollback Strategy

Always have one. If the migration is:

- **Offline (downtime window)**: keep the source DB intact. Rollback = repoint app to old DB.
- **Online (DMS/CDC)**: run reverse replication or keep source writable. Cutover = DNS/config switch.
- **One-way (source decommissioned)**: take a final backup of source before cutover. Keep it for 30+ days.

---

## ORM Migration Tooling

### Drizzle Kit

Drizzle generates migrations from schema diffs. The output needs babysitting.

**Workflow:**

```bash
# 1. Modify your schema file (e.g., src/db/schema.ts)
# 2. Generate migration
bun run drizzle-kit generate

# 3. ALWAYS review the generated SQL
cat drizzle/XXXX_migration_name.sql

# 4. Add safety guards to the DDL
# Drizzle generates bare DDL that crashes on re-run:
#   ALTER TABLE users ADD COLUMN email TEXT;
# Fix to:
#   ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;
#
# Same for DROP:
#   ALTER TABLE users DROP COLUMN old_field;
# Fix to:
#   ALTER TABLE users DROP COLUMN IF EXISTS old_field;

# 5. Run migration
bun run drizzle-kit migrate
```

**Drizzle gotchas:**

- `generate` reads schema files only -- no DB connection needed.
- `migrate` requires `DATABASE_URL` (or equivalent connection config).
- Generated SQL has no `IF NOT EXISTS` / `IF EXISTS` guards. If a previous deploy applied DDL but crashed before journaling the migration, re-running crashes. Always add guards manually.
- Drizzle doesn't generate data backfill SQL. Write separate scripts for data migrations.
- The `drizzle` meta table tracks applied migrations. Don't manually insert/delete rows.
- `push` (dev-only) applies schema directly without generating migration files. Never use in production.

### Prisma Migrate

```bash
# Generate migration from schema diff
npx prisma migrate dev --name add_email_column

# Apply in production (no interactive prompts)
npx prisma migrate deploy

# Reset (dev only -- drops and recreates DB)
npx prisma migrate reset
```

**Prisma gotchas:**

- `migrate dev` creates AND applies the migration. `migrate deploy` only applies.
- Prisma locks you into its migration format. Ejecting is painful.
- Shadow database required for `migrate dev` -- needs CREATE DATABASE permissions.
- No `IF NOT EXISTS` guards either. Same re-run crash risk as Drizzle.
- Prisma's introspection (`db pull`) can lose information (comments, partial indexes, custom types).
- Data migrations: write separate SQL files, reference them in the migration directory.

### Alembic (Python / SQLAlchemy)

```bash
# Generate migration from model diff
alembic revision --autogenerate -m "add email column"

# Apply
alembic upgrade head

# Rollback one step
alembic downgrade -1
```

**Alembic gotchas:**

- Autogenerate misses: table/column renames (detects as drop+add), some constraint changes, data-only migrations.
- Always review autogenerated code. It's a starting point, not gospel.
- Each migration has `upgrade()` and `downgrade()` -- write both.
- `alembic stamp head` marks current state without running migrations (useful after manual schema fixes).
- For zero-downtime, split expand and contract into separate revisions.
- Alembic can't detect changes in custom types, enums, or server defaults reliably.

### Flyway

```bash
# Apply pending migrations
flyway migrate

# Check current state
flyway info

# Validate (check applied migrations match local files)
flyway validate

# Repair (fix broken state after failed migration)
flyway repair
```

**Flyway conventions:**

- Naming: `V1__create_users.sql`, `V2__add_email.sql` (double underscore).
- Repeatable migrations: `R__refresh_views.sql` (re-applied when checksum changes).
- Undo (paid only): `U1__undo_create_users.sql`. Open-source: write your own rollback scripts.
- Flyway checksums every applied migration. Editing an applied migration breaks `validate`.
- Java-based migrations for complex data transformations: `V3__BackfillEmails.java`.

### Liquibase

```bash
# Apply pending changesets
liquibase update

# Rollback last N changesets
liquibase rollback-count 1

# Generate diff between DB and reference
liquibase diff

# Generate changelog from existing DB
liquibase generate-changelog
```

**Liquibase vs Flyway:**

| Aspect | Flyway | Liquibase |
|---|---|---|
| Format | Raw SQL (default) | XML/YAML/JSON/SQL |
| Rollback | Paid feature (or manual) | Built-in (if `rollback` block defined) |
| Diff | Paid feature | Free |
| Complexity | Simple | More features, steeper learning curve |
| Contexts/Labels | No (paid) | Yes (target env-specific changesets) |
| Checksums | Per-file SHA | Per-changeset |

### Common ORM Migration Anti-Patterns

- **Running `migrate` in application startup code.** Migrations should run once, separately, before the app starts. Race conditions with multiple replicas.
- **No down migration / rollback plan.** "We'll just fix forward" works until it doesn't.
- **Mixing schema and data migrations.** Keep them separate. Schema changes are fast and reversible. Data backfills are slow and not.
- **Not reviewing generated SQL.** Autogenerate is a suggestion, not a command. Review every migration.
- **Testing migrations only against empty databases.** Test against a copy of production data. Column type changes behave differently with 10M rows vs 0.
- **Skipping migrations in dev.** Using `push`/`db push`/`sync` in dev means your migrations are untested until staging. Run the actual migration flow locally.
- **Editing applied migrations.** Once a migration is applied anywhere (even dev), it's immutable. Create a new migration to fix issues.

---

## SQL Syntax Differences

### Identifier Quoting

| Engine | Quote Style | Example |
|---|---|---|
| MySQL | Backticks | `` `column name` `` |
| PostgreSQL | Double quotes | `"column name"` |
| MSSQL | Square brackets or double quotes | `[column name]` or `"column name"` |
| SQLite | Double quotes or backticks | `"column name"` or `` `column name` `` |

PG and MSSQL both support double quotes (SQL standard). MySQL's `ANSI_QUOTES` mode enables double quotes but breaks MySQL-native tools. Stick with backticks for MySQL.

### String Concatenation

```sql
-- MySQL
SELECT CONCAT(first_name, ' ', last_name) FROM users;
-- Or with CONCAT_WS (with separator):
SELECT CONCAT_WS(' ', first_name, last_name) FROM users;

-- PostgreSQL
SELECT first_name || ' ' || last_name FROM users;
-- CONCAT() also works but || is idiomatic.
-- WARNING: || with NULL returns NULL. Use COALESCE or CONCAT().

-- MSSQL
SELECT first_name + ' ' + last_name FROM users;
-- Or CONCAT() (2012+, NULL-safe):
SELECT CONCAT(first_name, ' ', last_name) FROM users;
```

### Pagination (LIMIT / OFFSET)

```sql
-- MySQL / PostgreSQL / SQLite
SELECT * FROM orders ORDER BY id LIMIT 20 OFFSET 40;

-- MSSQL (2012+)
SELECT * FROM orders ORDER BY id
OFFSET 40 ROWS FETCH NEXT 20 ROWS ONLY;

-- MSSQL (legacy, pre-2012)
SELECT TOP 20 * FROM (
    SELECT *, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM orders
) t WHERE rn > 40;
```

**Pagination gotcha:** `OFFSET` is O(n) -- it scans and discards rows. For deep pagination (page 1000+), use keyset pagination:

```sql
-- All engines (keyset / cursor-based):
SELECT * FROM orders WHERE id > :last_seen_id ORDER BY id LIMIT 20;
```

### UPSERT (INSERT ... ON CONFLICT / DUPLICATE KEY)

```sql
-- PostgreSQL (9.5+)
INSERT INTO users (email, name) VALUES ('a@b.com', 'Alice')
ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name;

-- MySQL (INSERT ... ON DUPLICATE KEY UPDATE)
INSERT INTO users (email, name) VALUES ('a@b.com', 'Alice')
ON DUPLICATE KEY UPDATE name = VALUES(name);
-- MySQL 8.0.19+: alias syntax
INSERT INTO users (email, name) VALUES ('a@b.com', 'Alice') AS new_row
ON DUPLICATE KEY UPDATE name = new_row.name;

-- MSSQL (MERGE)
MERGE INTO users AS target
USING (VALUES ('a@b.com', 'Alice')) AS source (email, name)
ON target.email = source.email
WHEN MATCHED THEN UPDATE SET name = source.name
WHEN NOT MATCHED THEN INSERT (email, name) VALUES (source.email, source.name);
-- MERGE has known bugs in older MSSQL versions. Always include a semicolon terminator.

-- SQLite (3.24+)
INSERT INTO users (email, name) VALUES ('a@b.com', 'Alice')
ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name;
```

### Date/Time Functions

| Operation | MySQL | PostgreSQL | MSSQL |
|---|---|---|---|
| Current timestamp | `NOW()` | `NOW()` or `CURRENT_TIMESTAMP` | `GETDATE()` or `SYSDATETIME()` |
| Current UTC | `UTC_TIMESTAMP()` | `NOW() AT TIME ZONE 'UTC'` | `GETUTCDATE()` or `SYSUTCDATETIME()` |
| Date part | `YEAR(col)`, `MONTH(col)` | `EXTRACT(YEAR FROM col)` | `YEAR(col)`, `DATEPART(YEAR, col)` |
| Add interval | `DATE_ADD(col, INTERVAL 7 DAY)` | `col + INTERVAL '7 days'` | `DATEADD(DAY, 7, col)` |
| Subtract dates | `DATEDIFF(d1, d2)` (days) | `d1 - d2` (returns interval) | `DATEDIFF(DAY, d2, d1)` |
| Format date | `DATE_FORMAT(col, '%Y-%m-%d')` | `TO_CHAR(col, 'YYYY-MM-DD')` | `FORMAT(col, 'yyyy-MM-dd')` or `CONVERT` |
| Parse string | `STR_TO_DATE('2024-01-01', '%Y-%m-%d')` | `TO_TIMESTAMP('2024-01-01', 'YYYY-MM-DD')` | `CAST('2024-01-01' AS DATE)` |
| Truncate to day | `DATE(col)` | `DATE_TRUNC('day', col)` | `CAST(col AS DATE)` |
| Epoch seconds | `UNIX_TIMESTAMP(col)` | `EXTRACT(EPOCH FROM col)` | `DATEDIFF(SECOND, '1970-01-01', col)` |

### Boolean Handling

```sql
-- PostgreSQL: real booleans
SELECT * FROM users WHERE is_active = TRUE;
SELECT * FROM users WHERE is_active;  -- implicit TRUE check
SELECT * FROM users WHERE NOT is_active;

-- MySQL: TINYINT(1) pretending to be boolean
SELECT * FROM users WHERE is_active = 1;
SELECT * FROM users WHERE is_active;  -- works (truthy: non-zero)
-- TRUE and FALSE keywords exist but are just aliases for 1 and 0.

-- MSSQL: BIT type
SELECT * FROM users WHERE is_active = 1;
-- No boolean literals. BIT columns can't be used in WHERE directly without comparison.
```

### NULL Handling Differences

```sql
-- All engines: NULL = NULL is NULL (not TRUE). Use IS NULL.
-- But there are subtle differences:

-- MySQL: NULL-safe equality operator
SELECT * FROM t WHERE col <=> NULL;   -- returns rows where col IS NULL
SELECT * FROM t WHERE col <=> 'foo';  -- NULL-safe comparison

-- PostgreSQL: IS NOT DISTINCT FROM (SQL standard, verbose)
SELECT * FROM t WHERE col IS NOT DISTINCT FROM NULL;

-- MSSQL: SET ANSI_NULLS OFF (legacy, avoid)
-- With ANSI_NULLS ON (default): col = NULL never matches.
-- MSSQL-specific: ISNULL() vs COALESCE() -- ISNULL is faster but only takes 2 args.

-- String concatenation with NULL:
-- MySQL CONCAT('a', NULL, 'b') = 'ab' (NULL is skipped)
-- PostgreSQL 'a' || NULL || 'b' = NULL (NULL propagates)
-- MSSQL 'a' + NULL + 'b' = NULL (NULL propagates, unless SET CONCAT_NULL_YIELDS_NULL OFF)

-- GROUP BY with NULL:
-- All engines: NULLs are grouped together into one group. Consistent behavior.

-- UNIQUE constraints with NULL:
-- PostgreSQL: allows multiple NULLs (NULLs are distinct in UNIQUE)
-- MySQL: allows multiple NULLs (same as PG)
-- MSSQL: allows only ONE NULL in a UNIQUE index (NULLs are equal)
-- MSSQL workaround: filtered index WHERE col IS NOT NULL
```

---

## Large Table Migration Patterns

### pt-online-schema-change (MySQL)

Percona's tool for zero-downtime DDL on large MySQL tables. Creates a shadow table, copies data in chunks, swaps via rename.

```bash
# Add a column to a 100M-row table without locking
pt-online-schema-change \
    --alter "ADD COLUMN email VARCHAR(255)" \
    --execute \
    --chunk-size=1000 \
    --max-lag=1s \
    --check-interval=1 \
    --critical-load="Threads_running=50" \
    D=mydb,t=users,h=localhost,u=root,p=secret

# Flags that matter:
# --max-lag: pause if replica lag exceeds this
# --critical-load: abort if server load exceeds threshold
# --chunk-size: rows per batch (tune based on row size)
# --dry-run: preview without executing
```

**How it works:**

1. Creates `_users_new` with the desired schema.
2. Creates triggers on `users` to replicate INSERT/UPDATE/DELETE to `_users_new`.
3. Copies data in chunks (configurable size).
4. Renames `users` -> `_users_old`, `_users_new` -> `users` (atomic).
5. Drops `_users_old` and triggers.

**Risks:** trigger overhead during copy, extra disk space for the shadow table, foreign key complications.

### gh-ost (GitHub Online Schema Migration, MySQL)

Trigger-free alternative to pt-online-schema-change. Uses binlog stream instead of triggers.

```bash
gh-ost \
    --host=localhost \
    --database=mydb \
    --table=users \
    --alter="ADD COLUMN email VARCHAR(255)" \
    --execute \
    --chunk-size=1000 \
    --max-lag-millis=1000 \
    --critical-load="Threads_running=50"
```

**Advantages over pt-osc:** no triggers (less overhead), pausable/resumable, testable (--test-on-replica).

### pg_repack (PostgreSQL)

Repacks tables and indexes online, without blocking. Useful for bloat removal and some schema changes.

```bash
# Repack a bloated table (reclaim dead tuple space)
pg_repack --table=orders --jobs=4 mydb

# Repack all tables in a database
pg_repack --jobs=4 mydb

# Repack only indexes
pg_repack --only-indexes --table=orders mydb
```

**Not a DDL tool** -- pg_repack is for maintenance (bloat, reindexing). For schema changes, use expand-contract + `CREATE INDEX CONCURRENTLY`.

### Online DDL (MySQL 8.0+)

MySQL 8.0+ supports many DDL operations as online (INPLACE or INSTANT algorithm).

```sql
-- INSTANT operations (metadata-only, PG 16+ equivalent):
ALTER TABLE t ADD COLUMN c INT, ALGORITHM=INSTANT;               -- 8.0.12+
ALTER TABLE t ALTER COLUMN c SET DEFAULT 42, ALGORITHM=INSTANT;
ALTER TABLE t RENAME COLUMN old TO new, ALGORITHM=INSTANT;        -- 8.0.28+

-- INPLACE operations (no table copy, allows concurrent DML):
ALTER TABLE t ADD INDEX idx_col (col), ALGORITHM=INPLACE, LOCK=NONE;
ALTER TABLE t DROP INDEX idx_col, ALGORITHM=INPLACE, LOCK=NONE;
ALTER TABLE t MODIFY COLUMN c VARCHAR(500), ALGORITHM=INPLACE, LOCK=NONE;

-- Check what's possible:
ALTER TABLE t ADD COLUMN c INT, ALGORITHM=INSTANT;
-- If it fails, try INPLACE, then COPY as last resort.
```

**MySQL INSTANT limitations:**

- Adding columns to the middle (not end) of the table: INSTANT only in 8.0.29+.
- Dropping columns: INSTANT only in 8.0.29+.
- Changing column type: never INSTANT (requires INPLACE or COPY).

### CONCURRENTLY Keyword (PostgreSQL)

```sql
-- Create index without blocking writes (takes longer, can't be in a transaction)
CREATE INDEX CONCURRENTLY idx_orders_email ON orders (email);

-- Drop index without blocking
DROP INDEX CONCURRENTLY idx_orders_email;

-- Reindex without blocking (PG 12+)
REINDEX INDEX CONCURRENTLY idx_orders_email;
REINDEX TABLE CONCURRENTLY orders;
```

**CONCURRENTLY gotchas:**

- Can't run inside a transaction block (`BEGIN ... COMMIT`).
- Takes an extra pass over the table (slower than regular CREATE INDEX).
- If interrupted, leaves an INVALID index that you must drop and retry.
- Check for invalid indexes: `SELECT * FROM pg_index WHERE NOT indisvalid;`

### Batched Data Backfill Pattern

For backfilling data in a new column across millions of rows without locking.

```sql
-- PostgreSQL batched backfill (run in a script with a loop)
UPDATE orders
SET new_status = CASE old_status
    WHEN 'P' THEN 'pending'
    WHEN 'S' THEN 'shipped'
    ELSE 'unknown'
END
WHERE id IN (
    SELECT id FROM orders
    WHERE new_status IS NULL
    ORDER BY id
    LIMIT 5000
);
-- Repeat until 0 rows affected. Add a short sleep between batches to reduce load.

-- MySQL batched backfill
UPDATE orders
SET new_status = CASE old_status
    WHEN 'P' THEN 'pending'
    WHEN 'S' THEN 'shipped'
    ELSE 'unknown'
END
WHERE new_status IS NULL
ORDER BY id
LIMIT 5000;
-- Repeat until 0 rows affected.
```

**Backfill script template (bash):**

```bash
#!/usr/bin/env bash
set -euo pipefail

BATCH_SIZE=5000
SLEEP_BETWEEN=0.5  # seconds

while true; do
    # psql prints "UPDATE N" on success -- extract N
    output=$(psql -c "
        WITH batch AS (
            SELECT id FROM orders
            WHERE new_status IS NULL
            ORDER BY id LIMIT ${BATCH_SIZE}
            FOR UPDATE SKIP LOCKED
        )
        UPDATE orders SET new_status = 'pending'
        FROM batch WHERE orders.id = batch.id;
    " "$DATABASE_URL" 2>&1)
    affected=$(echo "$output" | grep -oP 'UPDATE \K[0-9]+' || echo "0")

    echo "Updated ${affected} rows"
    if [[ "${affected}" -eq 0 ]]; then
        echo "Backfill complete."
        break
    fi
    sleep "${SLEEP_BETWEEN}"
done
```

**Key principles for large backfills:**

- **Batch size**: 1000-10000 rows. Too small = overhead. Too large = locks + replication lag.
- **Order by PK**: prevents deadlocks and gives predictable progress.
- **`FOR UPDATE SKIP LOCKED`** (PG): skip rows locked by other transactions. Prevents contention.
- **Monitor replica lag**: pause if replicas fall behind.
- **Idempotent**: `WHERE new_col IS NULL` ensures re-running is safe.
- **Track progress**: log batch number, total updated, estimated remaining.
