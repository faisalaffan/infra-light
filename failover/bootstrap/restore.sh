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

RESTORE_MODE="${1:-full}"

if [[ -f "$RESTORE_FLAG" && "$RESTORE_MODE" != "--delta" && "$RESTORE_MODE" != "--force" ]]; then
    echo "$LOG_PREFIX Cluster has already been restored successfully previously. Use --delta or --force to sync latest state."
    exit 0
fi

echo "$LOG_PREFIX === Starting Disaster Recovery Restore Sequence (Mode: $RESTORE_MODE) ==="
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
K3S_TOKEN="${K3S_TOKEN:-k3s-local-dev-token-2026}"
B2_ENDPOINT="${B2_ENDPOINT:-}"
B2_BUCKET="${B2_BUCKET:-}"
B2_PREFIX="${B2_PREFIX:-k3s-snapshots}"
SNAPSHOT_DIR="/var/lib/rancher/k3s/server/db/snapshots"

mkdir -p "$SNAPSHOT_DIR" /etc/rancher/k3s /var/lib/rancher/k3s/server/db

# Configure AWS CLI for B2 S3 compatibility
export AWS_ACCESS_KEY_ID="${B2_APPLICATION_KEY_ID:-}"
export AWS_SECRET_ACCESS_KEY="${B2_APPLICATION_KEY:-}"
export AWS_DEFAULT_REGION="us-east-1" # Generic for S3-compatible

# 1. Setup modern Restic binary (supports repository version 2)
echo "$LOG_PREFIX Verifying Restic version..."
if ! command -v restic &>/dev/null || [[ "$(/usr/local/bin/restic version 2>/dev/null || restic version 2>/dev/null)" =~ "0.12." ]]; then
    echo "$LOG_PREFIX Downloading modern Restic binary (v0.17.3)..."
    if curl -sfL https://github.com/restic/restic/releases/download/v0.17.3/restic_0.17.3_linux_amd64.bz2 | bzip2 -d -c > /usr/local/bin/restic 2>/dev/null; then
        chmod 755 /usr/local/bin/restic
        echo "$LOG_PREFIX Modern Restic installed successfully."
    elif curl -sfL https://github.com/restic/restic/releases/download/v0.17.3/restic_0.17.3_linux_amd64.bz2 | bunzip2 > /usr/local/bin/restic 2>/dev/null; then
        chmod 755 /usr/local/bin/restic
        echo "$LOG_PREFIX Modern Restic installed successfully via bunzip2."
    fi
fi

RESTIC_BIN="$(command -v /usr/local/bin/restic || command -v restic || echo 'restic')"
RESTIC_REPO="s3:${B2_ENDPOINT}/${B2_BUCKET}/restic-pvs"
export RESTIC_REPOSITORY="$RESTIC_REPO"
export RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"

DB_RESTORED=false

# 2. Check and restore K3s Database (SQLite state.db) from Restic
if [[ -n "$B2_BUCKET" && -n "$B2_ENDPOINT" && -n "$AWS_ACCESS_KEY_ID" && -n "${RESTIC_PASSWORD:-}" ]]; then
    echo "$LOG_PREFIX Checking for K3s database snapshots in B2 Restic repository..."
    if "$RESTIC_BIN" snapshots --tag k3s-db --latest 1 &>/dev/null; then
        echo "$LOG_PREFIX Found K3s DB snapshot! Restoring /k3s-db from Backblaze B2..."
        TEMP_DB_RESTORE="/tmp/restic-k3s-db"
        rm -rf "$TEMP_DB_RESTORE" && mkdir -p "$TEMP_DB_RESTORE"
        "$RESTIC_BIN" restore latest --tag k3s-db --target "$TEMP_DB_RESTORE"
        
        if [[ -d "$TEMP_DB_RESTORE/k3s-db" ]]; then
            cp -a "$TEMP_DB_RESTORE/k3s-db/"* /var/lib/rancher/k3s/server/db/
            echo "$LOG_PREFIX K3s database files copied to /var/lib/rancher/k3s/server/db/ ✓"
            
            # Configure K3s token and kubeconfig permissions
            cat << EOF > /etc/rancher/k3s/config.yaml
