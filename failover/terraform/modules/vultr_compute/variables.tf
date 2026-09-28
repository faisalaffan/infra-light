variable "project_name" {
  description = "Project name"
  type        = string
  default     = "k3s-failover"
}

variable "environment" {
  description = "Environment name (drill or prod)"
  type        = string
}

variable "region" {
  description = "Vultr DC Region (cgk = Jakarta, sgp = Singapore)"
  type        = string
  default     = "cgk"
}

variable "plan" {
  description = "Vultr Plan ID (e.g. voc-g-4c-16gb-150s-amd, voc-g-8c-32gb-300s-amd, vc2-4c-8gb)"
  type        = string
  default     = "voc-g-4c-16gb-150s-amd"
}

variable "os_id" {
  description = "Operating system ID (1743 = Ubuntu 22.04 x64)"
  type        = number
  default     = 1743
}

variable "user_data" {
  description = "Raw cloud-init user data script"
  type        = string
  default     = ""
}

variable "ssh_key_ids" {
  description = "List of SSH Key IDs registered in Vultr"
  type        = list(string)
  default     = []
}

variable "ddos_protection" {
  description = "Enable DDoS protection"
  type        = bool
  default     = false
}

variable "allowed_ssh_ip" {
  description = "Subnet/IP allowed for SSH (e.g. 1.2.3.4)"
  type        = string
  default     = ""
}

variable "allowed_ssh_subnet_size" {
  description = "Subnet mask size for SSH (e.g. 32 for single IP)"
  type        = number
  default     = 32
}

variable "allowed_k3s_ip" {
  description = "Subnet/IP allowed for K3s API 6443"
  type        = string
  default     = ""
}

variable "allowed_k3s_subnet_size" {
  description = "Subnet mask size for K3s API"
  type        = number
  default     = 32
}

variable "tags" {
  description = "Tags for the instance"
  type        = list(string)
  default     = ["failover", "k3s"]
}
