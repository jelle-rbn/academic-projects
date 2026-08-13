# Test report

- Test Executor(s): Guillaume Lescur - `guillaume.lescur@student.hogent.be`
- Executed on: 21/03/2026

## Test 1: Ping the local host

**Test procedure:**

- Run the command `ping 127.0.0.1`

Obtained result:

- All pings are successful.
- The round trips are almost instant (less then 1ms).

![Test 1](./img/Client_test_1.png)

Test passed:

- [x] Yes
- [ ] No

## Test 2: Is the client reachable on the network?

**Test procedure**

- On the client push `windows key + r`, then type `wf.msc` and press enter.
- Click inbound rules in the left panel.
- Right click and enable `File and Printer Sharing (Echo Request - ICMPv4-In)`
- Open another VM that is connected to the same internal network.
- Run the command: `ping 192.168.132.130 -c 4`

Obtained result:

- All pings are successful.

![Test 2](./img/Client_test_2.png)

Test passed:

- [x] Yes
- [ ] No

## Test 3: Is the client configured with the correct DNS servers?

**Test procedure**

- On the client open Powershell and run: `Get-DnsClientServerAddress -AddressFamily IPv4`

Obtained result:

- The primary DNS server is `192.168.132.193`. This is the IP address of the domain controller.
- The fallback servers `1.1.1.1` and `8.8.8.8` are also listed.

![Test 3](./img/Client_test_3.png)

Test passed:

- [x] Yes
- [ ] No

## Test 4: Can the client resolve the domain name?

**Test procedure**

- On the client open Powershell and run: `Resolve-DnsName ad.t02-domain404.internal`

Obtained result:

- The domain resolves successfully and returns the IP address of the domain controller `192.168.132.194`.

![Test 4](./img/Client_test_4.png)

Test passed:

- [x] Yes
- [ ] No

## Test 5: Is the client joined to the correct domain?

**Test procedure**

- On the client open Powershell and run: `(Get-CimInstance Win32_ComputerSystem).Domain`

Obtained result:

- The output shows `ad.t02-domain404.internal`.

![Test 5](./img/Client_test_5.png)

Test passed:

- [x] Yes
- [ ] No

## Test 6: Can the client reach the domain controller?

**Test procedure**

- On the client open Powershell and run: `Test-Connection -ComputerName 192.168.132.194 -Count 4`

Obtained result:

- All pings are successful.

![Test 6](./img/Client_test_6.png)

Test passed:

- [x] Yes
- [ ] No

## Test 7: Are the RSAT tools installed?

**Test procedure**

- On the client open Powershell and run: `Get-WindowsCapability -Online | Where-Object { $_.Name -like "Rsat*" -and $_.State -eq "Installed" }`

Obtained result:

- The following tools are installed:
  - `Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0`
  - `Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0`
  - `Rsat.Dns.Tools~~~~0.0.1.0`
  - `Rsat.FileServices.Tools~~~~0.0.1.0`
  - `Rsat.ServerManager.Tools~~~~0.0.1.0`

![Test 7](./img/Client_test_7.png)

Test passed:

- [x] Yes
- [ ] No
