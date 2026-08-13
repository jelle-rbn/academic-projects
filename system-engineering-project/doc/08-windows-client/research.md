# Research

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

This document outlines the preliminary research to deploy and configure the windows 11 client.

## Sources

| Source | Description |
| :--- | :--- |
| [Vagrant boxes catalog](https://portal.cloud.hashicorp.com/vagrant/discover) | The official vagrant boxes catalog of Hashicorp. |
| [Vagrant developer documentation](https://developer.hashicorp.com/vagrant/docs/providers/virtualbox/configuration) | Information on how to setup a GUI for a Vagrant box. |
| [Add-computer](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/add-computer?view=powershell-5.1) | Official Powershell documentation on how to add a computer to a domain. |
| [Set-DnsClientServerAddress](https://learn.microsoft.com/en-us/powershell/module/dnsclient/set-dnsclientserveraddress?view=windowsserver2025-ps) | Official Powershell documentation on DNS configuration. |
| [Resolve-DnsName](https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname?view=windowsserver2025-ps) | Official Powershell documentation on DNS name query resolution. |
| [Add-WindowsCapability](https://learn.microsoft.com/en-us/powershell/module/dism/add-windowscapability?view=windowsserver2025-ps) | Official Powershell documentation on how to install capability packages. |
| [Get-WindowsCapability](https://learn.microsoft.com/en-us/powershell/module/dism/get-windowscapability?view=windowsserver2025-ps) | Official Powershell documentation to check if a capability is already installed on the system. |
| [RSAT](https://www.pdq.com/blog/how-to-install-remote-server-administration-tools-rsat/) | Tutorial on how to install RSAT tools, including a list of all RSAT tools by name. |
| [Get-CimInstance Win32_ComputerSystem](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-computersystem) | Official Microsoft documentation on the Win32_ComputerSystem WMI class used to query domain membership and computer role. |
| [Test-Connection](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-connection?view=powershell-7.4) | Official Powershell documentation on how to test network connectivity to a remote host. |
| [Test-NetConnection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection) | Official Powershell documentation on how to test TCP port connectivity to a remote host. |
| [Get-NetAdapter](https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapter) | Official Powershell documentation on how to retrieve network adapter properties. |
| [Joining a computer to a domain](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/join-computer-to-domain) | Official Microsoft documentation on joining a Windows machine to an Active Directory domain. |
| [Vagrant multi-machine](https://developer.hashicorp.com/vagrant/docs/multi-machine) | Official Vagrant documentation on defining and managing multiple VMs in a single Vagrantfile. |
