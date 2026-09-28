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
    export TF_VAR_cloudflare_api_token="${CLOUDFLARE_API_TOKEN:-${TF_VAR_cloudflare_api_token:-}}"
    export TF_VAR_cloudflare_zone_id="${CLOUDFLARE_ZONE_ID:-${TF_VAR_cloudflare_zone_id:-}}"
fi

echo "=========================================================="
echo "🚀 Failover DR Orchestrator"
echo "Target: $ENV | Provider: $PROVIDER ($TARGET_ENV_DIR)"
echo "Action: $ACTION"
echo "=========================================================="

cd "$TARGET_ENV_DIR"


if [[ ! -f "terraform.tfvars" && -f "terraform.tfvars.example" ]]; then
    echo "⚠️  terraform.tfvars not found. Creating from terraform.tfvars.example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "👉 Please edit $TARGET_ENV_DIR/terraform.tfvars with your credentials."
    exit 1
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
