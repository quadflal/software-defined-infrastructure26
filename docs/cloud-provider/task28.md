# Task 28 - Creating a subnet

### Extend the setup to:

- Create a private Hetzner Cloud network and subnet.
- Create a public gateway host connected to both the Internet and the private subnet.
- Create an `intern` host connected only to the private subnet.
- Permit public SSH access to the gateway.
- Permit SSH access to `intern` only from the private subnet.
- Reach `intern` through a chained SSH connection using the gateway.
- Define local DNS names through `/etc/cloud/templates/hosts.debian.tmpl`.
- Avoid package installation and updates on `intern` while it has no Internet access.

The implementation is encapsulated in `Modules/PrivateSubnet`. It adds the two Task 28 hosts without changing the resources from the preceding exercises.

> **Cost warning:** This configuration creates two additional Hetzner Cloud servers. The implementation was validated locally but was not planned or applied, so no cloud resources were created while preparing this documentation.

## Solution

### 1. Configure the private subnet

The root variable in `cloud-provider/variables.tf` uses the object structure suggested by the exercise:

```terraform
variable "privateSubnet" {
  type = object({
    dnsDomainName = string
    ipAndNetmask  = string
  })
}
```

The current value in `cloud-provider/config.auto.tfvars` and its repository-safe example is:

```terraform
privateSubnet = {
  dnsDomainName = "intern.g4.hdm-stuttgart.cloud"
  ipAndNetmask  = "10.0.1.0/24"
}
```

`dnsDomainName` is used only for local hostname resolution. No public DNS records are created for these names.

### 2. Add the private-subnet module

The root module call in `cloud-provider/main.tf` is:

```terraform
module "privateSubnet" {
  source = "../Modules/PrivateSubnet"

  private_subnet  = var.privateSubnet
  ssh_public_keys = var.ssh_public_keys
}
```

The existing SSH public keys are passed into Cloud-init for the `devops` user on both hosts.

### 3. Define the module inputs

`Modules/PrivateSubnet/variables.tf` contains:

```terraform
variable "ssh_public_keys" {
  type = map(string)
}

variable "private_subnet" {
  type = object({
    dnsDomainName = string
    ipAndNetmask  = string
  })

  validation {
    condition     = can(cidrhost(var.private_subnet.ipAndNetmask, 3))
    error_message = "private_subnet.ipAndNetmask must be a valid subnet with at least four addresses."
  }
}

variable "network_ip_range" {
  type    = string
  default = "10.0.0.0/16"
}

variable "location" {
  type    = string
  default = "nbg1"
}

variable "network_zone" {
  type    = string
  default = "eu-central"
}
```

The private `/24` subnet is contained within the module's default `10.0.0.0/16` network range. Both hosts are placed in `nbg1`, which belongs to the `eu-central` network zone.

### 4. Derive the private addresses and local names

The module derives both fixed addresses from the configured CIDR instead of duplicating them as inputs:

```terraform
locals {
  gateway_private_ip = cidrhost(var.private_subnet.ipAndNetmask, 2)
  intern_private_ip  = cidrhost(var.private_subnet.ipAndNetmask, 3)
  gateway_fqdn       = "gateway.${var.private_subnet.dnsDomainName}"
  intern_fqdn        = "intern.${var.private_subnet.dnsDomainName}"
}
```

For the current configuration, this produces:

```text
10.0.1.2  gateway.intern.g4.hdm-stuttgart.cloud
10.0.1.3  intern.intern.g4.hdm-stuttgart.cloud
```

### 5. Create the network and subnet

The resources in `Modules/PrivateSubnet/main.tf` are:

```terraform
resource "hcloud_network" "private" {
  name     = "private-network"
  ip_range = var.network_ip_range
}

resource "hcloud_network_subnet" "private" {
  network_id   = hcloud_network.private.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.private_subnet.ipAndNetmask
}
```

The network provides the larger private address space. The cloud subnet selects `10.0.1.0/24` from that range for both hosts.

### 6. Restrict SSH with separate firewalls

The gateway firewall permits inbound SSH from the Internet:

