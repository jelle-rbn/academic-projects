# -----------------------------------------------------------------------------
# windowsdc-stage2.ps1  --  Active Directory & DNS Object Provisioning
# -----------------------------------------------------------------------------
# Constructs the Active Directory hierarchy (OUs, Users, Computers), delegates
# domain-join permissions, and configures foundational DNS zones and records.
# -----------------------------------------------------------------------------

# -- Environment Setup & Configuration ----------------------------------------
# Enforce strict error handling and dot-source the main configuration logic
$ErrorActionPreference = 'Stop'
. "C:\provisioning\win-config.ps1"

# -- Wait for Domain Availability ---------------------------------------------
$domain   = Wait-ForADAvailability
$DomainDN = $domain.DistinguishedName

Import-Module ActiveDirectory -ErrorAction SilentlyContinue
Import-Module DnsServer       -ErrorAction SilentlyContinue
Import-Module ADCSDeployment  -ErrorAction SilentlyContinue

# -- DNS Zones & Records Configuration ----------------------------------------
# Reconfigures forwarders, establishes forward and reverse lookup zones, and 
# creates static A/PTR/CNAME records for core infrastructure servers.
Write-Host "Configuring DNS zones and records"

$ipOctets    = $dcIP.Split('.')
$networkID   = "$($ipOctets[0]).$($ipOctets[1]).$($ipOctets[2]).0/24"
$reverseName = "$($ipOctets[2]).$($ipOctets[1]).$($ipOctets[0]).in-addr.arpa"
$dcLastOctet = $ipOctets[3]

# Reset DNS Forwarders to those defined in win-data.psd1
$existing = Get-DnsServerForwarder -ErrorAction SilentlyContinue
if ($existing.IPAddress) {
    Remove-DnsServerForwarder -IPAddress $existing.IPAddress -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}
Add-DnsServerForwarder -IPAddress $DNSForwarders -ErrorAction SilentlyContinue

# Ensure the primary Active Directory forward lookup zone exists
$fwdZone = Get-DnsServerZone -Name $DomainName -ErrorAction SilentlyContinue
if (-not $fwdZone) {
    Add-DnsServerPrimaryZone -Name $DomainName -ReplicationScope 'Forest' -DynamicUpdate 'Secure'
}

# Ensure the reverse lookup zone exists (with retry logic for propagation delays)
$revZone  = $null
$attempts = 0
while (-not $revZone -and $attempts -lt 6) {
    $revZone = Get-DnsServerZone -Name $reverseName -ErrorAction SilentlyContinue
    if (-not $revZone) { Start-Sleep -Seconds 5; $attempts++ }
}

if (-not $revZone) {
    try {
        Add-DnsServerPrimaryZone -NetworkID $networkID -ReplicationScope 'Forest' -DynamicUpdate 'Secure' -ErrorAction Stop
    } catch {
        $revZone = Get-DnsServerZone -Name $reverseName -ErrorAction SilentlyContinue
        if (-not $revZone) {
            Write-Host "Error: Failed to create reverse zone: $($_.Exception.Message)"
            throw
        }
    }
}

foreach ($srv in $Servers) {
    $h       = $srv.Hostname
    $ip      = $srv.IP
    $lastOct = $ip.Split('.')[3]

    $existingA = Get-DnsServerResourceRecord -ZoneName $DomainName -Name $h -RRType A -ErrorAction SilentlyContinue
    if (-not $existingA) {
        Add-DnsServerResourceRecordA -ZoneName $DomainName -Name $h -IPv4Address $ip
    }

    $existingPTR = Get-DnsServerResourceRecord -ZoneName $reverseName -Name $lastOct -RRType Ptr -ErrorAction SilentlyContinue
    if (-not $existingPTR) {
        Add-DnsServerResourceRecordPtr -ZoneName $reverseName -Name $lastOct -PtrDomainName "$h.$DomainName."
    }
}

