# Task 21 - Enhancing your web server

### Enhance the secured Nginx server to:

- Create an IPv4 DNS record for `gXY.sdi.hdm-stuttgart.cloud`.
- Create another IPv4 DNS record for `www.gXY.sdi.hdm-stuttgart.cloud`.
- Point both records to the same server.
- Install Certbot and its Nginx integration.
- Test certificate issuance against the Let's Encrypt staging environment first.
- Request a trusted production certificate only after staging succeeds.
- Serve both hostnames over HTTPS.

This task is performed manually. The commands and results below are templates: replace values enclosed in angle brackets with the values for the deployed server and record the actual output where indicated.

## Solution

### 1. Define the exercise values

Use the assigned group number in place of `XY`. The two required hostnames are:

```text
g4.sdi.hdm-stuttgart.cloud
www.g4.sdi.hdm-stuttgart.cloud
```

Obtain the server's public IPv4 address from Terraform:

```bash
terraform output
```

Output:

```text
device_string = "/dev/disk/by-id/scsi-0HC_Volume_106396791"
hello_id = "152073519"
hello_ip_addr = "178.104.204.33"
hello_location = "nbg1"
```

Values used for the remaining steps:

```text
Group number: 4
Server IPv4:  178.104.204.33
Base name:    g4.sdi.hdm-stuttgart.cloud
WWW name:     www.g4.sdi.hdm-stuttgart.cloud
Email:        sb322@hdm-stuttgart.de
```

### 2. Create both DNS A records with `nsupdate`

Export the supplied TSIG key as an environment variable. Replace the placeholders with the assigned key name and secret:

```bash
export HMAC='hmac-sha512:<key-name>:<key-secret>'
```

> **Security note:** The HMAC value grants permission to update DNS records. Do not add the real value to the repository, documentation, or shell history. Clear the variable with `unset HMAC` after completing the updates.

Start an authenticated dynamic DNS update session:

```bash
nsupdate -y "$HMAC"
```

Add the A record for the base hostname. The value `10` is the record's time to live in seconds:

```text
> server ns1.hdm-stuttgart.cloud
> update add g4.sdi.hdm-stuttgart.cloud 10 A 178.104.204.33
> send
```

Add the second A record for the `www` hostname in the same session:

```text
> update add www.g4.sdi.hdm-stuttgart.cloud 10 A 178.104.204.33
> send
> quit
```


No output after `send` normally indicates that the update was accepted. Query the authoritative name server directly to verify the base record:

```bash
dig +noall +answer @ns1.hdm-stuttgart.cloud g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
g4.sdi.hdm-stuttgart.cloud. 10  IN      A       178.104.204.33
```

Verify the `www` record against the authoritative name server:

```bash
dig +noall +answer @ns1.hdm-stuttgart.cloud www.g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
www.g4.sdi.hdm-stuttgart.cloud. 10 IN   A       178.104.204.33
```

Finally, query a public resolver to confirm that both updates are publicly visible:

```bash
dig +noall +answer @8.8.8.8 g4.sdi.hdm-stuttgart.cloud
dig +noall +answer @8.8.8.8 www.g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
g4.sdi.hdm-stuttgart.cloud. 10  IN      A       178.104.204.33
www.g4.sdi.hdm-stuttgart.cloud. 10 IN   A       178.104.204.33
```

Both public queries must return the server's IPv4 address before requesting a certificate. Clear the HMAC variable when the DNS updates are complete:

```bash
unset HMAC
```

### 3. Verify the HTTP virtual host

Connect to the server:

```bash
./bin/ssh
```

Check the active Nginx configuration:

```bash
sudo nginx -t
```

Output:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Verify that both names reach the server over HTTP:

