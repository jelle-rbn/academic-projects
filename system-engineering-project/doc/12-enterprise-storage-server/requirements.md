# Requirements: Enterprise Storage Server

Author(s): J. Magerman - `johan.magerman@student.hogent.be`

This document specifies the requirements and technical choices for the deployment of a centralized, Linux-based Enterprise Storage Server. The system is designed to decouple compute from storage, providing encrypted, redundant network shares for both Active Directory users and infrastructure services (Webserver).

## Host Requirements

The storage server is provisioned as a virtual machine using Vagrant and VirtualBox.

| Software | Description |
| :--- | :--- |
| [Oracle Virtualbox](https://www.virtualbox.org/) | Virtualisation software for running the node |
| [Vagrant](https://developer.hashicorp.com/vagrant) | Infrastructure-as-code tool for automated provisioning |

## Deliverables

- **Operating System Redundancy:** Implementation of a RAID-1 mirror for the OS drives.
- **Scalable Data Storage:** Implementation of a RAID-5 array with a hot spare for data storage.
- **Encryption at Rest:** Implementation of LUKS2 disk encryption on the data array.
- **Logical Volume Management:** Use of LVM to manage partitions on top of the encrypted layer.
- **Active Directory Integration:** Joining the server to the `ad.t02-domain404.internal` domain as a member server.
- **Network File Sharing:** Provisioning of Samba shares for Windows users and NFS exports for the WordPress webserver.
- **Security Hardening:** Implementation of SELinux policies and Firewall rules for storage protocols.

## Technical Choices & Rationale

| Layer | Choice | Rationale |
| :--- | :--- | :--- |
| **OS Partitioning** | **RAID-1** (2x 40GB) | Ensures system availability; if one OS disk fails, the node remains operational. |
| **Data Partitioning** | **RAID-5** (4x 128GB) | Provides a balance between storage capacity, performance, and fault tolerance. Using 3 active drives and 1 hot spare allows for immediate recovery upon disk failure. |
| **Partition Table** | **GPT** | Required for modern storage standards and partitions larger than 2TB. |
| **Encryption** | **LUKS2** | Provides high-grade enterprise encryption at rest using the `aes-xts-plain64` cipher and 512-bit keys. |
| **Volume Manager** | **LVM** | Allows for flexible management of storage; logical volumes can be resized or snapshotted without re-partitioning the raw disks. |
| **Filesystem** | **XFS** | The default for AlmaLinux; chosen for its superior performance with large files and high scalability in enterprise environments. |
| **Identity Service** | **Winbind** | Used to map Active Directory SIDs to Linux UIDs, allowing domain users to own files on the Linux storage. |
| **Protocol** | **NFS & Samba** | **Samba** provides native integration for Windows clients (home folders/profiles), while **NFS** is used for high-performance, low-overhead mounting of WordPress data on the webserver. |

## Subtasks

1. **Environment Setup**
  - Person in charge: J. Magerman
  - Dependencies: Vagrant configuration
2. **RAID Array Configuration**
  - Person in charge: J. Magerman
  - Dependencies: Block device availability
3. **LUKS2 Encryption & Automation**
  - Person in charge: J. Magerman
  - Dependencies: Subtask 2, Keyfile generation
4. **LVM & Filesystem Setup**
  - Person in charge: J. Magerman
  - Dependencies: Subtask 3
5. **AD Domain Integration**
  - Person in charge: J. Magerman
  - Dependencies: Windows DC availability
6. **NFS/Samba Share Provisioning**
  - Person in charge: J. Magerman
  - Dependencies: Subtask 4, 5
7. **Test Plan & Technical Documentation**
  - Person in charge: J. Magerman
  - Dependencies: All subtasks

## Technical Specifications

| Component | Value |
| :--- | :--- |
| **OS** | AlmaLinux 10 |
| **Storage IP** | `192.168.132.199` |
| **Encryption Mapper** | `md1_crypt` |
| **Mount Point** | `/export/storage` |
| **Samba Shares** | `homefolders`, `profiles` |
| **NFS Export** | `/export/storage/wordpress` to `192.168.132.196` |

## Time Spent

| Student | Estimated Effort | Actual effort | Variance remarks |
| :--- | :--- | :--- | :--- |
| Johan | 12h0m | 20h0m |  |