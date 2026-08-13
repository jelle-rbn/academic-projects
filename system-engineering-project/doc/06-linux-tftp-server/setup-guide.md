# Setup guide - Linux TFTP server

_Author: J. Robyn - jelle.robyn@student.hogent.be_

## Requirements for Starting

- VirtualBox
- Git

## Steps for deploying the TFTP server

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
   $ vagrant up tftp
   ```

4. Log in to the server:

   ```shell
   $ vagrant ssh tftp
   ```

## Utilising the TFTP server

The main function of this server is to bootstrap network devices with their correct settings.
This enables rapid deployment of the physical network infrastructure.

When installing a new network router or switch, a fitting configuration can be downloaded from the TFTP server:

```
Router# copy tftp://192.168.102.133/[filename] startup-config
```

Network devices can also upload (backup) their configuration with the following command:

```
Router# copy running-config tftp://192.168.132.227/upload/
```

_Note #1: the examples above use Cisco IOS commands_<br>
_Note #2: `The server uses /var/lib/tftpboot` as its root directory. You do not need to specify the full Linux path in your network device commands._

## Troubleshooting Common Issues

### Permission Denied Errors

If clients receive permission errors, verify SELinux contexts and file ownership:

**Verify write permissions for the tftp user**

```shell
ls -ld /var/lib/tftpboot/upload
```

**Check SELinux status**

```shell
sudo getsebool -a | grep tftp
```

**Enable TFTP anonymous write access (essential for uploads)**

```shell
sudo setsebool -P tftp_anon_write on
```

**Verify file contexts**

```shell
ls -Z /var/lib/tftpboot/
```

### Connection Timeouts

Timeout issues typically indicate firewall or network routing problems:

**Verify the service is running**

```shell
systemctl status tftp.socket
```

**Verify the socket is listening**

```shell
sudo ss -ulnp | grep :69
```

**Test connectivity from client**

```shell
nc -u -v 192.168.102.133 69
```

**Check firewall logs**

```shell
sudo journalctl -u firewalld | grep REJECT
```

### Large File Transfer Failures

TFTP's default 512-byte block size can cause issues with large files. Enable block size negotiation:

**Modify service configuration to allow larger blocks**

```shell
ExecStart=/usr/sbin/in.tftpd -s -c -B 1468 /var/lib/tftpboot
```

## Remarks

- This server is configured to provide write access to network devices. By doing so, this provides version control and disaster recovery capabilities.
- Consider isolating TFTP services on a dedicated management VLAN.
- Avoid using `chmod 777` in production. The `755` permissions allow the TFTP server to read files while preventing unauthorized writes. Only the `tftp` user needs write access for legitimate use cases.
