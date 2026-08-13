# Cheat Sheet - Linux TFTP server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## TFTP Server Arguments

| Argument | Purpose              | Use Case                                 |
| -------- | -------------------- | ---------------------------------------- |
| `-s`     | Secure mode (chroot) | Required for security in all deployments |
| `-c`     | Allow file creation  | Receiving config backups from devices    |
| `-v`     | Verbose logging      | Troubleshooting transfer issues          |
| `-B`     | Set block size limit | Optimize for large file transfers        |

_For example:_

```shell
ExecStart=/usr/sbin/in.tftpd -s -c -v --verbosity 4 /var/lib/tftpboot
```

## Installing TFTP server

| Command                                | Description                             |
| -------------------------------------- | --------------------------------------- |
| `sudo dnf install tftp-server tftp -y` | Install TFTP server components          |
| `sudo dnf upgrade -y`                  | Update all installed packages           |
| `rpm -q tftp-server`                   | Verify TFTP server package is installed |
| `rpm -q tftp`                          | Verify TFTP client is installed         |
| `dnf list installed \| grep tftp`      | List installed TFTP-related packages    |

## Service Management (systemd & socket)

| Command                              | Description                                              |
| ------------------------------------ | -------------------------------------------------------- |
| `systemctl enable --now tftp.socket` | Enable and start TFTP socket                             |
| `systemctl status tftp.socket`       | Check socket status                                      |
| `systemctl is-active tftp.socket`    | Check if socket is running                               |
| `systemctl is-enabled tftp.socket`   | Check if socket starts at boot                           |
| `systemctl daemon-reload`            | Reload systemd configuration                             |
| `journalctl -u tftp`                 | View TFTP service logs                                   |
| `systemctl status tftp.service`      | Check if the server is handling a transfer at the moment |
| `sudo systemctl stop tftp.socket`    | Shutdown TFTP-server                                     |

## Connectivity & Network

| Command                  | Description                                 |
| ------------------------ | ------------------------------------------- |
| `ip addr show`           | Show the IP-address of the server           |
| `hostname -I`            | Show system IP                              |
| `ping <client_ip>`       | Test client connectivity                    |
| `ss -ulpn \| grep :69`   | Verify if the server listens on UDP port 69 |
| `tcpdump -i any port 69` | Capture TFTP traffic                        |
| `tftp <server_ip>`       | Connect to TFTP server (client test)        |

## Firewall (firewalld)

| Command                                       | Description               |
| --------------------------------------------- | ------------------------- |
| `systemctl enable --now firewalld`            | Start and enable firewall |
| `firewall-cmd --permanent --add-service=tftp` | Allow TFTP permanently    |
| `firewall-cmd --reload`                       | Apply firewall changes    |
| `firewall-cmd --list-services`                | Verify TFTP is allowed    |
| `firewall-cmd --remove-service=tftp`          | Remove TFTP service       |

## File & Permission Management

| Command                                 | Description                                                   |
| --------------------------------------- | ------------------------------------------------------------- |
| `ls -ld /var/lib/tftpboot`              | Check TFTP root directory                                     |
| `ls -ld /var/lib/tftpboot/upload`       | Check upload directory                                        |
| `stat -c "%a" /var/lib/tftpboot`        | Check numeric permissions                                     |
| `stat -c "%a" /var/lib/tftpboot/upload` | Check upload directory permissions                            |
| `chown -R tftp:tftp /var/lib/tftpboot`  | Set correct ownership                                         |
| `chmod 755 /var/lib/tftpboot`           | Set root permissions                                          |
| `chmod 770 /var/lib/tftpboot/upload`    | Set upload permissions                                        |
| `sudo tail -f /var/log/messages`        | Follow live systemlogs (handy with -v for transfer debugging) |

## Users & Groups

| Command              | Description                       |
| -------------------- | --------------------------------- |
| `getent group tftp`  | Verify tftp group exists          |
| `getent passwd tftp` | Verify tftp user exists           |
| `id tftp`            | Show user ID and group membership |
| `groupadd -r tftp`   | Create system group               |

## SELinux

| Command                               | Description                                                   |
| ------------------------------------- | ------------------------------------------------------------- |
| getsebool tftp_anon_write             | Check if TFTP writing is allowed by policy                    |
| sudo setsebool -P tftp_anon_write 1   | Enable writing permissions for TFTP                           |
| sudo restorecon -Rv /var/lib/tftpboot | Restore the right SELinux labels on all files and directories |

| Command                                                       | Description                                 |
| ------------------------------------------------------------- | ------------------------------------------- |
| `getenforce`                                                  | Check SELinux mode                          |
| `sestatus`                                                    | Detailed SELinux status                     |
| `getsebool tftp_anon_write`                                   | Check if uploads are allowed                |
| `setsebool -P tftp_anon_write 1`                              | Allow TFTP anonymous write                  |
| `semanage fcontext -l \| grep tftpdir_t`                      | Check file context rules                    |
| `semanage fcontext -a -t tftpdir_t "/var/lib/tftpboot(/.*)?"` | Register tftp directory in SELinux database |
| `restorecon -Rv /var/lib/tftpboot`                            | Apply SELinux context                       |
| `ls -Zd /var/lib/tftpboot`                                    | Verify SELinux label                        |

## Configuration Inspection

| Command                                                           | Description                   |
| ----------------------------------------------------------------- | ----------------------------- |
| `cat /etc/systemd/system/tftp.service.d/override.conf`            | View TFTP override config     |
| `grep ExecStart /etc/systemd/system/tftp.service.d/override.conf` | Verify correct flags          |
| `systemctl cat tftp.service`                                      | Show effective systemd config |

## File Operations (Functional Testing)

| Command                                    | Description            |
| ------------------------------------------ | ---------------------- |
| `echo "test" > /var/lib/tftpboot/test.txt` | Create test file       |
| `tftp <server_ip>`                         | Connect to TFTP server |
| `get test.txt`                             | Download file          |
| `put upload.txt`                           | Upload file            |
| `quit`                                     | Exit TFTP client       |
| `cat /var/lib/tftpboot/test.txt`           | Verify downloaded file |
| `cat /var/lib/tftpboot/upload.txt`         | Verify uploaded file   |

## File Operations (Manual Testing)

| Command                        | Description                                               |
| ------------------------------ | --------------------------------------------------------- |
| `tftp 127.0.0.1 -c get <file>` | Test from the server to check if a file can be downloaded |
| `tftp 127.0.0.1 -c put <file>` | Test from the server to check if a file can be uploaded   |
