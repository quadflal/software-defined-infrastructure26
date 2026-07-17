# Task 31 - ssh keys and cloud-init script

1. A login user's ssh public key allowing for remote logins without password.
2. A cloud-init script as in Working on Cloud-init.

Solution for 1 + 2 :

``` java

static private final String cloudInitCode = """
            #cloud-config
            packages:
              - nginx
            runcmd:
              - systemctl enable nginx
              - rm /var/www/html/*
              - echo I am Nginx @ $(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com)
                created $(date -u) >> /var/www/html/index.html""";

static private final String sshPublicKeyIdentifier = "userSshPublicKey";

final String content;

        {
            try {
                content = Files.readString(Path.of("/Users/quadflal/.ssh/id_ed25519.pub"));
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }

        new SshKey(sshPublicKeyIdentifier, SshKeyArgs.builder()
                .name(sshPublicKeyIdentifier).publicKey(content).build()
        );

Server node1 = new Server(
                "Server1",
                ServerArgs.builder()
                        .name("node1")
                        .image("debian-13")
                        .serverType("cx23")
                        .location("nbg1")
                        .sshKeys(sshPublicKeyIdentifier)
                        .userData(cloudInitCode)
                        .build()
        );

```