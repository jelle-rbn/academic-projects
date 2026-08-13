# Test plan — Windows Domain Controller

Author(s): Johan Magerman - `johan.magerman@student.hogent.be`

## Before starting

- Open a terminal window and navigate to the `/src` folder of the project.
- Use the command `vagrant up windowsdc` and wait for provisioning to complete (both stages - this takes about 15 minutes!).
- Connect to the Windows server using `vagrant winrm windowsdc`.
- For tests that require a second machine (domain join, DNS queries from a client), have a Windows client VM available that is reachable on the same network segment.

---

## Test 1: Is the DC reachable via ping?

**Test procedure (from another machine on the same network):**

```
ping 192.168.132.194
```

**Expected result:**

- All replies are received with no packet loss.
- Round-trip times are in the single-digit milliseconds range.

---

## Test 2: Is the hostname and IP address configured correctly?

**Test procedure (on the DC):**

```powershell
$cs = Get-CimInstance Win32_ComputerSystem
Write-Host $cs.Name
ipconfig
```

**Expected result:**

- Hostname is `windowsdc`.
- The active network adapter shows IPv4 address `192.168.132.194` with subnet mask `255.255.255.224`.

---

## Test 3: Is the server successfully promoted to a Domain Controller?

**Test procedure (on the DC):**

```powershell
$cs = Get-CimInstance Win32_ComputerSystem
Write-Host "DomainRole: $($cs.DomainRole)  Domain: $($cs.Domain)"
```

**Expected result:**

- `DomainRole` is `5` (Primary Domain Controller).
- `Domain` is `ad.t02-domain404.internal`.

---

## Test 4: Are the required Windows features installed?

**Test procedure (on the DC):**

```powershell
Get-WindowsFeature DNS, AD-Domain-Services, RSAT-ADDS, RSAT-AD-PowerShell |
    Select-Object Name, Installed, InstallState
```

**Expected result:**

- All four features (`DNS`, `AD-Domain-Services`, `RSAT-ADDS`, `RSAT-AD-PowerShell`) show `Installed = True`.

---

## Test 5: Are the AD-related Windows services running?

**Test procedure (on the DC):**

```powershell
Get-Service ADWS, DNS, KDC, Netlogon, NTDS, W32Time |
    Select-Object Name, Status, StartType
```

**Expected result:**

- All services (`ADWS`, `DNS`, `KDC`, `Netlogon`, `NTDS`, `W32Time`) have `Status = Running` and `StartType = Automatic`.

---

## Test 6: Is the Active Directory domain configured correctly?

**Test procedure (on the DC):**

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode, PDCEmulator
Get-ADForest | Select-Object Name, ForestMode
```

**Expected result:**

- `DNSRoot` is `ad.t02-domain404.internal`.
- `NetBIOSName` is `DOMAIN404`.
- `DomainMode` and `ForestMode` are both `Windows2016...`.
- `PDCEmulator` points to `windowsdc.ad.t02-domain404.internal`.

---

## Test 7: Is the DC registered as a Domain Controller?

**Test procedure (on the DC):**

```powershell
Get-ADDomainController -Filter * | Select-Object Name, IPv4Address, IsGlobalCatalog, OperationMasterRoles
```

**Expected result:**

- `windowsdc` appears with IP `192.168.132.194`.
- `IsGlobalCatalog` is `True`.
- All five FSMO roles (`PDCEmulator`, `RIDMaster`, `InfrastructureMaster`, `SchemaMaster`, `DomainNamingMaster`) are held by `windowsdc`.

---

## Test 8: Is the DNS Server service running and configured correctly?

**Test procedure (on the DC):**

```powershell
Get-Service DNS | Select-Object Name, Status, StartType
Get-DnsServerForwarder | Select-Object -ExpandProperty IPAddress
```

**Expected result:**

- DNS service is `Running` with `StartType = Automatic`.
- Forwarders include `1.1.1.1`, `1.0.0.1`, `8.8.8.8`, and `8.8.4.4` (Cloudflare and Google).

---

## Test 9: Are the DNS zones created correctly?

**Test procedure (on the DC):**

```powershell
Get-DnsServerZone | Select-Object ZoneName, ZoneType, IsDsIntegrated, DynamicUpdate
```

**Expected result:**

- Forward lookup zone `ad.t02-domain404.internal` exists, is AD-integrated, and allows secure dynamic updates.
- Reverse lookup zone `132.168.192.in-addr.arpa` exists, is AD-integrated, and allows secure dynamic updates.

---

## Test 10: Are the DNS A and PTR records for the DC present?

**Test procedure (on the DC):**

```powershell
# A record
Resolve-DnsName -Name "windowsdc.ad.t02-domain404.internal" -Type A

# PTR record
Resolve-DnsName -Name "194.132.168.192.in-addr.arpa" -Type PTR
```

**Expected result:**

- The A record resolves to `192.168.132.194`.
- The PTR record resolves to `windowsdc.ad.t02-domain404.internal`.

---

## Test 11: Does the DC use itself as its DNS server?

**Test procedure (on the DC):**

```powershell
Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object { $_.ServerAddresses -ne '' } |
    Select-Object InterfaceAlias, ServerAddresses
```

**Expected result:**

- The active network adapter has `127.0.0.1` (or `192.168.132.194`) as its primary DNS server.

---

## Test 12: Can the DC resolve external DNS names (forwarders working)?

**Test procedure (on the DC):**

```powershell
Resolve-DnsName -Name "google.com" -Type A
```

**Expected result:**

- One or more A records are returned for `google.com`, confirming that DNS forwarding to Cloudflare/Google is operational.

---

## Test 13: Can DNS queries reach the DC from another machine?

**Test procedure (from a Windows client on the same network):**

```
nslookup windowsdc.ad.t02-domain404.internal 192.168.132.194
```

**Expected result:**

- The query returns `192.168.132.194` without errors, confirming the DC's DNS service is reachable from the network.

---

## Test 14: Are the default Active Directory Organisational Units present?

**Test procedure (on the DC):**

```powershell
Get-ADOrganizationalUnit -Filter * |
    Select-Object Name, DistinguishedName
```

**Expected result:**

- The default built-in OUs (`Domain Controllers`, etc.) are present.
- Any custom OUs defined in `$OUs` within `windowsdc-config.ps1` are also listed. *(Currently the `$OUs` array is empty.)*

---

## Test 15: Are the expected AD user accounts present?

**Test procedure (on the DC):**

```powershell
Get-ADUser -Filter * | Select-Object SamAccountName, Name, Enabled
```

**Expected result:**

- The built-in `Administrator` account is present.
- The users accounts are present.
- Any additional domain users created during provisioning are listed and `Enabled = True`. *(Update this test once user creation is implemented in stage2.)*

---
