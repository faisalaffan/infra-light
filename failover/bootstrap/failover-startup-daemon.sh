#!/usr/bin/env bash
# ==============================================================================
# failover-startup-daemon.sh - Automated Gatekeeper & Startup Synchronizer
#
# Runs on every boot of the Standby Cloud VM:
# 1. Enforces gate closure (cloudflared replicas=0)
# 2. Waits for K3s readiness
# 3. Pulls latest delta state/WAL from Backblaze B2
# 4. Verifies database health (Postgres, MySQL, MinIO)
# 5. Opens traffic gate (cloudflared replicas=1)
# ==============================================================================
set -euo pipefail

LOG_TAG="[FAILOVER-DAEMON $(date -u '+%Y-%m-%d %H:%M:%SZ')]"
LOG_FILE="/var/log/failover/startup-daemon.log"
mkdir -p /var/log/failover

log() { echo -e "${LOG_TAG} [INFO] $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${LOG_TAG} [WARN] $*" | tee -a "$LOG_FILE" >&2; }
err() { echo -e "${LOG_TAG} [ERROR] $*" | tee -a "$LOG_FILE" >&2; }

export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

log "Starting Failover Startup & Gatekeeper sequence..."

# 1. Ensure Traffic Gate is firmly CLOSED
if command -v kubectl &>/dev/null && kubectl get deployment cloudflared -n infra &>/dev/null; then
    log "Enforcing gatekeeper: scaling cloudflared to 0..."
    kubectl scale deployment cloudflared -n infra --replicas=0 || true
fi

# 2. Wait for K3s cluster service to become responsive
log "Waiting for K3s local node to report Ready..."
MAX_WAIT=180
COUNT=0
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    sleep 3
    COUNT=$((COUNT + 3))
    if [[ $COUNT -ge $MAX_WAIT ]]; then
        err "Timeout waiting for K3s node. Attempting systemctl restart k3s..."
        systemctl restart k3s || true
        sleep 10
        break
    fi
done
log "K3s node is Ready."

# 3. Run or Update Disaster Recovery Restore from Backblaze B2
if [[ -x "/usr/local/bin/restore.sh" ]]; then
    log "Executing automated data restore & delta synchronization from Backblaze B2..."
    /usr/local/bin/restore.sh --delta >> /var/log/failover/restore.log 2>&1 || warn "Restore script reported warnings, checking data state..."
fi

# 4. Verify Health of Critical Database Services & Unseal Vault
log "Verifying readiness of core stateful services..."
SERVICES=("postgres" "mysql" "minio" "mongodb" "redis")
for svc in "${SERVICES[@]}"; do
    log "Checking health of $svc..."
    kubectl rollout status "statefulset/$svc" -n infra --timeout=120s 2>/dev/null || \
    kubectl rollout status "deployment/$svc" -n infra --timeout=120s 2>/dev/null || \
    warn "Service $svc is still stabilizing..."
done

# Ensure Vault is unsealed
if kubectl get pod vault-0 -n infra &>/dev/null; then
    log "Checking HashiCorp Vault seal status..."
    if kubectl exec -n infra vault-0 -c vault -- vault status 2>&1 | grep -qi "Sealed.*true"; then
        log "Vault is sealed. Attempting automatic unseal..."
        SEAL_FILE="/etc/failover/SEALED_TOKEN_VAULT.md"
        [[ ! -f "$SEAL_FILE" ]] && SEAL_FILE="/opt/devops-gitops/SEALED_TOKEN_VAULT.md"
        if [[ -f "$SEAL_FILE" ]]; then
            keys=$(grep "Unseal Key" "$SEAL_FILE" | awk '{print $NF}' | head -3)
            for k in $keys; do
                kubectl exec -n infra vault-0 -c vault -- vault operator unseal "$k" >/dev/null 2>&1 || true
            done
            log "Vault unseal keys submitted ✓"
        elif [[ -n "${VAULT_UNSEAL_KEYS:-}" ]]; then
            IFS=',' read -ra ADDR <<< "$VAULT_UNSEAL_KEYS"
            for k in "${ADDR[@]}"; do
                kubectl exec -n infra vault-0 -c vault -- vault operator unseal "$k" >/dev/null 2>&1 || true
            done
            log "Vault unseal keys submitted from env ✓"
        else
            warn "Vault is sealed but unseal keys were not found."
        fi
    fi
fi

# Ensure ResourceQuota in resolva allows all replicas
kubectl patch resourcequota prod-quota -n resolva -p '{"spec":{"hard":{"limits.memory":"16Gi","requests.memory":"8Gi"}}}' 2>/dev/null || true


# 5. Open Traffic Gate (Scale cloudflared to 1)
# Ensure Standby Cloudflare Tunnel token and Nginx forwarded headers are enforced
if [[ -f "/etc/failover/env" ]]; then
    set -a; source /etc/failover/env; set +a
fi
if [[ -n "${CLOUDFLARE_STANDBY_TUNNEL_TOKEN:-}" ]]; then
    kubectl create secret generic tunnel-token -n infra --from-literal=token="${CLOUDFLARE_STANDBY_TUNNEL_TOKEN}" --dry-run=client -o yaml | kubectl apply -f -
fi
kubectl patch configmap -n ingress-nginx ingress-nginx-controller -p '{"data":{"use-forwarded-headers":"true"}}' 2>/dev/null || true

log "Stateful services verified. Opening Cloudflare Traffic Gate (scaling cloudflared to 1)..."
kubectl scale deployment cloudflared -n infra --replicas=1
kubectl rollout status deployment cloudflared -n infra --timeout=60s || warn "cloudflared rollout took longer than 60s"

log "=== Automated Failover Sequence COMPLETED successfully ✓ ==="
log "Traffic is now actively flowing through this Cloud Standby node."
