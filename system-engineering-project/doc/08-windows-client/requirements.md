# Requirements

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

This document specifies the requirements and technical procedures for the
automated deployment of a Windows 11 client virtual machine. The setup is
designed to be reproducible using Vagrant and integrated PowerShell
provisioning scripts.

## Host Requirements

The software can run on a host using Microsoft Windows, any Linux
distribution, or macOS.

| Software | Description |
| :--- | :--- |
| [Oracle Virtualbox](https://www.virtualbox.org/) | Virtualisation software used to run the virtual machines |
| [Vagrant](https://developer.hashicorp.com/vagrant) | Command line utility for managing the lifecycle of virtual machines, isolate dependencies and their configuration within a single disposable and consistent environment. |

## Deliverables

- **DNS Configuration:** The client must use the domain controller
  (`192.168.132.194`) as its primary DNS server to resolve the domain
  `ad.t02-domain404.local`.
- **Domain Join:** The client must be automatically joined to the Active
  Directory domain `ad.t02-domain404.local` (NetBIOS: `DOMAIN404`).
- **RSAT Installation:** Remote Server Administration Tools must be installed
  to allow management of the domain from the client.
- **DNS Registration:** The client must register its DNS records with the
  domain controller after joining the domain.

## Subtasks

1. Gather information and resources
   - Person in charge of implementation: D. Cooreman
   - Person in charge of testing: N/A
   - Dependencies: N/A

2. DNS configuration
   - Person in charge of implementation: D. Cooreman
   - Person in charge of testing: N/A
   - Dependencies: Subtask 1

3. Domain join
   - Person in charge of implementation: D. Cooreman
   - Person in charge of testing: N/A
   - Dependencies: Subtask 2

4. RSAT installation and DNS registration
   - Person in charge of implementation: D. Cooreman
   - Person in charge of testing: N/A
   - Dependencies: Subtask 3

5. Technical documentation
   - Person in charge of implementation: D. Cooreman
   - Person in charge of testing: N/A
   - Dependencies: Subtasks 1, 2, 3 and 4

6. Test plan / functional validation
   - Person in charge of implementation: D. Cooreman
   - Person in charge of testing: N/A
   - Dependencies: All subtasks

## Technical Specifications

| Component | Requirement / Value |
| :--- | :--- |
| OS | Windows 10 (`gusztavvargadr/windows-10`) |
| IP Address | DHCP (range `192.168.132.130` – `192.168.132.190`, VLAN 22) |
| Hostname | `winclient` |
| Domain | `ad.t02-domain404.local` |
| NetBIOS Name | `DOMAIN404` |
| Domain Controller | `windowsdc` (`192.168.132.194`) |
| Primary DNS | `192.168.132.194` (DC), fallback `1.1.1.1`, `8.8.8.8` |
| Memory | 4096 MB |
| CPUs | 2 |
| RSAT Features | AD DS Tools, Group Policy Management, DNS Tools, File Services Tools, Server Manager |

## Time Spent

| Student | Estimated Effort | Actual effort | Variance remarks |
| :--- | :--- | :--- | :--- |
| D. Cooreman | 10h0m | 19h20m | I've spent a lot of time figuring out how to make the provisioning faster. |

![time spent](./img/time.png)

