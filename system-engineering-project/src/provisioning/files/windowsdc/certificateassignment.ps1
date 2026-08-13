# ================== VARIABLES ==================

# --- Domain / CA ---
$DomainNetbiosName = "DOMAIN404"
$PKIAdminUsername  = "SVC_PKIAdmin"
$PKIAdminPassword  = "Str0ng-PKI-P@ss!"
$CACommonName      = "DOMAIN404-Root-CA"

# --- Reverse Proxy ---
$ProxyIP            = "192.168.132.234"
$ProxyUser          = "vagrant"
$ProxyCertKeySource = Join-Path $PSScriptRoot "proxy_cert_key"

# --- Certificate Details ---
$CertCN  = "t02-domain404.internal"
$CertSAN = "DNS:t02-domain404.internal,DNS:www.t02-domain404.internal,DNS:nextcloud.t02-domain404.internal,IP:192.168.132.234"

# --- Retry Settings ---
$RetryDelaySeconds = 10

# ===============================================================


function Write-Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}


# ================== STEP 1: ENSURE ADCS ==================

Write-Log "Checking ADCS installation..." Cyan

$adcsFeature = Get-WindowsFeature ADCS-Cert-Authority

if (-not $adcsFeature.Installed) {
    Write-Log "ADCS not installed. Installing..." Yellow
    Install-WindowsFeature -Name 'ADCS-Cert-Authority' -IncludeManagementTools | Out-Null
}

$caExists = Get-Service -Name CertSvc -ErrorAction SilentlyContinue

if (-not $caExists) {
    Write-Log "CA not configured. Installing Enterprise Root CA..." Yellow

    $pkiPass = ConvertTo-SecureString $PKIAdminPassword -AsPlainText -Force
    $pkiCred = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$PKIAdminUsername", $pkiPass)

    Invoke-Command -ComputerName localhost -Credential $pkiCred -ScriptBlock {
        Import-Module ADCSDeployment -ErrorAction Stop

        Install-AdcsCertificationAuthority `
            -CAType              EnterpriseRootCA `
            -CACommonName        $using:CACommonName `
            -CryptoProviderName  'RSA#Microsoft Software Key Storage Provider' `
            -KeyLength           4096 `
            -HashAlgorithmName   SHA256 `
            -ValidityPeriod      Years `
            -ValidityPeriodUnits 10 `
            -DatabaseDirectory   'C:\Windows\System32\CertLog' `
            -LogDirectory        'C:\Windows\System32\CertLog' `
            -Force
    }

    Write-Log "CA installed successfully." Green
} else {
    Write-Log "CA already configured." Green
}


# ================== STEP 2: PREP SSH KEY ==================

Write-Log "Preparing SSH key..." Cyan

$SecureKey = "$env:USERPROFILE\.ssh\$(Split-Path -Leaf $ProxyCertKeySource)"

if (-not (Test-Path "$env:USERPROFILE\.ssh")) {
    New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" | Out-Null
}

Copy-Item $ProxyCertKeySource $SecureKey -Force
icacls $SecureKey /inheritance:r /grant "$($env:USERNAME):F" | Out-Null


# ================== STEP 3: RETRY LOOP ==================

