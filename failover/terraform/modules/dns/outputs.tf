output "record_fqdn" {
  description = "FQDN of the configured DNS record or Load Balancer"
  value = (
    var.dns_provider == "cloudflare" && var.enable_load_balancer && length(cloudflare_load_balancer.this) > 0 ? cloudflare_load_balancer.this[0].name :
    var.dns_provider == "cloudflare" && var.enable_dns_switch && length(cloudflare_record.this) > 0 ? cloudflare_record.this[0].hostname :
    "DNS switch disabled or not configured"
  )
}

output "load_balancer_id" {
  description = "Cloudflare Load Balancer ID"
  value       = try(cloudflare_load_balancer.this[0].id, "")
}

output "primary_pool_id" {
  description = "Cloudflare Primary Pool ID (Homelab)"
  value       = try(cloudflare_load_balancer_pool.homelab_primary[0].id, "")
}

output "fallback_pool_id" {
  description = "Cloudflare Fallback Pool ID (Standby)"
  value       = try(cloudflare_load_balancer_pool.standby_fallback[0].id, "")
}
