# Dit script installeert en configureert WSUS voor Windows Server

# Variabelen
$IP = "192.168.56.20"
$Gateway = "192.168.56.1" # Standaard gateway voor VirtualBox NAT-netwerken
$DNS = "8.8.8.8"

# Logging
Start-Transcript -Path C:\setup-log.txt

# Netwerk & internet
New-NetIPAddress -InterfaceAlias "Ethernet" `
-IPAddress "$IP" `
-PrefixLength 24 `
-DefaultGateway "$Gateway" `
-ErrorAction SilentlyContinue

Set-DnsClientServerAddress  `
  -InterfaceAlias "Ethernet"  `
  -ServerAddresses "$DNS"  `
  -ErrorAction SilentlyContinue

# Firewall openzetten voor poort 8530
New-NetFirewallRule -DisplayName "WSUS 8530" -Direction Inbound -Protocol TCP -LocalPort 8530 -Action Allow

# Firewall openzetten voor ICMPv4 (Ping)
Enable-NetFirewallRule -Name "FPS-ICMP4-ERQ-In"

# WSUS installeren
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools

# WSUS directory
New-Item -ItemType Directory -Path C:\WSUS -Force

# Post install
& "C:\Program Files\Update Services\Tools\wsusutil.exe" postinstall CONTENT_DIR=C:\WSUS

# Service starten
Start-Service WsusService

# Check
Get-Service WsusService

Stop-Transcript