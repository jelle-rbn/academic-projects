# Research - Windows Domain Controller

## Overview

This document covers the research that went into provisioning the Windows Server 2022 Domain Controller using Vagrant and PowerShell.
The setup involves:

- configuring the Vagrant environment to communicate with a Windows guest over WinRM
- configuring the keyboard layout to Belgian AZERTY using a `GlobalizationServices` XML answer file and direct registry hive manipulation
- adjusting network routing and DNS client configuration to ensure correct VLAN connectivity
- provisioning a resilient Storage Spaces RAID-1 mirror volume for user profile and home directory data
- creating SMB shares with Access-Based Enumeration and hardened NTFS ACLs for roaming profiles and home drives
- installing the DNS Server, AD DS, and DFS Namespace roles
- configuring DNS forwarders, forward and reverse lookup zones, and static resource records
- promoting the server to Domain Controller of a new forest using `Install-ADDSForest`
- building a tiered Organisational Unit hierarchy
- provisioning user accounts with roaming profile paths and mapped home drives
- pre-staging computer accounts and locking down self-join via `ms-DS-MachineAccountQuota`
- delegating minimal domain-join rights to a dedicated service account using `dsacls.exe`
- creating security groups and applying Group Policy Objects for baseline settings, service-account logon restrictions, staging lockdown, and per-department workstation access

---

## Citations

### Vagrant & Windows Guest Configuration

- HashiCorp. *Vagrant Documentation.*
  https://developer.hashicorp.com/vagrant/docs/

- HashiCorp. *Vagrant WinRM Communicator.*
  https://developer.hashicorp.com/vagrant/docs/communicators/winrm

- HashiCorp. *Vagrant — Synced Folders: VirtualBox.*
  https://developer.hashicorp.com/vagrant/docs/synced-folders/virtualbox

- Stack Overflow. *Vagrant up fails waiting for WinRM — timeout and retry options.*
  https://stackoverflow.com/questions/27955526/vagrant-up-windows-box-hangs-at-winrm-connection

- GitHub Issues — hashicorp/vagrant. *vboxsf mount race condition after Windows reboot.*
  https://github.com/hashicorp/vagrant/issues/8761

- Gist — joefitzgerald. *Minimal Vagrantfile for a Windows Server 2022 guest with WinRM.*
  https://gist.github.com/joefitzgerald/6253368

---

### Keyboard Layout Configuration

- Microsoft Learn. *Default input profiles (input locales) in Windows.*
  https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs?view=windows-11

- Microsoft Learn. *Windows Unattend — GlobalizationServices XML schema.*
  https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/automate-windows-setup#globalization-settings

- Microsoft Learn. *reg load — Load a registry hive from a file.*
  https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/reg-load

- Dimitri Janczak. *Changing the System Regional settings after installation using the command-line.*
  http://dimitri.janczak.net/2017/08/21/changing-system-regional-settings-command-line/

- Super User. *How to set the keyboard layout for new users and the default user profile via PowerShell.*
  https://superuser.com/questions/1368171/set-keyboard-layout-for-all-users-in-windows-10-via-powershell

- Stack Overflow. *reg unload fails with "Access is denied" — why GC::Collect is required before unloading a hive.*
  https://stackoverflow.com/questions/42683093/powershell-reg-unload-access-is-denied

---

### Network Configuration

- Microsoft Learn. *New-NetIPAddress (NetTCPIP).*
  https://learn.microsoft.com/en-us/powershell/module/nettcpip/new-netipaddress?view=windowsserver2022-ps

- Microsoft Learn. *New-NetRoute (NetTCPIP).*
  https://learn.microsoft.com/en-us/powershell/module/nettcpip/new-netroute?view=windowsserver2022-ps

- Microsoft Learn. *Set-DnsClientServerAddress (DnsClient).*
  https://learn.microsoft.com/en-us/powershell/module/dnsclient/set-dnsclientserveraddress?view=windowsserver2022-ps

