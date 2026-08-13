# Test Plan - Reverse-proxy server (Nginx)

_Author: J. Robyn - jelle.robyn@student.hogent.be_

This test plan validates that the provisioning script correctly installs and configures the reverse proxy server according to the specification.

All tests are executed on the **reverse-proxy VM**, unless explicitly stated otherwise.

## Acceptance criteria

The reverse proxy server is considered correctly configured if:

- Nginx and firewalld are installed and active.
- Ports 80 and 443 are listening.
- HTTP redirects to HTTPS.
- HTTPS successfully proxies traffic to `192.168.132.196` (webserver).
- SELinux allows network connections.
- SSL certificate is generated correctly.
- Domain names are configured properly.
- No manual adjustments are required after provisioning.
- No SELinux denials occur

## Preconditions

- Vagrant environment is running:

```shell
vagrant up reverse-proxy
```

- Provisioning completed without visible errors.

## 1. Software installation

### Test 1.1 - Verify Nginx and firewalld are installed

**Test procedure:**

1. Open a terminal on the host machine.

2. Connect to the reverse-proxy VM:

```shell
vagrant ssh reverse-proxy
```

3. Display information about the installed package:

```shell
rpm -q nginx firewalld
```

**Expected Result**

- Both packages are installed:

![Verify Nginx and firewalld are installed](../07-linux-reverse-proxy/img/Verify_Nginx_and_firewalld_are_installed.png)

- No message stating "is not installed".

> If one of the packages is missing, provisioning failed!

## 2. Service status

### Test 2.1 - Verify Nginx is enabled and active

**Test procedure**

```shell
systemctl is-enabled nginx
systemctl is-active nginx
```

**Expected Result**

- Both commands return `enabled` and `active`.

![Verify Nginx is enabled and active](../07-linux-reverse-proxy/img/Verify_Nginx_is_enabled_and_active.png)

> If not active, reverse proxy functionality cannot work.

### Test 2.2 - Verify firewalld is enabled and active

**Test procedure**

```shell
systemctl is-enabled firewalld
systemctl is-active firewalld
```

**Expected Result**

- Both commands return `enabled` and `active`.

![Verify firewalld is enabled and active](../07-linux-reverse-proxy/img/Verify_firewalld_is_enabled_and_active.png)

## 3. Firewall configuration

### Test 3.1 - Verify HTTP and HTTPS are allowed

**Test procedure**

```shell
sudo firewall-cmd --list-services
```

> Do not rely on assumptions - explicitly check output!

**Expected Result**

- Output contains both `http` and `https`

![Verify HTTP and HTTPS are allowed](../07-linux-reverse-proxy/img/Verify_HTTP_and_HTTPS_are_allowed.png)

### Test 3.2 - Verify ports 80 and 443 are listening

**Test procedure**

```shell
sudo ss -tulpn | grep -E ':80|:443'
```

**Expected Result**

- Port 80 (TCP) is listening.

- Port 443 (TCP) is listening.

- Process associated with Nginx.

![Verify ports 80 and 443 are listening](../07-linux-reverse-proxy/img/Verify_ports_80_and_443_are_listening.png)

## 4. SELinux configuration

### Test 4.1 - Verify SELinux is enforcing

**Test procedure**

```shell
getenforce
```

**Expected Result**

![Verify SELinux is enforcing](../07-linux-reverse-proxy/img/Verify_SELinux_is_enforcing.png)

### Test 4.2 - Verify httpd_can_network_connect boolean

**Test procedure**

```shell
getsebool httpd_can_network_connect
```

**Expected Result**

![Verify httpd_can_network_connect boolean](../07-linux-reverse-proxy/img/Verify_httpd_can_network_connect_boolean.png)

> If set to off, proxying to backend will fail.

## 5. SSL certificate validation

### Test 5.1 - Verify SSL directory exists

**Test procedure**

```shell
ls -ld /etc/nginx/ssl
```

**Expected Result**

- Directory exists:

![Verify SSL directory exist](../07-linux-reverse-proxy/img/Verify_SSL_directory_exists.png)

### Test 5.2 - Verify certificate and key exist

**Test procedure**

```shell
ls -l /etc/nginx/ssl/
```

**Expected Result**

- Files exist:

