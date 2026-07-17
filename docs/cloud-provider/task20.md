# Task 20 - Mount point's name specification

### Extend the setup from Task 19 to:

- Create the server and volume independently.
- Place the server and volume in the same Hetzner Cloud location.
- Attach the volume with an `hcloud_volume_attachment` resource and disable provider-managed automounting.
- Pass the volume name and stable Linux device path to the Cloud-init template.
- Create a predictable mount point instead of using `/mnt/HC_Volume_<volume-id>`.
- Add the volume to `/etc/fstab` and mount it during Cloud-init.

The mount point is derived directly from the Terraform volume name. Naming the volume `volume01` therefore creates the required `/volume01` mount point.

## Solution

### 1. Create the volume independently

The volume resource in `cloud-provider/main.tf` no longer contains a `server_id` or enables automounting. The current resource is:

```terraform
resource "hcloud_volume" "volume01" {
  name      = "volume01"
  size      = 10
  location  = "nbg1"
  format    = "xfs"
}
```

Without `server_id`, creation of the volume is separated from creation of the server. The volume is formatted with XFS before it is attached. Its location is explicitly set to `nbg1`, matching the server location.

### 2. Attach the volume explicitly

The current configuration uses a separate attachment resource:

```terraform
resource "hcloud_volume_attachment" "attach" {
  server_id = module.createHostAmongMetaData.hello_id
  volume_id = hcloud_volume.volume01.id
  automount = false
}
```

Setting `automount = false` prevents Hetzner's automatically generated mount point from being used. Cloud-init is responsible for mounting the volume at the chosen path instead.

### 3. Pass the volume information to the host module

The current module call in `cloud-provider/main.tf` passes the volume's name and stable Linux device path to `HostMetaData`:

```terraform
module "createHostAmongMetaData" {
  source = "../Modules/HostMetaData"
  name  = "myserver"
  hcloud_token = var.hcloud_token
  ssh_public_keys = var.ssh_public_keys
  volume_name   = hcloud_volume.volume01.name
  volume_device = hcloud_volume.volume01.linux_device
}
```

`volume_name` supplies the mount-point name. `volume_device` supplies the stable `/dev/disk/by-id/...` path used in `/etc/fstab`.

### 4. Define the new module inputs

The following variables were added to `Modules/HostMetaData/variables.tf`:

```terraform
variable "volume_name"{
  type = string
}

variable "volume_device" {
  type = string
}
```

### 5. Forward the values to the Cloud-init template

The `templatefile` call in `Modules/HostMetaData/main.tf` currently reads:

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

Terraform substitutes both values into `Modules/HostMetaData/scripts/cloud-init.yml` while creating the server.

### 6. Create the mount point and `/etc/fstab` entry

The complete current `runcmd` section is:

```yaml
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
  - udevadm trigger -c add -s block -p ID_VENDOR=HC --verbose -p ID_MODEL=Volume
  - mkdir -p /${volume_name}
  - echo "${volume_device} /${volume_name} xfs defaults,nofail,discard 0 2" >> /etc/fstab
  - systemctl daemon-reload
  - mount -a
```

These commands perform the following operations:

1. `mkdir -p /${volume_name}` creates the mount point.
2. The `echo` command appends an XFS entry to `/etc/fstab` using the stable device path.
3. `systemctl daemon-reload` reloads systemd configuration after `/etc/fstab` changes.
4. `mount -a` processes `/etc/fstab` and mounts the volume immediately.

With the volume name `volume01`, the rendered commands create `/volume01` and append an entry with this structure:

```fstab
/dev/disk/by-id/scsi-0HC_Volume_<volume-id> /volume01 xfs defaults,nofail,discard 0 2
```

The `nofail` option allows the server to continue booting if the additional volume is temporarily unavailable. The `discard` option enables discard operations for storage blocks that are no longer in use.

## Test the result

Apply the Terraform configuration:

```bash
terraform apply
```

After the server has booted, connect through the generated SSH wrapper:

```bash
./bin/ssh
```

Check that the mount point exists and that the volume is mounted there:

```bash
findmnt /volume01
df -h /volume01
```

Inspect the generated `/etc/fstab` entry:

```bash
grep '/volume01' /etc/fstab
```

Finally, reboot the server and repeat `findmnt` to verify that the `/etc/fstab` entry makes the mount persistent:

```bash
sudo reboot
```

## Result

The server and volume are created as separate resources in the same `nbg1` location. Terraform passes the volume name and stable Linux device path into the server's Cloud-init configuration, while `hcloud_volume_attachment` connects the two resources without provider-managed automounting.

Cloud-init creates `/volume01`, adds the XFS volume to `/etc/fstab`, reloads systemd, and processes the new mount entry with `mount -a`. This replaces Hetzner's generated `/mnt/HC_Volume_<volume-id>` path with a predictable mount point that persists across reboots.
