resource "hcloud_ssh_key" "ssh_key" {
  for_each = var.ssh_public_keys
  name       = each.key
  public_key = each.value
}

resource "hcloud_server" "helloServer" {
  name         = var.name
  image        = "debian-13"
  server_type  = "cx23"
  location     = "nbg1"
  user_data = templatefile("${path.module}/scripts/cloud-init.yml", { //pass it here
    ssh_public_keys = values(var.ssh_public_keys)
    volume_device = var.volume_device
    volume_name = var.volume_name
  })
}
