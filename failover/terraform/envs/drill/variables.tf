variable "project_name" {
  description = "Project name"
  type        = string
  default     = "k3s-failover"
}

variable "aws_region" {
  description = "AWS Region (ap-southeast-3 for Jakarta, ap-southeast-1 for Singapore)"
  type        = string
  default     = "ap-southeast-3"
}

variable "vpc_cidr" {
  description = "VPC CIDR block for drill"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "Public Subnet CIDR block for drill"
  type        = string
  default     = "10.10.1.0/24"
}

variable "instance_type" {
  description = "EC2 Instance type (e.g. t3.xlarge for drill, c6i.2xlarge for full sizing)"
  type        = string
  default     = "t3.xlarge"
}

variable "ami_architecture" {
  description = "AMI CPU architecture (x86_64 or arm64)"
  type        = string
  default     = "x86_64"
}

variable "key_name" {
  description = "Optional EC2 Key Pair Name for SSH access"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root EBS Volume size in GB"
  type        = number
  default     = 60
}

variable "allocate_eip" {
  description = "Whether to allocate an Elastic IP"
  type        = bool
  default     = false
}

variable "allowed_http_cidr_blocks" {
  description = "Allowed CIDR blocks for HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_cidr_blocks" {
  description = "Allowed CIDR blocks for SSH (leave empty if using AWS SSM)"
  type        = list(string)
  default     = []
}

variable "allowed_k3s_cidr_blocks" {
  description = "Allowed CIDR blocks for K3s API 6443"
  type        = list(string)
  default     = []
}

# K3s & Backup configurations
variable "k3s_version" {
  description = "Target K3s version pinned to baremetal version"
  type        = string
  default     = "v1.30.2+k3s1"
}

variable "b2_endpoint" {
  description = "Backblaze B2 S3 endpoint URL (e.g. https://s3.us-west-004.backblazeb2.com)"
  type        = string
  default     = ""
}

variable "b2_bucket" {
  description = "Backblaze B2 Bucket name where etcd snapshots and backups are stored"
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
  description = "Backblaze B2 Application Key (Secret)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "b2_prefix" {
  description = "Prefix/Folder inside B2 bucket for etcd snapshots"
  type        = string
  default     = "k3s-snapshots"
}

variable "gitops_repo_url" {
  description = "GitOps repository URL containing kubernetes manifests"
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
  description = "DNS Provider (cloudflare, route53, or none)"
  type        = string
  default     = "none"
}

variable "enable_dns_switch" {
  description = "Whether to execute DNS record update in drill"
  type        = bool
  default     = false
}

variable "drill_record_name" {
  description = "Isolated DNS record name for drill (e.g. drill-homelab.example.com)"
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

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to assign to resources"
  type        = map(string)
  default = {
    Environment = "drill"
    ManagedBy   = "Terraform-Failover"
    Purpose     = "Disaster-Recovery-Drill"
  }
}
