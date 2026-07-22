output "gateway_public_ip" {
  value       = hcloud_primary_ip.gateway.ip_address
  description = "Public IPv4 address used to SSH into the gateway"
}

output "gateway_private_ip" {
  value       = local.gateway_private_ip
  description = "Private IPv4 address of the gateway"
}

output "intern_private_ip" {
  value       = local.intern_private_ip
  description = "Private IPv4 address of the intern host"
}

output "gateway_fqdn" {
  value       = local.gateway_fqdn
  description = "Locally resolved DNS name of the gateway"
}

output "intern_fqdn" {
  value       = local.intern_fqdn
  description = "Locally resolved DNS name of the intern host"
}
