output "instance_id" {
  description = "Production Vultr Instance ID"
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "Production Vultr Instance Public IP"
  value       = module.compute.public_ip
}

output "ssh_connect_command" {
  description = "Command to connect via SSH"
  value       = "ssh root@${module.compute.public_ip}"
}

output "prod_dns_record" {
  description = "Production DNS record status"
  value       = module.dns.record_fqdn
}
