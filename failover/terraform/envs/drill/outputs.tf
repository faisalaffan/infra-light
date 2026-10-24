output "instance_id" {
  description = "Drill EC2 Instance ID"
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "Drill EC2 Public IP address"
  value       = module.compute.public_ip
}

output "private_ip" {
  description = "Drill EC2 Private IP address"
  value       = module.compute.private_ip
}

output "ssm_connect_command" {
  description = "Command to connect securely via AWS Systems Manager Session Manager"
  value       = "aws ssm start-session --target ${module.compute.instance_id} --region ${var.aws_region}"
}

output "check_restore_logs_command" {
  description = "Command to view live restore logs on target instance"
  value       = "tail -f /var/log/failover/restore.log"
}

output "drill_dns_record" {
  description = "Drill test DNS record"
  value       = module.dns.record_fqdn
}
