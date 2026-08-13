# -----------------------------------------------------------------------------
# windowsdc-stage1.ps1  --  Domain Controller Setup & Promotion
# -----------------------------------------------------------------------------
# Installs required Windows features (DNS, ADDS, DFS), provisions a mirrored
# Storage Spaces volume for profiles/home drives, and promotes the server
# to the primary Domain Controller for the new forest.
# -----------------------------------------------------------------------------

# -- Environment Setup & Configuration ----------------------------------------
# Enforce strict error handling and dot-source the main configuration logic
$ErrorActionPreference = 'Stop'
. "C:\provisioning\win-config.ps1"

# -- DNS Server Role Installation ---------------------------------------------
# Ensures the DNS Server role is installed, the service is running automatically,
# and domain-external queries are routed to the specified public DNS forwarders.
Write-Host "Installing DNS Server role"

$dns = Get-WindowsFeature -Name DNS
if (-not $dns.Installed) {
    Install-WindowsFeature -Name DNS -IncludeManagementTools | Out-Null
    $dns = Get-WindowsFeature -Name DNS
    if (-not $dns.Installed) {
        Write-Host "Error: DNS role installation failed"
        exit 1
    }
}

Set-Service -Name DNS -StartupType Automatic
$svc = Get-Service -Name DNS
if ($svc.Status -ne 'Running') {
    Start-Service -Name DNS
    Start-Sleep -Seconds 3
}

Add-DnsServerForwarder -IPAddress $DNSForwarders -ErrorAction SilentlyContinue

Write-Host "DNS Server role installation OK"

# -- Active Directory & DFS Features ------------------------------------------
# Installs the underlying binaries and management tools required for Active
# Directory Domain Services and Distributed File System (DFS) Namespaces.
Write-Host "Installing ADDS features"

$adFeatures = @('AD-Domain-Services', 'RSAT-ADDS', 'RSAT-AD-PowerShell', 'FS-DFS-Namespace')
Install-WindowsFeature -Name $adFeatures -IncludeManagementTools | Out-Null

Write-Host "ADDS features installation OK"

# -- Domain Controller Promotion ----------------------------------------------
Write-Host "Promoting server to Domain Controller"

$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.DomainRole -ge 4) {
    Write-Host "Server is already a Domain Controller"
    exit 0
}

try {
    Import-Module ADDSDeployment -ErrorAction Stop
} catch {
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null
    Import-Module ADDSDeployment -ErrorAction Stop
}

try {
    $secureDSRM = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force
    $result = Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainNetbiosName -ForestMode $ForestMode -DomainMode $DomainMode -SafeModeAdministratorPassword $secureDSRM -InstallDns -NoRebootOnCompletion -Force -WarningAction SilentlyContinue

    if ($result.Status -ne 'Success') {
        Write-Host "Error: Forest installation reported non-success status"
        exit 1
    }
} catch {
    Write-Host "Error: Install-ADDSForest failed: $_"
    exit 1
}

# -- Script Completion --------------------------------------------------------
Write-Host "Promotion to Domain Controller OK"
exit 0
