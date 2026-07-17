# Task 23 - Creating a host with corresponding DNS entries

### Extend Solving the ~/.ssh/known_hosts quirk by adding DNS records like in Creating DNS records . The provider generated IP4 address shall be bound to workhorse within your given zone. Use the server's common DNS name rather than its IP in the generated gen/known_hosts, bin/ssh and bin/scp files, e.g:

Solution:

scp.sh:

``` shell

#!/usr/bin/env bash
GEN_DIR=$(dirname "$0")/../gen
if [ $# -lt 2 ]; then
   echo usage: .../bin/scp ... ${username}@${server_host} ...
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi
# end of script

```

ssh.sh:

``` shell
#!/usr/bin/env bash#!/usr/bin/env bash
GEN_DIR=$(dirname "$0")/../gen
ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${username}@${server_host} "$@"
# end of script
```


Root main:

```hcl

module "createSshKnownHosts" {
  depends_on = [module.createHostAmongMetaData, module.dns]
  source         = "../Modules/SshKnownHosts"
  loginUserName  = module.createHostAmongMetaData.hello_ip_addr
  serverNameOrIp = "${var.server_name}.${var.dns_zone}"
}

module "dns" {
  source         = "../Modules/Dns"
  hcloud_token   = var.hcloud_token
  server_ip      = module.createHostAmongMetaData.hello_ip_addr
  dns_zone       = var.dns_zone
  server_name    = var.server_name
  server_aliases = var.server_aliases
  dns_secret     = var.dns_secret
}

```