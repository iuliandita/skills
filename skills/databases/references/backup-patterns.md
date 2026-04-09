# Database Backup Patterns

Copy-pasteable backup strategies, PITR setup, retention policies, encryption, verification procedures, and monitoring for PostgreSQL, MongoDB, MySQL/MariaDB, and MSSQL.

---

## The 3-2-1 Rule

Every backup strategy starts here:

- **3** copies of data (production + 2 backups)
- **2** different storage media (local disk + object storage, or disk + tape)
- **1** offsite copy (different datacenter, cloud region, or physical location)

PCI-DSS 4.0 adds: backups must be encrypted, access-logged, and tested quarterly.

For real: if your backups are on the same disk array as production, you don't have backups. You have a second copy of something that dies when the storage dies.

---

## Cross-Engine Backup Strategy Decision Matrix

| Factor | pg_dump / mongodump / mysqldump | pg_basebackup / Physical | WAL/Oplog/Binlog PITR |
|---|---|---|---|
| Backup speed | Slow (reads all data via SQL/protocol) | Fast (copies data files) | Continuous (streams changes) |
| Restore speed | Slow (replays SQL/inserts) | Fast (copy files back) | Fast base + replay to point |
| DB size sweet spot | < 100 GB | Any size | Any size |
| PITR capable | No (snapshot only) | Yes (with WAL archiving) | Yes (the whole point) |
| Cross-version restore | Yes | No (same major version) | No (same major version) |
| Cross-engine migration | Yes (with conversion) | No | No |
| Partial restore | Yes (single table/collection) | No (all-or-nothing) | No |
| Impact on production | Moderate (shared_buffers churn, locks) | Low (streams files) | Minimal (copies WAL/oplog) |
| Complexity | Low | Medium | High |
| **Recommendation** | Dev, small DBs, schema-only, migration | Prod base backups | Prod PITR (combine with physical base) |

**Rule of thumb**: logical for portability, physical + PITR for production disaster recovery. Use both.

---

## PostgreSQL 18

### Logical vs Physical

| | Logical (pg_dump/pg_dumpall) | Physical (pg_basebackup + WAL) |
|---|---|---|
| Tool | `pg_dump`, `pg_dumpall` | `pg_basebackup` + WAL archiving |
| Output | SQL or custom format (.dump) | Binary data directory copy |
| PITR | No | Yes |
| Granularity | Per-database, per-table | Entire cluster |
| Cross-major-version | Yes | No |
| Restore time (100GB) | Hours | Minutes |

### Logical Backup

```bash
#!/usr/bin/env bash
set -euo pipefail

# pg_dump - single database, directory format (compressed, parallel dump + restore)
pg_dump \
  --host=localhost \
  --port=5432 \
  --username=backup_user \
  --dbname=mydb \
  --format=directory \
  --compress=zstd:6 \
  --jobs=4 \
  --verbose \
  --file="/backup/mydb_$(date +%Y%m%d_%H%M%S)"

# For single-file backups (no parallel dump, but supports parallel restore):
# pg_dump --format=custom --compress=zstd:6 --file=mydb.dump mydb

# pg_dumpall - all databases + globals (roles, tablespaces)
# Always take a globals-only dump alongside per-db dumps
pg_dumpall \
  --host=localhost \
  --port=5432 \
  --username=postgres \
  --globals-only \
  --file="/backup/globals_$(date +%Y%m%d_%H%M%S).sql"
```

**Recommended flags:**
- `--format=directory` - compressed, supports parallel dump AND restore, selective restore
- `--format=custom` - single compressed file, supports parallel restore (NOT parallel dump), selective restore
- `--compress=zstd:6` - PG 16+ native zstd (faster than gzip, better ratio)
- `--jobs=4` - parallel dump/restore (directory format ONLY - incompatible with custom format for dump)
- `--no-owner` - if restoring to a different role setup
- `--no-privileges` - skip GRANT/REVOKE (useful for dev restores)
- `--exclude-table-data='audit_log'` - skip large, non-critical tables

**Never use `--format=plain` for production backups** - no compression, no parallel restore, no selective restore. Plain SQL is only useful for migration or human reading.

### Restore from Logical Backup

```bash
#!/usr/bin/env bash
set -euo pipefail

# Restore globals first (roles must exist before database restore)
psql --host=localhost --username=postgres --file=globals.sql

# Restore database (parallel)
pg_restore \
  --host=localhost \
  --port=5432 \
  --username=postgres \
  --dbname=mydb \
  --jobs=4 \
  --verbose \
  --clean \
  --if-exists \
  "/backup/mydb_20260324_020000.dump"

# Single table restore from custom dump
pg_restore \
  --host=localhost \
  --username=postgres \
  --dbname=mydb \
  --table=orders \
  --data-only \
  "/backup/mydb_20260324_020000.dump"
```

### Physical Backup (pg_basebackup)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Full base backup with WAL streaming
pg_basebackup \
  --host=localhost \
  --port=5432 \
  --username=replicator \
  --pgdata=/backup/base/$(date +%Y%m%d_%H%M%S) \
  --format=tar \
  --compress=server-zstd:6 \
  --wal-method=stream \
  --checkpoint=fast \
  --progress \
  --verbose
```

**Required postgresql.conf for physical backups:**
```ini
wal_level = replica            # minimum for physical backup
max_wal_senders = 10           # at least 1 for pg_basebackup + 1 per replica
```

### PITR Setup

PITR = base backup + continuous WAL archiving. When disaster strikes, restore the base backup then replay WAL to any point in time.

**Step 1: Configure WAL archiving (postgresql.conf)**

```ini
archive_mode = on
archive_command = 'test ! -f /archive/%f && cp %p /archive/%f'
# Or with compression:
# archive_command = 'zstd -q %p -o /archive/%f.zst'
# Or to S3:
# archive_command = 'aws s3 cp %p s3://pg-wal-archive/%f --sse AES256'
archive_timeout = 300          # force WAL switch every 5 min (limits max data loss)
```

**Step 2: Take base backup** (see pg_basebackup above)

**Step 3: Restore to point in time**

```bash
#!/usr/bin/env bash
set -euo pipefail

