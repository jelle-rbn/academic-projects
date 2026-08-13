#! /bin/bash
# -----------------------------------------------------------------------------
# storage.sh  --  Enterprise Domain-Joined Storage Provisioning
# -----------------------------------------------------------------------------
# Configures a Linux-based storage server as an Active Directory domain member.
# Uses Winbind for identity mapping and Samba/NFS for file services.
# Data RAID array (md1) is encrypted at rest using LUKS2 with a keyfile.
# Encryption stack: Disks -> RAID-5 (md1) -> LUKS2 -> LVM -> XFS -> /export/storage
# -----------------------------------------------------------------------------

# -- Environment Setup & Configuration ----------------------------------------
set -o errexit   # stop bij fouten
set -o nounset   # stop bij ongedefinieerde variabelen
set -o pipefail  # behoud error codes in pijplijnen

readonly PROVISIONING_SCRIPTS="/vagrant/provisioning"
export PROVISIONING_SCRIPTS
readonly DEBUG=1  # Set to 1 for detailed command output during provisioning

# -- Domain & Network Constants -----------------------------------------------
readonly DOMAIN_NAME="ad.t02-domain404.internal"
readonly DOMAIN_UPPER="${DOMAIN_NAME^^}"
readonly WORKGROUP="DOMAIN404"
readonly DC_IP="192.168.132.194"
readonly STORAGE_IP="192.168.132.199"
readonly JOIN_USER="SVC_DomainJoin"
readonly JOIN_PASS="Str0ng-J0in-P@ss!"
readonly TARGET_OU="OU=Infrastructure,OU=Servers,OU=Computers,OU=D404,DC=ad,DC=t02-domain404,DC=internal"
readonly STORAGE_GROUP_DN="CN=GRP_Storage_Users,OU=ACL,OU=Groups,OU=D404,DC=ad,DC=t02-domain404,DC=internal"

# -- LUKS Encryption Constants ------------------------------------------------
readonly LUKS_KEY_DIR="/etc/luks"
readonly LUKS_KEY_PATH="${LUKS_KEY_DIR}/storage.key"
readonly LUKS_MAPPER_NAME="md1_crypt"

# -- Standalone / Degraded-Mode Helpers ---------------------------------------
# Tracks stages that were skipped due to unreachable external services.
# Populated by warn_skip(); reported in the final summary.
SKIPPED_STAGES=()

# warn_skip <stage-label> <reason>
# Logs a visible warning and records the stage -- does NOT exit.
warn_skip() {
  local stage="${1}"
  local reason="${2}"
  log "  +==============================================================+"
  log "  |  WARNING: Skipping ${stage}"
  log "  |  Reason : ${reason}"
  log "  +==============================================================+"
  SKIPPED_STAGES+=("${stage}: ${reason}")
}

# check_dc_reachable
# Tests TCP connectivity to the DC on port 389 (LDAP).
# Sets DC_REACHABLE=1 if reachable, DC_REACHABLE=0 otherwise.
# Uses nc (netcat) with a 3-second timeout -- no DNS required, raw IP only.
check_dc_reachable() {
  if nc -z -w 3 "${DC_IP}" 389 > /dev/null 2>&1; then
    DC_REACHABLE=1
    log "DC reachability check: ${DC_IP}:389 reachable"
  else
    DC_REACHABLE=0
    log "DC reachability check: ${DC_IP}:389 NOT reachable -- AD stages will be skipped"
  fi
}

# Load external utility functions (success, error, log, run, verify, install_package)
source "${PROVISIONING_SCRIPTS}/util.sh"
source "${PROVISIONING_SCRIPTS}/common.sh"

log "=================================================================="
log " Starting Domain Member Storage provisioning on ${HOSTNAME}"
log "=================================================================="

# Run once here -- all AD-dependent stages read this variable.
# Running it early means every stage decision is based on the same snapshot.
check_dc_reachable

# -- STAGE 1: DNS Configuration -----------------------------------------------
# Essential for Kerberos and AD discovery.
# Skipped in standalone mode -- writing the config is still safe and useful,
# but the live DNS verify requires the DC to be up.
log "[STAGE 1] Configuring DNS > DC (${DC_IP})"

