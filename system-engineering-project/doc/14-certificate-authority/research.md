# Research: Certificate Authority (CA) Extension

Author(s): J. Magerman - `johan.magerman@student.hogent.be`

This document outlines the preliminary research conducted for the implementation of the Enterprise Root CA and the automated certificate bridge between Windows and Linux.

---

## 1. Installing & Configuring Active Directory Certificate Services (AD CS)

Research focused on the programmatic installation of the Certificate Authority role on Windows Server 2022 to avoid manual GUI configuration.

**Key findings:**
* The `ADCS-Cert-Authority` feature must be installed before configuration using `Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools`.
* `Install-AdcsCertificationAuthority` allows for a fully headless setup of an Enterprise Root CA; the `-CAType EnterpriseRootCA` parameter and Enterprise Admin credentials are required.
* Key storage providers and hash algorithms (SHA256) are critical for modern browser compatibility; `RSA#Microsoft Software Key Storage Provider` with `-KeyLength 2048` and `-HashAlgorithmName SHA256` is the recommended baseline.
* Validity period (`-ValidityPeriod Years -ValidityPeriodUnits 10`) should be set explicitly for root CAs, as subordinate CA validity is always capped by the parent.
* The `-Force` parameter can be used to suppress interactive confirmation prompts during unattended provisioning.

