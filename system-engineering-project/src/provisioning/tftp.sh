#! /bin/bash
#
# Provisioning script for tftp
#
# Author: J. Robyn - jelle.robyn@student.hogent.be

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

# TFTP configuration
readonly tftpdir="/var/lib/tftpboot"
readonly tftpdir_backup="${tftpdir}/upload"
readonly tftp_user="tftp"
readonly tftp_group="tftp"

# Systemd drop-in configuration
readonly SYSTEMD_DROPIN_DIR="/etc/systemd/system/tftp.service.d"
readonly SYSTEMD_DROPIN_FILE="${SYSTEMD_DROPIN_DIR}/override.conf"

#------------------------------------------------------------------------------
# "Imports"
#------------------------------------------------------------------------------

# Utility functions
source ${PROVISIONING_SCRIPTS}/util.sh

# Actions/settings common to all servers
source ${PROVISIONING_SCRIPTS}/common.sh

#------------------------------------------------------------------------------
# Provision server
#------------------------------------------------------------------------------

info "Starting server specific provisioning tasks on ${HOSTNAME}"
info "Using provisioning directory: ${PROVISIONING_SCRIPTS}"


# 1. INSTALLATION

log "Installing TFTP Server components..."
log "This might take a while..."

#sudo dnf upgrade -y -q > /dev/null
sudo dnf install tftp-server tftp -y -q > /dev/null

success "TFTP components installed."


# 2. SERVICE CONFIG

log "Configuring TFTP service..."

# Make directory for drop-in config
mkdir -p "${SYSTEMD_DROPIN_DIR}"

# Use temporary file to check if config needs an update
TEMP_CONF=$(mktemp)
cat <<EOF > "${TEMP_CONF}"
[Service]
ExecStart=
ExecStart=/usr/sbin/in.tftpd -c -p -s ${tftpdir}
EOF

# Check for changes
if files_differ "${TEMP_CONF}" "${SYSTEMD_DROPIN_FILE}"; then
    # 'install' configures right owner (root) and permissions (644)
    sudo install -m 644 -o root -g root "${TEMP_CONF}" "${SYSTEMD_DROPIN_FILE}"
    # Reload systemd to make new config visible
    sudo systemctl daemon-reload
    # Restart service/socket to activate -c and -p flags
    sudo systemctl enable --now tftp.socket
    sudo systemctl restart tftp.service

    success "Service configuration updated and reloaded."
else
    debug "No configuration changes detected."
fi

rm "${TEMP_CONF}"


# 3. DIRECTORY STRUCTURE & FILES

log "Setting up directories..."

# Create the TFTP root & backup directory
mkdir -p "${tftpdir_backup}"

if [ -d "${PROVISIONING_FILES}" ] && [ "$(ls -A "${PROVISIONING_FILES}")" ]; then
    cp -r "${PROVISIONING_FILES}/." "${tftpdir}/"
    success "Configuration files copied to root."
else
    warn "No configuration files found to copy at ${PROVISIONING_FILES}"
fi

log "Checking required TFTP config files..."

ensure_file_exists "${tftpdir_backup}/router"
ensure_file_exists "${tftpdir_backup}/switch"


# 4. USERS & PERMISSIONS

log "Creating users and setting permissions..."

ensure_group_exists "${tftp_group}"
ensure_user_exists "${tftp_user}" -g "${tftp_group}" -s /sbin/nologin -c "TFTP Server"
usermod -g "${tftp_group}" -d "${tftpdir}" -s /sbin/nologin "${tftp_user}"

# Set owner recursive for all (including backup dir)
chown -R "${tftp_user}:${tftp_group}" "${tftpdir}"
# Permissions: 777 for root and for upload (needed for executing 'put')
chmod 777 "${tftpdir}"
chmod 777 "${tftpdir_backup}"
# Permissions: 666 for both backup configs, no X-permissions needed
chmod 666 "${tftpdir_backup}/router"
chmod 666 "${tftpdir_backup}/switch"

success "Permissions and ownership set."


# 5. SELINUX

log "Applying SELinux context..."

# SELINUX - Allow TFTP to write to its directory
ensure_sebool "tftp_anon_write"  >/dev/null
# SELINUX - Register tftp directory in SELinux database with read/write permissions
ensure_fcontext "public_content_rw_t" "${tftpdir}" >/dev/null 2>&1
ensure_fcontext "public_content_rw_t" "${tftpdir_backup}" >/dev/null 2>&1

success "SELinux context applied."


# 6. FIREWALL

log "Configuring firewall..."

# Ensure firewalld is running
systemctl enable --now firewalld >/dev/null
# Remove standard services that are not used
sudo firewall-cmd --permanent --remove-service=cockpit >/dev/null 2>&1
# Add TFTP service to the default zone
sudo firewall-cmd --permanent --add-service=tftp >/dev/null
# Apply changes
sudo firewall-cmd --reload >/dev/null

# Reload TFTP and start the service via socket
sudo systemctl enable --now tftp.socket >/dev/null 2>&1


# 7. NETWORK

log "Configuring network..."

# Import network fix script
bash ${PROVISIONING_SCRIPTS}/networkfix.sh


# 8. REBOOT CHECK

# Check if reboot is required (= kernel update), -r flag = reboot
# This command compares the active kernel to the new installed version
if sudo needs-restarting -r > /dev/null 2>&1; then
    success "System is up to date."
else
    warn "Kernel update detected: system requires a reboot!"
fi

info "--- Provisioning finished, TFTP server ready! ---"