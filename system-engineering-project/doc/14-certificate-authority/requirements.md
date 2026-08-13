# Requirements: Certificate Authority (CA) Extension

Author(s): J. Magerman - `johan.magerman@student.hogent.be`

This document specifies the requirements and technical procedures for the deployment of an Enterprise Root Certificate Authority (CA) on the Windows Domain Controller.
This extension facilitates automated SSL certificate issuance for internal infrastructure, specifically targeting the Linux-based reverse proxy.

## Host Requirements

The software runs as an extension of the existing Windows Infrastructure managed via Vagrant.

| Software | Description |
| :--- | :--- |
| [Oracle Virtualbox](https://www.virtualbox.org/) | Virtualisation software used to run the virtual machines |
| [Vagrant](https://developer.hashicorp.com/vagrant) | Command line utility for managing the lifecycle of the Windows DC and Client |

## Deliverables

- **Dedicated Service Account:** A specific account (`SVC_PKIAdmin`) must be created with Enterprise Admin rights to manage CA provisioning.
- **Enterprise Root CA Installation:** The Active Directory Certificate Services (AD CS) role must be installed and configured as an Enterprise Root CA.
- **Security Hardening:** The CA must use a 4096-bit RSA key with SHA256 hashing and a 10-year validity period.
- **Automated CSR Processing:** Implementation of a PowerShell-based bridge to pull Certificate Signing Requests (CSRs) from the Linux Reverse Proxy via SSH/SCP.
- **Certificate Issuance:** Automated signing of proxy requests using the `WebServer` template.
- **Deployment Automation:** Final certificates must be pushed back to the proxy and applied to the Nginx service without manual intervention.

## Subtasks

1. **Service Account Provisioning**
  - Person in charge: Johan
  - Dependencies: Active Directory Domain deployment
2. **AD CS Role Installation**
  - Person in charge: Johan
  - Dependencies: Subtask 1
3. **Enterprise Root CA Configuration**
  - Person in charge: Johan
  - Dependencies: Subtask 2
4. **SSH/SCP Automation Bridge**
  - Person in charge: Johan
  - Dependencies: Reverse Proxy availability, SSH Key configuration
5. **Certificate Template & Signing Logic**
  - Person in charge: Johan
  - Dependencies: Subtask 3, 4
6. **Technical Documentation**
  - Person in charge: Johan
  - Dependencies: All implementation subtasks
7. **Functional Validation**
  - Person in charge: Johan
  - Dependencies: All subtasks

## Technical Specifications

| Component | Requirement / Value |
| :--- | :--- |
| **OS** | Windows Server 2022 (Core/Standard) |
| **Role** | Active Directory Certificate Services (AD CS) |
| **CA Type** | Enterprise Root CA |
| **Common Name** | `DOMAIN404-Root-CA` |
| **Key Length** | 4096-bit RSA |
| **Hash Algorithm** | SHA256 |
| **Validity** | 10 Years |
| **Admin Account** | `SVC_PKIAdmin` |

## Time Spent

| Student | Estimated Effort | Actual effort | Variance remarks |
| :--- | :--- | :--- | :--- |
| Johan | 6h0m | 10h0m | CA installation was straightforward, but automating `certreq` via `Invoke-Command` loopbacks took significant troubleshooting. |
| Johan | 4h0m | 7h0m | Configuring SSH keys and ensuring line endings (`\r\n` vs `\n`) were correct during remote command execution added unexpected time. |