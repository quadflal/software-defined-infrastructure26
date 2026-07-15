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

module "createHostAmongMetaData" {
  source = "../Modules/HostMetaData"
  name  = "myserver"
  hcloud_token = var.hcloud_token
  ssh_public_keys = var.ssh_public_keys
}

module "createSshKnownHosts" {
  depends_on = [module.createHostAmongMetaData]
  source = "../Modules/SshKnownHosts"
  loginUserName        = module.createHostAmongMetaData.hello_ip_addr
  serverNameOrIp       = module.createHostAmongMetaData.hello_ip_addr
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