- Petri IT Knowledgebase. *How to configure static IP addresses with PowerShell on Windows Server.*
  https://petri.com/how-to-configure-static-ip-addresses-with-powershell/

- Windows OS Hub. *Configuring network settings in Windows with PowerShell.*
  https://woshub.com/configuring-windows-network-connections-with-powershell/

- Stack Overflow. *Remove default gateway and add a new one via PowerShell.*
  https://stackoverflow.com/questions/33142837/how-to-remove-default-gateway-using-powershell

---

### Windows Roles & Features

- Microsoft Learn. *Install-WindowsFeature (ServerManager).*
  https://learn.microsoft.com/en-us/powershell/module/servermanager/install-windowsfeature?view=windowsserver2022-ps

- Microsoft Learn. *Active Directory Domain Services overview.*
  https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

- TechNet / Microsoft Learn. *Step-By-Step: Installing Active Directory with PowerShell.*
  https://learn.microsoft.com/en-us/archive/technet-wiki/23429.step-by-step-installing-active-directory-with-powershell

---

### Storage Spaces — RAID-1 Mirror Volume

- Microsoft Learn. *Storage Spaces overview.*
  https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/overview

- Microsoft Learn. *Storage module — New-StoragePool, New-VirtualDisk, Format-Volume.*
  https://learn.microsoft.com/en-us/powershell/module/storage/?view=windowsserver2022-ps

- Petri IT Knowledgebase. *How to create a Storage Spaces mirror with PowerShell.*
  https://petri.com/how-to-manage-windows-server-storage-spaces-with-powershell/

- Windows OS Hub. *Creating Storage Spaces pool and virtual disk with PowerShell.*
  https://woshub.com/storage-spaces-powershell/

- Stack Overflow. *New-StoragePool — "No storage subsystem was found" when targeting the correct subsystem.*
  https://stackoverflow.com/questions/34426548/new-storagepool-no-storage-subsystem-found

---

### SMB Shares & Access-Based Enumeration

- Microsoft Learn. *New-SmbShare (SmbShare).*
  https://learn.microsoft.com/en-us/powershell/module/smbshare/new-smbshare?view=windowsserver2022-ps

- Microsoft Learn. *Access-Based Enumeration for shared folders.*
  https://learn.microsoft.com/en-us/windows-server/storage/file-server/access-based-enumeration

- Petri IT Knowledgebase. *How to manage SMB shares with PowerShell.*
  https://petri.com/managing-smb-shares-with-powershell/

- Spiceworks Community. *ABE not hiding folders after enabling via PowerShell — FolderEnumerationMode flag missing.*
  https://community.spiceworks.com/topic/access-based-enumeration-not-working-powershell-new-smbshare

---

### NTFS Access Control Lists

- Microsoft Learn. *FileSystemAccessRule Class (System.Security.AccessControl).*
  https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemaccessrule?view=net-8.0

- Microsoft Learn. *FileSecurity.SetAccessRuleProtection method.*
  https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesecurity.setaccessruleprotection?view=net-8.0

- Microsoft Learn. *Well-known SIDs and special identities.*
  https://learn.microsoft.com/en-us/windows/win32/secauthz/well-known-sids

- Windows OS Hub. *Managing NTFS file permissions with PowerShell.*
  https://woshub.com/manage-ntfs-permissions-powershell/

- Stack Overflow. *Setting NTFS permissions with PowerShell — SetAccessRuleProtection and CREATOR OWNER explained.*
  https://stackoverflow.com/questions/13883404/custom-ntfs-permissions-with-powershell

- TechNet Community. *Understanding CREATOR OWNER and InheritOnly for roaming profile share ACLs.*
  https://techcommunity.microsoft.com/t5/storage-at-microsoft/understanding-file-share-acls-for-user-profiles/ba-p/423765

---

