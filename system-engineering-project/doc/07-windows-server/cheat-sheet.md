# Cheat Sheet - Windows Domain Controller
_Author: Johan Magerman - johan.magerman@student.hogent.be_

# Windows Domain Controller — Cheat Sheet
### Environment: `windowsdc` · `ad.t02-domain404.internal` · `192.168.132.194`

> All commands are intended to be run in an **elevated PowerShell session** on the DC.
> Variables from `win-config.ps1` / `win-data.psd1` are shown where they map directly.

---

## Table of Contents

1. [Network](#1-network)
2. [DNS Server](#2-dns-server)
3. [Active Directory — OUs](#3-active-directory--organisational-units)
4. [Active Directory — Users](#4-active-directory--users)
5. [Active Directory — Groups](#5-active-directory--groups)
6. [Active Directory — Computers](#6-active-directory--computers)
7. [Domain Join & Delegation](#7-domain-join--delegation)
8. [Storage Spaces & Profile Drive](#8-storage-spaces--profile-drive)
9. [SMB Shares](#9-smb-shares)
10. [Group Policy](#10-group-policy)
11. [Windows Features & Roles](#11-windows-features--roles)
12. [Domain Controller Health](#12-domain-controller-health)
13. [Replication & FSMO](#13-replication--fsmo)
14. [Security & Audit](#14-security--audit)
15. [Quick-Reference Variables](#15-quick-reference-variables)

---

## 1. Network

### Show current IP configuration

```powershell
# All adapters — full detail
Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias, IPAddress, PrefixLength

# Compact ipconfig equivalent
ipconfig /all

# Show only the VLAN adapter (192.168.132.x)
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -match '^192\.168\.132\.' }
```

### Change a static IP address

```powershell
$iface  = 'Ethernet 2'          # replace with actual adapter name
$oldIP  = '192.168.132.194'
$newIP  = '192.168.132.194'      # new address
$prefix = 26                     # /26 = 255.255.255.192

Remove-NetIPAddress -InterfaceAlias $iface -IPAddress $oldIP -Confirm:$false
New-NetIPAddress    -InterfaceAlias $iface -IPAddress $newIP -PrefixLength $prefix
```

### Show & manage DNS client addresses

```powershell
# Show DNS servers configured on each adapter
Get-DnsClientServerAddress -AddressFamily IPv4

# Point all live adapters at localhost (DC resolves itself)
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
    Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses '127.0.0.1'
}

# Reset an adapter to DHCP-assigned DNS
Set-DnsClientServerAddress -InterfaceAlias 'Ethernet 2' -ResetServerAddresses
```

### Show routing table

```powershell
# All routes
Get-NetRoute -AddressFamily IPv4 | Sort-Object RouteMetric |
    Format-Table DestinationPrefix, NextHop, InterfaceAlias, RouteMetric

# Default gateway only
Get-NetRoute -DestinationPrefix '0.0.0.0/0'
```

### Add a routing entry

```powershell
# Add default gateway via the VLAN adapter
New-NetRoute -InterfaceAlias 'Ethernet 2' `
             -DestinationPrefix '0.0.0.0/0' `
             -NextHop '192.168.132.193' `
             -RouteMetric 50

# Add a host-specific or subnet route
New-NetRoute -InterfaceAlias 'Ethernet 2' `
             -DestinationPrefix '10.0.0.0/8' `
             -NextHop '192.168.132.193'
```

### Remove a routing entry

```powershell
Remove-NetRoute -DestinationPrefix '0.0.0.0/0' -InterfaceAlias 'Ethernet 2' -Confirm:$false

# Remove ALL default routes (use with care)
Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Remove-NetRoute -Confirm:$false
```

### Firewall — enable ICMP ping

```powershell
# Allow inbound ICMPv4 from anywhere on any profile
Set-NetFirewallRule -Name 'CoreNet-Diag-ICMP4-EchoRequest-In' `
                    -Profile Any -RemoteAddress Any -Enabled True
```

### Test connectivity

```powershell
# Ping
Test-NetConnection -ComputerName 192.168.132.193

# Port check (e.g. LDAP on client)
Test-NetConnection -ComputerName 192.168.132.130 -Port 389

# Trace route
Test-NetConnection -ComputerName 1.1.1.1 -TraceRoute
```

---

## 2. DNS Server

### Show current configuration

```powershell
# All zones
Get-DnsServerZone | Format-Table ZoneName, ZoneType, IsDsIntegrated, DynamicUpdate

# All forwarders
Get-DnsServerForwarder

# Records in a zone
Get-DnsServerResourceRecord -ZoneName 'ad.t02-domain404.internal' |
    Sort-Object RecordType | Format-Table HostName, RecordType, RecordData

# PTR records (reverse zone)
Get-DnsServerResourceRecord -ZoneName '132.168.192.in-addr.arpa' -RRType Ptr
```

### Manage forwarders

```powershell
# Add forwarders
Add-DnsServerForwarder -IPAddress '1.1.1.1','1.0.0.1','8.8.8.8','8.8.4.4'

# Replace all forwarders
$existing = Get-DnsServerForwarder
if ($existing.IPAddress) {
    Remove-DnsServerForwarder -IPAddress $existing.IPAddress -Force
}
Add-DnsServerForwarder -IPAddress '1.1.1.1','1.0.0.1','8.8.8.8','8.8.4.4'
```

### Create zones

```powershell
# Primary forward zone (AD-integrated)
Add-DnsServerPrimaryZone -Name 'ad.t02-domain404.internal' `
                         -ReplicationScope 'Forest' -DynamicUpdate 'Secure'

# Reverse lookup zone for /26 network
Add-DnsServerPrimaryZone -NetworkID '192.168.132.192/26' `
                         -ReplicationScope 'Forest' -DynamicUpdate 'Secure'

# Secondary (non-AD) internal zone
Add-DnsServerPrimaryZone -Name 't02-domain404.internal' `
                         -ReplicationScope 'Forest' -DynamicUpdate 'None'
```

### Add / remove DNS records

```powershell
# A record
Add-DnsServerResourceRecordA -ZoneName 'ad.t02-domain404.internal' `
                             -Name 'web' -IPv4Address '192.168.132.196'

# PTR record
Add-DnsServerResourceRecordPtr -ZoneName '132.168.192.in-addr.arpa' `
                               -Name '196' `
                               -PtrDomainName 'web.ad.t02-domain404.internal.'

# CNAME record
Add-DnsServerResourceRecordCName -ZoneName 'ad.t02-domain404.internal' `
                                 -Name 'www' `
                                 -HostNameAlias 'ad.t02-domain404.internal.'

# Remove any record type
Remove-DnsServerResourceRecord -ZoneName 'ad.t02-domain404.internal' `
                               -Name 'web' -RRType A -Force
```

### Force DNS registration / flush

```powershell
# Force client to re-register (run on client or DC)
ipconfig /registerdns

# Flush local DNS resolver cache
Clear-DnsClientCache

# Flush server cache
Clear-DnsServerCache -Force

# Check name resolution
Resolve-DnsName 'windowsdc.ad.t02-domain404.internal'
Resolve-DnsName '192.168.132.194' -Type PTR
```

### DNS diagnostic

```powershell
# Test zone delegation
Test-DnsServer -Context DnsServer -ComputerName 'windowsdc'

# Show DNS Server statistics
Get-DnsServerStatistics

# Show DNS debug log (if enabled)
Get-DnsServerDiagnostics
```

---

## 3. Active Directory — Organisational Units

### Browse the OU structure

```powershell
Import-Module ActiveDirectory

# List all OUs, sorted by DN depth
Get-ADOrganizationalUnit -Filter * -Properties CanonicalName |
    Sort-Object CanonicalName | Select-Object Name, CanonicalName

# Show direct children of a specific OU
Get-ADOrganizationalUnit -Filter * |
    Where-Object { $_.DistinguishedName -match 'OU=D404,DC=ad,DC=t02-domain404,DC=internal$' }
```

### Create an OU

```powershell
New-ADOrganizationalUnit -Name 'Finance' `
    -Path 'OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
    -ProtectedFromAccidentalDeletion $false
```

### Move an OU or object

```powershell
# Move computer from _Staging to IT Workstations
Move-ADObject `
    -Identity 'CN=L-26-00001,OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
    -TargetPath 'OU=IT,OU=Workstations,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
```

### Delete an OU

```powershell
# Disable accidental deletion protection first
Set-ADOrganizationalUnit -Identity 'OU=Finance,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
                         -ProtectedFromAccidentalDeletion $false

Remove-ADOrganizationalUnit `
    -Identity 'OU=Finance,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' -Confirm:$false
```

---

## 4. Active Directory — Users

### Query users

```powershell
# All users in a specific OU (recursive)
Get-ADUser -Filter * -SearchBase 'OU=IT,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
    -Properties DisplayName, EmailAddress, Title, Enabled |
    Format-Table SamAccountName, DisplayName, Enabled

# Find a specific user
Get-ADUser -Identity 'JMA8601' -Properties *

# Find disabled accounts
Get-ADUser -Filter { Enabled -eq $false } | Select-Object SamAccountName, DistinguishedName

# Find accounts with non-expiring passwords
Get-ADUser -Filter { PasswordNeverExpires -eq $true } | Select-Object SamAccountName
```

### Create a user

```powershell
$secPwd = ConvertTo-SecureString 'P@ssw0rd!' -AsPlainText -Force

New-ADUser `
    -SamAccountName      'USR0001' `
    -UserPrincipalName   'USR0001@ad.t02-domain404.internal' `
    -Name                'New User' `
    -GivenName           'New' `
    -Surname             'User' `
    -DisplayName         'New User' `
    -AccountPassword     $secPwd `
    -Path                'OU=IT,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
    -Enabled             $true `
    -ChangePasswordAtLogon $true `
    -EmailAddress        'new.user@t02-domain404.internal' `
    -Title               'System Engineer' `
    -Department          'IT' `
    -Company             'Domain 404' `
    -ProfilePath         '\\windowsdc\Profiles\%username%' `
    -HomeDrive           'H:' `
    -HomeDirectory       '\\windowsdc\Home\USR0001'
```

### Modify a user

```powershell
# Unlock
Unlock-ADAccount -Identity 'JMA8601'

# Reset password (force change at next logon)
Set-ADAccountPassword -Identity 'JMA8601' `
    -NewPassword (ConvertTo-SecureString 'NewP@ss!' -AsPlainText -Force) -Reset
Set-ADUser -Identity 'JMA8601' -ChangePasswordAtLogon $true

# Enable / disable
Enable-ADAccount  -Identity 'JMA8601'
Disable-ADAccount -Identity 'JMA8601'

# Update attributes
Set-ADUser -Identity 'JMA8601' -Title 'Senior System Engineer' -Department 'IT'

# Change profile path
Set-ADUser -Identity 'JMA8601' -ProfilePath '\\windowsdc\Profiles\%username%'

# Move user to another OU
Move-ADObject -Identity (Get-ADUser 'JMA8601').DistinguishedName `
    -TargetPath 'OU=_Decommissioned,OU=Users,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
```

### Delete a user

```powershell
Remove-ADUser -Identity 'USR0001' -Confirm:$false
```

### Password policy (domain-wide)

```powershell
# View
Get-ADDefaultDomainPasswordPolicy

# Relax (lab environment — matches win-data.psd1 intent)
Set-ADDefaultDomainPasswordPolicy -Identity 'ad.t02-domain404.internal' `
    -MinPasswordLength 0 -ComplexityEnabled $false `
    -PasswordHistoryCount 0 -MinPasswordAge 0 -MaxPasswordAge 0
```

---

## 5. Active Directory — Groups

### Query groups

```powershell
# All custom GPO/Role groups
Get-ADGroup -Filter * -SearchBase 'OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal' |
    Select-Object Name, GroupScope, GroupCategory

# Members of a group
Get-ADGroupMember -Identity 'GRP_Logon_IT' | Select-Object SamAccountName, ObjectClass

# Groups a user belongs to
Get-ADPrincipalGroupMembership -Identity 'JMA8601' | Select-Object Name
```

### Create a group

```powershell
New-ADGroup -Name 'GRP_Logon_Finance' `
    -SamAccountName 'GRP_Logon_Finance' `
    -GroupScope 'Global' `
    -GroupCategory 'Security' `
    -Path 'OU=GPO,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
    -Description 'Finance users. Permitted to log on to Finance workstations.'
```

### Add / remove members

```powershell
# Add one or more members
Add-ADGroupMember -Identity 'GRP_Logon_IT' -Members 'JMA8601','DCO9001'

# Remove a member
Remove-ADGroupMember -Identity 'GRP_Logon_IT' -Members 'DCO9001' -Confirm:$false
```

### Delete a group

```powershell
Remove-ADGroup -Identity 'GRP_Logon_Finance' -Confirm:$false
```

---

## 6. Active Directory — Computers

### Query computers

```powershell
# All computer accounts
Get-ADComputer -Filter * -Properties Description, OperatingSystem |
    Format-Table Name, Enabled, OperatingSystem, Description

# Computers in _Staging (not yet moved to production)
Get-ADComputer -Filter * `
    -SearchBase 'OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
```

### Pre-stage a computer account

```powershell
New-ADComputer `
    -Name        'L-26-00002' `
    -Path        'OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
    -Description 'Pre-staged workstation' `
    -Enabled     $true
```

### Move computer to production OU

```powershell
Move-ADObject `
    -Identity (Get-ADComputer 'L-26-00001').DistinguishedName `
    -TargetPath 'OU=IT,OU=Workstations,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
```

### Machine account quota

```powershell
# View current quota (default 10; set to 0 to block self-joins)
(Get-ADDomain).Properties | Where-Object Name -eq 'ms-DS-MachineAccountQuota'
# or
Get-ADObject -Identity (Get-ADDomain).DistinguishedName `
    -Properties 'ms-DS-MachineAccountQuota' |
    Select-Object 'ms-DS-MachineAccountQuota'

# Lock down self-join
Set-ADDomain -Identity 'ad.t02-domain404.internal' `
    -Replace @{ 'ms-DS-MachineAccountQuota' = '0' }
```

---

## 7. Domain Join & Delegation

### Manually join a machine (from the target machine)

```powershell
$cred = Get-Credential 'DOMAIN404\SVC_DomainJoin'
Add-Computer -DomainName 'ad.t02-domain404.internal' `
             -Credential $cred `
             -OUPath 'OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
             -Restart
```

### Check/repair delegated ACLs on _Staging OU

```powershell
$stagingOU   = 'OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal'
$joinAccount = 'DOMAIN404\SVC_DomainJoin'

# Show current ACL
(Get-Acl "AD:\$stagingOU").Access | Format-Table IdentityReference, ActiveDirectoryRights

# Re-apply minimal domain-join delegation
$rights = @(
    "/I:S /G `"${joinAccount}:CA;Reset Password;computer`""
    "/I:S /G `"${joinAccount}:WP;pwdLastSet;computer`""
    "/I:S /G `"${joinAccount}:WP;userAccountControl;computer`""
    "/I:S /G `"${joinAccount}:WS;Validated write to DNS host name;computer`""
    "/I:S /G `"${joinAccount}:WS;Validated write to service principal name;computer`""
)
foreach ($r in $rights) { Invoke-Expression "dsacls `"$stagingOU`" $r" | Out-Null }
```

### Remove a machine from the domain (from the target machine)

```powershell
Remove-Computer -WorkgroupName 'WORKGROUP' -UnjoinDomaincredential (Get-Credential) -Restart -Force
```

### Delete a stale computer account

```powershell
Remove-ADComputer -Identity 'L-26-00001' -Confirm:$false
```

---

## 8. Storage Spaces & Profile Drive

### Show Storage Spaces configuration

```powershell
# Storage pools
Get-StoragePool | Format-Table FriendlyName, HealthStatus, OperationalStatus, Size

# Virtual disks in the pool
Get-VirtualDisk | Format-Table FriendlyName, ResiliencySettingName, HealthStatus, Size

# Physical disks and poolability
Get-PhysicalDisk | Format-Table FriendlyName, CanPool, HealthStatus, Size

# Volumes
Get-Volume | Format-Table DriveLetter, FileSystemLabel, HealthStatus, SizeRemaining, Size
```

### Check pool and mirror health

```powershell
$pool = Get-StoragePool -FriendlyName 'Profiledrive'
$pool | Get-VirtualDisk | Get-Disk | Get-Partition | Get-Volume

# Trigger a repair (rebuild after disk failure)
$vdisk = Get-VirtualDisk -FriendlyName 'Profiledrive-vDisk'
Repair-VirtualDisk -InputObject $vdisk -Confirm:$false
```

### Expand the volume (after adding capacity)

```powershell
$vdisk = Get-VirtualDisk -FriendlyName 'Profiledrive-vDisk'
$disk  = $vdisk | Get-Disk
$part  = $disk  | Get-Partition | Where-Object { $_.DriveLetter -eq 'P' }

# Resize the partition to maximum available
$maxSize = ($part | Get-PartitionSupportedSize).SizeMax
Resize-Partition -InputObject $part -Size $maxSize
```

---

## 9. SMB Shares

### Show shares

```powershell
# All shares
Get-SmbShare | Format-Table Name, Path, Description

# Permissions on a specific share
Get-SmbShareAccess -Name 'Profiles'
Get-SmbShareAccess -Name 'Home'

# Current open sessions
Get-SmbSession

# Open files
Get-SmbOpenFile
```

### Create a share

```powershell
New-SmbShare -Name 'Profiles' `
             -Path 'P:\Profiles' `
             -FullAccess 'BUILTIN\Administrators' `
             -ChangeAccess 'Authenticated Users' `
             -FolderEnumerationMode 'AccessBased'
```

### Modify share permissions

```powershell
# Grant change access to a new group
Grant-SmbShareAccess -Name 'Profiles' -AccountName 'DOMAIN404\GRP_Logon_IT' `
                     -AccessRight Change -Force

# Revoke access
Revoke-SmbShareAccess -Name 'Profiles' -AccountName 'DOMAIN404\GRP_Logon_IT' -Force
```

### Remove a share

```powershell
Remove-SmbShare -Name 'OldShare' -Force
```

### NTFS permissions on profile/home root

```powershell
# View NTFS ACL
(Get-Acl 'P:\Profiles').Access | Format-Table IdentityReference, FileSystemRights, IsInherited

# Example: add a user's personal home folder with exclusive rights
$sam     = 'JMA8601'
$homePath = "P:\Home\$sam"
New-Item -ItemType Directory -Path $homePath -Force | Out-Null

$acl = Get-Acl $homePath
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    'NT AUTHORITY\SYSTEM', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    'BUILTIN\Administrators', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "DOMAIN404\$sam", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
Set-Acl -Path $homePath -AclObject $acl
```

---

## 10. Group Policy

### Query GPOs

```powershell
Import-Module GroupPolicy

# List all GPOs
Get-GPO -All -Domain 'ad.t02-domain404.internal' |
    Select-Object DisplayName, GpoStatus, CreationTime |
    Sort-Object DisplayName

# Show links on an OU
Get-GPInheritance -Target 'OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' |
    Select-Object -ExpandProperty GpoLinks

# Generate HTML report for a specific GPO
Get-GPOReport -Name 'GPO-Staging-Lockdown' -ReportType HTML -Path 'C:\Temp\staging-gpo.html'
```

### Create and link a GPO

```powershell
$gpo = New-GPO -Name 'GPO-New-Policy' -Domain 'ad.t02-domain404.internal'

New-GPLink -Name 'GPO-New-Policy' `
           -Target 'OU=IT,OU=Workstations,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
           -LinkEnabled 'Yes' -Enforced 'No'
```

### Set a registry value via GPO

```powershell
Set-GPRegistryValue -Name 'GPO-Baseline-Standard' `
    -Key 'HKLM\Software\Policies\Microsoft\Windows\System' `
    -ValueName 'AddAdminGroupToRUP' -Type DWord -Value 1
```

### Force GPO refresh

```powershell
# On the DC itself
gpupdate /force

# On a remote machine
Invoke-GPUpdate -Computer 'L-26-00001' -Force -RandomDelayInMinutes 0
```

### Disable / remove a GPO link

```powershell
# Disable link (GPO stays, just not applied)
Set-GPLink -Name 'GPO-Staging-Lockdown' `
    -Target 'OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal' `
    -LinkEnabled 'No'

# Remove link entirely
Remove-GPLink -Name 'GPO-Staging-Lockdown' `
    -Target 'OU=_Staging,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal'

# Delete the GPO object completely
Remove-GPO -Name 'GPO-New-Policy' -Domain 'ad.t02-domain404.internal'
```

### Backup and restore GPOs

```powershell
# Backup all GPOs
Backup-GPO -All -Path 'C:\GPOBackups' -Comment "Pre-change backup $(Get-Date -Format yyyyMMdd)"

# Restore a specific GPO
Restore-GPO -Name 'GPO-Staging-Lockdown' -Path 'C:\GPOBackups'
```

---

## 11. Windows Features & Roles

### Check installed roles and features

```powershell
# High-level summary
Get-WindowsFeature | Where-Object { $_.InstallState -eq 'Installed' } |
    Select-Object Name, DisplayName | Sort-Object Name

# Specific features used by this DC
$features = @('DNS','AD-Domain-Services','RSAT-ADDS','RSAT-AD-PowerShell','FS-DFS-Namespace')
Get-WindowsFeature -Name $features | Select-Object Name, DisplayName, InstallState
```

### Install a feature

```powershell
Install-WindowsFeature -Name 'FS-DFS-Replication' -IncludeManagementTools
```

### Remove a feature

```powershell
Uninstall-WindowsFeature -Name 'FS-DFS-Replication' -Remove
```

### RSAT features (Windows 10/11 client — run from client)

```powershell
# List available
Get-WindowsCapability -Online | Where-Object { $_.Name -like 'Rsat*' } |
    Select-Object Name, State

# Install AD and GP RSAT tools (matches win-data.psd1)
Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
Add-WindowsCapability -Online -Name 'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0'
```

---

## 12. Domain Controller Health

### AD and replication diagnostics

```powershell
# Overall DC diagnostic (runs ~20 tests)
dcdiag /v

# Replication summary
repadmin /replsummary

# Show replication partners
repadmin /showrepl

# Force inbound replication from all partners
repadmin /syncall /Ade

# Netlogon / Sysvol check
netlogon /check

# Verify Sysvol share is accessible
Test-Path '\\ad.t02-domain404.internal\SYSVOL'
Test-Path '\\ad.t02-domain404.internal\NETLOGON'
```

### Key services — check and restart

```powershell
$dcServices = @('ADWS','DNS','KDC','Netlogon','NTDS','W32Time','LanmanServer')

Get-Service -Name $dcServices | Format-Table Name, Status, StartType

# Restart a specific service
Restart-Service -Name 'DNS' -Force
Restart-Service -Name 'Netlogon' -Force
```

### Time synchronisation

```powershell
# Show current NTP status
w32tm /query /status

# Resync the clock
w32tm /resync /force

# Configure DC as authoritative NTP server (PDC emulator)
w32tm /config /manualpeerlist:'0.pool.ntp.org,1.pool.ntp.org' /syncfromflags:manual /reliable:yes /update
Restart-Service W32Time
```

### Event logs — check for AD/DNS errors

```powershell
# Last 50 errors from Directory Services log
Get-WinEvent -LogName 'Directory Service' -MaxEvents 50 |
    Where-Object { $_.LevelDisplayName -in 'Error','Critical' } |
    Select-Object TimeCreated, Id, Message | Format-List

# DNS Server log errors
Get-WinEvent -LogName 'DNS Server' -MaxEvents 30 |
    Where-Object { $_.LevelDisplayName -in 'Error','Warning' } |
    Select-Object TimeCreated, Id, Message | Format-List
```

---

## 13. Replication & FSMO

### Show FSMO role holders

```powershell
# All five roles
netdom query fsmo

# Via PowerShell
Get-ADDomain  | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
Get-ADForest  | Select-Object SchemaMaster, DomainNamingMaster
```

### Transfer FSMO roles (graceful — source DC online)

```powershell
# Transfer all roles to this DC
Move-ADDirectoryServerOperationMasterRole -Identity 'windowsdc' `
    -OperationMasterRole SchemaMaster, DomainNamingMaster, PDCEmulator, RIDMaster, InfrastructureMaster
```

### Seize FSMO roles (emergency — source DC offline)

```powershell
# Seize all roles (use only when source DC is permanently offline)
Move-ADDirectoryServerOperationMasterRole -Identity 'windowsdc' `
    -OperationMasterRole SchemaMaster, DomainNamingMaster, PDCEmulator, RIDMaster, InfrastructureMaster `
    -Force
```

---

## 14. Security & Audit

### Locked accounts and password status

```powershell
# All locked-out accounts
Search-ADAccount -LockedOut | Select-Object SamAccountName, LockedOut, LastLogonDate

# Accounts with passwords set to never expire
Search-ADAccount -PasswordNeverExpires | Select-Object SamAccountName

# Accounts not logged in for 60+ days
$cutoff = (Get-Date).AddDays(-60)
Get-ADUser -Filter { LastLogonDate -lt $cutoff -and Enabled -eq $true } `
    -Properties LastLogonDate | Select-Object SamAccountName, LastLogonDate
```

### Audit policy

```powershell
# Show current effective audit policy
auditpol /get /category:*

# Enable Account Logon auditing (success and failure)
auditpol /set /subcategory:'Logon' /success:enable /failure:enable
auditpol /set /subcategory:'Account Lockout' /success:enable /failure:enable
```

### Security event log — failed logon attempts

```powershell
Get-WinEvent -LogName Security |
    Where-Object { $_.Id -eq 4625 } |   # 4625 = failed logon
    Select-Object -First 20 TimeCreated, Message |
    Format-List
```

### Check SID of an object

```powershell
(Get-ADGroup  'GRP_SVC_All').SID.Value
(Get-ADUser   'SVC_DomainJoin').SID.Value
(Get-ADDomain).DomainSID.Value
```

---

## 15. Quick-Reference Variables

| Variable | Value |
|---|---|
| Domain FQDN | `ad.t02-domain404.internal` |
| NetBIOS Name | `DOMAIN404` |
| Base DN | `DC=ad,DC=t02-domain404,DC=internal` |
| DC Hostname | `windowsdc` |
| DC IP | `192.168.132.194` |
| DC Gateway | `192.168.132.193` |
| DSRM Password | `t02-domain404` |
| DomainJoin SVC | `DOMAIN404\SVC_DomainJoin` |
| Profile Share | `\\windowsdc\Profiles` → `P:\Profiles` |
| Home Share | `\\windowsdc\Home` → `P:\Home` |
| Profile Drive | `P:` (Storage Spaces Mirror) |
| DNS Forwarders | `1.1.1.1`, `1.0.0.1`, `8.8.8.8`, `8.8.4.4` |
| Staging OU | `OU=_Staging,OU=Computers,OU=D404,DC=ad,...` |
| Service Account OU | `OU=ServiceAccounts,OU=Admin,OU=D404,DC=ad,...` |

### Load win-config.ps1 manually in a session

```powershell
# Dot-source to get all environment variables in your current session
. 'C:\provisioning\win-config.ps1'

# Then use variables directly:
Write-Host $DomainName         # ad.t02-domain404.internal
Write-Host $dcIP               # 192.168.132.194
Write-Host $ProfileSharePath   # P:\Profiles
```

### One-liner health snapshot

```powershell
Write-Host "=== DC Health Snapshot ===" -ForegroundColor Cyan
Write-Host "Domain  : $((Get-ADDomain).DNSRoot)"
Write-Host "DC      : $($env:COMPUTERNAME)"
Write-Host "Services:" ; Get-Service NTDS,DNS,KDC,Netlogon | Select-Object Name,Status | Format-Table
Write-Host "Shares  :" ; Get-SmbShare | Where-Object { $_.Name -notmatch '^\$' } | Select-Object Name,Path | Format-Table
Write-Host "Storage :" ; Get-VirtualDisk | Select-Object FriendlyName,HealthStatus | Format-Table
Write-Host "FSMO    :" ; netdom query fsmo
```