# Task 14 - Automatic Nginx installation

### Use a Terraform user_data included bash script to:  
- Install the Nginx web server automatically.
- Start Nginx using the systemctl command.
- Enable the Nginx server permanently (surviving re-boot) using systemctl again.

## Solution
1. Create a file called `init.sh` in the `scripts` directory.
```bash
#!/bin/bash
set -e
apt-get update -y
apt-get install -y nginx #installs nginx
systemctl start nginx 
systemctl enable nginx #enables nginx to start after every boot
```
2. Add the `init.sh` file to the `user_data` variable in the `main.tf` file.

```terraform
resource "hcloud_server" "helloServer" {
  name        = "hello2"
  image       = "debian-13"
  server_type = "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id]
  user_data = file("scripts/init.sh") //new line
  ssh_keys    = [
    for key in hcloud_ssh_key.ssh_key : key.id
  ]
}
```