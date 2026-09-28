variable "environment" {
  description = "Environment name (drill or prod)"
  type        = string
}

variable "dns_provider" {
  description = "DNS Provider to manage (cloudflare, route53, or none)"
  type        = string
  default     = "none"
}

variable "enable_dns_switch" {
  description = "Whether to actually update the DNS record"
  type        = bool
  default     = false
}

variable "record_name" {
  description = "DNS record name/subdomain"
  type        = string
  default     = ""
}

variable "target_ip" {
  description = "Target IP address to point the record to"
  type        = string
  default     = ""
}

variable "ttl" {
  description = "TTL for DNS record (60 seconds recommended for failover)"
  type        = number
  default     = 60
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
  default     = ""
}

variable "cloudflare_proxied" {
  description = "Whether to enable Cloudflare proxy (orange cloud)"
  type        = bool
  default     = true
}

variable "route53_zone_id" {
  description = "AWS Route53 Hosted Zone ID"
  type        = string
  default     = ""
}
