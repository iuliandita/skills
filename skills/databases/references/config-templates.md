# Database Configuration Templates

Copy-pasteable configuration templates for PostgreSQL, MongoDB, MySQL/MariaDB, and MSSQL. Three variants: dev (permissive, verbose logging), prod (hardened, tuned), and PCI-CDE (compliance-ready).

---

## PostgreSQL

### postgresql.conf (production)

```ini
# ============================================================
# PostgreSQL Production Configuration
# Target: PG 17-18, dedicated server, SSD storage
# Adjust RAM-proportional values to your actual system RAM
# ============================================================

# - Connection -
listen_addresses = '*'                    # bind to all interfaces (firewall + pg_hba.conf handles access)
port = 5432
max_connections = 200                     # tune based on pooler config; default 100 is low for prod
superuser_reserved_connections = 3

# - Memory -
shared_buffers = '4GB'                    # 25% of RAM (16GB system example)
effective_cache_size = '12GB'             # 75% of RAM - tells planner about OS page cache
work_mem = '64MB'                         # per-sort/hash operation, NOT per-connection. Lower for OLTP (many concurrent queries)
maintenance_work_mem = '1GB'              # VACUUM, CREATE INDEX, ALTER TABLE
huge_pages = try                          # use if OS supports (Linux: vm.nr_hugepages)

# - WAL & Durability -
wal_level = replica                       # or 'logical' for logical replication
max_wal_senders = 10
max_replication_slots = 10
wal_compression = zstd                    # PG 15+. Requires --with-zstd at compile time. Most distro packages include this.
checkpoint_completion_target = 0.9
min_wal_size = '1GB'
max_wal_size = '4GB'

# - Query Planner -
random_page_cost = 1.1                    # SSD storage. Default 4.0 assumes spinning disk.
effective_io_concurrency = 200            # SSD: 200. HDD: 2.
default_statistics_target = 200           # more accurate planner estimates (default 100)

# - Autovacuum -
autovacuum = on
autovacuum_max_workers = 4                # increase for many tables
autovacuum_vacuum_scale_factor = 0.05     # vacuum when 5% of rows are dead (default 0.2 is too lazy for large tables)
autovacuum_analyze_scale_factor = 0.02    # analyze when 2% of rows change
autovacuum_vacuum_cost_delay = '2ms'      # PG 12+: faster vacuum, less impact with SSD

# - Logging -
logging_collector = on
log_destination = 'stderr'
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_rotation_age = '1d'
log_rotation_size = '100MB'
log_min_duration_statement = 1000         # log queries slower than 1s
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0                        # log all temp file usage
log_line_prefix = '%m [%p] %q%u@%d '

# - Security -
ssl = on
ssl_min_protocol_version = 'TLSv1.3'     # TLSv1.2 minimum for PCI
password_encryption = scram-sha-256       # NEVER md5
ssl_cert_file = '/etc/postgresql/server.crt'
ssl_key_file = '/etc/postgresql/server.key'

# - Timeouts -
statement_timeout = '30s'                 # per-role override for migrations: ALTER ROLE migrator SET statement_timeout = '0';
lock_timeout = '10s'
idle_in_transaction_session_timeout = '60s'
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 6

# - Extensions -
shared_preload_libraries = 'pg_stat_statements,pgaudit'  # add pgaudit for PCI
pg_stat_statements.max = 10000
pg_stat_statements.track = all
```

### pg_hba.conf (production)

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer            # superuser via unix socket only
local   all             all                                     scram-sha-256

# Replication
hostssl replication     replicator      10.0.0.0/8              scram-sha-256

# Application connections (TLS required)
hostssl all             app_user        10.0.0.0/8              scram-sha-256
hostssl all             migration_user  10.0.0.0/8              scram-sha-256
hostssl all             readonly_user   10.0.0.0/8              scram-sha-256

# PgBouncer (if running on same host or trusted network)
hostssl all             pgbouncer       127.0.0.1/32            scram-sha-256