```terraform
resource "hcloud_firewall" "gateway" {
  name = "private-subnet-gateway"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
```

The `intern` firewall permits SSH only from the configured private subnet:

```terraform
resource "hcloud_firewall" "intern" {
  name = "private-subnet-intern"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.private_subnet.ipAndNetmask]
  }
}
```

The absence of a public interface is the primary isolation boundary for `intern`; the private-source firewall rule adds a second restriction.

### 7. Create the dual-homed gateway

The gateway resource is:

```terraform
resource "hcloud_server" "gateway" {
  depends_on = [hcloud_network_subnet.private]

  name         = "gateway"
  image        = "debian-13"
  server_type  = "cx23"
  location     = var.location
  firewall_ids = [hcloud_firewall.gateway.id]
  user_data = templatefile("${path.module}/scripts/cloud-init.yml", {
    hostname        = "gateway"
    fqdn            = local.gateway_fqdn
    gateway_fqdn    = local.gateway_fqdn
    gateway_ip      = local.gateway_private_ip
    intern_fqdn     = local.intern_fqdn
    intern_ip       = local.intern_private_ip
    ssh_public_keys = values(var.ssh_public_keys)
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private.id
    ip         = local.gateway_private_ip
    alias_ips  = []
  }
}
```

The `public_net` block creates Internet-facing IPv4 and IPv6 interfaces. The `network` block adds the private interface with `10.0.1.2`.

The explicit subnet dependency ensures that the Hetzner subnet exists before the provider creates and attaches the server's private interface. `alias_ips = []` avoids repeated detach/attach behavior in affected Terraform versions.

### 8. Create the private-only intern host

The `intern` resource uses the same private network but explicitly disables public addressing:

```terraform
resource "hcloud_server" "intern" {
  depends_on = [hcloud_network_subnet.private]

  name         = "intern"
  image        = "debian-13"
  server_type  = "cx23"
  location     = var.location
  firewall_ids = [hcloud_firewall.intern.id]
  user_data = templatefile("${path.module}/scripts/cloud-init.yml", {
    hostname        = "intern"
    fqdn            = local.intern_fqdn
    gateway_fqdn    = local.gateway_fqdn
    gateway_ip      = local.gateway_private_ip
    intern_fqdn     = local.intern_fqdn
    intern_ip       = local.intern_private_ip
    ssh_public_keys = values(var.ssh_public_keys)
  })

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.private.id
    ip         = local.intern_private_ip
    alias_ips  = []
  }
}
```

The host receives only `10.0.1.3`. It has no public IP and no route providing outbound Internet access at this stage.

### 9. Configure local hostnames through Cloud-init

`Modules/PrivateSubnet/scripts/cloud-init.yml` disables package operations so that initialization also succeeds on the isolated host:

```yaml
package_update: false
package_upgrade: false
ssh_pwauth: false
disable_root: true
manage_etc_hosts: true
hostname: ${hostname}
fqdn: ${fqdn}
```

The template creates a hardened `devops` user with the supplied SSH keys. It also writes the Debian hosts template required by the exercise:

```yaml
  - path: /etc/cloud/templates/hosts.debian.tmpl
    owner: root:root
    permissions: "0644"
    content: |
      127.0.1.1 {{fqdn}} {{hostname}}
      127.0.0.1 localhost

      ${gateway_ip} ${gateway_fqdn} gateway
      ${intern_ip} ${intern_fqdn} intern

      ::1 localhost ip6-localhost ip6-loopback
      ff02::1 ip6-allnodes
      ff02::2 ip6-allrouters
```

With `manage_etc_hosts: true`, Cloud-init renders `/etc/hosts` from this template. Both short names and local fully qualified names resolve without public DNS.

### 10. Expose connection information

`Modules/PrivateSubnet/outputs.tf` exposes the public gateway address and both private addresses and names. The root module collects them in `cloud-provider/output.tf`:

