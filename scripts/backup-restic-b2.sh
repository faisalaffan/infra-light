#!/usr/bin/env bash
# ==============================================================================
# backup-restic-b2.sh - Automated Disaster Recovery Backup to Backblaze B2
#
# Backs up:
#   1. K3s Cluster State / etcd Snapshot to s3://${B2_BUCKET}/${B2_PREFIX}/
#   2. Kubernetes Persistent Volumes (/var/lib/rancher/k3s/storage) via Restic
#      with client-side AES-256 encryption, chunk-deduplication, and retention pruning.
#
# Usage:
#   ./backup-restic-b2.sh              # Full automated backup & prune
#   ./backup-restic-b2.sh --init-only  # Initialize remote Restic repository
#   ./backup-restic-b2.sh --dry-run    # Simulate backup without writing to B2
#   ./backup-restic-b2.sh --snapshots  # List existing snapshots in B2
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCK_FILE="/var/run/k3s-b2-backup.lock"
if [ ! -w "/var/run" ] 2>/dev/null; then
    LOCK_FILE="/tmp/k3s-b2-backup.lock"
fi

# ------------------------------------------------------------------------------
# 1. Load Environment Configuration
# ------------------------------------------------------------------------------
if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/.env"
    set +a
elif [[ -f "/etc/failover/env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "/etc/failover/env"
    set +a
fi

LOG_TAG="[B2-BACKUP $(date -u '+%Y-%m-%d %H:%M:%SZ')]"
log()  { echo -e "${LOG_TAG} \033[0;32m[INFO]\033[0m $*"; }
warn() { echo -e "${LOG_TAG} \033[1;33m[WARN]\033[0m $*" >&2; }
err()  { echo -e "${LOG_TAG} \033[0;31m[ERROR]\033[0m $*" >&2; exit 1; }

# Parse arguments
DRY_RUN=false
INIT_ONLY=false
LIST_ONLY=false
FORCE_BACKUP="${FORCE_BACKUP:-false}"

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=true ;;
        --init-only) INIT_ONLY=true ;;
        --snapshots) LIST_ONLY=true ;;
        --force)     FORCE_BACKUP=true ;;
        *)           ;;
    esac
done

# ------------------------------------------------------------------------------
# 2. Validate Credentials & Parameters
# ------------------------------------------------------------------------------
B2_ENDPOINT="${B2_ENDPOINT:-https://s3.us-west-004.backblazeb2.com}"
B2_BUCKET="${B2_BUCKET:-my-homelab-k3s-backups}"
B2_PREFIX="${B2_PREFIX:-k3s-snapshots}"
B2_KEY_ID="${B2_APPLICATION_KEY_ID:-}"
B2_APP_KEY="${B2_APPLICATION_KEY:-}"
STORAGE_PATH="${K3S_STORAGE_PATH:-/var/lib/rancher/k3s/storage}"
SNAPSHOT_PATH="${K3S_SNAPSHOT_PATH:-/var/lib/rancher/k3s/server/db/snapshots}"
EXCLUDE_REGISTRY="${RESTIC_EXCLUDE_REGISTRY:-true}"

RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
RESTIC_REPO="${RESTIC_REPOSITORY:-s3:${B2_ENDPOINT}/${B2_BUCKET}/restic-pvs}"

KEEP_DAILY="${RESTIC_RETENTION_KEEP_DAILY:-7}"
KEEP_WEEKLY="${RESTIC_RETENTION_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${RESTIC_RETENTION_KEEP_MONTHLY:-3}"

# Strip any wrapping quotes from variables (e.g. from .env or envsubst)
B2_ENDPOINT="${B2_ENDPOINT//\"/}"
B2_BUCKET="${B2_BUCKET//\"/}"
B2_PREFIX="${B2_PREFIX//\"/}"
B2_KEY_ID="${B2_KEY_ID//\"/}"
B2_APP_KEY="${B2_APP_KEY//\"/}"
RESTIC_PASSWORD="${RESTIC_PASSWORD//\"/}"
RESTIC_REPO="${RESTIC_REPO//\"/}"
EXCLUDE_REGISTRY="${EXCLUDE_REGISTRY//\"/}"
KEEP_DAILY="${KEEP_DAILY//\"/}"
KEEP_WEEKLY="${KEEP_WEEKLY//\"/}"
KEEP_MONTHLY="${KEEP_MONTHLY//\"/}"

if [[ -z "$B2_KEY_ID" || -z "$B2_APP_KEY" ]]; then
    err "B2_APPLICATION_KEY_ID or B2_APPLICATION_KEY is empty in .env. Please configure Backblaze B2 credentials."
fi

