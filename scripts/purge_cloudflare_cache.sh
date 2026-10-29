#!/usr/bin/env bash
# ==============================================================================
# Purge Cloudflare Edge Cache Script
# Supports:
#   1. Global API Key (X-Auth-Key + X-Auth-Email)
#   2. Scoped API Token (Authorization: Bearer)
#   3. Automatic fallback to HashiCorp Vault (secret/resolva/dev)
# ==============================================================================
set -eo pipefail

ZONE_ID="${1:-${CLOUDFLARE_ZONE_ID:-}}"
API_KEY="${2:-${CLOUDFLARE_API_KEY:-}}"
EMAIL="${3:-${CLOUDFLARE_EMAIL:-faisallionel@gmail.com}}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

# --- 1. Fallback to .env and Vault if credentials are missing ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

ZONE_ID="${ZONE_ID:-${1:-${CLOUDFLARE_ZONE_ID:-}}}"
API_KEY="${API_KEY:-${2:-${CLOUDFLARE_API_KEY:-}}}"
EMAIL="${EMAIL:-${3:-${CLOUDFLARE_EMAIL:-}}}"
API_TOKEN="${API_TOKEN:-${CLOUDFLARE_API_TOKEN:-}}"

if [ -z "$ZONE_ID" ] || { [ -z "$API_KEY" ] && [ -z "$API_TOKEN" ]; }; then
    VAULT_ADDR="${VAULT_ADDR:-http://vault.infra.svc:8200}"
    if [ -n "${VAULT_TOKEN:-}" ] && command -v curl &>/dev/null; then
        echo "🔒 Mengambil kredensial Cloudflare langsung dari HashiCorp Vault (secret/resolva/dev)..."
        VAULT_RESP=$(curl -s --connect-timeout 3 -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/secret/data/resolva/dev" 2>/dev/null || true)
        if [ -n "$VAULT_RESP" ]; then
            [ -z "$ZONE_ID" ] && ZONE_ID=$(echo "$VAULT_RESP" | grep -o '"CLOUDFLARE_ZONE_ID":"[^"]*' | cut -d'"' -f4 || true)
            [ -z "$API_KEY" ] && API_KEY=$(echo "$VAULT_RESP" | grep -o '"CLOUDFLARE_API_KEY":"[^"]*' | cut -d'"' -f4 || true)
            [ -z "$EMAIL" ] && EMAIL=$(echo "$VAULT_RESP" | grep -o '"CLOUDFLARE_EMAIL":"[^"]*' | cut -d'"' -f4 || true)
            [ -z "$API_TOKEN" ] && API_TOKEN=$(echo "$VAULT_RESP" | grep -o '"CLOUDFLARE_API_TOKEN":"[^"]*' | cut -d'"' -f4 || true)
        fi
    fi
fi

echo "🧹 Purging Cloudflare Edge Cache for Zone ID: ${ZONE_ID}..."

# --- 2. Execute Purge API Call ---
if [ -n "$API_KEY" ] && [ -n "$EMAIL" ]; then
    echo "🔑 Menggunakan Cloudflare Global API Key (${EMAIL})..."
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
        -H "X-Auth-Email: ${EMAIL}" \
        -H "X-Auth-Key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"purge_everything":true}')
elif [ -n "$API_TOKEN" ]; then
    echo "🔑 Menggunakan Cloudflare Scoped API Token..."
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data '{"purge_everything":true}')
else
    echo "❌ Error: Kredensial Cloudflare tidak ditemukan! Set CLOUDFLARE_API_KEY & CLOUDFLARE_EMAIL atau CLOUDFLARE_API_TOKEN." >&2
    exit 1
fi

# --- 3. Verify Response ---
if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✅ Berhasil! Cloudflare Edge Cache telah di-purge secara global (HTTP 200)."
else
    echo "❌ Gagal purge cache Cloudflare:" >&2
    echo "$RESPONSE" >&2
    exit 1
fi
