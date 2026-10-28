# Database Build Patterns

Quick-start patterns for the most common database requests: query optimization, lock contention and deadlock diagnosis, connection pooler sizing, migration safety checks, and the plan-validate-execute checklist for destructive or production-changing operations.

---

**Common operations - quick-start patterns:**

**Query optimization** (the most frequent request):
1. Get the plan with realistic parameters: `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;` (PG), `EXPLAIN FORMAT=TREE ...;` (MySQL 8.0+), `db.collection.explain('executionStats').find(...)` (MongoDB).
2. Look for: `Seq Scan` on large tables (PG) / `Full Table Scan` (MySQL) / `COLLSCAN` (MongoDB), `Nested Loop` with high row estimates, `Sort` spilling to disk (`Sort Method: external merge`), and `Rows Removed by Filter` >> `Rows` returned.
2a. Before assuming an index problem, verify semantic correctness: check JOIN conditions for column mismatches, confirm WHERE clause predicates don't unintentionally filter nulls, and verify LEFT JOIN semantics aren't silently converted to INNER JOIN by outer-table filters.
3. Check index usage: `SELECT schemaname, relname, idx_scan, seq_scan FROM pg_stat_user_tables WHERE seq_scan > 100 ORDER BY seq_scan DESC;` (PG; adjust `schemaname = 'public'` filter for non-public schemas) or `SELECT * FROM sys.schema_unused_indexes;` (MySQL performance_schema).
4. If a missing index is the fix, create it with `CONCURRENTLY` (PG): `CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);` or `ALGORITHM=INPLACE, LOCK=NONE` (MySQL).
5. Re-run `EXPLAIN ANALYZE` to confirm the planner uses the new index and that estimated vs actual rows are close.

**Lock contention / deadlock diagnosis** (second most common "it's stuck" scenario):
1. PG: `SELECT pid, age(xact_start), query, wait_event_type, wait_event FROM pg_stat_activity WHERE state != 'idle' AND wait_event IS NOT NULL ORDER BY age(xact_start) DESC;`
2. PG blocked queries: `SELECT blocked.pid AS blocked_pid, blocked.query AS blocked_query, blocking.pid AS blocking_pid, blocking.query AS blocking_query FROM pg_stat_activity blocked JOIN pg_locks bl ON bl.pid = blocked.pid JOIN pg_locks kl ON kl.locktype = bl.locktype AND kl.database IS NOT DISTINCT FROM bl.database AND kl.relation IS NOT DISTINCT FROM bl.relation AND kl.page IS NOT DISTINCT FROM bl.page AND kl.tuple IS NOT DISTINCT FROM bl.tuple AND kl.transactionid IS NOT DISTINCT FROM bl.transactionid AND kl.pid != bl.pid JOIN pg_stat_activity blocking ON blocking.pid = kl.pid WHERE NOT bl.granted AND kl.granted;`
3. MySQL: `SHOW ENGINE INNODB STATUS\G` - look for `LATEST DETECTED DEADLOCK` section. Also: `SELECT * FROM performance_schema.data_lock_waits;` (MySQL 8.0+).
4. MongoDB: `db.currentOp({"waitingForLock": true})` and check `mongod` log for `LockTimeout` entries.
5. Inspect the blocker owner, transaction age, and impact. Prefer query cancellation (PG: `SELECT pg_cancel_backend(<pid>);`); terminate the exact backend/thread (PG: `pg_terminate_backend(<pid>)`, MySQL: `KILL <thread_id>`) only with explicit authorization after assessing rollback impact. Then address the cause of the lock.

**Connection pooler sizing** (second most common):
1. Determine backend budget: `max_connections` minus reserved connections and operational headroom = available; budget replication workers/senders separately.
2. PgBouncer `default_pool_size` per user/db pair: budget the sum across every active user/database pool and PgBouncer instance within available backend capacity.
3. Set `max_client_conn` to the total connections your app fleet will open (all instances combined).
4. Use `transaction` pool mode for stateless web apps. Switch to `session` mode (which supports all PostgreSQL features) when the app needs session-level state: temp tables, advisory locks, `SET`, or prepared statements on PgBouncer older than 1.21 (1.21+ supports prepared statements in transaction mode via `max_prepared_statements`).
5. Validate: `psql -h pgbouncer-host -p 6432 pgbouncer -c "SHOW POOLS;"` - watch `sv_active` vs `sv_idle` under load.

**Migration safety check** (before running any DDL in production):
1. Identify versioned migration versus rerunnable operation; validate preconditions and preserve drift detection.
2. Check table size, write traffic, operation rewrite/lock behavior, and runtime budget; choose batching or supported concurrent indexing where needed.
3. Verify backward compatibility: can the current app version still function after this DDL runs?
4. Test the selected recovery path against representative populated data; do not require a lossy down migration.
5. Run during low-traffic window if the operation takes locks (even brief ones).

**Destructive or production-changing operations** (production DDL, `DROP`/`TRUNCATE`, restores
using `--clean`, `--drop`, or a replaced data directory, failover, backend termination) follow
plan-validate-execute. Copy and track:

- [ ] Target confirmed: run the identity query on the exact connection you will use and show it
- [ ] Backup confirmed: a restorable backup of the target exists; record its ID or path
- [ ] Plan written: exact command, expected effect, lock/runtime estimate, recovery path (DDL: safety check done)
- [ ] Rehearsed: tool dry run (pt-osc `--dry-run`, gh-ost without `--execute`) or the operation on a non-prod copy; for restores, restore into a scratch instance (`pg_restore --list` only inspects archive contents and is not a rehearsal; see `references/backup-patterns.md` Backup Verification)
- [ ] Approved: the user explicitly approved that exact command text and target
- [ ] Executed unchanged: no added flags, no retargeting; then validate (Step 4)

Identity queries: PG `SELECT current_database(), inet_server_addr(), pg_is_in_recovery();`,
MySQL/MariaDB `SELECT @@hostname, DATABASE(), @@read_only;`, MSSQL `SELECT @@SERVERNAME, DB_NAME();`,
MongoDB `db.getName()` plus `db.hello().isWritablePrimary`.
