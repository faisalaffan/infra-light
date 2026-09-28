terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.19"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "vultr" {
  api_key     = var.vultr_api_key
  rate_limit  = 700
  retry_limit = 3
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  environment = "drill"

  user_data_rendered = templatefile("${path.module}/../../bootstrap/cloud-init.yaml.tpl", {
    environment                = local.environment
    k3s_version                = var.k3s_version
    b2_endpoint                = var.b2_endpoint
    b2_bucket                  = var.b2_bucket
    b2_key_id                  = var.b2_key_id
    b2_application_key         = var.b2_application_key
    b2_prefix                  = var.b2_prefix
    gitops_repo_url            = var.gitops_repo_url
    gitops_branch              = var.gitops_branch
    restore_script_content     = indent(4, file("${path.module}/../../bootstrap/restore.sh"))
    healthcheck_script_content = indent(4, file("${path.module}/../../bootstrap/healthcheck.sh"))
  })
}

module "compute" {
  source = "../../modules/vultr_compute"

  project_name            = var.project_name
  environment             = local.environment
  region                  = var.vultr_region # Default "cgk" (Jakarta)
  plan                    = var.vultr_plan   # Lean plan for drill
  ssh_key_ids             = var.ssh_key_ids
  allowed_ssh_ip          = var.allowed_ssh_ip
  allowed_ssh_subnet_size = var.allowed_ssh_subnet_size
  user_data               = local.user_data_rendered
  tags                    = ["failover-drill", "k3s"]
}

module "dns" {
  source = "../../modules/dns"

  environment        = local.environment
  dns_provider       = var.dns_provider
  enable_dns_switch  = var.enable_dns_switch
  record_name        = var.drill_record_name
  target_ip          = module.compute.public_ip
  cloudflare_zone_id = var.cloudflare_zone_id
}
