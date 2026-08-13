#! /bin/bash
#
# Provisioning script for database
#
# Author: G. Lescur - guillaume.lescur@student.hogent.be

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
# Location of files to be copied to this server
readonly PROVISIONING_FILES="${PROVISIONING_SCRIPTS}/files/${HOSTNAME}"

export PROVISIONING_SCRIPTS PROVISIONING_FILES

# Debug mode: set to 1 to show full command output, 0 to suppress it
readonly DEBUG=0

setsebool -P haproxy_connect_any 1

# Trusted access
readonly webserver_ip='192.168.132.196'

#------------------------------------------------------------------------------
# "Imports"
#------------------------------------------------------------------------------

# Utility functions
source ${PROVISIONING_SCRIPTS}/util.sh
# Actions/settings common to all servers
source ${PROVISIONING_SCRIPTS}/common.sh

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

log "Installing HaProxy and MariaDb"

install_package haproxy mariadb

success "HaProxy and MariaDb successfully installed"


log "Configuring HaProxy configuration"

if [ ! -s /etc/haproxy/haproxy.cfg ]; then
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 4096

defaults
    log     global
    mode    tcp
    timeout connect 10s
    timeout client  1m
    timeout server  1m
EOF
fi

if ! grep -q "frontend mysql_front" /etc/haproxy/haproxy.cfg; then
cat >> /etc/haproxy/haproxy.cfg <<EOF

frontend mysql_front
    bind *:3306
    mode tcp
    default_backend mysql_back

backend mysql_back
    mode tcp
    balance roundrobin
    option mysql-check user haproxy_check
    server db1 192.168.132.195:3306 check
    server db2 192.168.132.200:3306 check

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /
    stats refresh 5s
EOF
fi

success "HaProxy configuration written"

log "Configuring firewall"

# Drop all firewall rules
run firewall-cmd --set-default-zone=public
# Only accept mysql connections from the webserver
run firewall-cmd --add-port=8404/tcp --permanent
run firewall-cmd --add-rich-rule="rule family='ipv4' source address='${webserver_ip}' service name='mysql' accept" --permanent
# Reload the firewall to apply the rules
run firewall-cmd --reload
success "Firewall successfully configured"

log "Manually enable and start HaProxy"
sudo systemctl enable haproxy
sudo systemctl start haproxy

log "Applying network fix"

bash ${PROVISIONING_SCRIPTS}/networkfix.sh


echo ""
echo "  +-------------------------------------------------+"
echo "  |                                                 |"
echo "  |               HaProxy — Ready!                 |"
echo "  |                                                 |"
echo "  |  Host  : ${HOSTNAME}                               |"
echo "  |  Group : t02-domain404.internal                 |"
echo "  |                                                 |"
echo "  +-------------------------------------------------+"
echo ""
