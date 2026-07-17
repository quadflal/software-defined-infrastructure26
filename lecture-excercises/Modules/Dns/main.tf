resource "dns_a_record_set" "helloRecord" {
  zone = "${var.dns_zone}." # The dot matters!
  name = var.server_name
  addresses = toset([var.server_ip])
  ttl = 300
}

resource "dns_a_record_set" "alias" {
  for_each  = toset(distinct(var.server_aliases))
  zone      = "${var.dns_zone}."  # The dot matters!
  name      = each.value
  addresses = toset([var.server_ip])
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
  account_key_pem =acme_registration.registration.account_key_pem
  common_name = "g4.sdi.hdm-stuttgart.cloud"
  subject_alternative_names = [
    "*.g4.sdi.hdm-stuttgart.cloud"
  ]
  dns_challenge {
    provider = "rfc2136"
    config = {
      RFC2136_NAMESERVER     = "ns1.hdm-stuttgart.cloud"
      RFC2136_TSIG_ALGORITHM = "hmac-sha512"
      RFC2136_TSIG_KEY       = "g4.key."
      RFC2136_TSIG_SECRET    = var.dns_secret
    }
  }
}