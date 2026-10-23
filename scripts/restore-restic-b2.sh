#!/usr/bin/env bash
# ==============================================================================
# restore-restic-b2.sh - Disaster Recovery Restore from Backblaze B2
#
# Restores:
#   Kubernetes Persistent Volumes from Restic backup in Backblaze B2
#   to a target directory (e.g. /var/lib/rancher/k3s/storage on a new VM).
#
# Usage:
#   ./restore-restic-b2.sh --list                  # List all available snapshots
#   ./restore-restic-b2.sh --target /tmp/restore   # Restore latest snapshot to /tmp/restore
#   ./restore-restic-b2.sh --target / --snapshot <id> # Restore specific snapshot
#   ./restore-restic-b2.sh --check                 # Verify repository integrity
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment
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

LOG_TAG="[B2-RESTORE $(date -u '+%Y-%m-%d %H:%M:%SZ')]"
log()  { echo -e "${LOG_TAG} \033[0;32m[INFO]\033[0m $*"; }
warn() { echo -e "${LOG_TAG} \033[1;33m[WARN]\033[0m $*" >&2; }
err()  { echo -e "${LOG_TAG} \033[0;31m[ERROR]\033[0m $*" >&2; exit 1; }

# Parse arguments
TARGET_DIR=""
SNAPSHOT_ID="latest"
INCLUDE_PATTERN=""
CHECK_REPO=false
LIST_SNAPSHOTS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --snapshot)
            SNAPSHOT_ID="$2"
            shift 2
            ;;
        --include)
            INCLUDE_PATTERN="$2"
            shift 2
            ;;
        --check)
            CHECK_REPO=true
            shift
            ;;
        --list)
            LIST_SNAPSHOTS=true
            shift
            ;;
        *)
            err "Unknown option: $1"
            ;;
    esac
done

B2_ENDPOINT="${B2_ENDPOINT:-https://s3.us-west-004.backblazeb2.com}"
B2_BUCKET="${B2_BUCKET:-my-homelab-k3s-backups}"
B2_KEY_ID="${B2_APPLICATION_KEY_ID:-}"
B2_APP_KEY="${B2_APPLICATION_KEY:-}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
RESTIC_REPO="${RESTIC_REPOSITORY:-s3:${B2_ENDPOINT}/${B2_BUCKET}/restic-pvs}"

if [[ -z "$B2_KEY_ID" || -z "$B2_APP_KEY" ]]; then
    err "B2 credentials not found in environment."
fi

if [[ -z "$RESTIC_PASSWORD" ]]; then
    err "RESTIC_PASSWORD not configured."
fi

export AWS_ACCESS_KEY_ID="${B2_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${B2_APP_KEY}"
export AWS_DEFAULT_REGION="us-east-1"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"
export RESTIC_REPOSITORY="${RESTIC_REPO}"

if ! command -v restic &>/dev/null; then
    if [[ -x "${HOME}/.local/bin/restic" ]]; then
        export PATH="${HOME}/.local/bin:${PATH}"
    else
        err "Restic binary not found."
    fi
fi

if [ "$CHECK_REPO" = true ]; then
    log "Checking repository integrity on Backblaze B2..."
    restic check
    log "Repository integrity verified successfully ✓"
    exit 0
fi

if [ "$LIST_SNAPSHOTS" = true ]; then
    log "Snapshots in repository ${RESTIC_REPO}:"
    restic snapshots
    exit 0
fi

if [[ -z "$TARGET_DIR" ]]; then
    err "Target directory must be specified with --target <directory> (e.g. --target /var/lib/rancher/k3s/storage or --target /tmp/test)"
fi

mkdir -p "$TARGET_DIR"

log "=== Starting Restic Restore ==="
log "Snapshot: $SNAPSHOT_ID"
log "Destination Target: $TARGET_DIR"

RESTORE_ARGS=("restore" "$SNAPSHOT_ID" "--target" "$TARGET_DIR")

if [[ -n "$INCLUDE_PATTERN" ]]; then
    log "Filtering include pattern: $INCLUDE_PATTERN"
    RESTORE_ARGS+=("--include" "$INCLUDE_PATTERN")
fi

START_TIME=$(date +%s)
restic "${RESTORE_ARGS[@]}"
DURATION=$(( $(date +%s) - START_TIME ))

log "=== Restore Completed in ${DURATION}s ✓ ==="
log "Files restored into: $TARGET_DIR"