while ($true) {

    Write-Log "Checking reverse proxy availability..." Cyan

    $proxyIsUp = $false

    try {
        $sshTest = ssh -i $SecureKey -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o LogLevel=ERROR ${ProxyUser}@${ProxyIP} "echo READY" 2>$null
        if ($sshTest -match "READY") { $proxyIsUp = $true }
    } catch {
        $proxyIsUp = $false
    }

    if (-not $proxyIsUp) {
        Write-Log "Proxy not reachable. Retrying in $RetryDelaySeconds seconds..." Yellow
        Start-Sleep $RetryDelaySeconds
        continue
    }

    Write-Log "Proxy reachable. Starting certificate provisioning..." Green

    if (-not (Test-Path "C:\certs")) {
        New-Item -ItemType Directory -Path "C:\certs" | Out-Null
    }

    # --- Generate CSR (only if no key exists yet) ---
    #
    # IMPORTANT: We check for an existing private key before running openssl.
    # If we unconditionally regenerate the key on every run, a re-run will
    # produce a new key that no longer matches any previously signed cert,
    # causing nginx to fail with SSL_CTX_use_PrivateKey errors.
    # Only generate a new key+CSR when there is no key present yet.
    #
    $cmdGenerate = @"
sudo mkdir -p /etc/nginx/ssl
sudo mkdir -p /certs
sudo chown ${ProxyUser}:${ProxyUser} /certs
if [ ! -f /etc/nginx/ssl/reverseproxy.key ]; then
    sudo openssl req -new -newkey rsa:2048 -nodes \
        -keyout /etc/nginx/ssl/reverseproxy.key \
        -out /certs/reverseproxy.csr \
        -subj "/C=BE/ST=Flanders/L=Ghent/O=Domain404/CN=$CertCN" \
        -addext "subjectAltName=$CertSAN" 2>/dev/null
    echo CSR_GENERATED
else
    sudo openssl req -new \
        -key /etc/nginx/ssl/reverseproxy.key \
        -out /certs/reverseproxy.csr \
        -subj "/C=BE/ST=Flanders/L=Ghent/O=Domain404/CN=$CertCN" \
        -addext "subjectAltName=$CertSAN" 2>/dev/null
    echo CSR_REUSED_KEY
fi
"@

    $cmdGenerate = $cmdGenerate -replace "`r", ""
    $csrOutput = ssh -i $SecureKey -o StrictHostKeyChecking=no -o LogLevel=ERROR ${ProxyUser}@${ProxyIP} $cmdGenerate

    if ($csrOutput -match "CSR_GENERATED") {
        Write-Log "New private key and CSR generated." Green
    } elseif ($csrOutput -match "CSR_REUSED_KEY") {
        Write-Log "Existing private key reused, fresh CSR generated." Yellow
    } else {
        Write-Log "CSR generation produced no confirmation output. Retrying..." Red
        Start-Sleep $RetryDelaySeconds
        continue
    }

    # --- Pull CSR ---
    Write-Log "Downloading CSR..." Cyan
    scp -i $SecureKey "${ProxyUser}@${ProxyIP}:/certs/reverseproxy.csr" "C:\certs\reverseproxy.csr" | Out-Null

    if (-not (Test-Path "C:\certs\reverseproxy.csr")) {
        Write-Log "CSR missing after download. Retrying..." Red
        Start-Sleep $RetryDelaySeconds
        continue
    }

    # --- Sign Certificate ---
    Write-Log "Signing certificate..." Cyan

    $CA_Config = "$env:COMPUTERNAME\$CACommonName"

    $pkiPass = ConvertTo-SecureString $PKIAdminPassword -AsPlainText -Force
    $pkiCred = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$PKIAdminUsername", $pkiPass)

    icacls "C:\certs" /grant "DOMAIN404\SVC_PKIAdmin:(OI)(CI)F" /T | Out-Null

    # Remove any stale cert and response file so certreq is forced to sign
    # the current CSR. Without this, certreq silently returns the old .cer
    # which no longer matches the current key, causing nginx to fail with
    # SSL_CTX_use_PrivateKey key values mismatch.
    if (Test-Path "C:\certs\reverseproxy.cer") { Remove-Item "C:\certs\reverseproxy.cer" -Force }
    if (Test-Path "C:\certs\reverseproxy.rsp") { Remove-Item "C:\certs\reverseproxy.rsp" -Force }

    Invoke-Command -ComputerName localhost -Credential $pkiCred -ScriptBlock {
        certreq -q -submit -config $using:CA_Config -attrib "CertificateTemplate:WebServer" C:\certs\reverseproxy.csr C:\certs\reverseproxy.cer | Out-Null
    }

    if (-not (Test-Path "C:\certs\reverseproxy.cer")) {
        Write-Log "Certificate signing failed. Retrying..." Red
        Start-Sleep $RetryDelaySeconds
        continue
    }

    # --- Push Cert ---
    Write-Log "Uploading certificate to proxy..." Cyan
    scp -i $SecureKey "C:\certs\reverseproxy.cer" "${ProxyUser}@${ProxyIP}:/certs/reverseproxy.cer" | Out-Null

    # --- Apply on Proxy ---
    Write-Log "Applying certificate on proxy and restarting Nginx..." Cyan

    $cmdApply = @"
sudo cp /certs/reverseproxy.cer /etc/nginx/ssl/reverseproxy.crt
sudo chown root:nginx /etc/nginx/ssl/reverseproxy.key
sudo chmod 600 /etc/nginx/ssl/reverseproxy.key
sudo chmod 644 /etc/nginx/ssl/reverseproxy.crt
sudo sed -i 's|ssl_certificate[[:space:]]*\".*\";|ssl_certificate "/etc/nginx/ssl/reverseproxy.crt";|g' /opt/nginx/conf/nginx.conf
sudo sed -i 's|ssl_certificate_key[[:space:]]*\".*\";|ssl_certificate_key "/etc/nginx/ssl/reverseproxy.key";|g' /opt/nginx/conf/nginx.conf
sudo systemctl restart nginx
"@

    $cmdApply = $cmdApply -replace "`r", ""
    ssh -i $SecureKey -o StrictHostKeyChecking=no -o LogLevel=ERROR ${ProxyUser}@${ProxyIP} $cmdApply | Out-Null

    Write-Log "SUCCESS: Certificate provisioning completed!" Green
    break
}