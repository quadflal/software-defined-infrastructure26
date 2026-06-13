# Task 15 - Working on Cloud-init

### Use Terraform and Cloud-init to:
- Install and configure the Nginx web server automatically.
- Open port 80 in the firewall.
- Disable SSH password login.
- Disable direct root login.
- Create a user called `devops`.
- Allow the `devops` user to log in via SSH key.
- Allow the `devops` user to use `sudo`.
- Upgrade all packages during server creation.
- Install and configure `fail2ban`.
- Install and initialize `plocate`.

## Solution

1. Create a file called `cloud-init.yml` in the `scripts` directory.

```yaml
#cloud-config

package_update: true
package_upgrade: true
package_reboot_if_required: true
ssh_pwauth: false
disable_root: true

users:
  - default
  - name: devops
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
    %{ for key in ssh_public_keys ~}
    - ${key}
    %{ endfor ~}

packages:
  - nginx
  - fail2ban
  - python3-systemd
  - plocate

write_files:
  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    owner: root:root
    permissions: "0644"
    content: |
      PasswordAuthentication no
      PermitRootLogin no
      PubkeyAuthentication yes

  - path: /etc/fail2ban/jail.local
    owner: root:root
    permissions: "0644"
    content: |
      [DEFAULT]
      bantime = 10m
      findtime = 10m
      maxretry = 3

      [sshd]
      enabled = true
      backend = systemd
      port = ssh
      filter = sshd
      maxretry = 3

runcmd:
  - systemctl restart ssh || systemctl restart sshd
  - systemctl enable nginx
  - systemctl restart nginx
  - systemctl enable fail2ban
  - systemctl restart fail2ban
  - updatedb
  - |
    IP=$(hostname -I | awk '{print $1}')
    DATE=$(date)
    echo "I'm Nginx @ \"$IP\" created $DATE" > /var/www/html/index.html
```

2. Pass the Cloud-init file to the Hetzner server resource using `templatefile`.

```terraform
resource "hcloud_server" "helloServer" {
  name         = "hello2"
  image        = "debian-13"
  server_type  = "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id]
  user_data = templatefile("scripts/cloud-init.yml", { //pass it here
    ssh_public_keys = values(var.ssh_public_keys)
  })
  ssh_keys = [
    for key in hcloud_ssh_key.ssh_key : key.id
  ]
}
```

3. Add port `80` to the firewall configuration.

```terraform
resource "hcloud_firewall" "sshFw" {
  name = "ssh-firewall-2"
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
```

After apply the following tests can be used to check the config:
1. Test the web server.

```bash
curl http://<server-ip>
```
Expected output:

```text
I'm Nginx @ "<server-ip>" created <date>
```

2. Test the `devops` SSH login.

```bash
ssh devops@<server-ip>
```

3. Test that root login is disabled.

```bash
ssh root@<server-ip>
```

Expected result:

```text
Permission denied (publickey).
```

4. Check if all packages are up to date.

```bash
sudo apt update
```

Expected result:

```text
All packages are up to date.
```
5. Check the `fail2ban` SSH jail.

```bash
sudo fail2ban-client status sshd
```
6. Test `plocate`.

```bash
sudo locate ssh_host
```

Expected example output:

```text
/etc/ssh/ssh_host_ed25519_key
/etc/ssh/ssh_host_ed25519_key.pub
```

## Result

The server is now created and configured automatically using Terraform and Cloud-init.

The final setup:
- serves a simple Nginx website on port `80`
- allows SSH login only with public keys
- disables direct root SSH login
- provides a `devops` user with sudo permissions
- upgrades packages during creation
- protects SSH with `fail2ban`
- supports fast file search using `plocate`