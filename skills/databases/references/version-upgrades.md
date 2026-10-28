# PostgreSQL Major Version Upgrades

Choosing an upgrade method, running a zero-downtime logical-replication upgrade, rolling back, and the pitfalls to check before starting.

---

Three approaches, pick by downtime tolerance:

| Method | Downtime | Best for |
|--------|----------|----------|
| `pg_upgrade --link` | Minutes (metadata copy) | Small-to-medium DBs where brief downtime is acceptable |
| Logical replication | Seconds (cutover only) | Large DBs, zero-downtime requirement, PG 10+ to any higher |
| `pg_dump` / `pg_restore` | Hours (full copy) | Cross-engine, major schema changes, or when logical replication is impractical |

**Zero-downtime with logical replication** (PG -> PG):
1. Confirm the source runs `wal_level = logical` (`SHOW wal_level;`). It can only be set at server start, so a source still on `replica` needs a restart scheduled before the migration window. Also confirm free `max_replication_slots`/`max_wal_senders` and a `pg_hba.conf` rule for the subscriber's role (logical replication connects to the database itself, not the `replication` pseudo-database), then stand up the new version instance alongside the primary
2. Create publication on source: `CREATE PUBLICATION upgrade_pub FOR ALL TABLES;`
3. Create subscription on target, pointing at the source/publisher: `CREATE SUBSCRIPTION upgrade_sub CONNECTION 'host=source-db.internal dbname=app user=repl' PUBLICATION upgrade_pub;` - omit `password=` so libpq reads the subscriber's mode-0600 `~/.pgpass`; an inline password is stored in `pg_subscription` and appears in catalog dumps and logs
4. Wait for initial sync + catchup (monitor `pg_stat_subscription`, replication lag)
5. Inventory sequences and prepare their synchronization; logical replication does not copy their values
6. Test application against the new version (read traffic, connection pooler split). **Monitor during split-test**: query latency p50/p95/p99 (compare old vs new - regression means planner stats or config drift), error rates by query type (new version may have stricter behavior), connection pool saturation (`SHOW POOLS` in PgBouncer - watch `cl_waiting`), replication lag trend (should stay flat or decrease, never grow during read-only test), and memory/CPU on the new instance. Run for at least one full traffic cycle (24h if your workload is diurnal). Abort and route back to old primary if error rate exceeds baseline or p99 latency degrades >20%.
7. Cutover: fence source writes and drain transactions, verify target replay reached the final source WAL position, synchronize final sequence values, then route writes to the target
8. Verify application health and retain the source for the agreed rollback window; decommission only after that window and explicit authorization

**Rollback procedure** (if replication stalls or validation fails):
- **Lag not reaching zero**: Check `pg_stat_subscription` for `last_msg_send_time` vs `last_msg_receipt_time` delta. Common causes: long-running transactions on source blocking WAL send, tables missing primary keys (forces full-row comparison), or network throughput limits. If lag is stuck, check `pg_replication_slots` on the source for `active = false` - an inactive slot means no current receiver is using it, not proof of a dropped subscription. Inspect target subscription/workers and logs; do not recreate it blindly or proceed with cutover.
- **Application validation fails on new version**: Route all traffic back to the old primary (update pooler config). The old primary never stopped accepting writes, so no data is lost. Drop the subscription on the new instance: `DROP SUBSCRIPTION upgrade_sub;` - this also drops the replication slot on the source. Investigate, fix, and restart from step 3.
- **Post-cutover rollback** (writes already went to new primary): This is the hard case. Options: (a) set up reverse logical replication from new -> old before decommissioning the old primary (plan this before cutover if RTO requires it), or (b) restore old primary from backup + WAL and accept data loss for the cutover window. Option (a) requires the old primary to still be running. **Decision point**: if you need rollback after cutover, test a reverse-replication/failback plan in step 6 before routing write traffic; prevent loops and never permit concurrent independent writers.

**Key pitfalls** (check all of these before starting):
- Tables need primary keys or `REPLICA IDENTITY FULL` - check first: `SELECT c.relname FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = c.oid AND contype = 'p');`
- DDL is not replicated - schema changes during migration need manual sync on both sides
- Large objects (`lo`) are not replicated
- Sequence values drift - copy final values after source write fencing/drain and before any target writes
- A lagging or inactive slot pins WAL on the source - watch `pg_replication_slots.wal_status` and free disk, and set `max_slot_wal_keep_size` deliberately (the default keeps WAL without bound and can fill the source volume; a bounded value invalidates the slot instead and forces a resync)
