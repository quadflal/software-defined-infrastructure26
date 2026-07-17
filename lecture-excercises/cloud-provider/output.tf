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