token: "${K3S_TOKEN}"
write-kubeconfig-mode: "0644"
EOF
            # Remove stale TLS and credentials so K3s reconciles cleanly from restored datastore
            rm -rf /var/lib/rancher/k3s/server/tls /var/lib/rancher/k3s/server/cred
            DB_RESTORED=true
        fi
        rm -rf "$TEMP_DB_RESTORE"
    fi
fi

# Fallback to S3 snapshot dump if Restic DB snapshot wasn't present
LATEST_SNAPSHOT=""
if [[ "$DB_RESTORED" == "false" && -n "$B2_BUCKET" && -n "$B2_ENDPOINT" && -n "$AWS_ACCESS_KEY_ID" ]]; then
    echo "$LOG_PREFIX Checking for standalone etcd snapshots in s3://${B2_BUCKET}/${B2_PREFIX}/..."
    LATEST_SNAPSHOT_KEY=$(aws --endpoint-url "$B2_ENDPOINT" s3 ls "s3://${B2_BUCKET}/${B2_PREFIX}/" \
        | sort | tail -n 1 | awk '{print $4}' || true)

    if [[ -n "$LATEST_SNAPSHOT_KEY" ]]; then
        echo "$LOG_PREFIX Found snapshot: $LATEST_SNAPSHOT_KEY. Downloading..."
        aws --endpoint-url "$B2_ENDPOINT" s3 cp \
            "s3://${B2_BUCKET}/${B2_PREFIX}/${LATEST_SNAPSHOT_KEY}" \
            "${SNAPSHOT_DIR}/${LATEST_SNAPSHOT_KEY}"
        LATEST_SNAPSHOT="${SNAPSHOT_DIR}/${LATEST_SNAPSHOT_KEY}"
        echo "$LOG_PREFIX Snapshot downloaded successfully to $LATEST_SNAPSHOT"
    fi
fi

# 3. Install and run K3s
if [[ "$RESTORE_MODE" == "--delta" && -f "/etc/rancher/k3s/k3s.yaml" ]] && systemctl is-active --quiet k3s 2>/dev/null; then
    echo "$LOG_PREFIX Running in delta mode: K3s is already active. Skipping K3s server reinstallation."
else
    echo "$LOG_PREFIX Installing K3s ($K3S_VERSION)..."

    if [[ -n "$LATEST_SNAPSHOT" && -f "$LATEST_SNAPSHOT" ]]; then
        echo "$LOG_PREFIX Initializing K3s with cluster-reset from snapshot..."
        curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
            INSTALL_K3S_EXEC="server --cluster-reset --from-dump=${LATEST_SNAPSHOT} --token=${K3S_TOKEN} --write-kubeconfig-mode 644" \
            sleep 2
        systemctl restart k3s || true
    elif [[ "$DB_RESTORED" == "true" ]]; then
        echo "$LOG_PREFIX Installing K3s server on top of restored datastore..."
        curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
            INSTALL_K3S_EXEC="server --token=${K3S_TOKEN} --write-kubeconfig-mode 644" \
            sh -
        
        sleep 2
        systemctl restart k3s || true
    else
        echo "$LOG_PREFIX Installing fresh K3s server..."
        curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
            INSTALL_K3S_EXEC="server --token=${K3S_TOKEN} --write-kubeconfig-mode 644" \
            sh -
    fi
fi

# Wait for K3s node readiness
echo "$LOG_PREFIX Waiting for K3s node to be Ready..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
MAX_WAIT=120
COUNT=0

until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    sleep 3
    COUNT=$((COUNT + 3))
    if [[ $COUNT -ge $MAX_WAIT ]]; then
        echo "$LOG_PREFIX [WARN] Waiting for K3s node, restarting service once..."
        systemctl restart k3s || true
        sleep 5
        break
    fi
done
echo "$LOG_PREFIX K3s cluster service is up."

# Scale down stateful services in delta mode to avoid file locking during rsync/restic
if [[ "$RESTORE_MODE" == "--delta" ]] && command -v kubectl &>/dev/null; then
    echo "$LOG_PREFIX Scaling down stateful services in infra namespace to safely sync disk data..."
    kubectl scale statefulset postgres mysql minio redis vault redpanda -n infra --replicas=0 2>/dev/null || true
    sleep 3