![DVerify certificate and key exist](../07-linux-reverse-proxy/img/Verify_certificate_and_key_exist.png)

### Test 5.3 - Verify private key permissions

**Test procedure**

```shell
stat -c "%a" /etc/nginx/ssl/nginx_selfsigned.key
```

**Expected Result**

```bash
600
```

![Verify private key permissions](../07-linux-reverse-proxy/img/Verify_private_key_permissions.png)

> Private key must not be world-readable.

### Test 5.4 - Verify certificate subject

**Test procedure**

```shell
openssl x509 -in /etc/nginx/ssl/nginx_selfsigned.crt -noout -subject
```

**Expected Result**

- Subject contains:

```bash
CN=example.local
```

![Verify certificate subject](../07-linux-reverse-proxy/img/Verify_certificate_subject.png)

- Country and locality fields should match provisioning script.

## 6. Nginx configuration File

### Test 6.1 - Verify reverse proxy configuration file exists

**Test procedure**

```shell
ls -l /etc/nginx/conf.d/reverseproxy.conf
```

**Expected Result**

- File exists:

![Verify reverse proxy configuration file exists](../07-linux-reverse-proxy/img/Verify_reverse_proxy_config_file_exists.png)

### Test 6.2 - Verify HTTP to HTTPS redirect configuration

**Test procedure**

```shell
grep "return 301" /etc/nginx/conf.d/reverseproxy.conf
```

**Expected Result**

- Line contains:

![Verify HTTP to HTTPS redirect configuration](../07-linux-reverse-proxy/img/Verify_HTTP_to_HTTPS_redirect_config.png)

### Test 6.3 - Verify proxy_pass configuration

**Test procedure**

```shell
grep proxy_pass /etc/nginx/conf.d/reverseproxy.conf
```

**Expected Result**

- IP must match backend webserver IP exactly.

```bash
proxy_pass `192.168.132.196`;
```

![Verify proxy_pass configuration](../07-linux-reverse-proxy/img/Verify_proxy_pass_config.png)

### Test 6.4 - Verify configuration syntax

**Test procedure**

```shell
sudo nginx -t
```

**Expected Result**

![Verify configuration syntax](../07-linux-reverse-proxy/img/Verify_config_syntax.png)

> Any error = configuration invalid.

## 7. Functional validation - HTTP redirect

### Test 7.1 - Verify HTTP redirects to HTTPS

**Test procedure**

From host machine:

```shell
curl -I http://192.168.132.234
```

> Do not use https here - test plain HTTP.

**Expected Result**

Response contains:

```bash
HTTP/1.1 301
Location: https://...
```

![Verify HTTP redirects to HTTPS](../07-linux-reverse-proxy/img/Verify_HTTP_redirects_to_HTTPS.png)

> Status must be 301 redirect.

## 8. Functional validation - HTTPS access

### Test 8.1 - Verify HTTPS responds

> Make sure the webserver is activated before proceeding with this test!

**Test procedure**

```shell
curl -k https://192.168.132.234
```

> Use -k because certificate is self-signed.

**Expected Result**

- HTML content of backend webserver is returned.

- No connection refused.

- No timeout.

![Verify HTTPS responds](../07-linux-reverse-proxy/img/Verify_HTTPS_responds.png)

## 9. Reverse proxy backend validation

### Test 9.1 - Confirm traffic reaches backend server

> Make sure the webserver is activated before proceeding with this test!

**Test procedure**

1. SSH into backend webserver (192.168.132.196).

```shell
vagrant ssh webserver
```

2. Check Apache logs:

```shell
sudo tail -f /var/log/httpd/access_log
```

3. From host machine:

```shell
curl -k https://192.168.132.234
```

**Expected Result**

- New entry appears in backend access log.

- Source IP equals proxy server IP (192.168.132.234).

![Confirm traffic reaches backend server](../07-linux-reverse-proxy/img/Confirm_traffic_reaches_backend_server.png)

This confirms proxy forwarding is active.

## 10. Domain name validation

### Test 10.1 - Verify server_name configuration

**Test procedure**

```shell
grep server_name /etc/nginx/conf.d/reverseproxy.conf
```

**Expected Result**

Contains:

```bash
example.local
www.example.local
```

![ Verify server_name configuration](../07-linux-reverse-proxy/img/Verify_server_name_config.png)
