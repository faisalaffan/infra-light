#!/usr/bin/env bash
# ==============================================================================
# healthcheck.sh - Post-Restore Cluster & Workload Health Verification
# ==============================================================================
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
LOG_PREFIX="[HEALTHCHECK $(date '+%Y-%m-%d %H:%M:%S')]"

echo "$LOG_PREFIX Starting Cluster Health Check..."

# 1. Verify k3s service status
if ! systemctl is-active --quiet k3s; then
    echo "$LOG_PREFIX [FAIL] k3s systemd service is NOT active!" >&2
    exit 1
fi
echo "$LOG_PREFIX [OK] k3s systemd service is active."

# 2. Verify Node Ready
NODE_STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
if [[ "$NODE_STATUS" != "True" ]]; then
    echo "$LOG_PREFIX [FAIL] Node is NOT in Ready state (current: $NODE_STATUS)" >&2
    exit 1
fi
echo "$LOG_PREFIX [OK] Node status: Ready"

# 3. Check kube-system critical pods
UNHEALTHY_SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers | grep -v -E "Running|Completed" || true)
if [[ -n "$UNHEALTHY_SYSTEM_PODS" ]]; then
    echo "$LOG_PREFIX [WARN] Some kube-system pods are not yet Running/Completed:"
    echo "$UNHEALTHY_SYSTEM_PODS"
fi

# 4. Check critical application pods (prod / default namespaces)
UNHEALTHY_PODS=$(kubectl get pods --all-namespaces --no-headers | grep -v -E "Running|Completed" || true)
if [[ -n "$UNHEALTHY_PODS" ]]; then
    echo "$LOG_PREFIX [WARN] Non-ready pods across namespaces:"
    echo "$UNHEALTHY_PODS"
else
    echo "$LOG_PREFIX [OK] All pods across all namespaces are in Running/Completed state."
fi

echo "$LOG_PREFIX === Health Check PASSED successfully ==="
exit 0
