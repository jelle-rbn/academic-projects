# Research: Enterprise Storage Server

Author(s): J. Magerman - `johan.magerman@student.hogent.be`

This document outlines the research and technical background for the implementation of the
Enterprise Storage Server, covering disk redundancy, encryption, volume management, and
cross-platform domain integration.

---

## 1. Redundant Disk Arrays (RAID)

To ensure high availability for both the operating system and user data, the server uses
Multiple Device Administration (`mdadm`) to build and manage software RAID arrays.

**Key findings:**
* **RAID-1 (Mirroring):** Used for the OS disks; two drives store identical copies so the
  server stays bootable after a single drive failure. Metadata version 1.0 is recommended
  for boot arrays; version 1.2 is the default for data arrays.
* **RAID-5 (Striping with Parity):** Chosen for data storage because it provides a balance
  between usable capacity, read performance, and single-drive fault tolerance. Usable
  capacity is (N-1) * drive_size.
* **Hot Spare:** Adding a spare with `--spare-devices=1` or `mdadm --manage --add` causes
  mdadm to begin automatic array reconstruction the moment a drive is marked as failed,
  without any administrator intervention.
* After creation, `mdadm --detail --scan | tee -a /etc/mdadm/mdadm.conf` and
  `update-initramfs -u` (Debian/Ubuntu) or `dracut --regenerate-all --force` (RHEL) are
  required to persist the array across reboots.
* Array health is monitored via `cat /proc/mdstat` (quick overview) and
  `mdadm --detail /dev/mdX` (full member-level status including spares).

