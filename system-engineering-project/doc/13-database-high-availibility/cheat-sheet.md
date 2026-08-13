# Cheat-sheet

Author(s): G. Lescur - `guillaume.lescur@student.hogent.be`

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
| `sudo systemctl status haproxy` | Checks the status of MariaDB |

## Firewall

| Command | Description |
| :--- | :--- |
| `sudo firewall-cmd --list-all` | Shows the firewall configuration |
| `sudo firewall-cmd --add-service=[service name] --permanent` | Allow a service |
| `sudo firewall-cmd --remove-port=[port number]/[tcp/udp] --permanent` | remove a service |
| `sudo firewall-cmd --reload` | Reloads the firewall |

## Database

| Command | Description |
| :--- | :--- |
| `mysql -u root -p` | Log in to the database as the root user |
| `mysqladmin -u root status` | Checks the status of the database root user |
| `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW STATUS LIKE 'wsrep_cluster_size';"` | Checks the cluster size |
| `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW STATUS LIKE 'wsrep_ready';"` | Check if the node is ready |
| `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW STATUS LIKE 'wsrep_cluster_status';"` | Checks if the node is ready |
| `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW STATUS LIKE 'wsrep_local_state_comment';"` | Check the node state |
| `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW VARIABLES LIKE 'wsrep%';"` | View all Galera variables |
| `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW STATUS LIKE 'wsrep_incoming_addresses';"` | Check connected cluster nodes |
| `ss -tulnp` | Check listening ports |
| `ss -tulnp [ grep 3306` | Check MySQL port |
| `SHOW DATABASES;` | Show databases |

## Replication tests
| Command | Description |
| :--- | :--- |
| `mysql -u root -p'WeWillCrushThisProject404'` | Log in to the database as the root user |
| `USE wordpress; CREATE TABLE testtable ( id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50) ); ` | Create test table |
| `INSERT INTO testtable (name) VALUES ('db1 works'); ` | Insert test data |
| `SELECT * FROM testtable; ` | Read replicated data |
| `mysql -h 192.168.132.195 -u domain404 -p'GroupT02ForVictory' ` | Connect through HAProxy |

## Haproxy

| Command | Description |
| :--- | :--- |
| `mysql -h 192.168.132.201 -u domain404 -p'GroupT02ForVictory' -e "SELECT @@hostname;"` | Load balancing check |
| `ss -tulnp` | Check listening ports |
| `ss -tulnp [ grep 4567` | Check Galera replication ports |
| `nc -zv 192.168.132.201 3306` | Test direct TCP connectivity to MySQL |
| `curl http://192.168.132.201:8404/stats` | Test HAProxy stats page |
| `sudo haproxy -c -f /etc/haproxy/haproxy.cfg` | Validate HAProxy configuration |

## Configuration files

| Command | Description |
| :--- | :--- |
| `sudo nano /etc/haproxy/haproxy.cfg` | View HAProxy config |
| `sudo nano /etc/my.cnf` | View MariaDB config |
| `sudo nano /etc/mysql/mariadb.conf.d/60-galera.cnf` | View Galera config |

## Log files

| Command | Description |
| :--- | :--- |
| `sudo journalctl -u haproxy -f` | View HaProxy logs |
| `sudo journalctl -u mariadb -f` | View MariaDB logs |

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
| HAProxy Stats | 8404 |
| HAProxy MySQL Frontend | 5000 |
| Galera Replication | 4567 |
| Galera IST | 4568 |
| Galera SST | 4444 |
| Cockpit/Web Console | 9090 |
