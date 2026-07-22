# Task 18 - A module for ssh host key handling

### Extend the setup from Task 17 to:

- Create a reusable `SshKnownHosts` Terraform module.
- Scan the generated host's SSH public key.
- Generate a custom `gen/known_hosts` file.
- Generate `bin/ssh` and `bin/scp` wrapper scripts.
- Pass the host address from `HostMetaData` to `SshKnownHosts` through a module output.

This implements the SSH host key handling from Task 16 as a child module instead of defining the resources directly in the parent module.

## Solution

### 1. Create the SshKnownHosts module

Create the following structure:

```text
Modules/SshKnownHosts/
├── scripts/
│   └── ssh-keyscan-json.sh
├── tpl/
│   ├── known_hosts
│   ├── scp.sh
│   └── ssh.sh
├── main.tf
├── outputs.tf
├── providers.tf
└── variables.tf
```

The helper script and templates correspond to the files introduced in Task 16, but now belong to the reusable module.

### 2. Define the module inputs

File: `Modules/SshKnownHosts/variables.tf`

```terraform
variable "loginUserName" {
  type = string
}

variable "serverNameOrIp" {
  type = string
}
```

`loginUserName` is the SSH user created by Cloud-init. `serverNameOrIp` is the server address returned by the `HostMetaData` module.

### 3. Configure the external provider

File: `Modules/SshKnownHosts/providers.tf`

```terraform
terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "2.3.5"
    }
  }
}
```

The external provider is required because `ssh-keyscan` is executed by a helper script.

### 4. Add the ssh-keyscan helper

File: `Modules/SshKnownHosts/scripts/ssh-keyscan-json.sh`

```bash
#!/usr/bin/env bash
set -e

ip="$1"
key="$(ssh-keyscan -t ed25519 "$ip" 2>/dev/null)"

jq -n --arg key "$key" '{ key: $key }'
```

Make the script executable:

```bash
chmod +x Modules/SshKnownHosts/scripts/ssh-keyscan-json.sh
```

The script converts the result of `ssh-keyscan` into JSON because Terraform's external data source expects JSON output.

### 5. Add the templates

File: `Modules/SshKnownHosts/tpl/known_hosts`

```text
${host_key}
```

File: `Modules/SshKnownHosts/tpl/ssh.sh`

```bash
#!/usr/bin/env bash
GEN_DIR=$(dirname "$0")/../gen
ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${username}@${server_ip} "$@"
# end of script
```

File: `Modules/SshKnownHosts/tpl/scp.sh`

```bash
#!/usr/bin/env bash
GEN_DIR=$(dirname "$0")/../gen
if [ $# -lt 2 ]; then
   echo "usage: ./bin/scp <source> <destination>"
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" "$@"
fi
# end of script
```

### 6. Generate known_hosts and the wrapper scripts

File: `Modules/SshKnownHosts/outputs.tf`

```terraform
data "external" "host_key" {
  program = [
    "bash",
    "${path.module}/scripts/ssh-keyscan-json.sh",
    var.serverNameOrIp
  ]
}

resource "local_file" "known_hosts_file" {
  content = templatefile("${path.module}/tpl/known_hosts", {
    host_key = data.external.host_key.result.key
  })
  filename        = "${path.root}/gen/known_hosts"
  file_permission = "0644"
}

resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/tpl/ssh.sh", {
    server_ip = var.serverNameOrIp
    username  = var.loginUserName
  })
  filename        = "${path.root}/bin/ssh"
  file_permission = "0755"
}

resource "local_file" "scp_script" {
  content = templatefile("${path.module}/tpl/scp.sh", {
    server_ip = var.serverNameOrIp
    username  = var.loginUserName
  })
  filename        = "${path.root}/bin/scp"
  file_permission = "0755"
}
```

As in Task 17, `path.module` reads files owned by the child module while `path.root` writes generated files into the parent module.

### 7. Connect both modules

Add the module call to `cloud-provider/main.tf`:

```terraform
module "createSshKnownHosts" {
  depends_on     = [module.createHostAmongMetaData]
  source         = "../Modules/SshKnownHosts"
  loginUserName  = "devops"
  serverNameOrIp = module.createHostAmongMetaData.hello_ip_addr
}
```

The `hello_ip_addr` output forms the connection between the modules. The explicit dependency ensures that host creation is complete before Terraform scans the SSH key.

## Test the result

Apply the configuration:

```bash
terraform init
terraform apply
```

Check the generated files:

```bash
cat gen/known_hosts
ls -l bin/ssh bin/scp
```

Connect through the SSH wrapper:

```bash
./bin/ssh
```

Copy a file through the SCP wrapper:

```bash
./bin/scp test.txt devops@178.104.204.33:/tmp
```

## Result

SSH host key scanning and wrapper generation are now encapsulated in `Modules/SshKnownHosts`. Terraform uses the IPv4 address produced by `HostMetaData` and generates:

```text
bin/ssh
bin/scp
gen/known_hosts
```

The wrapper scripts use the generated host key file, avoiding entries in the user's global `~/.ssh/known_hosts` file.