# Alias record for the main domain
$aliasName  = 'www'
$targetFQDN = "$DomainName."
$existingCNAME = Get-DnsServerResourceRecord -ZoneName $DomainName -Name $aliasName -RRType CNAME -ErrorAction SilentlyContinue
if (-not $existingCNAME) {
    Add-DnsServerResourceRecordCName -ZoneName $DomainName -Name $aliasName -HostNameAlias $targetFQDN
}

# Secondary internal web zone configuration
$webZone = 't02-domain404.internal'
$webFwdZone = Get-DnsServerZone -Name $webZone -ErrorAction SilentlyContinue
if (-not $webFwdZone) {
    Add-DnsServerPrimaryZone -Name $webZone -ReplicationScope 'Forest' -DynamicUpdate 'None'
}

# Root A record — points the bare domain to the reverse proxy
$existingWebA = Get-DnsServerResourceRecord -ZoneName $webZone -Name '@' -RRType A -ErrorAction SilentlyContinue
if (-not $existingWebA) {
    Add-DnsServerResourceRecordA -ZoneName $webZone -Name '@' -IPv4Address '192.168.132.234'
}

# www CNAME — www.t02-domain404.internal -> t02-domain404.internal
$existingWebCNAME = Get-DnsServerResourceRecord -ZoneName $webZone -Name 'www' -RRType CNAME -ErrorAction SilentlyContinue
if (-not $existingWebCNAME) {
    Add-DnsServerResourceRecordCName -ZoneName $webZone -Name 'www' -HostNameAlias "$webZone."
}

# Nextcloud zone — t02-domain404.internal
$nextcloudZone = 't02-domain404.internal'
$nextcloudFwdZone = Get-DnsServerZone -Name $nextcloudZone -ErrorAction SilentlyContinue
if (-not $nextcloudFwdZone) {
    Add-DnsServerPrimaryZone -Name $nextcloudZone -ReplicationScope 'Forest' -DynamicUpdate 'None'
}

# nextcloud A record — nextcloud.t02-domain404.internal -> reverse proxy
$existingNcA = Get-DnsServerResourceRecord -ZoneName $nextcloudZone -Name 'nextcloud' -RRType A -ErrorAction SilentlyContinue
if (-not $existingNcA) {
    Add-DnsServerResourceRecordA -ZoneName $nextcloudZone -Name 'nextcloud' -IPv4Address '192.168.132.234'
}

# Point local active adapters to localhost for DNS resolution
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
    Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses '127.0.0.1' -ErrorAction SilentlyContinue
}

# Prevent Vagrant NAT adapters (10.0.2.*) from registering their IPs in DNS
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
    $adapterIP = (Get-NetIPAddress -InterfaceAlias $_.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    if ($adapterIP -like '10.0.2.*') {
        Set-DnsClient -InterfaceAlias $_.Name -RegisterThisConnectionsAddress $false
    }
}

Write-Host "DNS zones and records configuration OK"

# -- Organizational Units (OUs) -----------------------------------------------
# Iterates through the hierarchy defined in win-data.psd1 and creates them.
Write-Host "Creating Organisational Units"

foreach ($ou in $OUs) {
    $ouDN = "OU=$($ou.Name),$($ou.Path)"
    try {
        Get-ADOrganizationalUnit -Identity $ouDN -ErrorAction Stop | Out-Null
    } catch {
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ProtectedFromAccidentalDeletion $false
    }
}

Write-Host "Organisational Units created"

# -- Domain Password Policy ---------------------------------------------------
# Relaxes default length, age, and complexity requirements for the lab environment.

Set-ADDefaultDomainPasswordPolicy -Identity $DomainName -MinPasswordLength 4 -ComplexityEnabled $false -PasswordHistoryCount 1 -MinPasswordAge 0 -MaxPasswordAge 0

# -- User Accounts & Remote Storage Mapping ----------------------------------
# Provisions users and maps their Home Drive and Profile Path to the 
# central Linux storage server instead of local DC storage.
Write-Host "Creating user accounts and mapping remote storage"

# We gebruiken 'storage' als hostname (moet in win-data.psd1 staan)
$storageServer = "storage" 

