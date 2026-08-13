# Test Plan – Nextcloud Server

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

## Before Starting

- Ensure `windowsdc`, `nextcloud-database`, `nextcloud-server`, and `reverse-proxy` are fully provisioned and running.
- Ensure `winclient` is provisioned and joined to the domain `ad.t02-domain404.internal`.
- Connect to the Windows client via VirtualBox GUI.
- Log in with: a valid username and password.

---

## Test 1: Is the Nextcloud server reachable on the network?

**Test procedure:**

- On another VM, run:

  ```bash
  ping 192.168.132.197 -c 4
  ```

**Expected result:**

- All 4 pings are successful.
- The round-trip times are low.

![succeful ping](./img/test1.png)

---

## Test 2: Is Apache running on the Nextcloud server?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  systemctl status httpd
  ```

**Expected result:**

- The service is `active (running)`.

![service running](./img/test2.png)

---

## Test 3: Is PHP-FPM running?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  systemctl status php-fpm
  ```

**Expected result:**

- The service is `active (running)`.

![service running](./img/test3.png)

---

## Test 4: Is Valkey running?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  systemctl status valkey
  ```

**Expected result:**

- The service is `active (running)`.

![service running](./img/test4.png)

---

## Test 5: Can the Nextcloud server reach the database?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  sudo dnf install -y mariadb
  ```

  ```bash
  mysql -h 192.168.132.198 -u nextcloud -pGroupT02ForVictory nextcloud -e "SELECT 1;"
  ```

**Expected result:**

- The command returns `1` without errors, confirming that the database server is reachable and the credentials are correct.

![service running](./img/test5.png)

---

## Test 6: Is the Nextcloud web interface reachable via the reverse proxy?

**Test procedure:**

- On the Windows client, open a browser and navigate to:

  ```
  https://nextcloud.t02-domain404.internal
  ```

**Expected result:**

- The browser opens the Nextcloud login page without any connection errors.
- The browser shows the self-signed certificate warning. After accepting it, the login page loads correctly.

![service running](./img/test6.png)

![service running](./img/test7.png)

![service running](./img/test8.png)

---

## Test 7: Can the admin user log in to Nextcloud?

**Test procedure:**

- On the Nextcloud login page, enter:
  - Username: `admin`
  - Password: `admin404`
- Click **Log in**.

**Expected result:**

- Login is successful and the Nextcloud dashboard is shown.

![service running](./img/test9.png)

![service running](./img/test10.png)


---

## Test 8: Does the local Nextcloud user account exist?

**Test procedure:**

- Log in as `admin` and navigate to **Settings, Users**.

**Expected result:**

- The user `linustorvalds` (display name: Linus Torvalds) is listed.

---

## Test 9: Can the local Nextcloud user log in?

**Test procedure:**

- Log out of the admin account.
- Log in with:
  - Username: `linustorvalds`
  - Password: `IDidntMadeAnyMoneyFromLinux`

**Expected result:**

- Login is successful and the Nextcloud dashboard is shown for the user `Linus Torvalds`.

![service running](./img/test11.png)

![service running](./img/test12.png)
---

## Test 10: Is the LDAP/AD integration enabled?

**Test procedure:**

- Log in as `admin` and navigate to **Settings → LDAP/AD Integration** (under Administration).

**Expected result:**

- An active LDAP configuration `s01` is listed.
- The configuration shows the host `192.168.132.194` (the Windows Domain Controller) on port `389`.
- The connection status shows a green checkmark or "Configuration OK".


![service running](./img/test13.png)

![service running](./img/test14.png)

![service running](./img/test15.png)

---

## Test 11: Can an Active Directory user log in to Nextcloud?

**Test procedure:**

- Login to the winclient with your usersname and choose a new password.
- On the login page of Nextcloud, enter the credentials of an existing AD user:
  - Username: `AD username`
  - Password: `AD password`

**Expected result:**

- Login is successful using the AD credentials.
- No separate Nextcloud account is needed — the user is authenticated via Active Directory.

![service running](./img/test16.png)

![service running](./img/test17.png)

![service running](./img/test18.png)

![service running](./img/test19.png)

![service running](./img/test20.png)

![service running](./img/test21.png)

---

## Test 12: Is file synchronisation working with the Nextcloud desktop client?

**Test procedure:**

- Open the Nextcloud client on the winclient and connect to `https://nextcloud.t02-domain404.internal`.
- Authenticate with a valid account (e.g. `linustorvalds`).
- Add a test file to the local sync folder.
- Wait for the sync indicator to show completion.
- Open the Nextcloud client on the rockyclient and connect to `https://nextcloud.t02-domain404.internal`.
- Authenticate with the same account as on the winclient.

**Expected result:**

- The file uploaded from the winclient is visible on the rockyclient.

![service running](./img/test22.png)

![service running](./img/test23.png)

![service running](./img/test24.png)

![service running](./img/test25.png)

![service running](./img/test26.png)

![service running](./img/test27.png)

![service running](./img/test28.png)

![service running](./img/test29.png)

![service running](./img/test30.png)

![service running](./img/test31.png)

---

## Test 13: Does the calendar for `linustorvalds` exist?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  sudo -u apache php /var/www/html/nextcloud/occ dav:list-calendars linustorvalds
  ```

**Expected result:**

- The output lists the calendar named `Domain404 Calendar`.

![service running](./img/test32.png)

---

## Test 14: Can the calendar be synchronised with Thunderbird?

**Test procedure:**

- Open **Thunderbird** on the winclient.
- In the side menu, go to **Calendar**.
- In the bottom left corner click **New Calendar...**.
- Select **On the Network** and click **Next**.
- Enter username: `linustorvalds`
- Enter the following URL: `https://nextcloud.t02-domain404.internal/remote.php/dav/calendars/linustorvalds/domain404-calendar/`
- Click **Find Calendars**.
- When prompted for credentials, enter the password: `IDidntMadeAnyMoneyFromLinux`
- Select **CalDAV** as the format.
- Accept the self-signed certificate warning if it appears.
- Thunderbird will detect the **Domain404 Calendar**. Select it and click **Subscribe**.
- Right-click somewhere on the calender and create a new event. 

**Expected result:**

- The calendar `Domain404 Calendar` appears in Thunderbird's calendar list on the left.
- The event is visible on the nextcloud webinterface under the tab activities.

![service running](./img/test33.png)

![service running](./img/test34.png)

![service running](./img/test35.png)

![service running](./img/test36.png)

![service running](./img/test37.png)

![service running](./img/test38.png)

![service running](./img/test39.png)

---

## Test 15: Can a form be created and shared?

**Test procedure:**

- Log in as `linustorvalds` (or any valid user).
- Navigate to the **Forms** app from the top navigation bar.
- Create a new form with at least one question (e.g. a text field).
- Click **Share** and copy the public link.
- Open the link in a private/incognito browser window (or a different browser).

**Expected result:**

- The form is accessible via the shared link without requiring a Nextcloud login.
- The respondent can fill in and submit the form.
- After submission, the responses appear in the form owner's **Forms** dashboard under **Responses**.

![service running](./img/test40.png)

![service running](./img/test41.png)

![service running](./img/test42.png)

![service running](./img/test43.png)

![service running](./img/test44.png)

![service running](./img/test45.png)

![service running](./img/test46.png)
