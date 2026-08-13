# ----------------------------------------------------------------------------------------
# Variabelen (PADEN CONTROLEREN!)
# ----------------------------------------------------------------------------------------
 
# VM configs
$TARGET_NAME = "WSUS-Target"
$KALI_NAME = "Kali-Linux"
$NET_NAME = "NPE_NAT"
$GATEWAY = "192.168.56.1"
$NET_IP = "192.168.56.0/24"
$WIN_ADDR = "192.168.56.10"
$KALI_ADDR = "192.168.56.20"
$WIN_USER = "Administrator"
$WIN_PASS = "P@ssw0rd!"
 
# Paden "Master VDI" bestanden
$MASTER_TARGET_VDI = "$env:USERPROFILE\CySec-NPE\WSUS-Target.vdi"
$MASTER_KALI_VDI = "$env:USERPROFILE\CySec-NPE\kali-linux-2026.1-virtualbox-amd64.vdi"
 
# Werkmappen
$TARGET_DIR = "$env:USERPROFILE\VirtualBox VMs\$TARGET_NAME"
$KALI_DIR = "$env:USERPROFILE\VirtualBox VMs\$KALI_NAME"
 
# Scripts
$WSUS_SCRIPT = "$env:USERPROFILE\CySec-NPE\scripts\setup-wsus.ps1"
$PICKLE_SCRIPT = "$env:USERPROFILE\CySec-NPE\scripts\setup-pickle.ps1"
$EXPLOIT_SCRIPT = "$env:USERPROFILE\CySec-NPE\scripts\exploit-python.py"
 
# ----------------------------------------------------------------------------------------
# 1. Opruimen & netwerk voorbereiden
# ----------------------------------------------------------------------------------------
 
Write-Host "Shutting down and removing any existing VM's..." -ForegroundColor Cyan
 
foreach ($vm in @($TARGET_NAME, $KALI_NAME)) {
    VBoxManage controlvm "$vm" poweroff 2>$null
    VBoxManage unregistervm "$vm" --delete 2>$null
}
 
Write-Host "Preparing network..." -ForegroundColor Cyan
Write-Host "Creating a NAT-network adapter for this lab..." -ForegroundColor Cyan
 
VBoxManage natnetwork remove --netname "$NET_NAME" 2>$null
VBoxManage natnetwork add --netname "$NET_NAME" --network "$NET_IP" --enable --dhcp off
 
Write-Host "[OK] NAT-Network '$NET_NAME' created" -ForegroundColor Green
 
# ----------------------------------------------------------------------------------------
# 2. Klonen en registreren
# ----------------------------------------------------------------------------------------
 
Write-Host "Cloning VDI's en registrating VM's..." -ForegroundColor Cyan
 
function Create-LabVM($Name, $Dir, $MasterVdi, $OsType) {
    if (Test-Path $Dir) { Remove-Item $Dir -Recurse -Force }
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    $diskPath = Join-Path $Dir "$Name.vdi"
 
    Write-Host "Copying VDI for $Name..." -ForegroundColor Cyan
    Copy-Item $MasterVdi $diskPath
   
    VBoxManage createvm --name "$Name" --ostype $OsType --register
    VBoxManage modifyvm "$Name" --memory 4096 --cpus 2 --graphicscontroller VBoxSVGA `
        --nic1 natnetwork --nat-network1 "$NET_NAME" --cableconnected1 on
   
    VBoxManage storagectl "$Name" --name "SATA" --add sata
    VBoxManage storageattach "$Name" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$diskPath"
}
 
Create-LabVM $TARGET_NAME $TARGET_DIR $MASTER_TARGET_VDI "Windows2022_64"
Create-LabVM $KALI_NAME $KALI_DIR $MASTER_KALI_VDI "Debian_64"
 
# ----------------------------------------------------------------------------------------
# 3. Starten & configureren
# ----------------------------------------------------------------------------------------
 
Write-Host "Starting and configuring machines..." -ForegroundColor Cyan
 
VBoxManage startvm "$KALI_NAME" --type gui
VBoxManage startvm "$TARGET_NAME" --type gui
 
$TotalSeconds = 120
$TargetTime = (Get-Date).AddSeconds($TotalSeconds)

Write-Host "[i] Initializing boot sequence..." -ForegroundColor Yellow

while ((Get-Date) -lt $TargetTime) {
    $TimeSpan = $TargetTime - (Get-Date)
    $Countdown = "{0:mm\:ss}" -f $TimeSpan
    Write-Host "`r[i] Waiting for boot: $Countdown remaining... " -NoNewline -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}

Write-Host "`r[i] Proceeding to next step...                            " -ForegroundColor Yellow
 
# Windows
Write-Host "Setting static IP on Windows ($WIN_ADDR)..." -ForegroundColor Cyan
 
$winIPCmd = @"
Get-NetAdapter | Set-NetIPInterface -Dhcp Disabled
New-NetIPAddress -InterfaceIndex (Get-NetAdapter).ifIndex -IPAddress "$WIN_ADDR" -PrefixLength 24 -DefaultGateway "$GATEWAY" -ErrorAction SilentlyContinue
Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter).ifIndex -ServerAddresses ("8.8.8.8")
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
"@
VBoxManage guestcontrol "$TARGET_NAME" run --username "$WIN_USER" --password "$WIN_PASS" --exe "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -- -Command "$winIPCmd"
 
