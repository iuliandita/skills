# Engine Operations

This reference keeps the per-engine operational guidance out of the main skill body.

## PostgreSQL

Core stance:

- SCRAM only, never `trust` or legacy auth where it can be avoided
- `hostssl` for remote access
- pool aggressively once connection counts grow
- keep autovacuum on and tune it, do not casually reach for `VACUUM FULL`

Operational areas to care about:

- WAL and logical replication
- `pg_stat_statements`
- `pgAudit`
- `pg_repack`
- index and table bloat

PG gotchas that still matter:

- DDL is not replicated by logical replication
- foreign keys are not auto-indexed
- `timestamptz` and identity columns are the sane defaults

## MongoDB

Core stance:

- auth and TLS enabled in production
- schema validation still matters even on a schemaless engine
- replica-set sizing and oplog sizing need explicit thought

Operational areas:

- replica-set health
- write concern and read preference
- unbounded array avoidance
- careful shard-key decisions if sharding enters the picture

## MySQL and MariaDB

Core stance:

- strict mode on
- `utf8mb4` always
- explicit transport encryption
- know whether you are on MySQL or MariaDB before prescribing features

Operational areas:

- GTID-based replication or cluster choice
- buffer pool sizing
- redo or log sizing
- ProxySQL where middleware pooling and routing are needed

## MSSQL

Core stance:

- set memory explicitly
- size TempDB deliberately
- enable Query Store
- use `DATETIME2`, `NVARCHAR`, and `SCOPE_IDENTITY()`

Operational areas:

- recovery model choice
- backup chain validation
- maintenance scripts
- parallelism settings

## Security and CVE posture

Per-engine CVEs age quickly. The main skill should keep only the highest-signal version anchors.
When the issue is engine security or patch urgency:

1. confirm the exact engine and branch
2. confirm the exact build version
3. check current CVEs and provider patch status

This is especially important for:

- PostgreSQL tooling around restore and poolers
- MongoDB wire-protocol and compression bugs
- MariaDB and MySQL parser or JSON-function bugs
- MSSQL privilege-escalation or managed-service patch lag