```bash
curl -I http://g4.sdi.hdm-stuttgart.cloud
curl -I http://www.g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 17 Jul 2026 16:27:01 GMT
Content-Type: text/html
Content-Length: 69
Last-Modified: Fri, 17 Jul 2026 16:15:18 GMT
Connection: keep-alive
ETag: "6a5a5516-45"
Accept-Ranges: bytes

HTTP/1.1 200 OK
Server: nginx
Date: Fri, 17 Jul 2026 16:27:04 GMT
Content-Type: text/html
Content-Length: 69
Last-Modified: Fri, 17 Jul 2026 16:15:18 GMT
Connection: keep-alive
ETag: "6a5a5516-45"
Accept-Ranges: bytes
```

The existing Hetzner firewall is used, so no host-firewall commands are required in this task. HTTP on port `80` must remain reachable for Certbot's Nginx validation. HTTPS on port `443` must be allowed for the final tests.

### 4. Install Certbot for Nginx

Update the package index and install Certbot with its Nginx plugin:

```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx
```
Record the installed Certbot version:

```bash
certbot --version
```

Output:

```text
certbot 4.0.0
```

### 5. Request and install a staging certificate

Use Let's Encrypt's staging environment until DNS and Nginx validation work correctly. Staging certificates are intentionally not trusted by browsers.

```bash
sudo certbot --nginx --staging \
  -d g4.sdi.hdm-stuttgart.cloud \
  -d www.g4.sdi.hdm-stuttgart.cloud \
  --email sb322@hdm-stuttgart.de \
  --agree-tos \
  --no-eff-email
```

Run only one of these two staging commands. Output placeholder:

```text
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/g4.sdi.hdm-stuttgart.cloud/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/g4.sdi.hdm-stuttgart.cloud/privkey.pem
This certificate expires on 2026-10-15.
These files will be updated when the certificate renews.
Certbot has set up a scheduled task to automatically renew this certificate in the background.

Deploying certificate
Successfully deployed certificate for g4.sdi.hdm-stuttgart.cloud to /etc/nginx/sites-enabled/default
Successfully deployed certificate for www.g4.sdi.hdm-stuttgart.cloud to /etc/nginx/sites-enabled/default
Congratulations! You have successfully enabled HTTPS on https://g4.sdi.hdm-stuttgart.cloud and https://www.g4.sdi.hdm-stuttgart.cloud
```

### 6. Test the staging configuration

Confirm that Nginx remains valid after Certbot modifies it:

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
```

Output:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful

● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-07-17 16:15:14 UTC; 15min ago
 Invocation: 8f4944524fe24bff92dd5c635e4ce942
       Docs: man:nginx(8)
   Main PID: 1070 (nginx)
      Tasks: 3 (limit: 4556)
     Memory: 4M (peak: 6.7M)
        CPU: 121ms
     CGroup: /system.slice/nginx.service
             ├─1070 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─1604 "nginx: worker process"
             └─1605 "nginx: worker process"

Jul 17 16:15:14 myserver systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Jul 17 16:15:14 myserver systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
```

Test both HTTPS endpoints. Because the staging certificate is not publicly trusted, `curl -k` is used only for this staging check:

```bash
curl -kI https://g4.sdi.hdm-stuttgart.cloud
curl -kI https://www.g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 17 Jul 2026 16:31:50 GMT
Content-Type: text/html
Content-Length: 69
Last-Modified: Fri, 17 Jul 2026 16:15:18 GMT
Connection: keep-alive
ETag: "6a5a5516-45"
Accept-Ranges: bytes

HTTP/1.1 200 OK
Server: nginx
Date: Fri, 17 Jul 2026 16:31:57 GMT
Content-Type: text/html
Content-Length: 69
Last-Modified: Fri, 17 Jul 2026 16:15:18 GMT
Connection: keep-alive
ETag: "6a5a5516-45"
Accept-Ranges: bytes
```

Inspect the issued certificate and verify that it covers both DNS names:

```bash
echo | openssl s_client \
  -connect g4.sdi.hdm-stuttgart.cloud:443 \
  -servername g4.sdi.hdm-stuttgart.cloud 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates -ext subjectAltName
```

Output:

```text
issuer=C=US, O=Let's Encrypt, CN=(STAGING) Baloney Bulgur YE2
subject=CN=g4.sdi.hdm-stuttgart.cloud
notBefore=Jul 17 15:31:20 2026 GMT
notAfter=Oct 15 15:31:19 2026 GMT
X509v3 Subject Alternative Name:
    DNS:g4.sdi.hdm-stuttgart.cloud, DNS:www.g4.sdi.hdm-stuttgart.cloud
```

### 7. Replace staging with a production certificate

After both staging endpoints work, request the trusted certificate by running the same command without `--staging` or `--test-cert`. The `--force-renewal` option requests replacement of the installed staging certificate:

```bash
sudo certbot --nginx --force-renewal \
  -d g4.sdi.hdm-stuttgart.cloud \
  -d www.g4.sdi.hdm-stuttgart.cloud \
  --email sb322@hdm-stuttgart.de \
  --agree-tos \
  --no-eff-email
```

Output:

```text
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/g4.sdi.hdm-stuttgart.cloud/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/g4.sdi.hdm-stuttgart.cloud/privkey.pem
This certificate expires on 2026-10-15.
These files will be updated when the certificate renews.
Certbot has set up a scheduled task to automatically renew this certificate in the background.

Deploying certificate
Successfully deployed certificate for g4.sdi.hdm-stuttgart.cloud to /etc/nginx/sites-enabled/default
Successfully deployed certificate for www.g4.sdi.hdm-stuttgart.cloud to /etc/nginx/sites-enabled/default
Your existing certificate has been successfully renewed, and the new certificate has been installed.
```

### 8. Verify trusted HTTPS access

The final certificate should now validate without disabling certificate verification:

```bash
curl -I https://g4.sdi.hdm-stuttgart.cloud
curl -I https://www.g4.sdi.hdm-stuttgart.cloud
```

Output:

```text
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 17 Jul 2026 16:33:27 GMT
Content-Type: text/html
Content-Length: 69
Last-Modified: Fri, 17 Jul 2026 16:15:18 GMT
Connection: keep-alive
ETag: "6a5a5516-45"
Accept-Ranges: bytes

HTTP/1.1 200 OK
Server: nginx
Date: Fri, 17 Jul 2026 16:33:29 GMT
Content-Type: text/html
Content-Length: 69
Last-Modified: Fri, 17 Jul 2026 16:15:18 GMT
Connection: keep-alive
ETag: "6a5a5516-45"
Accept-Ranges: bytes
```

List the certificate known to Certbot:

```bash
sudo certbot certificates
```

Output :

```text
Found the following certs:
  Certificate Name: g4.sdi.hdm-stuttgart.cloud
    Serial Number: 524fcd6ae86782047582b42983d37370817
    Key Type: ECDSA
    Domains: g4.sdi.hdm-stuttgart.cloud www.g4.sdi.hdm-stuttgart.cloud
    Expiry Date: 2026-10-15 15:34:32+00:00 (VALID: 89 days)
    Certificate Path: /etc/letsencrypt/live/g4.sdi.hdm-stuttgart.cloud/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/g4.sdi.hdm-stuttgart.cloud/privkey.pem
```

Test the renewal configuration without issuing another production certificate:

```bash
sudo certbot renew --dry-run
```

Output:

```text
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/g4.sdi.hdm-stuttgart.cloud.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Simulating renewal of an existing certificate for g4.sdi.hdm-stuttgart.cloud and www.g4.sdi.hdm-stuttgart.cloud

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Congratulations, all simulated renewals succeeded:
  /etc/letsencrypt/live/g4.sdi.hdm-stuttgart.cloud/fullchain.pem (success)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

## Result

Both DNS A records point to the same server. Nginx responds to the base and `www` hostnames, and a single Let's Encrypt certificate covers both names. Certificate issuance was tested against the staging environment before a trusted production certificate was requested, reducing the risk of reaching production rate limits.
