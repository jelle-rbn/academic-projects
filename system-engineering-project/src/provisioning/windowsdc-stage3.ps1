# -----------------------------------------------------------------------------
# windowsdc-stage3.ps1  --  Windows Group Policy & Security Provisioning
# -----------------------------------------------------------------------------
# Configures baseline domain policies, staging environment restrictions,
# security groups, and department-specific workstation logon rights.
# -----------------------------------------------------------------------------

# -- Environment Setup & Configuration ----------------------------------------
# Enforce strict error handling and load external configuration variables.
$ErrorActionPreference = 'Stop'
. "C:\provisioning\win-config.ps1"

Write-Host "GPO Provisioning"

# Ensure Domain Services are fully reachable before proceeding
$domain   = Wait-ForADAvailability
$DomainDN = $domain.DistinguishedName

Import-Module ActiveDirectory -ErrorAction SilentlyContinue
Import-Module GroupPolicy     -ErrorAction SilentlyContinue

# -- Group Policy Helper Functions --------------------------------------------
# Standardized wrappers for creating, linking, and managing GPOs.

# Ensure-GPO
# Purpose: Safely fetches an existing GPO or creates a new one if missing.
function Ensure-GPO {
    param([string]$Name)
    $gpo = Get-GPO -Name $Name -Domain $DomainName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $Name -Domain $DomainName
    }
    return $gpo
}

# Ensure-GPLinkSafe
# Purpose: Links a GPO to a Target DN without throwing errors on existing links.
function Ensure-GPLinkSafe {
    param(
        [string]$GpoName,
        [string]$TargetDn,
        [switch]$Enforced
    )
    $existing = (Get-GPInheritance -Target $TargetDn -Domain $DomainName).GpoLinks | 
                Where-Object { $_.DisplayName -eq $GpoName }

    $enfState = if ($Enforced) { 'Yes' } else { 'No' }

    if (-not $existing) {
        New-GPLink -Name $GpoName -Target $TargetDn -Domain $DomainName -LinkEnabled 'Yes' -Enforced $enfState | Out-Null
    }
}

# New-SecurityGPO
# Purpose: Programmatically configures User Rights Assignments
function New-SecurityGPO {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]    $GPOName,
        [Parameter(Mandatory)] [string[]]  $LinkedOUs,
        [Parameter(Mandatory)] [hashtable] $PrivilegeRights,
        [switch] $Enforced
    )

    $gpo = Ensure-GPO -Name $GPOName
    $gpoGuidBraced = $gpo.Id.ToString('B').ToUpper()
    $gpoCN         = "CN=$gpoGuidBraced,CN=Policies,CN=System,$DomainDN"

    # Translate the hashtable of rights into the required INF format
    $privLines = foreach ($right in $PrivilegeRights.Keys) {
        $sidTokens = $PrivilegeRights[$right] | ForEach-Object { "*$_" }
        "$right = $($sidTokens -join ',')"
    }

    # Construct and write the GptTmpl.inf file directly to the SYSVOL share
    $infContent = (@('[Unicode]', 'Unicode=yes', '[Version]', 'signature="$CHICAGO$"', 'Revision=1', '[Privilege Rights]') + $privLines) -join "`r`n"
    $sysvolRoot = "\\$DomainName\SYSVOL\$DomainName\Policies\$gpoGuidBraced"
    $secEditDir = "$sysvolRoot\Machine\Microsoft\Windows NT\SecEdit"
    if (-not (Test-Path $secEditDir)) { New-Item -Path $secEditDir -ItemType Directory -Force | Out-Null }
    [System.IO.File]::WriteAllText("$secEditDir\GptTmpl.inf", $infContent, [System.Text.Encoding]::Unicode)

    # Increment GPT.INI version to trigger client policy updates
    $gptIniPath = "$sysvolRoot\GPT.INI"
    $gptIni = if (Test-Path $gptIniPath) { [System.IO.File]::ReadAllText($gptIniPath) } else { "" }
    $gptIni = if ($gptIni -match 'Version=\d+') { $gptIni -replace 'Version=\d+', 'Version=1' } else { "Version=1`r`n" }
    [System.IO.File]::WriteAllText($gptIniPath, $gptIni, [System.Text.Encoding]::ASCII)

    # Register the Client Side Extensions (CSE) in Active Directory
    $secCSE  = '{827D319E-6EAC-11D2-A4EA-00C04F79F83A}'
    $secTool = '{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}'
    Set-ADObject -Identity $gpoCN -Replace @{ gpcMachineExtensionNames = "[$secCSE$secTool]"; versionNumber = 1 }

    foreach ($ou in $LinkedOUs) { Ensure-GPLinkSafe -GpoName $GPOName -TargetDn $ou -Enforced:$Enforced }
    return $gpo
}

