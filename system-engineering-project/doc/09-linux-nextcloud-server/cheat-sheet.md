# Cheat-sheet – Nextcloud server

**Author(s):** D. Cooreman — `dean.cooreman@student.hogent.be`

This document provides a quick reference for managing the Nextcloud server, its database, the `occ` CLI tool, LDAP/AD integration, and Valkey caching via the command line.

## Configuration Variables

| Variable | Value / Purpose |
| :--- | :--- |
| `NEXTCLOUD_VERSION` | Installed Nextcloud version (`31.0.4`) |
| `nc_server_ip` | IP of the Nextcloud server (`192.168.132.197`) |
| `nc_domain` | Public domain via reverse proxy (`nextcloud.t02-domain404.internal`) |
| `nc_proxy_ip` | Reverse proxy IP trusted for `X-Forwarded-For` (`192.168.132.234`) |
| `nc_admin_user` / `nc_admin_pass` | Admin credentials (`admin` / `admin404`) |
| `nc_user` | Regular user account (`linustorvalds`) |
| `db_host` | Database server IP (`192.168.132.198`) |
| `db_name` / `db_user` / `db_password` | Database name, user, and password (`nextcloud` / `nextcloud` / `GroupT02ForVictory`) |
| `valkey_password` | Valkey cache password (`domain404`) |

## occ – Nextcloud CLI

All `occ` commands must be run as the `apache` user. Use the wrapper below or prefix every call manually.

```bash
# Run occ as apache (use this wrapper on the nextcloud-server VM)
runuser -u apache -- php /var/www/html/nextcloud/occ <command>
```

### System

| Command | Description |
| :--- | :--- |
| `occ status` | Show Nextcloud version and installation status |
| `occ maintenance:mode --on` | Enable maintenance mode (blocks user access) |
| `occ maintenance:mode --off` | Disable maintenance mode |
| `occ upgrade` | Run database migrations after a version upgrade |
| `occ config:system:get <key>` | Read a value from `config.php` |
| `occ config:system:set <key> --value=<val>` | Write a value to `config.php` |
| `occ config:system:delete <key>` | Remove a key from `config.php` |

### Trusted Domains & Proxy

| Command | Description |
| :--- | :--- |
| `occ config:system:set trusted_domains 0 --value=<ip>` | Allow direct IP access |
| `occ config:system:set trusted_domains 1 --value=<domain>` | Allow access via reverse proxy domain |
| `occ config:system:set overwrite.cli.url --value=https://<domain>` | Set the canonical URL |
| `occ config:system:set overwriteprotocol --value=https` | Force HTTPS in generated URLs |
| `occ config:system:set trusted_proxies 0 --value=<proxy-ip>` | Trust a reverse proxy IP |

### Users

| Command | Description |
| :--- | :--- |
| `occ user:list` | List all local Nextcloud users |
| `occ user:info <username>` | Show details of a specific user |
| `OC_PASS=<pwd> occ user:add --password-from-env --display-name=<name> <user>` | Create a new user |
| `occ user:delete <username>` | Delete a user |
| `occ user:resetpassword <username>` | Reset a user's password interactively |

### Apps

| Command | Description |
| :--- | :--- |
| `occ app:list` | List all installed and available apps |
| `occ app:enable <app>` | Enable an app |
| `occ app:disable <app>` | Disable an app |
| `occ app:install <app>` | Install an app from the app store |
| `occ app:update <app>` | Update a specific app |
| `occ app:update --all` | Update all installed apps |

### LDAP

| Command | Description |
| :--- | :--- |
| `occ ldap:show-config` | Display all LDAP configuration values |
| `occ ldap:test-config s01` | Test the LDAP connection (returns OK or error) |
| `occ ldap:set-config s01 <key> <value>` | Set a single LDAP configuration option |
| `occ ldap:create-empty-config` | Create a new empty LDAP configuration |
| `occ ldap:delete-config s01` | Remove the LDAP configuration |
| `occ user:sync "OCA\User_LDAP\User_Proxy" -m remove` | Sync users from LDAP and remove stale accounts |

### Calendar (CalDAV)

| Command | Description |
| :--- | :--- |
| `occ dav:create-calendar <user> <name>` | Create a calendar for a user |
| `occ dav:list-calendars <user>` | List all calendars for a user |
| `occ dav:remove-invalid-shares` | Clean up invalid calendar/contact shares |

### Files & Caching

| Command | Description |
| :--- | :--- |
| `occ files:scan --all` | Re-scan all user files and update the database index |
| `occ files:scan <username>` | Re-scan files for a specific user |
| `occ files:cleanup` | Remove orphaned file cache entries |

