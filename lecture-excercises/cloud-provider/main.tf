terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.60.1"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.5"
    }
    dns = {
      source = "hashicorp/dns"
    }
    acme = {
      source = "vancluever/acme"
    }

  }

  cloud {
    organization = "simonbreit-dev"
    workspaces {
      name = "software-defined-infrastructure26"
    }
  }
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

provider "dns" {
  update {
    server        = "ns1.hdm-stuttgart.cloud"
    key_name      = "${split(".", var.dnsZone)[0]}.key."
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}

provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

locals {
  server_names = [for i in range(var.serverCount) : format("%s-%d", var.serverBaseName, i + 1)]
}

module "privateSubnet" {
  source = "../Modules/PrivateSubnet"

  private_subnet  = var.privateSubnet
  ssh_public_keys = var.ssh_public_keys
}

resource "hcloud_volume" "volume" {
  for_each = toset(local.server_names)

  name     = "${each.key}-volume"
  size     = 10
  location = "nbg1"
  format   = "xfs"
}

resource "hcloud_volume_attachment" "attach" {
  for_each = toset(local.server_names)

  server_id = module.createHostAmongMetaData[each.key].hello_id
  volume_id = hcloud_volume.volume[each.key].id
  automount = false
}

module "createHostAmongMetaData" {
  for_each = toset(local.server_names)

  source          = "../Modules/HostMetaData"
  name            = each.key
  hcloud_token    = var.hcloud_token
  ssh_public_keys = var.ssh_public_keys
  volume_name     = hcloud_volume.volume[each.key].name
  volume_device   = hcloud_volume.volume[each.key].linux_device
}

module "createSshKnownHosts" {
  for_each = toset(local.server_names)

  depends_on = [module.createHostAmongMetaData, module.dns]
  source     = "../Modules/SshKnownHosts"

  loginUserName  = module.createHostAmongMetaData[each.key].hello_ip_addr
  serverNameOrIp = "${each.key}.${var.dnsZone}"
  targetDir      = each.key
}

module "dns" {
  for_each = toset(local.server_names)

  source       = "../Modules/Dns"
  hcloud_token = var.hcloud_token
  server_ip    = module.createHostAmongMetaData[each.key].hello_ip_addr
  dns_zone     = var.dnsZone
  server_name  = each.key
  dns_secret   = var.dns_secret
}

# Create a firewall that allows ssh access to the server
resource "hcloud_firewall" "sshFw" {
  name = "ssh-firewall-2"
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
