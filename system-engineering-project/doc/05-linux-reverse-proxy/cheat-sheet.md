# Cheat Sheet - Linux reverse-proxy server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Installing reverse-proxy server

| Command                               | Description                    |
| ------------------------------------- | ------------------------------ |
| `sudo dnf install nginx firewalld -y` | Install Nginx and firewalld    |
| `sudo dnf upgrade -y`                 | Update all installed packages  |
| `rpm -q nginx`                        | Verify Nginx is installed      |
| `rpm -q firewalld`                    | Verify firewalld is installed  |
| `dnf list installed \| grep nginx`    | Check installed Nginx packages |

## Service Management

| Command                            | Description                                 |
| ---------------------------------- | ------------------------------------------- |
| `systemctl enable --now nginx`     | Enable and start Nginx immediately          |
| `systemctl enable --now firewalld` | Enable and start firewalld                  |
| `systemctl is-active nginx`        | Check if Nginx is running                   |
| `systemctl is-enabled nginx`       | Check if Nginx starts on boot               |
| `systemctl status nginx`           | Show detailed Nginx status                  |
| `systemctl reload nginx`           | Reload Nginx configuration without downtime |
| `systemctl restart nginx`          | Restart Nginx completely                    |
| `journalctl -u nginx`              | View Nginx service logs                     |

## Connectivity & Network

| Command                      | Description                                      |
| ---------------------------- | ------------------------------------------------ |
| `ip a`                       | Show IP addresses                                |
| `hostname -I`                | Show system IP address                           |
| `ss -tulpn`                  | Show listening ports and processes               |
| `ss -tulpn \| grep :80`      | Check if port 80 is listening                    |
| `ss -tulpn \| grep :443`     | Check if port 443 is listening                   |
| `ping 192.168.132.196`       | Test connectivity to backend server              |
| `curl -I http://localhost`   | Test local HTTP response                         |
| `curl -k https://localhost`  | Test local HTTPS response (ignore cert warnings) |
| `curl -I http://<proxy_ip>`  | Test HTTP redirect                               |
| `curl -k https://<proxy_ip>` | Test HTTPS reverse proxy                         |

## Firewall (firewalld)

| Command                                        | Description                        |
| ---------------------------------------------- | ---------------------------------- |
| `firewall-cmd --list-all`                      | Show active firewall configuration |
| `firewall-cmd --list-services`                 | List allowed services              |
| `firewall-cmd --permanent --add-service=http`  | Allow HTTP permanently             |
| `firewall-cmd --permanent --add-service=https` | Allow HTTPS permanently            |
| `firewall-cmd --reload`                        | Apply firewall changes             |
| `firewall-cmd --remove-service=http`           | Remove HTTP service                |

## Nginx Configuration

| Command                                                | Description                      |
| ------------------------------------------------------ | -------------------------------- |
| `nginx -t`                                             | Test Nginx configuration syntax  |
| `nginx -T`                                             | Dump full Nginx configuration    |
| `cat /etc/nginx/nginx.conf`                            | View main config file            |
| `ls /etc/nginx/conf.d/`                                | List virtual host configurations |
| `cat /etc/nginx/conf.d/reverseproxy.conf`              | View reverse proxy config        |
| `grep proxy_pass /etc/nginx/conf.d/reverseproxy.conf`  | Verify backend IP                |
| `grep server_name /etc/nginx/conf.d/reverseproxy.conf` | Verify domain names              |

## SSL / TLS Certificates

| Command                                                 | Description                    |
| ------------------------------------------------------- | ------------------------------ |
| `ls -l /etc/nginx/ssl/`                                 | List certificate files         |
| `openssl x509 -in nginx_selfsigned.crt -text -noout`    | View certificate details       |
| `openssl x509 -in nginx_selfsigned.crt -noout -subject` | Show certificate subject       |
| `stat -c "%a" nginx_selfsigned.key`                     | Check private key permissions  |
| `openssl rsa -in nginx_selfsigned.key -check`           | Validate private key integrity |

## SELinux

| Command                                    | Description                       |
| ------------------------------------------ | --------------------------------- |
| `getenforce`                               | Check SELinux mode                |
| `sestatus`                                 | Detailed SELinux status           |
| `getsebool httpd_can_network_connect`      | Verify reverse proxy boolean      |
| `setsebool -P httpd_can_network_connect 1` | Allow Nginx to connect to backend |
| `ausearch -m avc -ts recent`               | Check recent SELinux denials      |
| `restorecon -Rv /etc/nginx/`               | Restore SELinux contexts          |

## Reverse Proxy Validation

| Command                                          | Description                   |
| ------------------------------------------------ | ----------------------------- |
| `curl -I http://example.local`                   | Verify HTTP → HTTPS redirect  |
| `curl -k https://example.local`                  | Verify proxied HTTPS response |
| `curl -H "Host: example.local" http://127.0.0.1` | Test virtual host locally     |
| `tcpdump -i any port 443`                        | Inspect HTTPS traffic         |
| `tcpdump -i any host 192.168.132.196`            | Verify backend traffic        |

## Logs & Troubleshooting

| Command                             | Description                   |
| ----------------------------------- | ----------------------------- |
| `tail -f /var/log/nginx/access.log` | Monitor incoming requests     |
| `tail -f /var/log/nginx/error.log`  | Monitor Nginx errors          |
| `journalctl -xe`                    | View recent system errors     |
| `curl -v https://<proxy_ip>`        | Verbose HTTPS debugging       |
| `nginx -t`                          | Validate config before reload |
