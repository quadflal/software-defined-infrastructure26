terraform {
  required_providers {
    dns = {
      source = "hashicorp/dns"
    }
    acme = {
      source = "vancluever/acme"
    }
  }
}
