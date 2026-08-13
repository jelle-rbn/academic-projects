#! /bin/bash
#
# Provisioning script for the NetBox server.
#
# Author: D. Cooreman - dean.cooreman@student.hogent.be
#
# Discontinued - Not enough time left to finish.

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

readonly NETBOX_VERSION=""

# Debug mode: set to 1 to show full command output, 0 to suppress it
readonly DEBUG=1

#------------------------------------------------------------------------------
# Package arrays
#------------------------------------------------------------------------------

readonly dependencies=(

)

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

# Install dependencies

# Install and configure Valkey/Redis

# Download and extract NetBox

# Configure NetBox

# Run NetBox database migrations

# Create NetBox superuser

# Collect static files

# Install and configure Gunicorn

# Install and configure Nginx

# Configure firewall

# Configure SELinux

# Configure LDAP/AD authentication

# Apply network fix

log "Applying network fix"

bash ${PROVISIONING_SCRIPTS}/networkfix.sh

echo ""
echo "  +-------------------------------------------------+"
echo "  |                                                 |"
echo "  |            NetBox Server — Ready!               |"
echo "  |                                                 |"
echo "  |  Host  : ${HOSTNAME}                            |"
echo "  |  Group : t02-domain404.internal                 |"
echo "  |                                                 |"
echo "  +-------------------------------------------------+"
echo ""
