#! /bin/bash
#
# Network configuration - called at the end of every provisioning script.
#
# Detects onsite vs offsite mode by inspecting the prefix length of the
# 192.168.132.x interface that Vagrant configured:
#
#   /24  >  offsite (VirtualBox internal network, flat subnet)
#           NAT is already the default route and internet-capable.
#           All VMs are directly reachable - no routing changes needed.
#
#   /27, /29, …  >  onsite (bridged adapter, real VLAN subnets)
#           Gateway is derived automatically as network_address + 1.
#           NAT is demoted to metric 100 / never-default (Vagrant SSH only).
#           VLAN interface gets the read gateway and metric 50.

#------------------------------------------------------------------------------
# Bash settings
#------------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

source /vagrant/provisioning/util.sh

#------------------------------------------------------------------------------
# Detection
#------------------------------------------------------------------------------

log "Starting network configuration"

vlan_info="$(find_vlan_iface)"

if [ -z "${vlan_info}" ]; then
  error "No interface with a 192.168.132.x address found - skipping network config."
  exit 0
fi

read -r vlan_iface vlan_ip vlan_prefix <<< "${vlan_info}"

log "Detected: ${vlan_iface} > ${vlan_ip}/${vlan_prefix}"

# Fix SELinux contexts on NM connection files before modifying them
restorecon -Rv /etc/NetworkManager/system-connections > /dev/null 2>&1 || true

if [ "${vlan_prefix}" = "24" ]; then
  log "Offsite mode (/24) - clearing phantom gateway on ${vlan_iface}..."
  vlan_conn="$(get_conn_name "${vlan_iface}")"
  if [ -n "${vlan_conn}" ]; then
    nmcli connection modify "${vlan_conn}" ipv4.gateway "" > /dev/null
    nmcli connection down   "${vlan_conn}" > /dev/null
    nmcli connection up     "${vlan_conn}" > /dev/null
  fi
  log "Done - NAT remains the default route."
  exit 0
fi

log "Onsite mode (/${vlan_prefix}) - configuring routing..."

#------------------------------------------------------------------------------
# Interface discovery
#------------------------------------------------------------------------------

nat_iface="$(find_nat_iface)"

if [ -z "${nat_iface}" ]; then
  error "No NAT interface (10.0.2.x) found - cannot configure routing."
  exit 1
fi

vlan_conn="$(get_conn_name "${vlan_iface}")"
nat_conn="$(get_conn_name "${nat_iface}")"

if [ -z "${vlan_conn}" ] || [ -z "${nat_conn}" ]; then
  error "Could not resolve NetworkManager connection names (vlan='${vlan_conn}' nat='${nat_conn}')."
  exit 1
fi

log "NAT:  ${nat_iface} (connection: '${nat_conn}')"
log "VLAN: ${vlan_iface} (connection: '${vlan_conn}')"

#------------------------------------------------------------------------------
# Gateway derivation
#------------------------------------------------------------------------------

gateway=$(nmcli -g ipv4.gateway connection show "${vlan_conn}")

if [ -z "${gateway}" ]; then
  error "Gateway is not set on connection '${vlan_conn}' - was it defined in vagrant-hosts.yml?"
  exit 1
fi

log "Gateway: ${gateway}"

#------------------------------------------------------------------------------
# Apply configuration
#------------------------------------------------------------------------------

# NAT: keep active for Vagrant SSH but never use as the default route
nmcli connection modify "${nat_conn}" ipv4.never-default yes > /dev/null
nmcli connection modify "${nat_conn}" ipv4.route-metric 100 > /dev/null
nmcli connection down   "${nat_conn}" > /dev/null
nmcli connection up     "${nat_conn}" > /dev/null

# VLAN: assign the derived gateway and make it the preferred default route
nmcli connection modify "${vlan_conn}" ipv4.gateway      "${gateway}" > /dev/null
nmcli connection modify "${vlan_conn}" ipv4.route-metric 50 > /dev/null
nmcli connection down   "${vlan_conn}" > /dev/null
nmcli connection up     "${vlan_conn}" > /dev/null

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

log "Network configuration complete."
log "  ${nat_iface}  > metric 100, never-default  (Vagrant SSH + fallback)"
log "  ${vlan_iface} > ${vlan_ip}/${vlan_prefix} via ${gateway}, metric 50  (default route)"