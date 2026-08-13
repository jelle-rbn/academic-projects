# -----------------------------------------------------------------------------
# win-config.ps1  --  Windows Infrastructure Configuration Logic
# -----------------------------------------------------------------------------
# Core configuration script that derives computed values from win-data.psd1
# and exposes them as flat variables for infrastructure provisioning.
# -----------------------------------------------------------------------------

# -- Environment Initialization -----------------------------------------------
# Stop execution on any error to ensure configuration integrity.
$ErrorActionPreference = 'Stop'

# -- Data Loading -------------------------------------------------------------
$_configDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$_data      = Import-PowerShellDataFile -Path (Join-Path $_configDir 'win-data.psd1')

# -- Domain Variables ---------------------------------------------------------
# Extracts Active Directory forest and domain-wide settings.
$DomainName        = $_data.Domain.Name
$DomainNetbiosName = $_data.Domain.NetbiosName
$DomainMode        = $_data.Domain.Mode
$ForestMode        = $_data.Domain.Mode
$DSRMPassword      = $_data.Domain.DSRMPassword
$DNSForwarders     = [string[]] $_data.Domain.DNSForwarders
# Compute the Base Distinguished Name (DN) from the domain string.
$BaseDC            = ($DomainName.Split('.') | ForEach-Object { "DC=$_" }) -join ','

# -- Domain Controller Variables ----------------------------------------------
# Storage, Networking, and Share settings for the primary DC.
$dcHostname          = $_data.DC.Hostname
$dcIP                = $_data.DC.IP
$dcGateway           = $_data.DC.Gateway
$ProxyCertKeySource  = $_data.DC.ProxyCertKeySource
$ProfileDriveLetter  = $_data.DC.ProfileDriveLetter
$ProfileDriveLabel   = $_data.DC.ProfileDriveLabel
$ProfileShareName    = $_data.DC.ProfileShareName
$ProfileSharePath    = $_data.DC.ProfileSharePath
$HomeShareName       = $_data.DC.HomeShareName
$HomeSharePath       = $_data.DC.HomeSharePath
$HomeDriveLetter     = $_data.DC.HomeDriveLetter

# -- Reverse Proxy Variables --------------------------------------------------
$_proxyServer = $_data.Servers | Where-Object { $_.Hostname -eq 'reverse-proxy' } | Select-Object -First 1
$ProxyIP      = $_proxyServer.IP
$ProxyUser    = $_proxyServer.SshUsername

# -- Client Variables ---------------------------------------------------------
# Windows Client specific networking and RSAT feature requirements.
$clientHostname           = $_data.Client.Hostname
$clientIP                  = $_data.Client.IP
$clientGateway            = $_data.Client.Gateway
$clientAdminUsername      = $_data.Client.AdminUsername
$clientAdminPassword      = $_data.Client.AdminPassword
$NetworkAdapterPattern    = $_data.Client.NetworkAdapterPattern
$DNSServers               = [string[]] $_data.Client.DNSServers
$RSATFeatures             = [string[]] $_data.Client.RSATFeatures
# Default location for new computer objects before moving to production OUs.
$DefaultComputerOU        = "OU=_Staging,OU=Computers,OU=D404,$BaseDC"

# -- Domain Join Credentials --------------------------------------------------
# Dedicated service account used exclusively for domain join operations.
$JoinUsername = $_data.DomainJoinAccount
$_joinUser    = $_data.Users | Where-Object { $_.SamAccountName -eq $JoinUsername } | Select-Object -First 1
$JoinPassword = $_joinUser.Password

# -- Public Key Infrastructure Credentials ------------------------------------
# Dedicated service account used for CA provisioning.
$PKIAdminUsername = $_data.CertificateAccount
$_pkiUser         = $_data.Users | Where-Object { $_.SamAccountName -eq $PKIAdminUsername } | Select-Object -First 1
$PKIAdminPassword = $_pkiUser.Password

# -- Active Directory Structure -----------------------------------------------
# Imports arrays of OUs, Users, Computers, and Security Groups.
$OUs       = $_data.OUs
$Users     = $_data.Users
$Computers = $_data.Computers
$Groups    = $_data.Groups
$Servers   = @( @{ Hostname = $dcHostname; IP = $dcIP } ) + $_data.Servers

# -- Rename Computer ----------------------------------------------------------
# Ensures the local hostname matches the intended target defined in win-data.
function Invoke-ComputerRename {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TargetName
    )

    Write-Host "Renaming Computer"

    $current = $env:COMPUTERNAME
    if ($current -eq $TargetName) {
        Write-Host "Computer already named $TargetName"
        return
    }

    Rename-Computer -NewName $TargetName -Force -WarningAction SilentlyContinue
    Write-Host "Computer rename OK"
}

