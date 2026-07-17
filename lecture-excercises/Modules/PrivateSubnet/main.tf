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

resource "hcloud_server" "gateway" {
  depends_on = [hcloud_network_subnet.private]

  name         = "gateway"
  image        = "debian-13"
  server_type  = "cx23"
  location     = var.location
  firewall_ids = [hcloud_firewall.gateway.id]
  user_data = templatefile("${path.module}/scripts/cloud-init.yml", {
    hostname        = "gateway"
    fqdn            = local.gateway_fqdn
    gateway_fqdn    = local.gateway_fqdn
    gateway_ip      = local.gateway_private_ip
    intern_fqdn     = local.intern_fqdn
    intern_ip       = local.intern_private_ip
    ssh_public_keys = values(var.ssh_public_keys)
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private.id
    ip         = local.gateway_private_ip
    alias_ips  = []
  }
}

resource "hcloud_server" "intern" {
  depends_on = [hcloud_network_subnet.private]

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