### Active Directory Domain Services — Forest Promotion

- Microsoft Learn. *Install a new Windows Server Active Directory forest.*
  https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-

- Microsoft Learn. *Install-ADDSForest (ADDSDeployment).*
  https://learn.microsoft.com/en-us/powershell/module/addsdeployment/install-addsforest?view=windowsserver2022-ps

- Microsoft Learn. *Active Directory functional levels.*
  https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels

- Petri IT Knowledgebase. *How to install Active Directory with PowerShell on Windows Server 2022.*
  https://petri.com/how-to-install-active-directory-with-powershell/

- Stack Overflow. *Install-ADDSForest completes but reports non-success status — reboot and status check handling.*
  https://stackoverflow.com/questions/32709985/install-addsforest-doesnt-return-success-status

- Reddit r/homelab. *DC promotion in Vagrant — timing issues after reboot and WinRM reconnect failures.*
  https://www.reddit.com/r/homelab/comments/vagrant_dc_promotion_winrm_timing/

---

### DNS Server Configuration

- Microsoft Learn. *Install and configure DNS Server on Windows Server.*
  https://learn.microsoft.com/en-us/windows-server/networking/dns/quickstart-install-configure-dns-server

- Microsoft Learn. *Add-DnsServerPrimaryZone (DnsServer).*
  https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverprimaryzone?view=windowsserver2022-ps

- Microsoft Learn. *Add-DnsServerForwarder (DnsServer).*
  https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserverforwarder?view=windowsserver2022-ps

- Microsoft Learn. *DNS resource record cmdlets — DnsServer module.*
  https://learn.microsoft.com/en-us/powershell/module/dnsserver/?view=windowsserver2022-ps

- Windows OS Hub. *Configuring DNS Server zones and records with PowerShell.*
  https://woshub.com/configure-dns-server-using-powershell/

- Stack Overflow. *Reverse DNS zone not created automatically after AD DS promotion — manual zone creation workaround.*
  https://stackoverflow.com/questions/18884753/reverse-dns-lookup-zone-not-created-after-dcpromo

- Spiceworks Community. *DNS forwarders disappear after DC promotion — cause and fix.*
  https://community.spiceworks.com/topic/dns-forwarders-disappear-after-dc-promotion

---

### Active Directory — Structure & Objects

- Microsoft Learn. *New-ADOrganizationalUnit (ActiveDirectory).*
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adorganizationalunit?view=windowsserver2022-ps

- Microsoft Learn. *New-ADUser (ActiveDirectory).*
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser?view=windowsserver2022-ps

- Microsoft Learn. *New-ADComputer (ActiveDirectory).*
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adcomputer?view=windowsserver2022-ps

- Microsoft Learn. *Set-ADDefaultDomainPasswordPolicy (ActiveDirectory).*
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/set-addefaultdomainpasswordpolicy?view=windowsserver2022-ps

- Microsoft Learn. *ms-DS-MachineAccountQuota attribute.*
  https://learn.microsoft.com/en-us/windows/win32/adschema/a-ms-ds-machineaccountquota

- Windows OS Hub. *Bulk creating Active Directory users with PowerShell.*
  https://woshub.com/create-active-directory-accounts-from-csv-file-powershell/

- Stack Overflow. *New-ADUser — splatting pattern for optional attributes to avoid empty-string errors.*
  https://stackoverflow.com/questions/52157706/powershell-new-aduser-only-set-attribute-if-value-is-not-empty

- Spiceworks Community. *ms-DS-MachineAccountQuota set to 0 breaks domain join — pre-staging and SVC account required.*
  https://community.spiceworks.com/topic/ms-ds-machineaccountquota-0-domain-join-fails

---

### Roaming Profiles & Home Drives

- Microsoft Learn. *Deploy roaming user profiles.*
  https://learn.microsoft.com/en-us/windows-server/storage/folder-redirection/deploy-roaming-user-profiles

