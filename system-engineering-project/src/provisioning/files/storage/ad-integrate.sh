#! /bin/bash
# -----------------------------------------------------------------------------
# ad-integrate.sh  --  Post-Provisioning Active Directory Integration
# -----------------------------------------------------------------------------
# Executes the AD-dependent stages that were skipped during storage.sh
# provisioning when the domain controller was unreachable.
#
# Stages covered:
#   Stage 1  -- DNS verification
#   Stage 5  -- AD domain join, SPN registration, keytab generation
#   Stage 10 -- Samba/Winbind service startup and health check
#   Stage 10b-- Per-user home directory provisioning
#
# Safe to re-run: every stage is idempotent and checks its own current state
# before acting. Already-completed work is detected and skipped with a notice.
#
# Usage:
#   Run directly on the storage VM:
#     sudo bash /vagrant/provisioning/ad-integrate.sh
#
#   Or via vagrant from the host:
#     vagrant provision storage --provision-with ad-integrate
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

readonly PROVISIONING_SCRIPTS="/vagrant/provisioning"
export PROVISIONING_SCRIPTS

# -- Constants (must match storage.sh exactly) --------------------------------
readonly DOMAIN_NAME="ad.t02-domain404.internal"
readonly DOMAIN_UPPER="${DOMAIN_NAME^^}"
readonly WORKGROUP="DOMAIN404"
readonly DC_IP="192.168.132.194"
readonly JOIN_USER="SVC_DomainJoin"
readonly JOIN_PASS="Str0ng-J0in-P@ss!"
readonly TARGET_OU="OU=Infrastructure,OU=Servers,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal"
readonly STORAGE_GROUP_DN="CN=GRP_Storage_Users,OU=ACL,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal"

source "${PROVISIONING_SCRIPTS}/util.sh"
source "${PROVISIONING_SCRIPTS}/common.sh"

# -- Helpers ------------------------------------------------------------------

# already_done <message>
# Logs a notice that a step was detected as already complete and will be skipped.
already_done() {
  log "  [SKIP] Already done: ${1}"
}

# -- DC Reachability Check (hard requirement for this script) -----------------
log "=================================================================="
log " AD Integration Script -- ${HOSTNAME}"
log "=================================================================="
log ""
log "Checking DC reachability (${DC_IP}:389)..."

if ! nc -z -w 3 "${DC_IP}" 389 > /dev/null 2>&1; then
  log ""
  log "+--------------------------------------------------------------+"
  log "|  ERROR: Domain controller ${DC_IP} is not reachable.        |"
  log "|  This script requires the DC to be up before it can run.    |"
  log "|                                                              |"
  log "|  Things to check:                                            |"
  log "|    * Is the DC VM running?  (vagrant status)                 |"
  log "|    * Is the DC provisioned? (vagrant up dc)                  |"
  log "|    * Is port 389 open on the DC firewall?                    |"
  log "+--------------------------------------------------------------+"
  exit 1
fi

log "DC is reachable -- proceeding with AD integration."
log ""

# -- STAGE 1: DNS Verification ------------------------------------------------
log "[STAGE 1] Verifying DNS resolves ${DOMAIN_NAME}"

if host "${DOMAIN_NAME}" > /dev/null 2>&1; then
  already_done "DNS resolves ${DOMAIN_NAME} correctly"
  success "[STAGE 1] DNS OK"
else
  log "DNS lookup failed -- checking resolv.conf nameserver entry..."

  # resolv.conf may have been overwritten by NetworkManager after provisioning.
  # Re-assert the correct nameserver if the DC entry is missing.
  if ! grep -q "nameserver ${DC_IP}" /etc/resolv.conf; then
    log "DC nameserver missing from resolv.conf -- re-adding..."
    sed -i "1s/^/nameserver ${DC_IP}\n/" /etc/resolv.conf
  fi

  verify "DNS resolves ${DOMAIN_NAME} after nameserver fix" host "${DOMAIN_NAME}"
  success "[STAGE 1] DNS verified after nameserver correction"
fi

# -- STAGE 5: Active Directory Domain Join ------------------------------------
log "[STAGE 5] AD domain join"

# Check 1: Is the machine already joined?
if net ads testjoin > /dev/null 2>&1; then
  already_done "Machine is already joined to ${DOMAIN_NAME}"
else
  log "Machine is not joined -- performing domain join..."
  net ads join -U "${JOIN_USER}%${JOIN_PASS}" createcomputer="${TARGET_OU}"
  verify "Domain join succeeded" net ads testjoin
  success "Joined ${DOMAIN_NAME} successfully"
fi

# Check 2: SPN registration (|| true because duplicate SPNs are non-fatal)
log "Checking/registering CIFS SPNs..."

_spn_short="cifs/$(hostname -s)"
_spn_fqdn="cifs/$(hostname -f)"

if net ads setspn list "$(hostname -s)" -U "${JOIN_USER}%${JOIN_PASS}" 2>/dev/null \
    | grep -qi "cifs/$(hostname -s)"; then
  already_done "CIFS SPNs already registered"
else
  net ads setspn add "${_spn_short}" -U "${JOIN_USER}%${JOIN_PASS}" || true
  net ads setspn add "${_spn_fqdn}"  -U "${JOIN_USER}%${JOIN_PASS}" || true
  success "CIFS SPNs registered"
fi

# Check 3: Machine keytab
if [ -s /etc/krb5.keytab ]; then
  already_done "Machine keytab already present at /etc/krb5.keytab"