if [[ -z "$RESTIC_PASSWORD" ]]; then
    err "RESTIC_PASSWORD is not set. Please set a strong encryption password in .env."
fi

# Export AWS credentials required by Restic S3 backend & AWS CLI
export AWS_ACCESS_KEY_ID="${B2_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${B2_APP_KEY}"
export AWS_DEFAULT_REGION="us-east-1"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"
export RESTIC_REPOSITORY="${RESTIC_REPO}"

# Check restic binary
if ! command -v restic &>/dev/null; then
    if [[ -x "${HOME}/.local/bin/restic" ]]; then
        export PATH="${HOME}/.local/bin:${PATH}"
    else
        err "Restic binary not found! Run setup or install restic."
    fi
fi

# ------------------------------------------------------------------------------
# 3. Lock Acquisition (Prevent Concurrent Backup Runs)
# ------------------------------------------------------------------------------
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    warn "Another backup process is currently holding $LOCK_FILE. Exiting."
    exit 0
fi

# ------------------------------------------------------------------------------
# 4. Initialize Repository If Needed
# ------------------------------------------------------------------------------
init_repository() {
    log "Checking Restic repository: ${RESTIC_REPOSITORY}..."
    if restic snapshots --latest 1 &>/dev/null; then
        log "Restic repository is already initialized and accessible ✓"
    else
        log "Repository not initialized or empty. Initializing new Restic repository on B2..."
        restic init
        log "Restic repository successfully initialized in B2 bucket '${B2_BUCKET}' ✓"
    fi
}

if [ "$LIST_ONLY" = true ]; then
    log "Fetching snapshots from ${RESTIC_REPOSITORY}..."
    restic snapshots
    exit 0
fi

# ------------------------------------------------------------------------------
# 4a. Active-Origin Split-Brain Guard
# ------------------------------------------------------------------------------
verify_active_origin_guard() {
    if [ "$FORCE_BACKUP" = "true" ]; then
        log "[GUARD] --force diaktifkan, melewati pengecekan routing origin."
        return 0
    fi

    local local_role="HOMELAB"
    if [[ -f "/etc/failover/env" ]]; then
        local_role="TENCENT"
    fi

    local status_json=""
    if command -v curl &>/dev/null; then
        status_json=$(curl -sf -m 8 -H "X-Admin-Pin: ${ADMIN_PIN:-2026}" "https://dr.faisalaffan.com/api/status" 2>/dev/null || true)
    elif command -v wget &>/dev/null; then
        status_json=$(wget -qO- -T 8 --header="X-Admin-Pin: ${ADMIN_PIN:-2026}" "https://dr.faisalaffan.com/api/status" 2>/dev/null || true)
    fi

    if [[ -n "$status_json" ]]; then
        if [[ "$local_role" == "HOMELAB" && "$status_json" == *'"currentOrigin":"TENCENT"'* ]]; then
            warn "[GUARD] Routing Cloudflare saat ini sedang aktif di Server Cadangan (TENCENT)."
            warn "[GUARD] Membatalkan auto-backup di Homelab agar data lama tidak menimpa snapshot B2 terbaru! (Gunakan --force jika ingin memaksa)."
            exit 0
        elif [[ "$local_role" == "TENCENT" && "$status_json" == *'"currentOrigin":"HOMELAB"'* ]]; then
            warn "[GUARD] Routing Cloudflare saat ini sedang aktif di Server Utama (HOMELAB)."
            warn "[GUARD] Membatalkan auto-backup di Cloud Standby agar tidak bentrok dengan Homelab! (Gunakan --force jika ingin memaksa)."
            exit 0
        fi
        log "[GUARD] Terverifikasi server ini ($local_role) adalah server aktif. Melanjutkan backup..."
    fi
}

verify_active_origin_guard

init_repository

if [ "$INIT_ONLY" = true ]; then
    log "--init-only specified. Exiting cleanly."
    exit 0
fi