# DENY everything else (implicit, but explicit for clarity)
# host  all             all             0.0.0.0/0               reject
```

**Never use:**
- `trust` - allows passwordless access. Not even for local dev (muscle memory matters).
- `md5` - deprecated in PG 18, vulnerable to relay attacks. Use `scram-sha-256`.
- `host` (without ssl) for remote connections - unencrypted traffic.

### pg_hba.conf (PCI-CDE additions)

```
# CDE: certificate authentication for all database access
hostssl cde_db          all             10.100.0.0/16           cert            # client cert required
hostssl cde_db          all             0.0.0.0/0               reject          # deny all other access

# pgAudit: log everything on CDE database
# (set in postgresql.conf or per-database)
# ALTER DATABASE cde_db SET pgaudit.log = 'all';
```

### Role architecture

```sql
-- Application role: DML only (SELECT, INSERT, UPDATE, DELETE)
CREATE ROLE app_user LOGIN PASSWORD 'use_vault_not_this';
GRANT CONNECT ON DATABASE mydb TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
-- NO: CREATE, DROP, ALTER, TRUNCATE

-- Migration role: DDL (for schema changes only)
CREATE ROLE migration_user LOGIN PASSWORD 'use_vault_not_this';
GRANT CONNECT ON DATABASE mydb TO migration_user;
GRANT ALL ON SCHEMA public TO migration_user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO migration_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO migration_user;
-- Set longer statement timeout for migrations:
ALTER ROLE migration_user SET statement_timeout = '0';

-- Read-only role: analytics, support, dashboards
CREATE ROLE readonly_user LOGIN PASSWORD 'use_vault_not_this';
GRANT CONNECT ON DATABASE mydb TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;
```

### postgresql.conf (dev additions/overrides)

```ini
# Dev-specific overrides (relax timeouts, verbose logging)
log_min_duration_statement = 0            # log ALL queries
log_statement = 'all'                     # or 'ddl' for less noise
statement_timeout = '0'                   # no timeout in dev
max_connections = 50                      # dev doesn't need many
shared_buffers = '512MB'                  # smaller for dev machines
```

---

## MongoDB

### mongod.conf (production)

```yaml
# ============================================================
# MongoDB Production Configuration
# Target: MongoDB 8.0+, replica set, dedicated server
# ============================================================

storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 4                      # (RAM - 1GB) / 2 for dedicated server, set explicitly for shared
      journalCompressor: zstd
    collectionConfig:
      blockCompressor: zstd               # better compression than snappy (default)

systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
  logRotate: reopen                       # use logrotate with SIGUSR1

net:
  port: 27017
  bindIp: 0.0.0.0                         # all interfaces (firewall handles access)
  maxIncomingConnections: 65536
  tls:
    mode: requireTLS                      # NEVER 'disabled' or 'allowTLS' in production
    certificateKeyFile: /etc/mongodb/server.pem
    CAFile: /etc/mongodb/ca.pem
    allowConnectionsWithoutCertificates: false  # require client certs for PCI

security:
  authorization: enabled                  # NEVER run without auth
  keyFile: /etc/mongodb/keyfile           # inter-member auth for replica set
  # For PCI, consider x509 instead of keyFile:
  # clusterAuthMode: x509

replication:
  replSetName: rs0
  oplogSizeMB: 10240                      # 10GB oplog (increase for write-heavy workloads)

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100                  # log operations slower than 100ms
```

### mongod.conf (dev overrides)

```yaml
# Dev: relax security, increase logging
net:
  bindIp: 127.0.0.1                       # localhost only
  tls:
    mode: disabled                         # OK for local dev only

security:
  authorization: disabled                  # local dev only - build auth habits anyway

operationProfiling:
  mode: all                                # profile everything in dev
```

### Replica set initialization

```javascript
// Connect to primary candidate, then:
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo1:27017", priority: 2 },   // preferred primary
    { _id: 1, host: "mongo2:27017", priority: 1 },   // secondary
    { _id: 2, host: "mongo3:27017", priority: 1 }    // secondary
    // For homelab (2 servers): replace member 2 with an arbiter:
    // { _id: 2, host: "mongo3:27017", arbiterOnly: true }
    // But 3 data-bearing members is always preferred
  ]
});

// Verify:
rs.status();
rs.printReplicationInfo();     // oplog window
```

---

## MySQL / MariaDB

### my.cnf (production - MySQL 8.4 LTS)

```ini
[mysqld]
# ============================================================
# MySQL 8.4 LTS Production Configuration
# Target: dedicated server, InnoDB, SSD storage
# ============================================================

