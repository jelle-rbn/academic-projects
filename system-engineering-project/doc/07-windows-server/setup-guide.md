# Setup guide - Windows Domain Controller

_Author: Johan Magerman - johan.magerman@student.hogent.be_

## Requirements for Starting

* VirtualBox (with Guest Additions installed)
* Vagrant
* Git

## Steps for Deploying the Domain Controller

1. Ensure that Vagrant is correctly installed and that you're running an up-to-date version:

   ```shell
   $ vagrant version
   ```

   You should see something like:

   ```shell
   Installed Version: 2.4.9
   Latest Version: 2.4.9
   ```

2. Using Git, clone and navigate to the repository:

   ```shell
   $ git clone [https://github.com/HoGentTIN/system-engineering-project-25-26-sep2526-t02.git](https://github.com/HoGentTIN/system-engineering-project-25-26-sep2526-t02.git) <destination-directory>
   $ cd <destination-directory>/system-engineering-project-25-26-sep2526-t02/src
   ```

3. Initiate deployment of the Domain Controller:

   ```shell
   $ vagrant up windowsdc
   ```

4. Vagrant will prompt you to select the network adapter type:

   ```
   Select network adapter type:
     1) Bridged  (HoGent)
     2) Internal (Test)

   Enter choice [1/2]:
   ```

   * Choose **1** when working on the HoGent campus network. The VM will be assigned the static IP `192.168.132.194` and bridge onto the physical VLAN.
   * Choose **2** for local testing on your own machine. All VMs are connected to a shared internal network (`t02-localnet`) and use a `/24` mask so they can reach each other without a router.

5. Vagrant will now run three provisioning stages with an automatic reboot between Stage 1 and Stage 2. This process takes approximately **10-20 minutes**. You can follow the progress in the terminal:

   | Stage | What it does |
   |---|---|
   | **copy-provisioning** | Copies scripts from the shared folder (`C:\vagrant-provisioning`) to the local disk (`C:\provisioning`) to avoid race conditions after the DC promotion reboot. |
   | **windowsdc-stage1** | Installs the DNS Server role, adds public DNS forwarders, installs AD-DS and DFS feature binaries, and promotes the server to the primary Forest Domain Controller. Initiates an automatic reboot upon completion. |
   | **windowsdc-stage2** | Waits for Active Directory to come online. Configures forward/reverse DNS lookup zones and environment records. Constructs the full OU hierarchy, creates all user accounts, maps roaming user profile/home paths to an **external storage server**, pre-stages computer accounts, and delegates domain-join rights. |
   | **windowsdc-stage3** | Creates security groups, links Group Policy Objects, and provisions Active Directory Certificate Services (ADCS). Executes an **automated SSL certificate deployment to the Reverse Proxy** over SSH. Applies final network interface metrics, and runs a security cleanup of `C:\provisioning`. |

6. When provisioning completes successfully, you will see the following banner in the terminal:

   ```
     +-------------------------------------------------+
     |                                                 |
     |      Windows DomainController Ready!            |
     |                                                 |
     +-------------------------------------------------+
   ```

7. Connect to the Domain Controller via WinRM:

   ```shell
   $ vagrant winrm windowsdc
   ```

   Or open an interactive RDP session (requires an RDP client):

   ```shell
   $ vagrant rdp windowsdc
   ```

   Default credentials:

   | Field | Value |
   |---|---|
   | Username | `vagrant` |
   | Password | `vagrant` |

---

## What the Domain Controller provides

The Domain Controller is the core of the `ad.t02-domain404.internal` Active Directory forest and provides central infrastructure services.

### Active Directory Domain Services (AD-DS)
All Windows machines join the domain `ad.t02-domain404.internal` (NetBIOS: `DOMAIN404`). The domain features an explicit design for security delegation and automated setup:
* **Machine Account Quota:** Explicitly set to `0`. Standard authenticated domain users cannot join arbitrary machines to the domain.
* **Service Accounts:** Two dedicated administrative service accounts are provisioned:
    * `SVC_DomainJoin`: Authorized exclusively to bind physical machines to pre-staged computer objects in the `_Staging` and `Infrastructure` OUs.
    * `SVC_PKIAdmin`: Built with `Domain Admins` and `Enterprise Admins` group membership to securely handle the automated creation and signing of the enterprise Public Key Infrastructure.

