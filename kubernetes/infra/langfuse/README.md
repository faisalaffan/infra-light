# Langfuse — Production LLM Observability & Engineering Platform

Langfuse v3 enterprise-grade deployment on Kubernetes (k3s) with ClickHouse analytical telemetry store, PostgreSQL transactional metadata, Redis task queue, MinIO S3 blob storage, automated daily backups, and 7-day trace retention flush.

---

## 🏛 Architecture

```
Internet / Cloudflare Edge
        │
        ▼ (HTTPS)
ingress-nginx (infra-ingress) ───► langfuse.${DOMAIN}
        │
        ▼
langfuse-web (Port 3000) ◄─────► langfuse-worker (Port 3030)
   │        │     │                    │        │     │
   ▼        ▼     ▼                    ▼        ▼     ▼
PostgreSQL ClickHouse Redis         PostgreSQL ClickHouse Redis
(langfuse) (telemetry) (queues)     (langfuse) (telemetry) (queues)
   │           │                          │        │
   └───────────┴──────────────┬───────────┴────────┘
                              ▼
                 MinIO S3 (Events & Backups)
```

| Component | Image / Version | Description |
| :--- | :--- | :--- |
| **Langfuse Web** | `langfuse/langfuse:3` | Next.js Web UI & REST API for traces, evals, prompts, and metrics |
| **Langfuse Worker** | `langfuse/langfuse-worker:3` | Asynchronous queue consumer for ingestion, scoring, and batch tasks |
| **ClickHouse** | `clickhouse/clickhouse-server:24.8-alpine` | High-throughput OLAP database for traces, observations, and spans |
| **PostgreSQL** | `postgres.infra:5432` (db: `langfuse`) | Transactional database for organizations, projects, API keys, users |
| **Redis** | `redis.infra:6379` | Message broker and task queue between Web and Worker |
| **MinIO S3** | `minio-s3.infra:9000` | S3-compatible blob storage (`langfuse` and `langfuse-backups` buckets) |

---

## ⏱ Retention & Backup Policy

### 1. 7-Day Trace Retention & Flush (`langfuse-trace-flush`)
* **Schedule:** Daily at `03:15 UTC` via Kubernetes `CronJob/langfuse-trace-flush`.
* **Mechanism:**
  1. Identifies all physical `*MergeTree` tables in ClickHouse (`traces`, `observations`, `scores`, `event_log`, `blob_storage_file_log`).
  2. Queries the corresponding timestamp column (`timestamp`, `start_time`, `created_at`).
  3. Executes atomic partition/row deletion:
     ```sql
     ALTER TABLE default.<table_name> DELETE WHERE <date_col> < now() - INTERVAL 7 DAY;
     ```
  4. Runs `OPTIMIZE TABLE default.<table_name> FINAL` to flush deleted row parts and physically reclaim NVMe/SSD disk space.
* **Manual execution:**
  ```bash
  make langfuse-flush-traces
  ```

### 2. Daily Data Backup with Daily Retention (`langfuse-backup`)
* **Schedule:** Daily at `02:00 UTC` via Kubernetes `CronJob/langfuse-backup`.
* **Mechanism:**
  1. Dumps relational data from PostgreSQL database `langfuse` using `pg_dump -Fc` (custom format with compression and table-level restore support).
  2. Dumps ClickHouse DDL schemas for all tables and views into SQL.
  3. Bundles them into a compressed tarball: `/backups/langfuse_backup_<DATE>_<TIMESTAMP>.tar.gz` on PersistentVolumeClaim `langfuse-backup-data` (20Gi).
  4. Mirrors the daily backup archive to MinIO S3 object storage bucket `langfuse-backups`.
  5. Enforces daily backup retention: automatically prunes daily backup archives older than `LANGFUSE_BACKUP_RETENTION_DAYS` (default 7 days) to prevent disk saturation.
* **Manual execution:**
  ```bash
  make langfuse-backup
  ```

---

## 🛠 Management Commands (Makefile)

```bash
# Check status of Langfuse Web, Worker, ClickHouse pods and CronJobs
make langfuse-status

# Health check HTTP endpoints (Web /api/public/health and ClickHouse /ping)
make langfuse-health

# Trigger on-demand backup immediately
make langfuse-backup

# Trigger on-demand 7-day trace retention flush immediately
make langfuse-flush-traces

# Tail logs from Web and Worker containers
make langfuse-logs

# Display CLI help
make langfuse-help
```

---

## 🔐 Environment Variables (`.env`)

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `LANGFUSE_VERSION` | `3` | Langfuse container major version |
| `LANGFUSE_HOSTNAME` | `langfuse.faisalaffan.com` | Public FQDN routed via Ingress |
| `LANGFUSE_NEXTAUTH_SECRET` | *(Generated base64)* | NextAuth cryptographic session key |
| `LANGFUSE_SALT` | *(Generated base64)* | Cryptographic hash salt |
| `LANGFUSE_ENCRYPTION_KEY` | *(Generated 64-hex)* | 256-bit encryption key for integration secrets |
| `LANGFUSE_RETENTION_DAYS` | `7` | Trace retention period before flush (days) |
| `LANGFUSE_BACKUP_RETENTION_DAYS` | `7` | Backup retention threshold on storage (days) |
| `LANGFUSE_BACKUP_SCHEDULE` | `"0 2 * * *"` | Daily backup cron expression |
| `LANGFUSE_FLUSH_SCHEDULE` | `"15 3 * * *"` | Daily trace retention flush cron expression |
| `CLICKHOUSE_VERSION` | `24.8-alpine` | ClickHouse official server image |
| `CLICKHOUSE_PASSWORD` | *(Generated)* | Password for ClickHouse `default` user |
| `CLICKHOUSE_DATA_SIZE` | `20Gi` | Persistent storage size for ClickHouse |
| `LANGFUSE_BACKUP_DATA_SIZE` | `20Gi` | Persistent storage size for daily backups PVC |

---

## 🔄 Disaster Recovery / Restore Procedure

To restore Langfuse from a daily backup archive:

```bash
# 1. Inspect available backups on PVC or MinIO
kubectl exec -n infra minio-585d645856-946nz -- mc ls local/langfuse-backups

# 2. Extract backup tarball
tar -xzf /backups/langfuse_backup_<DATE>_<TIMESTAMP>.tar.gz

# 3. Restore PostgreSQL relational database
pg_restore -h postgres.infra.svc.cluster.local -U postgres -d langfuse --clean --if-exists <extracted_folder>/langfuse_postgres_*.dump

# 4. Restart Web and Worker deployments to reload schema
kubectl rollout restart deployment langfuse-web langfuse-worker -n infra
```
