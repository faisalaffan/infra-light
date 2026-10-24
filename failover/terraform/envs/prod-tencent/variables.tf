variable "project_name" {
  description = "Project name"
  type        = string
  default     = "k3s-failover"
}

variable "tencentcloud_secret_id" {
  description = "Tencent Cloud SecretId"
  type        = string
  sensitive   = true
}

variable "tencentcloud_secret_key" {
  description = "Tencent Cloud SecretKey"
  type        = string
  sensitive   = true
}

variable "tencentcloud_region" {
  description = "Tencent Cloud Region (e.g. ap-jakarta, ap-singapore)"
  type        = string
  default     = "ap-jakarta"
}

variable "tencentcloud_zone" {
  description = "Tencent Cloud Availability Zone. If empty, auto-selected."
  type        = string
  default     = ""
}

variable "tencent_instance_type" {
  description = "Tencent CVM Instance Type for production failover"
  type        = string
  default     = "SA2.4XLARGE64" # 16 vCPU, 64 GB AMD (or S5.4XLARGE64)
}

variable "ssh_public_key" {
  description = "SSH Public Key content to authorize in cloud-init"
  type        = string
  default     = ""
}

variable "allowed_ssh_ip" {
  description = "CIDR allowed for SSH. Defaults to 0.0.0.0/0"
  type        = string
  default     = "0.0.0.0/0"
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
  default     = "none"
}

variable "prod_record_name" {
  description = "Production DNS record name"
  type        = string
  default     = "homelab.example.com"
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

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (for Load Balancer)"
  type        = string
  default     = ""
}

variable "enable_load_balancer" {
  description = "Enable Cloudflare Load Balancer failover steering"
  type        = bool
  default     = false
}

variable "homelab_origin_address" {
  description = "Primary homelab origin IP or Argo Tunnel hostname"
  type        = string
  default     = ""
}

variable "standby_origin_address" {
  description = "Standby origin IP or Argo Tunnel hostname"
  type        = string
  default     = ""
}
