#!/bin/sh
set -eu

CH_URL="http://clickhouse.infra.svc.cluster.local:8123"
RETENTION="${RETENTION_DAYS:-7}"
PASS="${CH_PASSWORD:-}"

echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] === Starting Langfuse Trace Retention Flush (Retention: ${RETENTION} days) ==="

for TABLE in traces observations scores event_log blob_storage_file_log; do
  ENGINE=$(curl -s -u "default:${PASS}" "${CH_URL}/?query=SELECT+engine+FROM+system.tables+WHERE+database='default'+AND+name='${TABLE}'" || echo "")
  case "${ENGINE}" in
    *MergeTree*)
      DATE_COL=""
      for CANDIDATE in timestamp start_time created_at time; do
        COL_EXISTS=$(curl -s -u "default:${PASS}" "${CH_URL}/?query=SELECT+count()+FROM+system.columns+WHERE+database='default'+AND+table='${TABLE}'+AND+name='${CANDIDATE}'" || echo "0")
        if [ "${COL_EXISTS}" = "1" ]; then
          DATE_COL="${CANDIDATE}"
          break
        fi
      done

      if [ -n "${DATE_COL}" ]; then
        BEFORE_COUNT=$(curl -s -u "default:${PASS}" "${CH_URL}/?query=SELECT+count()+FROM+default.${TABLE}" || echo "0")
        echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Purging records older than ${RETENTION} days from default.${TABLE} (engine: ${ENGINE}, current count: ${BEFORE_COUNT}, date column: ${DATE_COL})..."
        
        curl -s -f -u "default:${PASS}" -d "ALTER TABLE default.${TABLE} DELETE WHERE ${DATE_COL} < now() - INTERVAL ${RETENTION} DAY" "${CH_URL}/"
        
        echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Running OPTIMIZE TABLE default.${TABLE} FINAL to flush and reclaim physical disk storage..."
        curl -s -f -u "default:${PASS}" -d "OPTIMIZE TABLE default.${TABLE} FINAL" "${CH_URL}/"
        
        AFTER_COUNT=$(curl -s -u "default:${PASS}" "${CH_URL}/?query=SELECT+count()+FROM+default.${TABLE}" || echo "0")
        echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Flush finished for default.${TABLE}. Remaining records: ${AFTER_COUNT}."
      fi
      ;;
    *)
      # View or non-existent, skip
      ;;
  esac
done

echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] === Langfuse Trace Retention Flush Completed Successfully ==="
