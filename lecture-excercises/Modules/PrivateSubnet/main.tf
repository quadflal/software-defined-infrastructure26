locals {
  gateway_private_ip = cidrhost(var.private_subnet.ipAndNetmask, 2)
  intern_private_ip  = cidrhost(var.private_subnet.ipAndNetmask, 3)
  gateway_fqdn       = "gateway.${var.private_subnet.dnsDomainName}"
  intern_fqdn        = "intern.${var.private_subnet.dnsDomainName}"
}

resource "hcloud_network" "private" {
  name     = "private-network"
  ip_range = var.network_ip_range
}

resource "hcloud_network_subnet" "private" {
  network_id   = hcloud_network.private.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.private_subnet.ipAndNetmask
}

resource "hcloud_firewall" "gateway" {
  name = "private-subnet-gateway"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "3142"
    source_ips = [var.private_subnet.ipAndNetmask]
  }
}

resource "hcloud_firewall" "intern" {
  name = "private-subnet-intern"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.private_subnet.ipAndNetmask]
  }
}

resource "hcloud_primary_ip" "gateway" {
  name          = "gateway-primary-ip"
  location      = var.location
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
}

resource "tls_private_key" "service_ready" {
  algorithm = "ED25519"
}

resource "hcloud_server" "gateway" {
  depends_on = [hcloud_network_subnet.private]

  name         = "gateway"
  image        = "debian-13"
  server_type  = "cx23"
  location     = var.location
  firewall_ids = [hcloud_firewall.gateway.id]
  user_data = templatefile("${path.module}/scripts/cloud-init-gateway.yml", {
    hostname     = "gateway"
    fqdn         = local.gateway_fqdn
    gateway_fqdn = local.gateway_fqdn
    gateway_ip   = local.gateway_private_ip
    intern_fqdn  = local.intern_fqdn
    intern_ip    = local.intern_private_ip
    ssh_public_keys = concat(
      values(var.ssh_public_keys),
      [tls_private_key.service_ready.public_key_openssh]
    )
  })

  public_net {
    ipv4         = hcloud_primary_ip.gateway.id
    ipv4_enabled = true
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.private.id
    ip         = local.gateway_private_ip
    alias_ips  = []
  }
}

resource "terraform_data" "apt_cacher_ready" {
  triggers_replace = [hcloud_server.gateway.id]

  connection {
    type        = "ssh"
    host        = hcloud_primary_ip.gateway.ip_address
    user        = "devops"
    private_key = tls_private_key.service_ready.private_key_openssh
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "until systemctl is-active --quiet apt-cacher-ng && curl --fail --silent --output /dev/null http://${local.gateway_private_ip}:3142/acng-report.html; do sleep 5; done"
    ]
  }
}

resource "hcloud_server" "intern" {
  depends_on = [hcloud_network_subnet.private, terraform_data.apt_cacher_ready]

  name         = "intern"
  image        = "debian-13"
  server_type  = "cx23"
  location     = var.location
  firewall_ids = [hcloud_firewall.intern.id]
  user_data = templatefile("${path.module}/scripts/cloud-init.yml", {
    hostname        = "intern"
    fqdn            = local.intern_fqdn
    gateway_fqdn    = local.gateway_fqdn
    gateway_ip      = local.gateway_private_ip
    intern_fqdn     = local.intern_fqdn
    intern_ip       = local.intern_private_ip
    apt_proxy       = "http://${local.gateway_private_ip}:3142"
    ssh_public_keys = values(var.ssh_public_keys)
  })

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.private.id
    ip         = local.intern_private_ip
    alias_ips  = []
  }
}
