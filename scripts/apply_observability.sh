#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUSTOMIZE_DIR="$SCRIPT_DIR/kubernetes/infra"

# 1. Load environment variables for envsubst
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

echo "==> Deploying Loki configuration..."
(cd "$KUSTOMIZE_DIR/loki" && kubectl kustomize . | envsubst | kubectl apply -f -)

echo "==> Deploying Alloy configuration..."
(cd "$KUSTOMIZE_DIR/alloy" && kubectl kustomize . | envsubst | kubectl apply -f -)

echo "==> Deploying Grafana datasources configuration..."
(cd "$KUSTOMIZE_DIR/grafana" && kubectl kustomize . | envsubst | kubectl apply -f -)

echo "==> Rolling out restarts..."
kubectl rollout restart deployment loki -n infra
kubectl rollout restart deployment alloy -n infra
kubectl rollout restart deployment grafana -n infra

echo "==> Waiting for deployments to be ready..."
kubectl rollout status deployment loki -n infra --timeout=120s
kubectl rollout status deployment alloy -n infra --timeout=120s
kubectl rollout status deployment grafana -n infra --timeout=120s

echo "==> Observability pipeline successfully updated and active!"
