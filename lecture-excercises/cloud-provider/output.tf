output "hello_ip_addr" {
  value       = hcloud_server.helloServer.ipv4_address
  description = "The server's IPv4 address"
}

output "hello_location" {
  value       = hcloud_server.helloServer.location
  description = "The server's datacenter location"
}
