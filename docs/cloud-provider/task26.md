# Task 26 - Testing your web certificate

### Extend the setup from Task 25 to:

- Create DNS A records for the zone apex and an arbitrary number of host labels.
- Point the apex, `www`, and `mail` records to the same server IPv4 address.
- Install Nginx on the server.
- Allow HTTPS through the Hetzner firewall.
- Copy the generated wildcard certificate and private key to the server.
- Configure Nginx to serve the apex, `www`, and `mail` names over HTTPS.
- Test the staging certificate before requesting and installing a production certificate.
- Restore the Terraform source to the staging ACME endpoint after production issuance.

The assignment uses `g3.sdi.hdm-stuttgart.cloud` as an example. This project is configured for group 4, so the corresponding names are `g4.sdi.hdm-stuttgart.cloud`, `www.g4.sdi.hdm-stuttgart.cloud`, and `mail.g4.sdi.hdm-stuttgart.cloud`.

## Solution

### 1. Configure an arbitrary number of DNS host labels

The current `cloud-provider/config.auto.tfvars` contains:

```terraform
dns_zone     = "g4.sdi.hdm-stuttgart.cloud"
server_names = ["www", "mail"]
```

`dns_zone` defines the zone apex. Each value in `server_names` is a relative label beneath that zone. Additional labels can be added to the list without defining more Terraform resources.

The repository-safe example in `cloud-provider/config.auto.tfvars.example` is:

```terraform
dns_zone     = "g3.sdi.hdm-stuttgart.cloud"
server_names = ["www", "mail"]
```

The root input in `cloud-provider/variables.tf` is:

```terraform
variable "server_names" {
  type     = list(string)
  nullable = false
}
```

The DNS module applies additional validation in `Modules/Dns/variables.tf`:

```terraform
variable "server_names" {
  type     = list(string)
  nullable = false

  validation {
    condition     = alltrue([for name in var.server_names : name != "" && !strcontains(name, ".")])
    error_message = "The server_names must contain non-empty DNS labels without dots."
  }
}
```

This accepts labels such as `www` and `mail` while rejecting empty values and fully qualified names.

### 2. Create the apex and host records

The current DNS resource in `Modules/Dns/main.tf` is:

```terraform
resource "dns_a_record_set" "server" {
  for_each  = toset(concat([""], distinct(var.server_names)))
  zone      = "${var.dns_zone}." # The dot matters!
  name      = each.value
  addresses = toset([var.server_ip])
  ttl       = 300
}
```

The empty string added by `concat([""], ...)` represents the zone apex. With the current inputs, `for_each` creates three A record sets:

```text
g4.sdi.hdm-stuttgart.cloud
www.g4.sdi.hdm-stuttgart.cloud
mail.g4.sdi.hdm-stuttgart.cloud
```

The root module passes the server's IPv4 address and the list into the DNS module:

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

Using `hello_ip_addr` is important because DNS A records require an IPv4 address rather than the Hetzner server ID.

Apply the configuration and verify all three records:

```bash
terraform apply
dig +noall +answer g4.sdi.hdm-stuttgart.cloud
dig +noall +answer www.g4.sdi.hdm-stuttgart.cloud
dig +noall +answer mail.g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
g4.sdi.hdm-stuttgart.cloud. <ttl> IN A <server-ipv4>
www.g4.sdi.hdm-stuttgart.cloud. <ttl> IN A <server-ipv4>
mail.g4.sdi.hdm-stuttgart.cloud. <ttl> IN A <server-ipv4>
```

All three records must return the same public IPv4 address.

### 3. Install Nginx and allow HTTPS

Nginx is already installed during server creation by `Modules/HostMetaData/scripts/cloud-init.yml`:

```yaml
packages:
  - nginx
  - fail2ban
  - python3-systemd
  - plocate
```

The HTTPS firewall rule in `cloud-provider/main.tf` is:

```terraform
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
```

The firewall is attached to the modular server through:

```terraform
resource "hcloud_firewall_attachment" "sshFw" {
  firewall_id = hcloud_firewall.sshFw.id
  server_ids  = [module.createHostAmongMetaData.hello_id]
}
```

### 4. Confirm that the certificate covers all names

Task 25 derives the certificate names from the configured zone:

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

The apex is covered by `common_name`. The wildcard subject alternative name covers both `www` and `mail`.

The generated `certificate.pem` contains the certificate and its issuer chain, while `private.pem` contains the corresponding private key:

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

Inspect the staging certificate locally:

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

### 5. Copy the staging certificate to the server

Copy both generated files into the server's temporary directory:

```bash
./bin/scp gen/certificate.pem gen/private.pem devops@<server-ipv4>:/tmp/
```

Output:

```text
certificate.pem                             100% <size> <transfer-rate> <duration>
private.pem                                 100% <size> <transfer-rate> <duration>
```

Connect to the server and install the files with appropriate ownership and permissions:

```bash
./bin/ssh
sudo install -d -m 0755 /etc/nginx/ssl
sudo install -o root -g root -m 0644 /tmp/certificate.pem /etc/nginx/ssl/certificate.pem
sudo install -o root -g root -m 0600 /tmp/private.pem /etc/nginx/ssl/private.pem
rm /tmp/certificate.pem /tmp/private.pem
```

