# connectiontest.ps1 - Lab Connectivity Diagnostic
# =============================================================================

# --- CONFIGURATION ---
$VLAN1Gateway  = "192.168.132.225"
$VLAN11Gateway = "192.168.132.233"
$VLAN22Gateway = "192.168.132.129"
$VLAN33Gateway = "192.168.132.193"
$TFTPSERVER    = "192.168.132.227"
$PROXYSERVER   = "192.168.132.234"
$WINCLIENT     = "192.168.132.130"
$WINDC         = "192.168.132.194"
$DBSERVER      = "192.168.132.195"
$WEBSERVER     = "192.168.132.196"
$NAT_LAPTOP_IP = "10.0.2.2"
$INTERNET_IP   = "8.8.8.8"
$INTERNET_IP2  = "1.1.1.1"

$PING_COUNT   = 2
$PING_TIMEOUT = 2   # seconds
# -----------------------------------------------------------------------------

# --- SETUP ---
$HOSTNAME_VAL = $env:COMPUTERNAME
$START_TIME   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$SCRIPT_DIR   = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOG_FILE     = Join-Path $SCRIPT_DIR "connectiontest_${HOSTNAME_VAL}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# --- HELPERS ---

function Write-Log {
    param([string]$Color = "White", [string]$msg)
    Write-Host $msg -ForegroundColor $Color
    $msg | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
}

function Write-LogPlain {
    param([string]$msg)
    Write-Host $msg -ForegroundColor DarkGray
    $msg | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
}

function Write-Separator {
    Write-Log DarkGray "------------------------------------------------------------"
}

function Write-Header {
    param([string]$title)
    "" | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
    Write-Host ""
    Write-Log Cyan  "============================================================"
    Write-Log Cyan  "  $title"
    Write-Log Cyan  "============================================================"
}

function Write-Section {
    param([string]$title)
    "" | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
    Write-Host ""
    Write-Log Yellow ">> $title"
    Write-Separator
}

function Test-PingHost {
    param([string]$label, [string]$ip)

    try {
        $ping   = [System.Net.NetworkInformation.Ping]::new()
        $reply  = $ping.Send($ip, ($PING_TIMEOUT * 1000))   # timeout in ms
        $result = $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success
    } catch {
        $result = $false
    }

    if ($result) {
        Write-Log Green "  [x]  $label ($ip) - REACHABLE"
    } else {
        Write-Log Red   "  [ ]  $label ($ip) - UNREACHABLE"
    }
}

# --- SCRIPT HEADER ---
@"
============================================================
 Connectivity Test Log
 Host     : $HOSTNAME_VAL
 Started  : $START_TIME
 Log file : $LOG_FILE
============================================================
"@ | Out-File -FilePath $LOG_FILE -Encoding UTF8

Write-Header "Lab Connectivity Diagnostic"
Write-Log White   "  Hostname : $HOSTNAME_VAL"
Write-Log White   "  Started  : $START_TIME"
Write-Log DarkGray "  Log file : $LOG_FILE"

# --- INTERFACE INFO ---

Write-Section "Interface Information"

Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notmatch '^127\.' } |
    ForEach-Object {
        $iface  = $_.InterfaceAlias
        $ip     = $_.IPAddress
        $prefix = $_.PrefixLength

        # Convert prefix length to dotted netmask
        $bits  = [Convert]::ToUInt32("1" * $prefix + "0" * (32 - $prefix), 2)
        $bytes = [BitConverter]::GetBytes($bits)
        if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($bytes) }
        $mask  = ([System.Net.IPAddress]$bytes).ToString()

        # Read gateway configured on this adapter
        $gw = (Get-NetIPConfiguration -InterfaceAlias $iface `
            -ErrorAction SilentlyContinue).IPv4DefaultGateway.NextHop

        if ($gw) {
            Write-Log White "  $iface  ->  $ip  /  $mask  (gateway: $gw)"
        } else {
            Write-Log White "  $iface  ->  $ip  /  $mask  (no gateway set)"
        }
    }

# --- ROUTING TABLE ---

Write-Section "Routing Table"

Get-NetRoute -AddressFamily IPv4 |
    Where-Object { $_.DestinationPrefix -ne "255.255.255.255/32" } |
    Sort-Object InterfaceMetric, RouteMetric |
    ForEach-Object {
        $gw = if ($_.NextHop -and $_.NextHop -ne "0.0.0.0") { "via $($_.NextHop)" } else { "direct" }
        Write-LogPlain ("  {0,-22}  {1,-22}  dev {2}  metric {3}" -f `
            $_.DestinationPrefix, $gw, $_.InterfaceAlias, $_.RouteMetric)
    }

# --- CONNECTIVITY TESTS ---

Write-Section "Connectivity Tests"
Test-PingHost "VLAN1  Gateway       " $VLAN1Gateway
Test-PingHost "VLAN11 Gateway       " $VLAN11Gateway
Test-PingHost "VLAN22 Gateway       " $VLAN22Gateway
Test-PingHost "VLAN33 Gateway       " $VLAN33Gateway
Test-PingHost "TFTP Server          " $TFTPSERVER
Test-PingHost "Proxy Server         " $PROXYSERVER
Test-PingHost "Win Client           " $WINCLIENT
Test-PingHost "Win DC               " $WINDC
Test-PingHost "DB Server            " $DBSERVER
Test-PingHost "Web Server           " $WEBSERVER
Test-PingHost "NAT / Laptop                " $NAT_LAPTOP_IP
Test-PingHost "Internet (Google DNS)        " $INTERNET_IP
Test-PingHost "Internet (Cloudflare DNS)    " $INTERNET_IP2

# --- FOOTER ---

$END_TIME = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

"" | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
Write-Host ""
Write-Log Cyan     "============================================================"
Write-Log Green    "  DONE"
Write-Log DarkGray "  Host    : $HOSTNAME_VAL"
Write-Log DarkGray "  Started : $START_TIME"
Write-Log DarkGray "  Ended   : $END_TIME"
Write-Log DarkGray "  Log     : $LOG_FILE"
Write-Log Cyan     "============================================================"
"" | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8