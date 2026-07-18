# software-defined-infrastructure26

Repository for Software Defined Infrastructure course at Hochschule der Medien

# Lecture notes:

- [Notes](https://medieninformatik.cloud/sdi.html)

# How to run the terraform code

To run the latest version of the terraform code, please follow these steps:

- Configure the config.auto.tfvars:

```

dnsZone        = "gxy.sdi.hdm-stuttgart.cloud"
serverBaseName = "work"
serverCount    = 2
```

- Configure the secrets.auto.tfvars:

```

hcloudToken = "your-hcloud-token"
dnsSecret   = "your-dns-secret"

```

- Configure the ssh_key.auto.tfvars. In our example whe have set the public keys so we can work on the servers created.
  Feel free to replace ours with yours:

```
ssh_public_keys = {
  simon = "ssh-ed25519 key"
  alex  = "ssh-ed25519 key"
}
```

# Contributors

* [Alex Q](https://github.com/quadflal)
* [Simon B](https://github.com/simonbreit-dev)


