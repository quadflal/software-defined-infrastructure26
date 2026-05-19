output "hello_ip_addr" {
  value       = hcloud_server.helloServer.ipv4_address
  description = "The server's IPv4 address"
}

output "hello_location" {
  value       = hcloud_server.helloServer.location
  description = "The server's datacenter location"
}

data "external" "host_key" {
  program = [
    "bash",
    "${path.module}/scripts/ssh-keyscan-json.sh",
    hcloud_server.helloServer.ipv4_address
  ]
}

resource "local_file" "known_hosts_file" {
  depends_on = [hcloud_server.helloServer]
  content = templatefile("${path.module}/templates/known_hosts", {
    host_key = data.external.host_key.result.key
  })
  filename        = "${path.root}/gen/known_hosts"
  file_permission = "0644"
}

resource "local_file" "ssh_script" {
  depends_on = [hcloud_server.helloServer]
  content = templatefile("${path.module}/templates/ssh.sh", {
    server_ip = hcloud_server.helloServer.ipv4_address
    username  = "devops"
  })
  filename        = "${path.root}/bin/ssh"
  file_permission = "0755"
}

resource "local_file" "scp_script" {
  depends_on = [hcloud_server.helloServer]
  content = templatefile("${path.module}/templates/scp.sh", {
    server_ip = hcloud_server.helloServer.ipv4_address
    username  = "devops"
  })
  filename        = "${path.root}/bin/scp"
  file_permission = "0755"
}