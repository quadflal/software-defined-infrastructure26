resource "local_sensitive_file" "private_key" {
  filename        = "${path.root}/gen/private.pem"
  content         = acme_certificate.wildcard.private_key_pem
  file_permission = "0600"
}

resource "local_file" "certificate" {
  filename        = "${path.root}/gen/certificate.pem"
  content         = "${acme_certificate.wildcard.certificate_pem}${acme_certificate.wildcard.issuer_pem}"
  file_permission = "0644"
}
