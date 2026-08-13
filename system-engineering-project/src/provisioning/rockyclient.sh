#!/usr/bin/env bash
#
# Provisioning script for the Rocky Linux client.
#
# Author: D. Cooreman - dean.cooreman@student.hogent.be

#------------------------------------------------------------------------------
# Bash settings
#------------------------------------------------------------------------------

# Enable "Bash strict mode"
set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable
set -o pipefail  # don't mask errors in piped commands

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

# Location of provisioning scripts and files
readonly PROVISIONING_SCRIPTS="/vagrant/provisioning"

# Debug mode: set to 1 to show full command output, 0 to suppress it
readonly DEBUG=1

#------------------------------------------------------------------------------
# Package arrays
#------------------------------------------------------------------------------

readonly applications=(
  nextcloud-client
  firefox
  thunderbird
)

readonly cli_utilities=(
  curl
  wget
  git
  vim
  nmap
)

#------------------------------------------------------------------------------
# "Imports"
#------------------------------------------------------------------------------

# Utility functions
source "${PROVISIONING_SCRIPTS}/util.sh"
# Actions/settings common to all servers
source "${PROVISIONING_SCRIPTS}/common.sh"

#------------------------------------------------------------------------------
# "Functions"
#------------------------------------------------------------------------------

# Function that installs packages
install_package() {
  while [ "$#" -gt 0 ]; do
    if run dnf install -y -q "$1"; then
      success "$1 installed."
    else
      error "Failed to install $1."
      return 1
    fi
    shift
  done
}

# Runs a command, suppressing output unless DEBUG=1
run() {
  if [ "${DEBUG}" -eq 1 ]; then
    "$@"
  else
    "$@" > /dev/null 2>&1
  fi
}

#------------------------------------------------------------------------------
# Provision server
#------------------------------------------------------------------------------

log "Starting server specific provisioning tasks on ${HOSTNAME}"

log "Updating system packages"

run dnf update -y -q
success "System successfully updated"

log "Enabling EPEL"

run dnf install -y -q epel-release
success "EPEL successfully enabled"

log "Installing GNOME desktop"

run dnf groupinstall -y "Workstation"
run systemctl set-default graphical.target
run systemctl enable gdm
success "GNOME desktop successfully installed"

log "Configuring GDM autologin"

echo "vagrant:vagrant" | chpasswd
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf << 'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=vagrant
EOF
success "GDM autologin successfully configured"

log "Installing applications"

install_package "${applications[@]}"
success "Applications successfully installed"

log "Installing CLI utilities"

install_package "${cli_utilities[@]}"
success "CLI utilities successfully installed"

log "Configuring firewall"

run systemctl enable --now firewalld
run firewall-cmd --set-default-zone=drop
run firewall-cmd --add-service=ssh --permanent
run firewall-cmd --reload
success "Firewall successfully configured"

log "Configuring network routing"

vlan_info="$(find_vlan_iface)"
read -r vlan_iface vlan_ip vlan_prefix <<< "${vlan_info}"
vlan_conn="$(get_conn_name "${vlan_iface}")"

if [ "${vlan_prefix}" != "24" ]; then
  log "Onsite mode detected — switching to DHCP and configuring routing"

  nat_iface="$(find_nat_iface)"
  nat_conn="$(get_conn_name "${nat_iface}")"

  # VLAN: switch to DHCP and set preferred metric in one operation
  run nmcli connection modify "${vlan_conn}" \
    ipv4.method auto \
    ipv4.gateway "" \
    ipv4.addresses "" \
    ipv4.dns "" \
    ipv4.ignore-auto-dns no \
    ipv4.route-metric 50
  run nmcli connection down "${vlan_conn}"
  run nmcli connection up   "${vlan_conn}"

  # NAT: stay active for Vagrant SSH but never use as default route
  run nmcli connection modify "${nat_conn}" \
    ipv4.never-default yes \
    ipv4.route-metric 100
  run nmcli connection down "${nat_conn}"
  run nmcli connection up   "${nat_conn}"

  success "Routing fixed — VLAN is default route (metric 50), NAT is fallback (metric 100)"
else
  nat_iface="$(find_nat_iface)"
  nat_conn="$(get_conn_name "${nat_iface}")"

  # Suppress NAT DNS injection — Telenet servers would shadow the DC
  run nmcli connection modify "${nat_conn}" ipv4.ignore-auto-dns yes
  run nmcli connection down   "${nat_conn}"
  run nmcli connection up     "${nat_conn}"

  # Offsite — clear phantom gateway, set DC first for internal resolution
  run nmcli connection modify "${vlan_conn}" \
    ipv4.gateway "" \
    ipv4.dns "192.168.132.194 1.1.1.1 8.8.8.8" \
    ipv4.ignore-auto-dns yes
  run nmcli connection down "${vlan_conn}"
  run nmcli connection up   "${vlan_conn}"
  success "Network successfully configured — offsite/static mode"
fi

log "Rebooting to bring up GUI"

echo ""
echo "  +-------------------------------------------------+"
echo "  |                                                 |"
echo "  |          Rocky Linux Client — Ready!            |"
echo "  |                                                 |"
echo "  |  Host  : ${HOSTNAME}                            |"
echo "  |  Group : t02-domain404.internal                 |"
echo "  |                                                 |"
echo "  +-------------------------------------------------+"
echo ""

shutdown -r now || true
