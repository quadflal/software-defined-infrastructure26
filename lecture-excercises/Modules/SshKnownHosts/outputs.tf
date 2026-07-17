data "external" "host_key" {
  depends_on = [var.serverNameOrIp]
  program = [
    "bash",
    "${path.module}/scripts/ssh-keyscan-json.sh",
    var.serverNameOrIp
  ]
}

resource "local_file" "known_hosts_file" {
  content = templatefile("${path.module}/tpl/known_hosts", {
    host_key = data.external.host_key.result.key
  })
  filename        = "${path.root}/gen/known_hosts"
  file_permission = "0644"
}

resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/tpl/ssh.sh", {
    server_host = var.serverNameOrIp
    username    = "devops"
  })
  filename        = "${path.root}/bin/ssh"
  file_permission = "0755"
}

resource "local_file" "scp_script" {
  content = templatefile("${path.module}/tpl/scp.sh", {
    server_host = var.serverNameOrIp
    username    = "devops"
  })
  filename        = "${path.root}/bin/scp"
  file_permission = "0755"
}
