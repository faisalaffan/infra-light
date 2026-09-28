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
  description = "Vultr Plan ID for drill test"
  type        = string
  default     = "voc-g-4c-16gb-150s-amd"
}

variable "ssh_key_ids" {
  description = "List of SSH Key IDs registered in Vultr account"
  type        = list(string)
  default     = []
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
  default     = "none"
}

variable "enable_dns_switch" {
  description = "Whether to execute DNS record update in drill"
  type        = bool
  default     = false
}

variable "drill_record_name" {
  description = "Isolated DNS record name for drill"
  type        = string
  default     = "drill.example.com"
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