# -- Active Directory - Security Groups ---------------------------------------
# Iterates through the predefined $Groups array to ensure required security 
# groups exist and possess the correct initial membership.
Write-Host "Creating Security Groups"

foreach ($grp in $Groups) {
    $existing = Get-ADGroup -Filter "SamAccountName -eq '$($grp.Name)'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADGroup -Name $grp.Name -SamAccountName $grp.Name -GroupScope $grp.Scope -GroupCategory $grp.Category -Path $grp.Path
    }
    foreach ($member in $grp.Members) {
        try { Add-ADGroupMember -Identity $grp.Name -Members $member -ErrorAction Stop } catch {}
    }
}

Write-Host "Security Groups created"

# -- Security Identifier (SID) Resolution -------------------------------------
# Pre-fetches SIDs for built-in and custom groups required for configuring
# the SeInteractiveLogonRight and SeDenyInteractiveLogonRight policies.
$sidAdministrators = 'S-1-5-32-544'    # Well-known SID for Builtin\Administrators
$sidDomainAdmins   = (Get-ADGroup 'Domain Admins').SID.Value
$sidSvcAll         = (Get-ADGroup 'GRP_SVC_All').SID.Value
$sidLogonIT        = (Get-ADGroup 'GRP_Logon_IT').SID.Value
$sidLogonHR        = (Get-ADGroup 'GRP_Logon_HR').SID.Value
$sidLogonMgmt      = (Get-ADGroup 'GRP_Logon_Management').SID.Value
$sidLogonDev       = (Get-ADGroup 'GRP_Logon_Development').SID.Value
# Base array of SIDs that should always have administrative logon rights
$allowBase         = @($sidAdministrators, $sidDomainAdmins)

# -- Domain Baseline GPO ------------------------------------------------------
# Establishes standard configurations across the entire D404 domain root
Write-Host "Configuring Domain Baseline GPO"

$baselineGPOName = 'GPO-Baseline-Standard'
$rootOU = "OU=D404,$DomainDN"

Ensure-GPO -Name $baselineGPOName | Out-Null

# Purge any inherited legal notices to prevent logon screen clutter
$targetKey = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System"
$valuesToRemove = @("legalnoticecaption", "legalnoticetext")

foreach ($valueName in $valuesToRemove) {
    $existing = Get-GPRegistryValue -Name $baselineGPOName -Key $targetKey -ValueName $valueName -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-GPRegistryValue -Name $baselineGPOName -Key $targetKey -ValueName $valueName | Out-Null
    }
}

# Allow administrators to be added to the Restricted Groups policy
$systemPoliciesKey = "HKLM\Software\Policies\Microsoft\Windows\System"
Set-GPRegistryValue -Name $baselineGPOName -Key $systemPoliciesKey -ValueName "AddAdminGroupToRUP" -Type DWord -Value 1 | Out-Null

Ensure-GPLinkSafe -GpoName $baselineGPOName -TargetDn $rootOU

Write-Host "Domain Baseline GPO configured"

# -- Service Account Logon Restrictions ---------------------------------------
# Explicitly denies interactive and RDP logon rights for all service accounts
Write-Host "Configuring Service Account Logon Block GPO"

New-SecurityGPO -GPOName 'GPO-Block-SvcAccount-Logon' `
    -LinkedOUs @("OU=Computers,OU=D404,$DomainDN") `
    -PrivilegeRights @{
        SeDenyInteractiveLogonRight       = @($sidSvcAll)
        SeDenyRemoteInteractiveLogonRight = @($sidSvcAll)
    } | Out-Null

Write-Host "Service Account Logon Block GPO configured"

# -- Staging Environment Lockdown ---------------------------------------------
# Secures newly joined computers in the _Staging OU by restricting logons
# strictly to Administrators and displaying a mandatory legal notice.
Write-Host "Configuring Staging Environment GPOs"

$stagingOU = "OU=_Staging,OU=Computers,OU=D404,$DomainDN"

$lockdownGPOName = 'GPO-Staging-Lockdown'
New-SecurityGPO -GPOName $lockdownGPOName `
    -LinkedOUs @($stagingOU) `
    -PrivilegeRights @{
        SeInteractiveLogonRight       = $allowBase
        SeRemoteInteractiveLogonRight = $allowBase
    } -Enforced | Out-Null

