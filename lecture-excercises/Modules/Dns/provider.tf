terraform {
  required_providers {
    dns = {
      source = "hashicorp/dns"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.60.1"
    }
    acme = {
      source = "vancluever/acme"
    }
  }
}
