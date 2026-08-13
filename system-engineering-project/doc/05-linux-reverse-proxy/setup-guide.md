# Setup guide - Linux reverse proxy server (Nginx)

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Requirements for Starting

- VirtualBox
- Vagrant
- Git

Optional (for testing from host machine):

- curl
- Web browser

## Steps for deploying the Nginx reverse proxy server

1. Ensure that Vagrant is correctly installed and that you're running an up-to-date version:

   ```shell
   $ vagrant version
   ```

   You should see something like:

   ```shell
   $ Installed Version: 2.4.9
   $ Latest Version: 2.4.9
   ```

2. Using Git, clone and navigate to the repository:

   ```shell
   $ git clone https://github.com/HoGentTIN/system-engineering-project-25-26-sep2526-t02.git <destination-directory>
   $ cd <directory>/system-engineering-project-25-26-sep2526-t02/src
   ```

3. Initiate installation of the TFTP server:

   ```shell
   $ vagrant up reverse-proxy
   ```

   This will:
   - Deploy an AlmaLinux 10 virtual machine
   - Execute the provisioning script
   - Install and configure Nginx
   - Configure Firewalld
   - Configure SELinux
   - Generate a self-signed TLS certificate
   - Enable HTTP -> HTTPS redirection

4. Log in to the server:

   ```shell
   $ vagrant ssh reverse-proxy
   ```

5. Verify Nginx service status

   ```shell
   systemctl status nginx
   ```

   You should see:

   ```shell
   Active: active (running)
   ```

6. Verify Firewall Configuration

   ```shell
   sudo firewall-cmd --list-all
   ```

   Expected services:

   ```shell
   services: http https
   ```

7. Verify SELinux Configuration

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

8. Verify open ports

   ```shell
   sudo ss -tulnp | grep nginx
   ```

   Expected listening ports:

   ```shell
   :80
   :443
   ```

9. Test HTTP -> HTTPS Redirect

   From host machine:

   ```shell
   curl -I http://192.168.132.234
   ```

   Expected output:

   ```shell
   HTTP/1.1 301 Moved Permanently
   Location: https://192.168.132.234/
   ```

   Test HTTPS Reverse Proxy

   ```shell
   url -k https://192.168.132.234
   ```

   The response should return the backend webserver content.

   _Note: -k is required because the certificate is self-signed._

## Troubleshooting Common Issues

### Connection Timeouts

**Verify the service is running**

```shell
systemctl status nginx
```

**Check firewall settings**

```shell
sudo firewall-cmd --list-all
```

**Check firewall logs**

```shell
sudo journalctl -u firewalld | grep REJECT
```

### SELinux Blocking Proxy Traffic

502 errors, Nginx error log contains permission denied messages

Check SELinux boolean

```shell
getsebool httpd_can_network_connect
```

Enable if needed:

```shell
sudo setsebool -P httpd_can_network_connect 1
```

### TLS Certificate Warnings

Because the server uses a self-signed certificate:

- Browsers will show a security warning. **This is expected behaviour.**

### Configuration Errors After Changes

Always validate before reload:

```shell
sudo nginx -t
```

If successful:

```shell
sudo systemctl reload nginx
```

Check logs if errors occur:

```shell
sudo journalctl -u nginx
```

## Remarks

- The backend webserver must be reachable from the proxy server on port 80/TCP for functional validation.
- For production environments, replace the self-signed certificate with a Let's Encrypt certificate.
