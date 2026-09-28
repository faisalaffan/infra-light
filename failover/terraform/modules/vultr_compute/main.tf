terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.19"
    }
  }
}

# Firewall Group
resource "vultr_firewall_group" "this" {
  description = "${var.project_name}-${var.environment}-fw"
}

# HTTP (80)
resource "vultr_firewall_rule" "http" {
  firewall_group_id = vultr_firewall_group.this.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "80"
  notes             = "HTTP Ingress"
}

# HTTPS (443)
resource "vultr_firewall_rule" "https" {
  firewall_group_id = vultr_firewall_group.this.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "443"
  notes             = "HTTPS Ingress"
}

# Optional Restricted SSH (22)
resource "vultr_firewall_rule" "ssh" {
  count             = var.allowed_ssh_ip != "" ? 1 : 0
  firewall_group_id = vultr_firewall_group.this.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = var.allowed_ssh_ip
  subnet_size       = var.allowed_ssh_subnet_size
  port              = "22"
  notes             = "SSH Access (Restricted)"
}

# Optional Restricted K3s API (6443)
resource "vultr_firewall_rule" "k3s_api" {
  count             = var.allowed_k3s_ip != "" ? 1 : 0
  firewall_group_id = vultr_firewall_group.this.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = var.allowed_k3s_ip
  subnet_size       = var.allowed_k3s_subnet_size
  port              = "6443"
  notes             = "K3s API Access"
}

# Tailscale / WireGuard (UDP 41641)
resource "vultr_firewall_rule" "tailscale" {
  firewall_group_id = vultr_firewall_group.this.id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "41641"
  notes             = "Tailscale / WireGuard"
}

# Vultr Instance (VPS)
resource "vultr_instance" "this" {
  plan              = var.plan
  region            = var.region
  os_id             = var.os_id # Default 1743 (Ubuntu 22.04 LTS x64)
  label             = "${var.project_name}-${var.environment}"
  hostname          = "${var.project_name}-${var.environment}"
  firewall_group_id = vultr_firewall_group.this.id
  enable_ipv6       = false
  backups           = "disabled" # Cold-standby does not need provider recurring backup
  ddos_protection   = var.ddos_protection
  ssh_key_ids       = var.ssh_key_ids
  user_data         = var.user_data
  tags              = var.tags
}
