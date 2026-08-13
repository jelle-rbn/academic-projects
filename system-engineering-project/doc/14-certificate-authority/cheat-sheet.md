# Cheat-sheet: Active Directory Certificate Services (AD CS)

Author(s): J. Magerman - `johan.magerman@student.hogent.be`

This document provides a quick reference for common commands used for the Windows Enterprise CA and the automated certificate workflow.

## Service Management

| Command | Description |
| :--- | :--- |
| `Get-Service certsvc` | Check the status of the Certification Authority service |
| `Install-WindowsFeature -Name 'ADCS-Cert-Authority'` | Install the CA feature binaries |
| `certsrv.msc` | Open the Certification Authority management GUI |

## Certificate Operations (PowerShell)

| Command | Description |
| :--- | :--- |
| `certreq -q -submit -config "windowsdc\DOMAIN404-Root-CA" -attrib "CertificateTemplate:WebServer" [CSR] [Output]` | Submit a CSR to the CA and save the signed certificate |
| `Get-CA` | View the configuration of the local CA |
| `icacls "C:\certs" /grant "DOMAIN404\SVC_PKIAdmin:(OI)(CI)F" /T` | Grant the PKI service account permissions to the certificate staging folder |

## Automated Provisioning (SSH/SCP)

The `windowsdc-stage3.ps1` script uses SSH and SCP to automate SSL setup for the Nginx proxy.

| Command | Description |
| :--- | :--- |
| `ssh -i [Key] [User]@[IP] "[Command]"` | Execute commands on the proxy to generate CSRs or restart Nginx |
| `scp -i [Key] [Source] [Destination]` | Transfer files between the DC and the Linux Proxy |

## CA Configuration Data

| Component | Value |
| :--- | :--- |
| **CA Common Name** | `DOMAIN404-Root-CA` |
| **PKI Admin Account** | `SVC_PKIAdmin` |
| **Root Domain** | `t02-domain404.internal` |
| **Validity Period** | `10 Years` |
| **Key Length** | `4096-bit RSA` |

## File Locations

| Resource | Location |
| :--- | :--- |
| **DC Staging Folder** | `C:\certs\` |
| **SSH Key on DC** | `$env:USERPROFILE\.ssh\proxy_cert_key` |
| **Proxy SSL Root** | `/etc/nginx/ssl/` |