# Database Bug Patterns

Bug patterns specific to database usage in application code. Focused on correctness -- not schema design, performance tuning, or style. Covers PostgreSQL, MongoDB, MySQL/MariaDB, and MSSQL, plus ORM pitfalls.

---

## General SQL Bugs (All Engines)

### Transaction Misuse

**Detect:**
- Missing transactions around multi-statement operations (partial writes on failure)
- Transaction scope too wide (holding locks across network calls, user input, or long computations)
- Nested transaction confusion -- most SQL databases don't support true nested transactions; savepoints behave differently
- Auto-commit mode when transactions are needed (each statement is its own transaction)
- Missing rollback on error paths (try/catch that catches but doesn't roll back)
- Read-then-write without `SELECT ... FOR UPDATE` or equivalent (lost update problem)

**Example:**
```java
// bug: if the second insert fails, the first is already committed (auto-commit)
connection.createStatement().execute("INSERT INTO orders ...");
connection.createStatement().execute("INSERT INTO order_items ...");

// fix: explicit transaction
connection.setAutoCommit(false);
try {
    connection.createStatement().execute("INSERT INTO orders ...");
    connection.createStatement().execute("INSERT INTO order_items ...");
    connection.commit();
} catch (SQLException e) {
    connection.rollback();
    throw e;
}
```

### SQL Injection via String Concatenation

This overlaps with security-audit but is worth catching in code review because it causes correctness bugs too (mangled queries on special characters).

**Detect:**
- String concatenation building SQL: `"SELECT * FROM users WHERE name = '" + name + "'"`
- f-strings or template literals in SQL: `f"SELECT * FROM users WHERE id = {user_id}"`
- Missing parameterized queries / prepared statements
- ORMs bypassed with raw SQL that isn't parameterized

### NULL Handling

**Detect:**
- `WHERE column = NULL` instead of `WHERE column IS NULL` (always returns 0 rows)
- `WHERE column != 'value'` not returning rows where column is NULL (NULL != anything is NULL, not true)
- `COUNT(column)` vs `COUNT(*)` (the former excludes NULLs, the latter doesn't)
- `NOT IN` with a subquery that can return NULLs (entire predicate becomes NULL -> 0 rows)
- Aggregations on nullable columns without `COALESCE` (SUM of all NULLs is NULL, not 0)
- Application code not handling NULL results from nullable columns

**Example:**
```sql
-- bug: if any tag_id is NULL, this returns 0 rows
SELECT * FROM items WHERE item_id NOT IN (SELECT tag_id FROM tags);

-- fix: filter NULLs or use NOT EXISTS
SELECT * FROM items WHERE item_id NOT IN (SELECT tag_id FROM tags WHERE tag_id IS NOT NULL);
-- or better:
SELECT * FROM items i WHERE NOT EXISTS (SELECT 1 FROM tags t WHERE t.tag_id = i.item_id);
```

### Type Coercion Surprises

**Detect:**
- Comparing string columns to integers without explicit cast (implicit coercion varies by engine)
- Date/timestamp comparison with string literals in ambiguous formats
- Boolean columns compared as integers (MySQL: tinyint(1), Postgres: native bool, MSSQL: bit)
- Decimal precision loss when mixing float and decimal types

### Migration Bugs

**Detect:**
- Adding NOT NULL column without DEFAULT on a table with existing rows (fails on most engines)
- Dropping a column that's still referenced by views, functions, or triggers
- Renaming a column without updating all queries (especially raw SQL, not caught by ORM)
- Index creation without `CONCURRENTLY` (Postgres) or equivalent (locks the table)
- Data migration that runs in a single transaction on a huge table (lock escalation, OOM)

---

## PostgreSQL-Specific

### Transaction Isolation

Postgres defaults to READ COMMITTED, which is fine for most cases but can surprise:

**Detect:**
- SERIALIZABLE isolation expected but not set (phantom reads possible in READ COMMITTED)
- Long-running transactions blocking autovacuum (table bloat)
- `idle in transaction` connections not cleaned up (holds locks, blocks DDL)
- Advisory locks not released on all code paths

### Postgres-Specific Gotchas

**Detect:**
- `UPSERT` (`ON CONFLICT DO UPDATE`) without specifying the conflict target correctly (wrong constraint name or columns)
- `TRUNCATE` not being MVCC-safe the way `DELETE` is (concurrent transactions see different things)
- `LISTEN/NOTIFY` payloads silently truncated at 8000 bytes
- `jsonb` operators: `->` returns JSON, `->>` returns text -- mixing them up causes type errors
- `LIKE` with `%` on a column without a trigram index (full table scan, but more importantly, `LIKE` is case-sensitive; use `ILIKE` for case-insensitive)
- `timestamp` vs `timestamptz` confusion -- `timestamp` stores no timezone info, can cause bugs when the server or session timezone changes
- Array operations: `ANY(array)` vs `IN (values)` behave differently with NULLs

**Example:**
```sql
-- bug: timestamp without timezone, server timezone change breaks everything
CREATE TABLE events (
    created_at timestamp DEFAULT now()  -- stores in server's current timezone
);

-- fix: always use timestamptz
CREATE TABLE events (
    created_at timestamptz DEFAULT now()  -- stores UTC, renders in session timezone
);
```

### Connection Pool Bugs

**Detect:**
- Connection pool exhaustion from leaked connections (acquired but not returned, especially on error paths)
- `statement_timeout` not set (runaway queries hold connections forever)
- PgBouncer in transaction mode with prepared statements (not compatible, silently breaks)
- Pool size mismatch between app instances and `max_connections` (N apps * pool_size > max_connections)

---

## MongoDB-Specific

### Schema-less Pitfalls

**Detect:**
- Missing schema validation on collections (any shape of document can be inserted)
- Field name typos in queries silently return empty results (`{ "naem": "John" }` matches nothing, no error)
- Inconsistent field types across documents (some docs have `age: 25`, others have `age: "25"`)
- Missing `$exists` checks when fields were added later (old documents don't have them)
- Dot notation in field names vs nested objects (`{"a.b": 1}` is a field literally named "a.b", not `{a: {b: 1}}`)

### Query Bugs

**Detect:**
- `find()` without projection returning entire documents (bandwidth waste, potential data exposure)
- Missing `await` on cursor operations (common in Node.js drivers)
- `updateMany` without `$set` (replaces the entire document): `db.users.updateMany({}, { active: true })` replaces all fields
- `$in` with an empty array matches nothing (correct but surprising)
- Aggregation pipeline `$match` stage not at the beginning (can't use indexes)
- `$lookup` (join) without indexes on the foreign collection's join field
- `findOneAndUpdate` without `returnDocument: 'after'` (returns the old document by default)

**Example:**
```javascript
// bug: replaces the entire document, removing all other fields
await db.collection('users').updateOne(
  { _id: userId },
  { status: 'active' }  // missing $set!
);

// fix: use $set
await db.collection('users').updateOne(
  { _id: userId },
  { $set: { status: 'active' } }
);
```

### Write Concern & Consistency

**Detect:**
- Write concern `w: 0` (fire-and-forget, no acknowledgment, data loss possible)
- Read preference `secondary` for data that must be fresh (replication lag means stale reads)
- Missing transactions for multi-document operations that need atomicity (single-document operations are atomic, multi-document are not without transactions)
- `ordered: false` on bulk writes where order matters (continues past errors, can cause inconsistent state)

---

## MySQL / MariaDB-Specific

### Silent Data Truncation

MySQL in non-strict mode silently truncates data that doesn't fit. This is the biggest correctness trap.

**Detect:**
- `sql_mode` not including `STRICT_TRANS_TABLES` (MySQL silently truncates strings, rounds numbers, converts invalid dates to '0000-00-00')
- Inserting a string longer than `VARCHAR(N)` (silently truncated in non-strict mode)
- Inserting out-of-range numbers (silently clamped to min/max of the type)
- `GROUP BY` without strict mode allowing non-aggregated columns (returns arbitrary values)

### MySQL-Specific Gotchas

**Detect:**
- `utf8` charset is actually UTF-8 with 3-byte max (can't store emoji). Use `utf8mb4`
- `TIMESTAMP` vs `DATETIME` -- TIMESTAMP is stored as UTC and converted on read; DATETIME is literal
- `ON UPDATE CURRENT_TIMESTAMP` implicitly added to first TIMESTAMP column in some versions
- `REPLACE INTO` deletes then inserts (triggers DELETE triggers, resets auto_increment gaps)
- `INSERT ... ON DUPLICATE KEY UPDATE` incrementing auto_increment even on updates

---

## MSSQL-Specific

**Detect:**
- `SET NOCOUNT ON` missing in stored procedures (row count messages interfere with some drivers)
- `@@IDENTITY` vs `SCOPE_IDENTITY()` -- `@@IDENTITY` returns the last identity from ANY scope (including triggers)
- `VARCHAR` vs `NVARCHAR` -- VARCHAR can't store Unicode; if your app handles international text, you need NVARCHAR
- `GETDATE()` vs `SYSDATETIME()` -- GETDATE returns datetime (3ms precision), SYSDATETIME returns datetime2 (100ns)
- Implicit transactions with `SET IMPLICIT_TRANSACTIONS ON` (every statement starts a transaction that must be explicitly committed)
- `TOP` without `ORDER BY` returns arbitrary rows (not necessarily the same ones each time)

---

## ORM Pitfalls

These apply regardless of which database engine is used.

### N+1 Queries

The most common ORM performance bug, but also a correctness issue when it causes timeouts.

**Detect:**
- Iterating over a collection and accessing a lazy-loaded relationship in each iteration
- JPA/Hibernate: `@OneToMany` defaulting to `FetchType.LAZY` with no explicit fetch strategy
- Mongoose: `populate()` called in a loop instead of once with an array
- SQLAlchemy: accessing relationship attributes without `joinedload()` or `selectinload()`

### Stale Data / Caching

**Detect:**
- Hibernate L2 cache returning stale data when another service writes directly to the DB
- Entity manager not cleared between operations in a batch job (memory grows, stale entities)
- Optimistic locking (`@Version`) not checked -- updates silently overwrite concurrent changes
- Detached entities merged back without conflict detection

### Migration / Schema Sync

**Detect:**
- ORM auto-DDL enabled in production (`hibernate.hbm2ddl.auto=update` or Mongoose `autoIndex`)
- Entity definition doesn't match actual schema (renamed in DB but not in code, or vice versa)
- Missing `@Column(nullable = false)` on fields that should never be null (ORM allows null, DB allows null, nobody catches it)

### Type Mapping Bugs

**Detect:**
- Java `BigDecimal` mapped to `float`/`double` column (precision loss)
- `LocalDateTime` vs `OffsetDateTime` in JPA (timezone handling depends on JDBC driver and DB)
- MongoDB driver returning `Document` when the app expects a typed object (missing deserialization)
- Enum stored as ordinal (reordering the enum changes all stored values) vs stored as string
