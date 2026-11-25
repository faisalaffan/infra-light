#!/usr/bin/env bash
# ==============================================================================
# generate-secrets.sh — Idempotent Cryptographic Secret Generator for .env
# Copies .env.example to .env if missing and replaces all placeholder secrets
# with strong random values via OpenSSL.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/.env}"
EXAMPLE_FILE="$ROOT_DIR/.env.example"

if [ ! -f "$ENV_FILE" ]; then
    if [ ! -f "$EXAMPLE_FILE" ]; then
        echo "[✗] Missing $EXAMPLE_FILE" >&2
        exit 1
    fi
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "[✓] Created $ENV_FILE from .env.example (chmod 600)"
fi

chmod 600 "$ENV_FILE"

rand_hex() {
    openssl rand -hex "${1:-24}"
}

rand_alnum() {
    # Alphanumeric + safe symbol for passwords requiring mixed char classes
    openssl rand -base64 36 | tr -dc 'A-Za-z0-9' | head -c "${1:-32}"
}

set_env_if_placeholder() {
    local key="$1"
    local gen_type="${2:-alnum}"
    local current_val
    current_val=$(grep -E "^${key}=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d '"'\''' || true)

    if [ -z "$current_val" ] || [[ "$current_val" == CHANGE_ME* ]] || [[ "$current_val" == generate_* ]] || [[ "$current_val" == *"_secret_2026"* ]] || [[ "$current_val" == "minioadmin" ]] || [[ "$current_val" == "k3s-local-dev-token-2026" ]]; then
        local new_val
        case "$gen_type" in
            hex16) new_val=$(rand_hex 16) ;;
            hex24) new_val=$(rand_hex 24) ;;
            hex32) new_val=$(rand_hex 32) ;;
            sk9r)  new_val="sk-9r-$(rand_hex 24)" ;;
            minio_user) new_val="minio_$(rand_hex 6)" ;;
            *)     new_val=$(rand_alnum 32) ;;
        esac

        if grep -qE "^${key}=" "$ENV_FILE"; then
            # Use python3 for safe replacement without sed delimiter collisions
            python3 -c '
import sys, pathlib
p = pathlib.Path(sys.argv[1])
k, v = sys.argv[2], sys.argv[3]
lines = p.read_text(encoding="utf-8").splitlines(True)
out = [f"{k}={v}\n" if line.startswith(f"{k}=") else line for line in lines]
p.write_text("".join(out), encoding="utf-8")
' "$ENV_FILE" "$key" "$new_val"
        else
            printf "%s=%s\n" "$key" "$new_val" >> "$ENV_FILE"
        fi
        echo "  [✓] Generated strong secret for $key"
    fi
}

echo "[i] Checking and generating cryptographic secrets in $ENV_FILE..."

set_env_if_placeholder "K3S_TOKEN" "hex24"
set_env_if_placeholder "INFRA_BASIC_AUTH_PASSWORD" "alnum"
set_env_if_placeholder "PG_SUPERUSER_PASSWORD" "alnum"
set_env_if_placeholder "PG_APP_PASSWORD" "alnum"
set_env_if_placeholder "MONGODB_ROOT_PASSWORD" "alnum"
set_env_if_placeholder "MONGO_EXPRESS_PASSWORD" "alnum"
set_env_if_placeholder "REDIS_COMMANDER_PASSWORD" "alnum"
set_env_if_placeholder "MINIO_ROOT_USER" "minio_user"
set_env_if_placeholder "MINIO_ROOT_PASSWORD" "alnum"
set_env_if_placeholder "EMQX_DASHBOARD_PASSWORD" "alnum"
set_env_if_placeholder "ZITADEL_ADMIN_PASSWORD" "alnum"
set_env_if_placeholder "ZITADEL_MASTERKEY" "hex16"
set_env_if_placeholder "GRAFANA_ADMIN_PASSWORD" "alnum"
set_env_if_placeholder "GRAFANA_DB_PASSWORD" "alnum"
set_env_if_placeholder "QDRANT_API_KEY" "hex24"
set_env_if_placeholder "PHOENIX_SECRET" "hex32"
set_env_if_placeholder "PHOENIX_ADMIN_SECRET" "hex32"
set_env_if_placeholder "PHOENIX_ADMIN_PASSWORD" "alnum"
set_env_if_placeholder "NINEROUTER_INITIAL_PASSWORD" "alnum"
set_env_if_placeholder "NINEROUTER_JWT_SECRET" "hex32"
set_env_if_placeholder "NINEROUTER_API_KEY" "sk9r"
set_env_if_placeholder "MEMGRAPH_PASSWORD" "alnum"
set_env_if_placeholder "CAP_MYSQL_ROOT_PASSWORD" "alnum"
set_env_if_placeholder "CAP_MYSQL_PASSWORD" "alnum"
set_env_if_placeholder "CAP_DATABASE_ENCRYPTION_KEY" "hex32"
set_env_if_placeholder "CAP_NEXTAUTH_SECRET" "hex32"
set_env_if_placeholder "CAP_MEDIA_SERVER_WEBHOOK_SECRET" "hex32"
set_env_if_placeholder "MAILPIT_UI_PASSWORD" "alnum"
set_env_if_placeholder "WOODPECKER_DB_PASSWORD" "alnum"
set_env_if_placeholder "WOODPECKER_AGENT_SECRET" "hex24"
set_env_if_placeholder "GEOSTACK_POSTGRES_PASSWORD" "alnum"
set_env_if_placeholder "GEOSTACK_JWT_SECRET" "hex32"
set_env_if_placeholder "DR_ADMIN_TOKEN" "hex24"
set_env_if_placeholder "RESTIC_PASSWORD" "alnum"

echo "[✓] Secret generation complete for $ENV_FILE"
