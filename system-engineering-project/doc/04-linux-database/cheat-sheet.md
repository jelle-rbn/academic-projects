# Cheat-sheet

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

This document provides a quick reference for common commands used for Almalinux, SQL and Vagrant.

## Network

| Command | Description |
| :--- | :--- |
| `ip -br l` | Check the status of the network interfaces |
| `ip addres` | Detailed information about all network interfaces |
| `nmcli device status` | Shows the status of the interfaces |

## Services

| Command | Description |
| :--- | :--- |
| `sudo systemctl status mariadb` | Checks the status of MariaDB |

## Firewall

| Command | Description |
| :--- | :--- |
| `sudo firewall-cmd --list-all` | Shows the firewall configuration |
| `sudo firewall-cmd --add-service=[service name] --permanent` | Allow a service |
| `sudo firewall-cmd --reload` | Reloads the firewall |

## Database

| Command | Description |
| :--- | :--- |
| `mysql -u root -p` | Log in to the database as the root user |
| `mysqladmin -u root status` | Checks the status of the database root user |

## Vagrant

| Command | Description |
| :--- | :--- |
| `vagrant up` | Creates and configures the virtual machines based on the vagrantfile and the provision scripts |
| `vagrant halt` | Shut down all running virtual machines |
| `vagrant suspend` | Suspend the virtual machine and saves the current state to disk |
| `vagrant resume` | Resumes a suspended virtual machine |
| `vagrant reload` | Equivalent to `halt` followed by an `up`. Required to apply changes made to the vagrantfile |
| `vagrant destroy` | Stops the virtual machines and deletes all associated rescources and disks |

## Ports used

| Service| Port |
| :--- | :--- |
| Mariadb | 3306 |
| SSH | 22 |
