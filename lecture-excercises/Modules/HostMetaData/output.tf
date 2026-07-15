resource "local_file" "hostdata" {
  content = templatefile("${path.module}/tpl/hostdata.json", {
    ip4       = hcloud_server.helloServer.ipv4_address,
    ip6       = hcloud_server.helloServer.ipv6_address,
    location = hcloud_server.helloServer.location
  })
  filename = "${path.root}/gen/${var.name}.json"
}

output "hello_ip_addr" {
  value       = hcloud_server.helloServer.ipv4_address
  description = "The server's IPv4 address"
}

output "hello_location" {
  value       = hcloud_server.helloServer.location
  description = "The server's datacenter location"
}