else
  log "Generating machine keytab..."
  net ads keytab create -U "${JOIN_USER}%${JOIN_PASS}"
  verify "Machine keytab generated" test -s /etc/krb5.keytab
  success "Machine keytab created"
fi

success "[STAGE 5] AD join and credentials complete"

# -- STAGE 10: Samba & Winbind Services ---------------------------------------
log "[STAGE 10] Samba and Winbind services"

# Enable and start services -- systemd is idempotent for already-running units
run systemctl enable --now smb nmb winbind

# Wait for Winbind to establish DC communication
log "Waiting for Winbind to connect to the DC (max 60s)..."
_wb_ready=0
for _i in $(seq 1 12); do
  if wbinfo --ping-dc > /dev/null 2>&1; then
    _wb_ready=1
    success "Winbind is online (attempt ${_i})"
    break
  fi
  log "  ...attempt ${_i}/12, retrying in 5s"
  sleep 5
done

if [ "${_wb_ready}" -eq 0 ]; then
  log ""
  log "+--------------------------------------------------------------+"
  log "|  ERROR: Winbind could not reach the DC within 60 seconds.   |"
  log "|  The domain join may have partially failed, or the DC       |"
  log "|  became unreachable after the initial check.                |"
  log "|                                                              |"
  log "|  Things to check:                                            |"
  log "|    * journalctl -u winbind --no-pager -n 50                  |"
  log "|    * wbinfo --ping-dc                                        |"
  log "|    * net ads testjoin                                        |"
  log "+--------------------------------------------------------------+"
  exit 1
fi

# Update share directory ownership now that Winbind can resolve group names
log "Updating share directory ownership to domain admins..."
chown root:"${WORKGROUP}\\domain admins" /export/storage/windows_homes
chown root:"${WORKGROUP}\\domain admins" /export/storage/windows_profiles
success "Share ownership updated"

success "[STAGE 10] Samba and Winbind running"

# -- STAGE 10b: Per-User Home Directory Provisioning --------------------------
log "[STAGE 10b] Per-user home directory provisioning"

log "Querying AD group ${STORAGE_GROUP_DN} for members..."

mapfile -t DOMAIN_USERS < <(
  net ads search \
    "(&(objectClass=user)(memberOf=${STORAGE_GROUP_DN}))" \
    sAMAccountName \
    -U "${JOIN_USER}%${JOIN_PASS}" 2>/dev/null \
    | grep "^sAMAccountName:" \
    | awk '{print $2}'
)

if [ "${#DOMAIN_USERS[@]}" -eq 0 ]; then
  log ""
  log "+--------------------------------------------------------------+"
  log "|  ERROR: No users found in GRP_Storage_Users.                |"
  log "|  The join succeeded but the group query returned empty.     |"
  log "|                                                              |"
  log "|  Things to check:                                            |"
  log "|    * Does GRP_Storage_Users exist in AD?                     |"
  log "|    * Are any user accounts members of that group?            |"
  log "|    * Does ${JOIN_USER} have read access to the group?        |"
  log "+--------------------------------------------------------------+"
  exit 1
fi

log "Found ${#DOMAIN_USERS[@]} user(s): ${DOMAIN_USERS[*]}"

_provisioned=0
_skipped=0

for user in "${DOMAIN_USERS[@]}"; do
  _home_dir="/export/storage/windows_homes/${user}"

  if [ -d "${_home_dir}" ]; then
    # Directory exists -- re-apply ownership and ACLs in case they drifted
    log "  [EXIST] ${user} -- re-applying ownership and ACLs"
    chown "${WORKGROUP}\\${user}":"${WORKGROUP}\\domain users" "${_home_dir}"
    chmod 0700 "${_home_dir}"
    setfacl -m  "g:${WORKGROUP}\\domain admins:rwx" "${_home_dir}"
    setfacl -m "d:g:${WORKGROUP}\\domain admins:rwx" "${_home_dir}"
    _skipped=$(( _skipped + 1 ))
  else
    # New user -- full provisioning
    mkdir -p "${_home_dir}"
    chown "${WORKGROUP}\\${user}":"${WORKGROUP}\\domain users" "${_home_dir}"
    chmod 0700 "${_home_dir}"
    setfacl -m  "g:${WORKGROUP}\\domain admins:rwx" "${_home_dir}"
    setfacl -m "d:g:${WORKGROUP}\\domain admins:rwx" "${_home_dir}"
    success "  [NEW]   Provisioned home folder for ${user}"
    _provisioned=$(( _provisioned + 1 ))
  fi
done

verify "Domain admins ACL present on first user dir" \
  bash -c "getfacl '/export/storage/windows_homes/${DOMAIN_USERS[0]}' \
    | grep -q 'domain\\\\040admins'"

success "[STAGE 10b] Done -- ${_provisioned} new, ${_skipped} existing (ACLs re-applied)"

# -- Summary ------------------------------------------------------------------
log ""
log "  +--------------------------------------------------+"
log "  |                                                  |"
log "  |   AD Integration Complete!                       |"
log "  |                                                  |"
log "  +--------------------------------------------------+"
log ""
log "  Domain      : ${DOMAIN_NAME}"
log "  Machine     : $(hostname -f)"
log "  Joined      : $(net ads testjoin 2>&1)"
log "  Keytab      : /etc/krb5.keytab ($(stat -c '%s bytes' /etc/krb5.keytab))"
log "  Shares      : //$(hostname -s)/homefolders"
log "                //$(hostname -s)/profiles"
log "  Users       : ${#DOMAIN_USERS[@]} total (${_provisioned} new, ${_skipped} updated)"
log ""

exit 0