**Sources:**
| Source | Description |
| :--- | :--- |
| [Linux Kernel - RAID Setup](https://docs.kernel.org/admin-guide/md.html) | Authoritative upstream reference for `mdadm --create` syntax, RAID level selection, metadata version guidance, and spare-device flags. |
| [DigitalOcean - Create RAID Arrays with mdadm on Ubuntu](https://www.digitalocean.com/community/tutorials/how-to-create-raid-arrays-with-mdadm-on-ubuntu) | Step-by-step guide for RAID 0, 1, 5, 6, and 10 on Ubuntu including array creation, persistence (mdadm.conf + initramfs), fstab with `nofail`, and disk replacement procedure. |
| [Hetzner Community - Software RAID under Linux](https://community.hetzner.com/tutorials/howto-setup-mdadm/) | Practical guide covering RAID-1 creation, persisting via UUID in fstab, hot spare behavior, and live expansion with `--grow` and a backup file. |
| [OneUptime - Add a Hot Spare Disk to an mdadm RAID Array on RHEL](https://oneuptime.com/blog/post/2026-03-04-add-hot-spare-mdadm-raid-rhel-9/view) | Focused guide on adding and verifying a hot spare to an existing array; covers shared spare groups for protecting multiple arrays with a single spare drive. |
| [HOGENT OpsLinux - Storage and RAID](https://hogenttin.github.io/linux-training-hogent/opslinux/storage_raid/) | Course material covering software RAID concepts and `mdadm` implementation in the context of this curriculum; used as the foundational reference for the setup decisions made in this project. |
| [HOGENT Linux Training Labs - RAID](https://github.com/HoGentTIN/linux-training-labs/tree/main/raid) | Accompanying practical lab exercises for `mdadm` array creation and management; directly informed the provisioning scripts used in this infrastructure. |

---

## 2. Disk Encryption (LUKS2)

Security requirements dictate that data must be encrypted at rest to prevent unauthorized
access if physical disks are removed or stolen.

**Key findings:**
* **LUKS2:** The Linux Unified Key Setup version 2 is the current standard, providing
  up to 32 independent key slots per device. The system uses `aes-xts-plain64` with a
  512-bit key (`--key-size 512`), which is the recommended cipher/mode combination for
  modern block device encryption.
* **Keyfile Management:** A random keyfile generated with
  `dd if=/dev/urandom of=/root/luks.key bs=512 count=4` allows unattended reboots without
  a passphrase prompt. The keyfile must be owned by root and mode 0400. A passphrase slot
  should always be retained as a backup in case the keyfile is lost.
* **crypttab:** The `/etc/crypttab` file maps a LUKS device UUID to a mapper name and
  optionally a keyfile path, so `systemd-cryptsetup-generator` can unlock it automatically
  at boot. UUIDs must be used instead of device names (`/dev/sdX`), since device names can
  change between reboots.
* **Initramfs rebuild:** After editing `/etc/crypttab`, `update-initramfs -u` (Debian/Ubuntu)
  or `dracut -f` (RHEL/AlmaLinux) must be run to embed the changes into the early-boot
  environment. Omitting this step causes the crypttab change to be ignored at boot.
* The `nofail` option in `/etc/crypttab` (for non-root volumes unlocked with keyfiles)
  prevents the boot process from stalling if the volume is temporarily unavailable.

**Sources:**
| Source | Description |
| :--- | :--- |
| [Red Hat - Encrypting Block Devices Using LUKS](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/encrypting-block-devices-using-luks_security-hardening) | Official RHEL 9 guide covering `cryptsetup luksFormat`, `luksOpen`, `luksAddKey`, `luksDump`, passphrase and keyfile management, and LUKS2-specific features. |
| [Arch Wiki - dm-crypt/Device Encryption](https://wiki.archlinux.org/title/dm-crypt/Device_encryption) | Comprehensive reference for encryption options, cipher selection, keyfile creation, header backup, and LUKS2 persistent flags (including TRIM on SSDs). |
| [Arch Wiki - dm-crypt/System Configuration](https://wiki.archlinux.org/title/Dm-crypt/System_configuration) | Explains `/etc/crypttab` syntax, `nofail` and `keyfile-timeout` options, systemd-cryptsetup-generator behavior, and integration with mkinitcpio hooks. |
| [GoLinuxCloud - Auto Mount and Unlock LUKS Encrypted Partitions at Boot](https://www.golinuxcloud.com/mount-luks-encrypted-disk-partition-linux/) | End-to-end walkthrough of generating a keyfile, adding it to a LUKS slot, writing a `/etc/crypttab` entry, updating `/etc/fstab`, and running `update-initramfs`; explicitly notes the `dracut -f` equivalent for RHEL-based distros. |
| [OneUptime - Set Up LUKS Key Files for Automated Decryption on Ubuntu](https://oneuptime.com/blog/post/2026-03-02-how-to-set-up-luks-key-files-for-automated-decryption-on-ubuntu/view) | Focused guide on keyfile sizing, permission hardening, multi-device key reuse, rotating keyfiles, and verifying keyfile validity with `--test-passphrase`. |

---

## 3. Logical Volume Management (LVM)

Layering LVM on top of the encrypted RAID device provides the flexibility required for
enterprise storage environments.

**Key findings:**
* LVM allows logical volumes to be created, resized online, and snapshotted without
  unmounting, decoupling storage management from the physical disk layout.
* In this architecture, the Physical Volume (PV) is created directly on the LUKS mapper
  device (`/dev/mapper/md1_crypt`) using `pvcreate`; LVM therefore operates entirely
  within the encryption boundary.
* A Volume Group (VG) is created on the PV with `vgcreate`, then individual Logical
  Volumes (LVs) are carved out with `lvcreate -L <size>` or `lvcreate -l 100%FREE` for
  the last volume.
* The layered stack at rest is: physical disks -> mdadm RAID -> LUKS2 -> LVM PV -> VG -> LVs.
  Each LV appears as a standard block device and can be formatted with any filesystem
  (`mkfs.xfs`, `mkfs.ext4`, etc.).

**Sources:**
| Source | Description |
| :--- | :--- |
| [Red Hat - Configuring and Managing Logical Volumes (RHEL 9)](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/index) | Official comprehensive guide covering PV, VG, and LV creation, resizing, snapshots, and the `pvdisplay`/`vgdisplay`/`lvdisplay` verification commands. |
| [OneUptime - Encrypt Individual Block Devices with LUKS on RHEL](https://oneuptime.com/blog/post/2026-03-04-encrypt-block-devices-luks-rhel-9/view) | Contains a dedicated "LVM on LUKS" section with the exact command sequence: `luksFormat` -> `luksOpen` -> `pvcreate` -> `vgcreate` -> `lvcreate` -> `mkfs` -> `crypttab` + `fstab`. |
| [Arch Wiki - dm-crypt/Encrypting an Entire System](https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system) | Documents the canonical LUKS-on-LVM and LVM-on-LUKS layouts, initramfs hook requirements, and considerations for encrypting the root vs. data volumes. |
| [LinuxHint - Encrypt LVM Volumes with LUKS](https://linuxhint.com/encrypt-lvm-volumes-luks/) | Step-by-step walkthrough aimed at server environments, covering kernel module loading, `pvcreate` on a mapper device, VG and LV setup, and post-reboot verification with `lsblk`. |
| [mvysny.github.io - LUKS, LVM and Linux Boot](https://mvysny.github.io/luks-lvm-boot/) | Explains how LVM and LUKS interact from a block-device conceptual perspective, with annotated `lsblk` output showing the full storage stack and the `/etc/crypttab` entry needed for auto-unlock. |

---

## 4. Active Directory Integration (Winbind)

The server must act as a domain member to allow Windows users to access their files
using their AD credentials without a separate Linux password.

**Key findings:**
* **Winbind:** Part of the Samba suite, `winbindd` resolves AD user and group names and
  makes them available to the Linux OS via the Name Service Switch (NSS). After joining the
  domain, domain users are visible through standard commands like `getent passwd`.
* **NSSwitch:** The `/etc/nsswitch.conf` file must be updated to include `winbind` in the
  `passwd` and `group` lookup chains (`passwd: files winbind`, `group: files winbind`), so
  the OS queries AD for user and group information after checking local files.
* **Identity Mapping (IDMAP):** The `autorid` backend automatically derives stable Linux
  UIDs/GIDs from Windows SIDs within a configured range (e.g. `10000-999999`). It requires
  only a single `idmap config * : backend = autorid` line and handles multi-domain
  environments without additional per-domain configuration. Note: `winbind use default domain`
  cannot be used with `autorid`; users must log in as `DOMAIN\username`.
* The domain join is performed with `net ads join -U administrator` after the `smb.conf`
  is prepared. Success can be verified with `wbinfo -t` (trust check) and
  `wbinfo -u` / `wbinfo -g` (user/group enumeration).
* Kerberos configuration (`/etc/krb5.conf`) must set `default_realm` and enable
  `dns_lookup_kdc = true` for the domain join to succeed against a modern AD domain.

**Sources:**
| Source | Description |
| :--- | :--- |
| [Samba Wiki - Setting up Samba as a Domain Member](https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Domain_Member) | The canonical official guide: smb.conf prerequisites, pre-join checklist, idmap backend selection table, joining with `net ads join`, and nsswitch configuration. |
| [Samba Wiki - Idmap Config Autorid](https://wiki.samba.org/index.php/Idmap_config_autorid) | Full reference for the `autorid` backend including range sizing, range size parameter, a minimal working smb.conf example, and behavior in multi-domain environments. |
| [Samba Wiki - Idmap Config AD](https://wiki.samba.org/index.php/Idmap_config_ad) | Reference for the `ad` idmap backend (RFC2307 attributes), which may be used instead of `autorid` when UID/GID consistency across domain members is required. |
| [Red Hat - Using Samba for Active Directory Integration (RHEL 7)](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/windows_integration_guide/winbind) | Explains using `realm join --client-software=winbind` to automate smb.conf, krb5.conf, and PAM configuration, and covers the relationship between Winbind and NSS for local service authentication. |
| [linux-training.be - Samba Domain Member](http://linux-training.be/networking/ch22.html) | Practical walkthrough showing the full nsswitch.conf update, `service winbind start`, `wbinfo -t` trust verification, and `getent passwd` confirmation that AD users resolve correctly. |

---

## 5. Network File Services (Samba and NFS)

The storage server provides multi-protocol file access for both Windows domain clients
and Linux infrastructure components.

**Key findings:**
* **Samba (SMB/CIFS):** Used for Windows Home Folders and Roaming Profiles. Share
  definitions use the `%U` variable to create per-user paths automatically. The
  `vfs objects = acl_xattr`, `map acl inherit = yes`, and `store dos attributes = yes`
  parameters are required for full Windows ACL compatibility and correct behavior of
  Explorer-based permission dialogs.
* **Roaming Profiles:** Configured via the `logon path` parameter in `smb.conf`, pointing
  to a dedicated profiles share. Windows NT/2000/XP+ and Windows 9x/Me require separate
  paths because the profile formats are incompatible.
* **NFS:** Used to export the WordPress data directory to the Webserver. NFS is preferred
  for server-to-server communication due to lower protocol overhead than SMB. The
  `/etc/exports` file controls export targets, access modes (`rw`/`ro`), and security
  options (`sync`, `no_subtree_check`, `root_squash` / `no_root_squash`).
* **Syntax pitfall in /etc/exports:** There must be no space between a hostname and its
  parenthesized options. `host(rw)` grants `rw` only to that host, while `host (rw)` grants
  `rw` to all other clients and read-only to the specified host.
* After any change to `/etc/exports`, `exportfs -ra` re-reads and applies the new
  configuration without restarting the NFS daemon. `exportfs -v` shows all active exports
  with their resolved options.

**Sources:**
| Source | Description |
| :--- | :--- |
| [Samba Wiki - Windows User Home Folders](https://wiki.samba.org/index.php/Windows_User_Home_Folders) | Official guide for configuring per-user home folder shares with `%U`-based paths, using both Windows ACLs and POSIX ACLs, and integrating with Active Directory Users and Computers or Group Policy Preferences. |
| [Samba.org - smb.conf(5) man page](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html) | Complete authoritative reference for all smb.conf parameters including `vfs objects`, `map acl inherit`, `store dos attributes`, `logon path`, `csc policy`, and variable substitutions. |
| [Samba.org - Desktop Profile Management (Samba HOWTO)](https://www.samba.org/samba/docs/old/Samba3-HOWTO/ProfileMgmt.html) | Explains the Windows 9x vs. NT/2000/XP+ profile format differences, `logon path` and `logon home` parameters, mandatory profiles, and disabling roaming profiles via Group Policy. |
| [Red Hat - Configuring the NFS Server (RHEL 7)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/storage_administration_guide/nfs-serverconfig) | Official reference for NFS server setup on RHEL including the `/etc/exports` syntax, `sync`/`async` write semantics, `root_squash`, `no_subtree_check`, firewall port requirements, and `exportfs` usage. |
| [OneUptime - Configure NFS Exports with Specific Options on Ubuntu](https://oneuptime.com/blog/post/2026-03-02-how-to-configure-nfs-exports-with-specific-options-on-ubuntu/view) | Practical guide covering the full range of `/etc/exports` options with annotated examples, NFSv4 pseudo-filesystem (`fsid=0`, `crossmnt`) setup, per-client option differentiation, and `exportfs -ra` / `exportfs -v` verification. |