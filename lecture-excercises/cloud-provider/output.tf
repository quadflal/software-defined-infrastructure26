output "hello_ip_addr" {
  value       = { for name, server in module.createHostAmongMetaData : name => server.hello_ip_addr }
  description = "The servers' IPv4 addresses"
}

output "hello_location" {
  value       = { for name, server in module.createHostAmongMetaData : name => server.hello_location }
  description = "The servers' datacenter locations"
}

output "hello_id" {
  value       = { for name, server in module.createHostAmongMetaData : name => server.hello_id }
  description = "The servers' IDs"
}



output "device_string" {
  value = { for name, volume in hcloud_volume.volume : name => volume.linux_device }
}

output "private_subnet" {
  value = {
    gateway_public_ip  = module.privateSubnet.gateway_public_ip
    gateway_private_ip = module.privateSubnet.gateway_private_ip
    intern_private_ip  = module.privateSubnet.intern_private_ip
    gateway_fqdn       = module.privateSubnet.gateway_fqdn
    intern_fqdn        = module.privateSubnet.intern_fqdn
  }
}