### DNS Services
The DC acts as the primary DNS server for the environment at `192.168.132.194`. It actively maintains the following zones:

| Zone | Type | Purpose / Records |
|---|---|---|
| `ad.t02-domain404.internal` | AD-integrated | Primary forward lookup zone for infrastructure machines. |
| `t02-domain404.internal` | Primary | Public-facing internal web zone. Maps the apex/bare domain, `www`, and `nextcloud` records directly to the Reverse Proxy (`192.168.132.234`). |
| `132.168.192.in-addr.arpa` | AD-integrated | Reverse lookup zone for pointer (PTR) validation. |

> External queries are routed out to Cloudflare (`1.1.1.1`, `1.0.0.1`) and Google (`8.8.8.8`, `8.8.4.4`) public forwarders.

### File Services - Mapped User Storage
User data storage is decoupled from the Domain Controller. It maps environments directly to a central, dedicated Linux storage server (`storage`) using standard SMB/UNC network paths:

| Data Type | UNC Path Destination | Mapped Environment |
|---|---|---|
| **Roaming Profiles** | `\\storage\profiles\%username%` | Applied automatically on user session handshake. |
| **Home Folders** | `\\storage\homefolders\%username%` | Mapped as drive letter `H:` for domain users. |

### Group Policy Objects (GPOs)
The baseline infrastructure enforces the following security boundaries and configurations:

| GPO | Linked Target Scope | Purpose |
|---|---|---|
| `GPO-Baseline-Standard` | `OU=D404` (Domain Root) | Clears legal notices to eliminate logon screen clutter and registers administrative Restricted Groups flags. |
| `GPO-Block-SvcAccount-Logon` | `OU=Computers` | Explicitly denies interactive and Remote Desktop (RDP) logons for all service accounts (`GRP_SVC_All`). |
| `GPO-Staging-Lockdown` | `OU=_Staging` (Computers) | Restricts logons strictly to Domain Admins and shows a mandatory warning legal notice while a computer object resides in the staging container. |
| `GPO-Logon-IT-Workstations` | `OU=IT\Workstations` | Explicitly allows members of `GRP_Logon_IT` to log on interactively. |
| `GPO-Logon-HR-Workstations` | `OU=HR\Workstations` | Explicitly allows members of `GRP_Logon_HR` to log on interactively. |
| `GPO-Logon-Management-Workstations` | `OU=Management\Workstations` | Explicitly allows members of `GRP_Logon_Management` to log on interactively. |
| `GPO-Logon-Development-Workstations` | `OU=Development\Workstations` | Explicitly allows members of `GRP_Logon_Development` to log on interactively. |
| `GPO-Restricted-Users` | `OU=Users` & `OU=Computers` | **New Policy:** Targets restricted environments (e.g., `GLE0301`). Disables the Control Panel, locks down the desktop wallpaper, blocks taskbar adjustments, forces Edge to open to `https://t02-domain404.internal`, and utilizes SAFER guidelines to block execution of `.exe` files out of the user's `Downloads` directory. |

### Public Key Infrastructure (PKI) & Reverse Proxy Automation
During Stage 3, an Enterprise Root Certificate Authority named `DOMAIN404-Root-CA` is provisioned under the `SVC_PKIAdmin` context. 

The script triggers an **automated lifecycle management sequence** for the web reverse proxy:
1. It initiates an SSH handshake with the reverse proxy server (`192.168.132.234`).
2. It commands the proxy to create an internal Certificate Signing Request (CSR) with Subject Alternative Names (`t02-domain404.internal`, `www.t02-domain404.internal`, `nextcloud.t02-domain404.internal`).
3. It securely pulls the CSR to the DC via SCP, signs it against the local CA, and transfers the resulting valid `.cer` certificate back to the proxy.
4. It updates the Nginx configuration references on the proxy and restarts Nginx to bind the certificate.

