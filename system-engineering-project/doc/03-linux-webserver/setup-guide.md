# Setup guide

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

This guide describes the step-by-step procedure to deploy the webserver using vagrant.

## Prerequisits

Ensure the following software installed on your host machine:
- Oracle VirtualBox
- Vagrant
- Git

## Steps

1. Open a terminal or command prompt.
2. Clone the project repository using `git clone`
3. Navigate to the directory `/system-engineering-project-25-26-sep2526-t02/src`. This is where the `vagrant-hosts.yml` file is located.
4. Launch the virtual machines with the command `vagrant up`. This command reads the `Vagrantfile` and creates the virtual machines listed in the `vagrant-hosts.yml` file and triggers the provisioning scripts.

## Provisioning workflow

The deployment is fully automated by vagrant. When `vagrant up` is executed the following occurs:

### Common configuration

The `common.sh` script runs on all nodes listed in the `vagrant-hosts.yml` file.

### Webserver setup

The `webserver.sh` script performs the following actions:
- Installs Apache (httpd) and PHP with the MySQL driver.
- Configures the Firewall to allow HTTP traffic on port 80
- Downloads and extracts the latest WordPress version to `/var/www/html`
- Creates the `wp-config.php` file and configures it with the predifined database variables.
- Configures the Apache virtualhost to show wordpress in the web browser and nog the apache test webpage. 
- Configures SELinux.

### Troubleshooting

Some common problems with possible solutions.

| Problem | Possible solution |
| :--- | :--- |
| Connection refused | Ensure the Database Server is running and its firewall allows traffic from the Web Server IP. |
| Permission denied (403) | Check if `restorecon` was applied correctly to the `/var/www/html` directory. |
| Database error | Verify that the `DB_HOST`, `DB_NAME`, and `DB_USER` in `webserver.sh` match the actual database configuration. |







