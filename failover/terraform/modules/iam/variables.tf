variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "k3s-failover"
}

variable "environment" {
  description = "Environment name (drill or prod)"
  type        = string
}

variable "tags" {
  description = "Tags to assign to resources"
  type        = map(string)
  default     = {}
}
