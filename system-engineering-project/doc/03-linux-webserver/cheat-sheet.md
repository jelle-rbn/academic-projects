# Cheat-sheet

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

This document provides a quick reference for common commands used for Almalinux and Apache webserver.

## Network

| Command | Description |
| :--- | :--- |
| `ip -br l` | Check the status of the network interfaces |
| `ip addres` | Detailed information about all network interfaces |
| `nmcli device status` | Shows the status of the interfaces |

## Services

| Command | Description |
| :--- | :--- |
| `sudo systemctl status httpd` | Checks the status of Apache |
| `sudo systemctl status php-fpm` | Checks the status of PHP |

## Firewall

| Command | Description |
| :--- | :--- |
| `sudo firewall-cmd --list-all` | Shows the firewall configuration |
| `sudo firewall-cmd --add-service=[service name] --permanent` | Allow a service |
| `sudo firewall-cmd --reload` | Reloads the firewall |

## Permissions

| Command | Description |
| :--- | :--- |
| `ls -l [filename]` | Shows file permissions |
| `ls -l [foldername]` | Shows folder permissions |

## SELinux

| Command | Description |
| :--- | :--- |
| `getenforce` | Checks if SELinux is enforcing |
| `getsebool httpd_can_network_connect_db` | Check if Apache can talk to a remote database |
| `ls -Z [filename]` | Shows the security context of files |

## Vagrant

| Command | Description |
| :--- | :--- |
| `vagrant up` | Creates and configures the virtual machines based on the vagrantfile and the provision scripts |
| `vagrant halt` | Shut down all running virtual machines |
| `vagrant suspend` | Suspend the virtual machine and saves the current state to disk |
| `vagrant resume` | Resumes a suspended virtual machine |
| `vagrant reload` | Equivalent to `halt` followed by an `up`. Required to apply changes made to the vagrantfile |
| `vagrant destroy` | Stops the virtual machines and deletes all associated rescources and disks |

## Ports used in LAMP-stack

| Service| Port |
| :--- | :--- |
| Apache http | 80 |
| Apache https | 443 |
| Mariadb | 3306 |

## File and folder locations

| Service| Port |
| :--- | :--- |
| `/var/www/html/wordpress/` | Wordpress root directory |
| `/var/www/html/wordpress/wp-config.php` | Main Wordpress configuration file |
| `/etc/httpd/conf.d/` | Directory with Apache configuration files |