RESTORE_DIR="/restore/pgdata"
BASE_BACKUP="/backup/base/20260324_020000"

# Extract base backup
mkdir -p "$RESTORE_DIR"
tar xzf "$BASE_BACKUP/base.tar.gz" -C "$RESTORE_DIR"
tar xzf "$BASE_BACKUP/pg_wal.tar.gz" -C "$RESTORE_DIR/pg_wal"

# Create recovery signal and config
touch "$RESTORE_DIR/recovery.signal"
cat >> "$RESTORE_DIR/postgresql.conf" <<'CONF'
restore_command = 'cp /archive/%f %p'
# Or from S3: restore_command = 'aws s3 cp s3://pg-wal-archive/%f %p'
recovery_target_time = '2026-03-24 14:30:00+00'
recovery_target_action = 'promote'
CONF

# Start PostgreSQL with restored data
pg_ctl -D "$RESTORE_DIR" start
```

**Recovery target options** (pick one):
- `recovery_target_time = '2026-03-24 14:30:00+00'` - restore to timestamp
- `recovery_target_lsn = '0/1A2B3C4D'` - restore to WAL position
- `recovery_target_xid = '12345'` - restore to transaction ID
- `recovery_target = 'immediate'` - stop at end of base backup (consistent state)

### pgBackRest (Production-Grade Alternative)

pgBackRest is what you should actually use in production. pg_basebackup works but pgBackRest adds incremental/differential backups, parallel backup/restore, encryption, S3/Azure/GCS native support, and backup verification.

```ini
# /etc/pgbackrest/pgbackrest.conf
[global]
repo1-type=s3
repo1-s3-bucket=pg-backups
repo1-s3-region=eu-central-1
repo1-s3-endpoint=s3.eu-central-1.amazonaws.com
repo1-cipher-type=aes-256-cbc
repo1-cipher-pass=CHANGE_ME_USE_VAULT
repo1-retention-full=4
repo1-retention-diff=14
compress-type=zst
compress-level=6
process-max=4

[mydb]
pg1-path=/var/lib/postgresql/18/main
```

```bash
# Full backup
pgbackrest --stanza=mydb backup --type=full

# Differential (changes since last full)
pgbackrest --stanza=mydb backup --type=diff

# Incremental (changes since last backup of any type)
pgbackrest --stanza=mydb backup --type=incr

# PITR restore
pgbackrest --stanza=mydb restore \
  --type=time \
  --target="2026-03-24 14:30:00+00" \
  --target-action=promote

# Verify backup integrity (PG 14+)
pgbackrest --stanza=mydb verify
```

### Backup Verification

**Backups that haven't been restored are not backups. They're hopes.**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Automated restore verification script
# Run weekly on a dedicated verification server

BACKUP_FILE="$1"
VERIFY_PORT=5433
VERIFY_DIR="/tmp/pg_verify_$$"

cleanup() { pg_ctl -D "$VERIFY_DIR" stop -m immediate 2>/dev/null; rm -rf "$VERIFY_DIR"; }
trap cleanup EXIT

# Initialize and start a temporary PG instance
initdb -D "$VERIFY_DIR" --username=postgres --no-locale --encoding=UTF8
pg_ctl -D "$VERIFY_DIR" -o "-p $VERIFY_PORT" -l "$VERIFY_DIR/pg.log" start
sleep 2

# Create target database
psql -p "$VERIFY_PORT" -U postgres -c "CREATE DATABASE mydb;"

# Restore
pg_restore \
  --dbname=mydb \
  --host=localhost \
  --port="$VERIFY_PORT" \
  --username=postgres \
  --jobs=4 \
  --no-owner \
  "$BACKUP_FILE"

# Basic verification queries
psql -p "$VERIFY_PORT" -U postgres -d mydb -c "SELECT count(*) FROM orders;" || exit 1
psql -p "$VERIFY_PORT" -U postgres -d mydb -c "SELECT max(created_at) FROM orders;" || exit 1

echo "Backup verification passed: $BACKUP_FILE"
```

For pgBackRest, use the built-in verify command:
```bash
pgbackrest --stanza=mydb verify
```

### Backup Encryption

```bash
# pg_dump + GPG encryption
pg_dump --format=custom --compress=zstd:6 mydb \
  | gpg --encrypt --recipient backup@company.com \
  > "/backup/mydb_$(date +%Y%m%d).dump.gpg"

# Decrypt and restore
gpg --decrypt /backup/mydb_20260324.dump.gpg \
  | pg_restore --dbname=mydb --jobs=4

# pgBackRest handles encryption natively (see config above)
# repo1-cipher-type=aes-256-cbc
# repo1-cipher-pass managed via vault/env
```

### Common Gotchas

- `pg_dump` takes `ACCESS SHARE` locks - it won't block writes, but long-running dumps on busy tables can cause autovacuum to stall.
- `pg_dumpall` uses plain format only. Always dump globals separately and per-database with custom format.
- `pg_basebackup` requires `replication` privilege in `pg_hba.conf` and `wal_level = replica`.
- Forgetting `archive_timeout` means quiet databases can have WAL gaps of hours (max data loss window).
- Restoring a `pg_dump` into an existing database without `--clean` causes duplicate key errors.
- `--jobs` on `pg_restore` requires the backup to be in custom or directory format. Plain SQL format is single-threaded.
- PG major version upgrades require `pg_dump`/`pg_restore` or `pg_upgrade`. Physical backups are NOT cross-version.

---

## MongoDB 8.0

### Logical vs Physical

| | Logical (mongodump) | Physical (filesystem snapshot) |
|---|---|---|
| Tool | `mongodump` / `mongorestore` | LVM/ZFS/EBS snapshot |
| Output | BSON files per collection | Raw data directory |
| PITR | No (snapshot only) | Yes (with oplog tailing) |
| Granularity | Per-database, per-collection | Entire instance |
| Oplog capture | Optional `--oplog` flag | Requires oplog replay |

