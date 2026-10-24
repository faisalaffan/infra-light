terraform {
  required_version = ">= 1.5.0"
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "tencentcloud" {
  secret_id  = var.tencentcloud_secret_id
  secret_key = var.tencentcloud_secret_key
  region     = var.tencentcloud_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : null
  api_key   = var.cloudflare_api_key != "" ? var.cloudflare_api_key : null
  email     = var.cloudflare_email != "" ? var.cloudflare_email : null
}

locals {
  environment = "drill"

  user_data_rendered = templatefile("${path.module}/../../../bootstrap/cloud-init.yaml.tpl", {
    environment                = local.environment
    k3s_version                = var.k3s_version
    k3s_token                  = var.k3s_token
    b2_endpoint                = var.b2_endpoint
    b2_bucket                  = var.b2_bucket
    b2_key_id                  = var.b2_key_id
    b2_application_key         = var.b2_application_key
    b2_prefix                  = var.b2_prefix
    restic_password            = var.restic_password
    ssh_public_key             = var.ssh_public_key
    gitops_repo_url            = var.gitops_repo_url
    gitops_branch              = var.gitops_branch
    restore_script_content        = indent(6, file("${path.module}/../../../bootstrap/restore.sh"))
    healthcheck_script_content    = indent(6, file("${path.module}/../../../bootstrap/healthcheck.sh"))
    startup_daemon_script_content = indent(6, file("${path.module}/../../../bootstrap/failover-startup-daemon.sh"))
  })
}

module "compute" {
  source = "../../modules/tencent_compute"

  project_name      = var.project_name
  environment       = local.environment
  availability_zone = var.tencentcloud_zone
  instance_type     = var.tencent_instance_type
  allowed_ssh_ip    = var.allowed_ssh_ip
  user_data         = local.user_data_rendered
  tags = {
    Environment = local.environment
    Role        = "k3s-failover-drill"
  }
}

module "dns" {
  source = "../../modules/dns"

  dns_provider           = var.dns_provider
  environment            = local.environment
  enable_dns_switch      = var.enable_dns_switch
  target_ip              = module.compute.public_ip
  record_name            = var.drill_record_name
  cloudflare_zone_id     = var.cloudflare_zone_id
  cloudflare_account_id  = var.cloudflare_account_id
  enable_load_balancer   = var.enable_load_balancer
  homelab_origin_address = var.homelab_origin_address
  standby_origin_address = var.standby_origin_address != "" ? var.standby_origin_address : module.compute.public_ip
}