Verify the installed files without displaying their contents:

```bash
sudo ls -l /etc/nginx/ssl/certificate.pem /etc/nginx/ssl/private.pem
```

Output:

```text
-rw-r--r-- 1 root root <size> <date> /etc/nginx/ssl/certificate.pem
-rw------- 1 root root <size> <date> /etc/nginx/ssl/private.pem
```

### 6. Configure Nginx for all three HTTPS names

Open the default server configuration:

```bash
sudo editor /etc/nginx/sites-available/default
```

Enable the HTTPS listeners, replace the snakeoil include with the generated certificate paths, and configure the apex and wildcard server names. The relevant server block should contain:

```nginx
listen 80 default_server;
listen [::]:80 default_server;
listen 443 ssl default_server;
listen [::]:443 ssl default_server;

ssl_certificate /etc/nginx/ssl/certificate.pem;
ssl_certificate_key /etc/nginx/ssl/private.pem;

server_name g4.sdi.hdm-stuttgart.cloud *.g4.sdi.hdm-stuttgart.cloud;
```

The wildcard `server_name` accepts both `www.g4.sdi.hdm-stuttgart.cloud` and `mail.g4.sdi.hdm-stuttgart.cloud`. Do not enable `include snippets/snakeoil.conf;`, because that would select the self-signed snakeoil certificate instead.

Check the configuration before restarting Nginx:

```bash
sudo nginx -t
```

Expected output:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Correct any reported problem before restarting the service:

```bash
sudo systemctl restart nginx
sudo systemctl status nginx --no-pager
```

Output:

```text
<nginx active service status>
```

### 7. Test the staging certificate

The staging issuer is deliberately not trusted by browsers. Open all three URLs and proceed past the certificate warning only for this staging test:

```text
https://g4.sdi.hdm-stuttgart.cloud
https://www.g4.sdi.hdm-stuttgart.cloud
https://mail.g4.sdi.hdm-stuttgart.cloud
```

The browser's certificate viewer should show both names:

```text
g4.sdi.hdm-stuttgart.cloud
*.g4.sdi.hdm-stuttgart.cloud
```

The same test can be performed from the command line with certificate validation disabled only for staging:

```bash
curl -kI https://g4.sdi.hdm-stuttgart.cloud
curl -kI https://www.g4.sdi.hdm-stuttgart.cloud
curl -kI https://mail.g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
HTTP/<protocol-version> <status-code>
Server: nginx/<nginx-version>
<remaining response headers for each request>
```

### 8. Generate the production certificate

Only after the staging certificate works for all three names, temporarily change `Modules/Dns/provider.tf` to the production endpoint:

```terraform
provider "acme" {

  server_url = "https://acme-v02.api.letsencrypt.org/directory"

}
```

Force replacement so Terraform requests a new certificate from the newly selected ACME service:

```bash
terraform apply -replace=module.dns.acme_certificate.wildcard
```

Output:

```text
module.dns.acme_certificate.wildcard: Destroying...
module.dns.acme_certificate.wildcard: Creation complete
module.dns.local_sensitive_file.private_key: Modifications complete
module.dns.local_file.certificate: Modifications complete
Apply complete! Resources: <added> added, <changed> changed, <destroyed> destroyed.
```

Immediately restore the provider configuration in the source code to the staging endpoint, but do not request another replacement certificate:

```terraform
provider "acme" {

  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"

}
```

Keeping the committed configuration on staging prevents an accidental future production certificate request while experimenting.

### 9. Install and verify the production certificate

Copy the newly generated files to the server again:

```bash
./bin/scp gen/certificate.pem gen/private.pem devops@<server-ipv4>:/tmp/
./bin/ssh
sudo install -o root -g root -m 0644 /tmp/certificate.pem /etc/nginx/ssl/certificate.pem
sudo install -o root -g root -m 0600 /tmp/private.pem /etc/nginx/ssl/private.pem
rm /tmp/certificate.pem /tmp/private.pem
sudo nginx -t
sudo systemctl restart nginx
```

Verify all three endpoints without bypassing certificate validation:

```bash
curl -I https://g4.sdi.hdm-stuttgart.cloud
curl -I https://www.g4.sdi.hdm-stuttgart.cloud
curl -I https://mail.g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
HTTP/<protocol-version> <status-code>
Server: nginx/<nginx-version>
<remaining response headers for each request>
```

Inspect the certificate served by Nginx:

```bash
echo | openssl s_client \
  -connect g4.sdi.hdm-stuttgart.cloud:443 \
  -servername g4.sdi.hdm-stuttgart.cloud 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates -ext subjectAltName
```

Output:

```text
issuer=<trusted Let's Encrypt issuer>
subject=<certificate subject>
notBefore=<start date>
notAfter=<expiry date>
X509v3 Subject Alternative Name:
    DNS:g4.sdi.hdm-stuttgart.cloud, DNS:*.g4.sdi.hdm-stuttgart.cloud
```

## Result

Terraform creates A records for the zone apex and every label in `server_names`, with all records pointing to the same host. Nginx serves the apex, `www`, and `mail` names through port 443 using the certificate generated in Task 25. The configuration is tested first with an untrusted staging certificate, then with a trusted production certificate, while the committed ACME provider configuration remains safely set to staging.
