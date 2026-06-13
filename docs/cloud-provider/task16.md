# Task 16 - Solving the ~/.ssh/known_hosts quirk

### Extend the Cloud-init setup to:

- Automatically generate a `gen/known_hosts` file.

- Automatically generate a `bin/ssh` wrapper script.

- Automatically generate a `bin/scp` wrapper script.

- Avoid SSH host authenticity warnings by using a custom `known_hosts` file.

- Use Terraform templates and local files.

---

# Solution

## 1. Create the template files

Create a `templates` directory containing:

```text

templates/

├── known_hosts

├── scp.sh

└── ssh.sh

```

---

## 2. Create the SSH wrapper template

File: `templates/ssh.sh`

```bash

#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${username}@${server_ip} "$@"

# end of script

```

---

## 3. Create the SCP wrapper template

File: `templates/scp.sh`

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

---

## 4. Create the known_hosts template

File: `templates/known_hosts`

```text

${host_key}

```

---

## 5. Create a helper script for ssh-keyscan

Terraform's `external` data source requires JSON output.

Therefore a helper script is used.

Create:

```text

scripts/ssh-keyscan-json.sh

```

```bash

#!/usr/bin/env bash

set -e

ip="$1"

key="$(ssh-keyscan -t ed25519 "$ip" 2>/dev/null)"

jq -n --arg key "$key" '{ key: $key }'

```

Make the script executable:

```bash

chmod +x scripts/ssh-keyscan-json.sh

```

---

## 6. Generate the known_hosts file

```terraform

data "external" "host_key" {

  program = [

    "bash",

    "${path.module}/scripts/ssh-keyscan-json.sh",

    hcloud_server.helloServer.ipv4_address

  ]

}

resource "local_file" "known_hosts_file" {

  depends_on = [hcloud_server.helloServer]

  content = templatefile("${path.module}/templates/known_hosts", {

    host_key = data.external.host_key.result.key

  })

  filename = "${path.root}/gen/known_hosts"

  file_permission = "0644"

}

```

---

## 7. Generate the SSH wrapper script

```terraform

resource "local_file" "ssh_script" {

  depends_on = [hcloud_server.helloServer]

  content = templatefile("${path.module}/templates/ssh.sh", {

    server_ip = hcloud_server.helloServer.ipv4_address

    username = "devops"

  })

  filename = "${path.root}/bin/ssh"

  file_permission = "0755"

}

```

---

## 8. Generate the SCP wrapper script

```terraform

resource "local_file" "scp_script" {

  depends_on = [hcloud_server.helloServer]

  content = templatefile("${path.module}/templates/scp.sh", {

    server_ip = hcloud_server.helloServer.ipv4_address

    username = "devops"

  })

  filename = "${path.root}/bin/scp"

  file_permission = "0755"

}

```

---

# Usage

## SSH Login

```bash

./bin/ssh

```

The wrapper automatically:

- uses the generated `known_hosts` file

- connects using the `devops` user

- connects to the correct server IP

---

## SCP File Transfer

Example:

```bash

./bin/scp test.txt devops@<server-ip>:/tmp

```

---

# Result

Terraform now automatically generates:

```text

bin/ssh

bin/scp

gen/known_hosts

```

This avoids SSH host authenticity warnings and simplifies SSH/SCP usage.