cat > /etc/NetworkManager/conf.d/99-ad-dns.conf << EOF
[main]
dns=none
EOF

cat > /etc/resolv.conf << EOF
search ${DOMAIN_NAME}
nameserver ${DC_IP}
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
# DC is always tried first for AD/Kerberos/SRV record resolution.
# Public fallbacks (Google, Cloudflare) ensure dnf/yum and general
# internet resolution work even when the DC is offline or not yet up.

run systemctl reload NetworkManager

if [ "${DC_REACHABLE}" -eq 1 ]; then
  verify "DNS resolves ${DOMAIN_NAME}" host "${DOMAIN_NAME}"
  success "[STAGE 1] DNS configured and verified"
else
  warn_skip "STAGE 1 (DNS verify)" "DC ${DC_IP} unreachable -- config written, live lookup skipped"
fi

# -- STAGE 2: Package Installation --------------------------------------------
log "[STAGE 2] Installing packages"

install_package \
  mdadm lvm2 parted cryptsetup adcli nfs-utils \
  samba samba-common samba-winbind samba-winbind-clients \
  oddjob oddjob-mkhomedir

verify "smbd binary present"       which smbd
verify "winbindd binary present"   which winbindd
verify "cryptsetup binary present" which cryptsetup
success "[STAGE 2] All packages installed"

# -- STAGE 3: Storage Layers (RAID + LUKS + LVM) ------------------------------
log "[STAGE 3] Configuring storage layers (RAID + LUKS + LVM)"

log "Stopping any existing RAID arrays..."
mdadm --stop /dev/md0 2>/dev/null || true
mdadm --stop /dev/md1 2>/dev/null || true

log "Wiping and partitioning disks..."
for disk in /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg; do
  for part in "${disk}1" "${disk}2"; do
    if [ -b "${part}" ]; then run mdadm --zero-superblock --force "${part}" || true; fi
  done
  run mdadm --zero-superblock --force "${disk}" || true
  run wipefs -a "${disk}"
  run parted -s "${disk}" mklabel gpt
  run parted -s "${disk}" mkpart primary 1MiB 100%
  run parted -s "${disk}" set 1 raid on
  run partprobe "${disk}"
done

sleep 2

# -- /dev/md0 : RAID-1 (OS mirror) -- NOT encrypted; required for unattended boot
if [ ! -b /dev/md0 ]; then
  run mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1 \
    --metadata=1.0 --run --force
fi

# -- /dev/md1 : RAID-5 + 1 spare (data array) -- will be LUKS-encrypted below
if [ ! -b /dev/md1 ]; then
  run mdadm --create /dev/md1 --level=5 --raid-devices=3 --spare-devices=1 \
    /dev/sdd1 /dev/sde1 /dev/sdf1 /dev/sdg1 --run --force
fi

verify "RAID array /dev/md0 exists" test -b /dev/md0
verify "RAID array /dev/md1 exists" test -b /dev/md1

# -- STAGE 3b: LUKS2 Keyfile Generation ---------------------------------------
log "[STAGE 3b] Generating LUKS2 keyfile"

mkdir -p "${LUKS_KEY_DIR}"
chmod 700 "${LUKS_KEY_DIR}"

if [ ! -f "${LUKS_KEY_PATH}" ]; then
  # 2 KiB of random bytes; strip NUL bytes so the key is safe for all tools
  dd if=/dev/urandom bs=512 count=4 | tr -d '\0' > "${LUKS_KEY_PATH}"
fi

chmod 400 "${LUKS_KEY_PATH}"
chattr +i "${LUKS_KEY_PATH}"   # Immutable -- prevent accidental deletion/overwrite

verify "LUKS keyfile present and non-empty" test -s "${LUKS_KEY_PATH}"
success "[STAGE 3b] Keyfile ready at ${LUKS_KEY_PATH}"

# -- STAGE 3c: LUKS2 Encryption of /dev/md1 -----------------------------------
log "[STAGE 3c] Applying LUKS2 encryption to /dev/md1"

if ! cryptsetup isLuks /dev/md1 2>/dev/null; then
  log "Formatting /dev/md1 with LUKS2 (aes-xts-plain64 / 512-bit key)..."
  run cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --iter-time 2000 \
    --key-file "${LUKS_KEY_PATH}" \
    /dev/md1