# -- Fix Network Routing ------------------------------------------------------
# Adjusts interface metrics to prioritize the VLAN adapter over NAT.
# Required for consistent communication between the DC and Client.
function Invoke-NetworkFix {
    param(
        [Parameter(Mandatory=$true)]
        [string] $Gateway
    )
    Write-Host "Checking network configuration"
    Set-NetFirewallRule -Name "CoreNet-Diag-ICMP4-EchoRequest-In" -Profile Any -RemoteAddress Any -ErrorAction SilentlyContinue

    $vlanAdapter = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -match '^192\.168\.132\.' } |
        Select-Object -First 1
    if (-not $vlanAdapter) {
        Write-Host "Error: No matching VLAN adapter found"
        return
    }
    $vlanIface  = $vlanAdapter.InterfaceAlias
    $vlanPrefix = $vlanAdapter.PrefixLength
    if ($vlanPrefix -eq 24) {
        Write-Host "Network in Local test mode - No routing changes required"
        return
    }

    $natAdapter = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -match '^10\.0\.2\.' } |
        Select-Object -First 1
    if (-not $natAdapter) {
        Write-Host "Warning: NAT adapter not found, proceeding with VLAN routing anyway"
    } else {
        $natIface = $natAdapter.InterfaceAlias
        Set-NetIPInterface -InterfaceAlias $natIface -InterfaceMetric 9000 -AddressFamily IPv4
        Write-Host "Deprioritised NAT adapter (metric 9000)"
    }

    # Ensure VLAN adapter has a low metric so it always wins
    Set-NetIPInterface -InterfaceAlias $vlanIface -InterfaceMetric 25 -AddressFamily IPv4

    # Add VLAN default route if missing (covers static IP scenario where DHCP won't inject it)
    $existingRoute = Get-NetRoute -InterfaceAlias $vlanIface -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue
    if (-not $existingRoute) {
        New-NetRoute -InterfaceAlias $vlanIface -DestinationPrefix '0.0.0.0/0' -NextHop $Gateway -RouteMetric 50 | Out-Null
        Write-Host "Added default route via $Gateway on $vlanIface"
    }

    Write-Host "Network routing set to onsite mode"
}

# -- Add DC Host Route -------------------------------------------------------
# Adds a specific host route to the Domain Controller via the VLAN gateway.
# Used during early provisioning (stage 1) to enable domain join in stage 2
# WITHOUT removing the NAT default route — preserving internet access so that
# Add-WindowsCapability (RSAT) can still reach Windows Update in stage 3.
# The full Invoke-NetworkFix is deferred to stage 3 after all downloads finish.
function Invoke-DCRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DCAddress,
        [Parameter(Mandatory)]
        [string] $Gateway
    )

    Write-Host "Adding DC host route"

    $vlanAdapter = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -match '^192\.168\.132\.' } |
        Select-Object -First 1

    if (-not $vlanAdapter) {
        Write-Host "Error: No VLAN adapter found for DC route"
        Exit 1
    }

    if ($vlanAdapter.PrefixLength -eq 24) {
        Write-Host "DC host route -- local test mode, skipping"
        return
    }

    $existing = Get-NetRoute -InterfaceAlias $vlanAdapter.InterfaceAlias `
        -DestinationPrefix "$DCAddress/32" -ErrorAction SilentlyContinue

    if (-not $existing) {
        New-NetRoute -InterfaceAlias $vlanAdapter.InterfaceAlias `
            -DestinationPrefix "$DCAddress/32" `
            -NextHop $Gateway `
            -RouteMetric 10 | Out-Null
        Write-Host "DC host route added ($DCAddress via $Gateway)"
    } else {
        Write-Host "DC host route already present"
    }
}

# -- Wait for AD Availability -------------------------------------------------
# Polling mechanism to ensure Domain Services are up before running stage scripts.
function Wait-ForADAvailability {
    [CmdletBinding()]
    param(
        [int] $TimeoutSeconds  = 300,
        [int] $IntervalSeconds = 15
    )

    Write-Host "Waiting for AD availability"

    $waited = 0
    while ($waited -lt $TimeoutSeconds) {
        try {
            $domain = Get-ADDomain -ErrorAction Stop
            Write-Host "AD availability OK"
            return $domain
        }
        catch {
            Start-Sleep -Seconds $IntervalSeconds
            $waited += $IntervalSeconds
        }
    }

    Write-Host "Error: AD did not become available within timeout"
    Exit 1
}

