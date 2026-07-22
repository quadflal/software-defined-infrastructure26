# Task 27 - Combining certificate generation and server creation

### Combine the previous exercises so that one Terraform configuration:

- Creates and configures the server.
- Installs Nginx through Cloud-init.
- Creates the apex and configured host DNS records for that server.
- Registers an ACME account and requests the apex and wildcard certificate.
- Writes the generated certificate and private key into the root module's `gen` directory.

No additional Terraform resource was required for this task. The root `cloud-provider` configuration already connects the host and DNS/certificate modules through their inputs and outputs.

## Solution

### 1. Create the server through the host module

The root module creates the server through `HostMetaData`:

```terraform
module "createHostAmongMetaData" {
  source          = "../Modules/HostMetaData"
  name            = "myserver"
  hcloud_token    = var.hcloud_token
  ssh_public_keys = var.ssh_public_keys
  volume_name     = hcloud_volume.volume01.name
  volume_device   = hcloud_volume.volume01.linux_device
}
```

`Modules/HostMetaData` exposes the server information required by the other modules. The relevant IPv4 output is:

```terraform
output "hello_ip_addr" {
  value       = hcloud_server.helloServer.ipv4_address
  description = "The server's IPv4 address"
}
```

### 2. Install Nginx during server creation

The host module passes its Cloud-init template to the Hetzner server resource:

```terraform
resource "hcloud_server" "helloServer" {
  name         = var.name
  image        = "debian-13"
  server_type  = "cx23"
  location     = "nbg1"
  user_data = templatefile("${path.module}/scripts/cloud-init.yml", { //pass it here
    ssh_public_keys = values(var.ssh_public_keys)
    volume_device = var.volume_device
    volume_name = var.volume_name
  })
}
```

The package list in `Modules/HostMetaData/scripts/cloud-init.yml` includes Nginx:

```yaml
packages:
  - nginx
  - fail2ban
  - python3-systemd
  - plocate
```

Cloud-init also enables and starts the service:

```yaml
  - systemctl enable nginx
  - systemctl restart nginx
```

### 3. Pass the server address into the DNS and certificate module

The same root configuration calls the DNS module after referencing the host module's IPv4 output:

```terraform
module "dns" {
  source       = "../Modules/Dns"
  hcloud_token = var.hcloud_token
  server_ip    = module.createHostAmongMetaData.hello_ip_addr
  dns_zone     = var.dns_zone
  server_names = var.server_names
  dns_secret   = var.dns_secret
}
```

The `server_ip` reference creates an implicit dependency from the DNS module to the server module. Terraform therefore knows that it must obtain the server's IPv4 address before it can create the A records.

The configured values are:

```terraform
dns_zone     = "g4.sdi.hdm-stuttgart.cloud"
server_names = ["www", "mail"]
```

These inputs result in records for:

```text
g4.sdi.hdm-stuttgart.cloud
www.g4.sdi.hdm-stuttgart.cloud
mail.g4.sdi.hdm-stuttgart.cloud
```

### 4. Generate the certificate in the same DNS module

`Modules/Dns` contains both the DNS record resources and the certificate resources from Task 25. The certificate names are derived from the same `dns_zone` input:

```terraform
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
      RFC2136_TSIG_KEY       = "${split(".", var.dns_zone)[0]}.key."
      RFC2136_TSIG_SECRET    = var.dns_secret
    }
  }
}
```

Because the DNS records and ACME DNS-01 challenge use the same zone and RFC2136 access, certificate generation is part of the same Terraform dependency graph as server and DNS creation.

### 5. Generate both PEM files

After successful certificate issuance, the DNS module writes both files into the root module:

```terraform
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
```

The resulting dependency order is:

```text
Hetzner server
└── server IPv4 address
    └── DNS A records and ACME DNS-01 challenge
        └── wildcard certificate
            ├── gen/private.pem
            └── gen/certificate.pem
```

These dependencies are inferred from Terraform references; no explicit `depends_on` is necessary.

## Test the combined configuration

Review the complete execution plan:

```bash
terraform plan
```

Output:

```text
Terraform will perform the following actions:
  # module.createHostAmongMetaData.hcloud_server.helloServer will be created
  # module.dns.dns_a_record_set.server[...] will be created
  # module.dns.acme_registration.registration will be created
  # module.dns.acme_certificate.wildcard will be created
  # module.dns.local_sensitive_file.private_key will be created
  # module.dns.local_file.certificate will be created

Plan: <add-count> to add, <change-count> to change, <destroy-count> to destroy.
```

Apply the combined configuration:

```bash
terraform apply
```

Output:

```text
module.createHostAmongMetaData.hcloud_server.helloServer: Creation complete
module.dns.dns_a_record_set.server[...]: Creation complete
module.dns.acme_registration.registration: Creation complete
module.dns.acme_certificate.wildcard: Creation complete
module.dns.local_sensitive_file.private_key: Creation complete
module.dns.local_file.certificate: Creation complete

Apply complete! Resources: <add-count> added, <change-count> changed, <destroy-count> destroyed.
```

Verify the combined result:

```bash
terraform output
dig +noall +answer g4.sdi.hdm-stuttgart.cloud
dig +noall +answer www.g4.sdi.hdm-stuttgart.cloud
dig +noall +answer mail.g4.sdi.hdm-stuttgart.cloud
ls -l gen/private.pem gen/certificate.pem
```

Output:

```text
<server outputs>
g4.sdi.hdm-stuttgart.cloud. <ttl> IN A <server-ipv4>
www.g4.sdi.hdm-stuttgart.cloud. <ttl> IN A <server-ipv4>
mail.g4.sdi.hdm-stuttgart.cloud. <ttl> IN A <server-ipv4>
-rw-r--r-- <owner> <group> <size> <date> gen/certificate.pem
-rw------- <owner> <group> <size> <date> gen/private.pem
```

## Installation boundary

Server creation and certificate generation are combined in one Terraform configuration. The current configuration does not automatically transfer the generated PEM files to the server or modify `/etc/nginx/sites-available/default`.

After `terraform apply`, use the certificate-copy and Nginx installation procedure documented in Task 26. Keeping this as a post-apply step avoids a circular relationship in which initial server creation would require a certificate whose DNS validation first requires the server's generated IPv4 address.

## Result

One root Terraform configuration now creates the server, installs Nginx, creates all configured DNS records, completes the RFC2136 ACME challenge, and generates the certificate files. Terraform derives the required order from the server IPv4 and certificate output references. Only deployment of the generated certificate into Nginx remains a manual post-apply operation.