# Kali
Write-Host "Setting static IP on Kali ($KALI_ADDR)..." -ForegroundColor Cyan
 
$kaliIPCmd = "echo 'kali' | sudo -S bash -c 'nmcli device set eth0 managed no && ip addr flush dev eth0 && ip addr add $KALI_ADDR/24 dev eth0 && ip link set eth0 up && ip route add default via $GATEWAY'"
 
VBoxManage guestcontrol "$KALI_NAME" run --username kali --password kali --exe "/bin/bash" -- -c "$kaliIPCmd"
 
# ----------------------------------------------------------------------------------------
# 4. Payload & setup
# ----------------------------------------------------------------------------------------
 
# Uploaden scripts
Write-Host "`nUploading scripts to machines..." -ForegroundColor Cyan
VBoxManage guestcontrol "$TARGET_NAME" copyto "$WSUS_SCRIPT" "C:\setup-wsus.ps1" --username "$WIN_USER" --password "$WIN_PASS"
VBoxManage guestcontrol "$TARGET_NAME" copyto "$PICKLE_SCRIPT" "C:\setup-pickle.ps1" --username "$WIN_USER" --password "$WIN_PASS"
VBoxManage guestcontrol "$KALI_NAME" copyto "$EXPLOIT_SCRIPT" "/home/kali/exploit-python.py" --username kali --password kali
 
Write-Host "Setting permissions on Kali script..." -ForegroundColor Cyan
$permCmd = "echo 'kali' | sudo -S chown kali:kali /home/kali/exploit-python.py && chmod +x /home/kali/exploit-python.py"
VBoxManage guestcontrol "$KALI_NAME" run --username kali --password kali --exe "/bin/bash" -- -c "$permCmd"
 
Write-Host "`n[i] Executing setups on Windows (this could take a while)..." -ForegroundColor Yellow
$setups = @("C:\setup-wsus.ps1", "C:\setup-pickle.ps1")
foreach ($s in $setups) {
    Write-Host "  -> Running $s" -ForegroundColor White
    VBoxManage guestcontrol "$TARGET_NAME" run --username "$WIN_USER" --password "$WIN_PASS" --exe "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -- -Command "Set-ExecutionPolicy Bypass -Force; & $s"
}
 
# ----------------------------------------------------------------------------------------
# 5a. Wachten tot alle services zeker opgestart zijn op target VM
# ----------------------------------------------------------------------------------------

$TotalMinutes = 10
$EndTime = (Get-Date).AddMinutes($TotalMinutes)

while ((Get-Date) -lt $EndTime) {
    $TimeLeft = $EndTime - (Get-Date)
    $FormatTime = "{0:mm\:ss}" -f $TimeLeft
    
    # De `r zorgt dat de cursor naar het begin van de regel springt
    Write-Host "`r[i] Time remaining: $FormatTime on $TARGET_NAME... " -NoNewline -ForegroundColor Yellow
    
    Start-Sleep -Seconds 1
}

# ----------------------------------------------------------------------------------------
# 5b. Netwerk check
# ----------------------------------------------------------------------------------------
 
Write-Host "`nVerifying network status..." -ForegroundColor Cyan
 
function Extract-IP($rawString) {
    if ($rawString -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") {
        return $matches[0]
    }
    return $null
}
 
$winRaw = [string](VBoxManage guestcontrol "$TARGET_NAME" run --username "$WIN_USER" --password "$WIN_PASS" --exe "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -- -Command "(Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4).IPAddress")
$kaliRaw = [string](VBoxManage guestcontrol "$KALI_NAME" run --username kali --password kali --exe "/usr/bin/hostname" -- -I)
 
$WIN_IP = Extract-IP $winRaw
$KALI_IP = Extract-IP $kaliRaw
 


# ----------------------------------------------------------------------------------------
# 6. Overzicht labomgeving
# ----------------------------------------------------------------------------------------
 
# Controleer Windows IP, Kali IP en of poort 8000 daadwerkelijk open staat
if ($WIN_IP -and $KALI_IP) {
    Write-Host "`n[SUCCESS] Lab is fully operational!" -ForegroundColor Green
    Write-Host "-------------------------------------------" -ForegroundColor Green
    Write-Host "[i] Windows Target: $WIN_IP" -ForegroundColor Yellow
    Write-Host "[i] Kali Attacker:  $KALI_IP" -ForegroundColor Yellow
    Write-Host "-------------------------------------------" -ForegroundColor Green
}
else {
    Write-Host "`n[FAILED] Lab is not (yet) fully operational!" -ForegroundColor Red
    Write-Host "-------------------------------------------" -ForegroundColor Red
    
    # Specifieke foutmeldingen debugging:
    if (-not $WIN_IP) { Write-Host "[-] Missing: Windows IP (Guest Additions issue?)" -ForegroundColor Red }
    if (-not $KALI_IP) { Write-Host "[-] Missing: Kali IP (Guest Additions issue?)" -ForegroundColor Red }
    
    Write-Host "-------------------------------------------" -ForegroundColor Red
    Write-Host "[!] Check the error messages above and logs in the VM." -ForegroundColor Yellow
}