### Logical Backup

```bash
#!/usr/bin/env bash
set -euo pipefail

# Full dump with oplog capture (replica set only)
mongodump \
  --uri="mongodb://backup_user:password@mongo1:27017,mongo2:27017,mongo3:27017/mydb?replicaSet=rs0&authSource=admin" \
  --oplog \
  --gzip \
  --out="/backup/mongodump_$(date +%Y%m%d_%H%M%S)"

# Single collection dump
mongodump \
  --uri="mongodb://backup_user:password@mongo1:27017/mydb?authSource=admin" \
  --db=mydb \
  --collection=orders \
  --gzip \
  --out="/backup/orders_$(date +%Y%m%d_%H%M%S)"

# Dump with query filter (partial backup)
mongodump \
  --uri="mongodb://backup_user:password@mongo1:27017/mydb?authSource=admin" \
  --db=mydb \
  --collection=orders \
  --query='{"created_at": {"$gte": {"$date": "2026-01-01T00:00:00Z"}}}' \
  --gzip \
  --out="/backup/orders_2026_$(date +%Y%m%d).dump"
```

**Recommended flags:**
- `--oplog` - captures a consistent snapshot even during writes (replica set only)
- `--gzip` - inline compression
- `--readPreference=secondary` - read from secondary to reduce primary load
- `--numParallelCollections=4` - parallel collection dumps (default 4)

### Restore

```bash
#!/usr/bin/env bash
set -euo pipefail

# Full restore with oplog replay
mongorestore \
  --uri="mongodb://admin:password@mongo1:27017/?authSource=admin" \
  --oplogReplay \
  --gzip \
  --drop \
  "/backup/mongodump_20260324_020000"

# Single collection restore
mongorestore \
  --uri="mongodb://admin:password@mongo1:27017/?authSource=admin" \
  --db=mydb \
  --collection=orders \
  --gzip \
  --drop \
  "/backup/orders_20260324/mydb/orders.bson.gz"
```

### PITR Setup

MongoDB PITR requires oplog-based continuous backup. Three approaches:

**Option 1: MongoDB Ops Manager / Atlas (managed)**
- Atlas has built-in continuous backup with PITR. Just enable it.
- Ops Manager does the same for self-hosted.

**Option 2: Manual oplog tailing**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Capture oplog continuously (run as a service)
# Start from a known timestamp (from your last full backup)
mongodump \
  --uri="mongodb://backup_user:password@mongo1:27017/local?authSource=admin" \
  --collection=oplog.rs \
  --query='{"ts": {"$gt": {"$timestamp": {"t": 1711324800, "i": 1}}}}' \
  --gzip \
  --out="/archive/oplog_$(date +%Y%m%d_%H%M%S)"
```

**Option 3: Percona Backup for MongoDB (pbm)**

```bash
# Configure PBM (production-recommended for self-hosted)
pbm config --set storage.type=s3
pbm config --set storage.s3.bucket=mongo-backups
pbm config --set storage.s3.region=eu-central-1
pbm config --set pitr.enabled=true
pbm config --set pitr.oplogSpanMin=10

# Take base backup
pbm backup --type=logical --compression=zstd

# PITR restore
pbm restore --time="2026-03-24T14:30:00Z"

# List backups
pbm list
```

### Backup Verification

```bash
#!/usr/bin/env bash
set -euo pipefail

# Restore to a separate instance and verify
mongorestore \
  --uri="mongodb://admin:password@verify-host:27017/?authSource=admin" \
  --oplogReplay \
  --gzip \
  --drop \
  "/backup/mongodump_20260324_020000"

# Verify document counts match
mongosh --eval '
  const source = connect("mongodb://mongo1:27017/mydb");
  const verify = connect("mongodb://verify-host:27017/mydb");
  const collections = source.getCollectionNames();
  for (const c of collections) {
    const srcCount = source.getCollection(c).countDocuments();
    const dstCount = verify.getCollection(c).countDocuments();
    if (srcCount !== dstCount) {
      print(`MISMATCH: ${c} source=${srcCount} verify=${dstCount}`);
      quit(1);
    }
  }
  print("All collection counts match");
'
```

### Common Gotchas

- `mongodump` without `--oplog` is NOT consistent during writes on replica sets. Always use `--oplog` in production.
- `--oplog` only works against the entire instance, not per-database/collection dumps.
- Large collections (>100GB) make `mongodump` impractical. Use filesystem snapshots or Percona Backup.
- The oplog is a capped collection - if it rolls over before your next backup, you lose your PITR window. Size the oplog for at least 48 hours of changes.
- `mongorestore --drop` drops and recreates collections - **this destroys data in the target**. Triple-check your connection string.
- MongoDB 8.0 deprecated `--ssl` flags in favor of URI connection string options (`tls=true`).

---

## MySQL 8.4 LTS / MariaDB 11.8

### Logical vs Physical

| | Logical (mysqldump / mariadb-dump) | Physical (Percona XtraBackup / mariabackup) |
|---|---|---|
| Tool | `mysqldump` / `mariadb-dump` | `xtrabackup` / `mariabackup` |
| Output | SQL text | Binary data files |
| PITR | No (snapshot only) | Yes (with binlog replay) |
| Locks | `FLUSH TABLES WITH READ LOCK` (brief, with `--single-transaction`) | No locks (InnoDB hot backup) |
| Incremental | No | Yes |
| Cross-version | Yes | Same major version only |

### Logical Backup

```bash
#!/usr/bin/env bash
set -euo pipefail

# mysqldump - single database, InnoDB-safe
mysqldump \
  --host=localhost \
  --user=backup_user \
  --password="$DB_BACKUP_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --set-gtid-purged=ON \
  --source-data=2 \
  --databases mydb \
  | zstd -6 > "/backup/mydb_$(date +%Y%m%d_%H%M%S).sql.zst"

# All databases
mysqldump \
  --host=localhost \
  --user=backup_user \
  --password="$DB_BACKUP_PASSWORD" \
  --all-databases \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --set-gtid-purged=ON \
  --source-data=2 \
  | zstd -6 > "/backup/all_$(date +%Y%m%d_%H%M%S).sql.zst"

