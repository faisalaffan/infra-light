#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a
    source "${ROOT_DIR}/.env"
    set +a
fi

export RESTIC_BACKUP_SCHEDULE="${RESTIC_BACKUP_SCHEDULE:-0 */6 * * *}"
export RESTIC_RETENTION_KEEP_DAILY="${RESTIC_RETENTION_KEEP_DAILY:-7}"
export RESTIC_RETENTION_KEEP_WEEKLY="${RESTIC_RETENTION_KEEP_WEEKLY:-4}"
export RESTIC_RETENTION_KEEP_MONTHLY="${RESTIC_RETENTION_KEEP_MONTHLY:-3}"
export RESTIC_EXCLUDE_REGISTRY="${RESTIC_EXCLUDE_REGISTRY:-true}"

cd "${ROOT_DIR}/kubernetes/infra/b2-backup"
ENVS_TO_SUBST='${RESTIC_BACKUP_SCHEDULE} ${RESTIC_RETENTION_KEEP_DAILY} ${RESTIC_RETENTION_KEEP_WEEKLY} ${RESTIC_RETENTION_KEEP_MONTHLY} ${RESTIC_EXCLUDE_REGISTRY} ${B2_APPLICATION_KEY_ID} ${B2_APPLICATION_KEY} ${RESTIC_PASSWORD} ${B2_ENDPOINT} ${B2_BUCKET} ${RESTIC_REPOSITORY}'
kubectl kustomize . | envsubst "$ENVS_TO_SUBST" | kubectl apply -f -
echo "B2 Backup CronJob and Secret successfully applied!"
