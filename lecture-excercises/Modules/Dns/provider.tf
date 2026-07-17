terraform {
  required_providers {
    dns = {
      source = "hashicorp/dns"
    },
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.60.1"
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
    key_name      = "g4.key."  # Corresponding to your group e.g., Group 12
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}
