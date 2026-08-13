# Setup guide - Extension: Hardened Nginx reverse-proxy server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Overview

This server is a Linux hardened reverse proxy, based on AlmaLinux 10, designed to securely handle incoming web traffic using TLS,<br>
apply security hardening techniques, and safely forward requests to internal backend servers (WordPress & Nextcloud).
The hardening includes:

- Custom-compiled Nginx (no distribution package)
- Integration of the `headers-more-nginx-module` for header manipulation
- Reduced attack surface (default-deny server blocks)
- Server identity obfuscation (header hardening)
- Custom error pages
- SELinux enforcing with minimal permissions
- Firewall whitelisting (HTTP/HTTPS only)

## Requirements before starting

- VirtualBox
- Vagrant
- Git

Optional (for testing from host machine):

- curl
- Web browser

## Steps for deploying the Nginx reverse proxy server

### 1. Ensure that Vagrant is correctly installed and that you're running an up-to-date version:

```shell
$ vagrant version
```

Expected output (version may be higher):

    ```shell
    Installed Version: 2.4.9
    Latest Version: 2.4.9
    ```

### 2. Using Git, clone and navigate to the repository:

```shell
   $ git clone https://github.com/HoGentTIN/system-engineering-project-25-26-sep2526-t02.git <destination-directory>
   $ cd <directory>/system-engineering-project-25-26-sep2526-t02/src
```

### 3. Initiate installation of the reverse proxy server server:

```shell
$ vagrant up reverse-proxy
```

This will automatically:

- Deploy an AlmaLinux 10 virtual machine
- Compile and install custom Nginx (installed under `/opt/nginx`)
- Integrate the `headers-more` module
- Configure firewalld (HTTP/HTTPS only)
- Keep SELinux enforcing and apply required booleans
- Generate a self-signed TLS certificate (with SAN)
- Enable HTTP -> HTTPS redirection
- Activate default-deny behavior for unknown hosts
- Deploy custom error pages
- Configure reverse proxying for:
- Main website (WordPress)
- Nextcloud backend

### 4. Log in to the server:

```shell
$ vagrant ssh reverse-proxy
```

## Post-deployment verification

### 5. Verify Nginx service status

```shell
systemctl status nginx
```

Expected output:

```shell
Active: active (running)
```

Confirm that the custom installation path is used:

    ```shell
    /opt/nginx/sbin/nginx -v
    ```

### 6. Verify firewall hardening

```shell
sudo firewall-cmd --list-all
```

Expected services:

```shell
services: http https
```

> - No cockpit<br>
> - No unnecessary services<br>
> - Explicit allow-list only

### 7. Verify SELinux enforcement

Ensure SELinux is enforcing:

```shell
getenforce
```

Expected output:

```shell
Enforcing
```

Verify reverse proxy network permission:

```shell
getsebool httpd_can_network_connect
```

Expected output:

```shell
httpd_can_network_connect --> on
```

### 8. Verify listening ports

```shell
sudo ss -tulnp | grep nginx
```

Expected listening ports:

```shell
:80
:443
```

> **No other open ports should be present**

### 9. Test default-deny behavior

Send a request with an unknown Host header:

```shell
curl -I http://<proxy-ip> -H "Host: evil.test"
```

Expected output:

```shell
url: (52) Empty reply from server
```

> **Requests are dropped using return 444**

### 10. Test HTTP -> HTTPS redirection

From host machine:

```shell
curl -I url http://t02-domain404.internal
```

Expected output:

```shell
TTP/1.1 301 Moved Permanently
Location: https://t02-domain404.internal/
```

### 11. Test HTTPS reverse proxy

```shell
curl -Ik https://t02-domain404.internal
```

Expected result:

- Backend content is returned
- TLS is active
- HTTP/2 is negotiated (if supported by client)
- `-k` is required because the certificate is self-signed

### 12. Verify security headers

```shell
curl -I https://t02-domain404.internal --insecure
```

Expected header:

```shell
Server: Microsoft-IIS/10.0
```

And absent headers:

- X-Powered-By
- X-Pingback
- Link

> Header manipulation is applied using the headers-more module.

### 13. Verify custom error pages

Trigger an error (e.g. backend offline or invalid path):

```shell
curl -k https://t02-domain404.internal/nonexistent
```

Expected result:

- Custom error page is returned
- No reference to Nginx is visible
- Error pages are served from `/var/ErrorPages/`

## Troubleshooting

### 502 Bad Gateway

Possible SELinux denial:

```shell
getenforce
getsebool httpd_can_network_connect
```

Fix if required:

```shell
sudo setsebool -P httpd_can_network_connect 1
```

### Nginx configuration errors

```shell
sudo /opt/nginx/sbin/nginx -t
sudo journalctl -u nginx
```

### TLS Certificate Warnings

Because the server uses a self-signed certificate:

- Browsers will show a security warning. **This is expected behaviour.**

## Remarks

- Backend servers must be reachable from the proxy server
- No services are accessible without explicit configuration
- For production environments, replace the self-signed certificate with a Let's Encrypt certificate.
- This setup follows a defensive-by-default security model
- Header spoofing is implemented at runtime using the headers-more module (no source patching)
