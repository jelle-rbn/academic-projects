# Requirements Document - Windows Domain Controller

## Deliverables

- **DNS Server Role Installation:** The DNS Server Windows feature must be installed with management tools, set to automatic startup, and running.
- **DNS Forwarder Configuration:** External DNS forwarders must be configured (Cloudflare and Google public resolvers) to handle queries outside the local domain.
- **Active Directory Domain Services (ADDS) Role:** The `AD-Domain-Services`, `RSAT-ADDS`, and `RSAT-AD-PowerShell` features must be installed with management tools.
- **Domain Controller Promotion:** The server must be promoted to a Domain Controller by creating a new Active Directory forest using the configured domain name and forest/domain functional level.
- **Post-Reboot AD Configuration:** After the DC promotion reboot, the server must wait for AD availability and then complete DNS and AD post-configuration.
- **DNS Zone Configuration:** A forward lookup zone and a reverse lookup zone must exist and be correctly configured. The DC must point to itself (`127.0.0.1`) as its primary DNS server.
- **DNS A and PTR Records:** An A record and a corresponding PTR record for the Domain Controller must be registered in the appropriate DNS zones.
- **Organisational Unit Structure:** Organisational Units (OUs) defined in the configuration file must be created in the Active Directory domain.
- **Domain Users:** Admin and standard domain users are to be created.

## Subtasks

1. Gather information and resources
   - Person in charge of implementation: Johan
   - Person in charge of testing: N/A
   - Dependencies: N/A

2. Provisioning - DNS installation and configuration, ADDS installation and configuration, and DC promotion (`windowsdc-stage1.ps1`)
   - Person in charge of implementation: Johan
   - Person in charge of testing: N/A
   - Dependencies: Subtask 1

3. Domain user and OU creation
   - Person in charge of implementation: Johan
   - Person in charge of testing: N/A
   - Dependencies: Subtask 2

4. Technical documentation
   - Person in charge of implementation: Johan
   - Person in charge of testing: N/A
   - Dependencies: Subtasks 1–3

5. Test plan / functional validation
   - Person in charge of implementation: Johan
   - Person in charge of testing: <!-- Name -->
   - Dependencies: All subtasks

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

## Time Spent

| Student | (Sub)task                      | Estimated effort | Actual effort |
| :---- | :------------------------------- | ---------------: | ------------: |
| Johan | Gather information and resources |           2h 00m |        4h 00m |
| Johan | Provisioning                     |           2h 30m |       16h 30m |
| Johan | Domain users and OUs             |           1h 00m |          0h m |
| Johan | Technical documentation          |           1h 00m |        1h 00m |
| Johan | Test plan v1                     |           1h 00m |        1h 30m |
| Johan | Testing and test report v1       |              h m |           h m |
| **Total** |                              |       **8h 00m** |       **h m** |

**Variance remarks**

_Gather information and resources:_
Switched from using a powershell script to create and configure the server to provisioning with vagrant.
So had to research both and for vagrant had to look into multi-stage provisioning since server requires a reboot to finish the promotion to domaincontroller after which there is still some configuration left to do.

_Provisioning:_
Again, switched from using powershell script to vagrant (multi-stage) provisioning. Powershell script was already prepared when we decided to switch, so this took some extra time.
Getting the configuration and procedure / proces correct for the multi-stage provisioning also took me a lot longer then expected. Took several different approaches along the way, discovering new possibilities to improve the scripts.
Testing out changes to the multi stage provisioning scripts is very time consuming since I had to wait 10 to 15 minutes every time before result was visible and I could continue to work from the new results.

_Technical documentation:_
This was just way more work then I had anticipated.