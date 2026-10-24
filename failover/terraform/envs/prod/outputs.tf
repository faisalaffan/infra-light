output "instance_id" {
  description = "Production Failover EC2 Instance ID"
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "Production Failover EC2 Public IP address"
  value       = module.compute.public_ip
}

output "private_ip" {
  description = "Production Failover EC2 Private IP address"
  value       = module.compute.private_ip
}

output "ssm_connect_command" {
  description = "Command to connect securely via AWS Systems Manager Session Manager"
  value       = "aws ssm start-session --target ${module.compute.instance_id} --region ${var.aws_region}"
}

output "prod_dns_record" {
  description = "Production DNS record status"
  value       = module.dns.record_fqdn
}
