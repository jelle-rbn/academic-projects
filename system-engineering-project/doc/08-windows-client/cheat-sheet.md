# Cheat-sheet

**Author(s):** D. Cooreman — `dean.cooreman@student.hogent.be`

This document provides a quick reference for configuring a Windows 11 client, joining it to an Active Directory domain, and managing RSAT tools via PowerShell.

## Configuration File

| Variable | Value / Purpose |
| :--- | :--- |
| `$clientHostname` | Hostname of the Windows client (`winclient`) |
| `$clientIP` | IP assignment method (`DHCP`) |
| `$gateway` | Default gateway (`192.168.132.129`) |
| `$dcHostname` / `$DcIP` | DC hostname and IP (`windowsdc` / `192.168.132.194`) |
| `$DomainName` | FQDN of the domain (`ad.t02-domain404.local`) |
| `$DomainNetbiosName` | NetBIOS name (`DOMAIN404`) |
| `$DNSServers` | DC IP first, then `1.1.1.1`, `8.8.8.8` as fallbacks |
| `$NetworkAdapterPattern` | Adapter name pattern to target (`Ethernet`) |
| `$JoinOU` | OU path for computer account (empty = default `Computers`) |

## Network

| Command | Description |
| :--- | :--- |
| `Get-NetAdapter` | List all network adapters and their status |
| `Get-NetAdapter \| Where-Object { $_.Status -eq "Up" }` | Show only active adapters |
| `Set-DnsClientServerAddress -InterfaceAlias <name> -ServerAddresses <IPs>` | Set DNS servers on a specific adapter |
| `Get-NetRoute` | Show the routing table |
| `route add <network> mask <mask> <gateway> -p` | Add a persistent static route |
| `Test-Connection -ComputerName <IP> -Count 2 -Quiet` | Ping a host (returns `True`/`False`) |
| `Resolve-DnsName <domain>` | Test DNS resolution of a domain name |
| `ipconfig /registerdns` | Re-register this client's DNS entries on the DC |
| `ipconfig /all` | Show full IP configuration including DNS servers |

## Domain Join

| Command | Description |
| :--- | :--- |
| `Get-CimInstance Win32_ComputerSystem` | Show current computer name, domain, and domain role |
| `ConvertTo-SecureString <pwd> -AsPlainText -Force` | Convert a plaintext password to a `SecureString` |
| `New-Object System.Management.Automation.PSCredential(<user>, <secpwd>)` | Build a `PSCredential` object for domain operations |
| `Add-Computer -DomainName <fqdn> -Credential <cred> -Force -Restart` | Join the domain and reboot |
| `Add-Computer ... -OUPath <ou>` | Join and place computer account in a specific OU |

## RSAT Installation

| Command | Description |
| :--- | :--- |
| `Get-WindowsCapability -Online -Name <feature>` | Check install state of a Windows capability |
| `Add-WindowsCapability -Online -Name <feature>` | Install a Windows capability (requires internet/NAT) |

### RSAT Features

| Capability | Tool |
| :--- | :--- |
| `Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` | AD Users & Computers, Sites, Domains |
| `Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0` | Group Policy Management Console |
| `Rsat.Dns.Tools~~~~0.0.1.0` | DNS Manager |
| `Rsat.FileServices.Tools~~~~0.0.1.0` | File Services Tools |
| `Rsat.ServerManager.Tools~~~~0.0.1.0` | Server Manager |

## Provisioning Scripts

| Script | Stage | Purpose |
| :--- | :--- | :--- |
| `winclient-config.ps1` | — | Shared config file, sourced by all stage scripts |
| `winclient-stage1.ps1` | Stage 1 | Configure DNS, verify DC reachability, join domain, reboot |
| `winclient-stage2.ps1` | Stage 2 | Verify domain membership, install RSAT, register DNS |

> **Note:** Stage 2 must run **after** the reboot triggered by Stage 1. Ensure the NAT adapter is active during Stage 2 for RSAT download.

## Vagrant

| Command | Description |
| :--- | :--- |
| `vagrant up` | Create and provision all VMs |
| `vagrant halt` | Shut down all running VMs |
| `vagrant reload` | Restart VMs and re-apply Vagrantfile changes |
| `vagrant destroy` | Stop and delete all VMs and associated disks |
| `vagrant provision` | Re-run provisioning scripts without recreating the VM |
| `vagrant ssh <vm-name>` | Open an SSH/WinRM shell into a specific VM |