foreach ($user in $Users) {
    $sam = $user.SamAccountName

    try {
        Get-ADUser -Identity $sam -ErrorAction Stop | Out-Null
        Write-Host "User $sam already exists, skipping creation..."
    } catch {
        $secPassword = ConvertTo-SecureString $user.Password -AsPlainText -Force

        $params = @{
            SamAccountName        = $sam
            UserPrincipalName     = "$sam@$DomainName"
            Name                  = $user.DisplayName
            DisplayName           = $user.DisplayName
            GivenName             = $user.GivenName
            Surname               = $user.Surname
            AccountPassword       = $secPassword
            Path                  = $user.OU
            ChangePasswordAtLogon = if ($user.ContainsKey('ChangePasswordAtLogon')) { $user.ChangePasswordAtLogon } else { $true }
            PasswordNeverExpires  = $false
            Enabled               = $true
        }

        if ($user.ContainsKey('EmailAddress')) { $params.EmailAddress = $user.EmailAddress }
        if ($user.ContainsKey('Title'))        { $params.Title = $user.Title }
        if ($user.ContainsKey('Department'))   { $params.Department = $user.Department }
        if ($user.ContainsKey('Company'))      { $params.Company = $user.Company }
        if ($user.ContainsKey('Description'))  { $params.Description = $user.Description }
        
        New-ADUser @params

        foreach ($group in $user.Groups) {
            try { Add-ADGroupMember -Identity $group -Members $sam -ErrorAction SilentlyContinue } catch {}
        }
    }

    # -- Remote Storage --
    if ($user.ProfilePath -ne '') {
        $homeUNC    = "\\$storageServer\homefolders\$sam"
        $profileUNC = "\\$storageServer\profiles\$sam"

        Write-Host "Mapping storage for $sam -> $homeUNC"
        
        Set-ADUser -Identity $sam `
            -HomeDrive "$($HomeDriveLetter):" `
            -HomeDirectory $homeUNC `
            -ProfilePath $profileUNC
    }
}

Write-Host "User accounts and remote storage mapping OK"

# -- Machine Account Quota ----------------------------------------------------
# Sets ms-DS-MachineAccountQuota to 0, preventing standard authenticated users 
# from joining computers to the domain (the Windows default is 10).

Set-ADDomain -Identity $DomainName -Replace @{ 'ms-DS-MachineAccountQuota' = '0' }

# -- Pre-stage Computer Accounts ----------------------------------------------
# Creates dummy computer objects in the Staging OU. This allows the dedicated 
# SVC_DomainJoin account to bind the physical machine to this existing object.
Write-Host "Pre-staging computer accounts"

foreach ($computer in $Computers) {
    try {
        Get-ADComputer -Identity $computer.Name -ErrorAction Stop | Out-Null
    } catch {
        New-ADComputer -Name $computer.Name -Path $computer.Path -Description $computer.Description -Enabled $true
    }
}

Write-Host "Computer accounts pre-staged"

# -- Delegate Domain Join Rights ----------------------------------------------
# Modifies the ACLs on the Staging OU for joining clients.
# Modifies the ACLs on the Servers OU for joining servers.

Write-Host "Delegating domain-join rights"

														   
$joinAccount = "$DomainNetbiosName\$JoinUsername"

$stagingOU   = "OU=_Staging,OU=Computers,OU=D404,$DomainDN"
$infraOU     = "OU=Infrastructure,OU=Servers,OU=Computers,OU=D404,$DomainDN"

$delegations = @(
    "/I:S /G `"${joinAccount}:CA;Reset Password;computer`""
    "/I:S /G `"${joinAccount}:WP;;computer`""
    "/I:S /G `"${joinAccount}:WS;Validated write to DNS host name;computer`""
    "/I:S /G `"${joinAccount}:WS;Validated write to service principal name;computer`""
)

foreach ($acl in $delegations) {
    Invoke-Expression "dsacls `"$stagingOU`" $acl" | Out-Null
	Invoke-Expression "dsacls `"$infraOU`" $acl" | Out-Null
}

Write-Host "Domain-join rights delegated"

# -- Script Completion --------------------------------------------------------
exit 0