fi

if ! cryptsetup status "${LUKS_MAPPER_NAME}" > /dev/null 2>&1; then
  log "Opening LUKS container as /dev/mapper/${LUKS_MAPPER_NAME}..."
  run cryptsetup open \
    --type luks2 \
    --key-file "${LUKS_KEY_PATH}" \
    /dev/md1 "${LUKS_MAPPER_NAME}"
fi

verify "LUKS container /dev/mapper/${LUKS_MAPPER_NAME} open" \
  test -b "/dev/mapper/${LUKS_MAPPER_NAME}"
success "[STAGE 3c] LUKS2 container open"

# -- STAGE 3d: LVM on top of the LUKS device ----------------------------------
log "[STAGE 3d] Configuring LVM on LUKS device"

if ! vgs vg_enterprise > /dev/null 2>&1; then
  run pvcreate /dev/mapper/${LUKS_MAPPER_NAME}
  run vgcreate vg_enterprise /dev/mapper/${LUKS_MAPPER_NAME}
  run lvcreate -n lv_data -l 100%FREE vg_enterprise
  run mkfs.xfs -f /dev/vg_enterprise/lv_data
fi

mkdir -p /export/storage
if ! grep -q "/dev/vg_enterprise/lv_data" /etc/fstab; then
  echo "/dev/vg_enterprise/lv_data /export/storage xfs defaults 0 0" >> /etc/fstab
fi
run mount -a

verify "Storage volume mounted at /export/storage" mountpoint -q /export/storage
success "[STAGE 3d] LVM and XFS filesystem ready on LUKS device"

# -- STAGE 3e: crypttab + dracut (automatic unlock at boot) -------------------
log "[STAGE 3e] Registering LUKS device for automatic unlock at boot"

LUKS_UUID=$(cryptsetup luksUUID /dev/md1)

# crypttab format: <mapper-name>  <block-device-UUID>  <keyfile>  <options>
if ! grep -q "${LUKS_MAPPER_NAME}" /etc/crypttab 2>/dev/null; then
  echo "${LUKS_MAPPER_NAME}  UUID=${LUKS_UUID}  ${LUKS_KEY_PATH}  luks,keyfile-timeout=10s" \
    >> /etc/crypttab
fi

# Instruct dracut to embed the keyfile and crypt module into the initramfs
cat > /etc/dracut.conf.d/luks.conf << EOF
# Embed LUKS keyfile and crypt module so the data array unlocks before pivot_root
install_items+=" ${LUKS_KEY_PATH} "
add_dracutmodules+=" crypt "
EOF

# Persist mdadm config then rebuild initramfs (includes LUKS key + crypt module)
mdadm --detail --scan > /etc/mdadm.conf
run dracut -H -f

verify "crypttab entry present" grep -q "${LUKS_MAPPER_NAME}" /etc/crypttab
success "[STAGE 3e] crypttab and initramfs updated -- array will auto-unlock at boot"
success "[STAGE 3] Storage layers ready (RAID-5 -> LUKS2 -> LVM -> XFS)"

# -- STAGE 4: Minimal smb.conf (Pre-Join) -------------------------------------
log "[STAGE 4] Writing minimal smb.conf"

cat > /etc/samba/smb.conf << EOF
[global]
    workgroup        = ${WORKGROUP}
    security         = ads
    realm            = ${DOMAIN_UPPER}
    kerberos method  = secrets and keytab
EOF

verify "Minimal smb.conf syntax valid" testparm -s /etc/samba/smb.conf

# -- STAGE 5: Active Directory Domain Join (Winbind/ADS) ----------------------
log "[STAGE 5] Joining domain ${DOMAIN_NAME} via ADS"

if [ "${DC_REACHABLE}" -eq 0 ]; then
  warn_skip "STAGE 5 (AD domain join)" "DC ${DC_IP} unreachable -- join, SPN registration and keytab skipped"