Set-GPRegistryValue -Name $lockdownGPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "legalnoticecaption" -Type String -Value "Warning" | Out-Null
Set-GPRegistryValue -Name $lockdownGPOName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "legalnoticetext" -Type String -Value "This computer is in staging OU. Only Domain Administrators may log on. Please move computer object to correct OU when ready." | Out-Null

Write-Host "Staging Environment GPOs configured"

# -- Department Workstation Logon Policies ------------------------------------
# Implements Tiered/Segmented logon restrictions. Users can only log onto
# workstations located within their respective departmental OUs.
Write-Host "Configuring Department Workstation GPOs"

$deptGPOs = @(
    @{ Name = 'GPO-Logon-IT-Workstations'; OU = "OU=IT,OU=Workstations,OU=Computers,OU=D404,$DomainDN"; SID = $sidLogonIT }
    @{ Name = 'GPO-Logon-HR-Workstations'; OU = "OU=HR,OU=Workstations,OU=Computers,OU=D404,$DomainDN"; SID = $sidLogonHR }
    @{ Name = 'GPO-Logon-Management-Workstations'; OU = "OU=Management,OU=Workstations,OU=Computers,OU=D404,$DomainDN"; SID = $sidLogonMgmt }
    @{ Name = 'GPO-Logon-Development-Workstations'; OU = "OU=Development,OU=Workstations,OU=Computers,OU=D404,$DomainDN"; SID = $sidLogonDev }
)

