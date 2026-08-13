#! /bin/bash
#
# Provisioning script for the Nextcloud database server.
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
# Location of files to be copied to this server
readonly PROVISIONING_FILES="${PROVISIONING_SCRIPTS}/files/${HOSTNAME}"

export PROVISIONING_SCRIPTS PROVISIONING_FILES

# Debug mode: set to 1 to show full command output, 0 to suppress it
readonly DEBUG=1

# Database
readonly db_root_password='WeWillCrushThisProject404'
readonly db_name='nextcloud'
readonly db_user='nextcloud'
readonly db_password='GroupT02ForVictory'

# Trusted access
readonly nextcloud_server_ip='192.168.132.197'

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

log "Installing MariaDB server"

install_package mariadb-server
success "MariaDB server successfully installed"

log "Enabling the MariaDB service"

run systemctl enable --now mariadb.service
success "MariaDB service successfully enabled"

log "Configuring firewall"

# Drop all firewall rules and add ssh and mysql
run firewall-cmd --set-default-zone=drop
run firewall-cmd --add-service=ssh --permanent
# Only accept mysql connections from the Nextcloud server
run firewall-cmd --add-rich-rule="rule family='ipv4' source address='${nextcloud_server_ip}' service name='mysql' accept" --permanent
# Reload the firewall to apply the rules
run firewall-cmd --reload
success "Firewall successfully configured"

log "Applying database hardening"

if is_mysql_root_password_empty; then
run mysql <<_EOF_
  SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${db_root_password}');
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
_EOF_
fi
success "Database hardening successfully applied"

log "Creating database and user"

run mysql --user=root --password="${db_root_password}" <<_EOF_
  CREATE DATABASE IF NOT EXISTS ${db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
  GRANT ALL ON ${db_name}.* TO '${db_user}'@'${nextcloud_server_ip}' IDENTIFIED BY '${db_password}';
  FLUSH PRIVILEGES;
_EOF_
success "Database and user successfully created"

log "Applying network fix"

bash ${PROVISIONING_SCRIPTS}/networkfix.sh

echo ""
echo "  +-------------------------------------------------+"
echo "  |                                                 |"
echo "  |          Nextcloud Database — Ready!            |"
echo "  |                                                 |"
echo "  |  Host  : ${HOSTNAME}                    |"
echo "  |  Group : t02-domain404.internal                 |"
echo "  |                                                 |"
echo "  +-------------------------------------------------+"
echo ""