## LDAP / Active Directory Configuration

| Setting | Value |
| :--- | :--- |
| `ldapHost` | `192.168.132.194` |
| `ldapPort` | `389` |
| `ldapBase` | `DC=ad,DC=t02-domain404,DC=internal` |
| `ldapBaseUsers` | `OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal` |
| `ldapBaseGroups` | `OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal` |
| `ldapAgentName` | `SVC_DomainJoin@ad.t02-domain404.internal` |
| `ldapUserFilter` | `(&(objectClass=person)(objectCategory=person))` |
| `ldapLoginFilter` | `(&(objectClass=person)(sAMAccountName=%uid))` |
| `ldapGroupMemberAssocAttr` | `member` |

## Valkey (Redis-compatible cache)

| Command | Description |
| :--- | :--- |
| `systemctl status valkey` | Check whether the Valkey service is running |
| `systemctl restart valkey` | Restart the Valkey service |
| `redis-cli -h 127.0.0.1 -a <password> ping` | Test connectivity to Valkey |
| `redis-cli -h 127.0.0.1 -a <password> info` | Show Valkey server statistics |
| `cat /etc/valkey/valkey.conf \| grep requirepass` | Verify the configured password |

## Apache & PHP

| Command | Description |
| :--- | :--- |
| `systemctl status httpd` | Check Apache status |
| `systemctl restart httpd` | Restart Apache |
| `systemctl status php-fpm` | Check PHP-FPM status |
| `systemctl restart php-fpm` | Restart PHP-FPM |
| `apachectl configtest` | Validate the Apache configuration syntax |
| `cat /etc/httpd/conf.d/nextcloud.conf` | Inspect the Nextcloud VirtualHost config |
| `php --version` | Confirm the active PHP version |
| `php -m` | List loaded PHP modules |

## MariaDB (nextcloud-database VM)

| Command | Description |
| :--- | :--- |
| `systemctl status mariadb` | Check MariaDB status |
| `mysql -u root -p` | Open a root MySQL shell |
| `mysql -u nextcloud -p nextcloud` | Connect as the Nextcloud DB user |
| `SHOW DATABASES;` | List all databases |
| `SHOW GRANTS FOR 'nextcloud'@'192.168.132.197';` | Verify the Nextcloud user's permissions |
| `SELECT table_name FROM information_schema.tables WHERE table_schema='nextcloud';` | List tables in the Nextcloud database |

## Firewall (Rocky Linux / firewalld)

| Command | Description |
| :--- | :--- |
| `firewall-cmd --list-all` | Show active firewall rules |
| `firewall-cmd --add-service=http --permanent` | Allow HTTP (port 80) |
| `firewall-cmd --add-service=https --permanent` | Allow HTTPS (port 443) |
| `firewall-cmd --reload` | Apply permanent rule changes |

## SELinux

| Command | Description |
| :--- | :--- |
| `getenforce` | Show current SELinux mode (`Enforcing` / `Permissive`) |
| `getsebool httpd_can_network_connect` | Check whether Apache may make outbound connections |
| `setsebool -P httpd_can_network_connect on` | Allow Apache outbound connections (persistent) |
| `setsebool -P httpd_can_network_connect_db on` | Allow Apache to connect to a remote database |
| `restorecon -R /var/www/html/nextcloud/` | Restore correct SELinux file contexts |
| `ls -Z /var/www/html/nextcloud/` | Inspect SELinux labels on Nextcloud files |

## Provisioning Scripts

| Script | Purpose |
| :--- | :--- |
| `nextcloud-server.sh` | Full provisioning of the Nextcloud application server |
| `nextcloud-database.sh` | MariaDB installation, hardening, and user/database creation |
| `common.sh` | Shared settings applied to all Linux servers |
| `util.sh` | Helper functions: `log`, `success`, `error`, `run` |
| `networkfix.sh` | Applied at the end of provisioning to correct routing |

## Vagrant

| Command | Description |
| :--- | :--- |
| `vagrant up nextcloud-server nextcloud-database` | Start (and provision) the Nextcloud VMs |
| `vagrant halt nextcloud-server` | Shut down the Nextcloud server |
| `vagrant reload nextcloud-server` | Restart and re-apply Vagrantfile changes |
| `vagrant destroy nextcloud-server` | Delete the VM and its disk |
| `vagrant provision nextcloud-server` | Re-run the provisioning script without recreating the VM |
| `vagrant ssh nextcloud-server` | Open an SSH shell into the Nextcloud server |
| `vagrant ssh nextcloud-database` | Open an SSH shell into the database server |
