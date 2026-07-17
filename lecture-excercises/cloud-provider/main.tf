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

resource "hcloud_volume" "volume01" {
  name     = "volume01"
  size     = 10
  location = "nbg1"
  format   = "xfs"
}
resource "hcloud_volume_attachment" "attach" {
  server_id = module.createHostAmongMetaData.hello_id
  volume_id = hcloud_volume.volume01.id
  automount = false
}

module "createHostAmongMetaData" {
  source          = "../Modules/HostMetaData"
  name            = "myserver"
  hcloud_token    = var.hcloud_token
  ssh_public_keys = var.ssh_public_keys
  volume_name     = hcloud_volume.volume01.name
  volume_device   = hcloud_volume.volume01.linux_device
}

module "createSshKnownHosts" {
  depends_on     = [module.createHostAmongMetaData]
  source         = "../Modules/SshKnownHosts"
  loginUserName  = module.createHostAmongMetaData.hello_ip_addr
  serverNameOrIp = module.createHostAmongMetaData.hello_ip_addr
}

module "dns" {
  source       = "../Modules/Dns"
  hcloud_token = var.hcloud_token
  server_ip    = module.createHostAmongMetaData.hello_ip_addr
  dns_zone     = var.dns_zone
  server_names = var.server_names
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
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "sshFw" {
  firewall_id = hcloud_firewall.sshFw.id
  server_ids  = [module.createHostAmongMetaData.hello_id]
}