# - Core -
server-id = 1                             # unique per server in replication
port = 3306
bind-address = 0.0.0.0
datadir = /var/lib/mysql
socket = /var/run/mysqld/mysqld.sock

# - CRITICAL: Strict mode (prevents silent data corruption) -
sql_mode = STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION

# - Character set (utf8mb4, NOT utf8 which is 3-byte only) -
character-set-server = utf8mb4
collation-server = utf8mb4_0900_ai_ci

# - InnoDB -
innodb_buffer_pool_size = 11G             # 70% of RAM (16GB system example)
# innodb_buffer_pool_instances - MySQL 8.4 auto-tunes this based on pool size + CPU count. Omit to let it auto-tune, or set explicitly (1 per GB, max 64).
innodb_redo_log_capacity = 2G              # MySQL 8.0.30+. Replaces innodb_log_file_size (deprecated, silently ignored in 8.4)
innodb_flush_log_at_trx_commit = 1        # ACID durability. 2 = faster but 1s data loss risk
innodb_flush_method = O_DIRECT            # bypass OS cache (InnoDB has its own)
innodb_file_per_table = ON                # always
innodb_io_capacity = 2000                 # SSD: 2000-10000. HDD: 200
innodb_io_capacity_max = 4000
innodb_read_io_threads = 8
innodb_write_io_threads = 8
innodb_adaptive_hash_index = ON

# - Connections -
max_connections = 200
wait_timeout = 300                        # close idle connections after 5 min
interactive_timeout = 300
thread_cache_size = 32

# - Logging -
log_output = FILE
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1                       # queries slower than 1s
log_queries_not_using_indexes = ON        # catch missing indexes
general_log = OFF                         # enable temporarily for debugging only
log_error = /var/log/mysql/error.log
log_error_verbosity = 2

# - Binary log (required for replication and PITR) -
log_bin = mysql-bin
binlog_format = ROW                       # required for GTID and safer than STATEMENT
binlog_expire_logs_seconds = 604800       # 7 days retention
gtid_mode = ON
enforce_gtid_consistency = ON
sync_binlog = 1                           # flush binlog at each commit (durability)

# - Security -
require_secure_transport = ON
tls_version = TLSv1.2,TLSv1.3
ssl_cert = /etc/mysql/server-cert.pem
ssl_key = /etc/mysql/server-key.pem
ssl_ca = /etc/mysql/ca-cert.pem
# default_authentication_plugin was REMOVED in MySQL 8.4 - caching_sha2_password is the hardcoded default.
# For older versions: default_authentication_plugin = caching_sha2_password

# - Performance Schema -
performance_schema = ON
```

### my.cnf (MariaDB 11.8 LTS differences)

```ini
# MariaDB-specific settings (in addition to / instead of MySQL settings above)
[mariadb]
# No gtid_mode / enforce_gtid_consistency - MariaDB uses domain-based GTID automatically
# No caching_sha2_password - MariaDB uses ed25519 or mysql_native_password
# plugin_load_add = server_audit          # MariaDB Audit Plugin (free, unlike MySQL Enterprise)

# MariaDB collation (uca1400 is the modern standard)
collation-server = utf8mb4_uca1400_ai_ci

# InnoDB encryption (MariaDB has free TDE, MySQL requires Enterprise)
innodb_encrypt_tables = ON
innodb_encrypt_log = ON
innodb_encryption_threads = 4
plugin_load_add = file_key_management     # or AWS/Vault key management plugin
file_key_management_filename = /etc/mysql/encryption/keyfile
```

### my.cnf (dev overrides)

```ini
[mysqld]
max_connections = 50
innodb_buffer_pool_size = 512M
slow_query_log = ON
long_query_time = 0                       # log ALL queries
general_log = ON                          # enable for debugging (disable in prod - huge I/O)
require_secure_transport = OFF            # local dev only
```

---

## MSSQL

### Key settings (T-SQL)

MSSQL doesn't use a config file like the others. Most settings are applied via T-SQL or SQL Server Configuration Manager.

```sql
-- ============================================================
-- SQL Server 2022-2025 Production Configuration
-- Run via sqlcmd or SSMS
-- ============================================================