**Sources:**
| Source | Description |
| :--- | :--- |
| [Microsoft Learn - Install the Certification Authority](https://learn.microsoft.com/en-us/windows-server/networking/core-network-guide/cncg/server-certs/install-the-certification-authority) | Official step-by-step guide covering both GUI wizard and PowerShell installation on Windows Server 2016-2025. |
| [Microsoft Learn - Install-AdcsCertificationAuthority cmdlet reference](https://learn.microsoft.com/en-us/powershell/module/adcsdeployment/install-adcscertificationauthority?view=windowsserver2022-ps) | Full parameter reference for the ADCSDeployment PowerShell module, including crypto provider options and CA type flags. |
| [iTomation - Install Microsoft CA on Server Core](https://itomation.ca/how-to-install-microsoft-ca-on-server-core/) | Practical walkthrough for a headless (no-GUI) Enterprise Root CA install using only PowerShell, including verification via `certsrv.msc`. |
| [Power Sysadmin - Install Active Directory Certification Authority](https://poweradm.com/install-certification-authority-windows/) | Covers both single-node root CA and a two-tier root/subordinate CA setup, including auto-enrollment GPO configuration. |
| [Medium - Building a Certificate Authority in Active Directory: A Step-by-Step Guide](https://medium.com/@alexswin/building-a-certificate-authority-in-active-directory-a-step-by-step-guide-10b8eff5ee28) | Community walkthrough covering prerequisites, role installation, and CA configuration with annotated PowerShell examples. |
| [Nginx.org - Configuring HTTPS Servers](https://nginx.org/en/docs/http/configuring_https_servers.html) | Official Nginx documentation for the `ssl_certificate` and `ssl_certificate_key` directives, file permission requirements, protocol/cipher configuration, and session cache tuning. |
| [Nginx Docs - SSL Termination (NGINX Plus)](https://docs.nginx.com/nginx/admin-guide/security-controls/terminating-ssl-http/) | Practical guide for setting up HTTPS on Nginx, covering certificate and key file placement, access restrictions for the private key, and TLS protocol hardening. |

---

## 2. Automated Certificate Signing with `certreq`

Since the Linux proxy cannot natively communicate with AD CS over RPC, a command-line tool was needed to process incoming Certificate Signing Requests (CSRs) from the Windows side.

**Key findings:**
* `certreq.exe` is the standard Windows utility for submitting requests to a CA via CLI; it is built into the OS and requires no additional installation.
* The `-submit` flag is used to send a `.req` or `.csr` file to the CA and retrieve the resulting `.cer` file in a single operation.
* The `-config` parameter must point to the CA in the format `ComputerName\CAName`; the CA name can be verified in the Certification Authority MMC snap-in (`certsrv.msc`).
* The `CertificateTemplate:WebServer` attribute must be explicitly passed via `-attrib` to ensure the correct Extended Key Usages (EKU) - in particular Server Authentication - are embedded in the issued certificate.
* When submitting from a non-domain-joined machine, `-username` and `-p` credentials for a CA administrator account must be supplied.

**Sources:**
| Source | Description |
| :--- | :--- |
| [Microsoft Learn - certreq command reference](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/certreq_1) | Official syntax reference covering `-new`, `-submit`, `-accept`, `-retrieve`, and all flags including `-config` and `-attrib`. |
| [250 Hello - How To Request a Certificate Without IIS or Exchange (2022)](https://blog.rmilne.ca/2022/02/01/how-to-request-certificate-without-using-iis-or-exchange-updated-2022/) | Detailed guide on generating an INF file, creating a CSR with `certreq -new`, and submitting it to an internal CA; covers SAN certificates and common encoding pitfalls (ANSI vs UTF-8). |
| [Aventis Tech - Request SSL Certificate from Microsoft CA with Certreq](https://aventistech.com/2019/09/09/request-ssl-certificate-from-microsoft-ca-with-certreq/) | Concise end-to-end example of `certreq -submit` against an internal Enterprise CA and importing the result with `Import-Certificate`.

---

## 3. SSH Key Authentication and Cross-Platform Trust

To enable the Domain Controller to perform actions on the Linux Reverse Proxy without manual password entry, an SSH-key-based trust relationship is established.

**Key findings:**
* Trust is established by placing a private key on the Domain Controller that corresponds to a public key in the `authorized_keys` file on the Reverse Proxy.
* OpenSSH on Windows enforces strict ACL requirements: the private key file must be owned by the connecting user, and all inherited permissions must be removed via `icacls` (`/inheritance:r`). Files with overly open ACLs are rejected outright with a "UNPROTECTED PRIVATE KEY FILE" error.
* For accounts that are members of the local Administrators group, Windows OpenSSH uses `C:\ProgramData\ssh\administrators_authorized_keys` rather than the per-user `~\.ssh\authorized_keys` file; that file itself must be restricted to SYSTEM and Administrators only.
* The connection uses `-o StrictHostKeyChecking=no` to automatically accept the remote host's fingerprint during the initial automated connection; subsequent connections reuse the stored fingerprint.
* The SSH Agent service (`ssh-agent`) can be configured to start automatically and store private keys so they do not need to be referenced by path on every invocation.

**Sources:**
| Source | Description |
| :--- | :--- |
| [Microsoft Learn - Key-Based Authentication in OpenSSH for Windows](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement) | Official guide covering key generation, `authorized_keys` placement, `icacls`-based permission hardening, and the administrators_authorized_keys special case. |
| [Win32-OpenSSH Wiki - Security Protection of Files](https://github.com/PowerShell/Win32-OpenSSH/wiki/Security-protection-of-various-files-in-Win32-OpenSSH) | Low-level explanation of how Windows ACLs map to Unix permission semantics in OpenSSH, with `icacls` commands to fix misconfigured host keys and user keys. |
| [Windows OS Hub - Configuring SSH Public Key Authentication on Windows](https://woshub.com/using-ssh-key-based-authentication-on-windows/) | End-to-end walkthrough covering key generation, ssh-agent setup, copying public keys to a remote host, and the administrator account / `administrators_authorized_keys` edge case. |
| [DEV Community - Fixing "Unprotected Private Key File" Errors on Windows](https://dev.to/theodora_e6f61d02577a5f06/using-ssh-keys-on-windows-fixing-unprotected-private-key-file-errors-1d07) | Targeted guide explaining why Windows ACL inheritance causes the "permissions too open" error and providing the exact `icacls /inheritance:r /remove` sequence to resolve it. |
| [SSH.com Academy - Public Key Authentication](https://www.ssh.com/academy/ssh/public-key-authentication) | Platform-agnostic explanation of asymmetric key authentication principles, the role of the `authorized_keys` file, and key management best practices. |

---

## 4. Cross-Platform Automation (SSH & SCP)

To bridge the gap between the Windows DC and the Linux Nginx proxy, a secure transport mechanism was required to exchange CSRs and signed certificates.

**Key findings:**
* Windows Server 2019/2022 ships with a native OpenSSH client; no third-party tools are required for `ssh` or `scp` operations from PowerShell or cmd.
* `scp` provides a reliable way to pull the `.csr` from the proxy and push the signed `.cer` back using the same syntax as on Linux (`scp user@host:/remote/path C:\local\path`).
* Remote commands (directory creation, Nginx configuration reloads, permission changes via `sudo`) are executed by passing a command string to `ssh` as a final argument.
* For text file transfers between Windows and Linux, encoding differences can corrupt file content; using `scp` for binary certificate files avoids this problem entirely.
* Public key authentication (not password) must be used for non-interactive automation - password-based `scp` in scripts is insecure and fragile.

**Sources:**
| Source | Description |
| :--- | :--- |
| [Microsoft Learn - OpenSSH for Windows overview](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview) | Official overview of the native OpenSSH client and server components available on Windows Server 2019/2022, including installation and feature scope. |
| [4sysops - Copying Files Between Windows and Linux with SCP and PowerShell](https://4sysops.com/archives/copying-files-between-windows-and-linux-with-scp-and-powershell/) | Practical guide covering native `scp` syntax from a Windows host, push and pull operations, and the recommendation to use public key auth for automated transfers. |
| [ShellGeek - Copy Files From Windows to Linux Using PowerShell](https://shellgeek.com/copy-files-from-windows-to-linux-using-powershell/) | Concise command reference for `scp` and `pscp` from PowerShell with annotated output examples. |
| [Serverspace - Copy Files and Run Commands via SSH](https://serverspace.io/support/help/copy-files-and-run-commands-through-ssh/) | Explains running single and chained remote commands over SSH (using `;` as a separator), executing local scripts remotely, and using non-default ports. |

---

## 5. Handling Scripting Incompatibilities (CRLF vs LF)

During development, it was discovered that executing multi-line strings originating from Windows on a Linux target causes shell errors due to line-ending differences.

**Key findings:**
* Windows uses CRLF (`\r\n`) while Linux uses LF (`\n`). When a PowerShell here-string is passed through an SSH tunnel, the `\r` characters are appended to each line of the bash command, causing errors like `/bin/bash^M: no such file or directory`.
* PowerShell strings must be sanitized using the `-replace` operator (`` `r`n``, `` `n` ``) or `[IO.File]::ReadAllText` / `WriteAllText` before being sent through an SSH command string.
* The `dos2unix` utility on Linux (or `sed -i 's/\r//'`) can strip stray CR characters from scripts or config files that were created on Windows and transferred over.
* Permissions on the Linux side (`/etc/nginx/ssl`) must be managed via `sudo` within the SSH command string to ensure the Nginx service account can read the deployed certificates.
* Certificate and key files deployed to Nginx must be readable by the Nginx master process; the `ssl_certificate` and `ssl_certificate_key` directives in `nginx.conf` point to these paths, and incorrect permissions cause a silent startup failure.

**Sources:**
| Source | Description |
| :--- | :--- |
| [SS64 - Set Line Endings in PowerShell (set-eol.ps1)](https://ss64.com/ps/syntax-set-eol.html) | Reference script and explanation for converting files between Windows (CRLF), Unix (LF), and classic Mac (CR) line endings using `[IO.File]::ReadAllText` and `WriteAllText`. |
| [Daniel Schwensen - Resolving Windows Line Endings (CRLF) Issues in Shell Scripts](https://danielschwensen.github.io/2025-05-25-Windows-Line-Endings/) | Explains the `/bin/bash^M` error caused by CRLF in scripts sent to Linux, and the `dos2unix` and `sed` remediation commands. |
| [Rigel Computer - Solve the CRLF vs LF Problem on Windows and Docker/Linux](https://medium.com/rigel-computer-com/crlf-and-lf-on-windows-and-docker-small-cause-big-trouble-%EF%B8%8F-a7005482bc79) | Covers root causes, impact on shell scripts and config files in Linux environments, and mitigation strategies including editor settings and Git `autocrlf`. |