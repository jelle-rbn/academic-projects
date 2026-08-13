# Test Plan - Extension: Hardened Nginx reverse-proxy server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

This test plan validates that the provisioning script correctly installs and configures the hardened Nginx reverse proxy server according to the defined specification.

All tests are executed on the reverse proxy VM, unless explicitly stated otherwise.

## Acceptance criteria

The reverse proxy server is considered correctly configured if:

- Nginx and firewalld are installed and active.
- Ports 80 and 443 are listening.
- HTTP redirects to HTTPS.
- HTTPS successfully proxies traffic to `192.168.132.196` (webserver).
- SSL certificate is generated correctly.
- Domain names are configured properly.
- No SELinux denials occur
- Reverse proxy functionality works over HTTPS
- Header manipulation is correctly applied
- Default-deny behaviour is enforced
- No manual configuration is required after provisioning
- All tests succeed

## Preconditions

1. Open a terminal on the host machine.

2. The Vagrant environment is up:

   ```shell
   vagrant up database
   vagrant up storage
   vagrant up haproxy
   vagrant up webserver
   vagrant up reverse-proxy
   ```

- Provisioning has completed without errors.

3. Connect to the reverse-proxy VM:

   ```shell
   vagrant ssh reverse-proxy
   ```

## 1. Software installation

### Test 1.1 - Verify Nginx is installed (custom build)

**Test procedure:**

```shell
/opt/nginx/sbin/nginx -v
```

**Expected Result**

Nginx version is displayed
Binary exists under `/opt/nginx/sbin/nginx`

![](../12-linux-reverse-proxy-hardened/img/Test%201.1%20-%20Verify%20Nginx%20is%20installed.png)

> If the binary is missing -> provisioning failed!

### Test 1.2 - Verify headers-more module is included

**Test procedure:**

```shell
/opt/nginx/sbin/nginx -V 2>&1 | grep headers-more
```

**Expected Result**

Output contains:

```shell
--add-module=...headers-more-nginx-module
```

![](../12-linux-reverse-proxy-hardened/img/Test%201.2%20-%20Verify%20headers-more%20module%20is%20included.png)

> If missing -> header manipulation will not work!

## 2. Systemd configuration

### Test 2.1 - Verify Nginx service is enabled and active

**Test procedure:**

```shell
systemctl is-enabled nginx
systemctl is-active nginx
```

**Expected Result**

![](../12-linux-reverse-proxy-hardened/img/Test%202.1%20-%20Verify%20Nginx%20service%20is%20enabled%20and%20active.png)

### Test 2.2 - Verify custom systemd unit file

**Test procedure:**

```shell
cat /lib/systemd/system/nginx.service
```

**Expected Result**

- File exists
- Contains references to `/opt/nginx/sbin/nginx`

![](../12-linux-reverse-proxy-hardened/img/Test%202.2%20-%20Verify%20custom%20systemd%20unit%20file.png)

> Confirms custom installation is used.

## 3. Configuration validation

### 3.1 Verify Nginx configuration syntax

**Test procedure:**

```shell
sudo /opt/nginx/sbin/nginx -t
```

**Expected Result**

![](../12-linux-reverse-proxy-hardened/img/Test%203.1%20Verify%20Nginx%20configuration%20syntax.png)

### Test 3.2 - Verify configuration file location

**Test procedure:**

```shell
ls -l /opt/nginx/conf/nginx.conf
```

**Expected Result**

- File exists
- Owned by root

![](../12-linux-reverse-proxy-hardened/img/Test%203.2%20-%20Verify%20configuration%20file%20location.png)

## 4. Firewall configuration

### Test 4.1 - Verify firewalld is active

**Test procedure:**

```shell
systemctl is-active firewalld
```

**Expected Result**

![](../12-linux-reverse-proxy-hardened/img/Test%204.1%20-%20Verify%20firewalld%20is%20active.png)

### Test 4.2 - Verify allowed services

**Test procedure:**

```shell
sudo firewall-cmd --list-services
```

**Expected Result**

![](../12-linux-reverse-proxy-hardened/img/Test%204.2%20-%20Verify%20allowed%20services.png)

> No additional services should be present.

## 5. SELinux validation