# MariaDB equivalent (mariadb-dump, same flags minus --set-gtid-purged)
mariadb-dump \
  --host=localhost \
  --user=backup_user \
  --password="$DB_BACKUP_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --source-data=2 \
  --databases mydb \
  | zstd -6 > "/backup/mydb_$(date +%Y%m%d_%H%M%S).sql.zst"
```

**Recommended flags:**
- `--single-transaction` - consistent snapshot without global lock (InnoDB only!)
- `--routines` - include stored procedures/functions
- `--triggers` - include triggers (on by default, but explicit is better)
- `--events` - include scheduled events
- `--set-gtid-purged=ON` - required for GTID replication
- `--source-data=2` - record binlog position as a comment (for PITR)

**Never use `--lock-all-tables`** unless you have MyISAM tables (why do you have MyISAM tables?).

### Physical Backup (Percona XtraBackup / mariabackup)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Full backup (MySQL 8.4 - Percona XtraBackup 8.4.x)
xtrabackup \
  --backup \
  --user=backup_user \
  --password="$DB_BACKUP_PASSWORD" \
  --target-dir=/backup/full/$(date +%Y%m%d_%H%M%S) \
  --compress=zstd \
  --compress-threads=4 \
  --parallel=4

# Incremental backup (based on last full)
xtrabackup \
  --backup \
  --user=backup_user \
  --password="$DB_BACKUP_PASSWORD" \
  --target-dir=/backup/incr/$(date +%Y%m%d_%H%M%S) \
  --incremental-basedir=/backup/full/20260324_020000 \
  --compress=zstd \
  --parallel=4

# MariaDB equivalent
mariabackup \
  --backup \
  --user=backup_user \
  --password="$DB_BACKUP_PASSWORD" \
  --target-dir=/backup/full/$(date +%Y%m%d_%H%M%S) \
  --parallel=4
```

### Restore from Physical Backup

```bash
#!/usr/bin/env bash
set -euo pipefail

# Step 1: Prepare (apply redo log)
xtrabackup --prepare --target-dir=/backup/full/20260324_020000

# Step 1b: If incremental, apply incrementals to full first
xtrabackup --prepare --apply-log-only --target-dir=/backup/full/20260324_020000
xtrabackup --prepare --target-dir=/backup/full/20260324_020000 \
  --incremental-dir=/backup/incr/20260324_140000

# Step 2: Stop MySQL
systemctl stop mysql

# Step 3: Move old data, copy backup
mv /var/lib/mysql /var/lib/mysql.old
xtrabackup --move-back --target-dir=/backup/full/20260324_020000
chown -R mysql:mysql /var/lib/mysql

# Step 4: Start MySQL
systemctl start mysql
```

### PITR Setup

MySQL/MariaDB PITR = physical backup + binary log replay.

**Step 1: Ensure binary logging is enabled (my.cnf)**

```ini
log_bin = mysql-bin
binlog_format = ROW
gtid_mode = ON                   # MySQL only
enforce_gtid_consistency = ON    # MySQL only
binlog_expire_logs_seconds = 604800   # 7 days
sync_binlog = 1
```

**Step 2: Archive binary logs**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Copy binlogs to archive (run via cron every 5 min)
rsync -av /var/lib/mysql/mysql-bin.* /archive/binlogs/
# Or to S3:
# aws s3 sync /var/lib/mysql/ s3://mysql-binlog-archive/ --exclude "*" --include "mysql-bin.*"
```

**Step 3: Restore to point in time**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Restore physical backup first (see above), then:

# Find the binlog position from the backup
cat /backup/full/20260324_020000/xtrabackup_binlog_info
# Output: mysql-bin.000042  154

# Replay binlogs from that position to target time
mysqlbinlog \
  --start-position=154 \
  --stop-datetime="2026-03-24 14:30:00" \
  /archive/binlogs/mysql-bin.000042 \
  /archive/binlogs/mysql-bin.000043 \
  | mysql -u root -p
```

### Common Gotchas

- `mysqldump --single-transaction` only works for InnoDB. MyISAM tables still get locked.
- `--set-gtid-purged=ON` is required when restoring to a GTID-enabled replica. Without it, replication breaks.
- Percona XtraBackup major version must match MySQL major version (XtraBackup 8.4 for MySQL 8.4).
- `mariabackup` is NOT compatible with MySQL, and XtraBackup is NOT compatible with MariaDB. Use the right tool.
- Binary log file names change across server restarts. Your archival script must handle the index file.
- `binlog_expire_logs_seconds` replaced the deprecated `expire_logs_days` in MySQL 8.0. Don't set both.
- MariaDB uses domain-based GTIDs, which are incompatible with MySQL's UUID-based GTIDs. Migration between engines requires GTID reset.

---

## MSSQL 2025

### Backup Types

| Type | What it captures | Restore requirement | Size |
|---|---|---|---|
| FULL | Entire database | Just the full backup | Largest |
| DIFFERENTIAL | Changes since last FULL | Last full + this diff | Medium |
| LOG | Transaction log since last log backup | Last full + last diff + all logs in sequence | Small |

### Backup Commands

```sql
-- Full backup (compressed, with checksum)
BACKUP DATABASE [mydb]
TO DISK = N'/backup/mydb_full_20260324.bak'
WITH
    COMPRESSION,
    CHECKSUM,
    STATS = 10,
    FORMAT,
    INIT,
    NAME = N'mydb-Full-20260324';

-- Differential backup
BACKUP DATABASE [mydb]
TO DISK = N'/backup/mydb_diff_20260324_1400.bak'
WITH
    DIFFERENTIAL,
    COMPRESSION,
    CHECKSUM,
    STATS = 10;

-- Transaction log backup (required for PITR)
BACKUP LOG [mydb]
TO DISK = N'/backup/mydb_log_20260324_1415.trn'
WITH
    COMPRESSION,
    CHECKSUM,
    STATS = 10;

-- Backup to multiple files (striped - faster for large DBs)
BACKUP DATABASE [mydb]
TO DISK = N'/backup/mydb_stripe1.bak',
   DISK = N'/backup/mydb_stripe2.bak',
   DISK = N'/backup/mydb_stripe3.bak',
   DISK = N'/backup/mydb_stripe4.bak'
WITH
    COMPRESSION,
    CHECKSUM,
    STATS = 10;

-- Backup encryption (SQL Server 2014+)
BACKUP DATABASE [mydb]
TO DISK = N'/backup/mydb_encrypted.bak'
WITH
    COMPRESSION,
    ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = [BackupCert]),
    CHECKSUM,
    STATS = 10;
```

