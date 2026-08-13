# Setup guide - Windows 10 client

Author(s): D. Cooreman - `dean.cooreman@student.hogent.be`

This guide describes the step-by-step procedure to manually provision the Windows 10 client virtual machine, join it to the Active Directory domain, install required tools (RSAT, Nextcloud, Thunderbird), and configure Nextcloud and CalDAV synchronization.

## Prerequisites

Ensure the following VMs are already running before you start:

- `windowsdc` - Active Directory domain controller
- `nextcloud-database` - Database backend for Nextcloud
- `nextcloud-server` - Nextcloud instance  
- `reverse-proxy` - Reverse proxy for web access

Also ensure:
- Oracle VirtualBox is installed on your host machine
- Vagrant is installed on your host machine
- You have administrator access on the host to manage VMs

## Provisioning workflow

The Windows client is provisioned manually in seven phases. Each phase must complete before moving to the next. Phases 3-5 include automatic reboots triggered by the provisioning scripts.

### Phase 0 - Verify prerequisites

Before starting provisioning, confirm all required VMs are running:

```bash
vagrant status windowsdc
vagrant status storage
```

All should show as `running`.

### Phase 1 - Boot the base VM

Boot the Windows 10 base box without provisioning:

```bash
vagrant up winclient
```

When prompted, select **Internal (Test)** as the network type. The VM boots with no configuration applied.

### Phase 2 - Copy provisioning scripts into the VM

1. In VirtualBox, select `t02_winclient` and click **Show** to access the VM console.
2. Log in with credentials: `vagrant` / `vagrant`
3. Open **PowerShell as Administrator** (right-click PowerShell → Run as Administrator)
4. Map the shared folder and copy the provisioning scripts into the VM:

```powershell
net use Z: \\VBOXSVR\C:_provisioning
New-Item -ItemType Directory -Path C:\provisioning -Force
Copy-Item Z:\* C:\provisioning\ -Recurse -Force -ErrorAction SilentlyContinue
```

This creates `C:\provisioning\` on the VM and copies all provisioning scripts from the host.

### Phase 3 - Stage 1 (keyboard, network, hostname)

In the PowerShell session, run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\provisioning\winclient-stage1.ps1
```

This script:
- Sets keyboard layout and system locale  
- Configures the network adapter (IP, DNS)  
- Sets the hostname to `winclient`  

The VM automatically reboots when complete. **Do not interrupt this reboot.**

### Phase 4 - Stage 2 (domain join)

After the reboot, log in again as `vagrant` / `vagrant` and open **PowerShell as Administrator**:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\provisioning\winclient-stage2.ps1
```

This script joins the Windows client to the `DOMAIN404` Active Directory domain.

The VM automatically reboots when complete. **Do not interrupt this reboot.**

### Phase 5 - Stage 3 (RSAT, software, network fix)

After the reboot, log in again and open **PowerShell as Administrator**:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\provisioning\winclient-stage3.ps1
```

This script:
- Installs RSAT (Remote Server Administration Tools) from Windows Update  
- Installs Nextcloud Desktop client via Chocolatey  
- Installs Thunderbird email/calendar client via Chocolatey  
- Applies a network fix to ensure proper connectivity  

Installation takes several minutes. When complete, the console displays:

```
    Windows 10 client -- Ready!
```

**No reboot is needed after this phase.**

### Phase 6 - Configure Nextcloud

1. Open **Nextcloud Desktop** from the Start menu
2. Click **Log in** and enter the Nextcloud server URL: `https://nextcloud.t02-domain404.internal`
3. Log in using your domain account (e.g., `DOMAIN404\vagrant` with password `vagrant`)
4. Choose a local folder to sync with (e.g., `C:\Users\<username>\Nextcloud`)
5. Click **Connect**

**Verify:** Drop a file into `C:\Users\<username>\Nextcloud\` and confirm it appears in the Nextcloud web interface.

### Phase 7 - Configure Thunderbird Calendar

#### 7.1 - Create a calendar in Nextcloud

1. Open a web browser and navigate to `https://nextcloud.t02-domain404.internal`
2. Log in with your domain account
3. Click **Calendar** in the left sidebar (or top menu)
4. Click **+ New calendar** and give it a name (e.g., "Personal")
5. Click the three-dot menu on the calendar → **Copy link** to retrieve the CalDAV URL

#### 7.2 - Add the calendar to Thunderbird

1. Open **Thunderbird** and click the **Calendar** tab
2. Right-click in the calendar list → **New Calendar** → **On the Network** → **CalDAV**
3. Paste the CalDAV URL you copied from Nextcloud
4. Enter your domain credentials when prompted
5. Click **OK**

**Verify:** Create an event in Nextcloud Calendar and confirm it appears in Thunderbird. Create an event in Thunderbird and verify it syncs back to Nextcloud.

## Troubleshooting

| Problem | Possible solution |
| :--- | :--- |
| VM fails to boot | Ensure sufficient disk space and RAM available on the host. Check VirtualBox logs for hardware compatibility issues. |
| Cannot copy scripts (Phase 2) | Verify the shared folder is enabled in VirtualBox VM settings. Ensure the provisioning scripts exist in `C:_provisioning` on the host. |
| Stage scripts fail to run | Ensure you are running PowerShell **as Administrator**. Check that the execution policy bypass worked: `Get-ExecutionPolicy`. |
| Domain join fails (Phase 4) | Verify the domain controller VM is running. Confirm DNS resolves `ad.t02-domain404.local`. Try `Resolve-DnsName ad.t02-domain404.local` in PowerShell. Check network connectivity to the DC at `192.168.132.194`. |
| RSAT installation fails (Phase 5) | Ensure the VM has internet connectivity on the NAT adapter. Check Windows Update service is running. Retry the stage script. |
| Nextcloud login fails (Phase 6) | Verify the Nextcloud server URL is correct and accessible from the VM (test with `ping` or a browser). Confirm your domain account exists in Active Directory. |
| CalDAV calendar won’t sync (Phase 7) | Verify the CalDAV URL is correct. Confirm Thunderbird has internet access. Check that your domain account has read/write permissions on the Nextcloud calendar. Try re-entering your credentials. |