# ------------------------------------------------------------------------------
# 5. K3s Cluster State / etcd Snapshot to B2
# ------------------------------------------------------------------------------
backup_k3s_state() {
    log "=== Phase 1: K3s Cluster State Snapshot ==="
    local timestamp
    timestamp=$(date -u +%Y%m%d_%H%M%SZ)
    local snapshot_name="k3s-snapshot-${timestamp}"

    if command -v k3s &>/dev/null && [ -w "/var/lib/rancher/k3s" ] 2>/dev/null; then
        log "Executing K3s etcd snapshot..."
        if [ "$DRY_RUN" = true ]; then
            log "[DRY-RUN] Would run: k3s etcd-snapshot save --name ${snapshot_name} --s3..."
        else
            k3s etcd-snapshot save \
                --name "${snapshot_name}" \
                --s3 \
                --s3-endpoint "${B2_ENDPOINT#https://}" \
                --s3-bucket "${B2_BUCKET}" \
                --s3-folder "${B2_PREFIX}" \
                --s3-access-key "${B2_KEY_ID}" \
                --s3-secret-key "${B2_APP_KEY}" \
                --s3-region "us-east-1" || {
                    warn "Direct k3s --s3 upload failed, checking local snapshot fallback..."
                }
        fi
    elif [ -d "$SNAPSHOT_PATH" ] && command -v aws &>/dev/null; then
        log "Uploading existing local K3s snapshots from ${SNAPSHOT_PATH} to B2..."
        if [ "$DRY_RUN" = false ]; then
            aws --endpoint-url "${B2_ENDPOINT}" s3 sync "${SNAPSHOT_PATH}" "s3://${B2_BUCKET}/${B2_PREFIX}/"
        fi
    else
        log "K3s daemon not running directly on this user context. State snapshot step deferred."
    fi
    log "K3s Cluster State step finished."
}

# ------------------------------------------------------------------------------
# 6. Persistent Volumes Backup via Restic
# ------------------------------------------------------------------------------
backup_persistent_volumes() {
    log "=== Phase 2: Persistent Volumes Backup ==="
    if [[ ! -d "$STORAGE_PATH" ]]; then
        warn "Storage path '$STORAGE_PATH' does not exist. Skipping PV backup."
        return
    fi
    if [[ ! -r "$STORAGE_PATH" ]]; then
        err "Permission denied: Cannot read '$STORAGE_PATH' as user '$(whoami)'.\n       Kubernetes storage volumes are owned by root.\n       👉 Jalankan dengan sudo: 'sudo ./scripts/backup-restic-b2.sh'\n       👉 Atau jalankan via K8s runner: 'make b2-cron-trigger'"
    fi

    log "Target volume directory: $STORAGE_PATH"
    local exclude_flags=(
        "--exclude=lost+found"
        "--exclude=*.sock"
        "--exclude=*.tmp"
    )

    if [[ "$EXCLUDE_REGISTRY" == "true" ]]; then
        log "Excluding Docker Registry cache (*docker-registry*) to optimize bandwidth & storage."
        exclude_flags+=("--exclude=*docker-registry*")
    fi

    local restic_args=(
        "backup"
        "$STORAGE_PATH"
        "--verbose"
        "--tag=k3s-pvs"
        "--tag=environment=${ENVIRONMENT:-prod}"
        "--tag=host=$(hostname)"
        "${exclude_flags[@]}"
    )

    if [ "$DRY_RUN" = true ]; then
        restic_args+=("--dry-run")
        log "[DRY-RUN] Simulating Restic backup to B2..."
    else
        log "Starting encrypted incremental backup to B2..."
    fi

    local start_time
    start_time=$(date +%s)
    restic "${restic_args[@]}"
    local duration=$(( $(date +%s) - start_time ))
    log "PV Backup completed in ${duration}s ✓"
}

# ------------------------------------------------------------------------------
# 7. Retention Policy & Pruning
# ------------------------------------------------------------------------------
prune_retention() {
    log "=== Phase 3: Pruning Old Snapshots & Enforcing Retention ==="
    if [ "$DRY_RUN" = true ]; then
        log "[DRY-RUN] Would prune: keep-daily=${KEEP_DAILY}, keep-weekly=${KEEP_WEEKLY}, keep-monthly=${KEEP_MONTHLY}"
        restic forget --dry-run \
            --keep-daily "${KEEP_DAILY}" \
            --keep-weekly "${KEEP_WEEKLY}" \
            --keep-monthly "${KEEP_MONTHLY}" \
            --tag=k3s-pvs
    else
        log "Enforcing retention: keep-daily=${KEEP_DAILY}, keep-weekly=${KEEP_WEEKLY}, keep-monthly=${KEEP_MONTHLY}..."
        restic forget --prune \
            --keep-daily "${KEEP_DAILY}" \
            --keep-weekly "${KEEP_WEEKLY}" \
            --keep-monthly "${KEEP_MONTHLY}" \
            --tag=k3s-pvs
    fi
    log "Prune step finished ✓"
}

# ------------------------------------------------------------------------------
# 8. Main Execution Flow
# ------------------------------------------------------------------------------
START_TOTAL=$(date +%s)
log "=== Starting Full K3s Disaster Recovery Backup to Backblaze B2 ==="
backup_k3s_state
backup_persistent_volumes
prune_retention

TOTAL_DURATION=$(( $(date +%s) - START_TOTAL ))
log "=== All Disaster Recovery Backup Tasks Completed in ${TOTAL_DURATION}s ==="
