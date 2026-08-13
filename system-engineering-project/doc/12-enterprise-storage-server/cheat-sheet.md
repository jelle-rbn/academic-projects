# Cheat-sheet: Enterprise Storage Server

Author(s): J. Magerman - `johan.magerman@student.hogent.be`

This document provides a quick reference for managing the storage stack and Active Directory integration on the storage node.

## Disk & RAID Management

| Command | Description |
| :--- | :--- |
| `lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE` | **Primary verification:** Showcases the full hierarchy from physical Disks -> RAID -> LUKS -> LVM -> XFS |
| `mdadm --detail /dev/md1` | Check the health and status of the RAID-5 data array |
| `cat /proc/mdstat` | Quick view of all active RAID devices and syncing progress |

## Encryption (LUKS2)

| Command | Description |
| :--- | :--- |
| `cryptsetup status md1_crypt` | Check if the encrypted container (`md1_crypt`) is open and active |
| `cryptsetup luksDump /dev/md1` | View LUKS2 metadata, cipher (aes-xts-plain64), and keyslots |
| `ls -l /etc/luks/storage.key` | Verify the presence of the immutable 2 KiB LUKS keyfile |

## Active Directory & Winbind

| Command | Description |
| :--- | :--- |
| `net ads testjoin` | Verify the server's machine account status in the domain |
| `wbinfo --ping-dc` | Check Winbind's communication with the Domain Controller (`192.168.132.194`) |
| `wbinfo -u` | List all AD users resolved via the Winbind `autorid` backend |
| `getent passwd [user]` | Verify AD user mapping to local Linux UIDs |

## Shared Services (Samba & NFS)

| Command | Description |
| :--- | :--- |
| `smbstatus` | View active Samba connections and locked files in `homefolders` or `profiles` |
| `testparm -s` | Validate the syntax of the `smb.conf` configuration |
| `showmount -e localhost` | Verify the NFS export for the Webserver at `192.168.132.196` |
| `getfacl /export/storage/windows_homes/[user]` | Verify that Domain Admins have full REX permissions on home folders |

## Key File Locations

| Resource | Path |
| :--- | :--- |
| **Storage Mount** | `/export/storage` (XFS on LVM) |
| **Samba Config** | `/etc/samba/smb.conf` |
| **LUKS Keyfile** | `/etc/luks/storage.key` (Immutable) |
| **NFS Exports** | `/etc/exports` |
| **AD Credentials** | `/var/lib/samba/private/secrets.tdb` |