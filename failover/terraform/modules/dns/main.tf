terraform {
  required_version = ">= 1.5.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Cloudflare DNS Record (when dns_provider == "cloudflare" and simple A-record mode is used)
resource "cloudflare_record" "this" {
  count   = var.dns_provider == "cloudflare" && var.enable_dns_switch && !var.enable_load_balancer ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.record_name
  value   = var.target_ip
  type    = "A"
  ttl     = var.ttl
  proxied = var.cloudflare_proxied
  comment = "Managed by Terraform Failover Pipeline (${var.environment})"
}

# ==============================================================================
# Cloudflare Load Balancer (Dual-Tunnel Active-Passive Steering)
# ==============================================================================

resource "cloudflare_load_balancer_monitor" "healthcheck" {
  count          = var.dns_provider == "cloudflare" && var.enable_load_balancer ? 1 : 0
  account_id     = var.cloudflare_account_id
  type           = "http"
  path           = var.health_check_path
  method         = "GET"
  interval       = var.health_check_interval
  retries        = 2
  timeout        = 5
  expected_codes = "2xx"
  description    = "Health monitor for k3s cluster failover (${var.environment})"
}

# Primary Pool: Homelab Baremetal Tunnel
resource "cloudflare_load_balancer_pool" "homelab_primary" {
  count      = var.dns_provider == "cloudflare" && var.enable_load_balancer ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "pool-homelab-${var.environment}"
  origins {
    name    = "homelab-baremetal"
    address = var.homelab_origin_address
    enabled = true
    weight  = 1.0
    header {
      header = "Host"
      values = [var.record_name]
    }
  }
  monitor = cloudflare_load_balancer_monitor.healthcheck[0].id
  enabled = true
}

# Fallback Pool: Standby Cloud Tunnel / Direct Origin (Vultr)
resource "cloudflare_load_balancer_pool" "standby_fallback" {
  count      = var.dns_provider == "cloudflare" && var.enable_load_balancer ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "pool-standby-${var.environment}"
  origins {
    name    = "standby-cloud"
    address = coalesce(var.standby_origin_address, var.target_ip)
    enabled = true
    weight  = 1.0
    header {
      header = "Host"
      values = [var.record_name]
    }
  }
  monitor = cloudflare_load_balancer_monitor.healthcheck[0].id
  enabled = true
}

# Cloudflare Load Balancer with Active-Passive Steering (Zero-TTL Failover)
resource "cloudflare_load_balancer" "this" {
  count            = var.dns_provider == "cloudflare" && var.enable_load_balancer ? 1 : 0
  zone_id          = var.cloudflare_zone_id
  name             = var.record_name
  default_pool_ids = [cloudflare_load_balancer_pool.homelab_primary[0].id]
  fallback_pool_id = cloudflare_load_balancer_pool.standby_fallback[0].id
  steering_policy  = "off" # Active-Passive: 100% to Primary, switches to Fallback if Primary fails
  proxied          = true
  enabled          = true
  description      = "Active-Passive Failover Load Balancer: Homelab -> Standby (${var.environment})"
}
