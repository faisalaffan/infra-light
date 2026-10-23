output "instance_id" {
  description = "Tencent Cloud CVM Instance ID"
  value       = tencentcloud_instance.this.id
}

output "public_ip" {
  description = "Tencent Cloud CVM Public IP"
  value       = tencentcloud_instance.this.public_ip
}

output "private_ip" {
  description = "Tencent Cloud CVM Private IP"
  value       = tencentcloud_instance.this.private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = tencentcloud_vpc.this.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = tencentcloud_subnet.this.id
}

output "security_group_id" {
  description = "Security Group ID"
  value       = tencentcloud_security_group.this.id
}
