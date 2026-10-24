variable "project_name" {
  description = "Project name"
  type        = string
  default     = "k3s-failover"
}

variable "vultr_api_key" {
  description = "Vultr API Key"
  type        = string
  sensitive   = true
}

variable "vultr_region" {
  description = "Vultr Region (cgk for Jakarta, sgp for Singapore)"
  type        = string
  default     = "cgk"
}

variable "vultr_plan" {
  description = "Vultr Plan ID for production capacity (16 vCPU, 64GB RAM, 960GB NVMe)"
  type        = string
  default     = "vx1-g-16c-64g-960s"
}

variable "ssh_key_ids" {
  description = "List of SSH Key IDs registered in Vultr account"
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "SSH Public Key content to authorize in cloud-init"
  type        = string
  default     = ""
}

variable "allowed_ssh_ip" {
  description = "Subnet/IP allowed for SSH"
  type        = string
  default     = ""
}

variable "allowed_ssh_subnet_size" {
  description = "Subnet mask size for SSH"
  type        = number
  default     = 32
}

# K3s & Backup configurations
variable "k3s_version" {
  description = "Target K3s version matching baremetal"
  type        = string
  default     = "v1.30.2+k3s1"
}

variable "k3s_token" {
  description = "K3s cluster token"
  type        = string
  default     = "k3s-local-dev-token-2026"
  sensitive   = true
}

variable "b2_endpoint" {
  description = "Backblaze B2 S3 endpoint URL"
  type        = string
  default     = ""
}

variable "b2_bucket" {
  description = "Backblaze B2 Bucket name"
  type        = string
  default     = ""
}

variable "b2_key_id" {
  description = "Backblaze B2 Application Key ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "b2_application_key" {
  description = "Backblaze B2 Application Key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "b2_prefix" {
  description = "Prefix for snapshots inside B2 bucket"
  type        = string
  default     = "k3s-snapshots"
}

variable "restic_password" {
  description = "Restic repository password for decrypting Persistent Volumes from Backblaze B2"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
  default     = ""
}

variable "gitops_branch" {
  description = "Branch for GitOps manifests"
  type        = string
  default     = "main"
}

# DNS Switcher configurations
variable "dns_provider" {
  description = "DNS Provider (cloudflare or none)"
  type        = string
  default     = "cloudflare"
}

variable "enable_dns_switch" {
  description = "Whether to execute production DNS record update"
  type        = bool
  default     = false
}

variable "prod_record_name" {
  description = "Production DNS record name"
  type        = string
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
  default     = ""
}

# --- Cloudflare Load Balancer Dual-Tunnel Steering ---
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

variable "vultr_origin_address" {
  description = "Origin address for Standby Vultr (e.g. <uuid>.cfargotunnel.com)"
  type        = string
  default     = ""
}
