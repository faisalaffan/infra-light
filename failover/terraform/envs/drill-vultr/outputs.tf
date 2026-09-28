output "instance_id" {
  description = "Vultr Drill Instance ID"
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "Vultr Drill Instance Public IP"
  value       = module.compute.public_ip
}

output "ssh_connect_command" {
  description = "Command to connect via SSH"
  value       = "ssh root@${module.compute.public_ip}"
}

output "check_restore_logs_command" {
  description = "Command to view restore progress"
  value       = "ssh root@${module.compute.public_ip} 'tail -f /var/log/failover/restore.log'"
}

output "drill_dns_record" {
  description = "Drill DNS Record"
  value       = module.dns.record_fqdn
}
