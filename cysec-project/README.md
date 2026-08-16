# NPE CyberSecurity & Virtualisation 2025-2026

## Project: Automated PoC for Insecure Deserialization (simulating CVE-2025-59287)

---

## Team Members

Jelle Robyn (@jelle-rbn)

Marc De Potter (@MarcDePotter)

---

## Project Overview

This project demonstrates an automated deployment of a Windows Server environment to exploit insecure deserialization flaws. While focusing on a WSUS-infrastructure, we demonstrate how untrusted data handling in .NET and Python services can lead to Remote Code Execution (RCE). This vulnerability exists in the Windows Server Update Service (WSUS) and allows an unauthorized attacker to execute arbitrary code over the network due to improper deserialization of untrusted data.

**Project Goals:**

1. **Automation:** Full VM lifecycle management using `VBoxManage` and a VDI approach.
2. **Infrastructure-as-Code:** Fully automated setup of the WSUS role, network stack, and vulnerable endpoints using PowerShell.
3. **Security Analysis:** Demonstrating RCE via Python `pickle` and .NET `BinaryFormatter` to illustrate why modern services move away from these methods.

---

## Environment & Requirements

To reproduce this project, the following components are required:

- **VirtualBox Version:** 7.x
- **Network:** Custom NAT-Network (**LabNet**: `192.168.56.0/24`) with DHCP enabled.
- **Target:** Windows Server 2022 (IP: `192.168.56.20`).
- **Attacker:** Kali Linux (Rolling release) with `netcat` and `python3`.

---

## The Attack (Proof of Concept)

The attack demonstrates how a malicious serialized object, when sent to a listening service, triggers code execution during the "unpacking" (deserialization) phase. Our PoC follows these steps:

1. **Listener:** Attacker starts a `netcat` listener on Kali (`nc -lvnp 4444`).
2. **Payload:** A Python script generates a serialized object containing a PowerShell Reverse Shell command.
3. **Execution:** The payload is sent to the vulnerable endpoint (Port `8000` or `9000`).
4. **Callback:** The Windows Server executes the command, granting the attacker a `SYSTEM` shell.

---

## Project Structure

- **/scripts:**
  - `server-install-vdi.ps1`: Main host automation script.
  - `setup-wsus.ps1`: Configures WSUS role and Firewall.
  - `setup-pickle-vuln.ps1`: Deploys vulnerable Python listener.
  - `setup-dotnet-vuln.ps1`: Deploys vulnerable .NET listener.
  - `exploit.py`: The attacker's exploit script.

- **/docs:**
  - `deployment_manual.md`: Includes the attack cheatsheet.
  - `sources`: Documentation used for preparation of the assignement and understanding the exploit.

- `README.md`: Project summary.
