terraform {
  required_version = ">= 1.5.0"
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = ">= 1.81.0"
    }
  }
}

# Auto-discover availability zone if not specified
data "tencentcloud_availability_zones_by_product" "this" {
  product = "cvm"
}

# Auto-discover official Ubuntu 22.04 LTS 64-bit image
data "tencentcloud_images" "ubuntu" {
  image_type = ["PUBLIC_IMAGE"]
  os_name    = "Ubuntu Server 22.04 LTS 64bit"
}

locals {
  selected_zone  = var.availability_zone != "" ? var.availability_zone : data.tencentcloud_availability_zones_by_product.this.zones[0].name
  selected_image = var.image_id != "" ? var.image_id : data.tencentcloud_images.ubuntu.images[0].image_id
}

# 1. VPC & Subnet
resource "tencentcloud_vpc" "this" {
  name       = "${var.project_name}-${var.environment}-vpc"
  cidr_block = var.vpc_cidr
  tags       = var.tags
}

resource "tencentcloud_subnet" "this" {
  vpc_id            = tencentcloud_vpc.this.id
  name              = "${var.project_name}-${var.environment}-subnet"
  cidr_block        = var.subnet_cidr
  availability_zone = local.selected_zone
  tags              = var.tags
}

# 2. Security Group
resource "tencentcloud_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for ${var.project_name} failover node"
}

resource "tencentcloud_security_group_rule" "ssh" {
  security_group_id = tencentcloud_security_group.this.id
  type              = "ingress"
  cidr_ip           = var.allowed_ssh_ip != "" ? var.allowed_ssh_ip : "0.0.0.0/0"
  ip_protocol       = "TCP"
  port_range        = "22"
  policy            = "ACCEPT"
  description       = "SSH Access"
}

resource "tencentcloud_security_group_rule" "http" {
  security_group_id = tencentcloud_security_group.this.id
  type              = "ingress"
  cidr_ip           = "0.0.0.0/0"
  ip_protocol       = "TCP"
  port_range        = "80"
  policy            = "ACCEPT"
  description       = "HTTP Ingress"
}

resource "tencentcloud_security_group_rule" "https" {
  security_group_id = tencentcloud_security_group.this.id
  type              = "ingress"
  cidr_ip           = "0.0.0.0/0"
  ip_protocol       = "TCP"
  port_range        = "443"
  policy            = "ACCEPT"
  description       = "HTTPS Ingress"
}

resource "tencentcloud_security_group_rule" "tailscale" {
  security_group_id = tencentcloud_security_group.this.id
  type              = "ingress"
  cidr_ip           = "0.0.0.0/0"
  ip_protocol       = "UDP"
  port_range        = "41641"
  policy            = "ACCEPT"
  description       = "Tailscale / WireGuard"
}

resource "tencentcloud_security_group_rule" "k3s_api" {
  security_group_id = tencentcloud_security_group.this.id
  type              = "ingress"
  cidr_ip           = "0.0.0.0/0"
  ip_protocol       = "TCP"
  port_range        = "6443"
  policy            = "ACCEPT"
  description       = "K3s API Access"
}

resource "tencentcloud_security_group_rule" "egress_all" {
  security_group_id = tencentcloud_security_group.this.id
  type              = "egress"
  cidr_ip           = "0.0.0.0/0"
  policy            = "ACCEPT"
  description       = "Allow all outbound traffic"
}

# 3. Tencent Cloud CVM Instance
resource "tencentcloud_instance" "this" {
  instance_name              = "${var.project_name}-${var.environment}"
  hostname                   = "${var.project_name}-${var.environment}"
  availability_zone          = local.selected_zone
  image_id                   = local.selected_image
  instance_type              = var.instance_type
  system_disk_type           = var.system_disk_type
  system_disk_size           = var.system_disk_size
  allocate_public_ip         = true
  internet_max_bandwidth_out = var.bandwidth
  vpc_id                     = tencentcloud_vpc.this.id
  subnet_id                  = tencentcloud_subnet.this.id
  orderly_security_groups    = [tencentcloud_security_group.this.id]

  user_data_raw              = var.user_data

  tags = var.tags
}
