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

# --- Cloudflare Load Balancer & Multi-Tunnel Steering ---
variable "enable_load_balancer" {
  description = "Whether to deploy Cloudflare Load Balancer instead of simple A-record"
  type        = bool
  default     = false
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (required for Load Balancer pools)"
  type        = string
  default     = ""
}

variable "homelab_origin_address" {
  description = "Origin address for Homelab Primary (e.g. <uuid>.cfargotunnel.com)"
  type        = string
  default     = ""
}

variable "standby_origin_address" {
  description = "Origin address for Standby Cloud (e.g. <uuid>.cfargotunnel.com or IP)"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Path for health check probe"
  type        = string
  default     = "/healthz"
}

variable "health_check_interval" {
  description = "Health check probe interval in seconds"
  type        = number
  default     = 60
}
