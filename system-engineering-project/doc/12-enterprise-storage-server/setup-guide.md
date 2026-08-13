# Setup guide: Enterprise Storage Server

Author(s): J. Magerman - `johan.magerman@student.hogent.be`

This guide describes the step-by-step procedure for deploying a redundant, encrypted, and domain-integrated storage server. The deployment focuses on a complex storage stack that secures data at rest while providing seamless access for Active Directory users.



## Prerequisites

Before starting the provisioning, ensure the following environment is ready:
* **Disk Configuration**: The VM must be equipped with 6 additional virtual disks:
    * 2x 40GB disks for OS redundancy.
    * 4x 128GB disks for the data array (3 active, 1 spare).
* **Network**: The Domain Controller (`192.168.132.194`) should be online to allow the storage server to join the domain during the automated phase.
* **Credentials**: The `SVC_DomainJoin` account must be functional in Active Directory.

## Provisioning Workflow

The deployment is fully automated via the `storage.sh` script. If the Domain Controller is unreachable, the script will skip AD-dependent stages and issue a warning at the end of the process.

### 1. Storage Layering (RAID -> LUKS -> LVM)
The script builds the storage stack from the bottom up:
* **RAID Configuration**: 
    * Creates a RAID-1 mirror (`/dev/md0`) for the OS using `/dev/sdb1` and `/dev/sdc1`.
    * Creates a RAID-5 array (`/dev/md1`) using `/dev/sdd1`, `/dev/sde1`, and `/dev/sdf1`, with `/dev/sdg1` as a hot spare.
* **LUKS2 Encryption**:
    * Generates a random 2 KiB keyfile at `/etc/luks/storage.key` and makes it immutable via `chattr +i`.
    * Formats the RAID-5 device (`/dev/md1`) with LUKS2 encryption using the `aes-xts-plain64` cipher and opens it as `md1_crypt`.
* **LVM & Filesystem**:
    * Creates a Volume Group (`vg_enterprise`) and Logical Volume (`lv_data`) on the encrypted device.
    * Formats the volume with XFS and mounts it at `/export/storage`.
* **Boot Automation**: Updates `/etc/crypttab` and the `dracut` initramfs to ensure the array auto-unlocks using the keyfile during boot.

### 2. Active Directory Integration
* **Domain Join**: Uses the `net ads join` command to join the `ad.t02-domain404.internal` domain.
* **Identity Mapping**: Configures Winbind with the `autorid` backend to map AD users to the Linux UID range `10000-999999`.
* **NSSwitch**: Updates `/etc/nsswitch.conf` to include `winbind` for user and group lookups.

### 3. Share Provisioning
* **Samba**: Configures the `homefolders` and `profiles` shares with Windows compatibility settings like `acl_xattr`.
* **NFS**: Exports `/export/storage/wordpress` specifically to the Webserver IP (`192.168.132.196`) with `no_root_squash`.
* **Permissions**: Automatically provisions home folders for all members of the `GRP_Storage_Users` AD group, setting ownership to the specific user and granting `domain admins` full access.

## Manual Fallback (Standalone Setup)

If the Domain Controller or other services were not reachable during provisioning, specific steps must be verified manually once connectivity is restored.

* **Step 1: Verify Mounts**: Ensure the encrypted volume is active and the hierarchy is correct.
    ```bash
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE
    ```
* **Step 2: Join Domain & Restart Services**: If the automated join was skipped, perform the join and restart Winbind.
    ```bash
    net ads join -U "SVC_DomainJoin%Str0ng-J0in-P@ss!"
    systemctl enable --now smb nmb winbind
    ```

## Verification

After provisioning, verify the health of the storage stack and domain status.

### 1. Verify Storage Stack
Run the following command to see the full hierarchy of the storage layers:
```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE
```
**Expected Result**: You should see raw disks leading to `md` devices, a `crypt` layer on `md1`, followed by `lvm` volumes and the `/export/storage` mount point.

### 2. Verify Domain Status
```bash
net ads testjoin
wbinfo --ping-dc
```
**Expected Result**: Both commands should return "Join is OK" or "succeeded".

### 3. Verify Shared Services
```bash
showmount -e localhost
testparm -s
```
**Expected Result**: The NFS export for the webserver should be listed, and the Samba configuration should report no errors.

## Troubleshooting

| Problem | Possible Solution |
| :--- | :--- |
| **AD Stages Skipped** | The DC was unreachable during provisioning. Ensure port 389 is open on the DC and re-run the AD join manually. |
| **Array Not Unlocking at Boot** | Verify that the keyfile path in `/etc/crypttab` is correct and that the initramfs was rebuilt via `dracut -H -f`. |
| **Permission Denied on Shares** | Check if Winbind can resolve domain users via `wbinfo -u`. Ensure the user is in the `GRP_Storage_Users` group. |