### PITR Setup

MSSQL PITR requires FULL recovery model + regular log backups.

```sql
-- Step 1: Set recovery model to FULL
ALTER DATABASE [mydb] SET RECOVERY FULL;

-- Step 2: Take initial full backup (activates log chain)
BACKUP DATABASE [mydb]
TO DISK = N'/backup/mydb_full.bak'
WITH COMPRESSION, CHECKSUM, INIT;

-- Step 3: Schedule log backups (every 5-15 min via SQL Agent job)
BACKUP LOG [mydb]
TO DISK = N'/backup/mydb_log.trn'
WITH COMPRESSION, CHECKSUM;
```

### Point-in-Time Restore

```sql
-- Step 1: Restore full backup (NORECOVERY = more backups coming)
RESTORE DATABASE [mydb_restore]
FROM DISK = N'/backup/mydb_full.bak'
WITH
    NORECOVERY,
    MOVE N'mydb' TO N'/data/mydb_restore.mdf',
    MOVE N'mydb_log' TO N'/data/mydb_restore_log.ldf';

-- Step 2: Restore differential (if you have one)
RESTORE DATABASE [mydb_restore]
FROM DISK = N'/backup/mydb_diff.bak'
WITH NORECOVERY;

-- Step 3: Restore log backups up to target time
RESTORE LOG [mydb_restore]
FROM DISK = N'/backup/mydb_log_1.trn'
WITH NORECOVERY;

RESTORE LOG [mydb_restore]
FROM DISK = N'/backup/mydb_log_2.trn'
WITH NORECOVERY;

-- Step 4: Final log restore with STOPAT
RESTORE LOG [mydb_restore]
FROM DISK = N'/backup/mydb_log_3.trn'
WITH STOPAT = '2026-03-24T14:30:00', RECOVERY;
```

### Backup Verification

```sql
-- Verify backup integrity (does NOT restore, just validates)
RESTORE VERIFYONLY
FROM DISK = N'/backup/mydb_full.bak'
WITH CHECKSUM;

-- Check backup metadata
RESTORE HEADERONLY FROM DISK = N'/backup/mydb_full.bak';
RESTORE FILELISTONLY FROM DISK = N'/backup/mydb_full.bak';

-- Actual restore test (the only real verification)
RESTORE DATABASE [mydb_verify]
FROM DISK = N'/backup/mydb_full.bak'
WITH
    RECOVERY,
    MOVE N'mydb' TO N'/verify/mydb_verify.mdf',
    MOVE N'mydb_log' TO N'/verify/mydb_verify_log.ldf';

-- Run DBCC checks on restored database
DBCC CHECKDB ([mydb_verify]) WITH NO_INFOMSGS;

-- Clean up
DROP DATABASE [mydb_verify];
```

### Common Gotchas

- FULL recovery model + no log backups = transaction log grows forever until disk is full. Schedule log backups or use SIMPLE recovery.
- `RESTORE VERIFYONLY` only checks the backup is readable, not that the data is correct. Always do actual restore tests.
- Differential backups are cumulative (changes since last full). Each new diff replaces the previous one for restore purposes.
- Log backup chain breaks if you switch to SIMPLE recovery or run `BACKUP LOG ... WITH TRUNCATE_ONLY`. You must take a new full backup to restart the chain.
- `COPY_ONLY` backups don't break the log chain - use them for ad-hoc copies.
- SQL Server on Linux (`/opt/mssql`) has the same backup capabilities as Windows. The path format changes but the T-SQL is identical.
- Compressed backups are CPU-intensive. On CPU-bound servers, consider scheduling them during off-peak hours.

---

## Backup Schedule Recommendations

### Dev Environment

| What | Frequency | Retention | Tool |
|---|---|---|---|
| Logical dump | Daily or on-demand | 3 days | pg_dump / mongodump / mysqldump |
| WAL/oplog/binlog archiving | Not needed | N/A | N/A |
| Verify restore | Before major changes | N/A | Manual |

```
# cron: daily at 2am
0 2 * * * /opt/scripts/backup-dev.sh
```

### Production

| What | Frequency | Retention | Tool |
|---|---|---|---|
| Full physical backup | Weekly (Sunday 2am) | 4 weeks | pgBackRest / XtraBackup / mariabackup / MSSQL FULL |
| Differential/Incremental | Daily (2am) | 2 weeks | Same tool, diff/incr mode |
| WAL/oplog/binlog archive | Continuous (5 min) | 2 weeks | archive_command / rsync / S3 sync |
| Logical dump | Weekly (for portability) | 4 weeks | pg_dump / mongodump / mysqldump |
| Verify restore | Weekly (automated) | N/A | Restore to verification server |

```
# cron examples (production)
# Weekly full (Sunday 2am)
0 2 * * 0 /opt/scripts/backup-full.sh

# Daily differential (Mon-Sat 2am)
0 2 * * 1-6 /opt/scripts/backup-diff.sh

# WAL/binlog archive (every 5 min)
*/5 * * * * /opt/scripts/archive-wal.sh

# Weekly logical dump (Wednesday 3am)
0 3 * * 3 /opt/scripts/backup-logical.sh

# Weekly restore verification (Thursday 4am)
0 4 * * 4 /opt/scripts/verify-restore.sh
```

### PCI-CDE (Cardholder Data Environment)