fi

# 4. Restore Persistent Volumes via Restic from Backblaze B2
if [[ -n "${B2_BUCKET:-}" && -n "${B2_APPLICATION_KEY_ID:-}" && -n "${RESTIC_PASSWORD:-}" ]]; then
    echo "$LOG_PREFIX Restoring Persistent Volumes from B2 Restic repository ($RESTIC_REPO)..."
    if "$RESTIC_BIN" snapshots --tag k3s-pvs --latest 1 &>/dev/null || "$RESTIC_BIN" snapshots --latest 1 &>/dev/null; then
        mkdir -p /var/lib/rancher/k3s/storage
        TEMP_PV_RESTORE="/tmp/restic-pvs-restore"
        rm -rf "$TEMP_PV_RESTORE" && mkdir -p "$TEMP_PV_RESTORE"
        
        echo "$LOG_PREFIX Restoring latest PV snapshot from Backblaze B2..."
        "$RESTIC_BIN" restore latest --tag k3s-pvs --target "$TEMP_PV_RESTORE" || "$RESTIC_BIN" restore latest --target "$TEMP_PV_RESTORE"
        
        if [[ -d "$TEMP_PV_RESTORE/storage" ]]; then
            echo "$LOG_PREFIX Syncing restored volumes from /storage to /var/lib/rancher/k3s/storage..."
            cp -a "$TEMP_PV_RESTORE/storage/"* /var/lib/rancher/k3s/storage/ 2>/dev/null || rsync -a "$TEMP_PV_RESTORE/storage/" /var/lib/rancher/k3s/storage/
        elif [[ -d "$TEMP_PV_RESTORE/var/lib/rancher/k3s/storage" ]]; then
            echo "$LOG_PREFIX Syncing restored volumes from /var/lib/rancher/k3s/storage..."
            cp -a "$TEMP_PV_RESTORE/var/lib/rancher/k3s/storage/"* /var/lib/rancher/k3s/storage/ 2>/dev/null || rsync -a "$TEMP_PV_RESTORE/var/lib/rancher/k3s/storage/" /var/lib/rancher/k3s/storage/
        fi
        rm -rf "$TEMP_PV_RESTORE"
        echo "$LOG_PREFIX Persistent Volumes restored successfully from Backblaze B2 ✓"
    else
        echo "$LOG_PREFIX [WARN] No Restic PV snapshots found in $RESTIC_REPO. Proceeding."
    fi
fi

# Rescale stateful services in delta mode
if [[ "$RESTORE_MODE" == "--delta" ]] && command -v kubectl &>/dev/null; then
    echo "$LOG_PREFIX Rescaling stateful services in infra namespace to 1..."
    kubectl scale statefulset postgres mysql minio redis vault redpanda -n infra --replicas=1 2>/dev/null || true
fi

# 5. Apply GitOps / Manifests if configured
if [[ -n "${GITOPS_REPO_URL:-}" ]]; then
    echo "$LOG_PREFIX Syncing manifests from GitOps repo: $GITOPS_REPO_URL ($GITOPS_BRANCH)..."
    CLONE_DIR="/opt/devops-gitops"
    rm -rf "$CLONE_DIR"
    git clone --depth 1 --branch "${GITOPS_BRANCH:-main}" "$GITOPS_REPO_URL" "$CLONE_DIR" || true
    
    if [[ -d "$CLONE_DIR/kubernetes" ]]; then
        echo "$LOG_PREFIX Applying base kubernetes manifests..."
        kubectl apply -k "$CLONE_DIR/kubernetes/environments/${ENVIRONMENT:-prod}" 2>/dev/null || \
        kubectl apply -f "$CLONE_DIR/kubernetes/environments/${ENVIRONMENT:-prod}" 2>/dev/null || true
    fi
fi

# Mark restore complete
touch "$RESTORE_FLAG"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "$LOG_PREFIX === Disaster Recovery Restore Sequence COMPLETED in ${DURATION}s ==="
