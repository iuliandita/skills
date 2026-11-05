---
checked_at: "2026-10-01"
checked_by: "migration"
pins:
  - tool: "PostgreSQL"
    version: "18.6"
    source: "https://www.postgresql.org/support/versioning/"
  - tool: "MongoDB"
    version: "9.0.2"
    source: "https://www.mongodb.com/legal/support-policy/lifecycles"
  - tool: "MongoDB 8.0 lane"
    version: "8.0.34"
    source: "https://www.mongodb.com/legal/support-policy/lifecycles"
  - tool: "MariaDB"
    version: "11.8.9"
    source: "https://mariadb.org/about/#maintenance-policy"
  - tool: "MariaDB"
    version: "12.3.3"
    source: "https://mariadb.org/about/#maintenance-policy"
  - tool: "MySQL"
    version: "8.4.12"
    source: "https://github.com/mysql/mysql-server/tags"
  - tool: "MySQL 9.7 LTS lane"
    version: "9.7.3"
    source: "https://github.com/mysql/mysql-server/tags"
  - tool: "Redis"
    version: "8.10.2"
    source: "https://github.com/redis/redis/releases"
  - tool: "Valkey"
    version: "9.1.2"
    source: "https://github.com/valkey-io/valkey/releases"
  - tool: "SQL Server"
    version: "2025 RTM + CU9"
    source: "https://learn.microsoft.com/en-us/troubleshoot/sql/releases/download-and-install-latest-updates"
  - tool: "PgBouncer"
    version: "1.26.0"
    source: "https://www.pgbouncer.org/changelog.html"
  - tool: "Pgpool-II"
    version: "4.7.3"
    source: "https://www.pgpool.net/mediawiki/index.php/Main_Page#News"
  - tool: "ProxySQL"
    version: "3.0.11"
    source: "https://github.com/sysown/proxysql/releases"
---

# Databases target versions

Pins referenced by `../SKILL.md`, moved unchanged from the former inline block (migration, no refresh). Reverify against the source before use if the receipt exceeds 120 days. Source URLs not present in the original text are canonical release pages.

| Tool | Version | Source | Notes |
|---|---|---|---|
| PostgreSQL | 18.6 | <https://www.postgresql.org/support/versioning/> | EOL 2030-11; August 13, 2026 release. Back-branches: 17.11, 16.15, 15.19, 14.24 (EOL 2026-11-12 - plan the upgrade off 14 now). PostgreSQL 19 RC 1 (2026-10-15) is for testing only |
| MongoDB | 9.0.2 | <https://www.mongodb.com/legal/support-policy/lifecycles> | New major, GA 2026-09-28, EOL 2031-10. Rapid lane is Atlas-only with a short window - verify live before pinning |
| MongoDB 8.0 lane | 8.0.34 | <https://www.mongodb.com/legal/support-policy/lifecycles> | EOL 2029-10; 8.0.32 fixes CVE-2026-89099 and is the security floor for the 8.0 lane |
| MariaDB | 11.8.9 | <https://mariadb.org/about/#maintenance-policy> | LTS, EOL 2028-06 |
| MariaDB | 12.3.3 | <https://mariadb.org/about/#maintenance-policy> | LTS, EOL 2029-06. 13.x rolling GA is quarterly and EOLs at each successor - verify live |
| MySQL | 8.4.12 | <https://github.com/mysql/mysql-server/tags> | LTS; August 18, 2026 release |
| MySQL 9.7 LTS lane | 9.7.3 | <https://github.com/mysql/mysql-server/tags> | August 18, 2026 release. The innovation lane has a short support window - verify live |
| Redis | 8.10.2 | <https://github.com/redis/redis/releases> | Verify live before pinning |
| Valkey | 9.1.2 | <https://github.com/valkey-io/valkey/releases> | 9.0.6 on the 9.0 lane; verify live before pinning |
| SQL Server | 2025 RTM + CU9 | <https://learn.microsoft.com/en-us/troubleshoot/sql/releases/download-and-install-latest-updates> | Released 2026-09-15 |
| PgBouncer | 1.26.0 | <https://www.pgbouncer.org/changelog.html> | Fixes CVE-2026-19888/6668/6669 |
| Pgpool-II | 4.7.3 | <https://www.pgpool.net/mediawiki/index.php/Main_Page#News> |  |
| ProxySQL | 3.0.11 | <https://github.com/sysown/proxysql/releases> | 3.0.9+ fixes CVE-2026-48772/48773; CVE-2026-48774 affects the 4.0 lane, fixed in 4.0.9 |
