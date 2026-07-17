terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.60.1"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}
