#!/usr/bin/env bash
# ==============================================================================
# rotate-all-secrets.sh — Live Credential Rotation & Hardening Sync for K3s
# Run this on the live K3s control plane host after pulling hardened manifests.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
BACKUP_DIR="/root/infra-rotation-backup-$(date +%Y%m%d_%H%M%S)"

[ -f "$ENV_FILE" ] || err ".env not found at $ENV_FILE"
command -v kubectl >/dev/null 2>&1 || err "kubectl not found"
kubectl get nodes >/dev/null 2>&1 || err "Cannot connect to K3s cluster"

echo "============================================================"
echo "  infra-light — Live Credential Rotation & Hardening"
echo "============================================================"

# 1. Backup current .env & K8s secrets outside Git
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
cp "$ENV_FILE" "$BACKUP_DIR/.env.bak"
chmod 600 "$BACKUP_DIR/.env.bak"
kubectl get secret -n infra -o yaml > "$BACKUP_DIR/infra-secrets-backup.yaml" 2>/dev/null || true
chmod 600 "$BACKUP_DIR/infra-secrets-backup.yaml" 2>/dev/null || true
log "Backed up old .env and K8s secrets to $BACKUP_DIR (chmod 700)"

# 2. Load old .env values (needed for stateful DB auth if needed)
set -a; source "$ENV_FILE"; set +a
OLD_MONGO_PASS="${MONGODB_ROOT_PASSWORD:-}"

# 3. Force-rotate compromised/weak secrets in .env
log "Rotating credentials in $ENV_FILE..."
python3 -c '
import pathlib, secrets, sys

env_path = pathlib.Path(sys.argv[1])
lines = env_path.read_text(encoding="utf-8").splitlines(True)

def gen_alnum(n=32):
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    return "".join(secrets.choice(alphabet) for _ in range(n))

rotations = {
    "K3S_TOKEN": secrets.token_hex(24),
    "INFRA_BASIC_AUTH_PASSWORD": gen_alnum(32),
    "PG_SUPERUSER_PASSWORD": gen_alnum(32),
    "PG_APP_PASSWORD": gen_alnum(32),
    "MONGODB_ROOT_PASSWORD": gen_alnum(32),
    "MONGO_EXPRESS_PASSWORD": gen_alnum(32),
    "REDIS_COMMANDER_PASSWORD": gen_alnum(32),
    "MINIO_ROOT_USER": f"minio_{secrets.token_hex(6)}",
    "MINIO_ROOT_PASSWORD": gen_alnum(32),
    "EMQX_DASHBOARD_PASSWORD": gen_alnum(32),
    "GRAFANA_ADMIN_PASSWORD": gen_alnum(32),
    "GRAFANA_DB_PASSWORD": gen_alnum(32),
    "QDRANT_API_KEY": secrets.token_hex(24),
    "MAILPIT_UI_PASSWORD": gen_alnum(32),
    "WOODPECKER_DB_PASSWORD": gen_alnum(32),
    "WOODPECKER_AGENT_SECRET": secrets.token_hex(24),
    "GEOSTACK_POSTGRES_PASSWORD": gen_alnum(32),
    "GEOSTACK_JWT_SECRET": secrets.token_hex(32),
    "MEMGRAPH_PASSWORD": gen_alnum(32),
    "DR_ADMIN_TOKEN": secrets.token_hex(24),
}

existing = set()
new_lines = []
for line in lines:
    stripped = line.strip()
    if stripped and not stripped.startswith("#") and "=" in line:
        k = line.split("=", 1)[0].strip()
        if k in rotations:
            new_lines.append(f"{k}={rotations[k]}\n")
            existing.add(k)
            continue
    new_lines.append(line)

for k, v in rotations.items():
    if k not in existing:
        new_lines.append(f"{k}={v}\n")

env_path.write_text("".join(new_lines), encoding="utf-8")
' "$ENV_FILE"
chmod 600 "$ENV_FILE"

# Reload new values
set -a; source "$ENV_FILE"; set +a
export MAILPIT_UI_AUTH="${MAILPIT_UI_USER:-mailpit_admin}:${MAILPIT_UI_PASSWORD}"
log "Generated fresh cryptographic secrets in .env ✓"

# 4. Update Stateful Databases In-Place before pod restarts
if kubectl get pod postgres-0 -n infra >/dev/null 2>&1; then
    log "Rotating PostgreSQL passwords & provisioning read-only grafana_reader..."
    kubectl exec -n infra postgres-0 -- psql -U "${PG_SUPERUSER:-postgres}" -v ON_ERROR_STOP=1 <<SQL
