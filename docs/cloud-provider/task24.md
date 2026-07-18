# Task 24 - Creating a fixed number of servers

Write a Terraform configuration for deploying a configurable number of servers being defined by the following
config.auto.tfvars:

``` dotenv
dnsZone        = "gxy.sdi.hdm-stuttgart.cloud"
serverBaseName = "work"
serverCount    = 2
```


**Solution**: Because this is a bigger task we have added some code examples how we achieved the solution. For the server creation we used the for loop to create the names used for the server and the dns. Using the names we iterated over to create the correct amount of servers specified in the config file. The principle was used create two corresponding servers each endowed with its own unique ssh host key pair and the two corresponding subdirectories work-1 and work-2 each containing its own bin/ssh and related gen/known_hosts file. 

```hcl
locals {
  server_names = [for i in range(var.serverCount) : format("%s-%d", var.serverBaseName, i + 1)]
}

module "createHostAmongMetaData" {
  for_each = toset(local.server_names)

  source          = "../Modules/HostMetaData"
  name            = each.key
  hcloud_token    = var.hcloud_token
  ssh_public_keys = var.ssh_public_keys
  volume_name     = hcloud_volume.volume[each.key].name
  volume_device   = hcloud_volume.volume[each.key].linux_device
}
```