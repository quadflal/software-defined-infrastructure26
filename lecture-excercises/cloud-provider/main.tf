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
  required_version = "1.14.9"

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

resource "hcloud_ssh_key" "ssh_key" {
  for_each = var.ssh_public_keys
  name       = each.key
  public_key = each.value
}
# Create a server
resource "hcloud_server" "helloServer" {
  name         = "hello2"
  image        = "debian-13"
  server_type  = "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id]
  user_data = templatefile("scripts/cloud-init.yml", {
    ssh_public_keys = values(var.ssh_public_keys)
  })
  ssh_keys = [
    for key in hcloud_ssh_key.ssh_key : key.id
  ]
}