-- Max memory (leave 4-8GB for OS)
EXEC sp_configure 'max server memory (MB)', 12288;  - 12GB on a 16GB server
RECONFIGURE;

-- MAXDOP (CPU cores per NUMA node, max 8 for OLTP)
EXEC sp_configure 'max degree of parallelism', 4;
RECONFIGURE;

-- Cost threshold for parallelism (default 5 is way too low for OLTP)
EXEC sp_configure 'cost threshold for parallelism', 50;
RECONFIGURE;

-- Enable Query Store on production databases
ALTER DATABASE [mydb] SET QUERY_STORE = ON;
ALTER DATABASE [mydb] SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,
    MAX_STORAGE_SIZE_MB = 1024,
    INTERVAL_LENGTH_MINUTES = 30
);

-- TempDB: 1 file per CPU core (up to 8), equal size
-- Check current:
SELECT name, physical_name, size * 8 / 1024 AS size_mb
FROM sys.master_files WHERE database_id = 2;
-- Add files via ALTER DATABASE [tempdb] ADD FILE (...)

-- Recovery model (FULL for production, enables PITR)
ALTER DATABASE [mydb] SET RECOVERY FULL;

-- Force encryption (via SQL Server Configuration Manager, not T-SQL)
-- Or connection string: Encrypt=True;TrustServerCertificate=False

-- Enable TDE for CDE databases
-- Step 1: Create master key and certificate in master (do this ONCE per server)
USE master;
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'use_vault_not_this';
CREATE CERTIFICATE TDECert WITH SUBJECT = 'TDE Certificate';
-- IMMEDIATELY back up the cert (losing it = permanent data loss on restore)
-- BACKUP CERTIFICATE TDECert TO FILE = '/secure/TDECert.cer'
--     WITH PRIVATE KEY (FILE = '/secure/TDECert.pvk',
--                       ENCRYPTION BY PASSWORD = 'use_vault_not_this');

-- Step 2: Create DEK in the target database
USE cde_db;
CREATE DATABASE ENCRYPTION KEY
    WITH ALGORITHM = AES_256
    ENCRYPTION BY SERVER CERTIFICATE TDECert;
ALTER DATABASE cde_db SET ENCRYPTION ON;

-- Audit (SQL Server Audit)
CREATE SERVER AUDIT [ProdAudit]
    TO FILE (FILEPATH = '/var/opt/mssql/audit/', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 10)
    WITH (QUEUE_DELAY = 1000);
ALTER SERVER AUDIT [ProdAudit] WITH (STATE = ON);

CREATE DATABASE AUDIT SPECIFICATION [CDE_DML_Audit]
    FOR SERVER AUDIT [ProdAudit]
    ADD (SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[dbo] BY [public])
    WITH (STATE = ON);
```

---

## PgBouncer

### pgbouncer.ini (production)

```ini
[databases]
mydb = host=127.0.0.1 port=5432 dbname=mydb

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Pool mode
pool_mode = transaction                   # default for web apps

# Pool sizing
max_client_conn = 1000                    # max connections from apps
default_pool_size = 20                    # backend connections per user/db pair
reserve_pool_size = 5                     # extra for burst
min_pool_size = 5                         # pre-warm this many connections

# Timeouts
server_idle_timeout = 300                 # reclaim idle backend connections after 5 min
query_wait_timeout = 120                  # fail fast if pool is exhausted
client_idle_timeout = 0                   # let the app manage its own idle timeout
server_connect_timeout = 15
server_login_retry = 15

# Prepared statements (PgBouncer 1.21+)
max_prepared_statements = 100             # fixes prepared stmt + transaction mode incompatibility

# TLS (client-facing)
client_tls_sslmode = require              # 'require' = encrypted channel only. For mutual TLS (PCI-CDE), use 'verify-ca' or 'verify-full' + client_tls_ca_file
client_tls_key_file = /etc/pgbouncer/server.key
client_tls_cert_file = /etc/pgbouncer/server.crt
# client_tls_ca_file = /etc/pgbouncer/client-ca.crt  # uncomment for mutual TLS (client cert verification)

# TLS (to PostgreSQL)
server_tls_sslmode = verify-full
server_tls_ca_file = /etc/pgbouncer/ca.crt

# Admin
admin_users = pgbouncer_admin
stats_users = pgbouncer_stats

# Logging
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
```
