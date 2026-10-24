variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "k3s-failover"
}

variable "environment" {
  description = "Environment name (drill or prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the instance will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be deployed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.xlarge"
}

variable "ami_architecture" {
  description = "Architecture for AMI lookup (x86_64 or arm64)"
  type        = string
  default     = "x86_64"
}

variable "custom_ami_id" {
  description = "Custom AMI ID if bypassing automatic Ubuntu AMI lookup"
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "IAM instance profile to attach to the instance"
  type        = string
  default     = null
}

variable "key_name" {
  description = "SSH key pair name (optional, SSM is preferred)"
  type        = string
  default     = ""
}

variable "user_data_base64" {
  description = "Base64-encoded user-data/cloud-init script"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 100
}

variable "root_volume_type" {
  description = "Root volume EBS type (e.g. gp3)"
  type        = string
  default     = "gp3"
}

variable "allocate_eip" {
  description = "Whether to allocate an Elastic IP for the instance"
  type        = bool
  default     = false
}

variable "allowed_http_cidr_blocks" {
  description = "CIDR blocks allowed for HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH"
  type        = list(string)
  default     = []
}

variable "allowed_k3s_cidr_blocks" {
  description = "CIDR blocks allowed for K3s API 6443"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to assign to resources"
  type        = map(string)
  default     = {}
}
