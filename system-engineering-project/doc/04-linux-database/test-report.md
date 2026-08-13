# Test report

- Test Executor(s): J. Robyn - `jelle.robyn@student.hogent.be`
- Executed on: 14/03/2026

## Test 1: Ping the local host

Test procedure:

- Run the command `ping 127.0.0.1 -c 4`

Expected result:

- All pings are succesful.
- The round trips are almost instant (less then 1ms).

Obtained result:

- The pings to the local host are succesfull and within the given time frame.

![Ping the local host](../06-linux-database/img/Ping_the_local_host.png)

Test passed:

- [x] Yes
- [ ] No

## Test 2: Is the database configured with the correct IP-address?

Test procedure:

- Run the command `ip -br a`

Expected result:

- The IP-address is `192.168.132.195`.

Obtained result:

- The database is configured with the correct IP-address: `192.168.132.195`.

![Database IP-address](../06-linux-database/img/Database_IP_address.png)

Test passed:

- [x] Yes
- [ ] No

## Test 3: Is MariaDB enabled and running?

Test procedure:

- Run the command `sudo systemctl status mariadb`

Expected result:

- The output show that the service is `enabled` and `active`.

Obtained result:

- The output shows that MariaDB is enabled and active.

![MariaDB enabled and running](../06-linux-database/img/MariaDB_enabled_and_running.png)

Test passed:

- [x] Yes
- [ ] No

## Test 4: Are the firewall rules restricting access correctly?

Test procedure:

- Run the command `sudo firewall-cmd --list-all`

Expected result:

- The default zone is set to drop.
- The `mysql` and `ssh` services are listed in the allowed services.
- A rule exists specifically allowing the `webserver` IP `192.168.132.196`.

Obtained result:

- The firewall results show that the default zone is set to drop. Additionally, only the services `mysql` and ssh are allowed. And finally the results show the rule for allowing the webserver IP-address `192.168.132.196`.

![Firewall rules](../06-linux-database/img/Firewall_rules.png)

Test passed:

- [x] Yes
- [ ] No

## Test 5: Is the root password set and secure?

Test procedure:

- Attempt to log in without a password: `mysql -u root`.
- Attempt to log in with the configured password: `mysql -u root -p'WeWillCrushThisProject404'`.

Expected results:

- The passwordless login is denied.
- The login with the password is successful.

Obtained result:

- As shown in the first screenshot, trying to log in without providing a password results in denied access.
  When providing the password on the other hand, the connection is successfull.

![Login without password](../06-linux-database/img/Login_without_password.png)

![Login with password](../06-linux-database/img/Login_with_password.png)

Test passed:

- [x] Yes
- [ ] No

## Test 6: Does the WordPress database and user exist?

Test procedure:

- Run the command: `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW DATABASES; SELECT User, Host FROM mysql.user WHERE User='domain404';"`.

Expected results:

- The wordpress database is listed.
- The user `domain404` is listed with the host allowed from `192.168.132.196`.

Obtained result:

- The first table in the result lists the WordPress database while the second table shows that user `domain404` is indeed listed with the host allowed from `192.168.132.196`.

![Wordpress database and user](../06-linux-database/img/Wordpress_database_and_user.png)

Test passed:

- [x] Yes
- [ ] No

## Test 7: Is the test database removed?

Test procedure:

- Run the command: `mysql -u root -p'WeWillCrushThisProject404' -e "SHOW DATABASES;"`.

Expected result:

- The test database does not appear in the list.

Obtained result:

- The table no longer contains the test database.

![Test database removed](../06-linux-database/img/Test_database_removed.png)

Test passed:

- [x] Yes
- [ ] No

## Test 8: Is the database reachable from the webserver?

Test procedure:

- SSH into the webserver: `vagrant ssh webserver`
- Install MariaDB: `sudo dnf install -y mariadb`
- Make connection with the database: `mysql -u domain404 -p'GroupT02ForVictory' -h 192.168.132.195`

Expected result:

- The connection is established successfully.

Obtained result:

- After successfully ssh'ing into the webserver and installing mariadb, the output shows that a connection with the database is established from the webserver.

![Database reachable from webserver](../06-linux-database/img/Database_reachable_for_webserver.png)

Test passed:

- [x] Yes
- [ ] No

## Test 9: Is the connection refused from the TFTP-server to the database?

Test procedure:

- SSH into the TFTP-server: `vagrant ssh tftp`
- Install MariaDB: `sudo dnf install -y mariadb`
- Try to make connection with the database: `mysql -u domain404 -p'GroupT02ForVictory' -h 192.168.132.195`

Expected result:

- The connection is refused or times out because the firewall rich rule only allows the webserver IP.

Obtained result:

- An error occurs trying to establish a connection from the TFTP server. This confirms that only the webserver is allowed to connect with the database.

![Connection refused from TFTP](../06-linux-database/img/Connection_refused_from_tftp.png)

Test passed:

- [x] Yes
- [ ] No