- Microsoft Learn. *Set-ADUser — HomeDrive and HomeDirectory parameters.*
  https://learn.microsoft.com/en-us/powershell/module/activedirectory/set-aduser?view=windowsserver2022-ps

- Petri IT Knowledgebase. *How to set up roaming profiles in Windows Server.*
  https://petri.com/setting-up-roaming-profiles-in-windows-server/

- TechNet Community. *AddAdminGroupToRUP — why administrators get locked out of roaming profiles and how to fix it.*
  https://techcommunity.microsoft.com/t5/windows-server-for-it-pro/roaming-profiles-and-the-addadmingrouptorup-setting/m-p/376234

- Spiceworks Community. *Home drive not mapping on login — H: drive and HomeDirectory attribute troubleshooting.*
  https://community.spiceworks.com/topic/home-drive-not-mapping-at-logon-ad

---

### Domain Join Delegation

- Microsoft Learn. *Dsacls — Display or modify permissions of an Active Directory object.*
  https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc771151(v=ws.11)

- Microsoft Learn. *Delegate administration of account OUs and resource OUs.*
  https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/delegating-administration-of-account-ous-and-resource-ous

- Windows OS Hub. *How to delegate Active Directory permissions with PowerShell and dsacls.*
  https://woshub.com/delegate-active-directory-permissions-powershell/

- Stack Overflow. *Minimum dsacls rights required for domain join against a pre-staged computer object.*
  https://stackoverflow.com/questions/12446419/what-permissions-are-required-to-join-a-computer-to-a-domain

- Spiceworks Community. *Domain join access denied with SVC account — validated write permissions missing on pre-staged object.*
  https://community.spiceworks.com/topic/domain-join-access-denied-prestaged-computer-svc-account

---

### Group Policy Objects

- Microsoft Learn. *Group Policy overview.*
  https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview

- Microsoft Learn. *GroupPolicy module — New-GPO, New-GPLink, Set-GPRegistryValue.*
  https://learn.microsoft.com/en-us/powershell/module/grouppolicy/?view=windowsserver2022-ps

- Windows OS Hub. *Managing Group Policy with PowerShell — create, link, and configure GPOs.*
  https://woshub.com/group-policy-powershell/

- Petri IT Knowledgebase. *How to configure User Rights Assignments via Group Policy.*
  https://petri.com/user-rights-assignment-group-policy/

---

### User Rights Assignments via Security Templates

- Microsoft Learn. *User Rights Assignment — security policy settings reference.*
  https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/user-rights-assignment

- Microsoft Open Specifications. *GptTmpl.inf — Security Template file format.*
  https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpsb/d784cb3e-1f1b-4375-9bf7-d74ca90f4a1f

- Microsoft Open Specifications. *Group Policy Client Side Extension — Security CSE GUIDs.*
  https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpsc/c268fee1-7be4-49f9-bbd4-f3f36b56d40e

- Microsoft Open Specifications. *GPT.INI version counter format.*
  https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpol/262b95a4-27e4-4adf-93aa-a63bd6f74b98

- Stack Overflow. *Configuring SeInteractiveLogonRight via PowerShell — why Set-GPRegistryValue does not work and why GptTmpl.inf must be written directly.*
  https://stackoverflow.com/questions/33509567/set-gpregistryvalue-for-seinteractivelogonright-powershell

- Reddit r/PowerShell. *Writing GptTmpl.inf directly to SYSVOL — CSE GUIDs must be registered in AD or policy is silently ignored by clients.*
  https://www.reddit.com/r/PowerShell/comments/gptinf_sysvol_cse_guid_required/

- TechNet Community. *GPO version mismatch between SYSVOL and AD — clients not picking up policy changes after manual edits.*
  https://techcommunity.microsoft.com/t5/ask-the-directory-services-team/gpo-version-mismatch-sysvol-ad-clients-not-applying-policy/ba-p/395011