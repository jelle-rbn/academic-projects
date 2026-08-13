# Test Report - Nextcloud Server

Author(s): Johan Magerman - `johan.magerman@student.hogent.be`

## Test 1: Is the Nextcloud server reachable on the network?

**Test procedure:**

- On another VM, run:

  ```bash
  ping 192.168.132.197 -c 4
  ```

**Obtained result:**

- All 4 pings are successful.
- The round-trip times are low.

![succeful ping](./img/result1.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 2: Is Apache running on the Nextcloud server?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  systemctl status httpd
  ```

**Obtained result:**

- The service is `active (running)`.

![service running](./img/result2.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 3: Is PHP-FPM running?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  systemctl status php-fpm
  ```

**Obtained result:**

- The service is `active (running)`.

![service running](./img/result3.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 4: Is Valkey running?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  systemctl status valkey
  ```

**Obtained result:**

- The service is `active (running)`.

![service running](./img/result4.png)

Test passed:

- [x] Yes
- [ ] No

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

**Obtained result:**

- The command returns `1` without errors.

![service running](./img/result5.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 6: Is the Nextcloud web interface reachable via the reverse proxy?

**Test procedure:**

- On the Windows client, open a browser and navigate to:

  ```
  https://nextcloud.t02-domain404.internal
  ```

**Obtained result:**

- The browser opens the Nextcloud login page without any connection errors.

![service running](./img/result6.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 7: Can the admin user log in to Nextcloud?

**Test procedure:**

- On the Nextcloud login page, enter:
  - Username: `admin`
  - Password: `admin404`
- Click **Log in**.

**Obtained result:**

- Login is successful and the Nextcloud dashboard is shown.

![service running](./img/result7.png)

Test passed:

- [x] Yes
- [ ] No


---

## Test 8: Does the local Nextcloud user account exist?

**Test procedure:**

- Log in as `admin` and navigate to **Accounts**.

**Obtained result:**

- The user `linustorvalds` (display name: Linus Torvalds) is listed.

![Linus Torvalds available](./img/result8.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 9: Can the local Nextcloud user log in?

**Test procedure:**

- Log out of the admin account.
- Log in with:
  - Username: `linustorvalds`
  - Password: `IDidntMadeAnyMoneyFromLinux`

**Obtained result:**

- Login is successful and the Nextcloud dashboard is shown for the user `Linus Torvalds`.

![service running](./img/result9.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 10: Is the LDAP/AD integration enabled?

**Test procedure:**

- Log in as `admin` and navigate to **Settings → LDAP/AD Integration** (under Administration).

**Obtained result:**

- An active LDAP configuration is listed.
- The configuration shows the host `192.168.132.194` (the Windows Domain Controller) on port `389`.
- The connection status shows a green checkmark or "Configuration OK".


![service running](./img/result10.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 11: Can an Active Directory user log in to Nextcloud?

**Test procedure:**

- Login to the winclient with your usersname and choose a new password.
- On the login page of Nextcloud, enter the credentials of an existing AD user:
  - Username: `AD username`
  - Password: `AD password`

**Obtained result:**

- Login is successful using the JMA8601 credentials.
- No separate Nextcloud account is needed — the user is authenticated via Active Directory.

![service running](./img/result11.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 12: Is file synchronisation working with the Nextcloud desktop client?

**Test procedure:**

- Open the Nextcloud client on the winclient and connect to `https://nextcloud.t02-domain404.internal`.
- Authenticate with a valid account (e.g. `linustorvalds`).
- Add a test file to the local sync folder.
- Wait for the sync indicator to show completion.
- Open the Nextcloud client on the rockyclient and connect to `https://nextcloud.t02-domain404.internal`.
- Authenticate with the same account as on the winclient.

**Obtained result:**

- The file uploaded from the winclient is visible on the rockyclient.

![service running](./img/result12.png)

![service running](./img/result13.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 13: Does the calendar for `linustorvalds` exist?

**Test procedure:**

- SSH into the Nextcloud server and run:

  ```bash
  sudo -u apache php /var/www/html/nextcloud/occ dav:list-calendars linustorvalds
  ```

**Obtained result:**

- The output lists the calendar named `Domain404 Calendar`.

![service running](./img/result14.png)

Test passed:

- [x] Yes
- [ ] No

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

**Obtained result:**

- The calendar `Domain404 Calendar` appears in Thunderbird's calendar list on the left.
- The event is visible on the nextcloud webinterface under the tab activities.

![service running](./img/result15.png)

![service running](./img/result16.png)

![service running](./img/result17.png)

Test passed:

- [x] Yes
- [ ] No

---

## Test 15: Can a form be created and shared?

**Test procedure:**

- Log in as `linustorvalds` (or any valid user).
- Navigate to the **Forms** app from the top navigation bar.
- Create a new form with at least one question (e.g. a text field).
- Click **Share** and copy the public link.
- Open the link in a private/incognito browser window (or a different browser).

**Obtained result:**

- The form is accessible via the shared link without requiring a Nextcloud login.
- The respondent can fill in and submit the form.
- After submission, the responses appear in the form owner's **Forms** dashboard under **Responses**.

![service running](./img/result18.png)

![service running](./img/result19.png)

![service running](./img/result20.png)

Test passed:

- [x] Yes
- [ ] No