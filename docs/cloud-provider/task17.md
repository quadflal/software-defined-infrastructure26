# Task 17 - Generating host meta data

### Refactor the setup from Task 15 to:

- Create the host through a reusable Terraform module.
- Keep the Cloud-init configuration inside the module.
- Generate a JSON file containing the host's IPv4 address, IPv6 address, and location.
- Write generated files into the root module's `gen` directory.
- Make the host's IPv4 address and location available as module outputs.

## Solution

### 1. Create the HostMetaData module

Create the following module structure next to the `cloud-provider` root module:

```text
lecture-excercises/
├── Modules/
│   └── HostMetaData/
│       ├── scripts/
│       │   └── cloud-init.yml
│       ├── tpl/
│       │   └── hostdata.json
│       ├── main.tf
│       ├── output.tf
│       ├── providers.tf
│       └── variables.tf
└── cloud-provider/
```

Move the `cloud-init.yml` created in Task 15 from `cloud-provider/scripts` to `Modules/HostMetaData/scripts`. Its contents remain unchanged.

### 2. Define the module variables

File: `Modules/HostMetaData/variables.tf`

```terraform
variable "ssh_public_keys" {
  type = map(string)
}

variable "name" {
  type     = string
  nullable = false
}

variable "hcloud_token" {
  type     = string
  nullable = false
}
```

The parent module passes the host name, Hetzner Cloud token, and SSH public keys into the child module.

### 3. Configure the module provider

File: `Modules/HostMetaData/providers.tf`

```terraform
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.60.1"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
```

### 4. Move host creation into the module

File: `Modules/HostMetaData/main.tf`

```terraform
resource "hcloud_ssh_key" "ssh_key" {
  for_each   = var.ssh_public_keys
  name       = each.key
  public_key = each.value
}

resource "hcloud_server" "helloServer" {
  name        = var.name
  image       = "debian-13"
  server_type = "cx23"
  user_data = templatefile("${path.module}/scripts/cloud-init.yml", {
    ssh_public_keys = values(var.ssh_public_keys)
  })
}
```

`path.module` points to the `HostMetaData` child module. This ensures that the Cloud-init template is loaded from the module, independent of the directory from which Terraform is run.

### 5. Create the host metadata template

File: `Modules/HostMetaData/tpl/hostdata.json`

```json
{
  "network": {
    "ipv4": "${ip4}",
    "ipv6": "${ip6}"
  },
  "location": "${location}"
}
```

### 6. Generate the metadata and expose module outputs

File: `Modules/HostMetaData/output.tf`

```terraform
resource "local_file" "hostdata" {
  content = templatefile("${path.module}/tpl/hostdata.json", {
    ip4      = hcloud_server.helloServer.ipv4_address
    ip6      = hcloud_server.helloServer.ipv6_address
    location = hcloud_server.helloServer.location
  })
  filename = "${path.root}/gen/${var.name}.json"
}

output "hello_ip_addr" {
  value       = hcloud_server.helloServer.ipv4_address
  description = "The server's IPv4 address"
}

output "hello_location" {
  value       = hcloud_server.helloServer.location
  description = "The server's datacenter location"
}
```

The two path expressions have different contexts:

- `path.module` refers to `Modules/HostMetaData`, so it is used to read the module-owned template.
- `path.root` refers to `cloud-provider`, so the generated metadata is written to the root module's `gen` directory.

### 7. Use the module from the parent module

Remove the SSH key and server resources from `cloud-provider/main.tf` and replace them with:

```terraform
module "createHostAmongMetaData" {
  source          = "../Modules/HostMetaData"
  name            = "myserver"
  hcloud_token    = var.hcloud_token
  ssh_public_keys = var.ssh_public_keys
}
```

The firewall from Task 15 remains in the parent module.

## Test the result

Apply the configuration:

```bash
terraform init
terraform apply
```

Check the generated metadata:

```bash
cat gen/myserver.json
```

Expected structure:

```json
{
  "network": {
    "ipv4": "<server-ipv4>",
    "ipv6": "<server-ipv6>"
  },
  "location": "<server-location>"
}
```

## Result

Host creation and Cloud-init configuration are now encapsulated in `Modules/HostMetaData`. The module creates `gen/myserver.json` in the parent module and exposes the host information required by other modules.
