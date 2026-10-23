#!/usr/bin/env bash
# ==============================================================================
# failover.sh - Seamless Disaster Recovery CLI Switcher (AWS / Vultr)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

ACTION="${1:-plan}"          # plan, apply, destroy, init, output
ENV="${2:-drill}"            # drill, prod
PROVIDER="${3:-vultr}"       # vultr, aws

print_help() {
    echo "Usage: ./failover.sh [action] [environment] [provider]"
    echo ""
    echo "Actions:"
    echo "  plan       Run terraform plan"
    echo "  apply      Run terraform apply -auto-approve"
    echo "  destroy    Run terraform destroy -auto-approve"
    echo "  init       Run terraform init"
    echo "  output     Show terraform outputs"
    echo ""
    echo "Environments:"
    echo "  drill      Isolated test environment (Default)"
    echo "  prod       Production failover environment"
    echo ""
    echo "Providers:"
    echo "  vultr      Vultr Cloud (Jakarta/Singapore) (Default)"
    echo "  aws        Amazon Web Services"
    echo ""
    echo "Examples:"
    echo "  ./failover.sh plan drill vultr"
    echo "  ./failover.sh apply drill vultr"
    echo "  ./failover.sh destroy drill vultr"
    echo "  ./failover.sh apply prod aws"
}

if [[ "$ACTION" == "-h" || "$ACTION" == "--help" || "$ACTION" == "help" ]]; then
    print_help
    exit 0
fi

# Determine target directory
TARGET_ENV_DIR=""
if [[ "$PROVIDER" == "vultr" ]]; then
    TARGET_ENV_DIR="$TERRAFORM_DIR/envs/${ENV}-vultr"
elif [[ "$PROVIDER" == "aws" ]]; then
    TARGET_ENV_DIR="$TERRAFORM_DIR/envs/${ENV}"
else
    echo "❌ Unknown provider: $PROVIDER. Valid options: vultr, aws" >&2
    exit 1
fi

if [[ ! -d "$TARGET_ENV_DIR" ]]; then
    echo "❌ Directory not found: $TARGET_ENV_DIR" >&2
    exit 1
fi

# Auto-load secrets from root .env if present
ROOT_ENV_FILE="$SCRIPT_DIR/../.env"
if [[ -f "$ROOT_ENV_FILE" ]]; then
    echo "🔑 Loading environment variables from .env..."
    set -a
    # shellcheck disable=SC1090
    source "$ROOT_ENV_FILE"
    set +a

    # Map to Terraform variables
    export TF_VAR_vultr_api_key="${VULTR_API_KEY:-${TF_VAR_vultr_api_key:-}}"
    export TF_VAR_b2_key_id="${B2_APPLICATION_KEY_ID:-${TF_VAR_b2_key_id:-}}"
    export TF_VAR_b2_application_key="${B2_APPLICATION_KEY:-${TF_VAR_b2_application_key:-}}"
    export TF_VAR_b2_bucket="${B2_BUCKET:-${TF_VAR_b2_bucket:-}}"
    export TF_VAR_b2_endpoint="${B2_ENDPOINT:-${TF_VAR_b2_endpoint:-}}"
    export TF_VAR_restic_password="${RESTIC_PASSWORD:-${TF_VAR_restic_password:-}}"
    export TF_VAR_cloudflare_api_token="${CLOUDFLARE_API_TOKEN:-${TF_VAR_cloudflare_api_token:-}}"
    export TF_VAR_cloudflare_zone_id="${CLOUDFLARE_ZONE_ID:-${TF_VAR_cloudflare_zone_id:-}}"
    export TF_VAR_cloudflare_account_id="${CLOUDFLARE_ACCOUNT_ID:-${TF_VAR_cloudflare_account_id:-}}"
    export TF_VAR_enable_load_balancer="${CLOUDFLARE_ENABLE_LOAD_BALANCER:-${TF_VAR_enable_load_balancer:-false}}"
    export TF_VAR_homelab_origin_address="${CLOUDFLARE_HOMELAB_ORIGIN_ADDRESS:-${CLOUDFLARE_HOMELAB_TUNNEL_UUID:+$CLOUDFLARE_HOMELAB_TUNNEL_UUID.cfargotunnel.com}}"
    export TF_VAR_vultr_origin_address="${CLOUDFLARE_VULTR_ORIGIN_ADDRESS:-${CLOUDFLARE_VULTR_TUNNEL_UUID:+$CLOUDFLARE_VULTR_TUNNEL_UUID.cfargotunnel.com}}"
    export TF_VAR_prod_record_name="${FAILOVER_DOMAIN:-homelab.faisalaffan.com}"
    export TF_VAR_drill_record_name="drill.${FAILOVER_DOMAIN:-homelab.faisalaffan.com}"
    export TF_VAR_ssh_public_key="${SSH_PUBLIC_KEY:-${SSH_KEY:-$(cat ~/.ssh/id_rsa.pub 2>/dev/null || cat ~/.ssh/id_ed25519.pub 2>/dev/null || echo '')}}"

    # Compute Instance Plans & Sizing (configured via .env)
    if [[ "$ENV" == "prod" ]]; then
        export TF_VAR_vultr_plan="${VULTR_PROD_PLAN:-${VULTR_PLAN:-vx1-g-16c-64g-960s}}"
        export TF_VAR_instance_type="${AWS_PROD_INSTANCE_TYPE:-${AWS_INSTANCE_TYPE:-c6i.2xlarge}}"
    else
        export TF_VAR_vultr_plan="${VULTR_DRILL_PLAN:-${VULTR_PLAN:-voc-g-4c-16gb-150s-amd}}"
        export TF_VAR_instance_type="${AWS_DRILL_INSTANCE_TYPE:-${AWS_INSTANCE_TYPE:-t3.xlarge}}"
    fi
    export TF_VAR_vultr_region="${VULTR_REGION:-cgk}"
    export TF_VAR_aws_region="${AWS_REGION:-ap-southeast-3}"
    if [[ -n "${FAILOVER_K3S_VERSION:-${K3S_VERSION:-}}" ]]; then
        export TF_VAR_k3s_version="${FAILOVER_K3S_VERSION:-${K3S_VERSION:-v1.30.2+k3s1}}"
    fi
    export TF_VAR_k3s_token="${K3S_TOKEN:-k3s-local-dev-token-2026}"
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
        echo "❌ Unknown action: $ACTION. Valid actions: init, plan, apply, destroy, output" >&2
        exit 1
        ;;
esac
