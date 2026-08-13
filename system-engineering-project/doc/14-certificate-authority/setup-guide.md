# Setup guide: Certificate Authority (CA) Extension

Author(s): J. Magerman - `johan.magerman@student.hogent.be`

This guide describes the step-by-step procedure to deploy the Enterprise Root CA and the automated certificate provisioning for the reverse proxy. It covers both the automated deployment during provisioning and the manual fallback procedure using a standalone script.

## Prerequisites

Ensure the following items are configured in your infrastructure before deployment:
* **Windows Domain Controller**: The server must be fully promoted and functional.
* **Service Account**: The `SVC_PKIAdmin` account must be defined in `win-data.psd1` and possess `Enterprise Admins` group membership.
* **SSH Key**: The private key for the reverse proxy (`proxy_cert_key`) must be present in the provisioning files directory.
* **Network Connectivity**: The Domain Controller must be able to reach the Reverse Proxy IP `192.168.132.234` over the internal network on port 22.

## Provisioning Workflow

The CA deployment and initial certificate assignment are integrated into the automated Vagrant provisioning process.

### 1. Automated Deployment (Stages 1 - 3)
* **Role Installation**: The `ADCS-Cert-Authority` feature is installed on the Domain Controller.
* **CA Provisioning**: The script executes `Install-AdcsCertificationAuthority` using the `SVC_PKIAdmin` credentials to establish the `DOMAIN404-Root-CA`.
* **SSH Security**: The proxy SSH key is copied to the local user profile and restricted via `icacls` to allow the OpenSSH client to function.
* **Automated SSL Bridge**: The `windowsdc-stage3.ps1` script attempts to pull a CSR from the proxy, sign it using `certreq` with the `WebServer` template, and push the signed certificate back.

### 2. Manual Fallback (Standalone Script)
If the Reverse Proxy is unreachable during the initial provisioning, the automated certificate block in Stage 3 skips the process gracefully. In this case, the certificate must be assigned manually once the proxy is online using a standalone script.

* **Step 1: Locate the Script**: Navigate to the following path on the Domain Controller: `C:\provisioning\files\windowsdc\certificateassignment.ps1`.
* **Step 2: Execute the Assignment**: Open PowerShell as an Administrator and run the script:
    ```powershell
    powershell.exe -File "C:\provisioning\files\windowsdc\certificateassignment.ps1"
    ```
* **Step 3: Script Logic**: The standalone script performs the same automated steps as the Stage 3 script:
    * It authenticates to the proxy using the `proxy_cert_key`.
    * It pulls the CSR from `/certs/reverseproxy.csr` on the proxy.
    * It signs the request via the local CA using the `WebServer` template.
    * It pushes the `.cer` back to the proxy and restarts the Nginx service.

## Verification

Confirm the CA and certificate assignment are working correctly using these checks:

| Test | Procedure | Expected Result |
| :--- | :--- | :--- |
| **CA Service Status** | Run `Get-Service certsvc` on the DC. | The status is listed as `Running`. |
| **Provisioning Log** | Check the Vagrant output for the message "Reverse Proxy Certificate Provisioning Complete!". | The success message is displayed. |
| **HTTPS Verification** | Run `curl.exe -vI https://t02-domain404.internal` from a Windows Client. | The connection is successful and the certificate is trusted. |

## Troubleshooting

| Problem | Possible Solution |
| :--- | :--- |
| **Automation Skipped** | Verify if the proxy was offline during provisioning; if so, run the `certificateassignment.ps1` script manually. |
| **SSH Key Permission Error** | Ensure all inherited permissions have been stripped from the key file in the user profile using `icacls`. |
| **`certreq` Signing Failure** | Confirm that the `SVC_PKIAdmin` has Full Control permissions over the `C:\certs` directory. |
| **Nginx Not Applying Certificate** | Manually execute `sudo systemctl restart nginx` on the proxy to force-load the updated certificate files. |