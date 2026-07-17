# Task 25 - Creating a web certificate

### Extend the DNS module to:

- Configure the ACME Terraform provider against Let's Encrypt's staging environment.
- Register an ACME account with a generated RSA account key.
- Use an RFC2136 DNS-01 challenge to request a certificate.
- Cover both the zone apex and every direct hostname beneath that zone.
- Generate `gen/private.pem` and `gen/certificate.pem` for later web-server installation.

This documentation covers only the certificate-related Task 25 changes. Resources created by the preceding DNS exercises are not repeated.

> **Caution:** Always use the Let's Encrypt staging endpoint during this exercise. Staging certificates are not publicly trusted, but the staging service has more generous limits for testing and troubleshooting.

## Solution

### 1. Add the ACME provider

The `required_providers` block in `Modules/Dns/provider.tf` includes `vancluever/acme` without a fixed version constraint:

```terraform
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
      source  = "vancluever/acme"
    }
  }
}
```

This avoids selecting an ACME provider older than the required version `2.23.2`. After initialization, `.terraform.lock.hcl` records the selected version `2.48.3` for this project.

Initialize the new provider:

```bash
terraform init
```

### 2. Select the Let's Encrypt staging service

The ACME provider configuration in `Modules/Dns/provider.tf` uses the staging directory explicitly:

```terraform
provider "acme" {

  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"

}
```

The production URL `https://acme-v02.api.letsencrypt.org/directory` must not be used for this exercise.

### 3. Keep the RFC2136 secret outside the source code

The existing module input in `Modules/Dns/variables.tf` declares the TSIG secret as sensitive:

```terraform
variable "dns_secret" {
  type      = string
  nullable  = false
  sensitive = true
}
```

The secret is passed into the DNS module from `cloud-provider/main.tf` as part of the existing module call. Its real value must not be committed to the repository.

### 4. Generate an ACME account key

The following resource in `Modules/Dns/main.tf` generates an RSA private key for the ACME account:

```terraform
resource "tls_private_key" "acme_account" {

  algorithm = "RSA"

}
```

This account key identifies the client to the ACME service. It is separate from the private key generated for the wildcard certificate.

### 5. Register the ACME account

The registration resource uses the generated account key:

```terraform
resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.acme_account.private_key_pem
  email_address   = "sb322@hdm-stuttgart.de"

}
```

The reference to `tls_private_key.acme_account.private_key_pem` creates an implicit dependency, ensuring that Terraform generates the key before registering the account.

### 6. Request the apex and wildcard certificate

The certificate resource in `Modules/Dns/main.tf` is:

```terraform
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
```

The requested certificate covers both required name patterns:

- `common_name` covers the zone apex `g4.sdi.hdm-stuttgart.cloud`.
- `subject_alternative_names` covers `*.g4.sdi.hdm-stuttgart.cloud`, including hosts such as `www.g4.sdi.hdm-stuttgart.cloud` and `mail.g4.sdi.hdm-stuttgart.cloud`.

A wildcard name does not cover the zone apex, so both entries are necessary.

The RFC2136 challenge configuration gives the ACME provider the name server and TSIG credentials needed to create and remove temporary `_acme-challenge` TXT records. Let's Encrypt checks those records to validate control of the requested names.

### 7. Generate the PEM files

The resources in `Modules/Dns/outputs.tf` write the certificate material into the root module's `gen` directory:

```terraform
resource "local_sensitive_file" "private_key" {
  filename        = "${path.root}/gen/private.pem"
  content         = acme_certificate.wildcard.private_key_pem
  file_permission = "0600"
}

resource "local_file" "certificate" {
  filename        = "${path.root}/gen/certificate.pem"
  content         = acme_certificate.wildcard.certificate_pem
  file_permission = "0644"
}
```

`path.root` resolves to the `cloud-provider` root module, producing:

```text
cloud-provider/gen/
├── certificate.pem
└── private.pem
```

The private key uses `local_sensitive_file` and permission mode `0600`, limiting access to its owner. The certificate is public material and uses permission mode `0644`.

References to `acme_certificate.wildcard` make both files depend implicitly on successful certificate issuance.

## Test the result

Review the changes before contacting the staging ACME service:

```bash
terraform plan
```

Output:

```text
Terraform will perform the following actions:
  # module.dns.tls_private_key.acme_account will be created
  # module.dns.acme_registration.registration will be created
  # module.dns.acme_certificate.wildcard will be created
  # module.dns.local_sensitive_file.private_key will be created
  # module.dns.local_file.certificate will be created

Plan: <add-count> to add, <change-count> to change, <destroy-count> to destroy.
```

Confirm again that the plan uses the staging ACME directory, then apply it:

```bash
terraform apply
```

Output:

```text
module.dns.tls_private_key.acme_account: Creation complete
module.dns.acme_registration.registration: Creation complete
module.dns.acme_certificate.wildcard: Creation complete
module.dns.local_sensitive_file.private_key: Creation complete
module.dns.local_file.certificate: Creation complete

Apply complete! Resources: <add-count> added, <change-count> changed, <destroy-count> destroyed.
```

### Verify the generated files

Check that both files exist with the intended permissions:

```bash
ls -l gen/private.pem gen/certificate.pem
```

Output:

```text
-rw-r--r-- <owner> <group> <size> <date> gen/certificate.pem
-rw------- <owner> <group> <size> <date> gen/private.pem
```

Inspect the staging certificate without printing the private key:

```bash
openssl x509 -in gen/certificate.pem -noout -issuer -subject -dates -ext subjectAltName
```

Output:

```text
issuer=<Let's Encrypt staging issuer>
subject=<certificate subject>
notBefore=<start date>
notAfter=<expiry date>
X509v3 Subject Alternative Name:
    DNS:g4.sdi.hdm-stuttgart.cloud, DNS:*.g4.sdi.hdm-stuttgart.cloud
```

Confirm that the certificate and private key belong together without displaying their contents:

```bash
openssl x509 -in gen/certificate.pem -pubkey -noout | openssl sha256
openssl pkey -in gen/private.pem -pubout | openssl sha256
```

Output:

```text
SHA2-256(stdin)= <public-key-hash>
SHA2-256(stdin)= <public-key-hash>
```

Both hashes must be identical.

## Result

Terraform registers an ACME account against Let's Encrypt's staging environment and completes a DNS-01 challenge through the RFC2136 provider. The resulting certificate covers both `g4.sdi.hdm-stuttgart.cloud` and `*.g4.sdi.hdm-stuttgart.cloud`. Its private key and certificate are written to `gen/private.pem` and `gen/certificate.pem` with appropriate file permissions for later web-server installation.
