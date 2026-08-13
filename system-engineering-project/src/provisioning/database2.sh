#! /bin/bash
#
# Provisioning script for database 2
#
# Author: D. Cooreman - dean.cooreman@student.hogent.be / G. Lescur - guillaume.lescur@student.hogent.be
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

# Trusted access
readonly webserver_ip='192.168.132.196'

#Galera Cluster settings
readonly db_node_ip='192.168.132.200'
readonly db_node_name="${HOSTNAME}"
readonly db_cluster_nodes='192.168.132.195,192.168.132.200'
readonly db_cluster_network='192.168.132.192/27'

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

# Predicate that returns exit status 0 if the database root password
# is not set, a nonzero exit status otherwise.
is_mysql_root_password_empty() {
  mysqladmin --user=root status > /dev/null 2>&1
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

log "Installing MariaDB server and Galera"

install_package mariadb-server galera
success "MariaDB server successfully installed"

log "Enabling the MariaDB service"

run systemctl enable mariadb.service
success "MariaDB service successfully enabled"

log "Configuring Galera cluster"

cat > /etc/my.cnf.d/galera.cnf <<EOF
[mysqld]
binlog_format=ROW
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2

# Galera
wsrep_on=ON
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_name="domain404_cluster"
wsrep_cluster_address="gcomm://${db_cluster_nodes}"

wsrep_node_address="${db_node_ip}"
wsrep_node_name="${db_node_name}"
wsrep_sst_auth="sst_user:YourSSTPassword"

wsrep_sst_method=rsync
EOF

success "Galera configuration written"

log "Configuring firewall"

# Drop all firewall rules and add ssh and mysql

run firewall-cmd --set-default-zone=public
run firewall-cmd --add-service=ssh --permanent
# Only accept mysql connections from the webserver
run firewall-cmd --add-rich-rule="rule family='ipv4' source address='${webserver_ip}' service name='mysql' accept" --permanent
# Reload the firewall to apply the rules
run firewall-cmd --reload
success "Firewall successfully configured"

log "Configuring Galera firewall rules"

# Allow Galera cluster communication
run firewall-cmd --add-rich-rule="rule family='ipv4' source address='${db_cluster_network}' port port='4567' protocol='tcp' accept" --permanent
run firewall-cmd --add-rich-rule="rule family='ipv4' source address='${db_cluster_network}' port port='4567' protocol='udp' accept" --permanent
run firewall-cmd --add-rich-rule="rule family='ipv4' source address='${db_cluster_network}' port port='4568' protocol='tcp' accept" --permanent
run firewall-cmd --add-rich-rule="rule family='ipv4' source address='${db_cluster_network}' port port='4444' protocol='tcp' accept" --permanent
run firewall-cmd --add-rich-rule="rule family='ipv4' source address='${db_cluster_network}' port port='3306' protocol='tcp' accept" --permanent

run firewall-cmd --reload

success "Galera firewall rules configured"

log "Creating database and user"

bash /vagrant/provisioning/cluster-init.sh

log "Applying network fix"

bash ${PROVISIONING_SCRIPTS}/networkfix.sh

echo ""
echo "  +-------------------------------------------------+"
echo "  |                                                 |"
echo "  |               Database — Ready!                 |"
echo "  |                                                 |"
echo "  |  Host  : ${HOSTNAME}                               |"
echo "  |  Group : t02-domain404.internal                 |"
echo "  |                                                 |"
echo "  +-------------------------------------------------+"
echo ""
