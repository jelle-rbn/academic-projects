# Requirements

Author(s): G. Lescur - `guillaume.lescur@student.hogent.be`

This document specifies the requirements and technical procedures for the automated deployment of the Extended GPOs. The setup is designed to be reproducible using Vagrant and integrated bash provisioning scripts.

## Host Requirements

The software can run on a host using Microsoft Windows, any Linux distribution, or macOS.

| Software | Description |
| :--- | :--- |
| [Oracle Virtualbox](https://www.virtualbox.org/) | Virtualisation software used to run the virtual machines |
| [Vagrant](https://developer.hashicorp.com/vagrant) | Command line utility for managing the lifecycle of virtual machines, isolate dependencies and their configuration within a single disposable and consistent environment. |

## Deliverables

- **Configuration panel:** The user has no access to the configuration panel
- **Background:** The background of the user is an even color and not changable
- **Taskbar:** Changes to the taskbar are not allowed
- **Exe:** .exe files can not be run in the downloads folder
- **Edge:** The default page of edge shows `https://t02-domain404.internal`

## Subtasks

1. Research
  - Person in charge of implementation: G. Lescur
  - Person in charge of testing: N/A
  - Dependancies: N/A

2. Implementation
  - Person in charge of implementation: G. Lescur
  - Person in charge of testing: N/A
  - Dependancies: Subtask 1

3. Testing
  - Person in charge of implementation: G. Lescur
  - Person in charge of testing: N/A
  - Dependancies: Subtask 2

4. Documentation
  - Person in charge of implementation: G. Lescur
  - Person in charge of testing: N/A
  - Dependancies: Subtask 3

## Technical Specifications

| Component | Requirement / Value |
| :--- | :--- |
| **OS** | Windows Server 2022 Standard Core (`gusztavvargadr/windows-server-2022-standard-core`) |
| **IP Address** | `192.168.132.194` |
| **Netmask** | `255.255.255.224` |
| **Memory** | 2048 MB |
| **CPUs** | 2 |
| **Network** | Bridged adapter (VLAN 33) |
| **Domain FQDN** | `ad.t02-domain404.local` |
| **NetBIOS Name** | `DOMAIN404` |
| **Forest / Domain Mode** | Windows Server 2022 functional level |
| **DSRM Password** | Defined in `windowsdc-config.ps1` |
| **DNS Forwarders** | `1.1.1.1`, `1.0.0.1`, `8.8.8.8`, `8.8.4.4` |
| **Forward Lookup Zone** | `ad.t02-domain404.local` |
| **Reverse Lookup Zone** | Derived from DC IP (AD-integrated, secure dynamic updates) |
| **Provisioning** | Staged: `windowsdc-stage1.ps1` > reboot > `windowsdc-stage2.ps1` |
| **Config file** | `windowsdc-config.ps1` (shared across all staging scripts) |

| Component                        | Requirement / Value                          |
| :------------------------------- | :------------------------------------------- |
| **Active Directory Domain**      | `ad.t02-domain404.local`                     |
| **Organizational Units (OUs)**   | `OU=Users`, `OU=Workstations`, `OU=Servers`  |
| **Group Policy Objects (GPOs)**  | Password Policy, RDP Policy, Drive Mapping   |
| **GPO Linking**                  | Domain level or specific OU                  |
| **Security Filtering**           | `Authenticated Users`, `DOMAIN404\IT-Admins` |
| **WMI Filters (optional)**       | Only Windows 10 clients                      |
| **Group Policy Management Tool** | `gpmc.msc`                                   |
| **Client Systems**               | Windows 10 client, Windows Server 2022       |
| **Domain Controller**            | `windowsdc`                                  |
| **Replication Scope**            | All Domain Controllers                       |
| **DNS Resolution**               | Correct AD DNS (DC IP address)               |

## Time Spent

| Student | (Sub)task                      | Estimated effort | Actual effort |
| :---- | :------------------------------- | ---------------: | ------------: |
| Guillaume | Research                         |           4h 00m |       1h 30m |
| Guillaume | Implementation                   |           8h 00m |       7h 40m |
| Guillaume | Testing                          |           8h 00m |       9h 00m |
| Guillaume | Documentation                    |           4h 00m |       5h 30m |
| Guillaume | Test plan                        |           2h 00m |       2h 15m |
| Guillaume | Bugs                             |           1h 00m |       0h 45m |
| Guillaume | Testing and test report          |              h m |          h m |
| **Total** |                                  |       **27h 00m**|   **26h 40m**|

**Variance remarks**

None