# -- Join Domain --------------------------------------------------------------
# Configures DNS and attempts to join the machine to the AD domain.
function Invoke-DomainJoin {
    [CmdletBinding()]
    param(
        [string] $TargetOU = $DefaultComputerOU
    )

    Write-Host "Starting domain join"

    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.Domain -eq $DomainName) {
        Write-Host "Already domain member"
        return
    }

    # Set DNS to look at the Domain Controller before attempting join.
    Get-NetAdapter |
        Where-Object { $_.Status -eq 'Up' -and $_.Name -match $NetworkAdapterPattern } |
        ForEach-Object {
            Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses $DNSServers
        }

    $dnsResolved  = $false
    $dnsTimeout   = 600
    $dnsInterval  = 5
    $dnsWaited    = 0

    while (-not $dnsResolved -and $dnsWaited -lt $dnsTimeout) {
        try {
            Resolve-DnsName $DomainName -ErrorAction Stop | Out-Null
            $dnsResolved = $true
        } catch {
            Start-Sleep -Seconds $dnsInterval
            $dnsWaited += $dnsInterval
        }
    }

    if (-not $dnsResolved) {
        Write-Host "Error: Could not resolve domain"
        Exit 1
    }

    $dcReachable  = $false
    $dcTimeout    = 300
    $dcInterval   = 15
    $dcWaited     = 0

    while (-not $dcReachable -and $dcWaited -lt $dcTimeout) {
        $tcpCheck = Test-NetConnection -ComputerName $dcIP -Port 389 -WarningAction SilentlyContinue
        if ($tcpCheck.TcpTestSucceeded) {
            $dcReachable = $true
        } else {
            Start-Sleep -Seconds $dcInterval
            $dcWaited += $dcInterval
        }
    }

    if (-not $dcReachable) {
        Write-Host "Error: Could not reach DC"
        Exit 1
    }

    $maxAttempts = 10
    $waitSeconds = 60
    $attempt     = 0

    while ($attempt -lt $maxAttempts) {
        $attempt++

        $securePass  = ConvertTo-SecureString $JoinPassword -AsPlainText -Force
        $credentials = New-Object System.Management.Automation.PSCredential(
            "$DomainNetbiosName\$JoinUsername", $securePass
        )

        try {
            Add-Computer -DomainName $DomainName -Credential $credentials -OUPath $TargetOU -Force -Restart:$false -ErrorAction Stop -WarningAction SilentlyContinue
            Write-Host "Domain join OK"
            return
        } catch {
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds $waitSeconds
            }
        }
    }

    Write-Host "Error: Domain join failed after maximum attempts"
    Exit 1
}

# -- Verify Domain Membership -------------------------------------------------
# Assertion check to confirm the join operation was successful.
function Assert-DomainMembership {
    Write-Host "Verifying domain membership"

    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.Domain -ne $DomainName) {
        Write-Host "Error: Machine is not joined to the expected domain"
        Exit 1
    }

    Write-Host "Domain membership OK"
}

function Invoke-KeyboardLayout {
    Write-Host "Configuring keyboard layout"
    $xmlPath = "$env:TEMP\intl-settings.xml"
    
    $xmlContent = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/>
    </gs:UserList>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="0813:00000813"/>
    </gs:InputPreferences>
</gs:GlobalizationServices>
"@
    Set-Content -Path $xmlPath -Value $xmlContent -Encoding UTF8
    Start-Process -FilePath "control.exe" -ArgumentList "intl.cpl,,/f:`"$xmlPath`"" -PassThru -Wait | Out-Null
    if (Test-Path $xmlPath) { Remove-Item -Path $xmlPath -Force }

    # Helper to write preload order into any already-loaded hive path
    function Set-KeyboardPreload($path) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name '1' -Value '00000813' -Type String  # AZERTY Belgian (default)
        Set-ItemProperty -Path $path -Name '2' -Value '00000409' -Type String  # QWERTY US (fallback)
    }

    # Current logged-in user (the provisioning session)
    Set-KeyboardPreload 'HKCU:\Keyboard Layout\Preload'

    # Logon/Welcome screen
    Set-KeyboardPreload 'Registry::HKU\.DEFAULT\Keyboard Layout\Preload'

    # New user profiles  must mount C:\Users\Default\NTUSER.DAT explicitly.
    # CopySettingsToDefaultUserAcct in the XML is unreliable; this is the safe way.
    $defaultHive = "C:\Users\Default\NTUSER.DAT"
    $mountKey   = "HKLM\TempDefaultUser"

    reg load $mountKey $defaultHive | Out-Null
    Set-KeyboardPreload "Registry::$mountKey\Keyboard Layout\Preload"
    [GC]::Collect()             # release any lingering handles before unload
    Start-Sleep -Milliseconds 500
    reg unload $mountKey | Out-Null

    Write-Host "Keyboard layout configuration OK"
}

Write-Host "Win-config module loaded"
