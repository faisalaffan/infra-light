#!/usr/bin/env bash
# ==============================================================================
# restore.sh - Cold-standby K3s Cluster & State Restoration
# ==============================================================================
set -euo pipefail

RESTORE_LOCK="/var/run/failover_restore.lock"
RESTORE_FLAG="/var/lib/failover_restored"
LOG_PREFIX="[RESTORE $(date '+%Y-%m-%d %H:%M:%S')]"

exec 200>"$RESTORE_LOCK"
flock -n 200 || { echo "$LOG_PREFIX Another restore process is currently running. Exiting."; exit 0; }

if [[ -f "$RESTORE_FLAG" ]]; then
    echo "$LOG_PREFIX Cluster has already been restored successfully previously. Skipping."
    exit 0
fi

echo "$LOG_PREFIX === Starting Disaster Recovery Restore Sequence ==="
START_TIME=$(date +%s)

# Load environment configuration
if [[ -f "/etc/failover/env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source /etc/failover/env
    set +a
else
    echo "$LOG_PREFIX ERROR: /etc/failover/env not found!" >&2
    exit 1
fi

K3S_VERSION="${K3S_VERSION:-v1.30.2+k3s1}"
B2_ENDPOINT="${B2_ENDPOINT:-}"
B2_BUCKET="${B2_BUCKET:-}"
B2_PREFIX="${B2_PREFIX:-k3s-snapshots}"
SNAPSHOT_DIR="/var/lib/rancher/k3s/server/db/snapshots"

mkdir -p "$SNAPSHOT_DIR" /etc/rancher/k3s

# Configure AWS CLI for B2 S3 compatibility
export AWS_ACCESS_KEY_ID="${B2_APPLICATION_KEY_ID:-}"
export AWS_SECRET_ACCESS_KEY="${B2_APPLICATION_KEY:-}"
export AWS_DEFAULT_REGION="us-east-1" # Generic for S3-compatible

LATEST_SNAPSHOT=""

if [[ -n "$B2_BUCKET" && -n "$B2_ENDPOINT" && -n "$AWS_ACCESS_KEY_ID" ]]; then
    echo "$LOG_PREFIX Fetching latest etcd snapshot metadata from B2 bucket: $B2_BUCKET..."
    
    LATEST_SNAPSHOT_KEY=$(aws --endpoint-url "$B2_ENDPOINT" s3 ls "s3://${B2_BUCKET}/${B2_PREFIX}/" \
        | sort | tail -n 1 | awk '{print $4}' || true)

    if [[ -n "$LATEST_SNAPSHOT_KEY" ]]; then
        echo "$LOG_PREFIX Found snapshot: $LATEST_SNAPSHOT_KEY. Downloading..."
        aws --endpoint-url "$B2_ENDPOINT" s3 cp \
            "s3://${B2_BUCKET}/${B2_PREFIX}/${LATEST_SNAPSHOT_KEY}" \
            "${SNAPSHOT_DIR}/${LATEST_SNAPSHOT_KEY}"
        LATEST_SNAPSHOT="${SNAPSHOT_DIR}/${LATEST_SNAPSHOT_KEY}"
        echo "$LOG_PREFIX Snapshot downloaded successfully to $LATEST_SNAPSHOT"
    else
        echo "$LOG_PREFIX [WARN] No etcd snapshot found in s3://${B2_BUCKET}/${B2_PREFIX}/. Proceeding with clean initialization."
    fi
else
    echo "$LOG_PREFIX [INFO] B2 credentials not fully specified. Skipping remote snapshot fetch."
fi

# Install and restore K3s
echo "$LOG_PREFIX Installing K3s ($K3S_VERSION)..."

if [[ -n "$LATEST_SNAPSHOT" && -f "$LATEST_SNAPSHOT" ]]; then
    echo "$LOG_PREFIX Initializing K3s with cluster-reset from snapshot..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
        INSTALL_K3S_EXEC="server --cluster-reset --from-dump=${LATEST_SNAPSHOT} --write-kubeconfig-mode 644" \
        sh -
    
    echo "$LOG_PREFIX Starting K3s service after snapshot restore..."
    systemctl restart k3s
else
    echo "$LOG_PREFIX Installing fresh K3s server..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
        INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" \
        sh -
fi

# Wait for K3s node readiness
echo "$LOG_PREFIX Waiting for K3s node to be Ready..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
MAX_WAIT=120
COUNT=0

until kubectl get nodes | grep -q "Ready"; do
    sleep 3
    COUNT=$((COUNT + 3))
    if [[ $COUNT -ge $MAX_WAIT ]]; then
        echo "$LOG_PREFIX [ERROR] Timed out waiting for K3s node to be Ready!" >&2
        exit 1
    fi
done
echo "$LOG_PREFIX K3s node is Ready."

# Apply GitOps / Manifests if configured
if [[ -n "${GITOPS_REPO_URL:-}" ]]; then
    echo "$LOG_PREFIX Syncing manifests from GitOps repo: $GITOPS_REPO_URL ($GITOPS_BRANCH)..."
    CLONE_DIR="/opt/devops-gitops"
    rm -rf "$CLONE_DIR"
    git clone --depth 1 --branch "${GITOPS_BRANCH:-main}" "$GITOPS_REPO_URL" "$CLONE_DIR"
    
    if [[ -d "$CLONE_DIR/kubernetes" ]]; then
        echo "$LOG_PREFIX Applying base kubernetes manifests..."
        kubectl apply -k "$CLONE_DIR/kubernetes/environments/${ENVIRONMENT:-prod}" || \
        kubectl apply -f "$CLONE_DIR/kubernetes/environments/${ENVIRONMENT:-prod}" || true
    fi
fi

# Mark restore complete
touch "$RESTORE_FLAG"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "$LOG_PREFIX === Disaster Recovery Restore Sequence COMPLETED in ${DURATION}s ==="