PCI-DSS 4.0 requirements that affect backup strategy:

- **Req 3.5**: Render PAN unreadable wherever stored - backups included. Encrypt backups at rest.
- **Req 3.6/3.7**: Cryptographic key management for backup encryption keys. Key rotation annually minimum.
- **Req 9.4**: Media (including backup media) must be physically secured and tracked.
- **Req 10.5**: Audit logs must be backed up and immutable for 12 months.
- **Req 12.10.2**: Incident response plan must include backup restoration procedures. Test annually.

| What | Frequency | Retention | Extra Requirements |
|---|---|---|---|
| Full physical backup | Daily | 90 days (quarterly audit window) | Encrypted (AES-256), access-logged |
| WAL/binlog archive | Continuous (< 1 min) | 90 days | Encrypted, immutable storage |
| Logical dump | Weekly | 90 days | Encrypted |
| Verify restore | Weekly (automated) + quarterly (documented) | Reports retained 12 months | QSA-auditable evidence |
| Backup integrity check | Daily | Logs retained 12 months | Automated alerts on failure |
| Key rotation | Annually minimum | Previous keys retained until oldest encrypted backup expires | Documented procedure |

```
# PCI-CDE cron (aggressive schedule)
# Full backup (daily 1am)
0 1 * * * /opt/scripts/backup-full-encrypted.sh

# Log archive (every 60 seconds via systemd timer, not cron)
# See systemd timer approach below

# Hourly integrity check
0 * * * * /opt/scripts/verify-backup-integrity.sh

# Weekly restore test
0 4 * * 4 /opt/scripts/verify-restore-full.sh
```

**For sub-minute WAL/binlog archiving, use a systemd timer instead of cron:**

```ini
# /etc/systemd/system/wal-archive.timer
[Unit]
Description=Archive WAL every 30 seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s
AccuracySec=1s

[Install]
WantedBy=timers.target
```

---

## Retention Policies

### Grandfather-Father-Son (GFS) Rotation

The standard for long-term retention:

| Level | Frequency | Retention | Example |
|---|---|---|---|
| Son (daily) | Daily incremental/diff | 14 days | Mon-Sat diffs |
| Father (weekly) | Weekly full | 8 weeks | Sunday fulls |
| Grandfather (monthly) | Monthly full (1st Sunday) | 12 months | Promoted weekly full |
| Annual | First full of the year | 7 years (PCI) or per policy | Promoted monthly full |

**pgBackRest retention config:**
```ini
repo1-retention-full=8           # keep 8 full backups (weekly = 2 months)
repo1-retention-full-type=count  # or 'time' for days-based
repo1-retention-diff=14          # keep 14 differential backups
repo1-retention-archive=8        # keep WAL for 8 full backup cycles
```

**S3 lifecycle policy for backup bucket:**
```json
{
  "Rules": [
    {
      "ID": "DailyToIA",
      "Filter": {"Prefix": "daily/"},
      "Status": "Enabled",
      "Transitions": [
        {"Days": 30, "StorageClass": "STANDARD_IA"}
      ],
      "Expiration": {"Days": 90}
    },
    {
      "ID": "MonthlyToGlacier",
      "Filter": {"Prefix": "monthly/"},
      "Status": "Enabled",
      "Transitions": [
        {"Days": 90, "StorageClass": "GLACIER"}
      ],
      "Expiration": {"Days": 2555}
    }
  ]
}
```

---

## Backup Encryption

### At Rest

| Engine | Native Encryption | Alternative |
|---|---|---|
| PostgreSQL | pgBackRest `aes-256-cbc` | GPG on dump files |
| MongoDB | Percona Backup `--encryption` | GPG / age on dump files |
| MySQL | XtraBackup `--encrypt=AES256` | GPG on dump files |
| MariaDB | mariabackup + MariaDB TDE | GPG on dump files |
| MSSQL | `BACKUP ... WITH ENCRYPTION` | BitLocker on backup volume |

### GPG Encryption (Cross-Engine)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Generate backup-specific GPG key (do this once)
gpg --batch --gen-key <<'GPG'
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: Database Backups
Name-Email: backup@company.com
Expire-Date: 2y
%commit
GPG

# Encrypt backup
pg_dump --format=custom mydb | gpg --encrypt --recipient backup@company.com > backup.dump.gpg

# age (modern alternative to GPG - simpler, no keyring)
pg_dump --format=custom mydb | age -r age1abc123... > backup.dump.age
```

### Key Management

- Never store encryption keys alongside backups. Separate systems, separate access controls.
- Use a secrets manager (Vault, AWS KMS, Azure Key Vault) for key storage.
- Document the key recovery procedure. Encrypted backups with lost keys = no backups.
- Rotate keys annually (PCI requirement). Old keys must remain available until the last backup encrypted with them expires.
- Test decryption after every key rotation.

---

## Monitoring Backup Freshness

### What to Monitor

| Metric | Warning Threshold | Critical Threshold |
|---|---|---|
| Time since last successful full backup | > 36 hours | > 48 hours (prod), > 25 hours (PCI) |
| Time since last WAL/binlog archive | > 10 minutes | > 30 minutes |
| Backup size change vs previous | > 50% decrease | > 80% decrease (empty backup?) |
| Restore verification age | > 14 days | > 30 days |
| Backup duration change | > 2x normal | > 5x normal |
| Backup storage utilization | > 70% | > 85% |
| Encryption key expiry | < 90 days | < 30 days |

### Monitoring Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# Check backup freshness - returns non-zero if stale
# Intended for cron + alerting (Prometheus pushgateway, PagerDuty, etc.)

BACKUP_DIR="/backup"
MAX_AGE_HOURS="${1:-24}"
MAX_AGE_SECONDS=$((MAX_AGE_HOURS * 3600))

latest=$(find "$BACKUP_DIR" -name "*.dump" -o -name "*.bak" -o -name "*.sql.zst" | \
  xargs stat --format='%Y' 2>/dev/null | sort -rn | head -1)

if [[ -z "$latest" ]]; then
  echo "CRITICAL: No backup files found in $BACKUP_DIR"
  exit 2
fi

age=$(( $(date +%s) - latest ))

if (( age > MAX_AGE_SECONDS )); then
  echo "CRITICAL: Latest backup is $(( age / 3600 )) hours old (threshold: ${MAX_AGE_HOURS}h)"
  exit 2
fi

echo "OK: Latest backup is $(( age / 3600 )) hours old"
exit 0
```