ALTER USER "${PG_SUPERUSER:-postgres}" WITH PASSWORD '${PG_SUPERUSER_PASSWORD}';
DO \$\$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${PG_APP_USER:-appuser}') THEN
    EXECUTE format('ALTER USER %I WITH PASSWORD %L', '${PG_APP_USER:-appuser}', '${PG_APP_PASSWORD}');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grafana_reader') THEN
    EXECUTE format('CREATE USER grafana_reader WITH PASSWORD %L', '${GRAFANA_DB_PASSWORD}');
  ELSE
    EXECUTE format('ALTER USER grafana_reader WITH PASSWORD %L', '${GRAFANA_DB_PASSWORD}');
  END IF;
END \$\$;
GRANT pg_read_all_data TO grafana_reader;
SQL
    log "PostgreSQL roles rotated ✓"
fi

if kubectl get pod -n infra -l app.kubernetes.io/name=mongodb -o name | head -1 | grep -q pod/; then
    MONGO_POD=$(kubectl get pod -n infra -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}')
    log "Rotating MongoDB root password on $MONGO_POD..."
    kubectl exec -n infra "$MONGO_POD" -- mongosh admin -u root -p "$OLD_MONGO_PASS" --eval \
        "db.changeUserPassword('root', '${MONGODB_ROOT_PASSWORD}')" >/dev/null 2>&1 || \
        warn "MongoDB password update skipped/failed — verify manually if MongoDB uses custom auth"
fi

if kubectl get pod -n infra -l app=grafana -o name | head -1 | grep -q pod/; then
    GRAFANA_POD=$(kubectl get pod -n infra -l app=grafana -o jsonpath='{.items[0].metadata.name}')
    log "Resetting Grafana admin password on $GRAFANA_POD..."
    kubectl exec -n infra "$GRAFANA_POD" -- grafana cli admin reset-admin-password "${GRAFANA_ADMIN_PASSWORD}" >/dev/null 2>&1 || \
        warn "Grafana CLI reset failed — check pod logs"
fi

# 5. Re-create Kubernetes Secrets cleanly
log "Recreating Kubernetes Secrets in namespace infra..."
envsubst < "$ROOT_DIR/kubernetes/infra/base/secrets-template.yaml" | kubectl apply -f -

AUTH_HTPASSWD=$(printf "%s:%s\n" "${INFRA_BASIC_AUTH_USER:-infra_admin}" "$(openssl passwd -apr1 "$INFRA_BASIC_AUTH_PASSWORD")")
kubectl create secret generic infra-basic-auth -n infra \
    --from-literal=auth="$AUTH_HTPASSWD" \
    --dry-run=client -o yaml | kubectl apply -f -

if [ -f "$ROOT_DIR/kubernetes/geostack-infra/secrets.yaml" ]; then
    envsubst < "$ROOT_DIR/kubernetes/geostack-infra/secrets.yaml" | kubectl apply -f -
fi

# 6. Apply hardened HelmCharts & Kustomize manifests
log "Applying hardened HelmCharts & Kustomize manifests..."
for chart in "$ROOT_DIR/kubernetes/helmcharts"/*.yaml; do
    [ -f "$chart" ] || continue
    envsubst < "$chart" | kubectl apply -f -
done

(cd "$ROOT_DIR/kubernetes/infra" && kubectl kustomize . | envsubst | kubectl apply -f -) || \
    warn "Kustomize apply returned warnings (check PVC resize messages)"

# 7. Remove legacy cluster-admin ClusterRoleBinding if still present
kubectl delete clusterrolebinding woodpecker-ci-admin 2>/dev/null || true

# 8. Restart affected workloads to pick up new secrets
log "Restarting affected deployments & statefulsets..."
for deploy in grafana mailpit mongo-express minio woodpecker-server woodpecker-agent dr-monitor cap-web; do
    kubectl rollout restart deployment/"$deploy" -n infra 2>/dev/null || true
done
for sts in qdrant memgraph postgres; do
    kubectl rollout restart statefulset/"$sts" -n infra 2>/dev/null || true
done

echo ""
echo "============================================================"
log "In-cluster rotation complete!"
echo "============================================================"
echo ""
warn "MANUAL PROVIDER ACTIONS REQUIRED (Cannot be automated from inside K3s):"
echo "  1. Cloudflare Tunnel: Rotate CF_TUNNEL_TOKEN in Cloudflare Zero Trust Dashboard -> update .env & secret 'tunnel-token'."
echo "  2. Cloudflare DR Worker: Push new DR_ADMIN_TOKEN to dr.faisalaffan.com:"
echo "     cd failover/cloudflare-worker && echo -n \"$DR_ADMIN_TOKEN\" | npx wrangler secret put ADMIN_PIN"
echo "  3. HashiCorp Vault: Revoke old Root Token & generate a new one via 'vault operator generate-root' (after Tailscale access)."
echo "  4. Cloudflare Dashboard: Remove Tier-3 hostnames from Public Tunnel & enable Cloudflare Access OTP on Tier-2 + dr subdomain."
echo "  5. Host UFW & K3s Token: Run 'sudo bash setup.sh' (or apply UFW tailscale-only 6443 rule) and update /etc/rancher/k3s/config.yaml token."
echo ""