```terraform
output "private_subnet" {
  value = {
    gateway_public_ip  = module.privateSubnet.gateway_public_ip
    gateway_private_ip = module.privateSubnet.gateway_private_ip
    intern_private_ip  = module.privateSubnet.intern_private_ip
    gateway_fqdn       = module.privateSubnet.gateway_fqdn
    intern_fqdn        = module.privateSubnet.intern_fqdn
  }
}
```

## Validate and apply

The configuration was initialized and validated without creating resources:

```bash
terraform init -backend=false
terraform validate
```

Validation result:

```text
Success! The configuration is valid.
```

Before applying, review the additional billable resources:

```bash
terraform plan
```

Expected Task 28 additions:

```text
module.privateSubnet.hcloud_network.private
module.privateSubnet.hcloud_network_subnet.private
module.privateSubnet.hcloud_firewall.gateway
module.privateSubnet.hcloud_firewall.intern
module.privateSubnet.hcloud_server.gateway
module.privateSubnet.hcloud_server.intern
```

No `terraform plan` or `terraform apply` was executed while implementing this task.

## Test the result after applying

### Inspect the output

```bash
terraform output private_subnet
```

Output:

```text
{
  "gateway_fqdn" = "gateway.intern.g4.hdm-stuttgart.cloud"
  "gateway_private_ip" = "10.0.1.2"
  "gateway_public_ip" = "88.99.224.53"
  "intern_fqdn" = "intern.intern.g4.hdm-stuttgart.cloud"
  "intern_private_ip" = "10.0.1.3"
}
```

### Connect to the gateway

```bash
ssh devops@88.99.224.53
```

On the gateway, inspect both interfaces and local names:

```bash
ip address
getent hosts gateway
getent hosts intern
ping -c 3 intern
```

Output:

```text
eth0             UP             88.99.224.53/32 fe80::b227:44eb:4f07:22de/64
enp7s0           UP             10.0.1.2/32 fe80::8400:ff:fe41:d5e2/64
10.0.1.2 gateway.intern.g4.hdm-stuttgart.cloud gateway
10.0.1.3 intern.intern.g4.hdm-stuttgart.cloud intern
3 packets transmitted, 3 received, 0% packet loss
```

### Connect through the gateway

From the local workstation, use OpenSSH ProxyJump. The local SSH agent/key authenticates to both hosts; no private key is copied to the gateway:

```bash
ssh -J devops@88.99.224.53 devops@10.0.1.3
```

The local FQDN can also be used as the final destination only after connecting through the gateway's resolver context. The fixed private IP is therefore the simplest ProxyJump target.

Alternatively, connect to the gateway with agent forwarding and then start the second SSH connection:

```bash
ssh -A devops@88.99.224.53
ssh devops@intern
```

On `intern`, verify its identity, private interface, and local names:

```bash
hostname --fqdn
ip address
getent hosts gateway
getent hosts intern
```

Output:

```text
intern.intern.g4.hdm-stuttgart.cloud
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp7s0           UP             10.0.1.3/32 fe80::8400:ff:fe41:d5aa/64
10.0.1.2 gateway.intern.g4.hdm-stuttgart.cloud gateway
10.0.1.3 intern.intern.g4.hdm-stuttgart.cloud intern
```

Direct SSH from the Internet to `10.0.1.3` should not be possible because it is a private address and the host has no public interface.

### Confirm the temporary Internet isolation

On `intern`, an Internet request should fail until the application-level gateway is implemented in the following exercise:

```bash
curl --connect-timeout 5 https://deb.debian.org
```

Output placeholder:

```text
curl: (<error-code>) <network-unreachable-or-timeout-message>
```

Package update and installation commands should not be run on `intern` yet. Its Cloud-init configuration deliberately sets `package_update` and `package_upgrade` to `false` and does not declare any packages.

## Result

The `PrivateSubnet` module defines a `10.0.0.0/16` private network containing the `10.0.1.0/24` cloud subnet. The gateway has public Internet interfaces plus private address `10.0.1.2`; `intern` has only private address `10.0.1.3`. Separate firewalls restrict access appropriately, Cloud-init supplies local DNS names through `hosts.debian.tmpl`, and the private host is reachable only through a chained SSH connection via the gateway.