else
  # Initial join and population of secrets.tdb
  net ads join -U "${JOIN_USER}%${JOIN_PASS}" createcomputer="${TARGET_OU}"

  # Registering SPNs for CIFS access
  net ads setspn add "cifs/$(hostname -s)" -U "${JOIN_USER}%${JOIN_PASS}" || true
  net ads setspn add "cifs/$(hostname -f)" -U "${JOIN_USER}%${JOIN_PASS}" || true

  # Generate machine keytab
  net ads keytab create -U "${JOIN_USER}%${JOIN_PASS}"

  verify "Samba machine credentials valid" net ads testjoin
  verify "Machine keytab present"          test -s /etc/krb5.keytab
  success "[STAGE 5] ADS Join and Keytab generation complete"
fi

# -- STAGE 6: Name Service Configuration (NSS) --------------------------------
# Tells Linux to use Winbind for user and group resolution.
log "[STAGE 6] Configuring NSSwitch for Winbind"

sed -i 's/^passwd:.*/passwd:     files winbind/' /etc/nsswitch.conf
sed -i 's/^group:.*/group:      files winbind/'  /etc/nsswitch.conf

success "[STAGE 6] nsswitch.conf updated"

# -- STAGE 7: Samba & Winbind Full Configuration ------------------------------
log "[STAGE 7] Writing full smb.conf"

cat > /etc/samba/smb.conf << EOF
[global]
    workgroup        = ${WORKGROUP}
    security         = ads
    realm            = ${DOMAIN_UPPER}
    kerberos method  = secrets and keytab

    # Winbind Identity Mapping (autorid backend)
    idmap config * : backend = autorid
    idmap config * : range   = 10000-999999

    # Standard Windows Compatibility
    vfs objects      = acl_xattr
    map acl inherit  = yes
    store dos attributes = yes
    log level        = 2

[homefolders]
    comment          = Domain User Home Folders
    path             = /export/storage/windows_homes
    read only        = No
    browseable       = Yes
    hide unreadable  = yes

[profiles]
    comment          = Roaming Profiles
    path             = /export/storage/windows_profiles
    read only        = No
    browseable       = No
    csc policy       = disable
EOF

verify "smb.conf syntax valid" testparm -s /etc/samba/smb.conf
success "[STAGE 7] smb.conf configured"

# -- STAGE 8: Directory Structure ---------------------------------------------
log "[STAGE 8] Creating share directories"

mkdir -p /export/storage/windows_homes
mkdir -p /export/storage/windows_profiles

# Initial root permissions before Winbind starts
chown root:root /export/storage/windows_homes
chown root:root /export/storage/windows_profiles
chmod 0755 /export/storage/windows_homes
chmod 1777 /export/storage/windows_profiles

# -- STAGE 9: SELinux Security ------------------------------------------------
log "[STAGE 9] Applying SELinux contexts"

ensure_fcontext "samba_share_t" "/export/storage"
run setsebool -P nfs_export_all_rw 1

success "[STAGE 9] SELinux contexts applied"

# -- STAGE 10: Start Services & Health Check ----------------------------------
log "[STAGE 10] Starting Samba and Winbind services"

if [ "${DC_REACHABLE}" -eq 0 ]; then
  warn_skip "STAGE 10 (Samba/Winbind services + health check)" \
    "DC ${DC_IP} unreachable -- services not started, Winbind ping and chown to domain admins skipped"
else
  run systemctl enable --now smb nmb winbind

  # Wait for Winbind to establish communication with the DC
  log "Waiting for Winbind to connect to the DC..."
  _wb_ready=0
  for _i in $(seq 1 12); do
    if wbinfo --ping-dc > /dev/null 2>&1; then
      _wb_ready=1
      success "Winbind is online (ready after attempt ${_i})"
      break
    fi
    sleep 5
  done

  if [ "${_wb_ready}" -eq 0 ]; then
    error "Winbind failed to reach DC within 60 seconds."
    exit 1
  fi

  # Update root ownership now that Winbind can resolve the group names
  chown root:"${WORKGROUP}\\domain admins" /export/storage/windows_homes
  chown root:"${WORKGROUP}\\domain admins" /export/storage/windows_profiles
fi

# -- STAGE 10b: Per-User Home Directory Provisioning --------------------------
log "[STAGE 10b] Provisioning user directories"

if [ "${DC_REACHABLE}" -eq 0 ]; then
  warn_skip "STAGE 10b (per-user home provisioning)" \
    "DC ${DC_IP} unreachable -- AD user query and home folder creation skipped"
