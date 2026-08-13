# Cheat Sheet - Extension: Hardened Nginx reverse-proxy server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Installing reverse-proxy server

| Command                                                                | Description                       |
| ---------------------------------------------------------------------- | --------------------------------- |
| `dnf groupinstall "Development Tools" -y`                              | Install build dependencies        |
| `dnf install firewalld git wget openssl-devel -y`                      | Install required packages         |
| `git clone https://github.com/openresty/headers-more-nginx-module.git` | Download headers-more module      |
| `wget http://nginx.org/download/nginx-1.28.3.tar.gz`                   | Download Nginx source             |
| `./configure --add-module=...`                                         | Configure Nginx with headers-more |
| `make -j$(nproc)`                                                      | Compile Nginx                     |
| `make install`                                                         | Install Nginx to `/opt/nginx`     |

> NOTE: Nginx is **not** installed via DNF in this setup.

## Service Management

| Command                            | Description                        |
| ---------------------------------- | ---------------------------------- |
| `systemctl enable --now nginx`     | Enable and start Nginx immediately |
| `systemctl enable --now firewalld` | Enable and start firewalld         |
| `systemctl is-active nginx`        | Check if Nginx is running          |
| `systemctl is-enabled nginx`       | Check if Nginx starts on boot      |
| `systemctl status nginx`           | Show detailed Nginx status         |
| `systemctl reload nginx`           | Reload Nginx configuration         |
| `systemctl restart nginx`          | Restart Nginx completely           |
| `journalctl -u nginx`              | View Nginx service logs            |

## Connectivity & Network

| Command                                     | Description                                      |
| ------------------------------------------- | ------------------------------------------------ |
| `ip a`                                      | Show IP addresses                                |
| `hostname -I`                               | Show system IP address                           |
| `ss -tulpn`                                 | Show listening ports and processes               |
| `ss -tulpn \| grep nginx`                   | Verify Nginx ports                               |
| `ping 192.168.132.196`                      | Test connectivity to backend server              |
| `curl -I http://localhost`                  | Test local HTTP response                         |
| `curl -k https://localhost`                 | Test local HTTPS response (ignore cert warnings) |
| `curl -I http://<proxy_ip>`                 | Test HTTP redirect                               |
| `curl -k https://<proxy_ip>`                | Test HTTPS reverse proxy                         |
| `curl -I -H "Host: test" http://<proxy_ip>` | Test default-deny (444)                          |

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

| Command                                       | Description                     |
| --------------------------------------------- | ------------------------------- |
| `/opt/nginx/sbin/nginx -t`                    | Test Nginx configuration syntax |
| `/opt/nginx/sbin/nginx -T`                    | Dump full Nginx configuration   |
| `cat /opt/nginx/conf/nginx.conf`              | View main config file           |
| `grep proxy_pass /opt/nginx/conf/nginx.conf`  | Verify backend IP               |
| `grep server_name /opt/nginx/conf/nginx.conf` | Verify domain names             |
| `/opt/nginx/sbin/nginx -V`                    | Show compile options (modules)  |

## Header Manipulation (headers-more)

| Command                                              | Description                |
| ---------------------------------------------------- | -------------------------- |
| `grep more_set_headers /opt/nginx/conf/nginx.conf`   | Verify header injection    |
| `grep more_clear_headers /opt/nginx/conf/nginx.conf` | Verify header removal      |
| `/opt/nginx/sbin/nginx -V 2>&1 \| grep headers-more` | Confirm module compiled in |
| `curl -I https://<domain> --insecure`                | Verify spoofed headers     |

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
| `curl -I http://example.local`                   | Verify HTTP -> HTTPS redirect |
| `curl -k https://example.local`                  | Verify proxied HTTPS response |
| `curl -H "Host: example.local" http://127.0.0.1` | Test virtual host locally     |
| `curl -I https://example.local --insecure`       | Verify headers (spoofing)     |
| `tcpdump -i any port 443`                        | Inspect HTTPS traffic         |
| `tcpdump -i any host 192.168.132.196`            | Verify backend traffic        |

## Error Handling

| Command                                      | Description                     |
| -------------------------------------------- | ------------------------------- |
| `ls /var/ErrorPages/`                        | Verify custom error pages exist |
| `curl -k https://<domain>/nonexistent`       | Trigger custom error page       |
| `grep error_page /opt/nginx/conf/nginx.conf` | Verify error page configuration |

## Logs & Troubleshooting

| Command                              | Description                    |
| ------------------------------------ | ------------------------------ |
| `tail -f /opt/nginx/logs/access.log` | Monitor incoming requests      |
| `tail -f /opt/nginx/logs/error.log`  | Monitor Nginx errors           |
| `journalctl -u nginx`                | View service logs              |
| `curl -v https://<proxy_ip>`         | Verbose HTTPS debugging        |
| `/opt/nginx/sbin/nginx -t`           | Validate config before restart |
