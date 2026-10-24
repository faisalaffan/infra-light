output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance or Elastic IP"
  value       = var.allocate_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "Security Group ID attached to the instance"
  value       = aws_security_group.this.id
}
