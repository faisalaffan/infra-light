output "instance_id" {
  description = "Tencent CVM Instance ID"
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "Tencent CVM Instance Public IP"
  value       = module.compute.public_ip
}

output "ssh_connect_command" {
  description = "Command to connect via SSH"
  value       = "ssh root@${module.compute.public_ip}"
}

output "check_restore_logs_command" {
  description = "Command to live stream restore logs"
  value       = "ssh root@${module.compute.public_ip} 'tail -f /var/log/failover/restore.log'"
}

output "prod_dns_record" {
  description = "Production DNS record status"
  value       = module.dns.record_fqdn
}
