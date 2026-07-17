# Task 32 - A set of servers

1. A firewall allowing for ICMP based pinging, http and ssh access.

``` java

var firewall = new Firewall("stdFirewall", FirewallArgs.builder()
                .name("my-firewall")
                .rules(
                        FirewallRuleArgs.builder()
                                .direction("in")
                                .protocol("icmp")
                                .sourceIps("0.0.0.0/0", "::/0")
                                .build(),
                        FirewallRuleArgs.builder()
                                .direction("in")
                                .protocol("tcp")
                                .port("22")
                                .sourceIps("0.0.0.0/0", "::/0")
                                .build(),
                        FirewallRuleArgs.builder()
                                .direction("in")
                                .protocol("tcp")
                                .port("80")
                                .sourceIps("0.0.0.0/0", "::/0")
                                .build()
                )
                .build());

```

2. The aforementioned servers related to your firewall and each carrying a web server providing an entry page showing
   the server's DNS name.

``` java
for (String dnsBaseName : servers) {
            var userData = """
                    #cloud-config
                    packages:
                      - nginx
                    runcmd:
                      - systemctl enable nginx
                      - systemctl restart nginx
                      - printf '<html><body><h1>%s</h1></body></html>\\n' > /var/www/html/index.html
                    """.formatted(dnsBaseName + "." + dnsZone);

            var server = new Server(dnsBaseName + "-server", ServerArgs.builder()
                    .name(dnsBaseName)
                    .image("debian-13")
                    .serverType("cx23")
                    .location("nbg1")
                    .sshKeys(sshPublicKeyIdentifier)
                    .firewallIds(firewall.id().applyValue(id -> List.of(Integer.parseInt(id))))
                    .userData(userData)
                    .build());

            new ARecordSet(dnsBaseName + "-A-record", ARecordSetArgs.builder()
                    .zone(dnsZone)
                    .name(dnsBaseName)
                    .addresses(server.ipv4Address().applyValue(List::of))
                    .ttl(100.0)
                    .build(),
                    CustomResourceOptions.builder()
                            .provider(dnsProvider)
                            .build());

            ctx.export(dnsBaseName + " ipv4", server.ipv4Address());
        }
```

3. Related DNS entries.

``` java

var dnsProvider = new com.pulumi.dns.Provider("dnsProvider", com.pulumi.dns.ProviderArgs.builder()
                .updates(ProviderUpdateArgs.builder()
                        .server("ns1.sdi.hdm-stuttgart.cloud")
                        .keyName("gxy.key.")
                        .keyAlgorithm("hmac-sha512")
                        .keySecret("dnsSecret")
                        .build())
                .build());

```
