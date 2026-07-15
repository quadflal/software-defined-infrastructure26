# Task 5 - MI Gitlab access by ssh

### In this exercise we pretend you can access a host A by ssh. On contrary a second host B can only be accessed from host A e.g. residing in a restricted network. You may thus:

1. Create two hosts A and B with ssh key access being enabled for both of your group.
2. Enable agent forwarding from your local workstation to host A.
3. Login to host A by ssh.
4. Continue login to host B.
5. Close both connections thus getting back to your workstation.
6. Login to host B.
7. Still on B try logging in to Host A.

What do you observe? Why does it happen?

### Solution

Enable SSH agent forwarding for the first connection to host A:

```bash
ssh-add ~/.ssh/id_ed25519
ssh -A root@<host-a-ip>
```

From host A it is now possible to connect to host B without copying the private key to host A:

```bash
ssh root@<host-b-ip>
```

This works because the SSH agent on the local workstation is forwarded to host A. Host A can ask the local agent to authenticate the connection to host B, but it never receives the private key itself.

After closing both SSH sessions and returning to the workstation, a direct login to host B only works if host B is directly reachable from the workstation:

```bash
ssh root@<host-b-ip>
```

When logged in directly on host B, logging from B back to host A fails unless agent forwarding was enabled for the connection to B as well:

```bash
ssh root@<host-a-ip>
```

The reason is that SSH agent forwarding is only active for the current SSH session chain. In the first login path the chain is:

```text
workstation -> host A -> host B
```

The forwarded agent is available on host A and then on host B if forwarding is allowed further. In the second path the chain is:

```text
workstation -> host B -> host A
```

If the connection to host B was opened without `-A`, host B has no access to the workstation's SSH agent. Therefore it cannot authenticate to host A using the local private key.