else
  mapfile -t DOMAIN_USERS < <(
    net ads search \
      "(&(objectClass=user)(memberOf=${STORAGE_GROUP_DN}))" \
      sAMAccountName \
      -U "${JOIN_USER}%${JOIN_PASS}" 2>/dev/null \
      | grep "^sAMAccountName:" \
      | awk '{print $2}'
  )

  if [ "${#DOMAIN_USERS[@]}" -eq 0 ]; then
    error "No users found in GRP_Storage_Users. Check AD group membership."
    exit 1
  fi

  for user in "${DOMAIN_USERS[@]}"; do
    mkdir -p "/export/storage/windows_homes/${user}"
    chown "${WORKGROUP}\\${user}":"${WORKGROUP}\\domain users" \
      "/export/storage/windows_homes/${user}"
    chmod 0700 "/export/storage/windows_homes/${user}"
    setfacl -m  "g:${WORKGROUP}\\domain admins:rwx" \
      "/export/storage/windows_homes/${user}"
    setfacl -m "d:g:${WORKGROUP}\\domain admins:rwx" \
      "/export/storage/windows_homes/${user}"
    success "Provisioned folder for ${user}"
  done

  verify "Domain admins ACL present" \
    bash -c "getfacl '/export/storage/windows_homes/${DOMAIN_USERS[0]}' \
      | grep -q 'domain\\\\040admins'"
  success "[STAGE 10b] Home directory provisioning complete"
fi

# -- STAGE 11: NFS Export for Webserver ---------------------------------------
log "[STAGE 11] Configuring NFS Export for Webserver"

readonly WEBSERVER_IP="192.168.132.196"
readonly WP_EXPORT_PATH="/export/storage/wordpress"

mkdir -p "${WP_EXPORT_PATH}"

echo "${WP_EXPORT_PATH} ${WEBSERVER_IP}(rw,sync,no_root_squash)" > /etc/exports

run systemctl enable --now rpcbind nfs-server

verify "NFS Export active" \
  bash -c "showmount -e localhost | grep -q '${WP_EXPORT_PATH}'"

success "[STAGE 11] NFS Export configured for ${WEBSERVER_IP}"

# -- STAGE 12: Firewall -------------------------------------------------------
log "[STAGE 12] Configuring firewall"

run systemctl enable --now firewalld

for svc in samba samba-client nfs mountd rpc-bind; do
  run firewall-cmd --add-service="${svc}" --permanent
done

run firewall-cmd --reload

success "[STAGE 12] Firewall updated"

# Apply network fix

log "Applying network fix"

bash ${PROVISIONING_SCRIPTS}/networkfix.sh

# -- Final Summary ------------------------------------------------------------
log ""
log "  +-------------------------------------------------+"
log "  |                                                 |"
log "  |      Enterprise Storage Server Ready!           |"
log "  |                                                 |"
log "  +-------------------------------------------------+"
log ""
log "  Domain      : ${DOMAIN_NAME}"
log "  Storage IP  : ${STORAGE_IP}"
log "  Shares      : //$(hostname -s)/homefolders"
log "                //$(hostname -s)/profiles"
log ""
log "  Encryption  : LUKS2 on /dev/md1 (aes-xts-plain64 / 512-bit)"
log "  LUKS UUID   : $(cryptsetup luksUUID /dev/md1)"
log "  Key path    : ${LUKS_KEY_PATH}  (immutable, 400, root only)"
log "  Boot unlock : /etc/crypttab + dracut initramfs"
log ""

if [ "${#SKIPPED_STAGES[@]}" -gt 0 ]; then
  log "  +==============================================================+"
  log "  |  PROVISIONING COMPLETED WITH SKIPPED STAGES                 |"
  log "  |  The following stages were bypassed because the DC          |"
  log "  |  (${DC_IP}) was unreachable. Re-run with the DC            |"
  log "  |  online to complete full domain integration.                |"
  log "  +==============================================================+"
  for entry in "${SKIPPED_STAGES[@]}"; do
    log "  |  * ${entry}"
  done
  log "  +==============================================================+"
  log ""
else
  log "  All stages completed successfully -- no skips."
  log ""
fi

exit 0