# Cloud Provider Exercise

This Terraform project provisions infrastructure in Hetzner Cloud, including:

- multiple public servers with attached volumes;
- a private subnet with gateway and internal hosts;
- firewall rules and SSH helper scripts;
- DNS A records through RFC 2136; and
- a staging ACME wildcard certificate.

## Prerequisites

- Terraform compatible with the versions in `lecture-excercises/cloud-provider/.terraform.lock.hcl`
- A Hetzner Cloud API token
- The SSH public keys that should be installed on the hosts
- The TSIG secret for the configured DNS zone
- Access to the configured Terraform Cloud organization when using the shared state

The DNS module is configured for `ns1.hdm-stuttgart.cloud`, and certificate requests use the Let's Encrypt staging environment.

## Configuration

Create local configuration files from the checked-in examples:

```bash
cp config.auto.tfvars.example config.auto.tfvars
cp secret.auto.tfvars.example secret.auto.tfvars
```

The default example in `config.auto.tfvars.example` creates two servers named `work-1` and `work-2`:

```terraform
dnsZone        = "g4.sdi.hdm-stuttgart.cloud"
serverBaseName = "work"
serverCount    = 2

privateSubnet = {
  dnsDomainName = "intern.g4.hdm-stuttgart.cloud"
  ipAndNetmask  = "10.0.1.0/24"
}
```

Adjust the DNS domains, server base name, server count, and private subnet for your environment.

Add credentials and SSH public keys to `lecture-excercises/cloud-provider/secret.auto.tfvars`:

```terraform
hcloud_token = "your_hetzner_cloud_api_token_here"
dns_secret   = "your_rfc2136_tsig_secret_here"

ssh_public_keys = {
  alice = "ssh-ed25519 AAAA..."
  bob   = "ssh-ed25519 AAAA..."
}
```

Do not commit `lecture-excercises/cloud-provider/secret.auto.tfvars` or real credentials.

## Shared Terraform Cloud state

The root configuration currently uses the shared Terraform Cloud workspace `simonbreit-dev/software-defined-infrastructure26`. Everyone using that workspace operates on the same state and potentially the same infrastructure.

Before planning or applying against it, coordinate with the other users and authenticate with:

```bash
terraform login
```

For isolated experimentation, use local state instead. Remove the `cloud` block from the root `terraform` block in `lecture-excercises/cloud-provider/main.tf`, then run `terraform init -reconfigure`. Without a `cloud` or remote backend block, Terraform stores state locally in `terraform.tfstate`. Do not commit local state because it can contain sensitive data.

Changing the backend does not copy or take ownership of existing infrastructure automatically. A fresh local state will treat the configured resources as new unless existing resources are imported or the state is migrated deliberately.

## Initialize and use the project

Initialize the providers and child modules:

```bash
terraform init
```

Format and validate the configuration:

```bash
terraform fmt -check -recursive
terraform validate
```

Review the proposed infrastructure changes carefully:

```bash
terraform plan
```

Apply only after confirming the selected state and reviewing all additions, modifications, and deletions:

```bash
terraform apply
```

Inspect the resulting server addresses, IDs, volume devices, and private-subnet information:

```bash
terraform output
```

After a successful apply, each public server gets SSH and SCP helper scripts in its own directory. For the default configuration, use them as follows:

```bash
./work-1/bin/ssh
./work-2/bin/ssh

./work-1/bin/scp ./local-file devops@work-1.g4.sdi.hdm-stuttgart.cloud:/tmp/
```

To remove infrastructure managed by the selected state:

```bash
terraform plan -destroy
terraform destroy
```

Always review the destroy plan, particularly when connected to the shared workspace.

## DNS testing limitation

The DNS record updates and ACME DNS-01 certificate flow could not be tested successfully. The authoritative DNS server rejected authenticated updates because its clock appeared to be unsynchronized. The Terraform wiring was reviewed, but successful DNS updates and certificate issuance remain unverified until the DNS server clock and TSIG authentication work correctly.

---

_Disclaimer: This README was created with the assistance of AI._