---

## Troubleshooting Common Issues

### Vagrant times out waiting for WinRM
Vagrant waits up to 20 minutes for a WinRM connection to come up. If the timeout is exceeded, Windows may still be performing updates or booting slowly.

* **Check whether the VM is running in VirtualBox:**
    ```shell
    $ vagrant status windowsdc
    ```
* **Increase the WinRM retry limit in the Vagrantfile if the machine is slow to start:**
    ```ruby
    node.winrm.retry_limit = 180
    node.vm.boot_timeout   = 1800
    ```
* **Check the VirtualBox console** to see whether Windows is waiting on a user prompt, completing a stage reboot, or displaying a recovery screen.

---

### Stage 2 fails - AD does not become available within the timeout
After DC promotion the server reboots. Stage 2 polls for Active Directory availability for up to 5 minutes. If the VM is resource-constrained, the service might take longer to initialize.

* **Rerun stage 2 once the VM has fully booted:**
    ```shell
    $ vagrant provision windowsdc --provision-with windowsdc-stage2
    ```
* **Verify that the NTDS service is running inside the VM:**
    ```powershell
    PS> Get-Service NTDS | Select-Object Name, Status
    ```

---

### Mapped user profiles or home folders are not accessible after login
Because storage configurations are hosted on an external server, check the environment mapping values:

* **Verify network path reachability to the external storage node:**
    ```powershell
    PS> Test-NetConnection -ComputerName storage -Port 445
    ```
* **Verify the user's Active Directory target path configurations:**
    ```powershell
    PS> Get-ADUser -Identity 'JMA8601' -Properties ProfilePath, HomeDrive, HomeDirectory | Format-List ProfilePath, HomeDrive, HomeDirectory
    ```
* **Verify group membership assignment:** The user must be a member of `GRP_Storage_Users` to gain home folder assignments on the remote storage node.

---

### Reverse Proxy certificate automation skipped or failed
If the script outputs a warning stating `Notice: Reverse Proxy is not reachable. Skipping certificate automation.`, the reverse proxy machine was not online or accessible over SSH when Stage 3 executed.

* **Manual Remediation:** If the proxy comes online later, you can manually execute the standalone certificate configuration backup script located within your provisioning directory:
    ```powershell
    PS> . "C:\vagrant-provisioning\files\windowsdc\certificateassignment.ps1"
    ```
* **Verify SSH Access Connectivity:** Ensure that public-key authorization or the local configuration assets path defined by `$ProxyCertKeySource` matches correctly in `win-data.psd1`.

---

### Domain join from client fails
If the Windows client (`winclient`) cannot join the domain, verify these steps:

* **From the client, verify DNS resolution points correctly to the DC:**
    ```powershell
    PS> Resolve-DnsName ad.t02-domain404.internal
    ```
* **Verify TCP connectivity to the DC on the LDAP port:**
    ```powershell
    PS> Test-NetConnection -ComputerName 192.168.132.194 -Port 389
    ```
* **Verify the pre-staged computer account exists inside the Staging container:**
    ```powershell
    PS> Get-ADComputer -Identity 'L-26-00001'
    ```
* **Verify the SVC_DomainJoin account status:**
    ```powershell
    PS> Get-ADUser -Identity 'SVC_DomainJoin' | Select-Object Enabled, LockedOut
    ```

---

## Remarks

* The `win-data.psd1` file acts as the configuration single-source-of-truth and must be treated as a secrets file.
* Computer accounts are pre-staged in `OU=_Staging` by default. They must be **manually moved** to their designated departmental workstation OUs (e.g., `OU=IT,OU=Workstations...`) after a machine has been verified. The `GPO-Staging-Lockdown` policy actively restricts standard user logons on that machine until it has been safely migrated out of the staging OU.