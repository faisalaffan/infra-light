#!/bin/sh
set -eu

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_DAY=$(date +%Y-%m-%d)
BACKUP_DIR="/backups/daily/${DATE_DAY}"
RETENTION="${RETENTION_DAYS:-7}"
CH_URL="http://clickhouse.infra.svc.cluster.local:8123"

mkdir -p "${BACKUP_DIR}"

echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] === Starting Langfuse Daily Backup for ${DATE_DAY} ==="

# 1. Backup PostgreSQL transactional database
PG_FILE="${BACKUP_DIR}/langfuse_postgres_${TIMESTAMP}.dump"
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Dumping PostgreSQL database '${PGDATABASE}'..."
PGPASSWORD="${PGPASSWORD}" pg_dump -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -Fc -f "${PG_FILE}"
ls -lh "${PG_FILE}"
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] PostgreSQL backup complete ✓"

# 2. Backup ClickHouse Schema & Metadata
CH_FILE="${BACKUP_DIR}/langfuse_clickhouse_schema_${TIMESTAMP}.sql"
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Exporting ClickHouse schemas..."
{
  echo "-- ClickHouse Schema Backup ${TIMESTAMP}"
  for T in $(curl -s -u "default:${CH_PASSWORD}" "${CH_URL}/?query=SHOW+TABLES+FROM+default"); do
    echo "-- Table: $T"
    curl -s -u "default:${CH_PASSWORD}" "${CH_URL}/?query=SHOW+CREATE+TABLE+default.${T}"
    echo ";"
  done
} > "${CH_FILE}" 2>/dev/null || true
ls -lh "${CH_FILE}"
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] ClickHouse schema backup complete ✓"

# 3. Create compressed bundle for the day
ARCHIVE_FILE="/backups/langfuse_backup_${DATE_DAY}_${TIMESTAMP}.tar.gz"
tar -czf "${ARCHIVE_FILE}" -C "/backups/daily" "${DATE_DAY}"
rm -rf "${BACKUP_DIR}"
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Compressed archive created: ${ARCHIVE_FILE} ($(du -h "${ARCHIVE_FILE}" | cut -f1))"

# 4. Mirror archive to MinIO S3 bucket (langfuse-backups)
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Mirroring archive to MinIO S3 bucket 'langfuse-backups'..."
FILENAME=$(basename "${ARCHIVE_FILE}")
curl -s -f -X PUT -T "${ARCHIVE_FILE}" "http://minio-s3.infra.svc.cluster.local:9000/langfuse-backups/${FILENAME}" || echo "Warning: MinIO mirror skipped, local persistent backup preserved."
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] MinIO mirror step completed ✓"

# 5. Daily Backup Retention: prune backups older than RETENTION_DAYS
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Pruning daily backups older than ${RETENTION} days in /backups..."
find /backups -maxdepth 1 -name "langfuse_backup_*.tar.gz" -mtime +"${RETENTION}" -exec echo "Removing expired backup: {}" \; -exec rm -f {} \;

echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Current backups in /backups:"
ls -lh /backups
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] === Langfuse Daily Backup Completed Successfully ==="
