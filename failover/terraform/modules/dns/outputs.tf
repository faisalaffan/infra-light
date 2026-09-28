output "record_fqdn" {
  description = "FQDN of the configured DNS record"
  value = (
    var.dns_provider == "cloudflare" && var.enable_dns_switch && length(cloudflare_record.this) > 0 ? cloudflare_record.this[0].hostname :
    var.dns_provider == "route53" && var.enable_dns_switch && length(aws_route53_record.this) > 0 ? aws_route53_record.this[0].fqdn :
    "DNS switch disabled or not configured"
  )
}
