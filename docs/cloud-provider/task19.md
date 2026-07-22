# Task 19 - Partitions and mounting

### Extend the setup from Task 18 to:

- Create and automatically attach a 10 GB Hetzner Cloud volume.
- Output the stable Linux device path reported by Terraform.
- Apply the `udevadm trigger` workaround for Hetzner's volume automount issue.
- Split the volume into two primary Linux partitions.
- Create an `ext4` file system on the first partition and an `xfs` file system on the second.
- Mount both partitions manually and make the mounts persistent through `/etc/fstab`.

The Terraform configuration creates and attaches the volume. Partitioning, formatting, and mounting are performed manually on the server.

> **Warning:** The partitioning and formatting commands in this task destroy existing data on the selected device. Verify the device name before running them.

## Solution

### 1. Expose the server ID from the host module

The volume needs the ID of the server to which it will be attached. Add the following output to `Modules/HostMetaData/output.tf`:

```terraform
output "hello_id" {
  value = hcloud_server.helloServer.id
  description = "The servers´s ID"
}
```

### 2. Create and attach the volume

Add the volume resource to `cloud-provider/main.tf`:

```terraform
resource "hcloud_volume" "volume01" {
  name      = "volume1"
  size      = 10
  server_id = module.createHostAmongMetaData.hello_id
  automount = true
  format    = "xfs"
}
```

The volume is initially formatted as XFS so Hetzner can mount it automatically. This initial file system is replaced later when the disk is divided into two partitions.

### 3. Output the stable device path

Add the following output to `cloud-provider/output.tf`:

```terraform
output "device_string" {
  value = hcloud_volume.volume01.linux_device
}
```

Apply the Terraform configuration:

```bash
terraform apply
```

The output has the following form:

```text
device_string = "/dev/disk/by-id/scsi-0HC_Volume_106439879"
```

Unlike a name such as `/dev/sdb`, this path contains Hetzner's volume ID and remains stable if Linux assigns a different device name after a reboot. It is a symbolic link to the current block device. The relationship can be verified on the server with:

```bash
readlink -f /dev/disk/by-id/scsi-0HC_Volume_106439879
```

Expected result for this setup:

```text
/dev/sdb
```

### 4. Apply the Hetzner automount workaround

The provider's automatic mount setup can be skipped when a server supplies its own Cloud-init configuration. Add the proposed `udevadm` trigger to the `runcmd` section in `Modules/HostMetaData/scripts/cloud-init.yml`. In this setup, it runs after the existing initialization commands:

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
```

The command re-emits an `add` event for Hetzner block volumes. This allows the automount rule created for the Terraform volume to process the attached device despite the custom Cloud-init configuration.

The attached volume becomes available after the server has rebooted. Connect to the server after the reboot and inspect the mounted file systems:

```bash
df -h
```

Output:

```text
Filesystem      Size  Used Avail Use% Mounted on
...
/dev/sdb         10G  104M  9.9G   2% /mnt/HC_Volume_106395540
...
```

Here, `/dev/sdb` is the device selected by the kernel, while Terraform's `linux_device` output is the stable symbolic link that resolves to that device.

### 5. Observe why an active mount is busy

Change into the automatically created mount point and try to unmount it:

```bash
cd /mnt/HC_Volume_106395540
sudo umount /mnt/HC_Volume_106395540
```

The command fails because the shell's current working directory is located on the mounted file system:

```text
umount: /mnt/HC_Volume_106395540: target is busy.
```

Leave the volume and repeat the command:

```bash
cd /
sudo umount /mnt/HC_Volume_106395540
```

The second attempt succeeds because the shell no longer uses the mounted file system.

### 6. Divide the volume into two partitions

Start `fdisk` with the kernel device identified above:

```bash
sudo fdisk /dev/sdb
```

Create a DOS partition table and two primary partitions. The first partition uses 5 GiB and the second uses the remaining space. Both partitions retain the default Linux type with ID `83`.

A shortened transcript of the interactive session is shown below:

```text
Device does not contain a recognized partition table.
Created a new DOS (MBR) disklabel with disk identifier 0x59ea7386.

Command (m for help): n
Partition type
   p   primary (0 primary, 0 extended, 4 free)
   e   extended (container for logical partitions)
Select (default p): p
Partition number (1-4, default 1): 1
First sector (2048-20971519, default 2048):
Last sector, +/-sectors or +/-size{K,M,G,T,P}: +5G

Created a new partition 1 of type 'Linux' and of size 5 GiB.

