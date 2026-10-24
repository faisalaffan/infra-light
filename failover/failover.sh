#!/usr/bin/env bash
# ==============================================================================
# failover.sh - Seamless Disaster Recovery CLI Switcher (AWS / Vultr)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

ACTION="${1:-plan}"          # plan, apply, destroy, init, output
ENV="${2:-drill}"            # drill, prod
PROVIDER="${3:-tencent}"       # tencent (default), vultr, aws

# Auto-load secrets from root .env if present
ROOT_ENV_FILE="$SCRIPT_DIR/../.env"
if [[ -f "$ROOT_ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ROOT_ENV_FILE"
    set +a

    # Map to Terraform variables
    export TF_VAR_vultr_api_key="${VULTR_API_KEY:-${TF_VAR_vultr_api_key:-}}"
    export TF_VAR_tencentcloud_secret_id="${TENCENTCLOUD_SECRET_ID:-${TF_VAR_tencentcloud_secret_id:-}}"
    export TF_VAR_tencentcloud_secret_key="${TENCENTCLOUD_SECRET_KEY:-${TF_VAR_tencentcloud_secret_key:-}}"
    export TF_VAR_tencentcloud_region="${TENCENTCLOUD_REGION:-ap-jakarta}"
    export TF_VAR_tencentcloud_zone="${TENCENTCLOUD_ZONE:-${TF_VAR_tencentcloud_zone:-}}"
    export TF_VAR_b2_key_id="${B2_APPLICATION_KEY_ID:-${TF_VAR_b2_key_id:-}}"
    export TF_VAR_b2_application_key="${B2_APPLICATION_KEY:-${TF_VAR_b2_application_key:-}}"
    export TF_VAR_b2_bucket="${B2_BUCKET:-${TF_VAR_b2_bucket:-}}"
    export TF_VAR_b2_endpoint="${B2_ENDPOINT:-${TF_VAR_b2_endpoint:-}}"
    export TF_VAR_restic_password="${RESTIC_PASSWORD:-${TF_VAR_restic_password:-}}"
    export CLOUDFLARE_API_KEY="${CLOUDFLARE_API_KEY:-}"
    export CLOUDFLARE_EMAIL="${CLOUDFLARE_EMAIL:-${GIT_EMAIL:-faisallionel@gmail.com}}"
    export TF_VAR_cloudflare_api_token="${CLOUDFLARE_API_TOKEN:-${TF_VAR_cloudflare_api_token:-}}"
    export TF_VAR_cloudflare_api_key="${CLOUDFLARE_API_KEY:-}"
    export TF_VAR_cloudflare_email="${CLOUDFLARE_EMAIL:-${GIT_EMAIL:-faisallionel@gmail.com}}"
    export TF_VAR_cloudflare_zone_id="${CLOUDFLARE_ZONE_ID:-${TF_VAR_cloudflare_zone_id:-}}"
    export TF_VAR_cloudflare_account_id="${CLOUDFLARE_ACCOUNT_ID:-${TF_VAR_cloudflare_account_id:-}}"
    export TF_VAR_enable_load_balancer="${CLOUDFLARE_ENABLE_LOAD_BALANCER:-${TF_VAR_enable_load_balancer:-false}}"
    export TF_VAR_homelab_origin_address="${CLOUDFLARE_HOMELAB_ORIGIN_ADDRESS:-${CLOUDFLARE_HOMELAB_TUNNEL_UUID:+$CLOUDFLARE_HOMELAB_TUNNEL_UUID.cfargotunnel.com}}"
    export TF_VAR_vultr_origin_address="${CLOUDFLARE_VULTR_ORIGIN_ADDRESS:-${CLOUDFLARE_VULTR_TUNNEL_UUID:+$CLOUDFLARE_VULTR_TUNNEL_UUID.cfargotunnel.com}}"
    export TF_VAR_tencent_origin_address="${CLOUDFLARE_TENCENT_ORIGIN_ADDRESS:-${CLOUDFLARE_TENCENT_TUNNEL_UUID:+$CLOUDFLARE_TENCENT_TUNNEL_UUID.cfargotunnel.com}}"
    export TF_VAR_prod_record_name="${FAILOVER_DOMAIN:-homelab.faisalaffan.com}"
    export TF_VAR_drill_record_name="drill.${FAILOVER_DOMAIN:-homelab.faisalaffan.com}"
    export TF_VAR_ssh_public_key="${SSH_PUBLIC_KEY:-${SSH_KEY:-$(cat ~/.ssh/id_rsa.pub 2>/dev/null || cat ~/.ssh/id_ed25519.pub 2>/dev/null || echo '')}}"

    # Compute Instance Plans & Sizing (configured via .env)
    if [[ "$ENV" == "prod" ]]; then
        export TF_VAR_vultr_plan="${VULTR_PROD_PLAN:-${VULTR_PLAN:-vx1-g-16c-64g-960s}}"
        export TF_VAR_instance_type="${AWS_PROD_INSTANCE_TYPE:-${AWS_INSTANCE_TYPE:-c6i.2xlarge}}"
        export TF_VAR_tencent_instance_type="${TENCENT_PROD_INSTANCE_TYPE:-${TENCENT_INSTANCE_TYPE:-SA2.4XLARGE64}}"
    else
        export TF_VAR_vultr_plan="${VULTR_DRILL_PLAN:-${VULTR_PLAN:-voc-g-4c-16gb-150s-amd}}"
        export TF_VAR_instance_type="${AWS_DRILL_INSTANCE_TYPE:-${AWS_INSTANCE_TYPE:-t3.xlarge}}"
        export TF_VAR_tencent_instance_type="${TENCENT_DRILL_INSTANCE_TYPE:-${TENCENT_INSTANCE_TYPE:-SA2.LARGE8}}"
    fi
    export TF_VAR_vultr_region="${VULTR_REGION:-cgk}"
    export TF_VAR_aws_region="${AWS_REGION:-ap-southeast-3}"
    if [[ -n "${FAILOVER_K3S_VERSION:-${K3S_VERSION:-}}" ]]; then
        export TF_VAR_k3s_version="${FAILOVER_K3S_VERSION:-${K3S_VERSION:-v1.30.2+k3s1}}"
    fi
    export TF_VAR_k3s_token="${K3S_TOKEN:-k3s-local-dev-token-2026}"
fi

print_help() {
    echo "Usage: ./failover.sh [action] [environment/target] [provider]"
    echo ""
    echo "⚡ DNS & Traffic Switching (Zero-Cost Master Pointer):"
    echo "  status     Show current routing origin & Standby CVM status"
    echo "  switch     Switch master CNAME pointer to homelab or tencent"
    echo "             Example: ./failover.sh switch tencent"
    echo "                      ./failover.sh switch homelab"
    echo "  auto-setup Auto-create Tencent tunnel & migrate all 29 subdomains"
    echo "             Example: ./failover.sh auto-setup"
    echo "                      ./failover.sh auto-setup --migrate-dns-dryrun"
    echo ""
    echo "🚀 Infrastructure Provisioning (Terraform):"
    echo "  plan       Run terraform plan"
    echo "  apply      Run terraform apply -auto-approve"
    echo "  destroy    Run terraform destroy -auto-approve"
    echo "  init       Run terraform init"
    echo "  output     Show terraform outputs"
    echo ""
    echo "Environments (for Terraform):"
    echo "  drill      Isolated test environment (Default)"
    echo "  prod       Production failover environment"
    echo ""
    echo "Providers (for Terraform):"
    echo "  tencent    Tencent Cloud (Default for failover)"
    echo "  vultr      Vultr Cloud (Jakarta/Singapore)"
    echo "  aws        Amazon Web Services"
    echo ""
    echo "Examples:"
    echo "  ./failover.sh status"
    echo "  ./failover.sh switch tencent"
    echo "  ./failover.sh switch homelab"
    echo "  ./failover.sh apply prod tencent"
}

if [[ "$ACTION" == "-h" || "$ACTION" == "--help" || "$ACTION" == "help" ]]; then
    print_help
    exit 0
fi

# ==============================================================================
# FAST-PATH ACTIONS: Status & DNS Switcher (No Terraform directory required)
# ==============================================================================
if [[ "$ACTION" == "status" ]]; then
    python3 "$SCRIPT_DIR/scripts/dns_switcher.py" status
    if [[ -f "$SCRIPT_DIR/scripts/tencent_cvm.py" && -n "${TENCENTCLOUD_SECRET_ID:-}" ]]; then
        echo "=========================================================="
        echo "☁️  Tencent Standby CVM Status"
        echo "=========================================================="
        python3 "$SCRIPT_DIR/scripts/tencent_cvm.py" status || true
    fi
    exit 0
fi

if [[ "$ACTION" == "switch" ]]; then
    TARGET_ORIGIN="${2:-tencent}"
    python3 "$SCRIPT_DIR/scripts/dns_switcher.py" switch "$TARGET_ORIGIN"
    exit 0
fi

if [[ "$ACTION" == "auto-setup" ]]; then
    SUB_MODE="${2:---all}"
    python3 "$SCRIPT_DIR/scripts/setup_auto_tunnel_and_dns.py" "$SUB_MODE"
    exit 0
fi

# Determine target directory for Terraform actions
TARGET_ENV_DIR=""
if [[ "$PROVIDER" == "vultr" ]]; then
    TARGET_ENV_DIR="$TERRAFORM_DIR/envs/${ENV}-vultr"
elif [[ "$PROVIDER" == "aws" ]]; then
    TARGET_ENV_DIR="$TERRAFORM_DIR/envs/${ENV}"
elif [[ "$PROVIDER" == "tencent" || "$PROVIDER" == "tencentcloud" ]]; then
    TARGET_ENV_DIR="$TERRAFORM_DIR/envs/${ENV}-tencent"
else
    echo "❌ Unknown provider: $PROVIDER. Valid options: tencent, vultr, aws" >&2
    exit 1
fi

if [[ ! -d "$TARGET_ENV_DIR" ]]; then
    echo "❌ Directory not found: $TARGET_ENV_DIR" >&2
    exit 1
fi

echo "=========================================================="
echo "🚀 Failover DR Orchestrator"
echo "Target: $ENV | Provider: $PROVIDER ($TARGET_ENV_DIR)"
echo "Action: $ACTION"
echo "=========================================================="

cd "$TARGET_ENV_DIR"

# Ensure terraform.tfvars exists so terraform doesn't block on missing file
if [[ ! -f "terraform.tfvars" ]]; then
    touch terraform.tfvars
fi

case "$ACTION" in
    init)
        terraform init
        ;;
    plan)
        terraform init -upgrade=false
        terraform plan
        ;;
    apply)
        terraform init -upgrade=false
        terraform apply -auto-approve
        ;;
    destroy)
        terraform destroy -auto-approve
        ;;
    output)
        terraform output
        ;;
    *)
        echo "❌ Unknown action: $ACTION. Valid actions: status, switch, init, plan, apply, destroy, output" >&2
        exit 1
        ;;
esac
