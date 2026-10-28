# Database Production Checklist: Engine-Specific and Compliance

Engine-specific production checks for PostgreSQL, MySQL/MariaDB, MongoDB, and MSSQL, plus PCI-DSS 4.0 database compliance. Apply these on top of the All Engines checklist in SKILL.md.

---

## PostgreSQL-Specific

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

## MySQL/MariaDB-Specific

- [ ] `sql_mode` includes `STRICT_TRANS_TABLES` (prevents silent data truncation)
- [ ] `innodb_buffer_pool_size` = 70% RAM
- [ ] `innodb_flush_log_at_trx_commit = 1` for durability
- [ ] `require_secure_transport = ON`
- [ ] `character-set-server = utf8mb4`
- [ ] Binary log enabled for PITR (`log_bin = ON`)
- [ ] `innodb_file_per_table = ON`
- [ ] MariaDB patched against CVE-2026-32710 (JSON_SCHEMA_VALID crash/RCE) - 11.8.6+ / 11.4.10+

## MongoDB-Specific

- [ ] `security.authorization: enabled` (never run without auth)
- [ ] Replica set with 3+ members (not standalone in production)
- [ ] Write concern `w: "majority"` (implicit default since 5.0; arbiter topologies can fall back to `w: 1`, so set it explicitly)
- [ ] Schema validation (`$jsonSchema`) on critical collections
- [ ] Patched against MongoBleed (CVE-2025-14847) - 8.0.17+ / 7.0.28+ / 6.0.27+
- [ ] Patched against CVE-2026-89099 - 8.0.32+ ([release notes](https://www.mongodb.com/docs/v8.0/release-notes/8.0/))
- [ ] Patched against CVE-2026-25611 (pre-auth DoS via compression) - 8.0.18+ / 8.2.4+ / 7.0.29+
- [ ] On the June 11, 2026 MongoDB security release (CVE-2026-11933) - 8.0.26+
- [ ] TLS enabled (`net.tls.mode: requireTLS`)

## MSSQL-Specific

- [ ] `Max Server Memory` set explicitly (not unlimited)
- [ ] `MAXDOP` per Microsoft guidance: <= logical processors per (soft-)NUMA node, capped at 8 on single-NUMA servers; multi-NUMA with >16 LPs/node uses half the LPs per node, max 16
- [ ] `Cost Threshold for Parallelism` raised from default 5
- [ ] TempDB files = min(CPU cores, 8), equal size
- [ ] Query Store enabled
- [ ] Recovery model = FULL for production databases
- [ ] TDE enabled for CDE databases
- [ ] Patched against CVE-2026-21262 (privilege escalation) - March 2026 CU+

## Compliance (PCI-DSS 4.0)

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
