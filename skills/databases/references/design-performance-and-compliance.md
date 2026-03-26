# Design, Performance, and Compliance

This reference covers the cross-engine design and operational decisions that were too large for the
main skill body.

## Schema design

Core patterns:

- composite indexes: equality, then sort, then range
- partition only when query shape, retention, or tenant isolation justify it
- choose multi-tenant layout deliberately, not by default convenience
- choose types for correctness first, not habit

Common examples:

- PostgreSQL: `timestamptz`, explicit FK indexes, partial or expression indexes where appropriate
- MySQL: `utf8mb4`, avoid weak temporal defaults, avoid `ENUM` unless you really want schema-coupled values
- MongoDB: embed vs reference based on lifecycle and cardinality, avoid unbounded arrays
- MSSQL: `DATETIME2`, `NVARCHAR`, `DECIMAL`

## Migration

Expand-contract is the safe default for production schema changes:

1. expand
2. backfill
3. contract

For cross-engine moves, keep the detailed type-mapping and tool comparison in
`references/migration-patterns.md`.

## Performance

Performance work starts with plans and metrics, not folklore.

- PostgreSQL: `EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_activity`, `pg_stat_statements`
- MySQL: `EXPLAIN FORMAT=TREE`, processlist, performance schema
- MongoDB: `explain("executionStats")`, `db.currentOp()`, `mongostat`, `mongotop`

Look for:

- full scans where index access should exist
- row estimates that diverge badly from reality
- idle-in-transaction behavior
- lock waits and deadlocks
- cache pressure and memory pressure

## Backup and recovery

The boring rules still apply:

- test restores
- encrypt backups
- monitor freshness
- document the restore path
- keep retention tied to policy, especially for regulated data

## Compliance

PCI-DSS 4.0 matters most in these areas:

- encryption at rest beyond simple disk encryption
- encryption in transit
- audit logging to immutable sinks
- role separation and MFA for privileged access
- masking and non-prod sanitization

Treat provider attestations as input, not as proof that your implementation is compliant.

## AI-age concerns

Database-specific AI failure patterns:

- string-built SQL
- missing idempotence in migrations
- wrong default types
- bad locking assumptions
- casual recommendations of destructive maintenance commands

For vector data, assume embeddings can still expose sensitive source information. Apply access,
logging, and encryption controls accordingly.

## Managed vs self-hosted

Managed lowers toil.
Self-hosted increases control.

The decision usually comes down to:

- operational headcount
- customization needs
- compliance boundaries
- scale economics

If self-hosting on Kubernetes, prefer an operator over hand-rolled StatefulSet cargo culting.
