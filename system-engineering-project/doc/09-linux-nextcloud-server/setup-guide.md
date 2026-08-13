# Setup guide – Nextcloud server

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

This guide describes the step-by-step procedure to deploy the Nextcloud server virtual machine with Vagrant. The provisioning is fully automated and installs Apache, PHP 8.2, Valkey caching, the Nextcloud application itself, LDAP/AD integration, a default calendar, and the Forms app.

## Prerequisites

Ensure the following software is installed on your host machine:
- Oracle VirtualBox
- Vagrant
- Git

The following VMs must be up and running **before** provisioning the Nextcloud server, otherwise provisioning will fail:

| VM | Role | IP |
| :--- | :--- | :--- |
| `windowsdc` | Active Directory domain controller (LDAP source) | `192.168.132.194` |
| `nextcloud-database` | MariaDB database backend | `192.168.132.198` |
| `reverse-proxy` | HTTPS reverse proxy | `192.168.132.234` |

## Steps

1. Open a terminal or command prompt.
2. Clone the project repository using `git clone`.
3. Navigate to the directory `/system-engineering-project-25-26-sep2526-t02/src`. This is where the `Vagrantfile` and provisioning scripts are located.
4. Bring up the prerequisite VMs first if they are not already running:
   ```
   vagrant up nextcloud-database windowsdc reverse-proxy
   ```
5. Launch the Nextcloud server with:
   ```
   vagrant up nextcloud-server
   ```

## Provisioning workflow

The deployment is fully automated by Vagrant. When `vagrant up nextcloud-server` is executed, the following occurs in order:

### Common configuration

The `common.sh` and `util.sh` scripts are sourced at the start of provisioning and provide shared helper functions (`log`, `success`, `error`, `run`) used throughout. The top of `nextcloud-server.sh` defines all key parameters:

- **Server hostname:** `nextcloud-server`
- **Server IP:** `192.168.132.197`
- **Nextcloud version:** `31.0.4`
- **Admin account:** username `admin`, password `admin404`
- **Regular user account:** `linustorvalds` (display name: Linus Torvalds)
- **Database host:** `192.168.132.198` (nextcloud-database VM)
- **Database name / user:** `nextcloud` / `nextcloud`
- **Trusted proxy IP:** `192.168.132.234` (reverse-proxy VM)
- **Public domain:** `nextcloud.t02-domain404.internal`

### Step 1 – Dependencies and Apache

System dependencies (`curl`, `wget`, `bzip2`, `policycoreutils-python-utils`, etc.) are installed via `dnf`. Apache (`httpd`) is installed and a `VirtualHost` configuration is written to `/etc/httpd/conf.d/nextcloud.conf` to serve the Nextcloud web root over HTTP on port 80. PHP-FPM is configured as the FastCGI handler.

### Step 2 – PHP 8.2

The EPEL and Remi repositories are enabled and PHP 8.2 is installed from the Remi stream. Both required modules (curl, dom, gd, xml, mbstring, zip, pdo, mysqlnd, …) and recommended modules (intl, sodium, opcache, apcu, redis, ldap, imagick, …) are installed. PHP limits in `/etc/php.ini` and `/etc/php-fpm.d/www.conf` are tuned:

- `memory_limit` → `512M`
- `max_execution_time` → `360`
- `upload_max_filesize` → `512M`
- `post_max_size` → `512M`

### Step 3 – Valkey caching

Valkey (a Redis-compatible in-memory cache) is installed and bound to `127.0.0.1` only. A password (`domain404`) is set in `/etc/valkey/valkey.conf`. The service is enabled and started. Nextcloud is later configured to use Valkey for both distributed caching and distributed locking, and APCu for local caching.

### Step 4 – Nextcloud download and installation

The Nextcloud archive for the configured version is downloaded from `download.nextcloud.com` together with its SHA-256 checksum file. The checksum is verified before extraction. The archive is extracted and copied to `/var/www/html/nextcloud`, with the `data` directory created separately. Ownership is set to `apache:apache`. The downloaded archives are cleaned up afterwards.

### Step 5 – Firewall and SELinux

