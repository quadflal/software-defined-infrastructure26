package myproject;

import com.pulumi.Context;
import com.pulumi.Pulumi;
import com.pulumi.core.Output;
import com.pulumi.dns.ARecordSetArgs;
import com.pulumi.dns.inputs.ProviderUpdateArgs;
import com.pulumi.hcloud.*;
import com.pulumi.hcloud.inputs.FirewallRuleArgs;
import com.pulumi.resources.CustomResourceOptions;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import com.pulumi.*;
import com.pulumi.dns.ARecordSet;


public class App {
    public static void main(String[] args) {
        Pulumi.run(ctx -> {
            ctx.export("exampleOutput", Output.of("example"));
            stack(ctx);
        });
    }

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
    static private final String dnsZone = "gxy.sdi.hdm-stuttgart.cloud.";

    public static void stack(Context ctx) {
        final String[] servers = {"www", "cloud"};

        final String sshPubKey;
        try {
            sshPubKey = Files.readString(Path.of("/Users/quadflal/.ssh/id_ed25519.pub"));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

        new SshKey(sshPublicKeyIdentifier, SshKeyArgs.builder()
                .name(sshPublicKeyIdentifier)
                .publicKey(sshPubKey)
                .build());

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

        var dnsProvider = new com.pulumi.dns.Provider("dnsProvider", com.pulumi.dns.ProviderArgs.builder()
                .updates(ProviderUpdateArgs.builder()
                        .server("ns1.sdi.hdm-stuttgart.cloud")
                        .keyName("gxy.key.")
                        .keyAlgorithm("hmac-sha512")
                        .keySecret("dnsSecret")
                        .build())
                .build());

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
    }

}
