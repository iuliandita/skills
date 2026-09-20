# Redis and Valkey Operations

Use this reference when Redis or Valkey is a durable data store, cache, stream, or session store.
They are similar protocol families, but verify commands and configuration against the chosen engine;
do not treat version compatibility as automatic.

## Classify the data first

| Role | Required posture |
|---|---|
| Rebuildable cache | Set `maxmemory` and an eviction policy that matches the miss/rebuild path. Monitor evictions and hit rate. |
| Session, rate-limit, or coordination state | Define loss and failover behavior; expiration must be intentional and observable. |
| Durable primary data | Choose RDB/AOF and replication from an explicit RPO/RTO, test restore and failover, and keep an authoritative recovery path. |
| Stream or queue | Define consumer-group acknowledgement, pending-entry recovery, retention, duplicate handling, and replay; use **message-queues** for cross-broker delivery semantics. |

## Safe operational checks

- Inspect `INFO memory`, `INFO replication`, persistence status, slow-log evidence, command latency,
  connected clients, cache hit/miss, evictions, expired keys, and replica lag before changing state.
- Size memory below host capacity. Replication and AOF buffers are not counted toward eviction in
  Valkey; monitor `mem_not_counted_for_evict` and leave headroom.
- Treat `noeviction` as a deliberate correctness choice for data that may not disappear. For caches,
  select an eviction policy that matches the key/TTL model and ensure a miss can rebuild safely.
- RDB is a point-in-time snapshot; AOF replays writes. State the tolerated loss window, verify
  backups by restore, and account for fork/copy-on-write memory and latency during persistence.
- Replication improves availability but is asynchronous. Avoid writable replicas; configure a
  minimum-replica policy only when its rejected-write behavior fits the application.
- Keep command complexity bounded. Identify large keys and expensive operations from evidence; do not
  use broad production scans or blocking operations as a first diagnostic step.

## Safeguards

- Require authentication, TLS, network restriction, and least-privilege ACLs where the engine supports them.
- Never run `FLUSHALL`, `FLUSHDB`, broad key deletion, `CONFIG SET`, failover, or topology changes
  while diagnosing. Present the exact target, expected data effect, recovery plan, and request approval.
- Preserve key prefixes and TTL semantics during migration or replay. A cache key collision can become
  a data-isolation incident.

## Primary documentation

- [Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)
- [Redis key eviction](https://redis.io/docs/latest/develop/reference/eviction/)
- [Valkey persistence](https://valkey.io/topics/persistence/)
- [Valkey replication](https://valkey.io/topics/replication/)
- [Valkey key eviction](https://valkey.io/topics/lru-cache/)