The firewall is opened for HTTP and HTTPS via `firewall-cmd --permanent`. SELinux booleans are set to allow Apache to make outbound network connections, connect to the remote database, and send mail. The correct `httpd_sys_rw_content_t` file context is applied to the Nextcloud `data`, `config`, `apps`, `.htaccess`, `.user.ini`, and AWS log directories using `semanage fcontext`, and then restored with `restorecon -R`.

### Step 6 – Nextcloud initial configuration

Nextcloud is configured headlessly via the `occ` CLI tool (run as the `apache` user) with the following parameters:

- **Database:** MySQL/MariaDB at `192.168.132.198`, database `nextcloud`, user `nextcloud`
- **Admin credentials:** `admin` / `admin404`
- **Data directory:** `/var/www/html/nextcloud/data`

Trusted domains are set to both the server's direct IP (`192.168.132.197`) and the public domain (`nextcloud.t02-domain404.internal`). The `overwrite.cli.url` and `overwriteprotocol` settings are configured for HTTPS because the server sits behind the reverse proxy. The proxy IP is added to `trusted_proxies` so that `X-Forwarded-For` headers are trusted.

Valkey is then wired into Nextcloud's caching layer via `occ config:system:set`.

### Step 7 – User accounts

A regular Nextcloud user is created using `occ user:add`:

| Username | Display name | Password |
| :--- | :--- | :--- |
| `linustorvalds` | Linus Torvalds | `IDidntMadeAnyMoneyFromLinux` |

The admin account (`admin` / `admin404`) is created during the initial Nextcloud configuration step above.

### Step 8 – LDAP / Active Directory authentication

The `user_ldap` app is enabled and a new LDAP configuration is created. The connection is pointed at the domain controller:

| Setting | Value |
| :--- | :--- |
| LDAP host | `192.168.132.194` |
| Port | `389` |
| Bind account | `SVC_DomainJoin@ad.t02-domain404.internal` |
| Base DN | `DC=ad,DC=t02-domain404,DC=internal` |
| User base | `OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal` |
| Group base | `OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal` |
| Login filter | `(&(objectClass=person)(sAMAccountName=%uid))` |

Once configured, Active Directory users can log in to Nextcloud with their AD credentials — no separate Nextcloud account is required.

### Step 9 – Calendar and Forms app

A default calendar named `Domain404 Calendar` is created for the `linustorvalds` user via `occ dav:create-calendar`. The Nextcloud Forms app is installed via `occ app:install forms`, enabling users to create and share forms.

### Step 10 – Network fix

The `networkfix.sh` script is applied at the end to ensure correct network routing inside the VM.

## Post-provisioning access

After provisioning completes, Nextcloud is reachable at:

```
https://nextcloud.t02-domain404.internal
```

Direct IP access is also available at `http://192.168.132.197`.

## Troubleshooting

| Problem | Possible solution |
| :--- | :--- |
| Nextcloud checksum verification fails during provisioning | Check internet connectivity from the VM. Re-run `vagrant provision nextcloud-server`. |
| Cannot reach Nextcloud via `https://nextcloud.t02-domain404.internal` | Verify that the `reverse-proxy` VM is running and that its Nextcloud upstream block points to `192.168.132.197`. Also confirm that your client's DNS resolves the domain correctly. |
| LDAP users cannot log in | Confirm that `windowsdc` is running and reachable on port 389 from `192.168.132.197`. Use `occ ldap:test-config s01` on the Nextcloud server to verify the connection. Also check that the `SVC_DomainJoin` service account exists in AD and that the OU paths match those defined in the provisioning script. |
| Admin password is not accepted | The admin account is created during `occ maintenance:install`. If provisioning failed partway through, the installation may be incomplete. Destroy and re-provision with `vagrant destroy nextcloud-server && vagrant up nextcloud-server`. |
| Nextcloud reports a "not trusted domain" error | The trusted domains list is set to the server IP and `nextcloud.t02-domain404.internal`. If you are accessing via a different hostname or IP, add it manually with `occ config:system:set trusted_domains 2 --value=<your-domain>`. |
| Valkey / Redis connection errors in Nextcloud | Verify that the Valkey service is running (`systemctl status valkey`), that it is bound to `127.0.0.1`, and that the password in Nextcloud's `config.php` matches the one in `/etc/valkey/valkey.conf`. |
| Forms app fails to install | The app installation requires internet access. Confirm the VM has a working NAT adapter and re-run `occ app:install forms` manually on the server. |