### pgBackRest Monitoring

```bash
# Check backup info (parseable output for monitoring)
pgbackrest --stanza=mydb info --output=json | jq '
  .[0].backup[-1] |
  {
    type: .type,
    timestamp_stop: .timestamp.stop,
    age_hours: ((now - .timestamp.stop) / 3600 | floor),
    size_bytes: .info.size,
    repo_size_bytes: .info.repository.size
  }
'
```

### Prometheus Metrics (conceptual)

```
# HELP db_backup_last_success_timestamp Unix timestamp of last successful backup
# TYPE db_backup_last_success_timestamp gauge
db_backup_last_success_timestamp{db="mydb",type="full"} 1711324800
db_backup_last_success_timestamp{db="mydb",type="incremental"} 1711368000

# HELP db_backup_duration_seconds Duration of last backup in seconds
# TYPE db_backup_duration_seconds gauge
db_backup_duration_seconds{db="mydb",type="full"} 1847

# HELP db_backup_size_bytes Size of last backup in bytes
# TYPE db_backup_size_bytes gauge
db_backup_size_bytes{db="mydb",type="full"} 53687091200
```

---

## Managed Database Backups

### AWS RDS / Aurora

- Automated backups: enabled by default, 1-35 day retention, daily snapshot + transaction log archiving.
- PITR: restore to any second within the retention window. Creates a new instance.
- Manual snapshots: persist until explicitly deleted. Use for pre-migration safety nets.
- Cross-region: enable cross-region automated backups or copy manual snapshots.
- **Gotcha**: Automated backups are deleted when you delete the RDS instance (unless you take a final snapshot). Manual snapshots survive.
- **Gotcha**: PITR creates a NEW instance. You can't restore in-place. Plan for DNS/endpoint switchover.
- **PCI**: Enable encryption at rest (KMS), audit via RDS Audit Plugin or pgAudit extension, retention >= 90 days.

```bash
# Manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier mydb-prod \
  --db-snapshot-identifier "mydb-pre-migration-$(date +%Y%m%d)"

# PITR restore
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier mydb-prod \
  --target-db-instance-identifier mydb-restored \
  --restore-time "2026-03-24T14:30:00Z"
```

### Google Cloud SQL

- Automated backups: daily, 1-365 day retention, PITR via binlog/WAL archiving.
- On-demand backups: manual trigger, persist until deleted.
- PITR: restore to any point within retention window. Creates a new instance or restores in-place (clone recommended).
- **Gotcha**: Cloud SQL for PostgreSQL uses pgBackRest internally but doesn't expose it. You can't run pgBackRest commands.
- **Gotcha**: Exporting via `gcloud sql export` uses `pg_dump`/`mysqldump` internally - slow for large databases.

```bash
# On-demand backup
gcloud sql backups create --instance=mydb-prod

# PITR (clone to new instance at specific time)
gcloud sql instances clone mydb-prod mydb-restored \
  --point-in-time="2026-03-24T14:30:00Z"
```

### MongoDB Atlas

- Continuous backup with PITR: oplog-based, restore to any second within the retention window.
- Cloud backup snapshots: configurable frequency and retention.
- Queryable snapshots: mount a snapshot as a read-only cluster to extract specific data without full restore.
- **Gotcha**: Free/shared tier only gets daily snapshots, no PITR. Upgrade for production.
- **Gotcha**: Cross-region restore requires the same Atlas project. Cross-project requires manual export/import.

---

## Kubernetes Database Backup Patterns

Databases on Kubernetes add a layer of complexity because the data lives on PVCs that are tied to the cluster's storage provisioner.

### General Principles

- **Don't rely solely on PVC snapshots.** VolumeSnapshots are storage-backend-specific and may not be portable across clusters.
- **Application-consistent backups > crash-consistent snapshots.** A PVC snapshot of a running database may capture a half-written page.
- **Use the database's native backup tools** (pg_dump, pgBackRest, mongodump, etc.) and stream to object storage. This is portable and database-aware.
- **Separate backup storage from cluster storage.** If the cluster dies, your backups should survive. S3/GCS/MinIO bucket outside the cluster.

### CloudNativePG (cnpg)

The recommended PostgreSQL operator for Kubernetes. Has first-class backup support via Barman (pgBackRest alternative).

```yaml
# Backup configuration in CloudNativePG Cluster spec
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: mydb
  namespace: databases
spec:
  instances: 3
  backup:
    barmanObjectStore:
      destinationPath: "s3://pg-backups/mydb/"
      s3Credentials:
        accessKeyId:
          name: s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: s3-creds
          key: SECRET_ACCESS_KEY
      wal:
        compression: zstd
        maxParallel: 4
      data:
        compression: zstd
    retentionPolicy: "30d"
---
# ScheduledBackup resource
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: mydb-daily
  namespace: databases
spec:
  schedule: "0 2 * * *"
  cluster:
    name: mydb
  backupOwnerReference: self
  immediate: false
```

PITR restore with cnpg:
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: mydb-restored
spec:
  instances: 3
  bootstrap:
    recovery:
      source: mydb
      recoveryTarget:
        targetTime: "2026-03-24 14:30:00.000000+00"
  externalClusters:
    - name: mydb
      barmanObjectStore:
        destinationPath: "s3://pg-backups/mydb/"
        s3Credentials:
          accessKeyId:
            name: s3-creds
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: s3-creds
            key: SECRET_ACCESS_KEY