foreach ($dept in $deptGPOs) {
    New-SecurityGPO -GPOName $dept.Name -LinkedOUs @($dept.OU) `
        -PrivilegeRights @{
            SeInteractiveLogonRight       = $allowBase + $dept.SID
            SeRemoteInteractiveLogonRight = $allowBase + $dept.SID
        } | Out-Null
}

Write-Host "Department Workstation GPOs configured"

# -- Restricted Users GPO ---------------------------------------------------- 
Write-Host "Configuring Restricted Users GPO" 

$RestrictedGPOName = "GPO-Restricted-Users" 
$RestrictedUsersOU = "OU=Users,OU=D404,$DomainDN" 
$RestrictedUserComputerOU = "OU=Computers,OU=D404,$DomainDN"

Ensure-GPO -Name $RestrictedGPOName | Out-Null 

Ensure-GPLinkSafe -GpoName $RestrictedGPOName -TargetDn $RestrictedUsersOU  | Out-Null

#Ensure-GPLinkSafe -GpoName $RestrictedGPOName `
#   -TargetDn "OU=Computers,OU=D404,$DomainDN" | Out-Null
Ensure-GPLinkSafe -GpoName $RestrictedGPOName -TargetDn $RestrictedUserComputerOU | Out-Null

Write-Host "Setting permissions..."

try {
    Set-GPPermission -Name $RestrictedGPOName `
        -TargetName "Authenticated Users" `
        -TargetType Group `
        -PermissionLevel GpoRead -ErrorAction Stop | Out-Null

    Set-GPPermission -Name $RestrictedGPOName `
        -TargetName "GRP_RestrictedUsers" `
        -TargetType Group `
        -PermissionLevel GpoApply -ErrorAction Stop | Out-Null
}
catch {
    Write-Host "Permission setting failed: $_"
}

# Block control panel
Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "NoControlPanel" -Type DWord -Value 1 | Out-Null

#Lock background color
Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "Wallpaper" -Type String -Value "" | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" `
    -ValueName "NoChangingWallPaper" -Type DWord -Value 1 | Out-Null

#Disallow taskabar
Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "NoTrayContextMenu" -Type DWord -Value 1 | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "LockTaskbar" -Type DWord -Value 1 | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Policies\Microsoft\Windows\Explorer" `
    -ValueName "NoPinningToTaskbar" -Type DWord -Value 1 | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "NoToolbarsOnTaskbar" -Type DWord -Value 1 | Out-Null

#Default browser shows https://t02-domain404.internal

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Policies\Microsoft\Edge" `
    -ValueName "RestoreOnStartup" -Type DWord `
    -Value 4  | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Policies\Microsoft\Edge" `
    -ValueName "RestoreOnStartupURLs" -Type MultiString `
    -Value "https://t02-domain404.internal" | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Policies\Microsoft\Edge" `
    -ValueName "HomepageIsNewTabPage" -Type DWord -Value 0 | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKCU\Software\Policies\Microsoft\Edge" `
    -ValueName "NewTabPageLocation" -Type String `
    -Value "https://t02-domain404.internal" | Out-Null

# -- Block EXE execution in Downloads folder ------------------------------
Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" `
    -ValueName "DefaultLevel" -Type DWord -Value 0x40000 | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" `
    -ValueName "PolicyScope" -Type DWord -Value 0 | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" `
    -ValueName "TransparentEnabled" -Type DWord -Value 1 | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" `
    -ValueName "ExecutableTypes" -Type MultiString `
    -Value @(".exe") | Out-Null

# Create path rule for Downloads
$ruleGuid = [guid]::NewGuid().ToString("B")
$rulePath = "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths\$ruleGuid"

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key $rulePath `
    -ValueName "ItemData" -Type String `
    -Value "C:\Users\*\Downloads\*.exe" | Out-Null

Set-GPRegistryValue -Name $RestrictedGPOName `
    -Key $rulePath `
    -ValueName "SaferFlags" -Type DWord -Value 0x0 | Out-Null

Write-Host "Restricted Users GPO configured"

# -- Enterprise Certificate Authority Provisioning ----------------------------
Write-Host "Installing ADCS Feature and Creating Certificate"

# 1. Install the feature binaries locally
Install-WindowsFeature -Name 'ADCS-Cert-Authority' -IncludeManagementTools | Out-Null

# 2. Build credentials for the dedicated PKI Admin defined in win-data.psd1
$pkiPass = ConvertTo-SecureString $PKIAdminPassword -AsPlainText -Force
$pkiCred = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$PKIAdminUsername", $pkiPass)

# 3. Execute the installation block as the Enterprise Admin
Invoke-Command -ComputerName localhost -Credential $pkiCred -ScriptBlock {
    Import-Module ADCSDeployment -ErrorAction Stop
    
    Install-AdcsCertificationAuthority `
        -CAType                 EnterpriseRootCA    `
        -CACommonName           'DOMAIN404-Root-CA' `
        -CryptoProviderName     'RSA#Microsoft Software Key Storage Provider' `
        -KeyLength              4096                `
        -HashAlgorithmName      SHA256              `
        -ValidityPeriod         Years               `
        -ValidityPeriodUnits    10                  `
        -DatabaseDirectory      'C:\Windows\System32\CertLog' `
        -LogDirectory           'C:\Windows\System32\CertLog' `
        -Force
} | Out-Null

Write-Host "Enterprise CA successfully provisioned"

# -- Automated Reverse Proxy Certificate Provisioning -------------------------
Write-Host "Starting Automated Reverse Proxy Certificate Provisioning..."

$SourceKey = $ProxyCertKeySource
$SecureKey = "$env:USERPROFILE\.ssh\$(Split-Path -Leaf $SourceKey)"

# 1. Secure the SSH Key locally on the DC
Write-Host "Securing SSH Key..."
if (-not (Test-Path "$env:USERPROFILE\.ssh")) { New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" | Out-Null }
Copy-Item $SourceKey $SecureKey -Force
icacls $SecureKey /inheritance:r /grant "$($env:USERNAME):F" | Out-Null

# 2. Test Connection (Single Attempt)
Write-Host "Checking if Reverse Proxy is reachable via SSH..."

$proxyIsUp = $false
try {
    # If this fails, the script jumps straight to 'catch' instead of exiting
    $sshTest = ssh -i $SecureKey -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o LogLevel=ERROR ${ProxyUser}@${ProxyIP} "echo READY" 2>$null
    
    if ($sshTest -match "READY") {
        $proxyIsUp = $true
    }
} catch {
    # We catch the 'Stop' error here so the script can keep moving
    $proxyIsUp = $false
}

if (-not $proxyIsUp) {
    Write-Host "Notice: Reverse Proxy is not reachable. Skipping certificate automation." -ForegroundColor Yellow
} else {
    Write-Host "Starting certificate provisioning..." -ForegroundColor Green
    
    if (-not (Test-Path "C:\certs")) { New-Item -ItemType Directory -Path "C:\certs" | Out-Null }

    # 3. Generate CSR Remotely via SSH (Stripping Windows Line Endings)
    $cmdGenerate = @"
sudo mkdir -p /etc/nginx/ssl
sudo mkdir -p /certs
sudo chown vagrant:vagrant /certs
sudo openssl req -new -newkey rsa:2048 -nodes -keyout /etc/nginx/ssl/nginx_selfsigned.key -out /certs/reverseproxy.csr -subj "/C=BE/ST=Flanders/L=Ghent/O=Domain404/CN=t02-domain404.internal" -addext "subjectAltName=DNS:t02-domain404.internal,DNS:www.t02-domain404.internal,DNS:nextcloud.t02-domain404.internal,IP:192.168.132.234" 2>/dev/null
"@
    # Fix the line endings on the fly!
    $cmdGenerate = $cmdGenerate -replace "`r", ""
    ssh -i $SecureKey -o StrictHostKeyChecking=no -o LogLevel=ERROR ${ProxyUser}@${ProxyIP} $cmdGenerate | Out-Null

    # 4. Pull CSR to the DC
    Write-Host "Pulling CSR from Reverse Proxy..."
    scp -i $SecureKey -o StrictHostKeyChecking=no -o LogLevel=ERROR "${ProxyUser}@${ProxyIP}:/certs/reverseproxy.csr" "C:\certs\reverseproxy.csr" | Out-Null

    # SAFETY CHECK: Don't hang if the file is missing!
    if (-not (Test-Path "C:\certs\reverseproxy.csr")) {
        Write-Host "Error: CSR was not downloaded. Aborting to prevent certreq from hanging." -ForegroundColor Red
    } else {
        # 5. Sign Certificate against the CA (Using WinRM Loopback)
        Write-Host "Signing Certificate locally on DC as SVC_PKIAdmin..."
        $CA_Config = "$env:COMPUTERNAME\DOMAIN404-Root-CA"
        
        # Setup credentials for your Service Account
        $pkiSecString = ConvertTo-SecureString $PKIAdminPassword -AsPlainText -Force
		$pkiCreds     = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$PKIAdminUsername", $pkiSecString)

        # Grant the Service Account permission to read/write in the certs folder!
        icacls "C:\certs" /grant "DOMAIN404\SVC_PKIAdmin:(OI)(CI)F" /T | Out-Null

        Write-Host "Executing certreq via Invoke-Command..." -ForegroundColor Cyan
        
        # Use Invoke-Command to create a proper background logon session
        Invoke-Command -ComputerName localhost -Credential $pkiCreds -ScriptBlock {
            # Note the $using: modifier to pull the variable into the remote session
            certreq -q -submit -config $using:CA_Config -attrib "CertificateTemplate:WebServer" C:\certs\reverseproxy.csr C:\certs\reverseproxy.cer | Out-Null
        }

        # SAFETY CHECK 2: Did the certificate actually get created?
        if (-not (Test-Path "C:\certs\reverseproxy.cer")) {
            Write-Host "CRITICAL ERROR: certreq failed to create the certificate!" -ForegroundColor Red
            exit 1  # Abort the script so we don't crash Nginx!
        } else {
            # 6. Push Certificate back to Proxy
            Write-Host "Pushing signed Certificate back to Reverse Proxy..."
            scp -i $SecureKey -o StrictHostKeyChecking=no -o LogLevel=ERROR "C:\certs\reverseproxy.cer" "${ProxyUser}@${ProxyIP}:/certs/reverseproxy.cer" | Out-Null

            # 7. Apply Configuration Remotely via SSH
            Write-Host "Applying Certificate and restarting Nginx on Reverse Proxy..."
            $cmdApply = @"
sudo mkdir -p /etc/nginx/ssl
sudo cp /certs/reverseproxy.cer /etc/nginx/ssl/nginx_selfsigned.crt
sudo chmod 600 /etc/nginx/ssl/nginx_selfsigned.key
sudo chmod 644 /etc/nginx/ssl/nginx_selfsigned.crt
sudo sed -i 's|ssl_certificate \".*\";|ssl_certificate \"/etc/nginx/ssl/nginx_selfsigned.crt\";|g' /opt/nginx/conf/nginx.conf
sudo sed -i 's|ssl_certificate_key \".*\";|ssl_certificate_key \"/etc/nginx/ssl/nginx_selfsigned.key\";|g' /opt/nginx/conf/nginx.conf
sudo systemctl restart nginx
"@
            $cmdApply = $cmdApply -replace "`r", ""
            ssh -i $SecureKey -o StrictHostKeyChecking=no -o LogLevel=ERROR ${ProxyUser}@${ProxyIP} $cmdApply | Out-Null

            Write-Host "Reverse Proxy Certificate Provisioning Complete!" -ForegroundColor Green
        }
    }
}

# -- Apply Network Fix --------------------------------------------------------
Invoke-NetworkFix -Gateway $dcGateway

# -- Cleanup the local provisioning folder ----------------------------
Write-Host "Cleaning up"

# Forcefully remove the local C:\provisioning folder and all its contents
Remove-Item -Path "C:\provisioning" -Recurse -Force -ErrorAction SilentlyContinue

# -- Script Completion --------------------------------------------------------
Write-Host ""
Write-Host "  +-------------------------------------------------+"
Write-Host "  |                                                 |"
Write-Host "  |      Windows DomainController Ready!            |"
Write-Host "  |                                                 |"
Write-Host "  +-------------------------------------------------+"
Write-Host ""

exit 0
