# This script installs and configures WSUS for Windows Server

# Variables
$IP = "192.168.56.20"
$Gateway = "192.168.56.1" # Default gateway for VirtualBox NAT networks
$DNS = "8.8.8.8"

# Logging
Start-Transcript -Path C:\setup-log.txt

# Network & internet
New-NetIPAddress -InterfaceAlias "Ethernet" `
-IPAddress "$IP" `
-PrefixLength 24 `
-DefaultGateway "$Gateway" `
-ErrorAction SilentlyContinue

Set-DnsClientServerAddress  `
  -InterfaceAlias "Ethernet"  `
  -ServerAddresses "$DNS"  `
  -ErrorAction SilentlyContinue

# Open firewall for port 8530
New-NetFirewallRule -DisplayName "WSUS 8530" -Direction Inbound -Protocol TCP -LocalPort 8530 -Action Allow

# Open firewall for ICMPv4 (Ping)
Enable-NetFirewallRule -Name "FPS-ICMP4-ERQ-In"

# Install WSUS
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools

# WSUS directory
New-Item -ItemType Directory -Path C:\WSUS -Force

# Post install
& "C:\Program Files\Update Services\Tools\wsusutil.exe" postinstall CONTENT_DIR=C:\WSUS

# Start service
Start-Service WsusService

# Check
Get-Service WsusService

Stop-Transcript