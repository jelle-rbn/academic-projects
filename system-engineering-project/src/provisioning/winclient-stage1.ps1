# -----------------------------------------------------------------------------
# winclient-stage1.ps1  --  Initial Client System Configuration
# -----------------------------------------------------------------------------
# Performs initial bootstrapping for the client machine, including keyboard
# layout, fallback static IP assignment (if DHCP fails), DC host route and
# hostname setup.
#
# USAGE (run as Administrator):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   C:\provisioning\winclient-stage1.ps1
#
# Reboot manually when complete, then run winclient-stage2.ps1.
# -----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
. "C:\provisioning\win-config.ps1"

# -- Configure Keyboard Layout ------------------------------------------------
Invoke-KeyboardLayout

# -- Network Verification & Fallback Configuration ----------------------------
Write-Host "Verifying VLAN IP address"

$vlanIP = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -match '^192\.168\.132\.' } |
    Select-Object -First 1

if (-not $vlanIP) {
    Write-Host "No VLAN IP found, applying fallback static IP"

    $vlanAdapter = Get-NetAdapter |
        Where-Object { $_.Status -eq 'Up' -and $_.Name -notmatch 'Ethernet$' } |
        Select-Object -First 1

    if (-not $vlanAdapter) {
        Write-Host "Error: Cannot find suitable adapter for fallback IP"
        exit 1
    }

    $existing = Get-NetIPAddress -InterfaceAlias $vlanAdapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-NetIPAddress -InterfaceAlias $vlanAdapter.Name -AddressFamily IPv4 -Confirm:$false
    }

    # Apply static IP only -- gateway routing handled by Invoke-DCRoute below
    New-NetIPAddress -InterfaceAlias $vlanAdapter.Name -IPAddress '192.168.132.130' -PrefixLength 26 | Out-Null
}

Write-Host "Disabling DNS registration on NAT interface"
Set-DnsClient -InterfaceAlias "Ethernet" -RegisterThisConnectionsAddress $false
Write-Host "VLAN IP address confirmed"

# -- Add DC Host Route --------------------------------------------------------
# Adds only a targeted route to the DC so domain join works in stage 2.
# NAT default route stays intact so internet (chocolatey) still works in
# stage 3. Full Invoke-NetworkFix runs last in stage 3.
Invoke-DCRoute -DCAddress $dcIP -Gateway $clientGateway

# -- Remote Server Administration Tools (RSAT) --------------------------------
Write-Host "Installing RSAT features"

foreach ($feature in $RSATFeatures) {
    $state = Get-WindowsCapability -Online -Name $feature -ErrorAction SilentlyContinue

    if ($state -and $state.State -eq 'Installed') {
        continue
    }

    try {
        Add-WindowsCapability -Online -Name $feature -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Warning: Failed to install $feature -- $_"
    }
}

Write-Host "RSAT features installed"

# -- Chocolatey ---------------------------------------------------------------
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null
}
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')

# -- Nextcloud Desktop Client -------------------------------------------------
Write-Host "Installing Nextcloud Desktop Client"
choco install nextcloud-client -y --no-progress --silent | Out-Null

# -- Thunderbird --------------------------------------------------------------
Write-Host "Installing Mozilla Thunderbird"
choco install thunderbird -y --no-progress --silent | Out-Null

# -- Nmap (voor netwerkdiagnose en ACL checks) --------------------------------
Write-Host "Installing Nmap"
choco install nmap -y --no-progress --silent | Out-Null

# Add permanently if not already present
$nmapPath = "C:\Program Files (x86)\Nmap"

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($machinePath -notlike "*$nmapPath*") {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$machinePath;$nmapPath",
        "Machine"
    )
}

# -- Set Hostname -------------------------------------------------------------
Invoke-ComputerRename -TargetName $clientHostname

# -- Script Completion --------------------------------------------------------
Start-Sleep -Seconds 3
Write-Host ""
Write-Host "  +-------------------------------------------------+"
Write-Host "  | Stage 1 complete - Enter to reboot              |"
Write-Host "  | After reboot, run: winclient-stage2.ps1         |"
Write-Host "  +-------------------------------------------------+"
Write-Host ""

Read-Host
Restart-Computer -Force
exit 0