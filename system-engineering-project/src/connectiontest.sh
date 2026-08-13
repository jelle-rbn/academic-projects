#!/usr/bin/env bash
# =============================================================================
# connectivity_test.sh - Lab Connectivity Diagnostic
# =============================================================================

# --- CONFIGURATION ---
HOSTNAME_VAL=$(hostname)
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

VLAN1Gateway="192.168.132.225"
VLAN11Gateway="192.168.132.233"
VLAN22Gateway="192.168.132.129"
VLAN33Gateway="192.168.132.193"
TFTPSERVER="192.168.132.227"
PROXYSERVER="192.168.132.234"
WINCLIENT="192.168.132.130"
WINDC="192.168.132.194"
DBSERVER="192.168.132.195"
WEBSERVER="192.168.132.196"
NAT_LAPTOP_IP="10.0.2.2"
INTERNET_IP="8.8.8.8"
INTERNET_IP2="1.1.1.1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/connectiontest_${HOSTNAME_VAL}_$(date +%Y%m%d_%H%M%S).log"
# -----------------------------------------------------------------------------

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
# -----------------------------------------------------------------------------

PING_COUNT=2
PING_TIMEOUT=2

# --- HELPERS ---

log() {
    local color="$1"; shift
    local msg="$*"
    echo -e "${color}${msg}${RESET}"
    echo -e "${msg}" | sed 's/\x1B\[[0-9;]*[mK]//g' >> "$LOG_FILE"
}

log_plain() {
    echo -e "$*"
    echo -e "$*" | sed 's/\x1B\[[0-9;]*[mK]//g' >> "$LOG_FILE"
}

separator() {
    log "$DIM" "------------------------------------------------------------"
}

header() {
    echo "" | tee -a "$LOG_FILE"
    log "$BOLD$CYAN" "============================================================"
    log "$BOLD$CYAN" "  $*"
    log "$BOLD$CYAN" "============================================================"
}

section() {
    echo "" | tee -a "$LOG_FILE"
    log "$BOLD$YELLOW" ">> $*"
    separator
}

ping_test() {
    local label="$1"
    local ip="$2"
    local route_info
    route_info=$(ip route get "$ip" 2>/dev/null | head -1 | sed 's/uid [0-9]*//' | xargs)
    if ping -c $PING_COUNT -W $PING_TIMEOUT "$ip" &>/dev/null; then
        log "$GREEN" "  [x]  ${label} (${ip}) - REACHABLE"
        log "$DIM"   "       route: ${route_info}"
    else
        log "$RED"   "  [ ]  ${label} (${ip}) - UNREACHABLE"
    fi
}

# --- SANITY CHECK ---
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}ERROR: This script must be run as root (sudo).${RESET}"
    exit 1
fi

# --- SCRIPT HEADER ---

echo "============================================================" > "$LOG_FILE"
echo " Connectivity Test Log"                                       >> "$LOG_FILE"
echo " Host     : $HOSTNAME_VAL"                                   >> "$LOG_FILE"
echo " Started  : $START_TIME"                                     >> "$LOG_FILE"
echo " Log file : $LOG_FILE"                                       >> "$LOG_FILE"
echo "============================================================" >> "$LOG_FILE"

header "Lab Connectivity Diagnostic"
log "$BOLD" "  Hostname : ${HOSTNAME_VAL}"
log "$BOLD" "  Started  : ${START_TIME}"
log "$DIM"  "  Log file : ${LOG_FILE}"

# --- INTERFACE INFO ---

section "Interface Information"

while IFS= read -r line; do
    iface=$(echo "$line" | awk '{print $2}')
    cidr=$(echo  "$line" | awk '{print $4}')
    ip_addr=${cidr%%/*}
    prefix=${cidr##*/}

    # Convert prefix to dotted netmask
    mask=$(python3 -c "
import ipaddress
n = ipaddress.ip_network('${ip_addr}/${prefix}', strict=False)
print(str(n.netmask))
" 2>/dev/null || echo "/${prefix}")

    # Look up gateway from NetworkManager for this interface
    conn=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null | head -1)
    if [ -n "$conn" ]; then
        gw=$(nmcli -g ipv4.gateway connection show "$conn" 2>/dev/null || true)
    else
        gw=""
    fi

    if [ -n "$gw" ]; then
        log "$RESET" "  ${iface}  →  ${ip_addr}  /  ${mask}  (gateway: ${gw})"
    else
        log "$RESET" "  ${iface}  →  ${ip_addr}  /  ${mask}  (no gateway set)"
    fi

done < <(ip -o -4 addr show | grep -v '127\.0\.0\.1')

# --- ROUTING TABLE ---

section "Routing Table"
log_plain "${DIM}$(ip route show)${RESET}"

# --- CONNECTIVITY TESTS ---

section "Connectivity Tests"
ping_test "VLAN1  Gateway    " "$VLAN1Gateway"
ping_test "VLAN11 Gateway    " "$VLAN11Gateway"
ping_test "VLAN22 Gateway    " "$VLAN22Gateway"
ping_test "VLAN33 Gateway    " "$VLAN33Gateway"
ping_test "TFTP Server       " "$TFTPSERVER"
ping_test "Proxy Server      " "$PROXYSERVER"
ping_test "Win Client        " "$WINCLIENT"
ping_test "Win DC            " "$WINDC"
ping_test "DB Server         " "$DBSERVER"
ping_test "Web Server        " "$WEBSERVER"
ping_test "NAT / Laptop      " "$NAT_LAPTOP_IP"
ping_test "Internet (8.8.8.8)" "$INTERNET_IP"
ping_test "Internet (1.1.1.1)" "$INTERNET_IP2"

# --- FOOTER ---

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo "" | tee -a "$LOG_FILE"
log "$BOLD$CYAN" "============================================================"
log "$BOLD$GREEN" "  DONE"
log "$DIM"        "  Host    : ${HOSTNAME_VAL}"
log "$DIM"        "  Started : ${START_TIME}"
log "$DIM"        "  Ended   : ${END_TIME}"
log "$DIM"        "  Log     : ${LOG_FILE}"
log "$BOLD$CYAN"  "============================================================"
echo "" | tee -a "$LOG_FILE"