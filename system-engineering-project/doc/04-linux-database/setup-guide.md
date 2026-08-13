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

### Database setup

The `database.sh` script performs the following actions:
- Installs and enables MariaDB: Uses `dnf` to install the MariaDB server package and ensures the service is enabled.
- Hardens the Installation: If the root password is not yet set, the script secures the instance by setting a root password and drops the default test database.
- Configures network security: Sets the default firewall zone to drop, then allows `ssh` and `mysql` services.
- Implements webserver only access: Adds a firewall rule to ensure that database connections are only accepted if they come from the webserver.
- Creates the database and user: Creates the wordpress database and a specific user with full privileges.

### Troubleshooting

Some common problems with possible solutions.

| Problem                         | Possible solution                                                                                                                |
| :------------------------------ | :------------------------------------------------------------------------------------------------------------------------------- |
| `vagrant up` fails              | Check your internet connection as it is need to use `dnf install`                                                                |
| Webserver cannot connect to DB  | Verify if the `webserver_ip` variable matches the IP of the webserver. Check the firewall status with `firewall-cmd --list-all`. |
| Database service is not active  | Check the status of `mariadb` with `systemctl status mariadb`, if not active, run `systemctl start mariadb`                      |
| `Access Denied` for domain404   | Ensure the credentials in the WordPress config match `db_user` and `db_password`.                                                |
| Vagrant cannot find Vagrantfile | Ensure you are in the `/src` directory of the project before running commands.                                                   |
