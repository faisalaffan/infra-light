variable "project_name" {
  description = "Project name"
  type        = string
  default     = "k3s-failover"
}

variable "environment" {
  description = "Environment name (drill or prod)"
  type        = string
}

variable "availability_zone" {
  description = "Tencent Cloud Availability Zone (e.g. ap-jakarta-1, ap-singapore-1). If empty, auto-selected."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "Tencent CVM Instance Type (e.g. S5.MEDIUM4, SA2.LARGE8, S5.4XLARGE64)"
  type        = string
  default     = "SA2.LARGE8"
}

variable "image_id" {
  description = "Custom image ID. If empty, latest Ubuntu 22.04 LTS is selected."
  type        = string
  default     = ""
}

variable "system_disk_type" {
  description = "System disk type (CLOUD_HSSD, CLOUD_BSSD, CLOUD_PREMIUM)"
  type        = string
  default     = "CLOUD_HSSD"
}

variable "system_disk_size" {
  description = "System disk size in GB"
  type        = number
  default     = 150
}

variable "bandwidth" {
  description = "Internet max bandwidth out in Mbps (Tencent max on traffic billing is 200)"
  type        = number
  default     = 200
}

variable "user_data" {
  description = "Cloud-init raw user data string"
  type        = string
  default     = ""
}

variable "allowed_ssh_ip" {
  description = "CIDR allowed for SSH. Defaults to 0.0.0.0/0"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