Command (m for help): n
Select (default p): p
Partition number (2-4, default 2): 2
First sector (10487808-20971519, default 10487808):
Last sector, +/-sectors or +/-size{K,M,G,T,P}:

Created a new partition 2 of type 'Linux' and of size 5 GiB.

Command (m for help): p
Disk /dev/sdb: 10 GiB, 10737418240 bytes, 20971520 sectors
Disklabel type: dos

Device     Boot    Start      End  Sectors Size Id Type
/dev/sdb1           2048 10487807 10485760   5G 83 Linux
/dev/sdb2       10487808 20971519 10483712   5G 83 Linux

Command (m for help): w
The partition table has been altered.
Syncing disks.
```

The `w` command writes the new partition table to disk. The partitions are now available as `/dev/sdb1` and `/dev/sdb2`.

### 7. Create two different file systems

Create an ext4 file system on the first partition and an XFS file system on the second:

```bash
sudo mkfs -t ext4 /dev/sdb1
sudo mkfs -t xfs /dev/sdb2
```

The commands completed successfully. The relevant output was:

```text
$ sudo mkfs -t ext4 /dev/sdb1
Creating filesystem with 1310720 4k blocks and 327680 inodes
Filesystem UUID: a414a9f1-4b3f-4002-8851-3e3e065c512e
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done

$ sudo mkfs -t xfs /dev/sdb2
meta-data=/dev/sdb2  isize=512  agcount=4, agsize=327616 blks
data     =            bsize=4096 blocks=1310464, imaxpct=25
Discarding blocks...Done.
```

### 8. Mount both partitions manually

Create a mount point for each file system:

```bash
sudo mkdir /disk1 /disk2
```

Mount the ext4 partition by its device path:

```bash
sudo mount /dev/sdb1 /disk1
```

Use `blkid` to obtain the UUID of the XFS partition:

```bash
sudo blkid /dev/sdb2
```

The output contains an individual UUID:

```text
/dev/sdb2: UUID="b15b4da6-a6ec-490c-88d8-694d9510ee0e" BLOCK_SIZE="512" TYPE="xfs" PARTUUID="d2358405-02"
```

Mount the second partition using that UUID:

```bash
sudo mount UUID=b15b4da6-a6ec-490c-88d8-694d9510ee0e /disk2
```

Verify both mounts:

```bash
df -h /disk1 /disk2
```

Expected structure:

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1       4.9G  1.3M  4.6G   1% /disk1
/dev/sdb2       5.0G  130M  4.9G   3% /disk2
```

### 9. Observe the effect of unmounting

Create a file on the first partition and then unmount both partitions:

```bash
sudo touch /disk1/testfile
ls -la /disk1
cd /
sudo umount /disk1
sudo umount /disk2
ls -la /disk1
```

After unmounting, `testfile` is no longer visible in `/disk1`. The file has not been deleted: it remains stored on the ext4 file system, but that file system is no longer attached to the server's directory tree. The file becomes visible again when `/dev/sdb1` is mounted.

### 10. Make both mounts persistent

Back up `/etc/fstab` before editing it:

```bash
sudo cp /etc/fstab /etc/fstab.bak
sudo editor /etc/fstab
```

Add one entry using the first partition's device name and another using the second partition's UUID. Replace `<xfs-uuid>` with the value reported by `blkid`:

```fstab
/dev/sdb1           /disk1  ext4  defaults  0  2
UUID=<xfs-uuid>     /disk2  xfs   defaults  0  2
```

The six fields specify the device, mount point, file-system type, mount options, dump setting, and file-system check order. A check order of `2` schedules non-root file systems after the root file system.

Test the entries without rebooting:

```bash
sudo mount -a
df -h /disk1 /disk2
```

`mount -a` reads `/etc/fstab` and mounts all entries that are not already mounted and do not use the `noauto` option. No output indicates success; `df` should list both partitions.

Finally, reboot and verify that the mounts are restored automatically:

```bash
sudo reboot
```

After reconnecting:

```bash
df -h /disk1 /disk2
ls -la /disk1
```

Both partitions should be mounted at their configured locations, and `testfile` should be visible again in `/disk1`.

## Result

Terraform now creates a 10 GB Hetzner Cloud volume, attaches it to the server, and exposes its stable Linux device path. The original volume file system was manually replaced by two primary partitions: an ext4 file system mounted at `/disk1` and an XFS file system mounted at `/disk2`. The `/etc/fstab` entries make both mounts persistent across reboots.
