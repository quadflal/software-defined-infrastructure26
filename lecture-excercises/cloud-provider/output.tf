output "hello_ip_addr" {
  value       = module.createHostAmongMetaData.hello_ip_addr
  description = "The server's IPv4 address"
}

output "hello_location" {
  value       = module.createHostAmongMetaData.hello_location
  description = "The server's datacenter location"
}

output "hello_id" {
  value = module.createHostAmongMetaData.hello_id
  description = "The servers´s ID"
}



output "device_string" {
  value = hcloud_volume.volume01.linux_device
}