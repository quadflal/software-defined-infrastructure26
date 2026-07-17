data "external" "host_key" {
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
  filename             = "${path.root}/${var.targetDir}/gen/known_hosts"
  file_permission      = "0644"
  directory_permission = "0755"
}

resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/tpl/ssh.sh", {
    server_host = var.serverNameOrIp
    username    = "devops"
  })
  filename             = "${path.root}/${var.targetDir}/bin/ssh"
  file_permission      = "0755"
  directory_permission = "0755"
}

resource "local_file" "scp_script" {
  content = templatefile("${path.module}/tpl/scp.sh", {
    server_host = var.serverNameOrIp
    username    = "devops"
  })
  filename             = "${path.root}/${var.targetDir}/bin/scp"
  file_permission      = "0755"
  directory_permission = "0755"
}