```

### Velero

Velero backs up Kubernetes resources and PVCs. It's cluster-level, not database-aware.

- Good for: disaster recovery of the entire namespace/cluster, including database StatefulSets + PVCs.
- Bad for: application-consistent database backups (it snapshots PVCs, which may catch the DB mid-write).
- **Combine Velero with native database backups.** Velero for cluster state, native tools for data.
- Use Velero's pre-backup hooks to trigger a native database backup or checkpoint before the PVC snapshot.

```yaml
# Velero pre-backup hook (freeze database before snapshot)
apiVersion: v1
kind: Pod
metadata:
  annotations:
    backup.velero.io/backup-volumes: pgdata
    pre.hook.backup.velero.io/command: '["/bin/sh", "-c", "pg_ctl -D /var/lib/postgresql/data stop -m fast"]'
    pre.hook.backup.velero.io/timeout: "60s"
    post.hook.backup.velero.io/command: '["/bin/sh", "-c", "pg_ctl -D /var/lib/postgresql/data start"]'
```

This stops the database, takes a consistent snapshot, then starts it again. Downtime is brief but nonzero - fine for dev, not great for production.

### pgBackRest in Kubernetes

pgBackRest can run as a sidecar or CronJob alongside your PostgreSQL pods. Defer to the kubernetes skill for the actual deployment manifests, but the backup configuration is the same as bare-metal pgBackRest (see PostgreSQL section above).

Key differences in k8s:
- Repository lives in an S3-compatible bucket (MinIO, AWS S3, GCS via interop).
- The pgBackRest config is mounted via ConfigMap or Secret.
- Stanza creation runs as an init container or one-shot Job.
- Backup CronJobs use the pgBackRest client image and connect to the PG pod via pgBackRest's TLS protocol.

### Summary: What to Use When

| Scenario | Primary Backup | Secondary | Cluster DR |
|---|---|---|---|
| PG on k8s (cnpg) | cnpg ScheduledBackup (Barman) | pg_dump CronJob | Velero |
| PG on k8s (manual) | pgBackRest sidecar | pg_dump CronJob | Velero |
| MongoDB on k8s (operator) | Operator-managed backup | mongodump CronJob | Velero |
| MySQL on k8s | XtraBackup CronJob | mysqldump CronJob | Velero |
| Any DB, managed (RDS/Cloud SQL) | Provider automated backup | Native dump to S3 | Cross-region replication |

---

## Universal Backup Script Template

A starting point for any engine. Customize per environment.

```bash
#!/usr/bin/env bash
set -euo pipefail

# === Configuration ===
DB_ENGINE="${DB_ENGINE:?Set DB_ENGINE (postgres|mysql|mariadb|mongodb|mssql)}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:?Set DB_NAME}"
DB_USER="${DB_USER:?Set DB_USER}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}"

# Optional: encryption recipient (GPG key email or age public key)
ENCRYPT_RECIPIENT="${ENCRYPT_RECIPIENT:-}"

# === Functions ===
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

encrypt_if_needed() {
  local file="$1"
  if [[ -n "$ENCRYPT_RECIPIENT" ]]; then
    if command -v age &>/dev/null; then
      age -r "$ENCRYPT_RECIPIENT" "$file" > "${file}.age" && rm "$file"
      echo "${file}.age"
    else
      gpg --encrypt --recipient "$ENCRYPT_RECIPIENT" "$file" && rm "$file"
      echo "${file}.gpg"
    fi
  else
    echo "$file"
  fi
}

cleanup_old() {
  log "Cleaning backups older than ${BACKUP_RETENTION_DAYS} days"
  find "$BACKUP_DIR" -name "${DB_NAME}_*" -mtime +"$BACKUP_RETENTION_DAYS" -delete
}

# === Backup ===
log "Starting ${DB_ENGINE} backup of ${DB_NAME}"
mkdir -p "$BACKUP_DIR"

case "$DB_ENGINE" in
  postgres)
    pg_dump --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" \
      --format=custom --compress=zstd:6 --dbname="$DB_NAME" \
      --file="${BACKUP_FILE}.dump"
    BACKUP_FILE=$(encrypt_if_needed "${BACKUP_FILE}.dump")
    ;;
  mysql)
    mysqldump --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" \
      --single-transaction --routines --triggers --events \
      --set-gtid-purged=ON --databases "$DB_NAME" \
      | zstd -6 > "${BACKUP_FILE}.sql.zst"
    BACKUP_FILE=$(encrypt_if_needed "${BACKUP_FILE}.sql.zst")
    ;;
  mariadb)
    mariadb-dump --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" \
      --single-transaction --routines --triggers --events \
      --databases "$DB_NAME" \
      | zstd -6 > "${BACKUP_FILE}.sql.zst"
    BACKUP_FILE=$(encrypt_if_needed "${BACKUP_FILE}.sql.zst")
    ;;
  mongodb)
    mongodump --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" \
      --authenticationDatabase=admin --db="$DB_NAME" \
      --gzip --out="${BACKUP_FILE}"
    tar cf "${BACKUP_FILE}.tar.gz" -C "$(dirname "$BACKUP_FILE")" "$(basename "$BACKUP_FILE")"
    rm -rf "${BACKUP_FILE}"
    BACKUP_FILE=$(encrypt_if_needed "${BACKUP_FILE}.tar.gz")
    ;;
  mssql)
    sqlcmd -S "$DB_HOST,$DB_PORT" -U "$DB_USER" -P "$DB_PASSWORD" -Q "
      BACKUP DATABASE [$DB_NAME]
      TO DISK = N'${BACKUP_FILE}.bak'
      WITH COMPRESSION, CHECKSUM, STATS = 10, INIT;
    "
    # For Windows Integrated Auth, replace -U/-P with -E
    BACKUP_FILE=$(encrypt_if_needed "${BACKUP_FILE}.bak")
    ;;
  *)
    log "ERROR: Unknown DB_ENGINE: $DB_ENGINE"
    exit 1
    ;;
esac

# === Post-backup ===
SIZE=$(stat --format='%s' "$BACKUP_FILE" 2>/dev/null || echo "unknown")
log "Backup complete: $BACKUP_FILE ($SIZE bytes)"

cleanup_old

log "Done"
```
