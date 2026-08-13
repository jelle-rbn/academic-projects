# Research

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

## Sources

### Installation

| Source | Description |
| :--- | :--- |
| [System requirements](https://docs.nextcloud.com/server/latest/admin_manual/installation/system_requirements.html) | Documentation about the required OS, database, webserver and PHP. |
| [Preparing PHP](https://docs.nextcloud.com/server/latest/admin_manual/installation/php_configuration.html) | Documentation that explains how to properly configure PHP before installing nextcloud. |
| [Installation on Linux](https://docs.nextcloud.com/server/latest/admin_manual/installation/source_installation.html) | Documentation about how to install nextcloud on Linux. |
| [Installing from command line](https://docs.nextcloud.com/server/latest/admin_manual/installation/command_line_installation.html) | Documentation about installing nextcloud entirely from the command line. |
| [SELinux configuration](https://docs.nextcloud.com/server/latest/admin_manual/installation/selinux_configuration.html) | Documentation about how to configure SELinux. |
| [Nextcloud security hardening](https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html) | Documentation about how to apply additional security hardening. |
| [Example installation](https://docs.nextcloud.com/server/latest/admin_manual/installation/example_centos.html) | Example installation on CentOS that can be helpful on Almalinux. |
| [Valkey](https://www.percona.com/blog/how-to-set-up-valkey-the-alternative-to-redis/) | Info about Valkey as an alternative to Redis |



### Configuration

| Source | Description |
| :--- | :--- |
| [Trusted domains](https://docs.nextcloud.com/server/latest/admin_manual/installation/installation_wizard.html#trusted-domains) | Documentation about configuring trusted domains so Nextcloud accepts requests from specific hostnames. |
| [Reverse proxy configuration](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/reverse_proxy_configuration.html) | Documentation about configuring Nextcloud behind a reverse proxy (`overwriteprotocol`, `trusted_proxies`, `overwrite.cli.url`). |
| [Caching configuration (Redis / Valkey)](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/caching_configuration.html) | Documentation about configuring local and distributed caching using Redis / Valkey (`memcache.local`, `memcache.distributed`, `memcache.locking`). |
| [occ command reference](https://docs.nextcloud.com/server/stable/admin_manual/occ_command.html) | Full reference for the `occ` command-line tool, covering all commands including `dav:create-calendar`, `app:install`, `app:enable`, `ldap:set-config` and more. |



### Active Directory / LDAP Integration

| Source | Description |
| :--- | :--- |
| [LDAP user and group backend](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_ldap.html) | Official Nextcloud documentation for configuring the `user_ldap` app to authenticate users against an LDAP/AD directory. |
| [LDAP user auth API](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_ldap_api.html) | Documentation about the LDAP configuration API and available config keys used with `ldap:set-config`. |
| [Active Directory Domain Services overview](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview) | Microsoft documentation providing an overview of Active Directory Domain Services (AD DS). |



### Client Software and installation

| Source | Description |
| :--- | :--- |
| [Chocolatey installation](https://chocolatey.org/install) | Official documentation for installing Chocolatey, the Windows package manager, via PowerShell.|
| [Chocolatey CLI reference](https://docs.chocolatey.org/en-us/choco/commands/install) | Reference for the `choco install` command. |
| [Nextcloud Desktop Client — Chocolatey package](https://community.chocolatey.org/packages/nextcloud-client) | Information about the installation of the Nextcloud desktop client with chocolatey. |
| [Thunderbird — Chocolatey package](https://community.chocolatey.org/packages/thunderbird) | Information about the installation of Thunderbird with chocolatey. |
| [Nextcloud Desktop Client documentation](https://docs.nextcloud.com/desktop/latest/) | Official documentation for the Nextcloud Desktop Client, covering installation, account setup and file synchronisation configuration. |



### Calendar & Thunderbird Synchronisation

| Source | Description |
| :--- | :--- |
| [Nextcloud Calendar app](https://apps.nextcloud.com/apps/calendar) | Official Nextcloud Calendar app page, required for CalDAV calendar functionality. |
| [Sync Nextcloud with Thunderbird](https://docs.nextcloud.com/server/latest/user_manual/en/groupware/sync_thunderbird.html) | Official Nextcloud documentation explaining how to sync calendars and contacts with Thunderbird via CalDAV/CardDAV. |
| [CalDAV — RFC 4791](https://datatracker.ietf.org/doc/html/rfc4791) | The official IETF standard defining the CalDAV protocol used for calendar synchronisation between Nextcloud and Thunderbird. |



### Forms

| Source | Description |
| :--- | :--- |
| [Nextcloud Forms app](https://apps.nextcloud.com/apps/forms) | Official Nextcloud Forms app page — needed for the requirement to create and share forms with other users. |
| [Nextcloud app management via occ](https://docs.nextcloud.com/server/stable/admin_manual/occ_command.html) | Reference for managing Nextcloud apps from the command line via `occ app:install` and `occ app:enable`. |