### Test 5.1 - Verify SELinux is enforcing

**Test procedure:**

```shell
getenforce
```

**Expected Result**

![](../12-linux-reverse-proxy-hardened/img/Test%205.1%20-%20Verify%20SELinux%20is%20enforcing.png)

### Test 5.2 - Verify required boolean

**Test procedure:**

```shell
getsebool httpd_can_network_connect
```

**Expected Result**

![](../12-linux-reverse-proxy-hardened/img/Test%205.2%20-%20Verify%20required%20boolean.png)

## 6. Network validation

### Test 6.1 - Verify listening ports

**Test procedure:**

```shell
sudo ss -tulnp | grep nginx
```

**Expected Result**

![](../12-linux-reverse-proxy-hardened/img/Test%206.1%20-%20Verify%20listening%20ports.png)

## Reverse proxy behaviour

### Test 7.1 - Test HTTP -> HTTPS redirect

**Test procedure:**

```shell
curl -I -H "Host: t02-domain404.internal" http://127.0.0.1
```

**Expected Result**

```shell
HTTP/1.1 301 Moved Permanently
Location: https://t02-domain404.internal/
```

![](../12-linux-reverse-proxy-hardened/img/Test%207.1%20-%20Test%20HTTP%20-%20HTTPS%20redirect.png)

### Test 7.2 - Test HTTPS reverse proxy

**Test procedure:**

```shell
curl -I --insecure -H "Host: t02-domain404.internal" https://127.0.0.1
```

**Expected Result**

- Backend response is returned
- TLS is active
- No connection errors

![](../12-linux-reverse-proxy-hardened/img/Test%207.2%20-%20Test%20HTTPS%20reverse%20proxy.png)

## 8. Security behaviour

### Test 8.1 - Verify default-deny behaviour

**Test procedure:**

```shell
curl -I http://192.168.132.234 -H "Host: unknown.test"
```

**Expected Result**

![](../12-linux-reverse-proxy-hardened/img/Test%208.1%20-%20Verify%20default-deny%20behaviour.png)

### Test 8.2 - Verify server header spoofing

**Test procedure:**

```shell
curl -I --insecure -H "Host: t02-domain404.internal" https://127.0.0.1
```

**Expected Result**

- The following headers must **NOT** be present:
  - X-Powered-By
  - X-Pingback
  - Link
- No Nginx version string is visible

```shell
Server: Microsoft-IIS/10.0
```

![](../12-linux-reverse-proxy-hardened/img/Test%208.2%20-%20Verify%20server%20header%20spoofing.png)

## 9. Error handling

### Test 9.1 - Verify custom error pages

**Test procedure:**

```shell
curl -k --resolve t02-domain404.internal:443:127.0.0.1 https://t02-domain404.internal/nonexistent
```

**Expected Result**

Expected result

- Custom error page is returned
- No reference to Nginx
- Content originates from `/var/ErrorPages/`

![](../12-linux-reverse-proxy-hardened/img/Test%209.1%20-%20Verify%20custom%20error%20pages.png)

### Test 9.2 - Verify backend error interception

Stop backend server and test:

**Test procedure:**

```shell
curl -I --insecure -H "Host: t02-domain404.internal" https://127.0.0.1
```

**Expected Result**

- Custom 502 page is returned
- No default Nginx error page

![](../12-linux-reverse-proxy-hardened/img/Test%209.2%20-%20Verify%20backend%20error%20interception.png)

## 10. TLS validation

### Test 10.1 - Verify TLS connection

**Test procedure:**

```shell
curl -I --resolve t02-domain404.internal:443:127.0.0.1 https://t02-domain404.internal
```

**Expected Result**

- TLS handshake succeeds
- Self-signed certificate warning is expected

![](../12-linux-reverse-proxy-hardened/img/Test%2010.1%20-%20Verify%20TLS%20connection.png)

### Test 10.2 - Verify HTTP/2 support

**Test procedure:**

```shell
curl -Ik --resolve t02-domain404.internal:443:127.0.0.1 https://t02-domain404.internal
```

**Expected Result**

- HTTP/2 is negotiated

![](../12-linux-reverse-proxy-hardened/img/Test%2010.2%20-%20Verify%20HTTP2%20support.png)
