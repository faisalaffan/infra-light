terraform {
  required_version = ">= 1.5.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Cloudflare DNS Record (when dns_provider == "cloudflare")
resource "cloudflare_record" "this" {
  count   = var.dns_provider == "cloudflare" && var.enable_dns_switch ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.record_name
  value   = var.target_ip
  type    = "A"
  ttl     = var.ttl
  proxied = var.cloudflare_proxied
  comment = "Managed by Terraform Failover Pipeline (${var.environment})"
}

# AWS Route53 Record (when dns_provider == "route53")
resource "aws_route53_record" "this" {
  count   = var.dns_provider == "route53" && var.enable_dns_switch ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.record_name
  type    = "A"
  ttl     = var.ttl
  records = [var.target_ip]
}
