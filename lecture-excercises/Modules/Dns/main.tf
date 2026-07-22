locals {
  tsig_key_name = "${split(".", var.dns_zone)[0]}.key."
}

resource "dns_a_record_set" "helloRecord" {
  for_each = var.server_addresses

  zone      = "${var.dns_zone}." # The dot matters!
  name      = each.key
  addresses = toset([each.value])
  ttl       = 300
}

resource "tls_private_key" "acme_account" {

  algorithm = "RSA"

}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.acme_account.private_key_pem
  email_address   = "sb322@hdm-stuttgart.de"

}

resource "acme_certificate" "wildcard" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = var.dns_zone
  subject_alternative_names = [
    "*.${var.dns_zone}"
  ]
  dns_challenge {
    provider = "rfc2136"
    config = {
      RFC2136_NAMESERVER     = "ns1.hdm-stuttgart.cloud"
      RFC2136_TSIG_ALGORITHM = "hmac-sha512"
      RFC2136_TSIG_KEY       = local.tsig_key_name
      RFC2136_TSIG_SECRET    = var.dns_secret
    }
  }
}
